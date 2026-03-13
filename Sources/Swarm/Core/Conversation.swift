import Foundation

/// Stateful multi-turn conversation wrapper around an `AgentRuntime`.
///
/// `Conversation` stores user/assistant messages locally and forwards each turn to
/// the wrapped agent. It can operate with an optional `Session` for persisted history.
public actor Conversation {
    /// Simple chat message model for conversation transcripts.
    public struct Message: Sendable, Equatable {
        public enum Role: String, Sendable {
            case user
            case assistant
        }

        public let role: Role
        public let text: String

        public init(role: Role, text: String) {
            self.role = role
            self.text = text
        }
    }

    public var messages: [Message] {
        _messages
    }

    /// Optional observer for agent lifecycle callbacks.
    public var observer: (any AgentObserver)?

    private let agent: any AgentRuntime
    private let session: (any Session)?
    private var _messages: [Message] = []

    public init(with agent: some AgentRuntime, session: (any Session)? = nil, observer: (any AgentObserver)? = nil) {
        self.agent = agent
        self.session = session
        self.observer = observer
    }

    /// Sends a single user turn and appends assistant output to `messages`.
    @discardableResult
    public func send(_ input: String) async throws -> AgentResult {
        _messages.append(.init(role: .user, text: input))
        let result = try await agent.run(input, session: session, observer: observer)
        _messages.append(.init(role: .assistant, text: result.output))
        return result
    }

    /// True streaming — forwards agent events to the caller.
    public nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        agent.stream(input, session: session, observer: nil)
    }

    /// Convenience that buffers streamed output into a single String.
    @discardableResult
    public func streamText(_ input: String) async throws -> String {
        _messages.append(.init(role: .user, text: input))

        var final = ""
        for try await event in agent.stream(input, session: session, observer: observer) {
            switch event {
            case .output(.token(let token)):
                final += token
            case .output(.chunk(let chunk)):
                final += chunk
            case .lifecycle(.completed(let result)):
                if final.isEmpty {
                    final = result.output
                }
            default:
                break
            }
        }

        _messages.append(.init(role: .assistant, text: final))
        return final
    }
}
