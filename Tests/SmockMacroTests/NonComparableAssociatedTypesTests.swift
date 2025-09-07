import Foundation
import Testing

@testable import Smockable

// MARK: - Non-Comparable Test Data Structures

struct NonComparableData: Sendable {
    let content: String
    let metadata: [String: String]  // Changed to Sendable type
    
    init(content: String, metadata: [String: String] = [:]) {
        self.content = content
        self.metadata = metadata
    }
}

struct SimpleData: Sendable {
    let value: String
}

// MARK: - Protocol Definitions with Non-Comparable Associated Types

@Smock
protocol NonComparableRepository {
    associatedtype Entity: Sendable
    
    func save(_ entity: Entity) async throws
    func find(id: String) async throws -> Entity?
    func delete(id: String) async throws
}

@Smock
protocol MixedComparabilityStore {
    associatedtype ComparableItem: Sendable & Comparable
    associatedtype NonComparableItem: Sendable
    
    func storeComparable(_ item: ComparableItem) async throws
    func storeNonComparable(_ item: NonComparableItem) async throws
    func getComparable(id: String) async throws -> ComparableItem?
    func getNonComparable(id: String) async throws -> NonComparableItem?
}

@Smock
protocol DataProcessor {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    
    func process(_ input: Input) async throws -> Output
    func validate(_ input: Input) async -> Bool
}

struct NonComparableAssociatedTypesTests {
    
    // MARK: - Non-Comparable Associated Type Tests
    
    @Test
    func testNonComparableAssociatedTypeOnlySupportsAnyMatcher() async throws {
        var expectations = MockNonComparableRepository<NonComparableData>.Expectations()
        
        let testData = NonComparableData(content: "test", metadata: ["key": "value"])
        
        // Non-comparable associated types should only support .any matcher
        when(expectations.save(.any), complete: .withSuccess)
        when(expectations.find(id: .any), return: testData)
        when(expectations.delete(id: .any), complete: .withSuccess)
        
        let mockRepo = MockNonComparableRepository<NonComparableData>(expectations: expectations)
        
        try await mockRepo.save(testData)
        let foundData = try await mockRepo.find(id: "123")
        try await mockRepo.delete(id: "123")
        
        #expect(foundData?.content == "test")
        
        let saveCount = await mockRepo.__verify.save.callCount
        let findCount = await mockRepo.__verify.find_id.callCount
        let deleteCount = await mockRepo.__verify.delete_id.callCount
        
        #expect(saveCount == 1)
        #expect(findCount == 1)
        #expect(deleteCount == 1)
    }
    
    @Test
    func testMixedComparabilityInSameProtocol() async throws {
        var expectations = MockMixedComparabilityStore<String, SimpleData>.Expectations()
        
        let comparableItem = "test-string"
        let nonComparableItem = SimpleData(value: "test-data")
        
        // Comparable associated type supports exact matching
        when(expectations.storeComparable("test-string"), complete: .withSuccess)
        when(expectations.storeComparable("A"..."Z"), complete: .withSuccess)  // Range matching
        when(expectations.getComparable(id: .any), return: comparableItem)
        
        // Non-comparable associated type only supports .any
        when(expectations.storeNonComparable(.any), complete: .withSuccess)
        when(expectations.getNonComparable(id: .any), return: nonComparableItem)
        
        let mockStore = MockMixedComparabilityStore<String, SimpleData>(expectations: expectations)
        
        // Test comparable item with exact match
        try await mockStore.storeComparable("test-string")
        
        // Test comparable item with range match
        try await mockStore.storeComparable("M")
        
        // Test non-comparable item (only .any works)
        try await mockStore.storeNonComparable(nonComparableItem)
        
        let retrievedComparable = try await mockStore.getComparable(id: "123")
        let retrievedNonComparable = try await mockStore.getNonComparable(id: "456")
        
        #expect(retrievedComparable == "test-string")
        #expect(retrievedNonComparable?.value == "test-data")
    }
    
    @Test
    func testUnconstrainedAssociatedTypes() async throws {
        var expectations = MockDataProcessor<String, Int>.Expectations()
        
        // Unconstrained associated types should only support .any matcher
        when(expectations.process(.any), return: 42)
        when(expectations.validate(.any), return: true)
        
        let mockProcessor = MockDataProcessor<String, Int>(expectations: expectations)
        
        let result = try await mockProcessor.process("input")
        let isValid = await mockProcessor.validate("input")
        
        #expect(result == 42)
        #expect(isValid == true)
        
        let processCount = await mockProcessor.__verify.process.callCount
        let validateCount = await mockProcessor.__verify.validate.callCount
        
        #expect(processCount == 1)
        #expect(validateCount == 1)
    }
    
    @Test
    func testNonComparableWithMultipleCalls() async throws {
        var expectations = MockNonComparableRepository<SimpleData>.Expectations()
        
        let data1 = SimpleData(value: "first")
        let data2 = SimpleData(value: "second")
        
        // Multiple expectations for non-comparable types
        when(expectations.save(.any), times: 2, complete: .withSuccess)
        when(expectations.find(id: .any), return: data1)
        when(expectations.find(id: .any), return: data2)
        
        let mockRepo = MockNonComparableRepository<SimpleData>(expectations: expectations)
        
        try await mockRepo.save(data1)
        try await mockRepo.save(data2)
        
        let found1 = try await mockRepo.find(id: "1")
        let found2 = try await mockRepo.find(id: "2")
        
        #expect(found1?.value == "first")
        #expect(found2?.value == "second")
        
        let saveCount = await mockRepo.__verify.save.callCount
        #expect(saveCount == 2)
    }
    
    @Test
    func testNonComparableWithErrorHandling() async throws {
        var expectations = MockNonComparableRepository<NonComparableData>.Expectations()
        
        enum TestError: Error {
            case notFound
            case invalidData
        }
        
        // Error expectations work with non-comparable types
        when(expectations.save(.any), throw: TestError.invalidData)
        when(expectations.find(id: .any), throw: TestError.notFound)
        
        let mockRepo = MockNonComparableRepository<NonComparableData>(expectations: expectations)
        
        let testData = NonComparableData(content: "test")
        
        await #expect(throws: TestError.invalidData) {
            try await mockRepo.save(testData)
        }
        
        await #expect(throws: TestError.notFound) {
            try await mockRepo.find(id: "123")
        }
    }
}