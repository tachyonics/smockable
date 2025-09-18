import Foundation
import Testing

@testable import Smockable

@Smock
protocol TestPropertyService {
    // Sync properties
    var syncName: String { get set }
    var syncReadOnly: Int { get }
    var syncOptional: String? { get set }
    var syncBool: Bool { get set }
    var syncData: Data { get set }

    // Async properties (read-only only)
    var asyncName: String { get async }
    var asyncOptional: String? { get async }
    var asyncCount: Int { get async }
    var asyncBool: Bool { get async }

    // Throwing properties (read-only only)
    var throwingName: String { get throws }
    var throwingOptional: String? { get throws }
    var throwingCount: Int { get throws }

    // Async throwing properties (read-only only)
    var asyncThrowingName: String { get async throws }
    var asyncThrowingOptional: String? { get async throws }
    var asyncThrowingBool: Bool { get async throws }
}

@Smock
protocol TestComplexPropertyService {
    // Sync complex properties
    var syncArray: [String] { get set }
    var syncDictionary: [String: String] { get set }
    var syncSet: Set<Int> { get set }

    // Async complex properties (read-only only)
    var asyncArray: [String] { get async }
    var asyncDictionary: [String: String] { get async }

    // Throwing complex properties (read-only only)
    var throwingArray: [Int] { get throws }

    // Async throwing complex properties (read-only only)
    var asyncThrowingDictionary: [String: String] { get async throws }
}

enum PropertyTestError: Error, Equatable {
    case syncError
    case asyncError
    case throwingError
    case asyncThrowingError
}

struct CorePropertyTests {

    // MARK: - Sync Property Tests

    @Test
    func testSyncPropertyBasicGetterAndSetter() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.syncName.get(), return: "initial value")
        when(expectations.syncName.set(.any), complete: .withSuccess)
        when(expectations.syncName.get(), return: "updated value")

        var mock = MockTestPropertyService(expectations: expectations)

        // Test getter
        let initialValue = mock.syncName
        #expect(initialValue == "initial value")

        // Test setter
        mock.syncName = "new value"

        // Test getter after set
        let updatedValue = mock.syncName
        #expect(updatedValue == "updated value")

        // Verify calls
        verify(mock, times: 2).syncName.get()
        verify(mock, times: 1).syncName.set("new value")
    }

    @Test
    func testSyncPropertyWithValueMatchers() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.syncName.set("test"..."zebra"), complete: .withSuccess)
        when(expectations.syncName.set("exact"), complete: .withSuccess)

        var mock = MockTestPropertyService(expectations: expectations)

        mock.syncName = "zebra"  // Matches range
        mock.syncName = "exact"  // Matches exact

        verify(mock, times: 1).syncName.set("test"..."zebra")
        verify(mock, times: 1).syncName.set("exact")
        verify(mock, times: 2).syncName.set(.any)
    }

    @Test
    func testSyncReadOnlyProperty() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.syncReadOnly.get(), return: 42)

        let mock = MockTestPropertyService(expectations: expectations)

        let value = mock.syncReadOnly
        #expect(value == 42)

        verify(mock, times: 1).syncReadOnly.get()
    }

    @Test
    func testSyncOptionalProperty() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.syncOptional.get(), return: "optional value")
        when(expectations.syncOptional.set(.any), complete: .withSuccess)
        when(expectations.syncOptional.get(), return: nil)

        var mock = MockTestPropertyService(expectations: expectations)

        // Test non-nil value
        let value1 = mock.syncOptional
        #expect(value1 == "optional value")

        // Test setting nil
        mock.syncOptional = nil

        // Test getting nil
        let value2 = mock.syncOptional
        #expect(value2 == nil)

        verify(mock, times: 2).syncOptional.get()
        verify(mock, times: 1).syncOptional.set(nil)
    }

    @Test
    func testSyncBoolProperty() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.syncBool.get(), return: true)
        when(expectations.syncBool.set(.any), complete: .withSuccess)

        var mock = MockTestPropertyService(expectations: expectations)

        let value = mock.syncBool
        #expect(value == true)

        mock.syncBool = false

        verify(mock, times: 1).syncBool.get()
        verify(mock, times: 1).syncBool.set(false)
    }

    @Test
    func testSyncPropertyWithMultipleExpectations() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.syncName.get(), return: "first")
        when(expectations.syncName.get(), return: "second")
        when(expectations.syncName.get(), times: .unbounded, return: "repeated")

        let mock = MockTestPropertyService(expectations: expectations)

        let value1 = mock.syncName
        let value2 = mock.syncName
        let value3 = mock.syncName
        let value4 = mock.syncName

        #expect(value1 == "first")
        #expect(value2 == "second")
        #expect(value3 == "repeated")
        #expect(value4 == "repeated")

        verify(mock, times: 4).syncName.get()
    }

    @Test
    func testSyncPropertyWithCustomClosure() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.syncName.get(), times: .unbounded) {
            return "dynamic value"
        }

        let mock = MockTestPropertyService(expectations: expectations)

        let value1 = mock.syncName
        let value2 = mock.syncName

        #expect(value1 == "dynamic value")
        #expect(value2 == "dynamic value")

        verify(mock, times: 2).syncName.get()
    }

    // MARK: - Async Property Tests

    @Test
    func testAsyncPropertyBasicGetter() async {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.asyncName.get(), return: "async value")

        let mock = MockTestPropertyService(expectations: expectations)

        let value = await mock.asyncName
        #expect(value == "async value")

        verify(mock, times: 1).asyncName.get()
    }

    @Test
    func testAsyncPropertyWithMultipleExpectations() async {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.asyncName.get(), return: "first async")
        when(expectations.asyncName.get(), return: "second async")
        when(expectations.asyncName.get(), times: 3, return: "repeated async")

        let mock = MockTestPropertyService(expectations: expectations)

        let value1 = await mock.asyncName
        let value2 = await mock.asyncName
        let value3 = await mock.asyncName
        let value4 = await mock.asyncName
        let value5 = await mock.asyncName

        #expect(value1 == "first async")
        #expect(value2 == "second async")
        #expect(value3 == "repeated async")
        #expect(value4 == "repeated async")
        #expect(value5 == "repeated async")

        verify(mock, times: 5).asyncName.get()
    }

    @Test
    func testAsyncOptionalProperty() async {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.asyncOptional.get(), return: "async optional")
        when(expectations.asyncOptional.get(), return: nil)

        let mock = MockTestPropertyService(expectations: expectations)

        let value1 = await mock.asyncOptional
        let value2 = await mock.asyncOptional

        #expect(value1 == "async optional")
        #expect(value2 == nil)

        verify(mock, times: 2).asyncOptional.get()
    }

    @Test
    func testAsyncPropertyConcurrentAccess() async {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.asyncName.get(), times: .unbounded, return: "concurrent async")

        let mock = MockTestPropertyService(expectations: expectations)

        // Test concurrent access
        async let value1 = mock.asyncName
        async let value2 = mock.asyncName
        async let value3 = mock.asyncName

        let results = await [value1, value2, value3]

        #expect(results.allSatisfy { $0 == "concurrent async" })
        verify(mock, times: 3).asyncName.get()
    }

    // MARK: - Throwing Property Tests

    @Test
    func testThrowingPropertyBasicGetter() throws {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.throwingName.get(), return: "throwing value")

        let mock = MockTestPropertyService(expectations: expectations)

        let value = try mock.throwingName
        #expect(value == "throwing value")

        verify(mock, times: 1).throwingName.get()
    }

    @Test
    func testThrowingPropertyWithError() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.throwingName.get(), throw: PropertyTestError.throwingError)

        let mock = MockTestPropertyService(expectations: expectations)

        #expect(throws: PropertyTestError.throwingError) {
            _ = try mock.throwingName
        }

        verify(mock, times: 1).throwingName.get()
    }

    @Test
    func testThrowingPropertyMixedSuccessAndError() throws {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.throwingName.get(), return: "success")
        when(expectations.throwingName.get(), throw: PropertyTestError.throwingError)
        when(expectations.throwingName.get(), return: "success again")

        let mock = MockTestPropertyService(expectations: expectations)

        // First call succeeds
        let value1 = try mock.throwingName
        #expect(value1 == "success")

        // Second call throws
        #expect(throws: PropertyTestError.throwingError) {
            _ = try mock.throwingName
        }

        // Third call succeeds
        let value3 = try mock.throwingName
        #expect(value3 == "success again")

        verify(mock, times: 3).throwingName.get()
    }

    @Test
    func testThrowingPropertyWithCustomThrowingClosure() {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.throwingName.get(), times: .unbounded) {
            throw PropertyTestError.throwingError
        }

        let mock = MockTestPropertyService(expectations: expectations)

        #expect(throws: PropertyTestError.throwingError) {
            _ = try mock.throwingName
        }

        #expect(throws: PropertyTestError.throwingError) {
            _ = try mock.throwingName
        }

        verify(mock, times: 2).throwingName.get()
    }

    // MARK: - Async Throwing Property Tests

    @Test
    func testAsyncThrowingPropertyBasicGetter() async throws {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), return: "async throwing value")

        let mock = MockTestPropertyService(expectations: expectations)

        let value = try await mock.asyncThrowingName
        #expect(value == "async throwing value")

        verify(mock, times: 1).asyncThrowingName.get()
    }

    @Test
    func testAsyncThrowingPropertyWithError() async {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), throw: PropertyTestError.asyncThrowingError)

        let mock = MockTestPropertyService(expectations: expectations)

        await #expect(throws: PropertyTestError.asyncThrowingError) {
            _ = try await mock.asyncThrowingName
        }

        verify(mock, times: 1).asyncThrowingName.get()
    }

    @Test
    func testAsyncThrowingPropertyMixedSuccessAndError() async throws {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), return: "async success")
        when(expectations.asyncThrowingName.get(), throw: PropertyTestError.asyncThrowingError)
        when(expectations.asyncThrowingName.get(), return: "async success again")

        let mock = MockTestPropertyService(expectations: expectations)

        // First call succeeds
        let value1 = try await mock.asyncThrowingName
        #expect(value1 == "async success")

        // Second call throws
        await #expect(throws: PropertyTestError.asyncThrowingError) {
            _ = try await mock.asyncThrowingName
        }

        // Third call succeeds
        let value3 = try await mock.asyncThrowingName
        #expect(value3 == "async success again")

        verify(mock, times: 3).asyncThrowingName.get()
    }

    @Test
    func testAsyncThrowingPropertyConcurrentWithErrors() async throws {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.asyncThrowingName.get(), times: .unbounded, return: "concurrent success")
        when(expectations.asyncThrowingOptional.get(), times: .unbounded, throw: PropertyTestError.asyncThrowingError)

        let mock = MockTestPropertyService(expectations: expectations)

        // Test concurrent successful access
        async let value1 = mock.asyncThrowingName
        async let value2 = mock.asyncThrowingName

        let results = try await [value1, value2]
        #expect(results.allSatisfy { $0 == "concurrent success" })

        // Test concurrent error access
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await #expect(throws: PropertyTestError.asyncThrowingError) {
                    _ = try await mock.asyncThrowingOptional
                }
            }
            group.addTask {
                await #expect(throws: PropertyTestError.asyncThrowingError) {
                    _ = try await mock.asyncThrowingOptional
                }
            }
        }

        verify(mock, times: 2).asyncThrowingName.get()
        verify(mock, times: 2).asyncThrowingOptional.get()
    }

    // MARK: - Complex Property Type Tests

    @Test
    func testSyncComplexProperties() {
        var expectations = MockTestComplexPropertyService.Expectations()
        when(expectations.syncArray.get(), return: ["a", "b", "c"])
        when(expectations.syncArray.set(.any), complete: .withSuccess)
        when(expectations.syncDictionary.get(), return: ["key1": "value1", "key2": "value2"])
        when(expectations.syncSet.get(), return: Set([1, 2, 3]))

        var mock = MockTestComplexPropertyService(expectations: expectations)

        // Test array property
        let array = mock.syncArray
        #expect(array == ["a", "b", "c"])
        mock.syncArray = ["x", "y", "z"]

        // Test dictionary property
        let dict = mock.syncDictionary
        #expect(dict["key1"] == "value1")
        #expect(dict["key2"] == "value2")

        // Test set property
        let set = mock.syncSet
        #expect(set == Set([1, 2, 3]))

        verify(mock, times: 1).syncArray.get()
        verify(mock, times: 1).syncArray.set(.any)
        verify(mock, times: 1).syncDictionary.get()
        verify(mock, times: 1).syncSet.get()
    }

    @Test
    func testAsyncComplexProperties() async {
        var expectations = MockTestComplexPropertyService.Expectations()
        when(expectations.asyncArray.get(), return: ["async1", "async2"])
        when(expectations.asyncDictionary.get(), return: ["asyncKey": "asyncValue"])

        let mock = MockTestComplexPropertyService(expectations: expectations)

        let array = await mock.asyncArray
        let dict = await mock.asyncDictionary

        #expect(array == ["async1", "async2"])
        #expect(dict["asyncKey"] == "asyncValue")

        verify(mock, times: 1).asyncArray.get()
        verify(mock, times: 1).asyncDictionary.get()
    }

    @Test
    func testThrowingComplexProperties() throws {
        var expectations = MockTestComplexPropertyService.Expectations()
        when(expectations.throwingArray.get(), return: [10, 20, 30])

        let mock = MockTestComplexPropertyService(expectations: expectations)

        let array = try mock.throwingArray
        #expect(array == [10, 20, 30])

        verify(mock, times: 1).throwingArray.get()
    }

    @Test
    func testAsyncThrowingComplexProperties() async throws {
        var expectations = MockTestComplexPropertyService.Expectations()
        when(expectations.asyncThrowingDictionary.get(), return: ["asyncThrowingKey": "asyncThrowingValue"])

        let mock = MockTestComplexPropertyService(expectations: expectations)

        let dict = try await mock.asyncThrowingDictionary
        #expect(dict["asyncThrowingKey"] == "asyncThrowingValue")

        verify(mock, times: 1).asyncThrowingDictionary.get()
    }

    // MARK: - Mixed Property Type Tests

    @Test
    func testMixedPropertyTypesInSingleTest() async throws {
        var expectations = MockTestPropertyService.Expectations()

        // Setup expectations for all property types
        when(expectations.syncName.get(), return: "sync value")
        when(expectations.syncBool.get(), return: true)
        when(expectations.asyncName.get(), return: "async value")
        when(expectations.asyncCount.get(), return: 42)
        when(expectations.throwingName.get(), return: "throwing value")
        when(expectations.asyncThrowingName.get(), return: "async throwing value")
        when(expectations.asyncThrowingBool.get(), return: false)

        let mock = MockTestPropertyService(expectations: expectations)

        // Test all property types
        let syncValue = mock.syncName
        let syncBool = mock.syncBool
        let asyncValue = await mock.asyncName
        let asyncCount = await mock.asyncCount
        let throwingValue = try mock.throwingName
        let asyncThrowingValue = try await mock.asyncThrowingName
        let asyncThrowingBool = try await mock.asyncThrowingBool

        // Verify values
        #expect(syncValue == "sync value")
        #expect(syncBool == true)
        #expect(asyncValue == "async value")
        #expect(asyncCount == 42)
        #expect(throwingValue == "throwing value")
        #expect(asyncThrowingValue == "async throwing value")
        #expect(asyncThrowingBool == false)

        // Verify all calls
        verify(mock, times: 1).syncName.get()
        verify(mock, times: 1).syncBool.get()
        verify(mock, times: 1).asyncName.get()
        verify(mock, times: 1).asyncCount.get()
        verify(mock, times: 1).throwingName.get()
        verify(mock, times: 1).asyncThrowingName.get()
        verify(mock, times: 1).asyncThrowingBool.get()
    }

    // MARK: - Comprehensive Verification Tests

    @Test
    func testComprehensivePropertyVerificationPatterns() async throws {
        var expectations = MockTestPropertyService.Expectations()
        when(expectations.syncName.get(), times: .unbounded, return: "sync")
        when(expectations.asyncName.get(), times: .unbounded, return: "async")
        when(expectations.throwingName.get(), times: .unbounded, return: "throwing")
        when(expectations.asyncThrowingName.get(), times: .unbounded, return: "async throwing")

        let mock = MockTestPropertyService(expectations: expectations)

        // Execute multiple property accesses
        _ = mock.syncName
        _ = mock.syncName
        _ = mock.syncName

        _ = await mock.asyncName
        _ = await mock.asyncName

        _ = try mock.throwingName

        _ = try await mock.asyncThrowingName
        _ = try await mock.asyncThrowingName
        _ = try await mock.asyncThrowingName
        _ = try await mock.asyncThrowingName

        // Test all verification patterns
        verify(mock, times: 3).syncName.get()
        verify(mock, atLeast: 2).asyncName.get()
        verify(mock, atMost: 5).throwingName.get()
        verify(mock, .atLeastOnce).asyncThrowingName.get()
        verify(mock, times: 1...1).throwingName.get()
        verify(mock, times: 4...4).asyncThrowingName.get()
        verify(mock, .never).syncReadOnly.get()
    }

    // MARK: - Unhappy Path Tests

    #if SMOCKABLE_UNHAPPY_PATH_TESTING
    @Test
    func testSyncPropertyVerificationFailures() {
        expectVerificationFailures(messages: ["Expected syncName.get() to be called exactly 2 times, but was called 1 time"]) {
            var expectations = MockTestPropertyService.Expectations()
            when(expectations.syncName.get(), return: "test")
            
            let mock = MockTestPropertyService(expectations: expectations)
            
            // Access once but verify for 2 times - should fail
            _ = mock.syncName
            verify(mock, times: 2).syncName.get()
        }
    }
    
    @Test
    func testSyncPropertySetterVerificationFailures() {
        expectVerificationFailures(messages: ["Expected syncName.set(_ newValue: any) to never be called, but was called 1 time"]) {
            var expectations = MockTestPropertyService.Expectations()
            when(expectations.syncName.set(.any), complete: .withSuccess)
            
            var mock = MockTestPropertyService(expectations: expectations)
            
            // Set the property but verify it was never set - should fail
            mock.syncName = "test"
            verify(mock, .never).syncName.set(.any)
        }
    }
    
    @Test
    func testAsyncPropertyVerificationFailures() async {
        await expectVerificationFailures(messages: ["Expected asyncName.get() to be called at least 3 times, but was called 1 time"]) {
            var expectations = MockTestPropertyService.Expectations()
            when(expectations.asyncName.get(), return: "async value")
            
            let mock = MockTestPropertyService(expectations: expectations)
            
            // Access once but verify at least 3 times - should fail
            _ = await mock.asyncName
            verify(mock, atLeast: 3).asyncName.get()
        }
    }
    
    @Test
    func testThrowingPropertyVerificationFailures() {
        expectVerificationFailures(messages: ["Expected throwingName.get() to be called at most 0 times, but was called 1 time"]) {
            var expectations = MockTestPropertyService.Expectations()
            when(expectations.throwingName.get(), return: "throwing value")
            
            let mock = MockTestPropertyService(expectations: expectations)
            
            // Access once but verify at most 0 times - should fail
            _ = try? mock.throwingName
            verify(mock, atMost: 0).throwingName.get()
        }
    }
    
    @Test
    func testAsyncThrowingPropertyVerificationFailures() async {
        expectVerificationFailures(messages: ["Expected asyncThrowingName.get() to be called at least once, but was never called"]) {
            var expectations = MockTestPropertyService.Expectations()
            when(expectations.asyncThrowingName.get(), return: "async throwing value")
            
            let mock = MockTestPropertyService(expectations: expectations)
            
            // Don't access but verify at least once - should fail
            verify(mock, .atLeastOnce).asyncThrowingName.get()
        }
    }
    
    @Test
    func testReadOnlyPropertyVerificationFailures() {
        expectVerificationFailures(messages: ["Expected syncReadOnly.get() to be called exactly 1 time, but was called 0 times"]) {
            var expectations = MockTestPropertyService.Expectations()
            when(expectations.syncReadOnly.get(), return: 43)
            
            let mock = MockTestPropertyService(expectations: expectations)
            
            // Don't access but verify once - should fail
            verify(mock, times: 1).syncReadOnly.get()
        }
    }
    
    @Test
    func testMultiplePropertyVerificationFailures() {
        expectVerificationFailures(messages: ["Expected syncName.get() to be called exactly 3 times, but was called 1 time", "Expected syncReadOnly.get() to be called at least once, but was never called"]) {
            var expectations = MockTestPropertyService.Expectations()
            when(expectations.syncName.get(), return: "test")
            when(expectations.syncReadOnly.get(), return: 43)
            
            let mock = MockTestPropertyService(expectations: expectations)
            
            // Access syncName once
            _ = mock.syncName
            
            // Two failing verifications
            verify(mock, times: 3).syncName.get()  // Fail 1
            verify(mock, .atLeastOnce).syncReadOnly.get()  // Fail 2
        }
    }
    
    @Test
    func testPropertyRangeVerificationFailures() {
        expectVerificationFailures(messages: ["Expected syncName.get() to be called 2...4 times, but was called 1 time"]) {
            var expectations = MockTestPropertyService.Expectations()
            when(expectations.syncName.get(), times: .unbounded, return: "test")
            
            let mock = MockTestPropertyService(expectations: expectations)
            
            // Access once but verify range 2...4 times - should fail
            _ = mock.syncName
            verify(mock, times: 2...4).syncName.get()
        }
    }
    
    @Test
    func testMixedPropertyAndSetterVerificationFailures() async {
        await expectVerificationFailures(messages: ["Expected asyncName.get() to never be called, but was called 1 time",
                                                    "Expected syncName.set(_ newValue: any) to be called exactly 2 times, but was called 1 time"]) {
            var expectations = MockTestPropertyService.Expectations()
            when(expectations.asyncName.get(), return: "async")
            when(expectations.syncName.set(.any), complete: .withSuccess)
            
            var mock = MockTestPropertyService(expectations: expectations)
            
            // Access async property once and set sync property once
            _ = await mock.asyncName
            mock.syncName = "sync value"
            
            // Two failing verifications
            verify(mock, .never).asyncName.get()  // Fail 1 - was called
            verify(mock, times: 2).syncName.set(.any)  // Fail 2 - only called once
        }
    }
    #endif
}
