import Foundation
import Testing

@testable import Smockable

@Smock
protocol TestService {
    func fetchUser(id: String) async -> String
    func processData(input: String, count: Int) async -> String
    func simpleFunction() async -> String
    func optionalParameter(name: String, age: Int?) async -> String
}

struct FunctionStyleExpectationsTests {

    @Test
    func testSimpleFunctionWithoutParameters() async {
        var expectations = MockTestService.Expectations()
        when(expectations.simpleFunction(), useValue: "test result")

        let mock = MockTestService(expectations: expectations)
        let actualResult = await mock.simpleFunction()

        #expect(actualResult == "test result")
    }

    @Test
    func testFunctionWithSingleParameterRange() async {
        var expectations = MockTestService.Expectations()
        when(expectations.fetchUser(id: "100"..."999"), times: 2, useValue: "user found")

        let mock = MockTestService(expectations: expectations)

        let result1 = await mock.fetchUser(id: "500")
        let result2 = await mock.fetchUser(id: "123")

        #expect(result1 == "user found")
        #expect(result2 == "user found")

        let callCount = await mock.__verify.fetchUser_id.callCount
        #expect(callCount == 2)
    }

    @Test
    func testFunctionWithMultipleParameterRanges() async {
        var expectations = MockTestService.Expectations()
        when(expectations.processData(input: "A"..."M", count: 1...10), times: 3, useValue: "processed")

        let mock = MockTestService(expectations: expectations)

        let result1 = await mock.processData(input: "B", count: 5)
        let result2 = await mock.processData(input: "K", count: 1)
        let result3 = await mock.processData(input: "A", count: 10)

        #expect(result1 == "processed")
        #expect(result2 == "processed")
        #expect(result3 == "processed")

        let callCount = await mock.__verify.processData_input_count.callCount
        #expect(callCount == 3)
    }

    @Test
    func testOptionalParameterMatching() async {
        var expectations = MockTestService.Expectations()
        when(expectations.optionalParameter(name: "A"..."Z", age: .nil), useValue: "no age provided")
        when(
            expectations.optionalParameter(name: "A"..."Z", age: .range(18...65)),
            useValue: "valid age"
        )

        let mock = MockTestService(expectations: expectations)

        let result1 = await mock.optionalParameter(name: "John", age: nil)
        let result2 = await mock.optionalParameter(name: "Jane", age: 25)

        #expect(result1 == "no age provided")
        #expect(result2 == "valid age")
    }

    @Test
    func testExplicitValueMatcherUsage() async {
        var expectations = MockTestService.Expectations()
        when(expectations.fetchUser(id: .range("100"..."999")), useValue: "explicit range")
        when(expectations.fetchUser(id: .any), useValue: "any id")

        let mock = MockTestService(expectations: expectations)

        let result1 = await mock.fetchUser(id: "500")
        let result2 = await mock.fetchUser(id: "abc")

        #expect(result1 == "explicit range")
        #expect(result2 == "any id")
    }
}
