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
//  InputMatcherGenerator.swift
//  SmockMacro
//

import SwiftSyntax
import SwiftSyntaxBuilder

enum InputMatcherGenerator {
    /// Generate an input matcher struct for a specific function.
    ///
    /// The generated `_InputMatcher` struct is intentionally `internal` regardless of
    /// the protocol's access level. It's an implementation detail used to compose the
    /// public matcher API; users should never reference it directly. Keeping it
    /// internal preserves freedom to refactor matcher storage in the future
    /// (e.g. to use parameter packs).
    static func inputMatcherStructDeclaration(
        variablePrefix: String,
        parameterList: FunctionParameterListSyntax,
        typePrefix: String = "",
        accessLevel: AccessLevel,
        typeConformanceProvider: (String) -> TypeConformance,
        genericContext: GenericContext = .empty
    ) throws -> StructDeclSyntax? {
        // Only generate matcher if function has parameters
        guard !parameterList.isEmpty else { return nil }

        let structName = "\(typePrefix)\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher"
        let parameters = Array(parameterList)

        return try StructDeclSyntax(
            name: TokenSyntax.identifier(structName),
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(type: IdentifierTypeSyntax(name: "Sendable"))
            },
            memberBlockBuilder: {
                // Generate properties for each parameter
                for parameter in parameters {
                    try generateMatcherProperty(
                        for: parameter,
                        typeConformanceProvider: typeConformanceProvider,
                        genericContext: genericContext
                    )
                }

                // Generate matches method
                try generateMatchesMethod(parameters: parameters, genericContext: genericContext)
            }
        )
    }

    /// Generate a matcher property for a function parameter
    private static func generateMatcherProperty(
        for parameter: FunctionParameterSyntax,
        typeConformanceProvider: (String) -> TypeConformance,
        genericContext: GenericContext
    ) throws -> VariableDeclSyntax {
        let paramName = parameter.secondName?.text ?? parameter.firstName.text

        // Generic-aware handling
        switch genericContext.classify(parameter.type) {
        case .directGeneric(let info):
            // Use the existential storage type (e.g. `any Encodable & Sendable`).
            // For Equatable constraints, allow exact matching via OnlyEquatableValueMatcher
            // — but matchers store the existential, not the original generic param.
            // The exact-match overload at the expectations layer captures the concrete
            // type and converts it to a `.matching` closure.
            return try VariableDeclSyntax(
                """
                let \(raw: paramName): NonComparableValueMatcher<\(raw: info.storageType)>
                """
            )
        case .wrappedGeneric:
            return try VariableDeclSyntax(
                """
                let \(raw: paramName): AnyValueMatcher
                """
            )
        case .concrete:
            break
        }

        let paramType = parameter.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let isOptional = paramType.hasSuffix("?")
        let baseType = (isOptional ? String(paramType.dropLast()) : paramType)
        let typePrefix: String

        switch typeConformanceProvider(baseType) {
        case .comparableAndEquatable:
            typePrefix = ""
        case .onlyEquatable:
            typePrefix = "OnlyEquatable"
        case .neitherComparableNorEquatable:
            typePrefix = "NonComparable"
        }

        if isOptional {
            return try VariableDeclSyntax(
                """
                let \(raw: paramName): Optional\(raw: typePrefix)ValueMatcher<\(raw: paramType.dropLast())>
                """
            )
        } else {
            return try VariableDeclSyntax(
                """
                let \(raw: paramName): \(raw: typePrefix)ValueMatcher<\(raw: paramType)>
                """
            )
        }
    }

    /// Generate the matches method that checks if all parameters match
    private static func generateMatchesMethod(
        parameters: [FunctionParameterSyntax],
        genericContext: GenericContext
    ) throws -> FunctionDeclSyntax {
        // Build parameter list for matches method
        var methodParameters: [String] = []
        var matchChecks: [String] = []

        for parameter in parameters {
            let paramName = parameter.secondName?.text ?? parameter.firstName.text

            // Determine the type used in the matches() method signature.
            // For generic params, the matches() method receives the existential
            // (case 1) or `any Sendable` (case 2) — the mock implementation
            // upcasts before calling. `any Sendable` is required (instead of `Any`)
            // because the mock state lives behind a Mutex and must be Sendable.
            let paramTypeForSignature: String
            switch genericContext.classify(parameter.type) {
            case .directGeneric(let info):
                paramTypeForSignature = info.storageType
            case .wrappedGeneric:
                paramTypeForSignature = "any Sendable"
            case .concrete:
                paramTypeForSignature = parameter.type.description
            }

            // Add parameter to method signature
            let firstName = parameter.firstName.text
            if firstName != paramName {
                methodParameters.append("\(firstName) \(paramName): \(paramTypeForSignature)")
            } else {
                methodParameters.append("\(paramName): \(paramTypeForSignature)")
            }

            // Add match check
            matchChecks.append("self.\(paramName).matches(\(paramName))")
        }

        let methodSignature = methodParameters.joined(separator: ", ")
        let matchCondition = matchChecks.joined(separator: " && ")

        return try FunctionDeclSyntax(
            """
            func matches(\(raw: methodSignature)) -> Bool {
                return \(raw: matchCondition)
            }
            """
        )
    }
}
