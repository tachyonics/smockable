//
//  InOrder.swift
//  smockable
//

import Testing

#if SMOCKABLE_UNHAPPY_PATH_TESTING
import Synchronization
#endif

/// Verification modes for InOrder verification, specifying how many additional times an interaction should occur.
///
/// These modes work similarly to `VerificationMode` but are specifically designed for ordered verification
/// where you want to verify additional occurrences of interactions in sequence.
///
/// ## Example
/// ```swift
/// let inOrder = InOrder(strict: false, mock1, mock2)
/// inOrder.verify(mock1, .additionalTimes(2)).method1()
/// inOrder.verify(mock2, .additionalAtLeast(1)).method2()
/// ```
public enum InOrderVerificationMode: Sendable {
    /// Verifies the interaction occurred exactly the specified number of additional times.
    case additionalTimes(Int)
    /// Verifies the interaction occurred at least the specified number of additional times.
    case additionalAtLeast(Int)
    /// Verifies the interaction occurred at most the specified number of additional times.
    case additionalAtMost(Int)
    /// Verifies the interaction never occurred again (0 additional times).
    case additionalNone
    /// Verifies the interaction occurred at least once more (>= 1 additional time).
    case additionalAtLeastOnce
    /// Verifies the interaction occurred within the specified range of additional times.
    case additionalRange(ClosedRange<Int>)

    /// Converts this InOrder verification mode to a standard VerificationMode.
    var verificationMode: VerificationMode {
        return switch self {
        case .additionalTimes(let times):
            .times(times)
        case .additionalAtLeast(let times):
            .atLeast(times)
        case .additionalAtMost(let times):
            .atMost(times)
        case .additionalNone:
            .never
        case .additionalAtLeastOnce:
            .atLeastOnce
        case .additionalRange(let range):
            .range(range)
        }
    }
}

/// A class for verifying that mock interactions occurred in a specific order.
///
/// Use `InOrder` when you need to verify that methods were called in a particular sequence
/// across one or more mocks. This is useful for testing workflows where the order of
/// operations is important.
///
/// ## Usage
///
/// ### Basic Ordered Verification
/// ```swift
/// let inOrder = InOrder(strict: false, mockService, mockLogger)
///
/// // Execute operations
/// mockService.login()
/// mockLogger.log("User logged in")
/// mockService.fetchData()
///
/// // Verify they occurred in order
/// inOrder.verify(mockService).login()
/// inOrder.verify(mockLogger).log("User logged in")
/// inOrder.verify(mockService).fetchData()
/// inOrder.verifyNoMoreInteractions()
/// ```
///
/// ### Strict vs Non-Strict Mode
/// - **Strict mode**: Every interaction must be verified in the exact order they occurred
/// - **Non-strict mode**: You can skip interactions as long as what you verify is in order
///
/// ## Important Notes
/// - All mocks must be provided to the InOrder constructor to be tracked
/// - Interactions with mocks not in the constructor will cause fatal errors
/// - Use `verifyNoMoreInteractions()` to ensure no unexpected interactions occurred
public class InOrder {
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
    private let strict: Bool
    private var globalIndexProgress: Int = 0
    private var localIndexProgress: [String: Int]
    private var previousFunctionName: String?

    /// Initializes InOrder verification with a set of mocks to track.
    ///
    /// ## Parameters
    /// - **strict**: Controls verification behavior:
    ///   - `true`: Every interaction with the provided mocks must be verified in exact order
    ///   - `false`: Allows skipping interactions as long as verified calls are in order
    /// - **mocks**: All mocks that will participate in ordered verification
    ///
    /// ## Example
    /// ```swift
    /// let inOrder = InOrder(strict: true, mockA, mockB, mockC)
    /// let inOrder = InOrder(strict: false, servicesMock, loggerMock)
    /// ```
    ///
    /// ## Important
    /// Only mocks provided to this constructor can be used with this InOrder instance.
    /// Attempting to verify mocks not in the constructor will result in a fatal error.
    ///
    /// - Parameters:
    ///   - strict: Whether to require strict ordering of all interactions
    ///   - mocks: The mocks to track for ordered verification
    public init(strict: Bool, _ mocks: any VerifiableSmock...) {
        self.strict = strict

        var mockDict: [String: Int] = [:]
        for mock in mocks {
            let id = mock.getMockIdentifier()
            mockDict[id] = 0
        }
        self.localIndexProgress = mockDict
    }

    /// Verifies a mock interaction occurred exactly the specified number of additional times.
    ///
    /// This is the most commonly used verification method for InOrder. It verifies that
    /// the next interaction(s) in sequence match the specified call.
    ///
    /// ## Example
    /// ```swift
    /// inOrder.verify(mockService).login()
    /// inOrder.verify(mockService, additionalTimes: 3).fetchData()
    /// ```
    ///
    /// - Parameters:
    ///   - mock: The mock to verify (must be in InOrder constructor)
    ///   - additionalTimes: Number of additional times to verify (default: 1)
    ///   - sourceLocation: Source location for error reporting (automatically captured)
    /// - Returns: A verifier for chaining method/property calls
    public func verify<T: VerifiableSmock>(
        _ mock: T,
        additionalTimes: Int = 1,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> T.VerifierType {
        return verify(mock, .additionalTimes(additionalTimes), sourceLocation: sourceLocation)
    }

    /// Verifies a mock interaction using a specific InOrder verification mode.
    ///
    /// This is the most flexible verification method, allowing you to specify exactly
    /// how many times an interaction should have occurred using verification modes.
    ///
    /// ## Example
    /// ```swift
    /// inOrder.verify(mockService, .additionalAtLeast(2)).processData()
    /// inOrder.verify(mockLogger, .additionalNone).debugLog()
    /// ```
    ///
    /// - Parameters:
    ///   - mock: The mock to verify (must be in InOrder constructor)
    ///   - mode: The verification mode specifying expected interaction count
    ///   - sourceLocation: Source location for error reporting (automatically captured)
    /// - Returns: A verifier for chaining method/property calls
    public func verify<T: VerifiableSmock>(
        _ mock: T,
        _ mode: InOrderVerificationMode,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> T.VerifierType {
        let mockId = mock.getMockIdentifier()
        guard self.localIndexProgress[mockId] != nil else {
            fatalError("Mock not specified in InOrder constructor")
        }
        return mock.getVerifier(mode: mode.verificationMode, sourceLocation: sourceLocation, inOrder: self)
    }

    /// Verifies a mock interaction occurred at least the specified number of additional times.
    ///
    /// Uses greedy matching - will consume as many matching interactions as possible.
    ///
    /// ## Example
    /// ```swift
    /// inOrder.verify(mockService, additionalAtLeast: 1).retryOperation()
    /// ```
    ///
    /// - Parameters:
    ///   - mock: The mock to verify (must be in InOrder constructor)
    ///   - additionalAtLeast: Minimum number of additional times to verify
    ///   - sourceLocation: Source location for error reporting (automatically captured)
    /// - Returns: A verifier for chaining method/property calls
    public func verify<T: VerifiableSmock>(
        _ mock: T,
        additionalAtLeast: Int,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> T.VerifierType {
        return verify(mock, .additionalAtLeast(additionalAtLeast), sourceLocation: sourceLocation)
    }

    /// Verifies a mock interaction occurred at most the specified number of additional times.
    ///
    /// ## Example
    /// ```swift
    /// inOrder.verify(mockService, additionalAtMost: 3).pollForUpdates()
    /// ```
    ///
    /// - Parameters:
    ///   - mock: The mock to verify (must be in InOrder constructor)
    ///   - additionalAtMost: Maximum number of additional times to verify
    ///   - sourceLocation: Source location for error reporting (automatically captured)
    /// - Returns: A verifier for chaining method/property calls
    public func verify<T: VerifiableSmock>(
        _ mock: T,
        additionalAtMost: Int,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> T.VerifierType {
        return verify(mock, .additionalAtMost(additionalAtMost), sourceLocation: sourceLocation)
    }

    /// Verifies a mock interaction occurred within the specified range of additional times.
    ///
    /// ## Example
    /// ```swift
    /// inOrder.verify(mockService, additionalRange: 2...5).batchProcess()
    /// ```
    ///
    /// - Parameters:
    ///   - mock: The mock to verify (must be in InOrder constructor)
    ///   - additionalRange: Range of acceptable additional times
    ///   - sourceLocation: Source location for error reporting (automatically captured)
    /// - Returns: A verifier for chaining method/property calls
    public func verify<T: VerifiableSmock>(
        _ mock: T,
        additionalRange: ClosedRange<Int>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> T.VerifierType {
        return verify(mock, .additionalRange(additionalRange), sourceLocation: sourceLocation)
    }

    /// Verifies that no more unverified interactions occurred on any tracked mocks.
    ///
    /// Call this at the end of your ordered verification to ensure no unexpected
    /// interactions occurred after the ones you explicitly verified.
    ///
    /// ## Example
    /// ```swift
    /// inOrder.verify(mockA).method1()
    /// inOrder.verify(mockB).method2()
    /// inOrder.verifyNoMoreInteractions() // Ensures no other calls happened
    /// ```
    ///
    /// - Parameter sourceLocation: Source location for error reporting (automatically captured)
    public func verifyNoMoreInteractions(sourceLocation: SourceLocation = #_sourceLocation) {
        // the range is off-by-1
        let calls = smockableGlobalCallIndex.getCalls(for: self.globalIndexProgress...)
        let unverifiedInteractions = calls.filter { (interactionMockIdentifier, _) in

            return self.localIndexProgress[interactionMockIdentifier] != nil
        }

        Self.handleExpectation(
            condition: unverifiedInteractions.count == 0,
            message:
                "Expected no remaining unverified mock interactions but interactions occurred \(times(unverifiedInteractions.count))",
            sourceLocation: sourceLocation
        )
    }

    /// Internal method called by verifier functions to perform ordered verification
    public func performVerification(
        mockIdentifier: String,
        mode: VerificationMode,
        matchingInvocations: [(localIndex: Int, globalIndex: Int)],
        functionName: String,
        sourceLocation: SourceLocation
    ) {
        guard let currentLocalIndex = self.localIndexProgress[mockIdentifier] else {
            fatalError("Mock not specified in InOrder constructor")
        }

        // Filter out already verified invocations
        let candidateInvocations = matchingInvocations.filter { invocation in
            invocation.localIndex > currentLocalIndex
        }

        // Apply verification mode logic
        let verifiedInvocations = applyVerificationMode(
            candidateInvocations: candidateInvocations,
            mode: mode,
            functionName: functionName,
            sourceLocation: sourceLocation
        )
        let verifiedCallIndices = Set((verifiedInvocations ?? []).map { $0.localIndex })

        // if the verifiedInvocations passed the verification mode
        if let verifiedInvocations, let first = verifiedInvocations.first, let last = verifiedInvocations.last {
            // check if the first invocation is the latest invocation so far
            if first.globalIndex > self.globalIndexProgress {
                if self.strict {
                    let calls = smockableGlobalCallIndex.getCalls(
                        for: self.globalIndexProgress..<(last.globalIndex - 1)
                    )
                    let unverifiedInteractions = calls.filter {
                        (interactionMockIdentifier, interactionLocalCallIndex) in
                        // filter out any verifiedInvocations
                        if mockIdentifier == interactionMockIdentifier
                            && verifiedCallIndices.contains(interactionLocalCallIndex)
                        {
                            return false
                        }
                        return self.localIndexProgress[interactionMockIdentifier] != nil
                    }

                    if verifiedInvocations.count == 1 {
                        Self.handleExpectation(
                            condition: unverifiedInteractions.count == 0,
                            message:
                                "Expected no unverified mock interactions before this call to \(functionName) but interactions occurred \(times(unverifiedInteractions.count))",
                            sourceLocation: sourceLocation
                        )
                    } else {
                        Self.handleExpectation(
                            condition: unverifiedInteractions.count == 0,
                            message:
                                "Expected no unverified mock interactions before or between these calls to \(functionName) but interactions occurred \(times(unverifiedInteractions.count))",
                            sourceLocation: sourceLocation
                        )
                    }
                }

                // update the global index
                self.globalIndexProgress = last.globalIndex

                // update the local index for the mock
                self.localIndexProgress[mockIdentifier] = last.localIndex
                self.previousFunctionName = functionName
            } else {
                guard let previousFunctionName = self.previousFunctionName else {
                    fatalError("Missing previousFunctionName")
                }
                Self.handleExpectation(
                    condition: first.globalIndex > self.globalIndexProgress,
                    message:
                        "Expected \(functionName) to be called after invocation of \(previousFunctionName) but was called before",
                    sourceLocation: sourceLocation
                )
            }
        }
    }

    /// Apply verification mode logic and return the verified invocations
    private func applyVerificationMode(
        candidateInvocations: [(localIndex: Int, globalIndex: Int)],
        mode: VerificationMode,
        functionName: String,
        sourceLocation: SourceLocation
    ) -> [(localIndex: Int, globalIndex: Int)]? {
        let count = candidateInvocations.count

        switch mode {
        case .times(let expected):
            Self.handleExpectation(
                condition: count >= expected,
                message:
                    "Expected \(functionName) to be called an additional \(times(expected)), but was called \(times(count))",
                sourceLocation: sourceLocation
            )
            return (count >= expected) ? Array(candidateInvocations.prefix(expected)) : nil

        case .atLeast(let minimum):
            Self.handleExpectation(
                condition: count >= minimum,
                message:
                    "Expected \(functionName) to be called at least an additional \(times(minimum)), but was called \(times(count))",
                sourceLocation: sourceLocation
            )
            // Greedy: verify as many as possible
            return (count >= minimum) ? candidateInvocations : nil

        case .atMost(let maximum):
            return Array(candidateInvocations.prefix(maximum))

        case .never:
            Self.handleExpectation(
                condition: count == 0,
                message: "Expected \(functionName) to not be called again, but was called \(times(count))",
                sourceLocation: sourceLocation
            )
            return (count == 0) ? [] : nil

        case .atLeastOnce:
            Self.handleExpectation(
                condition: count > 0,
                message: "Expected \(functionName) to be called additionally at least once, but was never called",
                sourceLocation: sourceLocation
            )
            // Greedy: verify as many as possible
            return (count > 0) ? candidateInvocations : nil

        case .range(let range):
            Self.handleExpectation(
                condition: count >= range.lowerBound,
                message:
                    "Expected \(functionName) to be called additionally \(range) times, but was called \(times(count))",
                sourceLocation: sourceLocation
            )
            return (count >= range.lowerBound) ? Array(candidateInvocations.prefix(range.upperBound)) : nil
        }
    }
}

// Helper function for formatting times (reusing from Verify.swift)
private func times<IntegerType: BinaryInteger>(_ count: IntegerType) -> String {
    if count == 1 {
        return "1 time"
    } else {
        return "\(count) times"
    }
}
