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
    /// public matcher API; users should never reference it directly.
    static func inputMatcherStructDeclaration(
        variablePrefix: String,
        parameterList: FunctionParameterListSyntax,
        typePrefix: String = "",
        accessLevel: AccessLevel,
        typeConformanceProvider: (String) -> TypeConformance,
        function: MockableFunction
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
                        function: function
                    )
                }

                // Generate matches method
                try generateMatchesMethod(parameters: parameters, function: function)
            }
        )
    }

    /// Generate a matcher property for a function parameter
    private static func generateMatcherProperty(
        for parameter: FunctionParameterSyntax,
        typeConformanceProvider: (String) -> TypeConformance,
        function: MockableFunction
    ) throws -> VariableDeclSyntax {
        let paramName = parameter.secondName?.text ?? parameter.firstName.text

        switch function.classify(parameter.type) {
        case .directGeneric(let info):
            return try VariableDeclSyntax(
                """
                let \(raw: paramName): ExistentialValueMatcher<\(raw: info.storageType)>
                """
            )
        case .wrappedGeneric:
            return try VariableDeclSyntax(
                """
                let \(raw: paramName): ExistentialValueMatcher<any Sendable>
                """
            )
        case .concrete:
            let paramType = parameter.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return try VariableDeclSyntax(
                """
                let \(raw: paramName): ValueMatcher<\(raw: paramType)>
                """
            )
        }
    }

    /// Generate the matches method that checks if all parameters match
    private static func generateMatchesMethod(
        parameters: [FunctionParameterSyntax],
        function: MockableFunction
    ) throws -> FunctionDeclSyntax {
        // Build parameter list for matches method
        var methodParameters: [String] = []
        var matchChecks: [String] = []

        for parameter in parameters {
            let paramName = parameter.secondName?.text ?? parameter.firstName.text

            // The matches() method receives the erased form of the parameter type,
            // so the mock implementation upcasts before calling.
            let paramTypeForSignature = function.erasedTypeString(for: parameter.type)

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
