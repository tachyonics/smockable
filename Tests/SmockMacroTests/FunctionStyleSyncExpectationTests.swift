import Foundation
import Testing

@testable import Smockable

@Smock
protocol TestSyncService {
    func fetchUser(id: String) -> String
    func processData(input: String, count: Int) -> String
    func simpleFunction() -> String
    func optionalParameter(name: String, age: Int?) -> String
    func numericFunction(value: Int) -> String
    func floatFunction(value: Double) -> String
    func characterFunction(char: Character) -> String
    func multipleComparableParams(id: String, count: Int, score: Double) -> String
    func mixedParams(name: String, data: Data) -> String
}

struct FunctionStyleSyncExpectationsTests {

    @Test
    func testSimpleFunctionWithoutParameters() {
        var expectations = MockTestSyncService.Expectations()
        when(expectations.simpleFunction(), return: "test result")

        let mock = MockTestSyncService(expectations: expectations)
        let actualResult = mock.simpleFunction()

        #expect(actualResult == "test result")
    }

    @Test
    func testFunctionWithSingleParameterRange() {
        var expectations = MockTestSyncService.Expectations()
        when(expectations.fetchUser(id: "100"..."999"), times: 2, return: "user found")

        let mock = MockTestSyncService(expectations: expectations)

        let result1 = mock.fetchUser(id: "500")
        let result2 = mock.fetchUser(id: "123")

        #expect(result1 == "user found")
        #expect(result2 == "user found")

        verify(mock, times: 2).fetchUser(id: "100"..."999")
    }

    @Test
    func testFunctionWithMultipleParameterRanges() {
        var expectations = MockTestSyncService.Expectations()
        when(expectations.processData(input: "A"..."M", count: 1...10), times: 3, return: "processed")

        let mock = MockTestSyncService(expectations: expectations)

        let result1 = mock.processData(input: "B", count: 5)
        let result2 = mock.processData(input: "K", count: 1)
        let result3 = mock.processData(input: "A", count: 10)

        #expect(result1 == "processed")
        #expect(result2 == "processed")
        #expect(result3 == "processed")

        verify(mock, times: 3).processData(input: "A"..."M", count: 1...10)
    }

    @Test
    func testOptionalParameterMatching() {
        var expectations = MockTestSyncService.Expectations()
        when(expectations.optionalParameter(name: "A"..."Z", age: nil), return: "no age provided")
        when(
            expectations.optionalParameter(name: "A"..."Z", age: .range(18...65)),
            return: "valid age"
        )

        let mock = MockTestSyncService(expectations: expectations)

        let result1 = mock.optionalParameter(name: "John", age: nil)
        let result2 = mock.optionalParameter(name: "Jane", age: 25)

        #expect(result1 == "no age provided")
        #expect(result2 == "valid age")
    }

    @Test
    func testExplicitValueMatcherUsage() {
        var expectations = MockTestSyncService.Expectations()
        when(expectations.fetchUser(id: .range("100"..."999")), return: "explicit range")
        when(expectations.fetchUser(id: .any), return: "any id")

        let mock = MockTestSyncService(expectations: expectations)

        let result1 = mock.fetchUser(id: "500")
        let result2 = mock.fetchUser(id: "abc")

        #expect(result1 == "explicit range")
        #expect(result2 == "any id")
    }

    // MARK: - Exact Value Matching Tests

    @Test
    func testExactStringValueMatching() {
        var expectations = MockTestSyncService.Expectations()
        when(expectations.fetchUser(id: "exact123"), return: "exact match found")
        when(expectations.fetchUser(id: "exact456"), return: "another exact match")

        let mock = MockTestSyncService(expectations: expectations)

        let result1 = mock.fetchUser(id: "exact123")
        let result2 = mock.fetchUser(id: "exact456")

        #expect(result1 == "exact match found")
        #expect(result2 == "another exact match")

        verify(mock, times: 2).fetchUser(id: .any)
        verify(mock, times: 1).fetchUser(id: "exact123")
        verify(mock, times: 1).fetchUser(id: "exact456")
    }

    @Test
    func testExactIntegerValueMatching() {
        var expectations = MockTestSyncService.Expectations()
        when(expectations.numericFunction(value: 42), return: "answer to everything")
        when(expectations.numericFunction(value: 100), return: "century")
        when(expectations.numericFunction(value: 0), return: "zero")

        let mock = MockTestSyncService(expectations: expectations)

        let result1 = mock.numericFunction(value: 42)
        let result2 = mock.numericFunction(value: 100)
        let result3 = mock.numericFunction(value: 0)

        #expect(result1 == "answer to everything")
        #expect(result2 == "century")
        #expect(result3 == "zero")

        verify(mock, times: 3).numericFunction(value: .any)
    }

    @Test
    func testExactDoubleValueMatching() {
        var expectations = MockTestSyncService.Expectations()
        when(expectations.floatFunction(value: 3.14159), return: "pi")
        when(expectations.floatFunction(value: 2.71828), return: "e")

        let mock = MockTestSyncService(expectations: expectations)

        let result1 = mock.floatFunction(value: 3.14159)
        let result2 = mock.floatFunction(value: 2.71828)

        #expect(result1 == "pi")
        #expect(result2 == "e")
    }

    @Test
    func testExactCharacterValueMatching() {
        var expectations = MockTestSyncService.Expectations()
        when(expectations.characterFunction(char: "A"), return: "letter A")
        when(expectations.characterFunction(char: "1"), return: "digit 1")

        let mock = MockTestSyncService(expectations: expectations)

        let result1 = mock.characterFunction(char: "A")
        let result2 = mock.characterFunction(char: "1")

        #expect(result1 == "letter A")
        #expect(result2 == "digit 1")
    }

    @Test
    func testMultipleExactValuesInSameFunction() {
        var expectations = MockTestSyncService.Expectations()
        when(expectations.multipleComparableParams(id: "user1", count: 5, score: 95.5), return: "perfect match")
        when(expectations.multipleComparableParams(id: "user2", count: 3, score: 87.2), return: "another match")

        let mock = MockTestSyncService(expectations: expectations)

        let result1 = mock.multipleComparableParams(id: "user1", count: 5, score: 95.5)
        let result2 = mock.multipleComparableParams(id: "user2", count: 3, score: 87.2)

        #expect(result1 == "perfect match")
        #expect(result2 == "another match")
    }

    @Test
    func testMixedExactAndRangeMatching() {
        var expectations = MockTestSyncService.Expectations()
        // Exact value for first parameter, range for second
        when(expectations.processData(input: "exact", count: 1...10), return: "exact input with range count")
        // Range for first parameter, exact value for second
        when(expectations.processData(input: "A"..."Z", count: 42), return: "range input with exact count")

        let mock = MockTestSyncService(expectations: expectations)

        let result1 = mock.processData(input: "exact", count: 5)
        let result2 = mock.processData(input: "M", count: 42)

        #expect(result1 == "exact input with range count")
        #expect(result2 == "range input with exact count")
    }

    @Test
    func testExactValueWithOptionalParameter() {
        var expectations = MockTestSyncService.Expectations()
        when(expectations.optionalParameter(name: "John", age: 25), return: "John is 25")
        when(expectations.optionalParameter(name: "Jane", age: nil), return: "Jane has no age")

        let mock = MockTestSyncService(expectations: expectations)

        let result1 = mock.optionalParameter(name: "John", age: 25)
        let result2 = mock.optionalParameter(name: "Jane", age: nil)

        #expect(result1 == "John is 25")
        #expect(result2 == "Jane has no age")
    }

    @Test
    func testExactValuePriorityOverRange() {
        var expectations = MockTestSyncService.Expectations()
        // the first provided expectation will be used first
        when(expectations.numericFunction(value: 1...100), return: "in range")
        when(expectations.numericFunction(value: 50), return: "exact fifty")

        let mock = MockTestSyncService(expectations: expectations)

        let result1 = mock.numericFunction(value: 50)
        let result2 = mock.numericFunction(value: 50)

        #expect(result1 == "in range")
        #expect(result2 == "exact fifty")
    }

    @Test
    func testNonComparableTypeOnlySupportsAnyMatcher() {
        var expectations = MockTestSyncService.Expectations()
        // Data is not Comparable, so only .any matcher should be available
        when(expectations.mixedParams(name: "test", data: .any), return: "mixed params")

        let mock = MockTestSyncService(expectations: expectations)
        let testData = Data([1, 2, 3, 4])

        let result = mock.mixedParams(name: "test", data: testData)

        #expect(result == "mixed params")
    }

    @Test
    func testExactValueMatchingWithMultipleCalls() {
        var expectations = MockTestSyncService.Expectations()
        when(expectations.fetchUser(id: "user123"), times: 3, return: "repeated exact match")

        let mock = MockTestSyncService(expectations: expectations)

        let result1 = mock.fetchUser(id: "user123")
        let result2 = mock.fetchUser(id: "user123")
        let result3 = mock.fetchUser(id: "user123")

        #expect(result1 == "repeated exact match")
        #expect(result2 == "repeated exact match")
        #expect(result3 == "repeated exact match")

        verify(mock, times: 3).fetchUser(id: .any)
    }
}
