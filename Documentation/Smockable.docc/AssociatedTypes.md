# Associated Types

Working with protocols that have associated types in Smockable.

## Overview

Smockable supports protocols with associated types, allowing you to create generic mocks that work with different concrete types. This enables testing of generic protocols and type-safe mock implementations.

## Basic Associated Types

### Simple Associated Type

```swift
@Smock
protocol Repository {
    associatedtype Entity
    
    func save(_ entity: Entity) async throws
    func find(id: String) async throws -> Entity?
    func delete(id: String) async throws
}

// Usage with specific type
func testUserRepository() async throws {
    let expectations = MockRepository<User>.Expectations()
    
    let testUser = User(id: "123", name: "John Doe")
    expectations.save.success()
    expectations.find_id.value(testUser)
    expectations.delete_id.success()
    
    let mockRepo = MockRepository<User>(expectations: expectations)
    
    try await mockRepo.save(testUser)
    let foundUser = try await mockRepo.find(id: "123")
    try await mockRepo.delete(id: "123")
    
    XCTAssertEqual(foundUser?.name, "John Doe")
}
```

### Multiple Associated Types

```swift
@Smock
protocol KeyValueStore {
    associatedtype Key: Hashable
    associatedtype Value: Codable
    
    func set(key: Key, value: Value) async throws
    func get(key: Key) async throws -> Value?
    func remove(key: Key) async throws
    func keys() async throws -> [Key]
}

func testStringIntStore() async throws {
    let expectations = MockKeyValueStore<String, Int>.Expectations()
    
    expectations.set_key_value.value(()).unboundedTimes()
    expectations.get_key.using { key in
        switch key {
        case "count": return 42
        case "total": return 100
        default: return nil
        }
    }.unboundedTimes()
    expectations.remove_key.success()
    expectations.keys.value(["count", "total"])
    
    let mockStore = MockKeyValueStore<String, Int>(expectations: expectations)
    
    try await mockStore.set(key: "count", value: 42)
    try await mockStore.set(key: "total", value: 100)
    
    let count = try await mockStore.get(key: "count")
    let total = try await mockStore.get(key: "total")
    let missing = try await mockStore.get(key: "missing")
    
    XCTAssertEqual(count, 42)
    XCTAssertEqual(total, 100)
    XCTAssertNil(missing)
    
    let allKeys = try await mockStore.keys()
    XCTAssertEqual(Set(allKeys), Set(["count", "total"]))
}
```

## Constrained Associated Types

### Type Constraints

```swift
@Smock
protocol Serializer {
    associatedtype Input: Codable
    associatedtype Output: Codable
    
    func serialize(_ input: Input) async throws -> Output
    func deserialize(_ output: Output) async throws -> Input
}

// Example with specific constrained types
struct UserData: Codable {
    let id: String
    let name: String
}

struct SerializedUserData: Codable {
    let data: Data
    let timestamp: Date
}

func testUserDataSerializer() async throws {
    let expectations = MockSerializer<UserData, SerializedUserData>.Expectations()
    
    let userData = UserData(id: "123", name: "John")
    let serializedData = SerializedUserData(
        data: try JSONEncoder().encode(userData),
        timestamp: Date()
    )
    
    expectations.serialize.value(serializedData)
    expectations.deserialize.value(userData)
    
    let mockSerializer = MockSerializer<UserData, SerializedUserData>(expectations: expectations)
    
    let serialized = try await mockSerializer.serialize(userData)
    let deserialized = try await mockSerializer.deserialize(serialized)
    
    XCTAssertEqual(deserialized.name, "John")
}
```

### Protocol Constraints

```swift
@Smock
protocol EventHandler {
    associatedtype Event: EventProtocol
    
    func handle(_ event: Event) async throws
    func canHandle(_ eventType: Event.Type) -> Bool
}

protocol EventProtocol {
    var timestamp: Date { get }
    var eventId: String { get }
}

struct UserCreatedEvent: EventProtocol {
    let timestamp: Date
    let eventId: String
    let userId: String
    let userName: String
}

func testUserEventHandler() async throws {
    let expectations = MockEventHandler<UserCreatedEvent>.Expectations()
    
    expectations.handle.success()
    expectations.canHandle.value(true)
    
    let mockHandler = MockEventHandler<UserCreatedEvent>(expectations: expectations)
    
    let event = UserCreatedEvent(
        timestamp: Date(),
        eventId: "event-123",
        userId: "user-456",
        userName: "John Doe"
    )
    
    let canHandle = mockHandler.canHandle(UserCreatedEvent.self)
    XCTAssertTrue(canHandle)
    
    try await mockHandler.handle(event)
    
    let handleCount = await mockHandler.__verify.handle.callCount
    XCTAssertEqual(handleCount, 1)
}
```

## Generic Protocol Inheritance

### Inheriting from Generic Protocols

```swift
@Smock
protocol BaseRepository {
    associatedtype Entity
    
    func save(_ entity: Entity) async throws
    func find(id: String) async throws -> Entity?
}

@Smock
protocol AuditableRepository: BaseRepository {
    associatedtype AuditLog
    
    func saveWithAudit(_ entity: Entity, audit: AuditLog) async throws
    func getAuditLog(for id: String) async throws -> [AuditLog]
}

struct User: Codable {
    let id: String
    let name: String
}

struct UserAuditLog: Codable {
    let action: String
    let timestamp: Date
    let userId: String
}

func testAuditableUserRepository() async throws {
    let expectations = MockAuditableRepository<User, UserAuditLog>.Expectations()
    
    let user = User(id: "123", name: "John")
    let auditLog = UserAuditLog(action: "created", timestamp: Date(), userId: "123")
    
    // Configure inherited methods
    expectations.save.success()
    expectations.find_id.value(user)
    
    // Configure protocol-specific methods
    expectations.saveWithAudit_entity_audit.success()
    expectations.getAuditLog_for.value([auditLog])
    
    let mockRepo = MockAuditableRepository<User, UserAuditLog>(expectations: expectations)
    
    // Test inherited functionality
    try await mockRepo.save(user)
    let foundUser = try await mockRepo.find(id: "123")
    XCTAssertEqual(foundUser?.name, "John")
    
    // Test new functionality
    try await mockRepo.saveWithAudit(user, audit: auditLog)
    let logs = try await mockRepo.getAuditLog(for: "123")
    XCTAssertEqual(logs.count, 1)
    XCTAssertEqual(logs[0].action, "created")
}
```

## Complex Generic Scenarios

### Multiple Generic Parameters with Constraints

```swift
@Smock
protocol DataTransformer {
    associatedtype Input: Codable
    associatedtype Output: Codable
    associatedtype Config: Codable
    
    func transform(_ input: Input, config: Config) async throws -> Output
    func validateInput(_ input: Input) async -> Bool
    func createDefaultConfig() async -> Config
}

struct RawData: Codable {
    let content: String
    let metadata: [String: String]
}

struct ProcessedData: Codable {
    let processedContent: String
    let tags: [String]
    let score: Double
}

struct ProcessingConfig: Codable {
    let enableTagging: Bool
    let scoreThreshold: Double
}

func testDataTransformer() async throws {
    let expectations = MockDataTransformer<RawData, ProcessedData, ProcessingConfig>.Expectations()
    
    let rawData = RawData(content: "test content", metadata: [:])
    let processedData = ProcessedData(
        processedContent: "processed: test content",
        tags: ["test"],
        score: 0.85
    )
    let config = ProcessingConfig(enableTagging: true, scoreThreshold: 0.5)
    
    expectations.transform_input_config.value(processedData)
    expectations.validateInput.value(true)
    expectations.createDefaultConfig.value(config)
    
    let mockTransformer = MockDataTransformer<RawData, ProcessedData, ProcessingConfig>(
        expectations: expectations
    )
    
    // Test validation
    let isValid = await mockTransformer.validateInput(rawData)
    XCTAssertTrue(isValid)
    
    // Test config creation
    let defaultConfig = await mockTransformer.createDefaultConfig()
    XCTAssertTrue(defaultConfig.enableTagging)
    
    // Test transformation
    let result = try await mockTransformer.transform(rawData, config: config)
    XCTAssertEqual(result.score, 0.85)
    XCTAssertEqual(result.tags, ["test"])
}
```

### Generic Protocol Composition

```swift
@Smock
protocol Readable {
    associatedtype Item
    func read(id: String) async throws -> Item?
}

@Smock
protocol Writable {
    associatedtype Item
    func write(id: String, item: Item) async throws
}

@Smock
protocol ReadWritable: Readable, Writable {
    // Inherits Item from both protocols
    func update(id: String, item: Item) async throws
}

func testReadWritableService() async throws {
    let expectations = MockReadWritable<User>.Expectations()
    
    let user = User(id: "123", name: "John")
    let updatedUser = User(id: "123", name: "John Updated")
    
    expectations.read_id.value(user)
    expectations.write_id_item.success()
    expectations.update_id_item.success()
    
    let mockService = MockReadWritable<User>(expectations: expectations)
    
    // Test reading
    let readUser = try await mockService.read(id: "123")
    XCTAssertEqual(readUser?.name, "John")
    
    // Test writing
    try await mockService.write(id: "456", item: user)
    
    // Test updating
    try await mockService.update(id: "123", item: updatedUser)
    
    // Verify all operations
    XCTAssertEqual(await mockService.__verify.read_id.callCount, 1)
    XCTAssertEqual(await mockService.__verify.write_id_item.callCount, 1)
    XCTAssertEqual(await mockService.__verify.update_id_item.callCount, 1)
}
```

## Best Practices for Associated Types

### 1. Use Meaningful Type Names

```swift
// Good: Clear, descriptive associated type names
@Smock
protocol Cache {
    associatedtype CacheKey: Hashable
    associatedtype CacheValue: Codable
    
    func store(key: CacheKey, value: CacheValue) async
    func retrieve(key: CacheKey) async -> CacheValue?
}

// Avoid: Generic, unclear names
@Smock
protocol Cache {
    associatedtype T: Hashable
    associatedtype U: Codable
    
    func store(key: T, value: U) async
    func retrieve(key: T) async -> U?
}
```

### 2. Provide Appropriate Constraints

```swift
// Good: Appropriate constraints for the use case
@Smock
protocol Serializable {
    associatedtype Data: Codable & Sendable
    
    func serialize() async throws -> Data
    func deserialize(_ data: Data) async throws
}

// Consider: Whether constraints are necessary
@Smock
protocol Processor {
    associatedtype Input
    associatedtype Output
    
    func process(_ input: Input) async throws -> Output
}
```

### 3. Test with Multiple Concrete Types

```swift
class AssociatedTypeTests: XCTestCase {
    
    func testRepositoryWithUsers() async throws {
        // Test with User type
        let userExpectations = MockRepository<User>.Expectations()
        userExpectations.save.success()
        
        let userRepo = MockRepository<User>(expectations: userExpectations)
        let user = User(id: "123", name: "John")
        try await userRepo.save(user)
    }
    
    func testRepositoryWithProducts() async throws {
        // Test with Product type
        let productExpectations = MockRepository<Product>.Expectations()
        productExpectations.save.success()
        
        let productRepo = MockRepository<Product>(expectations: productExpectations)
        let product = Product(id: "456", name: "Widget")
        try await productRepo.save(product)
    }
}
```

## Next Steps

- Explore <doc:AdvancedPatterns> for complex generic scenarios
- Review <doc:ProtocolInheritance> for inheritance with associated types
- See <doc:BestPractices> for generic protocol design guidelines