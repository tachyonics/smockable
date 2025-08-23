# Common Patterns

Real-world examples and patterns for using Smockable effectively.

## Overview

This guide provides practical examples of common testing scenarios and how to implement them with Smockable. These patterns are based on real-world usage and cover typical testing challenges you'll encounter.

## Repository Pattern Testing

### Basic Repository Mock

```swift
@Smock
protocol UserRepository {
    func findUser(by id: String) async throws -> User?
    func saveUser(_ user: User) async throws
    func deleteUser(id: String) async throws
    func findUsers(matching criteria: SearchCriteria) async throws -> [User]
}

@Test func userService() async throws {
    let expectations = MockUserRepository.Expectations()
    
    // Set up test data
    let testUser = User(id: "123", name: "John Doe", email: "john@example.com")
    
    expectations.findUser_by.value(testUser)
    expectations.saveUser.value(())
    expectations.deleteUser_id.value(())
    
    let mockRepo = MockUserRepository(expectations: expectations)
    let userService = UserService(repository: mockRepo)
    
    // Test user retrieval
    let user = try await userService.getUser(id: "123")
    #expect(user?.name == "John Doe")
    
    // Test user update
    var updatedUser = testUser
    updatedUser.name = "Jane Doe"
    try await userService.updateUser(updatedUser)
    
    // Verify interactions
    let findCount = await mockRepo.__verify.findUser_by.callCount
    let saveCount = await mockRepo.__verify.saveUser.callCount
    
    #expect(findCount == 1)
    #expect(saveCount == 1)
}
```

### Repository with Complex Queries

```swift
@Test func complexQueries() async throws {
    let expectations = MockUserRepository.Expectations()
    
    // Mock search functionality
    expectations.findUsers_matching.using { criteria in
        switch criteria.type {
        case .byName:
            return [User(id: "1", name: criteria.value, email: "test@example.com")]
        case .byEmail:
            return [User(id: "2", name: "Test User", email: criteria.value)]
        case .byRole:
            return [] // No users with this role
        }
    }
    
    let mockRepo = MockUserRepository(expectations: expectations)
    let userService = UserService(repository: mockRepo)
    
    // Test different search types
    let nameResults = try await userService.searchUsers(.byName("John"))
    let emailResults = try await userService.searchUsers(.byEmail("john@example.com"))
    let roleResults = try await userService.searchUsers(.byRole("admin"))
    
    #expect(nameResults.count == 1)
    #expect(emailResults.count == 1)
    #expect(roleResults.count == 0)
}
```

## Network Service Testing

### HTTP Client Mock

```swift
@Smock
protocol HTTPClient {
    func get(url: URL) async throws -> HTTPResponse
    func post(url: URL, body: Data) async throws -> HTTPResponse
    func put(url: URL, body: Data) async throws -> HTTPResponse
    func delete(url: URL) async throws -> HTTPResponse
}

@Test func apiService() async throws {
    let expectations = MockHTTPClient.Expectations()
    
    // Mock successful responses
    let successResponse = HTTPResponse(statusCode: 200, data: """
        {"id": "123", "name": "John Doe"}
        """.data(using: .utf8)!)
    
    expectations.get_url.value(successResponse)
    expectations.post_url_body.value(HTTPResponse(statusCode: 201, data: Data()))
    
    let mockClient = MockHTTPClient(expectations: expectations)
    let apiService = APIService(httpClient: mockClient)
    
    // Test GET request
    let user = try await apiService.fetchUser(id: "123")
    #expect(user.name == "John Doe")
    
    // Test POST request
    try await apiService.createUser(name: "Jane Doe", email: "jane@example.com")
    
    // Verify requests were made correctly
    let getInputs = await mockClient.__verify.get_url.receivedInputs
    let postInputs = await mockClient.__verify.post_url_body.receivedInputs
    
    #expect(getInputs[0].url.path == "/users/123")
    #expect(postInputs[0].url.path == "/users")
}
```

### Network Error Scenarios

```swift
@Test func networkErrorHandling() async throws {
    let expectations = MockHTTPClient.Expectations()
    
    // Simulate various network conditions
    expectations.get_url
        .error(NetworkError.connectionFailed).times(2)  // First 2 attempts fail
        .error(NetworkError.timeout)                     // Third attempt times out
        .value(HTTPResponse(statusCode: 500, data: Data())) // Server error
        .value(HTTPResponse(statusCode: 200, data: validData)) // Finally succeeds
    
    let mockClient = MockHTTPClient(expectations: expectations)
    let apiService = APIServiceWithRetry(httpClient: mockClient)
    
    // This should eventually succeed after retries
    let result = try await apiService.fetchUserWithRetry(id: "123")
    #expect(result != nil)
    
    // Verify retry attempts
    let callCount = await mockClient.__verify.get_url.callCount
    #expect(callCount == 5) // 4 failures + 1 success
}
```

## Authentication Service Testing

### Login Flow Testing

```swift
@Smock
protocol AuthenticationService {
    func login(username: String, password: String) async throws -> AuthToken
    func refreshToken(_ token: AuthToken) async throws -> AuthToken
    func logout(token: AuthToken) async throws
    func validateToken(_ token: AuthToken) async -> Bool
}

@Test func loginFlow() async throws {
    let expectations = MockAuthenticationService.Expectations()
    
    let validToken = AuthToken(value: "valid-token", expiresAt: Date().addingTimeInterval(3600))
    
    // Mock successful login
    expectations.login_username_password.using { username, password in
        guard username == "testuser" && password == "testpass" else {
            throw AuthError.invalidCredentials
        }
        return validToken
    }
    
    expectations.validateToken.value(true)
    
    let mockAuth = MockAuthenticationService(expectations: expectations)
    let authManager = AuthenticationManager(service: mockAuth)
    
    // Test successful login
    let token = try await authManager.login(username: "testuser", password: "testpass")
    #expect(token.value == "valid-token")
    
    // Test token validation
    let isValid = await authManager.isTokenValid(token)
    #expect(isValid)
    
    // Verify login was called with correct credentials
    let loginInputs = await mockAuth.__verify.login_username_password.receivedInputs
    #expect(loginInputs[0].username == "testuser")
    #expect(loginInputs[0].password == "testpass")
}
```

### Token Refresh Testing

```swift
@Test func tokenRefresh() async throws {
    let expectations = MockAuthenticationService.Expectations()
    
    let expiredToken = AuthToken(value: "expired-token", expiresAt: Date().addingTimeInterval(-3600))
    let newToken = AuthToken(value: "new-token", expiresAt: Date().addingTimeInterval(3600))
    
    expectations.validateToken
        .value(false)  // Token is expired
        .value(true)   // New token is valid
    
    expectations.refreshToken.value(newToken)
    
    let mockAuth = MockAuthenticationService(expectations: expectations)
    let authManager = AuthenticationManager(service: mockAuth)
    
    // This should automatically refresh the token
    let validToken = try await authManager.ensureValidToken(expiredToken)
    #expect(validToken.value == "new-token")
    
    // Verify refresh was called
    let refreshCount = await mockAuth.__verify.refreshToken.callCount
    #expect(refreshCount == 1)
}
```

## Data Persistence Testing

### Core Data Service Mock

```swift
@Smock
protocol DataPersistenceService {
    func save<T: Codable>(_ object: T, key: String) async throws
    func load<T: Codable>(_ type: T.Type, key: String) async throws -> T?
    func delete(key: String) async throws
    func exists(key: String) async -> Bool
}

@Test func dataPersistence() async throws {
    let expectations = MockDataPersistenceService.Expectations()
    
    // Mock storage behavior
    var storage: [String: Data] = [:]
    
    expectations.save_object_key.using { (object: Any, key: String) in
        let data = try JSONEncoder().encode(object as! Codable)
        storage[key] = data
    }.unboundedTimes()
    
    expectations.load_type_key.using { (type: Any.Type, key: String) in
        guard let data = storage[key] else { return nil }
        return try JSONDecoder().decode(type as! Codable.Type, from: data)
    }.unboundedTimes()
    
    expectations.exists_key.using { key in
        return storage.keys.contains(key)
    }.unboundedTimes()
    
    expectations.delete_key.using { key in
        storage.removeValue(forKey: key)
    }.unboundedTimes()
    
    let mockPersistence = MockDataPersistenceService(expectations: expectations)
    let dataManager = DataManager(persistence: mockPersistence)
    
    // Test save and load
    let testUser = User(id: "123", name: "John Doe")
    try await dataManager.saveUser(testUser)
    
    let loadedUser: User? = try await dataManager.loadUser(id: "123")
    #expect(loadedUser?.name == "John Doe")
    
    // Test existence check
    let exists = await dataManager.userExists(id: "123")
    #expect(exists)
}
```

## Notification Service Testing

### Push Notification Mock

```swift
@Smock
protocol NotificationService {
    func sendNotification(to userID: String, message: String) async throws
    func scheduleNotification(for date: Date, message: String) async throws -> String
    func cancelNotification(id: String) async throws
    func getDeliveredNotifications() async throws -> [DeliveredNotification]
}

@Test func notificationDelivery() async throws {
    let expectations = MockNotificationService.Expectations()
    
    // Track sent notifications
    var sentNotifications: [(userID: String, message: String)] = []
    var scheduledNotifications: [String: (date: Date, message: String)] = [:]
    
    expectations.sendNotification_to_message.using { userID, message in
        sentNotifications.append((userID: userID, message: message))
    }.unboundedTimes()
    
    expectations.scheduleNotification_for_message.using { date, message in
        let id = UUID().uuidString
        scheduledNotifications[id] = (date: date, message: message)
        return id
    }.unboundedTimes()
    
    let mockNotifications = MockNotificationService(expectations: expectations)
    let notificationManager = NotificationManager(service: mockNotifications)
    
    // Test immediate notification
    try await notificationManager.notifyUser("123", message: "Hello!")
    
    // Test scheduled notification
    let futureDate = Date().addingTimeInterval(3600)
    let notificationID = try await notificationManager.scheduleReminder(
        for: futureDate, 
        message: "Don't forget!"
    )
    
    // Verify notifications were processed
    #expect(sentNotifications.count == 1)
    #expect(sentNotifications[0].userID == "123")
    #expect(sentNotifications[0].message == "Hello!")
    
    #expect(scheduledNotifications.count == 1)
    #expect(scheduledNotifications[notificationID] != nil)
}
```

## File System Testing

### File Manager Mock

```swift
@Smock
protocol FileManagerProtocol {
    func fileExists(at path: String) -> Bool
    func createDirectory(at path: String) throws
    func writeData(_ data: Data, to path: String) throws
    func readData(from path: String) throws -> Data
    func deleteFile(at path: String) throws
}

@Test func fileOperations() throws {
    let expectations = MockFileManagerProtocol.Expectations()
    
    // Simulate file system state
    var fileSystem: [String: Data] = [:]
    var directories: Set<String> = []
    
    expectations.fileExists_at.using { path in
        return fileSystem.keys.contains(path)
    }.unboundedTimes()
    
    expectations.createDirectory_at.using { path in
        directories.insert(path)
    }.unboundedTimes()
    
    expectations.writeData_to.using { data, path in
        fileSystem[path] = data
    }.unboundedTimes()
    
    expectations.readData_from.using { path in
        guard let data = fileSystem[path] else {
            throw FileError.fileNotFound
        }
        return data
    }.unboundedTimes()
    
    expectations.deleteFile_at.using { path in
        guard fileSystem.removeValue(forKey: path) != nil else {
            throw FileError.fileNotFound
        }
    }.unboundedTimes()
    
    let mockFileManager = MockFileManagerProtocol(expectations: expectations)
    let fileService = FileService(fileManager: mockFileManager)
    
    // Test file operations
    let testData = "Hello, World!".data(using: .utf8)!
    let testPath = "/tmp/test.txt"
    
    try fileService.saveFile(data: testData, path: testPath)
    
    let exists = fileService.fileExists(at: testPath)
    #expect(exists)
    
    let loadedData = try fileService.loadFile(from: testPath)
    #expect(loadedData == testData)
}
```

## Testing Best Practices

### 1. Use Factory Methods for Test Data

```swift
extension User {
    static func testUser(
        id: String = "test-123",
        name: String = "Test User",
        email: String = "test@example.com"
    ) -> User {
        return User(id: id, name: name, email: email)
    }
}

// Usage
let user1 = User.testUser()
let user2 = User.testUser(name: "Different User")
```

### 2. Create Reusable Expectation Builders

```swift
extension MockUserRepository.Expectations {
    func withSuccessfulOperations() -> Self {
        self.findUser_by.value(User.testUser())
        self.saveUser.value(())
        self.deleteUser_id.value(())
        return self
    }
    
    func withNetworkErrors() -> Self {
        self.findUser_by.error(NetworkError.connectionFailed)
        self.saveUser.error(NetworkError.timeout)
        return self
    }
}

// Usage
let expectations = MockUserRepository.Expectations().withSuccessfulOperations()
```

### 3. Group Related Tests

```swift
@Suite struct UserServiceTests {
    var mockRepository: MockUserRepository!
    var userService: UserService!
    
    init() {
        let expectations = MockUserRepository.Expectations()
        mockRepository = MockUserRepository(expectations: expectations)
        userService = UserService(repository: mockRepository)
    }
    
    @Test func userRetrieval() async throws {
        // Test user retrieval scenarios
    }
    
    @Test func userCreation() async throws {
        // Test user creation scenarios
    }
    
    @Test func errorHandling() async throws {
        // Test error scenarios
    }
}
```

## Next Steps

- Learn about <doc:AdvancedPatterns> for complex scenarios
- Explore <doc:BestPractices> for testing strategy recommendations
- See <doc:TestingStrategies> for comprehensive testing approaches