# Verification

Learn how to verify mock interactions and validate test behavior.

## Overview

Verification is how you check that your code interacted with mocks as expected. Smockable provides comprehensive verification capabilities through the `__verify` property on generated mocks, allowing you to inspect call counts, received parameters, and call order.

The `__verify` is available anytime afer the creation of the mock, representing its current state. This means in advanced test scenarios, you can
verify the state of the mock at multiple points during the test.

## Basic Verification

### Call Counts

Check how many times a method was called:

```swift
let mock = MockUserService(expectations: expectations)

// Use the mock
await mock.fetchUser(id: "123")
await mock.fetchUser(id: "456")

// Verify call count
let callCount1 = await mock.__verify.fetchUser_id.callCount
#expect(callCount1 == 2)

await mock.fetchUser(id: "789")

let callCount2 = await mock.__verify.fetchUser_id.callCount
#expect(callCount2 == 3)
```

### Received Inputs

Inspect the parameters passed to mock methods:

```swift
// Use the mock with different parameters
await mock.fetchUser(id: "123")
await mock.fetchUser(id: "456")
await mock.updateUser(id: "123", user: user1)
await mock.updateUser(id: "456", user: user2)

// Verify received inputs
let fetchInputs = await mock.__verify.fetchUser_id.receivedInputs
#expect(fetchInputs.count == 2)
#expect(fetchInputs[0] == "123")
#expect(fetchInputs[1] == "456")

let updateInputs = await mock.__verify.updateUser.receivedInputs
#expect(updateInputs.count == 2)
#expect(updateInputs[0].id == user1.id)
#expect(updateInputs[1].id == user2.id)
```

**Note:** For functions with a single input (in this case `fetchUser`), the `receivedInputs` will be a simple array of that type. For functions
with multiple inputs, `receivedInputs` (in this case `updateUser`) will be an array of tuples with appropriately typed elements labelled according to the function's
inputs.

```swift
await mock.searchUsers(query: "john", limit: 10, includeInactive: false)

let inputs = await mock.__verify.searchUsers_query_limit_includeInactive.receivedInputs
#expect(inputs.count == 1)

let firstCall = inputs[0]
#expect(firstCall.query == "john")
#expect(firstCall.limit == 10)
#expect(!firstCall.includeInactive)
```

### Verifying No Calls

Ensure certain methods were never called:

```swift
// Only call some methods
await mock.fetchUser(id: "123")

// Verify other methods weren't called
let updateCount = await mock.__verify.updateUser.callCount
let deleteCount = await mock.__verify.deleteUser_id.callCount

#expect(updateCount == 0)
#expect(deleteCount == 0)
```

## Working with Complex Parameters

### Custom Types

Any custom types used as either the inputs or outputs of functions must be `Sendable` so they can be passed in or out of the mock implementation and - in the case
of inputs - stored by the mock. The documentation [here](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Sendable-Types) 
explains the rules for Sendable types. Some types are always sendable, like structures that have only sendable properties and enumerations that have only sendable 
associated values.

Additionally while not required making any custom type conform to `Equatable` will allow for for easy verification:

```swift
struct SearchCriteria: Equatable {
    let query: String
    let filters: [String]
    let sortOrder: SortOrder
}

// In your test
let criteria = SearchCriteria(
    query: "test", 
    filters: ["active", "verified"], 
    sortOrder: .ascending
)

await mock.searchWithCriteria(criteria)

let inputs = await mock.__verify.searchWithCriteria.receivedInputs
#expect(inputs[0] == criteria)
```

### Collections

Verify collection parameters:

```swift
await mock.batchUpdateUsers([user1, user2, user3])

let inputs = await mock.__verify.batchUpdateUsers.receivedInputs
#expect(inputs[0].count == 3)
#expect(inputs[0].contains(user1))
#expect(inputs[0].contains(user2))
#expect(inputs[0].contains(user3))
```

### Optional Parameters

Handle optional parameters in verification:

```swift
await mock.fetchUser(id: "123", includeDetails: true)
await mock.fetchUser(id: "456", includeDetails: nil)

let inputs = await mock.__verify.fetchUser_id_includeDetails.receivedInputs
#expect(inputs.count == 2)
#expect(inputs[0].includeDetails == true)
#expect(inputs[1].includeDetails == nil)
```

## Async Verification

### Concurrent Access

Special care needs when dealing with concurrency to account for the inherent uncertainty in these scenarios.

```swift
// Multiple concurrent calls
await withTaskGroup(of: Void.self) { group in
    for i in 0..<10 {
        group.addTask {
            await mock.fetchUser(id: "\(i)")
        }
    }
}

// Verify total calls
let callCount = await mock.__verify.fetchUser_id.callCount
#expect(callCount == 10)

// Verify all IDs were received
let inputs = await mock.__verify.fetchUser_id.receivedInputs
let receivedIds = Set(inputs.map { $0.id })
let expectedIds = Set((0..<10).map { "\($0)" })
#expect(receivedIds == expectedIds)
```

In the case above, `receivedInputs` has no guaranteed order as its ordering is dependant on how the executing machine happened to schedule threads. One method
to ensure a unit test is robust against this uncertainty is shown above - using a set to ensure all expected calls where made while ignoring the order they happened
to be processed by the mock.

## Next Steps

- Learn about <doc:BestPractices> for effective testing strategies
