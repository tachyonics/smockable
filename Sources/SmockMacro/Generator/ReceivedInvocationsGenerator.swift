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
//  ReceivedInvocationsGenerator.swift
//  SmockMacro
//

import SwiftSyntax
import SwiftSyntaxBuilder

/// The `ReceivedInvocationsGenerator` is designed to generate a representation of a Swift
/// variable declaration to keep track of the arguments passed to a certain function each time it is called.
///
/// The resulting variable is an array, where each element either corresponds to a single function parameter
/// or is a tuple of all parameters if the function has multiple parameters. The variable's name is constructed
/// by appending the word "ReceivedInvocations" to the `variablePrefix` parameter.
///
/// The factory also generates an expression that appends a tuple of parameter identifiers to the variable
/// each time the function is invoked.
///
/// The following code:
/// ```swift
/// var fooReceivedInvocations: [String] = []
///
/// fooReceivedInvocations.append(text)
/// ```
/// would be generated for a function like this:
/// ```swift
/// func foo(text: String)
/// ```
/// and an argument `variablePrefix` equal to `foo`.
///
/// For a function with multiple parameters, the factory generates an array of tuples:
/// ```swift
/// var barReceivedInvocations: [(text: String, count: Int)] = []
///
/// barReceivedInvocations.append((text, count))
/// ```
/// for a function like this:
/// ```swift
/// func bar(text: String, count: Int)
/// ```
/// and an argument `variablePrefix` equal to `bar`.
///
/// - Note: While the `ReceivedInvocationsGenerator` keeps track of every individual invocation of a function
///         and the arguments passed in each invocation, the `ReceivedArgumentsGenerator` only keeps track
///         of the arguments received in the last invocation of the function. If you want to test a function where the
///         order and number of invocations matter, use `ReceivedInvocationsGenerator`. If you only care
///         about the arguments in the last invocation, use `ReceivedArgumentsGenerator`.
enum ReceivedInvocationsGenerator {
    static func variableDeclaration(
        variablePrefix: String,
        parameterList: FunctionParameterListSyntax
    ) throws -> VariableDeclSyntax {
        let elementType = self.arrayElementType(parameterList: parameterList)

        return try VariableDeclSyntax(
            """
            var \(raw: variablePrefix): [\(elementType)] = []
            """
        )
    }

    static func arrayElementType(parameterList: FunctionParameterListSyntax) -> TypeSyntaxProtocol {
        let tupleElements = TupleTypeElementListSyntax {
            TupleTypeElementSyntax(
                firstName: TokenSyntax.identifier("__localCallIndex"),
                colon: .colonToken(),
                type: IdentifierTypeSyntax(name: "Int")
            )

            TupleTypeElementSyntax(
                firstName: TokenSyntax.identifier("__globalCallIndex"),
                colon: .colonToken(),
                type: IdentifierTypeSyntax(name: "Int")
            )

            for parameter in parameterList {
                TupleTypeElementSyntax(
                    firstName: parameter.secondName ?? parameter.firstName,
                    colon: .colonToken(),
                    type: {
                        if let attributedType = parameter.type.as(AttributedTypeSyntax.self) {
                            attributedType.baseType
                        } else {
                            parameter.type
                        }
                    }()
                )
            }
        }
        return TupleTypeSyntax(elements: tupleElements)
    }

    static func appendValueToVariableExpression(
        variablePrefix: String,
        storagePrefix: String,
        parameterList: FunctionParameterListSyntax
    ) -> ExprSyntax {
        let identifier = self.variableIdentifier()
        let argument = self.appendArgumentExpression(parameterList: parameterList)

        return ExprSyntax(
            """
            storage.\(identifier).\(raw: storagePrefix)\(raw: variablePrefix).append(\(argument))
            """
        )
    }

    private static func appendArgumentExpression(
        parameterList: FunctionParameterListSyntax
    )
        -> LabeledExprListSyntax
    {
        let tupleArgument = TupleExprSyntax(
            elements: LabeledExprListSyntax(
                itemsBuilder: {
                    LabeledExprSyntax(
                        expression: DeclReferenceExprSyntax(
                            baseName: TokenSyntax.identifier("storage.combinedCallCount")
                        )
                    )

                    LabeledExprSyntax(
                        expression: DeclReferenceExprSyntax(
                            baseName: TokenSyntax.identifier("globalCallIndex")
                        )
                    )

                    for parameter in parameterList {
                        LabeledExprSyntax(
                            expression: DeclReferenceExprSyntax(
                                baseName: parameter.secondName ?? parameter.firstName
                            )
                        )
                    }
                })
        )

        return LabeledExprListSyntax {
            LabeledExprSyntax(expression: tupleArgument)
        }
    }

    private static func variableIdentifier() -> TokenSyntax {
        TokenSyntax.identifier("receivedInvocations")
    }
}
