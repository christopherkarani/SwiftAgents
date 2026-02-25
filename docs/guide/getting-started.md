# Getting Started

Get a working Swarm agent in under a minute.

## Installation

### Swift Package Manager

Add Swarm to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/christopherkarani/Swarm.git", from: "0.3.4")
],
targets: [
    .target(name: "YourApp", dependencies: ["Swarm"])
]
```

### Xcode

**File → Add Package Dependencies →** `https://github.com/christopherkarani/Swarm.git`

## Your First Agent

```swift
import Swarm

// 1. Define a tool — the @Tool macro generates the JSON schema
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

## Multi-Agent Pipeline

Chain agents with the `-->` operator:

```swift
let result = try await (fetchAgent --> analyzeAgent --> writerAgent)
    .run("Summarize the WWDC session on Swift concurrency.")
```

This compiles to a Hive DAG with automatic checkpointing. If step 2 crashes, it resumes from step 2.

## Using a Blueprint

For production workflows, use `AgentBlueprint` — a SwiftUI-style declarative API:

```swift
struct ResearchPipeline: AgentBlueprint {
    let researcher = Agent(name: "Researcher", tools: [WebSearch()])
    let writer = Agent(name: "Writer", instructions: "Write clear summaries.")

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

## Choosing a Provider

Swarm supports multiple inference providers. Swap with one line:

```swift
// On-device (private, no network)
.environment(\.inferenceProvider, .foundationModels)

// Anthropic
.environment(\.inferenceProvider, .anthropic(key: "sk-..."))

// OpenAI
.environment(\.inferenceProvider, .openAI(key: "sk-..."))

// Ollama (local)
.environment(\.inferenceProvider, .ollama())

// Multiple providers — route by model prefix
.environment(\.inferenceProvider, MultiProvider(providers: [
    "anthropic": anthropicProvider,
    "openai": openAIProvider,
]))
```

## Requirements

| | Minimum |
|---|---|
| Swift | 6.2+ |
| iOS | 26.0+ |
| macOS | 26.0+ |
| Linux | Ubuntu 22.04+ with Swift 6.2 |

::: tip
Foundation Models require iOS 26 / macOS 26. Cloud providers (Anthropic, OpenAI, Ollama) work on any Swift 6.2 platform including Linux.
:::

## Next Steps

- **[Agents](/agents)** — Agent types, configuration, tool calling
- **[Tools](/tools)** — `@Tool` macro, `FunctionTool`, tool chains
- **[Orchestration](/orchestration)** — DAGs, parallel execution, routing
- **[Memory](/memory)** — Conversation, vector, summary, persistent
