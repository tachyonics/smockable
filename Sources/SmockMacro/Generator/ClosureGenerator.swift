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
        function: MockableFunction
    )
        -> TupleTypeElementListSyntax
    {
        let signature = function.declaration.signature
        return TupleTypeElementListSyntax {
            TupleTypeElementSyntax(
                type: FunctionTypeSyntax(
                    parameters: TupleTypeElementListSyntax {
                        for parameter in signature.parameterClause.parameters {
                            TupleTypeElementSyntax(
                                type: erasedType(of: parameter.type, function: function)
                            )
                        }
                    },
                    effectSpecifiers: TypeEffectSpecifiersSyntax(
                        asyncSpecifier: signature.effectSpecifiers?.asyncSpecifier,
                        throwsClause: signature.effectSpecifiers?.throwsClause
                    ),
                    returnClause: signature.returnClause.map { clause in
                        ReturnClauseSyntax(
                            type: erasedType(of: clause.type, function: function)
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
        function: MockableFunction
    ) -> TypeSyntax {
        switch function.classify(type) {
        case .directGeneric(let info):
            return TypeSyntax(IdentifierTypeSyntax(name: .identifier(info.storageType)))
        case .wrappedGeneric:
            return TypeSyntax(IdentifierTypeSyntax(name: .identifier("any Sendable")))
        case .concrete:
            return type
        }
    }


    static func callExpression(
        baseName: String,
        variablePrefix _: String,
        needsLabels: Bool,
        function: MockableFunction
    ) -> ExprSyntaxProtocol {
        let signature = function.declaration.signature
        let calledExpression = DeclReferenceExprSyntax(
            baseName: "\(raw: baseName)"
        )

        var expression: ExprSyntaxProtocol = FunctionCallExprSyntax(
            calledExpression: calledExpression,
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                for parameter in signature.parameterClause.parameters {
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

        if signature.effectSpecifiers?.asyncSpecifier != nil {
            expression = AwaitExprSyntax(expression: expression)
        }

        if signature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil {
            expression = TryExprSyntax(expression: expression)
        }

        return expression
    }
}
