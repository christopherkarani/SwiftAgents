# Production Readiness Audit — Swarm Framework

**Date:** 2026-02-22
**Auditor:** Principal Engineer (Automated Deep Review)
**Scope:** Full codebase — Sources, Tests, Build Configuration, Dependencies
**Methodology:** Adversarial static analysis across all subsystems

---

## 1. Executive Summary

### Production Readiness Score: 5.5 / 10

The Swarm framework demonstrates strong architectural vision and solid Swift 6.2 adoption. Protocol-first design, actor isolation, and comprehensive type safety are evident throughout. However, the codebase contains **multiple correctness issues, concurrency hazards, and silent failure paths** that make it unsuitable for production deployment without remediation.

### Top 5 Critical Risks

| # | Risk | Subsystem | Impact |
|---|------|-----------|--------|
| 1 | **Agent cancellation is completely broken** — `currentTask` is never assigned in `Agent` and `ReActAgent`, rendering `cancel()` a no-op | Agents | Users cannot stop runaway agents |
| 2 | **Unbounded parallelism** — No concurrency limits in ReActAgent parallel tool calls, DAGWorkflow root node execution, and ParallelGroup when `maxConcurrency` is nil | Orchestration / Agents | Memory exhaustion, DoS potential |
| 3 | **Silent failure paths everywhere** — Event stream errors logged but not propagated (HiveSwarm), callback errors swallowed (Handoff), tool lookup failures masked with placeholder data | All subsystems | Incorrect results delivered without indication of failure |
| 4 | **`@unchecked Sendable` on type-erased wrappers** — `AnyAgent` and `AgentBox` bypass compiler safety with no runtime enforcement | Core | Latent data races in multi-agent orchestration |
| 5 | **Infinite recursion in PlanAndExecuteAgent** — `skipDependentSteps` recurses without cycle detection; circular plan dependencies crash the process | Agents | Stack overflow crash |

### Release Blockers

1. Broken cancellation mechanism (agents cannot be stopped)
2. Unbounded task creation without concurrency limits
3. `@unchecked Sendable` type erasure without safety invariants
4. Infinite recursion on malformed plan dependencies
5. MCPClient silently discarded when building ReActAgent via DSL

---

## 2. Correctness Issues

### 2.1 Logic Bugs

#### **BLOCKER: Agent cancellation is a no-op**
- **Files:** `Sources/Swarm/Agents/Agent.swift:394`, `Sources/Swarm/Agents/ReActAgent.swift:261`
- `currentTask: Task<Void, Never>?` is declared but **never assigned** during `run()`.
- `cancel()` calls `currentTask?.cancel()`, which always operates on `nil`.
- All agent execution proceeds uncancellable.

#### **BLOCKER: Infinite recursion in `skipDependentSteps`**
- **File:** `Sources/Swarm/Agents/PlanAndExecuteAgent.swift:201-210`
- Recursively calls itself for dependent steps without tracking visited nodes.
- Circular dependencies (step A depends on B, B depends on A) cause stack overflow.
- No depth guard or visited-set protection.

#### **MAJOR: Missing return value in `ToolStep.execute()`**
- **File:** `Sources/Swarm/Tools/ToolChainBuilder.swift:233-238`
- Function declares `-> SendableValue` return type but both branches (`executeWithTimeout`, `executeWithRetry`) don't explicitly return.
- Behavior depends on implicit Swift return semantics; likely produces type mismatch at runtime.

#### **MAJOR: MCPClient silently discarded in ReActAgent builder**
- **File:** `Sources/Swarm/Agents/AgentBuilder.swift:621-651`
- `LegacyAgentBuilder.Components` collects `mcpClient` (line 479, 590-591), but the ReActAgent initializer call at line 621 **never passes it**.
- Code compiles, MCP client is silently dropped. Users configuring MCP integration via the builder get no error.

#### **MAJOR: Unreachable fallback in `ContextProfile.normalizeContextRatios`**
- **File:** `Sources/Swarm/Core/ContextProfile.swift:439-449`
- The `sum <= .ulpOfOne` check comes **after** applying `max(minimumContextRatio, ...)` floor of 0.05.
- Sum is always ≥ 0.15 after flooring, so the fallback branch `(0.55, 0.30, 0.15)` is dead code.
- `NaN` and `Infinity` inputs are not caught, producing `NaN` ratios downstream.

#### **MAJOR: `ContextProfile` init silently overrides user-specified `maxTotalContextTokens`**
- **File:** `Sources/Swarm/Core/ContextProfile.swift:351`
- If user passes `maxTotalContextTokens: 1000` but computed minimum is 2500, the value is silently raised to 2500. No warning, no error.

### 2.2 Race Conditions

#### **MAJOR: ParallelGroup context mutation during execution**
- **File:** `Sources/Swarm/Orchestration/ParallelGroup.swift:530-532`
- `context` property mutated inside `runInternal` without synchronization.
- Concurrent `run()` calls overwrite shared context, causing loss of execution state.

#### **MAJOR: CancellationController fire-and-forget cancellation**
- **File:** `Sources/Swarm/HiveSwarm/HiveBackedAgent.swift:435-445`
- `currentHandle?.outcome.cancel()` does not await completion.
- Back-to-back `.track()` calls leave previous handle in indeterminate state.

#### **MINOR: Brief race window in ResponseTracker eviction**
- **File:** `Sources/Swarm/Core/ResponseTracker.swift:194-223`
- Actor-isolated, but between insertion and LRU eviction, `sessionAccessTimes.count` can briefly exceed `maxSessions`.

### 2.3 Edge Cases Not Handled

| Edge Case | File | Impact |
|-----------|------|--------|
| `maxIterations = 0` | Agent.swift | Immediate failure, no validation |
| Agent hands off to itself | Agent.swift, Handoff.swift | Infinite loop |
| Empty tool list + tool calling mode | Agent.swift:466 | Unclear error message |
| `tokenLimit = 0` on memory query | ConversationMemory.swift | Undefined behavior |
| Embedding dimension mismatch after provider change | VectorMemory.swift:215-226 | Incorrect cosine similarity |
| Empty string token estimation | TokenEstimator.swift:65 | Returns 1 instead of 0 |
| Duplicate memory component IDs in CompositeMemory | MemoryBuilder.swift:230 | Silent masking |

### 2.4 Silent Failure Paths

| Location | What Happens | What Should Happen |
|----------|--------------|--------------------|
| `HiveBackedAgent.swift:190-194` | Event stream errors logged at debug level | Propagate to consumer |
| `Handoff.swift:445-454` | `onHandoff` callback errors swallowed | Fail the handoff or let user decide |
| `SwarmRunner.swift:508-516` | Missing handoff targets silently skipped | Log warning, fail-fast option |
| `EventStreamHooks.swift:50-62` | Missing tool call → placeholder `"unknown"` name | Log warning, propagate context |
| `OrchestrationHiveEngine.swift:344-349` | Checkpoint decoding uses `try?`, swallows error | Return error, not nil |
| `HiveAgents.swift:59-67` | Router channel read failure → silent `.end` | Propagate error to workflow |

---

## 3. Architecture & Design Gaps

### 3.1 Tight Coupling

- **HiveBackedAgent** duplicates error-mapping logic between `run()` and `stream()` methods (lines 129 vs 156-225). The `stream()` path lacks `HiveRuntimeError` catch that `run()` has, producing inconsistent error types for the same failure.
- **Agent and ReActAgent** share substantial implementation patterns (cancellation state, iteration loop, memory retrieval) but don't share a common base abstraction. Changes must be duplicated.

### 3.2 Missing Abstractions

- **No ConcurrencyLimiter abstraction** — Bounded parallelism is reimplemented ad-hoc in ParallelGroup (`maxConcurrency`), but absent in DAGWorkflow and ReActAgent parallel tool calls.
- **No error-mapping protocol** — Each subsystem (Hive, MCP, Orchestration) maps errors differently. A common `ErrorMapper` protocol would ensure consistency.
- **No tool call correlation protocol** — Tool call → result matching is done via dictionary lookups with fallback to synthetic placeholders. A dedicated correlation type would prevent the `"unknown_tool"` problem.

### 3.3 Over-Engineering

- **ContextProfile** is heavily parameterized (15+ configuration points) with complex normalization logic, yet the dead-code fallback branch suggests the complexity isn't fully tested.
- **AgentEvent equality** manually dispatches across all event types with helper methods. A macro-generated `Equatable` or simpler tagged-union design would be less error-prone.

### 3.4 Under-Engineering

- **No DAG validation at build time** — `DAGWorkflow` init captures validation errors but doesn't throw (`Sources/Swarm/Orchestration/DAGWorkflow.swift:132-136`). Errors only surface at `execute()` time. This should be a throwing initializer.
- **No builder completeness checking** — Agent builders accept components but don't validate required fields at build time. Missing inference provider is only caught at runtime.

---

## 4. Concurrency & Safety

### 4.1 Data Races

| Issue | File | Severity |
|-------|------|----------|
| `@unchecked Sendable` on `AnyAgent` and `AgentBox` — wraps potentially non-Sendable agents | `AnyAgent.swift:30,143` | **BLOCKER** |
| `@unchecked Sendable` on `ScriptedStreamingProvider` in tests — masks potential races | Test files | MAJOR |
| Protocol existentials (`any InferenceProvider`) in `Agent.Builder` marked `Sendable` without enforcement | `Agent.swift:905-1114` | MAJOR |
| `InferenceProviderSummarizer` is a struct, not actor — concurrent `summarize()` calls share provider state | `InferenceProviderSummarizer.swift:37` | MAJOR |

### 4.2 Actor Isolation Concerns

- **PlanAndExecuteAgent cancellation state** (`Sources/Swarm/Agents/PlanAndExecuteAgent.swift:579-610`): Checked at iteration boundaries only. Long-running steps cannot be interrupted mid-execution. The `cancellationState` enum adds complexity over simply using `Task.checkCancellation()`.
- **SequentialChain cancellation** (`Sources/Swarm/Orchestration/SequentialChain.swift:227-246`): `isCancelled` flag checked between agent runs, but in-flight agent execution continues uninterrupted.

### 4.3 Unstructured Concurrency Risks

| Pattern | File | Risk |
|---------|------|------|
| Unbounded `TaskGroup.addTask` for all tool calls | `ReActAgent.swift:473-488` | N tasks for N tool calls, no limit |
| Unbounded root node launch in DAG | `DAGWorkflow.swift:249-282` | All independent nodes started simultaneously |
| Fire-and-forget cancellation in CancellationController | `HiveBackedAgent.swift:440` | Resource leak, state pollution |
| `eventsTask` errors not awaited before throw | `HiveBackedAgent.swift:200-206` | Lost error context |

### 4.4 Cancellation Issues

- **Agent.cancel()** and **ReActAgent.cancel()** are no-ops (see §2.1).
- **SequentialChain.cancel()** cancels sub-agents but does not cancel the current `Task` driving the loop.
- **Pipeline.retry()** uses `try? await Task.sleep()` — swallows cancellation silently, immediately starting the next retry instead of propagating `CancellationError`.
- **StreamHelper.makeTrackedStream** — If the operation closure returns without calling `continuation.finish()`, consumers hang indefinitely. No timeout or watchdog mechanism.

---

## 5. Performance Bottlenecks

### 5.1 Quadratic Algorithms

| Algorithm | File | Complexity | Trigger |
|-----------|------|-----------|---------|
| `ConversationMemory.add()` → `removeFirst(count - max)` | `ConversationMemory.swift:57-64` | O(n) per add when at capacity | Long conversations |
| `SlidingWindowMemory.recalibrateTokenCount()` | `SlidingWindowMemory.swift:130-134` | O(n) every 100 ops, O(n²) amortized over time | High message throughput |
| `CompositeMemory` relevance scoring | `MemoryBuilder.swift:449-456` | O(n × m × k): messages × query terms × message length | Semantic memory retrieval |

### 5.2 Unbounded Growth

| Structure | File | Bound | Risk |
|-----------|------|-------|------|
| `VectorMemory.embeddedMessages` | `VectorMemory.swift:55-105` | **None** | Memory exhaustion in long-running RAG apps |
| `HybridMemory.pendingMessages` | `HybridMemory.swift:209` | **None** | Grows indefinitely if summarization fails |
| `InMemoryBackend` storage dict | `InMemoryBackend.swift:26-113` | **None** | Multi-tenant accumulation |
| `CircularBuffer._count` (total appended) | `CircularBuffer.swift:114` | Int.max | Integer overflow after 2^63 appends |

### 5.3 Blocking / Inefficient Patterns

- **Token estimation** uses `text.count / 4` which counts Unicode scalars, not bytes. CJK and emoji text significantly under-counts tokens, leading to context overflow.
- **Retry without backoff** — `Pipeline.retry()` defaults to `delay: .zero`, creating tight spin-loops on transient failures. The `try?` on `Task.sleep` further defeats cancellation-aware backoff.
- **Exponential backoff overflow** — `HiveAgents.swift:717-722`: `delay = UInt64(Double(delay) * factor)` can overflow `UInt64`, wrapping to a small value and creating rapid retries.

---

## 6. Security Risks

### 6.1 Injection Risks

#### **Prompt injection through summarizer**
- **File:** `Sources/Swarm/Memory/InferenceProviderSummarizer.swift:69-78`
- User conversation content is embedded between XML tags (`<text_to_summarize>...</text_to_summarize>`) without escaping.
- If conversation contains `</text_to_summarize><prompt>...`, the summarizer prompt is corrupted.
- **Severity:** MAJOR — LLM prompt injection through user-controlled memory content.

#### **Tool name / argument injection**
- **File:** `Sources/Swarm/HiveSwarm/SwarmToolRegistry.swift:91-99`
- JSON argument parsing provides generic error without logging the payload or validating tool name format.
- **File:** `Sources/Swarm/Orchestration/HandoffBuilder.swift:63-66`
- Tool name override accepts any string without validation (empty, special characters, collisions).

#### **DateTime format string injection**
- **File:** `Sources/Swarm/Tools/BuiltInTools.swift:176`
- DateTimeTool accepts arbitrary user-supplied format strings passed directly to `DateFormatter.dateFormat` without validation or whitelisting.

### 6.2 Information Leakage

- Multiple error messages include raw `error.localizedDescription` which may contain internal state, file paths, or model details.
- Agent logs (`Log.agents.error`) include step details, tool names, and error messages without PII filtering.
- The `swift-log` framework does not support privacy annotations (unlike `os.Logger`), so all interpolated values are logged as-is.
- **WebSearchTool API key exposure** (`Sources/Swarm/Tools/WebSearchTool.swift:109-114`): HTTP error responses logged verbatim — if the Tavily API echoes back the API key in error responses, it leaks into logs.
- **@Tool macro error messages expose type info** (`Sources/SwarmMacros/ToolMacro.swift:481-490`): When a tool return type fails to encode, the error includes `String(describing: type(of: result))`, which could serialize objects containing PII.

### 6.3 Denial of Service Vectors

- **ArithmeticParser unbounded recursion** (`Sources/Swarm/Tools/ArithmeticParser.swift:94-108`): Recursive descent parser has no nesting depth limit. Input like `(((((...(1)...))))))` with 100,000+ levels causes stack overflow.
- **Calculator expression complexity** (`Sources/Swarm/Tools/BuiltInTools.swift:63-80`): Character whitelist validation passes, but no limit on expression length or operator count. Expressions with millions of operators cause quadratic evaluation time.
- **String replace unbounded growth** (`Sources/Swarm/Tools/BuiltInTools.swift:286-294`): Replacing `"a"` with a megabyte string across a large input produces exponential memory growth. No output size validation.
- **No tool execution timeout** (`Sources/Swarm/Tools/Tool.swift:625-695`): `ToolRegistry.execute` has no built-in timeout mechanism. Malicious or buggy tools hang indefinitely.
- **WebSearch query size unlimited** (`Sources/Swarm/Tools/WebSearchTool.swift:85-97`): Query parameter sent to Tavily API with no length validation.

### 6.4 Unsafe Assumptions

- **No input size limits** — Agent `run()` accepts arbitrary-length strings. No maximum input size validation anywhere in the pipeline.
- **No tool argument size limits** — Tool execution accepts arbitrary `SendableValue` arguments without size validation.
- **No session count limits** — `InMemoryBackend` accumulates sessions without bound.
- **Tool type coercion bypasses** (`Sources/Swarm/Tools/Tool.swift:282-380`): `coerceValue` silently converts `"42"` (string) to `42` (int), which could bypass type-based validation in security-sensitive tools.

---

## 7. Testing Review

### 7.1 Coverage Summary

| Subsystem | Estimated Coverage | Risk |
|-----------|--------------------|------|
| Core Types | 80% | Low |
| Memory Systems | 85% | Low |
| Observability/Tracing | 85% | Low |
| Resilience Patterns | 85% | Low |
| Orchestration | 80% | Low |
| Tool Execution | 75% | Medium |
| Agents (Core) | 70% | Medium |
| Guardrails | 75% | Medium |
| DSL/Builders | 70% | Medium |
| Providers | 60% | **High** |
| MCP Integration | 60% | **High** |
| **Overall** | **~75%** | |

### 7.2 Critical Coverage Gaps

#### Missing error-path testing
- No tests for: network timeouts during inference, partial tool execution failures, memory backend failures mid-operation, inference provider disconnection during stream, database corruption recovery.

#### Missing cancellation testing
- Only 2 tests for cancel operations across entire suite.
- No tests for: cancel during tool execution, cancel during memory operations, cancel with pending streams, multiple rapid cancel calls, resource cleanup on cancel.

#### Missing boundary testing
- `maxIterations = 0` never tested
- `tokenLimit = 0` never tested
- Very large messages (1MB+) never tested
- 10,000+ messages in memory never tested
- 100+ simultaneous agents never tested

#### Missing stress/concurrency testing
- Concurrent writes tested with only 50 tasks (should be 1000+).
- No memory pressure tests.
- No stream backpressure tests.
- No actor reentrancy tests.

### 7.3 Flaky Test Patterns

| Pattern | File | Risk |
|---------|------|------|
| `Task.sleep(for: .milliseconds(5))` for ordering | ResponseTrackerTests+ConcurrencyTests.swift:179 | Unreliable on slow CI |
| Variable result acceptance (`count <= 50, count > 0`) | ResponseTrackerTests+ConcurrencyTests.swift:98-101 | Non-deterministic |
| Manual timeout via `awaitTaskResult(..., timeout:)` | AgentReliabilityTests.swift | Tests may hang if helper has bugs |

### 7.4 Mock Fidelity Issues

- `MockInferenceProvider`: No error injection for stream operations, no timeout simulation, no partial response dripping.
- `MockAgentMemory`: Doesn't validate `tokenLimit` impact on `context()` return value.
- **Missing mocks:** `MockSession` (critical gap), `MockPersistentMemoryBackend`, `MockVectorMemory`.

---

## 8. Build Configuration & Dependencies

### 8.1 Package.swift Issues

#### **MAJOR: `HiveSwarmTests` always included**
- **File:** `Package.swift:121-129`
- `HiveSwarmTests` target is always appended to `packageTargets` (outside any conditional). In contrast, demo targets are gated by `SWARM_INCLUDE_DEMO`. If Hive dependency resolution fails, all builds fail — including those that don't need Hive.

#### **MINOR: Broad swift-syntax version range**
- `"600.0.0"..<"603.0.0"` spans 3 major versions. Swift-syntax has breaking API changes between majors. Macro compilation may break on untested versions within this range.

#### **MINOR: Platform minimum is macOS 26 / iOS 26**
- These are unreleased platforms (as of audit date). This means the framework cannot be built or tested on any currently-shipping OS version without Xcode beta toolchains.

### 8.2 Dependency Risk

| Dependency | Source | Risk |
|------------|--------|------|
| `Wax` (0.1.3+) | `christopherkarani/Wax` | Single-maintainer, pre-1.0, no stability guarantees |
| `Conduit` (0.3.1+) | `christopherkarani/Conduit` | Single-maintainer, pre-1.0, no stability guarantees |
| `Hive` (0.1.0+) | `christopherkarani/Hive` | Single-maintainer, pre-1.0, no stability guarantees |
| `swift-syntax` (600+) | `swiftlang/swift-syntax` | Well-maintained, but broad version range risks breakage |
| `swift-log` (1.5.0+) | `apple/swift-log` | Stable, low risk |
| `swift-sdk` (0.10.0+) | `modelcontextprotocol/swift-sdk` | Pre-1.0, actively evolving MCP spec |

Three of six dependencies are authored by the same maintainer. This is a single-bus-factor risk for the entire dependency chain.

---

## 9. Refactoring Opportunities

### 9.1 High-Impact Simplifications

| Opportunity | Current State | Proposed Change | Impact |
|-------------|---------------|-----------------|--------|
| Extract `ConcurrencyLimiter` | Bounded parallelism reimplemented in 3+ places | Shared utility type with configurable limit | Prevents unbounded task creation everywhere |
| Unify agent cancellation | Broken `currentTask` pattern duplicated in Agent + ReActAgent | Use `withTaskCancellationHandler` in `run()` | Fixes cancellation across all agents |
| Throwing `DAGWorkflow.init` | Validation captured but not enforced | `init(...) throws` | Catches graph errors at construction |
| Extract error mapper protocol | Each subsystem maps errors ad-hoc | `protocol ErrorMapper { func map(_ error: Error) -> AgentError }` | Consistent error types across boundaries |
| Replace `removeFirst(n)` with Deque | O(n) array removal in ConversationMemory | Use `Deque` from swift-collections | O(1) eviction |

### 9.2 Naming Improvements

| Current | Suggested | Reason |
|---------|-----------|--------|
| `areSameRuntime(_:_:)` | `runtimesMatch(_:_:)` or remove entirely | Name-based identity comparison is fragile |
| `skipDependentSteps(of:)` | `cascadeSkip(from:visited:)` | Must include visited-set parameter |
| `ToolStep.execute()` → implicit return | Explicit `return try await ...` | Prevents silent type mismatch |

### 9.3 Dead Code Removal

- `ContextProfile.normalizeContextRatios` fallback branch (line 445) is unreachable.
- `Agent.currentTask` and `ReActAgent.currentTask` are declared but never assigned.
- `PlanAndExecuteAgent.CancellationState` enum adds complexity over `Task.isCancelled`.

---

## 10. Consolidated Issue Tracker

### Blockers (Must Fix Before Release)

| # | Issue | File | Line(s) |
|---|-------|------|---------|
| B1 | Agent cancellation no-op (`currentTask` never assigned) | Agent.swift, ReActAgent.swift | 394, 261 |
| B2 | Infinite recursion in `skipDependentSteps` (no cycle detection) | PlanAndExecuteAgent.swift | 201-210 |
| B3 | `@unchecked Sendable` on `AnyAgent`/`AgentBox` (no runtime safety) | AnyAgent.swift | 30, 143 |
| B4 | Unbounded parallel tool execution (no concurrency limit) | ReActAgent.swift | 473-488 |
| B5 | MCPClient silently discarded in ReActAgent builder | AgentBuilder.swift | 621-651 |

### Major Issues (Fix Before GA)

| # | Issue | File | Line(s) |
|---|-------|------|---------|
| M1 | StreamHelper hangs if operation doesn't call `finish()` | StreamHelper.swift | 51-107 |
| M2 | ParallelGroup context race condition | ParallelGroup.swift | 530-532 |
| M3 | No cancellation propagation in SequentialChain | SequentialChain.swift | 227-246 |
| M4 | VectorMemory unbounded embedding storage | VectorMemory.swift | 55-105 |
| M5 | HybridMemory unbounded pending queue | HybridMemory.swift | 209, 229-254 |
| M6 | Event stream errors silenced in HiveBackedAgent | HiveBackedAgent.swift | 190-194 |
| M7 | Synthetic `"unknown_tool"` on mismatched tool correlation | HiveBackedAgent.swift | 329-363 |
| M8 | NaN/Infinity not caught in ContextProfile normalization | ContextProfile.swift | 439-449 |
| M9 | `stopOnToolError` ignored in parallel execution path | ReActAgent.swift | 484 |
| M10 | DAG validation deferred to runtime instead of init | DAGWorkflow.swift | 132-136 |
| M11 | Pipeline retry swallows `CancellationError` via `try?` | Pipeline.swift | 241 |
| M12 | Prompt injection via summarizer XML tag escape | InferenceProviderSummarizer.swift | 69-78 |
| M13 | `InferenceProviderSummarizer` not actor-isolated | InferenceProviderSummarizer.swift | 37 |
| M14 | Missing return in ToolStep.execute() | ToolChainBuilder.swift | 233-238 |
| M15 | Unbounded DAG root node parallelism | DAGWorkflow.swift | 249-282 |
| M16 | Token estimation inaccuracy for non-English text | TokenEstimator.swift | 50-67 |
| M17 | Partial batch save without rollback in SwiftDataBackend | SwiftDataBackend.swift | 99-129 |
| M18 | `HiveSwarmTests` unconditionally included in package | Package.swift | 121-129 |
| M19 | No input size validation on agent `run()` | Agent.swift, ReActAgent.swift | Entry points |
| M20 | Handoff callback errors silently swallowed | Handoff.swift | 445-454 |
| M21 | ArithmeticParser stack overflow (no depth limit) | ArithmeticParser.swift | 94-108 |
| M22 | No tool execution timeout in ToolRegistry | Tool.swift | 625-695 |
| M23 | WebSearchTool API key exposure in error messages | WebSearchTool.swift | 109-114 |

### Minor Issues

| # | Issue | File | Line(s) |
|---|-------|------|---------|
| m1 | `CircularBuffer._count` overflow after 2^63 appends | CircularBuffer.swift | 114 |
| m2 | `AgentResult.Builder.build()` no validation of `start()` call | AgentResult.swift | 225-245 |
| m3 | `AgentEvent` equality requires manual update for new cases | AgentEvent.swift | 318-391 |
| m4 | `ModelSettings.validate()` is per-field only, no cross-field | ModelSettings.swift | 254-302 |
| m5 | Tool name override accepts invalid strings | HandoffBuilder.swift | 63-66 |
| m6 | `PersistedSession.itemCount` returns 0 on backend error | PersistentSession.swift | 79-89 |
| m7 | `areSameRuntime` uses fragile name+type comparison | AgentRouter.swift | 808-814 |
| m8 | Exponential backoff overflow in HiveAgents retry | HiveAgents.swift | 717-722 |
| m9 | `SendableValue` Double-to-Int uses JavaScript safe range, not Swift | SendableValue.swift | 326-332 |
| m10 | Guardrails accumulate silently in builder (unlike other components) | AgentBuilder.swift | 574-577 |
| m11 | Empty ToolChain not caught at init, only at execute | ToolChainBuilder.swift | 509-510 |
| m12 | Checkpoint decoding uses `try?` swallowing errors | OrchestrationHiveEngine.swift | 344-349 |
| m13 | Timing-dependent tests risk CI flakiness | ResponseTrackerTests | 98-101, 179 |
| m14 | Calculator expression complexity DoS (no length/depth limit) | BuiltInTools.swift | 63-80 |
| m15 | String replace unbounded output growth | BuiltInTools.swift | 286-294 |
| m16 | Tool type coercion silently converts string to int | Tool.swift | 282-380 |
| m17 | Tool name collision possible in @Tool macro | ToolMacro.swift | 159-168 |

---

## 11. Recommendations by Priority

### Immediate (Pre-Release)

1. **Fix cancellation** — Assign `currentTask` in `run()` or switch to `withTaskCancellationHandler`.
2. **Add cycle detection** to `skipDependentSteps` with a `Set<UUID>` visited parameter.
3. **Add `& Sendable` constraint** to `AnyAgent` generic parameter or add runtime validation.
4. **Implement `ConcurrencyLimiter`** and apply to all `TaskGroup.addTask` sites.
5. **Pass MCPClient through** in `AgentBuilder` ReActAgent construction path.

### Short-Term (First Patch)

6. Auto-call `continuation.finish()` in `StreamHelper` if operation returns without finishing.
7. Make `DAGWorkflow.init` throwing.
8. Escape XML tags in summarizer prompts.
9. Add bounds to `VectorMemory` and `HybridMemory.pendingMessages`.
10. Unify error mapping between `run()` and `stream()` in `HiveBackedAgent`.

### Medium-Term (Next Release)

11. Replace `Array.removeFirst(n)` with `Deque` in memory systems.
12. Add input size validation at agent entry points.
13. Expand test coverage: error paths, cancellation, stress tests, boundary conditions.
14. Replace timing-dependent tests with synchronization primitives.
15. Add cross-field validation to `ModelSettings`.

---

*End of audit. All findings are based on static analysis of the source code. Runtime verification is recommended to confirm behavioral findings.*
