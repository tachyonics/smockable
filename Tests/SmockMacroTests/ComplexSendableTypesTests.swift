import Foundation
import Testing

@testable import Smockable
/*
@Smock
protocol TestComplexSendableService {
    // Collection types
    func arrayParam(strings: [String]) -> String
    func dictParam(metadata: [String: String]) -> String
    func setParam(numbers: Set<Int>) -> String

    // Optional collection types
    func optionalArrayParam(strings: [String]?) -> String
    func optionalDictParam(metadata: [String: String]?) -> String

    // Nested collections
    func nestedArrayParam(matrix: [[Int]]) -> String
    func arrayOfDictsParam(configs: [[String: String]]) -> String

    // Mixed parameter types with collections
    func mixedWithArray(name: String, items: [String], enabled: Bool) -> String
    func mixedWithDict(count: Int, config: [String: String], data: Data) -> String

    // Generic Sendable parameters
    func genericSendableParam(value: Sendable) -> String
    func multipleSendableParams(first: Sendable, second: Sendable) -> String

    // UUID and other specific Sendable types
    func uuidParam(id: UUID) -> String
    func urlParam(location: URL) -> String
    func dateParam(timestamp: Date) -> String

    // Complex combinations
    func complexMixedParams(
        name: String,
        ids: [UUID],
        config: [String: String],
        enabled: Bool,
        data: Data,
        sendable: Sendable
    ) -> String
}

struct ComplexSendableTypesTests {

    // MARK: - Collection Type Tests

    @Test
    func testArrayParameters() {
        var expectations = MockTestComplexSendableService.Expectations()

        when(expectations.arrayParam(strings: .any), return: "array matched")
        when(expectations.arrayParam(strings: ["specific", "array"]), return: "specific array matched")

        let mock = MockTestComplexSendableService(expectations: expectations)

        let result1 = mock.arrayParam(strings: ["test", "array"])
        let result2 = mock.arrayParam(strings: ["specific", "array"])

        #expect(result1 == "array matched")
        #expect(result2 == "specific array matched")

        verify(mock, times: 1).arrayParam(strings: .any)
        verify(mock, times: 1).arrayParam(strings: ["specific", "array"])
    }

    @Test
    func testDictionaryParameters() {
        var expectations = MockTestComplexSendableService.Expectations()

        when(expectations.dictParam(metadata: .any), return: "dict matched")
        when(expectations.dictParam(metadata: ["key": "value"]), return: "specific dict matched")

        let mock = MockTestComplexSendableService(expectations: expectations)

        let result1 = mock.dictParam(metadata: ["test": "dict"])
        let result2 = mock.dictParam(metadata: ["key": "value"])

        #expect(result1 == "dict matched")
        #expect(result2 == "specific dict matched")

        verify(mock, times: 1).dictParam(metadata: .any)
        verify(mock, times: 1).dictParam(metadata: ["key": "value"])
    }

    @Test
    func testSetParameters() {
        var expectations = MockTestComplexSendableService.Expectations()

        when(expectations.setParam(numbers: .any), return: "set matched")
        when(expectations.setParam(numbers: Set([1, 2, 3])), return: "specific set matched")

        let mock = MockTestComplexSendableService(expectations: expectations)

        let result1 = mock.setParam(numbers: Set([4, 5, 6]))
        let result2 = mock.setParam(numbers: Set([1, 2, 3]))

        #expect(result1 == "set matched")
        #expect(result2 == "specific set matched")

        verify(mock, times: 1).setParam(numbers: .any)
        verify(mock, times: 1).setParam(numbers: Set([1, 2, 3]))
    }

    // MARK: - Optional Collection Tests

    @Test
    func testOptionalCollectionParameters() {
        var expectations = MockTestComplexSendableService.Expectations()

        when(expectations.optionalArrayParam(strings: .any), return: "optional array matched")
        when(expectations.optionalArrayParam(strings: nil), return: "nil array matched")
        when(expectations.optionalDictParam(metadata: .any), return: "optional dict matched")

        let mock = MockTestComplexSendableService(expectations: expectations)

        let result1 = mock.optionalArrayParam(strings: ["test"])
        let result2 = mock.optionalArrayParam(strings: nil)
        let result3 = mock.optionalDictParam(metadata: ["key": "value"])

        #expect(result1 == "optional array matched")
        #expect(result2 == "nil array matched")
        #expect(result3 == "optional dict matched")

        verify(mock, times: 2).optionalArrayParam(strings: .any)
        verify(mock, times: 1).optionalArrayParam(strings: nil)
        verify(mock, times: 1).optionalDictParam(metadata: .any)
    }

    // MARK: - Nested Collection Tests

    @Test
    func testNestedCollectionParameters() {
        var expectations = MockTestComplexSendableService.Expectations()

        when(expectations.nestedArrayParam(matrix: .any), return: "nested array matched")
        when(expectations.arrayOfDictsParam(configs: .any), return: "array of dicts matched")

        let mock = MockTestComplexSendableService(expectations: expectations)

        let result1 = mock.nestedArrayParam(matrix: [[1, 2], [3, 4]])
        let result2 = mock.arrayOfDictsParam(configs: [["key1": "value1"], ["key2": "value2"]])

        #expect(result1 == "nested array matched")
        #expect(result2 == "array of dicts matched")

        verify(mock, times: 1).nestedArrayParam(matrix: .any)
        verify(mock, times: 1).arrayOfDictsParam(configs: .any)
    }

    // MARK: - Mixed Parameter Type Tests

    @Test
    func testMixedParametersWithCollections() {
        var expectations = MockTestComplexSendableService.Expectations()

        when(expectations.mixedWithArray(name: "test"..."zebra", items: .any, enabled: true),
             return: "mixed with array matched")
        when(expectations.mixedWithDict(count: 1...100, config: .any, data: .any),
             return: "mixed with dict matched")

        let mock = MockTestComplexSendableService(expectations: expectations)

        let result1 = mock.mixedWithArray(name: "value", items: ["item1", "item2"], enabled: true)
        let result2 = mock.mixedWithDict(count: 50, config: ["setting": "value"], data: Data([1, 2, 3]))

        #expect(result1 == "mixed with array matched")
        #expect(result2 == "mixed with dict matched")

        verify(mock, times: 1).mixedWithArray(name: "test"..."zebra", items: .any, enabled: true)
        verify(mock, times: 1).mixedWithDict(count: 1...100, config: .any, data: .any)
    }

    // MARK: - Generic Sendable Tests

    @Test
    func testGenericSendableParameters() {
        var expectations = MockTestComplexSendableService.Expectations()

        when(expectations.genericSendableParam(value: .any), return: "sendable matched")
        when(expectations.multipleSendableParams(first: .any, second: .any), return: "multiple sendable matched")

        let mock = MockTestComplexSendableService(expectations: expectations)

        // Test different Sendable types
        let result1 = mock.genericSendableParam(value: "string")
        let result2 = mock.genericSendableParam(value: 42)
        let result3 = mock.genericSendableParam(value: true)
        let result4 = mock.genericSendableParam(value: Data([1, 2, 3]))

        let result5 = mock.multipleSendableParams(first: "first", second: 123)
        let result6 = mock.multipleSendableParams(first: Data([4, 5]), second: false)

        #expect(result1 == "sendable matched")
        #expect(result2 == "sendable matched")
        #expect(result3 == "sendable matched")
        #expect(result4 == "sendable matched")
        #expect(result5 == "multiple sendable matched")
        #expect(result6 == "multiple sendable matched")

        verify(mock, times: 4).genericSendableParam(value: .any)
        verify(mock, times: 2).multipleSendableParams(first: .any, second: .any)
    }

    // MARK: - Specific Sendable Type Tests

    @Test
    func testSpecificSendableTypes() {
        var expectations = MockTestComplexSendableService.Expectations()

        let testUUID = UUID()
        let testURL = URL(string: "https://example.com")!
        let testDate = Date()

        when(expectations.uuidParam(id: .any), return: "uuid matched")
        when(expectations.uuidParam(id: testUUID), return: "specific uuid matched")
        when(expectations.urlParam(location: .any), return: "url matched")
        when(expectations.dateParam(timestamp: .any), return: "date matched")

        let mock = MockTestComplexSendableService(expectations: expectations)

        let result1 = mock.uuidParam(id: UUID())
        let result2 = mock.uuidParam(id: testUUID)
        let result3 = mock.urlParam(location: URL(string: "https://test.com")!)
        let result4 = mock.dateParam(timestamp: Date())

        #expect(result1 == "uuid matched")
        #expect(result2 == "specific uuid matched")
        #expect(result3 == "url matched")
        #expect(result4 == "date matched")

        verify(mock, times: 2).uuidParam(id: .any)
        verify(mock, times: 1).uuidParam(id: testUUID)
        verify(mock, times: 1).urlParam(location: .any)
        verify(mock, times: 1).dateParam(timestamp: .any)
    }

    // MARK: - Complex Mixed Parameter Tests

    @Test
    func testComplexMixedParameters() {
        var expectations = MockTestComplexSendableService.Expectations()

        when(expectations.complexMixedParams(
            name: "test"..."zebra",        // Comparable - range
            ids: .any,                     // Collection - any
            config: .any,                  // Collection - any
            enabled: true,                 // Bool - exact
            data: .any,                    // Non-comparable - any
            sendable: .any                 // Generic Sendable - any
        ), return: "complex mixed matched")

        let mock = MockTestComplexSendableService(expectations: expectations)

        let result = mock.complexMixedParams(
            name: "value",
            ids: [UUID(), UUID()],
            config: ["key1": "value1", "key2": "value2"],
            enabled: true,
            data: Data([1, 2, 3, 4]),
            sendable: "any sendable value"
        )

        #expect(result == "complex mixed matched")

        verify(mock, times: 1).complexMixedParams(
            name: "test"..."zebra",
            ids: .any,
            config: .any,
            enabled: true,
            data: .any,
            sendable: .any
        )
    }

    @Test
    func testComplexMixedParametersWithSpecificValues() {
        var expectations = MockTestComplexSendableService.Expectations()

        let specificUUIDs = [UUID(), UUID()]
        let specificConfig = ["setting1": "value1", "setting2": "value2"]

        when(expectations.complexMixedParams(
            name: "exact",                 // Comparable - exact
            ids: specificUUIDs,            // Collection - exact
            config: specificConfig,        // Collection - exact
            enabled: .any,                 // Bool - any
            data: .any,                    // Non-comparable - any
            sendable: .any                 // Generic Sendable - any
        ), return: "specific complex matched")

        let mock = MockTestComplexSendableService(expectations: expectations)

        let result = mock.complexMixedParams(
            name: "exact",
            ids: specificUUIDs,
            config: specificConfig,
            enabled: false,
            data: Data([5, 6, 7]),
            sendable: 42
        )

        #expect(result == "specific complex matched")

        verify(mock, times: 1).complexMixedParams(
            name: "exact",
            ids: specificUUIDs,
            config: specificConfig,
            enabled: .any,
            data: .any,
            sendable: .any
        )
    }

    // MARK: - Collection Value Matcher Edge Cases

    @Test
    func testEmptyCollections() {
        var expectations = MockTestComplexSendableService.Expectations()

        when(expectations.arrayParam(strings: []), return: "empty array matched")
        when(expectations.dictParam(metadata: [:]), return: "empty dict matched")
        when(expectations.setParam(numbers: Set()), return: "empty set matched")

        let mock = MockTestComplexSendableService(expectations: expectations)

        let result1 = mock.arrayParam(strings: [])
        let result2 = mock.dictParam(metadata: [:])
        let result3 = mock.setParam(numbers: Set())

        #expect(result1 == "empty array matched")
        #expect(result2 == "empty dict matched")
        #expect(result3 == "empty set matched")

        verify(mock, times: 1).arrayParam(strings: [])
        verify(mock, times: 1).dictParam(metadata: [:])
        verify(mock, times: 1).setParam(numbers: Set())
    }

    @Test
    func testLargeCollections() {
        var expectations = MockTestComplexSendableService.Expectations()

        let largeArray = Array(1...100).map { "item\($0)" }
        let largeDict = Dictionary(uniqueKeysWithValues: (1...50).map { ("key\($0)", "value\($0)") })
        let largeSet = Set(1...75)

        when(expectations.arrayParam(strings: .any), return: "large array handled")
        when(expectations.dictParam(metadata: .any), return: "large dict handled")
        when(expectations.setParam(numbers: .any), return: "large set handled")

        let mock = MockTestComplexSendableService(expectations: expectations)

        let result1 = mock.arrayParam(strings: largeArray)
        let result2 = mock.dictParam(metadata: largeDict)
        let result3 = mock.setParam(numbers: largeSet)

        #expect(result1 == "large array handled")
        #expect(result2 == "large dict handled")
        #expect(result3 == "large set handled")

        verify(mock, times: 1).arrayParam(strings: .any)
        verify(mock, times: 1).dictParam(metadata: .any)
        verify(mock, times: 1).setParam(numbers: .any)
    }

    // MARK: - Comprehensive Sendable Type Verification

    @Test
    func testComprehensiveSendableTypeVerification() {
        var expectations = MockTestComplexSendableService.Expectations()

        when(expectations.arrayParam(strings: .any), times: .unbounded, return: "array")
        when(expectations.dictParam(metadata: .any), times: .unbounded, return: "dict")
        when(expectations.setParam(numbers: .any), times: .unbounded, return: "set")
        when(expectations.genericSendableParam(value: .any), times: .unbounded, return: "sendable")
        when(expectations.uuidParam(id: .any), times: .unbounded, return: "uuid")

        let mock = MockTestComplexSendableService(expectations: expectations)

        // Execute multiple calls with different Sendable types
        _ = mock.arrayParam(strings: ["a", "b"])
        _ = mock.arrayParam(strings: ["c", "d"])
        _ = mock.dictParam(metadata: ["k1": "v1"])
        _ = mock.setParam(numbers: Set([1, 2]))
        _ = mock.genericSendableParam(value: "string")
        _ = mock.genericSendableParam(value: 42)
        _ = mock.genericSendableParam(value: true)
        _ = mock.uuidParam(id: UUID())

        // Test verification patterns
        verify(mock, times: 2).arrayParam(strings: .any)
        verify(mock, times: 1).dictParam(metadata: .any)
        verify(mock, times: 1).setParam(numbers: .any)
        verify(mock, times: 3).genericSendableParam(value: .any)
        verify(mock, times: 1).uuidParam(id: .any)

        // Test specific value verification
        verify(mock, times: 1).arrayParam(strings: ["a", "b"])
        verify(mock, times: 1).dictParam(metadata: ["k1": "v1"])
        verify(mock, times: 1).setParam(numbers: Set([1, 2]))
    }
}*/
