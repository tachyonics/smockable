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
//  ExactValueMatchingTests.swift
//  SmockMacroTests
//

import Foundation
import Testing

@testable import Smockable

// MARK: - Test Protocols for Exact Value Matching

@Smock
protocol NumericService {
    func processInt(value: Int) async -> String
    func processInt8(value: Int8) async -> String
    func processInt16(value: Int16) async -> String
    func processInt32(value: Int32) async -> String
    func processInt64(value: Int64) async -> String
    func processUInt(value: UInt) async -> String
    func processUInt8(value: UInt8) async -> String
    func processUInt16(value: UInt16) async -> String
    func processUInt32(value: UInt32) async -> String
    func processUInt64(value: UInt64) async -> String
}

@Smock
protocol StringService {
    func processString(value: String) async -> String
    func processCharacter(value: Character) async -> String
    func processOptionalString(value: String?) async -> String
}

@Smock
protocol BooleanService {
    func processBoolean(value: Bool) async -> String
}

@Smock
protocol MixedComparableService {
    func complexFunction(id: String, count: Int, score: Double, active: Character) async -> String
    func optionalMixFunction(name: String?, age: Int?, score: Double?) async -> String
}

@Smock
protocol NonComparableService {
    func processData(data: Data) async -> String
    func processArray(items: [String]) async -> String
    func mixedFunction(name: String, data: Data) async -> String
}

struct ExactValueMatchingTests {

    // MARK: - Integer Type Tests

    @Test
    func testAllIntegerTypes() async {
        var expectations = MockNumericService.Expectations()

        // Test all integer types with exact values
        when(expectations.processInt(value: 42), return: "Int: 42")
        when(expectations.processInt8(value: 127), return: "Int8: 127")
        when(expectations.processInt16(value: 32767), return: "Int16: 32767")
        when(expectations.processInt32(value: 2_147_483_647), return: "Int32: 2147483647")
        when(expectations.processInt64(value: 9_223_372_036_854_775_807), return: "Int64: max")
        when(expectations.processUInt(value: 42), return: "UInt: 42")
        when(expectations.processUInt8(value: 255), return: "UInt8: 255")
        when(expectations.processUInt16(value: 65535), return: "UInt16: 65535")
        when(expectations.processUInt32(value: 4_294_967_295), return: "UInt32: 4294967295")
        when(expectations.processUInt64(value: 18_446_744_073_709_551_615), return: "UInt64: max")

        let mock = MockNumericService(expectations: expectations)

        #expect(await mock.processInt(value: 42) == "Int: 42")
        #expect(await mock.processInt8(value: 127) == "Int8: 127")
        #expect(await mock.processInt16(value: 32767) == "Int16: 32767")
        #expect(await mock.processInt32(value: 2_147_483_647) == "Int32: 2147483647")
        #expect(await mock.processInt64(value: 9_223_372_036_854_775_807) == "Int64: max")
        #expect(await mock.processUInt(value: 42) == "UInt: 42")
        #expect(await mock.processUInt8(value: 255) == "UInt8: 255")
        #expect(await mock.processUInt16(value: 65535) == "UInt16: 65535")
        #expect(await mock.processUInt32(value: 4_294_967_295) == "UInt32: 4294967295")
        #expect(await mock.processUInt64(value: 18_446_744_073_709_551_615) == "UInt64: max")
    }

    // MARK: - String and Character Tests

    @Test
    func testStringExactMatching() async {
        var expectations = MockStringService.Expectations()

        when(expectations.processString(value: ""), return: "empty string")
        when(expectations.processString(value: "hello"), return: "greeting")
        when(expectations.processString(value: "Hello"), return: "capitalized greeting")
        when(expectations.processString(value: "special chars: !@#$%^&*()"), return: "special")
        when(expectations.processString(value: "unicode: 🚀🎉"), return: "unicode")

        let mock = MockStringService(expectations: expectations)

        #expect(await mock.processString(value: "") == "empty string")
        #expect(await mock.processString(value: "hello") == "greeting")
        #expect(await mock.processString(value: "Hello") == "capitalized greeting")
        #expect(await mock.processString(value: "special chars: !@#$%^&*()") == "special")
        #expect(await mock.processString(value: "unicode: 🚀🎉") == "unicode")
    }

    @Test
    func testCharacterExactMatching() async {
        var expectations = MockStringService.Expectations()

        when(expectations.processCharacter(value: "A"), return: "letter A")
        when(expectations.processCharacter(value: "1"), return: "digit 1")
        when(expectations.processCharacter(value: " "), return: "space")
        when(expectations.processCharacter(value: "🎉"), return: "party emoji")

        let mock = MockStringService(expectations: expectations)

        #expect(await mock.processCharacter(value: "A") == "letter A")
        #expect(await mock.processCharacter(value: "1") == "digit 1")
        #expect(await mock.processCharacter(value: " ") == "space")
        #expect(await mock.processCharacter(value: "🎉") == "party emoji")
    }

    // MARK: - Optional Parameter Tests

    @Test
    func testOptionalStringExactMatching() async {
        var expectations = MockStringService.Expectations()

        when(expectations.processOptionalString(value: "hello"), return: "exact hello")
        when(expectations.processOptionalString(value: nil), return: "exact nil")
        when(expectations.processOptionalString(value: ""), return: "exact empty")

        let mock = MockStringService(expectations: expectations)

        #expect(await mock.processOptionalString(value: "hello") == "exact hello")
        #expect(await mock.processOptionalString(value: nil) == "exact nil")
        #expect(await mock.processOptionalString(value: "") == "exact empty")
    }

    @Test
    func testComplexOptionalExactMatching() async {
        var expectations = MockMixedComparableService.Expectations()

        when(
            expectations.optionalMixFunction(name: "John", age: 25, score: 95.5),
            return: "all exact"
        )
        when(
            expectations.optionalMixFunction(name: nil, age: nil, score: nil),
            return: "all nil"
        )
        when(
            expectations.optionalMixFunction(name: "Jane", age: nil, score: 87.2),
            return: "mixed exact"
        )

        let mock = MockMixedComparableService(expectations: expectations)

        #expect(await mock.optionalMixFunction(name: "John", age: 25, score: 95.5) == "all exact")
        #expect(await mock.optionalMixFunction(name: nil, age: nil, score: nil) == "all nil")
        #expect(await mock.optionalMixFunction(name: "Jane", age: nil, score: 87.2) == "mixed exact")
    }

    // MARK: - Complex Multi-Parameter Tests

    @Test
    func testComplexMultiParameterExactMatching() async {
        var expectations = MockMixedComparableService.Expectations()

        when(expectations.complexFunction(id: "user123", count: 42, score: 98.7, active: "A"), return: "perfect match")
        when(expectations.complexFunction(id: "user456", count: 0, score: 0.0, active: "B"), return: "zero values")
        when(expectations.complexFunction(id: "", count: -1, score: -99.9, active: "C"), return: "edge cases")

        let mock = MockMixedComparableService(expectations: expectations)

        #expect(await mock.complexFunction(id: "user123", count: 42, score: 98.7, active: "A") == "perfect match")
        #expect(await mock.complexFunction(id: "user456", count: 0, score: 0.0, active: "B") == "zero values")
        #expect(await mock.complexFunction(id: "", count: -1, score: -99.9, active: "C") == "edge cases")
    }

    // MARK: - Non-Comparable Type Tests

    @Test
    func testNonComparableTypesOnlySupportAnyMatcher() async {
        var expectations = MockNonComparableService.Expectations()

        // Non-comparable types should only support .any matcher
        when(expectations.processData(data: .any), return: "any data")
        when(expectations.processArray(items: .any), return: "any array")
        when(expectations.mixedFunction(name: "test", data: .any), return: "mixed with any data")

        let mock = MockNonComparableService(expectations: expectations)

        let testData = Data([1, 2, 3])
        let testArray = ["a", "b", "c"]

        #expect(await mock.processData(data: testData) == "any data")
        #expect(await mock.processArray(items: testArray) == "any array")
        #expect(await mock.mixedFunction(name: "test", data: testData) == "mixed with any data")
    }

    // MARK: - Edge Cases and Error Scenarios

    @Test
    func testExactMatchingWithNegativeNumbers() async {
        var expectations = MockNumericService.Expectations()

        when(expectations.processInt(value: -42), return: "negative int")

        let mock = MockNumericService(expectations: expectations)

        #expect(await mock.processInt(value: -42) == "negative int")
    }

    @Test
    func testExactMatchingWithBoundaryValues() async {
        var expectations = MockNumericService.Expectations()

        // Test boundary values for different integer types
        when(expectations.processInt8(value: -128), return: "Int8 min")
        when(expectations.processInt8(value: 127), return: "Int8 max")
        when(expectations.processUInt8(value: 0), return: "UInt8 min")
        when(expectations.processUInt8(value: 255), return: "UInt8 max")

        let mock = MockNumericService(expectations: expectations)

        #expect(await mock.processInt8(value: -128) == "Int8 min")
        #expect(await mock.processInt8(value: 127) == "Int8 max")
        #expect(await mock.processUInt8(value: 0) == "UInt8 min")
        #expect(await mock.processUInt8(value: 255) == "UInt8 max")
    }

    @Test
    func testMultipleExactMatchesForSameFunction() async {
        var expectations = MockStringService.Expectations()

        // Multiple exact matches for the same function
        when(expectations.processString(value: "first"), return: "first match")
        when(expectations.processString(value: "second"), return: "second match")
        when(expectations.processString(value: "third"), return: "third match")
        when(expectations.processString(value: "first"), return: "first again")

        let mock = MockStringService(expectations: expectations)

        #expect(await mock.processString(value: "first") == "first match")  // First should win
        #expect(await mock.processString(value: "second") == "second match")
        #expect(await mock.processString(value: "third") == "third match")
    }

    // MARK: - Unhappy Path Tests

    #if SMOCKABLE_UNHAPPY_PATH_TESTING
    @Test
    func testExactStringValueVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected processString(value: \"exact\") to be called exactly 2 times, but was called 1 time"
        ]) {
            var expectations = MockStringService.Expectations()
            when(expectations.processString(value: "exact"), return: "exact match")

            let mock = MockStringService(expectations: expectations)

            // Call once but verify twice - should fail
            _ = await mock.processString(value: "exact")

            verify(mock, times: 2).processString(value: "exact")
        }
    }

    @Test
    func testExactIntegerValueVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected processInt(value: 42) to never be called, but was called 1 time"
        ]) {
            var expectations = MockNumericService.Expectations()
            when(expectations.processInt(value: 42), return: "forty-two")

            let mock = MockNumericService(expectations: expectations)

            // Call it but verify never called - should fail
            _ = await mock.processInt(value: 42)

            verify(mock, .never).processInt(value: 42)
        }
    }

    @Test
    func testExactBooleanValueVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected processBoolean(value: true) to be called at least 3 times, but was called 1 time"
        ]) {
            var expectations = MockBooleanService.Expectations()
            when(expectations.processBoolean(value: true), times: .unbounded, return: "true processed")

            let mock = MockBooleanService(expectations: expectations)

            // Call once but verify at least 3 times - should fail
            _ = await mock.processBoolean(value: true)

            verify(mock, atLeast: 3).processBoolean(value: true)
        }
    }

    @Test
    func testMismatchedExactValueVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected processString(value: \"expected\") to be called exactly 1 time, but was called 0 times"
        ]) {
            var expectations = MockStringService.Expectations()
            when(expectations.processString(value: .any), times: .unbounded, return: "any match")

            let mock = MockStringService(expectations: expectations)

            // Call with different value but verify specific value - should fail
            _ = await mock.processString(value: "actual")

            verify(mock, times: 1).processString(value: "expected")
        }
    }

    @Test
    func testRangeValueVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected processInt(value: any) to be called 2...4 times, but was called 1 time"
        ]) {
            var expectations = MockNumericService.Expectations()
            when(expectations.processInt(value: .any), times: .unbounded, return: "any number")

            let mock = MockNumericService(expectations: expectations)

            // Call once but verify range 2...4 - should fail
            _ = await mock.processInt(value: 50)

            verify(mock, times: 2...4).processInt(value: .any)
        }
    }

    @Test
    func testExactVsAnyMatcherVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected processBoolean(value: false) to be called at least once, but was never called"
        ]) {
            var expectations = MockBooleanService.Expectations()
            when(expectations.processBoolean(value: .any), return: "any boolean")

            let mock = MockBooleanService(expectations: expectations)

            // Call with true but verify false specifically - should fail
            _ = await mock.processBoolean(value: true)

            verify(mock, .atLeastOnce).processBoolean(value: false)
        }
    }
    #endif
}
