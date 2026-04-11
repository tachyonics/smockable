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

/// Direct unit tests for the `matchingAs` / `exactAs` casting helpers on the
/// type-erased matcher types. These exercise the helpers (and especially the
/// cast-failure branches) without going through `@Smock` macro plumbing.
struct ValueMatcherCastingTests {

    private struct Payload: Equatable, Encodable, Hashable, Sendable {
        let id: String
    }

    // Class hierarchy used to exercise `OnlyEquatableValueMatcher.matchingAs`,
    // since `T` must be `Equatable & Sendable` and we need a single storage
    // type that can hold runtime-distinguishable sub-values.
    private class Animal: @unchecked Sendable, Equatable {
        let name: String
        init(name: String) { self.name = name }
        static func == (lhs: Animal, rhs: Animal) -> Bool { lhs.name == rhs.name }
    }
    private final class Dog: Animal {}
    private final class Cat: Animal {}

    // MARK: - ErasedValueMatcher

    @Test
    func erasedMatchingAsHits() {
        let matcher = ErasedValueMatcher.matchingAs(Payload.self) { payload in
            payload.id == "abc"
        }
        #expect(matcher.matches(Payload(id: "abc")))
        #expect(!matcher.matches(Payload(id: "xyz")))
    }

    @Test
    func erasedMatchingAsCastFailureReturnsFalse() {
        let matcher = ErasedValueMatcher.matchingAs(Payload.self) { _ in true }
        // Wrong concrete type — cast guard returns false without calling the closure.
        #expect(!matcher.matches("not a payload"))
    }

    @Test
    func erasedExactAsHits() {
        let expected = Payload(id: "abc")
        let matcher = ErasedValueMatcher.exactAs(expected)
        #expect(matcher.matches(Payload(id: "abc")))
        #expect(!matcher.matches(Payload(id: "xyz")))
    }

    @Test
    func erasedExactAsCastFailureReturnsFalse() {
        let matcher = ErasedValueMatcher.exactAs(Payload(id: "abc"))
        #expect(!matcher.matches("not a payload"))
    }

    // MARK: - NonComparableValueMatcher

    @Test
    func nonComparableMatchingAsHits() {
        let matcher = NonComparableValueMatcher<any Encodable & Sendable>.matchingAs(Payload.self) { payload in
            payload.id == "abc"
        }
        #expect(matcher.matches(Payload(id: "abc")))
        #expect(!matcher.matches(Payload(id: "xyz")))
    }

    @Test
    func nonComparableMatchingAsCastFailureReturnsFalse() {
        let matcher = NonComparableValueMatcher<any Encodable & Sendable>.matchingAs(Payload.self) { _ in true }
        #expect(!matcher.matches("not a payload"))
    }

    @Test
    func nonComparableExactAsHits() {
        let expected = Payload(id: "abc")
        let matcher = NonComparableValueMatcher<any Encodable & Sendable>.exactAs(expected)
        #expect(matcher.matches(Payload(id: "abc")))
        #expect(!matcher.matches(Payload(id: "xyz")))
    }

    @Test
    func nonComparableExactAsCastFailureReturnsFalse() {
        let matcher = NonComparableValueMatcher<any Encodable & Sendable>.exactAs(Payload(id: "abc"))
        #expect(!matcher.matches("not a payload"))
    }

    // MARK: - OnlyEquatableValueMatcher

    // `any Equatable` isn't a usable storage type because Equatable's Self
    // requirements mean the existential doesn't itself conform to Equatable,
    // and `AnyHashable` is explicitly non-Sendable. A small class hierarchy
    // gives us a single `Equatable & Sendable` storage type whose values can
    // be downcast to multiple distinct sub-types at runtime.
    @Test
    func onlyEquatableMatchingAsHits() {
        let matcher = OnlyEquatableValueMatcher<Animal>.matchingAs(Dog.self) { dog in
            dog.name == "rex"
        }
        #expect(matcher.matches(Dog(name: "rex")))
        #expect(!matcher.matches(Dog(name: "fido")))
    }

    @Test
    func onlyEquatableMatchingAsCastFailureReturnsFalse() {
        let matcher = OnlyEquatableValueMatcher<Animal>.matchingAs(Dog.self) { _ in true }
        #expect(!matcher.matches(Cat(name: "whiskers")))
    }
}
