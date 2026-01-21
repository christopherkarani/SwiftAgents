# SwiftAgents

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

## Quick Start

### 1. Basic Agent

```swift
import SwiftAgents

// Initialize logging once at startup
Log.bootstrap()

// Create your inference provider
let provider = MyInferenceProvider()

// Build and run an agent
let agent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .instructions("You are a helpful assistant.")
    .build()

let result = try await agent.run("What is the capital of France?")
print(result.output)  // "The capital of France is Paris."
```

### 2. Agent with Tools

Create tools using the `@Tool` macro:

```swift
@Tool("Calculate mathematical expressions")
struct CalculatorTool {
    @Parameter("The math expression to evaluate")
    var expression: String

    func execute() async throws -> Double {
        // Your calculation logic
        let result = try evaluate(expression)
        return result
    }
}

// Add tools to your agent
let agent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .instructions("You are a math assistant.")
    .addTool(CalculatorTool())
    .build()

let result = try await agent.run("What is 25% of 200?")
print(result.output)  // "50"
```

### 3. Agent with Memory

Maintain conversation context across interactions:

```swift
let memory = ConversationMemory(maxMessages: 100)

let agent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .memory(memory)
    .instructions("You are a friendly assistant.")
    .build()

// First message
let r1 = try await agent.run("My name is Alice.")
print(r1.output)  // "Nice to meet you, Alice!"

// Agent remembers context
let r2 = try await agent.run("What's my name?")
print(r2.output)  // "Your name is Alice."
```

---

## Key Features

### Streaming Responses

Stream agent execution in real-time:

```swift
for try await event in agent.stream("Explain quantum computing") {
    switch event {
    case .thinking(let thought):
        print("Thinking: \(thought)")
    case .toolCalling(let call):
        print("Using tool: \(call.toolName)")
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

> See [docs/streaming.md](docs/streaming.md) for SwiftUI integration examples.

### Multi-Agent Orchestration

Route requests to specialized agents:

```swift
// Create specialized agents
let mathAgent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .addTool(CalculatorTool())
    .instructions("You are a math specialist.")
    .build()

let weatherAgent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .addTool(WeatherTool())
    .instructions("You are a weather specialist.")
    .build()

// Create supervisor with intelligent routing
let supervisor = SupervisorAgent(
    agents: [
        (name: "math", agent: mathAgent, description: mathDesc),
        (name: "weather", agent: weatherAgent, description: weatherDesc)
    ],
    routingStrategy: LLMRoutingStrategy(inferenceProvider: provider)
)

// Supervisor routes to the right agent
let result = try await supervisor.run("What's 15 × 23?")
// → Routes to math agent
```

> See [docs/orchestration.md](docs/orchestration.md) for chains, parallel execution, and handoffs.

### Declarative Agents (SwiftUI-Style DSL)

Define agents as value types with explicit execution flow:

```swift
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
                Billing().temperature(0.2)
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
    var loop: some AgentLoop { Respond() }
}

struct GeneralSupport: Agent {
    var loop: some AgentLoop { Respond() }
}

let result = try await CustomerService()
    .environment(\.inferenceProvider, provider)
    .run("billing help")
```

### Session Management

Persist conversation history:

```swift
// In-memory session (ephemeral)
let session = InMemorySession(sessionId: "user_123")

try await agent.run("Remember: my favorite color is blue", session: session)
try await agent.run("What's my favorite color?", session: session)
// → "Your favorite color is blue."

// Persistent session (survives app restart - Apple platforms)
#if canImport(SwiftData)
let persistentSession = try PersistentSession.persistent(sessionId: "user_123")
#endif
```

> See [docs/sessions.md](docs/sessions.md) for session operations and persistence.

### Guardrails

Validate inputs and outputs for safety:

```swift
let inputGuardrail = InputGuard("ContentFilter") { input in
    if containsProhibitedContent(input) {
        return .tripwire(message: "Prohibited content detected")
    }
    return .passed()
}

let outputGuardrail = OutputGuard("PIIRedactor") { output in
    // Redact sensitive info from output
    let redacted = redactSensitiveInfo(output)
    return .passed(metadata: ["redacted": .bool(redacted != output)])
}

let agent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .inputGuardrails([inputGuardrail])
    .outputGuardrails([outputGuardrail])
    .build()
```

> See [docs/guardrails.md](docs/guardrails.md) for safety patterns.

### MCP Integration

Connect to Model Context Protocol servers:

```swift
// Connect to MCP servers
let client = MCPClient()
let server = HTTPMCPServer(name: "my-server", baseURL: serverURL)
try await client.addServer(server)

// Get all tools from connected servers
let mcpTools = try await client.getAllTools()

// Use MCP tools with your agent
let agent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .tools(mcpTools)
    .build()
```

> See [docs/mcp.md](docs/mcp.md) for server implementation.

### Resilience

Build robust agents with failure handling:

```swift
let resilientAgent = agent
    .withRetry(.exponentialBackoff(maxAttempts: 3))
    .withCircuitBreaker(threshold: 5, resetTimeout: .seconds(60))
    .withFallback(backupAgent)
    .withTimeout(.seconds(30))
```

> See [docs/resilience.md](docs/resilience.md) for circuit breakers and retry policies.

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
│    (Foundation Models / OpenRouter / Custom LLMs)        │
└─────────────────────────────────────────────────────────┘
```

**Cross-Platform**: Core framework works on all platforms. SwiftData persistence is Apple-only.

---

## Documentation

| Topic | Description |
|-------|-------------|
| [Agents](docs/agents.md) | Agent types, configuration, @Agent macro |
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
