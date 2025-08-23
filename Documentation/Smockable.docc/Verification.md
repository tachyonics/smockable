# Verification

Learn how to verify mock interactions and validate test behavior.

## Overview

Verification is how you check that your code interacted with mocks as expected. Smockable provides comprehensive verification capabilities through the `__verify` property on generated mocks, allowing you to inspect call counts, received parameters, and call order.

## Basic Verification

### Call Counts

Check how many times a method was called:

```swift
let mock = MockUserService(expectations: expectations)

// Use the mock
await mock.fetchUser(id: "123")
await mock.fetchUser(id: "456")

// Verify call count
let callCount = await mock.__verify.fetchUser_id.callCount
#expect(callCount == 2)
```

### Received Inputs

Inspect the parameters passed to mock methods:

```swift
// Use the mock with different parameters
await mock.fetchUser(id: "123")
await mock.fetchUser(id: "456")
await mock.updateUser(user1)
await mock.updateUser(user2)

// Verify received inputs
let fetchInputs = await mock.__verify.fetchUser_id.receivedInputs
#expect(fetchInputs.count == 2)
#expect(fetchInputs[0].id == "123")
#expect(fetchInputs[1].id == "456")

let updateInputs = await mock.__verify.updateUser.receivedInputs
#expect(updateInputs.count == 2)
#expect(updateInputs[0].id == user1.id)
#expect(updateInputs[1].id == user2.id)
```

## Advanced Verification

### Verifying Call Order

Check the order of method calls across different methods:

```swift
// Use the mock
await mock.authenticate(username: "john", password: "secret")
await mock.fetchUser(id: "123")
await mock.updateUser(user)
await mock.logout()

// Verify the sequence
let authCount = await mock.__verify.authenticate_username_password.callCount
let fetchCount = await mock.__verify.fetchUser_id.callCount
let updateCount = await mock.__verify.updateUser.callCount
let logoutCount = await mock.__verify.logout.callCount

#expect(authCount == 1)
#expect(fetchCount == 1)
#expect(updateCount == 1)
#expect(logoutCount == 1)
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

### Parameter Validation

Verify specific parameter values and types:

```swift
await mock.searchUsers(query: "john", limit: 10, includeInactive: false)

let inputs = await mock.__verify.searchUsers_query_limit_includeInactive.receivedInputs
#expect(inputs.count == 1)

let firstCall = inputs[0]
#expect(firstCall.query == "john")
#expect(firstCall.limit == 10)
#expect(!firstCall.includeInactive)
```

## Working with Complex Parameters

### Custom Types

For custom types, ensure they conform to `Equatable` for easy verification:

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

Verification properties are thread-safe and can be accessed concurrently:

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

### Timing Verification

Verify that calls happen within expected timeframes:

```swift
let startTime = Date()

await mock.performLongOperation()

let endTime = Date()
let duration = endTime.timeIntervalSince(startTime)

let callCount = await mock.__verify.performLongOperation.callCount
#expect(callCount == 1)
#expect(duration < 1.0) // Should complete quickly since it's a mock
```

## Verification Patterns

### Test Setup Pattern

```swift
@Suite struct UserServiceTests {
    var mockService: MockUserService!
    var expectations: MockUserService.Expectations!
    
    init() {
        expectations = MockUserService.Expectations()
        // Set up common expectations
        expectations.fetchUser_id.value(defaultUser)
    }
    
    @Test func userFetching() async {
        mockService = MockUserService(expectations: expectations)
        
        // Test code
        let user = await mockService.fetchUser(id: "123")
        
        // Verification
        await verifyFetchUserCalled(with: "123")
    }
    
    private func verifyFetchUserCalled(with id: String) async {
        let inputs = await mockService.__verify.fetchUser_id.receivedInputs
        #expect(inputs.contains { $0.id == id })
    }
}
```

### Verification Helper Methods

Create reusable verification helpers:

```swift
extension MockUserService {
    func verifyFetchUserCalled(times expectedCount: Int) async -> Bool {
        let count = await self.__verify.fetchUser_id.callCount
        return count == expectedCount
    }
    
    func verifyFetchUserCalledWith(id: String) async -> Bool {
        let inputs = await self.__verify.fetchUser_id.receivedInputs
        return inputs.contains { $0.id == id }
    }
    
    func verifyNoUpdatesCalled() async -> Bool {
        let count = await self.__verify.updateUser.callCount
        return count == 0
    }
}

// Usage in tests
#expect(await mock.verifyFetchUserCalled(times: 2))
#expect(await mock.verifyFetchUserCalledWith(id: "123"))
#expect(await mock.verifyNoUpdatesCalled())
```

## Common Verification Mistakes

### 1. Forgetting Async Context

```swift
// Wrong: Missing await
let callCount = mock.__verify.fetchUser_id.callCount // Compile error

// Correct: Using await
let callCount = await mock.__verify.fetchUser_id.callCount
```

### 2. Checking Verification Before Mock Usage

```swift
// Wrong: Checking before using mock
let callCount = await mock.__verify.fetchUser_id.callCount // Will be 0
await mock.fetchUser(id: "123")

// Correct: Check after using mock
await mock.fetchUser(id: "123")
let callCount = await mock.__verify.fetchUser_id.callCount // Will be 1
```

### 3. Not Handling Async Properly in Tests

```swift
// Wrong: Not marking test as async
func testUserService() { // Missing async
    let callCount = await mock.__verify.fetchUser_id.callCount // Compile error
}

// Correct: Async test
@Test func userService() async {
    let callCount = await mock.__verify.fetchUser_id.callCount
}
```

## Best Practices

### 1. Verify Both Positive and Negative Cases

```swift
// Verify expected calls happened
#expect(await mock.__verify.fetchUser_id.callCount == 1)

// Verify unexpected calls didn't happen
#expect(await mock.__verify.deleteUser_id.callCount == 0)
```

### 2. Use Descriptive Assertions

```swift
// Good: Descriptive assertion messages
#expect(
    await mock.__verify.fetchUser_id.callCount == 1,
    "fetchUser should be called exactly once during initialization"
)
```

### 3. Group Related Verifications

```swift
// Verify authentication flow
let authInputs = await mock.__verify.authenticate_username_password.receivedInputs
#expect(authInputs.count == 1)
#expect(authInputs[0].username == "testuser")

// Verify subsequent operations
#expect(await mock.__verify.fetchUserProfile.callCount == 1)
#expect(await mock.__verify.loadPreferences.callCount == 1)
```

## Next Steps

- Explore <doc:AsyncAndThrowing> for async-specific patterns
- See <doc:CommonPatterns> for real-world verification examples
- Learn about <doc:BestPractices> for effective testing strategies