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
public extension SMTPConnection {
    /// Connect to SMTP server.
    /// - Parameters:
    ///     - eventLoop: EventLoop on which to connect.
    ///     - config: Configuration data.
    /// - Returns: New SMTP Connection.
    static func connect(use eventLoop: EventLoop, from config: SMTPConnectionConfiguration) async throws -> SMTPConnection {
        return try await self.connect(use: eventLoop, from: config).get()
    }
    
    func write(outbound: SMTPOutbound) async throws -> SMTPReply {
        return try await self.write(outbound: outbound).get()
    }

    /// Close a connection.
    func close() async throws {
        return try await self.close().get()
    }
}
