//
//  Verify.swift
//  smockable
//

import Foundation
import Testing

#if SMOCKABLE_UNHAPPY_PATH_TESTING
import Synchronization
#endif

public typealias SourceLocation = Testing.SourceLocation

/// Verification modes for specifying how many times a mock interaction should have occurred.
///
/// Use these modes with the `verify()` function to assert that mock methods or properties
/// were called the expected number of times during testing.
///
/// ## Example
/// ```swift
/// verify(mock, .times(2)).getUser(id: .any)
/// verify(mock, .atLeast(1)).saveData()
/// verify(mock, .never).deleteAll()
/// ```
public enum VerificationMode {
    /// Verifies the interaction occurred exactly the specified number of times.
    case times(Int)
    /// Verifies the interaction occurred at least the specified number of times.
    case atLeast(Int)
    /// Verifies the interaction occurred at most the specified number of times.
    case atMost(Int)
    /// Verifies the interaction never occurred (0 times).
    case never
    /// Verifies the interaction occurred at least once (>= 1).
    case atLeastOnce
    /// Verifies the interaction occurred within the specified range of times.
    case range(ClosedRange<Int>)
}

private func times<IntegerType: BinaryInteger>(_ count: IntegerType) -> String {
    if count == 1 {
        return "1 time"
    } else {
        return "\(count) times"
    }
}

/// Helper utility for performing verification assertions in mock testing.
///
/// This struct provides internal functionality for handling verification failures
/// and integrating with the testing framework.
/// Users of mocks shouldn't interact with this type directly.
public struct VerificationHelper {
    private static func handleExpectation(
        condition: Bool,
        message: String,
        sourceLocation: SourceLocation
    ) {
        #if SMOCKABLE_UNHAPPY_PATH_TESTING
        if let recorder = failureRecorder {
            if !condition {
                recorder.record(
                    FailureRecord(
                        message: message,
                        sourceLocation: sourceLocation
                    )
                )
            }

            return
        }
        #endif

        #expect(condition, "\(message)", sourceLocation: sourceLocation)
    }

    public static func performVerification(
        mode: VerificationMode,
        matchingCount: Int,
        functionName: String,
        sourceLocation: SourceLocation
    ) {
        switch mode {
        case .times(let expected):
            handleExpectation(
                condition: matchingCount == expected,
                message:
                    "Expected \(functionName) to be called exactly \(times(expected)), but was called \(times(matchingCount))",
                sourceLocation: sourceLocation
            )
        case .atLeast(let minimum):
            handleExpectation(
                condition: matchingCount >= minimum,
                message:
                    "Expected \(functionName) to be called at least \(times(minimum)), but was called \(times(matchingCount))",
                sourceLocation: sourceLocation
            )
        case .atMost(let maximum):
            handleExpectation(
                condition: matchingCount <= maximum,
                message:
                    "Expected \(functionName) to be called at most \(times(maximum)), but was called \(times(matchingCount))",
                sourceLocation: sourceLocation
            )
        case .never:
            handleExpectation(
                condition: matchingCount == 0,
                message: "Expected \(functionName) to never be called, but was called \(times(matchingCount))",
                sourceLocation: sourceLocation
            )
        case .atLeastOnce:
            handleExpectation(
                condition: matchingCount > 0,
                message: "Expected \(functionName) to be called at least once, but was never called",
                sourceLocation: sourceLocation
            )
        case .range(let range):
            handleExpectation(
                condition: range.contains(matchingCount),
                message: "Expected \(functionName) to be called \(range) times, but was called \(times(matchingCount))",
                sourceLocation: sourceLocation
            )
        }
    }

    public static func performNoInteractionVerification(
        interactionCount: Int,
        mockName: String,
        sourceLocation: SourceLocation
    ) {
        handleExpectation(
            condition: interactionCount == 0,
            message: "Expected \(mockName) to have no interactions but was called \(times(interactionCount))",
            sourceLocation: sourceLocation
        )
    }
}

/// Protocol that all generated mocks conform to for verification functionality.
///
/// This protocol provides the interface for verifying mock interactions and is
/// automatically implemented by the `@Smock` macro for generated mock classes.
/// Users of mocks shouldn't interact with this protocol directly.
public protocol VerifiableSmock {
    /// The type of verifier returned for this mock.
    associatedtype VerifierType

    /// Returns a verifier configured with the specified verification mode.
    /// - Parameters:
    ///   - mode: The verification mode to use
    ///   - sourceLocation: The source location for error reporting
    ///   - inOrder: Optional InOrder instance for ordered verification
    /// - Returns: A verifier instance for method/property verification
    func getVerifier(mode: VerificationMode, sourceLocation: SourceLocation, inOrder: InOrder?) -> VerifierType

    /// Verifies that no interactions occurred on this mock.
    /// - Parameter sourceLocation: The source location for error reporting
    func verifyNoInteractions(sourceLocation: SourceLocation)

    /// Returns a unique identifier for this mock instance.
    /// - Returns: A unique string identifier
    func getMockIdentifier() -> String
}

/// Helper utilities for mock functionality.
public struct SmockHelper {
    /// Generates a unique identifier for mock instances.
    /// - Returns: A unique string identifier
    public static func generateMockIdentifier() -> String {
        return UUID().uuidString
    }
}

/// Verifies that no interactions occurred on the specified mock.
///
/// Use this function to ensure that a mock was never called during a test.
/// This is useful for testing scenarios where certain dependencies should
/// not be invoked under specific conditions.
///
/// ## Example
/// ```swift
/// verifyNoInteractions(mockService)
/// verifyNoInteractions(mockLogger)
/// ```
///
/// - Parameter mock: The mock to verify
/// - Parameter sourceLocation: The source location for error reporting (automatically captured)
public func verifyNoInteractions<T: VerifiableSmock>(
    _ mock: T,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    mock.verifyNoInteractions(sourceLocation: sourceLocation)
}

/// Verifies that mock interactions occurred according to the specified verification mode.
///
/// This is the primary verification function that returns a verifier object you can use
/// to specify which method or property to verify. Chain this with method calls to verify
/// specific interactions.
///
/// ## Example
/// ```swift
/// verify(mock, .times(3)).fetchUser(id: .any)
/// verify(mock, .never).deleteUser(id: .any)
/// verify(mock, .atLeastOnce).initialize()
/// verify(mock, .atMost(5)).logMessage(.any)
/// ```
///
/// - Parameters:
///   - mock: The mock to verify
///   - mode: The verification mode specifying how many times the interaction should have occurred
///   - sourceLocation: The source location for error reporting (automatically captured)
/// - Returns: A verifier object for chaining method/property verification calls
public func verify<T: VerifiableSmock>(
    _ mock: T,
    _ mode: VerificationMode,
    sourceLocation: SourceLocation = #_sourceLocation
) -> T.VerifierType {
    return mock.getVerifier(mode: mode, sourceLocation: sourceLocation, inOrder: nil)
}

/// Global verify function that returns verifier for function-style verification, specifying an exact number of invocations
/// with a default of 1 time.
///
/// This function provides an API for performing verification assertions.

///
/// Example usage:
/// ```swift
/// verify(mock, times: 3)).fetchUser(id: .any)
/// ```
public func verify<T: VerifiableSmock>(
    _ mock: T,
    times: Int = 1,
    sourceLocation: SourceLocation = #_sourceLocation
) -> T.VerifierType {
    return mock.getVerifier(mode: VerificationMode.times(times), sourceLocation: sourceLocation, inOrder: nil)
}

/// Global verify function that returns verifier for function-style verification, specifying a minimum number of invocations
///
/// This function provides an API for performing verification assertions.

///
/// Example usage:
/// ```swift
/// verify(mock, atLeast: 3)).fetchUser(id: .any)
/// ```
public func verify<T: VerifiableSmock>(
    _ mock: T,
    atLeast: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) -> T.VerifierType {
    return mock.getVerifier(mode: VerificationMode.atLeast(atLeast), sourceLocation: sourceLocation, inOrder: nil)
}

/// Global verify function that returns verifier for function-style verification, specifying a maximum number of invocations
///
/// This function provides an API for performing verification assertions.

///
/// Example usage:
/// ```swift
/// verify(mock, atMost: 3)).fetchUser(id: .any)
/// ```
public func verify<T: VerifiableSmock>(
    _ mock: T,
    atMost: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) -> T.VerifierType {
    return mock.getVerifier(mode: VerificationMode.atMost(atMost), sourceLocation: sourceLocation, inOrder: nil)
}

/// Global verify function that returns verifier for function-style verification, specifying a range of invocation count
///
/// This function provides an API for performing verification assertions.

///
/// Example usage:
/// ```swift
/// verify(mock, times: 3...10)).fetchUser(id: .any)
/// ```
public func verify<T: VerifiableSmock>(
    _ mock: T,
    times: ClosedRange<Int>,
    sourceLocation: SourceLocation = #_sourceLocation
) -> T.VerifierType {
    return mock.getVerifier(mode: VerificationMode.range(times), sourceLocation: sourceLocation, inOrder: nil)
}
