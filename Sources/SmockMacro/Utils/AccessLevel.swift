//===----------------------------------------------------------------------===//
//
// This source file is part of the Smockable open source project
//
// Copyright (c) 2026 the Smockable authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Smockable authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

//
//  AccessLevel.swift
//  SmockMacro
//

import SwiftSyntax

/// Represents the access level for generated mock structures
package enum AccessLevel: String, Sendable, CaseIterable {
    case `public` = "public"
    case `package` = "package"
    case `internal` = "internal"
    case `fileprivate` = "fileprivate"
    case `private` = "private"

    /// The default access level for generated mocks
    package static let `default`: AccessLevel = .public

    /// Returns the appropriate DeclModifierSyntax for this access level
    package var declModifier: DeclModifierSyntax {
        return DeclModifierSyntax(name: TokenSyntax.keyword(keyword))
    }

    /// Returns the keyword token for this access level
    private var keyword: Keyword {
        switch self {
        case .public:
            return .public
        case .package:
            return .package
        case .internal:
            return .internal
        case .fileprivate:
            return .fileprivate
        case .private:
            return .private
        }
    }
}
