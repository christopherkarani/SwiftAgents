# Swarm API Redesign — Implementation Plan

**Date**: 2026-03-02 (Updated 2026-03-03)
**Status**: Draft
**Thesis**: Swarm makes it effortless to add AI reasoning to your Apple platform app.

---

## Target API Reference (Source of Truth)

These 12 scenarios define the exact developer-facing API. Every phase must produce code that makes these compile and pass tests.

### Scenario 1: Hello World — On-Device, Zero Config

```swift
import Swarm

@Agent("You are a friendly assistant.")
struct Greeter {
    func process(_ input: String) async throws -> String {
        return "Hello! You said: \(input)"
    }
}

let result = try await Greeter().run("Hi there")
print(result.output)
```

### Scenario 2: Agent with Tools — Cloud Provider

```swift
import Swarm

@Tool("Calculates mathematical expressions")
struct Calculator {
    @Parameter("The expression to evaluate")
    var expression: String

    func execute() async throws -> String { "42" }
}

@Agent("You are a math assistant. Use the calculator tool.")
struct MathAssistant {
    let tools = [Calculator()]
    func process(_ input: String) async throws -> String { input }
}

await Swarm.configure(provider: AnthropicProvider(apiKey: "sk-..."))
let result = try await MathAssistant().run("What is 137 * 42?")
```

### Scenario 3: SwiftUI Chat — Conversation + @Observable

```swift
import SwiftUI
import Swarm

@Agent("You are a cooking assistant.")
struct ChefBot {
    func process(_ input: String) async throws -> String { input }
}

struct ChatView: View {
    @State private var conversation = Conversation(with: ChefBot())
    @State private var input = ""

    var body: some View {
        VStack {
            ScrollView {
                ForEach(conversation.messages) { message in
                    Text(message.text)
                }
            }
            if conversation.isThinking { ProgressView() }
            HStack {
                TextField("Ask...", text: $input)
                Button("Send") {
                    let text = input; input = ""
                    Task { try await conversation.send(text) }
                }
                .disabled(input.isEmpty || conversation.isThinking)
            }
        }
    }
}
```

### Scenario 4: Streaming Chat — Live Token Updates

```swift
import Swarm

let conversation = Conversation(with: ChefBot())

// Stream tokens live — streamingText updates in real-time
try await conversation.stream("Tell me about Swift concurrency")
// conversation.streamingText updates progressively
// On completion, final message appended to conversation.messages
```

### Scenario 5: Sequential Workflow — Multi-Agent Pipeline

```swift
import Swarm

@Agent("You are a researcher. Find key facts.")
struct Researcher {
    let tools = [WebSearchTool()]
    func process(_ input: String) async throws -> String { input }
}

@Agent("You are a writer. Write a clear article.")
struct Writer {
    func process(_ input: String) async throws -> String { input }
}

@Agent("You are an editor. Fix grammar, improve clarity.")
struct Editor {
    func process(_ input: String) async throws -> String { input }
}

let article = try await Workflow()
    .step(Researcher())
    .step(Writer())
    .step(Editor())
    .run("Swift concurrency best practices in 2026")
```

### Scenario 6: Parallel Agents — Fan-Out + Merge

```swift
import Swarm

@Agent("Analyze sentiment.") struct SentimentAnalyzer {
    func process(_ input: String) async throws -> String { input }
}
@Agent("Extract entities.") struct EntityExtractor {
    func process(_ input: String) async throws -> String { input }
}
@Agent("Summarize in 2-3 sentences.") struct Summarizer {
    func process(_ input: String) async throws -> String { input }
}

let analysis = try await Workflow()
    .parallel([SentimentAnalyzer(), EntityExtractor(), Summarizer()])
    .run("Apple announced the M5 chip today...")

// Custom merge:
let custom = try await Workflow()
    .parallel([SentimentAnalyzer(), Summarizer()],
              merge: .custom { results in results.map(\.output).joined(separator: "\n\n") })
    .run("Some text")
```

### Scenario 7: Router — Dynamic Agent Selection

```swift
import Swarm

@Agent("You handle billing.") struct BillingAgent {
    let tools = [LookupInvoiceTool()]
    func process(_ input: String) async throws -> String { input }
}
@Agent("You handle support.") struct SupportAgent {
    let tools = [SearchKBTool()]
    func process(_ input: String) async throws -> String { input }
}
@Agent("You handle general questions.") struct GeneralAgent {
    func process(_ input: String) async throws -> String { input }
}

let result = try await Workflow()
    .route { input in
        if input.contains("bill") { return BillingAgent() }
        if input.contains("bug") { return SupportAgent() }
        return GeneralAgent()
    }
    .run("I need help with my invoice")
```

### Scenario 8: Long-Running Autonomous Agent — Mac Mini

```swift
import Swarm

@Agent("Monitor server health. Escalate critical issues.")
struct ServerMonitor {
    let tools = [CheckCPUTool(), CheckMemoryTool(), AlertSlackTool()]
    func process(_ input: String) async throws -> String { input }
}

let result = try await Workflow()
    .step(ServerMonitor())
    .repeatUntil(maxIterations: 10_000) { $0.output.contains("SHUTDOWN") }
    .checkpointed(id: "server-monitor-v2")
    .timeout(.hours(720))
    .preventSleep(reason: "Server health monitoring")
    .observed(by: SlackAlertObserver())
    .run("Monitor prod-cluster-01")

// Resume after restart:
let resumed = try await Workflow.resume("server-monitor-v2", input: "continue")
```

### Scenario 9: Agent with Memory

```swift
import Swarm

@Agent("You are a journal assistant. Remember what the user tells you.")
struct JournalBot {
    let memory = ConversationMemory(maxMessages: 200)
    func process(_ input: String) async throws -> String { input }
}

let chat = Conversation(with: JournalBot())
try await chat.send("My dog's name is Max")
try await chat.send("What's my dog's name?")
// Remembers: "Max"
```

### Scenario 10: Guardrails (via Agent escape hatch)

```swift
import Swarm

let agent = try Agent(
    tools: [CustomerLookupTool()],
    instructions: "You are a professional customer service agent.",
    inputGuardrails: [NoPIIGuardrail()],
    outputGuardrails: [ProfessionalToneGuardrail()]
)
let result = try await agent.run("Look up account for John")
```

### Scenario 11: Handoffs — Agent Delegation

```swift
import Swarm

@Agent("You handle billing.") struct BillingSpecialist {
    let tools = [InvoiceTool(), RefundTool()]
    func process(_ input: String) async throws -> String { input }
}
@Agent("You handle shipping.") struct ShippingSpecialist {
    let tools = [TrackingTool()]
    func process(_ input: String) async throws -> String { input }
}

@Agent("Route to billing or shipping specialist.")
struct TriageAgent {
    let handoffs: [any AgentRuntime] = [BillingSpecialist(), ShippingSpecialist()]
    func process(_ input: String) async throws -> String { input }
}

let result = try await TriageAgent().run("I need a refund on order #12345")
```

### Scenario 12: Observability — AgentObserver

```swift
import Swarm

struct MetricsObserver: AgentObserver {
    func onAgentStart(context: AgentContext?, agent: any AgentRuntime, input: String) async {
        // track start
    }
    func onToolEnd(context: AgentContext?, agent: any AgentRuntime, result: ToolResult) async {
        // track tool duration
    }
}

// On a single agent:
let observed = MathAssistant().observed(by: MetricsObserver())
let result = try await observed.run("2+2")

// On a workflow:
let result2 = try await Workflow()
    .step(Researcher())
    .step(Writer())
    .observed(by: MetricsObserver())
    .run("Write about Swift")
```

---

## Gap Resolutions

| # | Gap | Resolution |
|---|-----|------------|
| 1 | `@Agent` struct + `cancel()` | Struct generates no-op `cancel()`. Cancellation via structured concurrency (`Task.isCancelled`). |
| 2 | `Conversation` missing streaming | Add `stream(_ text:)` method + `streamingText` observable property. |
| 3 | `Swarm` enum vs module name | Keep `enum Swarm`. Swift resolves type in expression position. Document pattern. |
| 4 | `defaultProvider` vs `cloudProvider` confusion | Single `configure(provider:)` for general use. Separate `configure(cloudProvider:)` only for hybrid FM+cloud. |
| 5 | `Workflow.route()` only gets `String` | Keep `String` for v1 (first step or previous output). Defer `WorkflowContext` to v2. |
| 6 | `@Agent` tools type bridging | Macro generates `[any AnyJSONTool]` from developer's `[Calculator()]`. Add explicit compilation test. |
| 7 | Handoff simplification underspecified | `let handoffs: [any AgentRuntime]` on struct. Macro auto-wraps to `AnyHandoffConfiguration`. |
| 8 | No `@Agent` + custom provider example | Property on struct: `let inferenceProvider: (any InferenceProvider)? = myProvider`. Macro reads it. |

---

## Locked Decisions

| Decision | Choice |
|----------|--------|
| Primary creation path | `@Agent` macro on structs (renamed from `@AgentActor`) |
| Tool definition | `@Tool` + `@Parameter` macros (already exist) |
| Multi-agent composition | `Workflow` type with fluent `.step()` chaining |
| Multi-turn chat | `Conversation` (`@Observable` class) for SwiftUI |
| Provider setup | `Swarm.configure(provider:)` global |
| Default provider | Foundation Models zero-config; cloud opt-in |
| Internal type hiding | `AnyJSONTool` hidden from public API |
| Hooks rename | `RunHooks` → `AgentObserver` |
| Handoffs | `let handoffs: [any AgentRuntime]` on struct, auto-wrapped |
| Long-running support | `.checkpointed(id:)`, `.repeatUntil{}`, `.preventSleep()` |
| Legacy DSL | Behind `declarative-dsl` package trait (deprecated) |
| Agent concrete type | Stays as-is (escape hatch for guardrails, advanced config) |
| Hive for Workflow | Always-on internally (not opt-in) |
| FM + tools error | `toolCallingRequiresCloudProvider` with recovery suggestion |
| Streaming chat | `Conversation.stream()` + `streamingText` property |
| Struct cancellation | No-op `cancel()`, rely on `Task.isCancelled` |

---

## Phase 1: SwarmConfiguration + Error Improvement

**Goal**: `Swarm.configure(provider:)` entry point + `toolCallingRequiresCloudProvider` error.
**Scenarios unlocked**: 2 (cloud provider), 10 (guardrails via Agent escape hatch).

### Files to Create
- `Sources/Swarm/Core/SwarmConfiguration.swift`

### Files to Modify
- `Sources/Swarm/Core/AgentError.swift`
- `Sources/Swarm/Providers/LanguageModelSession.swift`
- `Sources/Swarm/Agents/Agent.swift` (provider resolution fallback)

### Tests (TDD Red Phase)

**File**: `Tests/SwarmTests/Core/SwarmConfigurationTests.swift`

```swift
import Testing
@testable import Swarm

@Suite("SwarmConfiguration")
struct SwarmConfigurationTests {
    @Test("configure sets global provider")
    func configureProvider() async throws {
        let mock = MockInferenceProvider()
        await Swarm.configure(provider: mock)
        let resolved = await Swarm.defaultProvider
        #expect(resolved != nil)
        await Swarm.reset()
    }

    @Test("configure with cloud provider")
    func configureCloudProvider() async throws {
        let mock = MockInferenceProvider()
        await Swarm.configure(cloudProvider: mock)
        let resolved = await Swarm.cloudProvider
        #expect(resolved != nil)
        await Swarm.reset()
    }

    @Test("reset clears all providers")
    func resetConfiguration() async throws {
        let mock = MockInferenceProvider()
        await Swarm.configure(provider: mock)
        await Swarm.reset()
        let resolved = await Swarm.defaultProvider
        #expect(resolved == nil)
    }

    @Test("agent resolves global provider when none set explicitly")
    func agentResolvesGlobalProvider() async throws {
        let mock = MockInferenceProvider(defaultResponse: "from global")
        await Swarm.configure(provider: mock)
        let agent = try Agent(instructions: "test")
        let result = try await agent.run("hello")
        #expect(result.output == "from global")
        await Swarm.reset()
    }
}
```

**File**: `Tests/SwarmTests/Core/AgentErrorTests.swift` (add)

```swift
@Test("toolCallingRequiresCloudProvider has recovery suggestion")
func toolCallingErrorRecovery() {
    let error = AgentError.toolCallingRequiresCloudProvider
    #expect(error.recoverySuggestion != nil)
    #expect(error.recoverySuggestion!.contains("Swarm.configure"))
}

@Test("FM provider throws toolCallingRequiresCloudProvider when tools present")
func fmToolCallingError() async throws {
    // LanguageModelSession is unavailable in tests, so test Agent behavior
    // with no provider and tools — should throw inferenceProviderUnavailable
    // On real device with FM, would throw toolCallingRequiresCloudProvider
    let tool = MockTool(name: "test_tool")
    let agent = try Agent(tools: [tool], instructions: "test")
    await #expect(throws: AgentError.self) {
        try await agent.run("use the tool")
    }
}
```

### Implementation

**`Sources/Swarm/Core/SwarmConfiguration.swift`**:

```swift
import Foundation

/// Global configuration for the Swarm framework.
///
/// Call `Swarm.configure(provider:)` once at app launch:
/// ```swift
/// await Swarm.configure(provider: AnthropicProvider(apiKey: key))
/// ```
public enum Swarm {
    /// Sets the default inference provider for all agents.
    public static func configure(provider: some InferenceProvider) async {
        await Configuration.shared.setProvider(provider)
    }

    /// Sets a cloud provider for tool-calling agents.
    /// Foundation Models handle plain chat; this provider handles tool calls.
    public static func configure(cloudProvider: some InferenceProvider) async {
        await Configuration.shared.setCloudProvider(cloudProvider)
    }

    /// The currently configured default provider.
    public static var defaultProvider: (any InferenceProvider)? {
        get async { await Configuration.shared.provider }
    }

    /// The currently configured cloud provider for tool calling.
    public static var cloudProvider: (any InferenceProvider)? {
        get async { await Configuration.shared.cloud }
    }

    /// Resets all configuration. For testing only.
    public static func reset() async {
        await Configuration.shared.reset()
    }

    actor Configuration {
        static let shared = Configuration()
        private(set) var provider: (any InferenceProvider)?
        private(set) var cloud: (any InferenceProvider)?

        func setProvider(_ p: some InferenceProvider) { provider = p }
        func setCloudProvider(_ p: some InferenceProvider) { cloud = p }
        func reset() { provider = nil; cloud = nil }
    }
}
```

**`AgentError.swift`** — add case + recovery:

```swift
case toolCallingRequiresCloudProvider

// In errorDescription:
case .toolCallingRequiresCloudProvider:
    "Foundation Models do not support tool calling. A cloud provider is required."

// New computed property:
public var recoverySuggestion: String? {
    switch self {
    case .toolCallingRequiresCloudProvider:
        "Call Swarm.configure(cloudProvider:) with an Anthropic, OpenAI, or Ollama provider."
    default: nil
    }
}
```

**`LanguageModelSession.swift`** — change thrown error:

```swift
// Replace:
throw AgentError.generationFailed(reason: "Foundation Models tool calling is not supported...")
// With:
throw AgentError.toolCallingRequiresCloudProvider
```

**`Agent.swift`** — updated provider resolution:

```swift
// 1. Explicit provider on Agent
// 2. TaskLocal via .environment()
// 3. Swarm.defaultProvider (global)
// 4. Swarm.cloudProvider (if agent has tools)
// 5. Foundation Models (if no tools, on Apple platform)
// 6. Throw inferenceProviderUnavailable
```

---

## Phase 2: @Agent Macro (Rename + Struct Support)

**Goal**: `@Agent` on structs as primary creation path. `@AgentActor` deprecated.
**Scenarios unlocked**: 1 (hello world), 2 (tools), 5-9 (all struct-based agents), 11 (handoffs).

### Files to Modify
- `Sources/SwarmMacros/AgentMacro.swift` — support `struct`
- `Sources/SwarmMacros/Plugin.swift` — register `Agent` macro
- `Sources/Swarm/Macros/MacroDeclarations.swift` — add `@Agent`, deprecate `@AgentActor`

### Tests (TDD Red Phase)

**File**: `Tests/SwarmMacrosTests/AgentMacroTests.swift` (add)

```swift
// --- Scenario 1: Hello World struct ---
@Test("@Agent on struct generates AgentRuntime conformance")
func agentOnStructBasic() {
    assertMacroExpansion(
        """
        @Agent("You are a friendly assistant.")
        struct Greeter {
            func process(_ input: String) async throws -> String {
                return "Hello! You said: \\(input)"
            }
        }
        """,
        expandedSource: """
        struct Greeter {
            func process(_ input: String) async throws -> String {
                return "Hello! You said: \\(input)"
            }
            nonisolated let instructions: String = "You are a friendly assistant."
            nonisolated let tools: [any AnyJSONTool] = []
            nonisolated let configuration: AgentConfiguration = .default
            // ... remaining generated members ...
        }
        extension Greeter: AgentRuntime, Sendable {}
        """,
        macros: testMacros
    )
}

// --- Scenario 2: Struct with tools ---
@Test("@Agent struct with tools property bridges to AnyJSONTool")
func agentWithTools() {
    assertMacroExpansion(
        """
        @Agent("Math assistant")
        struct MathAssistant {
            let tools = [Calculator()]
            func process(_ input: String) async throws -> String { input }
        }
        """,
        // Verifies: macro does NOT re-generate tools property when user provides one
        expandedSource: /* tools preserved, AgentRuntime conformance added */,
        macros: testMacros
    )
}

// --- Scenario 11: Struct with handoffs ---
@Test("@Agent struct with handoffs auto-wraps to AnyHandoffConfiguration")
func agentWithHandoffs() {
    // This is a runtime test, not macro expansion
    // Verifies the handoffs property on a @Agent struct works
}

// --- Backward compat ---
@Test("@AgentActor on actor still compiles")
func agentActorBackwardCompat() {
    assertMacroExpansion(
        """
        @AgentActor("You are helpful")
        actor OldStyleAgent {
            func process(_ input: String) async throws -> String { input }
        }
        """,
        expandedSource: /* same as before, AgentRuntime conformance */,
        macros: testMacros
    )
}
```

**File**: `Tests/SwarmTests/Integration/ScenarioTests.swift` (NEW — integration)

```swift
import Testing
@testable import Swarm

@Suite("API Scenarios — Compilation + Runtime")
struct ScenarioTests {

    // --- Scenario 1: Hello World ---
    @Test("Scenario 1: @Agent struct runs with mock provider")
    func scenario1HelloWorld() async throws {
        // @Agent macro not available in test, so test the PATTERN
        // using Agent concrete type as stand-in:
        let mock = MockInferenceProvider(defaultResponse: "Hello! You said: Hi")
        let agent = try Agent(instructions: "You are a friendly assistant.",
                              inferenceProvider: mock)
        let result = try await agent.run("Hi there")
        #expect(result.output.contains("Hello"))
    }

    // --- Scenario 2: Agent with tools ---
    @Test("Scenario 2: Agent with tools requires provider")
    func scenario2ToolAgent() async throws {
        let mock = MockInferenceProvider(defaultResponse: "42")
        await Swarm.configure(provider: mock)
        let tool = MockTool(name: "calculator")
        let agent = try Agent(tools: [tool],
                              instructions: "Math assistant")
        let result = try await agent.run("What is 2+2?")
        #expect(result.output == "42")
        await Swarm.reset()
    }

    // --- Scenario 9: Agent with memory ---
    @Test("Scenario 9: Agent with ConversationMemory retains context")
    func scenario9Memory() async throws {
        let mock = MockInferenceProvider(defaultResponse: "Max")
        let memory = ConversationMemory(maxMessages: 100)
        let agent = try Agent(instructions: "Journal assistant",
                              memory: memory,
                              inferenceProvider: mock)
        _ = try await agent.run("My dog is Max")
        _ = try await agent.run("What's my dog's name?")
        let context = await memory.context(for: "dog name", tokenLimit: 1000)
        #expect(context.contains("Max"))
    }

    // --- Scenario 10: Guardrails ---
    @Test("Scenario 10: Agent with input guardrail blocks PII")
    func scenario10Guardrails() async throws {
        let mock = MockInferenceProvider(defaultResponse: "ok")
        let guardrail = MockInputGuardrail(shouldTripwire: true)
        let agent = try Agent(instructions: "Service agent",
                              inferenceProvider: mock,
                              inputGuardrails: [guardrail])
        await #expect(throws: Error.self) {
            try await agent.run("my SSN is 123-45-6789")
        }
    }
}
```

### Implementation

**`MacroDeclarations.swift`** — add `@Agent`:

```swift
@attached(
    member,
    names: named(tools), named(instructions), named(configuration),
    named(memory), named(inferenceProvider), named(tracer),
    named(_memory), named(_inferenceProvider), named(_tracer),
    named(isCancelled), named(init), named(run), named(stream),
    named(cancel)
)
@attached(extension, conformances: AgentRuntime, Sendable)
public macro Agent(_ instructions: String) = #externalMacro(
    module: "SwarmMacros", type: "AgentMacro"
)

@available(*, deprecated, renamed: "Agent")
@attached(member, names: named(tools), named(instructions), named(configuration),
    named(memory), named(inferenceProvider), named(tracer),
    named(_memory), named(_inferenceProvider), named(_tracer),
    named(isCancelled), named(init), named(run), named(stream),
    named(cancel), named(Builder))
@attached(extension, conformances: AgentRuntime)
public macro AgentActor(_ instructions: String) = #externalMacro(
    module: "SwarmMacros", type: "AgentMacro"
)
```

**`AgentMacro.swift`** — allow struct:

```swift
guard declaration.is(ActorDeclSyntax.self) || declaration.is(StructDeclSyntax.self) else {
    throw AgentMacroError.onlyApplicableToActorOrStruct
}
// For structs: generate Sendable conformance, nonisolated properties
// For structs: cancel() is no-op (rely on Task.isCancelled)
// For structs: if user declared `let handoffs: [any AgentRuntime]`,
//   macro bridges to [AnyHandoffConfiguration] in generated code
```

**`Plugin.swift`** — register both names:

```swift
"Agent": AgentMacro.self,
"AgentActor": AgentMacro.self,
```

---

## Phase 3: Conversation (@Observable for SwiftUI)

**Goal**: Multi-turn chat + streaming with SwiftUI binding via `@Observable`.
**Scenarios unlocked**: 3 (SwiftUI chat), 4 (streaming), 9 (memory via conversation).

### Files to Create
- `Sources/Swarm/Agents/Conversation.swift`
- `Sources/Swarm/Agents/ConversationMessage.swift`

### Tests (TDD Red Phase)

**File**: `Tests/SwarmTests/Agents/ConversationTests.swift`

```swift
import Testing
@testable import Swarm

@Suite("Conversation")
struct ConversationTests {

    // --- Scenario 3: send() adds messages ---
    @Test("send adds user and assistant messages")
    func sendAddsMessages() async throws {
        let mock = MockAgentRuntime(response: "Hello back!")
        let conversation = Conversation(with: mock)
        try await conversation.send("Hello")
        #expect(conversation.messages.count == 2)
        #expect(conversation.messages[0].role == .user)
        #expect(conversation.messages[0].text == "Hello")
        #expect(conversation.messages[1].role == .assistant)
        #expect(conversation.messages[1].text == "Hello back!")
    }

    // --- Scenario 3: isThinking tracks generation ---
    @Test("isThinking is true during generation")
    func isThinkingDuringGeneration() async throws {
        let mock = MockAgentRuntime(response: "Done", delay: .milliseconds(100))
        let conversation = Conversation(with: mock)
        async let _ = conversation.send("Think")
        try await Task.sleep(for: .milliseconds(20))
        #expect(conversation.isThinking == true)
    }

    // --- Scenario 3: clear resets ---
    @Test("clear removes all messages and resets session")
    func clearRemovesMessages() async throws {
        let mock = MockAgentRuntime(response: "Hi")
        let conversation = Conversation(with: mock)
        try await conversation.send("Hello")
        conversation.clear()
        #expect(conversation.messages.isEmpty)
        #expect(conversation.isThinking == false)
        #expect(conversation.lastError == nil)
    }

    // --- Scenario 4: streaming ---
    @Test("stream updates streamingText progressively")
    func streamUpdatesText() async throws {
        let mock = MockAgentRuntime(streamTokens: ["Hello", " ", "world"])
        let conversation = Conversation(with: mock)
        try await conversation.stream("Tell me something")
        // After streaming completes, final message is in messages
        #expect(conversation.messages.last?.text == "Hello world")
        #expect(conversation.streamingText.isEmpty)
    }

    // --- ConversationMessage is Identifiable ---
    @Test("ConversationMessage has unique IDs")
    func messageIsIdentifiable() {
        let a = ConversationMessage(role: .user, text: "Hello")
        let b = ConversationMessage(role: .user, text: "Hello")
        #expect(a.id != b.id)
    }

    // --- Multi-turn retains session ---
    @Test("multiple sends maintain session history")
    func multiTurnSession() async throws {
        let mock = MockAgentRuntime(responses: ["First", "Second", "Third"])
        let conversation = Conversation(with: mock)
        try await conversation.send("A")
        try await conversation.send("B")
        try await conversation.send("C")
        #expect(conversation.messages.count == 6) // 3 user + 3 assistant
    }

    // --- Error handling ---
    @Test("send stores lastError on failure")
    func sendStoresError() async throws {
        let mock = MockAgentRuntime(shouldThrow: AgentError.cancelled)
        let conversation = Conversation(with: mock)
        do {
            try await conversation.send("fail")
        } catch {}
        #expect(conversation.lastError != nil)
        #expect(conversation.isThinking == false)
    }
}
```

### Implementation

**`Sources/Swarm/Agents/ConversationMessage.swift`**:

```swift
import Foundation

/// A message in a conversation. Identifiable for SwiftUI ForEach.
public struct ConversationMessage: Identifiable, Sendable {
    public enum Role: String, Sendable { case user, assistant, system }

    public let id: UUID
    public let role: Role
    public let text: String
    public let timestamp: Date

    public init(role: Role, text: String, id: UUID = UUID(), timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}
```

**`Sources/Swarm/Agents/Conversation.swift`**:

```swift
import Foundation
import Observation

/// Multi-turn conversation with an agent, designed for SwiftUI.
///
/// ```swift
/// struct ChatView: View {
///     @State var conversation = Conversation(with: MyAgent())
///     var body: some View {
///         ForEach(conversation.messages) { msg in Text(msg.text) }
///         if conversation.isThinking { ProgressView() }
///     }
/// }
/// ```
@Observable
public final class Conversation: @unchecked Sendable {
    /// All messages in the conversation.
    public private(set) var messages: [ConversationMessage] = []

    /// Whether the agent is currently generating a response.
    public private(set) var isThinking: Bool = false

    /// Partial text during streaming. Empty when not streaming.
    public private(set) var streamingText: String = ""

    /// The last error that occurred, if any.
    public private(set) var lastError: Error?

    /// Creates a conversation backed by the given agent.
    public init(with agent: some AgentRuntime) {
        self.agent = agent
        self.session = InMemorySession()
    }

    /// Sends a message and waits for the full response.
    @MainActor
    public func send(_ text: String) async throws {
        messages.append(ConversationMessage(role: .user, text: text))
        isThinking = true
        lastError = nil
        defer { isThinking = false }
        do {
            let result = try await agent.run(text, session: session, hooks: nil)
            messages.append(ConversationMessage(role: .assistant, text: result.output))
        } catch {
            lastError = error
            throw error
        }
    }

    /// Streams a response, updating streamingText in real-time.
    @MainActor
    public func stream(_ text: String) async throws {
        messages.append(ConversationMessage(role: .user, text: text))
        isThinking = true
        streamingText = ""
        lastError = nil
        defer {
            isThinking = false
            streamingText = ""
        }
        do {
            var accumulated = ""
            for try await event in agent.stream(text, session: session, hooks: nil) {
                if case .outputToken(let token) = event {
                    accumulated += token
                    streamingText = accumulated
                }
            }
            messages.append(ConversationMessage(role: .assistant, text: accumulated))
        } catch {
            lastError = error
            throw error
        }
    }

    /// Clears all messages and resets the session.
    @MainActor
    public func clear() {
        messages.removeAll()
        session = InMemorySession()
        lastError = nil
        streamingText = ""
    }

    private let agent: any AgentRuntime
    private var session: any Session
}
```

---

## Phase 4: Workflow (Fluent Multi-Agent + Long-Running)

**Goal**: Replace `Orchestration {}` with fluent `Workflow`. Hive always-on internally.
**Scenarios unlocked**: 5 (sequential), 6 (parallel), 7 (router), 8 (long-running).

### Files to Create
- `Sources/Swarm/Orchestration/Workflow.swift`

### Files to Modify
- `Sources/Swarm/HiveSwarm/` (Workflow compiles to Hive DAG)

### Tests (TDD Red Phase)

**File**: `Tests/SwarmTests/Orchestration/WorkflowTests.swift`

```swift
import Testing
@testable import Swarm

@Suite("Workflow")
struct WorkflowTests {

    // --- Scenario 5: Sequential pipeline ---
    @Test("sequential steps chain output to input")
    func scenario5Sequential() async throws {
        let first = MockAgentRuntime(response: "researched")
        let second = MockAgentRuntime(response: "written")
        let third = MockAgentRuntime(response: "edited")
        let result = try await Workflow()
            .step(first)
            .step(second)
            .step(third)
            .run("topic")
        #expect(result.output == "edited")
    }

    // --- Scenario 6: Parallel fan-out ---
    @Test("parallel runs agents concurrently and merges")
    func scenario6Parallel() async throws {
        let a = MockAgentRuntime(response: "sentiment: positive")
        let b = MockAgentRuntime(response: "entities: Apple, M5")
        let result = try await Workflow()
            .parallel([a, b])
            .run("Apple announced M5")
        #expect(result.output.contains("sentiment"))
        #expect(result.output.contains("entities"))
    }

    @Test("parallel with custom merge")
    func scenario6CustomMerge() async throws {
        let a = MockAgentRuntime(response: "A")
        let b = MockAgentRuntime(response: "B")
        let result = try await Workflow()
            .parallel([a, b], merge: .custom { results in
                results.map(\.output).joined(separator: " + ")
            })
            .run("go")
        #expect(result.output == "A + B")
    }

    // --- Scenario 7: Router ---
    @Test("route selects agent based on input content")
    func scenario7Route() async throws {
        let billing = MockAgentRuntime(response: "billing response")
        let support = MockAgentRuntime(response: "support response")
        let general = MockAgentRuntime(response: "general response")
        let result = try await Workflow()
            .route { input in
                if input.contains("bill") { return billing }
                if input.contains("bug") { return support }
                return general
            }
            .run("I have a billing question")
        #expect(result.output == "billing response")
    }

    // --- Scenario 8: Long-running ---
    @Test("repeatUntil loops until condition met")
    func scenario8RepeatUntil() async throws {
        var count = 0
        let agent = MockAgentRuntime(responseFactory: {
            count += 1
            return count >= 3 ? "SHUTDOWN" : "running"
        })
        let result = try await Workflow()
            .step(agent)
            .repeatUntil { $0.output.contains("SHUTDOWN") }
            .run("start")
        #expect(result.output == "SHUTDOWN")
    }

    @Test("timeout throws after duration")
    func scenario8Timeout() async throws {
        let slow = MockAgentRuntime(response: "done", delay: .seconds(5))
        await #expect(throws: AgentError.self) {
            try await Workflow()
                .step(slow)
                .timeout(.milliseconds(50))
                .run("go")
        }
    }

    @Test("checkpointed stores checkpoint ID")
    func scenario8Checkpointed() async throws {
        let agent = MockAgentRuntime(response: "done")
        let workflow = Workflow()
            .step(agent)
            .checkpointed(id: "test-checkpoint")
        // Verify workflow builds without error
        let result = try await workflow.run("start")
        #expect(result.output == "done")
    }

    // --- Single step ---
    @Test("single step workflow runs one agent")
    func singleStep() async throws {
        let agent = MockAgentRuntime(response: "done")
        let result = try await Workflow()
            .step(agent)
            .run("hello")
        #expect(result.output == "done")
    }

    // --- Sequential then parallel ---
    @Test("step then parallel composes correctly")
    func stepThenParallel() async throws {
        let pre = MockAgentRuntime(response: "preprocessed")
        let a = MockAgentRuntime(response: "A")
        let b = MockAgentRuntime(response: "B")
        let result = try await Workflow()
            .step(pre)
            .parallel([a, b])
            .run("input")
        #expect(result.output.contains("A"))
        #expect(result.output.contains("B"))
    }
}
```

### Implementation

**`Sources/Swarm/Orchestration/Workflow.swift`**:

```swift
import Foundation

/// Fluent multi-agent workflow. Compiles to Hive DAG internally.
///
/// Sequential pipeline:
/// ```swift
/// let result = try await Workflow()
///     .step(researcher).step(writer).step(editor)
///     .run("Write about Swift concurrency")
/// ```
///
/// Long-running autonomous:
/// ```swift
/// let result = try await Workflow()
///     .step(monitor)
///     .repeatUntil { $0.output.contains("done") }
///     .checkpointed(id: "monitor-v1")
///     .preventSleep(reason: "Active monitoring")
///     .run("Watch server health")
/// ```
public struct Workflow: Sendable {
    enum Step: Sendable {
        case single(any AgentRuntime)
        case parallel([any AgentRuntime], merge: MergeStrategy)
        case route(@Sendable (String) -> (any AgentRuntime)?)
    }

    public enum MergeStrategy: Sendable {
        case structured
        case first
        case custom(@Sendable ([AgentResult]) -> String)
    }

    public func step(_ agent: some AgentRuntime) -> Workflow {
        var copy = self; copy.steps.append(.single(agent)); return copy
    }

    public func parallel(_ agents: [any AgentRuntime],
                         merge: MergeStrategy = .structured) -> Workflow {
        var copy = self; copy.steps.append(.parallel(agents, merge: merge)); return copy
    }

    public func route(_ condition: @escaping @Sendable (String) -> (any AgentRuntime)?) -> Workflow {
        var copy = self; copy.steps.append(.route(condition)); return copy
    }

    public func repeatUntil(maxIterations: Int = 100,
                            _ condition: @escaping @Sendable (AgentResult) -> Bool) -> Workflow {
        var copy = self
        copy._repeatCondition = condition
        copy._maxRepeatIterations = maxIterations
        return copy
    }

    public func timeout(_ duration: Duration) -> Workflow {
        var copy = self; copy._timeout = duration; return copy
    }

    public func checkpointed(id: String) -> Workflow {
        var copy = self; copy._checkpointId = id; return copy
    }

    public func preventSleep(reason: String) -> Workflow {
        var copy = self; copy._preventSleepReason = reason; return copy
    }

    public func observed(by observer: some AgentObserver) -> Workflow {
        var copy = self; copy._observer = observer; return copy
    }

    public func run(_ input: String) async throws -> AgentResult {
        // Compiles to Hive DAG via OrchestrationHiveEngine
        fatalError("TODO: Phase 4 implementation")
    }

    public static func resume(_ id: String, input: String) async throws -> AgentResult {
        fatalError("TODO: Phase 4 implementation")
    }

    private var steps: [Step] = []
    private var _repeatCondition: (@Sendable (AgentResult) -> Bool)?
    private var _maxRepeatIterations: Int = 100
    private var _timeout: Duration?
    private var _checkpointId: String?
    private var _preventSleepReason: String?
    private var _observer: (any AgentObserver)?
}
```

---

## Phase 5: AgentObserver (Rename RunHooks)

**Goal**: Rename `RunHooks` → `AgentObserver`. Old name kept as deprecated typealias.
**Scenarios unlocked**: 12 (observability), 8 (observed workflow).

### Files to Modify
- `Sources/Swarm/Core/RunHooks.swift` — rename protocol
- `Sources/Swarm/Core/AgentRuntime.swift` — `observer:` parameter
- All agent files — update `hooks:` to `observer:` internally (typealias preserves compilation)

### Tests (TDD Red Phase)

**File**: `Tests/SwarmTests/Core/AgentObserverTests.swift`

```swift
import Testing
@testable import Swarm

@Suite("AgentObserver")
struct AgentObserverTests {

    // --- Scenario 12: Custom observer ---
    @Test("AgentObserver conformance works")
    func observerConformance() async throws {
        struct TestObserver: AgentObserver {
            var startCalled = false
            func onAgentStart(context: AgentContext?, agent: any AgentRuntime, input: String) async {}
        }
        let observer = TestObserver()
        await observer.onAgentStart(context: nil, agent: MockAgentRuntime(response: ""), input: "test")
    }

    // --- Scenario 12: Fluent .observed(by:) ---
    @Test("observed(by:) wraps agent and calls observer")
    func observedByFluent() async throws {
        let mock = MockInferenceProvider(defaultResponse: "ok")
        let agent = try Agent(instructions: "test", inferenceProvider: mock)
        let observer = CallCountObserver()
        let observed = agent.observed(by: observer)
        _ = try await observed.run("hello")
        #expect(await observer.startCount == 1)
    }

    // --- Backward compat ---
    @Test("RunHooks typealias still compiles")
    func runHooksBackcompat() {
        let _: any RunHooks = LoggingRunHooks()
    }

    // --- Deprecated hooks: parameter still works ---
    @Test("run with hooks: parameter still compiles")
    func runWithHooksParam() async throws {
        let mock = MockInferenceProvider(defaultResponse: "ok")
        let agent = try Agent(instructions: "test", inferenceProvider: mock)
        let hooks = LoggingRunHooks()
        _ = try await agent.run("hello", hooks: hooks)
    }
}

/// Test helper
actor CallCountObserver: AgentObserver {
    var startCount = 0
    func onAgentStart(context: AgentContext?, agent: any AgentRuntime, input: String) async {
        startCount += 1
    }
}
```

### Implementation

**`RunHooks.swift`** — rename:

```swift
/// Protocol for observing agent execution lifecycle events.
public protocol AgentObserver: Sendable {
    // ... all existing methods unchanged ...
}

@available(*, deprecated, renamed: "AgentObserver")
public typealias RunHooks = AgentObserver
```

Rename `CompositeRunHooks` → `CompositeObserver` (keep typealias).
Rename `LoggingRunHooks` → `LoggingObserver` (keep typealias).

**`AgentRuntime.swift`** — update protocol:

```swift
func run(_ input: String, session: (any Session)?, observer: (any AgentObserver)?) async throws -> AgentResult
nonisolated func stream(_ input: String, session: (any Session)?, observer: (any AgentObserver)?) -> AsyncThrowingStream<AgentEvent, Error>

// Backward-compat extension:
extension AgentRuntime {
    func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)?) async throws -> AgentResult {
        try await run(input, session: session, observer: hooks)
    }
}
```

**New internal type** `ObservedAgent`:

```swift
struct ObservedAgent<Wrapped: AgentRuntime>: AgentRuntime {
    let wrapped: Wrapped
    let observer: any AgentObserver
    // Delegates all properties to wrapped
    // run() passes observer to wrapped.run(observer:)
}
```

**Extension on AgentRuntime**:

```swift
extension AgentRuntime {
    public func observed(by observer: some AgentObserver) -> some AgentRuntime {
        ObservedAgent(wrapped: self, observer: observer)
    }
}
```

---

## Phase 6: Deprecate Legacy DSL

**Goal**: Move old DSL behind `declarative-dsl` package trait. Deprecate `ChatAgent`.
**Scenarios unlocked**: None new (cleanup phase).

### Files to Modify
- `Sources/Swarm/DSL/AgentBlueprint.swift`
- `Sources/Swarm/DSL/AgentLoop.swift`
- `Sources/Swarm/DSL/AgentLoopBuilder.swift`
- `Sources/Swarm/DSL/AgentLoopStep.swift`
- `Sources/Swarm/DSL/DeclarativeAgent.swift`
- `Sources/Swarm/Agents/Chat.swift`
- `Package.swift`

### Tests (TDD Red Phase)

```swift
@Suite("Legacy DSL Deprecation")
struct LegacyDSLTests {
    @Test("ChatAgent is deprecated but still compiles")
    func chatAgentStillWorks() async throws {
        let mock = MockInferenceProvider(defaultResponse: "hi")
        let agent = ChatAgent("test instructions", inferenceProvider: mock)
        let result = try await agent.run("hello")
        #expect(result.output == "hi")
    }
}
```

### Implementation

Add `@available(*, deprecated)` to each DSL type:

```swift
@available(*, deprecated, message: "Use @Agent macro or Workflow instead")
public protocol AgentBlueprint { ... }
```

In `Package.swift`:

```swift
.target(
    name: "Swarm",
    swiftSettings: [
        .define("SWARM_DECLARATIVE_DSL", .when(traits: ["declarative-dsl"])),
    ]
)
```

Wrap DSL files: `#if SWARM_DECLARATIVE_DSL ... #endif`

Deprecate `ChatAgent`:

```swift
@available(*, deprecated, message: "Use @Agent macro with Conversation instead")
public actor ChatAgent: AgentRuntime { ... }
```

---

## Integration Test Suite (Post All Phases)

Verifies every scenario compiles and produces correct behavior.

**File**: `Tests/SwarmTests/Integration/FullAPIScenarioTests.swift`

```swift
import Testing
@testable import Swarm

@Suite("Full API Scenarios")
struct FullAPIScenarioTests {

    // === Scenario 1: Hello World ===
    @Test("Scenario 1: simple agent with no tools")
    func helloWorld() async throws {
        let mock = MockInferenceProvider(defaultResponse: "Hello! You said: Hi")
        let agent = try Agent(instructions: "You are a friendly assistant.",
                              inferenceProvider: mock)
        let result = try await agent.run("Hi there")
        #expect(result.output.contains("Hello"))
    }

    // === Scenario 2: Agent with tools ===
    @Test("Scenario 2: tool agent via Swarm.configure")
    func toolAgent() async throws {
        let mock = MockInferenceProvider(defaultResponse: "42")
        await Swarm.configure(provider: mock)
        let tool = MockTool(name: "calculator")
        let agent = try Agent(tools: [tool], instructions: "Math assistant")
        let result = try await agent.run("What is 2+2?")
        #expect(result.output == "42")
        await Swarm.reset()
    }

    // === Scenario 3: Conversation send ===
    @Test("Scenario 3: Conversation send/receive")
    func conversationSend() async throws {
        let mock = MockAgentRuntime(response: "Great recipe!")
        let conversation = Conversation(with: mock)
        try await conversation.send("How do I make pasta?")
        #expect(conversation.messages.count == 2)
        #expect(conversation.messages[1].role == .assistant)
    }

    // === Scenario 4: Conversation stream ===
    @Test("Scenario 4: Conversation streaming")
    func conversationStream() async throws {
        let mock = MockAgentRuntime(streamTokens: ["Hello", " ", "world"])
        let conversation = Conversation(with: mock)
        try await conversation.stream("Tell me something")
        #expect(conversation.messages.last?.text == "Hello world")
    }

    // === Scenario 5: Sequential workflow ===
    @Test("Scenario 5: three-step sequential pipeline")
    func sequentialWorkflow() async throws {
        let r = MockAgentRuntime(response: "researched")
        let w = MockAgentRuntime(response: "written")
        let e = MockAgentRuntime(response: "edited")
        let result = try await Workflow()
            .step(r).step(w).step(e)
            .run("topic")
        #expect(result.output == "edited")
    }

    // === Scenario 6: Parallel workflow ===
    @Test("Scenario 6: parallel fan-out with merge")
    func parallelWorkflow() async throws {
        let a = MockAgentRuntime(response: "positive")
        let b = MockAgentRuntime(response: "Apple, M5")
        let result = try await Workflow()
            .parallel([a, b])
            .run("text")
        #expect(result.output.contains("positive"))
        #expect(result.output.contains("Apple"))
    }

    // === Scenario 7: Router workflow ===
    @Test("Scenario 7: route selects correct agent")
    func routerWorkflow() async throws {
        let billing = MockAgentRuntime(response: "billing")
        let general = MockAgentRuntime(response: "general")
        let result = try await Workflow()
            .route { input in
                input.contains("bill") ? billing : general
            }
            .run("billing question")
        #expect(result.output == "billing")
    }

    // === Scenario 8: Long-running ===
    @Test("Scenario 8: repeatUntil with timeout")
    func longRunning() async throws {
        var count = 0
        let agent = MockAgentRuntime(responseFactory: {
            count += 1
            return count >= 2 ? "SHUTDOWN" : "running"
        })
        let result = try await Workflow()
            .step(agent)
            .repeatUntil { $0.output.contains("SHUTDOWN") }
            .timeout(.seconds(10))
            .run("monitor")
        #expect(result.output == "SHUTDOWN")
    }

    // === Scenario 9: Memory ===
    @Test("Scenario 9: agent with ConversationMemory")
    func memoryAgent() async throws {
        let mock = MockInferenceProvider(defaultResponse: "Max")
        let memory = ConversationMemory(maxMessages: 100)
        let agent = try Agent(instructions: "Journal", memory: memory,
                              inferenceProvider: mock)
        _ = try await agent.run("My dog is Max")
        let ctx = await memory.context(for: "dog", tokenLimit: 500)
        #expect(ctx.contains("Max"))
    }

    // === Scenario 10: Guardrails ===
    @Test("Scenario 10: input guardrail blocks bad input")
    func guardrails() async throws {
        let mock = MockInferenceProvider(defaultResponse: "ok")
        let guardrail = MockInputGuardrail(shouldTripwire: true)
        let agent = try Agent(instructions: "Service", inferenceProvider: mock,
                              inputGuardrails: [guardrail])
        await #expect(throws: Error.self) {
            try await agent.run("bad input")
        }
    }

    // === Scenario 11: Handoffs ===
    @Test("Scenario 11: agent with handoffAgents delegates")
    func handoffs() async throws {
        let mock = MockInferenceProvider(defaultResponse: "routed to billing")
        let billing = try Agent(instructions: "Billing", inferenceProvider: mock)
        let triage = try Agent(instructions: "Triage",
                               inferenceProvider: mock,
                               handoffAgents: [billing])
        let result = try await triage.run("refund please")
        #expect(result.output.contains("billing") || result.output.contains("routed"))
    }

    // === Scenario 12: Observer ===
    @Test("Scenario 12: observed(by:) receives callbacks")
    func observer() async throws {
        let mock = MockInferenceProvider(defaultResponse: "ok")
        let agent = try Agent(instructions: "test", inferenceProvider: mock)
        let counter = CallCountObserver()
        let observed = agent.observed(by: counter)
        _ = try await observed.run("hello")
        #expect(await counter.startCount == 1)
    }
}
```

---

## Execution Order & Dependencies

```
Phase 1 ──→ Phase 2 ──→ Phase 3
                 │
                 └──→ Phase 4 ──→ Phase 5 ──→ Phase 6
                                                 │
                                                 └──→ Integration Tests
```

- **Phase 1**: Independent. Establishes `Swarm.configure()` and error types.
- **Phase 2**: Depends on Phase 1. `@Agent` macro resolves `Swarm.defaultProvider`.
- **Phase 3**: Depends on Phase 2. Conversation wraps `@Agent`-created agents.
- **Phase 4**: Depends on Phase 2. Workflow runs `@Agent`-created agents.
- **Phase 5**: Depends on Phase 4. Workflow uses `AgentObserver` in `.observed(by:)`.
- **Phase 6**: Depends on all. Deprecation is the last step.
- **Integration Tests**: Run after Phase 6. Verify all 12 scenarios pass.

## Quality Gates

| Gate | Requirement |
|------|-------------|
| Phase N tests written | All `@Test` functions compile and FAIL (Red) |
| Phase N implemented | All tests PASS (Green) |
| Phase N reviewed | `swift build` clean, no warnings from new code |
| All phases done | `swift test` passes, zero regressions |
| Integration suite | All 12 scenario tests pass |

## Quick Reference: What Developers Write

| "I want to..." | Code |
|----------------|------|
| Make an agent | `@Agent("instructions") struct X { func process(...) }` |
| Give it tools | `let tools = [MyTool()]` on the struct |
| Run it once | `try await X().run("input")` |
| Chat in SwiftUI | `@State var chat = Conversation(with: X())` |
| Stream tokens | `try await conversation.stream("input")` |
| Chain agents | `Workflow().step(a).step(b).run("input")` |
| Fan-out parallel | `Workflow().parallel([a, b, c]).run("input")` |
| Route dynamically | `Workflow().route { input in ... }.run("input")` |
| Add memory | `let memory = ConversationMemory()` on the struct |
| Add handoffs | `let handoffs = [agentA, agentB]` on the struct |
| Observe lifecycle | `agent.observed(by: MyObserver())` |
| Run indefinitely | `.repeatUntil { }.checkpointed(id:).preventSleep()` |
| Set cloud provider | `await Swarm.configure(provider: ...)` |
| Use guardrails | `Agent(inputGuardrails: [...])` (escape hatch) |

## Migration Guide

```swift
// BEFORE (old API):
@AgentActor("You are helpful")
actor MyAgent {
    let tools: [any AnyJSONTool] = [WeatherTool()]
    func process(_ input: String) async throws -> String { ... }
}

// AFTER (new API):
@Agent("You are helpful")
struct MyAgent {
    let tools = [WeatherTool()]
    func process(_ input: String) async throws -> String { ... }
}

// SwiftUI chat:
@State var chat = Conversation(with: MyAgent())

// Multi-agent:
try await Workflow().step(a).step(b).run("input")

// Long-running:
try await Workflow()
    .step(monitor)
    .repeatUntil { $0.output.contains("done") }
    .checkpointed(id: "monitor-v1")
    .preventSleep(reason: "Active monitoring")
    .run("Watch server health")
```
