<p align="center">
<a href="https://github.com/tachyonics/smockable/actions">
<img src="https://github.com/tachyonics/smockable/actions/workflows/swift.yml/badge.svg?branch=main" alt="Build - Main Branch">
</a>
<a href="http://swift.org">
<img src="https://img.shields.io/badge/swift-6.2|6.1-orange.svg?style=flat" alt="Swift 6.2 and 6.1 Compatible and Tested">
</a>
<a href="https://swiftpackageindex.com/tachyonics/smockable/documentation">
<img src="https://img.shields.io/badge/docc-documentation-blue.svg?style=flat" alt="Package documentation">
</a>
<img src="https://img.shields.io/badge/ubuntu-22.04|24.04-yellow.svg?style=flat" alt="Ubuntu 22.04 and 24.04 Tested">
<img src="https://img.shields.io/badge/license-Apache2-blue.svg?style=flat" alt="Apache 2">
</p>


# Smockable

A Swift library that uses code generation through Macros for creating type-safe mocks from protocols. Smockable generates mock implementations that support expectations, verification, and comprehensive testing capabilities.

Inspired by Java's [Mockito](https://site.mockito.org) along with starting out life as a fork of https://github.com/Matejkob/swift-spyable.

## Features

- ✅ **Type-safe mocks** generated at compile time using Swift macros
- ✅ **Expectation-based testing** with parameter matching and support for multiple calls, return values, errors, and custom closures
- ✅ **Call verification** with detailed invocation tracking and optional argument capture
- ✅ **Thread-safe** mock implementations with Sendable conformance
- ✅ **Flexible verifications** with parameter matching and InOrder verification to verify invocation sequence (including across multiple mocks)
- ✅ **Protocol inheritance** and associated types support
- ✅ **Async/await**, sync and throwing function support (including [typed throws](https://swiftpackageindex.com/tachyonics/smockable/main/documentation/smockable/typedthrows))
- ✅ **Protocol property requirements** with full get/set/async/throws support
- ✅ **Collection expectations and verification** for Arrays, Dictionaries, and Sets (include Equatable checks when the Collection is Equatable)

## Documentation

For detailed documentation, examples, and advanced usage patterns, see the [documentation](https://swiftpackageindex.com/tachyonics/smockable/main/documentation/smockable).

## Requirements

- Swift 6.1+
- iOS 18.0+ / macOS 15.0+ / tvOS 18.0+ / watchOS 11.0+

## Installation

### Swift Package Manager

Add Smockable to your project using Swift Package Manager:

#### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/tachyonics/smockable.git", from: "0.5.0")
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
    var apiKey: String { get set }
    func fetchUser(id: String) async throws -> User
    func fetchUsers(ids: [String]) async throws -> [User]
    func updateUser(_ user: User) async throws
}

// Creates a mock with an internal access modifier
@Smock(accessLevel: .internal)
protocol InternalService { }

// wraps the generated mock type in conditional compilation
@Smock(preprocessorFlag: "DEBUG")
protocol DebugOnlyService { }
```

The `@Smock` macro supports these optional parameters:
- `accessLevel`: Controls mock visibility (`.public`, `.package`, `.internal`, `.fileprivate`, `.private`)
- `preprocessorFlag`: Wraps mock in conditional compilation (e.g., `"DEBUG"`, `"TESTING"`)

### 2. Create and Configure a Mock

```swift
import Testing

@Test
func userFetching() async throws {
    // Create expectations
    var expectations = MockUserService.Expectations()
    
    // Configure property expectations
    when(expectations.apiKey.get(), return: "test-key")
    when(expectations.apiKey.set(.any), complete: .withSuccess)
    
    // Set up expected behavior with range matching with when(:return)
    let expectedUser1 = User(id: "123", name: "John Doe")
    let expectedUser2 = User(id: "456", name: "Mary Jane")
    when(expectations.fetchUsers(ids: ["user1", "user2"]), return: [expectedUser1, expectedUser2])
    
    // For functions with no return type, use when(:complete)
    when(expectations.updateUser(.any), complete: .withSuccess)
    
    // Create the mock
    let mockService = MockUserService(expectations: expectations)
    let codeUnderTest = CodeUnderTest(service: mockService)
    
    // Exercise the code under test
    let key = codeUnderTest.apiKey
    codeUnderTest.apiKey = "new-key"
    let users = try await codeUnderTest.fetchUser(id: ["user1", "user2"])
    try await codeUnderTest.updateUser(user)
    
    // Verify behavior
    verify(mockService, times: 1).fetchUsers(id: ["user1", "user2"])
    verify(mockService, times: 1).updateUser(.any)
    
    // Verify property access
    verify(mock, times: 1).apiKey.get()
    verify(mock, times: 1).apiKey.set("new-key")
    
    #expect(key == "test-key")
    #expect(users[0].id == "123")
    #expect(users[1].id == "456")
}
```

### 3. Set more Expectations

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

### 4. Verify more mock interactions

Smockable's verifications integrate with Swift Testing to provide detailed error messages about failures. 

![Smockable provides detailed error messages in test cases](https://github.com/tachyonics/smockable/blob/main/expectation_example.png?raw=true)

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
verify(mock, times: 1).getUserProfile(name: "John", age: 25)
verify(mock, atMost: 5).getUserProfile(name: "Jane", age: nil)
```

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to the main branch.

## License

Smockable is available under the Apache 2.0 license. See the LICENSE file for more info.
