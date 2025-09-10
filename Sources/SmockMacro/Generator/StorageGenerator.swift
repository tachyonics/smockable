import SwiftSyntax
import SwiftSyntaxBuilder

enum StorageGenerator {
    static func expectationsDeclaration(
        functionDeclarations: [FunctionDeclSyntax],
        isComparableProvider: (String) -> Bool
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
                        for: functionDeclaration,
                        isComparableProvider: isComparableProvider
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

                    try ExpectedResponseGenerator.expectedResponseVariableDeclaration(
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

                    try ReceivedInvocationsGenerator.variableDeclaration(
                        variablePrefix: variablePrefix,
                        parameterList: parameterList
                    )
                }
            }
        )
    }

    static func storageDeclaration(functionDeclarations: [FunctionDeclSyntax]) throws -> StructDeclSyntax {
        try StructDeclSyntax(
            name: "Storage",
            memberBlockBuilder: {
                try VariableDeclSyntax(
                    """
                    var combinedCallCount: UInt32 = 0
                    """
                )

                try VariableDeclSyntax(
                    """
                    var expectedResponses: ExpectedResponses
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
            }
        )
    }

    static func stateDeclaration(functionDeclarations: [FunctionDeclSyntax]) throws -> ClassDeclSyntax {
        try ClassDeclSyntax(
            name: "State",
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: "@unchecked Sendable")
                )
            },
            memberBlockBuilder: {
                try VariableDeclSyntax(
                    """
                    let mutex: Mutex<Storage>
                    """
                )

                try InitializerDeclSyntax("init(expectedResponses: consuming ExpectedResponses) {") {
                    ExprSyntax(
                        """
                        self.mutex = Mutex(.init(expectedResponses: expectedResponses))
                        """
                    )
                }
            }
        )
    }

    static func variableDeclaration() throws -> VariableDeclSyntax {
        try VariableDeclSyntax(
            """
            private let state: State
            """
        )
    }
}
