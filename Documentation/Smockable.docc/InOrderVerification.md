# In-Order Verification

Verify that mock interactions occur in a specific sequence using `InOrder` verification.

## Overview

While standard verification checks that interactions occurred with the correct parameters and frequency, in-order verification adds the dimension of **sequence**. 
This is crucial when testing workflows where the order of operations matters, such as:

- Authentication flows that must happen before API calls
- Database transactions that require specific sequencing
- UI interactions that depend on previous state changes
- Multi-step processes with dependencies

Smockable provides the `InOrder` class to verify that mock interactions occur in the expected sequence, either strictly (every interaction must be verified in order) 
or loosely (allowing some interactions to be skipped). Invocation ordering across multiple mock implementations is also supported.

## Basic Usage

### Creating an InOrder Verifier

Create an `InOrder` instance with the mocks you want to track and specify the verification mode:

```swift
let inOrder = InOrder(strict: false, mockService, mockRepository, mockNotifier)
```

The `strict` parameter controls the verification behavior:
- **`false` (Non-Strict)**: Allows skipping interactions as long as what is verfied is verified in order
- **`true` (Strict)**: Every interaction must be verified in exact sequence

### Simple Verification

```swift
@Smock
protocol AuthenticationService {
    func validateCredentials(username: String, password: String) async throws -> Bool
    func generateToken(userId: String) async throws -> String
    func logActivity(event: String) async throws
}

@Test
func testAuthenticationFlow() async throws {
    var expectations = MockAuthenticationService.Expectations()
    when(expectations.validateCredentials(username: .any, password: .any), return: true)
    when(expectations.generateToken(userId: .any), return: "auth-token")
    when(expectations.logActivity(event: .any), complete: .withSuccess)
    
    let mockAuth = MockAuthenticationService(expectations: expectations)
    
    // Execute authentication flow
    let isValid = try await mockAuth.validateCredentials(username: "user", password: "pass")
    let token = try await mockAuth.generateToken(userId: "user123")
    try await mockAuth.logActivity(event: "login")
    
    // Verify interactions occurred in correct order
    let inOrder = InOrder(strict: false, mockAuth)
    inOrder.verify(mockAuth).validateCredentials(username: "user", password: "pass")
    inOrder.verify(mockAuth).generateToken(userId: "user123")
    inOrder.verify(mockAuth).logActivity(event: "login")
    inOrder.verifyNoMoreInteractions()
}
```

## Verification Modes

### Default Verification (additionalTimes: 1)

```swift
inOrder.verify(mock).someMethod()  // Verifies exactly 1 interaction
inOrder.verify(mock, additionalTimes: 3).repeatedMethod()  // Verifies exactly 3 interactions
```

The following statements are equivalent-

```swift
inOrder.verify(mock, .additionalNone).unwantedMethod()
inOrder.verify(mock, additionalTimes: 0).unwantedMethod()
```

### At Least Verification (Greedy)

```swift
inOrder.verify(mock, additionalAtLeast: 2).someMethod()
```

The following statements are equivalent-

```swift
inOrder.verify(mock, .additionalAtLeastOnce).requiredMethod()
inOrder.verify(mock, additionalAtLeast: 1).requiredMethod()
```

**Greedy Behavior**: `additionalAtLeast` consumes as many consecutive matching interactions of this function or property as possible, not just the minimum required.
Note that this may cause strict verification to fail if all these matching interactions are not all the next mock interactions.

### At Most Verification

```swift
inOrder.verify(mock, additionalAtMost: 5).someMethod()
```

Verifies up to the specified number of interactions.

### Range Verification

```swift
inOrder.verify(mock, additionalRange: 3...5).someMethod()
```

Verifies at least the lower bound and up to the upper bound number of matching interactions. Will consume as many consecutive matching interactions 
of this function or property as possible, not just the minimum required

## Strict vs Non-Strict Modes

### Non-Strict Mode (Default)

Allows skipping interactions as long as what is verfied is verified in order:

```swift
@Test
func testNonStrictMode() {
    // Setup...
    
    // Execute calls
    mockService.setupCall()      // This can be skipped
    mockService.importantCall()  // Verify this
    mockService.cleanupCall()    // This can be skipped
    mockService.finalCall()      // Verify this
    
    let inOrder = InOrder(strict: false, mockService)
    inOrder.verify(mockService).importantCall()  // Skips setupCall
    inOrder.verify(mockService).finalCall()      // Skips cleanupCall
    inOrder.verifyNoMoreInteractions()
}
```

### Strict Mode

Every interaction must be verified in exact sequence:

```swift
@Test
func testStrictMode() {
    // Setup...
    
    // Execute calls
    mockService.firstCall()
    mockService.secondCall()
    mockService.thirdCall()
    
    let inOrder = InOrder(strict: true, mockService)
    inOrder.verify(mockService).firstCall()    // Must verify all
    inOrder.verify(mockService).secondCall()   // interactions
    inOrder.verify(mockService).thirdCall()    // in exact order
    inOrder.verifyNoMoreInteractions()
}
```

## Multiple Mock Verification

Verify interactions across multiple mocks in global order:

```swift
@Test
func testMultipleMockOrdering() {
    var dbExpectations = MockDatabase.Expectations()
    var apiExpectations = MockAPIClient.Expectations()
    var logExpectations = MockLogger.Expectations()
    
    when(dbExpectations.connect(), complete: .withSuccess)
    when(apiExpectations.fetchData(), return: Data())
    when(dbExpectations.save(data: .any), complete: .withSuccess)
    when(logExpectations.log(message: .any), complete: .withSuccess)
    
    let mockDB = MockDatabase(expectations: dbExpectations)
    let mockAPI = MockAPIClient(expectations: apiExpectations)
    let mockLogger = MockLogger(expectations: logExpectations)
    
    // Execute workflow
    mockDB.connect()                    // Global order: 1
    let data = mockAPI.fetchData()      // Global order: 2
    mockDB.save(data: data)            // Global order: 3
    mockLogger.log(message: "Success") // Global order: 4
    
    // Verify global ordering across all mocks
    let inOrder = InOrder(strict: false, mockDB, mockAPI, mockLogger)
    inOrder.verify(mockDB).connect()
    inOrder.verify(mockAPI).fetchData()
    inOrder.verify(mockDB).save(data: .any)
    inOrder.verify(mockLogger).log(message: "Success")
    inOrder.verifyNoMoreInteractions()
}
```

## Unverified Interactions

It is recommended to call `verifyNoMoreInteractions` as the final verification to guard against expected interactions following the verified sequence.

```swift
inOrder.verifyNoMoreInteractions()

// In strict mode: Fails if any interactions weren't verified
// In non-strict mode: Fails if any verified global indexes have unverified interactions
```

## Integration with Existing Verification

In-order verification works alongside standard verification:

```swift
// Standard verification (no ordering)
verify(mock, times: 3).someMethod()

// In-order verification
let inOrder = InOrder(strict: false, mock)
inOrder.verify(mock, additionalTimes: 2).orderedMethod()
inOrder.verifyNoMoreInteractions()

// Both can be used in the same test
verify(mock).anyTimeMethod()  // Order doesn't matter
```

## See Also

- <doc:Verification> - Standard verification techniques
- <doc:Expectations> - Setting up mock expectations
- <doc:FrameworkLimitations> - Current limitations and workarounds
