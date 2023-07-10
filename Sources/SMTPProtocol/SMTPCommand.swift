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
import Network

public protocol PayloadDecodable {
    static func decode(from buffer: inout ByteBuffer) throws -> Self
}

public protocol PayloadEncodable {
    func encode(into buffer: inout ByteBuffer) throws
}

let MaxLineLength = 1024

typealias UnparsedArgs = ArraySlice<UInt8>

enum Token: UInt8, Sendable {
    case cr = 13    // '\r'
    case lf = 10    // '\n'
    case space = 32 // ' '
    case equal = 61 // '='
}

@available(macOS 13.0, *)
public struct Address: CustomStringConvertible, Sendable {
    /// User part of e-mail address
    /// ex. <localPart@domain.com> =>  localPart
    let localPart: String
    /// Domain  part of e-mail address
    /// ex. <localPart@domain.com> =>  domain.com
    let domain: String
    /// Full  original e-mail address
    /// ex. <localPart@domain.com> =>  <localPart@domain.com>
    var full: String {
        return "<\(localPart)@\(domain)>"
    }

    public var description: String { return self.full }

    var rawValue: String { return self.full }

    init(rawValue: String) throws {
        let parts = rawValue.split(separator: "@", omittingEmptySubsequences: true)
        if parts.count != 2 {
            throw ProtocolError.addressUnparsable(rawValue)
        }

        self.localPart = String(parts[0].trimmingPrefix("<"))
        self.domain = String(parts[1].trimmingPrefix(">"))
    }
}


@available(macOS 13.0, *)
public enum SMTPCommand: PayloadDecodable, PayloadEncodable, Sendable {
    /// Identifies client to SMTP server (legacy way).
    case helo(HeloArgs)
    /// Identifies client to SMTP server and request SMTP extensions.
    case ehlo(EhloArgs)
    /// Iinitiates mail transaction and specify reverse-path address and other options.
    case mailFrom(MailFromArgs)
    /// Identifies recipient of the mail data. Can be send multiple times in a single mail transaction.
    case rcptTo(RcptToArgs)
    /// Signals that mail data will be send after this command.
    case data
    /// Aborts current mail transaction (all of previous state MUST BE discared.
    case rset
    /// Signals start of Transport Layer Security communication
    /// see <https://datatracker.ietf.org/doc/html/rfc3207>
    case startTls
    /// Has no effect on any of parameters or previously entered commands.
    /// Used mostly for testing to avoid timeouts.
    case noop
    /// Closes mail transaction and communication channel.
    case quit

    public var verb: Verb {
        switch self {
        case .helo: return .helo
        case .ehlo: return .ehlo
        case .mailFrom: return .mailFrom
        case .rcptTo: return .rcptTo
        case .data: return .data
        case .rset: return .rset
        case .startTls: return .startTls
        case .noop: return .noop
        case .quit: return .quit
        }
    }
    
    public static func decode(from buffer: inout ByteBuffer) throws -> Self {
        let at = buffer.readerIndex

        guard let bytes = buffer.getBytes(at: at, length: buffer.readableBytes) else {
            throw ProtocolError.bytesNotFound
        }
        
        guard let end = bytes.firstIndex(of: Token.lf.rawValue) else {
            throw ProtocolError.incomplete
        }
        
        guard bytes[end-1] == Token.cr.rawValue else {
            throw ProtocolError.crlfNotFound
        }

        buffer.moveReaderIndex(to: at+end+1)

        let line = bytes[bytes.startIndex...end]
        
        if line.count < 6 {
            throw ProtocolError.commandTooShort(String(bytes: line, encoding: .utf8)!)
        }
        
        if line.count > MaxLineLength  {
            throw ProtocolError.commandTooLong
        }
        
        for verb in Verb.allCases {
            let value = verb.rawValue
            
            if line.starts(with: value.utf8, by: {$0.asciiUppercase() == $1}) {
                switch verb {
                case .helo: return try .helo(.init(rawValue: line[value.count...]))
                case .ehlo: return try .ehlo(.init(rawValue: line[value.count...]))
                case .mailFrom: return try .mailFrom(.init(rawValue: line[value.count...]))
                case .rcptTo: return try .rcptTo(.init(rawValue: line[value.count...]))
                case .data: return .data
                case .rset: return .rset
                case .startTls: return .startTls
                case .noop: return .noop
                case .quit: return .quit
                }
            }
        }
        
        throw ProtocolError.commandUnknown(String(bytes: line, encoding: .utf8)!)
    }
    
    public func encode(into buffer: inout ByteBuffer) throws {
        switch self {
        case let .helo(args):
            buffer.writeString(self.verb.rawValue)
            buffer.writeString(" ")
            buffer.writeString(args.rawValue)
            buffer.writeBytes(CRLFBytes)
        case let .ehlo(args):
            buffer.writeString(self.verb.rawValue)
            buffer.writeString(" ")
            buffer.writeString(args.rawValue)
            buffer.writeBytes(CRLFBytes)
        case let .mailFrom(args):
            buffer.writeString(self.verb.rawValue)
            try args.encode(into: &buffer)
            buffer.writeBytes(CRLFBytes)
        case let .rcptTo(args):
            buffer.writeString(self.verb.rawValue)
            try args.encode(into: &buffer)
            buffer.writeBytes(CRLFBytes)
        case .data, .rset, .startTls, .noop, .quit:
            buffer.writeString(self.verb.rawValue)
        }
    }
    
    public enum Verb: String, CaseIterable, Sendable {
        case helo = "HELO "
        case ehlo = "EHLO "
        case mailFrom = "MAIL FROM:"
        case rcptTo = "RCPT TO:"
        case data = "DATA\r\n"
        case rset = "RSET\r\n"
        case startTls = "STARTTLS\r\n"
        case noop = "NOOP\r\n"
        case quit = "QUIT\r\n"
    }
    
    public enum Client: Sendable {
        case domain(String)
        case ipv4(String)
        case ipv6(String)
        
        var rawValue: String {
            switch self {
                
            case let .domain(domain): return domain
            case let .ipv4(ip):  return ip
            case let .ipv6(ip): return ip
            }
        }
        
        init (rawValue: String) throws {
            if let ip = IPv4Address(rawValue) {
                self = .ipv4(ip.rawValue.description)
            } else if let ip = IPv6Address(rawValue) {
                self = .ipv6(ip.rawValue.description)
            } else {
                self = .domain(rawValue)
            }
        }
        
        init(rawValue: UnparsedArgs) throws {
            guard let value = String(bytes: rawValue.dropCRLF(), encoding: .utf8) else {
                throw ProtocolError.stringIsNil
            }
            
            try self.init(rawValue: value)
        }
    }
    
    /// Data  received or send from at the HELO command.
    public struct HeloArgs: Sendable {
        let client: Client
        
        var rawValue: String {
            return self.client.rawValue
        }

        init (rawValue: UnparsedArgs) throws {
            self.client = try .init(rawValue: rawValue)
        }
        
        public init(client: SMTPCommand.Client) {
            self.client = client
        }
    }
    
    /// Data  received or send from at the EHLO command.
    public struct EhloArgs: Sendable {
        let client: Client
        
        var rawValue: String {
            return self.client.rawValue
        }
        
        init (rawValue: UnparsedArgs) throws {
            self.client = try .init(rawValue: rawValue)
        }
        
        public init(client: SMTPCommand.Client) {
            self.client = client
        }
    }

    /// Data  received or send from  at the MAIL FROM command.
    public struct MailFromArgs: PayloadEncodable, Sendable {
        let reversePath: Address
        var mime: MimeBodyType? = nil
        var size: UInt? = nil
        var envelopId: String? = nil
        var ret: DsnReturn? = nil
        var useSmtpUtf8: Bool = false

        init (rawValue: UnparsedArgs) throws {
            var parts = rawValue.dropCRLF().split(separator: Token.space.rawValue, omittingEmptySubsequences: true).makeIterator()
            
            guard let addressPart = parts.next() else {
                throw ProtocolError.addressNotFound
            }
            
            guard let value = String(bytes: addressPart, encoding: .utf8) else {
                throw ProtocolError.stringIsNil
            }
                        
            self.reversePath = try Address(rawValue: value)
            
            
            for part in parts {
                let end = part.firstIndex(of: Token.equal.rawValue) ?? part.endIndex
                
                guard let value = String(bytes: part[part.startIndex...end], encoding: .utf8) else {
                    throw ProtocolError.stringIsNil
                }

                guard let arg = Args(rawValue: value.uppercased()) else {
                    throw ProtocolError.argumentUnsupported(value)
                }

                switch arg {
                case .mime:
                    if mime != nil {
                        throw ProtocolError.mailArgDuplicated(arg)
                    }
                    guard let value = String(bytes: part[part.index(after: end)...], encoding: .utf8) else {
                        throw ProtocolError.stringIsNil
                    }
                    guard let mime = MimeBodyType(rawValue: value.uppercased()) else {
                        throw ProtocolError.mimeUnsupported(value)
                    }
                    self.mime = mime
                case .size:
                    if size != nil {
                        throw ProtocolError.mailArgDuplicated(arg)
                    }
                    guard let value = String(bytes: part[part.index(after: end)...], encoding: .utf8) else {
                        throw ProtocolError.stringIsNil
                    }
                    self.size = UInt(value)
                case .envelopId:
                    if envelopId != nil {
                        throw ProtocolError.mailArgDuplicated(arg)
                    }
                    guard let value = String(bytes: part[part.index(after: end)...], encoding: .utf8) else {
                        throw ProtocolError.stringIsNil
                    }
                    self.envelopId = value
                case .ret:
                    if ret != nil {
                        throw ProtocolError.mailArgDuplicated(arg)
                    }
                    guard let value = String(bytes: part[part.index(after: end)...], encoding: .utf8) else {
                        throw ProtocolError.stringIsNil
                    }
                    guard let ret = DsnReturn.init(rawValue: value.uppercased()) else {
                        throw ProtocolError.retUnsupported(value)
                    }
                    self.ret = ret
                case .useSmtpUtf8:
                    if useSmtpUtf8 {
                        throw ProtocolError.mailArgDuplicated(arg)
                    }
                    self.useSmtpUtf8 = true
                }
            }
        }
        
        public func encode(into buffer: inout ByteBuffer) throws {
            buffer.writeString(self.reversePath.rawValue)
            
            if let mime = self.mime {
                buffer.writeString(" ")
                buffer.writeString(Args.mime.rawValue)
                buffer.writeString(mime.rawValue)
            }
            
            if let size = self.size {
                buffer.writeString(" ")
                buffer.writeString(Args.size.rawValue)
                buffer.writeString(String(size))
            }
            
            if let envelopId = self.envelopId {
                buffer.writeString(" ")
                buffer.writeString(Args.envelopId.rawValue)
                buffer.writeString(envelopId)
            }
            
            if let ret = self.ret {
                buffer.writeString(" ")
                buffer.writeString(Args.ret.rawValue)
                buffer.writeString(ret.rawValue)
            }
            
            if self.useSmtpUtf8 {
                buffer.writeString(" ")
                buffer.writeString(Args.ret.rawValue)
            }
        }
        
        public enum Args: String, Sendable {
            case mime = "BODY="
            case size = "SIZE="
            case envelopId = "ENVID="
            case ret = "RET="
            case useSmtpUtf8 = "SMTPUTF8"
        }

        public enum MimeBodyType: String, Sendable {
            case sevenBit = "7BIT"
            case eightBitMime = "8BITMIME"
            // TODO: https://datatracker.ietf.org/doc/html/rfc3030
            case binaryMime = "BINARYMIME"
        }
        
        public enum DsnReturn: String, Sendable {
            /// Complete message
            case full = "FULL"
            /// Only the message headers
            case headers = "HDRS"
        }
    }
    
    /// Data  received or send from at the RCPT TO  command.
    public struct RcptToArgs: PayloadEncodable, Sendable {
        let forwardPath: Address
        var originalForwardPath: OriginalRcpt? = nil
        var notifyOn: NotifyOn? = nil

        init(rawValue: UnparsedArgs) throws {
            var parts = rawValue.dropCRLF().split(separator: Token.space.rawValue, omittingEmptySubsequences: true).makeIterator()
            
            guard let addressPart = parts.next() else {
                throw ProtocolError.addressNotFound
            }
            
            guard let value = String(bytes: addressPart, encoding: .utf8) else {
                throw ProtocolError.stringIsNil
            }
                        
            self.forwardPath = try Address(rawValue: value)

            for part in parts {
                let end = part.firstIndex(of: Token.equal.rawValue) ?? part.endIndex
                
                guard let value = String(bytes: part[part.startIndex...end], encoding: .utf8) else {
                    throw ProtocolError.stringIsNil
                }

                guard let arg = Args(rawValue: value.uppercased()) else {
                    throw ProtocolError.argumentUnsupported(value)
                }
                
                switch arg {
                case .originalForwardPath:
                    if originalForwardPath != nil {
                        throw ProtocolError.rcptArgDuplicated(arg)
                    }
                    guard let value = String(bytes: part[part.index(after: end)...], encoding: .utf8) else {
                        throw ProtocolError.stringIsNil
                    }
                    self.originalForwardPath = try .init(rawValue: value)
                case .notifyOn:
                    if notifyOn != nil {
                        throw ProtocolError.rcptArgDuplicated(arg)
                    }
                    guard let value = String(bytes: part[part.index(after: end)...], encoding: .utf8) else {
                        throw ProtocolError.stringIsNil
                    }
                    self.notifyOn = try .init(rawValue: value.uppercased())
                }
            }
        }
        
        public func encode(into buffer: inout ByteBuffer) throws {
            buffer.writeString(self.forwardPath.rawValue)
            
            if let originalForwardPath = self.originalForwardPath {
                buffer.writeString(" ")
                buffer.writeString(Args.originalForwardPath.rawValue)
                buffer.writeString(originalForwardPath.rawValue)
            }
            
            if let notifyOn = self.notifyOn {
                buffer.writeString(" ")
                buffer.writeString(Args.notifyOn.rawValue)
                buffer.writeString(notifyOn.rawValue)
            }
        }
        
        
        public enum Args: String, CaseIterable, Sendable {
            case originalForwardPath = "ORCPT="
            case notifyOn = "NOTIFY="
        }
        
        public struct OriginalRcpt: Sendable {
            let addressType: String
            let mailbox: Address
            
            var rawValue: String {
                return "\(addressType);\(mailbox.rawValue)"
            }
            
            init (rawValue: String) throws {
                let parts = rawValue.split(separator: ";", omittingEmptySubsequences: true)
                if parts.count != 2 {
                    throw ProtocolError.addressUnparsable(rawValue)
                }
                
                self.addressType = String(parts[0])
                self.mailbox = try Address(rawValue: String(parts[1]))
            }
        }
        
        public enum NotifyOn: Sendable {
            /// This message must explicitly not produce a DSN.
            case never
            /// One or more scenarios that should produce a DSN.
            case some(NotifySet)
            
            var rawValue: String {
                switch self {
                case .never: return "NEVER"
                case let .some(notify): return notify.description
                }
            }
            
            init(rawValue: String) throws {
                guard rawValue != NotifyOn.never.rawValue else {
                    self = .never
                    return
                }
                self = try .some(.init(rawValue: rawValue))
            }
        }

        public struct NotifySet: OptionSet, Hashable, CustomStringConvertible, CaseIterable, Sendable {
            public let rawValue: Int
            /// The delivery of the message to the recipient was successful.
            public static let success  = NotifySet(rawValue: 1 << 0)
            /// The delivery of the message to the recipient failed.
            public static let failure  = NotifySet(rawValue: 1 << 1)
            /// The delivery of the message to the recipient has been delayed.
            public static let delay    = NotifySet(rawValue: 1 << 2)
            
            public static var allCases: [NotifySet] = [.success, .failure, .delay]

            public var description: String {
                switch self {
                case .success: return "SUCCESS"
                case .failure: return "FAILURE"
                case .delay: return "DELAY"
                default: return String(NotifySet.allCases.filter({self.contains($0)}).map({$0.description}).joined(separator: ","))
                }
            }

            public init(rawValue: Int) {
                self.rawValue = rawValue
            }

            init(rawValue: String) throws {
                let parts = rawValue.split(separator: ",", omittingEmptySubsequences: true)
                if parts.count == 0 {
                    throw ProtocolError.notifyNotFound
                }
                
                self = NotifySet()

                for part in parts {
                    var found: NotifySet? = nil

                    for option in NotifySet.allCases {
                        if option.description == part {
                            found = option
                            break
                        }
                    }
                    
                    guard let option = found else {
                        throw ProtocolError.notifyUnsupported(.init(part))
                    }
                    
                    if self.contains(option) {
                        throw ProtocolError.notifyArgDuplicated(.init(part))
                    }

                    self.insert(option)
                }
            }
        }
    }
}
