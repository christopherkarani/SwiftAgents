
<img width="3168" height="1344" alt="Gemini_Generated_Image_hflm6thflm6thflm" src="https://github.com/user-attachments/assets/62b0d34a-a0d4-45a9-a289-0e384939839f" />


[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20|%20macOS%2014%2B%20|%20Linux-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

**Build autonomous AI agents in Swift** — The agent framework for Apple platforms and Linux servers.

SwiftAgents provides everything you need to build AI agents: autonomous reasoning, tool use, memory systems, and multi-agent orchestration. Built natively for Swift 6.2 with full concurrency safety.

## Highlights

- **Agents** — ReAct, PlanAndExecute, and ToolCalling patterns
- **Tools** — Typed `Tool` API, `@Tool` macro, and `AnyJSONTool` ABI
- **Memory** — Conversation, summary, and vector memory systems
- **Multi-Agent** — Supervisor routing, chains, and parallel execution
- **Streaming** — Real-time event streaming for responsive UIs
- **Guardrails** — Input/output validation for safe AI interactions
- **MCP** — Model Context Protocol integration
- **Cross-Platform** — iOS, macOS, watchOS, tvOS, visionOS, and Linux

---

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/christopherkarani/SwiftAgents.git", from: "0.3.1")
]
```

Add to your target:

```swift
.target(name: "YourApp", dependencies: ["SwiftAgents"])
```

### Xcode

File → Add Package Dependencies → `https://github.com/chriskarani/SwiftAgents.git`

---

### Optional integrations (Wax)

Wax support lives behind a SwiftPM trait so that the adapter only builds when you explicitly enable it. Conduit is now built into `SwiftAgents`.

Enable the Wax trait when declaring the dependency and bind the trait-aware product inside your target:

```swift
.package(
    url: "https://github.com/christopherkarani/SwiftAgents.git",
    from: "0.3.1",
    traits: ["Wax"]
)

.target(
    name: "YourApp",
    dependencies: [
        .product(
            name: "SwiftAgentsWax",
            package: "SwiftAgents",
            condition: .when(traits: ["Wax"])
        ),
        "SwiftAgents"
    ]
)
```

When invoking SwiftPM directly you must supply `defaults` along with the traits you want:

```bash
swift build --traits defaults,Wax
```

The trait also defines a compile-time flag (`SWIFTAGENTS_WAX_ENABLED`) so downstream code can guard integrations.

---

## Wax Memory (RAG)

When the Wax trait is enabled, you can use `WaxMemory` as a primary RAG-backed memory store:

```swift
import SwiftAgents
import SwiftAgentsWax
import WaxVectorSearchMiniLM

let embedder = MiniLMEmbedder()
let memory = try await WaxMemory(url: waxURL, embedder: embedder)

let result = try await CustomerService()
    .environment(\.inferenceProvider, provider)
    .environment(\.memory, memory)
    .run("Summarize our billing policy.")
```

`Relay()` (the unified loop node) will prioritize Wax memory context when present.

---

## Quick Start

Design, configure, and execute agents solely through the SwiftUI-style DSL. Define your domain logic on value types and expose configuration via properties, then run or stream the agent when ready.

```swift
import SwiftAgents

let provider = MyInferenceProvider()

struct CustomerService: Agent {
    var instructions: String { "You are a helpful customer service agent." }

    var loop: some AgentLoop {
        Guard(.input) {
            InputGuard("no_secrets") { input in
                input.contains("password") ? .tripwire(message: "Sensitive data") : .passed()
            }
        }

        Routes {
            When(.contains("billing"), name: "billing") {
                Billing()
                    .temperature(0.2)
            }
            Otherwise {
                GeneralSupport()
            }
        }

        Guard(.output) {
            OutputGuard("no_pii") { output in
                output.contains("SSN") ? .tripwire(message: "PII detected") : .passed()
            }
        }
    }
}

struct Billing: Agent {
    var instructions: String { "You are billing support. Be concise." }
    var loop: some AgentLoop { Relay() }
}

struct GeneralSupport: Agent {
    var instructions: String { "You are general customer support." }
    var loop: some AgentLoop { Relay() }
}

let result = try await CustomerService()
    .environment(\.inferenceProvider, provider)
    .run("billing help")

print(result.output)
```

Notes:
- `Relay()` (aka `Generate()`) resolves its inference provider from the current environment and throws if none is set.
- Every `AgentLoop` must include a `Generate()` or `Relay()` call, either directly or through a sub-agent like `Billing`/`GeneralSupport`.
- The sample matches `Tests/SwiftAgentsTests/DSL/DeclarativeAgentDSLTests.swift`, so the guards and routes are exercised in automated tests.

---

## Key Features

### Streaming Responses

Stream the DSL agent you just defined and inspect `AgentEvent` cases:

```swift
let streamingAgent = CustomerService()
    .environment(\.inferenceProvider, provider)

for try await event in streamingAgent.stream("Explain quantum computing") {
    switch event {
    case .thinking(let thought):
        print("Thinking: \(thought)")
    case .toolCalling(let call):
        print("Calling tool: \(call.toolName)")
    case .chunk(let text):
        print(text, terminator: "")
    case .completed(let result):
        print("\nDone in \(result.duration)")
    case .failed(let error):
        print("Error: \(error)")
    default:
        break
    }
}
```

> See [docs/streaming.md](docs/streaming.md) for SwiftUI integration samples that consume `stream(...)`.

### Multi-Agent Orchestration

Define focused agents as value types and let a supervisor route requests based on the DSL logic:

```swift
struct MathSpecialist: Agent {
    var instructions: String { "Solve billing math crisply." }
    var loop: some AgentLoop { Relay() }
}

struct WeatherSpecialist: Agent {
    var instructions: String { "Report weather succinctly." }
    var loop: some AgentLoop { Relay() }
}

let mathDesc = AgentDescription(
    name: "math",
    description: "Handles billing calculations",
    keywords: ["math", "calculate"]
)

let weatherDesc = AgentDescription(
    name: "weather",
    description: "Handles weather inquiries",
    keywords: ["weather", "forecast"]
)

let strategy = KeywordRoutingStrategy()
let supervisor = SupervisorAgent(
    agents: [
        (name: mathDesc.name, agent: MathSpecialist(), description: mathDesc),
        (name: weatherDesc.name, agent: WeatherSpecialist(), description: weatherDesc)
    ],
    routingStrategy: strategy,
    fallbackAgent: GeneralSupport()
)

let result = try await supervisor.run("What is 15 × 23?")
print(result.output)
```

> Swap in `LLMRoutingStrategy(inferenceProvider: provider)` when you want the supervisor to reason about intent in addition to keywords.

> See [docs/orchestration.md](docs/orchestration.md) for chains, parallel execution, and handoffs built on top of DSL agents.

### Session Management

Store conversation history for longer-lived interactions while keeping DSL agents stateless:

```swift
let session = InMemorySession(sessionId: "user_123")
let customerService = CustomerService()
    .environment(\.inferenceProvider, provider)

try await customerService.run("Remember: my favorite color is blue", session: session)
try await customerService.run("What's my favorite color?", session: session)
// → "Your favorite color is blue."
```

> See [docs/sessions.md](docs/sessions.md) for persistence adapters, including `PersistentSession` on Apple platforms.

### Guardrails

Guard the inputs and outputs of DSL loops before or after calling `Relay()`:

```swift
struct GuardedAgent: Agent {
    var instructions: String { "Only pass safe content through." }

    var loop: some AgentLoop {
        Guard(.input) {
            InputGuard("no_shouting") { input in
                input.contains("SHOUT") ? .tripwire(message: "Calm please") : .passed()
            }
        }

        Relay()

        Guard(.output) {
            OutputGuard("no_pii") { output in
                output.contains("SSN") ? .tripwire(message: "PII detected") : .passed()
            }
        }
    }
}
```

> See [docs/guardrails.md](docs/guardrails.md) for helper guardrails and automatic metadata recording.

### MCP Integration

Offer Model Context Protocol tools directly on DSL agents:

```swift
let client = MCPClient()
let server = HTTPMCPServer(name: "my-server", baseURL: serverURL)
try await client.addServer(server)

let mcpTools = try await client.getAllTools()

struct ResearchAgent: Agent {
    var instructions: String { "Research the topic with MCP tools." }
    var tools: [any AnyJSONTool]
    var loop: some AgentLoop { Relay() }
}

let researchAgent = ResearchAgent(tools: mcpTools)
let researchResult = try await researchAgent
    .environment(\.inferenceProvider, provider)
    .run("Summarize the latest updates.")
print(researchResult.output)
```

> See [docs/mcp.md](docs/mcp.md) for server implementations, tool discovery, and caching strategies.

### Tools in the DSL

Every DSL agent can provide a `tools` array, and `Relay()` automatically makes those tools available to the inference provider (along with the agent’s instructions, guardrails, and environment). The `@Tool` macro reduces boilerplate by generating the necessary `Tool` conformance and typed parameters that `Relay()` exposes to the model.

```swift
@Tool("Calculates totals")
struct CalculatorTool {
    @Parameter("Values to sum")
    var values: [Double]

    func execute() async throws -> Double {
        try values.reduce(0, +)
    }
}

struct BillingAgent: Agent {
    var instructions: String { "Use calculator for numeric requests." }
    var tools: [any AnyJSONTool] { [CalculatorTool()] }
    var loop: some AgentLoop { Relay() }
}

let billingResult = try await BillingAgent()
    .environment(\.inferenceProvider, provider)
    .run("What is 25% of 200?")
```

When `Relay()` runs, it introspects the agent’s `tools` list (including any tool macros, wrappers, or imported MCP `ToolSchema`s) so the model can plan tool calls, pass in structured parameters, and receive typed results without extra plumbing. Guardrails and modifiers still wrap `Relay()`, keeping the DSL-focused flow consistent.

### Resilience

Wrap DSL agents with retry, timeout, fallback, and circuit-breaker behaviors:

```swift
let resilientAgent = CustomerService()
    .environment(\.inferenceProvider, provider)
    .retry(.exponentialBackoff(maxAttempts: 3, baseDelay: .seconds(1)))
    .withCircuitBreaker(threshold: 5, resetTimeout: .seconds(60))
    .withFallback(GeneralSupport())
    .timeout(.seconds(30))

let final = try await resilientAgent.run("Handle billing help urgently.")
print(final.output)
```

> See [docs/resilience.md](docs/resilience.md) for circuit breakers, retry policies, and fallback helpers.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your Application                      │
│         (iOS, macOS, watchOS, tvOS, visionOS, Linux)    │
├─────────────────────────────────────────────────────────┤
│                      SwiftAgents                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │   Agents    │ │   Memory    │ │    Tools    │       │
│  │ ReAct, Plan │ │ Conversation│ │ @Tool macro │       │
│  │ ToolCalling │ │ Vector, Sum │ │ Registry    │       │
│  └─────────────┘ └─────────────┘ └─────────────┘       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │Orchestration│ │ Guardrails  │ │    MCP      │       │
│  │ Supervisor  │ │ Input/Output│ │ Client/Srv  │       │
│  │ Chains      │ │ Validation  │ │ Protocol    │       │
│  └─────────────┘ └─────────────┘ └─────────────┘       │
├─────────────────────────────────────────────────────────┤
│              InferenceProvider Protocol                  │
│    (Foundation Models / SOTA Models / Local )        │
└─────────────────────────────────────────────────────────┘
```

**Cross-Platform**: Core framework works on all platforms. SwiftData persistence is Apple-only.

---

## Documentation

| Topic | Description |
|-------|-------------|
| [Agents](docs/agents.md) | Agent types, configuration, @AgentActor macro |
| [Tools](docs/tools.md) | Tool creation, @Tool macro, ToolRegistry |
| [Memory](docs/memory.md) | Memory systems and persistence backends |
| [Sessions](docs/sessions.md) | Session management and history |
| [Orchestration](docs/orchestration.md) | Multi-agent patterns and handoffs |
| [Streaming](docs/streaming.md) | Event streaming and SwiftUI integration |
| [Observability](docs/observability.md) | Tracing, metrics, and logging |
| [Resilience](docs/resilience.md) | Circuit breakers, retry, fallbacks |
| [Guardrails](docs/guardrails.md) | Input/output validation |
| [MCP](docs/mcp.md) | Model Context Protocol integration |
| [DSL](docs/dsl.md) | Operators and builders |
| [Providers](docs/providers.md) | InferenceProvider implementations |

---

## Requirements

- **Swift**: 6.2+
- **Apple Platforms**: iOS 17+, macOS 14+, watchOS 10+, tvOS 17+, visionOS 1+
- **Linux**: Ubuntu 22.04+ with Swift 6.2

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make changes following Swift 6.2 concurrency guidelines
4. Add tests for new functionality
5. Run `swift test` and `swift package plugin swiftformat`
6. Submit a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## Support

- **Issues**: [GitHub Issues](https://github.com/chriskarani/SwiftAgents/issues)
- **Discussions**: [GitHub Discussions](https://github.com/chriskarani/SwiftAgents/discussions)
- **Twitter**: [@ckarani7](https://x.com/ckarani7)

---

## License

SwiftAgents is released under the MIT License. See [LICENSE](LICENSE) for details.

---

Built with Swift for Apple platforms and Linux servers.
