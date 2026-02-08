// HybridMemory.swift
// Swarm Framework
//
// Combines multiple memory strategies for comprehensive context management.

import Foundation

// MARK: - HybridMemory

/// Combines multiple memory types for comprehensive context management.
///
/// `HybridMemory` maintains both short-term (conversation) and long-term
/// (summary) memory, intelligently combining them for context retrieval.
///
/// ## Architecture
///
/// ```
/// User Query
///     │
///     ▼
/// ┌─────────────────────┐
/// │   Short-term        │ ← Recent N messages
/// │   (Conversation)    │
/// ├─────────────────────┤
/// │   Long-term         │ ← Summarized history
/// │   (Summary)         │
/// └─────────────────────┘
/// ```
///
/// ## Context Retrieval Strategy
///
/// 1. Allocate portion of token budget to summary (configurable ratio)
/// 2. Fill remaining budget with recent messages
/// 3. Return combined context
///
/// ## Usage
///
/// ```swift
/// let memory = HybridMemory(
///     configuration: .init(shortTermMaxMessages: 30, summaryTokenRatio: 0.3)
/// )
/// await memory.add(.user("Hello"))
/// let context = await memory.context(for: "question", tokenLimit: 4000)
/// ```
public actor HybridMemory: Memory {
    // MARK: Public

    /// Configuration for hybrid memory behavior.
    public struct Configuration: Sendable {
        /// Default configuration.
        public static let `default` = Configuration()

        /// Maximum messages in short-term memory.
        public let shortTermMaxMessages: Int

        /// Token limit for long-term summary.
        public let longTermSummaryTokens: Int

        /// Ratio of token budget allocated to summary (0.0 - 1.0).
        public let summaryTokenRatio: Double

        /// Message threshold for triggering summarization.
        public let summarizationThreshold: Int

        /// Creates a hybrid memory configuration.
        ///
        /// - Parameters:
        ///   - shortTermMaxMessages: Messages in short-term memory (default: 30).
        ///   - longTermSummaryTokens: Max tokens for summary (default: 1000).
        ///   - summaryTokenRatio: Context budget ratio for summary (default: 0.3).
        ///   - summarizationThreshold: Messages before summarization (default: 60).
        public init(
            shortTermMaxMessages: Int = 30,
            longTermSummaryTokens: Int = 1000,
            summaryTokenRatio: Double = 0.3,
            summarizationThreshold: Int = 60
        ) {
            self.shortTermMaxMessages = max(10, shortTermMaxMessages)
            self.longTermSummaryTokens = max(200, longTermSummaryTokens)
            self.summaryTokenRatio = min(max(0.1, summaryTokenRatio), 0.5)
            self.summarizationThreshold = max(shortTermMaxMessages * 2, summarizationThreshold)
        }
    }

    /// Current configuration.
    public let configuration: Configuration

    public var count: Int {
        get async {
            await shortTermMemory.count
        }
    }

    /// Whether the memory is empty (no short-term messages and no summary).
    public var isEmpty: Bool {
        get async { await shortTermMemory.isEmpty && longTermSummary.isEmpty }
    }

    // MARK: - Summary Information

    /// Current long-term summary.
    public var summary: String {
        longTermSummary
    }

    /// Whether a long-term summary exists.
    public var hasSummary: Bool {
        !longTermSummary.isEmpty
    }

    /// Total messages processed.
    public var totalMessages: Int {
        totalMessagesAdded
    }

    /// Creates a new hybrid memory.
    ///
    /// - Parameters:
    ///   - configuration: Behavior configuration.
    ///   - summarizer: Summarization service.
    ///   - tokenEstimator: Token counting estimator.
    public init(
        configuration: Configuration = .default,
        summarizer: any Summarizer = TruncatingSummarizer.shared,
        tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared
    ) {
        self.configuration = configuration
        shortTermMemory = ConversationMemory(
            maxMessages: configuration.shortTermMaxMessages,
            tokenEstimator: tokenEstimator
        )
        self.summarizer = summarizer
        self.tokenEstimator = tokenEstimator
    }

    // MARK: - AgentMemory Conformance

    public func add(_ message: MemoryMessage) async {
        await shortTermMemory.add(message)
        pendingMessages.append(message)
        totalMessagesAdded += 1

        // Check if we should update long-term summary
        if pendingMessages.count >= configuration.summarizationThreshold {
            await updateLongTermSummary()
        }
    }

    public func context(for query: String, tokenLimit: Int) async -> String {
        var components: [String] = []

        // Calculate token allocation
        let summaryTokenBudget = Int(Double(tokenLimit) * configuration.summaryTokenRatio)
        let recentTokenBudget = tokenLimit - summaryTokenBudget

        // Add long-term summary if available
        if !longTermSummary.isEmpty {
            let summaryHeader = "[Conversation history summary]:\n\(longTermSummary)"
            let summaryTokens = tokenEstimator.estimateTokens(for: summaryHeader)

            if summaryTokens <= summaryTokenBudget {
                components.append(summaryHeader)
            } else {
                // Truncate summary if too long
                if let truncated = try? await TruncatingSummarizer.shared.summarize(
                    longTermSummary,
                    maxTokens: summaryTokenBudget
                ) {
                    components.append("[Conversation history summary]:\n\(truncated)")
                }
            }
        }

        // Add recent messages from short-term memory
        let recentContext = await shortTermMemory.context(for: query, tokenLimit: recentTokenBudget)
        if !recentContext.isEmpty {
            components.append("[Recent conversation]:\n\(recentContext)")
        }

        return components.joined(separator: "\n\n")
    }

    public func allMessages() async -> [MemoryMessage] {
        await shortTermMemory.allMessages()
    }

    public func clear() async {
        await shortTermMemory.clear()
        longTermSummary = ""
        pendingMessages.removeAll()
        totalMessagesAdded = 0
    }

    // MARK: Private

    /// Short-term memory component.
    private let shortTermMemory: ConversationMemory

    /// Long-term summary storage.
    private var longTermSummary: String = ""

    /// Summarization service.
    private let summarizer: any Summarizer

    /// Token estimator.
    private let tokenEstimator: any TokenEstimator

    /// Messages pending summarization.
    private var pendingMessages: [MemoryMessage] = []

    /// Total messages processed.
    private var totalMessagesAdded: Int = 0

    /// Number of summarizations performed.
    private var summarizationCount: Int = 0

    // MARK: - Private Methods

    private func updateLongTermSummary() async {
        let messagesToSummarize = pendingMessages
        pendingMessages.removeAll()

        guard !messagesToSummarize.isEmpty else { return }

        let newContent = messagesToSummarize.map(\.formattedContent).joined(separator: "\n")

        let textToSummarize: String = if longTermSummary.isEmpty {
            newContent
        } else {
            """
            Existing summary:
            \(longTermSummary)

            New conversation:
            \(newContent)
            """
        }

        do {
            if await summarizer.isAvailable {
                longTermSummary = try await summarizer.summarize(
                    textToSummarize,
                    maxTokens: configuration.longTermSummaryTokens
                )
                summarizationCount += 1
            }
        } catch {
            // Keep existing summary on failure, add truncated new content
            if let truncated = try? await TruncatingSummarizer.shared.summarize(
                newContent,
                maxTokens: configuration.longTermSummaryTokens / 2
            ) {
                if longTermSummary.isEmpty {
                    longTermSummary = truncated
                } else {
                    longTermSummary = "\(longTermSummary)\n\n[Additional context]: \(truncated)"
                }
            }
        }
    }
}

// MARK: - Manual Operations

public extension HybridMemory {
    /// Forces summarization even if threshold not reached.
    func forceSummarize() async {
        guard !pendingMessages.isEmpty else { return }
        await updateLongTermSummary()
    }

    /// Sets a custom long-term summary.
    ///
    /// - Parameter newSummary: The summary text to use.
    func setSummary(_ newSummary: String) async {
        longTermSummary = newSummary
    }

    /// Clears only the long-term summary, keeping recent messages.
    func clearSummary() async {
        longTermSummary = ""
        pendingMessages.removeAll()
    }
}

// MARK: - Diagnostics

public extension HybridMemory {
    /// Returns diagnostic information about memory state.
    func diagnostics() async -> HybridMemoryDiagnostics {
        await HybridMemoryDiagnostics(
            shortTermMessageCount: shortTermMemory.count,
            shortTermMaxMessages: configuration.shortTermMaxMessages,
            pendingMessages: pendingMessages.count,
            totalMessagesProcessed: totalMessagesAdded,
            hasSummary: !longTermSummary.isEmpty,
            summaryTokenCount: tokenEstimator.estimateTokens(for: longTermSummary),
            summarizationCount: summarizationCount,
            nextSummarizationIn: max(0, configuration.summarizationThreshold - pendingMessages.count)
        )
    }
}

// MARK: - HybridMemoryDiagnostics

/// Diagnostic information for hybrid memory.
public struct HybridMemoryDiagnostics: Sendable {
    /// Messages in short-term memory.
    public let shortTermMessageCount: Int
    /// Maximum short-term capacity.
    public let shortTermMaxMessages: Int
    /// Messages awaiting summarization.
    public let pendingMessages: Int
    /// Total messages processed since creation.
    public let totalMessagesProcessed: Int
    /// Whether a long-term summary exists.
    public let hasSummary: Bool
    /// Estimated token count of summary.
    public let summaryTokenCount: Int
    /// Number of summarizations performed.
    public let summarizationCount: Int
    /// Messages until next summarization.
    public let nextSummarizationIn: Int
}
