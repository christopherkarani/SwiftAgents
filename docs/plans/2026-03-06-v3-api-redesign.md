# V3 API Redesign — One Path, Maximum Clarity

**Date**: 2026-03-06
**Status**: Design approved, pending implementation
**Goal**: AI coding agent score from 64/100 to 95/100
**Target**: ~40-50 public types (down from 181 current)
**Breaking**: Yes — semver-major bump

---

## Philosophy

1. **One obvious path per operation** — if an AI agent has to choose between two ways, we failed
2. **Inline-first** — `Agent(...)` is THE way, `@Agent` macro is optional sugar
3. **Progressive disclosure** — simple things are simple, complex things are modifiers
4. **Apple-native** — follow Foundation Models patterns where possible
5. **Struct-first** — value types unless actor isolation is required

---

## Part 1: Agent

### Creation — ONE init

```swift
public struct Agent: Sendable {
    public init(
        _ instructions: String,
        guardrails: [Guardrail] = [],
        @ToolBuilder tools: () -> [any Tool] = { [] }
    )
}
```

- `instructions` is unlabeled first parameter — every agent starts with what it IS
- `tools` is a `@ToolBuilder` trailing closure — list tools without brackets or commas
- `guardrails` is the only other init parameter — rarely used, has a default
- Everything else is a modifier

### Modifiers — return new Agent (value semantics)

```swift
extension Agent {
    func provider(_ provider: some InferenceProvider) -> Agent
    func memory(_ memory: MemoryOption) -> Agent
    func named(_ name: String) -> Agent
    func observed(by observer: some AgentObserver) -> Agent
    func traced(by tracer: some Tracer) -> Agent
}
```

### Execution — run() and stream()

```swift
extension Agent {
    func run(_ input: String, options: RunOptions = .default) async throws -> AgentResult
    func stream(_ input: String, options: RunOptions = .default) -> AsyncThrowingStream<AgentEvent, Error>
}
```

### RunOptions — execution-time tuning

```swift
public struct RunOptions: Sendable {
    public static let `default` = RunOptions()
    public static let creative = RunOptions(temperature: 1.5)
    public static let precise = RunOptions(temperature: 0.2)
    public static let fast = RunOptions(timeout: .seconds(15), maxIterations: 3)

    public var maxIterations: Int = 10
    public var timeout: Duration = .seconds(60)
    public var temperature: Double? = nil
    public var maxTokens: Int? = nil
    public var parallelToolCalls: Bool = false
    public var stopOnToolError: Bool = false
}
```

### Examples — progressive complexity

```swift
// Level 0: Chat bot
let agent = Agent("You are a helpful assistant.")
let result = try await agent.run("Hello")

// Level 1: With tools
let agent = Agent("You are a math tutor.") {
    Calculator()
    UnitConverter()
}

// Level 2: With configuration
let agent = Agent("You are a math tutor.") {
    Calculator()
    WeatherTool()
}
.provider(.anthropic(key: "sk-..."))
.memory(.conversation(limit: 50))

// Level 3: Multi-agent with handoffs
let agent = Agent("You route support requests.") {
    TriageTool()
    Handoff(billingAgent)
    Handoff(techAgent, history: .summarized())
}
.named("Router")
.observed(by: LoggingObserver())

// Level 4: Execution tuning
let result = try await agent.run("Write a poem", options: .creative)
let result = try await agent.run("Solve this", options: RunOptions(maxIterations: 20, timeout: .seconds(120)))
```

---

## Part 2: Tools

### Design: Apple Foundation Models-inspired, simplified

Apple FM uses `Tool` protocol + nested `@Generable Arguments` struct + `@Guide` annotations.
Swarm simplifies: `Tool` protocol + `@Parameter` directly on struct properties + `call()` with no arguments.

### Tool Protocol

```swift
public protocol Tool: Sendable {
    static var name: String { get }
    static var description: String { get }
    var parameters: [ToolParameter] { get }  // auto-derived by @Tool macro
    func call() async throws -> String
}
```

### @Tool Macro — primary path for reusable tools

```swift
@Tool("Calculates math expressions")
struct Calculator {
    @Parameter("The math expression to evaluate")
    var expression: String

    func call() async throws -> String {
        "\(evaluate(expression))"
    }
}

@Tool("Gets current weather for a city")
struct WeatherTool {
    @Parameter("The city name")
    var city: String

    @Parameter("Temperature units", default: "celsius")
    var units: String

    func call() async throws -> String {
        "72F in \(city)"
    }
}
```

- `@Parameter` properties are populated by the framework before `call()` runs
- `call()` takes no arguments — properties ARE the arguments
- Schema is derived automatically from `@Parameter` annotations
- No nested `Arguments` struct (Apple's `@Generable` pattern eliminated)

### Inline tools — closure shorthand for one-offs

```swift
let greet = Tool("greet", "Greets a user") { (name: String) in
    "Hello, \(name)!"
}
```

For inline tools, parameter names and types are extracted from the closure signature.

### ToolBuilder — result builder for agent's tool list

```swift
@resultBuilder
public struct ToolBuilder {
    static func buildBlock(_ tools: any Tool...) -> [any Tool]
    static func buildOptional(_ tool: (any Tool)?) -> [any Tool]
    static func buildEither(first: any Tool) -> [any Tool]
    static func buildEither(second: any Tool) -> [any Tool]
    static func buildArray(_ tools: [[any Tool]]) -> [any Tool]
}
```

Enables:
```swift
Agent("...") {
    Calculator()
    WeatherTool()
    if useSearch {
        WebSearchTool()
    }
}
```

### What gets removed

| Removed | Replacement |
|---------|-------------|
| `AnyJSONTool` protocol | `Tool` protocol (one protocol, not two) |
| `AnyTool` type-eraser | `any Tool` existential |
| `FunctionTool` struct | Inline `Tool("name", "desc") { closure }` |
| `AgentTool` | `Handoff(agent)` in ToolBuilder |
| `ToolParameter.ParameterType` complex enum | Simplified — derived from Swift types |
| `ToolParameterBuilder` result builder | `@Parameter` macro handles schema |

---

## Part 3: Providers

### `InferenceProvider` protocol stays

```swift
public protocol InferenceProvider: Sendable {
    func generate(prompt: String, options: InferenceOptions) async throws -> String
    func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error>
    func generateWithToolCalls(prompt: String, tools: [ToolSchema], options: InferenceOptions) async throws -> InferenceResponse
}
```

### Static factories with dot-syntax

```swift
extension InferenceProvider where Self == LLM {
    public static func anthropic(key: String, model: String = "claude-sonnet-4-6") -> LLM
    public static func openAI(key: String, model: String = "gpt-4o-mini") -> LLM
    public static func ollama(_ model: String, settings: OllamaSettings = .default) -> LLM
    public static func openRouter(key: String, model: String) -> LLM
}
```

### Usage

```swift
// Per-agent
let agent = Agent("...").provider(.anthropic(key: "sk-..."))

// Global default
Swarm.configure(provider: .anthropic(key: "sk-..."))

// On-device (Apple platforms) — automatic, no config needed
let agent = Agent("...")  // uses Foundation Models
```

### MultiProvider stays for prefix routing

```swift
let multi = MultiProvider(default: .anthropic(key: "..."))
try await multi.register(prefix: "openai", provider: .openAI(key: "..."))
```

---

## Part 4: Memory

### MemoryOption enum — replaces `(any Memory)?`

```swift
public enum MemoryOption: Sendable {
    case none
    case conversation(limit: Int = 100)
    case slidingWindow(maxTokens: Int = 4000)
    case summary(recentMessages: Int = 20, summaryTokens: Int = 500)
    case hybrid(shortTermMessages: Int = 30, summaryTokens: Int = 1000)
    case vector(provider: any EmbeddingProvider, threshold: Float = 0.7, maxResults: Int = 10)
    case persistent(backend: any PersistentMemoryBackend, conversationId: String = "default")
    case custom(any Memory)
}
```

### Usage

```swift
let agent = Agent("...")
    .memory(.conversation(limit: 50))

let agent = Agent("...")
    .memory(.vector(provider: waxProvider, threshold: 0.8))

let agent = Agent("...")
    .memory(.hybrid())  // sensible defaults
```

### Memory protocol stays for custom implementations

```swift
public protocol Memory: Actor, Sendable {
    var count: Int { get async }
    var isEmpty: Bool { get async }
    func add(_ message: MemoryMessage) async
    func context(for query: String, tokenLimit: Int) async -> String
    func allMessages() async -> [MemoryMessage]
    func clear() async
}
```

Custom memory → `.custom(myMemoryActor)`

### What gets removed

| Removed | Replacement |
|---------|-------------|
| `AnyMemory` type-eraser | `any Memory` / `.custom()` |
| `CompositeMemory` + `@MemoryBuilder` | `.hybrid()` handles most cases; keep composite as internal |
| `MemoryComponent`, `MemoryPriority`, `RetrievalStrategy`, `MemoryMergeStrategy` | Internal implementation details |
| `VectorMemoryConfigurable` protocol | Absorbed into `MemoryOption.vector()` params |

---

## Part 5: Guardrails

### Unified `Guardrail` enum

```swift
public enum Guardrail: Sendable {
    // Input guardrails
    case maxInput(Int)
    case inputNotEmpty
    case inputCustom(String, @Sendable (String) async throws -> Bool)

    // Output guardrails
    case maxOutput(Int)
    case outputCustom(String, @Sendable (String) async throws -> Bool)

    // Tool guardrails
    case toolInputCustom(String, @Sendable (String, [String: SendableValue]) async throws -> Bool)
    case toolOutputCustom(String, @Sendable (String, SendableValue) async throws -> Bool)
}
```

### Usage

```swift
let agent = Agent("...", guardrails: [.maxInput(500), .maxOutput(5000), .inputNotEmpty])
```

### What gets removed

| Removed | Replacement |
|---------|-------------|
| `InputGuardrail` protocol | `Guardrail` enum cases |
| `OutputGuardrail` protocol | `Guardrail` enum cases |
| `ClosureInputGuardrail` struct | `.inputCustom()` |
| `ClosureOutputGuardrail` struct | `.outputCustom()` |
| `InputGuard` struct | `.inputCustom()` |
| `OutputGuard` struct | `.outputCustom()` |
| `InputGuardrailBuilder` | Removed |
| `OutputGuardrailBuilder` | Removed |
| `ToolInputGuardrail` protocol | `Guardrail` enum cases |
| `ToolOutputGuardrail` protocol | `Guardrail` enum cases |
| `ClosureToolInputGuardrail` | `.toolInputCustom()` |
| `ClosureToolOutputGuardrail` | `.toolOutputCustom()` |
| `ToolInputGuardrailBuilder` | Removed |
| `ToolOutputGuardrailBuilder` | Removed |
| `ToolGuardrailData` struct | Internal |
| `GuardrailRunnerConfiguration` | Internal |
| `GuardrailRunner` actor | Internal |
| `Guardrail` protocol (old) | Replaced by enum |

**Net: 18 types → 1 enum**

---

## Part 6: Handoffs

### Handoffs live inside @ToolBuilder

```swift
let agent = Agent("Route customers to the right agent.") {
    TriageTool()
    Handoff(billingAgent)
    Handoff(techAgent, history: .summarized(maxTokens: 600))
    Handoff(salesAgent, when: { context in context.contains("pricing") })
}
```

### Handoff struct

```swift
public struct Handoff: Tool {
    public init(
        _ target: Agent,
        name: String? = nil,
        description: String? = nil,
        history: HandoffHistory = .none
    )

    public init(
        _ target: Agent,
        history: HandoffHistory = .none,
        when: @escaping @Sendable (String) async -> Bool
    )
}

public enum HandoffHistory: Sendable {
    case none
    case nested
    case summarized(maxTokens: Int = 600)
}
```

### What gets removed

| Removed | Replacement |
|---------|-------------|
| `HandoffBuilder<Target>` | `Handoff()` struct in ToolBuilder |
| `HandoffConfiguration<Target>` | Internal |
| `AnyHandoffConfiguration` | Internal |
| `HandoffCoordinator` actor | Internal |
| `HandoffOptions<Target>` | `Handoff()` init params |
| `HandoffPolicy` enum | Simplified into Handoff init |
| `HandoffMetadataKey<V>` | Internal |
| `HandoffInputData` | Internal |
| `HandoffRequest` | Internal |
| `HandoffResult` | Internal — exposed via `AgentResult.metadata` |
| `HandoffReceiver` protocol | Internal |

**Net: 11 types → 2 public (Handoff struct + HandoffHistory enum)**

---

## Part 7: Conversation

### Actor wrapping multi-turn state

```swift
public actor Conversation {
    public struct Message: Sendable, Identifiable {
        public let id: UUID
        public let role: Role
        public let text: String
        public enum Role: Sendable { case user, assistant }
    }

    public var messages: [Message] { get }
    public var isThinking: Bool { get }

    public init(with agent: Agent)
    public func send(_ input: String) async throws -> AgentResult
    public func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error>
    public func clear() async
}
```

### Usage

```swift
let conversation = Conversation(with: agent)
let r1 = try await conversation.send("What is Swift?")
let r2 = try await conversation.send("Tell me more about concurrency")

// SwiftUI
ForEach(conversation.messages) { msg in Text(msg.text) }
```

---

## Part 8: Workflow

### Fluent orchestration stays — it's good

```swift
public struct Workflow: Sendable {
    public init(@WorkflowBuilder _ steps: () -> [WorkflowStep])

    public func parallel(_ agents: [Agent], merge: MergeStrategy = .structured) -> Workflow
    public func route(_ condition: @escaping @Sendable (String) -> Agent?) -> Workflow
    public func repeatUntil(maxIterations: Int = 100, _ condition: @escaping @Sendable (AgentResult) -> Bool) -> Workflow
    public func timeout(_ duration: Duration) -> Workflow
    public func observed(by observer: some AgentObserver) -> Workflow

    public func run(_ input: String) async throws -> AgentResult
    public func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error>
}
```

### Usage

```swift
let result = try await Workflow {
    Step(researchAgent)
    Step(writerAgent)
    Step(editorAgent)
}
.timeout(.seconds(120))
.run("Write about AI safety")
```

---

## Part 9: Observability

### AgentObserver protocol stays — clean design

```swift
public protocol AgentObserver: Sendable {
    func onAgentStart(agent: any AgentRuntime, input: String) async
    func onAgentEnd(agent: any AgentRuntime, result: AgentResult) async
    func onToolStart(agent: any AgentRuntime, call: ToolCall) async
    func onToolEnd(agent: any AgentRuntime, result: ToolResult) async
    func onError(agent: any AgentRuntime, error: Error) async
    // ... all with default no-op implementations
}
```

### Tracer protocol stays

```swift
public protocol Tracer: Actor, Sendable {
    func trace(_ event: TraceEvent) async
    func flush() async
}
```

### What gets removed

| Removed | Replacement |
|---------|-------------|
| `AnyTracer` | `any Tracer` |
| `AgentContext` parameter on all observer methods | Removed — internal detail |

---

## Part 10: AgentConfiguration — DELETED

The 18-field `AgentConfiguration` struct is eliminated entirely.

| Old Field | New Home |
|-----------|----------|
| `name` | `.named()` modifier |
| `maxIterations` | `RunOptions` |
| `timeout` | `RunOptions` |
| `temperature` | `RunOptions` |
| `maxTokens` | `RunOptions` |
| `stopSequences` | `RunOptions` |
| `modelSettings` | Killed — absorbed into RunOptions fields |
| `contextProfile` | Internal default (platform auto-selects) |
| `contextMode` | Killed — merged with contextProfile |
| `inferencePolicy` | Provider-level concern |
| `enableStreaming` | Killed — `.stream()` vs `.run()` IS the choice |
| `includeToolCallDetails` | Killed — always true |
| `stopOnToolError` | `RunOptions` |
| `includeReasoning` | Killed — always true |
| `sessionHistoryLimit` | `Conversation` concern |
| `parallelToolCalls` | `RunOptions` |
| `previousResponseId` | `Session` concern |
| `autoPreviousResponseId` | `Session` concern |
| `defaultTracingEnabled` | `.traced()` modifier |

---

## Part 11: What Gets Removed — Complete List

### Types removed (estimated ~130 types eliminated)

**Agent creation (26 types → 1 struct)**
- `AgentConfiguration` struct (18 fields)
- `ModelSettings` struct + `@Builder` chainable setters
- `ContextMode` enum
- `InferencePolicy` struct + nested enums
- `AgentBuilder` result builder + 13 `AgentComponent` types (Instructions, Tools, AgentMemory, Configuration, InferenceProviderComponent, TracerConfig, InputGuardrails, OutputGuardrails, Handoffs, ParallelToolCalls, PreviousResponseId, AutoPreviousResponseId, ModelSettingsComponent, MCPClientConfig)
- `Agent.Builder` fluent class
- 6 deprecated typealiases
- 7 of 8 Agent init overloads

**Tools (6 types → 1 protocol)**
- `AnyJSONTool` protocol
- `AnyTool` struct
- `FunctionTool` struct
- `AgentTool` struct
- `ToolArguments` struct
- `ToolArrayBuilder` result builder

**Guardrails (18 types → 1 enum)**
- See Part 5 table

**Handoffs (11 types → 2)**
- See Part 6 table

**Memory (7 types → 1 enum + protocol)**
- `AnyMemory`, `CompositeMemory`, `MemoryComponent`, `MemoryPriority`, `RetrievalStrategy`, `MemoryMergeStrategy`, `VectorMemoryConfigurable`

**Type erasers (5 types → 0)**
- `AnyAgent`, `AnyTool`, `AnyMemory`, `AnyTracer`, `AnyHandoffConfiguration`

**Observability (1 type)**
- `AnyTracer`

---

## Part 12: Final Public API Surface

### Core types (~15)

| Type | Kind | Purpose |
|------|------|---------|
| `Agent` | struct | The agent |
| `Tool` | protocol | Tool definition |
| `Workflow` | struct | Multi-agent orchestration |
| `Conversation` | actor | Stateful multi-turn chat |
| `AgentResult` | struct | Execution result |
| `AgentEvent` | enum | Stream events |
| `RunOptions` | struct | Execution-time tuning |
| `SendableValue` | enum | JSON-compatible value type |
| `TokenUsage` | struct | Token consumption |
| `ToolCall` | struct | Tool invocation record |
| `ToolResult` | struct | Tool execution result |
| `AgentError` | enum | Error cases |
| `MemoryMessage` | struct | Memory message |
| `ToolSchema` | struct | Tool schema for providers |
| `InferenceResponse` | struct | Provider response |

### Configuration types (~8)

| Type | Kind | Purpose |
|------|------|---------|
| `MemoryOption` | enum | Memory configuration |
| `Guardrail` | enum | Input/output validation |
| `Handoff` | struct | Agent-to-agent transfer |
| `HandoffHistory` | enum | Handoff history strategy |
| `MergeStrategy` | enum | Parallel result merging |
| `InferenceOptions` | struct | Provider-level options |
| `ToolParameter` | struct | Tool parameter definition |
| `ContextProfile` | struct | Context budget (rarely used) |

### Protocols (~7)

| Protocol | Purpose |
|----------|---------|
| `InferenceProvider` | LLM backend |
| `Memory` | Custom memory implementations |
| `AgentObserver` | Lifecycle hooks |
| `Tracer` | Observability |
| `Session` | Conversation history |
| `EmbeddingProvider` | Vector embeddings |
| `TokenEstimator` | Token counting |

### Concrete implementations (~12)

| Type | Kind | Purpose |
|------|------|---------|
| `LLM` | enum | Provider presets (anthropic/openai/ollama) |
| `MultiProvider` | actor | Prefix-based routing |
| `ConversationMemory` | actor | Rolling buffer memory |
| `VectorMemory` | actor | Semantic search memory |
| `SummaryMemory` | actor | LLM-compressed memory |
| `SlidingWindowMemory` | actor | Token-budget memory |
| `HybridMemory` | actor | Short-term + summary |
| `InMemorySession` | actor | Session implementation |
| `LoggingObserver` | struct | Log all events |
| `CompositeObserver` | struct | Fan-out to multiple observers |
| `ConsoleTracer` | actor | Console output |
| `SwiftLogTracer` | actor | swift-log bridge |

### Macros (~4)

| Macro | Purpose |
|-------|---------|
| `@Tool` | Generate Tool conformance |
| `@Parameter` | Annotate tool parameters |
| `@Agent` | Generate Agent (optional sugar) |
| `#Prompt` | Type-safe prompt strings |

### Estimated total: ~46 public types

Down from 181. A 75% reduction.

---

## What an AI Agent Needs to Know

The entire API fits in ~20 lines:

```
// Create
Agent("instructions") { tools }             // agent with tools
Agent("instructions")                        // agent without tools

// Configure
.provider(.anthropic(key:))                  // LLM backend
.memory(.conversation(limit:))              // memory system
.named("X")                                  // display name

// Execute
agent.run("input")                           // -> AgentResult
agent.stream("input")                        // -> AsyncThrowingStream<AgentEvent>
agent.run("input", options: .creative)       // with tuning

// Tools
@Tool("description") struct X {
    @Parameter("desc") var name: Type
    func call() async throws -> String
}

// Multi-agent
Workflow { Step(a); Step(b) }.run("input")   // sequential
Handoff(agent) in tool builder               // agent transfer
Conversation(with: agent).send("input")      // multi-turn
```

**That is the entire API.** Everything else is optional depth.
