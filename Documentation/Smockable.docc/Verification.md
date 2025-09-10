# Verification

Learn how to verify mock interactions and validate test behavior.

## Overview

Verification is how you check that your code interacted with mocks as expected. Smockable provides comprehensive verification capabilities through the 
global `verify()` function with verification modes, allowing you to assert call counts and parameter matching in an expressive, declarative way.

The `verify()` function mirrors the `when()` function pattern, providing a consistent API for both setting expectations and verifying behavior. You can 
verify mock interactions at any point during your test, making it easy to test complex scenarios.

The `verify()` functions integrate with SwiftTesting to provide appropriate error messages when the verification fails. These functions to not track 

## Basic Verification

### Exact Call Counts

Verify that a method was called an exact number of times:

```swift
let mock = MockUserService(expectations: expectations)

// Use the mock
await mock.fetchUser(id: "123")
await mock.fetchUser(id: "456")

// Verify exact call count
await verify(mock, times: 2).fetchUser(id: .any)

await mock.fetchUser(id: "789")

// Verify updated call count
await verify(mock, times: 3).fetchUser(id: .any)
```

### Parameter Matching

Verify calls with specific parameter values or patterns:

```swift
// Use the mock with different parameters
await mock.fetchUser(id: "123")
await mock.fetchUser(id: "456")
await mock.updateUser(user1)
await mock.updateUser(user2)

// Verify calls with specific parameters
await verify(mock, times: 1).fetchUser(id: "123")
await verify(mock, times: 1).fetchUser(id: "456")

// Verify calls with any parameters
await verify(mock, times: 2).fetchUser(id: .any)
await verify(mock, times: 2).updateUser(.any)
```

### Multiple Parameters

Verify functions with multiple parameters:

```swift
await mock.searchUsers(query: "john", limit: 10, includeInactive: false)
await mock.searchUsers(query: "jane", limit: 5, includeInactive: true)

// Verify specific parameter combinations
await verify(mock, times: 1).searchUsers(
    query: "john", 
    limit: 10, 
    includeInactive: false
)

// Verify with mixed matchers
await verify(mock, times: 2).searchUsers(
    query: .any, 
    limit: 1...20, 
    includeInactive: .any
)
```

### Verifying No Calls

Ensure certain methods were never called:

```swift
// Only call some methods
await mock.fetchUser(id: "123")

// Verify other methods weren't called
await verify(mock, .never).updateUser(.any)
await verify(mock, .never).deleteUser(id: .any)

// Verify specific parameters were never used
await verify(mock, .never).fetchUser(id: "nonexistent")
```

## Verification Modes

Smockable provides several verification modes for different testing scenarios:

### Exact Count Verification

```swift
// Verify exact number of calls
await verify(mock, times: 3).fetchUser(id: .any)
await verify(mock, times: 0).deleteUser(id: .any)  // Same as .never
```

### Boundary Verification

```swift
// At least N times
await verify(mock, atLeast: 1).fetchUser(id: .any)
await verify(mock, .atLeastOnce).initialize()  // Shorthand for atLeast: 1

// At most N times
await verify(mock, atMost: 5).logMessage(.any)
await verify(mock, atMost: 0).criticalError(.any)  // Same as .never
```

### Range Verification

```swift
// Within a specific range
await verify(mock, times: 2...5).processItem(.any)
await verify(mock, times: 0...1).optionalOperation(.any)
```

### Never Called

```swift
// Verify method was never called
await verify(mock, .never).dangerousOperation(.any)
await verify(mock, .never).fetchUser(id: "admin")
```

## Working with Complex Parameters

### Custom Types

Any custom types used as either the inputs or outputs of functions must be `Sendable` so they can be passed in or out of the mock implementation and - in the case
of inputs - stored by the mock. The documentation [here](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Sendable-Types) 
explains the rules for Sendable types. Some types are always sendable, like structures that have only sendable properties and enumerations that have only sendable 
associated values.

For custom types that conform to `Comparable`, you can use exact value matching and range matching:

```swift
struct SearchCriteria: Comparable, Sendable {
    let query: String
    let filters: [String]
    let sortOrder: SortOrder
    
    // Implement Comparable requirements...
}

// In your test
let criteria = SearchCriteria(
    query: "test", 
    filters: ["active", "verified"], 
    sortOrder: .ascending
)

await mock.searchWithCriteria(criteria)

// Verify with exact matching
await verify(mock, times: 1).searchWithCriteria(criteria)

// Verify with any matching
await verify(mock, .atLeastOnce).searchWithCriteria(.any)
```

For non-comparable custom types, you can only use `.any` matching:

```swift
struct NonComparableData: Sendable {
    let data: Data
    let metadata: [String: Any]
}

await mock.processData(nonComparableData)

// Only .any matching is available for non-comparable types
await verify(mock, times: 1).processData(.any)
```

### Collections

Verify collection parameters using `.any` matching (collections are typically non-comparable):

```swift
await mock.batchUpdateUsers([user1, user2, user3])
await mock.batchUpdateUsers([user4, user5])

// Verify calls were made
await verify(mock, times: 2).batchUpdateUsers(.any)
await verify(mock, atLeast: 1).batchUpdateUsers(.any)
```

### Optional Parameters

Handle optional parameters in verification:

```swift
await mock.fetchUser(id: "123", includeDetails: true)
await mock.fetchUser(id: "456", includeDetails: nil)

// Verify calls with specific optional values
await verify(mock, times: 1).fetchUser(id: "123", includeDetails: true)
await verify(mock, times: 1).fetchUser(id: "456", includeDetails: nil)

// Verify total calls regardless of optional parameter values
await verify(mock, times: 2).fetchUser(id: .any, includeDetails: .any)
```

## Advanced Verification Patterns

### Parameter Range Matching

Use range matching for comparable types:

```swift
await mock.processValue(42)
await mock.processValue(15)
await mock.processValue(88)

// Verify calls within specific ranges
await verify(mock, times: 2).processValue(10...50)
await verify(mock, times: 1).processValue(80...100)
await verify(mock, times: 3).processValue(1...100)
```

### Concurrent Access

When testing concurrent code, verify the total number of calls:

```swift
// Multiple concurrent calls
await withTaskGroup(of: Void.self) { group in
    for i in 0..<10 {
        group.addTask {
            await mock.fetchUser(id: "\(i)")
        }
    }
}

// Verify total calls (order is not guaranteed in concurrent scenarios)
await verify(mock, times: 10).fetchUser(id: .any)
await verify(mock, atLeast: 5).fetchUser(id: "0"..."9")
```

### Progressive Verification

Verify mock state at different points during your test:

```swift
// Initial state
await verify(mock, .never).fetchUser(id: .any)

// After first operation
await mock.fetchUser(id: "123")
await verify(mock, times: 1).fetchUser(id: .any)

// After batch operation
await mock.fetchUser(id: "456")
await mock.fetchUser(id: "789")
await verify(mock, times: 3).fetchUser(id: .any)
await verify(mock, times: 1).fetchUser(id: "123")
```
