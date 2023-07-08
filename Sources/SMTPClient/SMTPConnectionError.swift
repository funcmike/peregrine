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

import SMTPProtocol

@available(macOS 13.0, *)
public enum SMTPConnectionError: Error, Sendable {
    case connectionClosed
    case connectionClose(broker: Error? = nil, connection: Error? = nil)
    case invalidResponse(SMTPResponse)
}
