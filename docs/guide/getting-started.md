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

## Multi-Agent Workflow

Compose multi-agent execution with `Workflow`:

```swift
let result = try await Workflow()
    .step(fetchAgent)
    .step(analyzeAgent)
    .step(writerAgent)
    .run("Summarize the WWDC session on Swift concurrency.")
```

For checkpoint/resume and other power features, use the namespaced advanced API:

```swift
let result = try await Workflow()
    .step(fetchAgent)
    .step(analyzeAgent)
    .advanced
    .checkpoint(id: "report-v1", policy: .everyStep)
    .advanced
    .checkpointStore(.fileSystem(directory: checkpointsURL))
    .advanced
    .run("Summarize the WWDC session")
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
- **Workflow** — Use `Workflow` for sequential, parallel, and routed execution
- **[Memory](/memory)** — Conversation, vector, summary, persistent
