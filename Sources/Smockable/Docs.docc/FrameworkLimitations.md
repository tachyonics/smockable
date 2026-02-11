# Framework Limitations and Workarounds

This page discusses Smockable's limitations with protocol inheritance and external protocols, and how to work around them.

## Overview

Due to limitations in Swift macros, Smockable cannot automatically access the definitions of inherited protocols or protocols defined in external modules. This document
explains these limitations and provides practical workarounds to enable testing of complex protocol hierarchies.

## Limitation 1: Inherited Protocol Requirements

### The Problem

Swift macros cannot access the definitions of inherited protocols. When you apply `@Smock` to a protocol that inherits from another protocol, the macro only sees the
requirements explicitly declared in that protocol.

```swift
// This won't work as expected
protocol BaseService {
    func connect() async throws
    func disconnect() async throws
    func isConnected() async -> Bool
}

@Smock
protocol DataService: BaseService {
    func fetchData() async throws -> Data
    func saveData(_ data: Data) async throws
}

// MockDataService will only have fetchData and saveData methods
// connect, disconnect, and isConnected will be missing!
```

### The Workaround: Mirror Inherited Requirements

To work around this limitation, you must explicitly declare all inherited requirements in the protocol that has the `@Smock` macro applied:

```swift
protocol BaseService {
    func connect() async throws
    func disconnect() async throws
    func getConnectionStatus() async -> Bool
}

@Smock
protocol DataService: BaseService {
    // Mirror all inherited requirements
    func connect() async throws
    func disconnect() async throws
    func getConnectionStatus() async -> Bool
    
    // Add new requirements
    func fetchData() async throws -> Data
    func saveData(_ data: Data) async throws
}

@Test
func testInheritedProtocolWorkaround() async throws {
    var expectations = MockDataService.Expectations()
    
    // Now all methods are available
    when(expectations.connect(), complete: .withSuccess)
    when(expectations.disconnect(), complete: .withSuccess)
    when(expectations.getConnectionStatus(), return: true)
    when(expectations.fetchData(), return: "test data".data(using: .utf8)!)
    when(expectations.saveData(.any), complete: .withSuccess)
    
    let mock = MockDataService(expectations: expectations)
    let underTest = UnderTestComponent(service: mock)
    
    try await underTest.execute()

    // verify any mock interactions
}
```

In this scenario, `MockDataService` will conform to both the `DataService` and `BaseService` protocols and can be passed into component expecting conformance
to either.

## Limitation 2: External Protocol Dependencies

### The Problem

Smockable cannot be applied retroactively to protocols defined in external modules or the standard library. You cannot add `@Smock` to protocols you don't own.

```swift
// This won't work - you can't modify external protocols
@Smock  // ❌ Compiler error
extension ExternalNetworkService {
    // Cannot add @Smock to existing protocols
}
```

### The Workaround: Mirror External Protocol Requirements

When you need to mock a protocol that depends on external protocols, create a new protocol that mirrors all the external requirements of the existing protocol:

```swift
import Foundation

@Smock
protocol MyNetworkService: ExternalNetworkService {
    // Mirror all requirements of the external protocol
    func handleDataReceived(_ data: Data) async
    func handleRequestCompleted(error: Error?) async
}

@Test
func testExternalProtocolWorkaround() async throws {
    let expectations = MockMyNetworkService.Expectations()
    
    // Configure external protocol methods
    when(expectations.handleDataReceived(.any), complete: .withSuccess)
    when(expectations.handleRequestCompleted(error: .any), complete: .withSuccess)
    
    let mock = MockMyNetworkService(expectations: expectations)
    
    // Test external protocol behavior
    await mock.handleDataReceived(Data())
    await mock.handleRequestCompleted(error: nil)
    
    #expect(data.count > 0)
}
```

Because `MockMyNetworkService` conforms to the `ExternalNetworkService`, it can be passed when conformance to that protocol is required. In most cases
the protocol that you create can be kept private to your tests, simply to allow the mock to be generated.

## Limitation 3: Multiple Protocol Inheritance

### The Problem

When a protocol inherits from multiple protocols, the macro cannot access any of the parent protocol definitions.

```swift
// These protocols are defined separately
protocol Authenticatable {
    func authenticate(token: String) async throws -> Bool
}

protocol Cacheable {
    func cache(key: String, value: Data) async
    func getCached(key: String) async -> Data?
}

// This won't include methods from Authenticatable or Cacheable
@Smock
protocol SecureDataService: Authenticatable, Cacheable {
    func securelyFetchData(id: String) async throws -> Data
}
```

### The Workaround: Mirror All Parent Requirements

You must explicitly declare all requirements from all parent protocols:

```swift
protocol Authenticatable {
    func authenticate(token: String) async throws -> Bool
}

protocol Cacheable {
    func cache(key: String, value: Data) async
    func getCached(key: String) async -> Data?
}

@Smock
protocol SecureDataService: Authenticatable, Cacheable {
    // Mirror Authenticatable requirements
    func authenticate(token: String) async throws -> Bool
    
    // Mirror Cacheable requirements
    func cache(key: String, value: Data) async
    func getCached(key: String) async -> Data?
    
    // Add new requirements
    func securelyFetchData(id: String) async throws -> Data
}

@Test
func testMultipleInheritanceWorkaround() async throws {
    var expectations = MockSecureDataService.Expectations()
    
    // Configure methods from all parent protocols
    when(expectations.authenticate(token: .any), return: true)
    when(expectations.cache(key: .any, value: .any), complete: .withSuccess)
    when(expectations.getCached(key: .any), return: "cached data".data(using: .utf8)!)
    when(expectations.securelyFetchData(id: .any), return: "secure data".data(using: .utf8)!)
    
    let mock = MockSecureDataService(expectations: expectations)
    
    // Test all inherited functionality
    let isAuthenticated = try await mock.authenticate(token: "valid-token")
    #expect(isAuthenticated == true)
    
    await mock.cache(key: "test", value: Data())
    let cachedData = await mock.getCached(key: "test")
    #expect(cachedData != nil)
    
    let secureData = try await mock.securelyFetchData(id: "123")
    #expect(secureData.count > 0)
}
```

## Limitation 4: Actor Protocol Detection

### The Limitation

Smockable automatically detects `Actor` inheritance and generates an `actor` mock type when a protocol directly inherits from `Actor`. However, the macro can only detect direct inheritance — it cannot detect indirect conformance through parent protocols.

```swift
// ✅ Direct Actor inheritance — detected correctly
@Smock
protocol MyActorService: Actor {
    func process(id: String) async -> String
}

// ❌ Indirect Actor inheritance — NOT detected
protocol BaseActorService: Actor { }

@Smock
protocol MyService: BaseActorService {
    func process(id: String) async -> String
}
// MockMyService will be a struct, not an actor
```

### The Workaround

Add `Actor` directly to the protocol's inheritance clause alongside any other parent protocols:

```swift
protocol BaseActorService: Actor { }

@Smock
protocol MyService: BaseActorService, Actor {
    // Mirror BaseActorService requirements
    func process(id: String) async -> String
}
```

This is consistent with other inheritance limitations — the macro can only see what is explicitly declared in the protocol it is applied to.

## Limitation 5: Static Function and Property Restrictions

### Static Properties Not Supported

Smockable does not support static functions or properties, including constructors. Only instance functions and properties can be mocked.

```swift
@Smock
protocol ConfigService {
    var instanceProperty: String { get set }  // ✅ Supported
    func instanceFunction()  // ✅ Supported
    static var staticProperty: String { get } // ❌ Not supported
    static func staticFunction()  // ❌ Not supported
}
```

## See Also

- <doc:AssociatedTypes>
