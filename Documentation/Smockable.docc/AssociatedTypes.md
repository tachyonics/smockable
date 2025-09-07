# Associated Types

Working with protocols that have associated types in Smockable.

## Overview

Smockable supports protocols with associated types, allowing you to create generic mocks that work with different concrete types. This enables testing of generic protocols and type-safe mock implementations.

### Comparable Support for Associated Types

**Important:** For associated types to support range and exact-value expectation matching, the associated type must explicitly declare conformance to `Comparable` directly in the protocol definition. This conformance cannot be inherited through other protocol conformances - it must be specified explicitly.

```swift
@Smock
protocol Repository {
    associatedtype Entity: Comparable & Sendable  // Enables range/exact matching
    
    func save(_ entity: Entity) async throws
    func find(id: String) async throws -> Entity?
}

@Smock
protocol DataStore {
    associatedtype Item: Sendable  // Only .any matching available
    
    func store(_ item: Item) async throws
    func retrieve() async throws -> Item?
}
```

When an associated type conforms to `Comparable`, you can use:
- **Exact value matching**: `when(expectations.save("user123"), ...)`
- **Range matching**: `when(expectations.save("user100"..."user999"), ...)`

When an associated type does **not** conform to `Comparable`, you can only use:
- **Any matching**: `when(expectations.save(.any), ...)`


## Basic Associated Types

### Simple Associated Type

```swift
@Smock
protocol Repository {
    associatedtype Entity: Comparable  // Enables range and exact-value matching
    
    func save(_ entity: Entity) async throws
    func find(id: String) async throws -> Entity?
    func delete(id: String) async throws
}

// Usage with specific type
@Test
func testUserRepository() async throws {
    var expectations = MockRepository<User>.Expectations()
    
    let testUser = User(id: "123", name: "John Doe")
    
    // With Comparable associated types, you can use exact and range matching
    when(expectations.save(testUser), complete: .withSuccess)  // Exact value
    when(expectations.find(id: "100"..."999"), return: testUser)  // Range on String parameter
    when(expectations.delete(id: .any), complete: .withSuccess)  // Any matching
    
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
    associatedtype Key: Hashable & Comparable    // Both Hashable and Comparable
    associatedtype Value: Codable & Comparable   // Codable and Comparable
    
    func set(key: Key, value: Value) async throws
    func get(key: Key) async throws -> Value?
    func remove(key: Key) async throws
    func keys() async throws -> [Key]
}

@Test
func testStringIntStore() async throws {
    var expectations = MockKeyValueStore<String, Int>.Expectations()
    
    // With Comparable associated types, you can use exact and range matching
    when(expectations.set(key: "count", value: 42), complete: .withSuccess)  // Exact values
    when(expectations.set(key: "total", value: 100), complete: .withSuccess)  // Exact values
    when(expectations.get(key: "count"), return: 42)  // Exact key matching
    when(expectations.get(key: "total"), return: 100)  // Exact key matching
    when(expectations.get(key: .any), return: nil)  // Fallback for other keys
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

## Non-Comparable Associated Types

When associated types do not conform to `Comparable`, expectation matching is limited to `.any` matchers only.

```swift
@Smock
protocol DataStore {
    associatedtype Item: Sendable  // No Comparable conformance
    
    func store(_ item: Item) async throws
    func retrieve(id: String) async throws -> Item?
}

struct CustomData: Sendable {
    let content: String
    let metadata: [String: String]
}

@Test
func testNonComparableAssociatedType() async throws {
    var expectations = MockDataStore<CustomData>.Expectations()
    
    let testData = CustomData(content: "test", metadata: [:])
    
    // Only .any matching is available for non-Comparable associated types
    when(expectations.store(.any), complete: .withSuccess)
    when(expectations.retrieve(id: .any), return: testData)
    
    let mockStore = MockDataStore<CustomData>(expectations: expectations)
    
    try await mockStore.store(testData)
    let retrieved = try await mockStore.retrieve(id: "123")
    
    #expect(retrieved?.content == "test")
}
```

### Mixed Comparability

You can have protocols with both Comparable and non-Comparable associated types:

```swift
@Smock
protocol MixedStore {
    associatedtype ComparableItem: Comparable & Sendable  // Supports exact/range matching
    associatedtype NonComparableItem: Sendable // Only supports .any matching
    
    func storeComparable(_ item: ComparableItem) async throws
    func storeNonComparable(_ item: NonComparableItem) async throws
}

@Test
func testMixedComparability() async throws {
    var expectations = MockMixedStore<String, CustomData>.Expectations()
    
    // Comparable type supports exact and range matching
    when(expectations.storeComparable("exact"), complete: .withSuccess)
    when(expectations.storeComparable("A"..."Z"), complete: .withSuccess)
    
    // Non-comparable type only supports .any
    when(expectations.storeNonComparable(.any), complete: .withSuccess)
    
    let mockStore = MockMixedStore<String, CustomData>(expectations: expectations)
    // ... test implementation
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
