//
//  GlobalCallIndex.swift
//  smockable
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

/// Internal singleton of theGlobal CallIndex class
public let smockableGlobalCallIndex = GlobalCallIndex()
