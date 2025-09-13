import Foundation
import Testing

@testable import Smockable

@Smock
protocol TestPropertyService {
    var name: String { get set }
    var isActive: Bool { get set }
    var count: Int { get }
    var optionalValue: String? { get set }
    var readOnlyData: Data { get }
}

@Smock
protocol TestComplexPropertyService {
    var configuration: [String: Sendable] { get set }
    var numbers: [Int] { get set }
    var metadata: [String: String] { get set }
}

struct PropertyStyleExpectationsTests {

    @Test
    func testBasicPropertyGetter() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.name.get(), return: "test name")

        let mock = MockTestPropertyService(expectations: expectations)
        let actualResult = mock.name

        #expect(actualResult == "test name")
    }

    @Test
    func testBasicPropertySetter() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.name.set(.any), complete: .withSuccess)

        var mock = MockTestPropertyService(expectations: expectations)
        mock.name = "new name"

        // Verify the setter was called
        verify(mock, times: 1).name.set("new name")
    }

    @Test
    func testPropertyGetterAndSetter() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.name.get(), return: "initial name")
        when(expectations.name.set(.any), complete: .withSuccess)
        when(expectations.name.get(), return: "updated name")

        var mock = MockTestPropertyService(expectations: expectations)
        
        // First get
        let initialValue = mock.name
        #expect(initialValue == "initial name")
        
        // Set
        mock.name = "new name"
        
        // Second get
        let updatedValue = mock.name
        #expect(updatedValue == "updated name")
    }

    @Test
    func testReadOnlyProperty() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.count.get(), return: 42)

        let mock = MockTestPropertyService(expectations: expectations)
        let actualResult = mock.count

        #expect(actualResult == 42)
    }

    @Test
    func testOptionalProperty() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.optionalValue.get(), return: "optional value")
        when(expectations.optionalValue.set(.any), complete: .withSuccess)

        var mock = MockTestPropertyService(expectations: expectations)
        
        let value = mock.optionalValue
        #expect(value == "optional value")
        
        mock.optionalValue = "new optional"
        verify(mock, times: 1).optionalValue.set("new optional")
    }

    @Test
    func testOptionalPropertyWithNil() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.optionalValue.get(), return: nil)
        when(expectations.optionalValue.set(.any), complete: .withSuccess)

        var mock = MockTestPropertyService(expectations: expectations)
        
        let value = mock.optionalValue
        #expect(value == nil)
        
        mock.optionalValue = nil
        verify(mock, times: 1).optionalValue.set(nil)
    }

    @Test
    func testPropertyWithValueMatchers() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.name.set("test"..."zebra"), complete: .withSuccess)

        var mock = MockTestPropertyService(expectations: expectations)
        
        mock.name = "value"
        verify(mock, times: 1).name.set("test"..."zebra")
    }

    @Test
    func testPropertyWithMultipleExpectations() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.name.get(), return: "first")
        when(expectations.name.get(), return: "second")
        when(expectations.name.get(), return: "third")

        let mock = MockTestPropertyService(expectations: expectations)
        
        let first = mock.name
        let second = mock.name
        let third = mock.name
        
        #expect(first == "first")
        #expect(second == "second")
        #expect(third == "third")
    }

    @Test
    func testPropertyWithTimesParameter() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.name.get(), times: 3, return: "repeated value")

        let mock = MockTestPropertyService(expectations: expectations)
        
        let first = mock.name
        let second = mock.name
        let third = mock.name
        
        #expect(first == "repeated value")
        #expect(second == "repeated value")
        #expect(third == "repeated value")
        
        verify(mock, times: 3).name.get()
    }

    @Test
    func testPropertySetterWithTimesParameter() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.name.set(.any), times: 2, complete: .withSuccess)

        var mock = MockTestPropertyService(expectations: expectations)
        
        mock.name = "first"
        mock.name = "second"
        
        verify(mock, times: 2).name.set(.any)
        verify(mock, times: 1).name.set("first")
        verify(mock, times: 1).name.set("second")
    }

    @Test
    func testPropertyWithCustomClosure() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.name.get(), times: .unbounded) {
            return "dynamic value"
        }

        let mock = MockTestPropertyService(expectations: expectations)
        
        let first = mock.name
        let second = mock.name
        
        #expect(first == "dynamic value")
        #expect(second == "dynamic value")
    }

    @Test
    func testBooleanProperty() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.isActive.get(), return: true)
        when(expectations.isActive.set(.any), complete: .withSuccess)

        var mock = MockTestPropertyService(expectations: expectations)
        
        let isActive = mock.isActive
        #expect(isActive == true)
        
        mock.isActive = false
        verify(mock, times: 1).isActive.set(false)
    }

    @Test
    func testComplexTypeProperty() {
        var expectations = MockTestComplexPropertyService.Expectations()
        let testConfig = ["key1": "value1", "key2": "value2"]
        when(expectations.configuration.get(), return: testConfig)
        when(expectations.configuration.set(.any), complete: .withSuccess)

        var mock = MockTestComplexPropertyService(expectations: expectations)
        
        let config = mock.configuration
        #expect(config["key1"] as? String == "value1")
        #expect(config["key2"] as? String == "value2")
        
        mock.configuration = ["new": "config"]
        verify(mock, times: 1).configuration.set(.any)
    }

    @Test
    func testArrayProperty() {
        var expectations = MockTestComplexPropertyService.Expectations()
        when(expectations.numbers.get(), return: [1, 2, 3])
        when(expectations.numbers.set(.any), complete: .withSuccess)

        var mock = MockTestComplexPropertyService(expectations: expectations)
        
        let numbers = mock.numbers
        #expect(numbers == [1, 2, 3])
        
        mock.numbers = [4, 5, 6]
        verify(mock, times: 1).numbers.set(.any)
    }

    @Test
    func testPropertySetterWithSpecificValues() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.name.set("specific"), complete: .withSuccess)
        when(expectations.name.set("another"), complete: .withSuccess)

        var mock = MockTestPropertyService(expectations: expectations)
        
        mock.name = "specific"
        mock.name = "another"
        
        verify(mock, times: 1).name.set("specific")
        verify(mock, times: 1).name.set("another")
        verify(mock, times: 2).name.set(.any)
    }

    @Test
    func testMixedPropertyTypes() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.name.get(), return: "string value")
        when(expectations.count.get(), return: 100)
        when(expectations.isActive.get(), return: false)
        when(expectations.optionalValue.get(), return: "optional")

        let mock = MockTestPropertyService(expectations: expectations)
        
        let name = mock.name
        let count = mock.count
        let isActive = mock.isActive
        let optional = mock.optionalValue
        
        #expect(name == "string value")
        #expect(count == 100)
        #expect(isActive == false)
        #expect(optional == "optional")
        
        verify(mock, times: 1).name.get()
        verify(mock, times: 1).count.get()
        verify(mock, times: 1).isActive.get()
        verify(mock, times: 1).optionalValue.get()
    }
}
