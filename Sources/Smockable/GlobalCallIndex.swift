//
//  GlobalCallIndex.swift
//  smockable
//

import Synchronization

public struct GlobalCallIndex: ~Copyable, Sendable {
    private let value = Atomic<UInt32>(0)

    public func getCurrentIndex() -> UInt32 {
        let (_, updatedValue) = self.value.add(1, ordering: .sequentiallyConsistent)

        return updatedValue
    }
}

public let smockableGlobalCallIndex = GlobalCallIndex()
