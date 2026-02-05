# Session Management

Sessions provide automatic conversation history management for multi-turn agent interactions in Swarm. Unlike the `Memory` protocol which provides context retrieval with token limits, sessions focus on simple, chronological message storage and retrieval.

## Table of Contents

- [Session vs Memory](#session-vs-memory)
- [Session Protocol](#session-protocol)
- [InMemorySession](#inmemorysession)
- [PersistentSession](#persistentsession)
- [Session Operations](#session-operations)
- [Using Sessions with Agents](#using-sessions-with-agents)
- [Cross-Platform Considerations](#cross-platform-considerations)
- [Best Practices](#best-practices)

## Session vs Memory

Swarm provides two distinct abstractions for managing conversation history:

### Session
**Purpose**: Simple chronological storage and retrieval of conversation messages.

**Use When**:
- You need automatic multi-turn conversation management
- You want chronological message history without filtering
- You're building a chat interface with message persistence
- You need to share conversation state between multiple agents

**Key Features**:
- CRUD operations on messages (add, get, pop, clear)
- Chronological ordering (oldest first)
- Session isolation via unique session IDs
- Optional persistence via SwiftData

### Memory
**Purpose**: Context-aware retrieval with token limits and semantic search.

**Use When**:
- You need intelligent context retrieval based on relevance
- You want to enforce token limits on context
- You need semantic search or summarization
- You're implementing RAG (Retrieval-Augmented Generation)

**Key Features**:
- Context retrieval with token budgets
- Support for vector search (when using `VectorMemory`)
- Summary generation (when using `SummaryMemory`)
- Query-based relevance filtering

### Comparison

| Feature | Session | Memory |
|---------|---------|--------|
| Purpose | Message storage | Context retrieval |
| Ordering | Chronological | Relevance-based |
| Token Limits | Via `getItems(limit:)` | Built-in via `tokenLimit` |
| Persistence | Optional (SwiftData) | Optional (backend-dependent) |
| Use Case | Chat history | RAG, summarization |
| Actor Isolation | Required | Required |

**You can use both**: Sessions for managing conversation history and Memory for providing intelligent context to agents. They serve complementary purposes.

## Session Protocol

The `Session` protocol defines the contract for conversation history management.

```swift
public protocol Session: Actor, Sendable {
    /// Unique identifier for this session.
    nonisolated var sessionId: String { get }

    /// Number of items currently stored in the session.
    var itemCount: Int { get async }

    /// Whether the session contains no items.
    var isEmpty: Bool { get async }

    /// Retrieves the item count with proper error propagation.
    func getItemCount() async throws -> Int

    /// Retrieves conversation history from the session.
    func getItems(limit: Int?) async throws -> [MemoryMessage]

    /// Adds items to the conversation history.
    func addItems(_ items: [MemoryMessage]) async throws

    /// Removes and returns the most recent item from the session.
    func popItem() async throws -> MemoryMessage?

    /// Clears all items from this session.
    func clearSession() async throws
}
```

### Key Characteristics

**Actor Isolation**: All session implementations must be actors to ensure thread-safe access to conversation data. This prevents data races when multiple concurrent operations access the same session.

**Sendable Conformance**: Sessions are `Sendable`, allowing them to be safely passed across actor boundaries and used in concurrent contexts.

**Nonisolated Session ID**: The `sessionId` property is `nonisolated` because it's immutable and can be accessed without actor synchronization.

**Error Handling**: Methods throw `SessionError` for storage, retrieval, or deletion failures.

### SessionError

```swift
public enum SessionError: Error {
    case retrievalFailed(reason: String, underlyingError: String? = nil)
    case storageFailed(reason: String, underlyingError: String? = nil)
    case deletionFailed(reason: String, underlyingError: String? = nil)
    case invalidState(reason: String)
    case backendError(reason: String, underlyingError: String? = nil)
}
```

## InMemorySession

In-memory session implementation for testing, development, and short-lived conversations.

### Characteristics

- **Storage**: Ephemeral (data lost when session is deallocated)
- **Performance**: Fast (no I/O overhead)
- **Ideal For**: Unit testing, development, temporary conversations
- **Platform**: All platforms (iOS, macOS, Linux, etc.)

### Usage

```swift
import Swarm

// Create with auto-generated UUID session ID
let session = InMemorySession()

// Or with a custom session ID
let customSession = InMemorySession(sessionId: "user-123-chat")

// Add messages
try await session.addItem(.user("Hello!"))
try await session.addItem(.assistant("Hi there!"))

// Retrieve history
let allMessages = try await session.getAllItems()
print("Total messages: \(allMessages.count)") // 2

// Get recent messages
let recent = try await session.getItems(limit: 10)

// Check if empty
let isEmpty = await session.isEmpty
print("Session empty: \(isEmpty)") // false

// Clear session
try await session.clearSession()
```

### Thread Safety Example

```swift
// Multiple concurrent operations are safe due to actor isolation
let session = InMemorySession()

await withTaskGroup(of: Void.self) { group in
    group.addTask {
        try? await session.addItem(.user("Message 1"))
    }
    group.addTask {
        try? await session.addItem(.user("Message 2"))
    }
    group.addTask {
        try? await session.addItem(.user("Message 3"))
    }
}

// All messages are safely stored
let count = await session.itemCount // 3
```

## PersistentSession

SwiftData-backed session implementation for long-term persistence on Apple platforms.

### Platform Availability

```swift
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
```

**Note**: PersistentSession is only available on Apple platforms with SwiftData support. For cross-platform persistence, implement a custom session using your preferred database.

### Characteristics

- **Storage**: Persistent (survives app restarts)
- **Backend**: SwiftData `ModelContainer`
- **Performance**: Fast with disk I/O overhead
- **Ideal For**: Production apps, long-running conversations, multi-session apps

### Factory Methods

```swift
import Swarm

// Create with persistent disk storage
let session = try PersistentSession.persistent(sessionId: "user-123-chat")

// Create with in-memory storage (testing)
let testSession = try PersistentSession.inMemory(sessionId: "test-chat")
```

### Custom Backend

For advanced scenarios, create a session with a custom SwiftData backend:

```swift
import SwiftData

// Create shared backend
let backend = try SwiftDataBackend.persistent()

// Multiple sessions sharing the same backend
let session1 = PersistentSession(sessionId: "chat-1", backend: backend)
let session2 = PersistentSession(sessionId: "chat-2", backend: backend)

// Each session's data is isolated via sessionId
try await session1.addItem(.user("Hello from session 1"))
try await session2.addItem(.user("Hello from session 2"))

let session1Messages = try await session1.getAllItems() // 1 message
let session2Messages = try await session2.getAllItems() // 1 message
```

### Usage

```swift
// Create persistent session
let session = try PersistentSession.persistent(sessionId: "user-456-support")

// Add conversation messages
try await session.addItem(.user("I need help with my account"))
try await session.addItem(.assistant("I'd be happy to help! What seems to be the issue?"))

// Retrieve recent history
let recent = try await session.getItems(limit: 10)

// Session persists across app launches
// ... app restarts ...

// Reconnect to same session
let reconnectedSession = try PersistentSession.persistent(sessionId: "user-456-support")
let history = try await reconnectedSession.getAllItems()
print("Restored \(history.count) messages") // 2
```

### Error Handling

```swift
do {
    let session = try PersistentSession.persistent(sessionId: "chat-1")
    try await session.addItem(.user("Hello"))
} catch let error as SessionError {
    switch error {
    case .storageFailed(let reason, let underlying):
        print("Storage failed: \(reason)")
        if let underlying {
            print("Underlying error: \(underlying)")
        }
    case .backendError(let reason, _):
        print("Backend error: \(reason)")
    default:
        print("Session error: \(error)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## Session Operations

### Adding Messages

```swift
let session = InMemorySession()

// Add single message
try await session.addItem(.user("What's the weather?"))

// Add multiple messages
try await session.addItems([
    .user("What's the weather?"),
    .assistant("It's sunny and 72°F.")
])

// Add with metadata
try await session.addItem(.user(
    "Search for flights",
    metadata: ["intent": "travel", "priority": "high"]
))

// Add tool result
try await session.addItem(.tool(
    "Flight search returned 5 results",
    toolName: "flight_search"
))
```

### Retrieving Messages

```swift
let session = InMemorySession()

// Get all messages
let allMessages = try await session.getAllItems()

// Get recent messages (last N in chronological order)
let lastTen = try await session.getItems(limit: 10)

// Get with no limit (same as getAllItems)
let allAgain = try await session.getItems(limit: nil)

// Empty result for zero/negative limit
let empty = try await session.getItems(limit: 0) // []

// Check count
let count = try await session.getItemCount() // Throws on backend errors
let countNonThrowing = await session.itemCount // Returns 0 on error
```

**Ordering Guarantee**: Messages are always returned in chronological order (oldest first), even when using `limit`.

```swift
try await session.addItems([
    .user("Message 1"),
    .assistant("Response 1"),
    .user("Message 2"),
    .assistant("Response 2"),
    .user("Message 3")
])

let lastTwo = try await session.getItems(limit: 2)
// Returns: ["Message 3", "Response 2"] in chronological order
// (They were the last 2 added, but returned oldest-first)
```

### Removing Messages

```swift
let session = InMemorySession()

try await session.addItems([
    .user("First"),
    .assistant("Second"),
    .user("Third")
])

// Pop last item (LIFO - Last In, First Out)
let popped = try await session.popItem()
print(popped?.content) // "Third"

let remaining = try await session.getAllItems()
print(remaining.count) // 2

// Pop from empty session
try await session.clearSession()
let empty = try await session.popItem() // nil
```

### Clearing Sessions

```swift
let session = InMemorySession(sessionId: "chat-123")

try await session.addItems([
    .user("Message 1"),
    .user("Message 2")
])

// Clear all messages
try await session.clearSession()

print(await session.isEmpty) // true
print(await session.sessionId) // "chat-123" (unchanged)

// Session can be reused
try await session.addItem(.user("New conversation"))
```

## Using Sessions with Agents

Sessions integrate seamlessly with all Swarm agent types, automatically managing conversation history across multiple turns.

### Basic Multi-Turn Conversation

```swift
import Swarm

// Create session
let session = InMemorySession()

// Create agent
let agent = ReActAgent(
    tools: [WeatherTool(), CalculatorTool()],
    instructions: "You are a helpful assistant."
)

// Turn 1
let result1 = try await agent.run("Hello!", session: session)
print(result1.output) // "Hello! How can I help you?"

// Turn 2 - agent has context from turn 1
let result2 = try await agent.run("What's the weather?", session: session)
print(result2.output) // Agent can reference previous greeting

// Verify session history
let history = try await session.getAllItems()
print(history.count) // 4 (2 user messages + 2 assistant responses)
```

### Session History Loading

When you pass a session to `agent.run()`, the agent automatically loads recent session history as context:

```swift
let session = InMemorySession()

// Turn 1
try await agent.run("My name is Alice", session: session)

// Turn 2 - session history is loaded automatically
let result = try await agent.run("What's my name?", session: session)
// Agent has access to "My name is Alice" from history
```

**History Limit**: Configure how many recent messages to load via `AgentConfiguration`:

```swift
let config = AgentConfiguration.default
    .sessionHistoryLimit(20) // Load last 20 messages

let agent = ReActAgent(
    tools: [],
    instructions: "You are a helpful assistant.",
    configuration: config
)

// Agent loads last 20 messages from session on each run
```

### Multiple Agents Sharing a Session

Multiple agents can share the same session, enabling collaborative multi-agent workflows:

```swift
let sharedSession = InMemorySession()

// First agent
let researchAgent = ReActAgent(
    tools: [SearchTool()],
    instructions: "You are a research assistant."
)

// Second agent
let writerAgent = ReActAgent(
    tools: [WriteFileTool()],
    instructions: "You are a writing assistant."
)

// Research phase
try await researchAgent.run(
    "Research the history of AI",
    session: sharedSession
)

// Writing phase - has context from research
try await writerAgent.run(
    "Write a summary based on the research",
    session: sharedSession
)

// Both agents' messages are in the shared session
let fullHistory = try await sharedSession.getAllItems()
```

### Session with Streaming

```swift
let session = InMemorySession()

for try await event in agent.stream("Tell me a story", session: session) {
    switch event {
    case .reasoning(let thought):
        print("Thinking: \(thought)")
    case .content(let chunk):
        print("Content: \(chunk)", terminator: "")
    case .completed(let result):
        print("\nDone: \(result.output)")
    default:
        break
    }
}

// Session is automatically updated after stream completes
let messages = try await session.getAllItems()
```

### Session Cleanup Between Conversations

```swift
let session = InMemorySession()

// Conversation 1
try await agent.run("Hello", session: session)
try await agent.run("How are you?", session: session)

// Start fresh conversation
try await session.clearSession()

// Conversation 2 (no history from conversation 1)
try await agent.run("Tell me about Swift", session: session)
```

### Without a Session

You can run agents without a session for stateless interactions:

```swift
let agent = ReActAgent(
    tools: [CalculatorTool()],
    instructions: "You are a calculator."
)

// No session - each call is independent
let result1 = try await agent.run("What's 2+2?", session: nil)
let result2 = try await agent.run("What's 5*3?", session: nil)

// No conversation history is maintained
```

## Cross-Platform Considerations

### Platform Availability

| Session Type | iOS | macOS | watchOS | tvOS | Linux | Windows |
|--------------|-----|-------|---------|------|-------|---------|
| InMemorySession | ✅ 17+ | ✅ 14+ | ✅ 10+ | ✅ 17+ | ✅ | ✅ |
| PersistentSession | ✅ 17+ | ✅ 14+ | ✅ 10+ | ✅ 17+ | ❌ | ❌ |

### SwiftData Availability

`PersistentSession` requires SwiftData, which is only available on Apple platforms:

```swift
#if canImport(SwiftData)
    // PersistentSession is available
    let session = try PersistentSession.persistent(sessionId: "chat-1")
#else
    // Fall back to InMemorySession or custom implementation
    let session = InMemorySession(sessionId: "chat-1")
#endif
```

### Custom Cross-Platform Persistence

For Linux or other non-Apple platforms, implement a custom session using your preferred database:

```swift
import Foundation
import PostgresKit // Example: Using PostgreSQL

public actor PostgresSession: Session {
    public nonisolated let sessionId: String
    private let database: PostgresDatabase

    public init(sessionId: String, database: PostgresDatabase) {
        self.sessionId = sessionId
        self.database = database
    }

    public var itemCount: Int {
        get async {
            // Query PostgreSQL for message count
            // ...
        }
    }

    public func getItems(limit: Int?) async throws -> [MemoryMessage] {
        // Fetch from PostgreSQL
        // ...
    }

    public func addItems(_ items: [MemoryMessage]) async throws {
        // Insert into PostgreSQL
        // ...
    }

    // Implement remaining Session protocol methods...
}
```

## Best Practices

### 1. Use Appropriate Session Type

```swift
// Development/Testing: Use InMemorySession
let testSession = InMemorySession()

// Production (Apple platforms): Use PersistentSession
let prodSession = try PersistentSession.persistent(sessionId: userId)

// Production (Cross-platform): Implement custom session
let customSession = RedisSession(sessionId: userId, redis: redisClient)
```

### 2. Session ID Conventions

Use meaningful session IDs for easier debugging and tracking:

```swift
// ❌ Avoid generic IDs
let session = InMemorySession(sessionId: "session1")

// ✅ Use descriptive IDs
let userId = "user-12345"
let conversationId = UUID().uuidString
let session = InMemorySession(sessionId: "\(userId)-\(conversationId)")
```

### 3. Limit Session History

For long-running conversations, limit the history loaded by agents:

```swift
let config = AgentConfiguration.default
    .sessionHistoryLimit(50) // Only load last 50 messages

let agent = ReActAgent(
    tools: tools,
    instructions: instructions,
    configuration: config
)

// Agent only sees last 50 messages from session
try await agent.run(input, session: session)
```

### 4. Handle Session Errors Gracefully

```swift
func runAgent(input: String, session: any Session) async throws -> String {
    do {
        let result = try await agent.run(input, session: session)
        return result.output
    } catch let error as SessionError {
        Log.memory.error("Session error: \(error.localizedDescription)")

        // Fall back to stateless execution
        let result = try await agent.run(input, session: nil)
        return result.output
    }
}
```

### 5. Clean Up Old Sessions

For persistent sessions, implement cleanup logic:

```swift
import SwiftData

actor SessionManager {
    func cleanupOldSessions(olderThan days: Int) async throws {
        let backend = try SwiftDataBackend.persistent()
        let cutoffDate = Date().addingTimeInterval(-Double(days * 86400))

        // Query and delete old sessions
        // Implementation depends on your backend
    }
}
```

### 6. Session Per Conversation

Create a new session for each distinct conversation:

```swift
class ChatViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []

    func startNewConversation() async {
        let sessionId = UUID().uuidString
        let session = try? PersistentSession.persistent(sessionId: sessionId)

        let conversation = Conversation(
            id: sessionId,
            session: session,
            messages: []
        )

        conversations.append(conversation)
    }
}
```

### 7. Combine Session and Memory

Use sessions for conversation history and memory for context retrieval:

```swift
let session = InMemorySession()
let vectorMemory = VectorMemory(
    provider: OpenAIEmbeddings(),
    backend: InMemoryVectorBackend()
)

let agent = ReActAgent(
    tools: tools,
    instructions: instructions,
    memory: vectorMemory
)

// Session manages conversation history
// Memory provides semantic context retrieval
let result = try await agent.run(input, session: session)
```

### 8. Test with Both Session Types

```swift
@Suite("Agent Session Tests")
struct AgentSessionTests {
    @Test("Agent works with InMemorySession")
    func testInMemorySession() async throws {
        let session = InMemorySession()
        let result = try await agent.run("Hello", session: session)
        #expect(!result.output.isEmpty)
    }

    @Test("Agent works with PersistentSession")
    @available(macOS 14.0, iOS 17.0, *)
    func testPersistentSession() async throws {
        let session = try PersistentSession.inMemory(sessionId: "test")
        let result = try await agent.run("Hello", session: session)
        #expect(!result.output.isEmpty)
    }
}
```

## Summary

- **Sessions** provide simple chronological message storage for multi-turn conversations
- **Memory** provides intelligent context retrieval with token limits
- **InMemorySession** is fast and cross-platform but ephemeral
- **PersistentSession** provides SwiftData-backed persistence on Apple platforms
- Sessions integrate automatically with all agent types
- Multiple agents can share a single session for collaborative workflows
- Configure session history limits via `AgentConfiguration.sessionHistoryLimit`
- Implement custom sessions for cross-platform persistence needs

For more information, see:
- [Memory Systems Documentation](./memory.md) (when available)
- [Agent Configuration Guide](./configuration.md) (when available)
- [Swarm API Reference](./api-reference.md) (when available)
