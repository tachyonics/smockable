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
//  MockGenerator.swift
//  SmockMacro
//

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

enum MacroError: Error {
    case invalidPropertyDeclaration
}

enum MockGenerator {
    // swiftlint:disable function_body_length
    static func createGetterSetterPropertyDeclaration(
        for variable: VariableDeclSyntax,
        typeConformanceProvider: @escaping (String) -> TypeConformance
    ) throws -> PropertyDeclaration {
        guard let binding = variable.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
            let type = binding.typeAnnotation?.type
        else {
            throw MacroError.invalidPropertyDeclaration
        }

        let propertyName = identifier.text
        let propertyType = type

        // Parse accessor block to determine async/throws modifiers
        var isAsync = false
        var hasGetter = false
        var hasSetter = false
        var effectSpecifiers: AccessorEffectSpecifiersSyntax?

        if let accessorBlock = binding.accessorBlock {
            switch accessorBlock.accessors {
            case .accessors(let accessorList):
                for accessor in accessorList {
                    switch accessor.accessorSpecifier.tokenKind {
                    case .keyword(.get):
                        hasGetter = true
                        isAsync = accessor.effectSpecifiers?.asyncSpecifier != nil
                        effectSpecifiers = accessor.effectSpecifiers
                    case .keyword(.set):
                        hasSetter = true
                    // Setters inherit async/throws from getters in property declarations
                    default:
                        break
                    }
                }
            case .getter:
                hasGetter = true
            // For computed properties with just a getter block
            }
        } else {
            // If no accessor block, it's a stored property (get/set)
            hasGetter = true
            hasSetter = true
        }

        let throwsClause = effectSpecifiers?.throwsClause

        let getter =
            hasGetter
            ? try makePropertyFunction(
                propertyFunctionType: .get,
                propertyType: propertyType,
                isAsync: isAsync,
                throwsClause: throwsClause
            )
            : nil
        let setter =
            hasSetter
            ? try makePropertyFunction(
                propertyFunctionType: .set,
                propertyType: propertyType,
                isAsync: isAsync,
                throwsClause: throwsClause
            )
            : nil

        let typePrefix = "\(propertyName.capitalizingComponentsFirstLetter())_"

        let get: PropertyFunction?
        if let getter {
            let getterVariablePrefix = VariablePrefixGenerator.text(for: getter)
            get = PropertyFunction(
                function: getter,
                mockableFunction: MockableFunction(
                    declaration: getter,
                    typeConformanceProvider: typeConformanceProvider
                ),
                variablePrefix: getterVariablePrefix,
                parameterList: [],
                effectSpecifiers: effectSpecifiers
            )
        } else {
            get = nil
        }

        let set: PropertyFunction?
        if let setter {
            let setterVariablePrefix = VariablePrefixGenerator.text(for: setter)
            let setterParameterList = setter.signature.parameterClause.parameters

            set = PropertyFunction(
                function: setter,
                mockableFunction: MockableFunction(
                    declaration: setter,
                    typeConformanceProvider: typeConformanceProvider
                ),
                variablePrefix: setterVariablePrefix,
                parameterList: setterParameterList,
                effectSpecifiers: nil
            )
        } else {
            set = nil
        }

        return PropertyDeclaration(
            name: propertyName,
            typePrefix: typePrefix,
            storagePrefix: "\(propertyName).",
            variable: variable,
            get: get,
            set: set
        )
    }

    // swiftlint:disable function_body_length
    static func declaration(
        for protocolDeclaration: ProtocolDeclSyntax,
        parameters originalParameters: MacroParameters = .default,
        context: (some MacroExpansionContext)?
    ) throws -> DeclSyntax {
        let isActor = protocolInheritsFromActor(protocolDeclaration)
        let identifier = TokenSyntax.identifier("Mock" + protocolDeclaration.name.text)

        let originalAccessLevel = originalParameters.accessLevel
        let parameters: MacroParameters
        switch originalAccessLevel {
        case .public, .package, .internal:
            parameters = originalParameters
        case .fileprivate, .private:
            // for fileprivate and private access modifiers, internal components should still use internal
            parameters = .init(
                accessLevel: .internal,
                preprocessorFlag: originalParameters.preprocessorFlag,
                additionalComparableTypes: originalParameters.additionalComparableTypes,
                additionalEquatableTypes: originalParameters.additionalEquatableTypes
            )
        }

        let functionDeclarations = protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }

        let associatedTypes = protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(AssociatedTypeDeclSyntax.self) }

        let genericParameterClause = getGenericParameterClause(associatedTypes: associatedTypes)
        let (comparableAssociatedTypes, equatableAssociatedTypes) =
            AssociatedTypesGenerator.getTypeConformanceAssociatedTypes(
                associatedTypes: associatedTypes
            )

        var typeParseWarnings: [String] = []
        let typeConformanceProvider = TypeConformanceProvider.get(
            comparableAssociatedTypes: comparableAssociatedTypes,
            equatableAssociatedTypes: equatableAssociatedTypes,
            additionalComparableTypes: parameters.additionalComparableTypes,
            additionalEquatableTypes: parameters.additionalEquatableTypes,
            parseWarningHandler: { typeParseWarnings.append($0) }
        )
        defer {
            for warning in typeParseWarnings {
                context?.diagnose(SmockDiagnostic.unparseableTypeString(typeString: warning).asDiagnostic)
            }
        }

        let propertyDeclarations = try protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .map { variable in
                try createGetterSetterPropertyDeclaration(
                    for: variable,
                    typeConformanceProvider: typeConformanceProvider
                )
            }

        // Build the MockableFunction wrapper for each protocol method exactly once.
        // Every generator that needs generic context information receives it via this
        // array (or a single element from it), guaranteeing that the generic analysis
        // for a given function declaration runs only once.
        let mockableFunctions = functionDeclarations.map {
            MockableFunction(declaration: $0, typeConformanceProvider: typeConformanceProvider)
        }

        try validateGenericParametersSendable(mockableFunctions)

        let nonisolatedPrefix = isActor ? "nonisolated " : ""

        let inheritanceClause = InheritanceClauseSyntax {
            InheritedTypeSyntax(
                type: IdentifierTypeSyntax(name: protocolDeclaration.name)
            )

            if !isActor {
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: "Sendable")
                )
            }

            InheritedTypeSyntax(
                type: IdentifierTypeSyntax(name: "VerifiableSmock")
            )
        }

        let memberBlock = try MemberBlockSyntax {
            // VerifiableSmock conformance
            try TypeAliasDeclSyntax("\(raw: parameters.accessLevel.rawValue) typealias VerifierType = Verifier")

            let verifierSig =
                nonisolatedPrefix + parameters.accessLevel.rawValue
                + " func getVerifier(mode: VerificationMode,"
                + " sourceLocation: SourceLocation, inOrder: InOrder?) -> Verifier {"
            try FunctionDeclSyntax("\(raw: verifierSig)") {
                ReturnStmtSyntax(
                    expression: ExprSyntax(
                        "Verifier(state: self.state, mode: mode, sourceLocation: sourceLocation, inOrder: inOrder)"
                    )
                )
            }

            try InitializerDeclSyntax(
                "\(raw: parameters.accessLevel.rawValue) init(expectations: consuming Expectations = .init()) { "
            ) {
                ExprSyntax(
                    """
                    self.state = .init(expectedResponses: .init(expectations: expectations))
                    """
                )
            }

            for propertyDeclaration in propertyDeclarations {
                let propertyMockableFunctions = [
                    propertyDeclaration.get?.mockableFunction,
                    propertyDeclaration.set?.mockableFunction,
                ].compactMap { $0 }

                try StorageGenerator.expectationsDeclaration(
                    mockableFunctions: propertyMockableFunctions,
                    typePrefix: propertyDeclaration.typePrefix,
                    accessLevel: parameters.accessLevel
                )

                try StorageGenerator.expectedResponsesDeclaration(
                    mockableFunctions: propertyMockableFunctions,
                    typePrefix: propertyDeclaration.typePrefix
                )

                try StorageGenerator.receivedInvocationsDeclaration(
                    mockableFunctions: propertyMockableFunctions,
                    typePrefix: propertyDeclaration.typePrefix
                )

                try VerifierGenerator.verifierStructDeclaration(
                    mockableFunctions: propertyMockableFunctions,
                    typePrefix: propertyDeclaration.typePrefix,
                    storagePrefix: propertyDeclaration.storagePrefix,
                    accessLevel: parameters.accessLevel
                )

                if let get = propertyDeclaration.get {
                    try FieldOptionsGenerator.fieldOptionsClassDeclaration(
                        variablePrefix: get.variablePrefix,
                        typePrefix: propertyDeclaration.typePrefix,
                        accessLevel: parameters.accessLevel,
                        function: get.mockableFunction
                    )

                    try ExpectedResponseGenerator.expectedResponseEnumDeclaration(
                        typePrefix: propertyDeclaration.typePrefix,
                        variablePrefix: get.variablePrefix,
                        accessLevel: parameters.accessLevel,
                        function: get.mockableFunction
                    )
                }

                if let set = propertyDeclaration.set {
                    try FieldOptionsGenerator.fieldOptionsClassDeclaration(
                        variablePrefix: set.variablePrefix,
                        typePrefix: propertyDeclaration.typePrefix,
                        accessLevel: parameters.accessLevel,
                        function: set.mockableFunction
                    )

                    try ExpectedResponseGenerator.expectedResponseEnumDeclaration(
                        typePrefix: propertyDeclaration.typePrefix,
                        variablePrefix: set.variablePrefix,
                        accessLevel: parameters.accessLevel,
                        function: set.mockableFunction
                    )

                    if let setterInputMatcherStruct = try InputMatcherGenerator.inputMatcherStructDeclaration(
                        variablePrefix: set.variablePrefix,
                        parameterList: set.parameterList,
                        typePrefix: propertyDeclaration.typePrefix,
                        accessLevel: parameters.accessLevel,
                        typeConformanceProvider: typeConformanceProvider,
                        function: set.mockableFunction
                    ) {
                        setterInputMatcherStruct
                    }
                }

                try PropertyImplementationGenerator.propertyDeclaration(
                    propertyDeclaration: propertyDeclaration,
                    accessLevel: parameters.accessLevel
                )
            }

            try StorageGenerator.expectationsDeclaration(
                mockableFunctions: mockableFunctions,
                propertyDeclarations: propertyDeclarations,
                accessLevel: parameters.accessLevel
            )
            try StorageGenerator.expectedResponsesDeclaration(
                mockableFunctions: mockableFunctions,
                propertyDeclarations: propertyDeclarations
            )
            try StorageGenerator.receivedInvocationsDeclaration(
                mockableFunctions: mockableFunctions,
                propertyDeclarations: propertyDeclarations
            )
            try StorageGenerator.storageDeclaration()
            try StorageGenerator.stateDeclaration()
            try StorageGenerator.variableDeclaration(isActor: isActor)

            try VerifierGenerator.verifierStructDeclaration(
                mockableFunctions: mockableFunctions,
                propertyDeclarations: propertyDeclarations,
                accessLevel: parameters.accessLevel
            )

            for function in mockableFunctions {
                let variablePrefix = VariablePrefixGenerator.text(for: function.declaration)
                let parameterList = function.declaration.signature.parameterClause.parameters

                try FieldOptionsGenerator.fieldOptionsClassDeclaration(
                    variablePrefix: variablePrefix,
                    accessLevel: parameters.accessLevel,
                    function: function
                )
                try ExpectedResponseGenerator.expectedResponseEnumDeclaration(
                    variablePrefix: variablePrefix,
                    accessLevel: parameters.accessLevel,
                    function: function
                )

                // Generate input matcher struct for functions with parameters
                if let inputMatcherStruct = try InputMatcherGenerator.inputMatcherStructDeclaration(
                    variablePrefix: variablePrefix,
                    parameterList: parameterList,
                    accessLevel: parameters.accessLevel,
                    typeConformanceProvider: typeConformanceProvider,
                    function: function
                ) {
                    inputMatcherStruct
                }

                try FunctionImplementationGenerator.functionDeclaration(
                    variablePrefix: variablePrefix,
                    accessLevel: parameters.accessLevel,
                    function: function
                )
            }

            try StorageGenerator.verifyNoInteractions(
                mockName: identifier.description,
                accessLevel: parameters.accessLevel,
                isActor: isActor
            )
            try StorageGenerator.getMockIdentifier(accessLevel: parameters.accessLevel, isActor: isActor)
        }

        if isActor {
            return DeclSyntax(
                ActorDeclSyntax(
                    modifiers: [originalAccessLevel.declModifier],
                    name: identifier,
                    genericParameterClause: genericParameterClause,
                    inheritanceClause: inheritanceClause,
                    memberBlock: memberBlock
                )
            )
        } else {
            return DeclSyntax(
                StructDeclSyntax(
                    modifiers: [originalAccessLevel.declModifier],
                    name: identifier,
                    genericParameterClause: genericParameterClause,
                    inheritanceClause: inheritanceClause,
                    memberBlock: memberBlock
                )
            )
        }
    }
    // swiftlint:enable function_body_length
}

extension MockGenerator {
    /// Convenience overload that omits the `MacroExpansionContext` parameter.
    static func declaration(
        for protocolDeclaration: ProtocolDeclSyntax,
        parameters: MacroParameters = .default
    ) throws -> DeclSyntax {
        try declaration(
            for: protocolDeclaration,
            parameters: parameters,
            context: nil as BasicMacroExpansionContext?
        )
    }
}

private func getGenericParameterClause(
    associatedTypes: [AssociatedTypeDeclSyntax]
)
    -> GenericParameterClauseSyntax?
{
    let genericParameterClause: GenericParameterClauseSyntax?
    if !associatedTypes.isEmpty {
        let rawGenericParameterClause = associatedTypes.map { associatedType in
            if let inheritanceClause = associatedType.inheritanceClause {
                "\(associatedType.name) \(inheritanceClause)"
            } else {
                "\(associatedType.name)"
            }
        }.joined(separator: ", ")

        genericParameterClause = GenericParameterClauseSyntax("<\(raw: rawGenericParameterClause)>")
    } else {
        genericParameterClause = nil
    }

    return genericParameterClause
}

private func protocolInheritsFromActor(_ protocolDeclaration: ProtocolDeclSyntax) -> Bool {
    guard let inheritanceClause = protocolDeclaration.inheritanceClause else {
        return false
    }
    return inheritanceClause.inheritedTypes.contains { inheritedType in
        inheritedType.type.as(IdentifierTypeSyntax.self)?.name.text == "Actor"
    }
}

/// Validate that all generic parameters include Sendable. Mock state lives
/// behind a Mutex so all stored types must be Sendable. Without this check,
/// the user gets an opaque compiler error deep in the macro-generated code
/// instead of a clear message at the macro site.
private func validateGenericParametersSendable(_ functions: [MockableFunction]) throws {
    for function in functions {
        for (name, param) in function.genericParameters {
            if !param.isSendable && param.storageType != "Any" {
                throw SmockDiagnostic.genericParameterMissingSendable(
                    parameterName: name,
                    functionName: function.declaration.name.text
                )
            }
        }
    }
}

private enum PropertyFunctionType {
    case get
    case set
}

private func makePropertyFunction(
    propertyFunctionType: PropertyFunctionType,
    propertyType: TypeSyntax,
    isAsync: Bool,
    throwsClause: ThrowsClauseSyntax?
) throws -> FunctionDeclSyntax {
    var signature = "func "

    switch propertyFunctionType {
    case .get:
        signature += "get()"
    case .set:
        signature += "set(_ newValue: \(propertyType)"
    }

    if isAsync {
        signature += " async"
    }
    if let throwsClause {
        if let type = throwsClause.type {
            signature += " throws(\(type.trimmed))"
        } else {
            signature += " throws"
        }
    }

    if case .get = propertyFunctionType {
        signature += " -> \(propertyType)"
    }

    return try FunctionDeclSyntax("\(raw: signature) { fatalError(\"Not implemented\") }")
}
