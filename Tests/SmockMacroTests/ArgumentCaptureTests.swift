import Foundation
import Testing

@testable import Smockable

@Smock(accessLevel: .internal)
protocol ArgumentCaptureService {
    func singleParam(id: String) -> String
    func multiParam(name: String, count: Int) -> String
    func voidReturn(id: String)
    func noParams() -> String
    var settableProperty: String { get set }
}

struct ArgumentCaptureTests {

    // MARK: - Single Parameter Capture

    @Test
    func testSingleParamCapture() {
        var expectations = MockArgumentCaptureService.Expectations()
        when(expectations.singleParam(id: .any), times: .unbounded, return: "result")

        let mock = MockArgumentCaptureService(expectations: expectations)
        _ = mock.singleParam(id: "alpha")
        _ = mock.singleParam(id: "beta")

        let capturedIds = verify(mock, times: 2).singleParam(id: .any)
        #expect(capturedIds == ["alpha", "beta"])
    }

    // MARK: - Multi Parameter Capture

    @Test
    func testMultiParamCapture() {
        var expectations = MockArgumentCaptureService.Expectations()
        when(expectations.multiParam(name: .any, count: .any), times: .unbounded, return: "ok")

        let mock = MockArgumentCaptureService(expectations: expectations)
        _ = mock.multiParam(name: "Alice", count: 1)
        _ = mock.multiParam(name: "Bob", count: 2)

        let captured = verify(mock, times: 2).multiParam(name: .any, count: .any)
        #expect(captured.count == 2)
        #expect(captured[0].name == "Alice")
        #expect(captured[0].count == 1)
        #expect(captured[1].name == "Bob")
        #expect(captured[1].count == 2)
    }

    // MARK: - Filtered Capture

    @Test
    func testFilteredCapture() {
        var expectations = MockArgumentCaptureService.Expectations()
        when(expectations.multiParam(name: .any, count: .any), times: .unbounded, return: "ok")

        let mock = MockArgumentCaptureService(expectations: expectations)
        _ = mock.multiParam(name: "Alice", count: 10)
        _ = mock.multiParam(name: "Bob", count: 20)
        _ = mock.multiParam(name: "Alice", count: 30)

        let captured = verify(mock, times: 2).multiParam(name: "Alice", count: .any)
        #expect(captured.count == 2)
        #expect(captured[0].name == "Alice")
        #expect(captured[0].count == 10)
        #expect(captured[1].name == "Alice")
        #expect(captured[1].count == 30)
    }

    // MARK: - Capture with times: N

    @Test
    func testCaptureCountMatchesInvocations() {
        var expectations = MockArgumentCaptureService.Expectations()
        when(expectations.singleParam(id: .any), times: .unbounded, return: "ok")

        let mock = MockArgumentCaptureService(expectations: expectations)
        _ = mock.singleParam(id: "one")
        _ = mock.singleParam(id: "two")
        _ = mock.singleParam(id: "three")

        let captured = verify(mock, times: 3).singleParam(id: .any)
        #expect(captured.count == 3)
    }

    // MARK: - Void Return Function Capture

    @Test
    func testVoidReturnFunctionCapture() {
        var expectations = MockArgumentCaptureService.Expectations()
        when(expectations.voidReturn(id: .any), times: .unbounded, complete: .withSuccess)

        let mock = MockArgumentCaptureService(expectations: expectations)
        mock.voidReturn(id: "first")
        mock.voidReturn(id: "second")

        let capturedIds = verify(mock, times: 2).voidReturn(id: .any)
        #expect(capturedIds == ["first", "second"])
    }

    // MARK: - Zero Parameter Function

    @Test
    func testZeroParamFunctionStaysVoid() {
        var expectations = MockArgumentCaptureService.Expectations()
        when(expectations.noParams(), return: "hello")

        let mock = MockArgumentCaptureService(expectations: expectations)
        _ = mock.noParams()

        // This should compile without assignment — returns Void
        verify(mock, times: 1).noParams()
    }

    // MARK: - Property Setter Capture

    @Test
    func testPropertySetterCapture() {
        var expectations = MockArgumentCaptureService.Expectations()
        when(expectations.settableProperty.get(), times: .unbounded, return: "value")
        when(expectations.settableProperty.set(.any), times: .unbounded, complete: .withSuccess)

        var mock = MockArgumentCaptureService(expectations: expectations)
        mock.settableProperty = "first"
        mock.settableProperty = "second"

        let capturedValues = verify(mock, times: 2).settableProperty.set(.any)
        #expect(capturedValues == ["first", "second"])
    }

    // MARK: - Backward Compatibility

    @Test
    func testBackwardCompatibilityDiscardableResult() {
        var expectations = MockArgumentCaptureService.Expectations()
        when(expectations.singleParam(id: .any), return: "result")

        let mock = MockArgumentCaptureService(expectations: expectations)
        _ = mock.singleParam(id: "test")

        // Existing code: verify without assignment still compiles
        verify(mock, times: 1).singleParam(id: "test")
    }

    // MARK: - Capture with .first!

    @Test
    func testCaptureWithFirst() {
        var expectations = MockArgumentCaptureService.Expectations()
        when(expectations.multiParam(name: .any, count: .any), return: "ok")

        let mock = MockArgumentCaptureService(expectations: expectations)
        _ = mock.multiParam(name: "Alice", count: 42)

        let captured = verify(mock, times: 1).multiParam(name: .any, count: .any)
        #expect(captured.first!.name == "Alice")
        #expect(captured.first!.count == 42)
    }
}
