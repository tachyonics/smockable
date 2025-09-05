// ValueMatcher and OptionalValueMatcher for range-based expectation matching

public struct AlwaysMatcher: Sendable {
    public init() {

    }

    public func matches() -> Bool {
        return true
    }
}

/// A matcher for non-optional parameters that can match any value or values within a range
public enum ValueMatcher<T: Comparable & Sendable>: Sendable {
    case any  // Matches any value
    case range(ClosedRange<T>)  // Matches values in range

    /// Check if the given value matches this matcher
    public func matches(_ value: T) -> Bool {
        switch self {
        case .any:
            return true
        case .range(let range):
            return range.contains(value)
        }
    }
}

/// A matcher for optional parameters with support for nil matching
public enum OptionalValueMatcher<T: Comparable & Sendable>: Sendable {
    case any  // Matches any value (nil or non-nil)
    case `nil`  // Matches only nil
    case range(ClosedRange<T>)  // Matches only non-nil values in range

    /// Check if the given optional value matches this matcher
    public func matches(_ value: T?) -> Bool {
        switch self {
        case .any:
            return true
        case .nil:
            return value == nil
        case .range(let range):
            guard let unwrapped = value else { return false }
            return range.contains(unwrapped)
        }
    }
}

// MARK: - Convenience Extensions

extension ValueMatcher {
    /// Create a ValueMatcher from a ClosedRange
    public init(_ range: ClosedRange<T>) {
        self = .range(range)
    }
}

extension OptionalValueMatcher {
    /// Create an OptionalValueMatcher from a ClosedRange (matches only non-nil values in range)
    public init(_ range: ClosedRange<T>) {
        self = .range(range)
    }
}
