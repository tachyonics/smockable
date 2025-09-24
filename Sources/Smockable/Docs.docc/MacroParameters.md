# @Smock Macro Parameters

Customize mock generation with optional parameters.

## Overview

The `@Smock` macro supports optional parameters that allow you to customize how mocks are generated. These parameters give you control over access levels and conditional compilation.

## Parameters

### accessLevel

Controls the access level of the generated mock struct and all its members.

```swift
@Smock(accessLevel: .internal)
protocol MyService {
    func doSomething() -> String
}

// Generates:
internal struct MockMyService: MyService, Sendable, VerifiableSmock {
    internal typealias VerifierType = Verifier
    internal func getVerifier(mode: VerificationMode, sourceLocation: SourceLocation, inOrder: InOrder?) -> Verifier { ... }
    internal init(expectations: consuming Expectations = .init()) { ... }
    // ... all other members are also internal
}
```

**Available Values:**
- `.public` (default): Mock is publicly accessible
- `.package`: Mock has package-level access (Swift 5.9+)
- `.internal`: Mock is internal to the module
- `.fileprivate`: Mock is accessible only within the same file
- `.private`: Mock is private to the enclosing declaration

### preprocessorFlag

Wraps the entire generated mock in conditional compilation. The mock will only be compiled when the specified preprocessor flag is defined.

```swift
@Smock(preprocessorFlag: "DEBUG")
protocol MyService {
    func doSomething() -> String
}

// Generates:
#if DEBUG
public struct MockMyService: MyService, Sendable, VerifiableSmock {
    // ... implementation
}
#endif
```

**Use Cases:**
- `"DEBUG"`: Include mocks only in debug builds
- `"TESTING"`: Include mocks only when testing flags are enabled
- `"UNIT_TESTS"`: Custom flag for unit test environments
- Any custom preprocessor flag your project defines

### additionalComparableTypes

Specifies additional types that should be treated as both Comparable and Equatable in the generated mock. By default, built-in and standard library types that conform to Comparable
will be automatically recognized but this allows you to use custom types with comparison-based matchers and exact value matching.

```swift
@Smock(additionalComparableTypes: [CustomID.self, Priority.self, Timestamp.self])
protocol TaskService {
    func createTask(id: CustomID, priority: Priority, createdAt: Timestamp) async throws -> Task
    func getTasksWithPriority(_ priority: Priority) async throws -> [Task]
}

// Generated mock will treat CustomID, Priority, and Timestamp as comparable
// This enables:
// - Exact value matching: when(mock.createTask(id: .value(specificID), ...))
// - Range matching: when(mock.getTasksWithPriority(.range(minPriority...maxPriority)))
```

### additionalEquatableTypes

Specifies additional types that should be treated as Equatable only in the generated mock. By default, built-in and standard library types that conform to Comparable
will be automatically recognized but this allows you to use custom types with exact value matching but not comparison-based operations.

```swift
@Smock(additionalEquatableTypes: [UserProfile.self, Settings.self, Configuration.self])
protocol UserService {
    func updateProfile(_ profile: UserProfile) async throws
    func saveSettings(_ settings: Settings) async throws
    func configure(with config: Configuration) async throws
}

// Generated mock will treat UserProfile, Settings, and Configuration as equatable
// This enables:
// - Exact value matching: when(mock.updateProfile(.value(specificProfile)))
```
