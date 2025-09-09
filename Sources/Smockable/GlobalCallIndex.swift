//
//  GlobalCallIndex.swift
//  smockable
//

public actor GlobalCallIndex {
    private var value: UInt32 = 0

    public func getCurrentIndex() -> UInt32 {
        self.value += 1

        return self.value
    }
}

public let smockableGlobalCallIndex = GlobalCallIndex()
