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

@available(macOS 13.0, *)
public enum SMTPResponse: PayloadDecodable, PayloadEncodable, Sendable {
    case connected
    case closed
    case quitOk
    
    public static func decode(from buffer: inout ByteBuffer) throws -> SMTPResponse {
        throw ProtocolError.commandUnknown("test")
    }
    
    public func encode(into buffer: inout NIOCore.ByteBuffer) throws {
        return
    }
}
