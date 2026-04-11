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
//  ExpectedResponseGenerator.swift
//  SmockMacro
//

import SwiftSyntax
import SwiftSyntaxBuilder

enum ExpectedResponseGenerator {
    /// Generate an expected response enum for a specific function.
    ///
    /// The generated `_ExpectedResponse` enum is intentionally `internal` regardless of
    /// the protocol's access level. It's an implementation detail held inside
    /// `_FieldOptions` and the storage tuples; users never reference it directly.
    /// Keeping it internal preserves freedom to refactor the response storage shape.
    static func expectedResponseEnumDeclaration(
        typePrefix: String = "",
        variablePrefix: String,
        accessLevel: AccessLevel,
        function: MockableFunction
    ) throws -> EnumDeclSyntax {
        let signature = function.declaration.signature
        return try EnumDeclSyntax(
            name: "\(raw: typePrefix)\(raw: variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse",
            genericParameterClause: ": Sendable",
            memberBlockBuilder: {
                try EnumCaseDeclSyntax(
                    """
                    case closure(@Sendable \(ClosureGenerator.closureElements(function: function)))
                    """
                )

                if let throwsClause = signature.effectSpecifiers?.throwsClause {
                    let errorType = throwsClause.type.map { "\($0.trimmed)" } ?? "any Error"
                    try EnumCaseDeclSyntax(
                        """
                        case error(\(raw: errorType))
                        """
                    )
                }

                if let returnType = signature.returnClause?.type {
                    let valueType = function.erasedTypeString(for: returnType)
                    try EnumCaseDeclSyntax(
                        """
                        case value(\(raw: valueType))
                        """
                    )
                } else {
                    try EnumCaseDeclSyntax(
                        """
                        case success
                        """
                    )
                }
            }
        )
    }

    static func expectedResponseVariableDeclaration(
        typePrefix: String,
        variablePrefix: String,
        functionDeclaration: FunctionDeclSyntax,
        accessModifier: String,
        staticName: Bool
    ) throws -> VariableDeclSyntax {
        let expectedResponseType =
            "\(typePrefix)\(variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse"
        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
        let parameterList = functionDeclaration.signature.parameterClause.parameters
        let inputMatcherType =
            parameterList.count > 0
            ? "\(typePrefix)\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher" : "AlwaysMatcher"

        return try VariableDeclSyntax(
            """
            \(raw: accessModifier)var \(raw: staticName ? "expectedResponses" : variablePrefix): [(Int?,\(raw: expectedResponseType),\(raw: inputMatcherType))] = []
            """
        )
    }
}
