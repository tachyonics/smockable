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

### additionalComparableTypes / additionalEquatableTypes

These parameters control which **convenience overloads** the macro generates
for expectation and verifier methods. They do not affect matcher correctness
— `ValueMatcher<T>` always has `.exact()` when `T: Equatable` and `.range()`
when `T: Comparable`, regardless of these parameters.

By default, the macro recognizes built-in stdlib types (`String`, `Int`,
`Double`, `Bool`, `UUID`, `Date`, etc.) and generates shorthand overloads
for them. For example, a `String` parameter gets overloads that accept a
raw `String` (rather than wrapped in `.exact()`) and a `ClosedRange<String>` 
(rather than wrapped in `.range()`), so you can write:

```swift
when(expectations.getUser(name: "Alice"), return: user)
when(expectations.getUsers(name: "A"..."M"), return: users)
```

For custom types the macro doesn't recognize, it generates only the
explicit `ValueMatcher<T>` overload. You can still use `.exact()` and
`.range()` directly:

```swift
when(expectations.createTask(id: .exact(specificID)), return: task)
when(expectations.getTasksWithPriority(.range(low...high)), return: tasks)
```

If you prefer the shorthand form for custom types, add them to the
appropriate allowlist:

```swift
@Smock(additionalComparableTypes: [CustomID.self, Priority.self])
protocol TaskService {
    func createTask(id: CustomID, priority: Priority) async throws -> Task
}

Now you can write:

```swift
when(expectations.createTask(id: specificID, priority: low...high), return: task)
```

`additionalEquatableTypes` works the same way but only enables the exact-value
shorthand (not ranges).
