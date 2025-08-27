# Testing Strategies

Comprehensive testing strategies and methodologies using Smockable.

## Overview

This guide outlines different testing strategies and methodologies you can employ with Smockable to create robust, maintainable test suites. We'll cover various testing approaches and when to use each one.

## Unit Testing Strategy

### Isolated Component Testing

Test individual components in complete isolation:

```swift
class UserServiceUnitTests: XCTestCase {
    var mockRepository: MockUserRepository!
    var mockValidator: MockUserValidator!
    var mockNotificationService: MockNotificationService!
    var userService: UserService!
    
    override func setUp() {
        super.setUp()
        setupMocks()
        userService = UserService(
            repository: mockRepository,
            validator: mockValidator,
            notificationService: mockNotificationService
        )
    }
    
    private func setupMocks() {
        let repoExpectations = MockUserRepository.Expectations()
        let validatorExpectations = MockUserValidator.Expectations()
        let notificationExpectations = MockNotificationService.Expectations()
        
        mockRepository = MockUserRepository(expectations: repoExpectations)
        mockValidator = MockUserValidator(expectations: validatorExpectations)
        mockNotificationService = MockNotificationService(expectations: notificationExpectations)
    }
    
    func testCreateUser_WithValidData_CreatesUserSuccessfully() async throws {
        // Given
        let userData = UserData(name: "John Doe", email: "john@example.com")
        let expectedUser = User(id: "123", name: "John Doe", email: "john@example.com")
        
        mockValidator.expectations.validate.value(ValidationResult.valid)
        mockRepository.expectations.save.value(expectedUser)
        mockNotificationService.expectations.sendWelcomeEmail.success()
        
        // When
        let result = try await userService.createUser(userData)
        
        // Then
        XCTAssertEqual(result.name, "John Doe")
        XCTAssertEqual(await mockValidator.__verify.validate.callCount, 1)
        XCTAssertEqual(await mockRepository.__verify.save.callCount, 1)
        XCTAssertEqual(await mockNotificationService.__verify.sendWelcomeEmail.callCount, 1)
    }
}
```

### Behavior-Driven Testing

Structure tests around behaviors and scenarios:

```swift
class UserServiceBehaviorTests: XCTestCase {
    
    // MARK: - User Creation Behaviors
    
    func testCreateUser_GivenValidUserData_ShouldCreateUserAndSendWelcomeEmail() async throws {
        // Given valid user data
        let userData = UserData.valid()
        let mockSetup = MockSetup()
            .withSuccessfulValidation()
            .withSuccessfulUserCreation()
            .withSuccessfulEmailSending()
        
        let userService = UserService(dependencies: mockSetup.dependencies)
        
        // When creating a user
        let result = try await userService.createUser(userData)
        
        // Then user should be created and welcome email sent
        XCTAssertNotNil(result)
        await mockSetup.verifyUserCreationFlow()
    }
    
    func testCreateUser_GivenInvalidEmail_ShouldThrowValidationError() async {
        // Given invalid email data
        let userData = UserData.withInvalidEmail()
        let mockSetup = MockSetup()
            .withValidationError(.invalidEmail)
        
        let userService = UserService(dependencies: mockSetup.dependencies)
        
        // When creating a user
        // Then should throw validation error
        await XCTAssertThrowsError(try await userService.createUser(userData)) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
}
```

## Integration Testing Strategy

### Service Layer Integration

Test how multiple services work together:

```swift
class ServiceIntegrationTests: XCTestCase {
    
    func testUserRegistrationFlow_IntegratesAllServices() async throws {
        // Setup: Mock external dependencies but test service integration
        let mockEmailService = MockEmailService.withSuccessfulSending()
        let mockPaymentService = MockPaymentService.withSuccessfulProcessing()
        let mockAuditService = MockAuditService.withSuccessfulLogging()
        
        // Real services that integrate with each other
        let userService = RealUserService(emailService: mockEmailService)
        let subscriptionService = RealSubscriptionService(
            userService: userService,
            paymentService: mockPaymentService
        )
        let registrationService = RealRegistrationService(
            userService: userService,
            subscriptionService: subscriptionService,
            auditService: mockAuditService
        )
        
        // Test the integrated flow
        let registrationData = RegistrationData.premium()
        let result = try await registrationService.registerUser(registrationData)
        
        // Verify integration points
        XCTAssertNotNil(result.user)
        XCTAssertNotNil(result.subscription)
        
        // Verify external service calls
        await mockEmailService.verifyWelcomeEmailSent()
        await mockPaymentService.verifyPaymentProcessed()
        await mockAuditService.verifyRegistrationLogged()
    }
}
```

## Contract Testing Strategy

### API Contract Testing

Ensure your mocks match real API contracts:

```swift
protocol APIContract {
    func fetchUser(id: String) async throws -> User
    func createUser(_ user: CreateUserRequest) async throws -> User
}

class APIContractTests: XCTestCase {
    
    func testMockMatchesRealAPIContract() async throws {
        // Test that mock behavior matches real API
        let mockExpectations = MockAPIService.Expectations()
        mockExpectations.fetchUser_id.value(User.testUser())
        mockExpectations.createUser.value(User.testUser())
        
        let mockAPI = MockAPIService(expectations: mockExpectations)
        
        // Test contract compliance
        let user = try await mockAPI.fetchUser(id: "123")
        XCTAssertNotNil(user)
        
        let createRequest = CreateUserRequest(name: "John", email: "john@example.com")
        let createdUser = try await mockAPI.createUser(createRequest)
        XCTAssertNotNil(createdUser)
    }
    
    func testMockErrorsMatchAPIErrors() async {
        let mockExpectations = MockAPIService.Expectations()
        mockExpectations.fetchUser_id.error(APIError.userNotFound)
        
        let mockAPI = MockAPIService(expectations: mockExpectations)
        
        do {
            _ = try await mockAPI.fetchUser(id: "nonexistent")
            XCTFail("Expected error")
        } catch let error as APIError {
            XCTAssertEqual(error, .userNotFound)
        }
    }
}
```

## Performance Testing Strategy

### Load Testing with Controlled Scenarios

```swift
class PerformanceTestingStrategy: XCTestCase {
    
    func testServicePerformanceUnderLoad() async throws {
        let expectations = MockDataService.Expectations()
        
        // Simulate realistic response times
        expectations.processData.using { data in
            let processingTime = min(data.size * 10, 1000) // Max 1 second
            try await Task.sleep(nanoseconds: UInt64(processingTime * 1_000_000))
            return ProcessedData(from: data)
        }.unboundedTimes()
        
        let mockService = MockDataService(expectations: expectations)
        let systemUnderTest = DataProcessor(service: mockService)
        
        // Measure performance under load
        let startTime = Date()
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let data = TestData.create(size: i * 10)
                    try? await systemUnderTest.process(data)
                }
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Verify performance characteristics
        XCTAssertLessThan(duration, 5.0, "Processing should complete within 5 seconds")
        
        let callCount = await mockService.__verify.processData.callCount
        XCTAssertEqual(callCount, 100)
    }
}
```

## Error Handling Strategy

### Comprehensive Error Scenario Testing

```swift
class ErrorHandlingStrategy: XCTestCase {
    
    func testErrorRecoveryScenarios() async throws {
        let expectations = MockNetworkService.Expectations()
        
        // Test various error scenarios
        expectations.makeRequest_url
            .error(NetworkError.connectionTimeout).times(2)  // Transient errors
            .error(NetworkError.serverError(500))            // Server error
            .value(SuccessResponse.default())                // Recovery
        
        let mockNetwork = MockNetworkService(expectations: expectations)
        let resilientService = ResilientAPIService(networkService: mockNetwork)
        
        // Test error recovery
        let result = try await resilientService.fetchDataWithRetry(url: testURL)
        
        XCTAssertNotNil(result)
        
        // Verify retry attempts
        let callCount = await mockNetwork.__verify.makeRequest_url.callCount
        XCTAssertEqual(callCount, 4) // 3 failures + 1 success
    }
    
    func testCascadingErrorHandling() async {
        // Test how errors propagate through system layers
        let dbExpectations = MockDatabaseService.Expectations()
        let cacheExpectations = MockCacheService.Expectations()
        
        dbExpectations.query.error(DatabaseError.connectionLost)
        cacheExpectations.get.value(nil) // Cache miss
        cacheExpectations.set.error(CacheError.memoryFull)
        
        let mockDB = MockDatabaseService(expectations: dbExpectations)
        let mockCache = MockCacheService(expectations: cacheExpectations)
        
        let dataService = DataService(database: mockDB, cache: mockCache)
        
        do {
            _ = try await dataService.getData(id: "123")
            XCTFail("Expected cascading error")
        } catch {
            // Verify error handling chain
            XCTAssertTrue(error is DataServiceError)
        }
    }
}
```

## State-Based Testing Strategy

### Testing Stateful Interactions

```swift
class StatefulTestingStrategy: XCTestCase {
    
    func testStatefulServiceInteractions() async throws {
        let expectations = MockSessionService.Expectations()
        
        // Model session state
        var sessionState: SessionState = .inactive
        var sessionData: [String: Any] = [:]
        
        expectations.startSession.using { userId in
            sessionState = .active
            sessionData["userId"] = userId
            sessionData["startTime"] = Date()
            return SessionToken.generate()
        }
        
        expectations.getSessionData.using { key in
            guard sessionState == .active else {
                throw SessionError.sessionInactive
            }
            return sessionData[key]
        }.unboundedTimes()
        
        expectations.endSession.using { _ in
            sessionState = .inactive
            sessionData.removeAll()
        }
        
        let mockSession = MockSessionService(expectations: expectations)
        let userSession = UserSessionManager(sessionService: mockSession)
        
        // Test stateful behavior
        try await userSession.login(userId: "user123")
        
        let userData = try await userSession.getUserData(key: "userId")
        XCTAssertEqual(userData as? String, "user123")
        
        await userSession.logout()
        
        // Verify state transition
        do {
            _ = try await userSession.getUserData(key: "userId")
            XCTFail("Expected session inactive error")
        } catch SessionError.sessionInactive {
            // Expected
        }
    }
}
```

## Next Steps

- Apply these strategies to your specific testing scenarios
- Combine multiple strategies for comprehensive test coverage
- Review <doc:BestPractices> for implementation guidelines
