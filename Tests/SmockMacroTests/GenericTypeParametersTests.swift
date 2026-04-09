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
//  GenericTypeParametersTests.swift
//  SmockMacroTests
//

import Foundation
import Testing

@testable import Smockable

// MARK: - Test Types

/// A generic wrapper used to verify that the macro can parse generic type
/// parameters in function signatures.
public struct GenericBox<Value: Sendable>: Sendable {
    public let value: Value

    public init(value: Value) {
        self.value = value
    }
}

/// An equatable specialization of `GenericBox<Int>` that is explicitly
/// allowlisted via `additionalEquatableTypes`.
extension GenericBox: Equatable where Value: Equatable {}

@Smock(
    additionalEquatableTypes: [
        GenericBox<Int>.self
    ]
)
protocol GenericBoxService {
    /// Allowlisted specialization — `GenericBox<Int>` is in `additionalEquatableTypes`,
    /// so the parameter is treated as `Equatable` and exact-value matching works.
    func storeInt(_ box: GenericBox<Int>) async
    /// Non-allowlisted specialization — `GenericBox<String>` is *not* in
    /// `additionalEquatableTypes`, so the parameter is treated as non-Equatable
    /// and only `.any`/`.matching` matchers are available. The macro must
    /// successfully parse the generic type without crashing.
    func storeString(_ box: GenericBox<String>) async
}

// MARK: - Tests

struct GenericTypeParametersTests {

    @Test
    func allowlistedGenericSpecializationSupportsExactMatching() async {
        var expectations = MockGenericBoxService.Expectations()
        when(expectations.storeInt(GenericBox(value: 42)), complete: .withSuccess)

        let mock = MockGenericBoxService(expectations: expectations)
        await mock.storeInt(GenericBox(value: 42))

        verify(mock, times: 1).storeInt(GenericBox(value: 42))
    }

    @Test
    func nonAllowlistedGenericSpecializationCompilesAndUsesAnyMatcher() async {
        var expectations = MockGenericBoxService.Expectations()
        when(expectations.storeString(.any), complete: .withSuccess)

        let mock = MockGenericBoxService(expectations: expectations)
        await mock.storeString(GenericBox(value: "hello"))

        verify(mock, times: 1).storeString(.any)
    }
}
