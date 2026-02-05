// MemoryMessage.swift
// Swarm Framework
//
// Core message type for agent memory systems.

import Foundation

// MARK: - MemoryMessage

/// Represents a single message in agent memory.
///
/// `MemoryMessage` is the fundamental unit of conversation history,
/// storing the role, content, and metadata for each interaction.
public struct MemoryMessage: Sendable, Codable, Identifiable, Equatable, Hashable {
    /// The role of the entity in a conversation.
    public enum Role: String, Sendable, Codable, CaseIterable {
        /// Message from the user/human.
        case user
        /// Message from the AI assistant.
        case assistant
        /// System instruction or context.
        case system
        /// Output from a tool execution.
        case tool
    }

    /// Unique identifier for this message.
    public let id: UUID

    /// The role of the entity that produced this message.
    public let role: Role

    /// The textual content of the message.
    public let content: String

    /// When this message was created.
    public let timestamp: Date

    /// Additional key-value metadata attached to this message.
    public let metadata: [String: String]

    /// Formatted content including role prefix for context display.
    public var formattedContent: String {
        "[\(role.rawValue)]: \(content)"
    }

    /// Creates a new memory message.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID).
    ///   - role: The role of the message sender.
    ///   - content: The message content.
    ///   - timestamp: When the message was created (defaults to now).
    ///   - metadata: Additional key-value metadata.
    public init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Convenience Factory Methods

public extension MemoryMessage {
    /// Creates a user message.
    ///
    /// - Parameters:
    ///   - content: The message content.
    ///   - metadata: Optional metadata.
    /// - Returns: A new message with user role.
    static func user(_ content: String, metadata: [String: String] = [:]) -> MemoryMessage {
        MemoryMessage(role: .user, content: content, metadata: metadata)
    }

    /// Creates an assistant message.
    ///
    /// - Parameters:
    ///   - content: The message content.
    ///   - metadata: Optional metadata.
    /// - Returns: A new message with assistant role.
    static func assistant(_ content: String, metadata: [String: String] = [:]) -> MemoryMessage {
        MemoryMessage(role: .assistant, content: content, metadata: metadata)
    }

    /// Creates a system message.
    ///
    /// - Parameters:
    ///   - content: The message content.
    ///   - metadata: Optional metadata.
    /// - Returns: A new message with system role.
    static func system(_ content: String, metadata: [String: String] = [:]) -> MemoryMessage {
        MemoryMessage(role: .system, content: content, metadata: metadata)
    }

    /// Creates a tool result message.
    ///
    /// - Parameters:
    ///   - content: The tool output content.
    ///   - toolName: The name of the tool that produced this result.
    /// - Returns: A new message with tool role.
    static func tool(_ content: String, toolName: String) -> MemoryMessage {
        MemoryMessage(role: .tool, content: content, metadata: ["tool_name": toolName])
    }
}

// MARK: CustomStringConvertible

extension MemoryMessage: CustomStringConvertible {
    public var description: String {
        "MemoryMessage(\(role.rawValue): \"\(content.prefix(50))\(content.count > 50 ? "..." : "")\")"
    }
}
