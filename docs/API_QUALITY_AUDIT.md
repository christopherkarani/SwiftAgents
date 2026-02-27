# Swarm Framework — Public API Quality Audit

**Date:** 2026-02-27
**Revision:** 2 (post-verification pass — all claims checked against source)
**Methodology:** Evaluated against [Apple's Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/), Apple framework conventions (SwiftUI, Foundation, Observation), and Apple Human Interface engineering principles.
**Scope:** All public declarations in `Swarm` and `SwarmMCP` targets.

---

## Executive Summary

**Overall Grade: B+**

Swarm is a serious, well-architected framework that gets the hardest things right — strict concurrency compliance, protocol-oriented design, and a genuinely ergonomic SwiftUI-style DSL. It is closer to Apple-quality than most third-party Swift frameworks. However, several API surface inconsistencies, naming deviations, and structural choices prevent it from reaching the polish bar set by Foundation, SwiftUI, or Observation.

The issues below are ordered by severity, from framework-level concerns down to naming nits.

---

## 1. PROTOCOL NAMING — The `AgentRuntime` Problem

**Severity: High | Apple Guideline: "Protocols that describe a capability should be named using the suffixes -able, -ible, or -ing"**

`AgentRuntime` is the single most important protocol in the framework, yet its name suggests a concrete runtime engine (like `JavaScriptCore` or `URLSession`), not a protocol describing what an agent *can do*.

| Current | Apple-style Alternatives |
|---------|--------------------------|
| `AgentRuntime` | `AgentExecutable`, `Agent` (protocol), or `AgentProtocol` |
| `InferenceProvider` | Good — follows `-er` / `-or` convention for capability |
| `Memory` | Acceptable but generic — `AgentMemory` would scope it |

**Why this matters:** When a user sees `any AgentRuntime`, they read it as "any agent runtime engine," not "any agent." Apple would name this `Agent` (the protocol) and then use concrete names like `ReActAgent`, `ToolCallingAgent` for implementations — exactly how SwiftUI uses `View` for the protocol and `Text`, `Button` for concretes.

The fact that the concrete type is *also* named `Agent` creates a collision:
```swift
public actor Agent: AgentRuntime { ... }  // Agent conforms to AgentRuntime
```
This is the Swift equivalent of `class View: ViewProtocol` — it works, but it signals that the naming hierarchy wasn't designed protocol-first.

**Recommendation:** If renaming `AgentRuntime` is too disruptive, at minimum add a typealias:
```swift
public typealias AgentProtocol = AgentRuntime
```

---

## 2. TYPE PROLIFERATION — Too Many Ways to Do the Same Thing

**Severity: High | Apple Guideline: Progressive disclosure**

The framework exposes three generations of agent definition simultaneously:

| Generation | Entry Point | Status |
|-----------|-------------|--------|
| `AgentLoopDefinition` | Legacy DSL | Deprecated but still in builders |
| `AgentBlueprint` | SwiftUI-style protocol | "Current preferred" |
| `Agent` / `ReActAgent` | Direct instantiation | Most documented |

Apple's approach: when SwiftUI replaced UIKit patterns, the old API was hidden behind availability gates, not left sitting in the same result builder. The `@OrchestrationBuilder` still has:
```swift
@available(*, deprecated)
public static func buildExpression<A: AgentLoopDefinition>(_ agent: A) -> OrchestrationStep
```

**Recommendation:** Move deprecated generation behind `#if SWARM_LEGACY` or remove from the public builder entirely. A new user should never encounter `AgentLoopDefinition`.

---

## 3. OPERATOR OVERLOAD SPRAWL

**Severity: High | Apple Guideline: "Clarity at the point of use"**

Five custom operators is excessive for a framework at this stage:

| Operator | Meaning | Discoverability |
|----------|---------|-----------------|
| `-->` | Sequential chain | Low — resembles arrow but isn't one |
| `>>>` | Pipeline composition | Medium — known from FP |
| `&+` | Parallel composition | Low — looks like bitwise/overflow add |
| `~>` | Sequential (alternate) | Very low — conflicts with Combine conventions |
| `\|?` | Conditional fallback | Very low — novel syntax |

**The core problem:** `-->` and `~>` both mean "sequential." This violates Apple's "one obvious way" principle. `&+` is particularly dangerous because Swift already uses `&+` for overflow addition on integers.

Apple frameworks use custom operators extremely sparingly (SwiftUI uses zero). The idiomatic SwiftUI approach is method chaining and result builders, which Swarm *also* has via `Sequential { }` and `Parallel { }`.

Notably, the types produced by `&+` and `~>` are *already deprecated*:
- `ParallelComposition` (from `&+`): `@available(*, deprecated, message: "Use ParallelGroup for parallel orchestration.")`
- `AgentSequence` (from `~>`): `@available(*, deprecated, message: "Use SequentialChain for sequential orchestration.")`

The framework has already identified these as redundant but hasn't deprecated the *operators themselves*, leaving a trap: the operators still compile cleanly and produce deprecated types.

**Recommendation:**
- Deprecate `&+` and `~>` operators to match their deprecated return types.
- Keep `-->` (most intuitive, non-deprecated `SequentialChain`) and `>>>` (established FP convention).
- Deprecate `|?` in favor of an explicit `ConditionalFallback` initializer or result builder pattern.
- Add `@available(*, deprecated)` on the operator functions, not just the types.

---

## 4. NAMING CONSISTENCY ISSUES

**Severity: Medium | Apple Guideline: "Strive for fluent usage"**

### 4a. Inconsistent Start/End vs Start/Complete Naming

The `RunHooks` protocol mixes conventions:

```swift
func onAgentStart(...)   // "Start"
func onAgentEnd(...)     // "End"
func onToolStart(...)    // "Start"
func onToolEnd(...)      // "End"
func onLLMStart(...)     // "Start"
func onLLMEnd(...)       // "End"
func onIterationStart(...)  // "Start"
func onIterationEnd(...)    // "End"
```

But `AgentEvent` uses different suffixes:

```swift
case toolCallStarted(...)     // "Started" (past tense)
case toolCallCompleted(...)   // "Completed" (not "Ended")
case iterationStarted(...)    // "Started"
case iterationCompleted(...)  // "Completed"
```

Apple convention (Observation, Combine): events are past-tense (`didChange`, `willSet`), callbacks are present-tense (`onChange`, `onSubmit`). Pick one convention and apply it uniformly:

| Component | Current | Apple-style |
|-----------|---------|-------------|
| Hook | `onAgentStart` / `onAgentEnd` | `agentDidStart` / `agentDidFinish` |
| Event | `toolCallStarted` / `toolCallCompleted` | Consistent past-tense (good) |

### 4b. `AnyJSONTool` — Misleading Prefix (Partially Mitigated)

In Swift, the `Any` prefix means "type-erased wrapper" (`AnyView`, `AnyPublisher`, `AnySequence`). `AnyJSONTool` is a *protocol*, not a type-erased box, which violates this convention.

The framework *does* have the right layering underneath:
- `protocol Tool` — strongly-typed tool with `associatedtype Input/Output` (`TypedToolProtocol.swift`)
- `protocol AnyJSONTool` — dynamic JSON-level tool at the model boundary (`Tool.swift`)
- `struct AnyTool: AnyJSONTool` — actual type-erased wrapper (`AnyTool.swift`)

The problem is that `AnyJSONTool` is the protocol that appears in every public API signature (`tools: [any AnyJSONTool]`), so users see `any AnyJSONTool` — a doubly-abstract-looking type. Apple convention would be:

| Current | Apple Convention |
|---------|-----------------|
| `protocol AnyJSONTool` | `protocol JSONTool` or `protocol DynamicTool` |
| `protocol Tool` | Good — correct name for the primary typed protocol |
| `struct AnyTool: AnyJSONTool` | Should conform to `JSONTool` (or whatever the protocol becomes) |

The `protocol Tool` name is correct. The issue is the `Any` prefix on its dynamic sibling.

### 4c. `SendableValue` — Unconventional Name

This is the framework's universal JSON value type. Apple frameworks call this pattern:
- Foundation: `JSONValue` (proposed), `NSObject`
- SwiftData: `PersistentModel`

`SendableValue` describes an implementation detail (Sendable conformance) rather than the concept (a JSON-compatible dynamic value). The existing `public typealias JSONValue = SendableValue` is buried and should be promoted.

### 4d. `GuardrailResult.tripwireTriggered` — Domain Jargon

`tripwireTriggered` is an internal metaphor. Apple would use:
```swift
// Current
GuardrailResult(tripwireTriggered: true)

// Apple-style
GuardrailResult(passed: false)
// or
GuardrailResult.blocked(reason: "Content policy violation")
```

### 4e. Handoff Event Duplication

`AgentEvent` has overlapping handoff cases:
```swift
case handoffRequested(fromAgent:, toAgent:, reason:)
case handoffCompleted(fromAgent:, toAgent:)
case handoffStarted(from:, to:, input:)               // Overlaps with handoffRequested
case handoffCompletedWithResult(from:, to:, result:)   // Overlaps with handoffCompleted
case handoffSkipped(from:, to:, reason:)
```

Five handoff event variants with inconsistent labels (`fromAgent` vs `from`) suggest these were added incrementally. Consolidate:
```swift
case handoff(HandoffEvent)

public enum HandoffEvent: Sendable {
    case requested(from: String, to: String, input: String, reason: String?)
    case completed(from: String, to: String, result: AgentResult)
    case skipped(from: String, to: String, reason: String)
}
```

---

## 5. INITIALIZER ERGONOMICS

**Severity: Medium | Apple Guideline: "Omit needless words" and progressive disclosure**

### 5a. Agent Initializer is a Wall of Parameters

```swift
public init(
    tools: [any AnyJSONTool] = [],
    instructions: String = "",
    configuration: AgentConfiguration = .default,
    memory: (any Memory)? = nil,
    inferenceProvider: (any InferenceProvider)? = nil,
    tracer: (any Tracer)? = nil,
    inputGuardrails: [any InputGuardrail] = [],
    outputGuardrails: [any OutputGuardrail] = [],
    guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default,
    handoffs: [AnyHandoffConfiguration] = []
) throws
```

10 parameters (11 with the convenience `init(_:)` overload). Apple avoids this — SwiftUI's `Button` has 2-3 parameters; complex configuration goes into modifiers.

The `@Builder` macro on `AgentConfiguration` generates fluent setters, which is excellent. But the Agent itself doesn't follow this pattern — you can't write:
```swift
// This doesn't work:
Agent(instructions: "Help the user")
    .withMemory(ConversationMemory())
    .withGuardrails([lengthGuard])
```

**Recommendation:** Add a builder pattern or modifier chain for `Agent` itself, keeping the initializer for power users. The `@AgentActor` macro's generated `Builder` is a good model — expose the same pattern for `Agent`.

### 5b. AgentConfiguration's 18 Parameters

```swift
public init(
    name: String = "Agent",
    maxIterations: Int = 10,
    timeout: Duration = .seconds(60),
    temperature: Double = 1.0,
    maxTokens: Int? = nil,
    stopSequences: [String] = [],
    modelSettings: ModelSettings? = nil,
    contextProfile: ContextProfile = .platformDefault,
    hiveRunOptionsOverride: SwarmHiveRunOptionsOverride? = nil,
    inferencePolicy: InferencePolicy? = nil,
    enableStreaming: Bool = true,
    includeToolCallDetails: Bool = true,
    stopOnToolError: Bool = false,
    includeReasoning: Bool = true,
    sessionHistoryLimit: Int? = 50,
    contextMode: ContextMode = .adaptive,
    parallelToolCalls: Bool = false,
    previousResponseId: String? = nil,
    autoPreviousResponseId: Bool = false,
    defaultTracingEnabled: Bool = true
)
```

18 parameters is a configuration anti-pattern. The `@Builder` macro mitigates this with fluent setters, but the init still exists in the public API and autocomplete. Apple would group these into nested configuration types:

```swift
// Apple-style
struct AgentConfiguration {
    var model: ModelConfiguration      // temperature, maxTokens, stopSequences
    var execution: ExecutionLimits     // maxIterations, timeout, parallelToolCalls
    var observability: ObservabilityOptions  // tracing, reasoning, toolCallDetails
    var context: ContextConfiguration  // contextMode, contextProfile, sessionHistoryLimit
}
```

### 5c. `temperature` Appears in Three Places

`temperature` lives on:
- `AgentConfiguration.temperature` — non-optional, default `1.0` (`AgentConfiguration.swift:149`)
- `ModelSettings.temperature` — optional, default `nil` (`ModelSettings.swift:50`)
- `InferenceOptions.temperature` — non-optional, default `1.0` (`AgentRuntime.swift:311`)

The precedence is documented and implemented in `AgentConfiguration+InferenceOptions.swift`: `ModelSettings.temperature ?? AgentConfiguration.temperature → InferenceOptions.temperature`. This works correctly, but the three-layer indirection means a user setting `configuration.temperature(0.7)` may be surprised when `modelSettings.temperature` silently overrides it. Apple would have exactly one place to set temperature.

---

## 6. DSL AND RESULT BUILDER QUALITY

**Severity: Low-Medium | Overall: Strong**

### 6a. What's Good

The `@OrchestrationBuilder` is well-designed and follows SwiftUI conventions:
- `buildBlock`, `buildOptional`, `buildEither`, `buildArray` — complete set
- `buildExpression` overloads for `AgentRuntime`, `AgentBlueprint`, `OrchestrationStep` — progressive adoption
- Step types (`Sequential`, `Parallel`, `Branch`, `DAG`, `Router`, `RepeatWhile`, `Transform`) cover real workflows

The `Pipeline` type with `map`, `flatMap`, `catchError`, `retry`, `timeout` is genuinely excellent functional programming API design.

### 6b. `RouteCondition` Combinators — Best-in-Class

```swift
RouteCondition.contains("error")
    .and(.lengthInRange(10...1000))
    .or(.contextHas(key: "override"))
```

This is Apple-quality API design. Clear, composable, discoverable.

### 6c. Four Result Builders May Be Too Many

`@OrchestrationBuilder`, `@ParallelBuilder`, `@RouteBuilder`, `@DAGBuilder` — each builder has its own scope. Apple typically uses one builder per DSL (SwiftUI has `@ViewBuilder` and almost nothing else for users).

Consider whether `@ParallelBuilder` and `@DAGBuilder` could be folded into `@OrchestrationBuilder` using contextual types.

---

## 7. MACRO API QUALITY

**Severity: Low | Overall: Good**

### 7a. `@Tool` — Clean and Practical

```swift
@Tool("Calculates mathematical expressions")
struct CalculatorTool {
    @Parameter("The expression to evaluate")
    var expression: String

    func execute() async throws -> String { ... }
}
```

This is well-designed. The macro eliminates boilerplate while keeping the type explicit. The `@Parameter` marker macro with description, default, and `oneOf` is a good progressive-disclosure API.

### 7b. `@AgentActor` — Slight Naming Concern

The macro name `@AgentActor` bakes in the implementation detail (Swift actors) rather than the concept. If the framework ever supports class-based agents, the name becomes misleading. `@Agent` would be more forward-looking (similar to how `@Observable` doesn't say `@ObservableClass`).

### 7c. Two `@AgentActor` Overloads — Confusing

```swift
@AgentActor(instructions: "...", generateBuilder: true)
@AgentActor("...")  // Unlabeled convenience
```

The unlabeled version is convenient but the labeled version exposes `generateBuilder: Bool`, which is an implementation detail that shouldn't be in the API. Apple macros (like `@Observable`, `@Model`) take zero parameters.

---

## 8. CONCURRENCY MODEL

**Severity: Low | Overall: Excellent**

This is where Swarm shines. The concurrency design is genuinely Apple-grade:

- **All agents are actors** — correct isolation by construction
- **`Memory` requires `Actor` conformance** — prevents data races in memory systems
- **`Tracer` requires `Actor` conformance** — consistent with Memory
- **Strict concurrency on all targets** — no escape hatches
- **`nonisolated` on protocol requirements** — allows synchronous access to identity properties
- **Structured concurrency in `CompositeRunHooks`** — `withTaskGroup` for concurrent hook dispatch
- **`SendableValue` as the universal transfer type** — eliminates `@unchecked Sendable` temptation

One concern: `AgentResult.Builder` is `final class: @unchecked Sendable`, which is the one place the framework punches through the safety net. This is acceptable for an internal builder pattern but should not be visible in the public API.

---

## 9. ERROR HANDLING

**Severity: Low | Overall: Good**

`AgentError` is a comprehensive, well-organized error enum with associated values. It conforms to `LocalizedError`, `Equatable`, `CustomDebugStringConvertible` — all the right protocols.

**Minor issues:**
- `AgentError` has 16 cases, pushing toward an enum that should be split by domain:
  - `AgentError.Input`, `AgentError.Tool`, `AgentError.Model`, `AgentError.Execution`
- `GuardrailError` is separate from `AgentError` but both can be thrown from `run()`. Users need to catch both.
- `EmbeddingError` is yet another error type. Consider consolidating under a namespace.

---

## 10. DOCUMENTATION QUALITY

**Severity: Low | Overall: Good**

- Core protocols (`AgentRuntime`, `InferenceProvider`, `Memory`) have thorough `///` documentation with examples
- `RunHooks` has excellent per-method documentation explaining every parameter
- `AgentEvent` has code examples in the enum-level doc comment
- `AgentConfiguration` documents every parameter with defaults

**Gaps:**
- The orchestration step types lack usage examples in their doc comments
- No `// MARK: -` organization in some files (inconsistent)
- The relationship between `AgentResult` and `AgentResponse` is documented on `AgentResponse` but not on `AgentResult`, so users discovering `AgentResult` first won't know `AgentResponse` exists

---

## 11. MINOR ISSUES

### 11a. `TokenUsage` Defined Twice
`TokenUsage` exists as two structurally identical but distinct types:
- `TokenUsage` — top-level in `AgentResult.swift`, conforms to `Sendable, Equatable, Codable`
- `InferenceResponse.TokenUsage` — nested in `AgentRuntime.swift`, conforms to `Sendable, Equatable` (no `Codable`)

Same fields (`inputTokens`, `outputTokens`, computed `totalTokens`), same init signature, but they are NOT aliases — they are separate struct definitions with different conformances. The codebase uses qualified access (`InferenceResponse.TokenUsage`) to disambiguate. Apple would have one canonical `TokenUsage` type, adding `Codable` conformance uniformly.

### 11b. Inconsistent Optional Handling in `run()`
```swift
func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult
```

The convenience overloads handle the optionality well, but the protocol requirement forces conformers to accept optionals. Apple protocols typically use non-optional requirements with separate methods for optional features.

### 11c. `SwarmRuntimeMode` Has Two Deprecated Cases
```swift
public enum SwarmRuntimeMode: Sendable, Equatable {
    case hive
    @available(*, deprecated, renamed: "hive") case swift
    @available(*, deprecated, renamed: "hive") case requireHive
}
```

An enum with one valid case is not an enum — it's a constant. Remove the type entirely.

### 11d. Naming: `SwarmHiveRunOptionsOverride`
This is an implementation-detail name leaking into the public API. `HiveExecutionOptions` or just `ExecutionOptions` would be cleaner.

---

## SCORECARD

| Category | Grade | Notes |
|----------|-------|-------|
| **Protocol Design** | A- | Clean protocol hierarchy, good use of existentials |
| **Naming Conventions** | B | `AgentRuntime`, `AnyJSONTool`, `SendableValue` miss Apple conventions |
| **Progressive Disclosure** | B | Good defaults, but initializer walls and triple-DSL hurt |
| **Concurrency Safety** | A+ | Best-in-class for a Swift 6 framework |
| **DSL / Result Builders** | A- | Excellent orchestration DSL, too many operators |
| **Macros** | A- | `@Tool` is great, `@AgentActor` naming could improve |
| **Error Handling** | B+ | Comprehensive but fragmented across types |
| **Documentation** | B+ | Good coverage, some gaps in orchestration types |
| **API Consistency** | B- | Start/End vs Started/Completed, label mismatches |
| **Backward Compatibility** | C+ | Three DSL generations visible simultaneously |

---

## TOP 5 CHANGES FOR APPLE-WORTHY STATUS

1. **Rename `AnyJSONTool` to `JSONTool`** (or `DynamicTool`). The framework already has the right `Tool` protocol and `AnyTool` wrapper — the `Any` prefix on the *protocol* is the problem. Every public API surface reads `[any AnyJSONTool]`, which is confusing. `[any JSONTool]` reads cleanly.

2. **Deprecate the `&+`, `~>`, and `|?` operators** to match their already-deprecated return types (`ParallelComposition`, `AgentSequence`). Keep `-->` and `>>>` which produce non-deprecated types. The operators still compile cleanly and silently produce deprecated types — a trap for new users.

3. **Unify event naming** — pick either `Start/End` or `Started/Completed` and apply it everywhere. Consolidate the five handoff event cases into a nested `HandoffEvent` enum.

4. **Hide legacy DSL** — remove `AgentLoopDefinition` from the public `@OrchestrationBuilder`. New users should only see `AgentBlueprint` and direct `AgentRuntime` conformers.

5. **Group `AgentConfiguration` parameters** into nested types (`ModelConfiguration`, `ExecutionLimits`, `ObservabilityOptions`) to bring the init from 18 parameters down to 4-5.

---

*This audit evaluates the public API surface only. It does not assess internal implementation quality, test coverage, or runtime performance.*
