import SwiftSyntax
import SwiftSyntaxBuilder

enum FunctionImplementationGenerator {
    static func storageDeclaration(
        variablePrefix: String,
        protocolFunctionDeclaration: FunctionDeclSyntax
    ) throws -> FunctionDeclSyntax {
        var mockFunctionDeclaration = protocolFunctionDeclaration

        mockFunctionDeclaration.modifiers =
            protocolFunctionDeclaration.modifiers.removingMutatingKeyword
        mockFunctionDeclaration.modifiers += [DeclModifierSyntax(name: "public")]
        mockFunctionDeclaration.leadingTrivia = .init(pieces: [])

        let parameterList = protocolFunctionDeclaration.signature.parameterClause.parameters

        mockFunctionDeclaration.body = try CodeBlockSyntax {
            let withLockCall = try getWithLockCall(variablePrefix: variablePrefix, parameterList: parameterList)

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
                protocolFunctionDeclaration: protocolFunctionDeclaration
            )
        }

        return mockFunctionDeclaration
    }

    private static func getLockProtectedStatements(
        variablePrefix: String,
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
                item: .expr(
                    ReceivedInvocationsGenerator.appendValueToVariableExpression(
                        variablePrefix: variablePrefix,
                        parameterList: parameterList
                    )
                )
            ),
            CodeBlockItemSyntax(
                item: .decl(
                    DeclSyntax(
                        try VariableDeclSyntax(
                            """
                            var responseProvider: \(raw: variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse?
                            """
                        )
                    )
                )
            ),
            CodeBlockItemSyntax(
                item: .stmt(
                    StmtSyntax(
                        try ForStmtSyntax(
                            "for (index, expectedResponse) in storage.expectedResponses.\(raw: variablePrefix).enumerated()"
                        ) {
                            ExprSyntax(
                                """
                                if expectedResponse.2.matches(\(raw: matcherCall)) {
                                  if expectedResponse.0 == 1 {
                                    storage.expectedResponses.\(raw: variablePrefix).remove(at: index)
                                  } else if let currentCount = expectedResponse.0 {
                                    storage.expectedResponses.\(raw: variablePrefix)[index] = (currentCount - 1, expectedResponse.1, expectedResponse.2)
                                  }
                                  
                                  responseProvider = expectedResponse.1
                                  break
                                }
                                """
                            )
                        }
                    )
                )
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

    private static func getWithLockCall(
        variablePrefix: String,
        parameterList: FunctionParameterListSyntax
    ) throws -> FunctionCallExprSyntax {
        let lockProtectedStatements = try getLockProtectedStatements(
            variablePrefix: variablePrefix,
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

    private static func switchExpression(
        variablePrefix: String,
        protocolFunctionDeclaration: FunctionDeclSyntax
    ) -> SwitchExprSyntax {
        SwitchExprSyntax(
            subject: ExprSyntax(stringLiteral: "responseProvider"),
            casesBuilder: {
                SwitchCaseSyntax(
                    SyntaxNodeString("case .closure(let closure):"),
                    statementsBuilder: {
                        ReturnStmtSyntax(
                            expression:
                                ClosureGenerator.callExpression(
                                    baseName: "closure",
                                    variablePrefix: variablePrefix,
                                    needsLabels: false,
                                    functionSignature: protocolFunctionDeclaration.signature
                                )
                        )
                    }
                )

                if protocolFunctionDeclaration.signature.effectSpecifiers?.throwsClause?.throwsSpecifier
                    != nil
                {
                    SwitchCaseSyntax(
                        """
                        case .error(let error):
                            throw error
                        """
                    )
                }

                if (protocolFunctionDeclaration.signature.returnClause?.type) != nil {
                    SwitchCaseSyntax(
                        """
                        case .value(let value):
                            return value
                        """
                    )
                } else {
                    SwitchCaseSyntax(
                        """
                        case .success:
                            return
                        """
                    )
                }

                SwitchCaseSyntax(
                    """
                    case nil:
                        fatalError("\(raw: variablePrefix) without a matching expectation.")
                    """
                )
            }
        )
    }
}

extension DeclModifierListSyntax {
    fileprivate var removingMutatingKeyword: Self {
        filter { $0.name.text != TokenSyntax.keyword(.mutating).text }
    }
}
