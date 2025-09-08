//
//  GlobalCallIndex.swift
//  smockable
//

public actor GlobalCallIndex {
    private var value = 0
    
    public func getCurrentIndex() -> Int {
        self.value += 1
        
        return self.value
    }
}

public let __smockableGlobalCallIndex = GlobalCallIndex()

