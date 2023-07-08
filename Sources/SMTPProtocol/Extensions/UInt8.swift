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

internal extension UInt8  {
    @inlinable func asciiUppercase() -> UInt8 {
        if self > 96 && self < 123 {
            return self-32
        }
        return self
    }
}
