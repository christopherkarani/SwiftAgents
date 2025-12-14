// Extensions.swift
// SwiftAgents Framework
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

extension Duration {
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
    public var timeInterval: TimeInterval {
        let (seconds, attoseconds) = self.components

        // Handle overflow for very large durations
        guard seconds <= Int64(Double.greatestFiniteMagnitude) else {
            return .infinity
        }

        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
