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
//  FunctionImplementationGenerator.swift
//  SmockMacro
//

import SwiftSyntax
import SwiftSyntaxBuilder

enum FunctionImplementationGenerator {
    static func functionDeclaration(
        variablePrefix: String,
        accessLevel: AccessLevel,
        function: MockableFunction
    ) throws -> FunctionDeclSyntax {
        var mockFunctionDeclaration = function.declaration

        mockFunctionDeclaration.modifiers =
            function.declaration.modifiers.removingMutatingKeyword
        mockFunctionDeclaration.modifiers += [accessLevel.declModifier]
        mockFunctionDeclaration.leadingTrivia = .init(pieces: [])

        let parameterList = function.declaration.signature.parameterClause.parameters

        mockFunctionDeclaration.body = try getFunctionBody(
            variablePrefix: variablePrefix,
            parameterList: parameterList,
            function: function
        )

        return mockFunctionDeclaration
    }

    static func getFunctionBody(
        variablePrefix: String,
        typePrefix: String = "",
        storagePrefix: String = "",
        parameterList: FunctionParameterListSyntax,
        function: MockableFunction
    ) throws -> CodeBlockSyntax {
        var methodInterpolationParameters: [String] = []
        for parameter in parameterList {
            let paramName = (parameter.secondName?.text ?? parameter.firstName.text).trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let paramNameForSignature: String
            if let secondName = parameter.secondName?.text {
                paramNameForSignature = "\(parameter.firstName.text) \(secondName)"
            } else {
                paramNameForSignature = parameter.firstName.text
            }
            let paramType = parameter.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let isOptional = paramType.hasSuffix("?")

            if paramType == "String" {
                methodInterpolationParameters.append(
                    """
                    \(paramNameForSignature): \\"\\(\(paramName))\\"
                    """
                )
            } else if paramType == "String?" {
                methodInterpolationParameters.append(
                    """
                    \(paramNameForSignature): \\(\(paramName).map {"\\"\\($0)\\""} ?? "nil")
                    """
                )
            } else if isOptional {
                methodInterpolationParameters.append(
                    """
                    \(paramNameForSignature): \\(\(paramName).map {"\\($0)"} ?? "nil")
                    """
                )
            } else {
                methodInterpolationParameters.append("\(paramNameForSignature): \\(\(paramName))")
            }
        }
        let methodInterpolation = methodInterpolationParameters.joined(separator: ", ")
        let functionName = function.declaration.name.text
        let functionInterpolationSignature = "\(functionName)(\(methodInterpolation))"

        return try CodeBlockSyntax {
            let withLockCall = try getWithLockCall(
                variablePrefix: variablePrefix,
                typePrefix: typePrefix,
                storagePrefix: storagePrefix,
                parameterList: parameterList
            )

            VariableDeclSyntax(
                bindingSpecifier: .keyword(.let),
                bindings: PatternBindingListSyntax([
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(identifier: .identifier("responseProvider")),
                        initializer: InitializerClauseSyntax(
                            equal: .equalToken(),
                            value: ExprSyntax(withLockCall)
                        )
                    )
                ])
            )

            self.switchExpression(
                variablePrefix: variablePrefix,
                functionInterpolationSignature: functionInterpolationSignature,
                function: function
            )
        }
    }

    private static func getLockProtectedStatements(
        variablePrefix: String,
        typePrefix: String,
        storagePrefix: String,
        parameterList: FunctionParameterListSyntax
    ) throws -> CodeBlockItemListSyntax {
        let parameters = Array(parameterList)
        let matcherCall = AllParameterSequenceGenerator.generateMatcherCall(parameters: parameters)

        return CodeBlockItemListSyntax([
            CodeBlockItemSyntax(
                item: .expr(
                    ExprSyntax(
                        """
                        storage.combinedCallCount += 1
                        """
                    )
                )
            ),
            CodeBlockItemSyntax(
                item: .decl(
                    DeclSyntax(
                        try VariableDeclSyntax(
                            """
                            let globalCallIndex = smockableGlobalCallIndex.getCurrentIndex(mockIdentifier: self.state.mockIdentifier, 
                                                                                           localCallIndex: storage.combinedCallCount)
                            """
                        )
                    )
                )
            ),
            CodeBlockItemSyntax(
                item: .expr(
                    ReceivedInvocationsGenerator.appendValueToVariableExpression(
                        variablePrefix: variablePrefix,
                        storagePrefix: storagePrefix,
                        parameterList: parameterList
                    )
                )
            ),
            CodeBlockItemSyntax(
                item: .decl(
                    DeclSyntax(
                        try VariableDeclSyntax(
                            """
                            var responseProvider: \(raw: typePrefix)\(raw: variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse?
                            """
                        )
                    )
                )
            ),
            try getExpectedResponsesForStatement(
                matcherCall: matcherCall,
                variablePrefix: variablePrefix,
                storagePrefix: storagePrefix
            ),
            CodeBlockItemSyntax(
                item: .stmt(
                    StmtSyntax(
                        ReturnStmtSyntax(
                            expression: DeclReferenceExprSyntax(baseName: .identifier("responseProvider"))
                        )
                    )
                )
            ),
        ])
    }

    private static func getExpectedResponsesForStatement(
        matcherCall: String,
        variablePrefix: String,
        storagePrefix: String
    ) throws -> CodeBlockItemSyntax {
        CodeBlockItemSyntax(
            item: .stmt(
                StmtSyntax(
                    try ForStmtSyntax(
                        "for (index, expectedResponse) in storage.expectedResponses.\(raw: storagePrefix)\(raw: variablePrefix).enumerated()"
                    ) {
                        ExprSyntax(
                            """
                            if expectedResponse.2.matches(\(raw: matcherCall)) {
                              if expectedResponse.0 == 1 {
                                storage.expectedResponses.\(raw: storagePrefix)\(raw: variablePrefix).remove(at: index)
                              } else if let currentCount = expectedResponse.0 {
                                storage.expectedResponses.\(raw: storagePrefix)\(raw: variablePrefix)[index] = (currentCount - 1, expectedResponse.1, expectedResponse.2)
                              }
                              
                              responseProvider = expectedResponse.1
                              break
                            }
                            """
                        )
                    }
                )
            )
        )
    }

    private static func getWithLockCall(
        variablePrefix: String,
        typePrefix: String,
        storagePrefix: String,
        parameterList: FunctionParameterListSyntax
    ) throws -> FunctionCallExprSyntax {
        let lockProtectedStatements = try getLockProtectedStatements(
            variablePrefix: variablePrefix,
            typePrefix: typePrefix,
            storagePrefix: storagePrefix,
            parameterList: parameterList
        )

        let lockClosure = ClosureExprSyntax(
            signature: ClosureSignatureSyntax(
                parameterClause: .simpleInput(
                    ClosureShorthandParameterListSyntax([
                        ClosureShorthandParameterSyntax(name: .identifier("storage"))
                    ])
                )
            ),
            statements: lockProtectedStatements
        )

        return FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("self.state.mutex")),
                declName: DeclReferenceExprSyntax(baseName: .identifier("withLock"))
            ),
            arguments: LabeledExprListSyntax([
                LabeledExprSyntax(expression: ExprSyntax(lockClosure))
            ])
        )
    }

    /// Information about how the mock function's return type interacts with generic
    /// substitution. When the declared return type is generic, the stored closure and
    /// `.value` case return the existential storage type and need a force-cast back to
    /// the declared generic type.
    private struct ReturnCastInfo {
        let needsCast: Bool
        let returnTypeText: String

        static func compute(function: MockableFunction) -> ReturnCastInfo {
            guard let returnType = function.declaration.signature.returnClause?.type else {
                return .init(needsCast: false, returnTypeText: "")
            }
            switch function.classify(returnType) {
            case .directGeneric, .wrappedGeneric:
                return .init(
                    needsCast: true,
                    returnTypeText: returnType.description.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            case .concrete:
                return .init(needsCast: false, returnTypeText: "")
            }
        }
    }

    private static func switchExpression(
        variablePrefix: String,
        functionInterpolationSignature: String,
        function: MockableFunction
    ) -> SwitchExprSyntax {
        let returnCast = ReturnCastInfo.compute(function: function)

        return SwitchExprSyntax(
            subject: ExprSyntax(stringLiteral: "responseProvider"),
            casesBuilder: {
                closureCase(
                    variablePrefix: variablePrefix,
                    function: function,
                    returnCast: returnCast
                )

                if function.declaration.signature.effectSpecifiers?.throwsClause?.throwsSpecifier
                    != nil
                {
                    SwitchCaseSyntax(
                        """
                        case .error(let error):
                            throw error
                        """
                    )
                }

                returnOrSuccessCase(
                    function: function,
                    returnCast: returnCast
                )

                SwitchCaseSyntax(
                    """
                    case nil:
                        fatalError("\(raw: functionInterpolationSignature) called without a matching expectation.")
                    """
                )
            }
        )
    }

    private static func closureCase(
        variablePrefix: String,
        function: MockableFunction,
        returnCast: ReturnCastInfo
    ) -> SwitchCaseSyntax {
        SwitchCaseSyntax(
            SyntaxNodeString("case .closure(let closure):"),
            statementsBuilder: {
                if returnCast.needsCast {
                    // Closure returns the storage type; cast to the declared generic return type.
                    CodeBlockItemSyntax(
                        """
                        return await closure(\(raw: closureCallArgs(function: function))) as! \(raw: returnCast.returnTypeText)
                        """
                    )
                } else {
                    ReturnStmtSyntax(
                        expression:
                            ClosureGenerator.callExpression(
                                baseName: "closure",
                                variablePrefix: variablePrefix,
                                needsLabels: false,
                                function: function
                            )
                    )
                }
            }
        )
    }

    private static func returnOrSuccessCase(
        function: MockableFunction,
        returnCast: ReturnCastInfo
    ) -> SwitchCaseSyntax {
        if function.declaration.signature.returnClause?.type != nil {
            if returnCast.needsCast {
                return SwitchCaseSyntax(
                    """
                    case .value(let value):
                        return value as! \(raw: returnCast.returnTypeText)
                    """
                )
            } else {
                return SwitchCaseSyntax(
                    """
                    case .value(let value):
                        return value
                    """
                )
            }
        } else {
            return SwitchCaseSyntax(
                """
                case .success:
                    return
                """
            )
        }
    }

    /// Build the argument list for calling the stored closure for a function with
    /// a generic return type. We can't use ClosureGenerator.callExpression because
    /// the result needs to be wrapped in `await` and `as!`.
    private static func closureCallArgs(function: MockableFunction) -> String {
        function.declaration.signature.parameterClause.parameters.map { parameter in
            (parameter.secondName ?? parameter.firstName).text
        }.joined(separator: ", ")
    }
}

extension DeclModifierListSyntax {
    fileprivate var removingMutatingKeyword: Self {
        filter { $0.name.text != TokenSyntax.keyword(.mutating).text }
    }
}
