import Foundation
import Testing

@testable import Smockable

@Smock
protocol TestThrowingPropertyService {
    var throwingName: String { get throws }
    var throwingReadOnlyData: Data { get throws }
    var throwingOptionalValue: String? { get throws }
    var throwingIsActive: Bool { get throws }
    var throwingCount: Int { get throws }
}

@Smock
protocol TestThrowingComplexPropertyService {
    var throwingConfiguration: [String: Sendable] { get throws }
    var throwingNumbers: [Int] { get throws }
    var throwingMetadata: [String: String] { get throws }
}

enum PropertyError: Error, Equatable {
    case getterFailed
    case setterFailed
    case invalidValue
    case networkError
}

struct PropertyThrowingExpectationsTests {

    @Test
    func testBasicThrowingPropertyGetter() throws {
        var expectations = MockTestThrowingPropertyService.Expectations()
        when(expectations.throwingName.get(), return: "throwing test name")

        let mock = MockTestThrowingPropertyService(expectations: expectations)
        let actualResult = try mock.throwingName

        #expect(actualResult == "throwing test name")
    }

    @Test
    func testThrowingReadOnlyProperty() throws {
        var expectations = MockTestThrowingPropertyService.Expectations()
        when(expectations.throwingCount.get(), return: 42)

        let mock = MockTestThrowingPropertyService(expectations: expectations)
        let actualResult = try mock.throwingCount

        #expect(actualResult == 42)
    }

    @Test
    func testThrowingOptionalProperty() throws {
        var expectations = MockTestThrowingPropertyService.Expectations()
        when(expectations.throwingOptionalValue.get(), return: "throwing optional value")

        let mock = MockTestThrowingPropertyService(expectations: expectations)
        
        let value = try mock.throwingOptionalValue
        #expect(value == "throwing optional value")
    }

    @Test
    func testThrowingOptionalPropertyWithNil() throws {
        var expectations = MockTestThrowingPropertyService.Expectations()
        when(expectations.throwingOptionalValue.get(), return: nil)

        let mock = MockTestThrowingPropertyService(expectations: expectations)
        
        let value = try mock.throwingOptionalValue
        #expect(value == nil)
    }

    @Test
    func testThrowingPropertyGetterError() {
        var expectations = MockTestThrowingPropertyService.Expectations()
        when(expectations.throwingName.get(), throw: PropertyError.getterFailed)

        let mock = MockTestThrowingPropertyService(expectations: expectations)
        
        #expect(throws: PropertyError.getterFailed) {
            _ = try mock.throwingName
        }
    }

    @Test
    func testThrowingPropertyWithMultipleExpectations() throws {
        var expectations = MockTestThrowingPropertyService.Expectations()
        when(expectations.throwingName.get(), return: "first throwing")
        when(expectations.throwingName.get(), return: "second throwing")
        when(expectations.throwingName.get(), return: "third throwing")

        let mock = MockTestThrowingPropertyService(expectations: expectations)
        
        let first = try mock.throwingName
        let second = try mock.throwingName
        let third = try mock.throwingName
        
        #expect(first == "first throwing")
        #expect(second == "second throwing")
        #expect(third == "third throwing")
    }

    @Test
    func testThrowingPropertyWithTimesParameter() throws {
        var expectations = MockTestThrowingPropertyService.Expectations()
        when(expectations.throwingName.get(), times: 3, return: "repeated throwing value")

        let mock = MockTestThrowingPropertyService(expectations: expectations)
        
        let first = try mock.throwingName
        let second = try mock.throwingName
        let third = try mock.throwingName
        
        #expect(first == "repeated throwing value")
        #expect(second == "repeated throwing value")
        #expect(third == "repeated throwing value")
        
        verify(mock, times: 3).throwingName.get()
    }

    @Test
    func testThrowingPropertyWithCustomClosure() throws {
        var expectations = MockTestThrowingPropertyService.Expectations()
        when(expectations.throwingName.get(), times: .unbounded) {
            return "dynamic throwing value"
        }

        let mock = MockTestThrowingPropertyService(expectations: expectations)
        
        let first = try mock.throwingName
        let second = try mock.throwingName
        
        #expect(first == "dynamic throwing value")
        #expect(second == "dynamic throwing value")
    }

    @Test
    func testThrowingPropertyWithCustomThrowingClosure() {
        var expectations = MockTestThrowingPropertyService.Expectations()
        when(expectations.throwingName.get(), times: .unbounded) {
            throw PropertyError.networkError
        }

        let mock = MockTestThrowingPropertyService(expectations: expectations)
        
        #expect(throws: PropertyError.networkError) {
            _ = try mock.throwingName
        }
        
        #expect(throws: PropertyError.networkError) {
            _ = try mock.throwingName
        }
    }

    @Test
    func testThrowingBooleanProperty() throws {
        var expectations = MockTestThrowingPropertyService.Expectations()
        when(expectations.throwingIsActive.get(), return: true)

        let mock = MockTestThrowingPropertyService(expectations: expectations)
        
        let isActive = try mock.throwingIsActive
        #expect(isActive == true)
    }

    @Test
    func testThrowingComplexTypeProperty() throws {
        var expectations = MockTestThrowingComplexPropertyService.Expectations()
        let testConfig = ["key1": "value1", "key2": "value2"]
        when(expectations.throwingConfiguration.get(), return: testConfig)

        let mock = MockTestThrowingComplexPropertyService(expectations: expectations)
        
        let config = try mock.throwingConfiguration
        #expect(config["key1"] as? String == "value1")
        #expect(config["key2"] as? String == "value2")
    }

    @Test
    func testThrowingArrayProperty() throws {
        var expectations = MockTestThrowingComplexPropertyService.Expectations()
        when(expectations.throwingNumbers.get(), return: [1, 2, 3])

        let mock = MockTestThrowingComplexPropertyService(expectations: expectations)
        
        let numbers = try mock.throwingNumbers
        #expect(numbers == [1, 2, 3])
    }

    @Test
    func testMixedThrowingPropertyTypes() throws {
        var expectations = MockTestThrowingPropertyService.Expectations()
        when(expectations.throwingName.get(), return: "throwing string value")
        when(expectations.throwingCount.get(), return: 100)
        when(expectations.throwingIsActive.get(), return: false)
        when(expectations.throwingOptionalValue.get(), return: "throwing optional")

        let mock = MockTestThrowingPropertyService(expectations: expectations)
        
        let name = try mock.throwingName
        let count = try mock.throwingCount
        let isActive = try mock.throwingIsActive
        let optional = try mock.throwingOptionalValue
        
        #expect(name == "throwing string value")
        #expect(count == 100)
        #expect(isActive == false)
        #expect(optional == "throwing optional")
        
        verify(mock, times: 1).throwingName.get()
        verify(mock, times: 1).throwingCount.get()
        verify(mock, times: 1).throwingIsActive.get()
        verify(mock, times: 1).throwingOptionalValue.get()
    }

    @Test
    func testThrowingPropertyMixedSuccessAndError() throws {
        var expectations = MockTestThrowingPropertyService.Expectations()
        when(expectations.throwingName.get(), return: "success")
        when(expectations.throwingName.get(), throw: PropertyError.getterFailed)
        when(expectations.throwingName.get(), return: "success again")

        let mock = MockTestThrowingPropertyService(expectations: expectations)
        
        // First call succeeds
        let first = try mock.throwingName
        #expect(first == "success")
        
        // Second call throws
        #expect(throws: PropertyError.getterFailed) {
            _ = try mock.throwingName
        }
        
        // Third call succeeds
        let third = try mock.throwingName
        #expect(third == "success again")
    }

    @Test
    func testThrowingPropertyWithDifferentErrorTypes() {
        var expectations = MockTestThrowingPropertyService.Expectations()
        when(expectations.throwingName.get(), throw: PropertyError.getterFailed)
        when(expectations.throwingName.get(), throw: NSError(domain: "test", code: 123))
        when(expectations.throwingName.get(), throw: PropertyError.invalidValue)

        let mock = MockTestThrowingPropertyService(expectations: expectations)
        
        #expect(throws: PropertyError.getterFailed) {
            _ = try mock.throwingName
        }
        
        #expect(throws: NSError.self) {
            _ = try mock.throwingName
        }
        
        #expect(throws: PropertyError.invalidValue) {
            _ = try mock.throwingName
        }
    }

    @Test
    func testThrowingPropertyWithUnboundedExpectations() throws {
        var expectations = MockTestThrowingPropertyService.Expectations()
        when(expectations.throwingName.get(), times: .unbounded, return: "unbounded throwing")

        let mock = MockTestThrowingPropertyService(expectations: expectations)
        
        // Multiple gets
        let value1 = try mock.throwingName
        let value2 = try mock.throwingName
        let value3 = try mock.throwingName
        
        #expect(value1 == "unbounded throwing")
        #expect(value2 == "unbounded throwing")
        #expect(value3 == "unbounded throwing")
        
        verify(mock, times: 3).throwingName.get()
    }
}
