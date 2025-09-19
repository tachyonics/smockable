//
//  TestingSupport.swift
//  smockable
//

import Foundation
import Testing

#if SMOCKABLE_UNHAPPY_PATH_TESTING
import Synchronization

public struct FailureRecord: Sendable {
    public let message: String
    public let sourceLocation: SourceLocation
    public let timestamp: Date

    public init(message: String, sourceLocation: SourceLocation, timestamp: Date = Date()) {
        self.message = message
        self.sourceLocation = sourceLocation
        self.timestamp = timestamp
    }
}

public final class FailureRecorder: Sendable {
    private let failures = Mutex<[FailureRecord]>([])

    public init() {}

    public func record(_ failure: FailureRecord) {
        failures.withLock { failures in
            failures.append(failure)
        }
    }

    public func getFailures() -> [FailureRecord] {
        return failures.withLock { Array($0) }
    }

    public func clearFailures() {
        failures.withLock { failures in
            failures.removeAll()
        }
    }

    public var hasFailures: Bool {
        return failures.withLock { !$0.isEmpty }
    }
}

@TaskLocal public var failureRecorder: FailureRecorder?

public var isTestingUnhappyPath: Bool {
    return failureRecorder != nil
}
#endif
