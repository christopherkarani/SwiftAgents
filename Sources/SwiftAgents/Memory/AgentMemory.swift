// AgentMemory.swift
// SwiftAgents Framework
//
// Core protocol defining memory storage and retrieval for agents.

import Foundation

/// Protocol defining memory storage and retrieval for agents.
///
/// `AgentMemory` provides the contract for storing conversation history
/// and retrieving relevant context for agent operations. All implementations
/// must be actors to ensure thread-safe access.
///
/// ## Conformance Requirements
///
/// - Must be an `actor` (inherited from protocol requirements)
/// - Must be `Sendable` for safe concurrent access
/// - All methods are implicitly `async` due to actor isolation
///
/// ## Example Implementation
///
/// ```swift
/// public actor MyCustomMemory: AgentMemory {
///     private var messages: [MemoryMessage] = []
///
///     public func add(_ message: MemoryMessage) async {
///         messages.append(message)
///     }
///
///     public func getContext(for query: String, tokenLimit: Int) async -> String {
///         formatMessagesForContext(messages, tokenLimit: tokenLimit)
///     }
///
///     public func getAllMessages() async -> [MemoryMessage] {
///         messages
///     }
///
///     public func clear() async {
///         messages.removeAll()
///     }
///
///     public var count: Int { messages.count }
/// }
/// ```
public protocol AgentMemory: Actor, Sendable {
    /// Adds a message to memory.
    ///
    /// - Parameter message: The message to store.
    func add(_ message: MemoryMessage) async

    /// Retrieves context relevant to the query within token limits.
    ///
    /// The implementation determines how to select and format messages.
    /// Simple implementations may return recent messages; advanced ones
    /// may use semantic search or summarization.
    ///
    /// - Parameters:
    ///   - query: The query to find relevant context for.
    ///   - tokenLimit: Maximum tokens to include in the context.
    /// - Returns: A formatted string containing relevant context.
    func getContext(for query: String, tokenLimit: Int) async -> String

    /// Returns all messages currently in memory.
    ///
    /// - Returns: Array of all stored messages, typically in chronological order.
    func getAllMessages() async -> [MemoryMessage]

    /// Removes all messages from memory.
    func clear() async

    /// The number of messages currently stored.
    var count: Int { get async }

    /// Whether the memory contains no messages.
    ///
    /// Implementations should provide an efficient check that avoids
    /// fetching all messages when possible.
    var isEmpty: Bool { get async }
}

// MARK: - Helper Functions

/// Formats messages into a context string within token limits.
///
/// Processes messages from most recent to oldest, including as many
/// as fit within the token budget.
///
/// - Parameters:
///   - messages: Messages to format.
///   - tokenLimit: Maximum tokens allowed.
///   - tokenEstimator: Estimator for token counting.
/// - Returns: Formatted context string with messages joined by double newlines.
public func formatMessagesForContext(
    _ messages: [MemoryMessage],
    tokenLimit: Int,
    tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared
) -> String {
    var result: [String] = []
    var currentTokens = 0

    // Process messages in reverse (most recent first) then reverse result
    for message in messages.reversed() {
        let formatted = message.formattedContent
        let messageTokens = tokenEstimator.estimateTokens(for: formatted)

        if currentTokens + messageTokens <= tokenLimit {
            result.append(formatted)
            currentTokens += messageTokens
        } else {
            break
        }
    }

    return result.reversed().joined(separator: "\n\n")
}

/// Formats messages with a custom separator.
///
/// - Parameters:
///   - messages: Messages to format.
///   - tokenLimit: Maximum tokens allowed.
///   - separator: String to join messages (default: double newline).
///   - tokenEstimator: Estimator for token counting.
/// - Returns: Formatted context string.
public func formatMessagesForContext(
    _ messages: [MemoryMessage],
    tokenLimit: Int,
    separator: String,
    tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared
) -> String {
    var result: [String] = []
    var currentTokens = 0
    let separatorTokens = tokenEstimator.estimateTokens(for: separator)

    for message in messages.reversed() {
        let formatted = message.formattedContent
        let messageTokens = tokenEstimator.estimateTokens(for: formatted)
        let totalNeeded = messageTokens + (result.isEmpty ? 0 : separatorTokens)

        if currentTokens + totalNeeded <= tokenLimit {
            result.append(formatted)
            currentTokens += totalNeeded
        } else {
            break
        }
    }

    return result.reversed().joined(separator: separator)
}

// MARK: - Type-Erased Memory Wrapper

/// Type-erased wrapper for any AgentMemory implementation.
///
/// Useful when you need to store different memory types in collections
/// or pass them through APIs that don't support generics.
///
/// ## Usage
///
/// ```swift
/// let conversation = ConversationMemory(maxMessages: 50)
/// let erased = AnyAgentMemory(conversation)
/// await erased.add(.user("Hello"))
/// ```
public actor AnyAgentMemory: AgentMemory {
    private let _add: @Sendable (MemoryMessage) async -> Void
    private let _getContext: @Sendable (String, Int) async -> String
    private let _getAllMessages: @Sendable () async -> [MemoryMessage]
    private let _clear: @Sendable () async -> Void
    private let _count: @Sendable () async -> Int
    private let _isEmpty: @Sendable () async -> Bool

    /// Creates a type-erased wrapper around any AgentMemory.
    ///
    /// - Parameter memory: The memory implementation to wrap.
    public init<M: AgentMemory>(_ memory: M) {
        _add = { message in await memory.add(message) }
        _getContext = { query, limit in await memory.getContext(for: query, tokenLimit: limit) }
        _getAllMessages = { await memory.getAllMessages() }
        _clear = { await memory.clear() }
        _count = { await memory.count }
        _isEmpty = { await memory.isEmpty }
    }

    public func add(_ message: MemoryMessage) async {
        await _add(message)
    }

    public func getContext(for query: String, tokenLimit: Int) async -> String {
        await _getContext(query, tokenLimit)
    }

    public func getAllMessages() async -> [MemoryMessage] {
        await _getAllMessages()
    }

    public func clear() async {
        await _clear()
    }

    public var count: Int {
        get async {
            await _count()
        }
    }

    public var isEmpty: Bool {
        get async {
            await _isEmpty()
        }
    }
}
