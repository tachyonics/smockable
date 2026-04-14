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

    /// Precomputed classifications, keyed by the trimmed description of each
    /// parameter (after attribute stripping) and return type seen on the
    /// declaration. ``classify(_:)`` is a lookup against this map, so each
    /// type's syntax tree is walked exactly once during ``init``.
    private let classifications: [String: ParameterClassification]

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
        self.classifications = Self.precomputeClassifications(
            declaration: declaration,
            genericParameters: genericParameters,
            typeConformanceProvider: typeConformanceProvider
        )
    }

    /// Walk every parameter type (after attribute stripping) and the return
    /// type once, producing a lookup table that ``classify(_:)`` can consult.
    ///
    /// Multiple parameters can share the same stripped type (e.g.
    /// `func foo(a: Int, b: Int)` or `func bar(x: T, y: T)`). The
    /// classification depends only on the type, so the second computation
    /// would be identical to the first and the duplicate is silently skipped.
    private static func precomputeClassifications(
        declaration: FunctionDeclSyntax,
        genericParameters: [String: GenericParameter],
        typeConformanceProvider: (String) -> TypeConformance
    ) -> [String: ParameterClassification] {
        var classifications: [String: ParameterClassification] = [:]
        let genericNames = Set(genericParameters.keys)
        let parameterTypes = declaration.signature.parameterClause.parameters.map {
            Self.strippingAttributes($0.type)
        }
        for type in parameterTypes + [declaration.signature.returnClause?.type].compactMap({ $0 }) {
            let key = type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            // Multiple parameters can share the same stripped type (e.g.
            // `func foo(a: Int, b: Int)` or `func bar(x: T, y: T)`). The
            // classification depends only on the type, so the second computation
            // would be identical to the first.
            if classifications[key] == nil {
                classifications[key] = computeClassification(
                    for: type,
                    genericParameters: genericParameters,
                    genericNames: genericNames,
                    typeConformanceProvider: typeConformanceProvider
                )
            }
        }
        return classifications
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
    ///
    /// Looks the type up in the precomputed ``classifications`` map. Strips
    /// `inout`/attribute decorations first, since callers may pass either the
    /// raw `parameter.type` or an already-stripped form. Falls back to an
    /// on-demand computation if the type wasn't seen at init time so the API
    /// stays total, but every current caller passes a type from the function
    /// declaration and hits the cache.
    package func classify(_ parameterType: TypeSyntax) -> ParameterClassification {
        let stripped = Self.strippingAttributes(parameterType)
        let key = stripped.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = classifications[key] {
            return cached
        }
        return Self.computeClassification(
            for: stripped,
            genericParameters: genericParameters,
            genericNames: Set(genericParameters.keys),
            typeConformanceProvider: typeConformanceProvider
        )
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

    /// Build a `GenericParameter` from a `some Constraint` type's constraint
    /// expression. The constraint may be a single identifier (`some Encodable`)
    /// or a protocol composition (`some Encodable & Sendable`).
    private static func opaqueGenericParameter(
        constraint: TypeSyntax,
        typeConformanceProvider: (String) -> TypeConformance
    ) -> GenericParameter {
        // Extract the protocol name list from the constraint.
        let protocols: [String]
        if let composition = constraint.as(CompositionTypeSyntax.self) {
            protocols = composition.elements.map { element in
                element.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            protocols = [
                constraint.description.trimmingCharacters(in: .whitespacesAndNewlines)
            ]
        }

        let storageType: String
        if protocols.isEmpty {
            storageType = "Any"
        } else {
            storageType = "any " + protocols.joined(separator: " & ")
        }

        let isEquatable =
            protocols.contains("Equatable")
            || protocols.contains("Hashable")
            || protocols.contains { proto in
                typeConformanceProvider(proto) != .neitherComparableNorEquatable
            }

        return GenericParameter(storageType: storageType, isEquatable: isEquatable)
    }

    /// Strip `inout` (and any other `AttributedTypeSyntax`) decoration from a
    /// parameter type so the underlying type can be classified and used as a
    /// dictionary key.
    private static func strippingAttributes(_ type: TypeSyntax) -> TypeSyntax {
        if let attributed = type.as(AttributedTypeSyntax.self) {
            return attributed.baseType
        }
        return type
    }

    /// Compute the classification for a single type. Called once per unique
    /// parameter/return type during ``init`` to populate the cache, and as a
    /// fallback from ``classify(_:)`` for types not seen at init time.
    ///
    /// Uses a single combined visitor pass to detect both `some` opaque types
    /// nested inside the type and references to known generic parameter names.
    private static func computeClassification(
        for type: TypeSyntax,
        genericParameters: [String: GenericParameter],
        genericNames: Set<String>,
        typeConformanceProvider: (String) -> TypeConformance
    ) -> ParameterClassification {
        // Top-level `some Constraint` is a direct opaque generic.
        //
        // `func foo(item: some Encodable & Sendable)` uses opaque type sugar
        // that the Swift compiler implicitly desugars to an explicit generic
        // parameter — but that desugaring happens *after* the macro runs, so
        // the function declaration the macro sees has no
        // `genericParameterClause` entry for it. We surface it here as a
        // synthetic generic parameter.
        if let opaque = type.as(SomeOrAnyTypeSyntax.self),
            opaque.someOrAnySpecifier.tokenKind == .keyword(.some)
        {
            return .directGeneric(
                opaqueGenericParameter(
                    constraint: opaque.constraint,
                    typeConformanceProvider: typeConformanceProvider
                )
            )
        }

        // Single walk that records both nested `some` opaques and any
        // references to declared generic parameter names.
        let analyzer = TypeAnalyzer(names: genericNames, viewMode: .sourceAccurate)
        analyzer.walk(Syntax(type))

        // Wrapped opaque, e.g. `Wrapper<some Constraint>` or `[some Constraint]`.
        if analyzer.foundOpaque {
            return .wrappedGeneric
        }

        // Direct match: parameter type is exactly a generic parameter name.
        let typeString = type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if let parameter = genericParameters[typeString] {
            return .directGeneric(parameter)
        }

        // Wrapped match: the type tree references a generic parameter name.
        if analyzer.foundGenericNameReference {
            return .wrappedGeneric
        }

        return .concrete
    }
}

// MARK: - SyntaxVisitor

/// Single-pass type-tree analyzer that records both:
/// - whether the tree contains a `some Constraint` opaque type, and
/// - whether the tree references any `IdentifierTypeSyntax` whose name is in
///   the supplied generic-parameter-name set.
///
/// Skips the trailing `name` of `MemberTypeSyntax` so qualified member
/// references like `MyModule.T` or `Optional<Foo.T>` are not treated as
/// references to a generic parameter `T` declared on the function — only the
/// `baseType` chain (and any generic argument clauses) is descended.
private final class TypeAnalyzer: SyntaxVisitor {
    let names: Set<String>
    var foundOpaque = false
    var foundGenericNameReference = false

    init(names: Set<String>, viewMode: SyntaxTreeViewMode) {
        self.names = names
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: SomeOrAnyTypeSyntax) -> SyntaxVisitorContinueKind {
        if node.someOrAnySpecifier.tokenKind == .keyword(.some) {
            self.foundOpaque = true
        }
        return .visitChildren
    }

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        if self.names.contains(node.name.text) {
            self.foundGenericNameReference = true
        }
        return .visitChildren
    }

    override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
        self.walk(node.baseType)
        if let genericArgumentClause = node.genericArgumentClause {
            self.walk(genericArgumentClause)
        }
        return .skipChildren
    }
}
