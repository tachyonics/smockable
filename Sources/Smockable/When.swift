//
//  When.swift
//  smockable
//
//  Created by Simon Pilkington on 2/9/2025.
//

public enum ExpectationTimes {
    case unbounded
    case times(Int)
}

public func when<FieldExpectationType: ReturnableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: Int = 1,
    useValue value: FieldExpectationType.ReturnType
) {
    expectation.update(value: value)
    expectation.update(times: times)
}

public func when<FieldExpectationType: ReturnableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: ExpectationTimes,
    useValue value: FieldExpectationType.ReturnType
) {
    expectation.update(value: value)
    switch times {
    case .unbounded:
        expectation.update(times: nil)
    case .times(let count):
        expectation.update(times: count)

    }
}

public func when<FieldExpectationType: ErrorableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: Int = 1,
    useError error: Swift.Error
) {
    expectation.update(error: error)
    expectation.update(times: times)
}

public func when<FieldExpectationType: ErrorableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: ExpectationTimes,
    useError error: Swift.Error
) {
    expectation.update(error: error)
    switch times {
    case .unbounded:
        expectation.update(times: nil)
    case .times(let count):
        expectation.update(times: count)

    }
}

public func when<FieldExpectationType: FieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: Int = 1,
    use: FieldExpectationType.UsingFunctionType
) {
    expectation.update(using: use)
    expectation.update(times: times)
}

public func when<FieldExpectationType: FieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: ExpectationTimes,
    use: FieldExpectationType.UsingFunctionType
) {
    expectation.update(using: use)
    switch times {
    case .unbounded:
        expectation.update(times: nil)
    case .times(let count):
        expectation.update(times: count)

    }
}

public func successWhen<FieldExpectationType: VoidReturnableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: Int = 1
) {
    expectation.success()
    expectation.update(times: times)
}

public func successWhen<FieldExpectationType: VoidReturnableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: ExpectationTimes
) {
    expectation.success()
    switch times {
    case .unbounded:
        expectation.update(times: nil)
    case .times(let count):
        expectation.update(times: count)

    }
}
