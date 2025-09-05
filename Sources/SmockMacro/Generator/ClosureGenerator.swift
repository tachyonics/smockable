import SwiftSyntax
import SwiftSyntaxBuilder

enum ClosureGenerator {
    static func closureElements(
        functionSignature: FunctionSignatureSyntax
    )
        -> TupleTypeElementListSyntax
    {
        TupleTypeElementListSyntax {
            TupleTypeElementSyntax(
                type: FunctionTypeSyntax(
                    parameters: TupleTypeElementListSyntax {
                        for parameter in functionSignature.parameterClause.parameters {
                            TupleTypeElementSyntax(type: parameter.type)
                        }
                    },
                    effectSpecifiers: TypeEffectSpecifiersSyntax(
                        asyncSpecifier: functionSignature.effectSpecifiers?.asyncSpecifier,
                        throwsClause: functionSignature.effectSpecifiers?.throwsClause
                    ),
                    returnClause: functionSignature.returnClause
                        ?? ReturnClauseSyntax(
                            type: IdentifierTypeSyntax(
                                name: .identifier("Void")
                            )
                        )
                )
            )
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
