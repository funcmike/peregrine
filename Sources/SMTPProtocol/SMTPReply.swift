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

let MaxReplyLength = MaxLineLength * 4

public let CRLFString = String(bytes: CRLFBytes, encoding: .utf8)!

@available(macOS 13.0, *)
public struct SMTPReply: PayloadDecodable, PayloadEncodable, Equatable, Sendable {
    public let code: Code
    public let message: String

    public init(code: SMTPReply.Code, message: String) {
        self.code = code
        self.message = message
    }
    
    public static func decode(from buffer: inout ByteBuffer) throws -> SMTPReply {
        let at = buffer.readerIndex

        guard let lines = buffer.getString(at: at, length: buffer.readableBytes) else {
            throw ProtocolError.bytesNotFound
        }
        
        let allLines = lines.split(separator: CRLFString, omittingEmptySubsequences: false)
        guard allLines.count > 1 else {
            throw ProtocolError.incomplete
        }
                
        // last is always empty or ignored (without \r\n)
        let subLines = allLines.dropLast(1)

        var firstCode: Code? = nil
        var replyLength = 0
        var lastLineIdx = 0

    outter: for (i, line) in subLines.enumerated() {
            lastLineIdx = i
            replyLength += line.count + CRLFString.count

            guard replyLength <= MaxReplyLength else {
                throw ProtocolError.replyTooLong
            }

            let codeValue = line[line.startIndex...line.index(line.startIndex, offsetBy: 2)]
            guard let code = Code(rawValue: codeValue) else {
                throw ProtocolError.replyCodeUnparsable(String(codeValue))
            }
            
            if let firstCode, firstCode != code {
                throw ProtocolError.replyCodesDiffer(first: firstCode, current: code)
            } else {
                firstCode = code
            }
            
            let tagValue = line[line.index(line.startIndex, offsetBy: 3)]
            guard let tag = Tag(rawValue: tagValue) else {
                throw ProtocolError.replySignBad(tagValue)
            }

            switch tag {
            case .more where i < subLines.count-1: continue outter
            case .more: throw ProtocolError.incomplete
            case .stop: break outter
            }
        }

        guard let code = firstCode else {
            preconditionFailure("firstCode cannot be null")
        }

        buffer.moveReaderIndex(to: at+replyLength+1)

        var message = String(Set(minimumCapacity: replyLength))

        for line in subLines[...lastLineIdx] {
            message += line[line.index(line.startIndex, offsetBy: 4)...]+CRLFString
        }

        return .init(code: code, message: message)
    }
    
    public func encode(into buffer: inout NIOCore.ByteBuffer) throws {
        let subLines = self.message.split(separator: CRLFString, omittingEmptySubsequences: true)
        let lastLineIdx = subLines.count-1

        for (i, line) in subLines.enumerated() {
            buffer.writeBytes([
                self.code.severity.rawValue.asciiValue!,
                self.code.category.rawValue.asciiValue!,
                self.code.detail.rawValue.asciiValue!,
                i < lastLineIdx ? Tag.more.rawValue.asciiValue! : Tag.stop.rawValue.asciiValue!])
            buffer.writeSubstring(line)
        }
    }
    
    private enum Tag: Character {
        case more = "-"
        case stop = " "
    }
    
    public struct Code: Equatable, Sendable {
        public let severity: Serverity
        public let category: Category
        public let detail: Detail
        
        public init(severity: SMTPReply.Serverity, category: SMTPReply.Category, detail: SMTPReply.Detail) {
            self.severity = severity
            self.category = category
            self.detail = detail
        }
        
        public init?(rawValue: String.SubSequence) {
            if (rawValue.count != 3) { return nil }
            let severity = rawValue[rawValue.startIndex]
            let category = rawValue[rawValue.index(rawValue.startIndex, offsetBy: 1)]
            let detail = rawValue[rawValue.index(rawValue.startIndex, offsetBy: 2)]

            guard let severity = Serverity(rawValue: severity),
                  let category = Category(rawValue: category),
                  let detail = Detail(rawValue: detail) else {
                return nil
            }
            
            self.severity = severity
            self.category = category
            self.detail = detail
        }
    }
    
    public enum Serverity: Character, Sendable {
        /// 2yx
        case positiveCompletion = "2"
        /// 3yz
        case positiveIntermediate = "3"
        /// 4yz
        case transientNegativeCompletion = "4"
        /// 5yz
        case permanentNegativeCompletion = "5"
    }
    
    public enum Category: Character, Sendable {
        /// x0z
        case syntax = "0"
        /// x1z
        case information = "1"
        /// x2z
        case connections = "2"
        /// x3z
        case unspecified3 = "3"
        /// x4z
        case unspecified4 = "4"
        /// x5z
        case mailSystem = "5"
    }
    
    public enum Detail: Character, Sendable {
        case zero = "0"
        case one = "1"
        case two = "2"
        case three = "3"
        case four = "4"
        case five = "5"
        case six = "6"
        case seven = "7"
        case eight = "8"
        case nine = "9"
    }
}
