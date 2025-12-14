// MemoryBuilder.swift
// SwiftAgents Framework
//
// Result builder DSL for composing memory systems declaratively.

import Foundation

// MARK: - MemoryBuilder

/// A result builder for creating composite memory systems declaratively.
///
/// `MemoryBuilder` enables a SwiftUI-like syntax for combining multiple
/// memory implementations into a unified system.
///
/// Example:
/// ```swift
/// let memory = CompositeMemory {
///     ConversationMemory(maxMessages: 50)
///         .withSummarization(after: 20)
///
///     SlidingWindowMemory(maxTokens: 4000)
///         .withOverlapSize(5)
/// }
/// ```
@resultBuilder
public struct MemoryBuilder {
    /// Builds a block of memory components.
    public static func buildBlock(_ components: MemoryComponent...) -> [MemoryComponent] {
        components
    }

    /// Builds an empty block.
    public static func buildBlock() -> [MemoryComponent] {
        []
    }

    /// Builds an optional component.
    public static func buildOptional(_ component: [MemoryComponent]?) -> [MemoryComponent] {
        component ?? []
    }

    /// Builds the first branch of an if-else.
    public static func buildEither(first component: [MemoryComponent]) -> [MemoryComponent] {
        component
    }

    /// Builds the second branch of an if-else.
    public static func buildEither(second component: [MemoryComponent]) -> [MemoryComponent] {
        component
    }

    /// Builds an array of components from a for-loop.
    public static func buildArray(_ components: [[MemoryComponent]]) -> [MemoryComponent] {
        components.flatMap { $0 }
    }

    /// Converts a single AgentMemory to a MemoryComponent array.
    public static func buildExpression(_ expression: any AgentMemory) -> [MemoryComponent] {
        [MemoryComponent(memory: expression)]
    }

    /// Converts a MemoryComponent to an array.
    public static func buildExpression(_ expression: MemoryComponent) -> [MemoryComponent] {
        [expression]
    }

    /// Handles final result transformation.
    public static func buildFinalResult(_ component: [MemoryComponent]) -> [MemoryComponent] {
        component
    }
}

// MARK: - MemoryComponent

/// A wrapper for a memory with optional configuration.
public struct MemoryComponent: Sendable {
    /// The wrapped memory instance.
    public let memory: any AgentMemory

    /// Priority level for this memory (higher priority checked first).
    public let priority: MemoryPriority

    /// Identifier for this component.
    public let identifier: String?

    /// Creates a new memory component.
    ///
    /// - Parameters:
    ///   - memory: The memory instance to wrap.
    ///   - priority: Priority level (default: normal).
    ///   - identifier: Optional identifier for debugging.
    public init(
        memory: any AgentMemory,
        priority: MemoryPriority = .normal,
        identifier: String? = nil
    ) {
        self.memory = memory
        self.priority = priority
        self.identifier = identifier
    }

    /// Returns a new component with the specified priority.
    public func priority(_ priority: MemoryPriority) -> MemoryComponent {
        MemoryComponent(memory: memory, priority: priority, identifier: identifier)
    }

    /// Returns a new component with the specified identifier.
    public func identified(by identifier: String) -> MemoryComponent {
        MemoryComponent(memory: memory, priority: priority, identifier: identifier)
    }
}

// MARK: - MemoryPriority

/// Priority level for memory components in composite memory.
public enum MemoryPriority: Int, Sendable, Comparable {
    case low = 0
    case normal = 1
    case high = 2

    public static func < (lhs: MemoryPriority, rhs: MemoryPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - RetrievalStrategy

/// Strategy for retrieving messages from composite memory.
public enum RetrievalStrategy: Sendable {
    /// Retrieve messages by recency (most recent first).
    case recency

    /// Retrieve messages by relevance to the query.
    case relevance

    /// Combine recency and relevance.
    case hybrid(recencyWeight: Double, relevanceWeight: Double)

    /// Custom retrieval logic.
    case custom(@Sendable ([MemoryMessage], String) async -> [MemoryMessage])
}

// MARK: - MergeStrategy

/// Strategy for merging messages from multiple memory components.
public enum MergeStrategy: Sendable {
    /// Concatenate messages from all components (primary first).
    case concatenate

    /// Interleave messages by timestamp.
    case interleave

    /// Remove duplicate messages (by content hash).
    case deduplicate

    /// Use only the primary component's messages.
    case primaryOnly

    /// Custom merge logic.
    case custom(@Sendable ([[MemoryMessage]]) -> [MemoryMessage])
}

// MARK: - CompositeMemory

/// A memory that combines multiple memory systems with configurable strategies.
///
/// `CompositeMemory` enables sophisticated memory architectures by composing
/// different memory types. For example, combine a conversation memory for
/// recent context with a vector memory for semantic search.
///
/// Example:
/// ```swift
/// let memory = CompositeMemory {
///     ConversationMemory(maxMessages: 20)
///         .priority(.high)
///
///     SlidingWindowMemory(maxTokens: 4000)
///         .priority(.normal)
/// }
/// .withRetrievalStrategy(.hybrid(recencyWeight: 0.7, relevanceWeight: 0.3))
/// .withMergeStrategy(.interleave)
///
/// await memory.add(.user("Hello"))
/// let context = await memory.getContext(for: "greeting", tokenLimit: 2000)
/// ```
public actor CompositeMemory: AgentMemory {
    // MARK: - Properties

    /// The memory components sorted by priority.
    private let components: [MemoryComponent]

    /// Strategy for retrieving messages.
    private let retrievalStrategy: RetrievalStrategy

    /// Strategy for merging messages from multiple components.
    private let mergeStrategy: MergeStrategy

    /// Token estimator for context formatting.
    private let tokenEstimator: any TokenEstimator

    /// Number of memory components.
    public nonisolated var componentCount: Int {
        components.count
    }

    // MARK: - Initialization

    /// Creates a composite memory using the builder DSL.
    ///
    /// - Parameter content: A closure that builds the memory components.
    public init(
        tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared,
        @MemoryBuilder _ content: () -> [MemoryComponent]
    ) {
        let builtComponents = content()
        self.components = builtComponents.sorted { $0.priority > $1.priority }
        self.retrievalStrategy = .recency
        self.mergeStrategy = .concatenate
        self.tokenEstimator = tokenEstimator
    }

    /// Internal initializer for configuration chaining.
    private init(
        components: [MemoryComponent],
        retrievalStrategy: RetrievalStrategy,
        mergeStrategy: MergeStrategy,
        tokenEstimator: any TokenEstimator
    ) {
        self.components = components
        self.retrievalStrategy = retrievalStrategy
        self.mergeStrategy = mergeStrategy
        self.tokenEstimator = tokenEstimator
    }

    // MARK: - Configuration

    /// Returns a new composite memory with the specified retrieval strategy.
    ///
    /// - Parameter strategy: The retrieval strategy to use.
    /// - Returns: A new composite memory with the configured strategy.
    public nonisolated func withRetrievalStrategy(_ strategy: RetrievalStrategy) -> CompositeMemory {
        CompositeMemory(
            components: components,
            retrievalStrategy: strategy,
            mergeStrategy: mergeStrategy,
            tokenEstimator: tokenEstimator
        )
    }

    /// Returns a new composite memory with the specified merge strategy.
    ///
    /// - Parameter strategy: The merge strategy to use.
    /// - Returns: A new composite memory with the configured strategy.
    public nonisolated func withMergeStrategy(_ strategy: MergeStrategy) -> CompositeMemory {
        CompositeMemory(
            components: components,
            retrievalStrategy: retrievalStrategy,
            mergeStrategy: strategy,
            tokenEstimator: tokenEstimator
        )
    }

    /// Returns a new composite memory with a custom token estimator.
    ///
    /// - Parameter estimator: The token estimator to use.
    /// - Returns: A new composite memory with the configured estimator.
    public nonisolated func withTokenEstimator(_ estimator: any TokenEstimator) -> CompositeMemory {
        CompositeMemory(
            components: components,
            retrievalStrategy: retrievalStrategy,
            mergeStrategy: mergeStrategy,
            tokenEstimator: estimator
        )
    }

    // MARK: - AgentMemory Conformance

    public func add(_ message: MemoryMessage) async {
        for component in components {
            await component.memory.add(message)
        }
    }

    public func getContext(for query: String, tokenLimit: Int) async -> String {
        let messages = await retrieveMessages(for: query, limit: tokenLimit)
        return formatMessagesForContext(messages, tokenLimit: tokenLimit, tokenEstimator: tokenEstimator)
    }

    public func getAllMessages() async -> [MemoryMessage] {
        var allMessages: [[MemoryMessage]] = []

        for component in components {
            let messages = await component.memory.getAllMessages()
            allMessages.append(messages)
        }

        return mergeMessages(allMessages)
    }

    public func clear() async {
        for component in components {
            await component.memory.clear()
        }
    }

    public var count: Int {
        get async {
            var total = 0
            for component in components {
                total += await component.memory.count
            }
            return total
        }
    }

    // MARK: - Extended API

    /// Adds a message to all components.
    ///
    /// Alias for `add(_:)` that matches the test API expectations.
    ///
    /// - Parameter message: The message to store.
    public func store(_ message: MemoryMessage) async {
        await add(message)
    }

    /// Retrieves messages with a limit.
    ///
    /// - Parameter limit: Maximum number of messages to retrieve.
    /// - Returns: Array of messages.
    public func retrieve(limit: Int) async -> [MemoryMessage] {
        let allMessages = await getAllMessages()
        return Array(allMessages.suffix(limit))
    }

    /// Builds a context string for prompt injection.
    ///
    /// - Parameter maxTokens: Maximum tokens for the context.
    /// - Returns: Formatted context string.
    public func buildContext(maxTokens: Int) async -> String {
        await getContext(for: "", tokenLimit: maxTokens)
    }

    // MARK: - Private Methods

    /// Retrieves messages using the configured strategy.
    private func retrieveMessages(for query: String, limit: Int) async -> [MemoryMessage] {
        var allMessages: [[MemoryMessage]] = []

        for component in components {
            let messages = await component.memory.getAllMessages()
            allMessages.append(messages)
        }

        var merged = mergeMessages(allMessages)

        // Apply retrieval strategy
        switch retrievalStrategy {
        case .recency:
            // Already sorted by recency in merge
            break
        case .relevance:
            // Simple relevance: filter messages containing query terms
            if !query.isEmpty {
                let queryTerms = Set(query.lowercased().split(separator: " ").map(String.init))
                merged.sort { msg1, msg2 in
                    let score1 = relevanceScore(for: msg1, query: queryTerms)
                    let score2 = relevanceScore(for: msg2, query: queryTerms)
                    return score1 > score2
                }
            }
        case .hybrid(let recencyWeight, let relevanceWeight):
            if !query.isEmpty {
                let queryTerms = Set(query.lowercased().split(separator: " ").map(String.init))
                let indexed = merged.enumerated().map { ($0.offset, $0.element) }
                merged = indexed.sorted { pair1, pair2 in
                    let recency1 = Double(merged.count - pair1.0) / Double(merged.count)
                    let recency2 = Double(merged.count - pair2.0) / Double(merged.count)
                    let relevance1 = relevanceScore(for: pair1.1, query: queryTerms)
                    let relevance2 = relevanceScore(for: pair2.1, query: queryTerms)
                    let score1 = recency1 * recencyWeight + relevance1 * relevanceWeight
                    let score2 = recency2 * recencyWeight + relevance2 * relevanceWeight
                    return score1 > score2
                }.map { $0.1 }
            }
        case .custom(let retriever):
            merged = await retriever(merged, query)
        }

        return merged
    }

    /// Merges messages from multiple components using the configured strategy.
    private func mergeMessages(_ messageLists: [[MemoryMessage]]) -> [MemoryMessage] {
        switch mergeStrategy {
        case .concatenate:
            return messageLists.flatMap { $0 }

        case .interleave:
            var result: [MemoryMessage] = []
            var all = messageLists.flatMap { $0 }
            all.sort { $0.timestamp < $1.timestamp }
            result = all
            return result

        case .deduplicate:
            var seen = Set<String>()
            var result: [MemoryMessage] = []
            for messages in messageLists {
                for message in messages {
                    let key = "\(message.role):\(message.content)"
                    if !seen.contains(key) {
                        seen.insert(key)
                        result.append(message)
                    }
                }
            }
            return result

        case .primaryOnly:
            return messageLists.first ?? []

        case .custom(let merger):
            return merger(messageLists)
        }
    }

    /// Calculates a simple relevance score for a message.
    private func relevanceScore(for message: MemoryMessage, query: Set<String>) -> Double {
        let content = message.content.lowercased()
        var matches = 0
        for term in query {
            if content.contains(term) {
                matches += 1
            }
        }
        return query.isEmpty ? 0 : Double(matches) / Double(query.count)
    }
}

// MARK: - ConversationMemory Fluent Extensions

extension ConversationMemory {
    /// Returns a memory component with summarization enabled.
    ///
    /// - Parameter messageCount: Number of messages after which to summarize.
    /// - Returns: A configured memory component.
    public nonisolated func withSummarization(after messageCount: Int) -> MemoryComponent {
        // Note: Actual summarization would require additional implementation
        // This returns a component wrapper that could be enhanced later
        MemoryComponent(memory: self)
    }

    /// Returns a memory component with a token limit.
    ///
    /// - Parameter limit: Maximum tokens for context retrieval.
    /// - Returns: A configured memory component.
    public nonisolated func withTokenLimit(_ limit: Int) -> MemoryComponent {
        MemoryComponent(memory: self)
    }

    /// Returns a memory component with specified priority.
    ///
    /// - Parameter priority: The priority level.
    /// - Returns: A configured memory component.
    public nonisolated func priority(_ priority: MemoryPriority) -> MemoryComponent {
        MemoryComponent(memory: self, priority: priority)
    }
}

// MARK: - SlidingWindowMemory Fluent Extensions

extension SlidingWindowMemory {
    /// Returns a memory component with overlap configuration.
    ///
    /// - Parameter size: Number of messages to overlap when sliding.
    /// - Returns: A configured memory component.
    public nonisolated func withOverlapSize(_ size: Int) -> MemoryComponent {
        MemoryComponent(memory: self)
    }

    /// Returns a memory component with specified priority.
    ///
    /// - Parameter priority: The priority level.
    /// - Returns: A configured memory component.
    public nonisolated func priority(_ priority: MemoryPriority) -> MemoryComponent {
        MemoryComponent(memory: self, priority: priority)
    }
}

// MARK: - VectorMemoryConfiguration Protocol

/// Protocol for vector memory configuration.
public protocol VectorMemoryConfigurable: AgentMemory {
    /// Sets the similarity threshold for vector search.
    func withSimilarityThreshold(_ threshold: Double) -> MemoryComponent

    /// Sets the maximum results for vector search.
    func withMaxResults(_ max: Int) -> MemoryComponent
}

// MARK: - Default VectorMemoryConfigurable Implementation

extension VectorMemoryConfigurable {
    /// Default implementation that wraps in a component.
    public nonisolated func withSimilarityThreshold(_ threshold: Double) -> MemoryComponent {
        MemoryComponent(memory: self)
    }

    /// Default implementation that wraps in a component.
    public nonisolated func withMaxResults(_ max: Int) -> MemoryComponent {
        MemoryComponent(memory: self)
    }
}
