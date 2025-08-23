# Best Practices

Guidelines and recommendations for effective testing with Smockable.

## Overview

This guide provides best practices for using Smockable effectively in your test suite. Following these guidelines will help you write maintainable, reliable, and expressive tests.

## Test Organization

### 1. Structure Your Test Classes

Organize tests by the component being tested, not by the mock being used:

```swift
// Good: Organized by component
class UserServiceTests: XCTestCase {
    var mockRepository: MockUserRepository!
    var mockNotificationService: MockNotificationService!
    var userService: UserService!
    
    override func setUp() {
        super.setUp()
        setupMocks()
        userService = UserService(
            repository: mockRepository,
            notificationService: mockNotificationService
        )
    }
    
    private func setupMocks() {
        let repoExpectations = MockUserRepository.Expectations()
        let notificationExpectations = MockNotificationService.Expectations()
        
        mockRepository = MockUserRepository(expectations: repoExpectations)
        mockNotificationService = MockNotificationService(expectations: notificationExpectations)
    }
}

// Avoid: Organizing by mock type
class MockUserRepositoryTests: XCTestCase { /* ... */ }
```

### 2. Use Descriptive Test Names

Test names should clearly describe the scenario and expected outcome:

```swift
// Good: Clear, descriptive names
func testFetchUser_WhenUserExists_ReturnsUser() async throws { }
func testFetchUser_WhenUserNotFound_ThrowsNotFoundError() async throws { }
func testCreateUser_WhenValidData_SavesUserAndSendsWelcomeEmail() async throws { }

// Avoid: Vague or technical names
func testFetchUser() async throws { }
func testMockReturnsValue() async throws { }
```

### 3. Group Related Tests

Use nested test classes or test suites for related scenarios:

```swift
class UserServiceTests: XCTestCase {
    // Common setup
    
    class UserCreationTests: UserServiceTests {
        func testCreateUser_WithValidData_Succeeds() async throws { }
        func testCreateUser_WithInvalidEmail_ThrowsValidationError() async throws { }
        func testCreateUser_WhenRepositoryFails_PropagatesError() async throws { }
    }
    
    class UserRetrievalTests: UserServiceTests {
        func testFetchUser_WhenExists_ReturnsUser() async throws { }
        func testFetchUser_WhenNotFound_ReturnsNil() async throws { }
    }
}
```

## Mock Configuration

### 1. Set Up Expectations Before Mock Creation

Always configure all expectations before creating the mock:

```swift
// Good: All expectations set up first
func testUserService() async throws {
    let expectations = MockUserRepository.Expectations()
    expectations.findUser_by.value(testUser)
    expectations.saveUser.value(())
    expectations.deleteUser_id.value(())
    
    let mock = MockUserRepository(expectations: expectations)
    let service = UserService(repository: mock)
    
    // Use service and verify
}

// Avoid: Trying to modify expectations after mock creation
func testUserService() async throws {
    let expectations = MockUserRepository.Expectations()
    let mock = MockUserRepository(expectations: expectations)
    
    // This won't work - expectations are consumed during mock creation
    expectations.findUser_by.value(testUser) // ❌
}
```

### 2. Use Specific Expectations

Be specific about expected behavior rather than using catch-all patterns:

```swift
// Good: Specific expectations for each scenario
expectations.fetchUser_id
    .value(user1)                           // First call
    .error(NetworkError.timeout)            // Second call
    .value(user2)                           // Third call

// Avoid: Overly broad expectations
expectations.fetchUser_id.using { _ in
    // Complex logic that could hide test intent
    return someComplexLogic()
}.unboundedTimes()
```

### 3. Make Test Data Meaningful

Use realistic test data that reflects actual usage:

```swift
// Good: Realistic test data
let testUser = User(
    id: "user-12345",
    name: "Alice Johnson",
    email: "alice.johnson@example.com",
    role: .standardUser,
    createdAt: Date()
)

// Avoid: Meaningless test data
let testUser = User(id: "1", name: "a", email: "b", role: .standardUser, createdAt: Date())
```

## Verification Strategies

### 1. Verify Both Behavior and State

Check both that methods were called and that they were called correctly:

```swift
func testUserCreation() async throws {
    // Setup and execution
    try await userService.createUser(name: "John", email: "john@example.com")
    
    // Verify behavior (method was called)
    let saveCount = await mockRepository.__verify.saveUser.callCount
    XCTAssertEqual(saveCount, 1)
    
    // Verify state (method was called with correct parameters)
    let saveInputs = await mockRepository.__verify.saveUser.receivedInputs
    XCTAssertEqual(saveInputs[0].name, "John")
    XCTAssertEqual(saveInputs[0].email, "john@example.com")
}
```

### 2. Use Helper Methods for Complex Verification

Create reusable verification helpers:

```swift
extension MockUserRepository {
    func verifyUserSaved(withName name: String, email: String) async -> Bool {
        let inputs = await self.__verify.saveUser.receivedInputs
        return inputs.contains { $0.name == name && $0.email == email }
    }
    
    func verifyNoDeletesCalled() async -> Bool {
        let count = await self.__verify.deleteUser_id.callCount
        return count == 0
    }
}

// Usage in tests
XCTAssertTrue(await mockRepository.verifyUserSaved(withName: "John", email: "john@example.com"))
XCTAssertTrue(await mockRepository.verifyNoDeletesCalled())
```

### 3. Verify Negative Cases

Test that unwanted interactions don't occur:

```swift
func testReadOnlyOperation_DoesNotModifyData() async throws {
    // Perform read-only operation
    let users = try await userService.getAllUsers()
    
    // Verify no modifications were made
    let saveCount = await mockRepository.__verify.saveUser.callCount
    let deleteCount = await mockRepository.__verify.deleteUser_id.callCount
    
    XCTAssertEqual(saveCount, 0, "Read-only operation should not save users")
    XCTAssertEqual(deleteCount, 0, "Read-only operation should not delete users")
}
```

## Error Testing

### 1. Test All Error Paths

Ensure you test both happy path and error scenarios:

```swift
class UserServiceErrorTests: XCTestCase {
    func testCreateUser_WhenRepositoryThrowsError_PropagatesError() async {
        let expectations = MockUserRepository.Expectations()
        expectations.saveUser.error(DatabaseError.connectionFailed)
        
        let mock = MockUserRepository(expectations: expectations)
        let service = UserService(repository: mock)
        
        do {
            try await service.createUser(name: "John", email: "john@example.com")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is DatabaseError)
        }
    }
    
    func testCreateUser_WhenValidationFails_ThrowsValidationError() async {
        // Test validation error scenarios
    }
}
```

### 2. Use Specific Error Types

Test with specific error types rather than generic errors:

```swift
// Good: Specific error types
expectations.fetchUser_id.error(UserRepositoryError.userNotFound)
expectations.saveUser.error(UserRepositoryError.duplicateEmail)

// Avoid: Generic errors
expectations.fetchUser_id.error(NSError(domain: "test", code: 1))
```

### 3. Test Error Recovery

Test how your code handles and recovers from errors:

```swift
func testCreateUser_WhenFirstAttemptFails_RetriesSuccessfully() async throws {
    let expectations = MockUserRepository.Expectations()
    expectations.saveUser
        .error(DatabaseError.temporaryFailure)  // First attempt fails
        .value(())                              // Retry succeeds
    
    let mock = MockUserRepository(expectations: expectations)
    let service = UserServiceWithRetry(repository: mock)
    
    // Should succeed after retry
    try await service.createUser(name: "John", email: "john@example.com")
    
    // Verify retry occurred
    let saveCount = await mock.__verify.saveUser.callCount
    XCTAssertEqual(saveCount, 2)
}
```

## Async Testing Patterns

### 1. Use Proper Async Test Structure

Structure async tests clearly:

```swift
func testAsyncOperation() async throws {
    // Setup
    let expectations = MockService.Expectations()
    expectations.asyncMethod.value(expectedResult)
    let mock = MockService(expectations: expectations)
    
    // Execute
    let result = try await systemUnderTest.performAsyncOperation(using: mock)
    
    // Verify
    XCTAssertEqual(result, expectedResult)
    let callCount = await mock.__verify.asyncMethod.callCount
    XCTAssertEqual(callCount, 1)
}
```

### 2. Test Concurrent Operations

Test concurrent access patterns:

```swift
func testConcurrentOperations() async throws {
    let expectations = MockService.Expectations()
    expectations.threadSafeMethod.value(result).unboundedTimes()
    let mock = MockService(expectations: expectations)
    
    // Execute concurrent operations
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<10 {
            group.addTask {
                try? await systemUnderTest.performOperation(id: "\(i)", using: mock)
            }
        }
    }
    
    // Verify all operations completed
    let callCount = await mock.__verify.threadSafeMethod.callCount
    XCTAssertEqual(callCount, 10)
}
```

### 3. Handle Timeouts Appropriately

Set reasonable timeouts for async operations:

```swift
func testLongRunningOperation() async throws {
    let expectations = MockService.Expectations()
    expectations.slowMethod.using { _ in
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        return result
    }
    
    let mock = MockService(expectations: expectations)
    
    // Use timeout to prevent hanging tests
    let result = try await withTimeout(seconds: 5) {
        try await systemUnderTest.performSlowOperation(using: mock)
    }
    
    XCTAssertEqual(result, expectedResult)
}
```

## Test Data Management

### 1. Use Factory Methods

Create factory methods for consistent test data:

```swift
extension User {
    static func testUser(
        id: String = UUID().uuidString,
        name: String = "Test User",
        email: String = "test@example.com",
        role: UserRole = .standardUser
    ) -> User {
        return User(id: id, name: name, email: email, role: role)
    }
    
    static func adminUser() -> User {
        return testUser(name: "Admin User", email: "admin@example.com", role: .admin)
    }
}
```

### 2. Create Test Builders

Use builder patterns for complex test objects:

```swift
class UserBuilder {
    private var user = User.testUser()
    
    func withId(_ id: String) -> UserBuilder {
        user.id = id
        return self
    }
    
    func withName(_ name: String) -> UserBuilder {
        user.name = name
        return self
    }
    
    func withEmail(_ email: String) -> UserBuilder {
        user.email = email
        return self
    }
    
    func build() -> User {
        return user
    }
}

// Usage
let testUser = UserBuilder()
    .withName("John Doe")
    .withEmail("john@example.com")
    .build()
```

### 3. Isolate Test Data

Keep test data isolated between tests:

```swift
class UserServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Reset any shared state
        TestDataManager.reset()
    }
    
    override func tearDown() {
        // Clean up test data
        TestDataManager.cleanup()
        super.tearDown()
    }
}
```

## Performance Considerations

### 1. Minimize Mock Complexity

Keep mock expectations simple and focused:

```swift
// Good: Simple, focused expectations
expectations.fetchUser_id.value(testUser)
expectations.saveUser.value(())

// Avoid: Overly complex mock logic
expectations.fetchUser_id.using { id in
    // Complex database simulation logic
    let database = InMemoryDatabase()
    database.setup()
    return database.query(id: id)
}
```

### 2. Reuse Mock Configurations

Create reusable mock configurations for common scenarios:

```swift
extension MockUserRepository {
    static func withStandardBehavior() -> MockUserRepository {
        let expectations = Expectations()
        expectations.findUser_by.value(User.testUser())
        expectations.saveUser.value(())
        expectations.deleteUser_id.value(())
        return MockUserRepository(expectations: expectations)
    }
    
    static func withNetworkErrors() -> MockUserRepository {
        let expectations = Expectations()
        expectations.findUser_by.error(NetworkError.connectionFailed)
        expectations.saveUser.error(NetworkError.timeout)
        return MockUserRepository(expectations: expectations)
    }
}
```

### 3. Use Appropriate Test Scope

Don't over-test with mocks:

```swift
// Good: Test the component's behavior
func testUserService_CreatesUserAndSendsNotification() async throws {
    // Test that UserService coordinates between repository and notification service
}

// Avoid: Testing mock implementation details
func testMockRepository_ReturnsExpectedValue() async throws {
    // This tests the mock, not your code
}
```

## Common Pitfalls

### 1. Over-Mocking

Don't mock everything - focus on external dependencies:

```swift
// Good: Mock external dependencies
class UserService {
    let repository: UserRepository        // Mock this
    let notificationService: NotificationService  // Mock this
    let validator: UserValidator         // Don't mock - test with real validator
}
```

### 2. Brittle Tests

Avoid tests that break with minor implementation changes:

```swift
// Brittle: Tests implementation details
func testUserService_CallsRepositoryExactlyOnce() async throws {
    // This test breaks if implementation changes to call repository twice
}

// Better: Test behavior
func testUserService_CreatesUserSuccessfully() async throws {
    // This test focuses on the outcome, not the implementation
}
```

### 3. Unclear Test Intent

Make test intent clear through naming and structure:

```swift
// Clear intent
func testCreateUser_WhenEmailAlreadyExists_ThrowsDuplicateEmailError() async {
    // Given
    let existingUser = User.testUser(email: "existing@example.com")
    let expectations = MockUserRepository.Expectations()
    expectations.findUser_by_email.value(existingUser)
    
    // When & Then
    do {
        try await userService.createUser(name: "New User", email: "existing@example.com")
        XCTFail("Expected duplicate email error")
    } catch UserServiceError.duplicateEmail {
        // Expected error
    } catch {
        XCTFail("Unexpected error: \(error)")
    }
}
```

## Next Steps

- Review <doc:CommonPatterns> for practical examples
- Explore <doc:TestingStrategies> for comprehensive testing approaches
- See <doc:AdvancedPatterns> for complex testing scenarios