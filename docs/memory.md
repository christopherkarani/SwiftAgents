# Memory Systems

Memory systems are a critical component of intelligent agents. They allow agents to maintain context across interactions, recall relevant information, and provide coherent, contextually-aware responses. Without memory, agents would treat each interaction as completely independent, losing valuable context that makes conversations natural and effective.

## Overview

Swarm provides a comprehensive memory system designed for:

- **Context Persistence**: Maintain conversation history across multiple turns
- **Token Management**: Automatically manage context window limits
- **Semantic Retrieval**: Find relevant past interactions using vector similarity
- **Compression**: Summarize long conversations to preserve important information
- **Thread Safety**: All memory implementations are actors for safe concurrent access

The framework includes four memory implementations, each optimized for different use cases:

| Memory Type | Best For | Key Feature |
|------------|----------|-------------|
| `ConversationMemory` | Simple chat applications | Fixed message count |
| `SlidingWindowMemory` | Token-aware applications | Token budget management |
| `SummaryMemory` | Long conversations | Automatic summarization |
| `VectorMemory` | RAG applications | Semantic search |

## Memory Protocol

All memory implementations conform to the `Memory` protocol, which defines the contract for storing and retrieving conversation context.

### Protocol Definition

```swift
public protocol Memory: Actor, Sendable {
    /// The number of messages currently stored.
    var count: Int { get async }

    /// Whether the memory contains no messages.
    var isEmpty: Bool { get async }

    /// Adds a message to memory.
    func add(_ message: MemoryMessage) async

    /// Retrieves context relevant to the query within token limits.
    func context(for query: String, tokenLimit: Int) async -> String

    /// Returns all messages currently in memory.
    func allMessages() async -> [MemoryMessage]

    /// Removes all messages from memory.
    func clear() async
}
```

### Key Design Decisions

1. **Actor Requirement**: All memory implementations must be actors, ensuring thread-safe access without manual synchronization.

2. **Sendable Conformance**: Required for safe concurrent access across actor boundaries.

3. **Async Methods**: All operations are implicitly async due to actor isolation.

4. **Query-Based Context**: The `context(for:tokenLimit:)` method allows implementations to provide relevant context based on the current query, enabling semantic search in advanced implementations.

### Creating Custom Memory

To create a custom memory implementation:

```swift
public actor MyCustomMemory: Memory {
    private var messages: [MemoryMessage] = []

    public var count: Int { messages.count }
    public var isEmpty: Bool { messages.isEmpty }

    public func add(_ message: MemoryMessage) async {
        messages.append(message)
    }

    public func context(for query: String, tokenLimit: Int) async -> String {
        formatMessagesForContext(messages, tokenLimit: tokenLimit)
    }

    public func allMessages() async -> [MemoryMessage] {
        messages
    }

    public func clear() async {
        messages.removeAll()
    }
}
```

## Memory Types

### ConversationMemory

`ConversationMemory` is the simplest memory implementation, maintaining a fixed number of recent messages using a FIFO (First-In-First-Out) strategy.

#### When to Use

- Simple chatbots with predictable conversation lengths
- Applications where message count is more important than token count
- Quick prototypes and testing
- Scenarios where you want deterministic memory behavior

#### Configuration

```swift
let memory = ConversationMemory(
    maxMessages: 50,                                    // Maximum messages to retain
    tokenEstimator: CharacterBasedTokenEstimator.shared // Token counting strategy
)
```

#### Basic Usage

```swift
// Create memory with 100-message limit (default)
let memory = ConversationMemory(maxMessages: 100)

// Add messages
await memory.add(.user("Hello, how are you?"))
await memory.add(.assistant("I'm doing well, thank you!"))
await memory.add(.user("Can you help me with Swift?"))

// Get context for the agent
let context = await memory.context(for: "Swift help", tokenLimit: 2000)

// Check memory state
let messageCount = await memory.count
let isEmpty = await memory.isEmpty
```

#### Batch Operations

```swift
// Add multiple messages at once
await memory.addAll([
    .user("First message"),
    .assistant("First response"),
    .user("Second message"),
    .assistant("Second response")
])

// Get recent messages
let recent = await memory.getRecentMessages(5)

// Get oldest messages
let oldest = await memory.getOldestMessages(3)
```

#### Filtering and Queries

```swift
// Get all user messages
let userMessages = await memory.messages(withRole: .user)

// Get all assistant messages
let assistantMessages = await memory.messages(withRole: .assistant)

// Custom filtering
let longMessages = await memory.filter { $0.content.count > 100 }

// Access specific messages
if let lastMessage = await memory.lastMessage {
    print("Last message: \(lastMessage.content)")
}

if let firstMessage = await memory.firstMessage {
    print("First message: \(firstMessage.content)")
}
```

#### Diagnostics

```swift
let diagnostics = await memory.diagnostics()
print("Messages: \(diagnostics.messageCount)/\(diagnostics.maxMessages)")
print("Utilization: \(diagnostics.utilizationPercent)%")
print("Oldest: \(diagnostics.oldestTimestamp ?? Date())")
print("Newest: \(diagnostics.newestTimestamp ?? Date())")
```

---

### SummaryMemory

`SummaryMemory` automatically compresses older messages into summaries while keeping recent messages intact. This allows for much longer effective conversation histories within token limits.

#### Architecture

```
[Summary of messages 1-50] + [Recent messages 51-70]
```

When message count exceeds the threshold, older messages are summarized and the summary is prepended to the context.

#### When to Use

- Long-running conversations spanning many turns
- Customer support scenarios with extended interactions
- Applications where historical context matters but token limits are constrained
- Scenarios where you need to preserve key information from early in conversations

#### Configuration

```swift
let memory = SummaryMemory(
    configuration: .init(
        recentMessageCount: 20,      // Messages to keep unsummarized
        summarizationThreshold: 50,  // When to trigger summarization
        summaryTokenTarget: 500      // Target size for summaries
    ),
    summarizer: MySummarizer(),               // Primary summarization service
    fallbackSummarizer: TruncatingSummarizer.shared, // Fallback option
    tokenEstimator: CharacterBasedTokenEstimator.shared
)
```

#### Basic Usage

```swift
// Create with default configuration
let memory = SummaryMemory()

// Or with custom settings
let memory = SummaryMemory(
    configuration: .init(
        recentMessageCount: 30,
        summarizationThreshold: 100,
        summaryTokenTarget: 1000
    )
)

// Add messages normally
await memory.add(.user("Tell me about Swift concurrency"))
await memory.add(.assistant("Swift concurrency is built around..."))

// When messages exceed threshold, summarization happens automatically
// Get context includes both summary and recent messages
let context = await memory.context(for: "current query", tokenLimit: 4000)
```

#### Accessing Summary State

```swift
// Check if a summary exists
let hasSummary = await memory.hasSummary

// Get the current summary text
let summary = await memory.currentSummary

// Get total messages processed (including summarized ones)
let total = await memory.totalMessages
```

#### Manual Summarization

```swift
// Force summarization before threshold is reached
// Useful at conversation breakpoints
await memory.forceSummarize()

// Set a custom summary (e.g., from external source)
await memory.setSummary("The user discussed their project requirements...")
```

#### Diagnostics

```swift
let diagnostics = await memory.diagnostics()
print("Recent messages: \(diagnostics.recentMessageCount)")
print("Total processed: \(diagnostics.totalMessagesProcessed)")
print("Has summary: \(diagnostics.hasSummary)")
print("Summary tokens: \(diagnostics.summaryTokenCount)")
print("Summarization count: \(diagnostics.summarizationCount)")
print("Next summarization in: \(diagnostics.nextSummarizationIn) messages")
```

#### Fallback Behavior

If the primary summarizer is unavailable (e.g., Foundation Models on simulator), `SummaryMemory` automatically falls back to truncation to maintain functionality:

```swift
// TruncatingSummarizer is used as ultimate fallback
// This ensures memory always works, even without AI summarization
```

---

### SlidingWindowMemory

`SlidingWindowMemory` is a token-aware memory that maintains messages within a token budget rather than a message count. It automatically removes oldest messages when the total token count exceeds the limit.

#### When to Use

- Applications targeting specific LLM context windows
- When message sizes vary significantly
- Production applications requiring precise token management
- When you need to maximize context usage within model limits

#### Configuration

```swift
let memory = SlidingWindowMemory(
    maxTokens: 4000,                                   // Token budget
    tokenEstimator: CharacterBasedTokenEstimator.shared // Token counting
)
```

#### Basic Usage

```swift
// Create with 4000 token limit
let memory = SlidingWindowMemory(maxTokens: 4000)

// Add messages - old ones are evicted when token limit is exceeded
await memory.add(.user("This is a long message that uses many tokens..."))
await memory.add(.assistant("Here's an even longer response..."))

// Get context within a specific token budget
let context = await memory.context(for: "query", tokenLimit: 2000)
```

#### Token Information

```swift
// Current token usage
let currentTokens = await memory.tokenCount

// Remaining capacity
let remaining = await memory.remainingTokens

// Check if near capacity (>90%)
let nearCapacity = await memory.isNearCapacity

if nearCapacity {
    print("Memory is \(remaining) tokens from full")
}
```

#### Budget-Based Retrieval

```swift
// Get messages that fit within a specific token budget
let messagesForPrompt = await memory.getMessages(withinTokenBudget: 2000)
```

#### Token Recalibration

The memory automatically recalibrates token counts periodically to prevent drift from estimation errors:

```swift
// Manual recalibration if needed
await memory.recalculateTokenCount()
```

#### Diagnostics

```swift
let diagnostics = await memory.diagnostics()
print("Messages: \(diagnostics.messageCount)")
print("Tokens: \(diagnostics.currentTokens)/\(diagnostics.maxTokens)")
print("Utilization: \(diagnostics.utilizationPercent)%")
print("Remaining: \(diagnostics.remainingTokens)")
print("Avg tokens/message: \(diagnostics.averageTokensPerMessage)")
```

---

### VectorMemory

`VectorMemory` enables semantic search over conversation history using vector embeddings. Instead of returning recent messages, it returns the most semantically similar messages to the current query.

#### When to Use

- RAG (Retrieval-Augmented Generation) applications
- Long conversations where recency isn't the best relevance indicator
- Knowledge-intensive applications
- When you need to find contextually relevant information across many interactions

#### How It Works

1. When messages are added, they are embedded using the configured `EmbeddingProvider`
2. During context retrieval, the query is embedded and compared against stored embeddings
3. Messages with similarity above the threshold are returned, ranked by similarity
4. Results are limited by `maxResults` and `tokenLimit`

#### Configuration

```swift
let memory = VectorMemory(
    embeddingProvider: MyEmbeddingProvider(),  // Required
    similarityThreshold: 0.7,                   // Minimum similarity (0-1)
    maxResults: 10,                             // Maximum results
    tokenEstimator: CharacterBasedTokenEstimator.shared
)
```

#### Basic Usage

```swift
// Create memory with embedding provider
let memory = VectorMemory(
    embeddingProvider: OpenAIEmbeddingProvider(apiKey: "..."),
    similarityThreshold: 0.7,
    maxResults: 10
)

// Add messages (automatically embedded)
await memory.add(.user("What is Swift concurrency?"))
await memory.add(.assistant("Swift concurrency provides structured...")
await memory.add(.user("How do actors work?"))
await memory.add(.assistant("Actors are reference types that protect...")

// Semantic search - finds relevant messages regardless of recency
let context = await memory.context(
    for: "Tell me about thread safety",  // Will find actor-related messages
    tokenLimit: 2000
)
```

#### Direct Semantic Search

```swift
// Search with results including similarity scores
let results = try await memory.search(query: "concurrency patterns")

for result in results {
    print("Similarity: \(result.similarity)")
    print("Message: \(result.message.content)")
}

// Search with pre-computed embedding
let queryEmbedding = try await embeddingProvider.embed("my query")
let results = memory.search(queryEmbedding: queryEmbedding)
```

#### Batch Operations

```swift
// Add multiple messages efficiently (uses batch embedding)
await memory.addAll([
    .user("First question"),
    .assistant("First answer"),
    .user("Second question"),
    .assistant("Second answer")
])

// Filter messages by role
let userMessages = await memory.messages(withRole: .user)

// Custom filtering
let recentMessages = await memory.filter {
    $0.timestamp > Date().addingTimeInterval(-3600)
}
```

#### Builder Pattern

```swift
let memory = try VectorMemoryBuilder()
    .embeddingProvider(MyEmbeddingProvider())
    .similarityThreshold(0.75)
    .maxResults(15)
    .tokenEstimator(MyTokenEstimator())
    .build()
```

#### Diagnostics

```swift
let diagnostics = await memory.diagnostics()
print("Messages: \(diagnostics.messageCount)")
print("Embedding dimensions: \(diagnostics.embeddingDimensions)")
print("Similarity threshold: \(diagnostics.similarityThreshold)")
print("Max results: \(diagnostics.maxResults)")
print("Model: \(diagnostics.modelIdentifier)")
```

#### Performance Notes

On Apple platforms, cosine similarity calculations use SIMD-optimized operations via the Accelerate framework for efficient vector comparisons. A portable fallback is used on other platforms.

```swift
// The static method is available for custom use
let similarity = VectorMemory.cosineSimilarity(vector1, vector2)
```

---

## Combining Memory Systems

For sophisticated applications, you can combine multiple memory types to leverage their strengths.

### Hybrid Memory Pattern

```swift
actor HybridMemory: Memory {
    private let shortTerm: ConversationMemory
    private let longTerm: VectorMemory

    public var count: Int {
        get async {
            await shortTerm.count + await longTerm.count
        }
    }

    public var isEmpty: Bool {
        get async {
            await shortTerm.isEmpty && await longTerm.isEmpty
        }
    }

    init(embeddingProvider: any EmbeddingProvider) {
        self.shortTerm = ConversationMemory(maxMessages: 20)
        self.longTerm = VectorMemory(
            embeddingProvider: embeddingProvider,
            similarityThreshold: 0.6
        )
    }

    public func add(_ message: MemoryMessage) async {
        // Add to both memories
        await shortTerm.add(message)
        await longTerm.add(message)
    }

    public func context(for query: String, tokenLimit: Int) async -> String {
        // Allocate token budget between memories
        let recentBudget = tokenLimit / 2
        let semanticBudget = tokenLimit - recentBudget

        // Get recent context
        let recentContext = await shortTerm.context(
            for: query,
            tokenLimit: recentBudget
        )

        // Get semantically relevant context
        let semanticContext = await longTerm.context(
            for: query,
            tokenLimit: semanticBudget
        )

        return """
        [Recent conversation]:
        \(recentContext)

        [Relevant history]:
        \(semanticContext)
        """
    }

    public func allMessages() async -> [MemoryMessage] {
        await longTerm.allMessages()
    }

    public func clear() async {
        await shortTerm.clear()
        await longTerm.clear()
    }
}
```

### Summary + Vector Pattern

```swift
actor SmartMemory: Memory {
    private let summary: SummaryMemory
    private let vector: VectorMemory

    // ... implementation combining summarization with semantic search
}
```

---

## Memory with Agents

Memory systems integrate seamlessly with Swarm' agent infrastructure.

### Attaching Memory to Agents

```swift
// Create memory
let memory = ConversationMemory(maxMessages: 50)

// Create agent with memory
let agent = Agent(
    instructions: "You are a helpful assistant",
    configuration: AgentConfiguration(name: "Assistant"),
    memory: memory
)

// Memory is automatically used during conversations
let response = try await agent.run("Hello!")
// Memory now contains both the user message and assistant response
```

### Using AnyMemory for Flexibility

When you need to work with different memory types through a uniform interface:

```swift
// Type-erase any memory implementation
let conversation = ConversationMemory(maxMessages: 50)
let erasedMemory = AnyMemory(conversation)

// Use through the Memory protocol
await erasedMemory.add(.user("Hello"))
let context = await erasedMemory.context(for: "query", tokenLimit: 1000)
```

### Memory in Multi-Agent Systems

```swift
// Shared memory between agents
let sharedMemory = ConversationMemory(maxMessages: 100)

let agent1 = Agent(configuration: AgentConfiguration(name: "Researcher"), memory: sharedMemory)
let agent2 = Agent(configuration: AgentConfiguration(name: "Writer"), memory: sharedMemory)

// Both agents can access and contribute to the same memory
```

---

## Persistence

For applications requiring memory persistence across sessions, use the session management APIs.

### In-Memory Sessions

```swift
// Create session manager
let sessionManager = InMemorySessionManager()

// Save memory state
let messages = await memory.allMessages()
await sessionManager.save(sessionId: "user-123", messages: messages)

// Restore memory state
if let savedMessages = await sessionManager.load(sessionId: "user-123") {
    let memory = ConversationMemory(maxMessages: 100)
    await memory.addAll(savedMessages)
}
```

### Persistent Sessions

```swift
// File-based persistence
let sessionManager = PersistentSessionManager(
    directory: FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first!.appendingPathComponent("sessions")
)

// Save and load work the same way
await sessionManager.save(sessionId: "user-123", messages: messages)
let restored = await sessionManager.load(sessionId: "user-123")
```

### Custom Persistence

```swift
// Implement your own persistence (e.g., Core Data, CloudKit)
actor CoreDataSessionManager {
    func save(sessionId: String, memory: any Memory) async {
        let messages = await memory.allMessages()
        // Save to Core Data...
    }

    func restore(sessionId: String) async -> [MemoryMessage] {
        // Load from Core Data...
    }
}
```

---

## Best Practices

### 1. Choose the Right Memory Type

| Scenario | Recommended Memory |
|----------|-------------------|
| Simple chatbot | `ConversationMemory` |
| Production chat app | `SlidingWindowMemory` |
| Customer support | `SummaryMemory` |
| Knowledge base Q&A | `VectorMemory` |
| Complex assistant | Hybrid approach |

### 2. Token Management

```swift
// Always specify realistic token limits based on your model
let context = await memory.context(
    for: query,
    tokenLimit: 4000  // Leave room for system prompt and response
)

// Monitor token usage in production
let diagnostics = await slidingMemory.diagnostics()
if diagnostics.utilizationPercent > 80 {
    Log.memory.warning("Memory utilization high: \(diagnostics.utilizationPercent)%")
}
```

### 3. Handle Memory Errors Gracefully

```swift
// VectorMemory operations can fail
do {
    let results = try await vectorMemory.search(query: userQuery)
    // Use results...
} catch {
    // Fallback to simple retrieval
    let allMessages = await vectorMemory.allMessages()
    // Use recent messages...
}
```

### 4. Clear Memory Appropriately

```swift
// Clear memory at conversation boundaries
await memory.clear()

// Or use session management for persistence
await sessionManager.save(sessionId: currentSession, messages: messages)
await memory.clear()
```

### 5. Use Diagnostics for Monitoring

```swift
// Periodically log memory state in production
Task {
    while true {
        try await Task.sleep(for: .minutes(5))
        let diagnostics = await memory.diagnostics()
        Log.metrics.info("Memory state: \(diagnostics)")
    }
}
```

### 6. Consider Memory Initialization

```swift
// Pre-populate memory with system context
let memory = ConversationMemory(maxMessages: 100)
await memory.add(.system("You are helping with a coding project"))
await memory.add(.assistant("Hello! I'm ready to help with your code."))
```

### 7. Thread Safety

All memory implementations are actors, so you don't need additional synchronization:

```swift
// Safe to call from multiple tasks
async let add1 = memory.add(.user("Message 1"))
async let add2 = memory.add(.user("Message 2"))
await (add1, add2)  // Both complete safely
```

### 8. Memory Size Guidelines

| Model Context | Recommended maxTokens |
|--------------|----------------------|
| 4K tokens | 2000-3000 |
| 8K tokens | 5000-6000 |
| 16K tokens | 12000-14000 |
| 32K+ tokens | 24000-28000 |

Reserve 20-30% for system prompts and response generation.

---

## Summary

Swarm' memory system provides flexible, thread-safe options for managing conversation context:

- **ConversationMemory**: Simple FIFO with message count limits
- **SlidingWindowMemory**: Token-aware with automatic eviction
- **SummaryMemory**: Compresses history through summarization
- **VectorMemory**: Semantic search for relevant context retrieval

All implementations conform to the `Memory` protocol, enabling easy substitution and combination. Choose based on your application's needs for context length, relevance, and token efficiency.
