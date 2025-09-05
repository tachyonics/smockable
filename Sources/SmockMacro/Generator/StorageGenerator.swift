import SwiftSyntax
import SwiftSyntaxBuilder

enum StorageGenerator {
    static func expectationsDeclaration(
        functionDeclarations: [FunctionDeclSyntax]
    ) throws
        -> StructDeclSyntax
    {
        return try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "Expectations",
            memberBlockBuilder: {
                try InitializerDeclSyntax("public init() {") {
                    // nothing
                }

                for functionDeclaration in functionDeclarations {
                    let parameterList = functionDeclaration.signature.parameterClause.parameters
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
                    let inputMatcherType =
                        parameterList.count > 0
                        ? "\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher" : "AlwaysMatcher"

                    try VariableDeclSyntax(
                        """
                        var _\(raw: variablePrefix): [(\(raw: variablePrefix.capitalizingComponentsFirstLetter())_FieldOptions, \(raw: inputMatcherType))] = []
                        """
                    )
                }

                for functionDeclaration in functionDeclarations {
                    let methods = try FunctionStyleExpectationsGenerator.generateExpectationMethods(
                        for: functionDeclaration
                    )
                    for method in methods {
                        method
                    }
                }
            }
        )
    }

    static func expectedResponsesDeclaration(
        functionDeclarations: [FunctionDeclSyntax]
    ) throws
        -> StructDeclSyntax
    {
        try StructDeclSyntax(
            name: "ExpectedResponses",
            memberBlockBuilder: {
                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                    try FunctionPropertiesGenerator.expectedResponseVariableDeclaration(
                        variablePrefix: variablePrefix,
                        functionDeclaration: functionDeclaration,
                        accessModifier: "",
                        staticName: false
                    )
                }

                try InitializerDeclSyntax("init(expectations: borrowing Expectations) {") {
                    for functionDeclaration in functionDeclarations {
                        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                        ExprSyntax(
                            """
                            self.\(raw: variablePrefix) = expectations._\(raw: variablePrefix).map { 
                              guard let expectedResponse = $0.expectedResponse else {
                                fatalError("Expectation was added but not set correctly")
                              }

                              return ($0.times, expectedResponse, $1) 
                            }
                            """
                        )
                    }
                }
            }
        )
    }

    static func expectationMatchersDeclaration(
        functionDeclarations: [FunctionDeclSyntax]
    ) throws
        -> StructDeclSyntax
    {
        try StructDeclSyntax(
            name: "ExpectationMatchers",
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(type: IdentifierTypeSyntax(name: "Sendable"))
            },
            memberBlockBuilder: {
                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
                    let parameterList = functionDeclaration.signature.parameterClause.parameters

                    // Only generate matcher storage for functions with parameters
                    if !parameterList.isEmpty {
                        let inputMatcherType =
                            "\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher"
                        try VariableDeclSyntax(
                            """
                            var \(raw: variablePrefix): [\(raw: inputMatcherType)] = []
                            """
                        )
                    }
                }
            }
        )
    }

    static func callCountDeclaration(
        functionDeclarations: [FunctionDeclSyntax]
    ) throws
        -> StructDeclSyntax
    {
        try StructDeclSyntax(
            name: "CallCounts",
            memberBlockBuilder: {
                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                    try CallsCountGenerator.variableDeclaration(variablePrefix: variablePrefix)
                }
            }
        )
    }

    static func receivedInvocationsDeclaration(
        functionDeclarations: [FunctionDeclSyntax]
    ) throws
        -> StructDeclSyntax
    {
        try StructDeclSyntax(
            name: "ReceivedInvocations",
            memberBlockBuilder: {
                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
                    let parameterList = functionDeclaration.signature.parameterClause.parameters

                    if !parameterList.isEmpty {
                        try ReceivedInvocationsGenerator.variableDeclaration(
                            variablePrefix: variablePrefix,
                            parameterList: parameterList
                        )
                    }
                }
            }
        )
    }

    static func actorDeclaration(functionDeclarations: [FunctionDeclSyntax]) throws -> ActorDeclSyntax {
        try ActorDeclSyntax(
            name: "Storage",
            memberBlockBuilder: {
                try VariableDeclSyntax(
                    """
                    var expectedResponses: ExpectedResponses
                    """
                )

                try VariableDeclSyntax(
                    """
                    var callCounts: CallCounts = .init()
                    """
                )

                try VariableDeclSyntax(
                    """
                    var receivedInvocations: ReceivedInvocations = .init()
                    """
                )

                try InitializerDeclSyntax("init(expectedResponses: consuming ExpectedResponses) {") {
                    ExprSyntax(
                        """
                        self.expectedResponses = expectedResponses
                        """
                    )
                }

                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                    try FunctionImplementationGenerator.storageDeclaration(
                        variablePrefix: variablePrefix,
                        protocolFunctionDeclaration: functionDeclaration
                    )
                }
            }
        )
    }

    static func variableDeclaration() throws -> VariableDeclSyntax {
        try VariableDeclSyntax(
            """
            private let storage: Storage
            """
        )
    }
}
