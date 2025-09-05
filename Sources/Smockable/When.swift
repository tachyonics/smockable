//
//  When.swift
//  smockable
//

public enum ExpectationTimes {
    case unbounded
    case times(Int)
}

public enum VoidReturnableCompletion {
    case withSuccess
}

public func when<FieldExpectationType: ReturnableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: Int = 1,
    return value: FieldExpectationType.ReturnType
) {
    expectation.update(value: value)
    expectation.update(times: times)
}

public func when<FieldExpectationType: ReturnableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: ExpectationTimes,
    return value: FieldExpectationType.ReturnType
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
    throw error: Swift.Error
) {
    expectation.update(error: error)
    expectation.update(times: times)
}

public func when<FieldExpectationType: ErrorableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: ExpectationTimes,
    throw error: Swift.Error
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

public func when<FieldExpectationType: VoidReturnableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: Int = 1,
    complete: VoidReturnableCompletion
) {
    expectation.success()
    expectation.update(times: times)
}

public func when<FieldExpectationType: VoidReturnableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: ExpectationTimes,
    complete: VoidReturnableCompletion
) {
    expectation.success()
    switch times {
    case .unbounded:
        expectation.update(times: nil)
    case .times(let count):
        expectation.update(times: count)

    }
}
