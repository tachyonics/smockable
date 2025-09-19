//
//  TestingSupport.swift
//  smockable
//

import Foundation
import Testing

#if SMOCKABLE_UNHAPPY_PATH_TESTING
import Synchronization

package struct FailureRecord: Sendable {
    package let message: String
    package let sourceLocation: SourceLocation
    package let timestamp: Date

    package init(message: String, sourceLocation: SourceLocation, timestamp: Date = Date()) {
        self.message = message
        self.sourceLocation = sourceLocation
        self.timestamp = timestamp
    }
}

package final class FailureRecorder: Sendable {
    private let failures = Mutex<[FailureRecord]>([])

    package init() {}

    package func record(_ failure: FailureRecord) {
        failures.withLock { failures in
            failures.append(failure)
        }
    }

    package func getFailures() -> [FailureRecord] {
        return failures.withLock { Array($0) }
    }

    package func clearFailures() {
        failures.withLock { failures in
            failures.removeAll()
        }
    }

    package var hasFailures: Bool {
        return failures.withLock { !$0.isEmpty }
    }
}

@TaskLocal package var failureRecorder: FailureRecorder?

package var isTestingUnhappyPath: Bool {
    return failureRecorder != nil
}
#endif
