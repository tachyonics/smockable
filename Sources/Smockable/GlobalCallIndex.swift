//
//  GlobalCallIndex.swift
//  smockable
//

@_exported import Synchronization

package class GlobalCallIndex: @unchecked Sendable {
    private let mutex: Mutex<[(String, Int)]> = .init([])

    package func getCurrentIndex(mockIdentifier: String, localCallIndex: Int) -> Int {
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

package let smockableGlobalCallIndex = GlobalCallIndex()
