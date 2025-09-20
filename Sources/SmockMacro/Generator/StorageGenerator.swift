import SmockableUtils
import SwiftSyntax
import SwiftSyntaxBuilder

enum StorageGenerator {
    static func expectationsDeclaration(
        functionDeclarations: [FunctionDeclSyntax],
        typePrefix: String = "",
        propertyDeclarations: [PropertyDeclaration] = [],
        typeConformanceProvider: (String) -> TypeConformance,
        accessLevel: AccessLevel
    ) throws
        -> StructDeclSyntax
    {
        return try StructDeclSyntax(
            modifiers: [accessLevel.declModifier],
            name: "\(raw: typePrefix)Expectations",
            memberBlockBuilder: {
                try InitializerDeclSyntax("\(raw: accessLevel.rawValue) init() {") {
                    // nothing
                }

                for propertyDeclaration in propertyDeclarations {
                    try VariableDeclSyntax(
                        """
                        \(raw: accessLevel.rawValue) var \(raw: propertyDeclaration.name): \(raw: propertyDeclaration.typePrefix)Expectations = .init()
                        """
                    )
                }

                for functionDeclaration in functionDeclarations {
                    let parameterList = functionDeclaration.signature.parameterClause.parameters
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
                    let inputMatcherType =
                        parameterList.count > 0
                        ? "\(typePrefix)\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher"
                        : "AlwaysMatcher"

                    try VariableDeclSyntax(
                        """
                        var _\(raw: variablePrefix): [(\(raw: typePrefix)\(raw: variablePrefix.capitalizingComponentsFirstLetter())_FieldOptions, \(raw: inputMatcherType))] = []
                        """
                    )
                }

                for functionDeclaration in functionDeclarations {
                    let methods = try FunctionStyleExpectationsGenerator.generateExpectationMethods(
                        for: functionDeclaration,
                        typePrefix: typePrefix,
                        accessLevel: accessLevel,
                        typeConformanceProvider: typeConformanceProvider
                    )
                    for method in methods {
                        method
                    }
                }
            }
        )
    }

    static func expectedResponsesDeclaration(
        functionDeclarations: [FunctionDeclSyntax],
        propertyDeclarations: [PropertyDeclaration] = [],
        typePrefix: String = ""
    ) throws
        -> StructDeclSyntax
    {
        try StructDeclSyntax(
            name: "\(raw: typePrefix)ExpectedResponses",
            memberBlockBuilder: {
                for propertyDeclaration in propertyDeclarations {
                    try VariableDeclSyntax(
                        """
                        var \(raw: propertyDeclaration.name): \(raw: propertyDeclaration.typePrefix)ExpectedResponses
                        """
                    )
                }

                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                    try ExpectedResponseGenerator.expectedResponseVariableDeclaration(
                        typePrefix: typePrefix,
                        variablePrefix: variablePrefix,
                        functionDeclaration: functionDeclaration,
                        accessModifier: "",
                        staticName: false
                    )
                }

                try InitializerDeclSyntax("init(expectations: \(raw: typePrefix)Expectations) {") {
                    for propertyDeclaration in propertyDeclarations {
                        ExprSyntax(
                            """
                            self.\(raw: propertyDeclaration.name) = .init(expectations: expectations.\(raw: propertyDeclaration.name))
                            """
                        )
                    }
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

    static func receivedInvocationsDeclaration(
        functionDeclarations: [FunctionDeclSyntax],
        propertyDeclarations: [PropertyDeclaration] = [],
        typePrefix: String = ""
    ) throws
        -> StructDeclSyntax
    {
        try StructDeclSyntax(
            name: "\(raw: typePrefix)ReceivedInvocations",
            memberBlockBuilder: {
                for propertyDeclaration in propertyDeclarations {
                    try VariableDeclSyntax(
                        """
                        var \(raw: propertyDeclaration.name): \(raw: propertyDeclaration.typePrefix)ReceivedInvocations = .init()
                        """
                    )
                }

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
                    var combinedCallCount: Int = 0
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

                try VariableDeclSyntax(
                    """
                    let mockIdentifier: String
                    """
                )

                try InitializerDeclSyntax("init(expectedResponses: consuming ExpectedResponses) {") {
                    ExprSyntax(
                        """
                        self.mutex = Mutex(.init(expectedResponses: expectedResponses))
                        """
                    )
                    ExprSyntax(
                        """
                        self.mockIdentifier = SmockHelper.generateMockIdentifier()
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

    static func verifyNoInteractions(mockName: String, accessLevel: AccessLevel) throws -> FunctionDeclSyntax {
        // Function with no parameters
        try FunctionDeclSyntax(
            """
            \(raw: accessLevel.rawValue) func verifyNoInteractions(sourceLocation: SourceLocation) {
                let combinedCallCount = self.state.mutex.withLock { storage in
                    return storage.combinedCallCount
                }
                
                VerificationHelper.performNoInteractionVerification(
                    interactionCount: combinedCallCount,
                    mockName: "\(raw: mockName)",
                    sourceLocation: sourceLocation
                )
            }
            """
        )
    }

    static func getMockIdentifier(accessLevel: AccessLevel) throws -> FunctionDeclSyntax {
        // Function with no parameters
        try FunctionDeclSyntax(
            """
            \(raw: accessLevel.rawValue) func getMockIdentifier() -> String {
                return self.state.mockIdentifier
            }
            """
        )
    }
}
