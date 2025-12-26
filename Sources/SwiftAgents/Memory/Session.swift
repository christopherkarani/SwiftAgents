// Session.swift
// SwiftAgents Framework
//
// Protocol defining session-based conversation history management.

import Foundation

// MARK: - Session Protocol

/// Protocol for managing conversation session history.
///
/// Sessions provide automatic conversation history management across agent runs,
/// enabling multi-turn conversations without manual history tracking.
///
/// Conforming types must be actors to ensure thread-safe access to session data.
///
/// ## Example Usage
/// ```swift
/// let session = InMemorySession()
///
/// // Add messages to session
/// try await session.addItem(.user("Hello!"))
/// try await session.addItem(.assistant("Hi there!"))
///
/// // Retrieve conversation history
/// let history = try await session.getAllItems()
///
/// // Get recent messages only
/// let recent = try await session.getItems(limit: 5)
/// ```
public protocol Session: Actor, Sendable {
    /// Unique identifier for this session.
    ///
    /// Session IDs are used to distinguish between different conversation contexts
    /// and should remain constant throughout the session's lifecycle.
    var sessionId: String { get }

    /// Number of items currently stored in the session.
    ///
    /// This property provides efficient access to the item count without
    /// needing to retrieve all items.
    var itemCount: Int { get async }

    /// Whether the session contains no items.
    ///
    /// Returns `true` if `itemCount` is zero, `false` otherwise.
    var isEmpty: Bool { get async }

    /// Retrieves conversation history from the session.
    ///
    /// Items are returned in chronological order (oldest first).
    /// When a limit is specified, returns the most recent N items
    /// while still maintaining chronological order.
    ///
    /// - Parameter limit: Maximum number of items to retrieve.
    ///   - `nil`: Returns all items
    ///   - Positive value: Returns the last N items in chronological order
    ///   - Zero or negative: Returns an empty array
    /// - Returns: Array of messages in chronological order.
    /// - Throws: If retrieval fails due to underlying storage issues.
    func getItems(limit: Int?) async throws -> [MemoryMessage]

    /// Adds items to the conversation history.
    ///
    /// Items are appended to the session in the order they appear in the array,
    /// maintaining the conversation's chronological sequence.
    ///
    /// - Parameter items: Messages to add to the session.
    /// - Throws: If storage operation fails.
    func addItems(_ items: [MemoryMessage]) async throws

    /// Removes and returns the most recent item from the session.
    ///
    /// Follows LIFO (Last-In-First-Out) semantics, removing the last added item.
    /// This is useful for undoing the last message or implementing retry logic.
    ///
    /// - Returns: The removed message, or `nil` if the session is empty.
    /// - Throws: If removal operation fails.
    func popItem() async throws -> MemoryMessage?

    /// Clears all items from this session.
    ///
    /// The session ID remains unchanged after clearing, allowing the session
    /// to be reused for new conversations.
    ///
    /// - Throws: If clear operation fails.
    func clearSession() async throws
}

// MARK: - Default Extension Methods

public extension Session {
    /// Adds a single item to the conversation history.
    ///
    /// This is a convenience method that wraps a single message in an array
    /// and delegates to `addItems(_:)`.
    ///
    /// - Parameter item: The message to add.
    /// - Throws: If storage operation fails.
    func addItem(_ item: MemoryMessage) async throws {
        try await addItems([item])
    }

    /// Retrieves all items from the session.
    ///
    /// This is a convenience method equivalent to calling `getItems(limit: nil)`.
    ///
    /// - Returns: All messages in chronological order.
    /// - Throws: If retrieval fails.
    func getAllItems() async throws -> [MemoryMessage] {
        try await getItems(limit: nil)
    }
}
