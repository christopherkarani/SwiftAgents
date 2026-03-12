// TokenUsage.swift
// Swarm Framework
//
// Token usage statistics for inference calls.

import Foundation

// MARK: - TokenUsage

/// Token usage statistics for a generation.
///
/// Tracks input and output token counts for monitoring
/// and cost estimation purposes.
public struct TokenUsage: Sendable, Equatable, Codable {
    /// Number of tokens in the input/prompt.
    public let inputTokens: Int

    /// Number of tokens in the output/response.
    public let outputTokens: Int

    /// Total tokens used (input + output).
    public var totalTokens: Int {
        inputTokens + outputTokens
    }

    /// Creates token usage statistics.
    /// - Parameters:
    ///   - inputTokens: Input token count.
    ///   - outputTokens: Output token count.
    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

// MARK: - TokenUsage + CustomStringConvertible

extension TokenUsage: CustomStringConvertible {
    public var description: String {
        "TokenUsage(input: \(inputTokens), output: \(outputTokens), total: \(totalTokens))"
    }
}
