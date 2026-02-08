
<img width="3168" height="1344" alt="Gemini_Generated_Image_hflm6thflm6thflm" src="https://github.com/user-attachments/assets/62b0d34a-a0d4-45a9-a289-0e384939839f" />


[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20|%20macOS%2014%2B%20|%20Linux-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

**Build autonomous AI agents in Swift** — The agent framework for Apple platforms and Linux servers.

Swarm provides everything you need to build AI agents: autonomous reasoning, tool use, memory systems, and multi-agent orchestration. Built natively for Swift 6.2 with full concurrency safety.

## Highlights

- **Agents** — `AgentRuntime` implementations (ToolCalling, ReAct, PlanAndExecute) and `@AgentActor` macro
- **Workflows** — SwiftUI-style `AgentBlueprint` orchestration (preferred) + legacy loop DSL (deprecated)
- **Tools** — Typed `Tool` API, `@Tool` macro, `FunctionTool` closures, and `AnyJSONTool` ABI
- **Runner** — Static `Runner.run()` / `Runner.stream()` entry points separating definition from execution
- **Agent Composition** — Use any agent as a tool via `.asTool()` for hierarchical delegation
- **Memory** — Conversation, summary, and vector memory systems
- **Multi-Agent** — Supervisor routing, chains, handoffs, and parallel execution
- **Streaming** — Real-time event streaming for responsive UIs
- **Guardrails** — Input/output validation for safe AI interactions
- **Observability** — Default tracing out of the box, opt-out with `defaultTracingEnabled: false`
- **MCP** — Model Context Protocol integration
- **Cross-Platform** — iOS, macOS, watchOS, tvOS, visionOS, and Linux

## Runtime (Hive)

On macOS/iOS, Swarm uses Hive graph execution by default (when `HiveCore` is available). Set `SWARM_HIVE_RUNTIME=0` at build time to opt out and use the built-in Swift executor.

If a sibling Hive checkout exists at `../Hive`, Swarm auto-uses it; set `SWARM_USE_LOCAL_HIVE=0` to force the remote package (or `SWARM_USE_LOCAL_HIVE=1` to force local).

---

## For Coding Agents

### Retrieving Context (Sessions + Memory)

Swarm intentionally keeps **context retrieval** explicit and inspectable. In practice, you’ll pull context from either:

- **Session** (conversation history): `getItems(limit:)`
- **Memory** (RAG / summaries / recent-window): `context(for:tokenLimit:)` and `allMessages()`

```swift
// Session history (for UIs, debugging, or custom prompt building)
let history = try await session.getItems(limit: 20)

// Memory context string (what you want the model to “see” as context)
let context = await memory.context(for: "billing policy", tokenLimit: 1_200)

// Raw memory messages (for inspection / tests)
let messages = await memory.allMessages()
```

If your memory conforms to `MemoryPromptDescriptor` (e.g. `WaxMemory`), you can also expose UI labels/guidance:

```swift
if let descriptor = memory as? any MemoryPromptDescriptor {
    print(descriptor.memoryPromptTitle)
    print(descriptor.memoryPromptGuidance ?? "")
}
```

### Copy/Paste Prompts

Use these prompts verbatim in Claude Code / Codex / ChatGPT when working with this repo or integrating Swarm.

#### 1) Repo Orientation

```text
You are a coding agent integrating Swarm.
Please:
1) Read AGENTS.md and README.md.
2) Summarize the preferred API surface (AgentBlueprint + @Tool + @AgentActor).
3) Point me to the 5 most relevant docs pages for orchestration + tools + memory.
4) Give me a minimal “hello world agent” that compiles (no external services).
```

#### 2) “How do I retrieve context?”

```text
In Swarm, show me how to retrieve:
- session history (Session.getItems)
- model context from memory (Memory.context(for:tokenLimit:))
- raw messages (Memory.allMessages)
Include one example using WaxMemory and one using ConversationMemory.
```

#### 3) Compose a Complex Workflow

```text
Design an AgentBlueprint for: plan -> implement -> review -> summarize.
Constraints:
- Use Agent runtime steps.
- Use Parallel for implement+tests where appropriate.
- Use Router to pick specialist agents.
- Keep it hard to misuse (types, names, minimal magic).
Return a single Swift file with the blueprint + setup code.
```

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/christopherkarani/Swarm.git", from: "0.3.1")
]
```

Add to your target:

```swift
.target(name: "YourApp", dependencies: ["Swarm"])
```

### Xcode

File → Add Package Dependencies → `https://github.com/christopherkarani/Swarm.git`

---

### Optional integrations (Wax)

Wax support lives behind a SwiftPM trait so that the adapter only builds when you explicitly enable it. Conduit is now built into `Swarm`.

Enable the Wax trait when declaring the dependency and bind the trait-aware product inside your target:

```swift
.package(
    url: "https://github.com/christopherkarani/Swarm.git",
    from: "0.3.1",
    traits: ["Wax"]
)

.target(
    name: "YourApp",
    dependencies: [
        .product(
            name: "SwarmWax",
            package: "Swarm",
            condition: .when(traits: ["Wax"])
        ),
        "Swarm"
    ]
)
```

When invoking SwiftPM directly you must supply `defaults` along with the traits you want:

```bash
swift build --traits defaults,Wax
```

The trait also defines a compile-time flag (`SWARM_WAX_ENABLED`) so downstream code can guard integrations.

---

## Wax Memory (RAG)

When the Wax trait is enabled, you can use `WaxMemory` as a primary RAG-backed memory store:

```swift
import Swarm
import SwarmWax
import WaxVectorSearchMiniLM

let embedder = MiniLMEmbedder()
let memory = try await WaxMemory(url: waxURL, embedder: embedder)

let result = try await CustomerService()
    .environment(\.inferenceProvider, provider)
    .environment(\.memory, memory)
    .run("Summarize our billing policy.")
```

When using the legacy loop DSL, `Relay()` will prioritize Wax memory context when present.

---

## Quick Start

Start with runtime agents for model calls, then compose them with the SwiftUI-style `AgentBlueprint` workflow DSL when you need orchestration. The legacy loop DSL (`AgentLoopDefinition` + `@AgentLoopBuilder`) remains for compatibility but is deprecated.

```swift
import Swarm

let provider: any InferenceProvider = .anthropic(key: "ANTHROPIC_API_KEY")

struct CustomerService: AgentBlueprint {
    let billing = Agent(
        name: "Billing",
        tools: [CalculatorTool()],
        instructions: "You are billing support. Be concise."
    )

    let general = Agent(
        name: "General",
        instructions: "You are general customer support."
    )

    @OrchestrationBuilder var body: some OrchestrationStep {
        Guard(.input) {
            InputGuard("no_secrets") { input in
                input.contains("password") ? .tripwire(message: "Sensitive data") : .passed()
            }
        }

        Router {
            When(.contains("billing"), name: "billing") { billing }
            Otherwise { general }
        }

        Guard(.output) {
            OutputGuard("no_pii") { output in
                output.contains("SSN") ? .tripwire(message: "PII detected") : .passed()
            }
        }
    }
}

let result = try await CustomerService()
    .environment(\.inferenceProvider, provider)
    .run("billing help")

print(result.output)
```

Notes:
- `AgentBlueprint` is the preferred SwiftUI-style workflow DSL; embed `AgentRuntime` steps (Agent/ReActAgent/PlanAndExecuteAgent).
- The legacy loop DSL (`AgentLoopDefinition` + `Relay()`/`Generate()`) is deprecated for new code.
- The actor macro for boilerplate-free runtime agents is `@AgentActor` (renamed from `@Agent`).
- You can also pass a provider directly: `let agent = Agent(.anthropic(key: "ANTHROPIC_API_KEY"))`.
- If you don’t provide an inference provider, `Agent` will try Apple Foundation Models (on-device) when available; otherwise `Agent.run(...)` throws `AgentError.inferenceProviderUnavailable`.

---

## Key Features

### Streaming Responses

Stream the blueprint you just defined and inspect `AgentEvent` cases:

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

Define focused runtime agents and let a supervisor route requests based on routing strategy:

```swift
let mathAgent = Agent(
    name: "Math",
    tools: [CalculatorTool()],
    instructions: "Solve billing math crisply."
)

let weatherAgent = Agent(
    name: "Weather",
    tools: [WeatherTool()],
    instructions: "Report weather succinctly."
)

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
        (name: mathDesc.name, agent: mathAgent, description: mathDesc),
        (name: weatherDesc.name, agent: weatherAgent, description: weatherDesc)
    ],
    routingStrategy: strategy,
    fallbackAgent: Agent(instructions: "You are general customer support.")
)

let result = try await supervisor.run("What is 15 × 23?")
print(result.output)
```

> Swap in `LLMRoutingStrategy(inferenceProvider: provider)` when you want the supervisor to reason about intent in addition to keywords.

> See [docs/orchestration.md](docs/orchestration.md) for chains, parallel execution, and handoffs built on top of runtime agents and blueprints.

### Session Management

Store conversation history for longer-lived interactions while keeping blueprints stateless:

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

Guard inputs and outputs in a blueprint by surrounding a runtime agent step:

```swift
struct GuardedAgent: AgentBlueprint {
    let core = Agent(instructions: "Only pass safe content through.")

    @OrchestrationBuilder var body: some OrchestrationStep {
        Guard(.input) {
            InputGuard("no_shouting") { input in
                input.contains("SHOUT") ? .tripwire(message: "Calm please") : .passed()
            }
        }

        core

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

Offer Model Context Protocol tools directly on runtime agents:

```swift
let client = MCPClient()
let server = HTTPMCPServer(name: "my-server", baseURL: serverURL)
try await client.addServer(server)

let mcpTools = try await client.getAllTools()

let researchAgent = Agent(
    tools: mcpTools,
    instructions: "Research the topic with MCP tools."
)
let researchResult = try await researchAgent
    .environment(\.inferenceProvider, provider)
    .run("Summarize the latest updates.")
print(researchResult.output)
```

> See [docs/mcp.md](docs/mcp.md) for server implementations, tool discovery, and caching strategies.

### Tools on Runtime Agents

Runtime agents accept typed tools. The `@Tool` macro reduces boilerplate by generating `Tool` conformance and the JSON schema the model uses for calls.

```swift
@Tool("Calculates totals")
struct CalculatorTool {
    @Parameter("Values to sum")
    var values: [Double]

    func execute() async throws -> Double {
        try values.reduce(0, +)
    }
}

let billingAgent = Agent(
    tools: [CalculatorTool()],
    instructions: "Use calculator for numeric requests."
)

let billingResult = try await billingAgent
    .environment(\.inferenceProvider, provider)
    .run("What is 25% of 200?")
```

Agent (and ReActAgent / PlanAndExecuteAgent) bridge typed tools to the `AnyJSONTool` ABI so the model can plan tool calls, pass structured parameters, and receive typed results without extra plumbing.

#### FunctionTool — Inline Closures

For simple one-off tools, skip the struct ceremony with `FunctionTool`:

```swift
let getWeather = FunctionTool(
    name: "get_weather",
    description: "Gets weather for a city",
    parameters: [
        ToolParameter(name: "city", description: "City name", type: .string, isRequired: true)
    ]
) { args in
    let city = try args.require("city", as: String.self)
    return .string("72F in \(city)")
}

let agent = Agent(name: "Assistant", tools: [getWeather], instructions: "Help with weather.")
```

`FunctionTool` conforms to `AnyJSONTool` and works anywhere a typed tool does — agent registration, blueprints, and tool registries.

#### Runtime Tool Toggling

Tools support an `isEnabled` property for conditional availability. Disabled tools are excluded from LLM schemas and rejected at execution time:

```swift
struct AdminTool: AnyJSONTool {
    let name = "admin_reset"
    let description = "Resets user data"
    let parameters: [ToolParameter] = []
    var isEnabled: Bool { UserDefaults.standard.bool(forKey: "isAdmin") }

    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        // ...
    }
}
```

### Runner — Execution Entry Point

`Runner` provides a static API for agent execution, cleanly separating agent definition from execution concerns:

```swift
let agent = Agent(name: "Assistant", instructions: "You are helpful.")

// Simple execution:
let result = try await Runner.run(agent, input: "Hello!")

// With session:
let result = try await Runner.run(agent, input: "Hello!", session: mySession)

// Streaming:
for try await event in Runner.stream(agent, input: "What's the weather?") {
    switch event {
    case .chunk(let text):
        print(text, terminator: "")
    default:
        break
    }
}
```

### Agent Composition — Agents as Tools

Use any agent as a callable sub-tool for another agent via `.asTool()`. The inner agent runs with the provided input and returns its output as the tool result:

```swift
let researcher = Agent(
    name: "Researcher",
    instructions: "You research topics thoroughly.",
    tools: [searchTool]
)

let writer = Agent(
    name: "Writer",
    instructions: "Use the researcher for facts, then write clearly.",
    tools: [researcher.asTool()]
)

let result = try await Runner.run(writer, input: "Write about quantum computing")
```

This enables hierarchical agent patterns without full orchestration infrastructure like `Swarm` or `SupervisorAgent`.

### Handoffs

Pass agents directly as handoff targets — no manual `HandoffConfiguration` wrapping needed:

```swift
let billing = Agent(name: "Billing", instructions: "Handle billing questions.")
let support = Agent(name: "Support", instructions: "Handle support requests.")

let triage = Agent(
    name: "Triage",
    instructions: "Route requests to billing or support.",
    handoffAgents: [billing, support]
)
```

When using standalone `Agent` (outside `Swarm`), handoffs automatically appear as callable tools (e.g., `transfer_to_billing`). For fine-grained control, use `.asHandoff()`:

```swift
let handoff = billing.asHandoff(
    toolName: "transfer_to_billing",
    description: "Transfer billing questions"
)
```

### Resilience

Wrap runtime agents (or blueprint executions) with retry, timeout, fallback, and circuit-breaker behaviors:

```swift
let resilientAgent = CustomerService()
    .environment(\.inferenceProvider, provider)
    .withRetry(.exponentialBackoff(maxAttempts: 3, baseDelay: .seconds(1)))
    .withCircuitBreaker(threshold: 5, resetTimeout: .seconds(60))
    .withFallback(Agent(instructions: "You are general customer support."))
    .withTimeout(.seconds(30))

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
│                 Runner.run() / .stream()                 │
├─────────────────────────────────────────────────────────┤
│                        Swarm                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │   Agents    │ │   Memory    │ │    Tools    │       │
│  │ ReAct, Plan │ │ Conversation│ │ @Tool macro │       │
│  │ Agent       │ │ Vector, Sum │ │ FunctionTool│       │
│  └─────────────┘ └─────────────┘ └─────────────┘       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │Orchestration│ │ Guardrails  │ │Observability│       │
│  │ Supervisor  │ │ Input/Output│ │ Tracing     │       │
│  │ Handoffs    │ │ Validation  │ │ Metrics     │       │
│  └─────────────┘ └─────────────┘ └─────────────┘       │
│  ┌─────────────┐ ┌─────────────┐                        │
│  │    MCP      │ │ AgentTool   │                        │
│  │ Client/Srv  │ │ .asTool()   │                        │
│  │ Protocol    │ │ Composition │                        │
│  └─────────────┘ └─────────────┘                        │
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

- **Issues**: [GitHub Issues](https://github.com/christopherkarani/Swarm/issues)
- **Discussions**: [GitHub Discussions](https://github.com/christopherkarani/Swarm/discussions)
- **Twitter**: [@ckarani7](https://x.com/ckarani7)

---

## License

Swarm is released under the MIT License. See [LICENSE](LICENSE) for details.

---

Built with Swift for Apple platforms and Linux servers.
