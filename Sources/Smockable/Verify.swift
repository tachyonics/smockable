//
//  Verify.swift
//  smockable
//

/// Protocol that all generated mocks will conform to for verification access
public protocol VerifiableSmock {
    associatedtype VerificationsType
    func getVerifications() -> VerificationsType
}

/// Global verify function that returns verification interface for a mock
/// 
/// This function provides a clean API for accessing mock verification data,
/// mirroring the pattern used by the `when()` function for setting expectations.
///
/// Example usage:
/// ```swift
/// let callCount = await verify(mock).fetchUser_id.callCount
/// let invocations = await verify(mock).fetchUser_id.receivedInvocations
/// ```
public func verify<T: VerifiableSmock>(_ mock: T) -> T.VerificationsType {
    return mock.getVerifications()
}