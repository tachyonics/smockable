# Verification

Learn how to verify mock interactions and validate test behavior.

## Overview

Verification is how you check that your code interacted with mocks as expected. Smockable provides comprehensive verification capabilities through the 
global `verify()` function with verification modes, allowing you to assert call counts and parameter matching in an expressive, declarative way.

The `verify()` function mirrors the `when()` function pattern, providing a consistent API for both setting expectations and verifying behavior. You can 
verify mock interactions at any point during your test, making it easy to test complex scenarios.

The `verify()` functions integrate with SwiftTesting to provide appropriate error messages when the verification fails. These functions do not take into 
account any previous verifcation calls and so each `verify()` call is considering the full history of the mock.

## Basic Verification

### Exact Call Counts

Verify that a method was called an exact number of times:

```swift
let mock = MockUserService(expectations: expectations)

// Use the mock
await mock.fetchUser(id: "123")
await mock.fetchUser(id: "456")

// Verify exact call count
verify(mock, times: 2).fetchUser(id: .any)

await mock.fetchUser(id: "789")

// Verify updated call count - takes into account the full history of the mock
// and doesn't consider any previous verify calls
verify(mock, times: 3).fetchUser(id: .any)
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
verify(mock, times: 1).fetchUser(id: "123")
verify(mock, times: 1).fetchUser(id: "456")

// Verify calls with any parameters
verify(mock, times: 2).fetchUser(id: .any)
verify(mock, times: 2).updateUser(.any)
```

### Multiple Parameters

Verify functions with multiple parameters:

```swift
await mock.searchUsers(query: "john", limit: 10, includeInactive: false)
await mock.searchUsers(query: "jane", limit: 5, includeInactive: true)

// Verify specific parameter combinations
verify(mock, times: 1).searchUsers(
    query: "john", 
    limit: 10, 
    includeInactive: false
)

// Verify with mixed matchers
verify(mock, times: 2).searchUsers(
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
verify(mock, .never).updateUser(.any)
verify(mock, .never).deleteUser(id: .any)

// Verify specific parameters were never used
verify(mock, .never).fetchUser(id: "nonexistent")
```

You can also easily verify that no interactions occurred with the mock 
across any of its properties or functions.

```swift
verifyNoInteractions(mock)
```

## Verification Modes

Smockable provides several verification modes for different testing scenarios:

### Exact Count Verification

```swift
// Verify exact number of calls
verify(mock, times: 3).fetchUser(id: .any)
verify(mock, times: 0).deleteUser(id: .any)  // Same as .never
```

### Boundary Verification

```swift
// At least N times
verify(mock, atLeast: 1).fetchUser(id: .any)
verify(mock, .atLeastOnce).initialize()  // Shorthand for atLeast: 1

// At most N times
verify(mock, atMost: 5).logMessage(.any)
verify(mock, atMost: 0).criticalError(.any)  // Same as .never
```

### Range Verification

```swift
// Within a specific range
verify(mock, times: 2...5).processItem(.any)
verify(mock, times: 0...1).optionalOperation(.any)
```

### Never Called

```swift
// Verify method was never called
verify(mock, .never).dangerousOperation(.any)
verify(mock, .never).fetchUser(id: "admin")
```

## Custom Matcher Verification

Custom matchers can be used in verification just like in expectations, allowing you to verify calls with complex matching logic:

```swift
// Verify calls with custom matcher conditions
verify(mock, times: 2).processNumber(value: .matching { $0 % 2 == 0 })  // Even numbers
verify(mock, atLeast: 1).validateEmail(email: .matching { $0.contains("@") })  // Email format
verify(mock, .never).uploadData(data: .matching { $0.count > 1000000 })  // Large uploads

// Complex verification conditions
verify(mock, times: 1).processText(text: .matching { text in
    let words = text.split(separator: " ")
    return words.count >= 3 && words.allSatisfy { $0.count > 2 }
})

// Mix custom matchers with other verification types
verify(mock, times: 1).complexMethod(
    id: .matching { $0 > 100 },       // Custom condition
    name: "user"..."zebra",           // Range matching
    data: .matching { $0.count > 0 }, // Another custom condition
    flag: true                        // Exact matching
)
```

These matchers are useful for verifying parameter formats, ranges, computed properties or partially verifying inputs.

**Note:** Verifications will return the total number of matching invocations across the lifetime of the mock and regardless of 
what other verifications have occurred. This is different to how expectations work - where the first matching expectation will
be used for an invocation. 


```swift
var expectations = MockTestValueMatcherService.Expectations()

// Test that first matching custom expectation takes priority
when(
    expectations.customMatcherInt(value: .matching { $0 > 0 }),     // First: positive numbers
    return: "positive"
)
when(
    expectations.customMatcherInt(value: .matching { $0 % 2 == 0 }), // Second: even numbers
    return: "even"
)

let mock = MockTestValueMatcherService(expectations: expectations)

// Value 4 matches both conditions, should use first expectation
let result1 = mock.customMatcherInt(value: 4)
// Value 4 again, should now use second expectation (first is consumed)
let result2 = mock.customMatcherInt(value: 4)

#expect(result1 == "positive")
#expect(result2 == "even")

// both calls match to both parameter matcher expressions
verify(mock, times: 2).customMatcherInt(value: .matching { $0 > 0 })
verify(mock, times: 2).customMatcherInt(value: .matching { $0 % 2 == 0 })
```

In this case `InOrder` verification can provide a more equivalent experience.

```swift
let inOrder = InOrder(strict: true, mock)
inOrder.verify(mock, additionalTimes: 1).customMatcherInt(value: .matching { $0 > 0 })
inOrder.verify(mock, additionalTimes: 1).customMatcherInt(value: .matching { $0 % 2 == 0 })
inOrder.verifyNoAdditionalInteractions()
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
verify(mock, times: 1).searchWithCriteria(criteria)

// Verify with any matching
verify(mock, .atLeastOnce).searchWithCriteria(.any)
```

For non-comparable custom types, you can only use `.any` matching:

```swift
struct NonComparableData: Sendable {
    let data: Data
    let metadata: [String: Any]
}

await mock.processData(nonComparableData)

// Only .any matching is available for non-comparable types
verify(mock, times: 1).processData(.any)
```

### Collections

Verify collection parameters using `.any` matching (collections are typically non-comparable):

```swift
await mock.batchUpdateUsers([user1, user2, user3])
await mock.batchUpdateUsers([user4, user5])

// Verify calls were made
verify(mock, times: 2).batchUpdateUsers(.any)
verify(mock, atLeast: 1).batchUpdateUsers(.any)
```

### Optional Parameters

Handle optional parameters in verification:

```swift
await mock.fetchUser(id: "123", includeDetails: true)
await mock.fetchUser(id: "456", includeDetails: nil)

// Verify calls with specific optional values
verify(mock, times: 1).fetchUser(id: "123", includeDetails: true)
verify(mock, times: 1).fetchUser(id: "456", includeDetails: nil)

// Verify total calls regardless of optional parameter values
verify(mock, times: 2).fetchUser(id: .any, includeDetails: .any)
```

## Advanced Verification Patterns

### Parameter Range Matching

Use range matching for comparable types:

```swift
await mock.processValue(42)
await mock.processValue(15)
await mock.processValue(88)

// Verify calls within specific ranges
verify(mock, times: 2).processValue(10...50)
verify(mock, times: 1).processValue(80...100)
verify(mock, times: 3).processValue(1...100)
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
verify(mock, times: 10).fetchUser(id: .any)
verify(mock, atLeast: 5).fetchUser(id: "0"..."9")
```

### Progressive Verification

Verify mock state at different points during your test:

```swift
// Initial state
verify(mock, .never).fetchUser(id: .any)

// After first operation
await mock.fetchUser(id: "123")
verify(mock, times: 1).fetchUser(id: .any)

// After batch operation
await mock.fetchUser(id: "456")
await mock.fetchUser(id: "789")
verify(mock, times: 3).fetchUser(id: .any)
verify(mock, times: 1).fetchUser(id: "123")
```

## Property Verification

Smockable provides comprehensive verification for protocol property requirements, supporting all property types:

```swift
@Smock
protocol ConfigService {
    var apiKey: String { get set }
    var isEnabled: Bool { get }
    var lastUpdate: Date { get async }
    var secretKey: String { get throws }
    var asyncSecretKey: String { get async throws }
}

@Test func testPropertyVerification() async throws {
    var expectations = MockConfigService.Expectations()
    
    // Setup property expectations
    when(expectations.apiKey.get(), return: "test-key")
    when(expectations.apiKey.set(.any), complete: .withSuccess)
    when(expectations.isEnabled.get(), return: true)
    when(expectations.lastUpdate.get(), return: Date())
    when(expectations.secretKey.get(), return: "secret")
    when(expectations.asyncSecretKey.get(), return: "async-secret")
    
    let mock = MockConfigService(expectations: expectations)
    
    // Use properties
    let key = mock.apiKey
    mock.apiKey = "new-key"
    let enabled = mock.isEnabled
    let update = await mock.lastUpdate
    let secret = try mock.secretKey
    let asyncSecret = try await mock.asyncSecretKey
    
    // Verify property access patterns
    verify(mock, times: 1).apiKey.get()
    verify(mock, times: 1).apiKey.set("new-key")
    verify(mock, times: 1).apiKey.set(.any)
    verify(mock, times: 1).isEnabled.get()
    verify(mock, times: 1).lastUpdate.get()
    verify(mock, times: 1).secretKey.get()
    verify(mock, times: 1).asyncSecretKey.get()
    
    // Verify specific values
    verify(mock, times: 1).apiKey.set("new-key")
    verify(mock, .never).apiKey.set("wrong-key")
}
```

## Collection Verification

Verify collection parameters with flexible matching strategies:
Similar to expectations, Smockable you to set verifications for Arrays, Dictionaries, and Sets. Any such
collection can use wild-card (`.any`) verifications to match any invocations. Collections that conform to the Equatable protocol (because
there elements conform to this protocol), can use exact verification matching.

```swift
@Smock
protocol DataProcessor {
    func processItems(_ items: [String]) -> Int
    func mergeConfigs(_ configs: [String: String]) -> Bool
    func analyzeNumbers(_ numbers: Set<Int>) -> Double
}

@Test func testCollectionVerification() {
    var expectations = MockDataProcessor.Expectations()
    
    when(expectations.processItems(.any), times: .unbounded, return: 1)
    when(expectations.mergeConfigs(.any), times: .unbounded, return: true)
    when(expectations.analyzeNumbers(.any), times: .unbounded, return: 3.14)
    
    let mock = MockDataProcessor(expectations: expectations)
    
    // Call with different collections
    _ = mock.processItems(["a", "b"])
    _ = mock.processItems(["x", "y", "z"])
    _ = mock.mergeConfigs(["key1": "value1"])
    _ = mock.mergeConfigs(["key2": "value2", "key3": "value3"])
    _ = mock.analyzeNumbers(Set([1, 2, 3]))
    _ = mock.analyzeNumbers(Set([10, 20]))
    
    // Verify collection calls with .any matching
    verify(mock, times: 2).processItems(.any)
    verify(mock, times: 2).mergeConfigs(.any)
    verify(mock, times: 2).analyzeNumbers(.any)
    
    // Verify specific collection content
    verify(mock, times: 1).processItems(["a", "b"])
    verify(mock, times: 1).processItems(["x", "y", "z"])
    verify(mock, times: 1).mergeConfigs(["key1": "value1"])
    verify(mock, times: 1).analyzeNumbers(Set([1, 2, 3]))
    
    // Verify never called with specific content
    verify(mock, .never).processItems(["not", "called"])
    verify(mock, .never).mergeConfigs(["wrong": "config"])
}
```
