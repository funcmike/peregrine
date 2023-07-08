//
//  File.swift
//  
//
//  Created by Krzysztof Majk on 07/07/2023.
//

import XCTest
import NIOCore
import SMTPProtocol

@testable import SMTPProtocol

@available(macOS 13.0, *)
final class ParseTests: XCTestCase {
    func testParseCommand() throws {
        do {
            var buffer = ByteBuffer(string: "EhLo test.com\r\n")
            let command = try Command.decode(from: &buffer)
            print(command, command.verb.rawValue)

        }

        do {
            var buffer = ByteBuffer(string: "Helo test.com\r\n")
            let command = try Command.decode(from: &buffer)
            print(command, command.verb.rawValue)
        }

        do {
            var buffer = ByteBuffer(string: "Mail From: <test@test.com> SIZE=10 ENVID=ID\r\n")
            let command = try Command.decode(from: &buffer)
            print(command, command.verb.rawValue)
        }

        do {
            var buffer = ByteBuffer(string: "Rcpt To: <test@test.com> NOTIFY=FAILURE,SUCCESS,DELAY\r\n")
            let command = try Command.decode(from: &buffer)
            print(command, command.verb.rawValue)
        }

        do {
            var buffer = ByteBuffer(string: "Data\r\n")
            let command = try Command.decode(from: &buffer)
            print(command, command.verb.rawValue)
        }

        do {
            var buffer = ByteBuffer(string: "Quit\r\n")
            let command = try Command.decode(from: &buffer)
            print(command, command.verb.rawValue)
        }        
        
        do {
            var buffer = ByteBuffer(string: "Data\r\nQuit\r\n")
            let command1 = try Command.decode(from: &buffer)
            print(command1, command1.verb.rawValue)
            let command2 = try Command.decode(from: &buffer)
            print(command2, command2.verb.rawValue)
        }
    }
}
