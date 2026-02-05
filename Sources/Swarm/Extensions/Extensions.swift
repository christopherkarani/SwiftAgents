// Extensions.swift
// Swarm Framework
//
// Swift standard library and Foundation extensions.
// Utility extensions for:
// - Async sequence helpers
// - String processing for prompts
// - Collection utilities
// - Codable helpers for structured output
//
// To be implemented as needed

import Foundation

// MARK: - Duration Extensions

public extension Duration {
    /// Converts a Duration to TimeInterval (seconds as Double).
    ///
    /// This is useful for interoperability with APIs that expect TimeInterval,
    /// such as DispatchQueue and legacy Foundation APIs.
    ///
    /// For durations that exceed `Double.greatestFiniteMagnitude`, this property
    /// returns `.infinity` to prevent overflow.
    ///
    /// Example:
    /// ```swift
    /// let duration: Duration = .seconds(30)
    /// let interval: TimeInterval = duration.timeInterval  // 30.0
    ///
    /// let veryLong: Duration = .seconds(Int64.max)
    /// let infinite: TimeInterval = veryLong.timeInterval  // .infinity
    /// ```
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components

        // Handle overflow for very large durations
        // Int64 values beyond 2^53 lose precision when converted to Double,
        // and extremely large durations should be treated as infinity
        let maxSafeSeconds: Int64 = 1 << 53 // 9_007_199_254_740_992
        guard seconds < maxSafeSeconds else {
            return .infinity
        }

        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
