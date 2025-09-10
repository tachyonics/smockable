import Foundation
import Smockable
import Testing

@Smock
protocol TestVerificationService {
    func fetchUser(id: String) async throws -> String
    func updateUser(_ user: String) async throws
    func deleteUser(id: String) async throws
    func initialize() async
    func processData(input: String, count: Int) async -> String
}

struct FunctionStyleVerificationTests {

    @Test
    func testVerifyTimes() async throws {
        // Setup
        var expectations = MockTestVerificationService.Expectations()
        when(expectations.fetchUser(id: .any), times: .unbounded, return: "user")

        let mock = MockTestVerificationService(expectations: expectations)

        // Execute
        _ = try await mock.fetchUser(id: "123")
        _ = try await mock.fetchUser(id: "456")
        _ = try await mock.fetchUser(id: "789")

        // Verify - should pass
        verify(mock, times: 3).fetchUser(id: .any)

        // Verify with specific parameter - should pass
        verify(mock, times: 1).fetchUser(id: "123")

        // Verify with non-matching parameter - should pass (0 times)
        verify(mock, times: 0).fetchUser(id: "nonexistent")
    }

    @Test
    func testVerifyAtLeast() async throws {
        // Setup
        var expectations = MockTestVerificationService.Expectations()
        when(expectations.fetchUser(id: .any), times: .unbounded, return: "user")

        let mock = MockTestVerificationService(expectations: expectations)

        // Execute
        _ = try await mock.fetchUser(id: "123")
        _ = try await mock.fetchUser(id: "456")
        _ = try await mock.fetchUser(id: "789")

        // Verify - should pass
        verify(mock, atLeast: 1).fetchUser(id: .any)
        verify(mock, atLeast: 3).fetchUser(id: .any)
        verify(mock, atLeast: 1).fetchUser(id: "123")
    }

    @Test
    func testVerifyAtMost() async throws {
        // Setup
        var expectations = MockTestVerificationService.Expectations()
        when(expectations.fetchUser(id: .any), times: .unbounded, return: "user")

        let mock = MockTestVerificationService(expectations: expectations)

        // Execute
        _ = try await mock.fetchUser(id: "123")
        _ = try await mock.fetchUser(id: "456")

        // Verify - should pass
        verify(mock, atMost: 5).fetchUser(id: .any)
        verify(mock, atMost: 2).fetchUser(id: .any)
        verify(mock, atMost: 1).fetchUser(id: "123")
    }

    @Test
    func testVerifyNever() async throws {
        // Setup
        var expectations = MockTestVerificationService.Expectations()
        when(expectations.fetchUser(id: .any), return: "user")

        let mock = MockTestVerificationService(expectations: expectations)

        // Execute
        _ = try await mock.fetchUser(id: "123")

        // Verify - should pass
        verify(mock, .never).fetchUser(id: "nonexistent")
        verify(mock, .never).deleteUser(id: .any)
    }

    @Test
    func testVerifyAtLeastOnce() async throws {
        // Setup
        var expectations = MockTestVerificationService.Expectations()
        when(expectations.fetchUser(id: .any), return: "user")
        when(expectations.initialize(), complete: .withSuccess)

        let mock = MockTestVerificationService(expectations: expectations)

        // Execute
        _ = try await mock.fetchUser(id: "123")
        await mock.initialize()

        // Verify - should pass
        verify(mock, .atLeastOnce).fetchUser(id: .any)
        verify(mock, .atLeastOnce).fetchUser(id: "123")
        verify(mock, .atLeastOnce).initialize()
    }

    @Test
    func testVerifyRange() async throws {
        // Setup
        var expectations = MockTestVerificationService.Expectations()
        when(expectations.fetchUser(id: .any), times: .unbounded, return: "user")

        let mock = MockTestVerificationService(expectations: expectations)

        // Execute
        _ = try await mock.fetchUser(id: "123")
        _ = try await mock.fetchUser(id: "456")
        _ = try await mock.fetchUser(id: "789")

        // Verify - should pass
        verify(mock, times: 1...5).fetchUser(id: .any)
        verify(mock, times: 3...3).fetchUser(id: .any)
        verify(mock, times: 0...1).fetchUser(id: "123")
    }

    @Test
    func testVerifyFunctionWithNoParameters() async throws {
        // Setup
        var expectations = MockTestVerificationService.Expectations()
        when(expectations.initialize(), times: .unbounded, complete: .withSuccess)

        let mock = MockTestVerificationService(expectations: expectations)

        // Execute
        await mock.initialize()
        await mock.initialize()

        // Verify - should pass
        verify(mock, times: 2).initialize()
        verify(mock, atLeast: 1).initialize()
        verify(mock, atMost: 5).initialize()
        verify(mock, .atLeastOnce).initialize()
        verify(mock, times: 2...2).initialize()
    }

    @Test
    func testVerifyFunctionWithMultipleParameters() async throws {
        // Setup
        var expectations = MockTestVerificationService.Expectations()
        when(expectations.processData(input: .any, count: .any), times: .unbounded, return: "processed")

        let mock = MockTestVerificationService(expectations: expectations)

        // Execute
        _ = await mock.processData(input: "test1", count: 1)
        _ = await mock.processData(input: "test2", count: 2)
        _ = await mock.processData(input: "test1", count: 3)

        // Verify - should pass
        verify(mock, times: 3).processData(input: .any, count: .any)
        verify(mock, times: 2).processData(input: "test1", count: .any)
        verify(mock, times: 1).processData(input: .any, count: 2)
        verify(mock, times: 1).processData(input: "test1", count: 1)
        verify(mock, .never).processData(input: "nonexistent", count: .any)
    }

    @Test
    func testVerifyWithValueMatchers() async throws {
        // Setup
        var expectations = MockTestVerificationService.Expectations()
        when(expectations.processData(input: .any, count: .any), times: .unbounded, return: "processed")

        let mock = MockTestVerificationService(expectations: expectations)

        // Execute
        _ = await mock.processData(input: "apple", count: 5)
        _ = await mock.processData(input: "banana", count: 10)
        _ = await mock.processData(input: "cherry", count: 15)

        // Verify with range matchers - should pass
        verify(mock, times: 3).processData(input: "a"..."z", count: 1...20)
        verify(mock, times: 2).processData(input: "a"..."c", count: .any)
        verify(mock, times: 2).processData(input: .any, count: 10...15)
    }
}
