# Swarm Framework — Complete Public API Catalog

> Generated from source exploration of the `finalPhase` branch.
> Authoritative design spec: `docs/reference/front-facing-api.md`
> Last updated: 2026-03-04

---

## Table of Contents

1. [Entry Point & Global Configuration](#1-entry-point--global-configuration)
2. [Core Runtime Protocols](#2-core-runtime-protocols)
3. [Primary Agent Type](#3-primary-agent-type)
4. [Conversation API](#4-conversation-api)
5. [Workflow API](#5-workflow-api)
6. [Handoff API](#6-handoff-api)
7. [Tooling API](#7-tooling-api)
8. [Guardrails API](#8-guardrails-api)
9. [Memory & Sessions](#9-memory--sessions)
10. [Observability](#10-observability)
11. [Resilience Primitives](#11-resilience-primitives)
12. [Inference & Model Controls](#12-inference--model-controls)
13. [Core Value / Event / Error Types](#13-core-value--event--error-types)
14. [Public Macros](#14-public-macros)
15. [Inference Providers](#15-inference-providers)
16. [MCP Integration](#16-mcp-integration)
17. [Hive Runtime Integration](#17-hive-runtime-integration)
18. [Context & Environment](#18-context--environment)
19. [Stream Operations](#19-stream-operations)
20. [Naming Guarantees & Design Invariants](#20-naming-guarantees--design-invariants)

---

## 1. Entry Point & Global Configuration

**File**: `Sources/Swarm/Swarm.swift`

```swift
import Swarm

public enum Swarm {
    public static let version: String
    public static let minimumMacOSVersion: String
    public static let minimumiOSVersion: String

    /// Set the default inference provider for all agents.
    public static func configure(provider: some InferenceProvider) async

    /// Set the cloud-only provider (used when a tool requires cloud inference).
    public static func configure(cloudProvider: some InferenceProvider) async

    /// Reset all global configuration to defaults.
    public static func reset() async

    public static var defaultProvider: (any InferenceProvider)? { get async }
    public static var cloudProvider: (any InferenceProvider)? { get async }
}
```

---

## 2. Core Runtime Protocols

**File**: `Sources/Swarm/Core/AgentRuntime.swift`

### `AgentRuntime`

THE central protocol. Every agent type conforms to this.

```swift
public protocol AgentRuntime: Sendable {
    var name: String { get }
    var tools: [any AnyJSONTool] { get }
    var instructions: String { get }
    var configuration: AgentConfiguration { get }
    var memory: (any Memory)? { get }
    var inferenceProvider: (any InferenceProvider)? { get }
    var tracer: (any Tracer)? { get }
    var handoffs: [AnyHandoffConfiguration] { get }
    var inputGuardrails: [any InputGuardrail] { get }
    var outputGuardrails: [any OutputGuardrail] { get }

    func run(
        _ input: String,
        session: (any Session)?,
        observer: (any AgentObserver)?
    ) async throws -> AgentResult

    nonisolated func stream(
        _ input: String,
        session: (any Session)?,
        observer: (any AgentObserver)?
    ) -> AsyncThrowingStream<AgentEvent, Error>

    func runWithResponse(
        _ input: String,
        session: (any Session)?,
        observer: (any AgentObserver)?
    ) async throws -> AgentResponse

    func cancel() async
}
```

**Convenience extensions on `AgentRuntime`**:

```swift
// Omit session/observer for simple single-turn usage
func run(_ input: String, observer: (any AgentObserver)? = nil) async throws -> AgentResult
func stream(_ input: String, observer: (any AgentObserver)? = nil) -> AsyncThrowingStream<AgentEvent, Error>
func runWithResponse(_ input: String, observer: (any AgentObserver)? = nil) async throws -> AgentResponse

// Wrap an agent with a permanently-attached observer
func observed(by observer: some AgentObserver) -> some AgentRuntime
```

### `InferenceProvider`

LLM backend abstraction. Conformed to by all provider types.

```swift
public protocol InferenceProvider: Sendable {
    func generate(
        messages: [InferenceMessage],
        tools: [ToolSchema],
        options: InferenceOptions
    ) async throws -> InferenceResponse
}

public protocol InferenceStreamingProvider: InferenceProvider {
    func stream(
        messages: [InferenceMessage],
        tools: [ToolSchema],
        options: InferenceOptions
    ) -> AsyncThrowingStream<InferenceStreamEvent, Error>
}

public protocol ToolCallStreamingInferenceProvider: InferenceStreamingProvider { ... }
```

### `AgentConfiguration`

```swift
public struct AgentConfiguration: Sendable {
    public var maxIterations: Int
    public var parallelToolCalls: Bool
    public var modelSettings: ModelSettings?
    public var runtimeMode: SwarmRuntimeMode

    public static let `default`: AgentConfiguration
}

public enum SwarmRuntimeMode: Sendable {
    case swarm       // Pure Swarm execution
    case hive        // HiveCore DAG execution
    case auto        // Resolved at runtime
}
```

---

## 3. Primary Agent Type

**File**: `Sources/Swarm/Agents/Agent.swift`

```swift
public actor Agent: AgentRuntime
```

### Initializers

```swift
// Fully explicit
public init(
    name: String = "Agent",
    tools: [any AnyJSONTool] = [],
    instructions: String = "",
    configuration: AgentConfiguration = .default,
    memory: (any Memory)? = nil,
    inferenceProvider: (any InferenceProvider)? = nil,
    tracer: (any Tracer)? = nil,
    inputGuardrails: [any InputGuardrail] = [],
    outputGuardrails: [any OutputGuardrail] = [],
    guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default,
    handoffs: [AnyHandoffConfiguration] = []
) throws

// Provider-first convenience
public init(
    _ inferenceProvider: any InferenceProvider,
    name: String = "Agent",
    tools: [any AnyJSONTool] = [],
    instructions: String = "",
    configuration: AgentConfiguration = .default,
    memory: (any Memory)? = nil,
    tracer: (any Tracer)? = nil,
    inputGuardrails: [any InputGuardrail] = [],
    outputGuardrails: [any OutputGuardrail] = [],
    guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default,
    handoffs: [AnyHandoffConfiguration] = []
) throws

// Handoff-agents convenience
public init(
    name: String,
    instructions: String = "",
    tools: [any AnyJSONTool] = [],
    configuration: AgentConfiguration = .default,
    memory: (any Memory)? = nil,
    inferenceProvider: (any InferenceProvider)? = nil,
    tracer: (any Tracer)? = nil,
    inputGuardrails: [any InputGuardrail] = [],
    outputGuardrails: [any OutputGuardrail] = [],
    guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default,
    handoffAgents: [any AgentRuntime]
) throws
```

### Fluent Builder

```swift
Agent.Builder()
    .name("MyAgent")
    .tools([MyTool(), AnotherTool()])
    .addTool(YetAnotherTool())
    .withBuiltInTools()              // adds DateTimeTool, StringTool, etc.
    .instructions("You are a...")
    .configuration(.default)
    .memory(ConversationMemory())
    .inferenceProvider(myProvider)
    .tracer(ConsoleTracer())
    .inputGuardrails([myInputGuardrail])
    .addInputGuardrail(myInputGuardrail)
    .outputGuardrails([myOutputGuardrail])
    .addOutputGuardrail(myOutputGuardrail)
    .guardrailRunnerConfiguration(.default)
    .handoffs([myHandoff])
    .addHandoff(myHandoff)
    .handoff(to: targetAgent) { options in
        options.name("escalate").description("Escalate to expert")
    }
    .handoffs(agentA, agentB, agentC)   // variadic convenience
    .build()                             // throws
```

### Declarative DSL (SwiftUI-style)

```swift
let agent = try Agent {
    Instructions("You are a helpful assistant.")
    Tools {
        CalculatorTool()
        WebSearchTool()
    }
    Memory(ConversationMemory(maxTokens: 4000))
    Configuration(.default)
    InferenceProviderComponent(myProvider)
}
```

**DSL component types**:

| Type | Purpose |
|------|---------|
| `Instructions` | Sets system prompt |
| `Tools` | Provides tools block |
| `AgentMemoryComponent` | Wraps a `Memory` instance |
| `Configuration` | Sets `AgentConfiguration` |
| `InferenceProviderComponent` | Sets inference provider |
| `TracerComponent` | Attaches a tracer |
| `InputGuardrailsComponent` | Adds input guardrails |
| `OutputGuardrailsComponent` | Adds output guardrails |
| `HandoffsComponent` | Adds handoff targets |
| `MCPClientComponent` | Attaches an MCP client |
| `ParallelToolCalls` | Enables/disables parallel execution |
| `ModelSettingsComponent` | Per-agent model settings |

### `AnyAgent`

Type-erased wrapper for heterogeneous agent collections:

```swift
public struct AnyAgent: AgentRuntime {
    public init(_ agent: some AgentRuntime)
}
```

---

## 4. Conversation API

**File**: `Sources/Swarm/Core/Conversation.swift`

High-level multi-turn conversation interface. Backed by a persistent `Session`.

```swift
public final class Conversation {
    public struct Message {
        public enum Role { case user, assistant }
        public let role: Role
        public let text: String
    }

    public init(with agent: some AgentRuntime, session: (any Session)? = nil)

    /// All messages exchanged so far.
    public var messages: [Message] { get }

    /// Send a message and wait for the agent's full response.
    @discardableResult
    public func send(_ input: String) async throws -> AgentResult

    /// Send a message and stream the response; returns final concatenated text.
    @discardableResult
    public func stream(_ input: String) async throws -> String
}
```

---

## 5. Workflow API

**File**: `Sources/Swarm/Workflow/Workflow.swift`

Fluent multi-agent pipeline composition. The single preferred coordination primitive.

```swift
public struct Workflow {
    public enum MergeStrategy {
        case structured                                          // JSON object keyed by agent name
        case first                                               // First result to complete
        case custom(@Sendable ([AgentResult]) -> String)         // User-defined merge
    }

    public init()

    // Composition
    public func step(_ agent: some AgentRuntime) -> Workflow
    public func parallel(_ agents: [any AgentRuntime], merge: MergeStrategy = .structured) -> Workflow
    public func route(_ condition: @escaping @Sendable (String) -> (any AgentRuntime)?) -> Workflow
    public func repeatUntil(
        maxIterations: Int = 100,
        _ condition: @escaping @Sendable (AgentResult) -> Bool
    ) -> Workflow
    public func timeout(_ duration: Duration) -> Workflow
    public func observed(by observer: some AgentObserver) -> Workflow

    // Execution
    public func run(_ input: String) async throws -> AgentResult
    public func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error>

    // Advanced features
    public var advanced: Advanced { get }
}

public extension Workflow {
    struct Advanced {
        public enum CheckpointPolicy { case endOnly, everyStep }

        public func checkpoint(id: String, policy: CheckpointPolicy = .endOnly) -> Workflow
        public func checkpointStore(_ checkpointing: WorkflowCheckpointing) -> Workflow
        public func fallback(
            primary: some AgentRuntime,
            to backup: some AgentRuntime,
            retries: Int = 0
        ) -> Workflow
        public func run(
            _ input: String,
            resumeFrom checkpointID: String? = nil
        ) async throws -> AgentResult
    }
}

public struct WorkflowCheckpointing: Sendable {
    public static func inMemory() -> WorkflowCheckpointing
    public static func fileSystem(directory: URL) -> WorkflowCheckpointing
}
```

---

## 6. Handoff API

**Files**: `Sources/Swarm/Core/Handoff/`

Handoffs are injected as special tool calls into the LLM's tool list. When selected, the current agent delegates to the target agent directly.

### Core Types

| Type | Kind | Purpose |
|------|------|---------|
| `HandoffInputData` | struct | Payload passed at handoff time (input text, metadata) |
| `HandoffConfiguration<Target: AgentRuntime>` | struct | Typed handoff config with callbacks |
| `AnyHandoffConfiguration` | struct | Type-erased handoff for storage |
| `HandoffOptions<Target>` | struct | Fluent options builder |
| `HandoffHistory` | enum | `.none` / `.full` / `.summary` |
| `HandoffPolicy` | enum | Routing/delegation policy |
| `HandoffMetadataKey<Value>` | struct | Typed metadata key |
| `HandoffRequest` | struct | Runtime handoff request |
| `HandoffResult` | struct | Result of a handoff execution |
| `HandoffReceiver` | protocol | Agents that explicitly handle incoming handoffs |
| `HandoffCoordinator` | actor | Orchestrates multi-agent handoff chains |

### Callback Typealiases

```swift
public typealias OnTransferCallback = @Sendable (HandoffInputData) async -> Void
public typealias TransformCallback  = @Sendable (String) async -> String
public typealias WhenCallback       = @Sendable (String) -> Bool
```

### `HandoffOptions` Fluent API

```swift
HandoffOptions<Target>()
    .name("escalate_to_expert")
    .description("Transfer to the domain expert agent")
    .onTransfer { data in ... }       // called before handoff
    .transform { input in ... }       // mutate the input string
    .when { input in ... }            // conditional availability
    .history(.full)
    .policy(.sequential)
```

### `HandoffBuilder`

```swift
HandoffBuilder(to: targetAgent)
    .toolName("handoff_to_expert")
    .toolDescription("Transfer control to the expert agent")
    .onTransfer { data in ... }
    .transform { input in ... }
    .when { input in ... }
    .history(.none)
    .build()                           // -> AnyHandoffConfiguration
```

### Convenience Factory Functions

```swift
// Free function
handoff(
    to: targetAgent,
    name: String? = nil,
    description: String? = nil,
    onTransfer: OnTransferCallback? = nil,
    transform: TransformCallback? = nil,
    when: WhenCallback? = nil,
    history: HandoffHistory = .none
) -> AnyHandoffConfiguration

// Extensions on AgentRuntime
agent.asHandoff() -> AnyHandoffConfiguration
agent.asHandoff { options in ... } -> AnyHandoffConfiguration
```

---

## 7. Tooling API

**Files**: `Sources/Swarm/Tools/`

### Protocols

```swift
public protocol AnyJSONTool: Sendable {
    var name: String { get }
    var description: String { get }
    var schema: ToolSchema { get }
    func execute(arguments: SendableValue) async throws -> SendableValue
}

public protocol Tool: AnyJSONTool {
    associatedtype Arguments: Decodable & Sendable
    func execute(arguments: Arguments) async throws -> String
}
```

### Supporting Types

| Type | Kind | Purpose |
|------|------|---------|
| `ToolSchema` | struct | JSON Schema descriptor derived from `@Tool` |
| `ToolParameter` | struct | Individual parameter descriptor |
| `ToolArguments` | struct | Parsed, validated tool call arguments |
| `FunctionTool` | struct | Closure-based tool (no struct required) |
| `ToolRegistry` | actor | Mutable registry of tools; lookup by name |
| `ToolRegistryError` | enum | `toolNotFound`, `duplicateTool`, etc. |
| `AgentTool` | struct | Wraps an `AgentRuntime` as a callable tool |
| `ToolChainBuilder` | struct | Fluent builder for sequential tool chains |
| `ToolChain` | struct | Immutable sequential tool chain |
| `ParallelToolExecutor` | actor | Runs multiple tool calls concurrently |
| `ToolCallGoal` | struct | Structured-output hint targeting a specific tool |

### Built-In Tools

```swift
BuiltInTools            // Namespace
DateTimeTool            // Returns current date/time
StringTool              // String manipulation utilities
WebSearchTool           // Web search (requires provider support)
```

### Macros

```swift
@Tool("Searches the web for information")
struct WebSearchTool {
    @Parameter("The search query") var query: String
    @Parameter("Max results") var limit: Int = 5

    func execute() async throws -> String { ... }
}
```

---

## 8. Guardrails API

**Files**: `Sources/Swarm/Guardrails/`

### Protocols

```swift
public protocol Guardrail: Sendable { }

public protocol InputGuardrail: Guardrail {
    func validate(input: String) async throws -> GuardrailResult
}

public protocol OutputGuardrail: Guardrail {
    func validate(output: String) async throws -> GuardrailResult
}

public protocol ToolInputGuardrail: Guardrail {
    func validate(toolName: String, arguments: SendableValue) async throws -> GuardrailResult
}

public protocol ToolOutputGuardrail: Guardrail {
    func validate(toolName: String, result: SendableValue, data: ToolGuardrailData) async throws -> GuardrailResult
}
```

### Runner & Configuration

```swift
public actor GuardrailRunner {
    public init(configuration: GuardrailRunnerConfiguration = .default)
    public func runInputGuardrails(_ guardrails: [any InputGuardrail], input: String) async throws
    public func runOutputGuardrails(_ guardrails: [any OutputGuardrail], output: String) async throws
}

public struct GuardrailRunnerConfiguration: Sendable {
    public var failFast: Bool          // Stop on first violation (default: true)
    public var maxConcurrency: Int     // Max simultaneous guardrail checks
    public static let `default`: GuardrailRunnerConfiguration
}
```

### Result Types

```swift
public struct GuardrailResult: Sendable {
    public enum Outcome: Sendable { case pass, block(reason: String), modify(String) }
    public let outcome: Outcome
    public let outputInfo: [String: SendableValue]
}

public struct GuardrailExecutionResult: Sendable {
    public let results: [GuardrailResult]
    public var passed: Bool { get }
    public var blockedBy: GuardrailResult? { get }
}

public enum GuardrailError: Error {
    case inputBlocked(reason: String)
    case outputBlocked(reason: String)
    case toolInputBlocked(tool: String, reason: String)
    case toolOutputBlocked(tool: String, reason: String)
}

public enum GuardrailType: Sendable {
    case input, output, toolInput, toolOutput
}

public struct ToolGuardrailData: Sendable {
    public let toolName: String
    public let arguments: SendableValue
    public let result: SendableValue
}
```

### Closure Builders (DSL Convenience)

```swift
// Create guardrails inline without defining a conforming type
InputGuardrailBuilder  { input in ... }      // -> any InputGuardrail
OutputGuardrailBuilder { output in ... }     // -> any OutputGuardrail
ToolInputGuardrailBuilder { name, args in ... }
ToolOutputGuardrailBuilder { name, result, data in ... }
```

---

## 9. Memory & Sessions

**Files**: `Sources/Swarm/Memory/`

### Core Protocols

```swift
public protocol Memory: Actor, Sendable {
    var count: Int { get }
    var isEmpty: Bool { get }
    func add(_ message: MemoryMessage) async
    func context(for query: String, tokenLimit: Int) async -> String
    func allMessages() async -> [MemoryMessage]
    func clear() async
}

public protocol Session: Sendable {
    var id: String { get }
    var messages: [MemoryMessage] { get async }
    func add(_ message: MemoryMessage) async
    func clear() async
}

public protocol PersistentMemoryBackend: Actor, Sendable { ... }
public protocol EmbeddingProvider: Sendable { ... }
public protocol Summarizer: Sendable { ... }
public protocol TokenEstimator: Sendable { ... }
```

### Concrete Implementations

| Type | Kind | Description |
|------|------|-------------|
| `ConversationMemory` | actor | Token-limited rolling buffer |
| `SlidingWindowMemory` | actor | Fixed message count window |
| `SummaryMemory` | actor | LLM-compressed conversation history |
| `VectorMemory` | actor | SIMD cosine-similarity semantic search (via Accelerate) |
| `HybridMemory` | actor | Combines multiple memory strategies |
| `PersistentMemory` | actor | SwiftData-backed durable storage |
| `AnyMemory` | struct | Type-erased `Memory` wrapper |
| `CompositeMemory` | actor | Fans out reads/writes across multiple memories |
| `InMemorySession` | actor | In-process `Session` implementation |

### Supporting Types

```swift
public struct MemoryMessage: Sendable, Codable {
    public enum Role: Sendable { case user, assistant, system, tool }
    public let role: Role
    public let content: String
    public let timestamp: Date
    public let metadata: [String: SendableValue]
}

// Fluent builder
MemoryBuilder()
    .conversationMemory(maxTokens: 4000)
    .withSummary(using: mySummarizer)
    .withVectorSearch(using: myEmbeddingProvider)
    .build()                    // -> any Memory
```

---

## 10. Observability

**Files**: `Sources/Swarm/Observability/`, `Sources/Swarm/Core/RunHooks.swift`

### `AgentObserver` Protocol

Replaces the old `RunHooks`. Lifecycle callbacks for agent execution.

```swift
public protocol AgentObserver: Sendable {
    func agentDidStart(name: String, input: String) async
    func agentDidComplete(name: String, result: AgentResult) async
    func agentDidFail(name: String, error: Error) async
    func toolWillCall(name: String, arguments: SendableValue) async
    func toolDidReturn(name: String, result: SendableValue) async
    func handoffDidOccur(from: String, to: String) async
}
```

### `Tracer` Protocol

```swift
public protocol Tracer: Actor, Sendable {
    func startSpan(_ name: String, metadata: [String: SendableValue]) -> TraceSpan
    func emit(_ event: TraceEvent) async
    func flush() async
}
```

### Concrete Implementations

| Type | Kind | Description |
|------|------|-------------|
| `NoOpTracer` | actor | Discards all events |
| `BufferedTracer` | actor | Stores events in memory for retrieval |
| `ConsoleTracer` | actor | Prints events to stdout |
| `PrettyConsoleTracer` | actor | Formatted, human-readable console output |
| `SwiftLogTracer` | actor | Forwards events to `swift-log` |
| `CompositeTracer` | actor | Fan-out to multiple tracers |
| `AnyTracer` | struct | Type-erased `Tracer` |

### Event & Span Types

```swift
public struct TraceEvent: Sendable {
    public let name: String
    public let timestamp: Date
    public let metadata: [String: SendableValue]
    public let spanID: String?
}

public struct TraceSpan: Sendable {
    public let id: String
    public let name: String
    public let startTime: Date
    public func end(metadata: [String: SendableValue] = [:]) async
}

public struct TraceContext: Sendable {
    public let traceID: String
    public let spanID: String
    public let parentSpanID: String?
}
```

### Metrics

```swift
public actor MetricsCollector {
    public func record(event: MetricsEvent) async
    public func snapshot() async -> MetricsSnapshot
}

public struct MetricsSnapshot: Sendable {
    public let agentExecutionCount: Int
    public let toolCallCount: Int
    public let averageLatency: Duration
    public let tokenUsage: TokenUsage
}

public protocol MetricsReporter: Sendable {
    func report(snapshot: MetricsSnapshot) async throws
}

public struct JSONMetricsReporter: MetricsReporter { ... }

public actor PerformanceTracker {
    public struct PerformanceMetrics: Sendable {
        public var agentExecutionTime: Duration
        public var toolExecutionTime: Duration
        public var memoryLatency: Duration
        public var inferenceLatency: Duration
        public var throughput: Double           // tokens/sec
    }
}
```

### Logging Categories

```swift
// swift-log loggers — use these, never print()
Log.agents          // Agent lifecycle and execution
Log.memory          // Memory operations
Log.tracing         // Observability events
Log.metrics         // Performance and usage
Log.orchestration   // Multi-agent coordination
```

---

## 11. Resilience Primitives

**Files**: `Sources/Swarm/Resilience/` (if present) or inline in Core

```swift
public struct RetryPolicy: Sendable {
    public var maxRetries: Int
    public var backoffStrategy: BackoffStrategy
    public var maxDuration: Duration?
    public var retryableErrors: ((Error) -> Bool)?
}

public enum BackoffStrategy: Sendable {
    case constant(Duration)
    case linear(Duration)
    case exponential(Duration, base: Double = 2.0)
    case fibonacci(Duration)
}

public actor CircuitBreaker {
    public enum State { case closed, open, halfOpen }

    public struct Statistics: Sendable {
        public let successCount: Int
        public let failureCount: Int
        public let lastFailureTime: Date?
    }

    public func execute<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T
    public func reset() async
    public var statistics: Statistics { get async }
}

public actor CircuitBreakerRegistry {
    public func breaker(for key: String) -> CircuitBreaker
}

public actor RateLimiter {
    public init(requestsPerSecond: Double, burst: Int)
    public func acquire() async throws
}

public struct FallbackChain<Output: Sendable>: Sendable {
    public func step(_ operation: @escaping @Sendable () async throws -> Output) -> Self
    public func execute() async throws -> ExecutionResult<Output>
}

public struct ExecutionResult<Output: Sendable>: Sendable {
    public let value: Output
    public let errors: [Error]
    public let attemptCount: Int
}

public enum ResilienceError: Error {
    case maxRetriesExceeded(attempts: Int, lastError: Error)
    case maxDurationExceeded
    case timeout
    case circuitOpen
    case rateLimitExceeded
}
```

---

## 12. Inference & Model Controls

**Files**: `Sources/Swarm/Core/AgentRuntime.swift`, `Sources/Swarm/Providers/`

```swift
public struct InferenceOptions: Sendable {
    public var temperature: Double?
    public var maxTokens: Int?
    public var topP: Double?
    public var stopSequences: [String]
    public var model: String?
    public var toolChoice: ToolChoice
    public var truncationStrategy: TruncationStrategy
    public var stream: Bool

    public static let `default`: InferenceOptions
}

public struct InferenceResponse: Sendable {
    public let text: String?
    public let toolCalls: [ToolCall]
    public let usage: TokenUsage?
    public let finishReason: FinishReason?
    public let id: String?
}

public enum FinishReason: Sendable {
    case stop, length, toolCalls, contentFilter
}

public struct InferenceStreamEvent: Sendable {
    public enum Kind: Sendable {
        case textDelta(String)
        case toolCallDelta(PartialToolCallUpdate)
        case done(InferenceResponse)
    }
    public let kind: Kind
}

public struct InferenceStreamUpdate: Sendable {
    public let delta: String?
    public let toolCallDelta: PartialToolCallUpdate?
    public let isDone: Bool
}

public struct ModelSettings: Sendable {
    public var temperature: Double?
    public var maxTokens: Int?
    public var topP: Double?
    public var presencePenalty: Double?
    public var frequencyPenalty: Double?
    public var parallelToolCalls: Bool?

    public static let `default`: ModelSettings
}

public enum ToolChoice: Sendable {
    case auto
    case required
    case none
    case specific(name: String)
}

public enum TruncationStrategy: Sendable {
    case auto
    case lastN(Int)
    case disabled
}

public enum Verbosity: Sendable {
    case silent, normal, verbose
}

public enum CacheRetention: Sendable {
    case ephemeral
    case session
    case persistent
}

public enum ModelSettingsValidationError: Error {
    case temperatureOutOfRange(Double)
    case maxTokensOutOfRange(Int)
    case invalidModel(String)
}
```

---

## 13. Core Value / Event / Error Types

**Files**: `Sources/Swarm/Core/`

### Result Types

```swift
public struct AgentResult: Sendable {
    public let output: String
    public let toolCalls: [ToolCall]
    public let toolResults: [ToolResult]
    public let iterationCount: Int
    public let duration: Duration
    public let tokenUsage: TokenUsage?
    public let metadata: [String: SendableValue]
}

public struct AgentResponse: Sendable {
    public let result: AgentResult
    public let responseID: String?      // for multi-turn continuation
}

public struct TokenUsage: Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public var totalTokens: Int { inputTokens + outputTokens }
}

public struct ToolCall: Sendable {
    public let id: String
    public let name: String
    public let arguments: SendableValue
}

public struct ToolResult: Sendable {
    public let toolCallId: String
    public let output: SendableValue
    public let isError: Bool
}

public struct ToolCallRecord: Sendable {
    public let call: ToolCall
    public let result: ToolResult
    public let duration: Duration
}

public struct PartialToolCallUpdate: Sendable {
    public let id: String?
    public let name: String?
    public let argumentsDelta: String?
    public let index: Int
}
```

### Events

```swift
public enum AgentEvent: Sendable {
    case started
    case progress(String)
    case toolCall(ToolCall)
    case toolResult(ToolResult)
    case handoff(from: String, to: String)
    case completed(AgentResult)
    case failed(Error)
}

public enum MemoryOperation: Sendable {
    case added(MemoryMessage)
    case retrieved([MemoryMessage])
    case cleared
}
```

### Universal Data Carrier

```swift
public enum SendableValue: Sendable, Codable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([SendableValue])
    case dictionary([String: SendableValue])
}

extension SendableValue {
    // Codable round-trip
    public init<T: Encodable>(encoding value: T) throws
    public func decode<T: Decodable>() throws -> T

    // Typed accessors (return nil if wrong case)
    public var boolValue: Bool? { get }
    public var intValue: Int? { get }
    public var doubleValue: Double? { get }
    public var stringValue: String? { get }
    public var arrayValue: [SendableValue]? { get }
    public var dictionaryValue: [String: SendableValue]? { get }
    public var isNull: Bool { get }
}
```

### Errors

```swift
public enum AgentError: Error, Sendable {
    case inferenceProviderUnavailable
    case toolCallingRequiresCloudProvider
    case generationFailed(underlying: Error)
    case invalidToolArguments(tool: String, reason: String)
    case toolExecutionFailed(tool: String, underlying: Error)
    case toolNotFound(name: String)
    case maxIterationsExceeded(limit: Int)
    case conversationNotFound(id: String)
    case invalidSession
    case guardrailViolation(GuardrailError)
    case handoffFailed(target: String, reason: String)
    case cancelled
    case memoryError(underlying: Error)
    case streamingNotSupported
    case providerError(underlying: Error)
    case contextWindowExceeded
    case rateLimitExceeded
    case authenticationFailed
    case timeout(after: Duration)
    case unknownError(underlying: Error)
    // ... (21+ total cases)
}

public enum WorkflowError: Error, Sendable {
    case noSteps
    case stepFailed(index: Int, underlying: Error)
    case timeout(after: Duration)
    case cancelled
    case checkpointNotFound(id: String)
}

public enum WorkflowValidationError: Error, Sendable {
    case cyclicDependency
    case missingDependency(String)
    case duplicateStepID(String)
}

public enum GuardrailError: Error, Sendable {
    case inputBlocked(reason: String)
    case outputBlocked(reason: String)
    case toolInputBlocked(tool: String, reason: String)
    case toolOutputBlocked(tool: String, reason: String)
}

public enum ResilienceError: Error, Sendable {
    case maxRetriesExceeded(attempts: Int, lastError: Error)
    case maxDurationExceeded
    case timeout
    case circuitOpen
    case rateLimitExceeded
}
```

---

## 14. Public Macros

**Files**: `Sources/SwarmMacros/`, `Sources/Swarm/Macros/MacroDeclarations.swift`

| Macro | Applied To | Effect |
|-------|-----------|--------|
| `@Tool("description")` | `struct` | Synthesizes `AnyJSONTool` conformance + JSON schema from `@Parameter` properties |
| `@Parameter("description")` | `var` inside `@Tool` struct | Marks property as a schema parameter with description |
| `@AgentActor(instructions:generateBuilder:)` | `actor` | Synthesizes `AgentRuntime` conformance, builder type, and convenience initializers |
| `@AgentActor(_ instructions:)` | `actor` | Shorthand `@AgentActor` with just a string literal |
| `@Traceable` | `struct` conforming to `AnyJSONTool` | Injects `Tracer` span recording around `execute()` |
| `#Prompt(...)` | call site | Type-safe interpolated prompt string returning `PromptString` |
| `@Builder` | `struct` | Generates fluent `.with*(...)` setter methods for every stored property |

```swift
// @AgentActor example
@AgentActor("You are a data analyst specialized in CSV parsing.")
actor DataAnalystAgent {
    @Tool("Parse and summarize a CSV file")
    struct ParseCSVTool {
        @Parameter("The CSV content as a string") var csvContent: String
        @Parameter("Maximum rows to return") var limit: Int = 100

        func execute() async throws -> String { ... }
    }
}
// ↑ Generates: DataAnalystAgent.Builder, init(tools:instructions:...) throws

// #Prompt example
let prompt: PromptString = #Prompt("Analyze \(userInput) and return JSON")
```

---

## 15. Inference Providers

**Files**: `Sources/Swarm/Providers/`

### Conduit Providers (Unified Backend)

```swift
// Generic wrapper for any Conduit-backed provider
public struct ConduitInferenceProvider<Provider: ConduitProvider>: InferenceProvider {
    public init(_ provider: Provider)
}

// Routing by model name prefix ("anthropic/claude-..." → Anthropic provider)
public enum ConduitProviderSelection: InferenceProvider {
    public static func make(
        anthropicKey: String? = nil,
        openAIKey: String? = nil,
        ollamaBaseURL: URL? = nil,
        geminiKey: String? = nil
    ) throws -> ConduitProviderSelection
}

// Shorthand model ID enum
public enum LLM: InferenceProvider {
    case claude_opus_4_6
    case claude_sonnet_4_6
    case claude_haiku_4_5
    case gpt_4o
    case gpt_4o_mini
    case gemini_pro
    // etc.
}
```

### Multi-Provider Routing

```swift
// Routes to different providers based on model name prefix
public actor MultiProvider: InferenceProvider {
    public init(providers: [String: any InferenceProvider], default: any InferenceProvider)
    public func register(_ provider: any InferenceProvider, for prefix: String) async
}

public enum MultiProviderError: Error {
    case routingFailed(model: String)
    case noProvidersConfigured
}
```

### OpenRouter Provider

```swift
public actor OpenRouterProvider: InferenceStreamingProvider {
    public init(configuration: OpenRouterConfiguration)
}

public struct OpenRouterConfiguration: Sendable {
    public var apiKey: String
    public var model: String
    public var temperature: Double?
    public var maxTokens: Int?
    public var routingStrategy: OpenRouterRoutingStrategy
    public var providerPreferences: OpenRouterProviderPreferences
    public var retryStrategy: OpenRouterRetryStrategy
}

public enum OpenRouterRoutingStrategy: Sendable {
    case loadBalancing
    case preferCheap
    case preferFast
    case custom(String)
}

public struct OpenRouterProviderPreferences: Sendable {
    public var allowFallbacks: Bool
    public var prioritizeFreeModels: Bool
    public var dataPrivacy: Bool
}
```

### Ollama Settings

```swift
public struct OllamaSettings: Sendable {
    public var baseURL: URL
    public var model: String
    public var temperature: Double?
    public var contextWindowSize: Int?
}
```

---

## 16. MCP Integration

**Files**: `Sources/Swarm/MCP/` (client), `Sources/SwarmMCP/` (server)

### Swarm as MCP Client

Fetch external tools from MCP servers and use them as `AnyJSONTool` instances.

```swift
public actor MCPClient {
    public init(serverURL: URL)
    public func connect() async throws
    public func disconnect() async
    public func listTools() async throws -> [ToolSchema]
    public func callTool(name: String, arguments: SendableValue) async throws -> SendableValue
    public var state: MCPServerState { get async }
}

public enum MCPServerState: Sendable {
    case connecting, ready, error(Error), closed
}

public struct MCPCapabilities: Sendable {
    public let supportsTools: Bool
    public let supportsResources: Bool
    public let supportsPrompts: Bool
}

public struct MCPResource: Sendable {
    public let uri: String
    public let name: String
    public let description: String?
    public let mimeType: String?
}
```

### Swarm as MCP Server

Expose Swarm agent tools to external MCP clients.

```swift
public actor SwarmMCPServerService {
    public struct Metrics: Sendable {
        public let listToolsRequests: Int
        public let callToolRequests: Int
        public let callToolSuccesses: Int
        public let callToolFailures: Int
    }

    public init(tools: [any AnyJSONTool])
    public func start() async throws
    public func stop() async
    public func listTools() async -> [ToolSchema]
    public func callTool(name: String, arguments: SendableValue) async throws -> SendableValue
    public var metrics: Metrics { get async }
}

public protocol SwarmMCPToolCatalog: Sendable {
    func availableTools() async -> [ToolSchema]
}

public protocol SwarmMCPToolExecutor: Sendable {
    func execute(tool name: String, arguments: SendableValue) async throws -> SendableValue
}
```

---

## 17. Hive Runtime Integration

**Files**: `Sources/Swarm/HiveSwarm/`

The Hive bridge — used when `runtimeMode = .hive` or when `Orchestration` compiles to a DAG.

### Core Bridge Types

| Type | Kind | Purpose |
|------|------|---------|
| `GraphAgent` | struct | Hive-backed agent node for DAG orchestration |
| `RetryPolicyBridge` | enum | Converts `RetryPolicy` → Hive retry config (strips jitter for determinism) |
| `ToolRegistryAdapter` | struct | Bridges `ToolRegistry` to Hive's tool approval system |
| `ToolRegistryAdapterError` | enum | Adapter-level errors |
| `HiveCodableJSONCodec<Value>` | struct | Codable ↔ Hive serialization codec |

### Chat Graph (Low-Level Hive Graph Building)

```swift
public enum ChatGraph {
    public typealias ToolProvider = @Sendable () async -> [any AnyJSONTool]

    public protocol PreModelHook: Sendable {
        func beforeModel(context: RuntimeContext) async throws
    }

    public struct NoopPreModelHook: PreModelHook { ... }

    public protocol ToolResultTransformer: Sendable {
        func transform(result: SendableValue, for tool: String) async -> SendableValue
    }

    public protocol HiveTokenizer: Sendable {
        func tokenCount(for text: String) -> Int
    }

    public struct HiveCompactionPolicy: Sendable {
        public var maxTokens: Int
        public var strategy: CompactionStrategy
        public enum CompactionStrategy { case truncate, summarize }
    }

    public struct RuntimeContext: Sendable {
        public let sessionID: String
        public let agentName: String
        public let iteration: Int
        public let metadata: [String: SendableValue]
    }

    public struct RunStartRequest: Sendable {
        public let input: String
        public let sessionID: String?
        public let metadata: [String: SendableValue]
    }

    public struct RunResumeRequest: Sendable {
        public let checkpointID: String
        public let sessionID: String
    }

    public enum ToolApprovalPolicy: Sendable {
        case autoApprove
        case requireManual
        case custom(@Sendable (String, SendableValue) async -> Bool)
    }
}
```

### Runtime Hardening (Determinism & Checkpointing)

```swift
public enum HiveDeterminism {
    public static func verify(transcript: HiveCanonicalTranscript) throws
    public static func diff(_ lhs: HiveCanonicalTranscript, _ rhs: HiveCanonicalTranscript) -> HiveDeterminismDiff
}

public struct HiveCanonicalTranscript: Sendable, Codable {
    public let records: [HiveCanonicalEventRecord]
    public let schemaVersion: EventSchemaVersion
}

public enum EventSchemaVersion: String, Sendable, Codable {
    case v1, v2
}

public struct HiveRuntimeStateSnapshot<Schema: Sendable>: Sendable {
    public let frontier: HiveRuntimeFrontierSummary
    public let channels: [HiveRuntimeChannelStateSummary]
    public let interruptions: [HiveRuntimeInterruptionSummary<Schema>]
}
```

---

## 18. Context & Environment

**Files**: `Sources/Swarm/Core/AgentEnvironment.swift`, `Sources/Swarm/Core/Environment.swift`

### TaskLocal Dependency Injection

```swift
// Namespace for all TaskLocal environment values
public enum AgentEnvironmentValues {
    @TaskLocal public static var inferenceProvider: (any InferenceProvider)?
    @TaskLocal public static var tracer: (any Tracer)?
    @TaskLocal public static var memory: (any Memory)?
    @TaskLocal public static var observer: (any AgentObserver)?
}

// Wrap execution to set environment values for the subtree
public struct AgentEnvironment: Sendable {
    public static func withProvider<T: Sendable>(
        _ provider: some InferenceProvider,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T
}

// Generic environment value wrapper (SwiftUI-style)
@propertyWrapper
public struct Environment<Value> {
    public init(_ keyPath: KeyPath<AgentEnvironmentValues, Value>)
    public var wrappedValue: Value { get }
}
```

### Typed Context Keys

```swift
// Type-safe key for AgentContext storage
public struct ContextKey<Value: Sendable>: Sendable {
    public let name: String
    public init(_ name: String)
}

public actor AgentContext {
    public func set<Value: Sendable>(_ value: Value, for key: ContextKey<Value>) async
    public func get<Value: Sendable>(_ key: ContextKey<Value>) async -> Value?
    public func remove<Value: Sendable>(_ key: ContextKey<Value>) async
}

public enum AgentContextKey: Sendable {
    public static let agentName     = ContextKey<String>("agentName")
    public static let handoffReason = ContextKey<String>("handoffReason")
    public static let parentAgent   = ContextKey<String>("parentAgent")
    public static let iterationCount = ContextKey<Int>("iterationCount")
}
```

---

## 19. Stream Operations

**File**: `Sources/Swarm/Core/StreamOperations.swift`

```swift
public enum AgentEventStream {
    // Merge multiple agent event streams
    public static func merge(
        _ streams: [AsyncThrowingStream<AgentEvent, Error>],
        errorStrategy: MergeErrorStrategy = .failFast
    ) -> AsyncThrowingStream<AgentEvent, Error>

    // Collect all output text from a stream
    public static func collectOutput(
        _ stream: AsyncThrowingStream<AgentEvent, Error>
    ) async throws -> String
}

public enum MergeErrorStrategy: Sendable {
    case failFast       // Cancel all on first error
    case collect        // Emit all errors, continue
}

// Typealiases for clarity
public typealias ToolCallInfo = ToolCall
public typealias ToolResultInfo = ToolResult
```

---

## 20. Naming Guarantees & Design Invariants

These are hard contracts baked into the API design:

| Invariant | Detail |
|-----------|--------|
| **`observer` label** | All observer parameters use `observer:`, never `hooks:` |
| **Handoff callbacks** | Always named `onTransfer` / `transform` / `when` |
| **`Sendable` everywhere** | Every public type conforms to `Sendable` |
| **`Actor` for shared state** | `Memory`, `Tracer`, `ToolRegistry`, `CircuitBreaker`, `RateLimiter` are actors |
| **No legacy agent types** | `ReActAgent`, `PlanAndExecuteAgent`, `ResilientAgent`, `SupervisorAgent` are removed |
| **No legacy DSL** | `AgentLoop`, `AgentBlueprint`, `OrchestrationBuilder` are removed |
| **`Workflow` is the single primitive** | No parallel `Orchestration` struct in the public API |
| **`#if canImport(SwiftData)`** | `PersistentMemory` only available on platforms with SwiftData |
| **Strict concurrency** | `StrictConcurrency` enabled on all targets — crossing actor boundaries with non-`Sendable` types is a build error |
| **No `print()` in production** | All logging goes through `swift-log` category loggers (`Log.*`) |

---

## Quick-Reference Summary

| Subsystem | Key Entry Points |
|-----------|----------------|
| **Setup** | `Swarm.configure(provider:)` |
| **Agent** | `Agent`, `Agent.Builder`, `@AgentActor` |
| **Conversation** | `Conversation` |
| **Workflow** | `Workflow` |
| **Handoffs** | `handoff(to:)`, `agent.asHandoff()` |
| **Tools** | `@Tool`, `@Parameter`, `FunctionTool`, `ToolRegistry` |
| **Guardrails** | `InputGuardrail`, `OutputGuardrail`, `GuardrailRunner` |
| **Memory** | `ConversationMemory`, `VectorMemory`, `SummaryMemory` |
| **Observability** | `AgentObserver`, `Tracer`, `MetricsCollector` |
| **Resilience** | `RetryPolicy`, `CircuitBreaker`, `FallbackChain` |
| **Data** | `SendableValue`, `AgentResult`, `AgentEvent` |
| **Providers** | `ConduitProviderSelection`, `LLM`, `MultiProvider` |
| **MCP** | `MCPClient`, `SwarmMCPServerService` |
