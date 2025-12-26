// PersistentMemoryBackend.swift
// SwiftAgents Framework
//
// Protocol for persistent memory storage backends.

import Foundation

// MARK: - PersistentMemoryBackend

/// Protocol for persistent memory storage backends.
///
/// Implementations provide platform-specific persistence:
/// - `InMemoryBackend` for testing/ephemeral storage (cross-platform)
/// - `SwiftDataBackend` for Apple platforms
/// - User-implemented backends for servers (PostgreSQL, Redis, etc.)
///
/// ## Implementing a Custom Backend
///
/// To create a PostgreSQL backend for server deployments:
///
/// ```swift
/// public actor PostgreSQLBackend: PersistentMemoryBackend {
///     private let pool: PostgresConnectionPool
///
///     public init(connectionString: String) async throws {
///         self.pool = try await PostgresConnectionPool(connectionString)
///     }
///
///     public func store(_ message: MemoryMessage, conversationId: String) async throws {
///         // INSERT INTO messages ...
///     }
///
///     public func fetchMessages(conversationId: String) async throws -> [MemoryMessage] {
///         // SELECT * FROM messages WHERE conversation_id = ...
///     }
///
///     // ... implement remaining methods
/// }
/// ```
public protocol PersistentMemoryBackend: Actor, Sendable {
    /// Stores a message in the persistent store.
    ///
    /// - Parameters:
    ///   - message: The message to store.
    ///   - conversationId: The conversation identifier.
    func store(_ message: MemoryMessage, conversationId: String) async throws

    /// Retrieves all messages for a conversation.
    ///
    /// - Parameter conversationId: The conversation identifier.
    /// - Returns: Array of messages in chronological order.
    func fetchMessages(conversationId: String) async throws -> [MemoryMessage]

    /// Retrieves the N most recent messages for a conversation.
    ///
    /// - Parameters:
    ///   - conversationId: The conversation identifier.
    ///   - limit: Maximum number of messages to retrieve.
    /// - Returns: Array of recent messages in chronological order.
    func fetchRecentMessages(conversationId: String, limit: Int) async throws -> [MemoryMessage]

    /// Deletes all messages for a conversation.
    ///
    /// - Parameter conversationId: The conversation identifier.
    func deleteMessages(conversationId: String) async throws

    /// Returns the message count for a conversation.
    ///
    /// - Parameter conversationId: The conversation identifier.
    /// - Returns: Number of messages in the conversation.
    func messageCount(conversationId: String) async throws -> Int

    /// Returns all conversation IDs in the store.
    ///
    /// - Returns: Array of unique conversation identifiers.
    func allConversationIds() async throws -> [String]

    /// Stores multiple messages in a single batch operation.
    ///
    /// Default implementation calls `store` for each message.
    /// Override for optimized batch inserts.
    ///
    /// - Parameters:
    ///   - messages: The messages to store.
    ///   - conversationId: The conversation identifier.
    func storeAll(_ messages: [MemoryMessage], conversationId: String) async throws

    /// Deletes oldest messages, keeping only the most recent N.
    ///
    /// Default implementation fetches all messages, then deletes and re-inserts.
    /// Override for optimized database operations (e.g., DELETE with ORDER BY and LIMIT).
    ///
    /// - Parameters:
    ///   - conversationId: The conversation identifier.
    ///   - keepRecent: Number of recent messages to keep.
    func deleteOldestMessages(conversationId: String, keepRecent: Int) async throws

    /// Deletes and returns the most recent message from a conversation.
    ///
    /// This is an O(1) operation that fetches only the last message (using fetchLimit: 1
    /// with descending timestamp order), deletes it, and returns its content.
    ///
    /// Default implementation fetches all messages and performs O(n) operations.
    /// Override for optimized single-message deletion.
    ///
    /// - Parameter conversationId: The conversation identifier.
    /// - Returns: The deleted message, or `nil` if the conversation is empty.
    func deleteLastMessage(conversationId: String) async throws -> MemoryMessage?
}

// MARK: - Default Implementations

public extension PersistentMemoryBackend {
    func storeAll(_ messages: [MemoryMessage], conversationId: String) async throws {
        for message in messages {
            try await store(message, conversationId: conversationId)
        }
    }

    func deleteOldestMessages(conversationId: String, keepRecent: Int) async throws {
        // Default implementation: fetch all, keep recent, delete and re-insert
        let allMessages = try await fetchMessages(conversationId: conversationId)
        guard allMessages.count > keepRecent else { return }

        let messagesToKeep = Array(allMessages.suffix(keepRecent))
        try await deleteMessages(conversationId: conversationId)
        try await storeAll(messagesToKeep, conversationId: conversationId)
    }

    func deleteLastMessage(conversationId: String) async throws -> MemoryMessage? {
        // Default O(n) implementation: fetch all, delete all, re-insert all but last
        // Override this method for optimized O(1) implementations
        let allMessages = try await fetchMessages(conversationId: conversationId)
        guard !allMessages.isEmpty else { return nil }

        let lastMessage = allMessages[allMessages.count - 1]
        let remainingMessages = Array(allMessages.dropLast())

        try await deleteMessages(conversationId: conversationId)
        if !remainingMessages.isEmpty {
            try await storeAll(remainingMessages, conversationId: conversationId)
        }

        return lastMessage
    }
}

// MARK: - PersistentMemoryError

/// Errors that can occur during persistent memory operations.
public enum PersistentMemoryError: Error, Sendable, CustomStringConvertible {
    // MARK: Public

    public var description: String {
        switch self {
        case let .storeFailed(reason):
            "Failed to store message: \(reason)"
        case let .fetchFailed(reason):
            "Failed to fetch messages: \(reason)"
        case let .deleteFailed(reason):
            "Failed to delete messages: \(reason)"
        case let .connectionFailed(reason):
            "Database connection failed: \(reason)"
        case .notConfigured:
            "Persistent memory backend not configured"
        case .invalidConversationId:
            "Invalid conversation ID"
        }
    }

    case storeFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    case connectionFailed(String)
    case notConfigured
    case invalidConversationId
}
