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
//  ClosureGenerator.swift
//  SmockMacro
//

import SwiftSyntax
import SwiftSyntaxBuilder

enum ClosureGenerator {
    static func closureElements(
        functionSignature: FunctionSignatureSyntax,
        genericContext: GenericContext = .empty
    )
        -> TupleTypeElementListSyntax
    {
        TupleTypeElementListSyntax {
            TupleTypeElementSyntax(
                type: FunctionTypeSyntax(
                    parameters: TupleTypeElementListSyntax {
                        for parameter in functionSignature.parameterClause.parameters {
                            TupleTypeElementSyntax(
                                type: erasedType(of: parameter.type, genericContext: genericContext)
                            )
                        }
                    },
                    effectSpecifiers: TypeEffectSpecifiersSyntax(
                        asyncSpecifier: functionSignature.effectSpecifiers?.asyncSpecifier,
                        throwsClause: functionSignature.effectSpecifiers?.throwsClause
                    ),
                    returnClause: functionSignature.returnClause.map { clause in
                        ReturnClauseSyntax(
                            type: erasedType(of: clause.type, genericContext: genericContext)
                        )
                    }
                        ?? ReturnClauseSyntax(
                            type: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void")))
                        )
                )
            )
        }
    }

    /// Substitute generic parameter references in `type` with their existential
    /// storage type (case 1) or `any Sendable` (case 2). Concrete types are
    /// returned unchanged.
    ///
    /// `any Sendable` is used for wrapped generic types because the closure must
    /// be `@Sendable` and `Any` doesn't conform to `Sendable`.
    private static func erasedType(
        of type: TypeSyntax,
        genericContext: GenericContext
    ) -> TypeSyntax {
        switch genericContext.classify(type) {
        case .directGeneric(let info):
            return TypeSyntax(IdentifierTypeSyntax(name: .identifier(info.storageType)))
        case .wrappedGeneric:
            return TypeSyntax(IdentifierTypeSyntax(name: .identifier("any Sendable")))
        case .concrete:
            return type
        }
    }

    static func variableDeclaration(
        variablePrefix: String,
        functionSignature: FunctionSignatureSyntax
    ) throws -> VariableDeclSyntax {
        let elements = self.closureElements(functionSignature: functionSignature)

        return try VariableDeclSyntax(
            """
            var \(self.variableIdentifier(variablePrefix: variablePrefix)): (\(elements))?
            """
        )
    }

    static func callExpression(
        baseName: String,
        variablePrefix _: String,
        needsLabels: Bool,
        functionSignature: FunctionSignatureSyntax
    ) -> ExprSyntaxProtocol {
        let calledExpression = DeclReferenceExprSyntax(
            baseName: "\(raw: baseName)"
        )

        var expression: ExprSyntaxProtocol = FunctionCallExprSyntax(
            calledExpression: calledExpression,
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                for parameter in functionSignature.parameterClause.parameters {
                    LabeledExprSyntax(
                        label: needsLabels ? parameter.firstName : nil,
                        colon: needsLabels ? .colonToken() : nil,
                        expression: DeclReferenceExprSyntax(
                            baseName: parameter.secondName ?? parameter.firstName
                        )
                    )
                }
            },
            rightParen: .rightParenToken()
        )

        if functionSignature.effectSpecifiers?.asyncSpecifier != nil {
            expression = AwaitExprSyntax(expression: expression)
        }

        if functionSignature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil {
            expression = TryExprSyntax(expression: expression)
        }

        return expression
    }

    private static func variableIdentifier(variablePrefix: String) -> TokenSyntax {
        TokenSyntax.identifier(variablePrefix + "Closure")
    }
}
