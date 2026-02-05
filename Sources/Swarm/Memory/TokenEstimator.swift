// TokenEstimator.swift
// Swarm Framework
//
// Token counting abstraction for memory management.

import Foundation

// MARK: - TokenEstimator

/// Protocol for estimating token counts from text.
///
/// Different LLMs use different tokenization schemes. This protocol
/// allows pluggable token estimation strategies.
public protocol TokenEstimator: Sendable {
    /// Estimates the number of tokens in the given text.
    ///
    /// - Parameter text: The text to estimate tokens for.
    /// - Returns: Estimated token count.
    func estimateTokens(for text: String) -> Int

    /// Estimates the total tokens for multiple texts.
    ///
    /// - Parameter texts: Array of texts to estimate.
    /// - Returns: Total estimated token count.
    func estimateTokens(for texts: [String]) -> Int
}

// MARK: - Default Implementation

public extension TokenEstimator {
    func estimateTokens(for texts: [String]) -> Int {
        texts.reduce(0) { $0 + estimateTokens(for: $1) }
    }
}

// MARK: - CharacterBasedTokenEstimator

/// Character-based token estimator using approximation.
///
/// Uses the heuristic that ~4 characters equals 1 token on average.
/// This is a reasonable approximation for English text with GPT-style tokenizers.
///
/// ## Usage
///
/// ```swift
/// let estimator = CharacterBasedTokenEstimator.shared
/// let tokens = estimator.estimateTokens(for: "Hello, world!")
/// // tokens ≈ 3
/// ```
public struct CharacterBasedTokenEstimator: TokenEstimator, Sendable {
    /// Shared instance for convenience.
    public static let shared = CharacterBasedTokenEstimator()

    /// Characters per token ratio (default: 4).
    public let charactersPerToken: Int

    /// Creates a character-based token estimator.
    ///
    /// - Parameter charactersPerToken: Average characters per token (default: 4).
    public init(charactersPerToken: Int = 4) {
        self.charactersPerToken = max(1, charactersPerToken)
    }

    public func estimateTokens(for text: String) -> Int {
        max(1, text.count / charactersPerToken)
    }
}

// MARK: - WordBasedTokenEstimator

/// Word-based token estimator.
///
/// Uses word count as a proxy for tokens. Can be more accurate for
/// some use cases, especially non-English text or technical content.
///
/// ## Usage
///
/// ```swift
/// let estimator = WordBasedTokenEstimator.shared
/// let tokens = estimator.estimateTokens(for: "Hello world")
/// // tokens ≈ 3 (2 words × 1.3)
/// ```
public struct WordBasedTokenEstimator: TokenEstimator, Sendable {
    /// Shared instance with default configuration.
    public static let shared = WordBasedTokenEstimator()

    /// Tokens per word ratio (default: 1.3).
    public let tokensPerWord: Double

    /// Creates a word-based token estimator.
    ///
    /// - Parameter tokensPerWord: Average tokens per word (default: 1.3).
    public init(tokensPerWord: Double = 1.3) {
        self.tokensPerWord = max(0.1, tokensPerWord)
    }

    public func estimateTokens(for text: String) -> Int {
        let wordCount = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        return max(1, Int(Double(wordCount) * tokensPerWord))
    }
}

// MARK: - AveragingTokenEstimator

/// Combines multiple estimators and returns the average.
///
/// Useful for getting a more balanced estimate when the text type is unknown.
public struct AveragingTokenEstimator: TokenEstimator, Sendable {
    // MARK: Public

    /// Default instance combining character and word-based estimators.
    public static let shared = AveragingTokenEstimator(estimators: [
        CharacterBasedTokenEstimator.shared,
        WordBasedTokenEstimator.shared
    ])

    /// Creates an averaging token estimator.
    ///
    /// - Parameter estimators: The estimators to average.
    public init(estimators: [any TokenEstimator]) {
        self.estimators = estimators.isEmpty
            ? [CharacterBasedTokenEstimator.shared]
            : estimators
    }

    public func estimateTokens(for text: String) -> Int {
        let total = estimators.reduce(0) { $0 + $1.estimateTokens(for: text) }
        return max(1, total / estimators.count)
    }

    // MARK: Private

    private let estimators: [any TokenEstimator]
}
