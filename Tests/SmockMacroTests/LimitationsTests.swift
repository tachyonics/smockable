import Foundation
import Testing

@testable import Smockable

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct LimitationsTests {

    // MARK: - Test Data Structures

    struct UserData: Codable, Equatable {
        let id: String
        let name: String
    }

    enum AuthError: Error {
        case invalidToken
    }

    enum NetworkError: Error {
        case notFound
    }

    // MARK: - Limitation 1: Inherited Protocol Requirements Tests

    /// Base protocol that will be inherited from
    protocol BaseService {
        func connect() async throws
        func disconnect() async throws
        func getConnectionStatus() async -> Bool
    }

    /// Protocol that inherits from BaseService and mirrors all requirements
    @Smock
    protocol DataService: BaseService {
        // Mirror all inherited requirements
        func connect() async throws
        func disconnect() async throws
        func getConnectionStatus() async -> Bool

        // Add new requirements
        func fetchData() async throws -> Data
        func saveData(_ data: Data) async throws
    }

    @Test("Inherited protocol workaround functions correctly")
    func testInheritedProtocolWorkaround() async throws {
        var expectations = MockDataService.Expectations()

        // Now all methods are available
        when(expectations.connect(), complete: .withSuccess)
        when(expectations.disconnect(), complete: .withSuccess)
        when(expectations.getConnectionStatus(), return: true)
        when(expectations.fetchData(), return: "test data".data(using: .utf8)!)
        when(expectations.saveData(.any), complete: .withSuccess)

        let mock = MockDataService(expectations: expectations)

        try await mock.connect()
        let connected = await mock.getConnectionStatus()
        #expect(connected == true)

        let data = try await mock.fetchData()
        try await mock.saveData(data)
        try await mock.disconnect()

        // Verify all methods were called
        verify(mock, times: 1).connect()
        verify(mock, times: 1).disconnect()
        verify(mock, times: 1).getConnectionStatus()
        verify(mock, times: 1).fetchData()
        verify(mock, times: 1).saveData(.any)
    }

    // MARK: - Limitation 2: External Protocol Dependencies Tests

    protocol ExternalNetworkService {
        func handleDataReceived(_ data: Data) async
        func handleRequestCompleted(error: Error?) async
    }

    /// Mock protocol that mirrors URLSessionDataDelegate methods we need
    @Smock
    protocol MyNetworkService: ExternalNetworkService {
        // Mirror external requirements you need
        func handleDataReceived(_ data: Data) async
        func handleRequestCompleted(error: Error?) async

        // Add your own requirements
        func performRequest() async throws -> Data
        func configure(with url: URL) async
    }

    func tester<Service: ExternalNetworkService>(service: Service) {

    }

    @Test("External protocol workaround functions correctly")
    func testExternalProtocolWorkaround() async throws {
        var expectations = MockMyNetworkService.Expectations()

        // Configure external protocol methods
        when(expectations.handleDataReceived(.any), complete: .withSuccess)
        when(expectations.handleRequestCompleted(error: .any), complete: .withSuccess)

        // Configure your own methods
        when(expectations.performRequest(), return: "response data".data(using: .utf8)!)
        when(expectations.configure(with: .any), complete: .withSuccess)

        let mock = MockMyNetworkService(expectations: expectations)
        tester(service: mock)

        // Test external protocol behavior
        await mock.handleDataReceived("test data".data(using: .utf8)!)
        await mock.handleRequestCompleted(error: nil)

        // Test your own behavior
        await mock.configure(with: URL(string: "https://api.example.com")!)
        let data = try await mock.performRequest()

        #expect(data.count > 0)

        // Verify all methods were called
        verify(mock, times: 1).handleDataReceived(.any)
        verify(mock, times: 1).handleRequestCompleted(error: .any)
        verify(mock, times: 1).configure(with: .any)
        verify(mock, times: 1).performRequest()
    }

    // MARK: - Limitation 3: Multiple Protocol Inheritance Tests

    protocol Authenticatable {
        func authenticate(token: String) async throws -> Bool
    }

    protocol Cacheable {
        func cache(key: String, value: Data) async
        func getCached(key: String) async -> Data?
    }

    @Smock
    protocol SecureDataService: Authenticatable, Cacheable {
        // Mirror Authenticatable requirements
        func authenticate(token: String) async throws -> Bool

        // Mirror Cacheable requirements
        func cache(key: String, value: Data) async
        func getCached(key: String) async -> Data?

        // Add new requirements
        func securelyFetchData(id: String) async throws -> Data
    }

    @Test("Multiple inheritance workaround functions correctly")
    func testMultipleInheritanceWorkaround() async throws {
        var expectations = MockSecureDataService.Expectations()

        // Configure methods from all parent protocols
        when(expectations.authenticate(token: .any), return: true)
        when(expectations.cache(key: .any, value: .any), complete: .withSuccess)
        when(expectations.getCached(key: .any), return: "cached data".data(using: .utf8)!)
        when(expectations.securelyFetchData(id: .any), return: "secure data".data(using: .utf8)!)

        let mock = MockSecureDataService(expectations: expectations)

        // Test all inherited functionality
        let isAuthenticated = try await mock.authenticate(token: "valid-token")
        #expect(isAuthenticated == true)

        await mock.cache(key: "test", value: Data())
        let cachedData = await mock.getCached(key: "test")
        #expect(cachedData != nil)

        let secureData = try await mock.securelyFetchData(id: "123")
        #expect(secureData.count > 0)

        // Verify all methods were called
        verify(mock, times: 1).authenticate(token: .any)
        verify(mock, times: 1).cache(key: .any, value: .any)
        verify(mock, times: 1).getCached(key: .any)
        verify(mock, times: 1).securelyFetchData(id: .any)
    }

    // MARK: - Best Practice 1: Composition Tests

    @Smock
    protocol ConnectionManaging {
        func connect() async throws
        func disconnect() async throws
        func isConnected() async -> Bool
    }

    @Smock
    protocol DataReading {
        func find(id: String) async throws -> Data?
        func findAll() async throws -> [Data]
    }

    @Smock
    protocol DataWriting {
        func save(id: String, data: Data) async throws
        func delete(id: String) async throws
    }

    // Compose behaviors instead of inheriting
    class Repository {
        private let connectionManager: ConnectionManaging
        private let dataReader: DataReading
        private let dataWriter: DataWriting

        init(
            connectionManager: ConnectionManaging,
            dataReader: DataReading,
            dataWriter: DataWriting
        ) {
            self.connectionManager = connectionManager
            self.dataReader = dataReader
            self.dataWriter = dataWriter
        }

        func performTransaction<T>(operation: () async throws -> T) async throws -> T {
            try await connectionManager.connect()
            let result = try await operation()
            try await connectionManager.disconnect()
            return result
        }
    }

    @Test("Composition approach works correctly")
    func testCompositionApproach() async throws {
        var connectionExpectations = MockConnectionManaging.Expectations()
        var readExpectations = MockDataReading.Expectations()
        var writeExpectations = MockDataWriting.Expectations()

        when(connectionExpectations.connect(), complete: .withSuccess)
        when(connectionExpectations.disconnect(), complete: .withSuccess)
        when(connectionExpectations.isConnected(), return: true)
        when(readExpectations.find(id: .any), return: "test data".data(using: .utf8)!)
        when(writeExpectations.save(id: .any, data: .any), complete: .withSuccess)

        let mockConnection = MockConnectionManaging(expectations: connectionExpectations)
        let mockReader = MockDataReading(expectations: readExpectations)
        let mockWriter = MockDataWriting(expectations: writeExpectations)

        let repository = Repository(
            connectionManager: mockConnection,
            dataReader: mockReader,
            dataWriter: mockWriter
        )

        let result = try await repository.performTransaction {
            let data = try await mockReader.find(id: "123")
            try await mockWriter.save(id: "456", data: data ?? Data())
            return "success"
        }

        #expect(result == "success")

        // Verify the transaction workflow
        verify(mockConnection, times: 1).connect()
        verify(mockConnection, times: 1).disconnect()
        verify(mockReader, times: 1).find(id: .any)
        verify(mockWriter, times: 1).save(id: .any, data: .any)
    }

    // MARK: - Best Practice 2: Wrapper Protocol Tests

    @Smock
    protocol NetworkDataHandler: Sendable {
        // Only include the methods you actually use
        func handleReceivedData(_ data: Data) async
        func handleCompletion(error: Error?) async
    }

    // Adapter to bridge between external protocol and your wrapper
    final class NetworkAdapter: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        private let handler: NetworkDataHandler
        var task: Task<Void, Never>?

        init(handler: NetworkDataHandler) {
            self.handler = handler
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            self.task = Task { await handler.handleReceivedData(data) }
        }
    }

    @Test("Network adapter wrapper approach works correctly")
    func testNetworkAdapter() async throws {
        var expectations = MockNetworkDataHandler.Expectations()
        when(expectations.handleReceivedData(.any), complete: .withSuccess)

        let mockHandler = MockNetworkDataHandler(expectations: expectations)
        let adapter = NetworkAdapter(handler: mockHandler)

        // Test the adapter
        let session = URLSession.shared
        let task = session.dataTask(with: URL(string: "https://example.com")!)
        adapter.urlSession(session, dataTask: task, didReceive: Data())

        // Wait until the task has completed
        await adapter.task?.value

        verify(mockHandler, times: 1).handleReceivedData(.any)
    }

    // MARK: - Unhappy Path Tests

    #if SMOCKABLE_UNHAPPY_PATH_TESTING
    @Test
    func testInheritedProtocolVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected connect() to be called exactly 2 times, but was called 1 time"
        ]) {
            var expectations = MockDataService.Expectations()
            when(expectations.connect(), complete: .withSuccess)

            let mock = MockDataService(expectations: expectations)

            // Call once but verify twice - should fail
            try? await mock.connect()

            verify(mock, times: 2).connect()
        }
    }

    @Test
    func testMultipleInheritanceVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected authenticate(token: any) to never be called, but was called 1 time",
            "Expected cache(key: any, value: any) to be called at least 2 times, but was called 1 time",
        ]) {
            var expectations = MockSecureDataService.Expectations()
            when(expectations.authenticate(token: .any), return: true)
            when(expectations.cache(key: .any, value: .any), complete: .withSuccess)

            let mock = MockSecureDataService(expectations: expectations)

            // Call each once
            _ = try? await mock.authenticate(token: "token")
            await mock.cache(key: "key", value: Data())

            // Two failing verifications
            verify(mock, .never).authenticate(token: .any)  // Fail 1
            verify(mock, atLeast: 2).cache(key: .any, value: .any)  // Fail 2
        }
    }

    @Test
    func testCompositionApproachVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected connect() to be called at most 0 times, but was called 1 time"
        ]) {
            var connectionExpectations = MockConnectionManaging.Expectations()
            when(connectionExpectations.connect(), complete: .withSuccess)
            when(connectionExpectations.disconnect(), complete: .withSuccess)

            let mockConnection = MockConnectionManaging(expectations: connectionExpectations)
            let mockReader = MockDataReading(expectations: .init())
            let mockWriter = MockDataWriting(expectations: .init())

            let repository = Repository(
                connectionManager: mockConnection,
                dataReader: mockReader,
                dataWriter: mockWriter
            )

            // Perform transaction which calls connect
            _ = try? await repository.performTransaction {
                return "test"
            }

            // Verify connect was never called - should fail
            verify(mockConnection, atMost: 0).connect()
        }
    }

    @Test
    func testNetworkAdapterVerificationFailures() async {
        await expectVerificationFailures(messages: [
            "Expected handleReceivedData(_ data: any) to be called exactly 2 times, but was called 1 time"
        ]) {
            var expectations = MockNetworkDataHandler.Expectations()
            when(expectations.handleReceivedData(.any), complete: .withSuccess)

            let mockHandler = MockNetworkDataHandler(expectations: expectations)
            let adapter = NetworkAdapter(handler: mockHandler)

            // Call once through adapter
            let session = URLSession.shared
            let task = session.dataTask(with: URL(string: "https://example.com")!)
            adapter.urlSession(session, dataTask: task, didReceive: Data())

            // Wait for completion
            await adapter.task?.value

            // Verify called twice - should fail
            verify(mockHandler, times: 2).handleReceivedData(.any)
        }
    }
    #endif
}
