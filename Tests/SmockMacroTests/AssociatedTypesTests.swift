import Foundation
import Smockable
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

// MARK: - Test Data Structures

struct User: Codable, Equatable, Sendable, Comparable {
    static func < (lhs: User, rhs: User) -> Bool {
        return lhs.id < rhs.id
    }

    let id: String
    let name: String
}

struct Product: Codable, Equatable, Sendable, Comparable {
    let id: String
    let name: String

    static func < (lhs: Product, rhs: Product) -> Bool {
        return lhs.id < rhs.id
    }
}

struct UserData: Codable, Equatable, Sendable, Comparable {
    let id: String
    let name: String

    static func < (lhs: UserData, rhs: UserData) -> Bool {
        return lhs.id < rhs.id
    }
}

struct SerializedUserData: Codable, Equatable, Sendable, Comparable {
    let data: String  // Changed from Data to String
    let timestamp: String  // Changed from Date to String

    static func < (lhs: SerializedUserData, rhs: SerializedUserData) -> Bool {
        return lhs.data < rhs.data
    }
}

public protocol EventProtocol: Sendable {
    var timestamp: String { get }  // Changed from Date to String
    var eventId: String { get }
}

struct UserCreatedEvent: EventProtocol, Equatable, Sendable, Comparable {
    let timestamp: String  // Changed from Date to String
    let eventId: String
    let userId: String
    let userName: String

    static func < (lhs: UserCreatedEvent, rhs: UserCreatedEvent) -> Bool {
        return lhs.eventId < rhs.eventId
    }
}

struct RawData: Codable, Equatable, Sendable, Comparable {
    let content: String
    let metadata: [String: String]

    static func < (lhs: RawData, rhs: RawData) -> Bool {
        return lhs.content < rhs.content
    }
}

struct ProcessedData: Codable, Equatable, Sendable, Comparable {
    let processedContent: String
    let tags: [String]
    let score: Double

    static func < (lhs: ProcessedData, rhs: ProcessedData) -> Bool {
        return lhs.processedContent < rhs.processedContent
    }
}

struct ProcessingConfig: Codable, Equatable, Sendable, Comparable {
    let enableTagging: Bool
    let scoreThreshold: Double

    static func < (lhs: ProcessingConfig, rhs: ProcessingConfig) -> Bool {
        return lhs.scoreThreshold < rhs.scoreThreshold
    }
}

// MARK: - Protocol Definitions

@Smock
public protocol Repository {
    associatedtype Entity: Sendable & Comparable

    func save(_ entity: Entity) async throws
    func find(id: String) async throws -> Entity?
    func delete(id: String) async throws
}

@Smock
public protocol KeyValueStore {
    associatedtype Key: Hashable & Sendable & Comparable
    associatedtype Value: Codable & Sendable & Comparable

    func set(key: Key, value: Value) async throws
    func get(key: Key) async throws -> Value?
    func remove(key: Key) async throws
    func keys() async throws -> [Key]
}

@Smock
public protocol Serializer {
    associatedtype Input: Codable & Sendable & Comparable
    associatedtype Output: Codable & Sendable & Comparable

    func serialize(_ input: Input) async throws -> Output
    func deserialize(_ output: Output) async throws -> Input
}

@Smock
public protocol EventHandler {
    associatedtype Event: EventProtocol & Comparable

    func handle(_ event: Event) async throws
}

@Smock
public protocol DataTransformer {
    associatedtype Input: Codable & Sendable & Comparable
    associatedtype Output: Codable & Sendable & Comparable
    associatedtype Config: Codable & Sendable & Comparable

    func transform(_ input: Input, config: Config) async throws -> Output
    func validateInput(_ input: Input) async -> Bool
    func createDefaultConfig() async -> Config
}

@Smock
public protocol SimpleReadWritable {
    associatedtype Item: Sendable & Comparable

    func read(id: String) async throws -> Item?
    func write(id: String, item: Item) async throws
    func update(id: String, item: Item) async throws
}

@Smock
public protocol Cache {
    associatedtype CacheKey: Hashable & Sendable & Comparable
    associatedtype CacheValue: Codable & Sendable & Comparable

    func store(key: CacheKey, value: CacheValue) async
    func retrieve(key: CacheKey) async -> CacheValue?
}

@Smock
public protocol Serializable {
    associatedtype Data: Codable & Sendable & Comparable

    func serialize() async throws -> Data
    func deserialize(_ data: Data) async throws
}

@Smock
public protocol Processor {
    associatedtype Input: Sendable & Comparable
    associatedtype Output: Sendable & Comparable

    func process(_ input: Input) async throws -> Output
}

// MARK: - Test Cases

struct AssociatedTypesTests {

    // MARK: - Basic Associated Types Tests

    @Test
    func testSimpleAssociatedType() async throws {
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

        // Verify call counts
        let saveCount = await mockRepo.__verify.save.callCount
        let findCount = await mockRepo.__verify.find_id.callCount
        let deleteCount = await mockRepo.__verify.delete_id.callCount

        #expect(saveCount == 1)
        #expect(findCount == 1)
        #expect(deleteCount == 1)
    }

    @Test
    func testMultipleAssociatedTypes() async throws {
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

    // MARK: - Constrained Associated Types Tests

    @Test
    func testTypeConstraints() async throws {
        var expectations = MockSerializer<UserData, SerializedUserData>.Expectations()

        let userData = UserData(id: "123", name: "John")
        let serializedData = SerializedUserData(
            data: "serialized_data_123",
            timestamp: "2024-01-01T00:00:00Z"
        )

        when(expectations.serialize(.any), return: serializedData)
        when(expectations.deserialize(.any), return: userData)

        let mockSerializer = MockSerializer<UserData, SerializedUserData>(expectations: expectations)

        let serialized = try await mockSerializer.serialize(userData)
        let deserialized = try await mockSerializer.deserialize(serialized)

        #expect(deserialized.name == "John")

        // Verify call counts
        let serializeCount = await mockSerializer.__verify.serialize.callCount
        let deserializeCount = await mockSerializer.__verify.deserialize.callCount

        #expect(serializeCount == 1)
        #expect(deserializeCount == 1)
    }

    @Test
    func testProtocolConstraints() async throws {
        var expectations = MockEventHandler<UserCreatedEvent>.Expectations()

        when(expectations.handle(.any), complete: .withSuccess)

        let mockHandler = MockEventHandler<UserCreatedEvent>(expectations: expectations)

        let event = UserCreatedEvent(
            timestamp: "2024-01-01T00:00:00Z",
            eventId: "event-123",
            userId: "user-456",
            userName: "John Doe"
        )

        try await mockHandler.handle(event)

        let handleCount = await mockHandler.__verify.handle.callCount
        #expect(handleCount == 1)
    }

    // MARK: - Complex Generic Scenarios Tests

    @Test
    func testMultipleGenericParametersWithConstraints() async throws {
        var expectations = MockDataTransformer<RawData, ProcessedData, ProcessingConfig>.Expectations()

        let rawData = RawData(content: "test content", metadata: [:])
        let processedData = ProcessedData(
            processedContent: "processed: test content",
            tags: ["test"],
            score: 0.85
        )
        let config = ProcessingConfig(enableTagging: true, scoreThreshold: 0.5)

        when(expectations.transform(.any, config: .any), return: processedData)
        when(expectations.validateInput(.any), return: true)
        when(expectations.createDefaultConfig(), return: config)

        let mockTransformer = MockDataTransformer<RawData, ProcessedData, ProcessingConfig>(
            expectations: expectations
        )

        // Test validation
        let isValid = await mockTransformer.validateInput(rawData)
        #expect(isValid == true)

        // Test config creation
        let defaultConfig = await mockTransformer.createDefaultConfig()
        #expect(defaultConfig.enableTagging == true)

        // Test transformation
        let result = try await mockTransformer.transform(rawData, config: config)
        #expect(result.score == 0.85)
        #expect(result.tags == ["test"])

        // Verify call counts
        let validateCount = await mockTransformer.__verify.validateInput.callCount
        let configCount = await mockTransformer.__verify.createDefaultConfig.callCount
        let transformCount = await mockTransformer.__verify.transform_config.callCount

        #expect(validateCount == 1)
        #expect(configCount == 1)
        #expect(transformCount == 1)
    }

    @Test
    func testSimpleReadWritable() async throws {
        var expectations = MockSimpleReadWritable<User>.Expectations()

        let user = User(id: "123", name: "John")
        let updatedUser = User(id: "123", name: "John Updated")

        when(expectations.read(id: "100"..."999"), return: user)
        when(expectations.write(id: "400"..."499", item: .any), complete: .withSuccess)
        when(expectations.update(id: "100"..."199", item: .any), complete: .withSuccess)

        let mockService = MockSimpleReadWritable<User>(expectations: expectations)

        // Test reading
        let readUser = try await mockService.read(id: "123")
        #expect(readUser?.name == "John")

        // Test writing
        try await mockService.write(id: "456", item: user)

        // Test updating
        try await mockService.update(id: "123", item: updatedUser)

        // Verify all operations
        let readCount = await mockService.__verify.read_id.callCount
        let writeCount = await mockService.__verify.write_id_item.callCount
        let updateCount = await mockService.__verify.update_id_item.callCount

        #expect(readCount == 1)
        #expect(writeCount == 1)
        #expect(updateCount == 1)
    }

    // MARK: - Best Practices Tests

    @Test
    func testRepositoryWithMultipleTypes() async throws {
        // Test with User type
        var userExpectations = MockRepository<User>.Expectations()
        when(userExpectations.save(.any), complete: .withSuccess)

        let userRepo = MockRepository<User>(expectations: userExpectations)
        let user = User(id: "123", name: "John")
        try await userRepo.save(user)

        let userSaveCount = await userRepo.__verify.save.callCount
        #expect(userSaveCount == 1)

        // Test with Product type
        var productExpectations = MockRepository<Product>.Expectations()
        when(productExpectations.save(.any), complete: .withSuccess)

        let productRepo = MockRepository<Product>(expectations: productExpectations)
        let product = Product(id: "456", name: "Widget")
        try await productRepo.save(product)

        let productSaveCount = await productRepo.__verify.save.callCount
        #expect(productSaveCount == 1)
    }

    @Test
    func testCacheWithMeaningfulTypeNames() async throws {
        var expectations = MockCache<String, User>.Expectations()

        let user = User(id: "123", name: "John")
        when(expectations.store(key: "user_100"..."user_999", value: .any), complete: .withSuccess)
        when(expectations.retrieve(key: "user_100"..."user_999"), return: user)

        let mockCache = MockCache<String, User>(expectations: expectations)

        await mockCache.store(key: "user_123", value: user)
        let retrievedUser = await mockCache.retrieve(key: "user_123")

        #expect(retrievedUser?.name == "John")

        let storeCount = await mockCache.__verify.store_key_value.callCount
        let retrieveCount = await mockCache.__verify.retrieve_key.callCount

        #expect(storeCount == 1)
        #expect(retrieveCount == 1)
    }

    @Test
    func testSerializableWithConstraints() async throws {
        var expectations = MockSerializable<UserData>.Expectations()

        let userData = UserData(id: "123", name: "John")
        when(expectations.serialize(), return: userData)
        when(expectations.deserialize(.any), complete: .withSuccess)

        let mockSerializable = MockSerializable<UserData>(expectations: expectations)

        let serialized = try await mockSerializable.serialize()
        #expect(serialized.name == "John")

        try await mockSerializable.deserialize(userData)

        let serializeCount = await mockSerializable.__verify.serialize.callCount
        let deserializeCount = await mockSerializable.__verify.deserialize.callCount

        #expect(serializeCount == 1)
        #expect(deserializeCount == 1)
    }

    @Test
    func testProcessorWithoutConstraints() async throws {
        var expectations = MockProcessor<String, Int>.Expectations()

        when(expectations.process(.any), return: 42)

        let mockProcessor = MockProcessor<String, Int>(expectations: expectations)

        let result = try await mockProcessor.process("test")
        #expect(result == 42)

        let processCount = await mockProcessor.__verify.process.callCount
        #expect(processCount == 1)
    }
}
