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

import XCTest
import NIOPosix
import NIOCore
import SMTPClient
import SMTPProtocol

@testable import SMTPClient

@available(macOS 13.0, *)
final class ConnectionTests: XCTestCase {
    func testConnect() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let connection = try await SMTPConnection.connect(use: eventLoopGroup.next(), from: .init(connection: .plain, server: .init(port: 2525)))
        
        let reply = try await connection.write(outbound: .command(.noop))
        XCTAssertEqual(reply.code, SMTPReply.Code.init(severity: .positiveCompletion, category: .mailSystem, detail: .zero))
        try await connection.close()
    }
}
