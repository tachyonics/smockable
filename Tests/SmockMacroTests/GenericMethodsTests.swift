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
