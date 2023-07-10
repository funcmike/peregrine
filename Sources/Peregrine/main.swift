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
import NIOPosix
import SMTPClient
import SMTPProtocol

@available(macOS 13.0, *)
@main struct Peregrine {
  static func main() async throws {
      let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
      let connection = try await SMTPConnection.connect(use: eventLoopGroup.next(), from: .init(connection: .plain, server: .init(port: 2525)))
      let reply = try await connection.write(outbound: .command(.noop))
      try await connection.close()
  }
}
