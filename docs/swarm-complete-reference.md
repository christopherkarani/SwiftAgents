# Swarm Framework — Complete API Reference

> **Version**: 1.0 · **Swift**: 6.2+ · **Platforms**: macOS 26+, iOS 26+, Linux (Ubuntu 22.04+)
>
> A Swift-native multi-agent orchestration framework — "LangChain for Apple platforms."

---

## Table of Contents

1. [Overview & Architecture](#1-overview--architecture)
2. [Quick Start](#2-quick-start)
3. [Agents](#3-agents)
4. [Tools](#4-tools)
5. [DSL & Blueprints](#5-dsl--blueprints)
6. [Orchestration](#6-orchestration)
7. [Handoffs & Routing](#7-handoffs--routing)
8. [Memory](#8-memory)
9. [Guardrails](#9-guardrails)
10. [Resilience](#10-resilience)
11. [Observability](#11-observability)
12. [MCP Integration](#12-mcp-integration)
13. [Providers](#13-providers)
14. [Macros](#14-macros)
15. [Hive Runtime](#15-hive-runtime)

---

## 1. Overview & Architecture

### What Is Swarm?

Swarm is a Swift 6.2 framework for building multi-agent AI applications on Apple platforms and Linux. It provides:

- **Agent reasoning** — ReAct, Plan-and-Execute, Supervisor patterns
- **Tool execution** — Type-safe tools with parallel execution and chaining
- **Memory systems** — Conversation, vector, summary, persistent, and hybrid memory
- **Multi-agent coordination** — Handoffs, routing, supervisors, DAG workflows
- **Pluggable inference** — Apple Foundation Models, Anthropic, OpenAI, Ollama, Gemini, OpenRouter via Conduit
- **Observability** — Distributed tracing, metrics, performance tracking
- **Safety** — Input/output/tool guardrails with tripwire modes
- **Resilience** — Retry policies, circuit breakers, fallback chains, rate limiting

### Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│                    Your Application                      │
├─────────────────────────────────────────────────────────┤
│  AgentBlueprint DSL  │  Orchestration Builder  │  Macros │
├─────────────────────────────────────────────────────────┤
│          Orchestration Steps (11 types)                  │
│  Sequential · Parallel · DAG · Router · Branch · Guard   │
│  Transform · Pipeline · Loop · ParallelGroup · Chain     │
├─────────────────────────────────────────────────────────┤
│              AgentRuntime Protocol                        │
│  Agent · ReActAgent · PlanAndExecuteAgent · Supervisor   │
├──────────────┬──────────────┬───────────────────────────┤
│    Tools     │   Memory     │   Guardrails & Resilience  │
│  @Tool macro │ Conversation │   Input/Output/Tool guards │
│  FunctionTool│ Vector/SIMD  │   Retry · CircuitBreaker   │
│  ToolChain   │ Summary      │   Fallback · RateLimiter   │
│  Registry    │ Persistent   │   Timeout                  │
├──────────────┴──────────────┴───────────────────────────┤
│           Inference Providers (InferenceProvider)         │
│  LLM enum · MultiProvider · ConduitInferenceProvider     │
│  Foundation Models · OpenRouter · Ollama                  │
├─────────────────────────────────────────────────────────┤
│    Hive Runtime (DAG compilation, checkpointing)         │
├─────────────────────────────────────────────────────────┤
│         External: Conduit · Wax · HiveCore · MCP SDK     │
└─────────────────────────────────────────────────────────┘
```

### Package Targets

| Target | Type | Purpose |
|--------|------|---------|
| `Swarm` | Library | Core framework — agents, tools, memory, orchestration, Hive integration |
| `SwarmMCP` | Library | MCP server bridge — exposes Swarm tools to MCP clients |
| `SwarmMacros` | Macro (compiler plugin) | `@Tool`, `@AgentActor`, `@Prompt`, `@Traceable` macros |
| `SwarmTests` | Test | Tests for Swarm + SwarmMCP |
| `SwarmMacrosTests` | Test | Macro expansion tests |
| `HiveSwarmTests` | Test | Hive integration tests |

### External Dependencies

| Package | Purpose |
|---------|---------|
| **Conduit** | Unified inference provider abstraction (Anthropic, OpenAI, Ollama, Gemini, OpenRouter) |
| **Wax** | Embedding provider + vector operations for `VectorMemory` |
| **HiveCore** | Compiled DAG execution engine, checkpointing, interrupt/resume |
| **swift-syntax** | Powers `SwarmMacros` compiler plugin |
| **swift-log** | Cross-platform structured logging |
| **swift-sdk** (MCP) | Model Context Protocol Swift SDK |

### Concurrency Model

Swarm requires Swift 6.2 strict concurrency:

- **All public types are `Sendable`** — no exceptions
- **Memory and Tracer require `Actor` conformance** — thread-safe by design
- **`@TaskLocal` environment injection** — SwiftUI-style dependency resolution
- **Structured concurrency throughout** — `TaskGroup`, `async let` over unstructured `Task {}`

---

## 2. Quick Start

### Minimal Agent

```swift
import Swarm

// 1. Create a tool
@Tool
struct CalculatorTool {
    @Parameter(description: "Math expression to evaluate")
    var expression: String

    func execute() async throws -> String {
        // evaluation logic
        return "42"
    }
}

// 2. Create an agent with a provider
let agent = Agent(
    name: "MathBot",
    instructions: "You are a helpful math assistant.",
    tools: [CalculatorTool()],
    inferenceProvider: LLM.anthropic(
        apiKey: "sk-...",
        model: "claude-3-5-sonnet-20241022"
    )
)

// 3. Run it
let result = try await agent.run("What is 6 × 7?")
print(result.output)          // "42"
print(result.toolCalls.count) // 1
print(result.duration)        // 1.234 seconds
```

### Blueprint-Based Workflow

```swift
import Swarm

struct ResearchWorkflow: AgentBlueprint {
    @OrchestrationBuilder var body: some OrchestrationStep {
        AgentStep(researcher)
        Transform { result in
            "Summarize: \(result.output)"
        }
        AgentStep(summarizer)
    }

    var researcher: Agent { Agent(name: "Researcher", instructions: "Research the topic.") }
    var summarizer: Agent { Agent(name: "Summarizer", instructions: "Summarize concisely.") }
}

let result = try await ResearchWorkflow().run("Explain quantum computing")
```

### Streaming

```swift
for try await event in agent.stream("Tell me a story") {
    switch event {
    case .outputToken(let token):
        print(token, terminator: "")
    case .toolCallStarted(let call):
        print("\n[Calling \(call.toolName)...]")
    case .completed(let result):
        print("\nDone in \(result.duration)")
    default:
        break
    }
}
```

---

## 3. Agents

### `AgentRuntime` — The Central Protocol

Every agent in Swarm conforms to `AgentRuntime`. This is the single most important protocol in the framework.

```swift
public protocol AgentRuntime: Sendable {
    // Identity & Configuration
    nonisolated var name: String { get }
    nonisolated var tools: [any AnyJSONTool] { get }
    nonisolated var instructions: String { get }
    nonisolated var configuration: AgentConfiguration { get }

    // Optional Subsystems
    nonisolated var memory: (any Memory)? { get }
    nonisolated var inferenceProvider: (any InferenceProvider)? { get }
    nonisolated var tracer: (any Tracer)? { get }

    // Safety
    nonisolated var inputGuardrails: [any InputGuardrail] { get }
    nonisolated var outputGuardrails: [any OutputGuardrail] { get }

    // Multi-Agent
    nonisolated var handoffs: [AnyHandoffConfiguration] { get }

    // Execution
    func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult
    nonisolated func stream(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) -> AsyncThrowingStream<AgentEvent, Error>
    func cancel() async
    func runWithResponse(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResponse
}
```

**Default implementations** provide sensible defaults for all optional properties (`nil` memory, `nil` tracer, empty guardrails, empty handoffs). Convenience overloads allow calling `run("input")` without session or hooks.

**Provider resolution order** in `Agent`:
1. Explicit `agent.inferenceProvider`
2. `AgentEnvironmentValues.current.inferenceProvider` (TaskLocal)
3. Apple Foundation Models (macOS 26+ / iOS 26+)
4. Throws `AgentError.noInferenceProvider`

### `Agent` — The Workhorse

```swift
public actor Agent: AgentRuntime {
    nonisolated public let name: String
    nonisolated public let tools: [any AnyJSONTool]
    nonisolated public let instructions: String
    nonisolated public let configuration: AgentConfiguration
    nonisolated public let memory: (any Memory)?
    nonisolated public let inferenceProvider: (any InferenceProvider)?
    nonisolated public let tracer: (any Tracer)?
    nonisolated public let inputGuardrails: [any InputGuardrail]
    nonisolated public let outputGuardrails: [any OutputGuardrail]
    nonisolated public let handoffs: [AnyHandoffConfiguration]

    public init(
        name: String = "Agent",
        instructions: String = "You are a helpful assistant.",
        tools: [any AnyJSONTool] = [],
        inferenceProvider: (any InferenceProvider)? = nil,
        configuration: AgentConfiguration = .init(),
        memory: (any Memory)? = nil,
        tracer: (any Tracer)? = nil,
        inputGuardrails: [any InputGuardrail] = [],
        outputGuardrails: [any OutputGuardrail] = [],
        handoffs: [AnyHandoffConfiguration] = []
    )
}
```

`Agent` implements a **tool-calling loop**: it calls the LLM, checks if tools were requested, executes them, feeds results back, and repeats until the LLM produces a final text response or hits the iteration limit.

### `ReActAgent` — Reasoning + Acting

```swift
public actor ReActAgent: AgentRuntime {
    public init(
        name: String = "ReActAgent",
        tools: [any AnyJSONTool],
        instructions: String = "",
        inferenceProvider: (any InferenceProvider)? = nil,
        configuration: AgentConfiguration = .init(),
        memory: (any Memory)? = nil,
        tracer: (any Tracer)? = nil,
        runHooks: [any RunHooks] = [],
        inputGuardrails: [any InputGuardrail] = [],
        outputGuardrails: [any OutputGuardrail] = []
    )
}
```

Implements the **ReAct pattern** (Reasoning + Acting): the agent explicitly reasons about what to do, takes an action (tool call), observes the result, and repeats. Each iteration produces a visible "thought" before acting.

### `PlanAndExecuteAgent` — Strategic Planning

```swift
public actor PlanAndExecuteAgent: AgentRuntime {
    public init(
        name: String = "PlanAndExecuteAgent",
        tools: [any AnyJSONTool],
        instructions: String = "",
        inferenceProvider: (any InferenceProvider)? = nil,
        configuration: AgentConfiguration = .init(),
        memory: (any Memory)? = nil,
        tracer: (any Tracer)? = nil
    )
}
```

Two-phase execution: first creates a **plan** (list of `PlanStep`), then executes each step sequentially. Good for complex multi-step tasks.

```swift
public struct PlanStep: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let description: String
    public var status: StepStatus  // .pending, .inProgress, .completed, .failed, .skipped
    public var result: String?
}
```

### `SupervisorAgent` — Multi-Agent Coordinator

```swift
public actor SupervisorAgent: AgentRuntime {
    public init(
        name: String = "Supervisor",
        agents: [any AgentRuntime],
        instructions: String = "",
        inferenceProvider: (any InferenceProvider)? = nil,
        configuration: AgentConfiguration = .init(),
        memory: (any Memory)? = nil,
        tracer: (any Tracer)? = nil,
        routingStrategy: (any RoutingStrategy)? = nil
    )
}
```

Delegates work to sub-agents based on a routing strategy. The supervisor's LLM decides which agent handles each request.

### `ChatAgent` — Conversation-Focused

```swift
public actor ChatAgent: AgentRuntime {
    public init(
        name: String = "ChatAgent",
        instructions: String = "You are a helpful conversational assistant.",
        tools: [any AnyJSONTool] = [],
        inferenceProvider: (any InferenceProvider)? = nil,
        configuration: AgentConfiguration = .init(),
        memory: (any Memory)? = nil,
        tracer: (any Tracer)? = nil
    )
}
```

Optimized for multi-turn conversations with automatic memory integration.

### `AgentConfiguration`

```swift
public struct AgentConfiguration: Sendable, Equatable {
    public var name: String
    public var maxIterations: Int          // Default: 10
    public var modelSettings: ModelSettings?
    public var enableParallelToolCalls: Bool  // Default: true

    public init(
        name: String = "Agent",
        maxIterations: Int = 10,
        modelSettings: ModelSettings? = nil,
        enableParallelToolCalls: Bool = true
    )
}
```

### `ModelSettings`

```swift
public struct ModelSettings: Sendable, Equatable {
    public var temperature: Double?      // 0.0-2.0
    public var maxTokens: Int?
    public var topP: Double?
    public var frequencyPenalty: Double?
    public var presencePenalty: Double?
    public var seed: Int?
    public var stopSequences: [String]?
    public var toolChoice: ToolChoice?

    public func validated() throws -> ModelSettings  // Throws ModelSettingsValidationError
}
```

### `AgentResult`

```swift
public struct AgentResult: Sendable, Equatable {
    public let output: String
    public let toolCalls: [ToolCall]
    public let toolResults: [ToolResult]
    public let iterationCount: Int
    public let duration: Duration
    public let tokenUsage: TokenUsage?
    public let metadata: [String: SendableValue]
}
```

### `AgentResponse` — Enhanced Result with Tracking

```swift
public struct AgentResponse: Sendable {
    public let responseId: String          // Unique ID for conversation continuation
    public let output: String
    public let toolCallRecords: [ToolCallRecord]
    public let iterationCount: Int
    public let duration: Duration
    public let tokenUsage: TokenUsage?
    public let metadata: [String: SendableValue]
}
```

### `AgentEvent` — Streaming Events

```swift
public enum AgentEvent: Sendable {
    case agentStarted(name: String)
    case outputToken(token: String)
    case thinking(thought: String)
    case thinkingPartial(partialThought: String)
    case llmStarted(model: String?, promptTokens: Int?)
    case llmCompleted(model: String?, outputTokens: Int?, duration: Duration?)
    case toolCallStarted(call: ToolCall)
    case toolCallPartial(update: PartialToolCallUpdate)
    case toolCallCompleted(result: ToolResult)
    case toolCallFailed(callId: UUID, error: String)
    case handoff(from: String, to: String)
    case guardrailTriggered(name: String, type: GuardrailType, result: GuardrailResult)
    case iterationStarted(number: Int)
    case iterationCompleted(number: Int)
    case completed(result: AgentResult)
    case failed(error: SendableErrorWrapper)
}
```

### `AgentContext` — Shared Execution State

```swift
public actor AgentContext {
    public subscript(key: String) -> SendableValue?
    public func set(_ key: String, value: SendableValue)
    public func get(_ key: String) -> SendableValue?
    public func remove(_ key: String)
    public func merge(_ other: [String: SendableValue])
    public var allValues: [String: SendableValue]
    public func snapshot() -> [String: SendableValue]
}
```

### `SendableValue` — Universal Data Carrier

```swift
public enum SendableValue: Sendable, Equatable, Hashable, Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([SendableValue])
    case dictionary([String: SendableValue])
    case null
}
```

Used throughout: tool arguments/results, `AgentResult.metadata`, `AgentContext` values, MCP request/response, `GuardrailResult.outputInfo`, `HandoffInputData`.

### Type-Erased Wrappers

```swift
// Wraps any AgentRuntime for heterogeneous collections
public struct AnyAgent: AgentRuntime, @unchecked Sendable {
    public init(_ agent: any AgentRuntime)
}

// Callable wrapper for handoff targets
public struct CallableAgent: Sendable {
    public let name: String
    public let agent: any AgentRuntime
    public func call(_ input: String) async throws -> AgentResult
}
```

### `AgentError`

```swift
public enum AgentError: Error, Sendable, Equatable {
    case noInferenceProvider
    case maxIterationsReached(Int)
    case generationFailed(String)
    case cancelled
    case invalidConfiguration(String)
    case toolExecutionFailed(String)
    case handoffFailed(String)
    case noOutput
    case contextOverflow
}
```

### Environment Injection

```swift
// TaskLocal-based dependency injection
public enum AgentEnvironmentValues {
    @TaskLocal public static var current = AgentEnvironment()
}

public struct AgentEnvironment: Sendable {
    public var inferenceProvider: (any InferenceProvider)?
    public var tracer: (any Tracer)?
    public var memory: (any Memory)?
}

// Modifier pattern (SwiftUI-style)
let agent = myAgent.environment(\.inferenceProvider, anthropicProvider)

// @Environment property wrapper
@Environment(\.inferenceProvider) var provider
```

### `RunHooks` — Lifecycle Callbacks

```swift
public protocol RunHooks: Sendable {
    func onAgentStart(context: AgentContext?, agent: any AgentRuntime, input: String) async
    func onAgentEnd(context: AgentContext?, agent: any AgentRuntime, result: AgentResult) async
    func onError(context: AgentContext?, agent: any AgentRuntime, error: Error) async
    func onHandoff(context: AgentContext?, fromAgent: any AgentRuntime, toAgent: any AgentRuntime) async
    func onToolStart(context: AgentContext?, agent: any AgentRuntime, call: ToolCall) async
    func onToolCallPartial(context: AgentContext?, agent: any AgentRuntime, update: PartialToolCallUpdate) async
    func onToolEnd(context: AgentContext?, agent: any AgentRuntime, result: ToolResult) async
    func onLLMStart(context: AgentContext?, agent: any AgentRuntime, systemPrompt: String?, inputMessages: [MemoryMessage]) async
    func onLLMEnd(context: AgentContext?, agent: any AgentRuntime, response: String, usage: InferenceResponse.TokenUsage?) async
    func onGuardrailTriggered(context: AgentContext?, guardrailName: String, guardrailType: GuardrailType, result: GuardrailResult) async
    func onThinking(context: AgentContext?, agent: any AgentRuntime, thought: String) async
    func onThinkingPartial(context: AgentContext?, agent: any AgentRuntime, partialThought: String) async
    func onOutputToken(context: AgentContext?, agent: any AgentRuntime, token: String) async
    func onIterationStart(context: AgentContext?, agent: any AgentRuntime, number: Int) async
    func onIterationEnd(context: AgentContext?, agent: any AgentRuntime, number: Int) async
}
```

All methods have default no-op implementations. Use `CompositeRunHooks` to combine multiple hooks:

```swift
let hooks = CompositeRunHooks(hooks: [
    LoggingRunHooks(),
    MetricsRunHooks()
])
```

Built-in: `LoggingRunHooks` logs all events via swift-log.

---

## 4. Tools

### Tool Protocols

Swarm has two tool protocol levels — a typed Swift protocol and a dynamic JSON-based protocol:

```swift
/// High-level typed tool protocol
public protocol Tool: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable

    var name: String { get }
    var description: String { get }
    var parameters: [ToolParameter] { get }

    func execute(input: Input) async throws -> Output
}

/// Low-level dynamic tool protocol (JSON in/out)
public protocol AnyJSONTool: Sendable {
    var name: String { get }
    var description: String { get }
    var schema: ToolSchema { get }

    func execute(arguments: [String: SendableValue]) async throws -> SendableValue
}
```

All tools ultimately conform to `AnyJSONTool` for LLM interaction. Typed `Tool` conformers are wrapped via `AnyJSONToolAdapter`.

### `ToolSchema`

```swift
public struct ToolSchema: Sendable, Equatable {
    public let name: String
    public let description: String
    public let parameters: [ToolParameter]
    public let isStrict: Bool            // Default: false

    public init(
        name: String,
        description: String,
        parameters: [ToolParameter] = [],
        isStrict: Bool = false
    )
}
```

### `ToolParameter`

```swift
public struct ToolParameter: Sendable, Equatable {
    public let name: String
    public let description: String
    public let type: ParameterType
    public let isRequired: Bool          // Default: true
    public let defaultValue: SendableValue?

    public enum ParameterType: Sendable, Equatable {
        case string
        case int
        case double
        case bool
        case array(ParameterType)
        case object([ToolParameter])
        case oneOf([String])             // Enum-like
        case any
    }
}
```

### `FunctionTool` — Closure-Based Tools

```swift
public struct FunctionTool: AnyJSONTool, Sendable {
    public let name: String
    public let description: String
    public let schema: ToolSchema
    private let handler: @Sendable ([String: SendableValue]) async throws -> SendableValue

    public init(
        name: String,
        description: String,
        parameters: [ToolParameter] = [],
        handler: @escaping @Sendable ([String: SendableValue]) async throws -> SendableValue
    )
}
```

Example:

```swift
let weatherTool = FunctionTool(
    name: "get_weather",
    description: "Get weather for a city",
    parameters: [
        ToolParameter(name: "city", description: "City name", type: .string)
    ]
) { args in
    let city = args["city"]?.stringValue ?? "Unknown"
    return .string("72°F in \(city)")
}
```

### `ToolRegistry` — Dynamic Tool Management

```swift
public actor ToolRegistry {
    public init(tools: [any AnyJSONTool] = [])

    public func register(_ tool: any AnyJSONTool)
    public func register<T: Tool>(_ tool: T)
    public func unregister(named name: String)
    public func tool(named name: String) -> (any AnyJSONTool)?
    public func allTools() -> [any AnyJSONTool]
    public func allSchemas() -> [ToolSchema]
    public func execute(toolNamed name: String, arguments: [String: SendableValue]) async throws -> SendableValue
    public var count: Int
}
```

### `ParallelToolExecutor`

```swift
public actor ParallelToolExecutor {
    public init(
        registry: ToolRegistry,
        maxConcurrency: Int = 5,
        errorStrategy: ParallelExecutionErrorStrategy = .failFast
    )

    public func execute(calls: [ToolCall]) async throws -> [ToolResult]
}

public enum ParallelExecutionErrorStrategy: Sendable, Equatable {
    case failFast       // Stop on first error
    case collectAll     // Continue, collect all errors
    case bestEffort     // Continue, ignore errors
}
```

### Tool Chains

Tool chains allow composing tools into pipelines:

```swift
public struct ToolChain: Sendable {
    public init(@ToolChainBuilder _ build: () -> [any ToolChainStep])
    public func execute(input: [String: SendableValue]) async throws -> SendableValue
}

public protocol ToolChainStep: Sendable {
    var name: String { get }
    func execute(input: [String: SendableValue]) async throws -> [String: SendableValue]
}
```

**Step types:**

```swift
// Execute a tool
public struct ToolStep: ToolChainStep, Sendable {
    public init(tool: any AnyJSONTool, inputMapping: [String: String]?)
}

// Transform data between steps
public struct ToolTransform: ToolChainStep, Sendable {
    public init(name: String, transform: @Sendable ([String: SendableValue]) async throws -> [String: SendableValue])
}

// Filter/validate data
public struct ToolFilter: ToolChainStep, Sendable {
    public init(name: String, predicate: @Sendable ([String: SendableValue]) async throws -> Bool)
}

// Conditional branching
public struct ToolConditional: ToolChainStep, Sendable {
    public init(
        name: String,
        condition: @Sendable ([String: SendableValue]) async throws -> Bool,
        ifTrue: any ToolChainStep,
        ifFalse: (any ToolChainStep)?
    )
}
```

Example:

```swift
let chain = ToolChain {
    ToolStep(tool: fetchDataTool)
    ToolTransform(name: "parse") { data in
        // transform fetched data
        return data
    }
    ToolConditional(
        name: "check",
        condition: { $0["valid"]?.boolValue == true },
        ifTrue: ToolStep(tool: processTool),
        ifFalse: ToolStep(tool: errorTool)
    )
}
```

### Built-In Tools

```swift
public enum BuiltInTools {
    public static func calculator() -> DateTimeTool    // Date/time operations
    public static func dateTime() -> DateTimeTool      // Date/time queries
    public static func string() -> StringTool          // String manipulation
}

public struct DateTimeTool: AnyJSONTool, Sendable { ... }
public struct StringTool: AnyJSONTool, Sendable { ... }
```

### Type-Erasure Adapters

```swift
// Wraps a typed Tool as AnyJSONTool
public struct AnyJSONToolAdapter<T: Tool>: AnyJSONTool, Sendable { ... }

// Type-erased tool wrapper
public struct AnyTool: AnyJSONTool, Sendable {
    public init(_ tool: any AnyJSONTool)
}

// Wraps an AgentRuntime as a tool (for agent-as-tool patterns)
public struct AgentTool: AnyJSONTool, Sendable {
    public init(agent: any AgentRuntime, description: String?)
}
```

### `ToolChoice`

```swift
public enum ToolChoice: Sendable, Equatable, Codable {
    case auto            // LLM decides
    case none            // No tools
    case required        // Must use a tool
    case specific(String) // Must use this specific tool
}
```

### Result Builders

```swift
@resultBuilder
public struct ToolArrayBuilder {
    public static func buildBlock(_ tools: any AnyJSONTool...) -> [any AnyJSONTool]
    public static func buildOptional(_ tool: [any AnyJSONTool]?) -> [any AnyJSONTool]
    public static func buildEither(first: [any AnyJSONTool]) -> [any AnyJSONTool]
    public static func buildEither(second: [any AnyJSONTool]) -> [any AnyJSONTool]
}

@resultBuilder
public struct ToolChainBuilder { ... }

@resultBuilder
public struct ToolParameterBuilder { ... }
```

---

## 5. DSL & Blueprints

### `AgentBlueprint` — The Preferred API

`AgentBlueprint` is a SwiftUI-style declarative protocol for defining agent workflows. It compiles down to orchestration primitives at execution time.

```swift
public protocol AgentBlueprint: Sendable {
    associatedtype Body: OrchestrationStep

    @OrchestrationBuilder var body: Body { get }
    nonisolated var configuration: AgentConfiguration { get }
    nonisolated var handoffs: [AnyHandoffConfiguration] { get }
}
```

**Default implementations:**
- `configuration`: derives name from the type name
- `handoffs`: empty array
- `makeOrchestration()`: builds an `Orchestration` from `body`
- `run(_:session:hooks:)`: convenience execution
- `stream(_:session:hooks:)`: convenience streaming

Example:

```swift
struct CustomerServiceWorkflow: AgentBlueprint {
    @OrchestrationBuilder var body: some OrchestrationStep {
        // Classify the request
        AgentStep(classifier)

        // Route based on classification
        Router {
            Route("billing", agent: billingAgent)
            Route("technical", agent: techAgent)
            Route("general", agent: generalAgent)
        }
    }

    var configuration: AgentConfiguration {
        AgentConfiguration(name: "CustomerService", maxIterations: 5)
    }

    var classifier: Agent { ... }
    var billingAgent: Agent { ... }
    var techAgent: Agent { ... }
    var generalAgent: Agent { ... }
}
```

### `BlueprintAgent` — Runtime Adapter

```swift
public actor BlueprintAgent<Blueprint: AgentBlueprint>: AgentRuntime {
    nonisolated public let blueprint: Blueprint

    public init(_ blueprint: Blueprint)

    // Delegates to blueprint.makeOrchestration().run(...)
    public func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult
}
```

Lifts a blueprint into an `AgentRuntime` for use in routers, nested orchestrations, or any API expecting an agent.

### `OrchestrationBuilder` — Result Builder

```swift
@resultBuilder
public struct OrchestrationBuilder {
    public static func buildBlock(_ steps: any OrchestrationStep...) -> [any OrchestrationStep]
    public static func buildOptional(_ step: [any OrchestrationStep]?) -> [any OrchestrationStep]
    public static func buildEither(first: [any OrchestrationStep]) -> [any OrchestrationStep]
    public static func buildEither(second: [any OrchestrationStep]) -> [any OrchestrationStep]
    public static func buildArray(_ steps: [[any OrchestrationStep]]) -> [any OrchestrationStep]
}
```

### `OrchestrationStep` Protocol

```swift
public protocol OrchestrationStep: Sendable {
    func execute(input: String, context: OrchestrationStepContext) async throws -> AgentResult
}
```

All 11 step types and user-defined steps conform to this protocol.

### DSL Operators

```swift
// Sequential chaining: a --> b --> c
public func --> (lhs: any OrchestrationStep, rhs: any OrchestrationStep) -> Sequential

// Type-safe pipeline: a >>> b >>> c
public func >>> <A, B>(lhs: Pipeline<A, B>, rhs: Pipeline<B, C>) -> Pipeline<A, C>

// DAG dependency: step.dependsOn(other)
extension OrchestrationStep {
    public func dependsOn(_ dependency: any OrchestrationStep) -> DAGNode
}
```

### Step Modifiers

```swift
public protocol StepModifier: Sendable {
    func modify(step: any OrchestrationStep, input: String, context: OrchestrationStepContext) async throws -> AgentResult
}

// Apply modifiers
extension OrchestrationStep {
    public func modifier(_ mod: any StepModifier) -> ModifiedStep
    public func named(_ name: String) -> ModifiedStep
    public func retry(_ policy: RetryPolicy) -> ModifiedStep
    public func timeout(_ duration: Duration) -> ModifiedStep
}

public struct ModifiedStep: OrchestrationStep, Sendable { ... }
public struct LoggingModifier: StepModifier { ... }
public struct RetryModifier: StepModifier { ... }
public struct TimeoutModifier: StepModifier { ... }
public struct NamedModifier: StepModifier { ... }
```

### `Orchestration` — Structural Composition

```swift
public struct Orchestration: Sendable, OrchestratorProtocol {
    public init(
        root: any OrchestrationStep,
        configuration: AgentConfiguration = .init(),
        handoffs: [AnyHandoffConfiguration] = []
    )

    public init(@OrchestrationBuilder _ build: () -> [any OrchestrationStep])

    // OrchestratorProtocol
    public func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult
    public func stream(...) -> AsyncThrowingStream<AgentEvent, Error>
}
```

### `OrchestrationStepContext`

```swift
public struct OrchestrationStepContext: Sendable {
    public let agentContext: AgentContext
    public let session: (any Session)?
    public let hooks: (any RunHooks)?
    public let channelBag: ChannelBagStorage
    public let parentResult: AgentResult?
}
```

### Legacy DSL: `AgentLoopDefinition`

> **Deprecated** — Use `AgentBlueprint` instead.

```swift
public protocol AgentLoopDefinition: Sendable {
    associatedtype Body: AgentLoop
    @AgentLoopBuilder var body: Body { get }
    var configuration: AgentConfiguration { get }
}

// Step types
public struct Generate: OrchestrationStep { ... }   // LLM generation
public struct Relay: OrchestrationStep { ... }       // Pass-through

// Conversion to AgentRuntime
extension AgentLoopDefinition {
    public func asRuntime() -> LoopAgent<Self>
}
```

---

## 6. Orchestration

### Overview

Swarm provides 11 orchestration step types that compose into complex workflows. All conform to `OrchestrationStep` and execute through the Hive runtime for checkpointing and interrupt/resume support.

### Step Type 1: `Sequential`

Executes steps one after another, passing output forward.

```swift
public struct Sequential: OrchestrationStep, Sendable {
    public let steps: [any OrchestrationStep]
    public init(steps: [any OrchestrationStep])
    public init(@OrchestrationBuilder _ build: () -> [any OrchestrationStep])
}
```

Example:

```swift
Sequential {
    AgentStep(researchAgent)
    AgentStep(writerAgent)
    AgentStep(editorAgent)
}
```

### Step Type 2: `Parallel`

Executes steps concurrently and merges results.

```swift
public struct Parallel: OrchestrationStep, Sendable {
    public let items: [ParallelItem]
    public let errorHandling: ParallelErrorHandling
    public let mergeStrategy: ParallelMergeStrategy

    public init(
        errorHandling: ParallelErrorHandling = .failFast,
        mergeStrategy: ParallelMergeStrategy = .concatenate,
        @ParallelBuilder _ build: () -> [ParallelItem]
    )
}

public struct ParallelItem: Sendable {
    public let name: String
    public let step: any OrchestrationStep
}

public enum ParallelErrorHandling: Sendable {
    case failFast          // Stop on first error
    case collectAll        // Collect all errors
    case bestEffort        // Ignore errors
}

public enum ParallelMergeStrategy: Sendable {
    case concatenate       // Join outputs with newlines
    case first             // Take first completed result
    case custom(@Sendable ([AgentResult]) -> AgentResult)
}
```

### Step Type 3: `DAG` (Directed Acyclic Graph)

Executes steps respecting dependency edges, maximizing parallelism.

```swift
public struct DAG: OrchestrationStep, Sendable {
    public init(@DAGBuilder _ build: () -> [DAGNode])
}

public struct DAGNode: Sendable {
    public let name: String
    public let step: any OrchestrationStep
    public let dependencies: [String]

    public init(name: String, step: any OrchestrationStep, dependsOn: [String] = [])
}
```

Example:

```swift
DAG {
    DAGNode(name: "fetch", step: AgentStep(fetchAgent))
    DAGNode(name: "parse", step: AgentStep(parseAgent), dependsOn: ["fetch"])
    DAGNode(name: "validate", step: AgentStep(validateAgent), dependsOn: ["fetch"])
    DAGNode(name: "merge", step: AgentStep(mergeAgent), dependsOn: ["parse", "validate"])
}
```

### Step Type 4: `Router`

Dynamically routes to one of several agents based on input analysis.

```swift
public struct Router: OrchestrationStep, Sendable {
    public init(
        strategy: any RoutingStrategy,
        @RouteBuilder _ build: () -> [Route]
    )
}

public struct Route: Sendable {
    public let name: String
    public let agent: any AgentRuntime
    public let description: String?

    public init(_ name: String, agent: any AgentRuntime, description: String? = nil)
}
```

### Step Type 5: `RepeatWhile`

Loops a step while a condition holds.

```swift
public struct RepeatWhile: OrchestrationStep, Sendable {
    public init(
        condition: @Sendable (AgentResult) -> Bool,
        maxIterations: Int = 10,
        @OrchestrationBuilder body: () -> [any OrchestrationStep]
    )
}
```

Example:

```swift
RepeatWhile(
    condition: { $0.output.contains("NEEDS_REVISION") },
    maxIterations: 3
) {
    AgentStep(revisionAgent)
}
```

### Step Type 6: `Branch`

Conditional branching based on previous results.

```swift
public struct Branch: OrchestrationStep, Sendable {
    public init(
        condition: @Sendable (AgentResult) -> Bool,
        ifTrue: any OrchestrationStep,
        ifFalse: (any OrchestrationStep)?
    )
}
```

### Step Type 7: `Guard`

Validates conditions, failing the pipeline if unmet.

```swift
public struct Guard: OrchestrationStep, Sendable {
    public init(
        name: String = "Guard",
        check: @Sendable (AgentResult) async throws -> Bool,
        message: String = "Guard check failed"
    )
}
```

### Step Type 8: `Transform`

Transforms the output between steps.

```swift
public struct Transform: OrchestrationStep, Sendable {
    public init(
        name: String = "Transform",
        transform: @Sendable (AgentResult) async throws -> String
    )
}
```

### Step Type 9: `Pipeline`

Type-safe data transformation pipeline with generic input/output types.

```swift
public struct Pipeline<Input: Sendable, Output: Sendable>: Sendable {
    public init(transform: @Sendable (Input) async throws -> Output)

    public func execute(_ input: Input) async throws -> Output
}
```

Compose with `>>>`:

```swift
let pipeline = Pipeline<String, [String]> { text in text.components(separatedBy: ",") }
    >>> Pipeline<[String], Int> { items in items.count }
```

### Step Type 10: `SequentialChain`

A chain of agents where each agent's output feeds the next.

```swift
public actor SequentialChain: AgentRuntime {
    public init(
        name: String = "SequentialChain",
        agents: [any AgentRuntime],
        configuration: AgentConfiguration = .init()
    )
}
```

### Step Type 11: `ParallelGroup`

Runs multiple agents concurrently and combines results.

```swift
public actor ParallelGroup: AgentRuntime {
    public init(
        name: String = "ParallelGroup",
        agents: [any AgentRuntime],
        mergeStrategy: any ResultMergeStrategy,
        configuration: AgentConfiguration = .init()
    )
}

public protocol ResultMergeStrategy: Sendable {
    func merge(results: [AgentResult]) -> AgentResult
}
```

### Additional Steps

```swift
// Human-in-the-loop approval
public struct HumanApproval: OrchestrationStep, Sendable {
    public init(handler: any HumanApprovalHandler)
}

// Interrupt execution (for checkpointing)
public struct Interrupt: OrchestrationStep, Sendable {
    public init(reason: WorkflowInterruptReason)
}

// Fallback step
public struct FallbackStep: OrchestrationStep {
    public init(primary: any OrchestrationStep, fallback: any OrchestrationStep)
}

// Loop step
public struct Loop: OrchestrationStep {
    public init(maxIterations: Int, body: any OrchestrationStep, until: @Sendable (AgentResult) -> Bool)
}

// No-op step
public struct NoOpStep: OrchestrationStep, Sendable {
    public init()
}

// Agent execution step
public struct AgentStep: OrchestrationStep {
    public init(_ agent: any AgentRuntime)
}
```

### Orchestration Channels

Typed channels for passing data between steps:

```swift
public struct OrchestrationChannel<Value: Codable & Sendable>: Sendable {
    public let name: String
    public init(_ name: String)
}

public actor ChannelBagStorage {
    public func set<V>(_ channel: OrchestrationChannel<V>, value: V)
    public func get<V>(_ channel: OrchestrationChannel<V>) -> V?
}
```

### Workflow Checkpointing

```swift
public struct WorkflowCheckpointState: Sendable, Codable, Equatable {
    public let stepIndex: Int
    public let completedResults: [String: AgentResult]
    public let metadata: [String: SendableValue]
}

public protocol WorkflowCheckpointStore: Sendable {
    func save(_ state: WorkflowCheckpointState, for workflowId: String) async throws
    func load(for workflowId: String) async throws -> WorkflowCheckpointState?
    func delete(for workflowId: String) async throws
}

// Built-in stores
public actor InMemoryWorkflowCheckpointStore: WorkflowCheckpointStore { ... }
public actor FileSystemWorkflowCheckpointStore: WorkflowCheckpointStore {
    public init(directory: URL)
}
```

### Orchestration Errors

```swift
public enum OrchestrationError: Error, Sendable, Equatable {
    case stepFailed(String, String)
    case maxIterationsReached(Int)
    case guardFailed(String)
    case routingFailed(String)
    case channelNotFound(String)
    case cancelled
    case timeout(Duration)
    case dagCycle([String])
    case emptyOrchestration
}

public enum OrchestrationValidationError: Error, Sendable, Equatable {
    case emptySteps
    case duplicateStepNames([String])
    case unresolvedDependencies([String])
    case cyclicDependency([String])
}
```

---

## 7. Handoffs & Routing

### How Handoffs Work

Handoffs are **injected as extra tools** into the LLM's tool set. When the LLM chooses a handoff tool (named `handoff_to_<snake_case_target>`), the `Agent` detects the match and calls `targetAgent.run()` directly. This is not a separate communication channel — it reuses the existing tool-calling mechanism.

### `HandoffConfiguration`

```swift
public struct HandoffConfiguration<Target: AgentRuntime>: Sendable {
    public let target: Target
    public let toolName: String
    public let toolDescription: String
    public let inputFilter: (@Sendable (String) -> String)?
    public let onHandoff: (@Sendable (HandoffInputData) async -> Void)?
    public let isEnabled: (@Sendable () -> Bool)?

    public init(
        target: Target,
        toolName: String? = nil,          // Auto-generated: handoff_to_<name>
        toolDescription: String? = nil,    // Auto-generated
        inputFilter: (@Sendable (String) -> String)? = nil,
        onHandoff: (@Sendable (HandoffInputData) async -> Void)? = nil,
        isEnabled: (@Sendable () -> Bool)? = nil
    )
}
```

### `AnyHandoffConfiguration` — Type-Erased

```swift
public struct AnyHandoffConfiguration: Sendable {
    public let targetName: String
    public let toolName: String
    public let toolDescription: String

    public init<Target: AgentRuntime>(_ config: HandoffConfiguration<Target>)

    public func makeToolSchema() -> ToolSchema
    public func execute(input: String) async throws -> AgentResult
}
```

### `HandoffBuilder`

```swift
public struct HandoffBuilder<Target: AgentRuntime>: Sendable {
    public init(target: Target)

    public func toolName(_ name: String) -> Self
    public func toolDescription(_ desc: String) -> Self
    public func inputFilter(_ filter: @escaping @Sendable (String) -> String) -> Self
    public func onHandoff(_ callback: @escaping @Sendable (HandoffInputData) async -> Void) -> Self
    public func isEnabled(_ check: @escaping @Sendable () -> Bool) -> Self
    public func build() -> HandoffConfiguration<Target>
}
```

Example:

```swift
let agent = Agent(
    name: "Triage",
    instructions: "Route to the right specialist.",
    handoffs: [
        HandoffBuilder(target: billingAgent)
            .toolDescription("Transfer to billing specialist for payment issues")
            .inputFilter { "Context: billing inquiry. \($0)" }
            .build()
            .asAny(),
        HandoffBuilder(target: techAgent)
            .toolDescription("Transfer to tech support for technical issues")
            .build()
            .asAny()
    ]
)
```

### `HandoffInputData`

```swift
public struct HandoffInputData: Sendable, Equatable {
    public let sourceAgent: String
    public let targetAgent: String
    public let input: String
    public let metadata: [String: SendableValue]
}
```

### `HandoffResult`

```swift
public struct HandoffResult: Sendable, Equatable {
    public let targetAgent: String
    public let result: AgentResult
    public let duration: Duration
}
```

### `HandoffCoordinator`

```swift
public actor HandoffCoordinator {
    public init()

    public func register(handoff: AnyHandoffConfiguration)
    public func execute(handoffNamed name: String, input: String) async throws -> AgentResult
    public func availableHandoffs() -> [AnyHandoffConfiguration]
}
```

### Routing Strategies

```swift
public protocol RoutingStrategy: Sendable {
    func route(
        input: String,
        routes: [Route],
        context: AgentContext?
    ) async throws -> RoutingDecision
}

public struct RoutingDecision: Sendable, Equatable {
    public let selectedRoute: String
    public let confidence: Double?
    public let reasoning: String?
}
```

**Built-in strategies:**

```swift
// Routes based on keyword matching
public struct KeywordRoutingStrategy: RoutingStrategy {
    public init(keywords: [String: [String]])
}

// Uses an LLM to decide routing
public struct LLMRoutingStrategy: RoutingStrategy {
    public init(provider: any InferenceProvider, instructions: String?)
}
```

### `RouteCondition` — Deterministic Routing

```swift
public struct RouteCondition: Sendable {
    public init(_ evaluate: @escaping @Sendable (String, AgentContext?) async -> Bool)
    public func matches(input: String, context: AgentContext?) async -> Bool
}
```

**Built-in factory methods:**

```swift
// Basic conditions
RouteCondition.always                          // Always matches
RouteCondition.never                           // Never matches
RouteCondition.contains("keyword")             // Substring match
RouteCondition.startsWith("prefix")            // Prefix match
RouteCondition.endsWith("suffix")              // Suffix match
RouteCondition.matches(pattern: "regex")       // Regex match
RouteCondition.lengthInRange(10...500)         // Length check
RouteCondition.contextHas(key: "userId")       // Context key exists

// Combinators
condition.not                                  // Negation
condition.and(otherCondition)                  // Both must match
condition.or(otherCondition)                   // Either must match
RouteCondition.all(cond1, cond2, cond3)        // All must match
RouteCondition.any(cond1, cond2, cond3)        // Any must match
RouteCondition.exactly(2, of: [c1, c2, c3])   // Exact count must match
```

### DSL Route Helpers

```swift
// For use inside Router { ... } blocks
public func When(_ condition: RouteCondition, name: String? = nil,
    @OrchestrationBuilder _ content: () -> OrchestrationStep) -> RouteEntry
public func Otherwise(@OrchestrationBuilder _ content: () -> OrchestrationStep) -> RouteEntry
```

### `AgentRouter`

```swift
public actor AgentRouter: AgentRuntime {
    public init(
        routes: [Route],
        fallbackAgent: (any AgentRuntime)? = nil,
        configuration: AgentConfiguration = .init(),
        handoffs: [AnyHandoffConfiguration] = []
    )

    // With result builder
    public init(
        fallbackAgent: (any AgentRuntime)? = nil,
        configuration: AgentConfiguration = .init(),
        @RouteBuilder routes: () -> [Route]
    )
}
```

### `AgentSequence`

```swift
public actor AgentSequence: AgentRuntime {
    public init(
        name: String = "Sequence",
        agents: [any AgentRuntime],
        configuration: AgentConfiguration = .init()
    )
}
```

---

## 8. Memory

### `Memory` Protocol

All memory types are actors — thread-safe by design:

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

### `MemoryMessage`

```swift
public struct MemoryMessage: Sendable, Codable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public let role: Role
    public let content: String
    public let timestamp: Date
    public let metadata: [String: SendableValue]?
    public let toolCallId: String?
    public let toolCalls: [ToolCall]?

    public enum Role: String, Sendable, Codable, Equatable, Hashable {
        case system
        case user
        case assistant
        case tool
    }

    public init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date(),
        metadata: [String: SendableValue]? = nil,
        toolCallId: String? = nil,
        toolCalls: [ToolCall]? = nil
    )
}
```

### `ConversationMemory` — Token-Limited Buffer

```swift
public actor ConversationMemory: Memory {
    public init(
        maxTokens: Int = 4096,
        tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator(),
        truncationStrategy: TruncationStrategy = .dropOldest
    )

    // Memory protocol
    public var count: Int
    public var isEmpty: Bool
    public func add(_ message: MemoryMessage) async
    public func context(for query: String, tokenLimit: Int) async -> String
    public func allMessages() async -> [MemoryMessage]
    public func clear() async

    // Diagnostics
    public func diagnostics() async -> ConversationMemoryDiagnostics
}

public enum TruncationStrategy: String, Sendable, Codable {
    case dropOldest        // Remove oldest messages first
    case dropNewest        // Remove newest messages first
    case summarize         // Summarize overflow messages
}
```

### `SlidingWindowMemory` — Fixed Message Count

```swift
public actor SlidingWindowMemory: Memory {
    public init(
        windowSize: Int = 20,
        preserveSystemMessages: Bool = true
    )

    public func diagnostics() async -> SlidingWindowDiagnostics
}
```

### `VectorMemory` — Semantic Search

Uses SIMD cosine similarity via Accelerate (no network calls):

```swift
public actor VectorMemory: Memory {
    public init(
        embeddingProvider: any EmbeddingProvider,
        maxResults: Int = 5,
        similarityThreshold: Double = 0.7,
        maxStoredMessages: Int = 1000
    )

    // Additional API
    public func search(query: String, limit: Int?) async throws -> [MemoryMessage]
    public func diagnostics() async -> VectorMemoryDiagnostics
}

public protocol EmbeddingProvider: Sendable {
    func embed(_ text: String) async throws -> [Float]
    func embedBatch(_ texts: [String]) async throws -> [[Float]]
    var dimensions: Int { get }
}
```

### `SummaryMemory` — LLM-Compressed History

```swift
public actor SummaryMemory: Memory {
    public init(
        summarizer: any Summarizer,
        maxMessages: Int = 50,
        summaryThreshold: Int = 30
    )

    public func diagnostics() async -> SummaryMemoryDiagnostics
}

public protocol Summarizer: Sendable {
    func summarize(messages: [MemoryMessage]) async throws -> String
}

// Built-in summarizers
public actor InferenceProviderSummarizer: Summarizer {
    public init(provider: any InferenceProvider, instructions: String?)
}

public struct TruncatingSummarizer: Summarizer, Sendable {
    public init(maxLength: Int = 500)
}

public struct FallbackSummarizer: Summarizer, Sendable {
    public init(primary: any Summarizer, fallback: any Summarizer)
}
```

### `PersistentMemory` — Durable Storage

```swift
public actor PersistentMemory: Memory {
    public init(backend: any PersistentMemoryBackend)
}

public protocol PersistentMemoryBackend: Actor, Sendable {
    func save(_ message: MemoryMessage) async throws
    func loadAll() async throws -> [MemoryMessage]
    func delete(_ messageId: UUID) async throws
    func deleteAll() async throws
    func count() async throws -> Int
}

// Built-in backends
public actor InMemoryBackend: PersistentMemoryBackend { ... }

// SwiftData-backed (macOS 14+ / iOS 17+)
public actor SwiftDataBackend: PersistentMemoryBackend {
    public init(modelContainer: ModelContainer)
}
```

### `CompositeMemory` — Combine Multiple Memories

```swift
public actor CompositeMemory: Memory {
    public init(
        memories: [any Memory],
        mergeStrategy: MemoryMergeStrategy = .interleave
    )
}

public enum MemoryMergeStrategy: Sendable {
    case interleave         // Merge by timestamp
    case sequential         // Concatenate in order
    case prioritized        // Use priority hints
}
```

### `HybridMemory` — Conversation + Vector

```swift
public actor HybridMemory: Memory {
    public init(
        conversationMemory: ConversationMemory,
        vectorMemory: VectorMemory,
        contextMode: ContextMode = .combined
    )

    public func diagnostics() async -> HybridMemoryDiagnostics
}

public enum ContextMode: Sendable, Equatable {
    case conversationOnly
    case vectorOnly
    case combined            // Conversation context + relevant vector results
}
```

### `WaxMemory` — Wax-Integrated Vector Memory

```swift
public actor WaxMemory: Memory, MemoryPromptDescriptor, MemorySessionLifecycle {
    public init(
        embeddingProvider: any EmbeddingProvider,
        maxResults: Int = 5,
        similarityThreshold: Double = 0.7
    )
}
```

### Sessions

```swift
public protocol Session: Actor, Sendable {
    var id: String { get }
    var metadata: SessionMetadata { get async }

    func addMessage(_ message: MemoryMessage) async
    func messages() async -> [MemoryMessage]
    func clear() async
    func updateMetadata(_ metadata: SessionMetadata) async
}

public struct SessionMetadata: Sendable, Equatable {
    public var title: String?
    public var createdAt: Date
    public var lastActiveAt: Date
    public var customData: [String: SendableValue]
}

// Built-in sessions
public actor InMemorySession: Session {
    public init(id: String = UUID().uuidString)
}

// SwiftData-backed persistent session (iOS 17+, macOS 14+)
public actor PersistentSession: Session {
    public init(id: String, backend: any PersistentMemoryBackend)
}
```

### `SwiftDataMemory` — SwiftData Persistence (iOS 17+)

```swift
@available(iOS 17, macOS 14, watchOS 10, tvOS 17, *)
public actor SwiftDataMemory: Memory {
    public init(modelContainer: ModelContainer)
}
```

### Additional Summarizers

```swift
// Apple Foundation Models on-device summarizer (iOS 26+, macOS 26+)
@available(iOS 26.0, macOS 26.0, *)
public struct FoundationModelsSummarizer: Summarizer { ... }
```

### Token Estimators

```swift
public protocol TokenEstimator: Sendable {
    func estimateTokens(_ text: String) -> Int
}

public struct CharacterBasedTokenEstimator: TokenEstimator, Sendable {
    public init(charactersPerToken: Double = 4.0)
}

public struct WordBasedTokenEstimator: TokenEstimator, Sendable {
    public init(tokensPerWord: Double = 1.3)
}

public struct AveragingTokenEstimator: TokenEstimator, Sendable {
    public init(estimators: [any TokenEstimator])
}
```

### Memory Builder

```swift
public struct MemoryBuilder {
    public static func conversation(maxTokens: Int = 4096) -> ConversationMemory
    public static func slidingWindow(size: Int = 20) -> SlidingWindowMemory
    public static func vector(provider: any EmbeddingProvider) -> VectorMemory
    public static func summary(summarizer: any Summarizer) -> SummaryMemory
    public static func persistent(backend: any PersistentMemoryBackend) -> PersistentMemory
    public static func composite(_ memories: [any Memory]) -> CompositeMemory
    public static func hybrid(conversation: ConversationMemory, vector: VectorMemory) -> HybridMemory
}
```

### Embedding Utilities

```swift
public enum EmbeddingUtils {
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float
    public static func normalize(_ vector: [Float]) -> [Float]
}

public struct MockEmbeddingProvider: EmbeddingProvider {
    public init(dimensions: Int = 384)
}

// Wax integration adapters
public struct SwarmEmbeddingProviderAdapter: EmbeddingProvider { ... }
public struct WaxEmbeddingProviderAdapter: WaxVectorSearch.EmbeddingProvider { ... }
public struct WaxIntegration { ... }
```

### Memory Protocols (Extended)

```swift
public protocol MemoryPromptDescriptor: Sendable {
    func promptDescription() async -> String
}

public protocol MemorySessionLifecycle: Memory {
    func startSession(id: String) async
    func endSession() async
}

public protocol VectorMemoryConfigurable: Memory {
    func updateSimilarityThreshold(_ threshold: Double) async
    func updateMaxResults(_ maxResults: Int) async
}
```

---

## 9. Guardrails

### Overview

Guardrails validate input, output, and tool interactions at three levels:

```
Input → [InputGuardrails] → Agent Processing → [OutputGuardrails] → Output
                               ↕
                    [ToolInput/OutputGuardrails]
```

### Core Types

```swift
// Marker protocol
public protocol Guardrail: Sendable {}

// Result of a guardrail check
public struct GuardrailResult: Sendable, Equatable {
    public let passed: Bool
    public let tripwireTriggered: Bool
    public let message: String?
    public let outputInfo: SendableValue?

    public static func passed() -> GuardrailResult
    public static func failed(message: String) -> GuardrailResult
    public static func tripwire(message: String, outputInfo: SendableValue? = nil) -> GuardrailResult
}

public enum GuardrailType: String, Sendable, Codable {
    case input, output, toolInput, toolOutput
}
```

### Input Guardrails

```swift
public protocol InputGuardrail: Guardrail {
    var name: String { get }
    func validate(input: String, context: AgentContext?) async throws -> GuardrailResult
}

// Closure-based
public struct ClosureInputGuardrail: InputGuardrail, Sendable {
    public init(name: String, validate: @escaping @Sendable (String, AgentContext?) async throws -> GuardrailResult)

    // Presets
    public static func maxLength(_ length: Int, name: String = "MaxLength") -> ClosureInputGuardrail
    public static func notEmpty(name: String = "NotEmpty") -> ClosureInputGuardrail
}

// Lightweight variant
public struct InputGuard: InputGuardrail, Sendable {
    public init(name: String, check: @escaping @Sendable (String) async throws -> Bool, message: String = "Input validation failed")
}

// Builder
public struct InputGuardrailBuilder: Sendable {
    public init()
    public func name(_ name: String) -> Self
    public func validate(_ handler: @escaping @Sendable (String, AgentContext?) async throws -> GuardrailResult) -> Self
    public func build() -> ClosureInputGuardrail
}
```

### Output Guardrails

```swift
public protocol OutputGuardrail: Guardrail {
    var name: String { get }
    func validate(output: String, context: AgentContext?) async throws -> GuardrailResult
}

public struct ClosureOutputGuardrail: OutputGuardrail, Sendable {
    public init(name: String, validate: @escaping @Sendable (String, AgentContext?) async throws -> GuardrailResult)

    public static func maxLength(_ length: Int, name: String = "MaxLength") -> ClosureOutputGuardrail
}

public struct OutputGuard: OutputGuardrail, Sendable {
    public init(name: String, check: @escaping @Sendable (String) async throws -> Bool, message: String = "Output validation failed")
}

public struct OutputGuardrailBuilder: Sendable { ... }
```

### Tool Guardrails

```swift
public protocol ToolInputGuardrail: Sendable {
    var name: String { get }
    func validate(toolName: String, arguments: [String: SendableValue], context: AgentContext?) async throws -> GuardrailResult
}

public protocol ToolOutputGuardrail: Sendable {
    var name: String { get }
    func validate(toolName: String, result: SendableValue, context: AgentContext?) async throws -> GuardrailResult
}

public struct ClosureToolInputGuardrail: ToolInputGuardrail { ... }
public struct ClosureToolOutputGuardrail: ToolOutputGuardrail { ... }
public struct ToolInputGuardrailBuilder: Sendable { ... }
public struct ToolOutputGuardrailBuilder: Sendable { ... }
```

### `GuardrailRunner`

```swift
public actor GuardrailRunner {
    public init(configuration: GuardrailRunnerConfiguration = .default)

    public func runInputGuardrails(_ guardrails: [any InputGuardrail], input: String, context: AgentContext?) async throws -> [GuardrailExecutionResult]
    public func runOutputGuardrails(_ guardrails: [any OutputGuardrail], output: String, context: AgentContext?) async throws -> [GuardrailExecutionResult]
    public func runToolInputGuardrails(_ guardrails: [any ToolInputGuardrail], toolName: String, arguments: [String: SendableValue], context: AgentContext?) async throws -> [GuardrailExecutionResult]
    public func runToolOutputGuardrails(_ guardrails: [any ToolOutputGuardrail], toolName: String, result: SendableValue, context: AgentContext?) async throws -> [GuardrailExecutionResult]
}

public struct GuardrailRunnerConfiguration: Sendable, Equatable {
    public var runInParallel: Bool      // Default: false
    public var stopOnFirstTripwire: Bool // Default: true

    public static let `default`: Self    // Sequential, stop on first
    public static let parallel: Self     // Parallel, stop on first
}

public struct GuardrailExecutionResult: Sendable, Equatable {
    public let guardrailName: String
    public let result: GuardrailResult
    public let duration: Duration
}
```

### `GuardrailError`

```swift
public enum GuardrailError: Error, Sendable, LocalizedError, Equatable {
    case inputTripwireTriggered(guardrailName: String, message: String?, outputInfo: SendableValue?)
    case outputTripwireTriggered(guardrailName: String, message: String?, outputInfo: SendableValue?)
    case toolInputTripwireTriggered(guardrailName: String, toolName: String, message: String?)
    case toolOutputTripwireTriggered(guardrailName: String, toolName: String, message: String?)
    case validationFailed(String)
}
```

### Example: Complete Guardrail Setup

```swift
let agent = Agent(
    name: "SafeBot",
    instructions: "You are a helpful assistant.",
    inputGuardrails: [
        ClosureInputGuardrail.notEmpty(),
        ClosureInputGuardrail.maxLength(10_000),
        ClosureInputGuardrail(name: "NoPII") { input, _ in
            if input.contains(where: { $0.isNumber }) && input.count > 10 {
                return .tripwire(message: "Possible PII detected")
            }
            return .passed()
        }
    ],
    outputGuardrails: [
        ClosureOutputGuardrail.maxLength(50_000),
        OutputGuard(name: "NoSecrets", check: { !$0.contains("sk-") })
    ]
)
```

---

## 10. Resilience

### `RetryPolicy`

```swift
public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let backoff: BackoffStrategy
    public let shouldRetry: @Sendable (Error) -> Bool
    public let onRetry: (@Sendable (Int, Error) async -> Void)?

    public init(
        maxAttempts: Int = 3,
        backoff: BackoffStrategy = .exponential(base: 1.0, multiplier: 2.0, maxDelay: 60.0),
        shouldRetry: @escaping @Sendable (Error) -> Bool = { _ in true },
        onRetry: (@Sendable (Int, Error) async -> Void)? = nil
    )

    public func execute<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T
}
```

**Presets:**

```swift
extension RetryPolicy {
    public static let noRetry: RetryPolicy           // 0 retries
    public static let standard: RetryPolicy          // 3 retries, exp backoff (1→2→4s, max 60s)
    public static let aggressive: RetryPolicy        // 5 retries, exp+jitter (0.5s base, max 30s)
}
```

**Factories:**

```swift
extension RetryPolicy {
    public static func fixed(maxAttempts: Int, delay: TimeInterval) -> RetryPolicy
    public static func exponentialBackoff(maxAttempts: Int, baseDelay: TimeInterval, maxDelay: TimeInterval, multiplier: Double, jitter: Bool) -> RetryPolicy
    public static func decorrelatedJitter(maxAttempts: Int, baseDelay: TimeInterval, maxDelay: TimeInterval) -> RetryPolicy
    public static func linear(maxAttempts: Int, initialDelay: TimeInterval, increment: TimeInterval, maxDelay: TimeInterval) -> RetryPolicy
    public static func immediate(maxAttempts: Int) -> RetryPolicy
}

public typealias Retry = RetryPolicy
```

### `BackoffStrategy`

```swift
public enum BackoffStrategy: Sendable {
    case fixed(delay: TimeInterval)
    case linear(initial: TimeInterval, increment: TimeInterval, maxDelay: TimeInterval)
    case exponential(base: TimeInterval, multiplier: Double, maxDelay: TimeInterval)
    case exponentialWithJitter(base: TimeInterval, multiplier: Double, maxDelay: TimeInterval)
    case decorrelatedJitter(base: TimeInterval, maxDelay: TimeInterval)
    case immediate
    case custom(@Sendable (Int) -> TimeInterval)

    public func delay(for attempt: Int) -> TimeInterval
}
```

### `CircuitBreaker`

```swift
public actor CircuitBreaker {
    public enum State: Sendable, Equatable {
        case closed, open, halfOpen
    }

    public init(
        failureThreshold: Int = 5,
        successThreshold: Int = 2,
        resetTimeout: TimeInterval = 60.0,
        halfOpenMaxRequests: Int = 1
    )

    public var state: State { get async }
    public var statistics: Statistics { get async }

    public func execute<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T
    public func recordSuccess() async
    public func recordFailure() async
    public func reset() async
}

public struct Statistics: Sendable, Equatable {
    public let totalRequests: Int
    public let successCount: Int
    public let failureCount: Int
    public let consecutiveFailures: Int
    public let consecutiveSuccesses: Int
    public let lastFailureTime: Date?
    public let stateTransitions: Int
}
```

**State machine:**

```
Closed ──[failures ≥ threshold]──→ Open
  ↑                                  │
  │                      [timeout]   ↓
  │                              Half-Open
  │                            ↙        ↘
  │         [successes ≥ threshold]    [any failure]
  └──────────────────────────────        ↓
                                       Open
```

### `CircuitBreakerRegistry`

```swift
public actor CircuitBreakerRegistry {
    public init()

    public func breaker(named name: String, configure: ((inout Configuration) -> Void)?) async -> CircuitBreaker
    public func breaker(named name: String) async -> CircuitBreaker?
    public func removeBreaker(named name: String) async
    public func allBreakers() async -> [String: CircuitBreaker]
    public func reset() async

    public struct Configuration: Sendable {
        public var failureThreshold: Int
        public var successThreshold: Int
        public var resetTimeout: TimeInterval
        public var halfOpenMaxRequests: Int
    }
}
```

### `FallbackChain`

```swift
public struct FallbackChain<Output: Sendable>: Sendable {
    public init()

    public func attempt(name: String, operation: @escaping @Sendable () async throws -> Output) -> Self
    public func fallback(name: String, value: @escaping @Sendable () async -> Output) -> Self
    public func onFailure(_ handler: @escaping @Sendable (String, Error) async -> Void) -> Self
    public func execute() async throws -> ExecutionResult<Output>
}

public struct ExecutionResult<Output: Sendable>: Sendable {
    public let output: Output
    public let attemptName: String
    public let totalAttempts: Int
    public let errors: [StepError]
}

public struct StepError: Sendable, Equatable {
    public let stepName: String
    public let error: SendableErrorWrapper
}

public typealias Fallback = FallbackChain
```

### `RateLimiter`

```swift
public actor RateLimiter {
    public init(maxRequests: Int, perInterval: TimeInterval)

    public func acquire() async throws
    public func tryAcquire() async -> Bool
    public var availableTokens: Int { get async }
    public func reset() async
}
```

### `ResilientAgent` — Composed Resilience

```swift
public actor ResilientAgent: AgentRuntime {
    public init(
        base: any AgentRuntime,
        retryPolicy: RetryPolicy? = nil,
        circuitBreaker: CircuitBreaker? = nil,
        timeout: Duration? = nil,
        fallbackAgent: (any AgentRuntime)? = nil
    )
}
```

**Execution order:**
1. Timeout wrapper (if configured)
2. Circuit breaker check (if configured)
3. Retry policy (if configured)
4. Base agent execution
5. Fallback agent (if base fails and fallback available)

### `ResilienceError`

```swift
public enum ResilienceError: Error, Sendable, Equatable {
    case circuitBreakerOpen
    case maxRetriesExhausted(Int)
    case timeout(Duration)
    case rateLimitExceeded
    case allFallbacksFailed
}
```

---

## 11. Observability

### `Tracer` Protocol

All tracers are actors:

```swift
public protocol Tracer: Actor, Sendable {
    func record(event: TraceEvent) async
    func startSpan(name: String, attributes: [String: SendableValue]) async -> TraceSpan
    func endSpan(_ span: TraceSpan, status: SpanStatus) async
    func allEvents() async -> [TraceEvent]
    func allSpans() async -> [TraceSpan]
}
```

### `TraceEvent`

```swift
public struct TraceEvent: Sendable, Codable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public let kind: EventKind
    public let level: EventLevel
    public let message: String
    public let timestamp: Date
    public let source: SourceLocation?
    public let metadata: [String: SendableValue]?
    public let spanId: UUID?
}

public enum EventKind: String, Sendable, Codable, CaseIterable {
    case agentStart, agentEnd
    case toolStart, toolEnd
    case llmStart, llmEnd
    case handoff
    case guardrailTriggered
    case error
    case custom
    case thinking
    case iterationStart, iterationEnd
}

public enum EventLevel: Int, Sendable, Codable, Comparable, CaseIterable {
    case trace = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5
}
```

### `TraceSpan`

```swift
public struct TraceSpan: Sendable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public let name: String
    public let startTime: Date
    public var endTime: Date?
    public var status: SpanStatus
    public let parentId: UUID?
    public let attributes: [String: SendableValue]
    public var duration: Duration? { ... }
}

public enum SpanStatus: String, Sendable, Codable, CaseIterable {
    case active, completed, failed, cancelled
}
```

### Built-In Tracers

```swift
// In-memory storage for testing/debugging
public actor InMemoryTracer: Tracer { ... }   // (via BufferedTracer)

// Buffered with configurable retention
public actor BufferedTracer: Tracer {
    public init(maxEvents: Int = 10_000, maxSpans: Int = 1_000)
}

// Prints events to console
public actor ConsoleTracer: Tracer { ... }

// Pretty-printed console output
public actor PrettyConsoleTracer: Tracer {
    public init(verbosity: Verbosity = .normal)
}

public enum Verbosity: String, Sendable, Codable {
    case quiet, normal, verbose, debug
}

// Integrates with swift-log (cross-platform)
public actor SwiftLogTracer: Tracer {
    public init(label: String = "com.swarm.tracer", minimumLevel: EventLevel = .debug)
    public static func development() -> SwiftLogTracer   // Level .trace
    public static func production() -> SwiftLogTracer     // Level .info
}

// Apple unified logging + Instruments signposts (macOS/iOS only)
public actor OSLogTracer: Tracer {
    public init(subsystem: String, category: String, minimumLevel: EventLevel = .debug, emitSignposts: Bool = true)
    public static func `default`(subsystem: String) -> OSLogTracer
    public static func production(subsystem: String) -> OSLogTracer
    public static func debug(subsystem: String) -> OSLogTracer
}

// No-op (zero overhead)
public actor NoOpTracer: Tracer { ... }

// Combines multiple tracers
public actor CompositeTracer: Tracer {
    public init(tracers: [any Tracer])
}

// Type-erased tracer
public actor AnyTracer: Tracer {
    public init(_ tracer: any Tracer)
}
```

### `MetricsCollector`

```swift
public actor MetricsCollector: Tracer {
    public init()

    public func snapshot() async -> MetricsSnapshot
    public func reset() async
}

public struct MetricsSnapshot: Sendable, Codable, Equatable {
    public let totalEvents: Int
    public let eventsByKind: [String: Int]
    public let eventsByLevel: [String: Int]
    public let totalSpans: Int
    public let averageSpanDuration: Duration?
    public let errorCount: Int
    public let toolCallCount: Int
    public let llmCallCount: Int
}
```

### `PerformanceTracker`

```swift
public actor PerformanceTracker {
    public init()

    public func startTracking(label: String) async -> UUID
    public func stopTracking(id: UUID) async -> Duration
    public func metrics() async -> PerformanceMetrics
}

public struct PerformanceMetrics: Sendable, Equatable {
    public let totalOperations: Int
    public let averageDuration: Duration
    public let minDuration: Duration
    public let maxDuration: Duration
    public let p50Duration: Duration
    public let p95Duration: Duration
    public let p99Duration: Duration
}
```

### `TraceContext`

```swift
public actor TraceContext {
    public init(tracer: any Tracer)

    public func beginSpan(name: String, attributes: [String: SendableValue] = [:]) async -> TraceSpan
    public func endSpan(_ span: TraceSpan, status: SpanStatus = .completed) async
    public func record(event: TraceEvent) async
    public func withSpan<T: Sendable>(
        _ name: String,
        attributes: [String: SendableValue] = [:],
        operation: @Sendable () async throws -> T
    ) async throws -> T
}
```

### `TracingHelper`

```swift
public struct TracingHelper: Sendable {
    public static func traceAgentRun(
        tracer: (any Tracer)?,
        agentName: String,
        input: String,
        operation: @Sendable () async throws -> AgentResult
    ) async throws -> AgentResult
}
```

### Logging Categories

```swift
public enum Log {
    public static let agents: Logger         // Agent lifecycle events
    public static let memory: Logger         // Memory operations
    public static let tracing: Logger        // Tracing events
    public static let metrics: Logger        // Metrics collection
    public static let orchestration: Logger  // Orchestration flow
    public static let tools: Logger          // Tool execution
    public static let mcp: Logger            // MCP protocol
    public static let resilience: Logger     // Retry, circuit breaker
    public static let guardrails: Logger     // Guardrail checks
}
```

### Metrics Reporting

```swift
public protocol MetricsReporter: Sendable {
    func report(snapshot: MetricsSnapshot) async throws
}

public struct JSONMetricsReporter: MetricsReporter {
    public init(outputURL: URL)
    public func report(snapshot: MetricsSnapshot) async throws
}
```

---

## 12. MCP Integration

Swarm supports MCP (Model Context Protocol) in **two directions**:

1. **Client** (`Sources/Swarm/MCP/`) — Swarm consumes tools from external MCP servers
2. **Server** (`Sources/SwarmMCP/`) — Swarm exposes its tools to MCP clients

### MCP Client — Consuming External Tools

#### `MCPServer` Protocol

```swift
public protocol MCPServer: Sendable {
    var name: String { get }
    var capabilities: MCPCapabilities { get async }

    func initialize() async throws -> MCPCapabilities
    func close() async throws
    func listTools() async throws -> [ToolSchema]
    func callTool(name: String, arguments: [String: SendableValue]) async throws -> SendableValue
    func listResources() async throws -> [MCPResource]
    func readResource(uri: String) async throws -> MCPResourceContent
}

public enum MCPServerState: Sendable, Equatable {
    case disconnected, connecting, connected, failed(String)
}
```

#### `HTTPMCPServer` — HTTP Transport

```swift
public actor HTTPMCPServer: MCPServer {
    public init(
        name: String,
        baseURL: URL,
        apiKey: String? = nil,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0
    )

    // MCPServer protocol implementation
    public var capabilities: MCPCapabilities { get async }
    public func initialize() async throws -> MCPCapabilities
    public func close() async throws
    public func listTools() async throws -> [ToolSchema]
    public func callTool(name: String, arguments: [String: SendableValue]) async throws -> SendableValue
    public func listResources() async throws -> [MCPResource]
    public func readResource(uri: String) async throws -> MCPResourceContent
}
```

Features: exponential backoff retry, capability caching, JSON-RPC 2.0 protocol.

#### `MCPClient` — Multi-Server Manager

```swift
public actor MCPClient {
    public init()

    // Server management
    public func addServer(_ server: any MCPServer) async throws
    public func removeServer(named name: String) async
    public func server(named name: String) -> (any MCPServer)?

    // Tool aggregation (with caching)
    public func getAllTools() async throws -> [any AnyJSONTool]
    public func callTool(name: String, arguments: [String: SendableValue]) async throws -> SendableValue
    public func invalidateCache() async

    // Resource aggregation
    public func getAllResources() async throws -> [MCPResource]
    public func readResource(uri: String) async throws -> MCPResourceContent
}
```

**Caching:** Tools cached indefinitely (refreshed on `invalidateCache()`). Resources cached with 60-second TTL. Request deduplication prevents thundering herds.

**Name collision handling:** When two servers expose tools with the same name, the client prefixes them: `servername_toolname`.

#### `MCPToolBridge` — Schema-to-Tool Conversion

```swift
public actor MCPToolBridge {
    public init(client: MCPClient)

    public func bridgedTools() async throws -> [any AnyJSONTool]
    public func bridgedTool(named name: String) async throws -> (any AnyJSONTool)?
}
```

Creates `MCPBridgedTool` instances that delegate execution to the MCP server.

#### Protocol Types

```swift
public struct MCPRequest: Sendable, Codable, Equatable {
    public let jsonrpc: String     // "2.0"
    public let method: String
    public let params: [String: SendableValue]?
    public let id: String
}

public struct MCPResponse: Sendable, Codable, Equatable {
    public let jsonrpc: String
    public let result: SendableValue?
    public let error: MCPErrorObject?
    public let id: String
}

public struct MCPError: Error, Sendable, Equatable {
    public let code: Int           // JSON-RPC 2.0 error codes
    public let message: String
    public let data: SendableValue?
}

public struct MCPCapabilities: Sendable, Codable, Equatable {
    public let tools: Bool
    public let resources: Bool
    public let prompts: Bool
}

public struct MCPResource: Sendable, Codable, Equatable {
    public let uri: String
    public let name: String
    public let description: String?
    public let mimeType: String?
}

public struct MCPResourceContent: Sendable, Codable, Equatable {
    public let uri: String
    public let text: String?
    public let blob: Data?
    public let mimeType: String?
}
```

### MCP Server — Exposing Swarm Tools

#### `SwarmMCPServerService`

```swift
public actor SwarmMCPServerService {
    public init(
        toolCatalog: any SwarmMCPToolCatalog,
        toolExecutor: any SwarmMCPToolExecutor,
        serverInfo: ServerInfo = .init(name: "SwarmMCP", version: "1.0.0")
    )

    public func start() async throws
    public func stop() async throws

    // Metrics
    public var totalToolCalls: Int { get async }
    public var totalErrors: Int { get async }
    public var averageLatency: Duration { get async }
}
```

#### Tool Adapter Protocols

```swift
public protocol SwarmMCPToolCatalog: Sendable {
    func listTools() async throws -> [ToolSchema]
}

public protocol SwarmMCPToolExecutor: Sendable {
    func executeTool(named toolName: String, arguments: [String: SendableValue]) async throws -> SendableValue
}

// Default implementation using ToolRegistry
public struct SwarmMCPToolRegistryAdapter: SwarmMCPToolCatalog, SwarmMCPToolExecutor {
    public init(registry: ToolRegistry)
}
```

#### Value Mapping

```swift
public struct SwarmMCPToolMapper {
    public static func toMCPTool(_ schema: ToolSchema) -> MCPTool
    public static func toJSONSchema(_ parameters: [ToolParameter]) -> JSONObject
}

public struct SwarmMCPValueMapper {
    public static func toMCPValue(_ value: SendableValue) -> Value
    public static func fromMCPValue(_ value: Value) -> SendableValue
}

public struct SwarmMCPErrorMapper {
    public static func mapError(_ error: Error) -> SwarmMCPCallToolOutcome
}

public enum SwarmMCPCallToolOutcome {
    case success(SendableValue)
    case failure(String)
    case protocolError(MCPError)
}
```

---

## 13. Providers

### `InferenceProvider` Protocol

```swift
public protocol InferenceProvider: Sendable {
    func generate(prompt: String, options: InferenceOptions) async throws -> String
    func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error>
    func generateWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) async throws -> InferenceResponse
}
```

### `InferenceStreamingProvider`

```swift
public protocol InferenceStreamingProvider: Sendable {
    func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<InferenceStreamEvent, Error>
}

public enum InferenceStreamEvent: Sendable, Equatable {
    case text(String)
    case toolCall(InferenceResponse.ParsedToolCall)
    case usage(InferenceResponse.TokenUsage)
    case done
}
```

### `ToolCallStreamingInferenceProvider`

```swift
public protocol ToolCallStreamingInferenceProvider: InferenceProvider {
    func streamWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) -> AsyncThrowingStream<InferenceStreamUpdate, Error>
}

public enum InferenceStreamUpdate: Sendable, Equatable {
    case outputChunk(String)
    case toolCallPartial(PartialToolCallUpdate)
    case toolCallsCompleted([InferenceResponse.ParsedToolCall])
    case usage(InferenceResponse.TokenUsage)
}
```

### `InferenceOptions`

```swift
public struct InferenceOptions: Sendable, Equatable {
    public var temperature: Double?
    public var maxTokens: Int?
    public var topP: Double?
    public var topK: Int?
    public var presencePenalty: Double?
    public var frequencyPenalty: Double?
    public var stopSequences: [String]?
    public var toolChoice: ToolChoice?
    public var seed: Int?
    public var parallelToolCalls: Bool?
    public var truncationStrategy: TruncationStrategy?
    public var verbosity: Verbosity?

    // Presets
    public static let creative: InferenceOptions       // temp 0.9
    public static let precise: InferenceOptions        // temp 0.1
    public static let balanced: InferenceOptions       // temp 0.7
    public static let codeGeneration: InferenceOptions // temp 0.2
    public static let chat: InferenceOptions           // temp 0.8
}
```

### `InferenceResponse`

```swift
public struct InferenceResponse: Sendable, Equatable {
    public let content: String?
    public let toolCalls: [ParsedToolCall]
    public let finishReason: FinishReason
    public let usage: TokenUsage?

    public struct ParsedToolCall: Sendable, Equatable {
        public let id: String?
        public let name: String
        public let arguments: [String: SendableValue]
    }

    public enum FinishReason: String, Sendable, Equatable {
        case completed, toolCall, maxTokens, contentFilter, cancelled
    }

    public struct TokenUsage: Sendable, Equatable, Codable {
        public let promptTokens: Int?
        public let completionTokens: Int?
        public let totalTokens: Int?
    }
}
```

### `LLM` — Quick Provider Setup

```swift
public enum LLM: Sendable, InferenceProvider {
    case openAI(OpenAIConfig)
    case anthropic(AnthropicConfig)
    case openRouter(OpenRouterConfig)

    // Convenience factories
    public static func openAI(apiKey: String, model: String = "gpt-4o-mini") -> LLM
    public static func anthropic(apiKey: String, model: String = "claude-3-5-sonnet-20241022") -> LLM
    public static func openRouter(apiKey: String, model: String) -> LLM
}
```

Each case wraps a Conduit provider via `ConduitInferenceProvider`.

### `ConduitInferenceProvider` — Conduit Bridge

```swift
public struct ConduitInferenceProvider<Provider: Conduit.TextGenerator>: InferenceProvider, ToolCallStreamingInferenceProvider {
    public init(provider: Provider)

    // Maps InferenceOptions → Conduit.GenerateConfig
    // Converts ToolSchema → Conduit.ToolDefinition
    // Converts Conduit.ToolCall → InferenceResponse.ParsedToolCall
}
```

### `ConduitProviderSelection`

```swift
public enum ConduitProviderSelection: Sendable, InferenceProvider {
    case provider(any InferenceProvider)

    public static func anthropic(apiKey: String, model: String) -> Self
    public static func openAI(apiKey: String, model: String) -> Self
    public static func openRouter(apiKey: String, model: String, routing: OpenRouterRouting?) -> Self
    public static func ollama(model: String, settings: OllamaSettings = .init()) -> Self
}
```

### `MultiProvider` — Prefix-Based Routing

```swift
public actor MultiProvider: InferenceProvider {
    public init(defaultProvider: any InferenceProvider)

    public func register(prefix: String, provider: any InferenceProvider) throws
    public func unregister(prefix: String)
    public func setModel(_ model: String)
    public func clearModel()
    public func hasProvider(for prefix: String) -> Bool
    public func provider(for prefix: String) -> (any InferenceProvider)?
    public var registeredPrefixes: [String] { get async }
}
```

**Routing logic:** `"anthropic/claude-3-5-sonnet"` → prefix `"anthropic"` → registered provider. No prefix → default provider.

```swift
let multi = MultiProvider(defaultProvider: openRouterProvider)
try await multi.register(prefix: "anthropic", provider: anthropicProvider)
try await multi.register(prefix: "openai", provider: openAIProvider)
await multi.setModel("anthropic/claude-3-5-sonnet")
// Routes to anthropicProvider
```

### `OpenRouterProvider`

```swift
public actor OpenRouterProvider: InferenceProvider, InferenceStreamingProvider {
    public init(configuration: OpenRouterConfiguration)
}

public struct OpenRouterConfiguration: Sendable {
    public var apiKey: String
    public var model: OpenRouterModel
    public var routing: OpenRouterRouting?
    public var baseURL: URL?
    public var retryStrategy: OpenRouterRetryStrategy?
    public var providerPreferences: OpenRouterProviderPreferences?
}

public struct OpenRouterModel: Sendable, Hashable, ExpressibleByStringLiteral {
    public let id: String
    public init(_ id: String)

    // Presets
    public static let claude35Sonnet: OpenRouterModel
    public static let gpt4o: OpenRouterModel
    public static let geminiPro: OpenRouterModel
    // ... many more
}

public struct OpenRouterRouting: Sendable, Hashable {
    public var providers: [Provider]?     // Preferred provider order
    public var fallbacks: Bool            // Default: true
    public var routeByLatency: Bool       // Default: false
    public var siteURL: URL?
    public var appName: String?
    public var dataCollection: DataCollection?

    public enum Provider: String, Sendable, Hashable, CaseIterable {
        case openai, anthropic, google, googleAIStudio, together, fireworks,
             perplexity, mistral, groq, deepseek, cohere, ai21, bedrock, azure
    }
}
```

### `OllamaSettings`

```swift
public struct OllamaSettings: Sendable, Hashable {
    public var host: String = "localhost"
    public var port: Int = 11434
    public var keepAlive: String?
    public var pullOnMissing: Bool = false
    public var numGPU: Int?
    public var lowVRAM: Bool = false
    public var numCtx: Int?
    public var healthCheck: Bool = true
}
```

### Foundation Models Integration

On macOS 26+ / iOS 26+, Swarm automatically uses Apple Foundation Models as a fallback when no explicit provider is set:

```swift
// Internal — auto-detected
@available(macOS 26.0, iOS 26.0, *)
extension LanguageModelSession: InferenceProvider {
    // Supports: generate(), stream()
    // Does NOT support: generateWithToolCalls() (throws error)
}
```

### Environment Injection

```swift
// Set provider for an entire agent subtree
let agent = myAgent.environment(\.inferenceProvider, anthropicProvider)

// Set globally via TaskLocal
try await AgentEnvironmentValues.$current.withValue(
    AgentEnvironment(inferenceProvider: myProvider)
) {
    let result = try await agent.run("Hello")
}
```

---

## 14. Macros

Swarm provides 6 macros via the `SwarmMacros` compiler plugin:

### `@Tool` — Tool Protocol Conformance

Generates `AnyJSONTool` conformance from a struct with an `execute()` method.

```swift
@Tool
struct WeatherTool {
    @Parameter(description: "City name to check weather for")
    var city: String

    @Parameter(description: "Temperature unit", defaultValue: "celsius")
    var unit: String

    /// Get the current weather for a city.
    func execute() async throws -> String {
        return "72°F in \(city)"
    }
}
```

**Generated code:**
- `name` property (derived from struct name, converted to snake_case: `"weather_tool"`)
- `description` property (from doc comment on `execute()`)
- `schema` property (`ToolSchema` with parameters from `@Parameter` properties)
- `execute(arguments:)` method (deserializes `[String: SendableValue]` → typed properties → calls `execute()`)

**Supported parameter types:** `String`, `Int`, `Double`, `Bool`, `[String]`, `[Int]`, optional variants.

### `@Parameter` — Tool Parameter Marker

```swift
@attached(peer)
public macro Parameter(
    description: String,
    defaultValue: String? = nil
) = #externalMacro(module: "SwarmMacros", type: "ParameterMacro")
```

Marks stored properties as tool parameters. The macro extracts `description` and `defaultValue` for schema generation.

### `@AgentActor` — Agent Actor Generation

Generates a complete agent actor with builder pattern:

```swift
@AgentActor
actor ResearchAssistant {
    func process(input: String) async throws -> String {
        // Agent logic
        return "Research result for: \(input)"
    }
}
```

**Generated code:**
- `AgentRuntime` conformance (name, tools, instructions, configuration, memory, inferenceProvider, tracer)
- `run()`, `stream()`, `cancel()` methods
- Nested `Builder` class:

```swift
public struct Builder: Sendable {
    public init()
    public func tools(_ tools: [any AnyJSONTool]) -> Builder
    public func addTool(_ tool: some AnyJSONTool) -> Builder
    public func instructions(_ instructions: String) -> Builder
    public func configuration(_ configuration: AgentConfiguration) -> Builder
    public func memory(_ memory: any Memory) -> Builder
    public func inferenceProvider(_ provider: any InferenceProvider) -> Builder
    public func tracer(_ tracer: any Tracer) -> Builder
    public func build() -> Self
}
```

### `@Traceable` — Observability Wrapper

Generates a tracing wrapper around `execute()`:

```swift
@Traceable
struct DataFetchTool: Tool {
    func execute(input: String) async throws -> String {
        // ...
    }
}
```

**Generated code:**
- `executeWithTracing(arguments:tracer:)` method
- Records start time, duration, arguments, and results
- Emits `TraceEvent` for observability
- Handles success and error cases

### `#Prompt` — Type-Safe Prompt Building

Freestanding expression macro for compile-time validated prompts:

```swift
let prompt = #Prompt("You are \(role). Help with: \(task)")

let systemPrompt = #Prompt("""
    You are \(agentRole).
    Available tools: \(toolNames).
    User query: \(input)
""")
```

**Returns:** `PromptString` — a type that captures interpolation safely.

```swift
public struct PromptString: Sendable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible {
    public var description: String { content }
}
```

### `@Builder` — Fluent Setter Generation

Generates copy-on-write fluent setters for all stored `var` properties:

```swift
@Builder
public struct AgentOptions {
    public var timeout: Duration = .seconds(30)
    public var maxRetries: Int = 3
    public var enableLogging: Bool = true
}
```

**Generated code:**

```swift
@discardableResult
public func timeout(_ value: Duration) -> Self {
    var copy = self
    copy.timeout = value
    return copy
}

@discardableResult
public func maxRetries(_ value: Int) -> Self {
    var copy = self
    copy.maxRetries = value
    return copy
}

// ... for each var property
```

### Macro Plugin Entry Point

```swift
@main
struct SwarmMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ToolMacro.self,
        ParameterMacro.self,
        AgentMacro.self,
        TraceableMacro.self,
        PromptMacro.self,
        BuilderMacro.self
    ]
}
```

---

## 15. Hive Runtime

### Overview

Every `Orchestration { ... }` execution goes through the Hive runtime. `OrchestrationHiveEngine.makeGraph()` compiles `[OrchestrationStep]` into a HiveCore DAG. Even single-step orchestrations get Hive's checkpointing and interrupt/resume infrastructure.

The HiveSwarm bridge code lives in `Sources/Swarm/HiveSwarm/`.

### `HiveBackedAgent`

Wraps a Hive runtime as an `AgentRuntime`:

```swift
public struct HiveBackedAgent: AgentRuntime, Sendable {
    nonisolated public let tools: [any AnyJSONTool]
    nonisolated public let instructions: String
    nonisolated public let configuration: AgentConfiguration

    public init(
        runtime: HiveAgentsRuntime,
        name: String,
        instructions: String = "",
        threadID: HiveThreadID = HiveThreadID(UUID().uuidString),
        runOptions: HiveRunOptions = HiveRunOptions(maxSteps: 20, checkpointPolicy: .disabled),
        configuration: AgentConfiguration? = nil
    )

    // Execution
    public func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult
    public func stream(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) -> AsyncThrowingStream<AgentEvent, Error>
    public func cancel() async
}
```

**Event mapping** (HiveEvent → AgentEvent):

| HiveEvent | AgentEvent |
|-----------|------------|
| `.modelInvocationStarted` | `.llmStarted` |
| `.modelToken` | `.outputToken` |
| `.modelInvocationFinished` | `.llmCompleted` |
| `.toolInvocationStarted` | `.toolCallStarted` |
| `.toolInvocationFinished` | `.toolCallCompleted` or `.toolCallFailed` |
| `.stepStarted` | `.iterationStarted` |
| `.stepFinished` | `.iterationCompleted` |

### `HiveAgentsRuntime`

```swift
public struct HiveAgentsRuntime: Sendable {
    public let runControl: HiveAgentsRunController
}

public struct HiveAgentsRunController: Sendable {
    public let runtime: HiveRuntime<HiveAgents.Schema>

    public func start(_ request: HiveAgentsRunStartRequest) async throws -> HiveRunHandle<HiveAgents.Schema>
    public func resume(_ request: HiveAgentsRunResumeRequest) async throws -> HiveRunHandle<HiveAgents.Schema>
}
```

### `HiveAgentsRunStartRequest` / `HiveAgentsRunResumeRequest`

```swift
public struct HiveAgentsRunStartRequest: Sendable {
    public let threadID: HiveThreadID
    public let input: String
    public let tools: [any AnyJSONTool]
    public let systemPrompt: String?
    public let runOptions: HiveRunOptions
}

public struct HiveAgentsRunResumeRequest: Sendable {
    public let threadID: HiveThreadID
    public let resumeToken: ResumeToken
    public let additionalInput: String?
}
```

### `ResumeToken`

```swift
public struct ResumeToken: ~Copyable, Sendable {
    // Move-only type — prevents accidental double-resume
    // Obtained from workflow interrupts
}
```

### Hive Graph Structure

The Hive tool-using chat agent graph:

```
preModel (message compaction, hook transform)
   ↓
model (LLM invocation with tool definitions)
   ↓
[router] pending tools?
   ├─YES→ tools (tool approval check)
   │       ↓
   │    toolExecute (invoke tools, transform results)
   │       ↓
   │    [loop back to model]
   └─NO→ [end]
```

### `SwarmToolRegistry` — Hive Tool Bridge

```swift
public struct SwarmToolRegistry: HiveToolRegistry, Sendable {
    public init(tools: [any AnyJSONTool]) throws
    public static func fromRegistry(_ registry: ToolRegistry) async throws -> Self

    public func listTools() -> [HiveToolDefinition]
    public func invoke(_ call: HiveToolCall) async throws -> HiveToolResult
}
```

Converts Swarm `ToolSchema` → Hive `HiveToolDefinition` with JSON schema mapping:

| Swarm Type | JSON Schema |
|-----------|-------------|
| `.string` | `{"type": "string"}` |
| `.int` | `{"type": "integer"}` |
| `.double` | `{"type": "number"}` |
| `.bool` | `{"type": "boolean"}` |
| `.array(elem)` | `{"type": "array", "items": ...}` |
| `.object(props)` | `{"type": "object", "properties": ...}` |
| `.oneOf(opts)` | `{"type": "string", "enum": [...]}` |
| `.any` | `{"anyOf": [...]}` |

### `RetryPolicyBridge`

Converts Swarm retry policies to Hive retry policies (stripping jitter for determinism):

```swift
public enum RetryPolicyBridge {
    public static func toHive(_ policy: RetryPolicy) -> HiveRetryPolicy
}
```

| Swarm Strategy | Hive Strategy |
|---------------|---------------|
| `.exponential(base, mult, max)` | `.exponentialBackoff(initial, factor, max)` |
| `.exponentialWithJitter` | Strip jitter → `.exponentialBackoff` |
| `.decorrelatedJitter` | Approximate with factor=2.0 |
| `.fixed(delay)` | `.exponentialBackoff(initial, factor: 1.0)` |
| `.linear` | Approximate with factor=1.5 |
| `.immediate` | `.exponentialBackoff(initial: 0, factor: 1.0)` |
| `.custom` | Fallback defaults (1s, 2x, 60s max) |

### `HiveAgents` — Schema & Context

```swift
public enum HiveAgents {
    // Schema channels
    public static let messagesKey: HiveChannelKey<Schema, [HiveChatMessage]>
    public static let pendingToolCallsKey: HiveChannelKey<Schema, [HiveToolCall]>
    public static let finalAnswerKey: HiveChannelKey<Schema, String?>
    public static let llmInputMessagesKey: HiveChannelKey<Schema, [HiveChatMessage]?>
}

public struct HiveAgentsContext: Sendable {
    public let modelName: String
    public let toolApprovalPolicy: HiveAgentsToolApprovalPolicy
    public let compactionPolicy: HiveCompactionPolicy?
    public let tokenizer: (any HiveTokenizer)?
    public let retryPolicy: HiveRetryPolicy?
}

public enum HiveAgentsToolApprovalPolicy: Sendable, Equatable {
    case never               // Auto-approve all
    case always              // Require approval for all
    case allowList(Set<String>)  // Only these tools auto-approved
}
```

### `HiveCodableJSONCodec`

Deterministic JSON serialization for checkpoint hashing:

```swift
public struct HiveCodableJSONCodec<Value: Codable & Sendable>: HiveCodec, Sendable {
    public init(id: String? = nil)
    public func encode(_ value: Value) throws -> Data   // sortedKeys, withoutEscapingSlashes
    public func decode(_ data: Data) throws -> Value
}
```

### Hive Extension Hooks

```swift
// Transform messages before model invocation
public protocol HiveAgentsPreModelHook: Sendable {
    func transform(messages: [HiveChatMessage], systemPrompt: String?) async -> ([HiveChatMessage], String?)
}

// Custom message ID generation
public protocol HiveAgentsMessageIDFactory: Sendable {
    func makeID() -> String
}

// Transform tool results before adding to history
public protocol HiveAgentsToolResultTransformer: Sendable {
    func transform(toolName: String, result: String) async -> String
}

// No-op defaults
public struct HiveAgentsNoopPreModelHook: HiveAgentsPreModelHook { ... }
public struct HiveAgentsDefaultMessageIDFactory: HiveAgentsMessageIDFactory { ... }
public struct HiveAgentsNoopToolResultTransformer: HiveAgentsToolResultTransformer { ... }
```

### Workflow Execution & Interrupts

```swift
public enum WorkflowExecutionOutcome: Sendable {
    case completed(AgentResult)
    case interrupted(WorkflowInterruptReason, ResumeToken)
    case failed(Error)
}

public enum WorkflowInterruptReason: Sendable, Equatable {
    case humanApprovalRequired(String)
    case budgetExceeded
    case safetyCheck(String)
    case custom(String)
}

public enum WorkflowCheckpointPolicy: Sendable, Equatable {
    case disabled
    case everyStep
    case everyNSteps(Int)
    case onInterrupt
}

public struct WorkflowResumeHandle: Sendable {
    public let workflowId: String
    public let resumeToken: ResumeToken
    public func resume(additionalInput: String?) async throws -> WorkflowExecutionOutcome
}
```

### Human Approval

```swift
public protocol HumanApprovalHandler: Sendable {
    func requestApproval(_ request: ApprovalRequest) async throws -> ApprovalResponse
}

public struct ApprovalRequest: Sendable {
    public let toolName: String
    public let arguments: [String: SendableValue]
    public let context: String?
}

public enum ApprovalResponse: Sendable {
    case approved
    case denied(reason: String?)
    case modifiedAndApproved([String: SendableValue])
}

// Auto-approves everything
public struct AutoApproveHandler: HumanApprovalHandler { ... }
```

---

## Appendix A: Complete Type Index

### Actors (54)

`Agent`, `AgentContext`, `AgentRouter`, `AgentSequence`, `AnyMemory`, `AnyTracer`, `BlueprintAgent`, `BufferedTracer`, `ChannelBagStorage`, `ChatAgent`, `CircuitBreaker`, `CircuitBreakerRegistry`, `CompositeMemory`, `CompositeTracer`, `ConditionalFallback`, `ConsoleTracer`, `ConversationMemory`, `FileSystemWorkflowCheckpointStore`, `GuardrailRunner`, `HandoffCoordinator`, `HTTPMCPServer`, `HybridMemory`, `InferenceProviderSummarizer`, `InMemoryBackend`, `InMemorySession`, `InMemoryWorkflowCheckpointStore`, `LoopAgent`, `MCPClient`, `MCPToolBridge`, `MetricsCollector`, `MultiProvider`, `NoOpTracer`, `OpenRouterProvider`, `ParallelComposition`, `ParallelGroup`, `ParallelToolExecutor`, `PerformanceTracker`, `PersistentMemory`, `PlanAndExecuteAgent`, `PrettyConsoleTracer`, `RateLimiter`, `ReActAgent`, `ResilientAgent`, `ResponseTracker`, `SequentialChain`, `SlidingWindowMemory`, `SummaryMemory`, `SupervisorAgent`, `SwarmRunner`, `SwiftLogTracer`, `ToolRegistry`, `TraceContext`, `VectorMemory`, `WaxMemory`

### Structs (170+)

`AgentConfiguration`, `AgentDescription`, `AgentEnvironment`, `AgentResponse`, `AgentResult`, `AgentStep`, `AgentTool`, `AnyAgent`, `AnyHandoffConfiguration`, `AnyJSONToolAdapter`, `AnyTool`, `ApprovalRequest`, `AutoApproveHandler`, `AveragingTokenEstimator`, `Branch`, `CallableAgent`, `CharacterBasedTokenEstimator`, `CircularBuffer`, `ClosureInputGuardrail`, `ClosureOutputGuardrail`, `ClosureToolInputGuardrail`, `ClosureToolOutputGuardrail`, `CompositeRunHooks`, `ConduitInferenceProvider`, `ContextBucketCaps`, `ContextBudget`, `ContextKey`, `ContextProfile`, `ConversationMemoryDiagnostics`, `DAG`, `DAGNode`, `DateTimeTool`, `EnvironmentAgent`, `ErrorInfo`, `ExecutionPlan`, `ExecutionResult`, `FallbackChain`, `FallbackStep`, `FallbackSummarizer`, `FunctionTool`, `Guard`, `GuardrailExecutionResult`, `GuardrailResult`, `GuardrailRunnerConfiguration`, `HandoffBuilder`, `HandoffConfiguration`, `HandoffInputData`, `HandoffRequest`, `HandoffResult`, `HiveAgentsContext`, `HiveAgentsDefaultMessageIDFactory`, `HiveAgentsNoopPreModelHook`, `HiveAgentsNoopToolResultTransformer`, `HiveAgentsRunController`, `HiveAgentsRunResumeRequest`, `HiveAgentsRunStartRequest`, `HiveAgentsRuntime`, `HiveBackedAgent`, `HiveCodableJSONCodec`, `HiveCompactionPolicy`, `HiveStep`, `HumanApproval`, `HybridMemoryDiagnostics`, `InferenceOptions`, `InferencePolicy`, `InferenceResponse`, `InputGuard`, `InputGuardrailBuilder`, `Interrupt`, `JSONMetricsReporter`, `KeywordRoutingStrategy`, `LLMRoutingStrategy`, `LoggingModifier`, `LoggingRunHooks`, `Loop`, `MCPCapabilities`, `MCPError`, `MCPErrorObject`, `MCPRequest`, `MCPResource`, `MCPResourceContent`, `MCPResponse`, `MemoryBuilder`, `MemoryMessage`, `MetricsSnapshot`, `MockEmbeddingProvider`, `ModelSettings`, `ModifiedStep`, `NamedModifier`, `NoOpStep`, `OllamaSettings`, `OpenRouterConfiguration`, `OpenRouterModel`, `OpenRouterProviderPreferences`, `OpenRouterRetryStrategy`, `OpenRouterRouting`, `Orchestration`, `OrchestrationChannel`, `OrchestrationGroup`, `OrchestrationStepContext`, `OutputGuard`, `OutputGuardrailBuilder`, `OutputTransformer`, `Parallel`, `ParallelItem`, `PartialToolCallUpdate`, `PerformanceMetrics`, `Pipeline`, `PlanStep`, `PromptString`, `RepeatWhile`, `ResumeToken`, `RetryModifier`, `RetryPolicy`, `Route`, `RouteBranch`, `RouteCondition`, `Router`, `RoutingDecision`, `SendableErrorWrapper`, `Sequential`, `SessionMetadata`, `SlidingWindowDiagnostics`, `SourceLocation`, `Statistics`, `StepError`, `StringTool`, `SummaryMemoryDiagnostics`, `SwarmAgentProfile`, `SwarmEmbeddingProviderAdapter`, `SwarmHiveRunOptionsOverride`, `SwarmMCPToolRegistryAdapter`, `SwarmResponse`, `SwarmStreamChunk`, `SwarmToolCallDelta`, `SwarmToolRegistry`, `TimeoutModifier`, `TokenUsage`, `ToolArguments`, `ToolCall`, `ToolCallRecord`, `ToolChain`, `ToolConditional`, `ToolExecutionEngine`, `ToolExecutionResult`, `ToolFilter`, `ToolGuardrailData`, `ToolInputGuardrailBuilder`, `ToolOutputGuardrailBuilder`, `ToolParameter`, `ToolResult`, `ToolSchema`, `ToolStep`, `ToolTransform`, `TraceEvent`, `TraceSpan`, `TracingHelper`, `Transform`, `TruncatingSummarizer`, `VectorMemoryBuilder`, `VectorMemoryDiagnostics`, `WaxEmbeddingProviderAdapter`, `WaxIntegration`, `WordBasedTokenEstimator`, `WorkflowCheckpointState`, `WorkflowResumeHandle`

### Enums (60+)

`AgentContextKey`, `AgentEnvironmentValues`, `AgentError`, `AgentEvent`, `AgentEventStream`, `ApprovalResponse`, `BackoffStrategy`, `BuiltInTools`, `CacheRetention`, `ConduitProviderSelection`, `ContextMode`, `EmbeddingError`, `EmbeddingUtils`, `EventKind`, `EventLevel`, `GuardPhase`, `GuardrailError`, `GuardrailType`, `HiveAgents`, `HiveAgentsToolApprovalPolicy`, `InferenceStreamEvent`, `InferenceStreamUpdate`, `LLM`, `Log`, `MCPServerState`, `MemoryMergeStrategy`, `MemoryOperation`, `MemoryPriority`, `MemoryPriorityHint`, `MergeErrorStrategy`, `MergeStrategies`, `MetricsReporterError`, `ModelSettingsValidationError`, `MultiProviderError`, `OpenRouterProviderError`, `OpenRouterRoutingStrategy`, `OpenRouterToolChoice`, `OrchestrationError`, `OrchestrationValidationError`, `ParallelErrorHandling`, `ParallelExecutionErrorStrategy`, `ParallelMergeStrategy`, `PersistentMemoryError`, `PipelineError`, `ResilienceError`, `RetrievalStrategy`, `RetryPolicyBridge`, `SendableValue`, `SessionError`, `SpanStatus`, `StepStatus`, `StreamHelper`, `SummarizerError`, `Swarm`, `SwarmError`, `SwarmToolRegistryError`, `ToolChainError`, `ToolChoice`, `TruncationStrategy`, `TypedParallel`, `VectorMemoryError`, `Verbosity`, `WorkflowCheckpointPolicy`, `WorkflowExecutionOutcome`, `WorkflowInterruptReason`

### Protocols (40+)

`AgentBlueprint`, `AgentComponent`, `AgentContextProviding`, `AgentLoop`, `AgentLoopDefinition`, `AgentRuntime`, `AnyJSONTool`, `EmbeddingProvider`, `Guardrail`, `HandoffReceiver`, `HiveAgentsMessageIDFactory`, `HiveAgentsPreModelHook`, `HiveAgentsToolResultTransformer`, `HiveTokenizer`, `HumanApprovalHandler`, `InferenceProvider`, `InferenceStreamingProvider`, `InputGuardrail`, `MCPServer`, `Memory`, `MemoryPromptDescriptor`, `MemorySessionLifecycle`, `MetricsReporter`, `OrchestrationStep`, `OrchestratorProtocol`, `OutputGuardrail`, `PersistentMemoryBackend`, `ResultMergeStrategy`, `RoutingStrategy`, `RunHooks`, `Session`, `StepModifier`, `Summarizer`, `TokenEstimator`, `Tool`, `ToolCallGoal`, `ToolCallStreamingInferenceProvider`, `ToolChainStep`, `ToolInputGuardrail`, `ToolOutputGuardrail`, `Tracer`, `VectorMemoryConfigurable`, `WorkflowCheckpointStore`

### Result Builders (6)

`OrchestrationBuilder`, `ParallelBuilder`, `DAGBuilder`, `RouteBuilder`, `RouterBuilder`, `ToolArrayBuilder`, `ToolChainBuilder`, `ToolParameterBuilder`, `GuardrailBuilder`, `AgentLoopBuilder`

### Macros (6)

`@Tool`, `@Parameter`, `@AgentActor`, `@Traceable`, `#Prompt`, `@Builder`

---

## Appendix B: Error Reference

| Error Type | Context |
|-----------|---------|
| `AgentError` | Agent execution failures |
| `OrchestrationError` | Orchestration step failures |
| `OrchestrationValidationError` | DAG validation failures |
| `GuardrailError` | Guardrail tripwire violations |
| `ResilienceError` | Retry/circuit breaker/timeout failures |
| `ToolChainError` | Tool chain execution failures |
| `MCPError` | MCP protocol errors (JSON-RPC 2.0) |
| `MultiProviderError` | Provider routing failures |
| `OpenRouterProviderError` | OpenRouter API errors |
| `PersistentMemoryError` | Memory backend failures |
| `VectorMemoryError` | Vector search failures |
| `EmbeddingError` | Embedding generation failures |
| `SummarizerError` | Summarization failures |
| `SessionError` | Session management failures |
| `PipelineError` | Type-safe pipeline failures |
| `SwarmError` | General framework errors |
| `SwarmToolRegistryError` | Hive tool registry failures |
| `ModelSettingsValidationError` | Invalid model settings |
| `MetricsReporterError` | Metrics reporting failures |

---

## Appendix C: Build & Test

```bash
# Build
swift build                                    # Build all targets
swift test                                     # Run all test suites
swift test --filter AgentTests                 # Run a specific test suite
swift test --filter AgentTests/testHandoff     # Run a single test

# Demo (requires env var)
SWARM_INCLUDE_DEMO=1 swift build
SWARM_INCLUDE_DEMO=1 swift run SwarmDemo

# Formatting
swift package plugin --allow-writing-to-package-directory swiftformat

# Coverage
./scripts/generate-coverage-report.sh          # 70% threshold

# Environment variables
SWARM_INCLUDE_DEMO=1       # Enable demo targets
SWARM_USE_LOCAL_DEPS=1     # Use local Wax/Conduit packages
```

### Testing Conventions

- **Framework:** Swift Testing (`import Testing`, `@Suite`, `@Test`) — not XCTest
- **Mocks:** `MockInferenceProvider`, `MockAgentMemory`, `MockSummarizer`, `MockTool` in `Tests/SwarmTests/Mocks/`
- **Foundation Models:** Unavailable in tests — always use `MockInferenceProvider`
- **Test structure:** Mirrors source: `Tests/SwarmTests/Core/`, `Tests/SwarmTests/Orchestration/`, etc.
