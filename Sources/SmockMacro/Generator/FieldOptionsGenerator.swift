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
//  FieldOptionsGenerator.swift
//  SmockMacro
//

import SwiftSyntax
import SwiftSyntaxBuilder

enum FieldOptionsGenerator {
    static func fieldOptionsClassDeclaration(
        variablePrefix: String,
        functionSignature: FunctionSignatureSyntax,
        typePrefix: String = "",
        accessLevel: AccessLevel
    ) throws -> ClassDeclSyntax {

        var genericParameterClauseElements: [String] = []
        if functionSignature.effectSpecifiers?.throwsClause != nil {
            genericParameterClauseElements.append("ErrorableFieldOptionsProtocol")
        }

        if functionSignature.returnClause?.type != nil {
            genericParameterClauseElements.append("ReturnableFieldOptionsProtocol")
        } else {
            genericParameterClauseElements.append("VoidReturnableFieldOptionsProtocol")
        }

        return try ClassDeclSyntax(
            modifiers: [accessLevel.declModifier],
            name: "\(raw: typePrefix)\(raw: variablePrefix.capitalizingComponentsFirstLetter())_FieldOptions",
            genericParameterClause: genericParameterClauseElements.count > 0
                ? ": \(raw: genericParameterClauseElements.joined(separator: ", ")) " : nil,
            memberBlockBuilder: {
                try VariableDeclSyntax(
                    """
                    var expectedResponse: \(raw: typePrefix)\(raw: variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse?
                    """
                )

                try VariableDeclSyntax(
                    """
                    var times: Int?
                    """
                )

                try FunctionDeclSyntax(
                    """
                    \(raw: accessLevel.rawValue) func update(using closure: @Sendable @escaping \(ClosureGenerator.closureElements(functionSignature: functionSignature))) {
                      self.expectedResponse = .closure(closure)
                    }
                    """
                )

                if let throwsClause = functionSignature.effectSpecifiers?.throwsClause {
                    let errorType = throwsClause.type.map { "\($0.trimmed)" } ?? "any Error"
                    try FunctionDeclSyntax(
                        """
                        \(raw: accessLevel.rawValue) func update(error: \(raw: errorType)) {
                          self.expectedResponse = .error(error)
                        }
                        """
                    )
                }

                if let returnType = functionSignature.returnClause?.type {
                    try FunctionDeclSyntax(
                        """
                        \(raw: accessLevel.rawValue) func update(value: \(returnType)) {
                          self.expectedResponse = .value(value)
                        }
                        """
                    )
                } else {
                    try FunctionDeclSyntax(
                        """
                        \(raw: accessLevel.rawValue) func success() {
                          self.expectedResponse = .success
                        }
                        """
                    )
                }

                try FunctionDeclSyntax(
                    """
                    \(raw: accessLevel.rawValue) func update(times: Int?) {
                      self.times = times
                    }
                    """
                )
            }
        )
    }
}
