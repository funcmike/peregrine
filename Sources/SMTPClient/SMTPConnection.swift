//===----------------------------------------------------------------------===//
//
// This source file is part of the Peregrine project
//
// Copyright (c) 2023 Krzysztof Majk
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore
import NIOPosix
import NIOSSL
import NIOConcurrencyHelpers
import SMTPProtocol

@available(macOS 13.0, *)
public struct SMTPConnectionConfiguration: Sendable {
    public init(connection: SMTPConnectionConfiguration.Connection, server: SMTPConnectionConfiguration.Server) {
        self.connection = connection
        self.server = server
    }
    
    public let connection: Connection
    public let server: Server
    
    public enum Connection: Sendable {
        case tls(TLSConfiguration?, sniServerName: String?)
        case plain
    }
    
    public struct Server: Sendable {
        public init(host: String = "127.0.0.1", port: Int = 25, timeout: TimeAmount = TimeAmount(Duration.seconds(10))) {
            self.host = host
            self.port = port
            self.timeout = timeout
        }
        
        public var host: String
        public var port: Int
        public var timeout: TimeAmount
    }
}

@available(macOS 13.0, *)
public final class SMTPConnection {
    internal enum ConnectionState {
        case open
        case shuttingDown
        case closed
    }

    public var isConnected: Bool {
        // `Channel.isActive` is set to false before the `closeFuture` resolves in cases where the channel might be
        // closed, or closing, before our state has been updated
        return self.channel.isActive && self.state.withLockedValue { $0 == .open }
    }

    public var closeFuture: NIOCore.EventLoopFuture<Void> {
        return self.channel.closeFuture
    }

    public var eventLoop: EventLoop { return self.channel.eventLoop }

    private let channel: NIOCore.Channel

    private let state = NIOLockedValueBox(ConnectionState.open)

    init(channel: NIOCore.Channel) {
        self.channel = channel
    }

    /// Connect to broker.
    /// - Parameters:
    ///     - eventLoop: EventLoop on which to connect.
    ///     - config: Configuration data.
    /// - Returns:  EventLoopFuture with AMQP Connection.
    public static func connect(use eventLoop: EventLoop, from config: SMTPConnectionConfiguration) -> EventLoopFuture<SMTPConnection> {
        let promise = eventLoop.makePromise(of: SMTPReply.self)
        let handler = SMTPConnectionHandler(eventLoop: eventLoop, onReady: promise)

        return eventLoop.flatSubmit { () -> EventLoopFuture<SMTPConnection> in
            let result = self.boostrapChannel(use: eventLoop, from: config, with: handler)
                .flatMap { channel in
                    promise.futureResult.flatMapThrowing { reply in
                        guard .init(severity: .positiveCompletion, category: .connections, detail: .zero) == reply.code else {
                            throw SMTPConnectionError.invalidReply(reply)
                        }
                        return SMTPConnection(channel: channel)
                    }
                }

            result.whenFailure { err in handler.failAllReplies(because: err) }
            return result
        }
    }
    
    public func write(outbound: SMTPOutbound) -> EventLoopFuture<SMTPReply> {
        let promise = eventLoop.makePromise(of: SMTPReply.self)
        let result = self.channel.writeAndFlush((promise, outbound))
        result.whenFailure { promise.fail($0) }
        return result.flatMap { promise.futureResult }
    }
    
    private func quit() -> EventLoopFuture<Void> {
        return self.write(outbound: .command(.quit))
            .flatMapThrowing { reply in
                guard .init(severity: .positiveCompletion, category: .connections, detail: .one) == reply.code else {
                        throw SMTPConnectionError.invalidReply(reply)
                    }

                    return ()
                }
    }


    /// Close a connection.
    /// - Returns: EventLoopFuture that is resolved when connection is closed.
    public func close() -> EventLoopFuture<Void> {
        let shouldClose = state.withLockedValue { state in
            if state == .open {
                state = .shuttingDown
                return true
            }
            
            return false
        }
        
        guard shouldClose else { return self.channel.closeFuture }
        
        return self.eventLoop.flatSubmit {
           return self.quit()
                .map { () in
                    return nil as Error?
                }
                .recover { $0 }
                .flatMap { result in
                    self.channel.close().map {
                        self.state.withLockedValue { $0 = .closed }
                        return (result, nil) as (Error?, Error?)
                    }
                    .recover { error in
                        if case ChannelError.alreadyClosed = error  {
                            self.state.withLockedValue { $0 = .closed }
                            return (result, nil)
                        }
                        
                        return (result, error)
                    }
                }
                .flatMapThrowing {
                    let (server, channel) = $0
                    if (server ?? channel) != nil {
                        throw SMTPConnectionError.connectionClose(server: server, channel: channel)
                    }
                    return ()
                }
        }
    }

    private static func boostrapChannel(
        use eventLoop: EventLoop,
        from config: SMTPConnectionConfiguration,
        with handler: SMTPConnectionHandler
    ) -> EventLoopFuture<NIOCore.Channel> {
        let channelPromise = eventLoop.makePromise(of: NIOCore.Channel.self)

        do {
            let bootstrap = try boostrapClient(use: eventLoop, from: config)

            bootstrap
                .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
                .connectTimeout(config.server.timeout)
                .channelInitializer { channel in
                    channel.pipeline.addHandlers([
                        MessageToByteHandler(SMTPCommandEncoder()),
                        ByteToMessageHandler(SMTPReplyDecoder()),
                        handler
                    ])
                }
                .connect(host: config.server.host, port: config.server.port)
                .map { channelPromise.succeed($0) }
                .cascadeFailure(to: channelPromise)
        } catch {
            channelPromise.fail(error)
        }

        return channelPromise.futureResult
    }

    private static func boostrapClient(
        use eventLoopGroup: EventLoopGroup,
        from config: SMTPConnectionConfiguration
    ) throws -> NIOClientTCPBootstrap {
        guard let clientBootstrap = ClientBootstrap(validatingGroup: eventLoopGroup) else {
            preconditionFailure("Cannot create bootstrap for the supplied EventLoop")
        }

        switch config.connection {
        case .plain:
            return NIOClientTCPBootstrap(clientBootstrap, tls: NIOInsecureNoTLS())
        case .tls(let tls, let sniServerName):
            let sslContext = try NIOSSLContext(configuration: tls ?? TLSConfiguration.clientDefault)
            let tlsProvider = try NIOSSLClientTLSProvider<ClientBootstrap>(context: sslContext, serverHostname: sniServerName ?? config.server.host)
            let bootstrap = NIOClientTCPBootstrap(clientBootstrap, tls: tlsProvider)
            return bootstrap.enableTLS()
        }
    }
    
    deinit {
        if isConnected {
            assertionFailure("close() was not called before deinit!")
        }
    }
}
