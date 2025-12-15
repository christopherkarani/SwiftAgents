// PersistedMessage.swift
// SwiftAgents Framework
//
// SwiftData model for persistent message storage.

#if canImport(SwiftData)
import Foundation
import SwiftData

/// SwiftData model for persistent message storage.
///
/// `PersistedMessage` is the database representation of `MemoryMessage`,
/// enabling long-term storage across app launches.
///
/// ## Usage
///
/// ```swift
/// let container = try ModelContainer(for: PersistedMessage.self)
/// let context = ModelContext(container)
///
/// let message = MemoryMessage.user("Hello")
/// let persisted = PersistedMessage(from: message, conversationId: "chat-123")
/// context.insert(persisted)
/// try context.save()
/// ```
@Model
public final class PersistedMessage {
    /// Unique identifier matching the original MemoryMessage.
    @Attribute(.unique) public var id: UUID

    /// Message role as string (user, assistant, system, tool).
    public var role: String

    /// Message content.
    public var content: String

    /// Creation timestamp.
    public var timestamp: Date

    /// Serialized metadata as JSON string.
    public var metadataJSON: String

    /// Conversation/session identifier for grouping messages.
    @Attribute(.spotlight) public var conversationId: String

    /// Creates a new persisted message.
    ///
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - role: Message role as string.
    ///   - content: Message content.
    ///   - timestamp: Creation time.
    ///   - metadataJSON: Metadata as JSON string.
    ///   - conversationId: Conversation identifier.
    public init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = Date(),
        metadataJSON: String = "{}",
        conversationId: String = "default"
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metadataJSON = metadataJSON
        self.conversationId = conversationId
    }

    /// Creates a persisted message from a MemoryMessage.
    ///
    /// - Parameters:
    ///   - message: The MemoryMessage to persist.
    ///   - conversationId: Conversation identifier for grouping.
    public convenience init(from message: MemoryMessage, conversationId: String = "default") {
        let metadataJSON: String
        if let data = try? JSONEncoder().encode(message.metadata),
           let json = String(data: data, encoding: .utf8) {
            metadataJSON = json
        } else {
            metadataJSON = "{}"
        }

        self.init(
            id: message.id,
            role: message.role.rawValue,
            content: message.content,
            timestamp: message.timestamp,
            metadataJSON: metadataJSON,
            conversationId: conversationId
        )
    }

    /// Converts back to a MemoryMessage.
    ///
    /// - Returns: The equivalent MemoryMessage, or nil if conversion fails.
    public func toMemoryMessage() -> MemoryMessage? {
        guard let role = MemoryMessage.Role(rawValue: role) else { return nil }

        let metadata: [String: String]
        if let data = metadataJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            metadata = decoded
        } else {
            metadata = [:]
        }

        return MemoryMessage(
            id: id,
            role: role,
            content: content,
            timestamp: timestamp,
            metadata: metadata
        )
    }
}

// MARK: - Fetch Descriptors

extension PersistedMessage {
    /// Fetch descriptor for all messages in a conversation, sorted by timestamp.
    ///
    /// - Parameter conversationId: The conversation to fetch.
    /// - Returns: Configured fetch descriptor.
    public static func fetchDescriptor(
        forConversation conversationId: String
    ) -> FetchDescriptor<PersistedMessage> {
        FetchDescriptor<PersistedMessage>(
            predicate: #Predicate { $0.conversationId == conversationId },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
    }

    /// Fetch descriptor for recent messages in a conversation.
    ///
    /// - Parameters:
    ///   - conversationId: The conversation to fetch.
    ///   - limit: Maximum number of messages.
    /// - Returns: Configured fetch descriptor.
    public static func fetchDescriptor(
        forConversation conversationId: String,
        limit: Int
    ) -> FetchDescriptor<PersistedMessage> {
        var descriptor = FetchDescriptor<PersistedMessage>(
            predicate: #Predicate { $0.conversationId == conversationId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    /// Fetch descriptor for all conversations (unique conversation IDs).
    public static var allConversationsDescriptor: FetchDescriptor<PersistedMessage> {
        FetchDescriptor<PersistedMessage>(
            sortBy: [SortDescriptor(\.conversationId)]
        )
    }
}

// MARK: - Model Container Configuration

extension PersistedMessage {
    /// Creates a model container configured for PersistedMessage.
    ///
    /// - Parameter inMemory: If true, uses in-memory storage (for testing).
    /// - Returns: Configured model container.
    /// - Throws: If container creation fails.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([PersistedMessage.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
#endif
