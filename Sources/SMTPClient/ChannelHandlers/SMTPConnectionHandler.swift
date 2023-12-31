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
    typealias InboundIn = SMTPReply
    typealias OutboundOut = SMTPOutbound
    typealias OutboundIn = (EventLoopPromise<SMTPReply>, SMTPOutbound)
    
    private let eventLoop: EventLoop

    private var replyQueue = Deque<EventLoopPromise<SMTPReply>>()
    
    private var state: State = .ready
    
    private enum State {
        case ready, error(Error)
    }
    
    init(eventLoop: EventLoop, onReady: EventLoopPromise<SMTPReply>) {
        self.replyQueue.append(onReady)
        self.eventLoop = eventLoop
    }
    
    func channelActive(context: ChannelHandlerContext) {
        context.fireChannelActive()
    }
    
    public func channelInactive(context: ChannelHandlerContext) {
        switch self.state {
        case .error(let error):
            return self.failAllReplies(because: error)
        default:
            return self.failAllReplies(because: SMTPConnectionError.connectionClosed)
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
        let reply = self.unwrapInboundIn(data)
        
        print("reply", reply)
        
        if let promise = replyQueue.popFirst() {
            promise.succeed(reply)
        }
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let (replyPromise, outbound) = self.unwrapOutboundIn(data)

        switch state {
        case .ready:
            self.replyQueue.append(replyPromise)

            context.writeAndFlush(wrapOutboundOut(outbound), promise: promise)
            promise?.futureResult.whenFailure { replyPromise.fail($0) }
        case let .error(err):
            promise?.fail(err)
            replyPromise.fail(err)
        }
    }
    
    
    func failAllReplies(because error: Error) {
        self.state = .error(error)

        let queue = self.replyQueue
        self.replyQueue.removeAll()

        queue.forEach { $0.fail(error) }

    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.failAllReplies(because: error)
        return context.close(promise: nil)
    }

    deinit {
        if !self.replyQueue.isEmpty {
            assertionFailure("Queue is not empty! Queue size: \(self.replyQueue.count)")
        }
    }
}

