//===----------------------------------------------------------------------===//
//
// This source file is part of the Smockable open source project
//
// Copyright (c) 2026 the Smockable authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Smockable authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

//
//  FieldExpectations.swift
//  Smockable
//

/// Protocol for field expectations that can be configured to throw errors.
///
/// This protocol extends `FieldOptionsProtocol` to support throwing functions
/// and properties that can fail with an error.
public protocol ErrorableFieldOptionsProtocol: FieldOptionsProtocol {
    /// The type of error this expectation can throw.
    associatedtype ErrorType: Error

    /// Updates the expectation to throw the specified error when matched.
    /// - Parameter error: The error to throw
    func update(error: ErrorType)
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
