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

@available(macOS 13.0, *)
public enum ProtocolError: Error, Sendable {
    case incomplete
    case bytesNotFound
    case stringIsNil
    case crlfNotFound
    case addressNotFound
    case commandTooShort(String)
    case commandTooLong
    case commandUnknown(String)
    case addressUnparsable(String)
    case mailArgDuplicated(SMTPCommand.MailFromArgs.Args)
    case rcptArgDuplicated(SMTPCommand.RcptToArgs.Args)
    case notifyArgDuplicated(String)
    case notifyNotFound
    case notifyUnsupported(String)
    case argumentUnsupported(String)
    case mimeUnsupported(String)
    case retUnsupported(String)
    case replySignBad(Character)
    case replyTooLong
    case replyCodesDiffer(first: SMTPReply.Code, current: SMTPReply.Code)
    case replyCodeUnparsable(String)
}
