import SwiftSyntax
import SwiftSyntaxBuilder

enum StorageGenerator {
    static func expectationsDeclaration(functionDeclarations: [FunctionDeclSyntax]) throws -> StructDeclSyntax {
        return try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "Expectations",
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: "~Copyable"))
            },
            memberBlockBuilder: {
                try InitializerDeclSyntax("public init() {") {
                    // nothing
                }

                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                    try VariableDeclSyntax(
                        """
                        public var \(raw: variablePrefix): \(raw: variablePrefix.capitalizingComponentsFirstLetter())_Expectations = .init()
                        """)
                }
            })
    }

    static func actorDeclaration(functionDeclarations: [FunctionDeclSyntax]) throws -> ActorDeclSyntax {
        return try ActorDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "fileprivate")],
            name: "Storage",
            memberBlockBuilder: {
                try InitializerDeclSyntax("fileprivate init(expectations: borrowing Expectations) {") {
                    for functionDeclaration in functionDeclarations {
                        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                        ExprSyntax("""
                        self.\(raw: variablePrefix)_ExpectedResponses = expectations.\(raw: variablePrefix).\(raw: variablePrefix)_ExpectedResponses
                        """)
                    }
                }

                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
                    let parameterList = functionDeclaration.signature.parameterClause.parameters

                    try CallsCountGenerator.variableDeclaration(variablePrefix: variablePrefix)
                    try FunctionPropertiesGenerator.expectedResponseVariableDeclaration(variablePrefix: variablePrefix, accessModifier: "")

                    if !parameterList.isEmpty {
                        try ReceivedInvocationsGenerator.variableDeclaration(
                            variablePrefix: variablePrefix,
                            parameterList: parameterList)
                    }

                    FunctionImplementationGenerator.storageDeclaration(
                        variablePrefix: variablePrefix,
                        protocolFunctionDeclaration: functionDeclaration)
                }
            })
    }

    static func variableDeclaration() throws -> VariableDeclSyntax {
        try VariableDeclSyntax(
            """
            private let storage: Storage
            """)
    }
}
