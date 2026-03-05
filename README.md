<img width="3168" height="1344" alt="Swarm — Swift Agent Framework" src="https://github.com/user-attachments/assets/62b0d34a-a0d4-45a9-a289-0e384939839f" />

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2026%2B%20|%20macOS%2026%2B%20|%20Linux-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

# Swarm

**The agent framework Swift has been missing.** Chain LLMs, tools, and memory into production workflows — with compile-time safety, crash recovery, and on-device inference.

```swift
let result = try await Workflow()
    .step(fetchAgent)
    .step(reasonAgent)
    .step(writerAgent)
    .run("Summarize the WWDC session on Swift concurrency.")
```

Three agents. One line. Compiled to a DAG. Crash-resumable. Zero data races.

> If Swarm saves you time, **[a star](https://github.com/christopherkarani/Swarm)** helps others find it.

---

## Install

```swift
.package(url: "https://github.com/christopherkarani/Swarm.git", from: "0.3.4")
```

Or in Xcode: **File → Add Package Dependencies →** paste the URL above.

---

## 30-Second Quick Start

```swift
import Swarm

// 1. Define a tool — the @Tool macro generates the JSON schema for you
@Tool("Looks up the current stock price")
struct PriceTool {
    @Parameter("Ticker symbol") var ticker: String

    func execute() async throws -> String { "182.50" }
}

// 2. Create an agent with tools
let agent = Agent(
    name: "Analyst",
    tools: [PriceTool()],
    instructions: "Answer finance questions using real data."
)

// 3. Run it
let result = try await agent
    .environment(\.inferenceProvider, .anthropic(key: "sk-..."))
    .run("What is AAPL trading at?")

print(result.output) // "Apple (AAPL) is currently trading at $182.50."
```

That's a working agent with tool calling. Keep reading for multi-agent workflow composition, memory, guardrails, and more.

---

## What Makes Swarm Different

### Data races are compile errors, not 3 AM incidents

Swift 6.2 `StrictConcurrency` is enabled on **every** target. Non-`Sendable` types crossing actor boundaries won't build. Period.

### Workflows survive crashes

Advanced workflows can use [Hive](https://github.com/christopherkarani/Hive) checkpointing for resume support, including explicit checkpoint stores and checkpoint IDs.

```swift
let workflow = Workflow()
    .step(monitor)
    .advanced.checkpoint(id: "monitor-v1", policy: .everyStep)
    .advanced.checkpointStore(.fileSystem(directory: checkpointsURL))

let resumed = try await workflow.advanced.run("watch", resumeFrom: "monitor-v1")
```

### Workflow composition is fluent, not glue code

Compose multi-agent execution with a single fluent API:

```swift
Workflow().step(fetchAgent).step(analyzeAgent).step(writerAgent)
Workflow().parallel([bullAgent, bearAgent, analystAgent])
Workflow().route { input in input.contains("bill") ? billingAgent : generalAgent }
Workflow().step(monitor).advanced.checkpoint(id: "monitor-v1", policy: .everyStep)
```

### Run on-device or in the cloud — same code

Foundation Models, Anthropic, OpenAI, Ollama, Gemini, MLX. Swap providers with one line:

```swift
agent.environment(\.inferenceProvider, .foundationModels) // On-device, private
agent.environment(\.inferenceProvider, .anthropic(key: k)) // Cloud
```

---

## See It In Action

<details>
<summary><strong>Multi-agent pipeline with guardrails</strong></summary>

```swift
let researcher = try Agent(
    instructions: "Research the topic and extract key facts.",
    inferenceProvider: provider
)
let writer = try Agent(
    instructions: "Write a concise summary from the research.",
    inferenceProvider: provider
)

let result = try await Workflow()
    .step(researcher)
    .step(writer)
    .run("Latest advances in on-device ML")
```

</details>

<details>
<summary><strong>Parallel fan-out with merged results</strong></summary>

```swift
let group = ParallelGroup(
    agents: [
        (name: "optimist", agent: bullAgent),
        (name: "pessimist", agent: bearAgent),
        (name: "neutral", agent: analystAgent),
    ],
    mergeStrategy: MergeStrategies.Concatenate(separator: "\n\n---\n\n"),
    maxConcurrency: 3
)

let result = try await group.run("Evaluate Apple's Q4 earnings.")
// All three perspectives, merged into one output
```

</details>

<details>
<summary><strong>Semantic memory — on-device SIMD, no cloud API</strong></summary>

```swift
let memory = VectorMemory(
    embeddingProvider: myEmbedder,
    similarityThreshold: 0.75,
    maxResults: 8
)

await memory.add(.user("The project deadline is March 15."))

// Retrieves the deadline despite different phrasing
let context = await memory.context(for: "When is this due?", tokenLimit: 1_200)
```

</details>

<details>
<summary><strong>Workflow routing — choose the right agent</strong></summary>

```swift
let result = try await Workflow()
    .route { input in
        if input.contains("%") || input.contains("$") { return mathAgent }
        if input.contains("weather") { return weatherAgent }
        return codeAgent
    }
    .run("What is 15% of $240?")
```

</details>

<details>
<summary><strong>Production resilience — retry, circuit breaker, fallback, timeout</strong></summary>

```swift
let agent = myAgent
    .withRetry(.exponentialBackoff(maxAttempts: 3, baseDelay: .seconds(1)))
    .withCircuitBreaker(threshold: 5, resetTimeout: .seconds(60))
    .withFallback(Agent(instructions: "Service temporarily unavailable."))
    .withTimeout(.seconds(30))
```

</details>

<details>
<summary><strong>Streaming — real-time token output</strong></summary>

```swift
for try await event in Workflow()
    .step(fetchAgent)
    .step(writerAgent)
    .stream("Summarise the changelog.") {
    switch event {
    case .outputToken(let token):  print(token, terminator: "")
    case .toolCalling(let call):   print("\n[tool: \(call.toolName)]")
    case .completed(let result):   print("\nDone in \(result.duration)")
    default: break
    }
}
```

</details>

---

## How Swarm Compares

| | **Swarm** | LangChain | AutoGen |
|---|---|---|---|
| **Language** | Swift 6.2 | Python | Python |
| **Data race safety** | Compile-time | Runtime | Runtime |
| **On-device LLM** | Foundation Models | — | — |
| **Execution engine** | Compiled DAG (Hive) | Loop-based | Loop-based |
| **Crash recovery** | Automatic checkpoints | — | Partial |
| **Type-safe tools** | `@Tool` macro (compile-time) | Decorators (runtime) | Runtime |
| **Streaming** | `AsyncThrowingStream` | Callbacks | Callbacks |
| **iOS / macOS native** | First-class | — | — |

---

## Everything Included

| | |
|---|---|
| **Agents** | Tool-calling `Agent`, `ReActAgent`, `PlanAndExecuteAgent` |
| **Workflow** | Fluent composition: `.step`, `.parallel`, `.route`, `.repeatUntil`, `.timeout`, `.observed` |
| **Memory** | Conversation, Vector (SIMD/Accelerate), Summary (LLM-compressed), Hybrid, Persistent (SwiftData) |
| **Tools** | `@Tool` macro with auto-generated JSON schema, `FunctionTool`, `ToolChain`, parallel execution |
| **Guardrails** | Input, output, tool-input, tool-output validators with tripwire and warning modes |
| **Resilience** | Retry (7 backoff strategies), circuit breaker, fallback chains, rate limiting, timeouts |
| **Observability** | `OSLogTracer`, `SwiftLogTracer`, span-based tracing, per-agent token metrics |
| **MCP** | Model Context Protocol — both client (consume tools) and server (expose tools) |
| **Providers** | Foundation Models, Anthropic, OpenAI, Ollama, Gemini, OpenRouter, MLX via [Conduit](https://github.com/christopherkarani/Conduit) |
| **Macros** | `@Tool`, `@Parameter`, `@AgentActor`, `@Traceable`, `#Prompt`, `@Builder` |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Your Application                        │
│          iOS 26+ · macOS 26+ · Linux (Ubuntu 22.04+)        │
├─────────────────────────────────────────────────────────────┤
│            Workflow · .run() · .stream()                     │
├─────────────────────────────────────────────────────────────┤
│     Agents              Memory              Tools            │
│  Agent (tool-call)   Conversation        @Tool macro        │
│  ReActAgent          VectorMemory        FunctionTool       │
│  PlanAndExecute      SummaryMemory       AnyJSONTool ABI    │
│                    HybridMemory          ToolChain          │
├─────────────────────────────────────────────────────────────┤
│     Guardrails · Resilience · Observability · MCP           │
├─────────────────────────────────────────────────────────────┤
│                    Hive Runtime (HiveCore)                   │
│   Compiled DAG · Checkpointing · Deterministic retry        │
├─────────────────────────────────────────────────────────────┤
│              InferenceProvider (pluggable)                   │
│   Foundation Models · Anthropic · OpenAI · Ollama · MLX     │
└─────────────────────────────────────────────────────────────┘
```

---

## Documentation

| | |
|---|---|
| **[Complete API Reference](docs/swarm-complete-reference.md)** | **Every type, protocol, and API — with examples** |
| [Agents](docs/agents.md) | Agent types, configuration, `@AgentActor` macro |
| [Tools](docs/tools.md) | `@Tool` macro, `FunctionTool`, runtime toggling |
| [Workflow](docs/guide/getting-started.md) | Fluent workflow composition and execution |
| [Handoffs](docs/Handoffs.md) | Agent handoffs and routing between runtime agents |
| [Memory](docs/memory.md) | Conversation, Vector, Summary, SwiftData backends |
| [Streaming](docs/streaming.md) | `AgentEvent` streaming, SwiftUI integration |
| [Guardrails](docs/guardrails.md) | Input/output validation, tripwires |
| [Resilience](docs/resilience.md) | Retry, circuit breakers, fallback, timeouts |
| [Observability](docs/observability.md) | Tracing, `OSLogTracer`, `SwiftLogTracer`, metrics |
| [MCP](docs/mcp.md) | Model Context Protocol client and server |
| [Providers](docs/providers.md) | Inference providers, `MultiProvider` routing |
| [Migration Guide](docs/MIGRATION_GUIDE.md) | Upgrading between versions |

---

## Requirements

| | |
|---|---|
| Swift | 6.2+ |
| iOS | 26.0+ |
| macOS | 26.0+ |
| Linux | Ubuntu 22.04+ with Swift 6.2 |

Foundation Models require iOS 26 / macOS 26. Cloud providers (Anthropic, OpenAI, Ollama) work on any Swift 6.2 platform including Linux.

---

## Contributing

1. Fork → branch → `swift test` → PR
2. All public types must be `Sendable` — the compiler enforces it
3. Format with `swift package plugin --allow-writing-to-package-directory swiftformat`

---

## Support

[GitHub Issues](https://github.com/christopherkarani/Swarm/issues) · [Discussions](https://github.com/christopherkarani/Swarm/discussions) · [@ckarani7](https://x.com/ckarani7)

---

MIT License — see [LICENSE](LICENSE).
