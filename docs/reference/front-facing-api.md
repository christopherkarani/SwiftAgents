# Front-Facing API Reference

This document describes the current public API surface of Swarm.

## 1) Entry point and global configuration

```swift
import Swarm

public enum Swarm {
    public static let version: String
    public static let minimumMacOSVersion: String
    public static let minimumiOSVersion: String
}

await Swarm.configure(provider: some InferenceProvider)
await Swarm.configure(cloudProvider: some InferenceProvider)
await Swarm.reset()

let defaultProvider = await Swarm.defaultProvider
let cloudProvider = await Swarm.cloudProvider
```

## 2) Core runtime protocols

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

    func run(_ input: String, session: (any Session)?, observer: (any AgentObserver)?) async throws -> AgentResult
    nonisolated func stream(_ input: String, session: (any Session)?, observer: (any AgentObserver)?) -> AsyncThrowingStream<AgentEvent, Error>
    func runWithResponse(_ input: String, session: (any Session)?, observer: (any AgentObserver)?) async throws -> AgentResponse

    func cancel() async
}
```

Convenience:

```swift
run(_ input: String, observer: (any AgentObserver)? = nil)
stream(_ input: String, observer: (any AgentObserver)? = nil)
runWithResponse(_ input: String, observer: (any AgentObserver)? = nil)
observed(by: some AgentObserver) -> some AgentRuntime
```

## 3) Primary agent type

```swift
public actor Agent: AgentRuntime
```

Constructors:

```swift
try Agent(
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
)

try Agent(
    _ inferenceProvider: any InferenceProvider,
    tools: [any AnyJSONTool] = [],
    instructions: String = "",
    ...
)

try Agent(
    tools: [some Tool] = [],
    instructions: String = "",
    ...
)

try Agent(
    name: String,
    instructions: String = "",
    tools: [any AnyJSONTool] = [],
    ...
)

try Agent(
    name: String,
    instructions: String = "",
    tools: [any AnyJSONTool] = [],
    ...,
    handoffAgents: [any AgentRuntime]
)
```

Builder:

```swift
Agent.Builder()
    .tools(...)
    .addTool(...)
    .withBuiltInTools()
    .instructions(...)
    .configuration(...)
    .memory(...)
    .inferenceProvider(...)
    .tracer(...)
    .inputGuardrails(...)
    .addInputGuardrail(...)
    .outputGuardrails(...)
    .addOutputGuardrail(...)
    .guardrailRunnerConfiguration(...)
    .handoffs([AnyHandoffConfiguration])
    .addHandoff(...)
    .handoff(to: target) { options in ... }
    .handoffs(targetA, targetB, targetC)
    .build()
```

Declarative DSL entrypoint:

```swift
try Agent {
    Instructions("...")
    Tools { ... }
    Configuration(.default)
}
```

## 4) Conversation API

```swift
public final class Conversation {
    public struct Message {
        public enum Role { case user, assistant }
        public let role: Role
        public let text: String
    }

    public init(with agent: some AgentRuntime, session: (any Session)? = nil)
    public var messages: [Message] { get }

    @discardableResult
    public func send(_ input: String) async throws -> AgentResult

    @discardableResult
    public func stream(_ input: String) async throws -> String
}
```

## 5) Workflow API

Core fluent API:

```swift
public struct Workflow {
    public enum MergeStrategy {
        case structured   // JSON object: {"0": "output0", "1": "output1"}
        case indexed      // Labeled list: "[0]: output0\n[1]: output1"
        case first
        case custom(@Sendable ([AgentResult]) -> String)
    }

    public init()

    public func step(_ agent: some AgentRuntime) -> Workflow
    public func parallel(_ agents: [any AgentRuntime], merge: MergeStrategy = .structured) -> Workflow
    public func route(_ condition: @escaping @Sendable (String) -> (any AgentRuntime)?) -> Workflow
    public func repeatUntil(maxIterations: Int = 100, _ condition: @escaping @Sendable (AgentResult) -> Bool) -> Workflow
    public func timeout(_ duration: Duration) -> Workflow
    public func observed(by observer: some AgentObserver) -> Workflow

    public func run(_ input: String) async throws -> AgentResult
    public func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error>
}
```

Advanced namespace:

```swift
public extension Workflow {
    var advanced: Advanced { get }

    struct Advanced {
        enum CheckpointPolicy { case endOnly, everyStep }

        func checkpoint(id: String, policy: CheckpointPolicy = .endOnly) -> Workflow
        func checkpointStore(_ checkpointing: WorkflowCheckpointing) -> Workflow
        func fallback(primary: some AgentRuntime, to backup: some AgentRuntime, retries: Int = 0) -> Workflow
        func run(_ input: String, resumeFrom checkpointID: String? = nil) async throws -> AgentResult
    }
}

WorkflowCheckpointing.inMemory()
WorkflowCheckpointing.fileSystem(directory: URL)
```

## 6) Handoff API

Models and callbacks:

```swift
HandoffInputData
HandoffConfiguration<Target>
AnyHandoffConfiguration
HandoffRequest
HandoffResult

OnTransferCallback
TransformCallback
WhenCallback
```

Modern typed options:

```swift
HandoffHistory
HandoffPolicy
HandoffMetadataKey<Value>
HandoffOptions<Target>

HandoffOptions()
    .name(...)
    .description(...)
    .onTransfer { ... }
    .transform { ... }
    .when { ... }
    .history(...)
    .policy(...)
```

Builder/convenience:

```swift
HandoffBuilder(to: target)
    .toolName(...)
    .toolDescription(...)
    .onTransfer { ... }
    .transform { ... }
    .when { ... }
    .history(...)
    .build()

handoff(
    to: target,
    name: String? = nil,
    description: String? = nil,
    onTransfer: OnTransferCallback? = nil,
    transform: TransformCallback? = nil,
    when: WhenCallback? = nil,
    history: HandoffHistory = .none
)

agent.asHandoff()
agent.asHandoff { options in ... }
```

Coordination:

```swift
public protocol HandoffReceiver: AgentRuntime
public actor HandoffCoordinator
```

## 7) Tooling API

```swift
public protocol AnyJSONTool
public protocol Tool

ToolParameter
ToolSchema
ToolArguments
FunctionTool
ToolRegistry
ToolRegistryError
ToolChainBuilder
ToolChain
ParallelToolExecutor
```

Macros:

```swift
@Tool
@Parameter
```

## 8) Guardrails API

```swift
Guardrail
InputGuardrail
OutputGuardrail
ToolInputGuardrail
ToolOutputGuardrail

GuardrailRunnerConfiguration
GuardrailExecutionResult
GuardrailRunner
GuardrailResult
GuardrailError
GuardrailType
```

## 9) Memory and sessions

```swift
Memory
Session

ConversationMemory
SlidingWindowMemory
SummaryMemory
VectorMemory
HybridMemory
PersistentMemory
AnyMemory
CompositeMemory
InMemorySession

PersistentMemoryBackend
EmbeddingProvider
Summarizer
TokenEstimator
MemoryMessage
MemoryBuilder
MemoryComponent
```

## 10) Resilience primitives (no resilient wrapper agent)

```swift
RetryPolicy
BackoffStrategy
ResilienceError
CircuitBreaker
CircuitBreakerRegistry
RateLimiter
FallbackChain
```

## 11) Observability

```swift
Tracer
CompositeTracer
NoOpTracer
BufferedTracer
AnyTracer
ConsoleTracer
PrettyConsoleTracer
SwiftLogTracer
MetricsCollector

TraceEvent
TraceSpan
TraceContext
PerformanceMetrics
PerformanceTracker
MetricsSnapshot
MetricsReporter
JSONMetricsReporter
```

## 12) Inference and model controls

```swift
InferenceProvider
InferenceStreamingProvider
ToolCallStreamingInferenceProvider
InferenceOptions
InferenceResponse
InferenceStreamEvent
InferenceStreamUpdate

ModelSettings
ToolChoice
TruncationStrategy
Verbosity
CacheRetention
ModelSettingsValidationError
```

## 13) Core value/event/error types

```swift
AgentResult
TokenUsage
AgentResponse
ToolCallRecord
AgentEvent
ToolCall
ToolResult
PartialToolCallUpdate
MemoryOperation
SendableValue

AgentError
WorkflowError
WorkflowValidationError
GuardrailError
ResilienceError
```

## 14) Public macros

```swift
@Tool
@Parameter
@AgentActor(instructions:generateBuilder:)
@AgentActor(_ instructions:)
@Traceable
#Prompt(...)
@Builder

PromptString
```

## 15) Naming guarantees

- Observer APIs use the `observer` label.
- Legacy `hooks` label is removed from runtime entrypoints.
- Handoff callback/config naming is `onTransfer` / `transform` / `when`.
- Removed agents: `ReActAgent`, `PlanAndExecuteAgent`, `ResilientAgent`.
