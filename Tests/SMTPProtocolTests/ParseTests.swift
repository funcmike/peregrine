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
import NIOCore
import SMTPProtocol

@testable import SMTPProtocol

@available(macOS 13.0, *)
final class ParseTests: XCTestCase {
    func testParseCommand() throws {
        do {
            var buffer = ByteBuffer(string: "EhLo test.com\r\n")
            let command = try SMTPCommand.decode(from: &buffer)
            print(command, command.verb.rawValue)

        }

        do {
            var buffer = ByteBuffer(string: "Helo test.com\r\n")
            let command = try SMTPCommand.decode(from: &buffer)
            print(command, command.verb.rawValue)
        }

        do {
            var buffer = ByteBuffer(string: "Mail From: <test@test.com> SIZE=10 ENVID=ID\r\n")
            let command = try SMTPCommand.decode(from: &buffer)
            print(command, command.verb.rawValue)
        }

        do {
            var buffer = ByteBuffer(string: "Rcpt To: <test@test.com> NOTIFY=FAILURE,SUCCESS,DELAY\r\n")
            let command = try SMTPCommand.decode(from: &buffer)
            print(command, command.verb.rawValue)
        }

        do {
            var buffer = ByteBuffer(string: "Data\r\n")
            let command = try SMTPCommand.decode(from: &buffer)
            print(command, command.verb.rawValue)
        }

        do {
            var buffer = ByteBuffer(string: "Quit\r\n")
            let command = try SMTPCommand.decode(from: &buffer)
            print(command, command.verb.rawValue)
        }        
        
        do {
            var buffer = ByteBuffer(string: "Data\r\nQuit\r\n")
            let command1 = try SMTPCommand.decode(from: &buffer)
            print(command1, command1.verb.rawValue)
            let command2 = try SMTPCommand.decode(from: &buffer)
            print(command2, command2.verb.rawValue)
        }
    }
    
    func testParseReply() throws {
        do {
            var buffer = ByteBuffer(string: "221 test\r\n")
            let reply = try SMTPReply.decode(from: &buffer)
            print(reply)
        }
        
        do {
            var buffer = ByteBuffer(string: "221-test1\r\n221 test2\r\n")
            let reply = try SMTPReply.decode(from: &buffer)
            print(reply)
        }
        
        do {
            var buffer = ByteBuffer(string: "221 test1\r\n220 test2\r\n")
            let reply1 = try SMTPReply.decode(from: &buffer)
            print(reply1)
            let reply2 = try SMTPReply.decode(from: &buffer)
            print(reply2)
        }
    }
}
