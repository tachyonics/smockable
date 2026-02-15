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
//  NonComparableAssociatedTypesTests.swift
//  SmockMacroTests
//

import Foundation
import Testing

@testable import Smockable

// MARK: - Non-Comparable Test Data Structures

struct NonComparableData: Sendable {
    let content: String
    let metadata: [String: String]  // Changed to Sendable type

    init(content: String, metadata: [String: String] = [:]) {
        self.content = content
        self.metadata = metadata
    }
}

struct SimpleData: Sendable {
    let value: String
}

// MARK: - Protocol Definitions with Non-Comparable Associated Types

@Smock
protocol NonComparableRepository {
    associatedtype Entity: Sendable

    func save(_ entity: Entity) async throws
    func find(id: String) async throws -> Entity?
    func delete(id: String) async throws
}

@Smock
protocol MixedComparabilityStore {
    associatedtype ComparableItem: Sendable & Comparable
    associatedtype NonComparableItem: Sendable

    func storeComparable(_ item: ComparableItem) async throws
    func storeNonComparable(_ item: NonComparableItem) async throws
    func getComparable(id: String) async throws -> ComparableItem?
    func getNonComparable(id: String) async throws -> NonComparableItem?
}

@Smock
protocol DataProcessor {
    associatedtype Input: Sendable
    associatedtype Output: Sendable

    func process(_ input: Input) async throws -> Output
    func validate(_ input: Input) async -> Bool
}

struct NonComparableAssociatedTypesTests {

    // MARK: - Non-Comparable Associated Type Tests

    @Test
    func testNonComparableAssociatedTypeOnlySupportsAnyMatcher() async throws {
        var expectations = MockNonComparableRepository<NonComparableData>.Expectations()

        let testData = NonComparableData(content: "test", metadata: ["key": "value"])

        // Non-comparable associated types should only support .any matcher
        when(expectations.save(.any), complete: .withSuccess)
        when(expectations.find(id: .any), return: testData)
        when(expectations.delete(id: .any), complete: .withSuccess)

        let mockRepo = MockNonComparableRepository<NonComparableData>(expectations: expectations)

        try await mockRepo.save(testData)
        let foundData = try await mockRepo.find(id: "123")
        try await mockRepo.delete(id: "123")

        #expect(foundData?.content == "test")

        verify(mockRepo, times: 1).save(.any)
        verify(mockRepo, times: 1).find(id: .any)
        verify(mockRepo, times: 1).delete(id: .any)
    }

    @Test
    func testMixedComparabilityInSameProtocol() async throws {
        var expectations = MockMixedComparabilityStore<String, SimpleData>.Expectations()

        let comparableItem = "test-string"
        let nonComparableItem = SimpleData(value: "test-data")

        // Comparable associated type supports exact matching
        when(expectations.storeComparable("test-string"), complete: .withSuccess)
        when(expectations.storeComparable("A"..."Z"), complete: .withSuccess)  // Range matching
        when(expectations.getComparable(id: .any), return: comparableItem)

        // Non-comparable associated type only supports .any
        when(expectations.storeNonComparable(.any), complete: .withSuccess)
        when(expectations.getNonComparable(id: .any), return: nonComparableItem)

        let mockStore = MockMixedComparabilityStore<String, SimpleData>(expectations: expectations)

        // Test comparable item with exact match
        try await mockStore.storeComparable("test-string")

        // Test comparable item with range match
        try await mockStore.storeComparable("M")

        // Test non-comparable item (only .any works)
        try await mockStore.storeNonComparable(nonComparableItem)

        let retrievedComparable = try await mockStore.getComparable(id: "123")
        let retrievedNonComparable = try await mockStore.getNonComparable(id: "456")

        #expect(retrievedComparable == "test-string")
        #expect(retrievedNonComparable?.value == "test-data")
    }

    @Test
    func testUnconstrainedAssociatedTypes() async throws {
        var expectations = MockDataProcessor<String, Int>.Expectations()

        // Unconstrained associated types should only support .any matcher
        when(expectations.process(.any), return: 42)
        when(expectations.validate(.any), return: true)

        let mockProcessor = MockDataProcessor<String, Int>(expectations: expectations)

        let result = try await mockProcessor.process("input")
        let isValid = await mockProcessor.validate("input")

        #expect(result == 42)
        #expect(isValid == true)

        verify(mockProcessor, times: 1).process(.any)
        verify(mockProcessor, times: 1).validate(.any)
    }

    @Test
    func testNonComparableWithMultipleCalls() async throws {
        var expectations = MockNonComparableRepository<SimpleData>.Expectations()

        let data1 = SimpleData(value: "first")
        let data2 = SimpleData(value: "second")

        // Multiple expectations for non-comparable types
        when(expectations.save(.any), times: 2, complete: .withSuccess)
        when(expectations.find(id: .any), return: data1)
        when(expectations.find(id: .any), return: data2)

        let mockRepo = MockNonComparableRepository<SimpleData>(expectations: expectations)

        try await mockRepo.save(data1)
        try await mockRepo.save(data2)

        let found1 = try await mockRepo.find(id: "1")
        let found2 = try await mockRepo.find(id: "2")

        #expect(found1?.value == "first")
        #expect(found2?.value == "second")

        verify(mockRepo, times: 2).save(.any)
    }

    @Test
    func testNonComparableWithErrorHandling() async throws {
        var expectations = MockNonComparableRepository<NonComparableData>.Expectations()

        enum TestError: Error {
            case notFound
            case invalidData
        }

        // Error expectations work with non-comparable types
        when(expectations.save(.any), throw: TestError.invalidData)
        when(expectations.find(id: .any), throw: TestError.notFound)

        let mockRepo = MockNonComparableRepository<NonComparableData>(expectations: expectations)

        let testData = NonComparableData(content: "test")

        await #expect(throws: TestError.invalidData) {
            try await mockRepo.save(testData)
        }

        await #expect(throws: TestError.notFound) {
            try await mockRepo.find(id: "123")
        }
    }

    // MARK: - Unhappy Path Tests

    #if SMOCKABLE_UNHAPPY_PATH_TESTING
    @Test
    func testNonComparableAssociatedTypeVerificationFailures() async throws {
        try await expectVerificationFailures(messages: [
            "Expected save(_ entity: any) to be called exactly 3 times, but was called 2 times"
        ]) {
            var expectations = MockNonComparableRepository<NonComparableData>.Expectations()
            when(expectations.save(.any), times: .unbounded, complete: .withSuccess)

            let mockRepo = MockNonComparableRepository<NonComparableData>(expectations: expectations)

            // Call twice but verify 3 times - should fail
            try await mockRepo.save(NonComparableData(content: "first"))
            try await mockRepo.save(NonComparableData(content: "second"))

            verify(mockRepo, times: 3).save(.any)
        }
    }

    @Test
    func testMixedComparabilityVerificationFailures() async throws {
        try await expectVerificationFailures(messages: [
            "Expected storeComparable(_ item: any) to never be called, but was called 1 time",
            "Expected storeNonComparable(_ item: any) to be called at least 2 times, but was called 1 time",
        ]) {
            var expectations = MockMixedComparabilityStore<String, SimpleData>.Expectations()
            when(expectations.storeComparable(.any), complete: .withSuccess)
            when(expectations.storeNonComparable(.any), complete: .withSuccess)

            let mockStore = MockMixedComparabilityStore<String, SimpleData>(expectations: expectations)

            // Call each once
            try await mockStore.storeComparable("test")
            try await mockStore.storeNonComparable(SimpleData(value: "data"))

            // Two failing verifications
            verify(mockStore, .never).storeComparable(.any)  // Fail 1
            verify(mockStore, atLeast: 2).storeNonComparable(.any)  // Fail 2
        }
    }

    @Test
    func testDataProcessorVerificationFailures() async throws {
        try await expectVerificationFailures(messages: [
            "Expected process(_ input: any) to be called at most 1 time, but was called 3 times"
        ]) {
            var expectations = MockDataProcessor<String, Int>.Expectations()
            when(expectations.process(.any), times: .unbounded, return: 42)

            let mockProcessor = MockDataProcessor<String, Int>(expectations: expectations)

            // Call 3 times but verify at most 1 - should fail
            _ = try await mockProcessor.process("input1")
            _ = try await mockProcessor.process("input2")
            _ = try await mockProcessor.process("input3")

            verify(mockProcessor, atMost: 1).process(.any)
        }
    }

    @Test
    func testNonComparableRangeVerificationFailures() async throws {
        try await expectVerificationFailures(messages: [
            "Expected save(_ entity: any) to be called 2...4 times, but was called 1 time"
        ]) {
            var expectations = MockNonComparableRepository<SimpleData>.Expectations()
            when(expectations.save(.any), times: .unbounded, complete: .withSuccess)

            let mockRepo = MockNonComparableRepository<SimpleData>(expectations: expectations)

            // Call once but verify range 2...4 - should fail
            try await mockRepo.save(SimpleData(value: "test"))

            verify(mockRepo, times: 2...4).save(.any)
        }
    }

    @Test
    func testNonComparableWithErrorVerificationFailures() async {
        expectVerificationFailures(messages: ["Expected find(id: any) to be called at least once, but was never called"]
        ) {
            var expectations = MockNonComparableRepository<NonComparableData>.Expectations()
            when(expectations.find(id: .any), throw: NSError(domain: "test", code: 1))

            let mockRepo = MockNonComparableRepository<NonComparableData>(expectations: expectations)

            // Don't call but verify at least once - should fail
            verify(mockRepo, .atLeastOnce).find(id: .any)
        }
    }

    @Test
    func testMixedComparableAndNonComparableFailures() async throws {
        try await expectVerificationFailures(messages: [
            "Expected getComparable(id: \"specific\") to be called exactly 1 time, but was called 0 times"
        ]) {
            var expectations = MockMixedComparabilityStore<String, SimpleData>.Expectations()
            when(expectations.getComparable(id: .any), return: "result")
            when(expectations.getNonComparable(id: .any), return: SimpleData(value: "data"))

            let mockStore = MockMixedComparabilityStore<String, SimpleData>(expectations: expectations)

            // Call with different parameter but verify specific value - should fail
            _ = try await mockStore.getComparable(id: "different")
            _ = try await mockStore.getNonComparable(id: "test")

            verify(mockStore, times: 1).getComparable(id: "specific")
        }
    }

    @Test
    func testUnconstrainedAssociatedTypeVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected validate(_ input: any) to never be called, but was called 2 times"
        ]) {
            var expectations = MockDataProcessor<NonComparableData, String>.Expectations()
            when(expectations.validate(.any), times: .unbounded, return: true)

            let mockProcessor = MockDataProcessor<NonComparableData, String>(expectations: expectations)

            // Call twice but verify never called - should fail
            _ = await mockProcessor.validate(NonComparableData(content: "test1"))
            _ = await mockProcessor.validate(NonComparableData(content: "test2"))

            verify(mockProcessor, .never).validate(.any)
        }
    }
    #endif
}
