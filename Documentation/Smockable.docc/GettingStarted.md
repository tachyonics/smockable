# Getting Started

Learn how to set up and use Smockable in your Swift projects.

## Overview

Smockable is a Swift library that uses code generation through Macros that generates mock implementations for protocols at compile time. This guide will walk you through the basic concepts and show you how to create your first mock.

## What is Smockable?

Smockable uses Swift macros to automatically generate mock implementations of your protocols. When you annotate a protocol with `@Smock`, the macro generates a corresponding `Mock{ProtocolName}` struct that:

- Implements all protocol requirements
- Provides an expectations-based API for configuring behavior
- Tracks all method calls for verification
- Is thread-safe and Sendable
- Supports async/await and throwing functions

## Basic Workflow

The typical workflow with Smockable follows these steps:

1. **Define a protocol** with the `@Smock` attribute
2. **Create expectations** to define how the mock should behave
3. **Initialize the mock** with those expectations
4. **Use the mock** in your tests or code
5. **Verify behavior** by checking call counts and received inputs

## Your First Mock

Let's create a simple example:

```swift
import Smockable

// 1. Define a protocol with @Smock
@Smock
protocol NetworkService {
    func fetchData(from url: String) async throws -> Data
}

// 2. In your test
@Test func networkCall() async throws {
    // Create expectations
    let expectations = MockNetworkService.Expectations()
    
    // Configure expected behavior
    let expectedData = "Hello, World!".data(using: .utf8)!
    expectations.fetchData_from.value(expectedData)
    
    // Create the mock
    let mockService = MockNetworkService(expectations: expectations)
    
    // Use the mock
    let data = try await mockService.fetchData(from: "https://example.com")
    
    // Verify
    #expect(data == expectedData)
    
    let callCount = await mockService.__verify.fetchData_from.callCount
    #expect(callCount == 1)
}
```

## Key Components

### @Smock Macro

The `@Smock` macro is applied to protocol declarations and generates the mock implementation. It must be applied to protocols only.

### Expectations

Expectations define how your mock should behave when methods are called. They support:

- **Return values**: `.value(someValue)`
- **Errors**: `.error(someError)`
- **Custom logic**: `.using { parameters in ... }`
- **Call counts**: `.times(n)` or `.unboundedTimes()`

### Verification

The `__verify` property on generated mocks provides access to call tracking:

- `callCount`: Number of times a method was called
- `receivedInputs`: Array of all parameter values received

## Next Steps

- Learn about <doc:Expectations> to understand how to configure mock behavior
- Explore <doc:Verification> to see how to validate interactions
- Check out <doc:AsyncAndThrowing> for async and throwing function support