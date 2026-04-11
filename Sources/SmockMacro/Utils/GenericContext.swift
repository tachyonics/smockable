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
//  GenericContext.swift
//  SmockMacro
//

import Foundation
import SwiftSyntax

/// Captures information about a function's generic parameters and their constraints
/// so the mock generators can substitute generic types with appropriate storage types.
///
/// For each generic parameter (e.g. `T: Encodable & Sendable`), records the existential
/// storage type that should be used in matchers, storage tuples, and verifiers.
package struct GenericContext {
    /// Information about a single generic parameter on a function.
    package struct GenericParameter {
        /// The existential type used as the storage type when this parameter is used
        /// directly as a parameter type (e.g. `any Encodable & Sendable`).
        ///
        /// If the generic parameter has no constraints, this is `Any`.
        package let storageType: String
        /// Whether the generic parameter's constraint includes `Equatable` (either
        /// inline, in the where clause, or via the `additionalEquatableTypes` allowlist).
        package let isEquatable: Bool
    }

    /// All generic parameters declared on the function, keyed by name.
    package let parameters: [String: GenericParameter]

    /// An empty context for non-generic functions.
    package static let empty = GenericContext()

    private init() {
        self.parameters = [:]
    }

    /// Build a `GenericContext` for the given function declaration.
    /// - Parameters:
    ///   - functionDeclaration: The function whose generic clause should be parsed.
    ///   - typeConformanceProvider: Used to determine if a constraint type appears in
    ///     the `additionalEquatableTypes` allowlist.
    package init(
        functionDeclaration: FunctionDeclSyntax,
        typeConformanceProvider: (String) -> TypeConformance
    ) {
        // Collect inline constraints from the generic parameter clause.
        // e.g. `<T: Encodable & Sendable, U: Sendable>`
        var inlineConstraints: [String: [String]] = [:]
        var declarationOrder: [String] = []
        if let clause = functionDeclaration.genericParameterClause {
            for param in clause.parameters {
                let name = param.name.text
                declarationOrder.append(name)
                var constraintParts: [String] = []
                if let inheritedType = param.inheritedType {
                    constraintParts.append(
                        inheritedType.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                inlineConstraints[name] = constraintParts
            }
        }

        // Merge constraints from the where clause.
        // e.g. `where T: Equatable, U == String`
        if let whereClause = functionDeclaration.genericWhereClause {
            for requirement in whereClause.requirements {
                if let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self) {
                    let leftSide =
                        conformance.leftType.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    let rightSide =
                        conformance.rightType.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    if inlineConstraints[leftSide] != nil {
                        inlineConstraints[leftSide]?.append(rightSide)
                    }
                }
            }
        }

        // Build the final GenericParameter values from the merged constraints.
        var parameters: [String: GenericParameter] = [:]
        for name in declarationOrder {
            let constraints = inlineConstraints[name] ?? []

            // Split each "A & B" constraint into individual protocols, then dedupe.
            var protocols: [String] = []
            var seen: Set<String> = []
            for constraint in constraints {
                for component in constraint.split(separator: "&") {
                    let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty, !seen.contains(trimmed) {
                        protocols.append(trimmed)
                        seen.insert(trimmed)
                    }
                }
            }

            let storageType: String
            if protocols.isEmpty {
                storageType = "Any"
            } else {
                storageType = "any " + protocols.joined(separator: " & ")
            }

            // Determine equatability: a constraint protocol is `Equatable`/`Hashable`,
            // or one of the constraint protocols is in the additionalEquatableTypes
            // allowlist. Short-circuits on the cheap inline checks first.
            let isEquatable =
                protocols.contains("Equatable")
                || protocols.contains("Hashable")
                || protocols.contains { proto in
                    typeConformanceProvider(proto) != .neitherComparableNorEquatable
                }

            parameters[name] = GenericParameter(
                storageType: storageType,
                isEquatable: isEquatable
            )
        }

        self.parameters = parameters
    }

    // MARK: - Parameter classification

    /// How a function parameter relates to the function's generic parameters.
    package enum ParameterClassification {
        /// Parameter type doesn't reference any generic parameter.
        case concrete
        /// Parameter type *is* a generic parameter (e.g. `T`).
        /// The associated `GenericParameter` has the storage type to use.
        case directGeneric(GenericParameter)
        /// Parameter type references a generic parameter inside a wrapper
        /// (e.g. `Foo<T>`, `[T]`, `T?`).
        case wrappedGeneric
    }

    /// Classify a parameter type relative to this context's generic parameters.
    package func classify(_ parameterType: TypeSyntax) -> ParameterClassification {
        let typeString = parameterType.description.trimmingCharacters(in: .whitespacesAndNewlines)

        // Direct match: parameter type is exactly a generic parameter name.
        if let parameter = parameters[typeString] {
            return .directGeneric(parameter)
        }

        // Wrapped match: type description contains a generic parameter name as a token.
        for genericName in parameters.keys {
            if Self.containsToken(genericName, in: typeString) {
                return .wrappedGeneric
            }
        }

        return .concrete
    }

    /// Check whether `token` appears in `text` as a complete identifier (not as a
    /// substring of a longer identifier).
    private static func containsToken(_ token: String, in text: String) -> Bool {
        guard !token.isEmpty else { return false }
        var searchStart = text.startIndex
        while let range = text.range(of: token, range: searchStart..<text.endIndex) {
            let beforeOK: Bool
            if range.lowerBound == text.startIndex {
                beforeOK = true
            } else {
                let prev = text[text.index(before: range.lowerBound)]
                beforeOK = !prev.isLetter && !prev.isNumber && prev != "_"
            }
            let afterOK: Bool
            if range.upperBound == text.endIndex {
                afterOK = true
            } else {
                let next = text[range.upperBound]
                afterOK = !next.isLetter && !next.isNumber && next != "_"
            }
            if beforeOK && afterOK {
                return true
            }
            searchStart = range.upperBound
        }
        return false
    }
}
