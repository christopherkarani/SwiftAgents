#if canImport(Observation)
import Foundation
import Observation

/// A single message in a conversation.
public struct ConversationMessage: Identifiable, Sendable {
    public let id: UUID
    public var text: String
    public let role: Role
    public let timestamp: Date
    public var isError: Bool

    public enum Role: Sendable, Equatable {
        case user
        case assistant
        case system
    }

    public init(role: Role, text: String, isError: Bool = false) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.timestamp = Date()
        self.isError = isError
    }
}

/// Multi-turn conversation model for SwiftUI.
///
/// ```swift
/// @State var chat = Conversation(agent: myAgent)
///
/// Button("Send") { Task { try await chat.send(userText) } }
/// ForEach(chat.messages) { msg in Text(msg.text) }
/// ```
@Observable
@MainActor
public final class ConversationV3 {
    public private(set) var messages: [ConversationMessage] = []
    public private(set) var isThinking: Bool = false
    public private(set) var streamingText: String = ""

    private let agent: AgentV3

    public init(agent: AgentV3) {
        self.agent = agent
    }

    /// Send a message and await the full response.
    public func send(_ text: String) async throws {
        messages.append(ConversationMessage(role: .user, text: text))
        isThinking = true
        defer { isThinking = false }
        do {
            let result = try await agent.run(text)
            messages.append(ConversationMessage(role: .assistant, text: result.output))
        } catch {
            messages.append(ConversationMessage(
                role: .assistant, text: error.localizedDescription, isError: true
            ))
            throw error
        }
    }

    /// Send a message and stream tokens as they arrive.
    public func streamSend(_ text: String) async throws {
        messages.append(ConversationMessage(role: .user, text: text))
        messages.append(ConversationMessage(role: .assistant, text: ""))
        let assistantIndex = messages.count - 1
        isThinking = true
        streamingText = ""
        defer { isThinking = false; streamingText = "" }

        for try await event in agent.stream(text) {
            switch event {
            case .output(.token(let token)):
                streamingText += token
                messages[assistantIndex].text = streamingText
            case .output(.chunk(let chunk)):
                streamingText += chunk
                messages[assistantIndex].text = streamingText
            case .lifecycle(.completed(let result)):
                messages[assistantIndex].text = result.output
                streamingText = ""
            default:
                break
            }
        }
    }

    /// Clear all messages.
    public func clear() {
        messages.removeAll()
        streamingText = ""
    }
}
#endif
