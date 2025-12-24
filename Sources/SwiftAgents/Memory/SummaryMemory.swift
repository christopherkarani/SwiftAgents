// SummaryMemory.swift
// SwiftAgents Framework
//
// Memory that automatically summarizes old messages to compress history.

import Foundation

// MARK: - SummaryMemory

/// Memory that automatically summarizes old messages to compress history.
///
/// `SummaryMemory` maintains a summary of older conversation history
/// while keeping recent messages intact. When the message count exceeds
/// a threshold, older messages are summarized using the provided `Summarizer`.
///
/// ## Architecture
///
/// ```
/// [Summary of messages 1-50] + [Recent messages 51-100]
/// ```
///
/// ## Fallback Behavior
///
/// If the summarizer is unavailable (e.g., no Foundation Models on simulator),
/// falls back to truncation to maintain functionality.
///
/// ## Usage
///
/// ```swift
/// let memory = SummaryMemory(
///     configuration: .init(recentMessageCount: 20, summarizationThreshold: 50)
/// )
/// await memory.add(.user("Hello"))
/// // When messages exceed 50, older ones are summarized
/// ```
public actor SummaryMemory: Memory {
    // MARK: Public

    /// Configuration for summary memory behavior.
    public struct Configuration: Sendable {
        /// Default configuration.
        public static let `default` = Configuration()

        /// Number of recent messages to keep unsummarized.
        public let recentMessageCount: Int

        /// Message count threshold that triggers summarization.
        public let summarizationThreshold: Int

        /// Target token count for the summary.
        public let summaryTokenTarget: Int

        /// Creates a summary memory configuration.
        ///
        /// - Parameters:
        ///   - recentMessageCount: Messages to keep intact (default: 20).
        ///   - summarizationThreshold: When to trigger summarization (default: 50).
        ///   - summaryTokenTarget: Target summary size in tokens (default: 500).
        public init(
            recentMessageCount: Int = 20,
            summarizationThreshold: Int = 50,
            summaryTokenTarget: Int = 500
        ) {
            let enforcedRecentCount = max(5, recentMessageCount)
            self.recentMessageCount = enforcedRecentCount
            self.summarizationThreshold = max(enforcedRecentCount + 10, summarizationThreshold)
            self.summaryTokenTarget = max(100, summaryTokenTarget)
        }
    }

    /// Current configuration.
    public let configuration: Configuration

    public var count: Int {
        recentMessages.count
    }

    /// Whether the memory is empty (no recent messages and no summary).
    public var isEmpty: Bool { recentMessages.isEmpty && summary.isEmpty }

    // MARK: - Summary Information

    /// Current summary text.
    public var currentSummary: String {
        summary
    }

    /// Whether a summary exists.
    public var hasSummary: Bool {
        !summary.isEmpty
    }

    /// Total messages processed (including summarized ones).
    public var totalMessages: Int {
        totalMessagesAdded
    }

    /// Creates a new summary memory.
    ///
    /// - Parameters:
    ///   - configuration: Behavior configuration.
    ///   - summarizer: Primary summarization service.
    ///   - fallbackSummarizer: Fallback when primary unavailable.
    ///   - tokenEstimator: Token counting estimator.
    public init(
        configuration: Configuration = .default,
        summarizer: any Summarizer = TruncatingSummarizer.shared,
        fallbackSummarizer: any Summarizer = TruncatingSummarizer.shared,
        tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared
    ) {
        self.configuration = configuration
        self.summarizer = summarizer
        self.fallbackSummarizer = fallbackSummarizer
        self.tokenEstimator = tokenEstimator
    }

    // MARK: - AgentMemory Conformance

    public func add(_ message: MemoryMessage) async {
        recentMessages.append(message)
        totalMessagesAdded += 1

        // Check if summarization needed
        if recentMessages.count >= configuration.summarizationThreshold {
            await performSummarization()
        }
    }

    public func context(for _: String, tokenLimit: Int) async -> String {
        var components: [String] = []
        var remainingTokens = tokenLimit

        // Add summary if present
        if !summary.isEmpty {
            let summaryHeader = "[Previous conversation summary]:\n\(summary)"
            let summaryTokens = tokenEstimator.estimateTokens(for: summaryHeader)
            if summaryTokens <= remainingTokens {
                components.append(summaryHeader)
                remainingTokens -= summaryTokens
            }
        }

        // Add recent messages within remaining budget
        if remainingTokens > 0 {
            let recentContext = formatMessagesForContext(
                recentMessages,
                tokenLimit: remainingTokens,
                tokenEstimator: tokenEstimator
            )
            if !recentContext.isEmpty {
                components.append(recentContext)
            }
        }

        return components.joined(separator: "\n\n")
    }

    public func allMessages() async -> [MemoryMessage] {
        recentMessages
    }

    public func clear() async {
        summary = ""
        recentMessages.removeAll()
        totalMessagesAdded = 0
    }

    // MARK: Private

    /// Summarization service.
    private let summarizer: any Summarizer

    /// Fallback summarizer when primary unavailable.
    private let fallbackSummarizer: any Summarizer

    /// Token estimator.
    private let tokenEstimator: any TokenEstimator

    /// Compressed summary of old messages.
    private var summary: String = ""

    /// Recent messages not yet summarized.
    private var recentMessages: [MemoryMessage] = []

    /// Total messages ever added (for tracking).
    private var totalMessagesAdded: Int = 0

    /// Number of summarization operations performed.
    private var summarizationCount: Int = 0

    // MARK: - Private Methods

    private func performSummarization() async {
        // Keep only recent messages, summarize the rest
        let messagesToKeep = configuration.recentMessageCount
        let toSummarize = Array(recentMessages.prefix(recentMessages.count - messagesToKeep))
        recentMessages = Array(recentMessages.suffix(messagesToKeep))

        guard !toSummarize.isEmpty else { return }

        // Combine with existing summary
        let textToSummarize: String = if summary.isEmpty {
            toSummarize.map(\.formattedContent).joined(separator: "\n")
        } else {
            """
            Previous summary:
            \(summary)

            Additional conversation:
            \(toSummarize.map(\.formattedContent).joined(separator: "\n"))
            """
        }

        // Try primary summarizer, fall back if needed
        do {
            if await summarizer.isAvailable {
                summary = try await summarizer.summarize(textToSummarize, maxTokens: configuration.summaryTokenTarget)
            } else {
                summary = try await fallbackSummarizer.summarize(textToSummarize, maxTokens: configuration.summaryTokenTarget)
            }
            summarizationCount += 1
        } catch {
            // On failure, use truncation as last resort
            if let truncated = try? await TruncatingSummarizer.shared.summarize(
                textToSummarize,
                maxTokens: configuration.summaryTokenTarget
            ) {
                summary = truncated
            } else {
                // Ultimate fallback: just prefix
                summary = String(textToSummarize.prefix(configuration.summaryTokenTarget * 4))
            }
        }
    }
}

// MARK: - Manual Summarization

public extension SummaryMemory {
    /// Forces summarization even if threshold not reached.
    ///
    /// Useful when you know a conversation break is happening
    /// and want to compress before continuing.
    func forceSummarize() async {
        guard recentMessages.count > configuration.recentMessageCount else { return }
        await performSummarization()
    }

    /// Sets a custom summary, replacing any existing one.
    ///
    /// - Parameter newSummary: The summary text to use.
    func setSummary(_ newSummary: String) async {
        summary = newSummary
    }
}

// MARK: - Diagnostics

public extension SummaryMemory {
    /// Returns diagnostic information about memory state.
    func diagnostics() async -> SummaryMemoryDiagnostics {
        SummaryMemoryDiagnostics(
            recentMessageCount: recentMessages.count,
            totalMessagesProcessed: totalMessagesAdded,
            hasSummary: !summary.isEmpty,
            summaryTokenCount: tokenEstimator.estimateTokens(for: summary),
            summarizationCount: summarizationCount,
            nextSummarizationIn: max(0, configuration.summarizationThreshold - recentMessages.count)
        )
    }
}

// MARK: - SummaryMemoryDiagnostics

/// Diagnostic information for summary memory.
public struct SummaryMemoryDiagnostics: Sendable {
    /// Current number of recent (unsummarized) messages.
    public let recentMessageCount: Int
    /// Total messages processed since creation.
    public let totalMessagesProcessed: Int
    /// Whether a summary currently exists.
    public let hasSummary: Bool
    /// Estimated token count of current summary.
    public let summaryTokenCount: Int
    /// Number of times summarization has been performed.
    public let summarizationCount: Int
    /// Messages until next summarization triggers.
    public let nextSummarizationIn: Int
}
