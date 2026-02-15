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
//  ValueMatcherCategoryTests.swift
//  SmockMacroTests
//

import Foundation
import Testing

@testable import Smockable

@Smock
protocol TestValueMatcherService {
    // Single category tests
    func comparableOnly(string: String, int: Int, double: Double) -> String
    func boolOnly(flag: Bool, active: Bool) -> String
    func nonComparableOnly(data: Data, sendable: Sendable) -> String

    // Two-category combinations
    func comparableAndBool(name: String, count: Int, enabled: Bool) -> String
    func comparableAndNonComparable(name: String, data: Data) -> String
    func boolAndNonComparable(flag: Bool, data: Data) -> String

    // All three categories combined
    func allCategories(name: String, count: Int, enabled: Bool, data: Data, sendable: Sendable) -> String

    // Edge cases
    func optionalCategories(name: String?, count: Int?, enabled: Bool?) -> String
    func mixedOptionalCategories(name: String, optionalFlag: Bool?, data: Data) -> String

    // Custom matcher tests
    func customMatcherInt(value: Int) -> String
    func customMatcherString(text: String) -> String
    func customMatcherData(data: Data) -> String
    func customMatcherOptional(value: Int?) -> String
    func customMatcherMixed(id: Int, name: String, data: Data) -> String
}

struct ValueMatcherCategoryTests {

    // MARK: - Comparable Type Tests

    @Test
    func testComparableValueMatchers() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Comparable types support ranges and exact values
        when(
            expectations.comparableOnly(string: "a"..."m", int: 1...100, double: 0.0...10.0),
            return: "range matched"
        )
        when(
            expectations.comparableOnly(string: "exact", int: 42, double: 3.14),
            return: "exact matched"
        )
        when(
            expectations.comparableOnly(string: .any, int: .any, double: .any),
            return: "any matched"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result1 = mock.comparableOnly(string: "hello", int: 50, double: 5.5)
        let result2 = mock.comparableOnly(string: "exact", int: 42, double: 3.14)
        let result3 = mock.comparableOnly(string: "anything", int: 999, double: 99.9)

        #expect(result1 == "range matched")
        #expect(result2 == "exact matched")
        #expect(result3 == "any matched")

        verify(mock, times: 2).comparableOnly(string: "a"..."m", int: 1...100, double: 0.0...10.0)  // Final call is not within int or double ranges
        verify(mock, times: 1).comparableOnly(string: "exact", int: 42, double: 3.14)
        verify(mock, times: 3).comparableOnly(string: .any, int: .any, double: .any)
    }

    @Test
    func testComparableRangePriority() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Test that first expectation takes priority
        when(
            expectations.comparableOnly(string: "a"..."z", int: 1...100, double: .any),
            return: "broad range"
        )
        when(
            expectations.comparableOnly(string: "test", int: 50, double: 5.0),
            return: "exact match"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        // This should match the first (broader) expectation
        let result1 = mock.comparableOnly(string: "test", int: 50, double: 5.0)
        // This should match the second expectation
        let result2 = mock.comparableOnly(string: "test", int: 50, double: 5.0)

        #expect(result1 == "broad range")
        #expect(result2 == "exact match")
    }

    // MARK: - Bool Type Tests

    @Test
    func testBoolValueMatchers() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Bool types support exact values and .any (no ranges)
        when(expectations.boolOnly(flag: true, active: false), return: "exact bool matched")
        when(expectations.boolOnly(flag: .any, active: true), return: "mixed bool matched")
        when(expectations.boolOnly(flag: .any, active: .any), return: "any bool matched")

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result1 = mock.boolOnly(flag: true, active: false)
        let result2 = mock.boolOnly(flag: false, active: true)
        let result3 = mock.boolOnly(flag: true, active: true)

        #expect(result1 == "exact bool matched")
        #expect(result2 == "mixed bool matched")
        #expect(result3 == "any bool matched")

        verify(mock, times: 1).boolOnly(flag: true, active: false)
        verify(mock, times: 2).boolOnly(flag: .any, active: true)
        verify(mock, times: 3).boolOnly(flag: .any, active: .any)
    }

    @Test
    func testBoolExactValuePriority() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Test exact bool values vs .any priority
        when(expectations.boolOnly(flag: .any, active: .any), return: "any first")
        when(expectations.boolOnly(flag: true, active: false), return: "exact second")

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result1 = mock.boolOnly(flag: true, active: false)
        let result2 = mock.boolOnly(flag: true, active: false)

        #expect(result1 == "any first")
        #expect(result2 == "exact second")
    }

    // MARK: - Non-Comparable Type Tests

    @Test
    func testNonComparableValueMatchers() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Non-comparable types only support .any
        when(
            expectations.nonComparableOnly(data: .any, sendable: .any),
            return: "non-comparable matched"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result = mock.nonComparableOnly(data: Data([1, 2, 3]), sendable: "any value")
        #expect(result == "non-comparable matched")

        verify(mock, times: 1).nonComparableOnly(data: .any, sendable: .any)
    }

    @Test
    func testNonComparableWithDifferentSendableTypes() {
        var expectations = MockTestValueMatcherService.Expectations()

        when(
            expectations.nonComparableOnly(data: .any, sendable: .any),
            times: .unbounded,
            return: "sendable matched"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        // Test different Sendable types
        let result1 = mock.nonComparableOnly(data: Data([1, 2, 3]), sendable: "string")
        let result2 = mock.nonComparableOnly(data: Data([4, 5, 6]), sendable: 42)
        let result3 = mock.nonComparableOnly(data: Data([7, 8, 9]), sendable: true)
        let result4 = mock.nonComparableOnly(data: Data([10, 11, 12]), sendable: Data([13, 14, 15]))

        #expect(result1 == "sendable matched")
        #expect(result2 == "sendable matched")
        #expect(result3 == "sendable matched")
        #expect(result4 == "sendable matched")

        verify(mock, times: 4).nonComparableOnly(data: .any, sendable: .any)
    }

    // MARK: - Two-Category Combination Tests

    @Test
    func testComparableAndBoolCombination() {
        var expectations = MockTestValueMatcherService.Expectations()

        when(
            expectations.comparableAndBool(name: "test"..."zebra", count: 1...100, enabled: true),
            return: "comparable range + exact bool"
        )
        when(
            expectations.comparableAndBool(name: "exact", count: 42, enabled: .any),
            return: "exact comparable + any bool"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result1 = mock.comparableAndBool(name: "value", count: 50, enabled: true)
        let result2 = mock.comparableAndBool(name: "exact", count: 42, enabled: false)

        #expect(result1 == "comparable range + exact bool")
        #expect(result2 == "exact comparable + any bool")

        verify(mock, times: 1).comparableAndBool(name: "test"..."zebra", count: 1...100, enabled: true)
        verify(mock, times: 1).comparableAndBool(name: "exact", count: 42, enabled: .any)
    }

    @Test
    func testComparableAndNonComparableCombination() {
        var expectations = MockTestValueMatcherService.Expectations()

        when(
            expectations.comparableAndNonComparable(name: "a"..."m", data: .any),
            return: "comparable range + non-comparable any"
        )
        when(
            expectations.comparableAndNonComparable(name: "exact", data: .any),
            return: "exact comparable + non-comparable any"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result1 = mock.comparableAndNonComparable(name: "hello", data: Data([1, 2, 3]))
        let result2 = mock.comparableAndNonComparable(name: "exact", data: Data([4, 5, 6]))

        #expect(result1 == "comparable range + non-comparable any")
        #expect(result2 == "exact comparable + non-comparable any")

        verify(mock, times: 2).comparableAndNonComparable(name: "a"..."m", data: .any)
        verify(mock, times: 1).comparableAndNonComparable(name: "exact", data: .any)
    }

    @Test
    func testBoolAndNonComparableCombination() {
        var expectations = MockTestValueMatcherService.Expectations()

        when(
            expectations.boolAndNonComparable(flag: true, data: .any),
            return: "exact bool + non-comparable any"
        )
        when(
            expectations.boolAndNonComparable(flag: .any, data: .any),
            return: "any bool + non-comparable any"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result1 = mock.boolAndNonComparable(flag: true, data: Data([1, 2, 3]))
        let result2 = mock.boolAndNonComparable(flag: false, data: Data([4, 5, 6]))

        #expect(result1 == "exact bool + non-comparable any")
        #expect(result2 == "any bool + non-comparable any")

        verify(mock, times: 1).boolAndNonComparable(flag: true, data: .any)
        verify(mock, times: 2).boolAndNonComparable(flag: .any, data: .any)
    }

    // MARK: - All Three Categories Combined

    @Test
    func testAllCategoriesCombination() {
        var expectations = MockTestValueMatcherService.Expectations()

        when(
            expectations.allCategories(
                name: "test"..."zebra",  // Comparable - range
                count: 1...100,  // Comparable - range
                enabled: true,  // Bool - exact
                data: .any,  // Non-comparable - .any only
                sendable: .any  // Non-comparable - .any only
            ),
            return: "all categories matched"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result = mock.allCategories(
            name: "value",
            count: 50,
            enabled: true,
            data: Data([1, 2, 3]),
            sendable: UUID()
        )

        #expect(result == "all categories matched")

        verify(mock, times: 1).allCategories(
            name: "test"..."zebra",
            count: 1...100,
            enabled: true,
            data: .any,
            sendable: .any
        )
    }

    @Test
    func testAllCategoriesWithMixedMatchers() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Mix of exact, range, and .any across all categories
        when(
            expectations.allCategories(
                name: "exact",  // Comparable - exact
                count: 10...50,  // Comparable - range
                enabled: .any,  // Bool - any
                data: .any,  // Non-comparable - .any only
                sendable: .any  // Non-comparable - .any only
            ),
            return: "mixed matchers"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result = mock.allCategories(
            name: "exact",
            count: 25,
            enabled: false,
            data: Data([1, 2, 3]),
            sendable: "test"
        )

        #expect(result == "mixed matchers")

        verify(mock, times: 1).allCategories(
            name: "exact",
            count: 10...50,
            enabled: .any,
            data: .any,
            sendable: .any
        )
    }

    // MARK: - Optional Parameter Tests

    @Test
    func testOptionalCategoryParameters() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Test optional parameters across all categories
        when(
            expectations.optionalCategories(name: .any, count: .any, enabled: .any),
            return: "all optionals any"
        )
        when(
            expectations.optionalCategories(name: "test", count: 42, enabled: true),
            return: "all optionals exact"
        )
        when(
            expectations.optionalCategories(name: nil, count: nil, enabled: nil),
            return: "all optionals nil"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result1 = mock.optionalCategories(name: "value", count: 100, enabled: false)
        let result2 = mock.optionalCategories(name: "test", count: 42, enabled: true)
        let result3 = mock.optionalCategories(name: nil, count: nil, enabled: nil)

        #expect(result1 == "all optionals any")
        #expect(result2 == "all optionals exact")
        #expect(result3 == "all optionals nil")

        verify(mock, times: 3).optionalCategories(name: .any, count: .any, enabled: .any)
        verify(mock, times: 1).optionalCategories(name: "test", count: 42, enabled: true)
        verify(mock, times: 1).optionalCategories(name: nil, count: nil, enabled: nil)
    }

    @Test
    func testMixedOptionalCategories() {
        var expectations = MockTestValueMatcherService.Expectations()

        when(
            expectations.mixedOptionalCategories(name: "a"..."z", optionalFlag: .any, data: .any),
            times: .unbounded,
            return: "mixed optional matched"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result1 = mock.mixedOptionalCategories(name: "test", optionalFlag: true, data: Data([1, 2, 3]))
        let result2 = mock.mixedOptionalCategories(name: "value", optionalFlag: nil, data: Data([4, 5, 6]))

        #expect(result1 == "mixed optional matched")
        #expect(result2 == "mixed optional matched")

        verify(mock, times: 2).mixedOptionalCategories(name: "a"..."z", optionalFlag: .any, data: .any)
        verify(mock, times: 1).mixedOptionalCategories(name: "test", optionalFlag: true, data: .any)
        verify(mock, times: 1).mixedOptionalCategories(name: "value", optionalFlag: nil, data: .any)
    }

    // MARK: - Comprehensive Category Verification

    @Test
    func testComprehensiveCategoryVerification() {
        var expectations = MockTestValueMatcherService.Expectations()

        when(
            expectations.comparableOnly(string: .any, int: .any, double: .any),
            times: .unbounded,
            return: "comparable"
        )
        when(expectations.boolOnly(flag: .any, active: .any), times: .unbounded, return: "bool")
        when(expectations.nonComparableOnly(data: .any, sendable: .any), times: .unbounded, return: "non-comparable")
        when(
            expectations.allCategories(name: .any, count: .any, enabled: .any, data: .any, sendable: .any),
            times: .unbounded,
            return: "all"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        // Execute multiple calls across all categories
        _ = mock.comparableOnly(string: "test1", int: 1, double: 1.0)
        _ = mock.comparableOnly(string: "test2", int: 2, double: 2.0)
        _ = mock.comparableOnly(string: "test3", int: 3, double: 3.0)

        _ = mock.boolOnly(flag: true, active: false)
        _ = mock.boolOnly(flag: false, active: true)

        _ = mock.nonComparableOnly(data: Data([1]), sendable: "test")

        _ = mock.allCategories(name: "all1", count: 1, enabled: true, data: Data([1]), sendable: "s1")
        _ = mock.allCategories(name: "all2", count: 2, enabled: false, data: Data([2]), sendable: "s2")
        _ = mock.allCategories(name: "all3", count: 3, enabled: true, data: Data([3]), sendable: "s3")
        _ = mock.allCategories(name: "all4", count: 4, enabled: false, data: Data([4]), sendable: "s4")

        // Test comprehensive verification patterns
        verify(mock, times: 3).comparableOnly(string: .any, int: .any, double: .any)
        verify(mock, times: 2).boolOnly(flag: .any, active: .any)
        verify(mock, times: 1).nonComparableOnly(data: .any, sendable: .any)
        verify(mock, times: 4).allCategories(name: .any, count: .any, enabled: .any, data: .any, sendable: .any)

        // Test specific parameter verification
        verify(mock, times: 1).comparableOnly(string: "test1", int: 1, double: 1.0)
        verify(mock, times: 1).boolOnly(flag: true, active: false)
        verify(mock, times: 1).allCategories(name: "all4", count: 4, enabled: false, data: .any, sendable: .any)
    }

    // MARK: - Custom Matcher Tests

    @Test
    func testComparableCustomMatcher() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Test custom matcher for even numbers
        when(
            expectations.customMatcherInt(value: .matching { $0 % 2 == 0 }),
            times: 2,
            return: "even number"
        )

        // Test custom matcher for numbers greater than 50
        when(
            expectations.customMatcherInt(value: .matching { $0 > 50 }),
            return: "large number"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result1 = mock.customMatcherInt(value: 4)  // even
        let result2 = mock.customMatcherInt(value: 75)  // > 50
        let result3 = mock.customMatcherInt(value: 10)  // even

        #expect(result1 == "even number")
        #expect(result2 == "large number")
        #expect(result3 == "even number")

        verify(mock, times: 2).customMatcherInt(value: .matching { $0 % 2 == 0 })
        verify(mock, times: 1).customMatcherInt(value: .matching { $0 > 50 })
    }

    @Test
    func testStringCustomMatcher() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Test custom matcher for strings containing specific substring
        when(
            expectations.customMatcherString(text: .matching { $0.contains("test") }),
            times: 2,
            return: "contains test"
        )

        // Test custom matcher for long strings
        when(
            expectations.customMatcherString(text: .matching { $0.count > 10 }),
            return: "long string"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result1 = mock.customMatcherString(text: "this is a test")  // contains "test" (is also length > 10)
        let result2 = mock.customMatcherString(text: "this is a very long string")  // length > 10
        let result3 = mock.customMatcherString(text: "testing123")  // contains "test"

        #expect(result1 == "contains test")
        #expect(result2 == "long string")
        #expect(result3 == "contains test")

        verify(mock, times: 2).customMatcherString(text: .matching { $0.contains("test") })
        // 2 of the calls match this verification even though the order of the verifications caused the
        // of result from the same matching logic
        verify(mock, times: 2).customMatcherString(text: .matching { $0.count > 10 })
    }

    @Test
    func testNonComparableCustomMatcher() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Test custom matcher for Data with specific size
        when(
            expectations.customMatcherData(data: .matching { $0.count > 5 }),
            times: 2,
            return: "large data"
        )

        // Test custom matcher for Data containing specific byte
        when(
            expectations.customMatcherData(data: .matching { $0.contains(42) }),
            return: "contains 42"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result1 = mock.customMatcherData(data: Data([1, 2, 3, 4, 5, 6, 7]))  // count > 5
        let result2 = mock.customMatcherData(data: Data([10, 42, 30]))  // contains 42
        let result3 = mock.customMatcherData(data: Data([1, 2, 3, 4, 5, 6]))  // count > 5

        #expect(result1 == "large data")
        #expect(result2 == "contains 42")
        #expect(result3 == "large data")

        verify(mock, times: 2).customMatcherData(data: .matching { $0.count > 5 })
        verify(mock, times: 1).customMatcherData(data: .matching { $0.contains(42) })
    }

    @Test
    func testOptionalCustomMatcher() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Test custom matcher for positive non-nil values
        when(
            expectations.customMatcherOptional(
                value: .matching {
                    guard let val = $0 else { return false }
                    return val > 0
                }
            ),
            times: 2,
            return: "positive non-nil"
        )

        // Test custom matcher for nil values
        when(
            expectations.customMatcherOptional(value: .matching { $0 == nil }),
            return: "is nil"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result1 = mock.customMatcherOptional(value: 5)  // positive non-nil
        let result2 = mock.customMatcherOptional(value: nil)  // nil
        let result3 = mock.customMatcherOptional(value: 10)  // positive non-nil

        #expect(result1 == "positive non-nil")
        #expect(result2 == "is nil")
        #expect(result3 == "positive non-nil")

        verify(mock, times: 2).customMatcherOptional(
            value: .matching {
                guard let val = $0 else { return false }
                return val > 0
            }
        )
        verify(mock, times: 1).customMatcherOptional(value: .matching { $0 == nil })
    }

    @Test
    func testMixedCustomMatchers() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Test mixing custom matchers with other matcher types
        when(
            expectations.customMatcherMixed(
                id: .matching { $0 > 100 },  // custom matcher
                name: "test"..."zebra",  // range matcher
                data: .matching { $0.count > 0 }  // custom matcher
            ),
            return: "mixed matchers"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result = mock.customMatcherMixed(
            id: 150,
            name: "user",
            data: Data([1, 2, 3])
        )

        #expect(result == "mixed matchers")

        verify(mock, times: 1).customMatcherMixed(
            id: .matching { $0 > 100 },
            name: "test"..."zebra",
            data: .matching { $0.count > 0 }
        )
    }

    @Test
    func testCustomMatcherPriority() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Test that first matching custom expectation takes priority
        when(
            expectations.customMatcherInt(value: .matching { $0 > 0 }),  // First: positive numbers
            return: "positive"
        )
        when(
            expectations.customMatcherInt(value: .matching { $0 % 2 == 0 }),  // Second: even numbers
            return: "even"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        // Value 4 matches both conditions, should use first expectation
        let result1 = mock.customMatcherInt(value: 4)
        // Value 4 again, should now use second expectation (first is consumed)
        let result2 = mock.customMatcherInt(value: 4)

        #expect(result1 == "positive")
        #expect(result2 == "even")

        // both calls match to both parameter matcher expressions
        verify(mock, times: 2).customMatcherInt(value: .matching { $0 > 0 })
        verify(mock, times: 2).customMatcherInt(value: .matching { $0 % 2 == 0 })
    }

    @Test
    func testInOrderCustomMatcherPriority() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Test that first matching custom expectation takes priority
        when(
            expectations.customMatcherInt(value: .matching { $0 > 0 }),  // First: positive numbers
            return: "positive"
        )
        when(
            expectations.customMatcherInt(value: .matching { $0 % 2 == 0 }),  // Second: even numbers
            return: "even"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        // Value 4 matches both conditions, should use first expectation
        let result1 = mock.customMatcherInt(value: 4)
        // Value 4 again, should now use second expectation (first is consumed)
        let result2 = mock.customMatcherInt(value: 4)

        #expect(result1 == "positive")
        #expect(result2 == "even")

        let inOrder = InOrder(strict: true, mock)
        inOrder.verify(mock, additionalTimes: 1).customMatcherInt(value: .matching { $0 > 0 })
        inOrder.verify(mock, additionalTimes: 1).customMatcherInt(value: .matching { $0 % 2 == 0 })
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testComplexCustomMatcherLogic() {
        var expectations = MockTestValueMatcherService.Expectations()

        // Test complex custom matcher with multiple conditions
        when(
            expectations.customMatcherString(
                text: .matching { text in
                    let words = text.split(separator: " ")
                    return words.count >= 3 && words.contains(where: { $0.count > 5 }) && text.contains("important")
                }
            ),
            return: "complex match"
        )

        // Fallback for non-matching strings
        when(
            expectations.customMatcherString(text: .any),
            return: "no match"
        )

        let mock = MockTestValueMatcherService(expectations: expectations)

        let result1 = mock.customMatcherString(text: "this important message contains information")
        let result2 = mock.customMatcherString(text: "short text")

        #expect(result1 == "complex match")
        #expect(result2 == "no match")

        verify(mock, times: 1).customMatcherString(
            text: .matching { text in
                let words = text.split(separator: " ")
                return words.count >= 3 && words.contains(where: { $0.count > 5 }) && text.contains("important")
            }
        )
        verify(mock, times: 2).customMatcherString(text: .any)
    }

    @Test
    func testCustomMatcherDescriptions() {
        // Test that custom matchers have appropriate descriptions
        let intMatcher: ValueMatcher<Int> = .matching { $0 > 0 }
        let stringMatcher: ValueMatcher<String> = .matching { $0.contains("test") }
        let dataMatcher: NonComparableValueMatcher<Data> = .matching { $0.count > 0 }
        let optionalMatcher: OptionalValueMatcher<Int> = .matching { $0 != nil }

        #expect(intMatcher.description == "custom")
        #expect(stringMatcher.description == "custom")
        #expect(stringMatcher.stringSpecficDescription == "custom")
        #expect(dataMatcher.description == "custom")
        #expect(optionalMatcher.description == "custom")
    }

    // MARK: - Unhappy Path Tests

    #if SMOCKABLE_UNHAPPY_PATH_TESTING
    @Test
    func testComparableValueMatcherVerificationFailures() {
        expectVerificationFailures(messages: [
            "Expected comparableOnly(string: any, int: any, double: any) to be called exactly 3 times, but was called 2 times"
        ]) {
            var expectations = MockTestValueMatcherService.Expectations()
            when(
                expectations.comparableOnly(string: .any, int: .any, double: .any),
                times: .unbounded,
                return: "result"
            )

            let mock = MockTestValueMatcherService(expectations: expectations)

            // Call twice but verify 3 times - should fail
            _ = mock.comparableOnly(string: "test1", int: 10, double: 1.5)
            _ = mock.comparableOnly(string: "test2", int: 20, double: 2.5)

            verify(mock, times: 3).comparableOnly(string: .any, int: .any, double: .any)
        }
    }

    @Test
    func testRangeMatcherVerificationFailures() {
        expectVerificationFailures(messages: [
            "Expected comparableOnly(string: \"a\"...\"m\", int: 1...100, double: 0.0...10.0) to never be called, but was called 1 time"
        ]) {
            var expectations = MockTestValueMatcherService.Expectations()
            when(expectations.comparableOnly(string: .any, int: .any, double: .any), return: "result")

            let mock = MockTestValueMatcherService(expectations: expectations)

            // Call with range parameters but verify never called - should fail
            _ = mock.comparableOnly(string: "hello", int: 50, double: 5.5)  // matches "a"..."m", 1...100, 0.0...10.0

            verify(mock, .never).comparableOnly(string: "a"..."m", int: 1...100, double: 0.0...10.0)
        }
    }

    @Test
    func testBoolValueMatcherVerificationFailures() {
        expectVerificationFailures(messages: [
            "Expected boolOnly(flag: any, active: any) to be called at least 2 times, but was called 1 time"
        ]) {
            var expectations = MockTestValueMatcherService.Expectations()
            when(expectations.boolOnly(flag: .any, active: .any), times: .unbounded, return: "bool result")

            let mock = MockTestValueMatcherService(expectations: expectations)

            // Call once but verify at least 2 times - should fail
            _ = mock.boolOnly(flag: true, active: false)

            verify(mock, atLeast: 2).boolOnly(flag: .any, active: .any)
        }
    }

    @Test
    func testNonComparableValueMatcherVerificationFailures() {
        expectVerificationFailures(messages: [
            "Expected nonComparableOnly(data: any, sendable: any) to be called at most 1 time, but was called 3 times"
        ]) {
            var expectations = MockTestValueMatcherService.Expectations()
            when(expectations.nonComparableOnly(data: .any, sendable: .any), times: .unbounded, return: "data result")

            let mock = MockTestValueMatcherService(expectations: expectations)

            // Call 3 times but verify at most 1 time - should fail
            _ = mock.nonComparableOnly(data: Data([1, 2, 3]), sendable: "sendable1")
            _ = mock.nonComparableOnly(data: Data([4, 5, 6]), sendable: "sendable2")
            _ = mock.nonComparableOnly(data: Data([7, 8, 9]), sendable: "sendable3")

            verify(mock, atMost: 1).nonComparableOnly(data: .any, sendable: .any)
        }
    }

    @Test
    func testMixedCategoryVerificationFailures() {
        expectVerificationFailures(messages: [
            "Expected allCategories(name: any, count: any, enabled: any, data: any, sendable: any) to be called 1...2 times, but was called 5 times"
        ]) {
            var expectations = MockTestValueMatcherService.Expectations()
            when(
                expectations.allCategories(name: .any, count: .any, enabled: .any, data: .any, sendable: .any),
                times: .unbounded,
                return: "all result"
            )

            let mock = MockTestValueMatcherService(expectations: expectations)

            // Call 5 times but verify range 1...2 - should fail
            for i in 1...5 {
                _ = mock.allCategories(
                    name: "test\(i)",
                    count: i * 10,
                    enabled: i % 2 == 0,
                    data: Data([UInt8(i)]),
                    sendable: "sendable\(i)"
                )
            }

            verify(mock, times: 1...2).allCategories(name: .any, count: .any, enabled: .any, data: .any, sendable: .any)
        }
    }

    @Test
    func testSpecificValueMatchingVerificationFailures() {
        expectVerificationFailures(messages: [
            "Expected comparableOnly(string: \"expected\", int: 42, double: 3.14) to be called exactly 1 time, but was called 0 times"
        ]) {
            var expectations = MockTestValueMatcherService.Expectations()
            when(
                expectations.comparableOnly(string: .any, int: .any, double: .any),
                times: .unbounded,
                return: "result"
            )

            let mock = MockTestValueMatcherService(expectations: expectations)

            // Call with different specific values but verify specific value that wasn't called
            _ = mock.comparableOnly(string: "actual", int: 42, double: 3.14)

            // Verify specific values that don't match what was called - should fail
            verify(mock, times: 1).comparableOnly(string: "expected", int: 42, double: 3.14)
        }
    }

    @Test
    func testRangeAndSpecificValueMixedFailures() {
        expectVerificationFailures(messages: [
            "Expected comparableAndBool(name: \"test\"...\"zebra\", count: 1...100, enabled: true) to be called exactly 2 times, but was called 1 time",
            "Expected comparableAndBool(name: any, count: any, enabled: any) to never be called, but was called 1 time",
        ]) {
            var expectations = MockTestValueMatcherService.Expectations()
            when(
                expectations.comparableAndBool(name: .any, count: .any, enabled: .any),
                times: .unbounded,
                return: "mixed result"
            )

            let mock = MockTestValueMatcherService(expectations: expectations)

            // Call once with values in range
            _ = mock.comparableAndBool(name: "value", count: 50, enabled: true)

            // Two failing verifications
            verify(mock, times: 2).comparableAndBool(name: "test"..."zebra", count: 1...100, enabled: true)  // Fail 1 - called once, not twice
            verify(mock, .never).comparableAndBool(name: .any, count: .any, enabled: .any)  // Fail 2 - was called
        }
    }

    @Test
    func testComplexParameterCombinationFailures() {
        expectVerificationFailures(messages: [
            "Expected allCategories(name: \"specific\", count: 100, enabled: true, data: any, sendable: any) to be called at least once, but was never called"
        ]) {
            var expectations = MockTestValueMatcherService.Expectations()
            when(
                expectations.allCategories(name: .any, count: .any, enabled: .any, data: .any, sendable: .any),
                return: "result"
            )

            let mock = MockTestValueMatcherService(expectations: expectations)

            // Don't call but verify specific combination - should fail
            verify(mock, .atLeastOnce).allCategories(
                name: "specific",
                count: 100,
                enabled: true,
                data: .any,
                sendable: .any
            )
        }
    }

    @Test
    func testOutOfRangeValueMatcherFailures() {
        expectVerificationFailures(messages: [
            "Expected comparableOnly(string: \"a\"...\"m\", int: 1...100, double: 0.0...10.0) to be called exactly 1 time, but was called 0 times"
        ]) {
            var expectations = MockTestValueMatcherService.Expectations()
            when(
                expectations.comparableOnly(string: .any, int: .any, double: .any),
                times: .unbounded,
                return: "result"
            )

            let mock = MockTestValueMatcherService(expectations: expectations)

            // Call with values outside expected ranges
            _ = mock.comparableOnly(string: "zebra", int: 200, double: 15.0)  // outside "a"..."m", 1...100, 0.0...10.0

            // Verify with range that doesn't match - should fail since call was outside range
            verify(mock, times: 1).comparableOnly(string: "a"..."m", int: 1...100, double: 0.0...10.0)
        }
    }

    @Test
    func testCustomMatcherVerificationFailures() {
        expectVerificationFailures(messages: [
            "Expected customMatcherInt(value: custom) to be called exactly 2 times, but was called 1 time"
        ]) {
            var expectations = MockTestValueMatcherService.Expectations()
            when(
                expectations.customMatcherInt(value: .any),
                times: .unbounded,
                return: "result"
            )

            let mock = MockTestValueMatcherService(expectations: expectations)

            // Call once with even number but verify custom matcher twice - should fail
            _ = mock.customMatcherInt(value: 4)

            verify(mock, times: 2).customMatcherInt(value: .matching { $0 % 2 == 0 })
        }
    }

    @Test
    func testMixedMatcherVerificationFailures() {
        expectVerificationFailures(messages: [
            "Expected customMatcherMixed(id: custom, name: \"test\"...\"zebra\", data: custom) to never be called, but was called 1 time"
        ]) {
            var expectations = MockTestValueMatcherService.Expectations()
            when(
                expectations.customMatcherMixed(id: .any, name: .any, data: .any),
                times: .unbounded,
                return: "result"
            )

            let mock = MockTestValueMatcherService(expectations: expectations)

            // Call with values that match the custom matchers
            _ = mock.customMatcherMixed(id: 150, name: "user", data: Data([1, 2, 3]))

            // Verify never called but it was called - should fail
            verify(mock, .never).customMatcherMixed(
                id: .matching { $0 > 100 },
                name: "test"..."zebra",
                data: .matching { $0.count > 0 }
            )
        }
    }
    #endif
}
