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
}
