# SwiftAgents

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20|%20macOS%2014%2B%20|%20Linux-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

**LangChain for Apple Platforms and Linux Servers** — A comprehensive Swift framework for building autonomous AI agents

SwiftAgents provides the agent orchestration layer on top of SwiftAI SDK, enabling autonomous reasoning, intelligent tool use, persistent memory systems, and sophisticated multi-agent coordination—built natively for Apple platforms and Linux servers with Swift 6.2's strict concurrency safety.

---

## Features

- 🤖 **Agent Framework** - ReAct, PlanAndExecute, and ToolCalling patterns for autonomous reasoning
- 🧠 **Memory Systems** - Conversation, sliding window, summary, hybrid, and pluggable persistence backends
- 💬 **Session Management** - Automatic conversation history with in-memory and persistent storage
- 🔍 **Distributed Tracing** - TraceContext with hierarchical span tracking and task-local propagation
- 🛠️ **Tool Integration** - Type-safe tool protocol with fluent builder API and built-in utilities
- 🎭 **Multi-Agent Orchestration** - Supervisor-worker patterns, sequential chains, parallel execution, and intelligent routing
- 🤝 **Enhanced Handoffs** - Callbacks, input filters, and dynamic enablement for agent-to-agent transfers
- 🔀 **MultiProvider Routing** - Route inference requests to different providers based on model prefixes
- 📊 **Observability** - Cross-platform tracing with swift-log, metrics collection, and event streaming
- 🔄 **Resilience** - Circuit breakers, retry policies with exponential backoff, and fallback chains
- 🐧 **Cross-Platform** - Full support for Apple platforms (iOS 17+, macOS 14+) and Linux servers
- ⚡️ **Swift 6.2 Native** - Full actor isolation, Sendable types, and structured concurrency throughout
- 🍎 **LLM Agnostic** - Designed for use with any LLM, local, cloud or Foundation Models
- 🪄 **Swift Macros** - `@Tool`, `@Agent`, `@Parameter` macros eliminate boilerplate
- 🔗 **DSL & Operators** - Fluent APIs, result builders, and composition operators (`>>>`, `&+`, `~>`)

---

## Requirements
- **Swift 6.2+**
- **Apple Platforms**: Xcode 16.0+, iOS 17+, macOS 14+, watchOS 10+, tvOS 17+, visionOS 1+
- **Linux**: Ubuntu 22.04+ or compatible distribution with Swift 6.2

---

## Installation

### Swift Package Manager

Add SwiftAgents to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/chriskarani/SwiftAgents.git", from: "1.0.0")
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "SwiftAgents", package: "SwiftAgents")
    ]
)
```

### Xcode Project

1. File > Add Package Dependencies
2. Enter repository URL: `https://github.com/chriskarani/SwiftAgents.git`
3. Select version and add to your target

---

## Quick Start

### Setup Logging (Required)

SwiftAgents uses swift-log for cross-platform logging. Bootstrap logging once at application startup:

```swift
import SwiftAgents

// Bootstrap with default console logging
Log.bootstrap()
```

### Basic Agent

Create a simple agent with tool calling capabilities:

```swift
import SwiftAgents

// Create an inference provider (Foundation Models, SwiftAI SDK, etc.)
let provider = MyInferenceProvider()

// Build an agent with tools
let agent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .instructions("You are a helpful assistant that can perform calculations.")
    .withBuiltInTools()  // Adds DateTime and other built-in tools
    .addTool(CalculatorTool())
    .configuration(.default.maxIterations(5))
    .build()

// Execute the agent
let result = try await agent.run("What is 25% of 200?")
print(result.output)  // "50"
print("Executed in \(result.duration)")
print("Tool calls: \(result.toolCalls.count)")
```

### Agent with Memory

Maintain conversation context across multiple interactions:

```swift
import SwiftAgents

// Create a conversation memory with token limit
let memory = ConversationMemory(maxTokens: 4000)

let agent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .memory(memory)
    .instructions("You are a friendly assistant with memory of our conversation.")
    .build()

// First message
let response1 = try await agent.run("My name is Alice and I love Swift programming.")
print(response1.output)  // "Nice to meet you, Alice! Swift is a great language..."

// Second message - agent remembers context
let response2 = try await agent.run("What's my name and what do I love?")
print(response2.output)  // "Your name is Alice and you love Swift programming."

// Check memory contents
let messages = await memory.allMessages()
print("Stored messages: \(messages.count)")
```

### Session Management

Manage conversation history automatically with sessions—no manual history tracking required:

```swift
import SwiftAgents

// Create an in-memory session
let session = InMemorySession(sessionId: "user_123")

let agent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .instructions("You are a helpful assistant.")
    .build()

// First turn - session automatically stores history
let response1 = try await agent.run(
    "My favorite color is blue",
    session: session
)

// Second turn - agent automatically has access to previous messages
let response2 = try await agent.run(
    "What's my favorite color?",
    session: session
)
print(response2.output)  // "Your favorite color is blue."

// Inspect session contents
let history = try await session.getAllItems()
print("Messages in session: \(history.count)")  // 4 (2 user + 2 assistant)
```

**Persistent sessions** survive app restarts (Apple platforms only):

```swift
#if canImport(SwiftData)
// Create a persistent session (survives app restarts)
let session = try PersistentSession.persistent(sessionId: "user_123")

let agent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .build()

// Conversation history is automatically saved to disk
try await agent.run("Remember this for later", session: session)

// Even after app restart, history is preserved
let history = try await session.getAllItems()
#endif
```

**Session operations**:

```swift
// Get recent messages only
let recent = try await session.getItems(limit: 10)

// Remove the last message (undo)
let removed = try await session.popItem()

// Clear entire conversation
try await session.clearSession()

// Check session state
let count = await session.itemCount
let empty = await session.isEmpty
```

### TraceContext: Distributed Tracing

Group related operations and track execution hierarchies with `TraceContext`:

```swift
import SwiftAgents

// Execute agent within a trace context
await TraceContext.withTrace(
    "Customer Support Chat",
    groupId: "session_456",
    metadata: ["customer_id": .string("user_789")]
) {
    // TraceContext.current is automatically available
    let result = try await agent.run("Help me with my order")

    // Access trace information
    if let context = TraceContext.current {
        print("Trace ID: \(await context.traceId)")
        print("Duration: \(await context.duration)")

        // Get all spans collected during execution
        let spans = await context.getSpans()
        for span in spans {
            print("Span: \(span.name), Duration: \(span.duration ?? 0)")
        }
    }
}
```

**Manual span tracking**:

```swift
await TraceContext.withTrace("Data Pipeline") {
    guard let context = TraceContext.current else { return }

    // Start a span for database query
    let dbSpan = await context.startSpan(
        "database-query",
        metadata: ["table": .string("users")]
    )

    let users = try await fetchUsers()
    await context.endSpan(dbSpan, status: .ok)

    // Start another span for processing
    let processSpan = await context.startSpan("process-data")
    let processed = processUsers(users)
    await context.endSpan(processSpan, status: .ok)
}
```

**Nested traces** with automatic parent-child relationships:

```swift
await TraceContext.withTrace("Outer Workflow") {
    let result1 = try await agent.run("First query")

    // Spans are collected in the outer context
    if let context = TraceContext.current {
        let spans = await context.getSpans()
        print("Total spans: \(spans.count)")

        // Inspect span hierarchy
        for span in spans {
            if span.parentSpanId != nil {
                print("  Child span: \(span.name)")
            } else {
                print("Root span: \(span.name)")
            }
        }
    }
}
```

### Streaming Responses

Stream agent execution in real-time:

```swift
import SwiftAgents

let agent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .build()

for try await event in agent.stream("Explain quantum computing") {
    switch event {
    case .started(let input):
        print("Started: \(input)")

    case .thinking(let thought):
        print("Thinking: \(thought)")

    case .toolCalling(let toolCall):
        print("Calling tool: \(toolCall.toolName)")

    case .toolResult(let result):
        print("Tool result: \(result)")

    case .chunk(let text):
        print(text, terminator: "")

    case .completed(let result):
        print("\n\nCompleted in \(result.duration)")

    case .failed(let error):
        print("Error: \(error)")
    }
}
```

### Multi-Agent Orchestration

Route requests to specialized agents:

```swift
import SwiftAgents

// Create specialized agents
let mathAgent = ReActAgent.Builder()
    .addTool(CalculatorTool())
    .instructions("You are a math specialist.")
    .build()

let weatherAgent = ReActAgent.Builder()
    .addTool(WeatherTool())
    .instructions("You are a weather information specialist.")
    .build()

// Create agent descriptions for routing
let mathDescription = AgentDescription(
    name: "math_agent",
    description: "Performs mathematical calculations and solves equations",
    capabilities: ["arithmetic", "algebra", "calculus"],
    keywords: ["calculate", "math", "compute", "solve", "equation"]
)

let weatherDescription = AgentDescription(
    name: "weather_agent",
    description: "Provides weather information and forecasts",
    capabilities: ["current weather", "forecasts", "temperature"],
    keywords: ["weather", "temperature", "forecast", "rain", "sunny"]
)

// Create supervisor with LLM-based routing
let supervisor = SupervisorAgent(
    agents: [
        (name: "math_agent", agent: mathAgent, description: mathDescription),
        (name: "weather_agent", agent: weatherAgent, description: weatherDescription)
    ],
    routingStrategy: LLMRoutingStrategy(inferenceProvider: provider),
    fallbackAgent: nil  // Optional general-purpose fallback
)

// Supervisor routes to appropriate agent
let result1 = try await supervisor.run("What's 15 times 23?")
// Routes to math_agent

let result2 = try await supervisor.run("What's the weather in San Francisco?")
// Routes to weather_agent

// Check routing metadata
if let selectedAgent = result1.metadata["selected_agent"]?.stringValue,
   let confidence = result1.metadata["routing_confidence"]?.doubleValue {
    print("Routed to: \(selectedAgent) (confidence: \(confidence))")
}
```

### Enhanced Agent Handoffs

Configure how agents hand off control to other agents with callbacks, filters, and enablement checks:

```swift
import SwiftAgents

// Create agents
let plannerAgent = PlanAndExecuteAgent.Builder()
    .instructions("You create execution plans.")
    .build()

let executorAgent = ReActAgent.Builder()
    .instructions("You execute tasks.")
    .build()

// Configure handoffs with callbacks
let handoffConfig = handoff(
    to: executorAgent,
    toolName: "execute_task",
    toolDescription: "Hand off to the executor agent",
    onHandoff: { context, data in
        // Log or validate before handoff
        print("Handoff: \(data.sourceAgentName) -> \(data.targetAgentName)")
        await context.set("handoff_time", value: .double(Date().timeIntervalSince1970))
    },
    inputFilter: { data in
        // Transform input before passing to target
        var modified = data
        modified.metadata["priority"] = .string("high")
        return modified
    },
    isEnabled: { context, agent in
        // Dynamically enable/disable handoffs
        await context.get("planning_complete")?.boolValue ?? false
    }
)

// Use in an agent with handoffs
let coordinator = ReActAgent {
    Instructions("You coordinate between planning and execution.")
    HandoffsComponent(handoffConfig)
}
```

**Handoff events** for observability:

```swift
for try await event in agent.stream(input) {
    switch event {
    case .handoffStarted(let from, let to, let input):
        print("Handoff started: \(from) -> \(to)")
    case .handoffCompletedWithResult(let from, let to, let result):
        print("Handoff completed: \(result.output)")
    case .handoffSkipped(let from, let to, let reason):
        print("Handoff skipped: \(reason)")
    default:
        break
    }
}
```

### MultiProvider: Model Routing

Route inference requests to different providers based on model name prefixes:

```swift
import SwiftAgents

// Create a multi-provider with default fallback
let multiProvider = MultiProvider(defaultProvider: openRouterProvider)

// Register providers for specific prefixes
try await multiProvider.register(prefix: "anthropic", provider: anthropicProvider)
try await multiProvider.register(prefix: "openai", provider: openAIProvider)
try await multiProvider.register(prefix: "google", provider: googleProvider)

// Set model - prefix determines which provider handles requests
await multiProvider.setModel("anthropic/claude-3-5-sonnet-20241022")

// This request routes to Anthropic provider
let response = try await multiProvider.generate(
    prompt: "Hello, world!",
    options: .default
)

// Change model - now routes to OpenAI
await multiProvider.setModel("openai/gpt-4o")
let response2 = try await multiProvider.generate(prompt: "Hello!", options: .default)

// Model without prefix uses default provider
await multiProvider.setModel("gpt-4")  // Routes to openRouterProvider
```

**Use with agents**:

```swift
let agent = ReActAgent.Builder()
    .inferenceProvider(multiProvider)
    .instructions("You are a helpful assistant.")
    .build()

// Agent uses the multi-provider for all inference
let result = try await agent.run("What's 2+2?")
```

### Custom Tools

Create tools using the `@Tool` macro (recommended) or manual implementation:

```swift
import SwiftAgents

// With @Tool macro (recommended) - 70% less code
@Tool("Searches the web for information")
struct SearchTool {
    @Parameter("The search query")
    var query: String

    @Parameter("Maximum results", default: 5)
    var maxResults: Int = 5

    func execute() async throws -> [String] {
        try await performWebSearch(query: query, limit: maxResults)
    }
}

// Use the tool
let agent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .addTool(SearchTool())
    .build()
```

### Advanced Memory Systems

Combine multiple memory strategies:

```swift
import SwiftAgents

// Sliding window: Keep last N messages
let slidingMemory = SlidingWindowMemory(windowSize: 10)

// Summary memory: Automatically summarize old conversations
let summaryMemory = SummaryMemory(
    maxTokens: 4000,
    summaryThreshold: 3000,
    summarizer: MySummarizer()  // Implement Summarizer protocol
)

// Hybrid memory: Short-term conversation + long-term summaries
let hybridMemory = HybridMemory(
    conversationMemory: ConversationMemory(maxTokens: 2000),
    summaryMemory: summaryMemory
)

// SwiftData-backed persistence (Apple platforms only)
#if canImport(SwiftData)
let backend = try SwiftDataBackend.persistent()
let persistentMemory = PersistentMemory(
    backend: backend,
    conversationId: "user_123"
)
#endif

// Or use InMemoryBackend for cross-platform ephemeral storage
let inMemoryBackend = InMemoryBackend()
let memory = PersistentMemory(backend: inMemoryBackend, conversationId: "user_123")

let agent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .memory(hybridMemory)
    .build()
```

### SwiftUI Integration (Apple Platforms)

Build chat interfaces with SwiftAgents:

```swift
import SwiftUI
import SwiftAgents

struct ChatView: View {
    @State private var agent: ReActAgent
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false

    init() {
        let provider = MyInferenceProvider()
        _agent = State(initialValue: ReActAgent.Builder()
            .inferenceProvider(provider)
            .memory(ConversationMemory(maxTokens: 4000))
            .withBuiltInTools()
            .build()
        )
    }

    var body: some View {
        VStack {
            // Message list
            ScrollView {
                ForEach(messages) { message in
                    MessageRow(message: message)
                }
            }

            // Input field
            HStack {
                TextField("Ask me anything...", text: $inputText)
                    .textFieldStyle(.roundedBorder)

                Button("Send") {
                    sendMessage()
                }
                .disabled(inputText.isEmpty || isProcessing)
            }
            .padding()
        }
        .navigationTitle("AI Assistant")
    }

    private func sendMessage() {
        let userMessage = ChatMessage(role: .user, content: inputText)
        messages.append(userMessage)

        let prompt = inputText
        inputText = ""
        isProcessing = true

        Task {
            do {
                var assistantMessage = ChatMessage(role: .assistant, content: "")
                messages.append(assistantMessage)
                let messageIndex = messages.count - 1

                // Stream response
                for try await event in agent.stream(prompt) {
                    switch event {
                    case .chunk(let text):
                        messages[messageIndex].content += text
                    case .completed:
                        isProcessing = false
                    case .failed(let error):
                        messages[messageIndex].content = "Error: \(error.localizedDescription)"
                        isProcessing = false
                    default:
                        break
                    }
                }
            } catch {
                isProcessing = false
            }
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String

    enum Role {
        case user, assistant
    }
}

struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            Text(message.content)
                .padding()
                .background(message.role == .user ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(12)

            if message.role == .assistant {
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}
```

---

## Macros & DSL API

SwiftAgents provides Swift macros and DSL patterns to dramatically reduce boilerplate.

### @Tool Macro

Transform verbose tool definitions into concise declarations:

```swift
// Before: 30+ lines
struct WeatherTool: Tool, Sendable {
    let name = "weather"
    let description = "Gets weather for a location"
    let parameters: [ToolParameter] = [
        ToolParameter(name: "location", description: "City name", type: .string, isRequired: true),
        ToolParameter(name: "units", description: "Units", type: .string, isRequired: false, defaultValue: .string("celsius"))
    ]
    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        guard let location = arguments["location"]?.stringValue else { throw ... }
        let units = arguments["units"]?.stringValue ?? "celsius"
        return .string("72°F in \(location)")
    }
}

// After: 10 lines with @Tool macro
@Tool("Gets weather for a location")
struct WeatherTool {
    @Parameter("City name")
    var location: String

    @Parameter("Temperature units", default: "celsius")
    var units: String = "celsius"

    func execute() async throws -> String {
        "72°F in \(location)"
    }
}
```

### @Agent Macro

Create agents with minimal boilerplate:

```swift
@Agent("You are a helpful coding assistant")
actor CodingAssistant {
    let tools: [any Tool] = [CalculatorTool(), SearchTool()]

    func process(_ input: String) async throws -> String {
        // Your custom logic
        "Processed: \(input)"
    }
}

// Automatically generates: init, run(), stream(), cancel(), all protocol conformance
let agent = CodingAssistant()
let result = try await agent.run("Help me with Swift")
```

### Agent Builder DSL

Declarative agent construction with result builders:

```swift
let agent = ReActAgent {
    Instructions("You are a math tutor.")

    Tools {
        CalculatorTool()
        if advancedMode {
            GraphingTool()
        }
    }

    Memory(ConversationMemory(maxMessages: 50))

    Configuration(.default.maxIterations(10).temperature(0.7))
}
```

### Pipeline Operators

Type-safe composition with `>>>` operator:

```swift
// Chain transformations
let pipeline = parseInput() >>> validateData() >>> processResult()
let output = try await pipeline.execute(rawInput)

// Agent pipelines
let workflow = extractOutput() >>> summarize() >>> formatAsJSON()
```

### Agent Composition Operators

Compose agents with operators:

```swift
// Parallel execution: &+
let parallel = researchAgent &+ analysisAgent
let results = try await parallel.run(query)  // Both run concurrently

// Sequential chain: ~>
let chain = fetchAgent ~> processAgent ~> formatAgent
let result = try await chain.run(input)  // Output flows through each

// Fallback: |?
let resilient = primaryAgent |? backupAgent
let result = try await resilient.run(input)  // Falls back on failure
```

### Fluent Resilience

Chain resilience patterns fluently:

```swift
let resilientAgent = myAgent
    .withRetry(.exponentialBackoff(maxAttempts: 3))
    .withCircuitBreaker(threshold: 5, resetTimeout: .seconds(60))
    .withFallback(backupAgent)
    .withTimeout(.seconds(30))

let result = try await resilientAgent.run(input)
```

### Memory Builder DSL

Compose memory systems declaratively:

```swift
let memory = CompositeMemory {
    ConversationMemory(maxMessages: 50)
        .priority(.high)

    SlidingWindowMemory(maxTokens: 4000)
        .priority(.normal)
}
.withRetrievalStrategy(.hybrid(recencyWeight: 0.7, relevanceWeight: 0.3))
.withMergeStrategy(.interleave)
```

### Stream Operations

Functional operations on agent event streams:

```swift
for try await thought in agent.stream(query).thoughts {
    print("Thinking: \(thought)")
}

// Filter, map, collect
let events = try await agent.stream(query)
    .filter { $0.isThinking }
    .take(5)
    .collect()

// Side effects
let stream = agent.stream(query)
    .onEach { print("Event: \($0)") }
    .onComplete { print("Done: \($0.output)") }
```

### Typed Context Keys

Compile-time safe context access:

```swift
// Define typed keys
extension ContextKey {
    static let userID = ContextKey<String>("userID")
    static let preferences = ContextKey<UserPreferences>("preferences")
}

// Type-safe access
await context.setTyped(.userID, value: "user_123")
let id: String? = await context.getTyped(.userID)  // Compile-time type checking
```

### InferenceOptions Presets

Fluent configuration with presets:

```swift
let options = InferenceOptions.creative      // High temperature, diverse outputs
let options = InferenceOptions.precise       // Low temperature, deterministic
let options = InferenceOptions.codeGeneration // Optimized for code

// Fluent customization
let custom = InferenceOptions.default
    .temperature(0.8)
    .maxTokens(2000)
    .topP(0.95)
    .stopSequences("END", "DONE")
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Your Application                         │
│         (iOS, macOS, watchOS, tvOS, visionOS, Linux)            │
├─────────────────────────────────────────────────────────────────┤
│                    UI Layer (Apple Platforms)                   │
│                  (SwiftUI Chat Views, Custom UIs)               │
├─────────────────────────────────────────────────────────────────┤
│                          SwiftAgents                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Agents     │  │    Memory    │  │    Tools     │          │
│  │ • ReAct      │  │ • Conversation│ │ • @Tool      │          │
│  │ • @Agent     │  │ • Composite  │  │ • @Parameter │          │
│  │ • Supervisor │  │ • Summary    │  │ • Registry   │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │Orchestration │  │ Observability│  │  Resilience  │          │
│  │ • &+ ~> |?   │  │ • @Traceable │  │ • withRetry  │          │
│  │ • Pipeline   │  │ • Tracing    │  │ • withFallback│         │
│  │ • Routing    │  │ • Metrics    │  │ • Circuit    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
├─────────────────────────────────────────────────────────────────┤
│         SwiftAgentsMacros (Compile-Time Code Generation)        │
├─────────────────────────────────────────────────────────────────┤
│              InferenceProvider Protocol (Abstract)              │
│                  (Foundation Models / SwiftAI SDK)              │
└─────────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

- **Application Layer**: Your iOS/macOS/Linux app using SwiftAgents
- **UI Layer**: SwiftUI components for Apple platforms (build your own or use custom views)
- **SwiftAgents Core**: Agent implementations, memory, tools, orchestration (cross-platform)
- **InferenceProvider**: Abstraction for LLM backends (implement for your model)

### Cross-Platform Features

- **Logging**: Uses swift-log for unified logging across Apple platforms and Linux
- **Memory Backends**: Pluggable architecture supporting custom storage (PostgreSQL, Redis, etc.)
- **Concurrency**: Swift 6.2 actors and structured concurrency work identically on all platforms
- **Platform-Specific**: SwiftData backend and OSLog tracer available on Apple platforms via conditional compilation

---

## Core Components

### 1. Agents

The `Agent` protocol defines the core contract for autonomous agents:

```swift
public protocol Agent: Sendable {
    var tools: [any Tool] { get }
    var instructions: String { get }
    var configuration: AgentConfiguration { get }
    var memory: (any Memory)? { get }  // Was: AgentMemory
    var inferenceProvider: (any InferenceProvider)? { get }

    func run(_ input: String) async throws -> AgentResult
    func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error>
    func cancel() async
}
```

**Built-in Implementations:**

- **ReActAgent**: Implements Thought-Action-Observation reasoning loop
  - Iteratively reasons about problems
  - Decides when to use tools vs. provide final answer
  - Parses natural language tool calls
  - Configurable max iterations and error handling

- **PlanAndExecuteAgent**: Separates planning from execution (NEW)
  - Three-phase execution: Plan → Execute → Replan
  - Structured `ExecutionPlan` with step tracking
  - Automatic replanning when steps fail
  - Best for complex multi-step tasks

```swift
let agent = PlanAndExecuteAgent.Builder()
    .tools([WebSearchTool(), CalculatorTool()])
    .instructions("You are a research assistant.")
    .inferenceProvider(provider)
    .maxReplanAttempts(2)
    .build()

let result = try await agent.run("Research and summarize recent AI developments")
```

- **ToolCallingAgent**: Uses native LLM tool calling (NEW)
  - Uses structured `InferenceProvider.generateWithToolCalls()`
  - More reliable than text-based tool parsing
  - Best when your LLM supports native function calling

```swift
let agent = ToolCallingAgent.Builder()
    .tools([WeatherTool()])
    .instructions("You are a helpful assistant.")
    .inferenceProvider(provider)
    .build()
```

**Agent Configuration:**

```swift
let config = AgentConfiguration.default
    .maxIterations(10)
    .temperature(0.7)
    .maxTokens(2000)
    .stopOnToolError(false)
```

**Agent Results:**

```swift
struct AgentResult {
    let output: String              // Final answer
    let toolCalls: [ToolCall]       // Tools invoked
    let toolResults: [ToolResult]   // Tool outputs
    let metadata: [String: SendableValue]
    let duration: Duration          // Execution time
    let iterations: Int             // Number of reasoning loops
}
```

**Agent Events (Streaming):**

```swift
enum AgentEvent {
    case started(input: String)
    case thinking(thought: String)
    case toolCalling(toolCall: ToolCall)
    case toolResult(result: ToolResult)
    case chunk(text: String)
    case completed(result: AgentResult)
    case failed(error: AgentError)
}
```

### 2. Session Management

The `Session` protocol provides automatic conversation history management:

```swift
public protocol Session: Actor, Sendable {
    var sessionId: String { get }
    var itemCount: Int { get async }
    var isEmpty: Bool { get async }

    func getItems(limit: Int?) async throws -> [MemoryMessage]
    func addItems(_ items: [MemoryMessage]) async throws
    func popItem() async throws -> MemoryMessage?
    func clearSession() async throws
}
```

**Built-in Implementations:**

| Session Type | Description | Platforms | Use Case |
|-------------|-------------|-----------|----------|
| `InMemorySession` | Fast in-memory storage | All | Testing, temporary conversations |
| `PersistentSession` | SwiftData-backed persistence | Apple only | Production apps, cross-session history |

**Session vs Memory:**

Sessions and Memory serve complementary purposes:
- **Session**: Persists conversation history across agent runs (storage layer)
- **Memory**: Provides AI-optimized context from history (intelligence layer)

```swift
// Session: Long-term storage
let session = InMemorySession(sessionId: "chat_123")
try await agent.run("Hello", session: session)

// Memory: AI context generation
let memory = ConversationMemory(maxTokens: 4000)
let context = await memory.context(for: query, tokenLimit: 2000)
```

**InMemorySession Example:**

```swift
let session = InMemorySession(sessionId: "user_123")

// Add messages
try await session.addItem(.user("What's 2+2?"))
try await session.addItem(.assistant("4"))

// Retrieve history
let recent = try await session.getItems(limit: 10)
let all = try await session.getAllItems()

// Session state
print(await session.itemCount)  // 2
print(await session.isEmpty)    // false
```

**PersistentSession Example (Apple Platforms):**

```swift
#if canImport(SwiftData)
// Disk storage (survives app restarts)
let session = try PersistentSession.persistent(sessionId: "user_456")

// In-memory storage (for testing)
let testSession = try PersistentSession.inMemory(sessionId: "test")

// Multiple sessions with shared backend
let backend = try SwiftDataBackend.persistent()
let session1 = PersistentSession(sessionId: "chat_1", backend: backend)
let session2 = PersistentSession(sessionId: "chat_2", backend: backend)
#endif
```

### 3. Memory Systems

All memory implementations conform to the `Memory` protocol (actor-based for thread safety):

> **Note**: The protocol was renamed from `AgentMemory` to `Memory`. A deprecated typealias is provided for backward compatibility.

```swift
public protocol Memory: Actor, Sendable {
    func add(_ message: MemoryMessage) async
    func context(for query: String, tokenLimit: Int) async -> String  // Was: getContext
    func allMessages() async -> [MemoryMessage]  // Was: getAllMessages
    func clear() async
    var count: Int { get async }
}

// Deprecated typealias for backward compatibility
@available(*, deprecated, renamed: "Memory")
public typealias AgentMemory = Memory
```

**Available Memory Systems:**

| Memory Type | Description | Platforms | Use Case |
|-------------|-------------|-----------|----------|
| `ConversationMemory` | Simple FIFO with token limit | All | Basic chat applications |
| `SlidingWindowMemory` | Fixed-size window (last N messages) | All | Bounded memory requirements |
| `SummaryMemory` | Automatic summarization of old messages | All | Long conversations |
| `HybridMemory` | Combines conversation + summary | All | Best of both: recency + history |
| `PersistentMemory` | Pluggable backend architecture | All | Custom storage backends |
| `InMemoryBackend` | Ephemeral in-memory storage | All | Testing, temporary storage |
| `SwiftDataBackend` | SwiftData-backed persistence | Apple only | Cross-session persistence on Apple platforms |

**Message Types:**

```swift
enum MemoryMessage {
    case user(String)
    case assistant(String)
    case system(String)
    case tool(name: String, result: String)
}
```

### 4. Distributed Tracing (TraceContext)

`TraceContext` provides distributed tracing with task-local propagation:

```swift
public actor TraceContext: Sendable {
    static var current: TraceContext? { get }

    let name: String
    let traceId: UUID
    let groupId: String?
    let metadata: [String: SendableValue]
    let startTime: Date
    var duration: TimeInterval { get }

    static func withTrace<T: Sendable>(
        _ name: String,
        groupId: String? = nil,
        metadata: [String: SendableValue] = [:],
        operation: @Sendable () async throws -> T
    ) async rethrows -> T

    func startSpan(_ name: String, metadata: [String: SendableValue] = [:]) -> TraceSpan
    func endSpan(_ span: TraceSpan, status: SpanStatus = .ok)
    func getSpans() -> [TraceSpan]
}
```

**TraceSpan Structure:**

```swift
public struct TraceSpan: Sendable, Identifiable {
    let id: UUID
    let parentSpanId: UUID?
    let name: String
    let startTime: Date
    var endTime: Date?
    var status: SpanStatus  // .active, .ok, .error, .cancelled
    let metadata: [String: SendableValue]
    var duration: TimeInterval? { get }

    func completed(status: SpanStatus = .ok) -> TraceSpan
}
```

**Key Features:**

- **Task-Local Storage**: Context automatically propagates through async calls
- **Hierarchical Spans**: Parent-child relationships track operation trees
- **Automatic Timing**: Start/end times recorded automatically
- **Metadata Support**: Attach custom key-value data to traces and spans
- **Group Linking**: Group related traces with `groupId`

**Usage Pattern:**

```swift
// Create trace context
await TraceContext.withTrace("agent-workflow", groupId: "session_123") {
    // Access current context anywhere in the async call tree
    guard let context = TraceContext.current else { return }

    // Start operation span
    let span = await context.startSpan("tool-execution")

    // ... perform operation ...

    // End span with status
    await context.endSpan(span, status: .ok)

    // Retrieve all collected spans
    let allSpans = await context.getSpans()
    for span in allSpans {
        print("\(span.name): \(span.duration ?? 0)s")
    }
}
```

**Integration with Agents:**

```swift
// Traces work seamlessly with agent execution
await TraceContext.withTrace("customer-support") {
    let result1 = try await agent.run("First question")
    let result2 = try await agent.run("Follow-up question")

    // Both runs are traced in the same context
    if let context = TraceContext.current {
        print("Total trace duration: \(await context.duration)")
        print("Spans collected: \(await context.getSpans().count)")
    }
}
```

### 5. Tools

Tools give agents capabilities beyond text generation:

```swift
public protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameters: [ToolParameter] { get }

    func execute(arguments: [String: SendableValue]) async throws -> SendableValue
}
```

**Parameter Types:**

```swift
enum ParameterType {
    case string
    case int
    case double
    case bool
    case array(elementType: ParameterType)
    case object(properties: [ToolParameter])
    case oneOf([String])
    case any
}
```

**Built-in Tools:**

- `DateTimeTool`: Current date/time information
- More built-in tools coming in future releases

**Tool Registry:**

```swift
let registry = ToolRegistry(tools: [tool1, tool2])
await registry.register(tool3)

let result = try await registry.execute(
    toolNamed: "calculator",
    arguments: ["expression": .string("2+2")]
)
```

### 6. Multi-Agent Orchestration

Coordinate multiple agents for complex workflows:

**SupervisorAgent (Intelligent Routing):**

```swift
let supervisor = SupervisorAgent(
    agents: [
        (name: "agent1", agent: agent1, description: desc1),
        (name: "agent2", agent: agent2, description: desc2)
    ],
    routingStrategy: LLMRoutingStrategy(inferenceProvider: provider)
)
```

**Routing Strategies:**

- `LLMRoutingStrategy`: Uses LLM to analyze input and select best agent
- `KeywordRoutingStrategy`: Fast keyword-based matching (no LLM required)

**SequentialChain (Pipeline):**

```swift
let chain = SequentialChain(agents: [
    researchAgent,    // Gathers information
    analysisAgent,    // Analyzes findings
    summaryAgent      // Creates final report
])

let result = try await chain.run("Research Swift concurrency")
```

**ParallelGroup (Concurrent Execution):**

```swift
let group = ParallelGroup(agents: [
    weatherAgent,
    newsAgent,
    stockAgent
])

let results = try await group.run("Get me updates")
// All agents execute concurrently
```

**AgentContext (Shared State):**

```swift
let context = AgentContext(input: "User query")
await context.set(key: "location", value: .string("San Francisco"))

// Agents can access and modify shared context
let location = await context.get(key: "location")
```

### 7. Observability

Monitor agent execution with built-in tracing:

```swift
// Console tracing
let consoleTracer = ConsoleTracer(minLevel: .info)
agent.configuration.tracer = consoleTracer

// OSLog integration
let osLogTracer = OSLogTracer(subsystem: "com.myapp", category: "agents")
agent.configuration.tracer = osLogTracer

// Composite (multiple outputs)
let compositeTracer = CompositeTracer(tracers: [consoleTracer, osLogTracer])

// Buffered (batched for performance)
let bufferedTracer = BufferedTracer(
    wrapping: consoleTracer,
    bufferSize: 100
)

// Metrics collection
let metrics = MetricsCollector()
agent.configuration.metricsCollector = metrics

await metrics.recordExecution(
    agentName: "my_agent",
    duration: result.duration,
    success: true
)

let stats = await metrics.getStats(for: "my_agent")
print("Average duration: \(stats.averageDuration)")
print("Success rate: \(stats.successRate)")
```

**Trace Events:**

```swift
enum TraceEvent {
    case trace(message: String)
    case debug(message: String)
    case info(message: String)
    case warning(message: String)
    case error(message: String, error: Error?)
}
```

### 8. Resilience

Build robust agents with failure handling:

**Circuit Breaker:**

```swift
let breaker = CircuitBreaker(
    name: "llm_service",
    failureThreshold: 5,
    timeout: .seconds(30),
    resetTimeout: .seconds(60)
)

let result = try await breaker.execute {
    try await agent.run(input)
}

// Check state
let state = await breaker.state
switch state {
case .closed: print("Operating normally")
case .open: print("Circuit is open, failing fast")
case .halfOpen: print("Testing if service recovered")
}
```

**Retry Policy:**

```swift
let policy = RetryPolicy(
    maxAttempts: 3,
    initialDelay: .milliseconds(100),
    maxDelay: .seconds(5),
    backoffMultiplier: 2.0
)

let result = try await policy.execute {
    try await agent.run(input)
}
```

**Fallback Chain:**

```swift
let fallback = FallbackChain(
    primary: primaryAgent,
    fallbacks: [backupAgent1, backupAgent2, simpleAgent]
)

let result = try await fallback.run(input)
// Tries agents in order until one succeeds
```

---

## API Design Principles

SwiftAgents follows these design principles:

1. **Protocol-First**: Behavior contracts defined before implementations
2. **Actor Safety**: All mutable state protected by actors (Swift 6.2 strict concurrency)
3. **Sendable Types**: All public types are `Sendable` for safe concurrent access
4. **Fluent Builders**: Chainable configuration with `@discardableResult`
5. **Progressive Disclosure**: Simple defaults, advanced options available
6. **Value Semantics**: Prefer `struct` over `class` where possible
7. **Async/Await**: Structured concurrency throughout, no callbacks
8. **Type Safety**: Strong typing with `SendableValue` for dynamic values

---

## Testing

### Foundation Models Limitation

Foundation Models are unavailable in iOS/macOS simulators. For testing, use mock implementations:

```swift
import SwiftAgents

struct MockInferenceProvider: InferenceProvider {
    func generate(prompt: String, options: InferenceOptions) async throws -> String {
        return "Mock response for: \(prompt)"
    }

    func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield("Mock ")
            continuation.yield("streaming ")
            continuation.yield("response")
            continuation.finish()
        }
    }

    func generateWithToolCalls(
        prompt: String,
        tools: [ToolDefinition],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        return InferenceResponse(
            content: "Mock tool response",
            toolCalls: [],
            finishReason: .completed
        )
    }
}

// Use in tests
let agent = ReActAgent.Builder()
    .inferenceProvider(MockInferenceProvider())
    .build()

let result = try await agent.run("test input")
```

### Test Example

```swift
import XCTest
@testable import SwiftAgents

final class AgentTests: XCTestCase {
    func testAgentExecution() async throws {
        let mockProvider = MockInferenceProvider()
        let agent = ReActAgent.Builder()
            .inferenceProvider(mockProvider)
            .instructions("You are a test agent")
            .build()

        let result = try await agent.run("Hello")

        XCTAssertFalse(result.output.isEmpty)
        XCTAssertGreaterThan(result.duration, .zero)
    }

    func testAgentWithMemory() async throws {
        let memory = ConversationMemory(maxTokens: 1000)
        let agent = ReActAgent.Builder()
            .inferenceProvider(MockInferenceProvider())
            .memory(memory)
            .build()

        _ = try await agent.run("My name is Alice")

        let messages = await memory.allMessages()
        XCTAssertEqual(messages.count, 2) // User + Assistant
    }
}
```

---

## Examples

| Example | Description | Location |
|---------|-------------|----------|
| BasicAgent | Minimal agent setup and execution | `Examples/BasicAgent/` |
| ToolIntegration | Custom tool development | `Examples/ToolIntegration/` |
| MemorySystems | Different memory implementations | `Examples/MemorySystems/` |
| MultiAgentWorkflow | Supervisor-worker orchestration | `Examples/MultiAgentWorkflow/` |
| ChatApp | Complete SwiftUI chat application | `Examples/ChatApp/` |
| StreamingResponses | Real-time streaming with UI updates | `Examples/StreamingResponses/` |

---

## Advanced Topics

### Custom InferenceProvider

Integrate with any LLM backend:

```swift
import SwiftAgents

struct CustomLLMProvider: InferenceProvider {
    private let apiClient: MyAPIClient

    func generate(prompt: String, options: InferenceOptions) async throws -> String {
        let response = try await apiClient.complete(
            prompt: prompt,
            temperature: options.temperature,
            maxTokens: options.maxTokens
        )
        return response.text
    }

    func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in apiClient.streamComplete(prompt: prompt) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func generateWithToolCalls(
        prompt: String,
        tools: [ToolDefinition],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        let response = try await apiClient.completeWithTools(
            prompt: prompt,
            tools: tools.map { convertToAPIFormat($0) }
        )

        return InferenceResponse(
            content: response.text,
            toolCalls: response.toolCalls.map { parseToolCall($0) },
            finishReason: parseFinishReason(response.stopReason)
        )
    }
}
```

### Custom Memory Implementation

Create specialized memory strategies:

```swift
import SwiftAgents

public actor VectorMemory: Memory {
    private var messages: [MemoryMessage] = []
    private let vectorStore: VectorStore
    private let embedder: Embedder

    public init(vectorStore: VectorStore, embedder: Embedder) {
        self.vectorStore = vectorStore
        self.embedder = embedder
    }

    public func add(_ message: MemoryMessage) async {
        messages.append(message)

        // Generate embedding and store
        let embedding = await embedder.embed(message.content)
        await vectorStore.store(
            id: message.id,
            embedding: embedding,
            metadata: ["role": message.role]
        )
    }

    public func context(for query: String, tokenLimit: Int) async -> String {
        // Semantic search for relevant messages
        let queryEmbedding = await embedder.embed(query)
        let results = await vectorStore.search(
            embedding: queryEmbedding,
            limit: 10
        )

        // Retrieve and format relevant messages
        let relevantMessages = results.compactMap { result in
            messages.first { $0.id == result.id }
        }

        return formatMessagesForContext(
            relevantMessages,
            tokenLimit: tokenLimit
        )
    }

    public func allMessages() async -> [MemoryMessage] {
        messages
    }

    public func clear() async {
        messages.removeAll()
        await vectorStore.clear()
    }

    public var count: Int {
        messages.count
    }
}
```

### Error Handling

SwiftAgents provides comprehensive error types:

```swift
enum AgentError: Error {
    case invalidInput(reason: String)
    case toolNotFound(name: String)
    case toolExecutionFailed(toolName: String, underlyingError: String)
    case invalidToolArguments(toolName: String, reason: String)
    case maxIterationsExceeded(iterations: Int)
    case generationFailed(reason: String)
    case inferenceProviderUnavailable(reason: String)
    case cancelled
    case internalError(reason: String)
}

// Usage
do {
    let result = try await agent.run(input)
} catch AgentError.toolNotFound(let name) {
    print("Tool '\(name)' not found")
} catch AgentError.maxIterationsExceeded(let iterations) {
    print("Agent exceeded max iterations: \(iterations)")
} catch {
    print("Unexpected error: \(error)")
}
```

---

## Performance Considerations

- **Memory**: Use `SlidingWindowMemory` for bounded memory usage
- **Concurrency**: Leverage `ParallelGroup` for independent agent tasks
- **Streaming**: Use `stream()` for real-time UI updates
- **Circuit Breakers**: Prevent cascading failures in distributed systems
- **Tracing**: Use `BufferedTracer` in production to reduce overhead
- **Actor Isolation**: All agents and memory are actors—calls are async by design

---

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes following Swift 6.2 concurrency guidelines
4. Add tests for new functionality
5. Run test suite: `swift test`
6. Run formatter: `swift package plugin --allow-writing-to-package-directory swiftformat`
7. Commit changes: `git commit -m 'Add amazing feature'`
8. Push to branch: `git push origin feature/amazing-feature`
9. Open a Pull Request

### Code Standards

- All public APIs must have documentation comments
- All public types must conform to `Sendable`
- Use actors for mutable shared state
- Prefer `async/await` over callbacks
- Follow SwiftAgents naming conventions
- Add tests for new features

---

## Roadmap

- [x] Additional agent patterns (PlanAndExecuteAgent, ToolCallingAgent) ✅
- [x] @Agent macro builder generation ✅
- [x] Swift-style API naming (Memory protocol, method renames) ✅
- [x] Session management for conversation history ✅
- [x] TraceContext for distributed tracing ✅
- [x] Enhanced agent handoffs with callbacks ✅ NEW
- [x] MultiProvider for model routing ✅ NEW
- [ ] Vector memory with embedding support
- [ ] More built-in tools (web search, file system, etc.)
- [ ] SwiftData schema versioning for memory persistence
- [ ] Agent collaboration protocols
- [ ] Multi-modal support (images, audio)
- [ ] Fine-tuning integration for specialized agents
- [ ] Performance benchmarking suite

---

## License

SwiftAgents is released under the MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgments

- Inspired by [LangChain](https://langchain.com) and [AutoGPT](https://autogpt.net)
- Built for Apple's [Foundation Models](https://developer.apple.com/machine-learning/foundation-models/) and SwiftAI for LLM inferencee
- Part of the SwiftAI ecosystem
- Developed with Swift 6.2's strict concurrency model

---

## Support

- **Documentation**: [Full documentation](https://chriskarani.github.io/SwiftAgents/)
- **Issues**: [GitHub Issues](https://github.com/chriskarani/SwiftAgents/issues)
- **Discussions**: [GitHub Discussions](https://github.com/chriskarani/SwiftAgents/discussions)
- **Twitter**: [@ckarani7]([https://twitter.com/chriskarani](https://x.com/ckarani7))

---

Built with ❤️ for Apple platforms using Swift 6.2
