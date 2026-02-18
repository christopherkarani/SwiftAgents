<img width="3168" height="1344" alt="Swarm — Swift Agent Framework" src="https://github.com/user-attachments/assets/62b0d34a-a0d4-45a9-a289-0e384939839f" />

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2026%2B%20%7C%20macOS%2026%2B%20%7C%20Linux-blue.svg)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![SPM](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://swift.org/package-manager/)

> ⭐ If Swarm is useful to you, a star helps others find it.

# Swarm

**Multi-agent orchestration for Swift — built for production, not demos.**

```swift
let result = try await (fetchAgent --> reasonAgent --> writerAgent)
    .run("Summarize the WWDC session on Swift concurrency.")

print(result.output)
```

Three agents. One line. Crash-resumable, data-race-safe, compiled to a DAG.

---

## Why Swarm

Most agent frameworks are Python-first, stringly-typed, and assume every workflow completes in one shot. Swarm makes three different bets.

### 1. Data races are compile errors

Swift 6.2's `StrictConcurrency` is enabled across every Swarm target — agents, memory systems, orchestrators, macros, and tests. Non-`Sendable` types crossing actor boundaries is a **build failure**, not a 3 AM incident.

```swift
// ❌ Compile error under Swarm's StrictConcurrency — caught before it ships
struct BrokenAgent: AgentRuntime {
    var cache: NSCache<NSString, NSString>
    // error: stored property 'cache' of 'Sendable'-conforming struct
    //        has non-Sendable type 'NSCache<NSString, NSString>'
}

// ✓ Actor isolation makes shared state safe by construction
actor ResponseCache {
    private var store: [String: String] = [:]
    func set(_ value: String, for key: String) { store[key] = value }
    func get(_ key: String) -> String? { store[key] }
}
```

### 2. Workflows survive crashes

Swarm ships a `WorkflowCheckpointStore` protocol with two built-in implementations: `InMemoryWorkflowCheckpointStore` for tests and `FileSystemWorkflowCheckpointStore` for production. Each step boundary writes a snapshot. A pipeline that crashes on step 7 of 10 resumes from step 7 — not from the beginning.

```swift
// Crash-recovery checkpoint store — survives process restarts
let store = FileSystemWorkflowCheckpointStore(
    directory: .applicationSupportDirectory.appending(path: "workflow-checkpoints")
)

// Snapshots are serialised JSON — human-readable, diff-friendly
// { "workflowID": "run-42", "stepIndex": 3, "intermediateOutput": "...", "timestamp": "..." }
```

### 3. Orchestration is a DSL, not a switch statement

Eleven composable step types in a SwiftUI-style `@resultBuilder`. Sequential chains use `-->`. Type-safe pipelines use `>>>`. Dependency DAGs use `.dependsOn()`. Human review gates use a three-way response.

```swift
// Sequential chain
fetchAgent --> analyzeAgent --> writerAgent

// Type-safe pipeline (compiler enforces Input/Output types at each stage)
let pipeline = Pipeline<String, [String]>  { $0.components(separatedBy: "\n") }
             >>> Pipeline<[String], String> { $0.filter { !$0.isEmpty }.joined(separator: "• ") }

// Dependency DAG — nodes run as soon as their dependencies complete
DAGWorkflow(nodes: [
    DAGNode("fetch",   agent: fetchAgent),
    DAGNode("refs",    agent: refsAgent),
    DAGNode("analyze", agent: analyzeAgent).dependsOn("fetch", "refs"),
    DAGNode("write",   agent: writerAgent).dependsOn("analyze"),
])

// Human-in-the-loop: three-way response
HumanApproval("Approve before publishing?", handler: reviewerUI)
// .approved          → workflow continues with current output
// .rejected(reason)  → workflow throws OrchestrationError.humanApprovalRejected
// .modified(newInput) → corrected value flows forward, replacing the agent's output
```

---

## How Swarm Compares

| | Swarm | LangChain (Python) | AutoGen |
|---|---|---|---|
| Language | Swift 6.2 | Python | Python |
| Data race safety | Compile-time ✓ | Runtime | Runtime |
| On-device LLM | Foundation Models ✓ | ❌ | ❌ |
| DAG execution engine | Hive (compiled) ✓ | Loop-based | Loop-based |
| Crash-resumable workflows | ✓ `FileSystemCheckpointStore` | ❌ | Partial |
| Type-safe tool parameters | ✓ `@Tool` macro | Decorators (runtime) | Runtime |
| Streaming | `AsyncThrowingStream` ✓ | Callbacks | Callbacks |
| iOS support | ✓ iOS 26+ | ❌ | ❌ |

---

## Quick Start

```swift
import Swarm

// 1. Define a tool
@Tool("Returns the current price of a stock")
struct StockPriceTool {
    @Parameter("Ticker symbol, e.g. AAPL")
    var ticker: String

    func execute() async throws -> String {
        // call your price API here
        return "182.50"
    }
}

// 2. Define an agent blueprint
struct FinanceAgent: AgentBlueprint {
    let analyst = Agent(
        name: "Analyst",
        tools: [StockPriceTool()],
        instructions: "Answer finance questions concisely using real data."
    )

    @OrchestrationBuilder var body: some OrchestrationStep {
        Guard(.input) {
            InputGuard("no_pii") { input in
                input.contains("SSN") ? .tripwire(message: "PII detected") : .passed()
            }
        }
        analyst
    }
}

// 3. Run it
let result = try await FinanceAgent()
    .environment(\.inferenceProvider, .anthropic(key: "YOUR_API_KEY"))
    .run("What is the current price of AAPL?")

print(result.output)
```

---

## Features

| Capability | Detail |
|---|---|
| **Agents** | `Agent` (tool-calling), `ReActAgent` (thought→action→observation), `PlanAndExecuteAgent` (plan→execute→replan) |
| **DSL** | `@OrchestrationBuilder`, `-->` sequential chain, `>>>` typed pipeline, `.dependsOn()` DAG |
| **Step types** | Sequential, Parallel, DAGWorkflow, Router, RepeatWhile, Branch, Guard, Transform, Pipeline, SequentialChain, ParallelGroup |
| **Memory** | Conversation (rolling buffer), VectorMemory (SIMD cosine via Accelerate), SummaryMemory (LLM-compressed), HybridMemory |
| **Hive runtime** | Compiled DAG execution, channel checkpointing, deterministic retry (jitter stripped by `RetryPolicyBridge`) |
| **Macros** | `@Tool` → full `AnyJSONTool` conformance + JSON schema; `@AgentActor` → boilerplate-free agent actors |
| **Guardrails** | Input, output, tool-input, tool-output validators; tripwire and warning modes |
| **Resilience** | Configurable retry backoff, circuit breaker, fallback agents, per-step timeouts |
| **Observability** | `SwiftLogTracer`, `OSLogTracer`, span-based tracing, per-agent token metrics |
| **MCP** | Model Context Protocol client + HTTP server |
| **Providers** | Foundation Models (on-device), Anthropic, OpenAI, Ollama, Gemini, MLX via [Conduit](https://github.com/christopherkarani/Conduit) |
| **Concurrency** | All public types `Sendable`; actors for all shared state; `StrictConcurrency` on every target |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Your Application                        │
│          iOS 26+ · macOS 26+ · Linux (Ubuntu 22.04+)        │
├─────────────────────────────────────────────────────────────┤
│          AgentBlueprint · Runner.run() · .stream()           │
├──────────────────────┬──────────────────────────────────────┤
│   Orchestration DSL  │  Step Types                          │
│   @resultBuilder     │  Sequential · Parallel · DAGWorkflow │
│   --> · >>>          │  Router · RepeatWhile · Branch       │
│   .dependsOn()       │  Guard · Transform · HumanApproval   │
├──────────────────────┴──────────────────────────────────────┤
│     Agents              Memory              Tools            │
│  Agent (tool-call)   Conversation        @Tool macro        │
│  ReActAgent          VectorMemory        FunctionTool       │
│  PlanAndExecute      SummaryMemory       AnyJSONTool ABI    │
│  HiveBackedAgent     HybridMemory        Runtime toggling   │
├─────────────────────────────────────────────────────────────┤
│     Guardrails · Resilience · Observability · MCP           │
├─────────────────────────────────────────────────────────────┤
│                    Hive Runtime (HiveCore)                   │
│   Compiled DAG · Channel checkpointing · Tool approval      │
│   Deterministic retry · RetryPolicyBridge (jitter-free)     │
├─────────────────────────────────────────────────────────────┤
│              InferenceProvider (pluggable)                   │
│   Foundation Models · Anthropic · OpenAI · Ollama · MLX     │
└─────────────────────────────────────────────────────────────┘
```

---

## More Examples

### Parallel Fan-Out

Run multiple agents on the same input concurrently. Each agent's metadata is automatically namespaced as `"agentName.key"` — no key collisions across concurrent results.

```swift
let group = ParallelGroup(
    agents: [
        (name: "primary", agent: primaryAgent),
        (name: "backup",  agent: backupAgent),
        (name: "expert",  agent: expertAgent),
    ],
    mergeStrategy: MergeStrategies.Concatenate(
        separator: "\n\n---\n\n",
        shouldIncludeAgentNames: true
    ),
    maxConcurrency: 3
)

let result = try await group.run("Analyze the Swift concurrency model.")
```

### Semantic Memory (On-Device SIMD)

`VectorMemory` uses Accelerate's `vDSP_dotpr` for cosine similarity — no network call, no cloud embedding API.

```swift
let memory = VectorMemory(
    embeddingProvider: myEmbedder,
    similarityThreshold: 0.75,
    maxResults: 8
)

await memory.add(.user("The project deadline is March 15."))
await memory.add(.assistant("Noted. I will prioritise accordingly."))

// Semantically retrieves the deadline entry despite different phrasing
let context = await memory.context(for: "When is this due?", tokenLimit: 1_200)
```

### Supervisor Routing

```swift
let supervisor = SupervisorAgent(
    agents: [
        (name: "math",    agent: mathAgent,    description: mathDesc),
        (name: "weather", agent: weatherAgent, description: weatherDesc),
        (name: "code",    agent: codeAgent,    description: codeDesc),
    ],
    routingStrategy: LLMRoutingStrategy(inferenceProvider: provider),
    fallbackAgent: Agent(instructions: "I am a general assistant.")
)

let result = try await supervisor.run("What is 15% of $240?")
// Routes to mathAgent
```

### Resilience

```swift
let agent = FinanceAgent()
    .environment(\.inferenceProvider, provider)
    .withRetry(.exponentialBackoff(maxAttempts: 3, baseDelay: .seconds(1)))
    .withCircuitBreaker(threshold: 5, resetTimeout: .seconds(60))
    .withFallback(Agent(instructions: "Service temporarily unavailable."))
    .withTimeout(.seconds(30))
```

### Streaming

```swift
for try await event in (fetchAgent --> writerAgent).stream("Summarise the changelog.") {
    switch event {
    case .outputToken(let token):  print(token, terminator: "")
    case .toolCalling(let call):   print("\n[tool: \(call.toolName)]")
    case .completed(let result):   print("\n\nDone in \(result.duration)")
    case .failed(let error):       print("\nError: \(error)")
    default: break
    }
}
```

### Session Continuity

```swift
let session = InMemorySession(sessionId: "user-42")

try await agent.run("My portfolio has 100 AAPL shares.", session: session)
let result = try await agent.run("What is my total value?", session: session)
// Agent recalls the earlier context
```

---

## Installation

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/christopherkarani/Swarm.git", from: "0.3.1")
],
targets: [
    .target(name: "YourApp", dependencies: ["Swarm"])
]
```

### Xcode

**File → Add Package Dependencies →** `https://github.com/christopherkarani/Swarm.git`

---

## Documentation

| Topic | Description |
|---|---|
| [Agents](docs/agents.md) | Agent types, configuration, `@AgentActor` macro |
| [Tools](docs/tools.md) | `@Tool` macro, `FunctionTool`, `AnyJSONTool` ABI, runtime toggling |
| [Memory](docs/memory.md) | Conversation, Vector (SIMD), Summary, Hybrid, SwiftData backends |
| [Sessions](docs/sessions.md) | In-memory and persistent session management |
| [Orchestration](docs/orchestration.md) | DAG, parallel, chains, handoffs, human-in-the-loop |
| [Streaming](docs/streaming.md) | `AgentEvent` streaming and SwiftUI integration |
| [Observability](docs/observability.md) | Span-based tracing, `OSLogTracer`, `SwiftLogTracer`, metrics |
| [Resilience](docs/resilience.md) | Retry, circuit breakers, fallback agents, timeouts |
| [Guardrails](docs/guardrails.md) | Input/output validation, tripwires, audit trails |
| [MCP](docs/mcp.md) | Model Context Protocol client and server |
| [Providers](docs/providers.md) | Configuring inference providers |

---

## Requirements

| | Minimum |
|---|---|
| Swift | 6.2 |
| iOS | 26.0 |
| macOS | 26.0 |
| Linux | Ubuntu 22.04 + Swift 6.2 |

> iOS 26 / macOS 26 are required for Apple's on-device Foundation Models. External providers (Anthropic, OpenAI, Ollama) work on any Swift 6.2 platform including Linux.

---

## Contributing

1. Fork and create a branch: `git checkout -b feature/my-feature`
2. All public types must be `Sendable` — `StrictConcurrency` will reject violations at build time
3. Write tests first: `swift test`
4. Format: `swift package plugin --allow-writing-to-package-directory swiftformat`
5. Open a Pull Request — describe what changed and why it matters

See [CONTRIBUTING.md](CONTRIBUTING.md) for agent registry conventions and TDD workflow.

---

## Support

- **Issues** — [GitHub Issues](https://github.com/christopherkarani/Swarm/issues)
- **Discussions** — [GitHub Discussions](https://github.com/christopherkarani/Swarm/discussions)
- **X** — [@ckarani7](https://x.com/ckarani7)

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

*Built in Swift for Apple platforms and Linux.*
