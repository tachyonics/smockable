import SwiftSyntax
import SwiftSyntaxBuilder

enum FunctionImplementationGenerator {
    static func functionDeclaration(
        variablePrefix: String,
        functionDeclaration: FunctionDeclSyntax
    ) throws -> FunctionDeclSyntax {
        var mockFunctionDeclaration = functionDeclaration

        mockFunctionDeclaration.modifiers =
            functionDeclaration.modifiers.removingMutatingKeyword
        mockFunctionDeclaration.modifiers += [DeclModifierSyntax(name: "public")]
        mockFunctionDeclaration.leadingTrivia = .init(pieces: [])

        let parameterList = functionDeclaration.signature.parameterClause.parameters

        mockFunctionDeclaration.body = try getFunctionBody(
            variablePrefix: variablePrefix,
            functionDeclaration: functionDeclaration,
            parameterList: parameterList
        )

        return mockFunctionDeclaration
    }

    static func getFunctionBody(
        variablePrefix: String,
        typePrefix: String = "",
        storagePrefix: String = "",
        functionDeclaration: FunctionDeclSyntax,
        parameterList: FunctionParameterListSyntax
    ) throws -> CodeBlockSyntax {
        try CodeBlockSyntax {
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
                functionDeclaration: functionDeclaration
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

    private static func switchExpression(
        variablePrefix: String,
        functionDeclaration: FunctionDeclSyntax
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
                                    functionSignature: functionDeclaration.signature
                                )
                        )
                    }
                )

                if functionDeclaration.signature.effectSpecifiers?.throwsClause?.throwsSpecifier
                    != nil
                {
                    SwitchCaseSyntax(
                        """
                        case .error(let error):
                            throw error
                        """
                    )
                }

                if (functionDeclaration.signature.returnClause?.type) != nil {
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
