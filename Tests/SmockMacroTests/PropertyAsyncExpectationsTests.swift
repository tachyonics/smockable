import Foundation
import Testing

@testable import Smockable

@Smock
protocol TestAsyncPropertyService {
    var asyncName: String { get async }
    var asyncReadOnlyData: Data { get async }
    var asyncOptionalValue: String? { get async }
    var asyncIsActive: Bool { get async }
    var asyncCount: Int { get async }
}

@Smock
protocol TestAsyncComplexPropertyService {
    var asyncConfiguration: [String: Sendable] { get async }
    var asyncNumbers: [Int] { get async }
    var asyncMetadata: [String: String] { get async }
}

struct PropertyAsyncExpectationsTests {

    @Test
    func testBasicAsyncPropertyGetter() async {
        var expectations = MockTestAsyncPropertyService.Expectations()
        when(expectations.asyncName.get(), return: "async test name")

        let mock = MockTestAsyncPropertyService(expectations: expectations)
        let actualResult = await mock.asyncName

        #expect(actualResult == "async test name")
    }

    @Test
    func testAsyncReadOnlyProperty() async {
        var expectations = MockTestAsyncPropertyService.Expectations()
        when(expectations.asyncCount.get(), return: 42)

        let mock = MockTestAsyncPropertyService(expectations: expectations)
        let actualResult = await mock.asyncCount

        #expect(actualResult == 42)
    }

    @Test
    func testAsyncOptionalProperty() async {
        var expectations = MockTestAsyncPropertyService.Expectations()
        when(expectations.asyncOptionalValue.get(), return: "async optional value")

        let mock = MockTestAsyncPropertyService(expectations: expectations)
        
        let value = await mock.asyncOptionalValue
        #expect(value == "async optional value")
    }

    @Test
    func testAsyncOptionalPropertyWithNil() async {
        var expectations = MockTestAsyncPropertyService.Expectations()
        when(expectations.asyncOptionalValue.get(), return: nil)

        let mock = MockTestAsyncPropertyService(expectations: expectations)
        
        let value = await mock.asyncOptionalValue
        #expect(value == nil)
    }

    @Test
    func testAsyncPropertyWithMultipleExpectations() async {
        var expectations = MockTestAsyncPropertyService.Expectations()
        when(expectations.asyncName.get(), return: "first async")
        when(expectations.asyncName.get(), return: "second async")
        when(expectations.asyncName.get(), return: "third async")

        let mock = MockTestAsyncPropertyService(expectations: expectations)
        
        let first = await mock.asyncName
        let second = await mock.asyncName
        let third = await mock.asyncName
        
        #expect(first == "first async")
        #expect(second == "second async")
        #expect(third == "third async")
    }

    @Test
    func testAsyncPropertyWithTimesParameter() async {
        var expectations = MockTestAsyncPropertyService.Expectations()
        when(expectations.asyncName.get(), times: 3, return: "repeated async value")

        let mock = MockTestAsyncPropertyService(expectations: expectations)
        
        let first = await mock.asyncName
        let second = await mock.asyncName
        let third = await mock.asyncName
        
        #expect(first == "repeated async value")
        #expect(second == "repeated async value")
        #expect(third == "repeated async value")
        
        verify(mock, times: 3).asyncName.get()
    }

    @Test
    func testAsyncPropertyWithCustomClosure() async {
        var expectations = MockTestAsyncPropertyService.Expectations()
        when(expectations.asyncName.get(), times: .unbounded) {
            return "dynamic async value"
        }

        let mock = MockTestAsyncPropertyService(expectations: expectations)
        
        let first = await mock.asyncName
        let second = await mock.asyncName
        
        #expect(first == "dynamic async value")
        #expect(second == "dynamic async value")
    }

    @Test
    func testAsyncBooleanProperty() async {
        var expectations = MockTestAsyncPropertyService.Expectations()
        when(expectations.asyncIsActive.get(), return: true)

        let mock = MockTestAsyncPropertyService(expectations: expectations)
        
        let isActive = await mock.asyncIsActive
        #expect(isActive == true)
    }

    @Test
    func testAsyncComplexTypeProperty() async {
        var expectations = MockTestAsyncComplexPropertyService.Expectations()
        let testConfig = ["key1": "value1", "key2": "value2"]
        when(expectations.asyncConfiguration.get(), return: testConfig)

        let mock = MockTestAsyncComplexPropertyService(expectations: expectations)
        
        let config = await mock.asyncConfiguration
        #expect(config["key1"] as? String == "value1")
        #expect(config["key2"] as? String == "value2")
    }

    @Test
    func testAsyncArrayProperty() async {
        var expectations = MockTestAsyncComplexPropertyService.Expectations()
        when(expectations.asyncNumbers.get(), return: [1, 2, 3])

        let mock = MockTestAsyncComplexPropertyService(expectations: expectations)
        
        let numbers = await mock.asyncNumbers
        #expect(numbers == [1, 2, 3])
    }

    @Test
    func testMixedAsyncPropertyTypes() async {
        var expectations = MockTestAsyncPropertyService.Expectations()
        when(expectations.asyncName.get(), return: "async string value")
        when(expectations.asyncCount.get(), return: 100)
        when(expectations.asyncIsActive.get(), return: false)
        when(expectations.asyncOptionalValue.get(), return: "async optional")

        let mock = MockTestAsyncPropertyService(expectations: expectations)
        
        let name = await mock.asyncName
        let count = await mock.asyncCount
        let isActive = await mock.asyncIsActive
        let optional = await mock.asyncOptionalValue
        
        #expect(name == "async string value")
        #expect(count == 100)
        #expect(isActive == false)
        #expect(optional == "async optional")
        
        verify(mock, times: 1).asyncName.get()
        verify(mock, times: 1).asyncCount.get()
        verify(mock, times: 1).asyncIsActive.get()
        verify(mock, times: 1).asyncOptionalValue.get()
    }

    @Test
    func testAsyncPropertyWithUnboundedExpectations() async {
        var expectations = MockTestAsyncPropertyService.Expectations()
        when(expectations.asyncName.get(), times: .unbounded, return: "unbounded async")

        let mock = MockTestAsyncPropertyService(expectations: expectations)
        
        // Multiple gets
        let value1 = await mock.asyncName
        let value2 = await mock.asyncName
        let value3 = await mock.asyncName
        
        #expect(value1 == "unbounded async")
        #expect(value2 == "unbounded async")
        #expect(value3 == "unbounded async")
        
        verify(mock, times: 3).asyncName.get()
    }

    @Test
    func testAsyncPropertyConcurrentAccess() async {
        var expectations = MockTestAsyncPropertyService.Expectations()
        when(expectations.asyncName.get(), times: .unbounded, return: "concurrent async value")

        let mock = MockTestAsyncPropertyService(expectations: expectations)
        
        // Test concurrent access
        async let get1 = mock.asyncName
        async let get2 = mock.asyncName
        async let get3 = mock.asyncName
        
        let results = await [get1, get2, get3]
        
        #expect(results.allSatisfy { $0 == "concurrent async value" })
        
        verify(mock, times: 3).asyncName.get()
    }
}
