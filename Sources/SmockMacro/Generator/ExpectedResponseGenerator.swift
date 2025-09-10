import SwiftSyntax
import SwiftSyntaxBuilder

enum ExpectedResponseGenerator {
    static func expectedResponseEnumDeclaration(
        variablePrefix: String,
        functionSignature: FunctionSignatureSyntax
    ) throws -> EnumDeclSyntax {
        try EnumDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "\(raw: variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse",
            genericParameterClause: ": Sendable",
            memberBlockBuilder: {
                try EnumCaseDeclSyntax(
                    """
                    case closure(@Sendable \(ClosureGenerator.closureElements(functionSignature: functionSignature)))
                    """
                )

                if functionSignature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil {
                    try EnumCaseDeclSyntax(
                        """
                        case error(Swift.Error)
                        """
                    )
                }

                if let returnType = functionSignature.returnClause?.type {
                    try EnumCaseDeclSyntax(
                        """
                        case value(\(returnType))
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
        variablePrefix: String,
        functionDeclaration: FunctionDeclSyntax,
        accessModifier: String,
        staticName: Bool
    ) throws -> VariableDeclSyntax {
        let expectedResponseType =
            "\(variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse"
        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
        let parameterList = functionDeclaration.signature.parameterClause.parameters
        let inputMatcherType =
            parameterList.count > 0
            ? "\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher" : "AlwaysMatcher"

        return try VariableDeclSyntax(
            """
            \(raw: accessModifier)var \(raw: staticName ? "expectedResponses" : variablePrefix): [(Int?,\(raw: expectedResponseType),\(raw: inputMatcherType))] = []
            """
        )
    }
}
