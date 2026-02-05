# Swarm Feature Parity Plan
## Comprehensive Gap Analysis: Swarm vs OpenAI Agent SDK

**Document Version**: 1.0
**Analysis Date**: January 2026
**Status**: Strategic Planning

---

## Executive Summary

This document provides a comprehensive analysis of Swarm compared to OpenAI's Agent SDK (Python), identifying gaps, advantages, and a prioritized implementation roadmap. After analyzing 100+ types across both frameworks, we identified:

- **49 total gaps** between the frameworks
- **8 areas where Swarm is BETTER** than OpenAI SDK
- **8 must-implement features** for production parity
- **3 major Apple-native implementations**: Platform Tools, Trace Integrations, Voice Agents
- **Estimated implementation**: 31 weeks total (11 weeks core + 20 weeks advanced features)

---

## Table of Contents

1. [Framework Comparison Overview](#1-framework-comparison-overview)
2. [Where Swarm Excels](#2-where-swarm-excels)
3. [Where OpenAI SDK Excels](#3-where-openai-sdk-excels)
4. [Feature Categorization](#4-feature-categorization)
5. [Implementation Roadmap](#5-implementation-roadmap)
6. [Technical Specifications](#6-technical-specifications)
7. [Platform Tools (Apple-Native)](#7-platform-tools-apple-native)
8. [Trace Integrations](#8-trace-integrations)
9. [Voice & Realtime Agents](#9-voice--realtime-agents)
10. [Risk Assessment](#10-risk-assessment)
11. [Success Metrics](#11-success-metrics)

---

## 1. Framework Comparison Overview

### Architectural Philosophy

| Aspect | Swarm | OpenAI Agent SDK |
|--------|-------------|------------------|
| **Language** | Swift 6.2 | Python 3.9+ |
| **Paradigm** | Protocol-oriented, value types | Class-based, decorators |
| **Concurrency** | Actor isolation, structured concurrency | asyncio |
| **Type Safety** | Compile-time, generics | Runtime, Pydantic |
| **Metaprogramming** | Swift Macros | Python decorators |
| **Target Platform** | Apple ecosystem (iOS 17+, macOS 14+) | Server-side, cross-platform |
| **Persistence** | SwiftData, SQLite | SQLite, Redis, SQLAlchemy |
| **On-device AI** | Foundation Models (iOS 26+) | None |

### Feature Coverage Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                    FEATURE COVERAGE MATRIX                       │
├─────────────────────────────────────────────────────────────────┤
│ Category              │ Swarm │ OpenAI SDK │ Gap Status   │
├───────────────────────┼─────────────┼────────────┼──────────────┤
│ Core Agent System     │ ████████░░  │ ████████░░ │ Minor gaps   │
│ Tool System           │ ██████░░░░  │ █████████░ │ DX gap       │
│ Memory/Sessions       │ █████████░  │ ███████░░░ │ Swarm+ │
│ Orchestration         │ ████████░░  │ ████████░░ │ Minor gaps   │
│ Guardrails            │ ███████░░░  │ ████████░░ │ Mode gap     │
│ Observability         │ ██████░░░░  │ █████████░ │ Auto-trace   │
│ Resilience            │ █████████░  │ ██░░░░░░░░ │ Swarm+ │
│ MCP Integration       │ ██████░░░░  │ ████████░░ │ Transport    │
│ Voice/Realtime        │ ████████░░  │ ███████░░░ │ Apple-native │
│ Platform Tools        │ █████████░  │ █████████░ │ Apple-native │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Where Swarm Excels

### 2.1 Actor-Based Concurrency (MAJOR ADVANTAGE)

**Swarm**: Uses Swift actors for thread-safe state management
```swift
actor ToolRegistry {
    private var tools: [String: any Tool] = [:]
    func execute(toolNamed name: String, ...) async throws -> SendableValue
}
```

**OpenAI SDK**: Relies on Python's GIL and runtime checks
```python
# No compile-time race detection
class ToolRegistry:
    def __init__(self):
        self._tools = {}  # Potential race conditions
```

**Advantage**: Swarm prevents data races at compile time. OpenAI SDK relies on runtime discipline.

---

### 2.2 Memory System Diversity (MAJOR ADVANTAGE)

**Swarm**: 5 specialized memory implementations

| Memory Type | Purpose | OpenAI Equivalent |
|-------------|---------|-------------------|
| `ConversationMemory` | FIFO message buffer | Session (partial) |
| `VectorMemory` | Semantic search with embeddings | None |
| `SummaryMemory` | Auto-compression of history | None |
| `HybridMemory` | Combined short/long-term | None |
| `PersistentMemory` | SwiftData persistence | SQLite Session |

**OpenAI SDK**: 4 session types (SQLite, Redis, Encrypted, SQLAlchemy)

**Advantage**: Swarm has semantic memory capabilities. OpenAI only has conversation storage.

---

### 2.3 Resilience Patterns (MAJOR ADVANTAGE)

**Swarm Built-in Patterns**:
```swift
// Circuit Breaker - prevents cascade failures
let breaker = CircuitBreaker(failureThreshold: 5, recoveryTimeout: .seconds(30))

// Retry Policy - automatic retry with backoff
let policy = RetryPolicy(maxAttempts: 3, backoff: .exponential(base: 2))

// Rate Limiter - token bucket algorithm
let limiter = RateLimiter(tokensPerSecond: 10, burst: 20)

// Fallback Chain - graceful degradation
let chain = FallbackChain(primary: gpt4Agent, fallbacks: [gpt35Agent, localAgent])
```

**OpenAI SDK**: No built-in resilience patterns. Users must implement their own.

**Advantage**: Production-ready fault tolerance out of the box.

---

### 2.4 Event Granularity (ADVANTAGE)

**Swarm**: 20+ typed `AgentEvent` cases
```swift
enum AgentEvent: Sendable {
    case started(input: String)
    case thinking(thought: String)
    case thinkingPartial(partialThought: String)
    case toolCallStarted(call: ToolCall)
    case toolCallCompleted(call: ToolCall, result: ToolResult)
    case outputToken(token: String)
    case iterationStarted(number: Int)
    case decision(decision: String, options: [String])
    case handoffRequested(from: String, to: String, reason: String?)
    case guardrailPassed(name: String, type: GuardrailType)
    case memoryAccessed(operation: MemoryOperation, count: Int)
    case llmCompleted(model: String, promptTokens: Int, completionTokens: Int, duration: Duration)
    // ... 8 more cases
}
```

**OpenAI SDK**: Fewer event types with less structure
```python
class StreamEvent:
    type: str  # String-based, not type-safe
    data: Any
```

**Advantage**: Better observability and debugging with type-safe events.

---

### 2.5 RunHooks Lifecycle (ADVANTAGE)

**Swarm**: 9 typed lifecycle callbacks
```swift
protocol RunHooks: Sendable {
    func onAgentStart(context: AgentContext, agent: any Agent, input: String) async
    func onAgentEnd(context: AgentContext, agent: any Agent, result: AgentResult) async
    func onError(context: AgentContext, agent: any Agent, error: Error) async
    func onHandoff(context: AgentContext, fromAgent: any Agent, toAgent: any Agent) async
    func onToolStart(context: AgentContext, agent: any Agent, tool: any Tool, arguments: [String: SendableValue]) async
    func onToolEnd(context: AgentContext, agent: any Agent, tool: any Tool, result: ToolResult) async
    func onLLMStart(context: AgentContext, agent: any Agent, systemPrompt: String, inputMessages: [MemoryMessage]) async
    func onLLMEnd(context: AgentContext, agent: any Agent, response: InferenceResponse, usage: TokenUsage?) async
    func onGuardrailTriggered(context: AgentContext, guardrailName: String, guardrailType: GuardrailType, result: GuardrailResult) async
}
```

**OpenAI SDK**: `AgentHooks` with fewer callbacks

**Advantage**: More visibility into agent execution for monitoring and debugging.

---

### 2.6 Agent Implementations (ADVANTAGE)

**Swarm**: 3 specialized agent types
- `ReActAgent` - Reasoning + Acting with thought chains
- `PlanAndExecuteAgent` - Multi-phase planning with replanning
- `ToolCallingAgent` - Direct tool coordination

**OpenAI SDK**: Single `Agent` class with configuration

**Advantage**: Purpose-built agents for different reasoning patterns.

---

### 2.7 SwiftData Integration (PLATFORM ADVANTAGE)

```swift
// Native iOS persistence
let memory = SwiftDataMemory(modelContext: context)
agent.memory = memory
// Automatic iCloud sync, encryption, efficient queries
```

**OpenAI SDK**: Requires external database setup

**Advantage**: First-class iOS persistence with zero configuration.

---

### 2.8 Foundation Models Support (UNIQUE ADVANTAGE)

```swift
// On-device AI (iOS 26+)
let provider = FoundationModelsProvider()
let agent = ReActAgent(inferenceProvider: provider, ...)
// Runs entirely on-device, no API calls, private
```

**OpenAI SDK**: No equivalent. All inference requires API calls.

**Advantage**: Privacy-preserving on-device AI unique to Apple platforms.

---

## 3. Where OpenAI SDK Excels

### 3.1 Tool Definition DX (CRITICAL GAP)

**OpenAI SDK**: Zero-boilerplate tool creation
```python
@function_tool
def get_weather(city: str, unit: str = "celsius") -> str:
    """Gets the current weather for a city.

    Args:
        city: The city name to get weather for
        unit: Temperature unit (celsius or fahrenheit)
    """
    return f"Weather in {city}: 72°{unit[0].upper()}"
```

**Swarm Current**: Verbose manual definition
```swift
struct GetWeatherTool: Tool {
    var name = "get_weather"
    var description = "Gets the current weather for a city"
    var parameters: [ToolParameter] = [
        ToolParameter(name: "city", description: "The city name", type: .string, isRequired: true),
        ToolParameter(name: "unit", description: "Temperature unit", type: .oneOf(["celsius", "fahrenheit"]), isRequired: false, defaultValue: .string("celsius"))
    ]

    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        let city = try requiredString("city", from: arguments)
        let unit = optionalString("unit", from: arguments, default: "celsius")
        return .string("Weather in \(city): 72°\(unit.first?.uppercased() ?? "C")")
    }
}
```

**Gap Impact**: 🔴 CRITICAL - Tool creation is 10x more verbose

**OpenAI Reference**: `src/agents/tool.py` - `@function_tool` decorator uses `inspect` module

---

### 3.2 Structured Output (CRITICAL GAP)

**OpenAI SDK**: Type-safe responses with schema validation
```python
class WeatherReport(BaseModel):
    city: str
    temperature: float
    conditions: str

result = await Runner.run(agent, input="Weather in NYC", output_type=WeatherReport)
# result is typed as WeatherReport, validated against schema
```

**Swarm Current**: String output only
```swift
let result = try await agent.run("Weather in NYC")
// result.output is String, must parse manually
```

**Gap Impact**: 🔴 CRITICAL - No compile-time response validation

**OpenAI Reference**: `Agent(output_type=...)` parameter, uses Pydantic/dataclasses

---

### 3.3 Dependency Injection (MAJOR GAP)

**OpenAI SDK**: Type-safe context flowing through pipeline
```python
@dataclass
class AppContext:
    user_id: str
    logger: Logger
    database: Database

@function_tool
def lookup_user(ctx: RunContextWrapper[AppContext]) -> str:
    return ctx.context.database.get_user(ctx.context.user_id)

result = await Runner.run(agent, input="...", context=AppContext(...))
```

**Swarm Current**: Ad-hoc metadata dictionary
```swift
let context = AgentContext(metadata: ["userId": .string("123")])
// Not type-safe, no compile-time checks
```

**Gap Impact**: 🔴 HIGH - Testing and composition suffer

**OpenAI Reference**: `RunContextWrapper[T]` generic class

---

### 3.4 Automatic Tracing (MAJOR GAP)

**OpenAI SDK**: Zero-config observability
```python
# Every operation automatically traced:
# - Runner.run() creates trace
# - Each agent execution creates span
# - Each tool call creates span
# - Each LLM generation creates span
# - Each guardrail check creates span
# No code changes needed!
```

**Swarm Current**: Manual tracer integration
```swift
// Must explicitly configure and call tracer
agent.tracer = OSLogTracer()
tracer.startSpan(...)  // Manual calls required
```

**Gap Impact**: 🔴 HIGH - Observability requires significant setup

**OpenAI Reference**: `src/agents/tracing/` module, automatic instrumentation

---

### 3.5 Auto-Session Management (MAJOR GAP)

**OpenAI SDK**: Sessions automatically manage history
```python
session = SQLiteSession("user_123", "conversations.db")
# First turn
await Runner.run(agent, input="Hi", session=session)
# Second turn - history automatically included
await Runner.run(agent, input="What did I say?", session=session)
# No manual .to_input_list() or addItem() calls
```

**Swarm Current**: Manual history management
```swift
let session = InMemorySession(sessionId: "user_123")
let result1 = try await agent.run("Hi", session: session)
try await session.addItem(MemoryMessage.user("Hi"))  // Manual!
try await session.addItem(MemoryMessage.assistant(result1.output))  // Manual!
let result2 = try await agent.run("What did I say?", session: session)
```

**Gap Impact**: 🟡 HIGH - Error-prone, verbose

**OpenAI Reference**: `SessionABC` protocol with auto-management

---

### 3.6 Agent-as-Tool Pattern (MAJOR GAP)

**OpenAI SDK**: Agents can be used as tools
```python
research_agent = Agent(name="researcher", ...)
writer_agent = Agent(name="writer", ...)

manager_agent = Agent(
    name="manager",
    tools=[
        research_agent.as_tool(
            tool_name="do_research",
            tool_description="Researches a topic thoroughly"
        )
    ]
)
```

**Swarm Current**: No equivalent
```swift
// Cannot easily use agents as tools
// Must manually wrap in custom tool
```

**Gap Impact**: 🟡 HIGH - Manager pattern orchestration limited

**OpenAI Reference**: `Agent.as_tool()` method

---

### 3.7 Guardrail Execution Modes (MEDIUM GAP)

**OpenAI SDK**: Choice of parallel or blocking execution
```python
@input_guardrail(run_in_parallel=False)  # Blocking - guardrail completes before agent
async def check_content(ctx, agent, input):
    ...

@input_guardrail(run_in_parallel=True)  # Parallel - faster but uses tokens
async def check_content_fast(ctx, agent, input):
    ...
```

**Swarm Current**: Always sequential
```swift
// Guardrails always run before agent
// No parallel option for latency optimization
```

**Gap Impact**: 🟡 MEDIUM - Latency/cost tradeoff not available

**OpenAI Reference**: `@input_guardrail(run_in_parallel=...)` parameter

---

### 3.8 Dynamic Instructions (MEDIUM GAP)

**OpenAI SDK**: Instructions can be functions
```python
async def dynamic_instructions(ctx: RunContextWrapper, agent: Agent) -> str:
    user = await ctx.context.database.get_user(ctx.context.user_id)
    return f"You are helping {user.name}, a {user.tier} tier customer..."

agent = Agent(
    name="support",
    instructions=dynamic_instructions  # Async function!
)
```

**Swarm Current**: Static strings only
```swift
let agent = ReActAgent(
    instructions: "You are a helpful assistant"  // Static only
)
```

**Gap Impact**: 🟡 MEDIUM - Multi-tenant apps need runtime prompts

**OpenAI Reference**: `Agent(instructions=...)` accepts callable

---

## 4. Feature Categorization

### 4.1 MUST IMPLEMENT (v1.0 - Production Blocking)

These gaps block production use or significantly hurt developer experience.

| Priority | Feature | Gap Severity | Effort | OpenAI Reference |
|----------|---------|--------------|--------|------------------|
| **P0** | @Tool Macro | 🔴 Critical | High | `@function_tool` decorator |
| **P1** | Structured Output | 🔴 Critical | Medium | `Agent(output_type=...)` |
| **P2** | RunContext<T> | 🔴 High | Medium | `RunContextWrapper[T]` |
| **P3** | Auto-Session Management | 🔴 High | Medium | `SessionABC` auto-history |
| **P4** | Agent.asTool() | 🟡 High | Low | `Agent.as_tool()` |
| **P5** | Guardrail Modes | 🟡 Medium | Low | `run_in_parallel` parameter |
| **P6** | Automatic Tracing | 🔴 High | High | `src/agents/tracing/` |
| **P7** | Dynamic Instructions | 🟡 Medium | Low | Callable instructions |

**Total Estimated Effort**: 8 weeks

---

### 4.2 SHOULD IMPLEMENT (v1.1 - Important Enhancements)

These improve the framework significantly but aren't production blockers.

| Priority | Feature | Gap Severity | Effort | OpenAI Reference |
|----------|---------|--------------|--------|------------------|
| **S1** | SQLite Session | 🟡 Medium | Medium | `SQLiteSession` |
| **S2** | Handoff Input Types | 🟡 Medium | Low | `handoff(input_type=...)` |
| **S3** | Handoff Input Filter | 🟡 Medium | Low | `HandoffInputData`, filters |
| **S4** | Tool Choice Control | 🟡 Low | Low | `tool_choice` parameter |
| **S5** | Guardrail-as-Agent | 🟡 Medium | Medium | Guardrails using agents |
| **S6** | Trace Processors | 🟡 Medium | Medium | `add_trace_processor()` |
| **S7** | Sensitive Data Flags | 🟡 Medium | Low | `trace_include_sensitive_data` |
| **S8** | On-Handoff Callback | 🟡 Low | Low | `on_handoff` callback |

**Total Estimated Effort**: 5 weeks

---

### 4.3 NICE TO HAVE (v2.0 - Future Enhancements)

These are valuable but can wait for future versions.

| Feature | Rationale for Deferral | OpenAI Reference |
|---------|------------------------|------------------|
| Redis Session | Few iOS apps need distributed sessions | `RedisSession` |
| Encrypted Session | SwiftData already has encryption | `EncryptedSession` wrapper |
| Tool Output Types | Foundation Models handle multimodal | `ToolOutputImage`, etc. |
| Tool Failure Handler | Swift `throw` is sufficient | `failure_error_function` |
| Agent Clone | Trivial convenience method | `agent.clone()` |
| Session Branching | Niche use case | Advanced SQLite features |
| Session Token Analytics | Metrics system covers this | Token tracking |
| MCP Stdio Transport | HTTP covers most cases | `MCPServerStdio` |
| MCP SSE Transport | Low priority | `MCPServerSse` |
| MCP Tool Filtering | Can use guardrails | `create_static_tool_filter()` |
| MCP Prompt Support | Edge case | `list_prompts()`, `get_prompt()` |
| MCP Caching | Optimization | `cache_tools_list` |
| Tool Conditional Enabling | Can implement with guards | `is_enabled` parameter |
| Custom Output Extractor | Edge case | `custom_output_extractor` |
| Tool Use Behavior | Edge case | `tool_use_behavior` enum |

---

### 4.4 APPLE-NATIVE IMPLEMENTATIONS (Previously "Skip")

These features are being implemented with Apple-native equivalents rather than direct ports.

| Feature | Apple-Native Implementation | Reference Section |
|---------|----------------------------|-------------------|
| **Platform Tools** | WebSearchTool, SpotlightSearchTool, CodeExecutionTool, ImageGenerationTool, ShellTool, CoreMLTool, ARKitTool | [Section 7](#7-platform-tools-apple-native) |
| **10+ Tracing Integrations** | OSSignposter, OSLog, SwiftLog, OpenTelemetry, Datadog, Sentry, Firebase, Langfuse, W&B | [Section 8](#8-trace-integrations) |
| **Voice Agents** | Speech framework (STT), AVSpeechSynthesizer (TTS), VoiceAgent protocol | [Section 9](#9-voice--realtime-agents) |
| **Realtime Agents** | AVAudioEngine, full-duplex RealtimeVoiceAgent | [Section 9](#9-voice--realtime-agents) |

### 4.5 SKIP (Python-Specific Only)

These features are truly Python-specific and won't be implemented.

| Feature | Reason to Skip | OpenAI Reference |
|---------|----------------|------------------|
| **SQLAlchemy Sessions** | Python-specific ORM | `SQLAlchemySession` |
| **LiteLLM Integration** | Python package | `litellm/` prefix |
| **Decorator Patterns** | Swift uses macros, not decorators | `@function_tool`, etc. |

---

### 4.6 ALREADY BETTER (Preserve These Advantages)

These Swarm features exceed OpenAI SDK. Do not change.

| Feature | Swarm Implementation | Why It's Better |
|---------|---------------------------|-----------------|
| **Actor Concurrency** | `actor ToolRegistry`, `actor Memory` | Compile-time race prevention |
| **Protocol Tools** | `protocol Tool` with composition | More flexible than inheritance |
| **5 Memory Types** | Conversation, Vector, Summary, Hybrid, Persistent | Semantic search, compression |
| **Resilience** | CircuitBreaker, RetryPolicy, RateLimiter | No equivalent in OpenAI |
| **20+ Event Types** | `enum AgentEvent` with payloads | Type-safe, exhaustive matching |
| **9 RunHooks** | Typed lifecycle callbacks | More visibility |
| **SwiftData** | Native iOS persistence | Zero config |
| **Foundation Models** | On-device AI | Unique to Apple |

---

## 5. Implementation Roadmap

### Phase 1: DX Parity (Weeks 1-4) — CRITICAL PATH

**Goal**: Match OpenAI SDK developer experience for tool creation and basic usage.

#### Week 1-2: @Tool Macro

**Objective**: Reduce tool definition from 20+ lines to 3-5 lines

**Design**:
```swift
// BEFORE (current)
struct GetWeatherTool: Tool {
    var name = "get_weather"
    var description = "Gets weather for a city"
    var parameters: [ToolParameter] = [
        ToolParameter(name: "city", type: .string, isRequired: true, description: "City name"),
        ToolParameter(name: "unit", type: .oneOf(["celsius", "fahrenheit"]), isRequired: false)
    ]
    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        let city = try requiredString("city", from: arguments)
        return .string("Weather in \(city): 72°")
    }
}

// AFTER (with macro)
@Tool("Gets weather for a city")
func getWeather(
    city: String,
    unit: TemperatureUnit = .celsius
) async throws -> Weather {
    Weather(city: city, temperature: 72, unit: unit)
}
```

**Implementation Tasks**:
1. Create `@Tool` macro in SwarmMacros target
2. Use `FunctionDeclSyntax` to extract:
   - Function name → tool name (convert camelCase to snake_case)
   - Docstring → description
   - Parameters → ToolParameter array (infer types)
   - Return type → handle Codable conversion
3. Generate `struct <Name>Tool: Tool` wrapper
4. Handle async/throwing functions
5. Support optional parameters with defaults
6. Add comprehensive tests

**Acceptance Criteria**:
- [ ] Basic @Tool macro works for simple functions
- [ ] Supports String, Int, Double, Bool, enum parameters
- [ ] Supports optional parameters with defaults
- [ ] Generates correct JSON schema
- [ ] Works with async throws functions
- [ ] 90%+ test coverage

---

#### Week 2-3: Structured Output

**Objective**: Type-safe agent responses with Codable schema validation

**Design**:
```swift
// Define response type
struct WeatherReport: Codable {
    let city: String
    let temperature: Double
    let conditions: String
    let forecast: [String]
}

// Use with agent
let report: WeatherReport = try await agent.run(
    "What's the weather in Tokyo?",
    outputType: WeatherReport.self
)
// report is typed, validated against schema
```

**Implementation Tasks**:
1. Add `outputType` parameter to `Agent.run()` and `Agent.runWithResponse()`
2. Generate JSON Schema from Codable types using Mirror or macros
3. Append schema instructions to system prompt
4. Parse and validate response against schema
5. Handle validation failures gracefully
6. Support nested types, arrays, optionals

**Acceptance Criteria**:
- [ ] Can specify output type on agent.run()
- [ ] Generates valid JSON Schema from Codable
- [ ] Validates response matches schema
- [ ] Throws typed error on validation failure
- [ ] Works with streaming (validates at end)

---

#### Week 3-4: RunContext<T>

**Objective**: Type-safe dependency injection flowing through pipeline

**Design**:
```swift
// Define context type
struct AppContext: Sendable {
    let userId: String
    let logger: Logger
    let database: Database
}

// Context flows to tools
@Tool("Looks up user profile")
func lookupUser(context: RunContext<AppContext>) async throws -> UserProfile {
    context.value.database.getUser(context.value.userId)
}

// Context flows to hooks
class LoggingHooks<C: Sendable>: RunHooks {
    func onToolEnd(context: RunContext<C>, ...) async {
        if let appContext = context.value as? AppContext {
            appContext.logger.info("Tool completed")
        }
    }
}

// Pass context to runner
let result = try await Runner.run(
    agent,
    input: "Look up my profile",
    context: AppContext(userId: "123", logger: logger, database: db)
)
```

**Implementation Tasks**:
1. Create generic `RunContext<T: Sendable>` wrapper
2. Add context parameter to `Runner.run()` / `Agent.run()`
3. Thread context through tool execution
4. Thread context through hooks
5. Update protocol signatures
6. Maintain backward compatibility

**Acceptance Criteria**:
- [ ] RunContext<T> is generic and Sendable
- [ ] Context flows to all tools
- [ ] Context flows to all hooks
- [ ] Type-safe access in tools
- [ ] Backward compatible (context optional)

---

### Phase 2: Production Polish (Weeks 5-8)

#### Week 5: Auto-Session Management + Agent.asTool()

**Auto-Session Objective**: Sessions automatically maintain history

**Design**:
```swift
let session = SQLiteSession("user_123")

// Messages automatically added to session
let result1 = try await agent.run("Hello", session: session)
// No manual addItem() needed!

let result2 = try await agent.run("What did I just say?", session: session)
// Session contains full history automatically
```

**Agent.asTool() Objective**: Enable manager pattern

**Design**:
```swift
let researcher = ReActAgent(name: "researcher", ...)
let writer = ReActAgent(name: "writer", ...)

let manager = ReActAgent(
    name: "manager",
    tools: [
        researcher.asTool(name: "research", description: "Research a topic"),
        writer.asTool(name: "write", description: "Write content")
    ]
)
```

---

#### Week 6: Guardrail Execution Modes

**Objective**: Support parallel and blocking guardrail execution

**Design**:
```swift
// Blocking mode (default) - guardrail completes before agent starts
let contentGuard = InputGuardrail(
    name: "content_filter",
    mode: .blocking
) { input, context in
    // Agent hasn't started yet
    // If tripwire triggered, agent never runs
}

// Parallel mode - faster but agent may consume tokens
let fastGuard = InputGuardrail(
    name: "fast_check",
    mode: .parallel
) { input, context in
    // Runs concurrently with agent
    // If tripwire triggered, agent is cancelled
}
```

**Implementation**:
```swift
enum GuardrailExecutionMode: Sendable {
    case blocking  // Wait for guardrail before agent
    case parallel  // Run concurrently (faster, uses tokens if cancelled)
}
```

---

#### Week 6-8: Automatic Tracing

**Objective**: Zero-config observability for all operations

**Design**:
```swift
// Automatic - no configuration needed
let result = try await agent.run("Hello")
// Automatically creates:
// - Trace for entire run
// - Span for agent execution
// - Span for each tool call
// - Span for each LLM generation
// - Span for each guardrail check

// Optional: Configure trace behavior
Runner.configure(tracing: TracingConfiguration(
    enabled: true,
    includeSensitiveData: false,  // Redact inputs/outputs
    exporters: [OSSignposterExporter(), SwiftLogExporter()]
))
```

**Implementation Tasks**:
1. Create automatic span injection in Agent.run()
2. Create span injection in ToolRegistry.execute()
3. Create span injection in InferenceProvider calls
4. Create span injection in guardrail execution
5. Implement OSSignposter exporter (Instruments integration)
6. Implement swift-log exporter
7. Add sensitive data redaction

---

#### Week 8: Dynamic Instructions

**Objective**: Runtime instruction generation

**Design**:
```swift
// Static instructions (current)
let agent = ReActAgent(instructions: "You are helpful")

// Dynamic instructions (new)
let agent = ReActAgent(instructions: { context, agent in
    let user = try await context.database.getUser(context.userId)
    return """
    You are helping \(user.name), a \(user.tier) customer.
    Their preferences: \(user.preferences)
    """
})
```

**Implementation**:
```swift
// Union type for instructions
enum Instructions: Sendable {
    case `static`(String)
    case dynamic(@Sendable (RunContext<Any>, any Agent) async throws -> String)
}
```

---

### Phase 3: Orchestration (Weeks 9-11)

#### Week 9: Handoff Enhancements

**Handoff Input Types**:
```swift
struct BillingQuery: Codable, Sendable {
    let customerId: String
    let amount: Decimal
    let reason: String
}

Handoff(
    to: billingAgent,
    inputType: BillingQuery.self
)
```

**Handoff Input Filters**:
```swift
Handoff(
    to: agent,
    inputFilter: .removeToolCalls  // Remove tool history
)

Handoff(
    to: agent,
    inputFilter: .custom { history in
        // Custom filtering
        history.filter { $0.role != .tool }
    }
)
```

---

#### Week 10-11: Guardrail-as-Agent

**Objective**: Use agents for sophisticated content moderation

**Design**:
```swift
let moderator = ReActAgent(
    name: "content_moderator",
    instructions: """
    Analyze the input for harmful content.
    Respond with JSON: {"safe": true/false, "reason": "..."}
    """
)

let guardrail = AgentInputGuardrail(
    agent: moderator,
    tripwireCondition: { result in
        // Parse result and determine if tripwire
        !result.safe
    }
)

let mainAgent = ReActAgent(
    inputGuardrails: [guardrail],
    ...
)
```

---

### Phase 4: Ecosystem (Week 12+)

- SQLite Session implementation
- Trace processor pipeline
- Tool choice control
- Sensitive data flags
- Additional MCP transports

---

## 6. Technical Specifications

### 6.1 @Tool Macro Specification

**Input**:
```swift
@Tool("Description of the tool")
func toolName(
    param1: String,
    param2: Int = 42,
    param3: CustomEnum
) async throws -> ResultType
```

**Generated Output**:
```swift
struct ToolNameTool: Tool, Sendable {
    var name: String { "tool_name" }
    var description: String { "Description of the tool" }
    var parameters: [ToolParameter] {
        [
            ToolParameter(name: "param1", type: .string, isRequired: true),
            ToolParameter(name: "param2", type: .int, isRequired: false, defaultValue: .int(42)),
            ToolParameter(name: "param3", type: .oneOf(["case1", "case2"]), isRequired: true)
        ]
    }

    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        let param1 = try requiredString("param1", from: arguments)
        let param2 = optionalInt("param2", from: arguments) ?? 42
        let param3 = try CustomEnum(rawValue: requiredString("param3", from: arguments))!

        let result = try await toolName(param1: param1, param2: param2, param3: param3)
        return try SendableValue(encoding: result)
    }
}
```

### 6.2 RunContext<T> Specification

```swift
/// Type-safe context wrapper for dependency injection
public struct RunContext<T: Sendable>: Sendable {
    /// The wrapped context value
    public let value: T

    /// Execution metadata
    public let executionId: String
    public let startTime: Date
    public private(set) var metadata: [String: SendableValue]

    /// Create context with value
    public init(_ value: T) {
        self.value = value
        self.executionId = UUID().uuidString
        self.startTime = Date()
        self.metadata = [:]
    }

    /// Add metadata
    public mutating func set(_ key: String, value: SendableValue) {
        metadata[key] = value
    }
}

/// Type-erased context for protocol requirements
public struct AnyRunContext: Sendable {
    private let _value: any Sendable
    public let executionId: String
    public let startTime: Date
    public let metadata: [String: SendableValue]

    public init<T: Sendable>(_ context: RunContext<T>) {
        self._value = context.value
        self.executionId = context.executionId
        self.startTime = context.startTime
        self.metadata = context.metadata
    }

    public func value<T: Sendable>(as type: T.Type) -> T? {
        _value as? T
    }
}
```

### 6.3 Structured Output Specification

```swift
extension Agent {
    /// Run agent with typed output
    public func run<Output: Codable>(
        _ input: String,
        outputType: Output.Type,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> Output {
        // 1. Generate JSON Schema from Output type
        let schema = JSONSchemaGenerator.generate(for: Output.self)

        // 2. Append schema instruction
        let enhancedInstructions = """
        \(instructions)

        You MUST respond with valid JSON matching this schema:
        \(schema)
        """

        // 3. Run agent with enhanced instructions
        let result = try await runWithEnhancedInstructions(input, enhancedInstructions, session, hooks)

        // 4. Parse and validate response
        guard let data = result.output.data(using: .utf8) else {
            throw AgentError.invalidOutput("Response is not valid UTF-8")
        }

        do {
            return try JSONDecoder().decode(Output.self, from: data)
        } catch {
            throw AgentError.invalidOutput("Response does not match schema: \(error)")
        }
    }
}
```

---

## 7. Platform Tools (Cross-Platform)

### Design Philosophy

Implement **Platform Tools** with a cross-platform strategy:
1. **Protocol-first**: Define tool protocols that work everywhere
2. **Platform-optimized**: Use native frameworks (Spotlight, CoreML) on Apple when available
3. **Linux-compatible**: Provide alternative implementations using server-side APIs or cross-platform libraries
4. **Conditional compilation**: Use `#if canImport()` and `#if os()` for platform-specific code

### Cross-Platform Strategy

```swift
// Protocol works everywhere
public protocol FileSearchProvider: Sendable {
    func search(query: String, scope: SearchScope) async throws -> [FileSearchResult]
}

// Apple implementation
#if canImport(CoreSpotlight)
public struct SpotlightSearchProvider: FileSearchProvider { ... }
#endif

// Linux/cross-platform implementation
public struct FileSystemSearchProvider: FileSearchProvider { ... }

// Factory chooses best available
public enum FileSearchProviderFactory {
    public static var `default`: any FileSearchProvider {
        #if canImport(CoreSpotlight)
        return SpotlightSearchProvider()
        #else
        return FileSystemSearchProvider()
        #endif
    }
}
```

### Tool Matrix: Cross-Platform Compatibility

| Tool | Linux | macOS | iOS | visionOS | Implementation Strategy |
|------|-------|-------|-----|----------|------------------------|
| **WebSearchTool** | ✅ | ✅ | ✅ | ✅ | HTTP APIs (DuckDuckGo, Google, Bing) |
| **FileSearchTool** | ✅ | ✅ | ✅ | ✅ | Linux: `find`/`grep` wrapper, Apple: Spotlight |
| **SemanticSearchTool** | ✅ | ✅ | ✅ | ✅ | VectorMemory (cross-platform) |
| **CodeExecutionTool** | ✅ | ✅ | ⚠️ | ⚠️ | Linux: subprocess, Apple: JavaScriptCore |
| **ImageGenerationTool** | ✅ | ✅ | ✅ | ✅ | API-based (OpenAI, Stability), Apple: +CoreML |
| **ShellTool** | ✅ | ✅ | ❌ | ❌ | Foundation.Process (Linux + macOS) |
| **MLModelTool** | ✅ | ✅ | ✅ | ✅ | Linux: ONNX Runtime, Apple: CoreML |
| **AutomationTool** | ❌ | ✅ | ❌ | ❌ | macOS-only (Accessibility APIs) |
| **ShortcutsTool** | ❌ | ✅ | ✅ | ✅ | Apple-only (Siri Shortcuts) |
| **ARKitTool** | ❌ | ❌ | ✅ | ✅ | Apple-only (ARKit) |

**Legend**: ✅ Full support | ⚠️ Limited | ❌ Not available

### 7.1 WebSearchTool

```swift
/// Searches the web using configurable search providers
public struct WebSearchTool: Tool {
    public enum SearchProvider: Sendable {
        case duckDuckGo      // Privacy-focused, no API key needed
        case google(apiKey: String, searchEngineId: String)
        case bing(apiKey: String)
        case brave(apiKey: String)
        case custom(endpoint: URL, headers: [String: String])
    }

    public var name = "web_search"
    public var description = "Searches the web and returns relevant results"
    public var provider: SearchProvider
    public var maxResults: Int = 10

    public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        let query = try requiredString("query", from: arguments)
        let results = try await performSearch(query: query)
        return .array(results.map { $0.toSendableValue() })
    }
}
```

### 7.2 FileSearchTool (Cross-Platform)

```swift
/// Cross-platform file search protocol
public protocol FileSearchProvider: Sendable {
    func search(query: String, in directories: [URL], fileTypes: [String]?) async throws -> [FileSearchResult]
}

/// Main file search tool - uses best available provider
public struct FileSearchTool: Tool {
    public var name = "file_search"
    public var description = "Searches for files by name or content"
    private let provider: any FileSearchProvider

    public init(provider: (any FileSearchProvider)? = nil) {
        self.provider = provider ?? FileSearchProviderFactory.default
    }

    public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        let query = try requiredString("query", from: arguments)
        let results = try await provider.search(query: query, in: [.documentsDirectory], fileTypes: nil)
        return .array(results.map { $0.toSendableValue() })
    }
}

// MARK: - Apple Implementation (Spotlight)
#if canImport(CoreSpotlight)
import CoreSpotlight

@available(iOS 17.0, macOS 14.0, *)
public struct SpotlightSearchProvider: FileSearchProvider {
    public func search(query: String, in directories: [URL], fileTypes: [String]?) async throws -> [FileSearchResult] {
        // Uses NSMetadataQuery for fast indexed search
        let mdQuery = NSMetadataQuery()
        mdQuery.predicate = NSPredicate(format: "kMDItemTextContent CONTAINS[cd] %@", query)
        // ... implementation
    }
}
#endif

// MARK: - Linux/Cross-Platform Implementation
public struct FileSystemSearchProvider: FileSearchProvider {
    public func search(query: String, in directories: [URL], fileTypes: [String]?) async throws -> [FileSearchResult] {
        // Uses FileManager + String matching (works on Linux)
        var results: [FileSearchResult] = []
        for directory in directories {
            let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.nameKey])
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.lastPathComponent.localizedCaseInsensitiveContains(query) {
                    results.append(FileSearchResult(url: fileURL, matchType: .filename))
                }
            }
        }
        return results
    }
}

// MARK: - Factory
public enum FileSearchProviderFactory {
    public static var `default`: any FileSearchProvider {
        #if canImport(CoreSpotlight)
        if #available(iOS 17.0, macOS 14.0, *) {
            return SpotlightSearchProvider()
        }
        #endif
        return FileSystemSearchProvider()
    }
}

/// Vector-based semantic file search (cross-platform)
public struct SemanticFileSearchTool: Tool {
    public var name = "semantic_file_search"
    public var description = "Searches files by meaning using embeddings"
    public var vectorStore: VectorMemory  // Uses existing cross-platform VectorMemory
    public var embeddingProvider: any EmbeddingProvider
}
```

### 7.3 CodeExecutionTool (Cross-Platform)

```swift
/// Cross-platform code execution
public struct CodeExecutionTool: Tool {
    public enum Runtime: Sendable {
        case javaScript          // Apple: JavaScriptCore, Linux: server-side
        case python              // Linux: subprocess, Apple: server-side or Pyodide
        case subprocess(String)  // Any language via subprocess (Linux/macOS)
        case serverSide(URL)     // Remote execution server (all platforms)
    }

    public var name = "execute_code"
    public var description = "Executes code and returns the result"
    public var runtime: Runtime
    public var timeout: Duration = .seconds(30)

    public init(runtime: Runtime? = nil) {
        self.runtime = runtime ?? Self.defaultRuntime
    }

    private static var defaultRuntime: Runtime {
        #if canImport(JavaScriptCore)
        return .javaScript
        #else
        return .subprocess("node")  // Use Node.js on Linux
        #endif
    }

    public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        let code = try requiredString("code", from: arguments)
        let language = optionalString("language", from: arguments) ?? "javascript"

        switch runtime {
        case .javaScript:
            return try await executeJavaScript(code)
        case .python:
            return try await executePython(code)
        case .subprocess(let interpreter):
            return try await executeSubprocess(code: code, interpreter: interpreter)
        case .serverSide(let url):
            return try await executeRemotely(code: code, language: language, endpoint: url)
        }
    }

    // MARK: - JavaScript Execution
    private func executeJavaScript(_ code: String) async throws -> SendableValue {
        #if canImport(JavaScriptCore)
        // Apple: Use JavaScriptCore (sandboxed, fast)
        import JavaScriptCore
        let context = JSContext()!
        let result = context.evaluateScript(code)
        return result?.toSendableValue() ?? .null
        #else
        // Linux: Use Node.js subprocess
        return try await executeSubprocess(code: code, interpreter: "node", flag: "-e")
        #endif
    }

    // MARK: - Python Execution (Cross-Platform)
    private func executePython(_ code: String) async throws -> SendableValue {
        // Works on both Linux and macOS via subprocess
        return try await executeSubprocess(code: code, interpreter: "python3", flag: "-c")
    }

    // MARK: - Subprocess Execution (Linux + macOS)
    private func executeSubprocess(code: String, interpreter: String, flag: String = "-e") async throws -> SendableValue {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [interpreter, flag, code]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return .dictionary([
            "stdout": .string(output),
            "stderr": .string(error),
            "exit_code": .int(Int(process.terminationStatus)),
            "success": .bool(process.terminationStatus == 0)
        ])
    }
}
```

### 7.4 ImageGenerationTool (Cross-Platform)

```swift
/// Cross-platform image generation
public struct ImageGenerationTool: Tool {
    public enum GenerationBackend: Sendable {
        // Cross-platform (API-based)
        case openAI(apiKey: String)          // DALL-E (all platforms)
        case stabilityAI(apiKey: String)     // Stable Diffusion API (all platforms)
        case replicateAI(apiKey: String)     // Replicate (all platforms)

        // Apple-only (on-device)
        #if canImport(CoreML)
        case coreML(modelURL: URL)           // On-device Stable Diffusion
        #endif
    }

    public var name = "generate_image"
    public var description = "Generates an image from a text prompt"
    public var backend: GenerationBackend

    public init(backend: GenerationBackend? = nil) {
        // Default to API-based for cross-platform compatibility
        self.backend = backend ?? .stabilityAI(apiKey: ProcessInfo.processInfo.environment["STABILITY_API_KEY"] ?? "")
    }

    public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        let prompt = try requiredString("prompt", from: arguments)

        switch backend {
        case .openAI(let apiKey):
            return try await generateWithDALLE(prompt: prompt, apiKey: apiKey)
        case .stabilityAI(let apiKey):
            return try await generateWithStability(prompt: prompt, apiKey: apiKey)
        case .replicateAI(let apiKey):
            return try await generateWithReplicate(prompt: prompt, apiKey: apiKey)
        #if canImport(CoreML)
        case .coreML(let modelURL):
            // Apple-only: Uses ml-stable-diffusion package for on-device generation
            let image = try await generateWithCoreML(prompt: prompt, modelURL: modelURL)
            return .dictionary([
                "success": .bool(true),
                "image_data": .string(image.base64EncodedString()),
                "format": .string("png")
            ])
        #endif
        }
    }

    // API implementations work on all platforms (Linux, macOS, iOS)
    private func generateWithDALLE(prompt: String, apiKey: String) async throws -> SendableValue {
        // HTTP request to OpenAI API - works everywhere
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        // ... implementation
    }
}
```

### 7.5 ShellTool (Linux + macOS)

```swift
/// Executes shell commands (Linux and macOS)
/// Note: Not available on iOS/visionOS due to sandboxing
#if os(Linux) || os(macOS)
public struct ShellTool: Tool {
    public var name = "shell"
    public var description = "Executes shell commands"
    public var allowedCommands: [String]? = nil  // nil = allow all (dangerous!)
    public var timeout: Duration = .seconds(60)
    public var workingDirectory: URL? = nil

    public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        let command = try requiredString("command", from: arguments)

        // Security check
        if let allowed = allowedCommands {
            let baseCommand = command.split(separator: " ").first.map(String.init) ?? command
            guard allowed.contains(baseCommand) else {
                throw AgentError.toolExecutionFailed(toolName: name, error: SecurityError.commandNotAllowed)
            }
        }

        let process = Process()
        #if os(Linux)
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        #else
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        #endif
        process.arguments = ["-c", command]

        if let workingDir = workingDirectory {
            process.currentDirectoryURL = workingDir
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return .dictionary([
            "exit_code": .int(Int(process.terminationStatus)),
            "stdout": .string(output),
            "stderr": .string(error),
            "success": .bool(process.terminationStatus == 0)
        ])
    }
}
#endif
```

### 7.6 MLModelTool (Cross-Platform)

```swift
/// Cross-platform ML model execution protocol
public protocol MLModelProvider: Sendable {
    func predict(inputs: [String: Any]) async throws -> [String: Any]
}

/// Cross-platform ML model tool
public struct MLModelTool: Tool {
    public var name: String
    public var description: String
    private let provider: any MLModelProvider
    public let inputMapping: @Sendable ([String: SendableValue]) throws -> [String: Any]
    public let outputMapping: @Sendable ([String: Any]) throws -> SendableValue

    public init(
        name: String,
        description: String,
        provider: any MLModelProvider,
        inputMapping: @escaping @Sendable ([String: SendableValue]) throws -> [String: Any],
        outputMapping: @escaping @Sendable ([String: Any]) throws -> SendableValue
    ) {
        self.name = name
        self.description = description
        self.provider = provider
        self.inputMapping = inputMapping
        self.outputMapping = outputMapping
    }

    public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        let inputs = try inputMapping(arguments)
        let outputs = try await provider.predict(inputs: inputs)
        return try outputMapping(outputs)
    }
}

// MARK: - Apple Implementation (CoreML)
#if canImport(CoreML)
import CoreML

public struct CoreMLModelProvider: MLModelProvider {
    private let model: MLModel

    public init(modelURL: URL) throws {
        self.model = try MLModel(contentsOf: modelURL)
    }

    public func predict(inputs: [String: Any]) async throws -> [String: Any] {
        let featureProvider = try DictionaryFeatureProvider(dictionary: inputs)
        let prediction = try await model.prediction(from: featureProvider)
        return prediction.featureNames.reduce(into: [:]) { result, name in
            result[name] = prediction.featureValue(for: name)?.anyValue
        }
    }
}
#endif

// MARK: - Linux Implementation (ONNX Runtime)
#if os(Linux)
// Note: Requires swift-onnxruntime package
public struct ONNXModelProvider: MLModelProvider {
    private let modelPath: String

    public init(modelPath: String) {
        self.modelPath = modelPath
    }

    public func predict(inputs: [String: Any]) async throws -> [String: Any] {
        // Use ONNX Runtime via C API or swift-onnxruntime wrapper
        // This enables running the same models on Linux servers
        fatalError("Implement with swift-onnxruntime")
    }
}
#endif

// MARK: - Server-Side Implementation (HTTP API)
public struct RemoteMLModelProvider: MLModelProvider {
    private let endpoint: URL
    private let apiKey: String?

    public init(endpoint: URL, apiKey: String? = nil) {
        self.endpoint = endpoint
        self.apiKey = apiKey
    }

    public func predict(inputs: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = apiKey {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: inputs)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

// MARK: - Factory
public enum MLModelProviderFactory {
    public static func create(from url: URL) throws -> any MLModelProvider {
        #if canImport(CoreML)
        if url.pathExtension == "mlmodelc" || url.pathExtension == "mlpackage" {
            return try CoreMLModelProvider(modelURL: url)
        }
        #endif

        #if os(Linux)
        if url.pathExtension == "onnx" {
            return ONNXModelProvider(modelPath: url.path)
        }
        #endif

        // Default to remote API
        return RemoteMLModelProvider(endpoint: url)
    }
}
```

### 7.7 ShortcutsTool (NEW)

```swift
/// Runs Siri Shortcuts by name
public struct ShortcutsTool: Tool {
    public var name = "run_shortcut"
    public var description = "Runs a Siri Shortcut by name"

    public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        let shortcutName = try requiredString("name", from: arguments)
        // Uses Shortcuts URL scheme: shortcuts://run-shortcut?name=...
        let url = URL(string: "shortcuts://run-shortcut?name=\(shortcutName.urlEncoded)")!
        await UIApplication.shared.open(url)
        return .string("Shortcut '\(shortcutName)' launched")
    }
}
```

### 7.8 ARKitTool (NEW - iOS/visionOS)

```swift
/// Augmented reality operations for spatial computing
@available(iOS 17.0, visionOS 1.0, *)
public struct ARKitTool: Tool {
    public enum Operation: String, Codable, Sendable {
        case detectPlanes
        case detectObjects
        case measureDistance
        case placeAnchor
        case captureScene
    }

    public var name = "ar_operation"
    public var description = "Performs augmented reality operations"
}
```

### Platform Tools Registry

```swift
/// Pre-configured platform tools
public enum PlatformTools {
    /// All available tools for current platform
    public static var available: [any Tool] {
        var tools: [any Tool] = [
            WebSearchTool(provider: .duckDuckGo),
            SpotlightSearchTool(),
        ]

        #if os(macOS)
        tools.append(ShellTool(allowedCommands: ["ls", "cat", "grep", "find"]))
        #endif

        #if canImport(JavaScriptCore)
        tools.append(CodeExecutionTool(runtime: .javaScript))
        #endif

        return tools
    }
}
```

### Implementation Effort

| Tool | Effort | Priority |
|------|--------|----------|
| WebSearchTool | 1 week | P1 |
| SpotlightSearchTool | 1 week | P1 |
| CodeExecutionTool (JS) | 1 week | P2 |
| ImageGenerationTool | 2 weeks | P2 |
| ShellTool | 0.5 week | P2 |
| CoreMLTool | 1 week | P2 |
| ShortcutsTool | 0.5 week | P2 |
| ARKitTool | 1 week | P3 |

**Total**: ~8 weeks

---

## 8. Trace Integrations (Cross-Platform)

### Design Philosophy

Create a pluggable trace exporter system with cross-platform support:
1. **Protocol-first**: `TraceExporter` protocol works on all platforms
2. **Platform-optimized**: OSSignposter on Apple, standard exporters on Linux
3. **HTTP-based exporters**: Work everywhere (Datadog, Sentry, OpenTelemetry)
4. **Conditional compilation**: Apple-specific exporters use `#if canImport()`

### Cross-Platform Compatibility Matrix

| Exporter | Linux | macOS | iOS | Protocol |
|----------|-------|-------|-----|----------|
| **SwiftLogExporter** | ✅ | ✅ | ✅ | swift-log |
| **OpenTelemetryExporter** | ✅ | ✅ | ✅ | OTLP HTTP/gRPC |
| **DatadogExporter** | ✅ | ✅ | ✅ | HTTP API |
| **SentryExporter** | ✅ | ✅ | ✅ | HTTP API |
| **LangfuseExporter** | ✅ | ✅ | ✅ | HTTP API |
| **WandBExporter** | ✅ | ✅ | ✅ | HTTP API |
| **ConsoleExporter** | ✅ | ✅ | ✅ | stdout |
| **OSSignposterExporter** | ❌ | ✅ | ✅ | os.signpost |
| **OSLogExporter** | ❌ | ✅ | ✅ | os.log |
| **FirebaseExporter** | ❌ | ✅ | ✅ | Firebase SDK |

### TraceExporter Protocol

```swift
/// Protocol for trace data exporters
public protocol TraceExporter: Sendable {
    var identifier: String { get }
    func export(_ spans: [TraceSpan]) async throws
    func flush() async throws
    func shutdown() async throws
}

/// Configuration for trace exporters
public struct TraceExporterConfiguration: Sendable {
    public var batchSize: Int = 100
    public var flushInterval: Duration = .seconds(5)
    public var maxQueueSize: Int = 10_000
    public var includeSensitiveData: Bool = false
    public var samplingRate: Double = 1.0  // 1.0 = 100%
}

/// Composite exporter that sends to multiple destinations
public actor CompositeTraceExporter: TraceExporter {
    public let identifier = "composite"
    private var exporters: [any TraceExporter] = []

    public func add(_ exporter: any TraceExporter) {
        exporters.append(exporter)
    }

    public func export(_ spans: [TraceSpan]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for exporter in exporters {
                group.addTask { try await exporter.export(spans) }
            }
            try await group.waitForAll()
        }
    }
}
```

### Tier 1: Core Exporters (Cross-Platform First)

#### 8.1 SwiftLogExporter (Cross-Platform - PRIMARY)

```swift
/// Cross-platform trace exporter via swift-log
/// Works on: Linux, macOS, iOS, visionOS
public struct SwiftLogExporter: TraceExporter {
    public let identifier = "swift_log"
    private let logger: Logging.Logger

    public init(label: String = "swarm.tracing") {
        self.logger = Logging.Logger(label: label)
    }

    public func export(_ spans: [TraceSpan]) async throws {
        for span in spans {
            let level: Logging.Logger.Level = span.status == .error ? .error : .info
            logger.log(level: level, """
                Span: \(span.name) [\(span.id)]
                Duration: \(span.duration)ms
                Status: \(span.status)
                """, metadata: span.metadata.toLoggerMetadata())
        }
    }
}
```

#### 8.2 ConsoleExporter (Cross-Platform)

```swift
/// Simple console output exporter - works everywhere
public struct ConsoleExporter: TraceExporter {
    public let identifier = "console"
    public var verbose: Bool = false

    public func export(_ spans: [TraceSpan]) async throws {
        for span in spans {
            let emoji = span.status == .error ? "❌" : "✅"
            print("\(emoji) [\(span.name)] \(span.duration)ms")
            if verbose {
                for (key, value) in span.metadata {
                    print("   \(key): \(value)")
                }
            }
        }
    }
}
```

#### 8.3 OSSignposterExporter (Apple-Only)

```swift
/// Exports traces to Instruments via OSSignposter (Apple platforms only)
#if canImport(OSLog)
import OSLog

@available(iOS 17.0, macOS 14.0, *)
public struct OSSignposterExporter: TraceExporter {
    public let identifier = "os_signposter"
    private let signposter: OSSignposter

    public init(subsystem: String = "com.swarm", category: String = "Tracing") {
        self.signposter = OSSignposter(subsystem: subsystem, category: category)
    }

    public func export(_ spans: [TraceSpan]) async throws {
        for span in spans {
            let signpostID = signposter.makeSignpostID()
            signposter.emitEvent("Span", id: signpostID, "\(span.name): \(span.duration)ms")
        }
    }
}
#endif

/// Exports traces to unified logging system (Apple platforms only)
#if canImport(os)
import os

public struct OSLogExporter: TraceExporter {
    public let identifier = "os_log"
    private let logger: os.Logger

    public init(subsystem: String = "com.swarm", category: String = "Tracing") {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }

    public func export(_ spans: [TraceSpan]) async throws {
        for span in spans {
            let level: OSLogType = span.status == .error ? .error : .info
            logger.log(level: level, "[Trace] \(span.name, privacy: .public) - \(span.duration)ms")
        }
    }
}
#endif
```

### Tier 2: Popular Observability Platforms

#### 8.4 DatadogExporter

```swift
/// Exports traces to Datadog APM
public struct DatadogExporter: TraceExporter {
    public let identifier = "datadog"
    private let apiKey: String
    private let site: DatadogSite
    private let service: String

    public enum DatadogSite: String, Sendable {
        case us1 = "datadoghq.com"
        case eu1 = "datadoghq.eu"
        case us3 = "us3.datadoghq.com"
    }

    public func export(_ spans: [TraceSpan]) async throws {
        let ddSpans = spans.map { $0.toDatadogFormat(service: service) }
        try await sendToDatadog(ddSpans)
    }
}
```

#### 8.5 SentryExporter

```swift
/// Exports traces and errors to Sentry
public struct SentryExporter: TraceExporter {
    public let identifier = "sentry"
    private let dsn: String
    private let environment: String

    public func export(_ spans: [TraceSpan]) async throws {
        for span in spans {
            if span.status == .error {
                try await sendErrorEvent(span)
            } else {
                try await sendTransaction(span)
            }
        }
    }
}
```

#### 8.6 FirebasePerformanceExporter

```swift
/// Exports traces to Firebase Performance Monitoring
@available(iOS 17.0, *)
public struct FirebasePerformanceExporter: TraceExporter {
    public let identifier = "firebase"

    public func export(_ spans: [TraceSpan]) async throws {
        #if canImport(FirebasePerformance)
        for span in spans {
            let trace = Performance.startTrace(name: span.name)
            for (key, value) in span.metadata {
                trace?.setValue("\(value)", forAttribute: key)
            }
            trace?.stop()
        }
        #endif
    }
}
```

### Tier 3: OpenTelemetry Standard

#### 8.7 OpenTelemetryExporter

```swift
/// Exports traces using OpenTelemetry Protocol (OTLP)
public struct OpenTelemetryExporter: TraceExporter {
    public let identifier = "opentelemetry"
    private let endpoint: URL
    private let headers: [String: String]

    public enum OTLPProtocol: Sendable {
        case grpc
        case httpProtobuf
        case httpJson
    }

    public func export(_ spans: [TraceSpan]) async throws {
        let otlpSpans = spans.map { $0.toOTLPSpan() }
        try await sendOTLP(otlpSpans)
    }
}
```

**OpenTelemetry enables integration with**:
- Jaeger
- Zipkin
- Grafana Tempo
- Honeycomb
- Lightstep
- Dynatrace
- Splunk
- AWS X-Ray
- Google Cloud Trace
- Azure Monitor

### Tier 4: AI-Specific Platforms

#### 8.8 LangfuseExporter

```swift
/// Exports to Langfuse (LLM observability platform)
public struct LangfuseExporter: TraceExporter {
    public let identifier = "langfuse"
    private let publicKey: String
    private let secretKey: String
    private let host: URL

    public func export(_ spans: [TraceSpan]) async throws {
        let events = spans.flatMap { span -> [LangfuseEvent] in
            if span.spanType == .generation {
                return [LangfuseGeneration(from: span)]
            } else {
                return [LangfuseSpan(from: span)]
            }
        }
        try await sendToLangfuse(events)
    }
}
```

#### 8.9 WeightsAndBiasesExporter

```swift
/// Exports to Weights & Biases
public struct WandBExporter: TraceExporter {
    public let identifier = "wandb"
    private let apiKey: String
    private let project: String

    public func export(_ spans: [TraceSpan]) async throws {
        for span in spans where span.spanType == .agentRun {
            try await logRun(span)
        }
    }
}
```

### Complete Exporter List

| Tier | Exporter | Platform | Effort | Priority |
|------|----------|----------|--------|----------|
| **1** | OSSignposterExporter | Apple | 0.5 week | P0 |
| **1** | OSLogExporter | Apple | 0.5 week | P0 |
| **1** | SwiftLogExporter | Cross-platform | 0.5 week | P0 |
| **2** | DatadogExporter | All | 1 week | P1 |
| **2** | SentryExporter | All | 1 week | P1 |
| **2** | FirebasePerformanceExporter | Apple | 1 week | P1 |
| **2** | NewRelicExporter | All | 1 week | P2 |
| **3** | OpenTelemetryExporter | All | 2 weeks | P1 |
| **4** | LangfuseExporter | All | 1 week | P2 |
| **4** | WandBExporter | All | 1 week | P2 |
| **4** | BraintrustExporter | All | 1 week | P3 |

**Total**: ~11 weeks (can be parallelized)

---

## 9. Voice & Realtime Agents (Cross-Platform)

### Design Philosophy

Build voice capabilities with cross-platform support:
1. **Protocol-first**: `SpeechRecognizer` and `SpeechSynthesizer` protocols work everywhere
2. **Platform-optimized**: Apple: Speech.framework + AVSpeechSynthesizer (on-device, private)
3. **Linux-compatible**: Server-side APIs (Whisper, Google Speech, OpenAI TTS, ElevenLabs)
4. **Fallback chain**: Use best available provider

### Cross-Platform Compatibility Matrix

| Component | Linux | macOS | iOS | Implementation |
|-----------|-------|-------|-----|----------------|
| **SpeechRecognizer** | ✅ | ✅ | ✅ | Linux: Whisper/Google API, Apple: Speech.framework |
| **SpeechSynthesizer** | ✅ | ✅ | ✅ | Linux: OpenAI TTS/ElevenLabs, Apple: AVSpeechSynthesizer |
| **VoiceAgentImpl** | ✅ | ✅ | ✅ | Uses platform-specific providers |
| **RealtimeVoiceAgent** | ✅ | ✅ | ✅ | WebSocket streaming for Linux |
| **WakeWordDetector** | ⚠️ | ✅ | ✅ | Linux: requires always-on STT |

**Legend**: ✅ Full support | ⚠️ Limited

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     VoiceAgent Pipeline                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │   Mic    │───▶│   STT    │───▶│  Agent   │───▶│   TTS    │  │
│  │ (Input)  │    │ (Speech) │    │ (LLM)    │    │(AVSpeech)│  │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘  │
│       │               │               │               │          │
│       │               ▼               ▼               ▼          │
│       │         ┌──────────┐   ┌──────────┐   ┌──────────┐     │
│       │         │ Partial  │   │ Streaming│   │  Audio   │     │
│       │         │  Text    │   │ Response │   │  Output  │     │
│       │         └──────────┘   └──────────┘   └──────────┘     │
│       │                                            │            │
│       └────────────── Interrupt Detection ─────────┘            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 9.1 VoiceAgent Protocol

```swift
/// Protocol for voice-enabled agents
public protocol VoiceAgent: Agent {
    var speechRecognizer: SpeechRecognizer { get }
    var speechSynthesizer: SpeechSynthesizer { get }
    var voiceConfiguration: VoiceConfiguration { get }

    func startListening() async throws
    func stopListening() async
    func speak(_ text: String) async throws
    func voiceEvents() -> AsyncStream<VoiceEvent>
}

/// Voice-specific events
public enum VoiceEvent: Sendable {
    // Listening states
    case listeningStarted
    case listeningStopped
    case speechDetected
    case silenceDetected(duration: Duration)

    // Transcription
    case partialTranscription(text: String, confidence: Float)
    case finalTranscription(text: String, confidence: Float)

    // Speaking states
    case speakingStarted(text: String)
    case speakingProgress(characterIndex: Int, text: String)
    case speakingStopped

    // Interrupts
    case userInterrupted
    case agentInterrupted

    // Errors
    case error(VoiceError)
}

/// Voice configuration
public struct VoiceConfiguration: Sendable {
    public var locale: Locale = .current
    public var voice: SpeechVoice? = nil
    public var speechRate: Float = 0.5
    public var pitchMultiplier: Float = 1.0
    public var volume: Float = 1.0
    public var enableInterrupts: Bool = true
    public var silenceThreshold: Duration = .seconds(1.5)
    public var enableWakeWord: Bool = false
    public var wakeWord: String? = nil
}
```

### 9.2 SpeechRecognizer (Cross-Platform STT)

```swift
/// Cross-platform speech recognition protocol
public protocol SpeechRecognitionProvider: Sendable {
    func startStreaming(locale: Locale) -> AsyncThrowingStream<TranscriptionResult, Error>
    func stop() async
}

public struct TranscriptionResult: Sendable {
    public let text: String
    public let isFinal: Bool
    public let confidence: Float
    public let alternatives: [String]
}

/// Main speech recognizer - uses best available provider
public actor SpeechRecognizer {
    private let provider: any SpeechRecognitionProvider

    public init(provider: (any SpeechRecognitionProvider)? = nil, locale: Locale = .current) throws {
        self.provider = provider ?? SpeechRecognitionProviderFactory.default(locale: locale)
    }

    public func startStreaming() -> AsyncThrowingStream<TranscriptionResult, Error> {
        provider.startStreaming(locale: .current)
    }

    public func stop() async {
        await provider.stop()
    }
}

// MARK: - Apple Implementation (On-Device)
#if canImport(Speech)
import Speech
import AVFoundation

@available(iOS 17.0, macOS 14.0, *)
public actor AppleSpeechProvider: SpeechRecognitionProvider {
    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    public func startStreaming(locale: Locale) -> AsyncThrowingStream<TranscriptionResult, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let recognizer = SFSpeechRecognizer(locale: locale) else {
                    continuation.finish(throwing: VoiceError.speechRecognitionUnavailable)
                    return
                }
                self.recognizer = recognizer

                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
                request.requiresOnDeviceRecognition = true  // Privacy!

                // Setup audio engine and yield results
                // ... implementation
            }
        }
    }

    public func stop() async {
        recognitionTask?.cancel()
        audioEngine?.stop()
    }
}
#endif

// MARK: - Linux/Cross-Platform Implementation (Whisper API)
public actor WhisperAPIProvider: SpeechRecognitionProvider {
    private let apiKey: String
    private let endpoint: URL

    public init(apiKey: String, endpoint: URL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!) {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }

    public func startStreaming(locale: Locale) -> AsyncThrowingStream<TranscriptionResult, Error> {
        AsyncThrowingStream { continuation in
            // For streaming, use chunked audio upload
            // Returns transcription for each chunk
            // Works on Linux, macOS, iOS
        }
    }

    public func stop() async { }
}

// MARK: - Google Speech-to-Text (Cross-Platform)
public actor GoogleSpeechProvider: SpeechRecognitionProvider {
    private let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func startStreaming(locale: Locale) -> AsyncThrowingStream<TranscriptionResult, Error> {
        AsyncThrowingStream { continuation in
            // Uses Google Cloud Speech-to-Text API
            // Supports streaming recognition via gRPC or REST
        }
    }

    public func stop() async { }
}

// MARK: - Factory
public enum SpeechRecognitionProviderFactory {
    public static func `default`(locale: Locale) -> any SpeechRecognitionProvider {
        #if canImport(Speech)
        if #available(iOS 17.0, macOS 14.0, *) {
            return AppleSpeechProvider()
        }
        #endif

        // Fallback to Whisper API for Linux or older Apple platforms
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        return WhisperAPIProvider(apiKey: apiKey)
    }
}
```

### 9.3 SpeechSynthesizer (Cross-Platform TTS)

```swift
/// Cross-platform text-to-speech protocol
public protocol SpeechSynthesisProvider: Sendable {
    func speak(_ text: String, voice: VoiceConfiguration) -> AsyncStream<SpeechEvent>
    func stop() async
    func pause() async
    func resume() async
}

public enum SpeechEvent: Sendable {
    case started
    case progress(characterIndex: Int)
    case audioChunk(Data)  // For streaming audio
    case paused
    case resumed
    case finished
    case cancelled
}

/// Main speech synthesizer - uses best available provider
public actor SpeechSynthesizer {
    private let provider: any SpeechSynthesisProvider
    private let configuration: VoiceConfiguration

    public init(provider: (any SpeechSynthesisProvider)? = nil, configuration: VoiceConfiguration = VoiceConfiguration()) {
        self.provider = provider ?? SpeechSynthesisProviderFactory.default
        self.configuration = configuration
    }

    public func speak(_ text: String) -> AsyncStream<SpeechEvent> {
        provider.speak(text, voice: configuration)
    }

    public func stop() async { await provider.stop() }
    public func pause() async { await provider.pause() }
    public func resume() async { await provider.resume() }
}

// MARK: - Apple Implementation (On-Device)
#if canImport(AVFoundation)
import AVFoundation

@available(iOS 17.0, macOS 14.0, *)
public actor AppleSpeechSynthesisProvider: NSObject, SpeechSynthesisProvider, AVSpeechSynthesizerDelegate {
    private let synthesizer: AVSpeechSynthesizer
    private var continuation: AsyncStream<SpeechEvent>.Continuation?

    public override init() {
        self.synthesizer = AVSpeechSynthesizer()
        super.init()
        synthesizer.delegate = self
    }

    public func speak(_ text: String, voice: VoiceConfiguration) -> AsyncStream<SpeechEvent> {
        AsyncStream { continuation in
            self.continuation = continuation
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice.voice?.avVoice
            utterance.rate = voice.speechRate
            utterance.pitchMultiplier = voice.pitchMultiplier
            utterance.volume = voice.volume
            synthesizer.speak(utterance)
        }
    }

    public func stop() async { synthesizer.stopSpeaking(at: .immediate) }
    public func pause() async { synthesizer.pauseSpeaking(at: .word) }
    public func resume() async { synthesizer.continueSpeaking() }

    // AVSpeechSynthesizerDelegate
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { await self.continuation?.yield(.started) }
    }
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { await self.continuation?.yield(.finished); await self.continuation?.finish() }
    }
}
#endif

// MARK: - Linux/Cross-Platform Implementation (OpenAI TTS)
public actor OpenAITTSProvider: SpeechSynthesisProvider {
    private let apiKey: String
    private let model: String
    private let voice: String

    public init(apiKey: String, model: String = "tts-1", voice: String = "alloy") {
        self.apiKey = apiKey
        self.model = model
        self.voice = voice
    }

    public func speak(_ text: String, voice config: VoiceConfiguration) -> AsyncStream<SpeechEvent> {
        AsyncStream { continuation in
            Task {
                continuation.yield(.started)

                var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/speech")!)
                request.httpMethod = "POST"
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONEncoder().encode([
                    "model": model,
                    "input": text,
                    "voice": voice,
                    "response_format": "mp3"
                ])

                // Stream audio chunks
                let (bytes, _) = try await URLSession.shared.bytes(for: request)
                for try await byte in bytes {
                    continuation.yield(.audioChunk(Data([byte])))
                }

                continuation.yield(.finished)
                continuation.finish()
            }
        }
    }

    public func stop() async { }
    public func pause() async { }
    public func resume() async { }
}

// MARK: - ElevenLabs TTS (Cross-Platform, High Quality)
public actor ElevenLabsTTSProvider: SpeechSynthesisProvider {
    private let apiKey: String
    private let voiceId: String

    public init(apiKey: String, voiceId: String = "21m00Tcm4TlvDq8ikWAM") {
        self.apiKey = apiKey
        self.voiceId = voiceId
    }

    public func speak(_ text: String, voice: VoiceConfiguration) -> AsyncStream<SpeechEvent> {
        AsyncStream { continuation in
            Task {
                // ElevenLabs streaming API - works on Linux
                let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)/stream")!
                // ... implementation
            }
        }
    }

    public func stop() async { }
    public func pause() async { }
    public func resume() async { }
}

// MARK: - Factory
public enum SpeechSynthesisProviderFactory {
    public static var `default`: any SpeechSynthesisProvider {
        #if canImport(AVFoundation)
        if #available(iOS 17.0, macOS 14.0, *) {
            return AppleSpeechSynthesisProvider()
        }
        #endif

        // Fallback to OpenAI TTS for Linux
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        return OpenAITTSProvider(apiKey: apiKey)
    }
}
```

### 9.4 VoiceAgentImpl

```swift
/// Complete voice-enabled agent implementation
@available(iOS 17.0, macOS 14.0, *)
public actor VoiceAgentImpl<BaseAgent: Agent>: VoiceAgent {
    private let baseAgent: BaseAgent
    public let speechRecognizer: SpeechRecognizer
    public let speechSynthesizer: SpeechSynthesizer
    public let voiceConfiguration: VoiceConfiguration

    private var isListening = false
    private var isSpeaking = false

    public init(agent: BaseAgent, configuration: VoiceConfiguration = VoiceConfiguration()) throws {
        self.baseAgent = agent
        self.voiceConfiguration = configuration
        self.speechRecognizer = try SpeechRecognizer(locale: configuration.locale)
        self.speechSynthesizer = SpeechSynthesizer(configuration: configuration)
    }

    public func startListening() async throws {
        let status = await speechRecognizer.requestAuthorization()
        guard status == .authorized else { throw VoiceError.notAuthorized }

        isListening = true
        for try await transcription in speechRecognizer.startStreaming() {
            if transcription.isFinal {
                // Stop speaking if user interrupts
                if isSpeaking && voiceConfiguration.enableInterrupts {
                    await speechSynthesizer.stop()
                }
                // Process with agent
                await processVoiceInput(transcription.text)
            }
        }
    }

    private func processVoiceInput(_ text: String) async {
        do {
            let result = try await baseAgent.run(text, session: nil, hooks: nil)
            try await speak(result.output)
        } catch {
            // Handle error
        }
    }
}
```

### 9.5 RealtimeVoiceAgent (Full-Duplex)

```swift
/// Real-time voice agent with full-duplex audio
@available(iOS 17.0, macOS 14.0, *)
public actor RealtimeVoiceAgent<BaseAgent: Agent> {
    private let baseAgent: BaseAgent
    private let audioEngine: AVAudioEngine
    private let speechRecognizer: SpeechRecognizer
    private let speechSynthesizer: SpeechSynthesizer
    private var isActive = false
    private var pendingResponse: Task<Void, Never>?

    /// Start real-time conversation
    public func startConversation() async throws {
        isActive = true

        // Configure audio session for real-time
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
        try session.setActive(true)

        while isActive {
            // Listen for user input
            var fullTranscription = ""
            for try await transcription in speechRecognizer.startStreaming() {
                if transcription.isFinal {
                    fullTranscription = transcription.text
                    break
                }
                // Check for barge-in during agent response
                if pendingResponse != nil {
                    pendingResponse?.cancel()
                    await speechSynthesizer.stop()
                }
            }

            guard !fullTranscription.isEmpty else { continue }

            // Stream agent response and speak simultaneously
            pendingResponse = Task {
                for await event in baseAgent.stream(fullTranscription, session: nil, hooks: nil) {
                    if Task.isCancelled { break }
                    if case .outputChunk(let chunk) = event {
                        try? await speechSynthesizer.speak(chunk)
                    }
                }
            }
        }
    }

    public func stopConversation() async {
        isActive = false
        pendingResponse?.cancel()
        await speechRecognizer.stop()
        await speechSynthesizer.stop()
    }
}
```

### 9.6 SwiftUI Integration

```swift
/// SwiftUI view for voice agent interaction
@available(iOS 17.0, macOS 14.0, *)
public struct VoiceAgentView<Agent: VoiceAgent>: View {
    @State private var agent: Agent
    @State private var isListening = false
    @State private var transcription = ""
    @State private var response = ""

    public var body: some View {
        VStack(spacing: 20) {
            Text(transcription)
                .font(.headline)
            Text(response)
                .font(.body)
            VoiceWaveformView(isActive: isListening)
                .frame(height: 60)
            Button(action: toggleListening) {
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .font(.largeTitle)
                    .foregroundStyle(isListening ? .red : .blue)
            }
        }
        .task {
            for await event in agent.voiceEvents() {
                handleEvent(event)
            }
        }
    }
}
```

### 9.7 WakeWordDetector

```swift
/// Wake word detection for hands-free activation
@available(iOS 17.0, macOS 14.0, *)
public actor WakeWordDetector {
    private let wakeWord: String
    private let speechRecognizer: SpeechRecognizer
    private var isListening = false

    public init(wakeWord: String, locale: Locale = .current) throws {
        self.wakeWord = wakeWord.lowercased()
        self.speechRecognizer = try SpeechRecognizer(locale: locale)
    }

    public func listen() -> AsyncStream<Void> {
        AsyncStream { continuation in
            Task {
                isListening = true
                while isListening {
                    for try await transcription in speechRecognizer.startStreaming() {
                        if transcription.text.lowercased().contains(wakeWord) {
                            continuation.yield(())
                            break
                        }
                    }
                }
            }
        }
    }
}
```

### Voice Utilities

```swift
/// Available speech voices
public struct SpeechVoice: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let language: String
    public let quality: Quality

    public enum Quality: Sendable {
        case `default`, enhanced, premium
    }

    public var avVoice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(identifier: id)
    }

    public static var allVoices: [SpeechVoice] {
        AVSpeechSynthesisVoice.speechVoices().map { voice in
            SpeechVoice(id: voice.identifier, name: voice.name, language: voice.language, quality: .default)
        }
    }
}

/// Voice errors
public enum VoiceError: Error, Sendable {
    case notAuthorized
    case speechRecognitionUnavailable
    case audioSessionFailed(Error)
    case processingFailed(Error)
    case noMicrophoneAccess
    case cancelled
}
```

### Implementation Effort

| Component | Effort | Priority |
|-----------|--------|----------|
| SpeechRecognizer | 1 week | P1 |
| SpeechSynthesizer | 0.5 week | P1 |
| VoiceAgentImpl | 1 week | P1 |
| RealtimeVoiceAgent | 2 weeks | P2 |
| WakeWordDetector | 1 week | P3 |
| SwiftUI Views | 1 week | P2 |
| Voice Utilities | 0.5 week | P1 |

**Total**: ~7 weeks

---

## 10. Risk Assessment

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Macro complexity | Medium | High | Start simple, iterate. Use existing Swift macro examples |
| Breaking API changes | Medium | High | Semantic versioning, deprecation warnings |
| Performance regression | Low | Medium | Benchmark suite, profile critical paths |
| Swift 6 concurrency issues | Medium | Medium | Thorough actor audit, Sendable checks |

### Schedule Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Macro implementation takes longer | Medium | Medium | Scope to basic types first |
| Auto-tracing complexity | Medium | Medium | Implement incrementally |
| Community adoption | Low | High | Great documentation, examples |

### Mitigation Strategies

1. **Incremental delivery**: Ship @Tool macro first, then iterate
2. **Feature flags**: New features behind flags for testing
3. **Backward compatibility**: All new features are additive
4. **Extensive testing**: 90%+ coverage requirement

---

## 11. Success Metrics

### Quantitative Metrics

| Metric | Current | Target | Timeline |
|--------|---------|--------|----------|
| Tool definition LOC | 20+ lines | <5 lines | Phase 1 |
| Time to first agent | 30+ min | <10 min | Phase 1 |
| Test coverage | ~70% | >85% | Phase 2 |
| GitHub stars | 0 | 500+ | 6 months |
| Production apps | 0 | 3+ | 6 months |

### Qualitative Metrics

- Developer satisfaction surveys
- Community feedback on ergonomics
- Enterprise adoption interest
- Conference talk acceptances

---

## Appendix A: OpenAI SDK Reference Locations

| Feature | OpenAI SDK Location |
|---------|---------------------|
| @function_tool | `src/agents/tool.py` |
| output_type | `src/agents/agent.py:Agent.__init__` |
| RunContextWrapper | `src/agents/run_context.py` |
| Sessions | `src/agents/sessions/` |
| Guardrails | `src/agents/guardrail.py` |
| Tracing | `src/agents/tracing/` |
| Handoffs | `src/agents/handoff.py` |
| Agent.as_tool | `src/agents/agent.py:Agent.as_tool` |

---

## Appendix B: Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| Jan 2026 | Implement Platform Tools | Apple-native equivalents using Spotlight, JavaScriptCore, CoreML, ARKit |
| Jan 2026 | Implement 10+ Trace Integrations | OSSignposter, OpenTelemetry as core; Datadog, Sentry, Langfuse for enterprise |
| Jan 2026 | Implement Voice Agents | Apple Speech framework + AVSpeechSynthesizer for native voice |
| Jan 2026 | Preserve actor design | Compile-time safety > Python compatibility |
| Jan 2026 | Use macros not decorators | Swift paradigm |
| Jan 2026 | Prioritize @Tool macro | Biggest DX improvement |
| Jan 2026 | Add ARKitTool | Unique Apple advantage for spatial computing |
| Jan 2026 | Add CoreMLTool | Leverage on-device ML models as tools |
| Jan 2026 | Add ShortcutsTool | Deep Siri integration for automation |

---

## Appendix C: Glossary

| Term | Definition |
|------|------------|
| **DX** | Developer Experience |
| **LOC** | Lines of Code |
| **MCP** | Model Context Protocol |
| **POP** | Protocol-Oriented Programming |
| **Tripwire** | Guardrail failure that halts execution |
| **Handoff** | Transfer of control between agents |

---

**Document Maintainers**: Swarm Core Team
**Review Cycle**: Quarterly
**Next Review**: April 2026
