// ValueMatcher and OptionalValueMatcher for range-based expectation matching

public struct AlwaysMatcher: Sendable {
    public init() {

    }

    public func matches() -> Bool {
        return true
    }
}

/// A matcher for non-optional parameters that can match any value or values within a range
public enum ValueMatcher<T: Comparable & Sendable>: Sendable, CustomStringConvertible {
    case any  // Matches any value
    case range(ClosedRange<T>)  // Matches values in range
    case exact(T)

    /// Check if the given value matches this matcher
    public func matches(_ value: T) -> Bool {
        switch self {
        case .any:
            return true
        case .range(let range):
            return range.contains(value)
        case .exact(let match):
            return value == match
        }
    }

    public var description: String {
        switch self {
        case .any:
            return "any"
        case .range(let range):
            return range.description
        case .exact(let match):
            return "\(match)"
        }
    }
}

extension ValueMatcher where T == String {
    public var stringSpecficDescription: String {
        switch self {
        case .any:
            return "any"
        case .range(let range):
            return "\"\(range.lowerBound)\"...\"\(range.upperBound)\""
        case .exact(let match):
            return "\"\(match)\""
        }
    }
}

public enum NonComparableValueMatcher<T: Sendable>: Sendable, CustomStringConvertible {
    case any  // Matches any value

    /// Check if the given value matches this matcher
    public func matches(_ value: T) -> Bool {
        switch self {
        case .any:
            return true
        }
    }

    public var description: String {
        switch self {
        case .any:
            return "any"
        }
    }
}

public enum OnlyEquatableValueMatcher<T: Equatable & Sendable>: Sendable, CustomStringConvertible {
    case any  // Matches any value
    case exact(T)

    /// Check if the given value matches this matcher
    public func matches(_ value: T) -> Bool {
        switch self {
        case .any:
            return true
        case .exact(let match):
            return value == match
        }
    }

    public var description: String {
        switch self {
        case .any:
            return "any"
        case .exact(let match):
            return "\(match)"
        }
    }
}

/// A matcher for optional parameters with support for nil matching
public enum OptionalValueMatcher<T: Comparable & Sendable>: Sendable, CustomStringConvertible {
    case any  // Matches any value (nil or non-nil)
    case range(ClosedRange<T>)  // Matches only non-nil values in range
    case exact(T?)

    /// Check if the given optional value matches this matcher
    public func matches(_ value: T?) -> Bool {
        switch self {
        case .any:
            return true
        case .range(let range):
            guard let unwrapped = value else { return false }
            return range.contains(unwrapped)
        case .exact(let match):
            return value == match
        }
    }

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
        }
    }
}

extension OptionalValueMatcher where T == String {
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
        }
    }
}

public enum OptionalNonComparableValueMatcher<T: Sendable>: Sendable, CustomStringConvertible {
    case any  // Matches any value (nil or non-nil)

    /// Check if the given optional value matches this matcher
    public func matches(_ value: T?) -> Bool {
        switch self {
        case .any:
            return true
        }
    }

    public var description: String {
        switch self {
        case .any:
            return "any"
        }
    }
}

public enum OptionalOnlyEquatableValueMatcher<T: Equatable & Sendable>: Sendable, CustomStringConvertible {
    case any  // Matches any value (nil or non-nil)
    case exact(T?)

    /// Check if the given optional value matches this matcher
    public func matches(_ value: T?) -> Bool {
        switch self {
        case .any:
            return true
        case .exact(let match):
            return value == match
        }
    }

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
        }
    }
}
