# Advanced Patterns

Advanced techniques and patterns for complex testing scenarios with Smockable.

## Overview

This guide covers advanced patterns and techniques for using Smockable in complex testing scenarios. These patterns help you handle sophisticated mocking requirements and create more maintainable test suites.

## Protocol Inheritance and Composition

### Testing Protocol Inheritance

Smockable supports protocol inheritance, generating mocks that implement all inherited requirements:

```swift
@Smock
protocol BaseService {
    func connect() async throws
    func disconnect() async throws
    var isConnected: Bool { get }
}

@Smock
protocol DataService: BaseService {
    func fetchData() async throws -> Data
    func saveData(_ data: Data) async throws
}

func testInheritedProtocol() async throws {
    let expectations = MockDataService.Expectations()
    
    // Configure inherited methods
    expectations.connect.success()
    expectations.disconnect.success()
    expectations.isConnected.value(true)
    
    // Configure protocol-specific methods
    expectations.fetchData.value("test data".data(using: .utf8)!)
    expectations.saveData.success()
    
    let mock = MockDataService(expectations: expectations)
    
    // Use both inherited and specific methods
    try await mock.connect()
    let data = try await mock.fetchData()
    try await mock.saveData(data)
    
    // Verify all interactions
    XCTAssertEqual(await mock.__verify.connect.callCount, 1)
    XCTAssertEqual(await mock.__verify.fetchData.callCount, 1)
    XCTAssertEqual(await mock.__verify.saveData.callCount, 1)
}
```

### Protocol Composition

Test services that depend on multiple protocols:

```swift
@Smock
protocol AuthenticationService {
    func authenticate(token: String) async throws -> User
}

@Smock
protocol LoggingService {
    func log(message: String, level: LogLevel) async
}

class SecureDataService {
    private let authService: AuthenticationService
    private let loggingService: LoggingService
    private let dataService: DataService
    
    init(
        authService: AuthenticationService,
        loggingService: LoggingService,
        dataService: DataService
    ) {
        self.authService = authService
        self.loggingService = loggingService
        self.dataService = dataService
    }
    
    func securelyFetchData(token: String) async throws -> Data {
        await loggingService.log(message: "Starting secure data fetch", level: .info)
        
        let user = try await authService.authenticate(token: token)
        await loggingService.log(message: "User authenticated: \(user.id)", level: .info)
        
        let data = try await dataService.fetchData()
        await loggingService.log(message: "Data fetched successfully", level: .info)
        
        return data
    }
}

func testSecureDataService() async throws {
    // Set up all mocks
    let authExpectations = MockAuthenticationService.Expectations()
    let loggingExpectations = MockLoggingService.Expectations()
    let dataExpectations = MockDataService.Expectations()
    
    let testUser = User(id: "123", name: "Test User")
    let testData = "secure data".data(using: .utf8)!
    
    authExpectations.authenticate_token.value(testUser)
    loggingExpectations.log_message_level.success().unboundedTimes()
    dataExpectations.fetchData.value(testData)
    
    let mockAuth = MockAuthenticationService(expectations: authExpectations)
    let mockLogging = MockLoggingService(expectations: loggingExpectations)
    let mockData = MockDataService(expectations: dataExpectations)
    
    let secureService = SecureDataService(
        authService: mockAuth,
        loggingService: mockLogging,
        dataService: mockData
    )
    
    // Test the composed service
    let result = try await secureService.securelyFetchData(token: "valid-token")
    
    XCTAssertEqual(result, testData)
    
    // Verify all services were used correctly
    XCTAssertEqual(await mockAuth.__verify.authenticate_token.callCount, 1)
    XCTAssertEqual(await mockLogging.__verify.log_message_level.callCount, 3)
    XCTAssertEqual(await mockData.__verify.fetchData.callCount, 1)
}
```

## Associated Types Support

### Generic Protocol Mocking

Smockable supports protocols with associated types:

```swift
@Smock
protocol Repository {
    associatedtype Entity: Codable
    associatedtype ID: Hashable
    
    func find(by id: ID) async throws -> Entity?
    func save(_ entity: Entity) async throws
    func delete(id: ID) async throws
}

// Usage with specific types
func testUserRepository() async throws {
    let expectations = MockRepository<User, String>.Expectations()
    
    let testUser = User(id: "123", name: "John Doe")
    expectations.find_by.value(testUser)
    expectations.save.success()
    expectations.delete_id.success()
    
    let mockRepo = MockRepository<User, String>(expectations: expectations)
    
    let foundUser = try await mockRepo.find(by: "123")
    XCTAssertEqual(foundUser?.name, "John Doe")
    
    try await mockRepo.save(testUser)
    try await mockRepo.delete(id: "123")
}
```

### Constrained Associated Types

Handle associated types with constraints:

```swift
@Smock
protocol CacheService {
    associatedtype Key: Hashable
    associatedtype Value: Codable
    
    func get(key: Key) async -> Value?
    func set(key: Key, value: Value) async
    func remove(key: Key) async
}

func testCacheService() async {
    let expectations = MockCacheService<String, UserProfile>.Expectations()
    
    let testProfile = UserProfile(name: "John", preferences: [:])
    
    expectations.get_key
        .value(nil)         // Cache miss
        .value(testProfile) // Cache hit
    
    expectations.set_key_value.success().unboundedTimes()
    expectations.remove_key.success()
    
    let mockCache = MockCacheService<String, UserProfile>(expectations: expectations)
    
    // Test cache miss
    let result1 = await mockCache.get(key: "user-123")
    XCTAssertNil(result1)
    
    // Set value
    await mockCache.set(key: "user-123", value: testProfile)
    
    // Test cache hit
    let result2 = await mockCache.get(key: "user-123")
    XCTAssertEqual(result2?.name, "John")
}
```

## State Management Patterns

### Stateful Mock Behavior

Create mocks that maintain state across calls:

```swift
@Smock
protocol CounterService {
    func increment() async -> Int
    func decrement() async -> Int
    func reset() async
    func getValue() async -> Int
}

func testStatefulCounter() async {
    let expectations = MockCounterService.Expectations()
    
    // Simulate stateful behavior
    var counter = 0
    
    expectations.increment.using { _ in
        counter += 1
        return counter
    }.unboundedTimes()
    
    expectations.decrement.using { _ in
        counter -= 1
        return counter
    }.unboundedTimes()
    
    expectations.reset.using { _ in
        counter = 0
    }.unboundedTimes()
    
    expectations.getValue.using { _ in
        return counter
    }.unboundedTimes()
    
    let mockCounter = MockCounterService(expectations: expectations)
    
    // Test stateful behavior
    let value1 = await mockCounter.increment() // 1
    let value2 = await mockCounter.increment() // 2
    let value3 = await mockCounter.decrement() // 1
    
    XCTAssertEqual(value1, 1)
    XCTAssertEqual(value2, 2)
    XCTAssertEqual(value3, 1)
    
    let currentValue = await mockCounter.getValue()
    XCTAssertEqual(currentValue, 1)
    
    await mockCounter.reset()
    let resetValue = await mockCounter.getValue()
    XCTAssertEqual(resetValue, 0)
}
```

### Session-Based Testing

Test services that maintain session state:

```swift
@Smock
protocol SessionService {
    func startSession(userId: String) async throws -> SessionToken
    func validateSession(token: SessionToken) async -> Bool
    func endSession(token: SessionToken) async
}

func testSessionLifecycle() async throws {
    let expectations = MockSessionService.Expectations()
    
    // Simulate session management
    var activeSessions: Set<String> = []
    
    expectations.startSession_userId.using { userId in
        let token = SessionToken(value: UUID().uuidString, userId: userId)
        activeSessions.insert(token.value)
        return token
    }.unboundedTimes()
    
    expectations.validateSession_token.using { token in
        return activeSessions.contains(token.value)
    }.unboundedTimes()
    
    expectations.endSession_token.using { token in
        activeSessions.remove(token.value)
    }.unboundedTimes()
    
    let mockSession = MockSessionService(expectations: expectations)
    
    // Test session lifecycle
    let token = try await mockSession.startSession(userId: "user-123")
    
    let isValid1 = await mockSession.validateSession(token: token)
    XCTAssertTrue(isValid1)
    
    await mockSession.endSession(token: token)
    
    let isValid2 = await mockSession.validateSession(token: token)
    XCTAssertFalse(isValid2)
}
```

## Complex Interaction Patterns

### Chain of Responsibility Testing

Test patterns where multiple services are called in sequence:

```swift
@Smock
protocol ValidationService {
    func validate(_ data: InputData) async throws -> ValidationResult
}

@Smock
protocol ProcessingService {
    func process(_ data: InputData) async throws -> ProcessedData
}

@Smock
protocol StorageService {
    func store(_ data: ProcessedData) async throws -> StorageResult
}

class DataPipeline {
    private let validator: ValidationService
    private let processor: ProcessingService
    private let storage: StorageService
    
    init(
        validator: ValidationService,
        processor: ProcessingService,
        storage: StorageService
    ) {
        self.validator = validator
        self.processor = processor
        self.storage = storage
    }
    
    func processData(_ input: InputData) async throws -> PipelineResult {
        let validationResult = try await validator.validate(input)
        guard validationResult.isValid else {
            throw PipelineError.validationFailed(validationResult.errors)
        }
        
        let processedData = try await processor.process(input)
        let storageResult = try await storage.store(processedData)
        
        return PipelineResult(
            processed: processedData,
            stored: storageResult
        )
    }
}

func testDataPipeline_SuccessfulFlow() async throws {
    // Set up all mocks
    let validationExpectations = MockValidationService.Expectations()
    let processingExpectations = MockProcessingService.Expectations()
    let storageExpectations = MockStorageService.Expectations()
    
    let inputData = InputData(content: "test data")
    let validationResult = ValidationResult(isValid: true, errors: [])
    let processedData = ProcessedData(content: "processed test data")
    let storageResult = StorageResult(id: "stored-123", location: "/data/stored-123")
    
    validationExpectations.validate.value(validationResult)
    processingExpectations.process.value(processedData)
    storageExpectations.store.value(storageResult)
    
    let mockValidator = MockValidationService(expectations: validationExpectations)
    let mockProcessor = MockProcessingService(expectations: processingExpectations)
    let mockStorage = MockStorageService(expectations: storageExpectations)
    
    let pipeline = DataPipeline(
        validator: mockValidator,
        processor: mockProcessor,
        storage: mockStorage
    )
    
    // Test the pipeline
    let result = try await pipeline.processData(inputData)
    
    XCTAssertEqual(result.stored.id, "stored-123")
    
    // Verify the chain of calls
    XCTAssertEqual(await mockValidator.__verify.validate.callCount, 1)
    XCTAssertEqual(await mockProcessor.__verify.process.callCount, 1)
    XCTAssertEqual(await mockStorage.__verify.store.callCount, 1)
    
    // Verify call order by checking inputs
    let validationInputs = await mockValidator.__verify.validate.receivedInputs
    let processingInputs = await mockProcessor.__verify.process.receivedInputs
    
    XCTAssertEqual(validationInputs[0].content, "test data")
    XCTAssertEqual(processingInputs[0].content, "test data")
}
```

### Event-Driven Architecture Testing

Test event-driven systems with multiple subscribers:

```swift
@Smock
protocol EventPublisher {
    func publish<T: Event>(_ event: T) async
    func subscribe<T: Event>(to eventType: T.Type, handler: @escaping (T) async -> Void) async
}

@Smock
protocol EventHandler {
    func handle(_ event: UserCreatedEvent) async
    func handle(_ event: UserUpdatedEvent) async
    func handle(_ event: UserDeletedEvent) async
}

func testEventDrivenSystem() async {
    let publisherExpectations = MockEventPublisher.Expectations()
    let handlerExpectations = MockEventHandler.Expectations()
    
    // Track published events
    var publishedEvents: [Any] = []
    
    publisherExpectations.publish.using { event in
        publishedEvents.append(event)
    }.unboundedTimes()
    
    publisherExpectations.subscribe_to_handler.success().unboundedTimes()
    
    handlerExpectations.handle_UserCreatedEvent.success().unboundedTimes()
    handlerExpectations.handle_UserUpdatedEvent.success().unboundedTimes()
    handlerExpectations.handle_UserDeletedEvent.success().unboundedTimes()
    
    let mockPublisher = MockEventPublisher(expectations: publisherExpectations)
    let mockHandler = MockEventHandler(expectations: handlerExpectations)
    
    let eventSystem = EventDrivenUserService(
        publisher: mockPublisher,
        handler: mockHandler
    )
    
    // Test event publishing
    let user = User(id: "123", name: "John Doe")
    await eventSystem.createUser(user)
    await eventSystem.updateUser(user)
    await eventSystem.deleteUser(id: "123")
    
    // Verify events were published
    XCTAssertEqual(publishedEvents.count, 3)
    XCTAssertTrue(publishedEvents[0] is UserCreatedEvent)
    XCTAssertTrue(publishedEvents[1] is UserUpdatedEvent)
    XCTAssertTrue(publishedEvents[2] is UserDeletedEvent)
}
```

## Performance Testing Patterns

### Load Testing with Mocks

Test system behavior under load:

```swift
@Smock
protocol LoadTestService {
    func processRequest(id: String) async throws -> ProcessingResult
}

func testHighLoadScenario() async throws {
    let expectations = MockLoadTestService.Expectations()
    
    // Simulate varying response times
    expectations.processRequest_id.using { id in
        let requestNumber = Int(id.suffix(3)) ?? 0
        
        // Simulate slower responses as load increases
        let delay = min(requestNumber * 1_000_000, 100_000_000) // Max 0.1 seconds
        try await Task.sleep(nanoseconds: UInt64(delay))
        
        return ProcessingResult(id: id, processingTime: delay)
    }.unboundedTimes()
    
    let mockService = MockLoadTestService(expectations: expectations)
    
    let startTime = Date()
    
    // Simulate concurrent load
    await withTaskGroup(of: ProcessingResult?.self) { group in
        for i in 0..<100 {
            group.addTask {
                do {
                    return try await mockService.processRequest(id: String(format: "req-%03d", i))
                } catch {
                    return nil
                }
            }
        }
        
        var results: [ProcessingResult] = []
        for await result in group {
            if let result = result {
                results.append(result)
            }
        }
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        XCTAssertEqual(results.count, 100)
        XCTAssertLessThan(totalTime, 5.0) // Should complete within 5 seconds
    }
    
    let callCount = await mockService.__verify.processRequest_id.callCount
    XCTAssertEqual(callCount, 100)
}
```

### Memory Usage Testing

Test memory-intensive operations:

```swift
@Smock
protocol DataProcessingService {
    func processLargeDataset(_ data: [DataPoint]) async throws -> ProcessingResult
}

func testLargeDatasetProcessing() async throws {
    let expectations = MockDataProcessingService.Expectations()
    
    expectations.processLargeDataset.using { dataPoints in
        // Simulate memory-intensive processing
        let processedCount = dataPoints.count
        let memoryUsage = processedCount * 1024 // Simulate memory usage
        
        return ProcessingResult(
            processedItems: processedCount,
            memoryUsed: memoryUsage,
            processingTime: TimeInterval(processedCount) / 1000.0
        )
    }
    
    let mockService = MockDataProcessingService(expectations: expectations)
    
    // Create large dataset
    let largeDataset = (0..<10000).map { DataPoint(id: $0, value: Double($0)) }
    
    let result = try await mockService.processLargeDataset(largeDataset)
    
    XCTAssertEqual(result.processedItems, 10000)
    XCTAssertGreaterThan(result.memoryUsed, 0)
}
```

## Integration Testing Patterns

### Multi-Service Integration

Test integration between multiple services:

```swift
class IntegrationTestSuite: XCTestCase {
    var mockUserService: MockUserService!
    var mockNotificationService: MockNotificationService!
    var mockAuditService: MockAuditService!
    var systemUnderTest: UserManagementSystem!
    
    override func setUp() {
        super.setUp()
        setupMocks()
        systemUnderTest = UserManagementSystem(
            userService: mockUserService,
            notificationService: mockNotificationService,
            auditService: mockAuditService
        )
    }
    
    private func setupMocks() {
        let userExpectations = MockUserService.Expectations()
        let notificationExpectations = MockNotificationService.Expectations()
        let auditExpectations = MockAuditService.Expectations()
        
        // Configure cross-service interactions
        userExpectations.createUser.value(User.testUser())
        notificationExpectations.sendWelcomeEmail.success()
        auditExpectations.logUserAction.success().unboundedTimes()
        
        mockUserService = MockUserService(expectations: userExpectations)
        mockNotificationService = MockNotificationService(expectations: notificationExpectations)
        mockAuditService = MockAuditService(expectations: auditExpectations)
    }
    
    func testUserCreationFlow() async throws {
        let userData = UserCreationData(name: "John Doe", email: "john@example.com")
        
        let createdUser = try await systemUnderTest.createUserWithNotification(userData)
        
        // Verify integration flow
        XCTAssertEqual(await mockUserService.__verify.createUser.callCount, 1)
        XCTAssertEqual(await mockNotificationService.__verify.sendWelcomeEmail.callCount, 1)
        XCTAssertEqual(await mockAuditService.__verify.logUserAction.callCount, 2) // Create + notification
        
        // Verify data flow between services
        let notificationInputs = await mockNotificationService.__verify.sendWelcomeEmail.receivedInputs
        XCTAssertEqual(notificationInputs[0].userEmail, "john@example.com")
    }
}
```

## Next Steps

- Explore <doc:BestPractices> for testing strategy recommendations
- See <doc:TestingStrategies> for comprehensive testing approaches
