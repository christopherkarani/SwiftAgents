// MockSummarizer.swift
// Swarm Framework
//
// Mock summarizer for testing memory systems.

import Foundation
@testable import Swarm

// MARK: - MockSummarizer

/// Mock summarizer for testing.
///
/// Provides controllable summarization behavior for unit tests.
/// Tracks all calls for verification.
///
/// ## Usage
///
/// ```swift
/// let mock = MockSummarizer()
/// await mock.stub(result: "Test summary")
///
/// let memory = SummaryMemory(summarizer: mock)
/// // ... perform operations ...
///
/// #expect(await mock.callCount == 1)
/// ```
public actor MockSummarizer: Summarizer {
    /// Whether the summarizer reports as available.
    public var isAvailableValue: Bool

    /// The result to return from summarize().
    public var summarizeResult: String

    /// Records of all summarize() calls.
    public var summarizeCalls: [(text: String, maxTokens: Int)] = []

    /// Whether summarize() should throw an error.
    public var shouldThrow: Bool

    /// The error to throw when shouldThrow is true.
    public var errorToThrow: Error

    /// Delay before returning (for testing async behavior).
    public var responseDelay: Duration

    // MARK: - Summarizer Protocol

    public var isAvailable: Bool {
        get async { isAvailableValue }
    }

    /// Returns the most recent summarize call, if any.
    public var lastCall: (text: String, maxTokens: Int)? {
        summarizeCalls.last
    }

    /// Returns the number of times summarize was called.
    public var callCount: Int {
        summarizeCalls.count
    }

    /// Creates a new mock summarizer with configurable initial state.
    ///
    /// - Parameters:
    ///   - isAvailable: Whether summarizer reports as available. Default: true
    ///   - result: Result to return from summarize(). Default: "Mock summary"
    ///   - shouldThrow: Whether to throw errors. Default: false
    ///   - error: Error to throw when shouldThrow is true. Default: SummarizerError.unavailable
    ///   - delay: Response delay for async testing. Default: .zero
    public init(
        isAvailable: Bool = true,
        result: String = "Mock summary",
        shouldThrow: Bool = false,
        error: Error = SummarizerError.unavailable,
        delay: Duration = .zero
    ) {
        isAvailableValue = isAvailable
        summarizeResult = result
        self.shouldThrow = shouldThrow
        errorToThrow = error
        responseDelay = delay
    }

    public func summarize(_ text: String, maxTokens: Int) async throws -> String {
        summarizeCalls.append((text, maxTokens))

        if responseDelay > .zero {
            try? await Task.sleep(for: responseDelay)
        }

        if shouldThrow {
            throw errorToThrow
        }

        return summarizeResult
    }

    // MARK: - Test Helpers

    /// Resets all state to defaults.
    public func reset() {
        summarizeCalls.removeAll()
        isAvailableValue = true
        summarizeResult = "Mock summary"
        shouldThrow = false
        errorToThrow = SummarizerError.unavailable
        responseDelay = .zero
    }

    /// Configures the mock to return a specific result.
    public func stub(result: String) {
        summarizeResult = result
        shouldThrow = false
    }

    /// Configures the mock to throw an error.
    public func stub(error: Error) {
        errorToThrow = error
        shouldThrow = true
    }

    /// Configures availability.
    public func stub(available: Bool) {
        isAvailableValue = available
    }
}

// MARK: - Convenience Factory

public extension MockSummarizer {
    /// Creates a mock that always succeeds with a given result.
    static func succeeding(with result: String = "Mock summary") -> MockSummarizer {
        MockSummarizer(result: result)
    }

    /// Creates a mock that always fails with a given error.
    static func failing(with error: Error = SummarizerError.unavailable) -> MockSummarizer {
        MockSummarizer(shouldThrow: true, error: error)
    }

    /// Creates a mock that reports as unavailable.
    static func unavailable() -> MockSummarizer {
        MockSummarizer(isAvailable: false)
    }
}
