// SwiftDataMemory.swift
// SwiftAgents Framework
//
// Persistent memory using SwiftData.

import Foundation
import os
import SwiftData

/// Persistent memory using SwiftData.
///
/// `SwiftDataMemory` stores conversation history in a local database,
/// enabling persistence across app launches and sessions.
///
/// ## Thread Safety
///
/// Uses actor isolation with a dedicated `ModelContext` for thread safety.
/// The `ModelContainer` is shared but contexts are actor-isolated.
///
/// ## Usage
///
/// ```swift
/// let container = try PersistedMessage.makeContainer()
/// let memory = SwiftDataMemory(modelContainer: container, conversationId: "chat-123")
/// await memory.add(.user("Hello"))
/// // Messages persist across app launches
/// ```
public actor SwiftDataMemory: AgentMemory {
    /// The SwiftData model container.
    private let modelContainer: ModelContainer

    /// Actor-isolated model context for database operations.
    private let modelContext: ModelContext

    /// Conversation identifier for message grouping.
    public let conversationId: String

    /// Maximum messages to retain (0 = unlimited).
    public let maxMessages: Int

    /// Token estimator for context retrieval.
    private let tokenEstimator: any TokenEstimator

    /// Creates a new SwiftData memory.
    ///
    /// - Parameters:
    ///   - modelContainer: SwiftData model container.
    ///   - conversationId: Identifier for this conversation.
    ///   - maxMessages: Maximum messages to retain (0 = unlimited).
    ///   - tokenEstimator: Token counting estimator.
    public init(
        modelContainer: ModelContainer,
        conversationId: String = "default",
        maxMessages: Int = 0,
        tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared
    ) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        self.conversationId = conversationId
        self.maxMessages = maxMessages
        self.tokenEstimator = tokenEstimator
    }

    // MARK: - AgentMemory Conformance

    public func add(_ message: MemoryMessage) async {
        let persisted = PersistedMessage(from: message, conversationId: conversationId)
        modelContext.insert(persisted)

        do {
            try modelContext.save()

            // Trim if needed
            if maxMessages > 0 {
                await trimToMaxMessages()
            }
        } catch {
            // Log error but don't throw - memory operations should be resilient
            Logger.memory.error("SwiftDataMemory: Failed to save message: \(error, privacy: .private)")
        }
    }

    public func getContext(for query: String, tokenLimit: Int) async -> String {
        let messages = await getAllMessages()
        return formatMessagesForContext(messages, tokenLimit: tokenLimit, tokenEstimator: tokenEstimator)
    }

    public func getAllMessages() async -> [MemoryMessage] {
        let descriptor = PersistedMessage.fetchDescriptor(forConversation: conversationId)

        do {
            let persisted = try modelContext.fetch(descriptor)
            return persisted.compactMap { $0.toMemoryMessage() }
        } catch {
            Logger.memory.error("SwiftDataMemory: Failed to fetch messages: \(error, privacy: .private)")
            return []
        }
    }

    public func clear() async {
        let descriptor = PersistedMessage.fetchDescriptor(forConversation: conversationId)

        do {
            let messages = try modelContext.fetch(descriptor)
            for message in messages {
                modelContext.delete(message)
            }
            try modelContext.save()
        } catch {
            Logger.memory.error("SwiftDataMemory: Failed to clear messages: \(error, privacy: .private)")
        }
    }

    public var count: Int {
        get async {
            let descriptor = PersistedMessage.fetchDescriptor(forConversation: conversationId)

            do {
                return try modelContext.fetchCount(descriptor)
            } catch {
                Logger.memory.error("SwiftDataMemory: Failed to fetch count: \(error, privacy: .private)")
                return 0
            }
        }
    }

    /// Whether the memory contains no messages for this conversation.
    public var isEmpty: Bool {
        get async { await count.isZero }
    }

    // MARK: - Private Methods

    private func trimToMaxMessages() async {
        let descriptor = PersistedMessage.fetchDescriptor(forConversation: conversationId)

        do {
            let messages = try modelContext.fetch(descriptor)
            if messages.count > maxMessages {
                // Remove oldest messages (they're sorted by timestamp ascending)
                let toRemove = messages.prefix(messages.count - maxMessages)
                for message in toRemove {
                    modelContext.delete(message)
                }
                try modelContext.save()
            }
        } catch {
            Logger.memory.error("SwiftDataMemory: Failed to trim messages: \(error, privacy: .private)")
        }
    }
}

// MARK: - Batch Operations

extension SwiftDataMemory {
    /// Adds multiple messages at once.
    ///
    /// More efficient than individual adds for importing conversation history.
    ///
    /// - Parameter messages: Messages to add.
    public func addAll(_ messages: [MemoryMessage]) async {
        for message in messages {
            let persisted = PersistedMessage(from: message, conversationId: conversationId)
            modelContext.insert(persisted)
        }

        do {
            try modelContext.save()

            if maxMessages > 0 {
                await trimToMaxMessages()
            }
        } catch {
            Logger.memory.error("SwiftDataMemory: Failed to save messages: \(error, privacy: .private)")
        }
    }

    /// Returns the most recent N messages.
    ///
    /// - Parameter n: Number of messages to return.
    /// - Returns: Array of recent messages.
    public func getRecentMessages(_ n: Int) async -> [MemoryMessage] {
        let descriptor = PersistedMessage.fetchDescriptor(forConversation: conversationId, limit: n)

        do {
            let persisted = try modelContext.fetch(descriptor)
            // Reverse because fetch was in descending order
            return persisted.reversed().compactMap { $0.toMemoryMessage() }
        } catch {
            Logger.memory.error("SwiftDataMemory: Failed to fetch recent messages: \(error, privacy: .private)")
            return []
        }
    }
}

// MARK: - Conversation Management

extension SwiftDataMemory {
    /// Returns all conversation IDs in the database.
    ///
    /// - Returns: Array of unique conversation identifiers.
    public func allConversationIds() async -> [String] {
        do {
            let descriptor = PersistedMessage.allConversationsDescriptor
            let messages = try modelContext.fetch(descriptor)
            return Array(Set(messages.map(\.conversationId))).sorted()
        } catch {
            Logger.memory.error("SwiftDataMemory: Failed to fetch conversation IDs: \(error, privacy: .private)")
            return []
        }
    }

    /// Deletes all messages for a specific conversation.
    ///
    /// - Parameter id: The conversation ID to delete.
    public func deleteConversation(_ id: String) async {
        let descriptor = PersistedMessage.fetchDescriptor(forConversation: id)

        do {
            let messages = try modelContext.fetch(descriptor)
            for message in messages {
                modelContext.delete(message)
            }
            try modelContext.save()
        } catch {
            Logger.memory.error("SwiftDataMemory: Failed to delete conversation: \(error, privacy: .private)")
        }
    }

    /// Returns the message count for a specific conversation.
    ///
    /// - Parameter id: The conversation ID to count.
    /// - Returns: Number of messages in the conversation.
    public func messageCount(forConversation id: String) async -> Int {
        let descriptor = PersistedMessage.fetchDescriptor(forConversation: id)

        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            Logger.memory.error("SwiftDataMemory: Failed to fetch message count for conversation \(id): \(error, privacy: .private)")
            return 0
        }
    }
}

// MARK: - Diagnostics

extension SwiftDataMemory {
    /// Returns diagnostic information about memory state.
    public func diagnostics() async -> SwiftDataMemoryDiagnostics {
        let messageCount = await count
        let allConversations = await allConversationIds()

        return SwiftDataMemoryDiagnostics(
            conversationId: conversationId,
            messageCount: messageCount,
            maxMessages: maxMessages,
            totalConversations: allConversations.count,
            isUnlimited: maxMessages == 0
        )
    }
}

/// Diagnostic information for SwiftData memory.
public struct SwiftDataMemoryDiagnostics: Sendable {
    /// Current conversation ID.
    public let conversationId: String
    /// Messages in current conversation.
    public let messageCount: Int
    /// Maximum messages allowed (0 = unlimited).
    public let maxMessages: Int
    /// Total conversations in database.
    public let totalConversations: Int
    /// Whether message limit is disabled.
    public let isUnlimited: Bool
}

// MARK: - Factory Methods

extension SwiftDataMemory {
    /// Creates a SwiftDataMemory with a new in-memory container.
    ///
    /// Useful for testing or temporary storage that doesn't persist.
    ///
    /// - Parameters:
    ///   - conversationId: Conversation identifier.
    ///   - maxMessages: Maximum messages to retain.
    /// - Returns: Configured SwiftDataMemory.
    /// - Throws: If container creation fails.
    public static func inMemory(
        conversationId: String = "default",
        maxMessages: Int = 0
    ) throws -> SwiftDataMemory {
        let container = try PersistedMessage.makeContainer(inMemory: true)
        return SwiftDataMemory(
            modelContainer: container,
            conversationId: conversationId,
            maxMessages: maxMessages
        )
    }

    /// Creates a SwiftDataMemory with persistent storage.
    ///
    /// - Parameters:
    ///   - conversationId: Conversation identifier.
    ///   - maxMessages: Maximum messages to retain.
    /// - Returns: Configured SwiftDataMemory.
    /// - Throws: If container creation fails.
    public static func persistent(
        conversationId: String = "default",
        maxMessages: Int = 0
    ) throws -> SwiftDataMemory {
        let container = try PersistedMessage.makeContainer(inMemory: false)
        return SwiftDataMemory(
            modelContainer: container,
            conversationId: conversationId,
            maxMessages: maxMessages
        )
    }
}
