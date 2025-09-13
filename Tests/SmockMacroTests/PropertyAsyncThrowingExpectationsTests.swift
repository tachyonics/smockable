import Foundation
import Testing

@testable import Smockable

@Smock
protocol TestAsyncThrowingPropertyService {
    var asyncThrowingName: String { get async throws }
    var asyncThrowingReadOnlyData: Data { get async throws }
    var asyncThrowingOptionalValue: String? { get async throws }
    var asyncThrowingIsActive: Bool { get async throws }
    var asyncThrowingCount: Int { get async throws }
}

@Smock
protocol TestAsyncThrowingComplexPropertyService {
    var asyncThrowingConfiguration: [String: Sendable] { get async throws }
    var asyncThrowingNumbers: [Int] { get async throws }
    var asyncThrowingMetadata: [String: String] { get async throws }
}

enum AsyncPropertyError: Error, Equatable {
    case asyncGetterFailed
    case asyncSetterFailed
    case asyncInvalidValue
    case asyncNetworkError
    case asyncTimeout
}

struct PropertyAsyncThrowingExpectationsTests {

    @Test
    func testBasicAsyncThrowingPropertyGetter() async throws {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), return: "async throwing test name")

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)
        let actualResult = try await mock.asyncThrowingName

        #expect(actualResult == "async throwing test name")
    }

    @Test
    func testAsyncThrowingReadOnlyProperty() async throws {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingCount.get(), return: 42)

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)
        let actualResult = try await mock.asyncThrowingCount

        #expect(actualResult == 42)
    }

    @Test
    func testAsyncThrowingOptionalProperty() async throws {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingOptionalValue.get(), return: "async throwing optional value")

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)

        let value = try await mock.asyncThrowingOptionalValue
        #expect(value == "async throwing optional value")
    }

    @Test
    func testAsyncThrowingOptionalPropertyWithNil() async throws {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingOptionalValue.get(), return: nil)

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)

        let value = try await mock.asyncThrowingOptionalValue
        #expect(value == nil)
    }

    @Test
    func testAsyncThrowingPropertyGetterError() async {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), throw: AsyncPropertyError.asyncGetterFailed)

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)

        await #expect(throws: AsyncPropertyError.asyncGetterFailed) {
            _ = try await mock.asyncThrowingName
        }
    }

    @Test
    func testAsyncThrowingPropertyWithMultipleExpectations() async throws {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), return: "first async throwing")
        when(expectations.asyncThrowingName.get(), return: "second async throwing")
        when(expectations.asyncThrowingName.get(), return: "third async throwing")

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)

        let first = try await mock.asyncThrowingName
        let second = try await mock.asyncThrowingName
        let third = try await mock.asyncThrowingName

        #expect(first == "first async throwing")
        #expect(second == "second async throwing")
        #expect(third == "third async throwing")
    }

    @Test
    func testAsyncThrowingPropertyWithTimesParameter() async throws {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), times: 3, return: "repeated async throwing value")

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)

        let first = try await mock.asyncThrowingName
        let second = try await mock.asyncThrowingName
        let third = try await mock.asyncThrowingName

        #expect(first == "repeated async throwing value")
        #expect(second == "repeated async throwing value")
        #expect(third == "repeated async throwing value")

        verify(mock, times: 3).asyncThrowingName.get()
    }

    @Test
    func testAsyncThrowingPropertyWithCustomClosure() async throws {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), times: .unbounded) {
            return "dynamic async throwing value"
        }

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)

        let first = try await mock.asyncThrowingName
        let second = try await mock.asyncThrowingName

        #expect(first == "dynamic async throwing value")
        #expect(second == "dynamic async throwing value")
    }

    @Test
    func testAsyncThrowingPropertyWithCustomThrowingClosure() async {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), times: .unbounded) {
            throw AsyncPropertyError.asyncNetworkError
        }

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)

        await #expect(throws: AsyncPropertyError.asyncNetworkError) {
            _ = try await mock.asyncThrowingName
        }

        await #expect(throws: AsyncPropertyError.asyncNetworkError) {
            _ = try await mock.asyncThrowingName
        }
    }

    @Test
    func testAsyncThrowingBooleanProperty() async throws {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingIsActive.get(), return: true)

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)

        let isActive = try await mock.asyncThrowingIsActive
        #expect(isActive == true)
    }

    @Test
    func testAsyncThrowingComplexTypeProperty() async throws {
        var expectations = MockTestAsyncThrowingComplexPropertyService.Expectations()
        let testConfig = ["key1": "value1", "key2": "value2"]
        when(expectations.asyncThrowingConfiguration.get(), return: testConfig)

        let mock = MockTestAsyncThrowingComplexPropertyService(expectations: expectations)

        let config = try await mock.asyncThrowingConfiguration
        #expect(config["key1"] as? String == "value1")
        #expect(config["key2"] as? String == "value2")
    }

    @Test
    func testAsyncThrowingArrayProperty() async throws {
        var expectations = MockTestAsyncThrowingComplexPropertyService.Expectations()
        when(expectations.asyncThrowingNumbers.get(), return: [1, 2, 3])

        let mock = MockTestAsyncThrowingComplexPropertyService(expectations: expectations)

        let numbers = try await mock.asyncThrowingNumbers
        #expect(numbers == [1, 2, 3])
    }

    @Test
    func testMixedAsyncThrowingPropertyTypes() async throws {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), return: "async throwing string value")
        when(expectations.asyncThrowingCount.get(), return: 100)
        when(expectations.asyncThrowingIsActive.get(), return: false)
        when(expectations.asyncThrowingOptionalValue.get(), return: "async throwing optional")

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)

        let name = try await mock.asyncThrowingName
        let count = try await mock.asyncThrowingCount
        let isActive = try await mock.asyncThrowingIsActive
        let optional = try await mock.asyncThrowingOptionalValue

        #expect(name == "async throwing string value")
        #expect(count == 100)
        #expect(isActive == false)
        #expect(optional == "async throwing optional")

        verify(mock, times: 1).asyncThrowingName.get()
        verify(mock, times: 1).asyncThrowingCount.get()
        verify(mock, times: 1).asyncThrowingIsActive.get()
        verify(mock, times: 1).asyncThrowingOptionalValue.get()
    }

    @Test
    func testAsyncThrowingPropertyMixedSuccessAndError() async throws {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), return: "async success")
        when(expectations.asyncThrowingName.get(), throw: AsyncPropertyError.asyncGetterFailed)
        when(expectations.asyncThrowingName.get(), return: "async success again")

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)

        // First call succeeds
        let first = try await mock.asyncThrowingName
        #expect(first == "async success")

        // Second call throws
        await #expect(throws: AsyncPropertyError.asyncGetterFailed) {
            _ = try await mock.asyncThrowingName
        }

        // Third call succeeds
        let third = try await mock.asyncThrowingName
        #expect(third == "async success again")
    }

    @Test
    func testAsyncThrowingPropertyWithDifferentErrorTypes() async {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), throw: AsyncPropertyError.asyncGetterFailed)
        when(expectations.asyncThrowingName.get(), throw: NSError(domain: "async test", code: 123))
        when(expectations.asyncThrowingName.get(), throw: AsyncPropertyError.asyncTimeout)

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)

        await #expect(throws: AsyncPropertyError.asyncGetterFailed) {
            _ = try await mock.asyncThrowingName
        }

        await #expect(throws: NSError.self) {
            _ = try await mock.asyncThrowingName
        }

        await #expect(throws: AsyncPropertyError.asyncTimeout) {
            _ = try await mock.asyncThrowingName
        }
    }

    @Test
    func testAsyncThrowingPropertyWithUnboundedExpectations() async throws {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), times: .unbounded, return: "unbounded async throwing")

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)

        // Multiple gets
        let value1 = try await mock.asyncThrowingName
        let value2 = try await mock.asyncThrowingName
        let value3 = try await mock.asyncThrowingName

        #expect(value1 == "unbounded async throwing")
        #expect(value2 == "unbounded async throwing")
        #expect(value3 == "unbounded async throwing")

        verify(mock, times: 3).asyncThrowingName.get()
    }

    @Test
    func testAsyncThrowingPropertyConcurrentAccess() async throws {
        var expectations = MockTestAsyncThrowingPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), times: .unbounded, return: "concurrent value")

        let mock = MockTestAsyncThrowingPropertyService(expectations: expectations)

        // Test concurrent access
        async let get1 = mock.asyncThrowingName
        async let get2 = mock.asyncThrowingName
        async let get3 = mock.asyncThrowingName

        let results = try await [get1, get2, get3]

        #expect(results.allSatisfy { $0 == "concurrent value" })

        verify(mock, times: 3).asyncThrowingName.get()
    }
}
