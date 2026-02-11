import Foundation
import Testing

@testable import Smockable

// MARK: - Actor Protocol Definitions

@Smock
protocol TestActorService: Actor {
    func process(id: String) async -> String
    func asyncThrowingMethod(name: String, count: Int) async throws -> String
    func voidMethod() async
}

@Smock
protocol TestActorPropertyService: Actor {
    var name: String { get async }
    var count: Int { get async throws }
}

@Smock
protocol TestSecondActorService: Actor {
    func execute(command: String) async -> Bool
}

enum ActorTestError: Error, Equatable {
    case processingFailed
    case notFound
}

// MARK: - Tests

struct ActorProtocolTests {

    // MARK: - Basic Actor Function Tests

    @Test
    func testBasicActorFunctionExpectationAndVerification() async {
        var expectations = MockTestActorService.Expectations()
        when(expectations.process(id: .any), return: "processed")

        let mock = MockTestActorService(expectations: expectations)

        let result = await mock.process(id: "test-123")

        #expect(result == "processed")
        verify(mock, times: 1).process(id: "test-123")
    }

    @Test
    func testActorVoidMethod() async {
        var expectations = MockTestActorService.Expectations()
        when(expectations.voidMethod(), complete: .withSuccess)

        let mock = MockTestActorService(expectations: expectations)

        await mock.voidMethod()

        verify(mock, times: 1).voidMethod()
    }

    @Test
    func testActorAsyncThrowingMethod() async throws {
        var expectations = MockTestActorService.Expectations()
        when(expectations.asyncThrowingMethod(name: .any, count: .any), return: "result")

        let mock = MockTestActorService(expectations: expectations)

        let result = try await mock.asyncThrowingMethod(name: "test", count: 5)

        #expect(result == "result")
        verify(mock, times: 1).asyncThrowingMethod(name: "test", count: 5)
    }

    @Test
    func testActorAsyncThrowingMethodThrows() async {
        var expectations = MockTestActorService.Expectations()
        when(expectations.asyncThrowingMethod(name: .any, count: .any), throw: ActorTestError.processingFailed)

        let mock = MockTestActorService(expectations: expectations)

        await #expect(throws: ActorTestError.processingFailed) {
            try await mock.asyncThrowingMethod(name: "test", count: 1)
        }
    }

    @Test
    func testActorMultipleExpectations() async {
        var expectations = MockTestActorService.Expectations()
        when(expectations.process(id: .any), return: "first")
        when(expectations.process(id: .any), return: "second")

        let mock = MockTestActorService(expectations: expectations)

        let result1 = await mock.process(id: "a")
        let result2 = await mock.process(id: "b")

        #expect(result1 == "first")
        #expect(result2 == "second")
        verify(mock, times: 2).process(id: .any)
    }

    // MARK: - Actor Property Tests

    @Test
    func testActorPropertyGet() async {
        var expectations = MockTestActorPropertyService.Expectations()
        when(expectations.name.get(), return: "Alice")

        let mock = MockTestActorPropertyService(expectations: expectations)

        let name = await mock.name

        #expect(name == "Alice")
        verify(mock, times: 1).name.get()
    }

    @Test
    func testActorThrowingPropertyGet() async throws {
        var expectations = MockTestActorPropertyService.Expectations()
        when(expectations.count.get(), return: 42)

        let mock = MockTestActorPropertyService(expectations: expectations)

        let count = try await mock.count

        #expect(count == 42)
        verify(mock, times: 1).count.get()
    }

    @Test
    func testActorThrowingPropertyThrows() async {
        var expectations = MockTestActorPropertyService.Expectations()
        when(expectations.count.get(), throw: ActorTestError.notFound)

        let mock = MockTestActorPropertyService(expectations: expectations)

        await #expect(throws: ActorTestError.notFound) {
            try await mock.count
        }
    }

    // MARK: - InOrder Verification with Actor Mocks

    @Test
    func testInOrderVerificationWithMultipleActorMocks() async {
        var expectations1 = MockTestActorService.Expectations()
        when(expectations1.process(id: .any), return: "from-service-1")

        var expectations2 = MockTestSecondActorService.Expectations()
        when(expectations2.execute(command: .any), return: true)

        let mock1 = MockTestActorService(expectations: expectations1)
        let mock2 = MockTestSecondActorService(expectations: expectations2)

        let result1 = await mock1.process(id: "step-1")
        let result2 = await mock2.execute(command: "step-2")

        #expect(result1 == "from-service-1")
        #expect(result2 == true)

        let inOrder = InOrder(strict: false, mock1, mock2)
        inOrder.verify(mock1).process(id: "step-1")
        inOrder.verify(mock2).execute(command: "step-2")
        inOrder.verifyNoMoreInteractions()
    }

    // MARK: - No Interactions Verification

    @Test
    func testActorVerifyNoInteractions() async {
        let mock = MockTestActorService()

        verifyNoInteractions(mock)
    }
}
