//
//  When.swift
//  smockable
//

/// Defines how many times an expectation can be matched.
public enum ExpectationTimes {
    /// The expectation can be matched unlimited times.
    case unbounded
    /// The expectation can be matched exactly the specified number of times.
    case times(Int)
}

/// Completion options for void-returning functions and property setters.
public enum VoidReturnableCompletion {
    /// The operation completes successfully without throwing an error.
    case withSuccess
}

/// Sets up an expectation for a function or property getter that returns a value.
///
/// Use this function to configure what value a mock should return when a specific
/// method is called or property is accessed.
///
/// ## Example
/// ```swift
/// when(expectations.getName(id: .any), return: "John Doe")
/// when(expectations.userCount.get(), times: 2, return: 42)
/// ```
///
/// - Parameters:
///   - expectation: The method or property expectation to configure
///   - times: How many times this expectation can be matched (default: 1)
///   - value: The value to return when the expectation is matched
public func when<FieldExpectationType: ReturnableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: Int = 1,
    return value: FieldExpectationType.ReturnType
) {
    expectation.update(value: value)
    expectation.update(times: times)
}

/// Sets up an expectation for a function or property getter that returns a value.
///
/// This overload allows specifying `ExpectationTimes` for more flexible timing control.
///
/// ## Example
/// ```swift
/// when(expectations.getName(id: .any), times: .unbounded, return: "John Doe")
/// when(expectations.getUser(id: .any), times: .times(3), return: testUser)
/// ```
///
/// - Parameters:
///   - expectation: The method or property expectation to configure
///   - times: How many times this expectation can be matched
///   - value: The value to return when the expectation is matched
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

/// Sets up an expectation for a throwing function or property that should throw an error.
///
/// Use this function to configure what error a mock should throw when a specific
/// throwing method is called or throwing property is accessed.
///
/// ## Example
/// ```swift
/// when(expectations.loadUser(id: .any), throw: NetworkError.notFound)
/// when(expectations.config.get(), times: 2, throw: ConfigError.invalid)
/// ```
///
/// - Parameters:
///   - expectation: The throwing method or property expectation to configure
///   - times: How many times this expectation can be matched (default: 1)
///   - error: The error to throw when the expectation is matched
public func when<FieldExpectationType: ErrorableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: Int = 1,
    throw error: FieldExpectationType.ErrorType
) {
    expectation.update(error: error)
    expectation.update(times: times)
}

/// Sets up an expectation for a throwing function or property that should throw an error.
///
/// This overload allows specifying `ExpectationTimes` for more flexible timing control.
///
/// ## Example
/// ```swift
/// when(expectations.loadUser(id: .any), times: .unbounded, throw: NetworkError.notFound)
/// when(expectations.validateData(), times: .times(2), throw: ValidationError.invalid)
/// ```
///
/// - Parameters:
///   - expectation: The throwing method or property expectation to configure
///   - times: How many times this expectation can be matched
///   - error: The error to throw when the expectation is matched
public func when<FieldExpectationType: ErrorableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: ExpectationTimes,
    throw error: FieldExpectationType.ErrorType
) {
    expectation.update(error: error)
    switch times {
    case .unbounded:
        expectation.update(times: nil)
    case .times(let count):
        expectation.update(times: count)

    }
}

/// Sets up an expectation with a custom closure to handle the function call.
///
/// Use this function when you need custom logic to handle method calls, such as
/// dynamic return values or side effects.
///
/// ## Example
/// ```swift
/// when(expectations.processData(input: .any), use: { input in
///     return "Processed: \(input)"
/// })
/// ```
///
/// - Parameters:
///   - expectation: The method expectation to configure
///   - times: How many times this expectation can be matched (default: 1)
///   - use: A closure that will be called when the expectation is matched
public func when<FieldExpectationType: FieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: Int = 1,
    use: FieldExpectationType.UsingFunctionType
) {
    expectation.update(using: use)
    expectation.update(times: times)
}

/// Sets up an expectation with a custom closure to handle the function call.
///
/// This overload allows specifying `ExpectationTimes` for more flexible timing control.
///
/// ## Example
/// ```swift
/// when(expectations.processData(input: .any), times: .unbounded, use: { input in
///     return "Processed: \(input)"
/// })
/// ```
///
/// - Parameters:
///   - expectation: The method expectation to configure
///   - times: How many times this expectation can be matched
///   - use: A closure that will be called when the expectation is matched
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

/// Sets up an expectation for a void-returning function or property setter.
///
/// Use this function to configure void functions and property setters to complete successfully.
///
/// ## Example
/// ```swift
/// when(expectations.saveUser(user: .any), complete: .withSuccess)
/// when(expectations.userName.set(.any), times: 2, complete: .withSuccess)
/// ```
///
/// - Parameters:
///   - expectation: The void method or property setter expectation to configure
///   - times: How many times this expectation can be matched (default: 1)
///   - complete: How the operation should complete
public func when<FieldExpectationType: VoidReturnableFieldOptionsProtocol>(
    _ expectation: FieldExpectationType,
    times: Int = 1,
    complete: VoidReturnableCompletion
) {
    expectation.success()
    expectation.update(times: times)
}

/// Sets up an expectation for a void-returning function or property setter.
///
/// This overload allows specifying `ExpectationTimes` for more flexible timing control.
///
/// ## Example
/// ```swift
/// when(expectations.saveUser(user: .any), times: .unbounded, complete: .withSuccess)
/// when(expectations.logMessage(_: .any), times: .times(5), complete: .withSuccess)
/// ```
///
/// - Parameters:
///   - expectation: The void method or property setter expectation to configure
///   - times: How many times this expectation can be matched
///   - complete: How the operation should complete
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
