---
layout: home

hero:
  name: Swarm
  text: Multi-Agent Workflows for Swift
  tagline: Chain LLMs, tools, and memory into production workflows — with compile-time safety, crash recovery, and on-device inference.
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/christopherkarani/Swarm

features:
  - icon: 🔗
    title: Compose Workflows Fluently
    details: Build sequential, parallel, and routed workflows with `Workflow().step(...).parallel(...).route(...)`.
    link: /guide/getting-started
    linkText: Learn workflows

  - icon: 🛡️
    title: Data Races Are Compile Errors
    details: Swift 6.2 StrictConcurrency on every target. Non-Sendable types crossing actor boundaries won't build.
    link: /agents
    linkText: See agent types

  - icon: 💾
    title: Workflows Survive Crashes
    details: Advanced workflows can checkpoint and resume with explicit checkpoint stores and deterministic IDs.
    link: /reference/overview
    linkText: Explore checkpointing

  - icon: 🧠
    title: Semantic Memory — On-Device
    details: VectorMemory uses Accelerate SIMD for cosine similarity. No cloud API. No network call. Just fast local retrieval.
    link: /memory
    linkText: Memory systems

  - icon: 🔌
    title: Any LLM, Same Code
    details: Foundation Models, Anthropic, OpenAI, Ollama, Gemini, MLX. Swap providers with one line.
    link: /providers
    linkText: Configure providers

  - icon: ⚡
    title: Production Resilience
    details: Retry with 7 backoff strategies, circuit breakers, fallback agents, rate limiting, and per-step timeouts.
    link: /resilience
    linkText: Add resilience
---

## Install

```swift
.package(url: "https://github.com/christopherkarani/Swarm.git", from: "0.3.4")
```

## Quick Start

```swift
import Swarm

@Tool("Looks up the current stock price")
struct PriceTool {
    @Parameter("Ticker symbol") var ticker: String
    func execute() async throws -> String { "182.50" }
}

let agent = Agent(
    name: "Analyst",
    tools: [PriceTool()],
    instructions: "Answer finance questions using real data."
)

let result = try await agent
    .environment(\.inferenceProvider, .anthropic(key: "sk-..."))
    .run("What is AAPL trading at?")
```

## How Swarm Compares

| | **Swarm** | LangChain | AutoGen |
|---|---|---|---|
| Language | **Swift 6.2** | Python | Python |
| Data race safety | **Compile-time** | Runtime | Runtime |
| On-device LLM | **Foundation Models** | — | — |
| Execution engine | **Compiled DAG** | Loop-based | Loop-based |
| Crash recovery | **Auto checkpoints** | — | Partial |
| Type-safe tools | **@Tool macro** | Decorators | Runtime |
| Streaming | **AsyncThrowingStream** | Callbacks | Callbacks |
| iOS / macOS | **First-class** | — | — |
