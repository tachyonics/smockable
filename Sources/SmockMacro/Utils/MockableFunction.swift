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
//  MockableFunction.swift
//  SmockMacro
//

import Foundation
import SwiftSyntax

/// A protocol method requirement together with the parsed metadata that all generators
/// need: the function declaration itself plus the analysis of its generic parameters
/// and constraints.
package struct MockableFunction {
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

    /// The underlying SwiftSyntax declaration for the protocol method.
    package let declaration: FunctionDeclSyntax

    /// All generic parameters declared on the function, keyed by name.
    package let genericParameters: [String: GenericParameter]

    /// The type conformance provider used to look up `additionalEquatableTypes`
    /// allowlist entries for non-generic parameters.
    ///
    /// Stored on the `MockableFunction` so generators can pass a single value
    /// around instead of threading a separate provider closure alongside.
    package let typeConformanceProvider: (String) -> TypeConformance

    /// Build a `MockableFunction` for the given function declaration.
    /// - Parameters:
    ///   - declaration: The function whose generic clause should be parsed.
    ///   - typeConformanceProvider: Used to determine if a constraint type appears in
    ///     the `additionalEquatableTypes` allowlist. Stored on the resulting
    ///     `MockableFunction` so consumers don't need to thread it separately.
    package init(
        declaration: FunctionDeclSyntax,
        typeConformanceProvider: @escaping (String) -> TypeConformance
    ) {
        self.declaration = declaration
        self.typeConformanceProvider = typeConformanceProvider

        // Collect inline constraints from the generic parameter clause.
        // e.g. `<T: Encodable & Sendable, U: Sendable>`
        var inlineConstraints: [String: [String]] = [:]
        var declarationOrder: [String] = []
        if let clause = declaration.genericParameterClause {
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
        if let whereClause = declaration.genericWhereClause {
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
        var genericParameters: [String: GenericParameter] = [:]
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

            genericParameters[name] = GenericParameter(
                storageType: storageType,
                isEquatable: isEquatable
            )
        }

        self.genericParameters = genericParameters
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

    /// Classify a parameter type relative to this function's generic parameters.
    package func classify(_ parameterType: TypeSyntax) -> ParameterClassification {
        let typeString = parameterType.description.trimmingCharacters(in: .whitespacesAndNewlines)

        // Direct match: parameter type is exactly a generic parameter name.
        if let parameter = genericParameters[typeString] {
            return .directGeneric(parameter)
        }

        // Wrapped match: type description contains a generic parameter name as a token.
        for genericName in genericParameters.keys {
            if Self.containsToken(genericName, in: typeString) {
                return .wrappedGeneric
            }
        }

        return .concrete
    }

    // MARK: - Type erasure for generic substitution

    /// Substitute a type with its erased storage form, returning a `TypeSyntax`.
    ///
    /// - Direct generic parameter (e.g. `T`) → the constraint existential
    ///   (e.g. `any Encodable & Sendable`).
    /// - Wrapped generic (e.g. `Foo<T>`, `[T]`) → `any Sendable`. Wrapped types
    ///   collapse to `any Sendable` because Swift can't express the wrapped
    ///   existential as a storage type.
    /// - Concrete type → returned unchanged.
    ///
    /// `any Sendable` is required (instead of plain `Any`) because the storage
    /// it goes into lives behind a `Mutex` and must be `Sendable`-conforming.
    package func erasedType(for type: TypeSyntax) -> TypeSyntax {
        switch classify(type) {
        case .directGeneric(let info):
            return TypeSyntax(IdentifierTypeSyntax(name: .identifier(info.storageType)))
        case .wrappedGeneric:
            return TypeSyntax(IdentifierTypeSyntax(name: .identifier("any Sendable")))
        case .concrete:
            return type
        }
    }

    /// String form of ``erasedType(for:)``. Convenient when the result is going
    /// to be interpolated into generated source as a raw string rather than
    /// embedded as a `TypeSyntax`.
    package func erasedTypeString(for type: TypeSyntax) -> String {
        switch classify(type) {
        case .directGeneric(let info):
            return info.storageType
        case .wrappedGeneric:
            return "any Sendable"
        case .concrete:
            return type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
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
