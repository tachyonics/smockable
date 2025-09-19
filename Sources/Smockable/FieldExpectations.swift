//
//  FieldExpectations.swift
//  smockable
//

/// Protocol for field expectations that can be configured to throw errors.
///
/// This protocol extends `FieldOptionsProtocol` to support throwing functions
/// and properties that can fail with an error.
public protocol ErrorableFieldOptionsProtocol: FieldOptionsProtocol {
    /// Updates the expectation to throw the specified error when matched.
    /// - Parameter error: The error to throw
    func update(error: Swift.Error)
}

/// Protocol for field expectations that return a value.
///
/// This protocol extends `FieldOptionsProtocol` to support functions and
/// properties that return a specific type.
public protocol ReturnableFieldOptionsProtocol: FieldOptionsProtocol {
    /// The type of value this expectation returns.
    associatedtype ReturnType

    /// Updates the expectation to return the specified value when matched.
    /// - Parameter value: The value to return
    func update(value: ReturnType)
}

/// Protocol for field expectations that represent void operations.
///
/// This protocol extends `FieldOptionsProtocol` to support void functions
/// and property setters that complete without returning a value.
public protocol VoidReturnableFieldOptionsProtocol: FieldOptionsProtocol {
    /// Marks the expectation to complete successfully when matched.
    func success()
}

/// Base protocol for all field expectation types.
///
/// This protocol defines the common interface for configuring expectations
/// including timing constraints and custom implementation closures.
public protocol FieldOptionsProtocol {
    /// The type of closure that can be used for custom implementation.
    associatedtype UsingFunctionType

    /// Updates how many times this expectation can be matched.
    /// - Parameter times: Maximum number of matches, or `nil` for unlimited
    func update(times: Int?)
    
    /// Updates the expectation to use a custom closure when matched.
    /// - Parameter using: The closure to execute when the expectation is matched
    func update(using: UsingFunctionType)
}
