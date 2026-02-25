# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Swarm is a Swift 6.2 multi-agent orchestration framework — "LangChain for Apple platforms." It provides agent reasoning, memory systems, tool execution, and multi-agent coordination on top of pluggable inference providers (Apple Foundation Models, Anthropic, OpenAI, Ollama, Gemini, MLX via Conduit).

**Platforms**: macOS 26+, iOS 26+ (Apple Intelligence-era), Linux (Ubuntu 22.04+ with Swift 6.2)

## Build & Test Commands

```bash
swift build                                    # Build all targets
swift test                                     # Run all test suites
swift test --filter AgentTests                 # Run a specific test suite
swift test --filter AgentTests/testHandoff     # Run a single test
swift run SwarmDemo                            # Run demo (requires SWARM_INCLUDE_DEMO=1)
SWARM_INCLUDE_DEMO=1 swift build               # Build with demo targets included

# Formatting & linting
swift package plugin --allow-writing-to-package-directory swiftformat
swiftlint lint

# Coverage
./scripts/generate-coverage-report.sh          # Outputs to .build/coverage/, 70% threshold
```

**Environment variables**:
- `SWARM_INCLUDE_DEMO=1` — enables `SwarmDemo` and `SwarmMCPServerDemo` executable targets
- `SWARM_USE_LOCAL_DEPS=1` — uses local `../Wax` and `../Conduit` instead of remote packages

## Package Targets

| Target | Type | Purpose |
|--------|------|---------|
| `Swarm` | Library | Core framework — agents, tools, memory, orchestration, Hive integration |
| `SwarmMCP` | Library | MCP server bridge — exposes Swarm tools to MCP clients |
| `SwarmMacros` | Macro (compiler plugin) | `@Tool`, `@AgentActor`, `@Prompt`, `@Traceable` macros |
| `SwarmTests` | Test | Tests for Swarm + SwarmMCP |
| `SwarmMacrosTests` | Test | Macro expansion tests using SwiftSyntaxMacrosTestSupport |
| `HiveSwarmTests` | Test | Hive integration tests |

## Architecture — What Actually Matters

### Core Protocol: `AgentRuntime` (not "AgentProtocol")

`AgentRuntime` (in `Core/AgentRuntime.swift`) is THE central protocol. Every agent — `Agent`, `ReActAgent`, `PlanAndExecuteAgent`, `SupervisorAgent`, `HiveBackedAgent` — conforms to it.

```
AgentRuntime: Sendable
├── name, tools, instructions, configuration, memory
├── run(input:session:hooks:) async throws -> AgentResult
└── stream(input:session:hooks:) -> AsyncThrowingStream<AgentEvent, Error>
```

`InferenceProvider` (also in `AgentRuntime.swift`) is the protocol for LLM backends. Resolution order in `Agent`: explicit provider → `AgentEnvironmentValues.current.inferenceProvider` (TaskLocal) → Foundation Models → throws.

### Three DSL Generations

1. **`AgentLoopDefinition`** — deprecated legacy DSL using `AgentLoop`, `Generate()`, `Relay()`. Converts to `AgentRuntime` via `.asRuntime()`.
2. **`AgentBlueprint`** — current preferred SwiftUI-style protocol with `@OrchestrationBuilder var body: some OrchestrationStep`.
3. **`Orchestration` struct** — for purely structural (non-declarative) composition.

Always use `AgentBlueprint` for new code.

### Orchestration Always Goes Through Hive

Every `Orchestration { ... }` execution goes through `OrchestrationHiveEngine.makeGraph()`, which compiles `[OrchestrationStep]` into a HiveCore DAG. Even a single-step orchestration gets Hive's checkpointing and interrupt/resume infrastructure. There is no lightweight bypass.

The HiveSwarm bridge code lives at `Sources/Swarm/HiveSwarm/` (inside the Swarm target, NOT a separate target despite the name). Key files:
- `HiveBackedAgent.swift` — wraps an `AgentRuntime` as a Hive node
- `RetryPolicyBridge.swift` — converts Swarm retry policies to Hive retry policies (strips jitter for determinism)
- `SwarmToolRegistry.swift` — bridges Swarm tools to Hive's tool approval system

### `SendableValue` — The Universal Data Carrier

A JSON-compatible enum used everywhere `Any` would break `Sendable`:

```swift
public enum SendableValue: Sendable, Codable, Equatable {
    case string(String), int(Int), double(Double), bool(Bool)
    case array([SendableValue]), dictionary([String: SendableValue]), null
}
```

Appears in: tool arguments/results, `AgentResult.metadata`, `AgentContext` values, MCP request/response, `GuardrailResult.outputInfo`, `HandoffInputData`.

### Environment Injection via TaskLocal

`AgentEnvironmentValues` uses `@TaskLocal` for dependency injection (inference provider, tracer, memory). The `.environment(...)` modifier on `AgentRuntime` wraps execution in an `EnvironmentAgent` that sets TaskLocal values for the subtree.

### Handoffs Are Tools

Handoffs are injected as extra `ToolSchema` entries into `generateWithToolCalls`. When the LLM chooses a handoff tool (name: `handoff_to_<snake_case_target>`), `Agent` detects the match and calls `targetAgent.run()` directly. Not a separate communication channel.

### MultiProvider — Prefix-Based Routing

`MultiProvider` (actor) routes inference by model name prefix: `"anthropic/claude-3-5-sonnet"` → provider for `"anthropic"`. Models without a slash use the default provider. Enables mixing Claude, GPT, and Ollama in one orchestration.

### Orchestration Step Types (11)

Sequential, Parallel, DAGWorkflow, Router, RepeatWhile, Branch, Guard, Transform, Pipeline, SequentialChain, ParallelGroup. All conform to `OrchestrationStep` protocol. Built with `@OrchestrationBuilder` (a `@resultBuilder`).

DSL operators: `-->` (sequential chain), `>>>` (type-safe pipeline composition), `.dependsOn()` (DAG edges).

### Memory System

All memory types conform to `Memory: Actor, Sendable` — actor conformance is mandatory.

| Type | Purpose |
|------|---------|
| `ConversationMemory` | Rolling token-limited buffer |
| `VectorMemory` | SIMD cosine similarity via Accelerate (no network) |
| `SummaryMemory` | LLM-compressed history |
| `SlidingWindowMemory` | Fixed message count window |
| `PersistentMemory` | SwiftData-backed durable storage |

Backends: `InMemoryBackend`, `SwiftDataBackend` conforming to `PersistentMemoryBackend: Actor`.

### MCP — Two Directions

- `Sources/Swarm/MCP/` — Swarm as **MCP client** (fetches tools from external MCP servers)
- `Sources/SwarmMCP/` — Swarm as **MCP server** (exposes its tools to other MCP clients via `SwarmMCPServerService`)

### External Dependencies

| Package | Purpose |
|---------|---------|
| **Conduit** | Unified inference provider abstraction — wraps Anthropic, OpenAI, Ollama, Gemini, OpenRouter APIs |
| **Wax** | Embedding provider + vector operations for `VectorMemory` |
| **HiveCore** (from Hive) | Compiled DAG execution engine, checkpointing, interrupt/resume |
| **swift-syntax** | Powers `SwarmMacros` compiler plugin |
| **swift-log** | Cross-platform logging (`Log.agents`, `Log.memory`, `Log.orchestration`, etc.) |
| **swift-sdk** (MCP) | Model Context Protocol Swift SDK |

## Key Conventions

### Concurrency
- `StrictConcurrency` enabled on ALL targets — non-`Sendable` types crossing actor boundaries are build errors
- All public types must be `Sendable`
- Memory protocol requires `Actor` conformance
- `Tracer` protocol requires `Actor` conformance
- Use structured concurrency (`TaskGroup`, `async let`) over unstructured `Task { }`

### Testing
- Use Swift Testing (`import Testing`, `@Suite`, `@Test`) — not XCTest
- Foundation Models unavailable in test — always use `MockInferenceProvider`
- Mocks live in `Tests/SwarmTests/Mocks/` (`MockInferenceProvider`, `MockAgentMemory`, `MockSummarizer`, `MockTool`)
- Test files mirror source structure: `Tests/SwarmTests/Core/`, `Tests/SwarmTests/Orchestration/`, etc.

### Logging
- Use `swift-log` category loggers: `Log.agents`, `Log.memory`, `Log.tracing`, `Log.metrics`, `Log.orchestration`
- Never use `print()` in production code
- swift-log does NOT support `privacy:` annotations — do not log PII

### Commit Style
- Short, imperative, capitalized: `Add`, `Fix`, `Refactor`, `Default`, `Revert`

## Agent Orchestration System (Claude Code Sub-Agents)

### Agent Registry

#### Tier 1: Orchestration (Route & Coordinate)
| Agent | Model | Role |
|-------|-------|------|
| **Lead Session** | opus | Router, delegator, user interface |
| `context-builder` | sonnet | Research at start of tasks spanning 3+ files |
| `context-manager` | haiku | Context preservation between phases |

#### Tier 2: Design (Read-Only)
| Agent | When to Use |
|-------|-------------|
| `protocol-architect` | Protocol design, type hierarchies, generic constraints |
| `api-designer` | Public API naming, fluent interfaces, progressive disclosure |
| `framework-architect` | Orchestration patterns, new step types, Hive DAG design |
| `concurrency-expert` | Actor isolation, Sendable conformance, data-race review |

#### Tier 3: Implementation
| Agent | Scope | When to Use |
|-------|-------|-------------|
| `swarm-implementer` | `Sources/Swarm/` | Swarm framework code |
| `hive-implementer` | `Sources/Swarm/HiveSwarm/` | HiveSwarm bridge code |
| `swift-expert` (opus) | Any | Complex: new subsystems, multi-file refactors |
| `implementer` (sonnet) | Any | Medium: add methods, implement protocols |
| `fixer` (haiku) | Any | Low: rename, fix imports, <20 line edits |

#### Tier 4: Quality
| Agent | When to Use |
|-------|-------------|
| `test-specialist` | TDD Red phase: write failing tests, create mocks. Never production code. |
| `macro-engineer` | Swift macros (@AgentActor, @Tool, custom) |
| `swift-code-reviewer` | After code changes, before commits |
| `swift-debug-agent` | Build failures, compilation errors |

### Routing (First-Match-Wins)

```
TASK → 3+ files? → context-builder
     → Protocol design? → protocol-architect
     → Public API design? → api-designer
     → Orchestration patterns? → framework-architect
     → Concurrency? → concurrency-expert → implementer
     → Macros? → macro-engineer
     → Tests? → test-specialist
     → Swarm source code? → swarm-implementer (or hive-implementer for HiveSwarm/)
     → High complexity? → swift-expert
     → Medium? → implementer
     → Low (<20 lines)? → fixer
     → Build failure? → swift-debug-agent
     → Code review? → swift-code-reviewer
```

### Common Chains

- **New Feature**: `context-builder → test-specialist → protocol-architect → api-designer → swarm-implementer → concurrency-expert → swift-code-reviewer`
- **Bug Fix**: `context-builder → swift-debug-agent → swarm-implementer → test-specialist → swift-code-reviewer`
- **Hive Bridge**: `context-builder → framework-architect → test-specialist → hive-implementer → concurrency-expert → swift-code-reviewer`

### Agent Handoff Protocol

Every delegation includes: task brief, context path, previous agent summary, file scope.
Every agent returns: summary (<200 words), files changed, decisions with rationale, handoff notes, risks.

### Quality Gates

| Gate | Check |
|------|-------|
| Design → Implementation | Protocol compiles, API is ergonomic |
| Implementation → Review | `swift build` succeeds |
| Review → Commit | No critical issues from reviewer |
| Commit → Done | `swift test` passes |

### Skills

| Skill | When to Load |
|-------|-------------|
| `/swarm-patterns` | Any agent working on Swarm code |
| `/tdd-workflow` | Start of implementation tasks |
| `/swift-concurrency-guide` | Concurrency review or async code |
