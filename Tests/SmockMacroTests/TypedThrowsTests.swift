import Foundation
import Testing

@testable import Smockable

enum TypedThrowsError: Error, Equatable {
    case specificError
    case anotherError
}

@Smock(accessLevel: .internal)
protocol TypedThrowsService {
    func typedThrowingFunction(id: String) throws(TypedThrowsError) -> String
    func typedThrowingVoidFunction() throws(TypedThrowsError)
    func asyncTypedThrowingFunction(id: String) async throws(TypedThrowsError) -> String
    var typedThrowingProperty: String { get throws(TypedThrowsError) }
}

// Note: Generic error service with associated type + typed throws is not tested here
// because it triggers a compiler crash (signal 11) in SIL witness table generation
// on Swift 6.2. A closely related bug was fixed in Swift 6.3:
// https://github.com/swiftlang/swift/issues/81317

struct TypedThrowsTests {

    // MARK: - Typed Throwing Function Tests

    @Test
    func testTypedThrowingFunctionSuccess() throws {
        var expectations = MockTypedThrowsService.Expectations()
        when(expectations.typedThrowingFunction(id: .any), return: "success")

        let mock = MockTypedThrowsService(expectations: expectations)
        let result = try mock.typedThrowingFunction(id: "test")

        #expect(result == "success")
        verify(mock, times: 1).typedThrowingFunction(id: "test")
    }

    @Test
    func testTypedThrowingFunctionError() {
        var expectations = MockTypedThrowsService.Expectations()
        when(expectations.typedThrowingFunction(id: .any), throw: TypedThrowsError.specificError)

        let mock = MockTypedThrowsService(expectations: expectations)

        #expect(throws: TypedThrowsError.specificError) {
            _ = try mock.typedThrowingFunction(id: "test")
        }
        verify(mock, times: 1).typedThrowingFunction(id: "test")
    }

    // MARK: - Typed Throwing Void Function Tests

    @Test
    func testTypedThrowingVoidFunctionSuccess() throws {
        var expectations = MockTypedThrowsService.Expectations()
        when(expectations.typedThrowingVoidFunction(), complete: .withSuccess)

        let mock = MockTypedThrowsService(expectations: expectations)
        try mock.typedThrowingVoidFunction()

        verify(mock, times: 1).typedThrowingVoidFunction()
    }

    @Test
    func testTypedThrowingVoidFunctionError() {
        var expectations = MockTypedThrowsService.Expectations()
        when(expectations.typedThrowingVoidFunction(), throw: TypedThrowsError.anotherError)

        let mock = MockTypedThrowsService(expectations: expectations)

        #expect(throws: TypedThrowsError.anotherError) {
            try mock.typedThrowingVoidFunction()
        }
        verify(mock, times: 1).typedThrowingVoidFunction()
    }

    // MARK: - Async Typed Throwing Function Tests

    @Test
    func testAsyncTypedThrowingFunctionSuccess() async throws {
        var expectations = MockTypedThrowsService.Expectations()
        when(expectations.asyncTypedThrowingFunction(id: .any), return: "async success")

        let mock = MockTypedThrowsService(expectations: expectations)
        let result = try await mock.asyncTypedThrowingFunction(id: "test")

        #expect(result == "async success")
        verify(mock, times: 1).asyncTypedThrowingFunction(id: "test")
    }

    @Test
    func testAsyncTypedThrowingFunctionError() async {
        var expectations = MockTypedThrowsService.Expectations()
        when(
            expectations.asyncTypedThrowingFunction(id: .any),
            throw: TypedThrowsError.specificError
        )

        let mock = MockTypedThrowsService(expectations: expectations)

        await #expect(throws: TypedThrowsError.specificError) {
            _ = try await mock.asyncTypedThrowingFunction(id: "test")
        }
        verify(mock, times: 1).asyncTypedThrowingFunction(id: "test")
    }

    // MARK: - Mixed Success/Error Sequence

    @Test
    func testMixedSuccessAndErrorSequence() throws {
        var expectations = MockTypedThrowsService.Expectations()
        when(expectations.typedThrowingFunction(id: .any), return: "first")
        when(expectations.typedThrowingFunction(id: .any), throw: TypedThrowsError.specificError)
        when(expectations.typedThrowingFunction(id: .any), return: "third")

        let mock = MockTypedThrowsService(expectations: expectations)

        let result1 = try mock.typedThrowingFunction(id: "1")
        #expect(result1 == "first")

        #expect(throws: TypedThrowsError.specificError) {
            _ = try mock.typedThrowingFunction(id: "2")
        }

        let result3 = try mock.typedThrowingFunction(id: "3")
        #expect(result3 == "third")

        verify(mock, times: 3).typedThrowingFunction(id: .any)
    }

    // MARK: - Custom Closure with Typed Throws

    @Test
    func testCustomClosureWithTypedThrows() throws {
        var expectations = MockTypedThrowsService.Expectations()
        when(
            expectations.typedThrowingFunction(id: .any),
            times: 2,
            use: { (id: String) throws(TypedThrowsError) -> String in
                if id == "fail" {
                    throw TypedThrowsError.specificError
                }
                return "processed: \(id)"
            }
        )

        let mock = MockTypedThrowsService(expectations: expectations)

        let result = try mock.typedThrowingFunction(id: "ok")
        #expect(result == "processed: ok")

        #expect(throws: TypedThrowsError.specificError) {
            _ = try mock.typedThrowingFunction(id: "fail")
        }
    }

    // MARK: - Typed Throwing Property Tests

    @Test
    func testTypedThrowingPropertySuccess() throws {
        var expectations = MockTypedThrowsService.Expectations()
        when(expectations.typedThrowingProperty.get(), return: "property value")

        let mock = MockTypedThrowsService(expectations: expectations)
        let result = try mock.typedThrowingProperty

        #expect(result == "property value")
    }

    @Test
    func testTypedThrowingPropertyError() {
        var expectations = MockTypedThrowsService.Expectations()
        when(expectations.typedThrowingProperty.get(), throw: TypedThrowsError.specificError)

        let mock = MockTypedThrowsService(expectations: expectations)

        #expect(throws: TypedThrowsError.specificError) {
            _ = try mock.typedThrowingProperty
        }
    }

    // MARK: - Verification Tests

    @Test
    func testVerificationWithTypedThrows() throws {
        var expectations = MockTypedThrowsService.Expectations()
        when(expectations.typedThrowingFunction(id: .any), times: 3, return: "result")

        let mock = MockTypedThrowsService(expectations: expectations)

        _ = try mock.typedThrowingFunction(id: "a")
        _ = try mock.typedThrowingFunction(id: "b")
        _ = try mock.typedThrowingFunction(id: "a")

        verify(mock, times: 3).typedThrowingFunction(id: .any)
        verify(mock, times: 2).typedThrowingFunction(id: "a")
        verify(mock, times: 1).typedThrowingFunction(id: "b")
        verify(mock, .never).typedThrowingFunction(id: "c")
    }
}
