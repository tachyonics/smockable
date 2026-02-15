//===----------------------------------------------------------------------===//
//
// This source file is part of the Smockable open source project
//
// Copyright (c) 2026 the Smockable authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Smockable authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

//
//  TestingSupport.swift
//  Smockable
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
