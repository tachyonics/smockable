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
