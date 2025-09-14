import Foundation
import Testing

@testable import Smockable

@Smock
protocol TestFunctionService {
    // Sync functions
    func syncFunction(id: String) -> String
    func syncVoidFunction()
    func syncMultiParam(name: String, count: Int, score: Double) -> String
    func syncOptionalParam(name: String, age: Int?) -> String

    // Async functions
    func asyncFunction(id: String) async -> String
    func asyncVoidFunction() async
    func asyncMultiParam(name: String, count: Int) async -> String
    func asyncOptionalParam(name: String, age: Int?) async -> String

    // Throwing functions
    func throwingFunction(id: String) throws -> String
    func throwingVoidFunction() throws
    func throwingMultiParam(name: String, count: Int) throws -> String

    // Async throwing functions
    func asyncThrowingFunction(id: String) async throws -> String
    func asyncThrowingVoidFunction() async throws
    func asyncThrowingMultiParam(name: String, count: Int) async throws -> String
}

enum TestFunctionError: Error, Equatable {
    case syncError
    case asyncError
    case throwingError
    case asyncThrowingError
}

struct CoreFunctionTests {

    // MARK: - Sync Function Tests

    @Test
    func testSyncFunctionBasicExpectationAndVerification() {
        var expectations = MockTestFunctionService.Expectations()
        when(expectations.syncFunction(id: .any), return: "sync result")
        when(expectations.syncVoidFunction(), complete: .withSuccess)

        let mock = MockTestFunctionService(expectations: expectations)

        let result = mock.syncFunction(id: "test")
        mock.syncVoidFunction()

        #expect(result == "sync result")
        verify(mock, times: 1).syncFunction(id: "test")
        verify(mock, times: 1).syncVoidFunction()
    }

    @Test
    func testSyncFunctionWithValueMatchers() {
        var expectations = MockTestFunctionService.Expectations()
        when(
            expectations.syncMultiParam(name: "a"..."m", count: 1...100, score: 0.0...10.0),
            times: 2,
            return: "range matched"
        )
        when(
            expectations.syncMultiParam(name: "exact", count: 42, score: 3.14),
            return: "exact matched"
        )

        let mock = MockTestFunctionService(expectations: expectations)

        let result1 = mock.syncMultiParam(name: "hello", count: 50, score: 5.5)
        let result2 = mock.syncMultiParam(name: "apple", count: 25, score: 2.2)
        let result3 = mock.syncMultiParam(name: "exact", count: 42, score: 3.14)

        #expect(result1 == "range matched")
        #expect(result2 == "range matched")
        #expect(result3 == "exact matched")

        verify(mock, times: 3).syncMultiParam(name: "a"..."m", count: 1...100, score: 0.0...10.0)
        verify(mock, times: 1).syncMultiParam(name: "exact", count: 42, score: 3.14)
    }

    @Test
    func testSyncFunctionWithOptionalParameters() {
        var expectations = MockTestFunctionService.Expectations()
        when(expectations.syncOptionalParam(name: .any, age: .any), times: .unbounded, return: "optional handled")

        let mock = MockTestFunctionService(expectations: expectations)

        let result1 = mock.syncOptionalParam(name: "test", age: 25)
        let result2 = mock.syncOptionalParam(name: "test", age: nil)

        #expect(result1 == "optional handled")
        #expect(result2 == "optional handled")

        verify(mock, times: 2).syncOptionalParam(name: .any, age: .any)
        verify(mock, times: 1).syncOptionalParam(name: "test", age: 25)
        verify(mock, times: 1).syncOptionalParam(name: "test", age: nil)
    }

    @Test
    func testSyncFunctionWithMultipleExpectationsAndCustomClosure() {
        var expectations = MockTestFunctionService.Expectations()
        when(expectations.syncFunction(id: .any), return: "first")
        when(expectations.syncFunction(id: .any), return: "second")
        when(expectations.syncFunction(id: .any), times: .unbounded) { id in
            return "dynamic-\(id)"
        }

        let mock = MockTestFunctionService(expectations: expectations)

        let result1 = mock.syncFunction(id: "test1")
        let result2 = mock.syncFunction(id: "test2")
        let result3 = mock.syncFunction(id: "test3")
        let result4 = mock.syncFunction(id: "test4")

        #expect(result1 == "first")
        #expect(result2 == "second")
        #expect(result3 == "dynamic-test3")
        #expect(result4 == "dynamic-test4")

        verify(mock, times: 4).syncFunction(id: .any)
    }

    // MARK: - Async Function Tests

    @Test
    func testAsyncFunctionBasicExpectationAndVerification() async {
        var expectations = MockTestFunctionService.Expectations()
        when(expectations.asyncFunction(id: .any), return: "async result")
        when(expectations.asyncVoidFunction(), complete: .withSuccess)

        let mock = MockTestFunctionService(expectations: expectations)

        let result = await mock.asyncFunction(id: "test")
        await mock.asyncVoidFunction()

        #expect(result == "async result")
        verify(mock, times: 1).asyncFunction(id: "test")
        verify(mock, times: 1).asyncVoidFunction()
    }

    @Test
    func testAsyncFunctionWithValueMatchers() async {
        var expectations = MockTestFunctionService.Expectations()
        when(
            expectations.asyncMultiParam(name: "test"..."zebra", count: 10...50),
            times: 3,
            return: "async range matched"
        )

        let mock = MockTestFunctionService(expectations: expectations)

        let result1 = await mock.asyncMultiParam(name: "value", count: 25)
        let result2 = await mock.asyncMultiParam(name: "word", count: 30)
        let result3 = await mock.asyncMultiParam(name: "text", count: 15)

        #expect(result1 == "async range matched")
        #expect(result2 == "async range matched")
        #expect(result3 == "async range matched")

        verify(mock, times: 3).asyncMultiParam(name: "test"..."zebra", count: 10...50)
    }

    @Test
    func testAsyncFunctionWithErrorExpectation() async throws {
        var expectations = MockTestFunctionService.Expectations()
        when(expectations.asyncThrowingFunction(id: "error"), throw: TestFunctionError.asyncError)
        when(expectations.asyncThrowingFunction(id: .any), return: "success")

        let mock = MockTestFunctionService(expectations: expectations)

        await #expect(throws: TestFunctionError.asyncError) {
            _ = try await mock.asyncThrowingFunction(id: "error")
        }

        let result = try await mock.asyncThrowingFunction(id: "success")
        #expect(result == "success")

        verify(mock, times: 2).asyncThrowingFunction(id: .any)
        verify(mock, times: 1).asyncThrowingFunction(id: "error")
        verify(mock, times: 1).asyncThrowingFunction(id: "success")
    }

    @Test
    func testAsyncFunctionConcurrentAccess() async {
        var expectations = MockTestFunctionService.Expectations()
        when(expectations.asyncFunction(id: .any), times: .unbounded, return: "concurrent result")

        let mock = MockTestFunctionService(expectations: expectations)

        // Test concurrent access
        async let result1 = mock.asyncFunction(id: "concurrent1")
        async let result2 = mock.asyncFunction(id: "concurrent2")
        async let result3 = mock.asyncFunction(id: "concurrent3")

        let results = await [result1, result2, result3]

        #expect(results.allSatisfy { $0 == "concurrent result" })
        verify(mock, times: 3).asyncFunction(id: .any)
    }

    // MARK: - Throwing Function Tests

    @Test
    func testThrowingFunctionBasicExpectationAndVerification() throws {
        var expectations = MockTestFunctionService.Expectations()
        when(expectations.throwingFunction(id: .any), return: "throwing result")
        when(expectations.throwingVoidFunction(), complete: .withSuccess)

        let mock = MockTestFunctionService(expectations: expectations)

        let result = try mock.throwingFunction(id: "test")
        try mock.throwingVoidFunction()

        #expect(result == "throwing result")
        verify(mock, times: 1).throwingFunction(id: "test")
        verify(mock, times: 1).throwingVoidFunction()
    }

    @Test
    func testThrowingFunctionWithErrors() {
        var expectations = MockTestFunctionService.Expectations()
        when(expectations.throwingFunction(id: "success"), return: "success result")
        when(expectations.throwingFunction(id: "error"), throw: TestFunctionError.throwingError)
        when(expectations.throwingVoidFunction(), throw: NSError(domain: "test", code: 1))

        let mock = MockTestFunctionService(expectations: expectations)

        // Test success case
        let result = try? mock.throwingFunction(id: "success")
        #expect(result == "success result")

        // Test error cases
        #expect(throws: TestFunctionError.throwingError) {
            _ = try mock.throwingFunction(id: "error")
        }

        #expect(throws: NSError.self) {
            try mock.throwingVoidFunction()
        }

        verify(mock, times: 2).throwingFunction(id: .any)
        verify(mock, times: 1).throwingVoidFunction()
    }

    @Test
    func testThrowingFunctionMixedSuccessAndError() throws {
        var expectations = MockTestFunctionService.Expectations()
        when(expectations.throwingMultiParam(name: .any, count: .any), return: "success")
        when(expectations.throwingMultiParam(name: .any, count: .any), throw: TestFunctionError.throwingError)
        when(expectations.throwingMultiParam(name: .any, count: .any), return: "success again")

        let mock = MockTestFunctionService(expectations: expectations)

        // First call succeeds
        let result1 = try mock.throwingMultiParam(name: "test1", count: 1)
        #expect(result1 == "success")

        // Second call throws
        #expect(throws: TestFunctionError.throwingError) {
            _ = try mock.throwingMultiParam(name: "test2", count: 2)
        }

        // Third call succeeds
        let result3 = try mock.throwingMultiParam(name: "test3", count: 3)
        #expect(result3 == "success again")

        verify(mock, times: 3).throwingMultiParam(name: .any, count: .any)
    }

    // MARK: - Async Throwing Function Tests

    @Test
    func testAsyncThrowingFunctionBasicExpectationAndVerification() async throws {
        var expectations = MockTestFunctionService.Expectations()
        when(expectations.asyncThrowingFunction(id: .any), return: "async throwing result")
        when(expectations.asyncThrowingVoidFunction(), complete: .withSuccess)

        let mock = MockTestFunctionService(expectations: expectations)

        let result = try await mock.asyncThrowingFunction(id: "test")
        try await mock.asyncThrowingVoidFunction()

        #expect(result == "async throwing result")
        verify(mock, times: 1).asyncThrowingFunction(id: "test")
        verify(mock, times: 1).asyncThrowingVoidFunction()
    }

    @Test
    func testAsyncThrowingFunctionWithErrors() async throws {
        var expectations = MockTestFunctionService.Expectations()
        when(expectations.asyncThrowingFunction(id: "success"), return: "async success")
        when(expectations.asyncThrowingFunction(id: "error"), throw: TestFunctionError.asyncThrowingError)

        let mock = MockTestFunctionService(expectations: expectations)

        // Test success case
        let result = try await mock.asyncThrowingFunction(id: "success")
        #expect(result == "async success")

        // Test error case
        await #expect(throws: TestFunctionError.asyncThrowingError) {
            _ = try await mock.asyncThrowingFunction(id: "error")
        }

        verify(mock, times: 2).asyncThrowingFunction(id: .any)
        verify(mock, times: 1).asyncThrowingFunction(id: "success")
        verify(mock, times: 1).asyncThrowingFunction(id: "error")
    }

    @Test
    func testAsyncThrowingFunctionConcurrentWithErrors() async throws {
        var expectations = MockTestFunctionService.Expectations()
        when(expectations.asyncThrowingFunction(id: "success"), times: .unbounded, return: "concurrent success")
        when(
            expectations.asyncThrowingFunction(id: "error"),
            times: .unbounded,
            throw: TestFunctionError.asyncThrowingError
        )

        let mock = MockTestFunctionService(expectations: expectations)

        // Test concurrent access with mixed success/error
        async let result1 = mock.asyncThrowingFunction(id: "success")
        async let result2 = mock.asyncThrowingFunction(id: "success")

        let results = try await [result1, result2]
        #expect(results.allSatisfy { $0 == "concurrent success" })

        // Test concurrent errors
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await #expect(throws: TestFunctionError.asyncThrowingError) {
                    _ = try await mock.asyncThrowingFunction(id: "error")
                }
            }
            group.addTask {
                await #expect(throws: TestFunctionError.asyncThrowingError) {
                    _ = try await mock.asyncThrowingFunction(id: "error")
                }
            }
        }

        verify(mock, times: 4).asyncThrowingFunction(id: .any)
        verify(mock, times: 2).asyncThrowingFunction(id: "success")
        verify(mock, times: 2).asyncThrowingFunction(id: "error")
    }

    // MARK: - Verification Pattern Tests

    @Test
    func testComprehensiveVerificationPatterns() async throws {
        var expectations = MockTestFunctionService.Expectations()
        when(expectations.syncFunction(id: .any), times: .unbounded, return: "sync")
        when(expectations.asyncFunction(id: .any), times: .unbounded, return: "async")
        when(expectations.throwingFunction(id: .any), times: .unbounded, return: "throwing")
        when(expectations.asyncThrowingFunction(id: .any), times: .unbounded, return: "async throwing")

        let mock = MockTestFunctionService(expectations: expectations)

        // Execute multiple calls
        _ = mock.syncFunction(id: "test1")
        _ = mock.syncFunction(id: "test2")
        _ = mock.syncFunction(id: "test3")

        _ = await mock.asyncFunction(id: "async1")
        _ = await mock.asyncFunction(id: "async2")

        _ = try mock.throwingFunction(id: "throw1")

        _ = try await mock.asyncThrowingFunction(id: "asyncThrow1")
        _ = try await mock.asyncThrowingFunction(id: "asyncThrow2")
        _ = try await mock.asyncThrowingFunction(id: "asyncThrow3")
        _ = try await mock.asyncThrowingFunction(id: "asyncThrow4")

        // Test all verification patterns
        verify(mock, times: 3).syncFunction(id: .any)
        verify(mock, atLeast: 2).asyncFunction(id: .any)
        verify(mock, atMost: 5).throwingFunction(id: .any)
        verify(mock, .atLeastOnce).asyncThrowingFunction(id: .any)
        verify(mock, times: 1...1).throwingFunction(id: .any)
        verify(mock, times: 4...4).asyncThrowingFunction(id: .any)
        verify(mock, .never).syncVoidFunction()

        // Test specific parameter verification
        verify(mock, times: 1).syncFunction(id: "test1")
        verify(mock, times: 1).asyncFunction(id: "async2")
        verify(mock, times: 1).asyncThrowingFunction(id: "asyncThrow4")
    }
}
