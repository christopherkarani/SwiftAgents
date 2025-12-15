// PersistentMemoryBackend.swift
// SwiftAgents Framework
//
// Protocol for persistent memory storage backends.

import Foundation

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
}

// MARK: - Default Implementations

extension PersistentMemoryBackend {
    public func storeAll(_ messages: [MemoryMessage], conversationId: String) async throws {
        for message in messages {
            try await store(message, conversationId: conversationId)
        }
    }
}

// MARK: - Errors

/// Errors that can occur during persistent memory operations.
public enum PersistentMemoryError: Error, Sendable, CustomStringConvertible {
    case storeFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    case connectionFailed(String)
    case notConfigured
    case invalidConversationId

    public var description: String {
        switch self {
        case .storeFailed(let reason):
            return "Failed to store message: \(reason)"
        case .fetchFailed(let reason):
            return "Failed to fetch messages: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete messages: \(reason)"
        case .connectionFailed(let reason):
            return "Database connection failed: \(reason)"
        case .notConfigured:
            return "Persistent memory backend not configured"
        case .invalidConversationId:
            return "Invalid conversation ID"
        }
    }
}
