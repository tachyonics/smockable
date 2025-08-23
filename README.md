<p align="center">
<a href="https://github.com/tachyonics/smockable/actions">
<img src="https://github.com/tachyonics/smockable/actions/workflows/swift.yml/badge.svg?branch=main" alt="Build - Main Branch">
</a>
<a href="http://swift.org">
<img src="https://img.shields.io/badge/swift-6.1|6.0-orange.svg?style=flat" alt="Swift 6.1 and 6.0 Compatible and Tested">
</a>
<img src="https://img.shields.io/badge/ubuntu-22.04|24.04-yellow.svg?style=flat" alt="Ubuntu 22.04 and 24.04 Tested">
<img src="https://img.shields.io/badge/license-Apache2-blue.svg?style=flat" alt="Apache 2">
</p>


# Smockable

A Swift library that uses code generation through Macros for creating type-safe mocks from protocols. Smockable generates mock implementations that support expectations, verification, and comprehensive testing capabilities.

Inspired by and a fork of https://github.com/Matejkob/swift-spyable.

## Features

- ✅ **Type-safe mocks** generated at compile time using Swift macros
- ✅ **Expectation-based testing** with support for return values, errors, and custom closures
- ✅ **Call verification** with detailed invocation tracking
- ✅ **Thread-safe** mock implementations with Sendable conformance
- ✅ **Flexible expectations** supporting multiple calls, unbounded calls, and custom logic
- ✅ **Protocol inheritance** and associated types support
- ✅ **Async/await** and throwing function support

## Requirements

- Swift 6.0+
- Xcode 16.0+
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+

## Installation

### Swift Package Manager

Add Smockable to your project using Swift Package Manager:

#### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/tachyonics/smockable.git", from: "1.0.0")
]
```

Then add it to your test target:

```swift
.testTarget(
    name: "YourTestTarget",
    dependencies: [
        "Smockable",
        // ... other dependencies
    ]
)
```

#### Xcode

1. Open your project in Xcode
2. Go to File → Add Package Dependencies
3. Enter the repository URL: `https://github.com/tachyonics/smockable.git`
4. Choose the version and add it to your test targets

## Quick Start

### 1. Define a Protocol with @Smock

```swift
import Smockable

@Smock
protocol UserService {
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
    var isLoggedIn: Bool { get }
}
```

### 2. Create and Configure a Mock

```swift
import Testing

@Test func userFetching() async throws {
    // Create expectations
    let expectations = MockUserService.Expectations()
    
    // Set up expected behavior
    let expectedUser = User(id: "123", name: "John Doe")
    expectations.fetchUser_id.value(expectedUser)
    expectations.updateUser.value(())
    
    // Create the mock
    let mockService = MockUserService(expectations: expectations)
    
    // Use the mock
    let user = try await mockService.fetchUser(id: "123")
    try await mockService.updateUser(user)
    
    // Verify behavior
    let fetchCallCount = await mockService.__verify.fetchUser_id.callCount
    let updateInputs = await mockService.__verify.updateUser.receivedInputs
    
    #expect(fetchCallCount == 1)
    #expect(updateInputs.count == 1)
    #expect(user.id == "123")
}
```

### 3. Advanced Expectations

```swift
// Multiple return values
expectations.fetchUser_id
    .value(user1)           // First call returns user1
    .value(user2).times(2)  // Next 2 calls return user2
    .error(NetworkError.notFound) // Fourth call throws error

// Custom logic with closures
expectations.fetchUser_id.using { id in
    return User(id: id, name: "Generated User")
}.unboundedTimes() // Apply to all subsequent calls

// Throwing errors
expectations.updateUser.error(ValidationError.invalidData)
```

## Documentation

For detailed documentation, examples, and advanced usage patterns, see the [Documentation](Documentation/) folder or visit our [DocC documentation](link-to-docc-when-available).

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to the main branch.

## License

Smockable is available under the Apache 2.0 license. See the LICENSE file for more info.
