<img width="3168" height="1344" alt="Swarm — Swift Agent Framework" src="https://github.com/user-attachments/assets/62b0d34a-a0d4-45a9-a289-0e384939839f" />

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2026%2B%20|%20macOS%2026%2B%20|%20Linux-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

# Swarm

**The agent framework Swift has been missing.** Chain LLMs, tools, and memory into production workflows — with compile-time safety, crash recovery, and on-device inference.

```swift
let result = try await (fetchAgent --> reasonAgent --> writerAgent)
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

That's a working agent with tool calling. Keep reading for multi-agent orchestration, memory, guardrails, and more.

---

## Why Swarm

```
  ┌─────────────────────────────────────────────────────────────────┐
  │                    THE SWARM ADVANTAGE                          │
  │                                                                 │
  │   Python Frameworks              Swarm (Swift 6.2)              │
  │   ─────────────────              ─────────────────              │
  │                                                                 │
  │   Data races?                    Caught at COMPILE time         │
  │   ╳ Runtime crash at 3 AM        ✓ Won't even build             │
  │                                                                 │
  │   Crash recovery?               Automatic checkpoints          │
  │   ╳ Start over from scratch      ✓ Resume from last step        │
  │                                                                 │
  │   On-device LLM?                Apple Foundation Models         │
  │   ╳ Cloud-only                   ✓ Private, zero latency        │
  │                                                                 │
  │   Tool schemas?                  @Tool macro                    │
  │   ╳ Runtime decorators           ✓ Compiler-verified JSON       │
  │                                                                 │
  │   Type safety?                   End-to-end generics            │
  │   ╳ dict["key"] maybe?           ✓ Pipeline<In, Out>            │
  │                                                                 │
  │   iOS / macOS native?            First-class citizen            │
  │   ╳ Not supported                ✓ SwiftUI, Combine, async/await│
  └─────────────────────────────────────────────────────────────────┘
```

---

## Feature Highlights

### 1. Compile-Time Concurrency Safety

```
  ┌────────────────────────────────────────────────────────────────┐
  │                                                                │
  │    Your Code          Swift 6.2 Compiler          Runtime      │
  │   ┌──────────┐       ┌────────────────┐       ┌──────────┐   │
  │   │  Agent A  │──────▶│  StrictConcur- │──────▶│  ZERO    │   │
  │   │  Agent B  │       │  rency Check   │       │  data    │   │
  │   │  Agent C  │──────▶│                │──────▶│  races   │   │
  │   └──────────┘       │  ╳ Non-Sendable │       │          │   │
  │                       │    = BUILD ERROR│       │  Sleep   │   │
  │                       └────────────────┘       │  soundly │   │
  │                                                 └──────────┘   │
  │                                                                │
  │    Every target. Every type. Every actor boundary. Checked.    │
  └────────────────────────────────────────────────────────────────┘
```

### 2. Crash-Resumable Orchestration via Hive DAG

Every orchestration compiles to a directed acyclic graph with automatic checkpointing.

```
       Step 1       Step 2       Step 3       Step 4       Step 5
      ┌──────┐     ┌──────┐     ┌──────┐     ┌──────┐     ┌──────┐
      │Fetch │────▶│Parse │────▶│Reason│────▶│Write │────▶│Email │
      │  ✓   │     │  ✓   │     │  ✓   │     │  ✓   │     │  ✗   │
      └──────┘     └──────┘     └──────┘     └──────┘     └──┬───┘
        saved        saved        saved        saved      CRASH│
                                                               │
      ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
      │  On restart:
      │  Steps 1-4 SKIPPED (checkpointed)
      ▼
      ┌──────┐
      │Email │  ◀── resumes here, not from the beginning
      │  ✓   │
      └──────┘
```

### 3. SwiftUI-Style Orchestration DSL

Eleven composable step types. One `@resultBuilder`. Infinite combinations.

```
  ┌────────────────────────────────────────────────────────────────┐
  │                    ORCHESTRATION STEPS                          │
  │                                                                │
  │  FLOW                LOGIC               COMPOSITION           │
  │  ────                ─────               ───────────           │
  │  Sequential          Router              Pipeline              │
  │  A ──▶ B ──▶ C       ┌─▶ Agent1          In ══▶ Transform     │
  │                    ┌──┤                        ══▶ Out         │
  │  Parallel           │  ├─▶ Agent2                              │
  │  ┌─▶ A              │  └─▶ Agent3         DAGWorkflow          │
  │  ├─▶ B              │                     A ──┐                │
  │  └─▶ C              │  Branch              B ──┼──▶ D          │
  │    ╰── merge         │  condition?          C ──┘               │
  │                      │  ├─ yes ──▶ X                            │
  │  RepeatWhile         │  └─ no  ──▶ Y       Guard               │
  │  ┌─▶ A ──┐           │                     ▶ validate           │
  │  └── ◀──┘            │  Transform           ├─ pass ──▶ run    │
  │  until done          │  map(input)           └─ trip ──▶ halt   │
  └────────────────────────────────────────────────────────────────┘

  // Build with operators:
  fetchAgent --> analyzeAgent --> writerAgent           // Sequential
  Pipeline<String, [Item]> { ... } >>> Pipeline { ... } // Type-safe
  DAGNode("write", agent: w).dependsOn("fetch", "ref")  // DAG edges
```

### 4. Plug Any LLM — On-Device or Cloud

```
                          ┌──────────────────┐
                          │   Your Agent     │
                          │                  │
                          │  .environment(   │
                          │    \.inference,  │
                          │    provider      │
                          │  )              │
                          └────────┬─────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
              ┌─────▼─────┐ ┌─────▼─────┐ ┌─────▼─────┐
              │ On-Device  │ │   Cloud    │ │  Local    │
              ├───────────┤ ├───────────┤ ├───────────┤
              │ Foundation │ │ Anthropic  │ │  Ollama   │
              │ Models     │ │ OpenAI     │ │  MLX      │
              │            │ │ Gemini     │ │           │
              │ Private    │ │ OpenRouter │ │ Self-host │
              │ Zero-lat   │ │            │ │           │
              └───────────┘ └───────────┘ └───────────┘

  // Same code, different provider — one line change:
  .environment(\.inferenceProvider, .foundationModels)  // On-device
  .environment(\.inferenceProvider, .anthropic(key: k)) // Cloud
  .environment(\.inferenceProvider, .ollama())           // Local
```

### 5. Five Memory Systems

```
  ┌────────────────────────────────────────────────────────────────┐
  │                       MEMORY LAYER                             │
  │                                                                │
  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
  │  │ Conversation │  │   Vector     │  │      Summary         │ │
  │  │   Memory     │  │   Memory     │  │      Memory          │ │
  │  ├──────────────┤  ├──────────────┤  ├──────────────────────┤ │
  │  │ Rolling      │  │ SIMD cosine  │  │ LLM-compressed      │ │
  │  │ token-limited│  │ similarity   │  │ history — keeps      │ │
  │  │ buffer       │  │ via Accelerate│  │ meaning, drops noise │ │
  │  │              │  │ No cloud API │  │                      │ │
  │  └──────────────┘  └──────────────┘  └──────────────────────┘ │
  │                                                                │
  │  ┌──────────────┐  ┌──────────────────────────────────────┐   │
  │  │   Sliding    │  │           Persistent                 │   │
  │  │   Window     │  │           Memory                     │   │
  │  ├──────────────┤  ├──────────────────────────────────────┤   │
  │  │ Fixed message│  │ SwiftData-backed durable storage     │   │
  │  │ count window │  │ Survives app restarts                │   │
  │  └──────────────┘  └──────────────────────────────────────┘   │
  │                                                                │
  │  All memory types: Actor-isolated, Sendable, composable        │
  └────────────────────────────────────────────────────────────────┘
```

### 6. Production Resilience — Built In

```
                        Request
                           │
                    ┌──────▼──────┐
                    │   Timeout   │  30s max
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐     ┌─────────────┐
                    │   Retry     │────▶│ 7 backoff   │
                    │             │     │ strategies   │
                    └──────┬──────┘     └─────────────┘
                           │
                    ┌──────▼──────┐
                    │  Circuit    │  trips after N failures
                    │  Breaker    │  auto-resets after cooldown
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  Fallback   │  graceful degradation
                    │  Chain      │  to backup agent
                    └──────┬──────┘
                           │
                        Response

  let agent = myAgent
      .withRetry(.exponentialBackoff(maxAttempts: 3))
      .withCircuitBreaker(threshold: 5, resetTimeout: .seconds(60))
      .withFallback(backupAgent)
      .withTimeout(.seconds(30))
```

### 7. Guardrails at Every Boundary

```
      INPUT                    AGENT                    OUTPUT
   ┌─────────┐            ┌───────────┐            ┌──────────┐
   │  User   │            │           │            │  Result   │
   │  Query  │──▶ GUARD ──▶│  Process  │──▶ GUARD ──▶│          │
   └─────────┘    │    │   │           │    │    │   └──────────┘
                  │    │   │  ┌─────┐  │    │    │
              Validate │   │  │Tools│  │  Validate
              PII check│   │  └──┬──┘  │  Toxicity
              Injection│   │     │     │  Format
                       │   │  GUARD    │
                       │   │  ├ args   │
                       │   │  └ result │
                       │   └───────────┘
                       │
               .passed()  or  .tripwire(message:)  or  .warning(message:)
```

### 8. MCP — Both Directions

```
  ┌─────────────────────────────────────────────────────────────┐
  │                                                             │
  │        MCP CLIENT                    MCP SERVER             │
  │   (consume external tools)     (expose Swarm tools)        │
  │                                                             │
  │   ┌───────────┐                ┌───────────────────┐       │
  │   │   Swarm   │ ──requests──▶  │  External MCP     │       │
  │   │   Agent   │ ◀──tools────   │  Server           │       │
  │   └───────────┘                └───────────────────┘       │
  │                                                             │
  │   ┌───────────────────┐        ┌───────────┐               │
  │   │  External MCP     │ ──req─▶│   Swarm   │               │
  │   │  Client           │ ◀tools─│   Server  │               │
  │   └───────────────────┘        └───────────┘               │
  │                                                             │
  │   Your agents consume AND expose tools via the standard     │
  │   Model Context Protocol.                                   │
  └─────────────────────────────────────────────────────────────┘
```

### 9. Streaming — Real-Time Token Output

```swift
for try await event in (fetchAgent --> writerAgent).stream("Summarise the changelog.") {
    switch event {
    case .outputToken(let token):  print(token, terminator: "")
    case .toolCalling(let call):   print("\n[tool: \(call.toolName)]")
    case .completed(let result):   print("\nDone in \(result.duration)")
    default: break
    }
}
```

### 10. Agent Types for Every Pattern

```
  ┌────────────────────────────────────────────────────────────────┐
  │                                                                │
  │  Agent (tool-calling)         ReActAgent                       │
  │  ─────────────────────        ──────────                       │
  │  LLM picks tools from a      Reason ──▶ Act ──▶ Observe       │
  │  schema, executes them,         ▲                    │         │
  │  returns structured output      └────────────────────┘         │
  │                                 Loop until answer found        │
  │                                                                │
  │  PlanAndExecuteAgent          SupervisorAgent                  │
  │  ───────────────────          ────────────────                  │
  │  1. Plan (break into steps)   Routes to the right agent:       │
  │  2. Execute (step by step)    ┌─▶ mathAgent                    │
  │  3. Replan if needed          ├─▶ codeAgent                    │
  │                               └─▶ weatherAgent                 │
  │                                                                │
  │  ChatAgent                    HiveBackedAgent                   │
  │  ─────────                    ──────────────                    │
  │  Stateful conversation        Any AgentRuntime wrapped         │
  │  with memory persistence      as a Hive DAG node               │
  └────────────────────────────────────────────────────────────────┘
```

---

## Architecture

```
  ┌─────────────────────────────────────────────────────────────────┐
  │                       YOUR APPLICATION                          │
  │             iOS 26+ · macOS 26+ · Linux (Ubuntu 22.04+)        │
  ├─────────────────────────────────────────────────────────────────┤
  │              AgentBlueprint · .run() · .stream()                │
  ├─────────────────────┬───────────────────────────────────────────┤
  │  Orchestration DSL  │  Sequential · Parallel · DAG · Router    │
  │  @resultBuilder     │  Branch · Guard · Transform · Pipeline   │
  │  --> · >>> operators │  RepeatWhile · ParallelGroup · Chain     │
  ├─────────────────────┴───────────────────────────────────────────┤
  │   Agents              │  Memory             │  Tools            │
  │   Agent (tool-call)   │  ConversationMemory │  @Tool macro      │
  │   ReActAgent          │  VectorMemory       │  FunctionTool     │
  │   PlanAndExecute      │  SummaryMemory      │  ToolChain        │
  │   SupervisorAgent     │  Persistent (SwiftData)                 │
  ├─────────────────────────────────────────────────────────────────┤
  │      Guardrails · Resilience · Observability · MCP              │
  ├─────────────────────────────────────────────────────────────────┤
  │                     Hive Runtime (HiveCore)                     │
  │      Compiled DAG · Checkpointing · Deterministic retry         │
  ├─────────────────────────────────────────────────────────────────┤
  │               InferenceProvider (pluggable via Conduit)         │
  │  Foundation Models · Anthropic · OpenAI · Ollama · Gemini · MLX │
  └─────────────────────────────────────────────────────────────────┘
```

---

## See It In Action

<details>
<summary><strong>Multi-agent pipeline with guardrails</strong></summary>

```swift
struct ResearchPipeline: AgentBlueprint {
    let researcher = Agent(name: "Researcher", tools: [WebSearch()])
    let writer     = Agent(name: "Writer", instructions: "Write clear summaries.")

    @OrchestrationBuilder var body: some OrchestrationStep {
        Guard(.input) {
            InputGuard("no_pii") { input in
                input.contains("SSN") ? .tripwire(message: "PII detected") : .passed()
            }
        }
        researcher --> writer
    }
}

let result = try await ResearchPipeline()
    .environment(\.inferenceProvider, provider)
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
<summary><strong>Supervisor routing — LLM picks the right agent</strong></summary>

```swift
let supervisor = SupervisorAgent(
    agents: [
        (name: "math",    agent: mathAgent,    description: "Arithmetic and calculations"),
        (name: "weather", agent: weatherAgent, description: "Weather forecasts"),
        (name: "code",    agent: codeAgent,    description: "Programming help"),
    ],
    routingStrategy: LLMRoutingStrategy(inferenceProvider: provider)
)

let result = try await supervisor.run("What is 15% of $240?")
// Automatically routes to mathAgent
```

</details>

---

## Documentation

| | |
|---|---|
| **[Complete API Reference](docs/swarm-complete-reference.md)** | **Every type, protocol, and API — with examples** |
| [Agents](docs/agents.md) | Agent types, configuration, `@AgentActor` macro |
| [Tools](docs/tools.md) | `@Tool` macro, `FunctionTool`, runtime toggling |
| [DSL & Blueprints](docs/dsl.md) | `AgentBlueprint`, `@OrchestrationBuilder`, modifiers |
| [Orchestration](docs/orchestration.md) | DAG, parallel, chains, human-in-the-loop |
| [Handoffs](docs/Handoffs.md) | Agent handoffs, routing, `SupervisorAgent` |
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
