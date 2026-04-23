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
//  GenericMethodsTests.swift
//  SmockMacroTests
//

import Foundation
import Testing

@testable import Smockable

// MARK: - Test Types

public struct GenericWrapper<Value: Sendable>: Sendable {
    public let value: Value

    public init(value: Value) {
        self.value = value
    }
}

extension GenericWrapper: Equatable where Value: Equatable {}

public struct EquatablePayload: Equatable, Encodable, Sendable {
    public let id: String
    public let count: Int

    public init(id: String, count: Int) {
        self.id = id
        self.count = count
    }
}

// MARK: - Protocols

@Smock
protocol DirectGenericService {
    /// Direct generic: parameter type is exactly the generic param.
    func process<T: Encodable & Sendable>(item: T) async
}

@Smock
protocol WrappedGenericService {
    /// Wrapped generic: parameter type is a wrapper containing the generic param.
    func process<T: Sendable>(wrapper: GenericWrapper<T>) async
}

@Smock
protocol DirectGenericReturnService {
    /// Direct generic return type: returns the generic param itself.
    func produce<T: Encodable & Sendable>(label: String) async -> T
}

@Smock
protocol DirectOpaqueGenericService {
    /// Direct opaque generic: parameter is `some Constraint`. Equivalent to
    /// `func process<T: Encodable & Sendable>(item: T)`.
    func process(item: some Encodable & Sendable) async
}

@Smock
protocol WrappedOpaqueGenericService {
    /// Wrapped opaque generic: parameter wraps `some Constraint`. Equivalent
    /// to `func process<T: Sendable>(wrapper: GenericWrapper<T>)`.
    func process(wrapper: GenericWrapper<some Sendable>) async
}

@Smock
protocol WrappedGenericReturnService {
    /// Wrapped generic return type: returns a wrapper containing the generic param.
    func produce<T: Sendable>(label: String) async -> GenericWrapper<T>
}

@Smock
protocol EquatableDirectGenericService {
    /// Direct generic with Equatable constraint — enables the typed `.exact` form.
    func process<T: Equatable & Sendable>(item: T) async
    /// Direct generic with Hashable constraint — Hashable implies Equatable.
    func consume<T: Hashable & Sendable>(key: T) async
}

@Smock
protocol EquatableDirectOpaqueGenericService {
    /// Direct opaque generic with Equatable constraint.
    func process(item: some Equatable & Sendable) async
}

@Smock
protocol MixedEquatableDirectGenericService {
    /// Two direct generics, one Equatable and one not — verifies the exact form
    /// is emitted per-parameter, independently.
    func process<T: Equatable & Sendable, U: Encodable & Sendable>(
        equatable: T,
        other: U
    ) async
}

// MARK: - Tests

struct GenericMethodsTests {

    @Test
    func directGenericWithAnyMatcher() async {
        var expectations = MockDirectGenericService.Expectations()
        when(expectations.process(item: .any), times: 2, complete: .withSuccess)

        let mock = MockDirectGenericService(expectations: expectations)
        await mock.process(item: "hello")
        await mock.process(item: 42)

        verify(mock, times: 2).process(item: .any)
    }

    @Test
    func directGenericWithMatchingClosure() async {
        var expectations = MockDirectGenericService.Expectations()
        when(
            expectations.process(
                item: .matching { (item: any Encodable & Sendable) in
                    (item as? String) == "hello"
                }
            ),
            complete: .withSuccess
        )

        let mock = MockDirectGenericService(expectations: expectations)
        await mock.process(item: "hello")

        verify(mock, times: 1).process(item: .any)
    }

    @Test
    func wrappedGenericWithAnyMatcher() async {
        var expectations = MockWrappedGenericService.Expectations()
        when(expectations.process(wrapper: .any), times: 2, complete: .withSuccess)

        let mock = MockWrappedGenericService(expectations: expectations)
        await mock.process(wrapper: GenericWrapper(value: 1))
        await mock.process(wrapper: GenericWrapper(value: "hello"))

        verify(mock, times: 2).process(wrapper: .any)
    }

    @Test
    func wrappedGenericWithMatchingClosure() async {
        var expectations = MockWrappedGenericService.Expectations()
        when(
            expectations.process(
                wrapper: .matching { (anyWrapper: Any) in
                    (anyWrapper as? GenericWrapper<Int>)?.value == 42
                }
            ),
            complete: .withSuccess
        )

        let mock = MockWrappedGenericService(expectations: expectations)
        await mock.process(wrapper: GenericWrapper(value: 42))

        verify(mock, times: 1).process(wrapper: .any)
    }

    @Test
    func directGenericWithMatchingAs() async {
        var expectations = MockDirectGenericService.Expectations()
        when(
            expectations.process(
                item: .matchingAs(EquatablePayload.self) { payload in
                    payload.id == "abc" && payload.count == 3
                }
            ),
            complete: .withSuccess
        )

        let mock = MockDirectGenericService(expectations: expectations)
        await mock.process(item: EquatablePayload(id: "abc", count: 3))

        verify(mock, times: 1).process(item: .any)
    }

    @Test
    func directGenericMatchingAsCastFailureDoesNotMatch() async {
        var expectations = MockDirectGenericService.Expectations()
        when(
            expectations.process(
                item: .matchingAs(EquatablePayload.self) { _ in true }
            ),
            complete: .withSuccess
        )
        // Fallback for the wrong type so the call doesn't blow up.
        when(expectations.process(item: .any), complete: .withSuccess)

        let mock = MockDirectGenericService(expectations: expectations)
        await mock.process(item: "not a payload")

        // The matchingAs expectation should not have been consumed; it should
        // still be live and ready to match a real payload.
        await mock.process(item: EquatablePayload(id: "x", count: 1))
        verify(mock, times: 2).process(item: .any)
    }

    @Test
    func directGenericWithExactAs() async {
        var expectations = MockDirectGenericService.Expectations()
        let expected = EquatablePayload(id: "abc", count: 3)
        when(
            expectations.process(item: .exactAs(expected)),
            complete: .withSuccess
        )

        let mock = MockDirectGenericService(expectations: expectations)
        await mock.process(item: EquatablePayload(id: "abc", count: 3))

        verify(mock, times: 1).process(item: .any)
    }

    @Test
    func wrappedGenericWithMatchingAs() async {
        var expectations = MockWrappedGenericService.Expectations()
        when(
            expectations.process(
                wrapper: .matchingAs(GenericWrapper<Int>.self) { wrapper in
                    wrapper.value == 42
                }
            ),
            complete: .withSuccess
        )

        let mock = MockWrappedGenericService(expectations: expectations)
        await mock.process(wrapper: GenericWrapper(value: 42))

        verify(mock, times: 1).process(wrapper: .any)
    }

    @Test
    func wrappedGenericWithExactAs() async {
        var expectations = MockWrappedGenericService.Expectations()
        let expected = GenericWrapper(value: 42)
        when(
            expectations.process(wrapper: .exactAs(expected)),
            complete: .withSuccess
        )

        let mock = MockWrappedGenericService(expectations: expectations)
        await mock.process(wrapper: GenericWrapper(value: 42))

        verify(mock, times: 1).process(wrapper: .any)
    }

    @Test
    func directGenericReturnWithClosure() async {
        var expectations = MockDirectGenericReturnService.Expectations()
        // Use a closure-based response that returns a String. Swift implicitly
        // upcasts to the existential storage type `any Encodable & Sendable`.
        expectations.produce(label: .any).update(using: { _ in
            "the answer"
        })

        let mock = MockDirectGenericReturnService(expectations: expectations)
        // Caller specifies the concrete type via the binding.
        let result: String = await mock.produce(label: "x")
        #expect(result == "the answer")
    }

    @Test
    func wrappedGenericReturnWithClosure() async {
        var expectations = MockWrappedGenericReturnService.Expectations()
        // Closure returns a concrete GenericWrapper. Swift implicitly upcasts to
        // `any Sendable` (the storage type for wrapped generic returns).
        expectations.produce(label: .any).update(using: { _ in
            GenericWrapper(value: 99)
        })

        let mock = MockWrappedGenericReturnService(expectations: expectations)
        let result: GenericWrapper<Int> = await mock.produce(label: "x")
        #expect(result.value == 99)
    }

    // MARK: - Opaque `some` parameters
    //
    // These prove that `some Constraint` in parameter position generates the
    // same mock surface as the explicit-generic form. The opaque-aware
    // classification synthesizes an implicit generic parameter from each
    // `some` occurrence and routes it through the same case 1 / case 2
    // machinery as explicit generics.

    @Test
    func directOpaqueGenericWithAnyMatcher() async {
        var expectations = MockDirectOpaqueGenericService.Expectations()
        when(expectations.process(item: .any), times: 2, complete: .withSuccess)

        let mock = MockDirectOpaqueGenericService(expectations: expectations)
        await mock.process(item: "hello")
        await mock.process(item: 42)

        verify(mock, times: 2).process(item: .any)
    }

    @Test
    func directOpaqueGenericWithMatchingAs() async {
        var expectations = MockDirectOpaqueGenericService.Expectations()
        when(
            expectations.process(
                item: .matchingAs(EquatablePayload.self) { payload in
                    payload.id == "abc" && payload.count == 3
                }
            ),
            complete: .withSuccess
        )

        let mock = MockDirectOpaqueGenericService(expectations: expectations)
        await mock.process(item: EquatablePayload(id: "abc", count: 3))

        verify(mock, times: 1).process(item: .any)
    }

    @Test
    func directOpaqueGenericWithExactAs() async {
        var expectations = MockDirectOpaqueGenericService.Expectations()
        let expected = EquatablePayload(id: "abc", count: 3)
        when(
            expectations.process(item: .exactAs(expected)),
            complete: .withSuccess
        )

        let mock = MockDirectOpaqueGenericService(expectations: expectations)
        await mock.process(item: EquatablePayload(id: "abc", count: 3))

        verify(mock, times: 1).process(item: .any)
    }

    @Test
    func wrappedOpaqueGenericWithAnyMatcher() async {
        var expectations = MockWrappedOpaqueGenericService.Expectations()
        when(expectations.process(wrapper: .any), times: 2, complete: .withSuccess)

        let mock = MockWrappedOpaqueGenericService(expectations: expectations)
        await mock.process(wrapper: GenericWrapper(value: 1))
        await mock.process(wrapper: GenericWrapper(value: "hello"))

        verify(mock, times: 2).process(wrapper: .any)
    }

    @Test
    func wrappedOpaqueGenericWithMatchingAs() async {
        var expectations = MockWrappedOpaqueGenericService.Expectations()
        when(
            expectations.process(
                wrapper: .matchingAs(GenericWrapper<Int>.self) { wrapper in
                    wrapper.value == 42
                }
            ),
            complete: .withSuccess
        )

        let mock = MockWrappedOpaqueGenericService(expectations: expectations)
        await mock.process(wrapper: GenericWrapper(value: 42))

        verify(mock, times: 1).process(wrapper: .any)
    }

    @Test
    func wrappedOpaqueGenericWithExactAs() async {
        var expectations = MockWrappedOpaqueGenericService.Expectations()
        let expected = GenericWrapper(value: 42)
        when(
            expectations.process(wrapper: .exactAs(expected)),
            complete: .withSuccess
        )

        let mock = MockWrappedOpaqueGenericService(expectations: expectations)
        await mock.process(wrapper: GenericWrapper(value: 42))

        verify(mock, times: 1).process(wrapper: .any)
    }

    // MARK: - Direct generic `.exact` form (Equatable constraint)
    //
    // When a case-1 direct generic parameter's constraint includes Equatable
    // (or Hashable), the macro emits an additional overload that accepts a
    // concrete typed value and delegates to `.exactAs` internally. This lets
    // users write `when(expectations.process(item: "hello"))` instead of
    // `.exactAs("hello")`.

    @Test
    func equatableDirectGenericExactFormWhen() async {
        var expectations = MockEquatableDirectGenericService.Expectations()
        when(expectations.process(item: "hello"), complete: .withSuccess)

        let mock = MockEquatableDirectGenericService(expectations: expectations)
        await mock.process(item: "hello")

        verify(mock, times: 1).process(item: .any)
    }

    @Test
    func equatableDirectGenericExactFormVerify() async {
        var expectations = MockEquatableDirectGenericService.Expectations()
        when(expectations.process(item: .any), times: 2, complete: .withSuccess)

        let mock = MockEquatableDirectGenericService(expectations: expectations)
        await mock.process(item: "hello")
        await mock.process(item: 42)

        verify(mock, times: 1).process(item: "hello")
        verify(mock, times: 1).process(item: 42)
    }

    @Test
    func equatableDirectGenericExactDoesNotMatchDifferentConcreteType() async {
        // `.exact(item: "hello")` should cast to String at match time; a
        // non-String call with the same underlying representation shouldn't match.
        var expectations = MockEquatableDirectGenericService.Expectations()
        when(expectations.process(item: .any), complete: .withSuccess)

        let mock = MockEquatableDirectGenericService(expectations: expectations)
        await mock.process(item: 42)

        verify(mock, .never).process(item: "42")
        verify(mock, times: 1).process(item: 42)
    }

    @Test
    func hashableDirectGenericExactForm() async {
        var expectations = MockEquatableDirectGenericService.Expectations()
        when(expectations.consume(key: "k"), complete: .withSuccess)

        let mock = MockEquatableDirectGenericService(expectations: expectations)
        await mock.consume(key: "k")

        verify(mock, times: 1).consume(key: "k")
    }

    @Test
    func equatableDirectOpaqueGenericExactForm() async {
        var expectations = MockEquatableDirectOpaqueGenericService.Expectations()
        when(expectations.process(item: "hello"), complete: .withSuccess)

        let mock = MockEquatableDirectOpaqueGenericService(expectations: expectations)
        await mock.process(item: "hello")

        verify(mock, times: 1).process(item: "hello")
    }

    @Test
    func mixedEquatableDirectGenericExactFormOnEquatableParam() async {
        // The Equatable parameter gets an exact overload; the non-Equatable one
        // still requires an ExistentialValueMatcher. Both are independently
        // selectable, so we expect overloads covering (exact, matcher),
        // (matcher, matcher), and (matcher, matcher) combinations — the one
        // exercised here is (exact, .any).
        var expectations = MockMixedEquatableDirectGenericService.Expectations()
        when(
            expectations.process(equatable: "tag", other: .any),
            complete: .withSuccess
        )

        let mock = MockMixedEquatableDirectGenericService(expectations: expectations)
        await mock.process(equatable: "tag", other: 123)

        verify(mock, times: 1).process(equatable: "tag", other: .any)
    }
}
