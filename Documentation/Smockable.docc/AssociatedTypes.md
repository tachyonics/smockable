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
@Test
func testUserRepository() async throws {
    var expectations = MockRepository<User>.Expectations()
    
    let testUser = User(id: "123", name: "John Doe")
    when(expectations.save(.any), complete: .withSuccess)
    when(expectations.find(id: .any), return: testUser)
    when(expectations.delete(id: .any), complete: .withSuccess)
    
    let mockRepo = MockRepository<User>(expectations: expectations)
    
    try await mockRepo.save(testUser)
    let foundUser = try await mockRepo.find(id: "123")
    try await mockRepo.delete(id: "123")
    
    #expect(foundUser?.name == "John Doe")
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

@Test
func testStringIntStore() async throws {
    var expectations = MockKeyValueStore<String, Int>.Expectations()
    
    when(expectations.set(key: .any, value: .any), times: .unbounded, complete: .withSuccess)
    when(expectations.get(key: .any), times: .unbounded) { key in
        switch key {
        case "count": return 42
        case "total": return 100
        default: return nil
        }
    }
    when(expectations.remove(key: .any), complete: .withSuccess)
    when(expectations.keys(), return: ["count", "total"])
    
    let mockStore = MockKeyValueStore<String, Int>(expectations: expectations)
    
    try await mockStore.set(key: "count", value: 42)
    try await mockStore.set(key: "total", value: 100)
    
    let count = try await mockStore.get(key: "count")
    let total = try await mockStore.get(key: "total")
    let missing = try await mockStore.get(key: "missing")
    
    #expect(count == 42)
    #expect(total == 100)
    #expect(missing == nil)
    
    let allKeys = try await mockStore.keys()
    #expect(Set(allKeys) == Set(["count", "total"]))
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

@Test
func testUserDataSerializer() async throws {
    var expectations = MockSerializer<UserData, SerializedUserData>.Expectations()
    
    let userData = UserData(id: "123", name: "John")
    let serializedData = SerializedUserData(
        data: try JSONEncoder().encode(userData),
        timestamp: Date()
    )
    
    when(expectations.serialize(.any), return: serializedData)
    when(expectations.deserialize(.any), return: userData)
    
    let mockSerializer = MockSerializer<UserData, SerializedUserData>(expectations: expectations)
    
    let serialized = try await mockSerializer.serialize(userData)
    let deserialized = try await mockSerializer.deserialize(serialized)
    
    #expect(deserialized.name == "John")
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

@Test
func testUserEventHandler() async throws {
    var expectations = MockEventHandler<UserCreatedEvent>.Expectations()
    
    when(expectations.handle(.any), complete: .withSuccess)
    when(expectations.canHandle(.any), return: true)
    
    let mockHandler = MockEventHandler<UserCreatedEvent>(expectations: expectations)
    
    let event = UserCreatedEvent(
        timestamp: Date(),
        eventId: "event-123",
        userId: "user-456",
        userName: "John Doe"
    )
    
    let canHandle = mockHandler.canHandle(UserCreatedEvent.self)
    #expect(canHandle)
    
    try await mockHandler.handle(event)
    
    let handleCount = await mockHandler.__verify.handle.callCount
    #expect(handleCount == 1)
}
```

## Next Steps

- Review <doc:FrameworkLimitations> for a discussion of Smockable's limitations and possible workarounds
