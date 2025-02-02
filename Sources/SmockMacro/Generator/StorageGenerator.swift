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
    
    static func expectedResponsesDeclaration(functionDeclarations: [FunctionDeclSyntax]) throws -> StructDeclSyntax {
        return try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "fileprivate")],
            name: "ExpectedResponses",
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: "~Copyable"))
            },
            memberBlockBuilder: {
                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                    try FunctionPropertiesGenerator.expectedResponseVariableDeclaration(variablePrefix: variablePrefix,
                                                                                        accessModifier: "", staticName: false)
                }
                
                try InitializerDeclSyntax("init(expectations: borrowing Expectations) {") {
                    for functionDeclaration in functionDeclarations {
                        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                        ExprSyntax("""
                        self.\(raw: variablePrefix) = expectations.\(raw: variablePrefix).expectedResponses
                        """)
                    }
                }
            })
    }
    
    static func callCountDeclaration(functionDeclarations: [FunctionDeclSyntax]) throws -> StructDeclSyntax {
        return try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "fileprivate")],
            name: "CallCounts",
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: "~Copyable"))
            },
            memberBlockBuilder: {
                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                    try CallsCountGenerator.variableDeclaration(variablePrefix: variablePrefix)
                }
            })
    }
    
    static func receivedInvocationsDeclaration(functionDeclarations: [FunctionDeclSyntax]) throws -> StructDeclSyntax {
        return try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "fileprivate")],
            name: "ReceivedInvocations",
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: "~Copyable"))
            },
            memberBlockBuilder: {
                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
                    let parameterList = functionDeclaration.signature.parameterClause.parameters

                    if !parameterList.isEmpty {
                        try ReceivedInvocationsGenerator.variableDeclaration(
                            variablePrefix: variablePrefix,
                            parameterList: parameterList)
                    }
                }
            })
    }

    static func actorDeclaration(functionDeclarations: [FunctionDeclSyntax]) throws -> ActorDeclSyntax {
        return try ActorDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "fileprivate")],
            name: "Storage",
            memberBlockBuilder: {
                try VariableDeclSyntax(
                    """
                    fileprivate var expectedResponses: ExpectedResponses
                    """)
                
                try VariableDeclSyntax(
                    """
                    fileprivate var callCounts: CallCounts = .init()
                    """)
                
                try VariableDeclSyntax(
                    """
                    fileprivate var receivedInvocations: ReceivedInvocations = .init()
                    """)
                
                try InitializerDeclSyntax("init(expectedResponses: consuming ExpectedResponses) {") {
                    ExprSyntax("""
                    self.expectedResponses = expectedResponses
                    """)
                }

                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

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
