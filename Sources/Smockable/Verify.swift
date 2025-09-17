//
//  Verify.swift
//  smockable
//

import Testing
import Foundation

/// Verification modes for function-style verification
public enum VerificationMode {
    case times(Int)  // Exactly N times
    case atLeast(Int)  // At least N times
    case atMost(Int)  // At most N times
    case never  // Never called (0 times)
    case atLeastOnce  // At least once (>= 1)
    case range(ClosedRange<Int>)  // Within a range
}

private func times<IntegerType: BinaryInteger>(_ count: IntegerType) -> String {
    if count == 1 {
        return "1 time"
    } else {
        return "\(count) times"
    }
}

/// Helper for performing verification assertions
public struct VerificationHelper {
    public static func performVerification(
        mode: VerificationMode,
        matchingCount: Int,
        functionName: String,
        sourceLocation: SourceLocation
    ) {
        switch mode {
        case .times(let expected):
            #expect(
                matchingCount == expected,
                "Expected \(functionName) to be called exactly \(times(expected)), but was called \(times(matchingCount))",
                sourceLocation: sourceLocation
            )
        case .atLeast(let minimum):
            #expect(
                matchingCount >= minimum,
                "Expected \(functionName) to be called at least \(times(minimum)), but was called \(times(matchingCount))",
                sourceLocation: sourceLocation
            )
        case .atMost(let maximum):
            #expect(
                matchingCount <= maximum,
                "Expected \(functionName) to be called at most \(times(maximum)), but was called \(times(matchingCount))",
                sourceLocation: sourceLocation
            )
        case .never:
            #expect(
                matchingCount == 0,
                "Expected \(functionName) to never be called, but was called \(times(matchingCount))",
                sourceLocation: sourceLocation
            )
        case .atLeastOnce:
            #expect(
                matchingCount > 0,
                "Expected \(functionName) to be called at least once, but was never called",
                sourceLocation: sourceLocation
            )
        case .range(let range):
            #expect(
                range.contains(matchingCount),
                "Expected \(functionName) to be called \(range) times, but was called \(times(matchingCount))",
                sourceLocation: sourceLocation
            )
        }
    }

    package static func performNoInteractionVerification(
        interactionCount: Int,
        mockName: String,
        sourceLocation: SourceLocation
    ) {
        #expect(
            interactionCount == 0,
            "Expected \(mockName) to have no interactions but was called \(times(interactionCount))",
            sourceLocation: sourceLocation
        )
    }
}

/// Protocol that all generated mocks will conform to for verification access
public protocol VerifiableSmock {
    associatedtype VerifierType

    func getVerifier(mode: VerificationMode, sourceLocation: SourceLocation, inOrder: InOrder?) -> VerifierType

    func verifyNoInteractions(sourceLocation: SourceLocation)

    func getMockIdentifier() -> String
}

public struct SmockHelper {
    public static func generateMockIdentifier() -> String {
        return UUID().uuidString
    }
}

/// Global verifyNoInteractions function to confirm no interactions happened on this mock
///
/// Example usage:
/// ```swift
/// verifyNoInteractions(mock)
/// ```
public func verifyNoInteractions<T: VerifiableSmock>(
    _ mock: T,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    mock.verifyNoInteractions(sourceLocation: sourceLocation)
}

/// Global verify function that returns verifier for function-style verification
///
/// This function provides an API for performing verification assertions.
///
/// Example usage:
/// ```swift
/// verify(mock, times: 3).fetchUser(id: .any)
/// verify(mock, .never).deleteUser(id: .any)
/// verify(mock, .atLeastOnce).initialize()
/// ```
public func verify<T: VerifiableSmock>(
    _ mock: T,
    _ mode: VerificationMode,
    sourceLocation: SourceLocation = #_sourceLocation
) -> T.VerifierType {
    return mock.getVerifier(mode: mode, sourceLocation: sourceLocation, inOrder: nil)
}

/// Global verify function that returns verifier for function-style verification, specifying an exact number of invocations
///
/// This function provides an API for performing verification assertions.

///
/// Example usage:
/// ```swift
/// verify(mock, times: 3)).fetchUser(id: .any)
/// ```
public func verify<T: VerifiableSmock>(
    _ mock: T,
    times: Int,
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
