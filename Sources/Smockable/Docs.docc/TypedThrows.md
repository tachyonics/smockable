# Typed Throws

Use typed throws to get compile-time safety when setting up error expectations.

## Overview

Swift's typed throws (`throws(ErrorType)`) lets functions and properties declare the specific error type they can throw. Smockable propagates this type information through the generated mock code, so `when(..., throw:)` only accepts errors of the declared type.

This means that passing the wrong error type to a mock expectation is a compile-time error rather than an issue during test execution.

## Typed Throwing Functions

When a protocol function declares a specific error type, the generated mock enforces that type in expectations:

```swift
enum ServiceError: Error {
    case notFound
    case unauthorized
}

@Smock
protocol UserService {
    func fetchUser(id: String) throws(ServiceError) -> User
    func deleteUser(id: String) throws(ServiceError)
}
```

Setting up expectations works the same as with untyped throws, but the compiler ensures only `ServiceError` values are accepted:

```swift
var expectations = MockUserService.Expectations()

// These compile — ServiceError matches the declared error type
when(expectations.fetchUser(id: .any), throw: ServiceError.notFound)
when(expectations.deleteUser(id: .any), throw: ServiceError.unauthorized)

// This would NOT compile — wrong error type
// when(expectations.fetchUser(id: .any), throw: SomeOtherError.failed)
```

## Typed Throwing Properties

Property getters can also use typed throws:

```swift
@Smock
protocol ConfigService {
    var currentConfig: Config { get throws(ConfigError) }
}

var expectations = MockConfigService.Expectations()
when(expectations.currentConfig.get(), throw: ConfigError.missing)
```

## Async Typed Throwing Functions

Typed throws works with async functions:

```swift
@Smock
protocol DataService {
    func loadData(id: String) async throws(DataError) -> Data
}

var expectations = MockDataService.Expectations()
when(expectations.loadData(id: .any), throw: DataError.networkFailure)

let mock = MockDataService(expectations: expectations)
await #expect(throws: DataError.networkFailure) {
    _ = try await mock.loadData(id: "test")
}
```

## Custom Closures with Typed Throws

When using `when(..., use:)` with a typed throwing function, the closure must declare the matching typed throws signature:

```swift
when(expectations.fetchUser(id: .any), use: { (id: String) throws(ServiceError) -> User in
    if id == "invalid" {
        throw ServiceError.notFound
    }
    return User(id: id, name: "Test")
})
```

## Untyped Throws

Functions declared with plain `throws` (no specific error type) continue to work as before — the error parameter accepts `any Error`:

```swift
@Smock
protocol LegacyService {
    func doWork() throws -> String
}

var expectations = MockLegacyService.Expectations()
when(expectations.doWork(), throw: NSError(domain: "test", code: 1))  // any Error accepted
```

## See Also

- <doc:Expectations>
- <doc:Capabilities>
