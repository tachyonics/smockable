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
//  GenericContextTests.swift
//  SmockMacroTests
//

import SwiftSyntax
import Testing

@testable import SmockMacro

/// Direct unit tests for `GenericContext`. These exercise the constraint-parsing
/// logic and parameter classification without going through the `@Smock` macro
/// expansion machinery, so they're cheap to write and read.
struct GenericContextTests {

    // MARK: - Helpers

    /// Build a `FunctionDeclSyntax` from source text. Throws if parsing fails.
    private func makeFunction(_ source: String) throws -> FunctionDeclSyntax {
        try FunctionDeclSyntax("\(raw: source)")
    }

    /// Build a `GenericContext` from a function declaration source string.
    /// The default conformance provider treats no types as Equatable so that
    /// allowlist-based equatability is opt-in per-test.
    private func context(
        _ source: String,
        equatableTypes: Set<String> = []
    ) throws -> GenericContext {
        let function = try makeFunction(source)
        return GenericContext(
            functionDeclaration: function,
            typeConformanceProvider: { type in
                equatableTypes.contains(type) ? .onlyEquatable : .neitherComparableNorEquatable
            }
        )
    }

    /// Find a parameter on the function by its label, used to drive `classify`.
    private func parameterType(in source: String, label: String) throws -> TypeSyntax {
        let function = try makeFunction(source)
        let parameter = try #require(
            function.signature.parameterClause.parameters.first(where: { $0.firstName.text == label }),
            "No parameter named \(label) in: \(source)"
        )
        return parameter.type
    }

    // MARK: - Empty context

    @Test
    func emptyContext() {
        let context = GenericContext.empty
        #expect(context.parameters.isEmpty)
        #expect(context.classify("String") == .concrete)
    }

    @Test
    func nonGenericFunctionProducesEmptyContext() throws {
        let context = try self.context("func foo(item: String) -> Int")
        #expect(context.parameters.isEmpty)
    }

    // MARK: - Parsing inline constraints

    @Test
    func singleGenericWithSingleConstraint() throws {
        let context = try self.context("func foo<T: Encodable>(item: T)")

        #expect(context.parameters.count == 1)
        let t = try #require(context.parameters["T"])
        #expect(t.storageType == "any Encodable")
        #expect(t.isEquatable == false)
    }

    @Test
    func singleGenericWithComposedConstraint() throws {
        let context = try self.context("func foo<T: Encodable & Sendable>(item: T)")

        let t = try #require(context.parameters["T"])
        #expect(t.storageType == "any Encodable & Sendable")
        #expect(t.isEquatable == false)
    }

    @Test
    func unconstrainedGenericProducesAnyStorage() throws {
        let context = try self.context("func foo<T>(item: T)")

        let t = try #require(context.parameters["T"])
        #expect(t.storageType == "Any")
        #expect(t.isEquatable == false)
    }

    @Test
    func multipleGenericParameters() throws {
        let context = try self.context(
            "func foo<T: Encodable, U: Sendable>(a: T, b: U)"
        )

        #expect(context.parameters.count == 2)
        #expect(context.parameters["T"]?.storageType == "any Encodable")
        #expect(context.parameters["U"]?.storageType == "any Sendable")
    }

    // MARK: - Where clauses

    @Test
    func whereClauseAddsConstraintsToInlineParameters() throws {
        let context = try self.context(
            "func foo<T: Encodable>(item: T) where T: Sendable"
        )

        let t = try #require(context.parameters["T"])
        // Inline constraint comes first, then where clause appended.
        #expect(t.storageType == "any Encodable & Sendable")
    }

    @Test
    func whereClauseOnUnconstrainedGeneric() throws {
        let context = try self.context(
            "func foo<T>(item: T) where T: Encodable & Sendable"
        )

        let t = try #require(context.parameters["T"])
        #expect(t.storageType == "any Encodable & Sendable")
    }

    @Test
    func whereClauseConstraintsForMultipleGenerics() throws {
        let context = try self.context(
            "func foo<T, U>(a: T, b: U) where T: Encodable, U: Sendable"
        )

        #expect(context.parameters["T"]?.storageType == "any Encodable")
        #expect(context.parameters["U"]?.storageType == "any Sendable")
    }

    // MARK: - Equatability detection

    @Test
    func equatableConstraintMarksParameterAsEquatable() throws {
        let context = try self.context("func foo<T: Equatable>(item: T)")
        #expect(context.parameters["T"]?.isEquatable == true)
    }

    @Test
    func hashableConstraintMarksParameterAsEquatable() throws {
        // Hashable inherits from Equatable, so it counts.
        let context = try self.context("func foo<T: Hashable>(item: T)")
        #expect(context.parameters["T"]?.isEquatable == true)
    }

    @Test
    func equatableInComposedConstraint() throws {
        let context = try self.context(
            "func foo<T: Encodable & Equatable & Sendable>(item: T)"
        )
        #expect(context.parameters["T"]?.isEquatable == true)
    }

    @Test
    func nonEquatableConstraintIsNotEquatable() throws {
        let context = try self.context("func foo<T: Encodable & Sendable>(item: T)")
        #expect(context.parameters["T"]?.isEquatable == false)
    }

    @Test
    func equatableViaAdditionalEquatableTypesAllowlist() throws {
        let context = try self.context(
            "func foo<T: MyAllowlistedProtocol>(item: T)",
            equatableTypes: ["MyAllowlistedProtocol"]
        )
        #expect(context.parameters["T"]?.isEquatable == true)
    }

    @Test
    func equatableViaWhereClause() throws {
        let context = try self.context(
            "func foo<T: Encodable>(item: T) where T: Equatable"
        )
        #expect(context.parameters["T"]?.isEquatable == true)
    }

    // MARK: - Classification

    @Test
    func classifyDirectGenericParameter() throws {
        let source = "func foo<T: Encodable & Sendable>(item: T)"
        let context = try self.context(source)
        let type = try parameterType(in: source, label: "item")

        switch context.classify(type) {
        case .directGeneric(let info):
            #expect(info.storageType == "any Encodable & Sendable")
        default:
            Issue.record("Expected directGeneric, got \(context.classify(type))")
        }
    }

    @Test
    func classifyWrappedGenericParameter() throws {
        let source = "func foo<T: Sendable>(input: PutItemInput<T>)"
        let context = try self.context(source)
        let type = try parameterType(in: source, label: "input")

        #expect(context.classify(type) == .wrappedGeneric)
    }

    @Test
    func classifyOptionalGenericIsWrapped() throws {
        let source = "func foo<T: Sendable>(item: T?)"
        let context = try self.context(source)
        let type = try parameterType(in: source, label: "item")

        #expect(context.classify(type) == .wrappedGeneric)
    }

    @Test
    func classifyArrayOfGenericIsWrapped() throws {
        let source = "func foo<T: Sendable>(items: [T])"
        let context = try self.context(source)
        let type = try parameterType(in: source, label: "items")

        #expect(context.classify(type) == .wrappedGeneric)
    }

    @Test
    func classifyConcreteParameter() throws {
        let source = "func foo<T: Sendable>(item: T, name: String)"
        let context = try self.context(source)
        let type = try parameterType(in: source, label: "name")

        #expect(context.classify(type) == .concrete)
    }

    @Test
    func classifyDoesNotMatchSubstringOfLongerIdentifier() throws {
        // The generic parameter is `T`. A type called `Tree` should NOT classify as
        // wrappedGeneric — `T` only appears as a substring of an unrelated identifier.
        let source = "func foo<T: Sendable>(item: T, tree: Tree)"
        let context = try self.context(source)
        let treeType = try parameterType(in: source, label: "tree")

        #expect(context.classify(treeType) == .concrete)
    }

    @Test
    func classifyMatchesGenericInsideNestedGenerics() throws {
        let source = "func foo<T: Sendable>(items: Dictionary<String, T>)"
        let context = try self.context(source)
        let type = try parameterType(in: source, label: "items")

        #expect(context.classify(type) == .wrappedGeneric)
    }

    @Test
    func classifyWithMultipleGenericsMatchesAnyOfThem() throws {
        let source = "func foo<T: Sendable, U: Sendable>(item: U)"
        let context = try self.context(source)
        let type = try parameterType(in: source, label: "item")

        switch context.classify(type) {
        case .directGeneric(let info):
            #expect(info.storageType == "any Sendable")
        default:
            Issue.record("Expected directGeneric for U")
        }
    }
}

// MARK: - Equatable conformance for ParameterClassification

extension GenericContext.ParameterClassification: Equatable {
    public static func == (
        lhs: GenericContext.ParameterClassification,
        rhs: GenericContext.ParameterClassification
    ) -> Bool {
        switch (lhs, rhs) {
        case (.concrete, .concrete), (.wrappedGeneric, .wrappedGeneric):
            return true
        case (.directGeneric(let l), .directGeneric(let r)):
            return l.storageType == r.storageType && l.isEquatable == r.isEquatable
        default:
            return false
        }
    }
}

extension GenericContext {
    /// Convenience for testing — classify a type by its source string.
    fileprivate func classify(_ source: String) -> ParameterClassification {
        let type = TypeSyntax(stringLiteral: source)
        return classify(type)
    }
}
