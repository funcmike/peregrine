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

public let crlf = ArraySlice([Token.cr.rawValue, Token.lf.rawValue])

internal extension ArraySlice<UInt8>  {
    @inlinable func dropCRLF() -> ArraySlice<UInt8> {
        if self.suffix(crlf.count) == crlf {
            return self.dropLast(crlf.count)
        }
        return self
    }
}
