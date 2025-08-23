# Async and Throwing Functions

Learn how to work with async and throwing functions in Smockable.

## Overview

Smockable provides full support for modern Swift concurrency patterns, including async functions, throwing functions, and combinations of both. The generated mocks maintain the same async and throwing characteristics as the original protocol methods.

## Async Functions

### Basic Async Support

Async functions work seamlessly with Smockable:

```swift
@Smock
protocol DataService {
    func fetchData() async -> Data
    func processData(_ data: Data) async -> ProcessedData
}

// In your test
@Test func asyncOperations() async {
    let expectations = MockDataService.Expectations()
    let expectedData = "test".data(using: .utf8)!
    
    expectations.fetchData.value(expectedData)
    expectations.processData.value(ProcessedData())
    
    let mock = MockDataService(expectations: expectations)
    
    // These calls are naturally async
    let data = await mock.fetchData()
    let processed = await mock.processData(data)
    
    // Verification is also async
    let fetchCount = await mock.__verify.fetchData.callCount
    #expect(fetchCount == 1)
}
```

### Async Closures in Expectations

You can use async closures in expectations:

```swift
expectations.fetchUserData_id.using { id in
    // This closure can perform async operations
    let userData = await someAsyncDataFetch(id)
    return userData
}
```

### Concurrent Mock Usage

Mocks are thread-safe and support concurrent access:

```swift
@Test func concurrentAccess() async {
    let expectations = MockDataService.Expectations()
    expectations.fetchData.using { 
        // Simulate some async work
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        return "data".data(using: .utf8)!
    }.unboundedTimes()
    
    let mock = MockDataService(expectations: expectations)
    
    // Multiple concurrent calls
    await withTaskGroup(of: Data.self) { group in
        for i in 0..<5 {
            group.addTask {
                return await mock.fetchData()
            }
        }
        
        var results: [Data] = []
        for await result in group {
            results.append(result)
        }
        
        #expect(results.count == 5)
    }
    
    let callCount = await mock.__verify.fetchData.callCount
    #expect(callCount == 5)
}
```

## Throwing Functions

### Basic Throwing Support

Throwing functions support both success and error cases:

```swift
@Smock
protocol NetworkService {
    func uploadFile(_ data: Data) throws -> UploadResult
    func downloadFile(id: String) throws -> Data
}

@Test func throwingFunctions() throws {
    let expectations = MockNetworkService.Expectations()
    
    // Set up success and error expectations
    expectations.uploadFile
        .value(UploadResult.success)           // First call succeeds
        .error(NetworkError.connectionFailed)  // Second call throws
        .value(UploadResult.success)           // Third call succeeds
    
    expectations.downloadFile_id
        .error(NetworkError.fileNotFound)      // Always throws
    
    let mock = MockNetworkService(expectations: expectations)
    
    // Test successful upload
    let result = try mock.uploadFile(testData)
    #expect(result == UploadResult.success)
    
    // Test failed upload
    #expect(throws: NetworkError.connectionFailed) {
        try mock.uploadFile(testData)
    }
    
    // Test download error
    #expect(throws: NetworkError.fileNotFound) {
        try mock.downloadFile(id: "test")
    }
}
```

### Custom Error Logic

Use closures for complex error conditions:

```swift
expectations.validateInput.using { input in
    if input.isEmpty {
        throw ValidationError.emptyInput
    }
    if input.count > 100 {
        throw ValidationError.inputTooLong
    }
    return ValidationResult.valid
}
```

## Async Throwing Functions

### Combined Async and Throwing

Functions that are both async and throwing work naturally:

```swift
@Smock
protocol APIService {
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws -> User
    func deleteUser(id: String) async throws
}

@Test func asyncThrowingFunctions() async throws {
    let expectations = MockAPIService.Expectations()
    
    expectations.fetchUser_id
        .value(testUser)                        // First call succeeds
        .error(APIError.userNotFound)           // Second call throws
        .using { id in                          // Third call uses custom logic
            if id == "admin" {
                throw APIError.unauthorized
            }
            return User(id: id, name: "Generated")
        }.unboundedTimes()
    
    let mock = MockAPIService(expectations: expectations)
    
    // Test successful fetch
    let user = try await mock.fetchUser(id: "123")
    #expect(user.id == "123")
    
    // Test error case
    await #expect(throws: APIError.userNotFound) {
        try await mock.fetchUser(id: "456")
    }
    
    // Test custom logic
    await #expect(throws: APIError.unauthorized) {
        try await mock.fetchUser(id: "admin")
    }
}
```

### Async Error Closures

Closures in expectations can be both async and throwing:

```swift
expectations.processDataAsync_input.using { input async throws in
    // Simulate async validation
    let isValid = await validateInputAsync(input)
    guard isValid else {
        throw ProcessingError.invalidInput
    }
    
    // Simulate async processing
    let result = await processAsync(input)
    return result
}
```

## Error Types and Patterns

### Specific Error Types

Work with specific error types for precise testing:

```swift
enum NetworkError: Error, Equatable {
    case connectionFailed
    case timeout
    case serverError(code: Int)
    case invalidResponse
}

expectations.makeRequest_url
    .error(NetworkError.connectionFailed)
    .error(NetworkError.timeout)
    .error(NetworkError.serverError(code: 500))
    .value(successResponse)
```

### Error Sequences

Create complex error scenarios:

```swift
// Simulate retry logic: fail twice, then succeed
expectations.unreliableOperation
    .error(TransientError.temporaryFailure).times(2)
    .value(OperationResult.success)
    .error(TransientError.temporaryFailure).times(2)
    .value(OperationResult.success)
```

## Testing Patterns

### Retry Logic Testing

Test retry mechanisms with controlled failures:

```swift
@Test func retryLogic() async throws {
    let expectations = MockNetworkService.Expectations()
    
    // Fail first 3 attempts, succeed on 4th
    expectations.fetchData_url
        .error(NetworkError.timeout).times(3)
        .value(successData)
    
    let mock = MockNetworkService(expectations: expectations)
    let retryService = RetryService(networkService: mock)
    
    // This should eventually succeed after retries
    let result = try await retryService.fetchDataWithRetry(url: testURL)
    #expect(result == successData)
    
    // Verify retry attempts
    let callCount = await mock.__verify.fetchData_url.callCount
    #expect(callCount == 4) // 3 failures + 1 success
}
```

### Timeout Testing

Test timeout behavior:

```swift
@Test func timeout() async {
    let expectations = MockSlowService.Expectations()
    
    expectations.slowOperation.using { _ in
        // Simulate a slow operation
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        return "result"
    }
    
    let mock = MockSlowService(expectations: expectations)
    
    // Test with timeout
    await #expect(throws: TimeoutError.self) {
        try await withTimeout(seconds: 1) {
            await mock.slowOperation()
        }
    }
}
```

### Error Recovery Testing

Test error recovery scenarios:

```swift
@Test func errorRecovery() async throws {
    let expectations = MockDataService.Expectations()
    
    expectations.saveData
        .error(StorageError.diskFull)           // First save fails
        .value(())                              // Recovery save succeeds
    
    expectations.clearCache.value(())           // Cache clearing succeeds
    
    let mock = MockDataService(expectations: expectations)
    let service = DataManager(dataService: mock)
    
    // This should handle the error and recover
    try await service.saveDataWithRecovery(testData)
    
    // Verify recovery was attempted
    let saveCount = await mock.__verify.saveData.callCount
    let clearCount = await mock.__verify.clearCache.callCount
    
    #expect(saveCount == 2)    // Initial attempt + recovery
    #expect(clearCount == 1)   // Cache was cleared for recovery
}
```

## Best Practices

### 1. Match Original Function Signatures

Ensure your expectations match the async/throwing nature of the original functions:

```swift
// If the protocol method is async throws, use async throws in closures
expectations.asyncThrowingMethod.using { param async throws in
    // Implementation
}
```

### 2. Test Both Success and Failure Paths

```swift
// Test success path
expectations.operation.value(successResult)
let result = try await mock.operation()

// Test failure path  
expectations.operation.error(expectedError)
XCTAssertThrowsError(try await mock.operation())
```

### 3. Use Realistic Error Scenarios

```swift
// Good: Realistic error progression
expectations.networkCall
    .error(NetworkError.connectionFailed).times(2)  // Temporary network issues
    .value(partialData)                              // Partial recovery
    .error(NetworkError.timeout)                     // Another issue
    .value(fullData)                                 // Final success

// Avoid: Unrealistic immediate success after setup
```

### 4. Handle Cancellation

Test cancellation behavior with async operations:

```swift
@Test func cancellation() async throws {
    let expectations = MockLongRunningService.Expectations()
    
    expectations.longOperation.using { _ in
        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        return "result"
    }
    
    let mock = MockLongRunningService(expectations: expectations)
    
    let task = Task {
        try await mock.longOperation()
    }
    
    // Cancel after a short delay
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    task.cancel()
    
    await #expect(throws: CancellationError.self) {
        try await task.value
    }
}
```

## Next Steps

- Learn about <doc:AdvancedPatterns> for complex testing scenarios
- Explore <doc:CommonPatterns> for real-world async/throwing examples
- See <doc:BestPractices> for testing strategy recommendations