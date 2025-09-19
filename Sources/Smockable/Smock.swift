/// A macro that generates mock implementations for protocols.
///
/// The `@Smock` macro creates a mock class for any protocol, allowing you to set expectations
/// for method calls and property access during testing. The generated mock includes:
/// - An `Expectations` struct for configuring expected behavior
/// - Mock implementations of all protocol methods and properties
/// - Support for verifying call counts and parameters
///
/// ## Usage
///
/// Apply `@Smock` to any protocol:
/// ```swift
/// @Smock
/// protocol UserService {
///     func getUser(id: String) -> User
///     var isLoggedIn: Bool { get }
/// }
/// ```
///
/// This generates a `MockUserService` class that can be used in tests:
/// ```swift
/// var expectations = MockUserService.Expectations()
/// when(expectations.getUser(id: .any), return: testUser)
/// when(expectations.isLoggedIn.get(), return: true)
///
/// let mock = MockUserService(expectations: expectations)
/// let user = mock.getUser(id: "123")
/// verify(mock).getUser(id: "123")
/// ```
///
/// - Parameter name: Optional custom name for the generated mock class. 
///   If not provided, the mock will be named "Mock" + protocol name.
@attached(peer, names: prefixed(Mock))
public macro Smock(named name: String? = nil) =
    #externalMacro(
        module: "SmockMacro",
        type: "SmockMacro"
    )
