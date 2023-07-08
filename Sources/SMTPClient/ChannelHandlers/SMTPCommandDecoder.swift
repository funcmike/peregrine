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
import SMTPProtocol

@available(macOS 13.0, *)
public final class SMTPCommandDecoder: ByteToMessageDecoder  {
    public typealias InboundOut = Command

    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        let startReaderIndex = buffer.readerIndex

        do {
            let command = try Command.decode(from: &buffer)
            context.fireChannelRead(wrapInboundOut(command))

            return .continue
        } catch let error as ProtocolError {
            buffer.moveReaderIndex(to: startReaderIndex)

            guard case .incomplete = error else {
                throw error
            }

            return .needMoreData
        } catch {
            preconditionFailure("Expected to only see `ProtocolError`s here.")
        }
    }

    public func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState  {
        return .needMoreData
    }
}

