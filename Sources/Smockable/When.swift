//
//  When.swift
//  smockable
//
//  Created by Simon Pilkington on 2/9/2025.
//

public func when<FieldExpectationType: ReturnableFieldOptionsProtocol>(_ expectation: FieldExpectationType,
                                                                           times: Int? = 1, useValue value: FieldExpectationType.ReturnType) {
    expectation.update(value: value)
    expectation.update(times: times)
}

public func when<FieldExpectationType: ErrorableFieldOptionsProtocol>(_ expectation: FieldExpectationType,
                                                                          times: Int? = 1, useError error: Swift.Error) {
    expectation.update(error: error)
    expectation.update(times: times)
}

public func when<FieldExpectationType: FieldOptionsProtocol>(_ expectation: FieldExpectationType,
                                                                 times: Int? = 1, use: FieldExpectationType.UsingFunctionType) {
    expectation.update(using: use)
    expectation.update(times: times)
}

