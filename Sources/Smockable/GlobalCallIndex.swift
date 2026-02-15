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
//  GlobalCallIndex.swift
//  Smockable
//

import Synchronization

public typealias Mutex = Synchronization.Mutex

/// Internal class for keeping track of the global order of all mock interactions
/// Users of mocks shouldn't interact with this class directly.
public class GlobalCallIndex: @unchecked Sendable {
    private let mutex: Mutex<[(String, Int)]> = .init([])

    public func getCurrentIndex(mockIdentifier: String, localCallIndex: Int) -> Int {
        return self.mutex.withLock { list in
            list.append((mockIdentifier, localCallIndex))

            return Int(list.count)
        }
    }

    package func getCalls(for range: Range<Int>) -> [(String, Int)] {
        return self.mutex.withLock { list in
            return Array(list[range])
        }
    }

    package func getCalls(for range: PartialRangeFrom<Int>) -> [(String, Int)] {
        return self.mutex.withLock { list in
            if range.lowerBound > list.count {
                return []
            }

            return Array(list[range])
        }
    }
}

/// Internal singleton of the GlobalCallIndex class
/// Users of mocks shouldn't interact with this singleton directly.
public let smockableGlobalCallIndex = GlobalCallIndex()
