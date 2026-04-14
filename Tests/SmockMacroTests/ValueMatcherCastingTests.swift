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
//  ValueMatcherCastingTests.swift
//  SmockMacroTests
//

import Foundation
import Testing

@testable import Smockable

/// Direct unit tests for the `matchingAs` / `exactAs` casting helpers on
/// `ExistentialValueMatcher`. These exercise the helpers (and especially the
/// cast-failure branches) without going through `@Smock` macro plumbing.
struct ValueMatcherCastingTests {

    private struct Payload: Equatable, Encodable, Hashable, Sendable {
        let id: String
    }

    // Class hierarchy used to exercise `ExistentialValueMatcher.matchingAs`
    // with a storage type that can hold runtime-distinguishable sub-values.
    private class Animal: @unchecked Sendable, Equatable {
        let name: String
        init(name: String) { self.name = name }
        static func == (lhs: Animal, rhs: Animal) -> Bool { lhs.name == rhs.name }
    }
    private final class Dog: Animal {}
    private final class Cat: Animal {}

    // MARK: - ExistentialValueMatcher with any Sendable (case 2 / wrapped generic)

    @Test
    func wrappedGenericMatchingAsHits() {
        let matcher = ExistentialValueMatcher<any Sendable>.matchingAs(Payload.self) { payload in
            payload.id == "abc"
        }
        #expect(matcher.matches(Payload(id: "abc")))
        #expect(!matcher.matches(Payload(id: "xyz")))
    }

    @Test
    func wrappedGenericMatchingAsCastFailureReturnsFalse() {
        let matcher = ExistentialValueMatcher<any Sendable>.matchingAs(Payload.self) { _ in true }
        #expect(!matcher.matches("not a payload"))
    }

    @Test
    func wrappedGenericExactAsHits() {
        let expected = Payload(id: "abc")
        let matcher = ExistentialValueMatcher<any Sendable>.exactAs(expected)
        #expect(matcher.matches(Payload(id: "abc")))
        #expect(!matcher.matches(Payload(id: "xyz")))
    }

    @Test
    func wrappedGenericExactAsCastFailureReturnsFalse() {
        let matcher = ExistentialValueMatcher<any Sendable>.exactAs(Payload(id: "abc"))
        #expect(!matcher.matches("not a payload"))
    }

    // MARK: - ExistentialValueMatcher with constraint existential (case 1 / direct generic)

    @Test
    func directGenericMatchingAsHits() {
        let matcher = ExistentialValueMatcher<any Encodable & Sendable>.matchingAs(Payload.self) { payload in
            payload.id == "abc"
        }
        #expect(matcher.matches(Payload(id: "abc")))
        #expect(!matcher.matches(Payload(id: "xyz")))
    }

    @Test
    func directGenericMatchingAsCastFailureReturnsFalse() {
        let matcher = ExistentialValueMatcher<any Encodable & Sendable>.matchingAs(Payload.self) { _ in true }
        #expect(!matcher.matches("not a payload"))
    }

    @Test
    func directGenericExactAsHits() {
        let expected = Payload(id: "abc")
        let matcher = ExistentialValueMatcher<any Encodable & Sendable>.exactAs(expected)
        #expect(matcher.matches(Payload(id: "abc")))
        #expect(!matcher.matches(Payload(id: "xyz")))
    }

    @Test
    func directGenericExactAsCastFailureReturnsFalse() {
        let matcher = ExistentialValueMatcher<any Encodable & Sendable>.exactAs(Payload(id: "abc"))
        #expect(!matcher.matches("not a payload"))
    }

    // MARK: - ExistentialValueMatcher with concrete base type (class hierarchy)

    @Test
    func classHierarchyMatchingAsHits() {
        let matcher = ExistentialValueMatcher<Animal>.matchingAs(Dog.self) { dog in
            dog.name == "rex"
        }
        #expect(matcher.matches(Dog(name: "rex")))
        #expect(!matcher.matches(Dog(name: "fido")))
    }

    @Test
    func classHierarchyMatchingAsCastFailureReturnsFalse() {
        let matcher = ExistentialValueMatcher<Animal>.matchingAs(Dog.self) { _ in true }
        #expect(!matcher.matches(Cat(name: "whiskers")))
    }
}
