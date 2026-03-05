# Phase 4–6 Implementation Prompt: Workflow + AgentObserver + Legacy Deprecation

> [!WARNING]
> Historical prompt. This file includes superseded method names and transitional migration details.
> Current API: `Workflow` core surface plus namespaced power features under `workflow.advanced`.

## Role

You are a senior Swift 6.2 framework engineer implementing Phases 4, 5, and 6 of the Swarm API redesign. You specialize in fluent API design, protocol renaming with backward compatibility, and conditional compilation. You are working inside the Swarm repository at `/Users/chriskarani/CodingProjects/AIStack/Swarm/`.

Your goal: Implement the `Workflow` fluent API, rename `RunHooks` → `AgentObserver`, deprecate the legacy DSL, and verify all 12 target API scenarios pass as an integration suite. Follow strict TDD (Red → Green → Refactor).

**Prerequisites**: Phases 1 (SwarmConfiguration), 2 (@Agent macro), and 3 (Conversation) must be complete.

## Context

### What These Phases Enable

After Phases 4–6, the full Swarm API redesign is complete. Developers get:

```swift
// Scenario 5: Sequential pipeline
let result = try await Workflow()
    .step(researcher).step(writer).step(editor)
    .run("Write about Swift concurrency")

// Scenario 6: Parallel fan-out
let result = try await Workflow()
    .parallel([sentimentAgent, entityAgent])
    .run("Apple announced M5")

// Scenario 7: Router
let result = try await Workflow()
    .route { input in input.contains("bill") ? billingAgent : generalAgent }
    .run("I have a billing question")

// Scenario 8: Long-running autonomous
let result = try await Workflow()
    .step(monitor)
    .repeatUntil { $0.output.contains("done") }
    .checkpointed(id: "monitor-v1")
    .preventSleep(reason: "Active monitoring")
    .run("Watch server health")

// Scenario 12: Observer
let observed = agent.observed(by: MyObserver())
_ = try await observed.run("hello")
```

### Key Design Decisions

| Decision | Choice |
|----------|--------|
| Workflow type | `public struct Workflow: Sendable` — value-type, copy-on-write fluent API |
| Internal execution | Compiles to Hive DAG via `OrchestrationHiveEngine` (simplified for v1: direct execution) |
| MergeStrategy | `.structured` (default), `.first`, `.custom(@Sendable ([AgentResult]) -> String)` |
| AgentObserver | Renamed from `RunHooks`, old name kept as deprecated typealias |
| ObservedAgent | Internal wrapper struct conforming to `AgentRuntime` |
| Legacy DSL | `@available(*, deprecated)` + `#if SWARM_DECLARATIVE_DSL` conditional compilation |
| Package trait | `"declarative-dsl"` trait in Package.swift |

### Existing Types You Must Know

**`AgentRuntime` protocol** (`Sources/Swarm/Core/AgentRuntime.swift`):
```swift
public protocol AgentRuntime: Sendable {
    var name: String { get }
    var tools: [any AnyJSONTool] { get }
    var instructions: String { get }
    var configuration: AgentConfiguration { get }
    var memory: (any Memory)? { get }
    var inferenceProvider: (any InferenceProvider)? { get }
    var tracer: (any Tracer)? { get }
    var handoffs: [AnyHandoffConfiguration] { get }
    var inputGuardrails: [any InputGuardrail] { get }
    var outputGuardrails: [any OutputGuardrail] { get }
    func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult
    nonisolated func stream(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) -> AsyncThrowingStream<AgentEvent, Error>
    func cancel() async
    var isCancelled: Bool { get async }
    func runWithResponse(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentRunResponse
}
```

**`AgentResult`**: Has `output: String`, `iterationCount: Int`, `duration: Duration`, `toolCalls: [ToolCall]`, `metadata: [String: SendableValue]`.

**`RunHooks` protocol** (`Sources/Swarm/Core/RunHooks.swift`): 15 lifecycle methods (onAgentStart, onAgentEnd, onError, onHandoff, onToolStart, onToolCallPartial, onToolEnd, onLLMStart, onLLMEnd, onGuardrailTriggered, onThinking, onThinkingPartial, onOutputToken, onIterationStart, onIterationEnd). All have default no-op implementations.

**`CompositeRunHooks`**: Delegates to multiple hooks concurrently via `withTaskGroup`.

**`LoggingRunHooks`**: Logs all events via `swift-log`.

**`MockAgentRuntime`** (from Phase 3, in `Tests/SwarmTests/Mocks/MockAgentRuntime.swift`): Test mock with configurable `response`, `streamTokens`, `responseFactory`, `delay`.

---

## Phase 4: Workflow

### Step 1 — Write Failing Tests (RED)

**Create** `Tests/SwarmTests/Orchestration/WorkflowTests.swift`:

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
        let result = try await workflow.run("start")
        #expect(result.output == "done")
    }

    // --- Composition ---
    @Test("single step workflow runs one agent")
    func singleStep() async throws {
        let agent = MockAgentRuntime(response: "done")
        let result = try await Workflow()
            .step(agent)
            .run("hello")
        #expect(result.output == "done")
    }

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

Run `swift test --filter WorkflowTests` — all 10 tests must **fail** (RED).

### Step 2 — Implement (GREEN)

**Create** `Sources/Swarm/Orchestration/Workflow.swift`:

```swift
import Foundation

/// Fluent multi-agent workflow. Executes steps sequentially, with support
/// for parallel fan-out, routing, looping, timeouts, and checkpointing.
///
/// ```swift
/// let result = try await Workflow()
///     .step(researcher).step(writer).step(editor)
///     .run("Write about Swift concurrency")
/// ```
public struct Workflow: Sendable {

    // MARK: - Step Types

    enum Step: @unchecked Sendable {
        case single(any AgentRuntime)
        case parallel([any AgentRuntime], merge: MergeStrategy)
        case route(@Sendable (String) -> (any AgentRuntime)?)
    }

    /// Strategy for merging parallel agent results.
    public enum MergeStrategy: @unchecked Sendable {
        /// Concatenates results with labels (default).
        case structured
        /// Takes only the first result.
        case first
        /// Custom merge function.
        case custom(@Sendable ([AgentResult]) -> String)
    }

    // MARK: - Fluent API

    public init() {}

    /// Append a sequential step.
    public func step(_ agent: some AgentRuntime) -> Workflow {
        var copy = self
        copy.steps.append(.single(agent))
        return copy
    }

    /// Append a parallel fan-out step.
    public func parallel(_ agents: [any AgentRuntime],
                         merge: MergeStrategy = .structured) -> Workflow {
        var copy = self
        copy.steps.append(.parallel(agents, merge: merge))
        return copy
    }

    /// Append a routing step that selects an agent based on input.
    public func route(
        _ condition: @escaping @Sendable (String) -> (any AgentRuntime)?
    ) -> Workflow {
        var copy = self
        copy.steps.append(.route(condition))
        return copy
    }

    /// Loop all steps until a condition is met.
    public func repeatUntil(
        maxIterations: Int = 100,
        _ condition: @escaping @Sendable (AgentResult) -> Bool
    ) -> Workflow {
        var copy = self
        copy._repeatCondition = condition
        copy._maxRepeatIterations = maxIterations
        return copy
    }

    /// Set a timeout for the entire workflow.
    public func timeout(_ duration: Duration) -> Workflow {
        var copy = self
        copy._timeout = duration
        return copy
    }

    /// Enable checkpointing for interrupt/resume.
    public func checkpointed(id: String) -> Workflow {
        var copy = self
        copy._checkpointId = id
        return copy
    }

    /// Prevent system sleep while workflow is running.
    public func preventSleep(reason: String) -> Workflow {
        var copy = self
        copy._preventSleepReason = reason
        return copy
    }

    /// Attach an observer for lifecycle events.
    public func observed(by observer: some AgentObserver) -> Workflow {
        var copy = self
        copy._observer = observer
        return copy
    }

    // MARK: - Execution

    /// Run the workflow with the given input string.
    public func run(_ input: String) async throws -> AgentResult {
        let execution: @Sendable () async throws -> AgentResult = {
            try await self.executeSteps(input: input)
        }

        if let timeout = _timeout {
            return try await withThrowingTaskGroup(of: AgentResult.self) { group in
                group.addTask { try await execution() }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw AgentError.timeout(after: timeout)
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        } else {
            return try await execution()
        }
    }

    // MARK: - Private

    private var steps: [Step] = []
    private var _repeatCondition: (@Sendable (AgentResult) -> Bool)?
    private var _maxRepeatIterations: Int = 100
    private var _timeout: Duration?
    private var _checkpointId: String?
    private var _preventSleepReason: String?
    private var _observer: (any AgentObserver)?

    private func executeSteps(input: String) async throws -> AgentResult {
        if let repeatCondition = _repeatCondition {
            var lastResult: AgentResult?
            for _ in 0..<_maxRepeatIterations {
                let currentInput = lastResult?.output ?? input
                lastResult = try await runOnce(input: currentInput)
                if repeatCondition(lastResult!) { return lastResult! }
            }
            return lastResult ?? AgentResult(output: "")
        } else {
            return try await runOnce(input: input)
        }
    }

    private func runOnce(input: String) async throws -> AgentResult {
        var currentInput = input
        var lastResult = AgentResult(output: "")

        for step in steps {
            switch step {
            case .single(let agent):
                lastResult = try await agent.run(currentInput, session: nil, hooks: _observer)
                currentInput = lastResult.output

            case .parallel(let agents, let merge):
                let results = try await withThrowingTaskGroup(
                    of: AgentResult.self,
                    returning: [AgentResult].self
                ) { group in
                    for agent in agents {
                        group.addTask {
                            try await agent.run(currentInput, session: nil, hooks: nil)
                        }
                    }
                    var collected: [AgentResult] = []
                    for try await result in group {
                        collected.append(result)
                    }
                    return collected
                }
                let merged = mergeResults(results, strategy: merge)
                lastResult = AgentResult(output: merged)
                currentInput = merged

            case .route(let condition):
                guard let selected = condition(currentInput) else {
                    throw AgentError.routingFailed(
                        reason: "No agent matched for input"
                    )
                }
                lastResult = try await selected.run(currentInput, session: nil, hooks: _observer)
                currentInput = lastResult.output
            }
        }
        return lastResult
    }

    private func mergeResults(_ results: [AgentResult], strategy: MergeStrategy) -> String {
        switch strategy {
        case .structured:
            return results.enumerated().map { i, r in
                "[\(i)]: \(r.output)"
            }.joined(separator: "\n")
        case .first:
            return results.first?.output ?? ""
        case .custom(let fn):
            return fn(results)
        }
    }
}
```

**Important implementation notes:**
- `AgentResult(output:)` — verify this initializer exists. If not, create a convenience init or use the existing init with default values for other fields.
- `AgentError.timeout(after:)` — you may need to add this case to `AgentError`. If it doesn't exist, add: `case timeout(after: Duration)`.
- `AgentError.routingFailed(reason:)` — similarly, add if missing.
- The `_observer` is passed as `hooks:` parameter because Phase 5 hasn't renamed it yet. Phase 5 will update this.

Run `swift test --filter WorkflowTests` — all 10 tests must **pass** (GREEN).

### Step 3 — Refactor

- Remove any duplication in `runOnce`
- Ensure all stored closures are `@Sendable`
- Verify `swift build` produces zero warnings from new code

---

## Phase 5: AgentObserver (Rename RunHooks)

### Step 1 — Write Failing Tests (RED)

**Create** `Tests/SwarmTests/Core/AgentObserverTests.swift`:

```swift
import Testing
@testable import Swarm

@Suite("AgentObserver")
struct AgentObserverTests {

    // --- Scenario 12: Custom observer conformance ---
    @Test("AgentObserver conformance works")
    func observerConformance() async throws {
        struct TestObserver: AgentObserver {
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

    // --- Backward compat: RunHooks typealias ---
    @Test("RunHooks typealias still compiles")
    func runHooksBackcompat() {
        let _: any RunHooks = LoggingRunHooks()
    }

    // --- Backward compat: hooks: parameter ---
    @Test("run with hooks: parameter still compiles")
    func runWithHooksParam() async throws {
        let mock = MockInferenceProvider(defaultResponse: "ok")
        let agent = try Agent(instructions: "test", inferenceProvider: mock)
        let hooks = LoggingRunHooks()
        _ = try await agent.run("hello", hooks: hooks)
    }
}

/// Test helper — counts observer callbacks
actor CallCountObserver: AgentObserver {
    var startCount = 0
    var endCount = 0
    func onAgentStart(context: AgentContext?, agent: any AgentRuntime, input: String) async {
        startCount += 1
    }
    func onAgentEnd(context: AgentContext?, agent: any AgentRuntime, result: AgentResult) async {
        endCount += 1
    }
}
```

Run `swift test --filter AgentObserverTests` — all 4 tests must **fail** (RED) because `AgentObserver` doesn't exist yet.

### Step 2 — Implement (GREEN)

#### 2a. Rename protocol in `Sources/Swarm/Core/RunHooks.swift`

1. Rename `public protocol RunHooks` → `public protocol AgentObserver`
2. Add deprecated typealias below the protocol:
   ```swift
   @available(*, deprecated, renamed: "AgentObserver")
   public typealias RunHooks = AgentObserver
   ```
3. Rename the default implementations extension: `public extension RunHooks` → `public extension AgentObserver`
4. Rename `CompositeRunHooks` → `CompositeObserver`, add:
   ```swift
   @available(*, deprecated, renamed: "CompositeObserver")
   public typealias CompositeRunHooks = CompositeObserver
   ```
5. Rename `LoggingRunHooks` → `LoggingObserver`, add:
   ```swift
   @available(*, deprecated, renamed: "LoggingObserver")
   public typealias LoggingRunHooks = LoggingObserver
   ```
6. Update the file header comment to reference "AgentObserver"

#### 2b. Update `AgentRuntime` protocol in `Sources/Swarm/Core/AgentRuntime.swift`

Add a new protocol requirement with `observer:` parameter and backward-compat extension:

```swift
// In the protocol — add new methods:
func run(_ input: String, session: (any Session)?, observer: (any AgentObserver)?) async throws -> AgentResult
nonisolated func stream(_ input: String, session: (any Session)?, observer: (any AgentObserver)?) -> AsyncThrowingStream<AgentEvent, Error>

// Default extension — bridge old hooks: to new observer:
extension AgentRuntime {
    public func run(_ input: String, session: (any Session)? = nil,
                    hooks: (any RunHooks)?) async throws -> AgentResult {
        try await run(input, session: session, observer: hooks)
    }
    public func run(_ input: String) async throws -> AgentResult {
        try await run(input, session: nil, observer: nil)
    }
}
```

**IMPORTANT**: This is a large protocol change. The safest approach:
- Keep the existing `hooks:` methods as the *actual* implementations inside `Agent` and other conforming types
- Add a default extension that bridges `observer:` calls to `hooks:` calls (reverse direction)
- This avoids changing every `AgentRuntime` conformer at once

The minimal-risk bridge:
```swift
extension AgentRuntime {
    /// New API: observer parameter (delegates to hooks: internally)
    public func run(_ input: String, session: (any Session)? = nil,
                    observer: (any AgentObserver)?) async throws -> AgentResult {
        try await run(input, session: session, hooks: observer)
    }
}
```

This works because `RunHooks` is now a typealias for `AgentObserver`, so `observer` (typed `AgentObserver?`) can be passed where `RunHooks?` is expected.

#### 2c. Create `ObservedAgent` wrapper

**Create** `Sources/Swarm/Core/ObservedAgent.swift`:

```swift
/// Internal wrapper that attaches an observer to an existing agent.
struct ObservedAgent<Wrapped: AgentRuntime>: AgentRuntime {
    let wrapped: Wrapped
    let observer: any AgentObserver

    // Delegate all properties
    nonisolated var name: String { wrapped.name }
    nonisolated var tools: [any AnyJSONTool] { wrapped.tools }
    nonisolated var instructions: String { wrapped.instructions }
    nonisolated var configuration: AgentConfiguration { wrapped.configuration }
    nonisolated var memory: (any Memory)? { wrapped.memory }
    nonisolated var inferenceProvider: (any InferenceProvider)? { wrapped.inferenceProvider }
    nonisolated var tracer: (any Tracer)? { wrapped.tracer }
    nonisolated var handoffs: [AnyHandoffConfiguration] { wrapped.handoffs }
    nonisolated var inputGuardrails: [any InputGuardrail] { wrapped.inputGuardrails }
    nonisolated var outputGuardrails: [any OutputGuardrail] { wrapped.outputGuardrails }

    var isCancelled: Bool {
        get async { await wrapped.isCancelled }
    }

    func cancel() async { await wrapped.cancel() }

    func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult {
        await observer.onAgentStart(context: nil, agent: wrapped, input: input)
        do {
            let result = try await wrapped.run(input, session: session, hooks: hooks ?? observer)
            await observer.onAgentEnd(context: nil, agent: wrapped, result: result)
            return result
        } catch {
            await observer.onError(context: nil, agent: wrapped, error: error)
            throw error
        }
    }

    nonisolated func stream(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) -> AsyncThrowingStream<AgentEvent, Error> {
        wrapped.stream(input, session: session, hooks: hooks ?? observer)
    }

    func runWithResponse(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentRunResponse {
        try await wrapped.runWithResponse(input, session: session, hooks: hooks ?? observer)
    }
}
```

#### 2d. Add `.observed(by:)` extension

Add to `Sources/Swarm/Core/ObservedAgent.swift` (same file):

```swift
extension AgentRuntime {
    /// Wraps this agent with an observer that receives lifecycle callbacks.
    public func observed(by observer: some AgentObserver) -> some AgentRuntime {
        ObservedAgent(wrapped: self, observer: observer)
    }
}
```

Run `swift test --filter AgentObserverTests` — all 4 tests must **pass** (GREEN).

### Step 3 — Refactor

- Search all source files for remaining `RunHooks` references (excluding the deprecated typealias). Update doc comments.
- Ensure `swift build` produces zero warnings from new code
- Run `swift test` to verify zero regressions

---

## Phase 6: Deprecate Legacy DSL

### Step 1 — Write Failing Tests (RED)

**Add** to existing test file or create `Tests/SwarmTests/DSL/LegacyDSLDeprecationTests.swift`:

```swift
import Testing
@testable import Swarm

@Suite("Legacy DSL Deprecation")
struct LegacyDSLDeprecationTests {
    @Test("ChatAgent is deprecated but still compiles")
    func chatAgentStillWorks() async throws {
        let mock = MockInferenceProvider(defaultResponse: "hi")
        let agent = ChatAgent("test instructions", inferenceProvider: mock)
        let result = try await agent.run("hello")
        #expect(result.output == "hi")
    }
}
```

Run `swift test --filter LegacyDSLDeprecationTests` — test should **pass** (ChatAgent exists). The goal here is to ensure it *still* passes after deprecation annotations are added.

### Step 2 — Implement (GREEN)

#### 2a. Deprecate DSL types

Add `@available(*, deprecated)` to each file:

**`Sources/Swarm/DSL/AgentBlueprint.swift`**:
```swift
@available(*, deprecated, message: "Use @Agent macro or Workflow instead")
public protocol AgentBlueprint: Sendable { ... }
```

**`Sources/Swarm/DSL/AgentLoop.swift`** — deprecate the main type.

**`Sources/Swarm/DSL/AgentLoopBuilder.swift`** — deprecate the result builder.

**`Sources/Swarm/DSL/AgentLoopStep.swift`** — deprecate step types.

**`Sources/Swarm/DSL/DeclarativeAgent.swift`** — deprecate.

**`Sources/Swarm/DSL/LoopAgent.swift`** — deprecate.

#### 2b. Deprecate ChatAgent

**`Sources/Swarm/Agents/Chat.swift`**:
```swift
@available(*, deprecated, message: "Use @Agent macro with Conversation instead")
public actor ChatAgent: AgentRuntime { ... }
```

#### 2c. Add package trait for conditional compilation

**`Package.swift`** — add the `declarative-dsl` trait:

```swift
// At the package level, add traits:
let package = Package(
    name: "Swarm",
    // ... existing config ...
    traits: [
        .trait(name: "declarative-dsl", description: "Enable deprecated declarative DSL types")
    ],
    // ...
)
```

In the Swarm target's `swiftSettings`, add:
```swift
.define("SWARM_DECLARATIVE_DSL", .when(traits: ["declarative-dsl"]))
```

#### 2d. Wrap DSL files with conditional compilation

In each DSL file (`AgentBlueprint.swift`, `AgentLoop.swift`, `AgentLoopBuilder.swift`, `AgentLoopStep.swift`, `DeclarativeAgent.swift`, `LoopAgent.swift`), wrap the **entire** file content:

```swift
#if SWARM_DECLARATIVE_DSL
// ... existing content with @available(*, deprecated) ...
#endif
```

**IMPORTANT**: After wrapping, the default build (without the trait) will NOT include DSL types. This means:
- Any `import` or reference to `AgentBlueprint` etc. in non-DSL code must be behind `#if SWARM_DECLARATIVE_DSL` too
- Search for references: `grep -r "AgentBlueprint\|AgentLoop\|DeclarativeAgent\|LoopAgent\|AgentLoopBuilder\|AgentLoopStep" Sources/`
- Update any references found (likely in `Orchestration/` or other bridge code)

Run `swift test --filter LegacyDSLDeprecationTests` — must still **pass**.
Run `swift build` — must succeed with zero errors.

### Step 3 — Refactor

- Verify `swift build` clean
- Verify `swift test` passes (all existing tests, not just new ones)
- Any test files referencing DSL types should also be behind `#if SWARM_DECLARATIVE_DSL` or updated

---

## Integration Test Suite (Final Verification)

After all three phases are complete, create the integration suite that verifies all 12 target API scenarios.

**Create** `Tests/SwarmTests/Integration/FullAPIScenarioTests.swift`:

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

**Note**: `CallCountObserver` is defined in `AgentObserverTests.swift`. Either move it to a shared test helper file or re-define it here.

Run `swift test --filter FullAPIScenarioTests` — all 12 tests must **pass**.

---

## Success Criteria

| # | Criterion | Verification |
|---|-----------|-------------|
| 1 | `Workflow().step(a).step(b).run("x")` compiles and runs sequentially | WorkflowTests.scenario5Sequential |
| 2 | `Workflow().parallel([a, b]).run("x")` fans out concurrently | WorkflowTests.scenario6Parallel |
| 3 | Custom merge strategy works | WorkflowTests.scenario6CustomMerge |
| 4 | `Workflow().route { }.run("x")` selects correct agent | WorkflowTests.scenario7Route |
| 5 | `.repeatUntil { }` loops until condition met | WorkflowTests.scenario8RepeatUntil |
| 6 | `.timeout()` throws `AgentError.timeout` | WorkflowTests.scenario8Timeout |
| 7 | `.checkpointed(id:)` builds without error | WorkflowTests.scenario8Checkpointed |
| 8 | `AgentObserver` protocol exists and works | AgentObserverTests.observerConformance |
| 9 | `.observed(by:)` wraps agent and fires callbacks | AgentObserverTests.observedByFluent |
| 10 | `RunHooks` typealias compiles (backward compat) | AgentObserverTests.runHooksBackcompat |
| 11 | `hooks:` parameter still works (backward compat) | AgentObserverTests.runWithHooksParam |
| 12 | `ChatAgent` compiles with deprecation warning | LegacyDSLDeprecationTests |
| 13 | DSL types behind `#if SWARM_DECLARATIVE_DSL` | `swift build` succeeds without trait |
| 14 | All 12 API scenarios pass | FullAPIScenarioTests (all 12) |
| 15 | `swift build` clean, zero errors | Terminal |
| 16 | `swift test` passes, zero regressions | Terminal |

## Edge Cases & Gotchas

1. **`AgentResult` initializer**: The plan uses `AgentResult(output: "")`. Verify this convenience init exists. If only the full initializer exists, create a test-friendly factory or extension.

2. **`AgentError` new cases**: Phase 4 needs `timeout(after:)` and `routingFailed(reason:)`. Check `AgentError.swift` — add these cases if missing, with appropriate `LocalizedError` messages and `recoverySuggestion`.

3. **RunHooks → AgentObserver migration ripple**: After renaming, every file that references `RunHooks` directly (not via typealias) may get deprecation warnings. The typealias handles compile-time compatibility, but internal code should migrate to `AgentObserver`. Search with: `grep -r "RunHooks" Sources/ --include="*.swift"`.

4. **DSL conditional compilation cascade**: When wrapping DSL files in `#if SWARM_DECLARATIVE_DSL`, any code that *imports* or *references* these types outside the DSL directory will break. Common locations: `Sources/Swarm/Orchestration/`, `Sources/Swarm/HiveSwarm/`. Search and wrap those references too.

5. **Parallel result ordering**: `withThrowingTaskGroup` does NOT guarantee result order. The structured merge uses enumeration index, which reflects *completion* order, not *submission* order. This is acceptable for v1 but document it.

6. **ObservedAgent Sendable**: `ObservedAgent` stores `any AgentObserver` (which is `Sendable`) and `Wrapped: AgentRuntime` (also `Sendable`), so the struct is automatically `Sendable`. No `@unchecked` needed.

7. **Workflow value semantics**: Each fluent method returns a copy. This means `let w = Workflow().step(a)` and `w.step(b)` don't modify `w` — they return a new value. This is correct but test that users chain calls properly.

## Execution Order

```
Phase 4 (Workflow)
  └─ Write WorkflowTests (RED) → Implement Workflow.swift (GREEN) → Refactor
      └─ Phase 5 (AgentObserver)
          └─ Write AgentObserverTests (RED) → Rename RunHooks, create ObservedAgent (GREEN) → Refactor
              └─ Phase 6 (Legacy Deprecation)
                  └─ Write LegacyDSLDeprecationTests → Add deprecations + conditional compilation → Verify
                      └─ Integration Tests
                          └─ Create FullAPIScenarioTests → All 12 pass → DONE
```

At each phase boundary: `swift build` must succeed, `swift test` must show zero regressions.
