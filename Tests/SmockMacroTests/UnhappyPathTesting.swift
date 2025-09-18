//
//  UnhappyPathTesting.swift
//  smockable
//

#if SMOCKABLE_UNHAPPY_PATH_TESTING
import Testing
import Foundation
import Smockable

private func withFailureRecording<T>(
    operation: () throws -> T
) rethrows -> (result: T, failures: [FailureRecord]) {
    let recorder = FailureRecorder()
    let result = try $failureRecorder.withValue(recorder) {
        try operation()
    }
    let failures = recorder.getFailures()
    return (result: result, failures: failures)
}

private func withFailureRecording<T>(
    operation: () async throws -> T
) async rethrows -> (result: T, failures: [FailureRecord]) {
    let recorder = FailureRecorder()
    let result = try await $failureRecorder.withValue(recorder) {
        try await operation()
    }
    let failures = recorder.getFailures()
    return (result: result, failures: failures)
}



func expectVerificationFailures<T>(
    messages: [String],
    operation: () throws -> T,
    sourceLocation: SourceLocation = #_sourceLocation
) rethrows {
    let (_, failures) = try withFailureRecording(operation: operation)
    
    let actualMessages = failures.map(\.message)
    
    #expect(
        messages == actualMessages,
        "Expected verification failures '\(messages)', but got failures: \(actualMessages)",
        sourceLocation: sourceLocation
    )
}

func expectVerificationFailures<T>(
    messages: [String],
    operation: () async throws -> T,
    sourceLocation: SourceLocation = #_sourceLocation
) async rethrows {
    let (_, failures) = try await withFailureRecording(operation: operation)
    
    let actualMessages = failures.map(\.message)
    
    #expect(
        messages == actualMessages,
        "Expected verification failures '\(messages)', but got failures: \(actualMessages)",
        sourceLocation: sourceLocation
    )
}
#endif
