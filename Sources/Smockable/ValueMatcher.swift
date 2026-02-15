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

/// A matcher for non-optional parameters that can match any value, exact values, or values within a range.
///
/// Use `ValueMatcher` in mock expectations to specify what parameter values should be accepted.
/// This provides flexible matching capabilities for testing different scenarios.
///
/// ## Example
/// ```swift
/// when(expectations.getUser(id: .any), return: testUser)
/// when(expectations.getUsers(count: 1...10), return: users)
/// when(expectations.processItem(name: "specific"), return: result)
/// ```
public enum ValueMatcher<T: Comparable & Sendable>: Sendable, CustomStringConvertible {
    /// Matches any value of type T.
    case any
    /// Matches values within the specified closed range.
    case range(ClosedRange<T>)
    /// Matches only the exact specified value.
    case exact(T)
    /// Uses a closure for custom matching logic
    case matching(_ matcher: @Sendable (T) -> Bool)

    /// Check if the given value matches this matcher.
    /// - Parameter value: The value to test against this matcher
    /// - Returns: `true` if the value matches, `false` otherwise
    public func matches(_ value: T) -> Bool {
        switch self {
        case .any:
            return true
        case .range(let range):
            return range.contains(value)
        case .exact(let match):
            return value == match
        case .matching(let matcher):
            return matcher(value)
        }
    }

    /// A string representation of this matcher for debugging and error messages.
    public var description: String {
        switch self {
        case .any:
            return "any"
        case .range(let range):
            return range.description
        case .exact(let match):
            return "\(match)"
        case .matching:
            return "custom"
        }
    }
}

extension ValueMatcher where T == String {
    /// A string-specific description that includes quotes around string values.
    public var stringSpecficDescription: String {
        switch self {
        case .any:
            return "any"
        case .range(let range):
            return "\"\(range.lowerBound)\"...\"\(range.upperBound)\""
        case .exact(let match):
            return "\"\(match)\""
        case .matching:
            return "custom"
        }
    }
}

/// A matcher for non-optional parameters of types that don't conform to `Comparable`.
///
/// This matcher is more limited than `ValueMatcher` since it can only match any value,
/// not ranges or exact values, due to the lack of comparison operations.
///
/// ## Example
/// ```swift
/// when(expectations.process(data: .any), return: result)
/// ```
public enum NonComparableValueMatcher<T: Sendable>: Sendable, CustomStringConvertible {
    /// Matches any value of type T.
    case any
    /// Uses a closure for custom matching logic
    case matching(_ matcher: @Sendable (T) -> Bool)

    /// Check if the given value matches this matcher.
    /// - Parameter value: The value to test against this matcher
    /// - Returns: Always `true` since this matcher only supports `.any`
    public func matches(_ value: T) -> Bool {
        switch self {
        case .any:
            return true
        case .matching(let matcher):
            return matcher(value)
        }
    }

    /// A string representation of this matcher for debugging and error messages.
    public var description: String {
        switch self {
        case .any:
            return "any"
        case .matching:
            return "custom"
        }
    }
}

/// A matcher for non-optional parameters of types that conform to `Equatable` but not `Comparable`.
///
/// This matcher supports exact value matching and any value matching, but not range matching
/// since the type doesn't conform to `Comparable`.
///
/// ## Example
/// ```swift
/// when(expectations.process(item: .any), return: result)
/// when(expectations.process(item: specificItem), return: result)
/// ```
public enum OnlyEquatableValueMatcher<T: Equatable & Sendable>: Sendable, CustomStringConvertible {
    /// Matches any value of type T.
    case any
    /// Matches only the exact specified value.
    case exact(T)
    /// Uses a closure for custom matching logic
    case matching(_ matcher: @Sendable (T) -> Bool)

    /// Check if the given value matches this matcher.
    /// - Parameter value: The value to test against this matcher
    /// - Returns: `true` if the value matches, `false` otherwise
    public func matches(_ value: T) -> Bool {
        switch self {
        case .any:
            return true
        case .exact(let match):
            return value == match
        case .matching(let matcher):
            return matcher(value)
        }
    }

    /// A string representation of this matcher for debugging and error messages.
    public var description: String {
        switch self {
        case .any:
            return "any"
        case .exact(let match):
            return "\(match)"
        case .matching:
            return "custom"
        }
    }
}

/// A matcher for optional parameters that can match nil, any value, exact values, or values within a range.
///
/// Use `OptionalValueMatcher` when working with optional parameters in mock expectations.
/// It provides the same matching capabilities as `ValueMatcher` but with additional support for nil values.
///
/// ## Example
/// ```swift
/// when(expectations.getUser(id: .any), return: testUser)
/// when(expectations.updateAge(age: 18...65), return: success)
/// when(expectations.setName(name: nil), return: success)
/// ```
public enum OptionalValueMatcher<T: Comparable & Sendable>: Sendable, CustomStringConvertible {
    /// Matches any value (nil or non-nil).
    case any
    /// Matches only non-nil values within the specified closed range.
    case range(ClosedRange<T>)
    /// Matches the exact specified value (which may be nil).
    case exact(T?)
    /// Uses a closure for custom matching logic
    case matching(_ matcher: @Sendable (T?) -> Bool)

    /// Check if the given optional value matches this matcher.
    /// - Parameter value: The optional value to test against this matcher
    /// - Returns: `true` if the value matches, `false` otherwise
    public func matches(_ value: T?) -> Bool {
        switch self {
        case .any:
            return true
        case .range(let range):
            guard let unwrapped = value else { return false }
            return range.contains(unwrapped)
        case .exact(let match):
            return value == match
        case .matching(let matcher):
            return matcher(value)
        }
    }

    /// A string representation of this matcher for debugging and error messages.
    public var description: String {
        switch self {
        case .any:
            return "any"
        case .range(let range):
            return range.description
        case .exact(let match):
            if let match {
                return "\(match)"
            } else {
                return "nil"
            }
        case .matching:
            return "custom"
        }
    }
}

extension OptionalValueMatcher where T == String {
    /// A string-specific description that includes quotes around string values.
    public var stringSpecficDescription: String {
        switch self {
        case .any:
            return "any"
        case .range(let range):
            return "\"\(range.lowerBound)\"...\"\(range.upperBound)\""
        case .exact(let match):
            if let match {
                return "\"\(match)\""
            } else {
                return "nil"
            }
        case .matching:
            return "custom"
        }
    }
}

/// A matcher for optional parameters of types that don't conform to `Comparable`.
///
/// This matcher is limited to matching any value (including nil) since the type
/// doesn't support comparison operations for ranges or exact matching.
///
/// ## Example
/// ```swift
/// when(expectations.process(data: .any), return: result)
/// ```
public enum OptionalNonComparableValueMatcher<T: Sendable>: Sendable, CustomStringConvertible {
    /// Matches any value (nil or non-nil).
    case any
    /// Uses a closure for custom matching logic
    case matching(_ matcher: @Sendable (T?) -> Bool)

    /// Check if the given optional value matches this matcher.
    /// - Parameter value: The optional value to test against this matcher
    /// - Returns: Always `true` since this matcher only supports `.any`
    public func matches(_ value: T?) -> Bool {
        switch self {
        case .any:
            return true
        case .matching(let matcher):
            return matcher(value)
        }
    }

    /// A string representation of this matcher for debugging and error messages.
    public var description: String {
        switch self {
        case .any:
            return "any"
        case .matching:
            return "custom"
        }
    }
}

/// A matcher for optional parameters of types that conform to `Equatable` but not `Comparable`.
///
/// This matcher supports exact value matching (including nil) and any value matching,
/// but not range matching since the type doesn't conform to `Comparable`.
///
/// ## Example
/// ```swift
/// when(expectations.setItem(item: .any), return: success)
/// when(expectations.setItem(item: nil), return: success)
/// when(expectations.setItem(item: specificItem), return: success)
/// ```
public enum OptionalOnlyEquatableValueMatcher<T: Equatable & Sendable>: Sendable, CustomStringConvertible {
    /// Matches any value (nil or non-nil).
    case any
    /// Matches the exact specified value (which may be nil).
    case exact(T?)
    /// Uses a closure for custom matching logic
    case matching(_ matcher: @Sendable (T?) -> Bool)

    /// Check if the given optional value matches this matcher.
    /// - Parameter value: The optional value to test against this matcher
    /// - Returns: `true` if the value matches, `false` otherwise
    public func matches(_ value: T?) -> Bool {
        switch self {
        case .any:
            return true
        case .exact(let match):
            return value == match
        case .matching(let matcher):
            return matcher(value)
        }
    }

    /// A string representation of this matcher for debugging and error messages.
    public var description: String {
        switch self {
        case .any:
            return "any"
        case .exact(let match):
            if let match {
                return "\(match)"
            } else {
                return "nil"
            }
        case .matching:
            return "custom"
        }
    }
}
