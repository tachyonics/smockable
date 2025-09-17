//
//  InOrder.swift
//  smockable
//

import Testing

public enum InOrderVerificationMode {
    case additionalTimes(Int)  // Exactly N times
    case additionalAtLeast(Int)  // At least N times
    case additionalAtMost(Int)  // At most N times
    case additionalNone  // Never called (0 times)
    case additionalAtLeastOnce  // At least once (>= 1)
    case additionalRange(ClosedRange<Int>)  // Within a range

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

/// InOrder verification class for verifying mock interactions in a specific order
public class InOrder {
    private let strict: Bool
    private var globalIndexProgress: Int = 0
    private var localIndexProgress: [String: Int]
    private var previousFunctionName: String?

    /// Initialize InOrder verification with a set of mocks
    /// - Parameters:
    ///   - strict: If true, verification must account for every interaction with the mocks in order.
    ///            If false, interactions can be skipped as long as what is verfied is verified in order.
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

    /// Verify a mock interaction with exactly `additionalTimes` occurrences
    public func verify<T: VerifiableSmock>(
        _ mock: T,
        additionalTimes: Int = 1,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> T.VerifierType {
        return verify(mock, .additionalTimes(additionalTimes), sourceLocation: sourceLocation)
    }

    /// Verify a mock interaction with a specific verification mode
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

    /// Verify a mock interaction with at least `additionalAtLeast` occurrences (greedy matching)
    public func verify<T: VerifiableSmock>(
        _ mock: T,
        additionalAtLeast: Int,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> T.VerifierType {
        return verify(mock, .additionalAtLeast(additionalAtLeast), sourceLocation: sourceLocation)
    }

    /// Verify a mock interaction with at most `additionalAtMost` occurrences
    public func verify<T: VerifiableSmock>(
        _ mock: T,
        additionalAtMost: Int,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> T.VerifierType {
        return verify(mock, .additionalAtMost(additionalAtMost), sourceLocation: sourceLocation)
    }

    /// Verify a mock interaction with at most `additionalRange` occurrences
    public func verify<T: VerifiableSmock>(
        _ mock: T,
        additionalRange: ClosedRange<Int>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> T.VerifierType {
        return verify(mock, .additionalRange(additionalRange), sourceLocation: sourceLocation)
    }

    /// Verify that no more interactions occurred on any of the tracked mocks
    public func verifyNoMoreInteractions(sourceLocation: SourceLocation = #_sourceLocation) {
        // the range is off-by-1
        let calls = smockableGlobalCallIndex.getCalls(for: self.globalIndexProgress...)
        let unverifiedInteractions = calls.filter { (interactionMockIdentifier, _) in

            return self.localIndexProgress[interactionMockIdentifier] != nil
        }

        #expect(
            unverifiedInteractions.count == 0,
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
            if self.strict {
                let calls = smockableGlobalCallIndex.getCalls(for: self.globalIndexProgress..<(last.globalIndex - 1))
                let unverifiedInteractions = calls.filter { (interactionMockIdentifier, interactionLocalCallIndex) in
                    // filter out any verifiedInvocations
                    if mockIdentifier == interactionMockIdentifier
                        && verifiedCallIndices.contains(interactionLocalCallIndex)
                    {
                        return false
                    }
                    return self.localIndexProgress[interactionMockIdentifier] != nil
                }

                if verifiedInvocations.count == 1 {
                    #expect(
                        unverifiedInteractions.count == 0,
                        "Expected no unverified mock interactions before this call to \(functionName) but interactions occurred \(times(unverifiedInteractions.count))",
                        sourceLocation: sourceLocation
                    )
                } else {
                    #expect(
                        unverifiedInteractions.count == 0,
                        "Expected no unverified mock interactions before or between these calls to \(functionName) but interactions occurred \(times(unverifiedInteractions.count))",
                        sourceLocation: sourceLocation
                    )
                }
            } else {
                // update the local index for the mock
                self.localIndexProgress[mockIdentifier] = last.localIndex
            }

            // check if the first invocation is the latest invocation so far
            if first.globalIndex > self.globalIndexProgress {
                // update the global index
                self.globalIndexProgress = last.globalIndex
            } else {
                guard let previousFunctionName = self.previousFunctionName else {
                    fatalError("Missing previousFunctionName")
                }
                #expect(
                    first.globalIndex > self.globalIndexProgress,
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
            #expect(
                count >= expected,
                "Expected \(functionName) to be called an additional \(times(expected)), but was called \(times(count))",
                sourceLocation: sourceLocation
            )
            return (count >= expected) ? Array(candidateInvocations.prefix(expected)) : nil

        case .atLeast(let minimum):
            #expect(
                count >= minimum,
                "Expected \(functionName) to be called at least an additional \(times(minimum)), but was called \(times(count))",
                sourceLocation: sourceLocation
            )
            // Greedy: verify as many as possible
            return (count >= minimum) ? candidateInvocations : nil

        case .atMost(let maximum):
            return Array(candidateInvocations.prefix(maximum))

        case .never:
            #expect(
                count == 0,
                "Expected \(functionName) to not be called again, but was called \(times(count))",
                sourceLocation: sourceLocation
            )
            return (count == 0) ? [] : nil

        case .atLeastOnce:
            #expect(
                count > 0,
                "Expected \(functionName) to be called additionally at least once, but was never called",
                sourceLocation: sourceLocation
            )
            // Greedy: verify as many as possible
            return (count > 0) ? candidateInvocations : nil

        case .range(let range):
            #expect(
                count >= range.lowerBound,
                "Expected \(functionName) to be called additionally \(range) times in order, but was called \(times(count))",
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
