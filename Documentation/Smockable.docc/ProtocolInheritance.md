# Protocol Inheritance

Working with protocol inheritance and composition in Smockable.

## Overview

Smockable fully supports Swift protocol inheritance, allowing you to create mocks for protocols that inherit from other protocols. This enables testing of complex protocol hierarchies and compositions.

## Basic Protocol Inheritance

### Single Inheritance

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
    
    // Use inherited methods
    try await mock.connect()
    let connected = mock.isConnected
    XCTAssertTrue(connected)
    
    // Use protocol-specific methods
    let data = try await mock.fetchData()
    try await mock.saveData(data)
    
    await mock.disconnect()
}
```

### Multiple Protocol Inheritance

```swift
@Smock
protocol Authenticatable {
    func authenticate(token: String) async throws -> Bool
}

@Smock
protocol Cacheable {
    func cache(key: String, value: Data) async
    func getCached(key: String) async -> Data?
}

@Smock
protocol SecureDataService: Authenticatable, Cacheable {
    func securelyFetchData(id: String) async throws -> Data
}

func testMultipleInheritance() async throws {
    let expectations = MockSecureDataService.Expectations()
    
    // Configure methods from all inherited protocols
    expectations.authenticate_token.value(true)
    expectations.cache_key_value.success()
    expectations.getCached_key.value("cached data".data(using: .utf8)!)
    expectations.securelyFetchData_id.value("secure data".data(using: .utf8)!)
    
    let mock = MockSecureDataService(expectations: expectations)
    
    // Test all inherited functionality
    let isAuthenticated = try await mock.authenticate(token: "valid-token")
    XCTAssertTrue(isAuthenticated)
    
    await mock.cache(key: "test", value: Data())
    let cachedData = await mock.getCached(key: "test")
    XCTAssertNotNil(cachedData)
    
    let secureData = try await mock.securelyFetchData(id: "123")
    XCTAssertNotNil(secureData)
}
```

## Protocol Composition

### Dependency Injection with Multiple Protocols

```swift
class UserManager {
    private let authService: Authenticatable
    private let dataService: DataService
    private let cacheService: Cacheable
    
    init(
        authService: Authenticatable,
        dataService: DataService,
        cacheService: Cacheable
    ) {
        self.authService = authService
        self.dataService = dataService
        self.cacheService = cacheService
    }
    
    func getUserData(token: String, userId: String) async throws -> UserData {
        // Authenticate first
        guard try await authService.authenticate(token: token) else {
            throw AuthError.invalidToken
        }
        
        // Check cache
        if let cachedData = await cacheService.getCached(key: userId),
           let userData = try? JSONDecoder().decode(UserData.self, from: cachedData) {
            return userData
        }
        
        // Fetch from data service
        try await dataService.connect()
        let data = try await dataService.fetchData()
        let userData = try JSONDecoder().decode(UserData.self, from: data)
        
        // Cache the result
        let encodedData = try JSONEncoder().encode(userData)
        await cacheService.cache(key: userId, value: encodedData)
        
        return userData
    }
}

func testUserManagerWithMultipleProtocols() async throws {
    // Set up separate mocks for each protocol
    let authExpectations = MockAuthenticatable.Expectations()
    let dataExpectations = MockDataService.Expectations()
    let cacheExpectations = MockCacheable.Expectations()
    
    let userData = UserData(id: "123", name: "John Doe")
    let encodedUserData = try JSONEncoder().encode(userData)
    
    authExpectations.authenticate_token.value(true)
    dataExpectations.connect.success()
    dataExpectations.fetchData.value(encodedUserData)
    cacheExpectations.getCached_key.value(nil) // Cache miss
    cacheExpectations.cache_key_value.success()
    
    let mockAuth = MockAuthenticatable(expectations: authExpectations)
    let mockData = MockDataService(expectations: dataExpectations)
    let mockCache = MockCacheable(expectations: cacheExpectations)
    
    let userManager = UserManager(
        authService: mockAuth,
        dataService: mockData,
        cacheService: mockCache
    )
    
    let result = try await userManager.getUserData(token: "valid", userId: "123")
    
    XCTAssertEqual(result.name, "John Doe")
    
    // Verify all services were used
    XCTAssertEqual(await mockAuth.__verify.authenticate_token.callCount, 1)
    XCTAssertEqual(await mockData.__verify.fetchData.callCount, 1)
    XCTAssertEqual(await mockCache.__verify.cache_key_value.callCount, 1)
}
```

## Complex Inheritance Hierarchies

### Deep Inheritance Chains

```swift
@Smock
protocol BaseRepository {
    func connect() async throws
    func disconnect() async throws
}

@Smock
protocol ReadableRepository: BaseRepository {
    func find(id: String) async throws -> Data?
    func findAll() async throws -> [Data]
}

@Smock
protocol WritableRepository: ReadableRepository {
    func save(id: String, data: Data) async throws
    func delete(id: String) async throws
}

@Smock
protocol TransactionalRepository: WritableRepository {
    func beginTransaction() async throws
    func commitTransaction() async throws
    func rollbackTransaction() async throws
}

func testDeepInheritanceChain() async throws {
    let expectations = MockTransactionalRepository.Expectations()
    
    // Configure all methods from the inheritance chain
    expectations.connect.success()
    expectations.disconnect.success()
    expectations.find_id.value("test data".data(using: .utf8)!)
    expectations.findAll.value([Data()])
    expectations.save_id_data.success()
    expectations.delete_id.success()
    expectations.beginTransaction.success()
    expectations.commitTransaction.success()
    expectations.rollbackTransaction.success()
    
    let mock = MockTransactionalRepository(expectations: expectations)
    
    // Test transactional workflow
    try await mock.connect()
    try await mock.beginTransaction()
    
    let data = try await mock.find(id: "123")
    XCTAssertNotNil(data)
    
    try await mock.save(id: "456", data: Data())
    try await mock.commitTransaction()
    
    try await mock.disconnect()
    
    // Verify the complete workflow
    XCTAssertEqual(await mock.__verify.connect.callCount, 1)
    XCTAssertEqual(await mock.__verify.beginTransaction.callCount, 1)
    XCTAssertEqual(await mock.__verify.find_id.callCount, 1)
    XCTAssertEqual(await mock.__verify.save_id_data.callCount, 1)
    XCTAssertEqual(await mock.__verify.commitTransaction.callCount, 1)
    XCTAssertEqual(await mock.__verify.disconnect.callCount, 1)
}
```

## Protocol Extensions and Default Implementations

### Testing with Protocol Extensions

```swift
@Smock
protocol NetworkService {
    func makeRequest(url: URL) async throws -> Data
}

extension NetworkService {
    func makeGETRequest(path: String) async throws -> Data {
        let url = URL(string: "https://api.example.com/\(path)")!
        return try await makeRequest(url: url)
    }
    
    func makePOSTRequest(path: String, body: Data) async throws -> Data {
        let url = URL(string: "https://api.example.com/\(path)")!
        // In real implementation, this would include the body
        return try await makeRequest(url: url)
    }
}

func testProtocolExtensions() async throws {
    let expectations = MockNetworkService.Expectations()
    
    // Only need to mock the base protocol method
    expectations.makeRequest_url.using { url in
        if url.path.contains("users") {
            return """
            {"users": [{"id": "123", "name": "John"}]}
            """.data(using: .utf8)!
        } else {
            return Data()
        }
    }.unboundedTimes()
    
    let mock = MockNetworkService(expectations: expectations)
    
    // Test extension methods
    let userData = try await mock.makeGETRequest(path: "users")
    let postResult = try await mock.makePOSTRequest(path: "users", body: Data())
    
    XCTAssertNotNil(userData)
    XCTAssertNotNil(postResult)
    
    // Verify the underlying method was called
    XCTAssertEqual(await mock.__verify.makeRequest_url.callCount, 2)
    
    let receivedURLs = await mock.__verify.makeRequest_url.receivedInputs
    XCTAssertTrue(receivedURLs.allSatisfy { $0.url.host == "api.example.com" })
}
```

## Best Practices for Protocol Inheritance

### 1. Keep Inheritance Hierarchies Focused

```swift
// Good: Focused, single-responsibility protocols
@Smock
protocol Readable {
    func read(id: String) async throws -> Data
}

@Smock
protocol Writable {
    func write(id: String, data: Data) async throws
}

@Smock
protocol ReadWritable: Readable, Writable {
    // Combines focused protocols
}

// Avoid: Overly broad base protocols
@Smock
protocol MegaService {
    func read(id: String) async throws -> Data
    func write(id: String, data: Data) async throws
    func authenticate(token: String) async throws -> Bool
    func log(message: String) async
    func cache(key: String, value: Data) async
    // Too many responsibilities
}
```

### 2. Use Composition Over Deep Inheritance

```swift
// Good: Composition approach
class DataManager {
    private let reader: Readable
    private let writer: Writable
    private let authenticator: Authenticatable
    
    init(reader: Readable, writer: Writable, authenticator: Authenticatable) {
        self.reader = reader
        self.writer = writer
        self.authenticator = authenticator
    }
}

// Avoid: Deep inheritance chains
@Smock
protocol Level1: BaseProtocol { }
@Smock
protocol Level2: Level1 { }
@Smock
protocol Level3: Level2 { }
@Smock
protocol Level4: Level3 { }
// Too deep - hard to understand and maintain
```

### 3. Test Each Level of Inheritance

```swift
class ProtocolInheritanceTests: XCTestCase {
    
    func testBaseProtocolFunctionality() async throws {
        // Test just the base protocol methods
        let expectations = MockBaseService.Expectations()
        expectations.connect.success()
        
        let mock = MockBaseService(expectations: expectations)
        try await mock.connect()
        
        XCTAssertEqual(await mock.__verify.connect.callCount, 1)
    }
    
    func testDerivedProtocolFunctionality() async throws {
        // Test the derived protocol including inherited methods
        let expectations = MockDataService.Expectations()
        expectations.connect.success() // Inherited
        expectations.fetchData.value(Data()) // New method
        
        let mock = MockDataService(expectations: expectations)
        try await mock.connect()
        let data = try await mock.fetchData()
        
        XCTAssertNotNil(data)
    }
    
    func testProtocolInteraction() async throws {
        // Test how inherited and new methods work together
        let expectations = MockDataService.Expectations()
        expectations.connect.success()
        expectations.fetchData.using { 
            // Only return data if connected
            return "connected data".data(using: .utf8)!
        }
        
        let mock = MockDataService(expectations: expectations)
        
        try await mock.connect()
        let data = try await mock.fetchData()
        
        XCTAssertNotNil(data)
    }
}
```

## Next Steps

- Learn about <doc:AssociatedTypes> for generic protocol support
