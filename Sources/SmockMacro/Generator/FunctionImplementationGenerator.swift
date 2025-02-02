import SwiftSyntax
import SwiftSyntaxBuilder

enum FunctionImplementationGenerator {
    static func declaration(variablePrefix: String,
                            accessModifier: String?,
                            protocolFunctionDeclaration: FunctionDeclSyntax) -> FunctionDeclSyntax {
        var mockFunctionDeclaration = protocolFunctionDeclaration

        mockFunctionDeclaration.modifiers = protocolFunctionDeclaration.modifiers.removingMutatingKeyword

        if let accessModifier {
            mockFunctionDeclaration.modifiers += [DeclModifierSyntax(name: "\(raw: accessModifier)")]
        }

        mockFunctionDeclaration.body = CodeBlockSyntax {
            ClosureGenerator.callExpression(
                baseName: "self.storage.\(protocolFunctionDeclaration.name.text)",
                variablePrefix: variablePrefix, needsLabels: true,
                functionSignature: protocolFunctionDeclaration.signature)
        }

        return mockFunctionDeclaration
    }

    static func storageDeclaration(variablePrefix: String,
                                   protocolFunctionDeclaration: FunctionDeclSyntax) -> FunctionDeclSyntax {
        var mockFunctionDeclaration = protocolFunctionDeclaration

        mockFunctionDeclaration.modifiers = protocolFunctionDeclaration.modifiers.removingMutatingKeyword

        mockFunctionDeclaration.body = CodeBlockSyntax {
            let parameterList = protocolFunctionDeclaration.signature.parameterClause.parameters

            CallsCountGenerator.incrementVariableExpression(variablePrefix: variablePrefix)

            if !parameterList.isEmpty {
                ReceivedInvocationsGenerator.appendValueToVariableExpression(
                    variablePrefix: variablePrefix,
                    parameterList: parameterList)
            }

            IfExprSyntax(
                conditions: ConditionElementListSyntax {
                    ConditionElementSyntax(
                        condition: .expression(
                            ExprSyntax("""
                            let first = self.expectedResponses.\(raw: variablePrefix).first 
                            """)))
                },
                elseKeyword: .keyword(.else),
                elseBody: .codeBlock(
                    CodeBlockSyntax {
                        ExprSyntax("""
                        fatalError("\(raw: variablePrefix) without a provided return value.")
                        """)
                    }),
                bodyBuilder: {
                    ExprSyntax("""
                    if first.0 == 1 {
                      self.expectedResponses.\(raw: variablePrefix) = Array(self.expectedResponses.\(raw: variablePrefix).dropFirst())
                    } else if let currentCount = first.0 {
                      self.expectedResponses.\(raw: variablePrefix) = [(currentCount - 1, first.1)] + Array(self.expectedResponses.\(raw: variablePrefix).dropFirst())
                    }
                    """)
                    self.switchExpression(variablePrefix: variablePrefix, protocolFunctionDeclaration: protocolFunctionDeclaration)
                })
        }

        return mockFunctionDeclaration
    }

    private static func switchExpression(variablePrefix: String,
                                         protocolFunctionDeclaration: FunctionDeclSyntax) -> SwitchExprSyntax {
        SwitchExprSyntax(subject: ExprSyntax(stringLiteral: "first.1"),
                         casesBuilder: {
                             SwitchCaseSyntax(SyntaxNodeString("case .closure(let closure):"), statementsBuilder: {
                                 ReturnStmtSyntax(expression:
                                     ClosureGenerator.callExpression(baseName: "closure", variablePrefix: variablePrefix,
                                                                     needsLabels: false, functionSignature: protocolFunctionDeclaration.signature))
                             })

                             if protocolFunctionDeclaration.signature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil {
                                 SwitchCaseSyntax("""
                                 case .error(let error):
                                     throw error
                                 """)
                             }

                             if (protocolFunctionDeclaration.signature.returnClause?.type) != nil {
                                 SwitchCaseSyntax("""
                                 case .value(let value):
                                     return value
                                 """)
                             }
                         })
    }
}

private extension DeclModifierListSyntax {
    var removingMutatingKeyword: Self {
        filter { $0.name.text != TokenSyntax.keyword(.mutating).text }
    }
}
