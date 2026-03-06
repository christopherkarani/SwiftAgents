# API Improvement Report
Generated: 2026-03-04 | Framework: Swarm | Branch: finalPhase

## Executive Summary
- Current public surface: 361 types, 2603 members (from `swift package dump-symbol-graph --minimum-access-level public --skip-synthesized-members`).
- Proposed after changes (estimated): 320 types, 2270 members (reduction: ~12.8%).
- Top 5 highest-impact changes:
1. Hide `AnyJSONTool` from public entry points and expose a typed tool-first surface.
2. Collapse `Agent` construction to a strict 3-tier progressive disclosure model.
3. Make `Workflow.parallel` merge ordering deterministic by preserving submission index.
4. Complete `AnyAgent` forwarding so `runWithResponse` behavior is not silently downgraded.
5. Unify guardrail observability between sequential and parallel execution paths.

## DX Scorecard
| Category | Current H | Current A | Current DX | Proposed DX |
|----------|-----------|-----------|------------|-------------|
| Entry points & construction | 3.6 | 3.1 | 3.2 | 4.3 |
| Tools & handoffs | 3.2 | 2.6 | 2.7 | 4.4 |
| Workflow composition | 3.4 | 2.8 | 2.9 | 4.2 |
| Configuration ergonomics | 2.9 | 2.4 | 2.5 | 3.9 |
| Guardrails & observability | 3.1 | 2.7 | 2.8 | 4.0 |
| Utility/legacy surfaces | 2.2 | 2.0 | 2.0 | 3.6 |

## Findings (sorted by impact)

### Finding 1: Low-level tool ABI leaks into the front-facing API
- **Category**: 3I (Leaky Abstraction) + 3C (`some`/`any` simplification)
- **Current DX**: H=4, A=5, Combined=4.8
- **Impact**: High
- **Files**: `Sources/Swarm/Tools/Tool.swift:32`, `Sources/Swarm/Core/AgentRuntime.swift:39`, `Sources/Swarm/Agents/Agent.swift:81`
- **Current API**:
```swift
public protocol AnyJSONTool: Sendable { ... }
nonisolated var tools: [any AnyJSONTool] { get }
public init(tools: [any AnyJSONTool] = [], ...)
```
- **Proposed API**:
```swift
public protocol Tool: Sendable { ... }
nonisolated var tools: [any Tool] { get }
public init(tools: [some Tool] = [], ...)
// AnyJSONTool becomes SPI/internal adapter boundary only.
```
- **Rationale**: The JSON boundary type is implementation detail and directly pollutes autocomplete/discovery.
- **Lock Check**: Decision touched = “Internal type hiding”; Compatible = Yes; Evidence = `docs/plans/2026-03-02-swarm-api-redesign.md` (locked decision: hide `AnyJSONTool`).
- **Breaking**: Yes; migration = provide bridging overloads + deprecate existential JSON overloads for one release.
- **Swift 6.2 Feature Used**: `some` parameters + constrained protocols.

### Finding 2: Agent construction has too many overlapping entry paths
- **Category**: 3G (Progressive Disclosure)
- **Current DX**: H=4, A=4, Combined=4.0
- **Impact**: High
- **Files**: `Sources/Swarm/Agents/Agent.swift:80`, `:111`, `:150`, `:203`, `:1426`, `:1470`, `:1532`
- **Current API**:
```swift
init(tools: [any AnyJSONTool] = [], ...)
init(_ inferenceProvider: any InferenceProvider, ...)
init(tools: [some Tool] = [], ...)
init(..., handoffAgents: [any AgentRuntime])
init(name: String, ...)
init(@AgentBuilder ...)
```
- **Proposed API**:
```swift
// Tier 1
init(_ provider: some InferenceProvider)
// Tier 2
init(tools: [some Tool] = [], instructions: String = "", configuration: AgentConfiguration = .default, ...)
// Tier 3
init(@AgentBuilder _ content: () -> AgentBuilder.Components)
```
- **Rationale**: Multiple near-equivalent inits degrade first-try correctness for agents and humans.
- **Lock Check**: Decision touched = “Agent escape hatch remains”; Compatible = Yes.
- **Breaking**: No (deprecate extra paths first), eventual Yes (cleanup major release).
- **Swift 6.2 Feature Used**: progressive disclosure + parameter packs retained on handoffs.

### Finding 3: `Workflow.parallel` indexing is completion-ordered, not submission-ordered
- **Category**: 3E (Type-safe variadic/parallel composition semantics)
- **Current DX**: H=4, A=4, Combined=4.0
- **Impact**: High
- **Files**: `Sources/Swarm/Workflow/Workflow.swift:161`, `:168`, `:216`
- **Current API**:
```swift
for try await result in group { collected.append(result) }
let dict = results.enumerated().reduce(into: [String: String]()) { ... }
```
- **Proposed API**:
```swift
group.addTask { (index, try await agent.run(...)) }
for try await (index, result) in group { collected[index] = result }
```
- **Rationale**: `.structured` and `.indexed` imply stable positional meaning; current ordering is nondeterministic.
- **Lock Check**: Decision touched = workflow fluent core; Compatible = Yes.
- **Breaking**: Behavioral change (non-source-breaking), should be documented.
- **Swift 6.2 Feature Used**: structured concurrency with typed tuple aggregation.

### Finding 4: `AnyAgent` does not forward `runWithResponse`
- **Category**: 3C (`some`/`any` protocol simplification correctness)
- **Current DX**: H=4, A=4, Combined=4.0
- **Impact**: High
- **Files**: `Sources/Swarm/Core/AgentRuntime.swift:108`, `Sources/Swarm/Core/AnyAgent.swift:95`, `:122-137`
- **Current API**:
```swift
public struct AnyAgent: AgentRuntime { ... run/stream/cancel ... }
// runWithResponse missing in AnyAgentBox forwarding surface.
```
- **Proposed API**:
```swift
private protocol AnyAgentBox {
    func runWithResponse(...) async throws -> AgentResponse
}
public func runWithResponse(...) async throws -> AgentResponse {
    try await box.runWithResponse(...)
}
```
- **Rationale**: Type erasure currently downgrades specialized runtime behavior to default extension behavior.
- **Lock Check**: Decision touched = response tracking API; Compatible = Yes.
- **Breaking**: No.
- **Swift 6.2 Feature Used**: protocol forwarding completeness under existential boxing.

### Finding 5: Guardrail observer behavior differs between sequential and parallel modes
- **Category**: 3C (Behavioral consistency)
- **Current DX**: H=4, A=3, Combined=3.2
- **Impact**: Medium
- **Files**: `Sources/Swarm/Guardrails/GuardrailRunner.swift:336`, `:394`, `:452`, `:512`, `:556`, `:614`, `:677`, `:738`
- **Current API**:
```swift
// Sequential paths emit `emitGuardrailEvent(...)`.
// Parallel paths never call `emitGuardrailEvent(...)`.
```
- **Proposed API**:
```swift
// In each parallel collector branch:
if executionResult.result.tripwireTriggered {
    await emitGuardrailEvent(...)
}
```
- **Rationale**: Observability should not depend on execution mode.
- **Lock Check**: Decision touched = AgentObserver-first hooks; Compatible = Yes.
- **Breaking**: No.
- **Swift 6.2 Feature Used**: actor-isolated event emission from task-group result collection.

### Finding 6: Public `AgentComponent` appears extensible but unknown conformances are dropped in release
- **Category**: 3A (Access control tightening) + 3I (Copy-paste protocol / zombie extensibility)
- **Current DX**: H=3, A=4, Combined=3.8
- **Impact**: Medium
- **Files**: `Sources/Swarm/Agents/AgentBuilder.swift:13`, `:552`, `:593-603`
- **Current API**:
```swift
public protocol AgentComponent {}
default:
    assertionFailure("unknown AgentComponent")
```
- **Proposed API**:
```swift
// Option A: seal protocol internally; expose only built-in components.
// Option B: throw/precondition on unknown component in all build modes.
```
- **Rationale**: Public marker protocol implies supported external conformance, but runtime ignores unknown components outside debug.
- **Lock Check**: Decision touched = DSL remains available; Compatible = Yes.
- **Breaking**: Possibly (for third-party custom conformers).
- **Swift 6.2 Feature Used**: access control + explicit closed-world DSL modeling.

### Finding 7: Configuration APIs overuse boolean toggles and optional booleans
- **Category**: 3F (Enum-based configuration)
- **Current DX**: H=3, A=3, Combined=3.0
- **Impact**: Medium
- **Files**: `Sources/Swarm/Guardrails/GuardrailRunner.swift:45`, `:50`, `:69`; `Sources/Swarm/Core/AgentConfiguration.swift:205`, `:211`, `:215`, `:219`, `:249`, `:267`, `:278`; `Sources/Swarm/Core/AgentConfiguration.swift:36-37`
- **Current API**:
```swift
init(runInParallel: Bool = false, stopOnFirstTripwire: Bool = true)
var enableStreaming: Bool
var includeToolCallDetails: Bool
var stopOnToolError: Bool
var includeReasoning: Bool
var parallelToolCalls: Bool
var autoPreviousResponseId: Bool
var defaultTracingEnabled: Bool
```
- **Proposed API**:
```swift
enum GuardrailExecutionMode { case sequential, parallel }
enum TripwirePolicy { case failFast, collectAll }
enum TracingMode { case automatic, disabled }
```
- **Rationale**: Booleans scale poorly and reduce intent discoverability.
- **Lock Check**: Decision touched = no lock conflict.
- **Breaking**: No (add enum alternatives first, deprecate bools later).
- **Swift 6.2 Feature Used**: enum-based options and strong typing.

### Finding 8: Public `@unchecked Sendable` weakens concurrency guarantees in core workflow/result APIs
- **Category**: 3I (Code smell: overuse of unchecked Sendable)
- **Current DX**: H=3, A=3, Combined=3.0
- **Impact**: Medium
- **Files**: `Sources/Swarm/Workflow/Workflow.swift:5`, `:12`; `Sources/Swarm/Core/AgentResult.swift:117`
- **Current API**:
```swift
enum Step: @unchecked Sendable { ... }
public enum MergeStrategy: @unchecked Sendable { ... }
final class Builder: @unchecked Sendable { ... }
```
- **Proposed API**:
```swift
// Replace unchecked enums/closures with explicit Sendable wrappers.
// Consider `actor AgentResultBuilder` or `ManagedCriticalState` wrapper.
```
- **Rationale**: `@unchecked Sendable` in public contracts makes thread-safety assumptions opaque to consumers.
- **Lock Check**: Decision touched = strict-concurrency posture; Compatible = Yes.
- **Breaking**: Potentially (if builder type changes shape).
- **Swift 6.2 Feature Used**: strict Sendable modeling with actor isolation.

### Finding 9: Public platform constants in `Swarm` are stale relative to package platform requirements
- **Category**: 3H (Naming/discoverability correctness)
- **Current DX**: H=3, A=3, Combined=3.0
- **Impact**: Medium
- **Files**: `Sources/Swarm/Swarm.swift:55`, `:58`; `Package.swift:205-207`
- **Current API**:
```swift
public static let minimumMacOSVersion = "15.0"
public static let minimumiOSVersion = "17.0"
// Package.swift requires macOS/iOS/tvOS v26.
```
- **Proposed API**:
```swift
@available(*, deprecated, message: "Use package platform constraints")
public static let minimumMacOSVersion = ...
```
- **Rationale**: Public constants that drift from actual build constraints mislead users and coding agents.
- **Lock Check**: Decision touched = none.
- **Breaking**: No (deprecation first).
- **Swift 6.2 Feature Used**: deprecation/migration annotations.

### Finding 10: Legacy aliases and stale examples increase API noise
- **Category**: 3A (Access tightening) + 3H (discoverability)
- **Current DX**: H=2, A=3, Combined=2.8
- **Impact**: Medium
- **Files**: `Sources/Swarm/Agents/RelayAgent.swift:9`; `Sources/Swarm/Core/AgentConfiguration.swift:24-29`; `Sources/Swarm/Core/AnyAgent.swift:16-19`
- **Current API**:
```swift
public typealias RelayAgent = Agent
@available(*, deprecated, renamed: "hive") case swift
@available(*, deprecated, renamed: "hive") case requireHive
```
- **Proposed API**:
```swift
// Keep aliases deprecated but out of primary docs/autocomplete guidance.
// Remove stale examples referencing removed agent families.
```
- **Rationale**: Compatibility is useful, but these names should not compete with primary API discovery.
- **Lock Check**: Decision touched = preserve compatibility aliases; Compatible = Yes (documentation focus).
- **Breaking**: No.
- **Swift 6.2 Feature Used**: staged deprecation.

## Priority Matrix
| Priority | Human Impact | Agent Impact | Effort |
|----------|-------------|-------------|--------|
| P0 | Tool API clarity and correctness | Very high | Medium |
| P0 | Deterministic workflow parallel semantics | Very high | Very high | Small |
| P0 | AnyAgent response-forwarding correctness | High | High | Small |
| P1 | Construction path reduction for Agent | High | High | Medium |
| P1 | Guardrail observability parity | Medium | High | Small |
| P1 | Seal/fix AgentComponent extension trap | Medium | High | Medium |
| P2 | Enum-based config replacements | Medium | Medium | Medium |
| P2 | Remove public unchecked Sendable hot spots | Medium | Medium | Medium/High |
| P2 | Platform constant drift cleanup | Medium | Medium | Small |
| P3 | Legacy alias/document cleanup | Low/Medium | Medium | Small |

## Implementation Recommendations

### Quick wins (<1 hour each)
1. Deterministic `Workflow.parallel` result ordering.
- Files: `Sources/Swarm/Workflow/Workflow.swift`
- Breaking: No
- Incremental: Yes
- Tests: add regression in `Tests/SwarmTests/Workflow/*` for stable `.structured`/`.indexed` ordering.

2. `AnyAgent` forwards `runWithResponse`.
- Files: `Sources/Swarm/Core/AnyAgent.swift`
- Breaking: No
- Incremental: Yes
- Tests: add case in `Tests/SwarmTests/Core/*` asserting wrapped runtime-specific response behavior.

3. Guardrail event parity in parallel mode.
- Files: `Sources/Swarm/Guardrails/GuardrailRunner.swift`, observer tests under `Tests/SwarmTests/Guardrails/*` or `Core/AgentObserverTests.swift`
- Breaking: No
- Incremental: Yes
- Tests: parallel and sequential should emit equivalent tripwire callbacks.

### Medium lifts (1-4 hours)
1. Reduce Agent construction overloads via staged deprecations.
- Files: `Sources/Swarm/Agents/Agent.swift`, `docs/reference/front-facing-api.md`
- Breaking: No in phase 1, potential Yes later.
- Incremental: Yes (deprecations first).
- Tests: API compile tests + migration compile fixtures.

2. Seal `AgentComponent` or fail-fast unknown conformances.
- Files: `Sources/Swarm/Agents/AgentBuilder.swift`
- Breaking: Possibly.
- Incremental: Yes, with runtime warning path first.
- Tests: explicit unknown component behavior test.

3. Enum-first replacements for bool-heavy configuration.
- Files: `Sources/Swarm/Core/AgentConfiguration.swift`, `Sources/Swarm/Guardrails/GuardrailRunner.swift`
- Breaking: No if additive.
- Incremental: Yes.
- Tests: default equivalence tests between old bool paths and new enum paths.

### Strategic changes (4+ hours)
1. Hide `AnyJSONTool` from public API and provide typed top-level tool contracts.
- Files: `Sources/Swarm/Tools/Tool.swift`, `Sources/Swarm/Core/AgentRuntime.swift`, `Sources/Swarm/Agents/Agent.swift`, adapter files under `Sources/Swarm/Tools/*`
- Breaking: Yes (multi-release migration recommended).
- Incremental: Yes (bridging period).
- Tests: expand `Tests/SwarmTests/APIAuditTests.swift` and typed tool compile-usage tests.

2. Remove `@unchecked Sendable` from public workflow/result surfaces.
- Files: `Sources/Swarm/Workflow/Workflow.swift`, `Sources/Swarm/Core/AgentResult.swift`
- Breaking: Potentially.
- Incremental: Partially.
- Tests: concurrency and Sendable compile checks + stress tests.

3. Public API hygiene pass for stale constants/aliases/docs.
- Files: `Sources/Swarm/Swarm.swift`, `Sources/Swarm/Agents/RelayAgent.swift`, `Sources/Swarm/Core/AnyAgent.swift`, `docs/reference/front-facing-api.md`
- Breaking: No (deprecate + docs first).
- Incremental: Yes.
- Tests: doc-linked API snippets compile tests.
