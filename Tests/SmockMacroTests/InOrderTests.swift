import Foundation
import Testing

@testable import Smockable

// Test protocol for InOrder verification
@Smock
protocol TestInOrderService {
    func firstMethod(id: String) -> String
    func secondMethod(count: Int) -> Int
    func thirdMethod() -> Bool
    func voidMethod()
}

struct InOrderTests {

    // MARK: - Basic InOrder Tests

    @Test
    func testBasicInOrderVerification() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), return: "first")
        when(expectations.secondMethod(count: .any), return: 42)
        when(expectations.thirdMethod(), return: true)

        let mock = MockTestInOrderService(expectations: expectations)

        // Execute methods in order
        let result1 = mock.firstMethod(id: "test1")
        let result2 = mock.secondMethod(count: 10)
        let result3 = mock.thirdMethod()

        #expect(result1 == "first")
        #expect(result2 == 42)
        #expect(result3 == true)

        // Verify in order
        let inOrder = InOrder(strict: false, mock)
        inOrder.verify(mock).firstMethod(id: "test1")
        inOrder.verify(mock).secondMethod(count: 10)
        inOrder.verify(mock).thirdMethod()
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testStrictInOrderVerification() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
        when(expectations.secondMethod(count: .any), times: .unbounded, return: 1)

        let mock = MockTestInOrderService(expectations: expectations)

        // Execute methods
        _ = mock.firstMethod(id: "test1")
        _ = mock.firstMethod(id: "test2")
        _ = mock.secondMethod(count: 5)

        // Verify in strict order
        let inOrder = InOrder(strict: true, mock)
        inOrder.verify(mock).firstMethod(id: "test1")
        inOrder.verify(mock).firstMethod(id: "test2")
        inOrder.verify(mock).secondMethod(count: 5)
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testNonStrictAllowsSkipping() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
        when(expectations.secondMethod(count: .any), times: .unbounded, return: 1)
        when(expectations.voidMethod(), times: .unbounded, complete: .withSuccess)

        let mock = MockTestInOrderService(expectations: expectations)

        // Execute methods with some interactions we'll skip
        _ = mock.firstMethod(id: "skip1")
        _ = mock.secondMethod(count: 1)
        _ = mock.firstMethod(id: "verify1")
        mock.voidMethod()
        _ = mock.firstMethod(id: "verify2")
        _ = mock.secondMethod(count: 2)

        // Non-strict mode can skip interactions
        let inOrder = InOrder(strict: false, mock)
        inOrder.verify(mock).firstMethod(id: "verify1")  // Skips the first two calls
        inOrder.verify(mock).firstMethod(id: "verify2")  // Skips voidMethod
        inOrder.verify(mock).secondMethod(count: 2)
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testMultipleMocksInOrder() {
        var expectations1 = MockTestInOrderService.Expectations()
        when(expectations1.firstMethod(id: .any), return: "mock1")

        var expectations2 = MockTestInOrderService.Expectations()
        when(expectations2.secondMethod(count: .any), return: 100)

        let mock1 = MockTestInOrderService(expectations: expectations1)
        let mock2 = MockTestInOrderService(expectations: expectations2)

        // Execute methods on different mocks
        _ = mock1.firstMethod(id: "test")
        _ = mock2.secondMethod(count: 20)

        // Verify in order across mocks
        let inOrder = InOrder(strict: false, mock1, mock2)
        inOrder.verify(mock1).firstMethod(id: "test")
        inOrder.verify(mock2).secondMethod(count: 20)
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testInterleavedMockCalls() {
        var expectations1 = MockTestInOrderService.Expectations()
        when(expectations1.firstMethod(id: .any), times: .unbounded, return: "mock1")
        when(expectations1.secondMethod(count: .any), times: .unbounded, return: 1)

        var expectations2 = MockTestInOrderService.Expectations()
        when(expectations2.firstMethod(id: .any), times: .unbounded, return: "mock2")
        when(expectations2.thirdMethod(), times: .unbounded, return: true)

        let mock1 = MockTestInOrderService(expectations: expectations1)
        let mock2 = MockTestInOrderService(expectations: expectations2)

        // Interleaved calls
        _ = mock1.firstMethod(id: "call1")
        _ = mock2.firstMethod(id: "call2")
        _ = mock1.secondMethod(count: 10)
        _ = mock2.thirdMethod()

        // Verify global ordering is maintained
        let inOrder = InOrder(strict: false, mock1, mock2)
        inOrder.verify(mock1).firstMethod(id: "call1")
        inOrder.verify(mock2).firstMethod(id: "call2")
        inOrder.verify(mock1).secondMethod(count: 10)
        inOrder.verify(mock2).thirdMethod()
        inOrder.verifyNoMoreInteractions()
    }

    // MARK: - Verification Mode Tests

    @Test
    func testAdditionalTimesVerification() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")

        let mock = MockTestInOrderService(expectations: expectations)

        // Execute method multiple times
        _ = mock.firstMethod(id: "test1")
        _ = mock.firstMethod(id: "test2")
        _ = mock.firstMethod(id: "test3")

        // Verify multiple times in order
        let inOrder = InOrder(strict: false, mock)
        inOrder.verify(mock, additionalTimes: 3).firstMethod(id: .any)
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testAdditionalAtLeastVerification() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")

        let mock = MockTestInOrderService(expectations: expectations)

        // Execute method multiple times
        _ = mock.firstMethod(id: "test1")
        _ = mock.firstMethod(id: "test2")
        _ = mock.firstMethod(id: "test3")
        _ = mock.firstMethod(id: "test4")

        // Verify at least some calls (greedy matching)
        let inOrder = InOrder(strict: false, mock)
        inOrder.verify(mock, additionalAtLeast: 2).firstMethod(id: .any)
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testAdditionalAtMostVerification() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")

        let mock = MockTestInOrderService(expectations: expectations)

        // Execute method multiple times
        _ = mock.firstMethod(id: "test1")
        _ = mock.firstMethod(id: "test2")
        _ = mock.firstMethod(id: "test3")

        let inOrder = InOrder(strict: false, mock)
        inOrder.verify(mock, additionalAtMost: 5).firstMethod(id: .any)  // Should verify all 3
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testVerificationModeVariants() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
        when(expectations.secondMethod(count: .any), times: .unbounded, return: 1)

        let mock = MockTestInOrderService(expectations: expectations)

        // Execute methods
        _ = mock.firstMethod(id: "test1")
        _ = mock.firstMethod(id: "test2")
        _ = mock.secondMethod(count: 5)
        _ = mock.secondMethod(count: 6)
        _ = mock.secondMethod(count: 7)

        let inOrder = InOrder(strict: false, mock)

        // Test different verification mode syntax
        inOrder.verify(mock, .additionalTimes(2)).firstMethod(id: .any)
        inOrder.verify(mock, .additionalAtLeast(1)).secondMethod(count: .any)
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testNeverVerificationMode() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), return: "result")

        let mock = MockTestInOrderService(expectations: expectations)

        _ = mock.firstMethod(id: "test")

        let inOrder = InOrder(strict: false, mock)
        inOrder.verify(mock).firstMethod(id: "test")
        // Verify that secondMethod was never called in order after firstMethod
        inOrder.verify(mock, .additionalNone).secondMethod(count: .any)
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testAtLeastOnceVerificationMode() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")

        let mock = MockTestInOrderService(expectations: expectations)

        _ = mock.firstMethod(id: "test1")
        _ = mock.firstMethod(id: "test2")
        _ = mock.firstMethod(id: "test3")

        let inOrder = InOrder(strict: false, mock)
        inOrder.verify(mock, .additionalAtLeastOnce).firstMethod(id: .any)
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testRangeVerificationMode() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")

        let mock = MockTestInOrderService(expectations: expectations)

        _ = mock.firstMethod(id: "test1")
        _ = mock.firstMethod(id: "test2")
        _ = mock.firstMethod(id: "test3")

        let inOrder = InOrder(strict: false, mock)
        inOrder.verify(mock, .additionalRange(2...5)).firstMethod(id: .any)
        inOrder.verifyNoMoreInteractions()
    }

    // MARK: - Edge Cases

    @Test
    func testVoidMethodVerification() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.voidMethod(), times: .unbounded, complete: .withSuccess)
        when(expectations.firstMethod(id: .any), return: "after")

        let mock = MockTestInOrderService(expectations: expectations)

        mock.voidMethod()
        mock.voidMethod()
        _ = mock.firstMethod(id: "test")

        let inOrder = InOrder(strict: false, mock)
        inOrder.verify(mock, additionalTimes: 2).voidMethod()
        inOrder.verify(mock).firstMethod(id: "test")
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testSingleMockMultipleCalls() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")

        let mock = MockTestInOrderService(expectations: expectations)

        // Many calls to same method
        for i in 1...10 {
            _ = mock.firstMethod(id: "call\(i)")
        }

        let inOrder = InOrder(strict: true, mock)

        // Verify them one by one in strict order
        for i in 1...10 {
            inOrder.verify(mock).firstMethod(id: "call\(i)")
        }
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testEmptyInOrderCreation() {
        // Should be able to create InOrder with no mocks
        let inOrder = InOrder(strict: false)
        inOrder.verifyNoMoreInteractions()  // Should pass with no mocks
    }

    @Test
    func testGreedyAtLeastMatching() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
        when(expectations.secondMethod(count: .any), return: 42)

        let mock = MockTestInOrderService(expectations: expectations)

        // Execute many matching calls
        _ = mock.firstMethod(id: "test1")
        _ = mock.firstMethod(id: "test2")
        _ = mock.firstMethod(id: "test3")
        _ = mock.firstMethod(id: "test4")
        _ = mock.firstMethod(id: "test5")
        _ = mock.secondMethod(count: 1)  // Different call to stop greedy matching

        let inOrder = InOrder(strict: false, mock)

        // AtLeast should greedily consume all matching calls before the different one
        inOrder.verify(mock, additionalAtLeast: 2).firstMethod(id: .any)  // Should consume all 5
        inOrder.verify(mock).secondMethod(count: 1)
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testPartialVerificationInNonStrictMode() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
        when(expectations.secondMethod(count: .any), times: .unbounded, return: 1)
        when(expectations.thirdMethod(), times: .unbounded, return: true)

        let mock = MockTestInOrderService(expectations: expectations)

        _ = mock.firstMethod(id: "test1")
        _ = mock.secondMethod(count: 1)
        _ = mock.firstMethod(id: "test2")
        _ = mock.thirdMethod()
        _ = mock.secondMethod(count: 2)

        let inOrder = InOrder(strict: false, mock)

        // Only verify some of the interactions, leaving others unverified
        inOrder.verify(mock).firstMethod(id: "test1")
        inOrder.verify(mock).firstMethod(id: "test2")
        inOrder.verify(mock).secondMethod(count: 2)

        // verifyNoMoreInteractions should pass because unverified calls
        // in non-strict mode don't count as "more interactions"
        inOrder.verifyNoMoreInteractions()
    }

    @Test
    func testValueMatcherCompatibility() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
        when(expectations.secondMethod(count: .any), times: .unbounded, return: 1)

        let mock = MockTestInOrderService(expectations: expectations)

        _ = mock.firstMethod(id: "exact")
        _ = mock.firstMethod(id: "range")
        _ = mock.secondMethod(count: 5)
        _ = mock.secondMethod(count: 15)

        let inOrder = InOrder(strict: false, mock)

        // Test various matcher types work in ordered verification
        inOrder.verify(mock).firstMethod(id: "exact")  // Exact match
        inOrder.verify(mock).firstMethod(id: .any)  // Any match
        inOrder.verify(mock).secondMethod(count: 1...10)  // Range match
        inOrder.verify(mock).secondMethod(count: 10...20)  // Range match
        inOrder.verifyNoMoreInteractions()
    }

    // MARK: - Stress Tests

    @Test
    func testLargeNumberOfInteractions() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
        when(expectations.secondMethod(count: .any), times: .unbounded, return: 1)

        let mock = MockTestInOrderService(expectations: expectations)

        // Create many interactions
        for i in 1...1000 {
            if i % 2 == 0 {
                _ = mock.firstMethod(id: "even\(i)")
            } else {
                _ = mock.secondMethod(count: i)
            }
        }

        let inOrder = InOrder(strict: false, mock)

        // Verify a subset in order
        inOrder.verify(mock).secondMethod(count: 1)
        inOrder.verify(mock).firstMethod(id: "even2")
        inOrder.verify(mock).secondMethod(count: 3)
        inOrder.verify(mock).firstMethod(id: "even4")

        // Should be able to verify more without issues
        inOrder.verify(mock, additionalAtLeast: 5).firstMethod(id: .any)
        inOrder.verifyNoMoreInteractions()
    }

    @Test(
        arguments: [true, false],
        [
            InOrderVerificationMode.additionalTimes(2), InOrderVerificationMode.additionalAtMost(2),
            InOrderVerificationMode.additionalRange(1...2),
        ]
    )
    func testLargeNumberOfInteractionsFullVerification(strict: Bool, verificationMode: InOrderVerificationMode) {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
        when(expectations.secondMethod(count: .any), times: .unbounded, return: 1)

        let mock = MockTestInOrderService(expectations: expectations)

        // Create many interactions
        for i in 1...1000 {
            if i % 2 == 0 {
                _ = mock.firstMethod(id: "input")
                _ = mock.firstMethod(id: "input")
            } else {
                _ = mock.secondMethod(count: 556)
                _ = mock.secondMethod(count: 556)
            }
        }

        let inOrder = InOrder(strict: strict, mock)

        for i in 1...1000 {
            if i % 2 == 0 {
                inOrder.verify(mock, verificationMode).firstMethod(id: "input")
            } else {
                inOrder.verify(mock, verificationMode).secondMethod(count: 556)
            }
        }
        inOrder.verifyNoMoreInteractions()
    }

    // MARK: - Trailing Closure Shorthand Tests

    @Test
    func testTrailingClosureNonStrict() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), return: "first")
        when(expectations.secondMethod(count: .any), return: 42)
        when(expectations.thirdMethod(), return: true)

        let mock = MockTestInOrderService(expectations: expectations)

        _ = mock.firstMethod(id: "test1")
        _ = mock.secondMethod(count: 10)
        _ = mock.thirdMethod()

        InOrder(strict: false, mock) { inOrder in
            inOrder.verify(mock).firstMethod(id: "test1")
            inOrder.verify(mock).secondMethod(count: 10)
            inOrder.verify(mock).thirdMethod()
        }
    }

    @Test
    func testTrailingClosureStrict() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
        when(expectations.secondMethod(count: .any), times: .unbounded, return: 1)

        let mock = MockTestInOrderService(expectations: expectations)

        _ = mock.firstMethod(id: "test1")
        _ = mock.firstMethod(id: "test2")
        _ = mock.secondMethod(count: 5)

        InOrder(strict: true, mock) { inOrder in
            inOrder.verify(mock).firstMethod(id: "test1")
            inOrder.verify(mock).firstMethod(id: "test2")
            inOrder.verify(mock).secondMethod(count: 5)
        }
    }

    @Test
    func testTrailingClosureMultipleMocks() {
        var expectations1 = MockTestInOrderService.Expectations()
        when(expectations1.firstMethod(id: .any), return: "mock1")

        var expectations2 = MockTestInOrderService.Expectations()
        when(expectations2.secondMethod(count: .any), return: 100)

        let mock1 = MockTestInOrderService(expectations: expectations1)
        let mock2 = MockTestInOrderService(expectations: expectations2)

        _ = mock1.firstMethod(id: "test")
        _ = mock2.secondMethod(count: 20)

        InOrder(strict: false, mock1, mock2) { inOrder in
            inOrder.verify(mock1).firstMethod(id: "test")
            inOrder.verify(mock2).secondMethod(count: 20)
        }
    }

    @Test
    func testTrailingClosureWithVerificationModes() {
        var expectations = MockTestInOrderService.Expectations()
        when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
        when(expectations.secondMethod(count: .any), times: .unbounded, return: 1)

        let mock = MockTestInOrderService(expectations: expectations)

        _ = mock.firstMethod(id: "test1")
        _ = mock.firstMethod(id: "test2")
        _ = mock.firstMethod(id: "test3")
        _ = mock.secondMethod(count: 5)
        _ = mock.secondMethod(count: 6)
        _ = mock.secondMethod(count: 7)

        InOrder(strict: false, mock) { inOrder in
            inOrder.verify(mock, .additionalTimes(3)).firstMethod(id: .any)
            inOrder.verify(mock, .additionalAtLeast(1)).secondMethod(count: .any)
        }
    }

    // MARK: - Fatal Error Tests (Swift 6.2+)

    #if swift(>=6.2)
    // These tests require Swift 6.2+ for improved fatalError testing support

    @Test
    func testMockNotInConstructorFails() async {
        await #expect(processExitsWith: .failure) {
            var expectations1 = MockTestInOrderService.Expectations()
            when(expectations1.firstMethod(id: .any), return: "mock1")

            var expectations2 = MockTestInOrderService.Expectations()
            when(expectations2.secondMethod(count: .any), return: 100)

            let mock1 = MockTestInOrderService(expectations: expectations1)
            let mock2 = MockTestInOrderService(expectations: expectations2)

            // Only add mock1 to InOrder
            let inOrder = InOrder(strict: false, mock1)

            // This should work
            _ = mock1.firstMethod(id: "test")
            inOrder.verify(mock1).firstMethod(id: "test")

            // This should fail with fatalError
            _ = mock2.secondMethod(count: 20)
            inOrder.verify(mock2).secondMethod(count: 20)
        }
    }
    #endif

    // MARK: - Unhappy Path Tests

    #if SMOCKABLE_UNHAPPY_PATH_TESTING
    @Test
    func testInOrderVerificationFailureWrongOrder() {
        expectVerificationFailures(messages: [
            "Expected secondMethod(count: 5) to be called an additional 1 time, but was called 0 times"
        ]) {
            var expectations = MockTestInOrderService.Expectations()
            when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
            when(expectations.secondMethod(count: .any), times: .unbounded, return: 42)

            let mock = MockTestInOrderService(expectations: expectations)
            let inOrder = InOrder(strict: false, mock)

            // Call in one order
            _ = mock.secondMethod(count: 5)
            _ = mock.firstMethod(id: "first")

            // Verify in different order - should fail
            inOrder.verify(mock, additionalTimes: 1).firstMethod(id: "first")
            inOrder.verify(mock, additionalTimes: 1).secondMethod(count: 5)
        }
    }

    @Test
    func testInOrderVerificationFailureNotEnoughCalls() {
        expectVerificationFailures(messages: [
            "Expected firstMethod(id: any) to be called an additional 2 times, but was called 1 time"
        ]) {
            var expectations = MockTestInOrderService.Expectations()
            when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")

            let mock = MockTestInOrderService(expectations: expectations)
            let inOrder = InOrder(strict: false, mock)

            // Call once
            _ = mock.firstMethod(id: "test")

            // Verify for 2 additional times - should fail
            inOrder.verify(mock, additionalTimes: 2).firstMethod(id: .any)
        }
    }

    @Test
    func testInOrderVerificationFailureAtLeast() {
        expectVerificationFailures(messages: [
            "Expected firstMethod(id: any) to be called at least an additional 3 times, but was called 1 time"
        ]) {
            var expectations = MockTestInOrderService.Expectations()
            when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")

            let mock = MockTestInOrderService(expectations: expectations)
            let inOrder = InOrder(strict: false, mock)

            // Call once
            _ = mock.firstMethod(id: "test")

            // Verify at least 3 additional times - should fail
            inOrder.verify(mock, additionalAtLeast: 3).firstMethod(id: .any)
        }
    }

    @Test
    func testInOrderVerificationFailureNeverCalled() {
        expectVerificationFailures(messages: [
            "Expected firstMethod(id: any) to not be called again, but was called 1 time"
        ]) {
            var expectations = MockTestInOrderService.Expectations()
            when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")

            let mock = MockTestInOrderService(expectations: expectations)
            let inOrder = InOrder(strict: false, mock)

            // Call it
            _ = mock.firstMethod(id: "test")

            // Verify never called again - should fail
            inOrder.verify(mock, .additionalNone).firstMethod(id: .any)
        }
    }

    @Test
    func testInOrderVerificationFailureAtLeastOnce() {
        expectVerificationFailures(messages: [
            "Expected firstMethod(id: any) to be called additionally at least once, but was never called"
        ]) {
            var expectations = MockTestInOrderService.Expectations()
            when(expectations.firstMethod(id: .any), return: "result")

            let mock = MockTestInOrderService(expectations: expectations)
            let inOrder = InOrder(strict: false, mock)

            // Don't call it

            // Verify at least once additionally - should fail
            inOrder.verify(mock, .additionalAtLeastOnce).firstMethod(id: .any)
        }
    }

    @Test
    func testInOrderVerificationFailureRange() {
        expectVerificationFailures(messages: [
            "Expected firstMethod(id: any) to be called additionally 1...2 times, but was called 0 times"
        ]) {
            var expectations = MockTestInOrderService.Expectations()
            when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")

            let mock = MockTestInOrderService(expectations: expectations)
            let inOrder = InOrder(strict: false, mock)

            // Don't call it enough times

            // Verify range 1...2 times - should fail since no calls
            inOrder.verify(mock, additionalRange: 1...2).firstMethod(id: .any)
        }
    }

    @Test
    func testInOrderVerifyNoMoreInteractionsFailure() {
        expectVerificationFailures(messages: [
            "Expected no remaining unverified mock interactions but interactions occurred 1 time"
        ]) {
            var expectations = MockTestInOrderService.Expectations()
            when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
            when(expectations.secondMethod(count: .any), times: .unbounded, return: 42)

            let mock = MockTestInOrderService(expectations: expectations)
            let inOrder = InOrder(strict: false, mock)

            // Call both methods
            _ = mock.firstMethod(id: "test1")
            _ = mock.secondMethod(count: 5)

            // Verify only one of them
            inOrder.verify(mock, additionalTimes: 1).firstMethod(id: .any)

            // Verify no more interactions - should fail because secondMethod wasn't verified
            inOrder.verifyNoMoreInteractions()
        }
    }

    @Test
    func testInOrderStrictModeFailure() {
        expectVerificationFailures(messages: [
            "Expected no unverified mock interactions before this call to firstMethod(id: \"second\") but interactions occurred 1 time"
        ]) {
            var expectations = MockTestInOrderService.Expectations()
            when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
            when(expectations.secondMethod(count: .any), times: .unbounded, return: 42)

            let mock = MockTestInOrderService(expectations: expectations)
            let inOrder = InOrder(strict: true, mock)  // Strict mode

            // Call in sequence with an unverified call in between
            _ = mock.firstMethod(id: "first")
            _ = mock.secondMethod(count: 11)  // This will cause strict mode to fail
            _ = mock.firstMethod(id: "second")

            // Verify the first and third calls - should fail in strict mode
            inOrder.verify(mock, additionalTimes: 1).firstMethod(id: "first")
            inOrder.verify(mock, additionalTimes: 1).firstMethod(id: "second")
        }
    }

    @Test
    func testTrailingClosureImplicitVerifyNoMoreInteractionsFailure() {
        expectVerificationFailures(messages: [
            "Expected no remaining unverified mock interactions but interactions occurred 1 time"
        ]) {
            var expectations = MockTestInOrderService.Expectations()
            when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
            when(expectations.secondMethod(count: .any), times: .unbounded, return: 42)

            let mock = MockTestInOrderService(expectations: expectations)

            _ = mock.firstMethod(id: "test1")
            _ = mock.secondMethod(count: 5)

            InOrder(strict: false, mock) { inOrder in
                inOrder.verify(mock).firstMethod(id: .any)
                // secondMethod is not verified — implicit verifyNoMoreInteractions should fail
            }
        }
    }

    @Test
    func testMisordering() {
        expectVerificationFailures(messages: [
            "Expected no unverified mock interactions before this call to firstMethod(id: any) but interactions occurred 1 time",
            "Expected secondMethod(count: 1...10) to be called an additional 1 time, but was called 0 times",
        ]) {
            var expectations = MockTestInOrderService.Expectations()
            when(expectations.firstMethod(id: .any), times: .unbounded, return: "result")
            when(expectations.secondMethod(count: .any), times: .unbounded, return: 1)

            let mock = MockTestInOrderService(expectations: expectations)

            _ = mock.firstMethod(id: "exact")
            _ = mock.secondMethod(count: 5)
            _ = mock.firstMethod(id: "range")
            _ = mock.secondMethod(count: 15)

            let inOrder = InOrder(strict: true, mock)

            // Test various matcher types work in ordered verification
            inOrder.verify(mock).firstMethod(id: "exact")  // Exact match
            inOrder.verify(mock).firstMethod(id: .any)  // Ordering fail
            inOrder.verify(mock).secondMethod(count: 1...10)  // Range match
            inOrder.verify(mock).secondMethod(count: 10...20)  // Range match
            inOrder.verifyNoMoreInteractions()
        }
    }
    #endif
}
