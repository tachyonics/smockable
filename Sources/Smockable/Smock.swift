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
//  Smock.swift
//  Smockable
//

/// A macro that generates mock implementations for protocols.
///
/// The `@Smock` macro creates a mock class for any protocol, allowing you to set expectations
/// for method calls and property access during testing. The generated mock includes:
/// - An `Expectations` struct for configuring expected behavior
/// - Mock implementations of all protocol methods and properties
/// - Support for verifying call counts and parameters
///
/// ## Usage
///
/// Apply `@Smock` to any protocol:
/// ```swift
/// @Smock
/// protocol UserService {
///     func getUser(id: String) -> User
///     var isLoggedIn: Bool { get }
/// }
/// ```
///
/// This generates a `MockUserService` class that can be used in tests:
/// ```swift
/// var expectations = MockUserService.Expectations()
/// when(expectations.getUser(id: .any), return: testUser)
/// when(expectations.isLoggedIn.get(), return: true)
///
/// let mock = MockUserService(expectations: expectations)
/// let user = mock.getUser(id: "123")
/// verify(mock).getUser(id: "123")
/// ```
///
/// - Parameters:
///    - accessLevel: The access modifier for the generated mock definition. Public if not specified
///    - preprocessorFlag: If specified the generated mock definition will be wrapped in a preprocessor flag
///    - additionalComparableTypes: An Array of additional types to be considered conforming to Comparable
///    - additionalEquatableTypes: An Array of additional types to be considered conforming to Equatable

@attached(peer, names: prefixed(Mock))
public macro Smock(
    accessLevel: AccessLevel? = nil,
    preprocessorFlag: String? = nil,
    additionalComparableTypes: [any Comparable.Type]? = nil,
    additionalEquatableTypes: [any Equatable.Type]? = nil
) =
    #externalMacro(
        module: "SmockMacro",
        type: "SmockMacro"
    )

public enum AccessLevel {
    case `public`
    case `package`
    case `internal`
    case `fileprivate`
    case `private`
}
