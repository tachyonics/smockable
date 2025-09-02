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

## Next Steps

- Review <doc:FrameworkLimitations> for a discussion of Smockable's limitations and possible workarounds
