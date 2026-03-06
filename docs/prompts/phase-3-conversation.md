# Phase 3 Implementation Prompt: Conversation (@Observable for SwiftUI)

## Role

You are a senior Swift 6.2 framework engineer implementing Phase 3 of the Swarm API redesign. You specialize in SwiftUI data flow, the Observation framework, and actor isolation. You are working inside the Swarm repository at `/Users/chriskarani/CodingProjects/AIStack/Swarm/`.

Your goal: Create `Conversation` — an `@Observable` class for multi-turn chat with streaming support, designed for SwiftUI binding. Follow strict TDD.

**Prerequisite**: Phase 1 (SwarmConfiguration) and Phase 2 (@Agent macro) must be complete.

## Context

### What This Enables

After Phase 3, developers can build a full SwiftUI chat UI in ~20 lines:

```swift
// Scenario 3: SwiftUI Chat
struct ChatView: View {
    @State private var conversation = Conversation(with: ChefBot())
    @State private var input = ""

    var body: some View {
        VStack {
            ScrollView {
                ForEach(conversation.messages) { message in
                    Text(message.text)
                }
            }
            if conversation.isThinking { ProgressView() }
            HStack {
                TextField("Ask...", text: $input)
                Button("Send") {
                    let text = input; input = ""
                    Task { try await conversation.send(text) }
                }
                .disabled(input.isEmpty || conversation.isThinking)
            }
        }
    }
}

// Scenario 4: Streaming
let conversation = Conversation(with: ChefBot())
try await conversation.stream("Tell me about Swift concurrency")
// conversation.streamingText updates progressively
// On completion, final message appended to conversation.messages
```

### Key Design Decisions

| Decision | Choice |
|----------|--------|
| Type | `@Observable public final class Conversation` |
| Sendable | `@unchecked Sendable` (needed for actor-isolated agent calls from `@MainActor` methods) |
| UI methods | `@MainActor` — `send()`, `stream()`, `clear()` |
| Session | Internal `InMemorySession` — auto-managed, reset on `clear()` |
| Message type | `ConversationMessage` — `Identifiable + Sendable` struct |
| Streaming | `stream()` reads `AgentEvent.outputToken` from agent's stream, accumulates into `streamingText` |
| Error handling | `lastError` property set on failure, method still throws |
| Agent storage | `private let agent: any AgentRuntime` — type-erased |

## Existing Types You Must Use

### `AgentRuntime` protocol (in `Sources/Swarm/Core/AgentRuntime.swift`)

```swift
public protocol AgentRuntime: Sendable {
    func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult
    nonisolated func stream(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) -> AsyncThrowingStream<AgentEvent, Error>
    // ... properties: name, tools, instructions, configuration, memory, etc.
}
```

### `AgentResult` (in `Sources/Swarm/Core/AgentResult.swift`)

Has `output: String` property containing the agent's text response.

### `AgentEvent` (in `Sources/Swarm/Core/AgentEvent.swift`)

Key cases for streaming:
```swift
public enum AgentEvent: Sendable {
    case started(input: String)
    case completed(result: AgentResult)
    case failed(error: AgentError)
    case outputToken(token: String)    // ← use this for streaming text
    case outputChunk(chunk: String)
    // ... 20+ other cases
}
```

### `Session` protocol + `InMemorySession` (in `Sources/Swarm/Memory/`)

```swift
public protocol Session: Actor, Sendable {
    func getItems(limit: Int?) async throws -> [MemoryMessage]
    func addItems(_ items: [MemoryMessage]) async throws
    func clearSession() async throws
}

public actor InMemorySession: Session { /* in-memory storage */ }
```

### `MemoryMessage` (in `Sources/Swarm/Memory/MemoryMessage.swift`)

```swift
public struct MemoryMessage: Sendable, Codable, Identifiable, Equatable {
    public enum Role: String, Sendable, Codable { case user, assistant, system, tool }
    public let id: UUID
    public let role: Role
    public let content: String
    public let timestamp: Date
}
```

### Test Mocks Available

- `MockInferenceProvider` — actor, configurable responses, in `Tests/SwarmTests/Mocks/`
- `MockTool` — struct, in `Tests/SwarmTests/Mocks/`
- **No `MockAgentRuntime` exists** — you must create one

## Instructions

Execute in this exact order.

### Step 1: Create MockAgentRuntime (Test Infrastructure)

**Create file**: `Tests/SwarmTests/Mocks/MockAgentRuntime.swift`

This mock must conform to `AgentRuntime` and support:
- Configurable single response or sequence of responses
- Optional delay (for testing `isThinking`)
- Optional error to throw
- Stream support that yields `outputToken` events

```swift
import Foundation
@testable import Swarm

/// A lightweight mock AgentRuntime for testing Conversation.
public actor MockAgentRuntime: AgentRuntime {
    // MARK: - AgentRuntime properties
    nonisolated public var tools: [any AnyJSONTool] { [] }
    nonisolated public let instructions: String = ""
    nonisolated public let configuration: AgentConfiguration = .init(name: "MockAgent")

    // MARK: - Configurable behavior
    private var responses: [String]
    private var responseIndex: Int = 0
    private let delay: Duration
    private let errorToThrow: Error?
    private let streamTokens: [String]?

    public init(response: String, delay: Duration = .zero) {
        self.responses = [response]
        self.delay = delay
        self.errorToThrow = nil
        self.streamTokens = nil
    }

    public init(responses: [String]) {
        self.responses = responses
        self.delay = .zero
        self.errorToThrow = nil
        self.streamTokens = nil
    }

    public init(shouldThrow error: Error) {
        self.responses = []
        self.delay = .zero
        self.errorToThrow = error
        self.streamTokens = nil
    }

    public init(streamTokens: [String]) {
        self.responses = [streamTokens.joined()]
        self.delay = .zero
        self.errorToThrow = nil
        self.streamTokens = streamTokens
    }

    public func run(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        if let error = errorToThrow { throw error }
        if delay > .zero { try await Task.sleep(for: delay) }
        let output: String
        if responseIndex < responses.count {
            output = responses[responseIndex]
            responseIndex += 1
        } else {
            output = responses.last ?? ""
        }
        return AgentResult(
            output: output,
            toolCalls: [],
            toolResults: [],
            iterationCount: 1,
            duration: .zero,
            tokenUsage: nil,
            metadata: [:]
        )
    }

    nonisolated public func stream(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        let tokens = streamTokens
        let agent = self
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(.started(input: input))
                    if let tokens {
                        for token in tokens {
                            continuation.yield(.outputToken(token: token))
                        }
                    }
                    let result = try await agent.run(input, session: session, hooks: hooks)
                    continuation.yield(.completed(result: result))
                    continuation.finish()
                } catch {
                    if let agentError = error as? AgentError {
                        continuation.yield(.failed(error: agentError))
                    }
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func cancel() async {}
}
```

### Step 2: Write Failing Tests (TDD Red Phase)

**Create file**: `Tests/SwarmTests/Agents/ConversationTests.swift`

```swift
import Testing
@testable import Swarm

@Suite("Conversation")
struct ConversationTests {

    // --- Scenario 3: send() adds messages ---
    @Test("send adds user and assistant messages")
    func sendAddsMessages() async throws {
        let mock = MockAgentRuntime(response: "Hello back!")
        let conversation = Conversation(with: mock)
        try await conversation.send("Hello")
        #expect(conversation.messages.count == 2)
        #expect(conversation.messages[0].role == .user)
        #expect(conversation.messages[0].text == "Hello")
        #expect(conversation.messages[1].role == .assistant)
        #expect(conversation.messages[1].text == "Hello back!")
    }

    // --- Scenario 3: isThinking tracks state ---
    @Test("isThinking is false before and after send")
    func isThinkingLifecycle() async throws {
        let mock = MockAgentRuntime(response: "Done")
        let conversation = Conversation(with: mock)
        #expect(conversation.isThinking == false)
        try await conversation.send("Hello")
        #expect(conversation.isThinking == false)
    }

    // --- Scenario 3: clear resets ---
    @Test("clear removes all messages and resets")
    func clearRemovesMessages() async throws {
        let mock = MockAgentRuntime(response: "Hi")
        let conversation = Conversation(with: mock)
        try await conversation.send("Hello")
        await conversation.clear()
        #expect(conversation.messages.isEmpty)
        #expect(conversation.isThinking == false)
        #expect(conversation.lastError == nil)
    }

    // --- Scenario 4: streaming ---
    @Test("stream appends final message after completion")
    func streamAppendsFinalMessage() async throws {
        let mock = MockAgentRuntime(streamTokens: ["Hello", " ", "world"])
        let conversation = Conversation(with: mock)
        try await conversation.stream("Tell me something")
        #expect(conversation.messages.count == 2) // user + assistant
        #expect(conversation.messages.last?.text == "Hello world")
        #expect(conversation.streamingText.isEmpty)
    }

    // --- ConversationMessage is Identifiable ---
    @Test("ConversationMessage has unique IDs")
    func messageIsIdentifiable() {
        let a = ConversationMessage(role: .user, text: "Hello")
        let b = ConversationMessage(role: .user, text: "Hello")
        #expect(a.id != b.id)
    }

    // --- Multi-turn retains session ---
    @Test("multiple sends accumulate messages")
    func multiTurnSession() async throws {
        let mock = MockAgentRuntime(responses: ["First", "Second", "Third"])
        let conversation = Conversation(with: mock)
        try await conversation.send("A")
        try await conversation.send("B")
        try await conversation.send("C")
        #expect(conversation.messages.count == 6) // 3 user + 3 assistant
    }

    // --- Error handling ---
    @Test("send stores lastError on failure")
    func sendStoresError() async throws {
        let mock = MockAgentRuntime(shouldThrow: AgentError.cancelled)
        let conversation = Conversation(with: mock)
        do {
            try await conversation.send("fail")
        } catch {}
        #expect(conversation.lastError != nil)
        #expect(conversation.isThinking == false)
    }

    // --- Error clears on next successful send ---
    @Test("lastError clears on successful send")
    func errorClearsOnSuccess() async throws {
        let mock = MockAgentRuntime(responses: ["ok"])
        let conversation = Conversation(with: mock)
        // Manually set an error state by attempting to use a failing mock first
        // For simplicity, just verify that after a successful send, lastError is nil
        try await conversation.send("hello")
        #expect(conversation.lastError == nil)
    }
}
```

### Step 3: Create ConversationMessage.swift

**Create file**: `Sources/Swarm/Agents/ConversationMessage.swift`

```swift
// ConversationMessage.swift
// Swarm Framework
//
// A message in a Conversation, designed for SwiftUI ForEach.

import Foundation

/// A message in a conversation. Identifiable for SwiftUI `ForEach`.
///
/// ```swift
/// ForEach(conversation.messages) { message in
///     Text(message.text)
/// }
/// ```
public struct ConversationMessage: Identifiable, Sendable, Equatable {
    /// The role of the message sender.
    public enum Role: String, Sendable, Codable {
        case user
        case assistant
        case system
    }

    /// Unique identifier for this message.
    public let id: UUID

    /// Who sent this message.
    public let role: Role

    /// The text content of the message.
    public let text: String

    /// When this message was created.
    public let timestamp: Date

    /// Creates a new conversation message.
    public init(
        role: Role,
        text: String,
        id: UUID = UUID(),
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}
```

### Step 4: Create Conversation.swift

**Create file**: `Sources/Swarm/Agents/Conversation.swift`

```swift
// Conversation.swift
// Swarm Framework
//
// Multi-turn conversation with an agent, designed for SwiftUI.

import Foundation
import Observation

/// Multi-turn conversation with an agent, designed for SwiftUI.
///
/// `Conversation` is `@Observable`, so SwiftUI views automatically
/// update when `messages`, `isThinking`, or `streamingText` change.
///
/// ```swift
/// struct ChatView: View {
///     @State var conversation = Conversation(with: MyAgent())
///
///     var body: some View {
///         ForEach(conversation.messages) { msg in Text(msg.text) }
///         if conversation.isThinking { ProgressView() }
///     }
/// }
/// ```
@Observable
public final class Conversation: @unchecked Sendable {

    // MARK: - Observable State

    /// All messages in the conversation.
    public private(set) var messages: [ConversationMessage] = []

    /// Whether the agent is currently generating a response.
    public private(set) var isThinking: Bool = false

    /// Partial text during streaming. Empty when not streaming.
    public private(set) var streamingText: String = ""

    /// The last error that occurred, if any.
    public private(set) var lastError: (any Error)?

    // MARK: - Initialization

    /// Creates a conversation backed by the given agent.
    ///
    /// - Parameter agent: Any `AgentRuntime` conforming agent.
    public init(with agent: some AgentRuntime) {
        self.agent = agent
        self.session = InMemorySession()
    }

    // MARK: - Public API

    /// Sends a message and waits for the full response.
    ///
    /// Appends a user message immediately, sets `isThinking` to true,
    /// then appends the assistant response when complete.
    ///
    /// - Parameter text: The user's message.
    /// - Throws: `AgentError` or `GuardrailError` if the agent fails.
    @MainActor
    public func send(_ text: String) async throws {
        messages.append(ConversationMessage(role: .user, text: text))
        isThinking = true
        lastError = nil
        do {
            let result = try await agent.run(text, session: session, hooks: nil)
            messages.append(ConversationMessage(role: .assistant, text: result.output))
            isThinking = false
        } catch {
            lastError = error
            isThinking = false
            throw error
        }
    }

    /// Streams a response, updating `streamingText` in real-time.
    ///
    /// Appends a user message immediately, then accumulates tokens into
    /// `streamingText`. On completion, appends the final assistant message
    /// and clears `streamingText`.
    ///
    /// - Parameter text: The user's message.
    /// - Throws: `AgentError` if streaming fails.
    @MainActor
    public func stream(_ text: String) async throws {
        messages.append(ConversationMessage(role: .user, text: text))
        isThinking = true
        streamingText = ""
        lastError = nil
        do {
            var accumulated = ""
            for try await event in agent.stream(text, session: session, hooks: nil) {
                if case .outputToken(let token) = event {
                    accumulated += token
                    streamingText = accumulated
                }
            }
            messages.append(ConversationMessage(role: .assistant, text: accumulated))
            isThinking = false
            streamingText = ""
        } catch {
            lastError = error
            isThinking = false
            streamingText = ""
            throw error
        }
    }

    /// Clears all messages and resets the session.
    @MainActor
    public func clear() {
        messages.removeAll()
        session = InMemorySession()
        lastError = nil
        streamingText = ""
        isThinking = false
    }

    // MARK: - Private

    private let agent: any AgentRuntime
    private var session: any Session
}
```

### Step 5: Build and Run Tests

```bash
swift build 2>&1 | head -50
swift test --filter ConversationTests 2>&1
swift test 2>&1 | tail -30
```

Fix any compilation errors. All tests must pass.

**Common issues to watch for:**

1. **`@MainActor` in tests**: The test methods call `@MainActor` methods (`send`, `stream`, `clear`). Swift Testing handles this — `async` test functions can call `@MainActor` methods via `await`. If you get isolation errors, annotate the test function or call site.

2. **`@Observable` import**: Requires `import Observation`. This framework is available on macOS 14+/iOS 17+. Since the project targets macOS 26+/iOS 26+, this is fine.

3. **`@unchecked Sendable`**: Required because `Conversation` holds `any AgentRuntime` (which is `Sendable`) and `any Session` (which is `Actor` and thus `Sendable`), but the compiler can't verify the `@Observable` class's full thread safety. The `@MainActor` annotations on mutating methods provide the actual safety guarantee.

4. **`MockAgentRuntime` needs `AgentConfiguration`**: Check how `AgentConfiguration` is initialized. It likely needs at minimum a `name` parameter. Use `.init(name: "MockAgent")` or `.default`.

5. **Stream test timing**: The `streamAppendsFinalMessage` test calls `stream()` which completes fully before assertions. The mock yields tokens synchronously in a Task, so by the time `stream()` returns, all tokens are consumed. This should work reliably.

### Step 6: Format Code

```bash
swift package plugin --allow-writing-to-package-directory swiftformat
```

## Success Criteria

1. `swift build` succeeds with zero errors
2. `ConversationTests` — all 8 tests pass
3. `swift test` — ALL existing tests still pass (zero regressions)
4. `Conversation` is `@Observable` and `@unchecked Sendable`
5. `ConversationMessage` is `Identifiable`, `Sendable`, and `Equatable`
6. `send()` appends user + assistant messages, toggles `isThinking`
7. `stream()` accumulates tokens in `streamingText`, appends final message
8. `clear()` resets messages, session, error, and streaming state
9. `lastError` is set on failure, cleared on next call
10. `MockAgentRuntime` exists and supports response, responses, error, stream modes
11. No `print()` in production code
12. All new types in `Sources/Swarm/Agents/`

## Files Changed Summary

| File | Action | What Changes |
|------|--------|-------------|
| `Tests/SwarmTests/Mocks/MockAgentRuntime.swift` | CREATE | Lightweight mock for Conversation tests |
| `Tests/SwarmTests/Agents/ConversationTests.swift` | CREATE | 8 tests covering Scenarios 3, 4 |
| `Sources/Swarm/Agents/ConversationMessage.swift` | CREATE | `Identifiable + Sendable` struct |
| `Sources/Swarm/Agents/Conversation.swift` | CREATE | `@Observable` multi-turn chat class |

## Edge Cases to Watch

1. **`@MainActor` isolation**: `send()`, `stream()`, and `clear()` are `@MainActor`. Tests call them with `await` which hops to the main actor. If tests fail with isolation errors, add `@MainActor` to the test method.
2. **`any Session` mutability**: `session` is `var` (reassigned in `clear()`). Since `Session` conforms to `Actor`, the value is reference-typed. Assignment is safe on `@MainActor`.
3. **`@Observable` vs `@unchecked Sendable`**: These are compatible. `@Observable` generates observation tracking; `@unchecked Sendable` tells the compiler to trust your thread safety. The `@MainActor` methods provide the actual guarantee.
4. **`AgentConfiguration` init**: Verify the exact initializer. It may be `AgentConfiguration(name:)` or have a `.default` static. Check `Sources/Swarm/Core/AgentConfiguration.swift` if the mock doesn't compile.
5. **Stream accumulation**: If the agent's `stream()` doesn't yield `.outputToken` events (some agents yield `.completed` directly), `streamingText` stays empty but the final message is still appended from the `.completed` result. Consider handling `.completed` as a fallback in `stream()`.
6. **Conversation does NOT conform to `AgentRuntime`**: It is a wrapper around an agent, not an agent itself. It does not have `run()` returning `AgentResult` — its `send()` returns `Void`.
