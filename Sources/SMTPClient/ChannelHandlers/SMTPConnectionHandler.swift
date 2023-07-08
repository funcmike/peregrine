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
import Collections
import SMTPProtocol


@available(macOS 13.0, *)
internal class SMTPConnectionHandler: ChannelDuplexHandler {
    typealias InboundIn = Command
    typealias OutboundOut = SMTPOutbound
    typealias OutboundIn = (EventLoopPromise<SMTPResponse>, SMTPOutbound)
    
    private let eventLoop: EventLoop

    private var responseQueue = Deque<EventLoopPromise<SMTPResponse>>()
    
    private var state: State = .ready
    
    private enum State {
        case ready, error(Error)
    }
    
    init(eventLoop: EventLoop, onReady: EventLoopPromise<SMTPResponse>) {
        self.responseQueue.append(onReady)
        self.eventLoop = eventLoop
    }
    
    func channelActive(context: ChannelHandlerContext) {
        context.fireChannelActive()
        //return start(use: context)
    }
    
    public func channelInactive(context: ChannelHandlerContext) {
        switch self.state {
        case .error(let error):
            return self.failAllResponses(because: error)
        default:
            return self.failAllResponses(because: SMTPConnectionError.connectionClosed)
        }
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        switch state {
        case .ready: self.state = .error(SMTPConnectionError.connectionClosed)
        default:
            return
        }
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let command = self.unwrapInboundIn(data)
        
        switch command {
        default:
            return
        }

    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let (promise, outbound) = self.unwrapOutboundIn(data)
        
        self.responseQueue.append(promise)
        
        let writeResult = context.writeAndFlush(wrapOutboundOut(outbound))
        writeResult.whenFailure { promise.fail($0) }
    }
    
    
    func failAllResponses(because error: Error) {
        self.state = .error(error)

        let queue = self.responseQueue
        self.responseQueue.removeAll()

        queue.forEach { $0.fail(error) }

    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.failAllResponses(because: error)
        return context.close(promise: nil)
    }

    deinit {
        if !self.responseQueue.isEmpty {
            assertionFailure("Queue is not empty! Queue size: \(self.responseQueue.count)")
        }
    }
}

