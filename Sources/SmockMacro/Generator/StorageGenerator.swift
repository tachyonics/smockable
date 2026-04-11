//===----------------------------------------------------------------------===//
//
// This source file is part of the Smockable open source project
//
// Copyright (c) 2026 the Smockable authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Smockable authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

//
//  StorageGenerator.swift
//  SmockMacro
//

import SwiftSyntax
import SwiftSyntaxBuilder

enum StorageGenerator {
    static func expectationsDeclaration(
        mockableFunctions: [MockableFunction],
        typePrefix: String = "",
        propertyDeclarations: [PropertyDeclaration] = [],
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

                for function in mockableFunctions {
                    let parameterList = function.declaration.signature.parameterClause.parameters
                    let variablePrefix = VariablePrefixGenerator.text(for: function.declaration)
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

                for function in mockableFunctions {
                    let methods = try FunctionStyleExpectationsGenerator.generateExpectationMethods(
                        for: function,
                        typePrefix: typePrefix,
                        accessLevel: accessLevel
                    )
                    for method in methods {
                        method
                    }
                }
            }
        )
    }

    static func expectedResponsesDeclaration(
        mockableFunctions: [MockableFunction],
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

                for function in mockableFunctions {
                    let variablePrefix = VariablePrefixGenerator.text(for: function.declaration)

                    try ExpectedResponseGenerator.expectedResponseVariableDeclaration(
                        typePrefix: typePrefix,
                        variablePrefix: variablePrefix,
                        functionDeclaration: function.declaration,
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
                    for function in mockableFunctions {
                        let variablePrefix = VariablePrefixGenerator.text(for: function.declaration)

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
        mockableFunctions: [MockableFunction],
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

                for function in mockableFunctions {
                    let variablePrefix = VariablePrefixGenerator.text(for: function.declaration)
                    let parameterList = function.declaration.signature.parameterClause.parameters

                    try ReceivedInvocationsGenerator.variableDeclaration(
                        variablePrefix: variablePrefix,
                        parameterList: parameterList,
                        function: function
                    )
                }
            }
        )
    }

    static func storageDeclaration() throws -> StructDeclSyntax {
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

    static func stateDeclaration() throws -> ClassDeclSyntax {
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

    static func variableDeclaration(isActor: Bool = false) throws -> VariableDeclSyntax {
        if isActor {
            return try VariableDeclSyntax(
                """
                nonisolated private let state: State
                """
            )
        } else {
            return try VariableDeclSyntax(
                """
                private let state: State
                """
            )
        }
    }

    static func verifyNoInteractions(
        mockName: String,
        accessLevel: AccessLevel,
        isActor: Bool = false
    ) throws -> FunctionDeclSyntax {
        let nonisolatedPrefix = isActor ? "nonisolated " : ""
        // Function with no parameters
        return try FunctionDeclSyntax(
            """
            \(raw: nonisolatedPrefix)\(raw: accessLevel.rawValue) func verifyNoInteractions(sourceLocation: SourceLocation) {
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

    static func getMockIdentifier(accessLevel: AccessLevel, isActor: Bool = false) throws -> FunctionDeclSyntax {
        let nonisolatedPrefix = isActor ? "nonisolated " : ""
        // Function with no parameters
        return try FunctionDeclSyntax(
            """
            \(raw: nonisolatedPrefix)\(raw: accessLevel.rawValue) func getMockIdentifier() -> String {
                return self.state.mockIdentifier
            }
            """
        )
    }
}
