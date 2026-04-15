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
//  MockableFunctionTests.swift
//  SmockMacroTests
//

import SwiftSyntax
import Testing

@testable import SmockMacro

/// Direct unit tests for `MockableFunction`. These exercise the constraint-parsing
/// logic and parameter classification without going through the `@Smock` macro
/// expansion machinery, so they're cheap to write and read.
struct MockableFunctionTests {

    // MARK: - Helpers

    /// Build a `FunctionDeclSyntax` from source text. Throws if parsing fails.
    private func makeDeclaration(_ source: String) throws -> FunctionDeclSyntax {
        try FunctionDeclSyntax("\(raw: source)")
    }

    /// Build a `MockableFunction` from a function declaration source string.
    /// The default conformance provider treats no types as Equatable so that
    /// allowlist-based equatability is opt-in per-test.
    private func mockableFunction(
        _ source: String,
        equatableTypes: Set<String> = []
    ) throws -> MockableFunction {
        let declaration = try makeDeclaration(source)
        return MockableFunction(
            declaration: declaration,
            typeConformanceProvider: { type in
                equatableTypes.contains(type) ? .onlyEquatable : .neitherComparableNorEquatable
            }
        )
    }

    /// Find a parameter on the function by its label, used to drive `classify`.
    private func parameterType(in source: String, label: String) throws -> TypeSyntax {
        let declaration = try makeDeclaration(source)
        let parameter = try #require(
            declaration.signature.parameterClause.parameters.first(where: { $0.firstName.text == label }),
            "No parameter named \(label) in: \(source)"
        )
        return parameter.type
    }

    // MARK: - Empty / non-generic

    @Test
    func nonGenericFunctionProducesNoGenericParameters() throws {
        let function = try mockableFunction("func foo(item: String) -> Int")
        #expect(function.genericParameters.isEmpty)
    }

    // MARK: - Parsing inline constraints

    @Test
    func singleGenericWithSingleConstraint() throws {
        let function = try mockableFunction("func foo<T: Encodable>(item: T)")

        #expect(function.genericParameters.count == 1)
        let t = try #require(function.genericParameters["T"])
        #expect(t.storageType == "any Encodable")
        #expect(t.isEquatable == false)
    }

    @Test
    func singleGenericWithComposedConstraint() throws {
        let function = try mockableFunction("func foo<T: Encodable & Sendable>(item: T)")

        let t = try #require(function.genericParameters["T"])
        #expect(t.storageType == "any Encodable & Sendable")
        #expect(t.isEquatable == false)
    }

    @Test
    func unconstrainedGenericProducesAnyStorage() throws {
        let function = try mockableFunction("func foo<T>(item: T)")

        let t = try #require(function.genericParameters["T"])
        #expect(t.storageType == "Any")
        #expect(t.isEquatable == false)
    }

    @Test
    func multipleGenericParameters() throws {
        let function = try mockableFunction(
            "func foo<T: Encodable, U: Sendable>(a: T, b: U)"
        )

        #expect(function.genericParameters.count == 2)
        #expect(function.genericParameters["T"]?.storageType == "any Encodable")
        #expect(function.genericParameters["U"]?.storageType == "any Sendable")
    }

    // MARK: - Where clauses

    @Test
    func whereClauseAddsConstraintsToInlineParameters() throws {
        let function = try mockableFunction(
            "func foo<T: Encodable>(item: T) where T: Sendable"
        )

        let t = try #require(function.genericParameters["T"])
        // Inline constraint comes first, then where clause appended.
        #expect(t.storageType == "any Encodable & Sendable")
    }

    @Test
    func whereClauseOnUnconstrainedGeneric() throws {
        let function = try mockableFunction(
            "func foo<T>(item: T) where T: Encodable & Sendable"
        )

        let t = try #require(function.genericParameters["T"])
        #expect(t.storageType == "any Encodable & Sendable")
    }

    @Test
    func whereClauseConstraintsForMultipleGenerics() throws {
        let function = try mockableFunction(
            "func foo<T, U>(a: T, b: U) where T: Encodable, U: Sendable"
        )

        #expect(function.genericParameters["T"]?.storageType == "any Encodable")
        #expect(function.genericParameters["U"]?.storageType == "any Sendable")
    }

    // MARK: - Equatability detection

    @Test
    func equatableConstraintMarksParameterAsEquatable() throws {
        let function = try mockableFunction("func foo<T: Equatable>(item: T)")
        #expect(function.genericParameters["T"]?.isEquatable == true)
    }

    @Test
    func hashableConstraintMarksParameterAsEquatable() throws {
        // Hashable inherits from Equatable, so it counts.
        let function = try mockableFunction("func foo<T: Hashable>(item: T)")
        #expect(function.genericParameters["T"]?.isEquatable == true)
    }

    @Test
    func equatableInComposedConstraint() throws {
        let function = try mockableFunction(
            "func foo<T: Encodable & Equatable & Sendable>(item: T)"
        )
        #expect(function.genericParameters["T"]?.isEquatable == true)
    }

    @Test
    func nonEquatableConstraintIsNotEquatable() throws {
        let function = try mockableFunction("func foo<T: Encodable & Sendable>(item: T)")
        #expect(function.genericParameters["T"]?.isEquatable == false)
    }

    @Test
    func equatableViaAdditionalEquatableTypesAllowlist() throws {
        let function = try mockableFunction(
            "func foo<T: MyAllowlistedProtocol>(item: T)",
            equatableTypes: ["MyAllowlistedProtocol"]
        )
        #expect(function.genericParameters["T"]?.isEquatable == true)
    }

    @Test
    func equatableViaWhereClause() throws {
        let function = try mockableFunction(
            "func foo<T: Encodable>(item: T) where T: Equatable"
        )
        #expect(function.genericParameters["T"]?.isEquatable == true)
    }

    // MARK: - Classification

    @Test
    func classifyDirectGenericParameter() throws {
        let source = "func foo<T: Encodable & Sendable>(item: T)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "item")

        let classification = function.classify(type)
        switch classification {
        case .directGeneric(let info):
            #expect(info.storageType == "any Encodable & Sendable")
        default:
            Issue.record("Expected directGeneric, got \(classification)")
        }
    }

    @Test
    func classifyWrappedGenericParameter() throws {
        let source = "func foo<T: Sendable>(input: PutItemInput<T>)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "input")

        #expect(function.classify(type) == .wrappedGeneric)
    }

    @Test
    func classifyOptionalGenericIsWrapped() throws {
        let source = "func foo<T: Sendable>(item: T?)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "item")

        #expect(function.classify(type) == .wrappedGeneric)
    }

    @Test
    func classifyArrayOfGenericIsWrapped() throws {
        let source = "func foo<T: Sendable>(items: [T])"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "items")

        #expect(function.classify(type) == .wrappedGeneric)
    }

    @Test
    func classifyConcreteParameter() throws {
        let source = "func foo<T: Sendable>(item: T, name: String)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "name")

        #expect(function.classify(type) == .concrete)
    }

    @Test
    func classifyDoesNotMatchSubstringOfLongerIdentifier() throws {
        // The generic parameter is `T`. A type called `Tree` should NOT classify as
        // wrappedGeneric — `T` only appears as a substring of an unrelated identifier.
        let source = "func foo<T: Sendable>(item: T, tree: Tree)"
        let function = try mockableFunction(source)
        let treeType = try parameterType(in: source, label: "tree")

        #expect(function.classify(treeType) == .concrete)
    }

    @Test
    func classifyMatchesGenericInsideNestedGenerics() throws {
        let source = "func foo<T: Sendable>(items: Dictionary<String, T>)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "items")

        #expect(function.classify(type) == .wrappedGeneric)
    }

    @Test
    func classifyWithMultipleGenericsMatchesAnyOfThem() throws {
        let source = "func foo<T: Sendable, U: Sendable>(item: U)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "item")

        let classification = function.classify(type)
        switch classification {
        case .directGeneric(let info):
            #expect(info.storageType == "any Sendable")
        default:
            Issue.record("Expected directGeneric, got \(classification)")
        }
    }

    // MARK: - Type erasure helpers

    @Test
    func erasedTypeStringForDirectGenericReturnsConstraintExistential() throws {
        let source = "func foo<T: Encodable & Sendable>(item: T)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "item")

        #expect(function.erasedTypeString(for: type) == "any Encodable & Sendable")
    }

    @Test
    func erasedTypeStringForWrappedGenericReturnsAnySendable() throws {
        let source = "func foo<T: Sendable>(input: PutItemInput<T>)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "input")

        #expect(function.erasedTypeString(for: type) == "any Sendable")
    }

    @Test
    func erasedTypeStringForConcreteTypeReturnsTypeUnchanged() throws {
        let source = "func foo<T: Sendable>(item: T, name: String)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "name")

        #expect(function.erasedTypeString(for: type) == "String")
    }

    @Test
    func erasedTypeStringForUnconstrainedGenericReturnsAny() throws {
        let source = "func foo<T>(item: T)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "item")

        #expect(function.erasedTypeString(for: type) == "Any")
    }

    @Test
    func erasedTypeForDirectGenericReturnsExistentialIdentifier() throws {
        let source = "func foo<T: Encodable & Sendable>(item: T)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "item")

        let erased = function.erasedType(for: type)
        #expect(
            erased.description.trimmingCharacters(in: .whitespacesAndNewlines)
                == "any Encodable & Sendable"
        )
    }

    @Test
    func erasedTypeForWrappedGenericReturnsAnySendable() throws {
        let source = "func foo<T: Sendable>(input: PutItemInput<T>)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "input")

        let erased = function.erasedType(for: type)
        #expect(
            erased.description.trimmingCharacters(in: .whitespacesAndNewlines)
                == "any Sendable"
        )
    }

    @Test
    func erasedTypeForConcreteTypeReturnsOriginalSyntaxNode() throws {
        let source = "func foo<T: Sendable>(item: T, name: String)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "name")

        // Concrete types are returned as-is, not transformed.
        let erased = function.erasedType(for: type)
        #expect(
            erased.description.trimmingCharacters(in: .whitespacesAndNewlines)
                == type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: - Member-type qualified-name false positives (item 2)

    @Test
    func classifyDoesNotMatchGenericNameAsMemberOfQualifiedType() throws {
        // `Outer.T` mentions a top-level type named `T` only as a *member*
        // of `Outer`. The function's generic parameter `T` should not be
        // treated as referenced here — the parameter is concrete.
        let source = "func foo<T: Sendable>(item: T, holder: Outer.T)"
        let function = try mockableFunction(source)
        let holderType = try parameterType(in: source, label: "holder")

        #expect(function.classify(holderType) == .concrete)
    }

    @Test
    func classifyDoesNotMatchGenericNameAsGenericMemberOfQualifiedType() throws {
        // `Outer.T<Int>` is a member type lookup with a generic argument; it
        // should not match the function's generic parameter `T`.
        let source = "func foo<T: Sendable>(item: T, holder: Outer.T<Int>)"
        let function = try mockableFunction(source)
        let holderType = try parameterType(in: source, label: "holder")

        #expect(function.classify(holderType) == .concrete)
    }

    @Test
    func classifyDoesNotMatchGenericNameInsideOptionalQualifiedType() throws {
        // `Optional<Foo.T>` should not match `T` either.
        let source = "func foo<T: Sendable>(item: T, holder: Optional<Foo.T>)"
        let function = try mockableFunction(source)
        let holderType = try parameterType(in: source, label: "holder")

        #expect(function.classify(holderType) == .concrete)
    }

    @Test
    func classifyMatchesGenericReferenceInBaseTypeOfMemberAccess() throws {
        // `T.AssociatedType` references the function's generic parameter
        // `T` as the base of a member access — this *should* still classify
        // as wrappedGeneric.
        let source = "func foo<T: Sendable>(item: T.AssociatedType)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "item")

        #expect(function.classify(type) == .wrappedGeneric)
    }

    // MARK: - Opaque `some` parameters (item 3)

    @Test
    func classifyDirectOpaqueParameterIsDirectGeneric() throws {
        let source = "func foo(item: some Encodable & Sendable)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "item")

        let classification = function.classify(type)
        switch classification {
        case .directGeneric(let info):
            #expect(info.storageType == "any Encodable & Sendable")
            #expect(info.isEquatable == false)
        default:
            Issue.record("Expected directGeneric, got \(classification)")
        }
    }

    @Test
    func classifyDirectOpaqueWithSingleConstraintIsDirectGeneric() throws {
        let source = "func foo(item: some Encodable)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "item")

        let classification = function.classify(type)
        switch classification {
        case .directGeneric(let info):
            #expect(info.storageType == "any Encodable")
        default:
            Issue.record("Expected directGeneric, got \(classification)")
        }
    }

    @Test
    func classifyWrappedOpaqueParameterIsWrappedGeneric() throws {
        let source = "func foo(input: PutItemInput<some Encodable & Sendable>)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "input")

        #expect(function.classify(type) == .wrappedGeneric)
    }

    @Test
    func classifyOptionalOpaqueIsWrapped() throws {
        let source = "func foo(item: (some Sendable)?)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "item")

        #expect(function.classify(type) == .wrappedGeneric)
    }

    @Test
    func classifyArrayOfOpaqueIsWrapped() throws {
        let source = "func foo(items: [some Sendable])"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "items")

        #expect(function.classify(type) == .wrappedGeneric)
    }

    @Test
    func classifyMixedExplicitAndOpaqueGenerics() throws {
        let source = "func foo<T: Sendable>(named: T, item: some Encodable & Sendable)"
        let function = try mockableFunction(source)

        let namedType = try parameterType(in: source, label: "named")
        let namedClassification = function.classify(namedType)
        switch namedClassification {
        case .directGeneric(let info):
            #expect(info.storageType == "any Sendable")
        default:
            Issue.record("Expected directGeneric, got \(namedClassification)")
        }

        let itemType = try parameterType(in: source, label: "item")
        let itemClassification = function.classify(itemType)
        switch itemClassification {
        case .directGeneric(let info):
            #expect(info.storageType == "any Encodable & Sendable")
        default:
            Issue.record("Expected directGeneric, got \(itemClassification)")
        }
    }

    @Test
    func classifyOpaqueIsEquatableForEquatableConstraint() throws {
        let source = "func foo(item: some Equatable & Sendable)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "item")

        let classification = function.classify(type)
        switch classification {
        case .directGeneric(let info):
            #expect(info.isEquatable == true)
        default:
            Issue.record("Expected directGeneric, got \(classification)")
        }
    }

    @Test
    func classifyOpaqueRespectsAdditionalEquatableTypesAllowlist() throws {
        let source = "func foo(item: some MyAllowlistedProtocol & Sendable)"
        let function = try mockableFunction(
            source,
            equatableTypes: ["MyAllowlistedProtocol"]
        )
        let type = try parameterType(in: source, label: "item")

        let classification = function.classify(type)
        switch classification {
        case .directGeneric(let info):
            #expect(info.isEquatable == true)
        default:
            Issue.record("Expected directGeneric, got \(classification)")
        }
    }

    @Test
    func classifyAnyExistentialIsConcrete() throws {
        // `any Encodable` is an existential, not a reference to a generic
        // parameter, so it should classify as .concrete.
        let source = "func foo(item: any Encodable)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "item")

        #expect(function.classify(type) == .concrete)
    }

    @Test
    func erasedTypeStringForDirectOpaqueReturnsConstraintExistential() throws {
        let source = "func foo(item: some Encodable & Sendable)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "item")

        #expect(function.erasedTypeString(for: type) == "any Encodable & Sendable")
    }

    @Test
    func erasedTypeStringForWrappedOpaqueReturnsAnySendable() throws {
        let source = "func foo(input: GenericWrapper<some Sendable>)"
        let function = try mockableFunction(source)
        let type = try parameterType(in: source, label: "input")

        #expect(function.erasedTypeString(for: type) == "any Sendable")
    }
    // MARK: - Sendable diagnostic

    @Test
    func genericParameterMissingSendableThrowsDiagnostic() throws {
        let protocolSource = """
            protocol Service {
                func process<T: Encodable>(item: T) async
            }
            """
        let protocolDecl = try ProtocolDeclSyntax("\(raw: protocolSource)")

        #expect(throws: SmockDiagnostic.self) {
            _ = try MockGenerator.declaration(for: protocolDecl)
        }
    }

    @Test
    func genericParameterWithSendableDoesNotThrow() throws {
        let protocolSource = """
            protocol Service {
                func process<T: Encodable & Sendable>(item: T) async
            }
            """
        let protocolDecl = try ProtocolDeclSyntax("\(raw: protocolSource)")

        #expect(throws: Never.self) {
            _ = try MockGenerator.declaration(for: protocolDecl)
        }
    }
}

// MARK: - Equatable conformance for ParameterClassification

extension MockableFunction.ParameterClassification: Equatable {
    public static func == (
        lhs: MockableFunction.ParameterClassification,
        rhs: MockableFunction.ParameterClassification
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

extension MockableFunction {
    /// Convenience for testing — classify a type by its source string.
    fileprivate func classify(_ source: String) -> ParameterClassification {
        let type = TypeSyntax(stringLiteral: source)
        return classify(type)
    }
}
