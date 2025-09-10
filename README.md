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

Inspired by Java's [Mockito](https://site.mockito.org) along with starting out life as a fork of https://github.com/Matejkob/swift-spyable.

## Features

- ✅ **Type-safe mocks** generated at compile time using Swift macros
- ✅ **Expectation-based testing** with support for return values, errors, and custom closures
- ✅ **Call verification** with detailed invocation tracking
- ✅ **Thread-safe** mock implementations with Sendable conformance
- ✅ **Flexible expectations** supporting multiple calls, unbounded calls, and custom logic
- ✅ **Protocol inheritance** and associated types support
- ✅ **Async/await**, sync and throwing function support

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
}
```

### 2. Create and Configure a Mock

```swift
import Testing

@Test
func userFetching() async throws {
    // Create expectations
    var expectations = MockUserService.Expectations()
    
    // Set up expected behavior with range matching with when(:return)
    let expectedUser = User(id: "123", name: "John Doe")
    when(expectations.fetchUser(id: "100"..."999"), return: expectedUser)
    
    // For functions with no return type, use when(:complete)
    when(expectations.updateUser(.any), complete: .withSuccess)
    
    // Create the mock
    let mockService = MockUserService(expectations: expectations)
    let codeUnderTest = CodeUnderTest(service: mockService)
    
    // Exercise the code under test
    let user = try await codeUnderTest.fetchUser(id: "123")
    try await codeUnderTest.updateUser(user)
    
    // Verify behavior
    verify(mockService, times: 1).fetchUser(id: .any)
    verify(mockService, times: 1).updateUser(.any)
    
    #expect(user.id == "123")
}
```

### 3. Set Expectations

```swift
// Range-based parameter matching for functions with return values
when(expectations.fetchUser(id: "100"..."999"), return: user1)
when(expectations.fetchUser(id: "A"..."Z"), times: 2, return: user2)
when(expectations.fetchUser(id: .any), throw: NetworkError.notFound)

// Exact value matching
when(expectations.fetchUser(id: "user123"), return: specificUser)
when(expectations.fetchUser(id: "admin"), return: adminUser)

// Multiple parameter ranges
when(expectations.processData(input: "A"..."M", count: 1...10), return: "processed")

// Mix exact values with ranges
when(expectations.processData(input: "exact", count: 1...10), return: "exact input")
when(expectations.processData(input: "A"..."Z", count: 42), return: "exact count")

// Functions with no return type
when(expectations.updateUser(name: "A"..."Z", age: nil), complete: .withSuccess)
when(expectations.deleteUser(id: "100"..."999"), complete: .withSuccess)
when(expectations.saveData(data: "A"..."Z"), times: 3, complete: .withSuccess)

// Exact value matching for void functions
when(expectations.updateUser(name: "John", age: 25), complete: .withSuccess)
when(expectations.deleteUser(id: "user123"), complete: .withSuccess)
when(expectations.saveData(data: "important"), times: 2, complete: .withSuccess)

// Optional parameter matching
when(expectations.getUserProfile(name: "A"..."Z", age: nil), return: profile1)
when(expectations.getUserProfile(name: "A"..."Z", age: 18...65), return: profile2)

// Exact value matching with optionals
when(expectations.getUserProfile(name: "John", age: 25), return: johnProfile)
when(expectations.getUserProfile(name: "Jane", age: nil), return: janeProfile)

// Custom logic with closures
when(expectations.fetchUser(id: "A"..."Z"), times: .unbounded) { id in
    return User(id: id, name: "Generated User")
}

// Or with explicit use: parameter
when(expectations.fetchUser(id: "A"..."Z"), times: 3, use: myClosure)

// Error handling for functions with no return type
when(expectations.saveData(data: "invalid"), throw: ValidationError.invalidData)
```

### 4. Verify mock interactions

![Smockable provides detailed error messages in test cases](https://github.com/tachyonics/smockable/blob/main/expectation_example.pngraw=true)

```swift
// Range-based parameter matching and verification of exact, 
// range, at least and at most invocation counts
verify(mock, times: 6).fetchUser(id: "100"..."999")
verify(mock, times: 3...10).fetchUser(id: "100"..."999")
verify(mock, atLeast: 4).fetchUser(id: "A"..."Z")
verify(mock, atMost: 2).fetchUser(id: .any)

// Exact value matching with verification of no or at least one invocation
verify(mock, .never).fetchUser(id: "user123")
verify(mock, .atLeastOnce).fetchUser(id: "admin")

// Mix exact values with ranges
verify(mock, times: 2).processData(input: "exact", count: 1...10)
verify(mock, .never).processData(input: "A"..."Z", count: 42)

// Optional parameter matching
verify(mock, times: 2...18).getUserProfile(name: "A"..."Z", age: nil)
verify(mock, atMost: 2).getUserProfile(name: "A"..."Z", age: 18...65)

// Exact value matching with optionals
verify(mock, times: 1).getUserProfile(name: "John", age: 25), return: johnProfile)
verify(mock, atMost: 5).getUserProfile(name: "Jane", age: nil), return: janeProfile)
```

## Documentation

For detailed documentation, examples, and advanced usage patterns, see the [Documentation](Documentation/) folder or visit our [DocC documentation](link-to-docc-when-available).

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to the main branch.

## License

Smockable is available under the Apache 2.0 license. See the LICENSE file for more info.
