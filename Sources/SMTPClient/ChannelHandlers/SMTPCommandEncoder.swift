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
public enum SMTPOutbound {
    case command(Command)
    case bulk([Command])
    case bytes([UInt8])
}

@available(macOS 13.0, *)
public final class SMTPCommandEncoder: MessageToByteEncoder {
    public typealias OutboundIn = SMTPOutbound

    public func encode(data: SMTPOutbound, out: inout ByteBuffer) throws {
        switch data {
        case .command(let command):
            try command.encode(into: &out)
        case .bulk(let commands):
            for command in commands {
                try command.encode(into: &out)
            }
        case .bytes(let bytes):
            _ = out.writeBytes(bytes)
        }
    }
}
