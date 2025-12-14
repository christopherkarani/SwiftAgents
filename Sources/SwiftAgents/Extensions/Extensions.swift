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
    /// Example:
    /// ```swift
    /// let duration: Duration = .seconds(30)
    /// let interval: TimeInterval = duration.timeInterval  // 30.0
    /// ```
    public var timeInterval: TimeInterval {
        let (seconds, attoseconds) = self.components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
