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
//  VariablePrefixGenerator.swift
//  SmockMacro
//

import SwiftSyntax
import SwiftSyntaxBuilder

/// The `VariablePrefixGenerator` struct is responsible for creating a unique textual representation
/// for a given function declaration. This representation can be used as a prefix when naming variables
/// associated with that function.
///
/// The Generator constructs the representation by combining the function name with the first names of its parameters.
///
/// For example, given the function declaration:
/// ```swift
/// func display(text: String, color: Color)
/// ```
/// the `VariablePrefixGenerator` generates the following text:
/// ```
/// displayTextColor
/// ```
/// It will capitalize the first letter of each parameter name and append it to the function name.
/// Please note that if a parameter is underscored (anonymous), it's ignored.
enum VariablePrefixGenerator {
    static func text(for functionDeclaration: FunctionDeclSyntax) -> String {
        var parts: [String] = [functionDeclaration.name.text]

        let parameterList = functionDeclaration.signature.parameterClause.parameters

        let parameters =
            parameterList
            .map(\.firstName.text)
            .filter { $0 != "_" }

        parts.append(contentsOf: parameters)

        return parts.joined(separator: "_")
    }
}
