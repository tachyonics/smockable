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
protocol WrappedGenericReturnService {
    /// Wrapped generic return type: returns a wrapper containing the generic param.
    func produce<T: Sendable>(label: String) async -> GenericWrapper<T>
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
}
