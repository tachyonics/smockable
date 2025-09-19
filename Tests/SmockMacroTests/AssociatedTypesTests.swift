import Foundation
import Smockable
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

// MARK: - Test Data Structures

// Equatable-only types (not Comparable)
struct EquatableOnlyData: Equatable, Sendable {
    let id: UUID
    let enabled: Bool
    let metadata: Data
}

struct BooleanConfig: Equatable, Sendable {
    let debug: Bool
    let verbose: Bool
    let autoSave: Bool
}

struct IdentifierData: Equatable, Sendable {
    let primaryId: UUID
    let secondaryId: UUID
    let isActive: Bool
}

struct NetworkConfig: Equatable, Sendable {
    let baseURL: URL
    let timeout: Bool  // Simplified for testing
    let retryEnabled: Bool
}

// Mix of Comparable and Equatable-only
struct MixedTypeData: Equatable, Sendable {
    let name: String  // Comparable
    let isEnabled: Bool  // Equatable-only
    let identifier: UUID  // Equatable-only
}

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

// MARK: - Equatable-Only Associated Type Protocols

@Smock
public protocol BooleanConfigRepository {
    associatedtype ConfigType: Equatable & Sendable

    func save(_ config: ConfigType) async throws
    func load() async throws -> ConfigType?
    func update(_ config: ConfigType) async throws
    func reset() async throws
}

@Smock
public protocol IdentifierService {
    associatedtype IDType: Equatable & Sendable

    func generate() async -> IDType
    func validate(_ id: IDType) async -> Bool
    func store(_ id: IDType) async throws
    func retrieve() async throws -> [IDType]
}

@Smock
public protocol EquatableDataProcessor {
    associatedtype InputData: Equatable & Sendable
    associatedtype OutputData: Equatable & Sendable

    func process(_ input: InputData) async throws -> OutputData
    func canProcess(_ input: InputData) async -> Bool
    func getLastProcessed() async -> OutputData?
}

@Smock
public protocol NetworkManager {
    associatedtype ConfigType: Equatable & Sendable
    associatedtype ResponseType: Equatable & Sendable

    func configure(_ config: ConfigType) async throws
    func request() async throws -> ResponseType
    func isConfigured() async -> Bool
}

@Smock
public protocol MixedTypeService {
    associatedtype ComparableType: Comparable & Sendable
    associatedtype EquatableType: Equatable & Sendable

    func processComparable(_ data: ComparableType) async throws
    func processEquatable(_ data: EquatableType) async throws
    func combine(_ comparable: ComparableType, _ equatable: EquatableType) async throws -> String
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
        verify(mockRepo, times: 1).save(.any)
        verify(mockRepo, times: 1).find(id: .any)
        verify(mockRepo, times: 1).delete(id: .any)
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
        verify(mockSerializer, times: 1).serialize(.any)
        verify(mockSerializer, times: 1).deserialize(.any)
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

        verify(mockHandler, times: 1).handle(.any)
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
        verify(mockTransformer, times: 1).validateInput(.any)
        verify(mockTransformer, times: 1).createDefaultConfig()
        verify(mockTransformer, times: 1).transform(.any, config: .any)
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
        verify(mockService, times: 1).read(id: "100"..."999")
        verify(mockService, times: 1).write(id: "400"..."499", item: .any)
        verify(mockService, times: 1).update(id: "100"..."199", item: .any)
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

        verify(userRepo, times: 1).save(.any)

        // Test with Product type
        var productExpectations = MockRepository<Product>.Expectations()
        when(productExpectations.save(.any), complete: .withSuccess)

        let productRepo = MockRepository<Product>(expectations: productExpectations)
        let product = Product(id: "456", name: "Widget")
        try await productRepo.save(product)

        verify(productRepo, times: 1).save(.any)
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

        verify(mockCache, times: 1).store(key: "user_100"..."user_999", value: .any)
        verify(mockCache, times: 1).retrieve(key: "user_100"..."user_999")
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

        verify(mockSerializable, times: 1).serialize()
        verify(mockSerializable, times: 1).deserialize(.any)
    }

    @Test
    func testProcessorWithoutConstraints() async throws {
        var expectations = MockProcessor<String, Int>.Expectations()

        when(expectations.process(.any), return: 42)

        let mockProcessor = MockProcessor<String, Int>(expectations: expectations)

        let result = try await mockProcessor.process("test")
        #expect(result == 42)

        verify(mockProcessor, times: 1).process(.any)
    }

    // MARK: - Equatable-Only Associated Types Tests

    @Test
    func testBooleanConfigRepository() async throws {
        var expectations = MockBooleanConfigRepository<BooleanConfig>.Expectations()

        let config = BooleanConfig(debug: true, verbose: false, autoSave: true)
        let updatedConfig = BooleanConfig(debug: false, verbose: true, autoSave: true)

        // Test with exact matching (only .any and .exact available for Equatable-only)
        when(expectations.save(config), complete: .withSuccess)
        when(expectations.load(), return: config)
        when(expectations.update(.any), complete: .withSuccess)
        when(expectations.reset(), complete: .withSuccess)

        let mockRepo = MockBooleanConfigRepository<BooleanConfig>(expectations: expectations)

        // Test save with exact config
        try await mockRepo.save(config)

        // Test load
        let loadedConfig = try await mockRepo.load()
        #expect(loadedConfig?.debug == true)
        #expect(loadedConfig?.verbose == false)

        // Test update with any config
        try await mockRepo.update(updatedConfig)

        // Test reset
        try await mockRepo.reset()

        // Verify calls
        verify(mockRepo, times: 1).save(config)
        verify(mockRepo, times: 1).load()
        verify(mockRepo, times: 1).update(.any)
        verify(mockRepo, times: 1).reset()
    }

    @Test
    func testIdentifierServiceWithUUID() async throws {
        var expectations = MockIdentifierService<UUID>.Expectations()

        let testUUID = UUID()
        let anotherUUID = UUID()

        when(expectations.generate(), return: testUUID)
        when(expectations.validate(testUUID), return: true)
        when(expectations.validate(.any), return: false)  // Default for non-matching UUIDs
        when(expectations.store(.any), complete: .withSuccess)
        when(expectations.retrieve(), return: [testUUID, anotherUUID])

        let mockService = MockIdentifierService<UUID>(expectations: expectations)

        // Test generate
        let generatedID = await mockService.generate()
        #expect(generatedID == testUUID)

        // Test validate with exact match
        let isValidExact = await mockService.validate(testUUID)
        #expect(isValidExact == true)

        // Test validate with different UUID
        let isValidOther = await mockService.validate(anotherUUID)
        #expect(isValidOther == false)

        // Test store
        try await mockService.store(testUUID)

        // Test retrieve
        let storedIDs = try await mockService.retrieve()
        #expect(storedIDs.count == 2)
        #expect(storedIDs.contains(testUUID))

        // Verify calls
        verify(mockService, times: 1).generate()
        verify(mockService, times: 1).validate(testUUID)
        verify(mockService, times: 2).validate(.any)
        verify(mockService, times: 1).store(.any)
        verify(mockService, times: 1).retrieve()
    }

    @Test
    func testDataProcessorWithEquatableData() async throws {
        var expectations = MockEquatableDataProcessor<EquatableOnlyData, IdentifierData>.Expectations()

        let inputData = EquatableOnlyData(
            id: UUID(),
            enabled: true,
            metadata: Data("test".utf8)
        )
        let outputData = IdentifierData(
            primaryId: UUID(),
            secondaryId: UUID(),
            isActive: true
        )

        when(expectations.process(.any), return: outputData)
        when(expectations.canProcess(inputData), return: true)
        when(expectations.canProcess(.any), return: false)  // Default for other inputs
        when(expectations.getLastProcessed(), return: outputData)

        let mockProcessor = MockEquatableDataProcessor<EquatableOnlyData, IdentifierData>(expectations: expectations)

        // Test can process with exact match
        let canProcessExact = await mockProcessor.canProcess(inputData)
        #expect(canProcessExact == true)

        // Test can process with different data
        let differentData = EquatableOnlyData(
            id: UUID(),
            enabled: false,
            metadata: Data("different".utf8)
        )
        let canProcessDifferent = await mockProcessor.canProcess(differentData)
        #expect(canProcessDifferent == false)

        // Test process
        let result = try await mockProcessor.process(inputData)
        #expect(result.isActive == true)

        // Test get last processed
        let lastProcessed = await mockProcessor.getLastProcessed()
        #expect(lastProcessed?.isActive == true)

        // Verify calls
        verify(mockProcessor, times: 1).canProcess(inputData)
        verify(mockProcessor, times: 2).canProcess(.any)
        verify(mockProcessor, times: 1).process(.any)
        verify(mockProcessor, times: 1).getLastProcessed()
    }

    @Test
    func testNetworkManagerWithURL() async throws {
        var expectations = MockNetworkManager<NetworkConfig, BooleanConfig>.Expectations()

        let networkConfig = NetworkConfig(
            baseURL: URL(string: "https://api.example.com")!,
            timeout: true,
            retryEnabled: false
        )
        let response = BooleanConfig(debug: false, verbose: true, autoSave: false)

        when(expectations.configure(networkConfig), complete: .withSuccess)
        when(expectations.request(), return: response)
        when(expectations.isConfigured(), return: true)

        let mockManager = MockNetworkManager<NetworkConfig, BooleanConfig>(expectations: expectations)

        // Test configure
        try await mockManager.configure(networkConfig)

        // Test is configured
        let isConfigured = await mockManager.isConfigured()
        #expect(isConfigured == true)

        // Test request
        let requestResponse = try await mockManager.request()
        #expect(requestResponse.verbose == true)
        #expect(requestResponse.debug == false)

        // Verify calls
        verify(mockManager, times: 1).configure(networkConfig)
        verify(mockManager, times: 1).isConfigured()
        verify(mockManager, times: 1).request()
    }

    @Test
    func testMixedTypeServiceComparableAndEquatable() async throws {
        var expectations = MockMixedTypeService<String, BooleanConfig>.Expectations()

        let comparableData = "test string"
        let equatableData = BooleanConfig(debug: true, verbose: false, autoSave: true)
        let combinedResult = "processed: test string with config"

        // Comparable type supports ranges
        when(expectations.processComparable("a"..."z"), complete: .withSuccess)

        // Equatable-only type supports exact and .any only
        when(expectations.processEquatable(equatableData), complete: .withSuccess)

        when(expectations.combine(.any, .any), return: combinedResult)

        let mockService = MockMixedTypeService<String, BooleanConfig>(expectations: expectations)

        // Test comparable with range
        try await mockService.processComparable(comparableData)

        // Test equatable with exact match
        try await mockService.processEquatable(equatableData)

        // Test combine
        let result = try await mockService.combine(comparableData, equatableData)
        #expect(result == combinedResult)

        // Verify calls
        verify(mockService, times: 1).processComparable("a"..."z")
        verify(mockService, times: 1).processEquatable(equatableData)
        verify(mockService, times: 1).combine(.any, .any)
    }

    @Test
    func testEquatableOnlyAnyMatching() async throws {
        var expectations = MockBooleanConfigRepository<BooleanConfig>.Expectations()

        let config1 = BooleanConfig(debug: true, verbose: false, autoSave: true)
        let config2 = BooleanConfig(debug: false, verbose: true, autoSave: false)

        // Test .any matching works for any Equatable-only type
        when(expectations.save(.any), times: 2, complete: .withSuccess)
        when(expectations.update(.any), times: 2, complete: .withSuccess)

        let mockRepo = MockBooleanConfigRepository<BooleanConfig>(expectations: expectations)

        // Save different configs - both should match .any
        try await mockRepo.save(config1)
        try await mockRepo.save(config2)

        // Update different configs - both should match .any
        try await mockRepo.update(config1)
        try await mockRepo.update(config2)

        // Verify that .any matched all calls
        verify(mockRepo, times: 2).save(.any)
        verify(mockRepo, times: 2).update(.any)
    }

    // MARK: - Unhappy Path Tests

    #if SMOCKABLE_UNHAPPY_PATH_TESTING
    @Test
    func testAssociatedTypeVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected read(id: any) to be called exactly 2 times, but was called 1 time"
        ]) {
            var expectations = MockSimpleReadWritable<User>.Expectations()
            when(expectations.read(id: .any), return: User(id: "test", name: "test"))

            let mockService = MockSimpleReadWritable<User>(expectations: expectations)

            // Call once but verify twice - should fail
            _ = try? await mockService.read(id: "100")
            verify(mockService, times: 2).read(id: .any)
        }
    }

    @Test
    func testComplexAssociatedTypeVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected process(_ input: any) to never be called, but was called 1 time"
        ]) {
            var expectations = MockProcessor<String, String>.Expectations()
            when(expectations.process(.any), return: "processed")

            let mockProcessor = MockProcessor<String, String>(expectations: expectations)

            // Call it but verify never called - should fail
            _ = try? await mockProcessor.process("test input")

            verify(mockProcessor, .never).process(.any)
        }
    }

    @Test
    func testGenericParameterVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected store(key: any, value: any) to be called at least 3 times, but was called 1 time"
        ]) {
            var expectations = MockCache<String, String>.Expectations()
            when(expectations.store(key: .any, value: .any), complete: .withSuccess)
            when(expectations.retrieve(key: .any), return: "cached")

            let mockCache = MockCache<String, String>(expectations: expectations)

            // Call once but verify at least 3 times - should fail
            await mockCache.store(key: "user_100", value: "data")

            verify(mockCache, atLeast: 3).store(key: .any, value: .any)
        }
    }

    @Test
    func testEquatableOnlyTypeVerificationFailures() async {
        expectVerificationFailures(messages: [
            "Expected validate(_ id: any) to be called exactly 1 time, but was called 0 times"
        ]) {
            var expectations = MockIdentifierService<UUID>.Expectations()
            when(expectations.validate(.any), return: true)

            let mockValidator = MockIdentifierService<UUID>(expectations: expectations)

            // Don't call but verify once - should fail
            verify(mockValidator, times: 1).validate(.any)
        }
    }

    @Test
    func testComparableTypeWithRangeVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected transform(_ input: any, config: any) to be called 2...4 times, but was called 1 time"
        ]) {
            var expectations = MockDataTransformer<RawData, ProcessedData, ProcessingConfig>.Expectations()
            when(
                expectations.transform(.any, config: .any),
                times: .unbounded,
                return: ProcessedData(processedContent: "result", tags: [], score: 0.5)
            )

            let mockTransformer = MockDataTransformer<RawData, ProcessedData, ProcessingConfig>(
                expectations: expectations
            )

            // Call once but verify range 2...4 - should fail
            _ = try? await mockTransformer.transform(
                RawData(content: "test", metadata: [:]),
                config: ProcessingConfig(enableTagging: true, scoreThreshold: 0.5)
            )

            verify(mockTransformer, times: 2...4).transform(.any, config: .any)
        }
    }

    @Test
    func testCodableTypeVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected serialize(_ input: any) to be called at most 1 time, but was called 3 times"
        ]) {
            var expectations = MockSerializer<UserData, SerializedUserData>.Expectations()
            when(
                expectations.serialize(.any),
                times: .unbounded,
                return: SerializedUserData(data: "serialized", timestamp: "2024-01-01")
            )

            let mockSerializer = MockSerializer<UserData, SerializedUserData>(expectations: expectations)

            // Call 3 times but verify at most 1 - should fail
            _ = try? await mockSerializer.serialize(UserData(id: "1", name: "test1"))
            _ = try? await mockSerializer.serialize(UserData(id: "2", name: "test2"))
            _ = try? await mockSerializer.serialize(UserData(id: "3", name: "test3"))

            verify(mockSerializer, atMost: 1).serialize(.any)
        }
    }

    @Test
    func testMultipleAssociatedTypeVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected read(id: any) to be called exactly 2 times, but was called 1 time",
            "Expected write(id: any, item: any) to never be called, but was called 1 time",
        ]) {
            var expectations = MockSimpleReadWritable<User>.Expectations()
            when(expectations.read(id: .any), return: User(id: "test", name: "test"))
            when(expectations.write(id: .any, item: .any), complete: .withSuccess)

            let mockService = MockSimpleReadWritable<User>(expectations: expectations)

            // Call each once
            _ = try? await mockService.read(id: "100")
            try? await mockService.write(id: "200", item: User(id: "write", name: "write"))

            // Two failing verifications
            verify(mockService, times: 2).read(id: .any)  // Fail 1
            verify(mockService, .never).write(id: .any, item: .any)  // Fail 2
        }
    }

    @Test
    func testGenericCacheComplexVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected retrieve(key: any) to be called at least once, but was never called"
        ]) {
            var expectations = MockCache<String, String>.Expectations()
            when(expectations.store(key: .any, value: .any), complete: .withSuccess)
            when(expectations.retrieve(key: .any), return: "cached")

            let mockCache = MockCache<String, String>(expectations: expectations)

            // Only call store, not retrieve
            await mockCache.store(key: "user_100", value: "data")

            // Verify retrieve was called - should fail
            verify(mockCache, .atLeastOnce).retrieve(key: .any)
        }
    }

    @Test
    func testProcessingResultEnumVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected process(_ input: any) to be called exactly 3 times, but was called 2 times"
        ]) {
            var expectations = MockProcessor<String, String>.Expectations()
            when(expectations.process(.any), times: .unbounded, return: "processed")

            let mockProcessor = MockProcessor<String, String>(expectations: expectations)

            // Call twice but verify 3 times - should fail
            _ = try? await mockProcessor.process("input1")
            _ = try? await mockProcessor.process("input2")

            verify(mockProcessor, times: 3).process(.any)
        }
    }
    #endif
}
