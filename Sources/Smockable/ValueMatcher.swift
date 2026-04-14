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
//  ValueMatcher.swift
//  Smockable
//

// MARK: - AlwaysMatcher

/// A matcher that always returns true, used internally for unconditional matching.
public struct AlwaysMatcher: Sendable {
    /// Creates a new AlwaysMatcher instance.
    public init() {

    }

    /// Always returns true, indicating a match.
    /// - Returns: Always `true`
    public func matches() -> Bool {
        return true
    }
}

// MARK: - ValueMatcher

/// A matcher for parameters whose concrete type is known at compile time.
///
/// Use `ValueMatcher` in mock expectations to specify what parameter values
/// should be accepted. The available matching operations depend on the type's
/// protocol conformances — `.exact()` requires `Equatable`, `.range()` requires
/// `Comparable`, and `.any` / `.matching()` are always available.
///
/// ## Example
/// ```swift
/// when(expectations.getUser(id: .any), return: testUser)
/// when(expectations.getUsers(count: 1...10), return: users)
/// when(expectations.processItem(name: "specific"), return: result)
/// ```
public struct ValueMatcher<T: Sendable>: Sendable, CustomStringConvertible {
    private let _matches: @Sendable (T) -> Bool

    /// A string representation of this matcher for debugging and error messages.
    public let description: String

    /// Creates a matcher from a closure and a description.
    public init(matches: @escaping @Sendable (T) -> Bool, description: String) {
        self._matches = matches
        self.description = description
    }

    /// Check if the given value matches this matcher.
    /// - Parameter value: The value to test against this matcher
    /// - Returns: `true` if the value matches, `false` otherwise
    public func matches(_ value: T) -> Bool {
        _matches(value)
    }

    /// Matches any value of type T.
    public static var any: ValueMatcher<T> {
        ValueMatcher(matches: { _ in true }, description: "any")
    }

    /// Uses a closure for custom matching logic.
    public static func matching(_ matcher: @escaping @Sendable (T) -> Bool) -> ValueMatcher<T> {
        ValueMatcher(matches: matcher, description: "custom")
    }
}

// MARK: ValueMatcher — Equatable

extension ValueMatcher where T: Equatable {
    /// Matches only the exact specified value.
    public static func exact(_ value: T) -> ValueMatcher<T> {
        ValueMatcher(matches: { $0 == value }, description: "\(value)")
    }
}

// MARK: ValueMatcher — Comparable

extension ValueMatcher where T: Comparable {
    /// Matches values within the specified closed range.
    public static func range(_ range: ClosedRange<T>) -> ValueMatcher<T> {
        ValueMatcher(matches: { range.contains($0) }, description: range.description)
    }
}

// MARK: ValueMatcher — String specifics

extension ValueMatcher where T == String {
    /// A string-specific description that includes quotes around string values.
    public var stringSpecficDescription: String {
        description
    }

    /// Matches only the exact specified string value. The description includes
    /// quotes for clarity in error messages.
    public static func exact(_ value: String) -> ValueMatcher<String> {
        ValueMatcher(matches: { $0 == value }, description: "\"\(value)\"")
    }

    /// Matches string values within the specified closed range. The description
    /// includes quotes around the range bounds for clarity in error messages.
    public static func range(_ range: ClosedRange<String>) -> ValueMatcher<String> {
        ValueMatcher(
            matches: { range.contains($0) },
            description: "\"\(range.lowerBound)\"...\"\(range.upperBound)\""
        )
    }
}

// MARK: ValueMatcher — Optional Equatable

extension ValueMatcher {
    /// Matches the exact specified optional value (which may be nil).
    public static func exact<U: Equatable & Sendable>(_ value: U?) -> ValueMatcher<T> where T == U? {
        ValueMatcher(
            matches: { $0 == value },
            description: value.map { "\($0)" } ?? "nil"
        )
    }
}

// MARK: ValueMatcher — Optional Comparable

extension ValueMatcher {
    /// Matches only non-nil values within the specified closed range.
    public static func range<U: Comparable & Sendable>(
        _ range: ClosedRange<U>
    ) -> ValueMatcher<T> where T == U? {
        ValueMatcher(
            matches: { value in
                guard let unwrapped = value else { return false }
                return range.contains(unwrapped)
            },
            description: range.description
        )
    }
}

// MARK: ValueMatcher — Optional String specifics

extension ValueMatcher where T == String? {
    /// A string-specific description that includes quotes around string values.
    public var stringSpecficDescription: String {
        description
    }

    /// Matches the exact specified optional string value. The description includes
    /// quotes for clarity in error messages.
    public static func exact(_ value: String?) -> ValueMatcher<String?> {
        ValueMatcher(
            matches: { $0 == value },
            description: value.map { "\"\($0)\"" } ?? "nil"
        )
    }

    /// Matches only non-nil string values within the specified closed range.
    /// The description includes quotes around the range bounds.
    public static func range(_ range: ClosedRange<String>) -> ValueMatcher<String?> {
        ValueMatcher(
            matches: { value in
                guard let unwrapped = value else { return false }
                return range.contains(unwrapped)
            },
            description: "\"\(range.lowerBound)\"...\"\(range.upperBound)\""
        )
    }
}

// MARK: - ExistentialValueMatcher

/// A matcher for parameters whose type is an existential — either a direct
/// generic parameter (e.g. `T` stored as `any Encodable & Sendable`) or a
/// wrapped generic (e.g. `PutItemInput<T>` stored as `any Sendable`).
///
/// Because the concrete type isn't known until invocation time, the matcher
/// provides ``matchingAs(_:_:)`` and ``exactAs(_:)`` to cast to a concrete type
/// before matching. The non-casting ``matching(_:)`` is also available for cases
/// where the raw existential is sufficient.
///
/// ## Example
/// ```swift
/// when(
///     expectations.process(item: .matchingAs(MyPayload.self) { payload in
///         payload.id == "abc"
///     }),
///     complete: .withSuccess
/// )
///
/// when(
///     expectations.process(item: .exactAs(expectedPayload)),
///     complete: .withSuccess
/// )
/// ```
public struct ExistentialValueMatcher<T: Sendable>: Sendable, CustomStringConvertible {
    private let _matches: @Sendable (T) -> Bool

    /// A string representation of this matcher for debugging and error messages.
    public let description: String

    /// Creates a matcher from a closure and a description.
    public init(matches: @escaping @Sendable (T) -> Bool, description: String) {
        self._matches = matches
        self.description = description
    }

    /// Check if the given value matches this matcher.
    /// - Parameter value: The value to test against this matcher
    /// - Returns: `true` if the value matches, `false` otherwise
    public func matches(_ value: T) -> Bool {
        _matches(value)
    }

    /// Matches any value.
    public static var any: ExistentialValueMatcher<T> {
        ExistentialValueMatcher(matches: { _ in true }, description: "any")
    }

    /// Uses a closure for custom matching logic. The closure receives the value
    /// as the existential type `T`. For type-safe matching against a known
    /// concrete type, prefer ``matchingAs(_:_:)``.
    public static func matching(
        _ matcher: @escaping @Sendable (T) -> Bool
    ) -> ExistentialValueMatcher<T> {
        ExistentialValueMatcher(matches: matcher, description: "custom")
    }

    /// Casts the existential value to a concrete type `U` before invoking the
    /// closure.
    ///
    /// Use this when the production code passes a known concrete type and the
    /// test wants to inspect its properties directly. The cast happens inside
    /// the matcher; if the production code passes a different type, the
    /// matcher returns `false` (the expectation simply doesn't match).
    ///
    /// ## Example
    /// ```swift
    /// when(
    ///     expectations.process(item: .matchingAs(MyPayload.self) { payload in
    ///         payload.id == "abc" && payload.count == 3
    ///     }),
    ///     complete: .withSuccess
    /// )
    /// ```
    public static func matchingAs<U>(
        _ type: U.Type,
        _ check: @escaping @Sendable (U) -> Bool
    ) -> ExistentialValueMatcher<T> {
        .matching { (value: T) in
            guard let typed = value as? U else { return false }
            return check(typed)
        }
    }

    /// Casts the existential value to a concrete type `U` and compares it for
    /// equality with `value`.
    ///
    /// Use this when the production code passes a known concrete type and the
    /// test wants to assert that it equals a specific value. The cast happens
    /// inside the matcher; if the production code passes a different type, the
    /// matcher returns `false`.
    ///
    /// ## Example
    /// ```swift
    /// when(
    ///     expectations.process(item: .exactAs(expectedPayload)),
    ///     complete: .withSuccess
    /// )
    /// ```
    public static func exactAs<U: Equatable & Sendable>(
        _ value: U
    ) -> ExistentialValueMatcher<T> {
        .matching { (storedValue: T) in
            guard let typed = storedValue as? U else { return false }
            return typed == value
        }
    }
}
