import Foundation
import Testing

@testable import Smockable

@Smock
protocol TestPropertyVerificationService {
    var name: String { get set }
    var readOnlyCount: Int { get }
    var optionalValue: String? { get set }
    var isActive: Bool { get set }
}

@Smock
protocol TestAsyncPropertyVerificationService {
    var asyncName: String { get async }
    var asyncReadOnlyData: Data { get async }
    var asyncOptionalValue: String? { get async }
}

@Smock
protocol TestThrowingPropertyVerificationService {
    var throwingName: String { get throws }
    var throwingReadOnlyCount: Int { get throws }
    var throwingOptionalValue: String? { get throws }
}

@Smock
protocol TestAsyncThrowingPropertyVerificationService {
    var asyncThrowingName: String { get async throws }
    var asyncThrowingReadOnlyData: Data { get async throws }
    var asyncThrowingOptionalValue: String? { get async throws }
}

struct PropertyVerificationTests {

    // MARK: - Sync Property Verification Tests

    @Test
    func testVerifyPropertyGetterTimes() {
        var expectations = MockTestPropertyVerificationService.Expectations()
        when(expectations.name.get(), times: .unbounded, return: "test value")

        let mock = MockTestPropertyVerificationService(expectations: expectations)

        // Execute
        _ = mock.name
        _ = mock.name
        _ = mock.name

        // Verify - should pass
        verify(mock, times: 3).name.get()
        verify(mock, times: 0).name.set(.any)
    }

    @Test
    func testVerifyPropertySetterTimes() {
        var expectations = MockTestPropertyVerificationService.Expectations()
        when(expectations.name.set(.any), times: .unbounded, complete: .withSuccess)

        var mock = MockTestPropertyVerificationService(expectations: expectations)

        // Execute
        mock.name = "value1"
        mock.name = "value2"
        mock.name = "value3"

        // Verify - should pass
        verify(mock, times: 3).name.set(.any)
        verify(mock, times: 1).name.set("value1")
        verify(mock, times: 1).name.set("value2")
        verify(mock, times: 1).name.set("value3")
        verify(mock, times: 0).name.get()
    }

    @Test
    func testVerifyPropertyAtLeast() {
        var expectations = MockTestPropertyVerificationService.Expectations()
        when(expectations.name.get(), times: .unbounded, return: "test value")

        let mock = MockTestPropertyVerificationService(expectations: expectations)

        // Execute
        _ = mock.name
        _ = mock.name
        _ = mock.name

        // Verify - should pass
        verify(mock, atLeast: 1).name.get()
        verify(mock, atLeast: 3).name.get()
        verify(mock, atLeast: 0).name.set(.any)
    }

    @Test
    func testVerifyPropertyAtMost() {
        var expectations = MockTestPropertyVerificationService.Expectations()
        when(expectations.name.get(), times: .unbounded, return: "test value")

        let mock = MockTestPropertyVerificationService(expectations: expectations)

        // Execute
        _ = mock.name
        _ = mock.name

        // Verify - should pass
        verify(mock, atMost: 5).name.get()
        verify(mock, atMost: 2).name.get()
        verify(mock, atMost: 0).name.set(.any)
    }

    @Test
    func testVerifyPropertyNever() {
        var expectations = MockTestPropertyVerificationService.Expectations()
        when(expectations.name.get(), return: "test value")

        let mock = MockTestPropertyVerificationService(expectations: expectations)

        // Execute
        _ = mock.name

        // Verify - should pass
        verify(mock, .never).name.set(.any)
        verify(mock, .never).readOnlyCount.get()
        verify(mock, .never).optionalValue.get()
    }

    @Test
    func testVerifyPropertyAtLeastOnce() {
        var expectations = MockTestPropertyVerificationService.Expectations()
        when(expectations.name.get(), return: "test value")
        when(expectations.name.set(.any), complete: .withSuccess)

        var mock = MockTestPropertyVerificationService(expectations: expectations)

        // Execute
        _ = mock.name
        mock.name = "new value"

        // Verify - should pass
        verify(mock, .atLeastOnce).name.get()
        verify(mock, .atLeastOnce).name.set(.any)
        verify(mock, .atLeastOnce).name.set("new value")
    }

    @Test
    func testVerifyPropertyRange() {
        var expectations = MockTestPropertyVerificationService.Expectations()
        when(expectations.name.get(), times: .unbounded, return: "test value")

        let mock = MockTestPropertyVerificationService(expectations: expectations)

        // Execute
        _ = mock.name
        _ = mock.name
        _ = mock.name

        // Verify - should pass
        verify(mock, times: 1...5).name.get()
        verify(mock, times: 3...3).name.get()
        verify(mock, times: 0...0).name.set(.any)
    }

    @Test
    func testVerifyPropertyWithValueMatchers() {
        var expectations = MockTestPropertyVerificationService.Expectations()
        when(expectations.name.set(.any), times: .unbounded, complete: .withSuccess)

        var mock = MockTestPropertyVerificationService(expectations: expectations)

        // Execute
        mock.name = "apple"
        mock.name = "banana"
        mock.name = "cherry"

        // Verify with range matchers - should pass
        verify(mock, times: 3).name.set("a"..."z")
        verify(mock, times: 2).name.set("a"..."c")
        verify(mock, times: 1).name.set("cherry")
    }

    @Test
    func testVerifyMixedPropertyTypes() {
        var expectations = MockTestPropertyVerificationService.Expectations()
        when(expectations.name.get(), return: "string value")
        when(expectations.readOnlyCount.get(), return: 100)
        when(expectations.isActive.get(), return: false)
        when(expectations.optionalValue.get(), return: "optional")
        when(expectations.name.set(.any), complete: .withSuccess)
        when(expectations.isActive.set(.any), complete: .withSuccess)
        when(expectations.optionalValue.set(.any), complete: .withSuccess)

        var mock = MockTestPropertyVerificationService(expectations: expectations)

        // Execute
        _ = mock.name
        _ = mock.readOnlyCount
        _ = mock.isActive
        _ = mock.optionalValue
        mock.name = "new name"
        mock.isActive = true
        mock.optionalValue = "new optional"

        // Verify
        verify(mock, times: 1).name.get()
        verify(mock, times: 1).readOnlyCount.get()
        verify(mock, times: 1).isActive.get()
        verify(mock, times: 1).optionalValue.get()
        verify(mock, times: 1).name.set("new name")
        verify(mock, times: 1).isActive.set(true)
        verify(mock, times: 1).optionalValue.set("new optional")
    }

    // MARK: - Async Property Verification Tests

    @Test
    func testVerifyAsyncPropertyGetterTimes() async {
        var expectations = MockTestAsyncPropertyVerificationService.Expectations()
        when(expectations.asyncName.get(), times: .unbounded, return: "async test value")

        let mock = MockTestAsyncPropertyVerificationService(expectations: expectations)

        // Execute
        _ = await mock.asyncName
        _ = await mock.asyncName
        _ = await mock.asyncName

        // Verify - should pass
        verify(mock, times: 3).asyncName.get()
    }

    @Test
    func testVerifyAsyncPropertyAtLeast() async {
        var expectations = MockTestAsyncPropertyVerificationService.Expectations()
        when(expectations.asyncName.get(), times: .unbounded, return: "async test value")

        let mock = MockTestAsyncPropertyVerificationService(expectations: expectations)

        // Execute
        _ = await mock.asyncName
        _ = await mock.asyncName
        _ = await mock.asyncName

        // Verify - should pass
        verify(mock, atLeast: 1).asyncName.get()
        verify(mock, atLeast: 3).asyncName.get()
    }

    @Test
    func testVerifyAsyncPropertyNever() async {
        var expectations = MockTestAsyncPropertyVerificationService.Expectations()
        when(expectations.asyncName.get(), return: "async test value")

        let mock = MockTestAsyncPropertyVerificationService(expectations: expectations)

        // Execute
        _ = await mock.asyncName

        // Verify - should pass
        verify(mock, .never).asyncReadOnlyData.get()
        verify(mock, .never).asyncOptionalValue.get()
    }

    // MARK: - Throwing Property Verification Tests

    @Test
    func testVerifyThrowingPropertyGetterTimes() throws {
        var expectations = MockTestThrowingPropertyVerificationService.Expectations()
        when(expectations.throwingName.get(), times: .unbounded, return: "throwing test value")

        let mock = MockTestThrowingPropertyVerificationService(expectations: expectations)

        // Execute
        _ = try mock.throwingName
        _ = try mock.throwingName
        _ = try mock.throwingName

        // Verify - should pass
        verify(mock, times: 3).throwingName.get()
    }

    @Test
    func testVerifyThrowingPropertyWithErrors() {
        var expectations = MockTestThrowingPropertyVerificationService.Expectations()
        when(expectations.throwingName.get(), return: "success")
        when(expectations.throwingName.get(), throw: NSError(domain: "test", code: 1))

        let mock = MockTestThrowingPropertyVerificationService(expectations: expectations)

        // Execute
        _ = try? mock.throwingName  // Success
        _ = try? mock.throwingName  // Throws

        // Verify - should pass (both successful and failed calls are counted)
        verify(mock, times: 2).throwingName.get()
    }

    // MARK: - Async Throwing Property Verification Tests

    @Test
    func testVerifyAsyncThrowingPropertyGetterTimes() async throws {
        var expectations = MockTestAsyncThrowingPropertyVerificationService.Expectations()
        when(expectations.asyncThrowingName.get(), times: .unbounded, return: "async throwing test value")

        let mock = MockTestAsyncThrowingPropertyVerificationService(expectations: expectations)

        // Execute
        _ = try await mock.asyncThrowingName
        _ = try await mock.asyncThrowingName
        _ = try await mock.asyncThrowingName

        // Verify - should pass
        verify(mock, times: 3).asyncThrowingName.get()
    }

    @Test
    func testVerifyAsyncThrowingPropertyWithErrors() async {
        var expectations = MockTestAsyncThrowingPropertyVerificationService.Expectations()
        when(expectations.asyncThrowingName.get(), return: "async success")
        when(expectations.asyncThrowingName.get(), throw: NSError(domain: "async test", code: 1))

        let mock = MockTestAsyncThrowingPropertyVerificationService(expectations: expectations)

        // Execute
        _ = try? await mock.asyncThrowingName  // Success
        _ = try? await mock.asyncThrowingName  // Throws

        // Verify - should pass (both successful and failed calls are counted)
        verify(mock, times: 2).asyncThrowingName.get()
    }

    @Test
    func testVerifyAsyncThrowingPropertyRange() async throws {
        var expectations = MockTestAsyncThrowingPropertyVerificationService.Expectations()
        when(expectations.asyncThrowingName.get(), times: .unbounded, return: "async throwing test value")

        let mock = MockTestAsyncThrowingPropertyVerificationService(expectations: expectations)

        // Execute
        _ = try await mock.asyncThrowingName
        _ = try await mock.asyncThrowingName
        _ = try await mock.asyncThrowingName

        // Verify - should pass
        verify(mock, times: 1...5).asyncThrowingName.get()
        verify(mock, times: 3...3).asyncThrowingName.get()
    }
}
