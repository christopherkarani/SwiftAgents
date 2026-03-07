# Production Readiness Audit — Swarm Framework

**Date:** 2026-03-07
**Auditor:** Principal Engineer (Deep Adversarial Review)
**Scope:** Full codebase — Sources (200 files), Tests (161 files), Build Configuration, Dependencies
**Methodology:** Multi-pass adversarial analysis: architecture, concurrency, security, correctness, performance, testing

---

## 1. Executive Summary

### Production Readiness Score: 6.0 / 10

The Swarm framework demonstrates **strong architectural foundations** with excellent protocol-first design, comprehensive actor isolation, and modern Swift 6.2 concurrency adoption. The codebase has improved since the prior audit (Feb 2026), with `AnyAgent` now correctly `Sendable` (not `@unchecked`) and broader test coverage. However, **critical correctness issues, concurrency hazards, and security gaps** remain that make production deployment risky without remediation.

### Top 5 Critical Risks

| # | Risk | Subsystem | Impact |
|---|------|-----------|--------|
| 1 | **`@unchecked Sendable` Builders with NSLock** — `AgentResult.Builder` and `TraceEvent.Builder` bypass compiler safety using manual locking, risking deadlocks with async code | Core / Observability | Deadlocks, data races in concurrent result building |
| 2 | **Silent tool result loss** — `runWithResponse()` silently drops orphaned tool results via `compactMap`, and crashes on duplicate tool call IDs via `Dictionary(uniqueKeysWithValues:)` | Core | Data loss, runtime crashes |
| 3 | **Unprotected infinite loops** — MCP client name deduplication, retry policies, and arithmetic parser loops lack timeout guards | MCP / Resilience | DoS vulnerability, resource exhaustion |
| 4 | **Tool argument normalization has no depth limit** — Recursive descent into nested objects can trigger stack overflow | Tools | Stack exhaustion, potential crash |
| 5 | **HiveBackedAgent stream race** — Race between `handle.outcome.value` completing and `handle.events` being fully consumed causes lost events | HiveSwarm | Incomplete observability, client hangs |

### Release Blockers

1. `@unchecked Sendable` builders must be converted to actors or use proper synchronization
2. `Dictionary(uniqueKeysWithValues:)` crash on duplicate tool call IDs — must validate uniqueness
3. Infinite loop vectors in MCP client and retry paths — must add timeout guards
4. Recursive tool argument normalization without depth limit — must cap recursion

---

## 2. Correctness Issues

### 2.1 BLOCKER: Runtime Crash on Duplicate Tool Call IDs

**File:** `Sources/Swarm/Core/AgentRuntime.swift:179`

`Dictionary(uniqueKeysWithValues:)` will **fatal error** at runtime if any duplicate `ToolCall.id` values exist in `result.toolCalls`. No validation occurs before construction. A malformed inference provider response crashes the entire process.

```swift
// CRASHES if any toolCall.id is duplicated
let toolCallDict = Dictionary(uniqueKeysWithValues: result.toolCalls.map { ($0.id, $0) })
```

**Remediation:** Use `Dictionary(grouping:by:)` with duplicate detection, or `reduce(into:)`.

### 2.2 BLOCKER: Silent Tool Result Data Loss

**File:** `Sources/Swarm/Core/AgentRuntime.swift:182-196`

When converting `ToolResults` to `ToolCallRecords`, orphaned results (those without matching tool calls) are silently discarded via `compactMap`. A tool can execute successfully but its result vanishes from the response with only a warning log.

**Impact:** Clients using `runWithResponse()` receive incomplete execution histories. Silent data loss breaks auditability.

### 2.3 MAJOR: Silent Error Swallowing in Plan Parsing

**File:** `Sources/Swarm/Agents/PlanAndExecuteAgent+Planning.swift:104`

```swift
guard let planResponse = try? decoder.decode(PlanResponse.self, from: jsonData) else { return nil }
```

The actual JSON decoding error is completely discarded. When plan parsing fails in production, operators have zero diagnostic information. There are **30+ instances of `try?`** across the Sources directory, many of which similarly swallow diagnostic errors.

### 2.4 MAJOR: Stream Finish Gaps

**File:** `Sources/Swarm/Core/StreamOperations.swift:140`, `Sources/Swarm/Agents/Agent.swift:295`

The `retry()` stream factory can silently fall through after the while loop exits without finishing the stream. If `maxAttempts` exhausts and the error accumulation path breaks, the stream never finishes and consumers hang indefinitely.

### 2.5 MAJOR: Agent Loop Spin on Empty Tool Calls

**File:** `Sources/Swarm/Agents/Agent.swift:523-622`

If an inference provider returns `hasToolCalls=true` but an empty `toolCalls` array, the agent loop continues without progress, spinning until `maxIterations`. No guard validates that tool calls are actually present.

### 2.6 MINOR: Configuration Validation is Non-Enforcing

**File:** `Sources/Swarm/Core/AgentConfiguration.swift:98-103, 326-338`

Invalid configuration values (temperature outside [0.0, 2.0], timeout <= 0, tokenBudget <= 0) trigger warnings but silently coerce to defaults. Misconfigurations become invisible.

---

## 3. Architecture & Design Gaps

### 3.1 Stub Files in Production Source Tree

**Files:**
- `Sources/Swarm/Observability/Tracing.swift` — "To be implemented in Phase 5: Observability"
- `Sources/Swarm/Integration/Integration.swift` — "To be implemented in Phase 7: Integrations"
- `Sources/Swarm/Extensions/Extensions.swift` — "To be implemented as needed"

**Severity:** Minor — but these stub files ship in the library, pollute the module namespace, and signal incomplete implementation to consumers.

### 3.2 Incomplete Membrane Integration

**File:** `Sources/Swarm/Integration/Membrane/MembraneAgentAdapter.swift`

Contains **5 TODO comments** for features blocked on `MembraneHive` shipping `MembraneCheckpointAdapter`. The adapter has significant dead code paths guarded by comments. This integration is not production-ready.

### 3.3 Three DSL Generations Create Confusion

The codebase maintains three DSL layers (`AgentLoopDefinition` [deprecated], `AgentBlueprint` [current], `Orchestration` struct). While `AgentLoopDefinition` is marked deprecated, it's still actively maintained with tests. This creates maintenance burden and API surface confusion.

### 3.4 Handoff Input Filter Cannot Reject

**File:** `Sources/Swarm/Orchestration/HandoffConfiguration.swift:131`

```swift
public typealias InputFilterCallback = @Sendable (HandoffInputData) -> HandoffInputData
```

The callback is synchronous and cannot throw. A filter that needs to reject a handoff has no mechanism to signal failure — it can only mutate metadata. This is a silent failure pattern that prevents proper validation gates.

### 3.5 Branch Dependency on `main` for Membrane

**File:** `Package.swift:68`

```swift
.package(url: "...", .branch("main"))
```

Membrane depends on a branch reference (`main`), not a tagged release. This means builds are non-reproducible and subject to upstream breaking changes at any time.

---

## 4. Concurrency & Safety

### 4.1 BLOCKER: `@unchecked Sendable` Builders with NSLock

**Files:**
- `Sources/Swarm/Core/AgentResult.swift:117` — `AgentResult.Builder`
- `Sources/Swarm/Observability/TraceEvent.swift:218` — `TraceEvent.Builder`

Both use `final class: @unchecked Sendable` with manual `NSLock` synchronization. This is a **deadlock hazard**:
- NSLock can deadlock if acquired from an async context that already holds any lock
- No protection against reentrant calls
- Violates Swift's structured concurrency model

**Remediation:** Convert to actors.

### 4.2 MAJOR: Task Cancellation Race in Agent.run()

**Files:**
- `Sources/Swarm/Agents/Agent.swift:246-272`
- `Sources/Swarm/Agents/ReActAgent.swift:139-165`

```swift
let task = Task { [self] in
    try await runInternal(input, session: session, hooks: hooks)
}
currentTask = task      // Race window: cancel() between Task creation and assignment
currentRunID = runID
```

If `cancel()` is called between `Task {}` creation and `currentTask = task` assignment, the handle is lost and cannot be cancelled. Orphaned tasks continue executing indefinitely.

### 4.3 MAJOR: HiveBackedAgent Stream Race Condition

**File:** `Sources/Swarm/HiveSwarm/HiveBackedAgent.swift:199-222`

There's an inherent race between `handle.outcome.value` completing and `handle.events` stream being fully consumed. If the outcome completes first, events may be lost. The continuation is only closed after awaiting `eventsTask.value`, but by then the stream consumer may have abandoned iteration.

### 4.4 MAJOR: Unstructured Task in MultiProvider.stream()

**File:** `Sources/Swarm/Providers/MultiProvider.swift:178-194`

Uses manual `Task {}` creation with `onTermination` handler instead of `StreamHelper.makeTrackedStream()`. If the stream consumer disappears before task completion, the task becomes orphaned.

### 4.5 MINOR: Unnecessary `@unchecked Sendable` Wrappers

**Files:**
- `Sources/Swarm/Orchestration/AgentRouter.swift:10-12` — `SendableRegex<Output>`
- `Sources/Swarm/DSL/Core/Environment.swift:31` — `SendableKeyPath`
- `Sources/Swarm/DSL/Modifiers/EnvironmentAgent.swift:74` — `SendableWritableKeyPath`

`Regex<Output>` and `KeyPath` are `Sendable` in Swift 6.2. These wrappers are unnecessary and misleading.

### 4.6 Inventory: `@unchecked Sendable` Usage

| Location | Type | Risk |
|----------|------|------|
| `AgentResult.Builder` | NSLock-based class | **HIGH** — deadlock risk |
| `TraceEvent.Builder` | NSLock-based class | **HIGH** — deadlock risk |
| `SendableRegex` | Wrapper | LOW — unnecessary but harmless |
| `SendableKeyPath` | Wrapper | LOW — unnecessary but harmless |
| `SendableWritableKeyPath` | Wrapper | LOW — unnecessary but harmless |
| 8+ test-only classes | Test mocks | Acceptable for testing |

### 4.7 Concurrency Strengths

- All memory implementations (`ConversationMemory`, `VectorMemory`, `SummaryMemory`, `SlidingWindowMemory`, `PersistentMemory`) are properly `actor`-isolated
- `ParallelToolExecutor` correctly uses `withThrowingTaskGroup` with cancellation propagation
- `CircuitBreaker` and `RateLimiter` are properly actor-isolated
- `StreamHelper` provides good default stream creation patterns
- `Tracer` protocol requires `Actor` conformance — correct design

---

## 5. Performance Bottlenecks

### 5.1 MAJOR: DAG Cycle Detection is O(n^2)

**File:** `Sources/Swarm/Orchestration/DAGWorkflow.swift:181-189`

When a cycle is detected, the code rebuilds a `Set` from sorted names and then filters the full node array. For a 1000-node DAG, this performs ~1,000,000 operations. Use Tarjan's algorithm for O(n+e) cycle detection.

### 5.2 MAJOR: MetricsSnapshot Percentile Computation Sorts Repeatedly

**File:** `Sources/Swarm/Observability/MetricsCollector.swift:125-138`

`p95ExecutionDuration` and `p99ExecutionDuration` each independently sort the entire `executionDurations` array. With 10,000 samples, this is two O(n log n) sorts per snapshot. Same array, sorted twice.

**Remediation:** Cache sorted array or compute both percentiles in a single pass.

### 5.3 MINOR: Pipeline Nested Closures Create O(n) Memory Chain

**File:** `Sources/Swarm/Orchestration/Pipeline.swift:32-60`

Each `>>>` operator creates a new closure capturing the previous one. A 100-step pipeline creates a 100-deep closure chain. Measurable overhead above ~50 steps.

### 5.4 MINOR: ParallelGroup JSON Round-Trip

**File:** `Sources/Swarm/Orchestration/ParallelGroup.swift:277-282`

Structured merge strategy builds a JSON dictionary, serializes to `Data`, then converts to `String`. Unnecessary intermediate allocation.

### 5.5 Performance Strengths

- `CircularBuffer` used correctly for bounded metric storage — prevents unbounded memory growth
- `MetricsCollector` uses `maxMetricsHistory` cap (default 10,000)
- `TokenEstimator` uses byte-level estimation without regex — efficient

---

## 6. Security Risks

### 6.1 HIGH: Path Traversal Bypass in HTTPMCPServer

**File:** `Sources/Swarm/MCP/HTTPMCPServer.swift:210-231`

The `readResource(uri:)` method checks for path traversal with a simple string literal match:

```swift
guard !uri.contains("..") else {
    throw MCPError.invalidParams("Path traversal not allowed")
}
```

This is **bypassable via URL encoding** (`%2E%2E`), double encoding (`%252E%252E`), or Unicode normalization. Additionally, `file://` URI validation only checks the prefix — no allowlist of accessible directories, no symlink resolution.

**Remediation:** Use Swift's `URL` path component API, resolve canonical paths with `realpath(3)`, implement an allowlist of accessible directories.

### 6.2 HIGH: Error Information Disclosure Across Multiple Subsystems

**Files:**
- `Sources/Swarm/MCP/MCPClient.swift:510-523` — leaks server names and error conditions in aggregated errors
- `Sources/Swarm/Providers/OpenRouter/OpenRouterProvider.swift:100-102` — exposes raw HTTP response body (500 chars) in thrown errors

```swift
// OpenRouter: raw response leaked in error message
throw AgentError.generationFailed(
    reason: "Failed to decode response: \(error.localizedDescription). Raw response: \(rawResponse.prefix(500))"
)
```

Raw API responses may contain stack traces, SQL errors, internal IP addresses, or third-party credentials. Server names in MCP error aggregation reveal service topology.

**Remediation:** Log detailed errors internally only. Return opaque error IDs to callers. Sanitize all error messages before propagation.

### 6.3 HIGH: WebSearchTool Accepts Unbounded Input

**File:** `Sources/Swarm/Tools/WebSearchTool.swift:66-143`

- **No query length validation** — arbitrary-length strings forwarded to Tavily API
- **No response size limit** — unbounded JSON parsing on response
- **Error leakage** — Tavily API error responses exposed in tool output, potentially leaking API implementation details
- **SSRF vector** — malicious query values could be crafted to probe internal networks via the search provider

**Remediation:** Validate query length (max 1000 chars), limit response size, sanitize error output.

### 6.2 HIGH: Tool Argument Normalization — No Recursion Depth Limit

**File:** `Sources/Swarm/Tools/Tool.swift:182-207, 365`

`normalizeArguments()` recursively descends into nested object parameters with **no maximum depth check**. A tool accepting deeply nested arguments can trigger stack overflow via crafted input.

**Remediation:** Add `maxDepth` parameter (default: 50), throw on exceeded depth.

### 6.3 HIGH: Handoff Context Injection

**File:** `Sources/Swarm/Orchestration/Handoff.swift:339-340`

```swift
for (key, value) in request.context {
    await context.set(key, value: value)  // No key sanitization
}
```

An attacker controlling a source agent could inject arbitrary context keys, overwriting sensitive state (`user_id`, `authorization_level`) in multi-agent scenarios.

**Remediation:** Whitelist context keys at orchestration level, validate key patterns.

### 6.4 MEDIUM: MCP Client Infinite Loop in Name Deduplication

**File:** `Sources/Swarm/MCP/MCPClient.swift:683`

```swift
var suffix = 2
while true {
    let candidate = "\(serverName).\(baseName)#\(suffix)"
    if usedNames.insert(candidate).inserted { return candidate }
    suffix += 1
}
```

No upper bound on iteration. While theoretically bounded by `Int.max`, this is a DoS vector if `usedNames` is externally influenced.

### 6.5 MEDIUM: No HTTPS Enforcement in OpenRouter Provider

**File:** `Sources/Swarm/Providers/OpenRouter/OpenRouterConfiguration.swift`

While the default `baseURL` is HTTPS, there is no validation preventing override to HTTP. A developer could set `baseURL` to an HTTP endpoint, transmitting API keys in plaintext. `HTTPMCPServer` enforces HTTPS when an API key is present, but `OpenRouterProvider` does not.

### 6.6 MEDIUM: MultiProvider Model Name Injection

**File:** `Sources/Swarm/Providers/MultiProvider.swift:274-289`

`parseModelName()` performs no validation that model names don't contain dangerous characters (newlines, null bytes, control characters). Model names are passed downstream to HTTP requests. If used in request headers, this could enable HTTP header injection.

**Remediation:** Validate model names against `^[a-zA-Z0-9._/-]+$`, enforce max length.

### 6.7 MEDIUM: MCP Tool Results Have No Size Limit

**File:** `Sources/SwarmMCP/SwarmMCPErrorMapper.swift:61-91`

Tool execution results are mapped to MCP responses with no size enforcement. A tool returning gigabytes of data would cause memory exhaustion during JSON encoding.

### 6.8 MEDIUM: JSONMetricsReporter File Path Injection

**File:** `Sources/Swarm/Observability/MetricsCollector.swift:502-505`

```swift
let url = URL(fileURLWithPath: outputPath)
try data.write(to: url, options: .atomic)
```

`outputPath` is user-provided with no validation. Path traversal is possible (e.g., `"../../etc/cron.d/evil"`). In practice, OS permissions limit impact, but the API should validate paths.

### 6.7 LOW: Memory Systems Store PII Without Sanitization

All memory implementations store conversation messages without PII filtering. The `swift-log` convention explicitly prohibits logging PII, but the memory system persists full conversation text to `SwiftData` stores and in-memory buffers. No redaction mechanism exists.

---

## 7. Testing Review

### 7.1 Coverage Assessment

| Subsystem | Test Files | Coverage Level | Verdict |
|-----------|-----------|----------------|---------|
| Subsystem | Estimated Coverage | Test Files | Verdict |
|-----------|-------------------|-----------|---------|
| Core (AgentRuntime, AgentResult, AgentEvent) | ~85% | 15 | Adequate |
| Agents (Agent, ReActAgent) | ~70% | 8 | ChatAgent, PlanAndExecuteAgent untested |
| Orchestration | ~75% | 17 | DAG/Sequential/Parallel solid; Router/Guard sparse |
| Memory | ~80% | 12 | ConversationMemory/Summary/Sliding tested; VectorMemory incomplete |
| Tools | ~85% | 10 | Schema/execution solid; guardrail composition missing |
| Resilience | ~60% | 6 | Basic paths only; no stress/concurrency tests |
| MCP | ~50% | 8 | Happy path only; error recovery/concurrency untested |
| Observability | ~80% | 11 | Tracers, metrics, spans well tested |
| Guardrails | ~65% | 6 | Individual types tested; composition missing |
| Macros | ~70% | 5 | Expansion verified; integration weak |
| Providers | ~55% | 8 | Conduit/MultiProvider tested; OpenRouter partial |
| HiveSwarm | ~60% | 5 | Bridge tested; streaming race conditions unverified |

**Overall: 2,263 test cases across 161 files (~46,366 lines of test code)**

### 7.2 MAJOR: Critical Test Coverage Gaps

| Gap | Severity | What's Missing |
|-----|----------|----------------|
| **PlanAndExecuteAgent** — no dedicated test file | BLOCKER | ~600 lines of planning/execution/replanning logic with zero tests. No tests for plan generation, step execution, dependency resolution, circular dependencies, or max iteration limits |
| **ChatAgent** — no dedicated test file | MAJOR | Public API with no isolated test. Only referenced in session seeding tests. No tests for empty input, memory integration, error paths |
| **VectorMemory** — no unit tests | MAJOR | Critical for RAG-style agents. No tests for semantic search, embedding caching, cosine similarity edge cases, or capacity eviction |
| **SupervisorAgent routing** — undertested | MAJOR | Only init/basic flow tested. No tests for KeywordRoutingStrategy correctness, misrouted queries, 10+ agents, or dynamic registration |
| **MCP error recovery** — not tested | MAJOR | No tests for server crash recovery, network timeout, concurrent tool calls, protocol version mismatch, or malformed responses |
| **Resilience stress testing** — absent | MAJOR | No concurrent stress tests for CircuitBreaker state transitions, RateLimiter burst recovery, or retry backoff math correctness |
| **Cancellation stress tests** — none | MAJOR | No tests for concurrent cancel/run races across any agent type |
| **Stream termination** — no tests for orphaned streams | MAJOR | Resource leak scenarios from abandoned async streams completely unverified |
| **RelayAgent** — no dedicated test file | MAJOR | Agent delegation path untested in isolation |
| **Guardrail composition** — no end-to-end tests | MINOR | No tests combining input + tool + output guardrails in a single execution |
| **Property-based / fuzz testing** — none | MINOR | Edge cases from random inputs completely unexplored |

### 7.3 MAJOR: Weak Assertion Patterns

47 test cases use `Issue.record()` or `#expect(true)` (trivially-passing assertions). These tests record failures but don't assert specific conditions — failures can go unnoticed in CI. Example: `FluentResilienceTests.swift:37` catches an error but doesn't verify the error type.

**Remediation:** Replace all `Issue.record()` patterns with proper `#expect()` or `await #expect(throws:)`.

### 7.4 MAJOR: Mock Quality Concerns

The `MockInferenceProvider` returns static responses, which is appropriate for unit testing but insufficient for:
- **Streaming behavior** — mocks don't simulate partial delivery, back-pressure, or mid-stream failures
- **Tool call patterns** — mocks don't simulate complex multi-turn tool call sequences
- **Latency simulation** — no mocks introduce realistic timing for timeout testing
- **MockAgentMemory** uses silent `try?` in `add()` and `context()` — should fail hard in tests

### 7.5 MINOR: Test-Only `@unchecked Sendable` Usage

8+ test files use `@unchecked Sendable` for mock classes. While acceptable for testing, these mocks could mask real concurrency issues that would appear in production. Consider converting test mocks to actors where feasible.

### 7.6 Testing Strengths

- **Macro expansion tests** are thorough — all 5 macros have dedicated test suites
- **Guardrail integration tests** are comprehensive with both passing and failing scenarios
- **Resilience tests** cover circuit breaker state transitions, rate limiter token refill, retry backoff
- **161 test files** for 200 source files — strong test-to-source ratio
- **Consistent use of Swift Testing** (`@Test`, `@Suite`) — modern test framework adoption
- **Well-organized structure** — test directory mirrors source directory layout
- **Good mock isolation** — 4 main mocks prevent external dependencies

### 7.7 Test Files That Should Be Created

| File | Priority | Est. Tests |
|------|----------|-----------|
| `Tests/SwarmTests/Agents/PlanAndExecuteAgentTests.swift` | BLOCKER | 40+ |
| `Tests/SwarmTests/Agents/ChatAgentTests.swift` | MAJOR | 15+ |
| `Tests/SwarmTests/Memory/VectorMemoryTests.swift` | MAJOR | 20+ |
| `Tests/SwarmTests/MCP/MCPErrorRecoveryTests.swift` | MAJOR | 25+ |
| `Tests/SwarmTests/Resilience/ResilienceStressTests.swift` | MAJOR | 20+ |
| `Tests/SwarmTests/Agents/RelayAgentTests.swift` | MAJOR | 10+ |

---

## 8. Refactoring Opportunities

### 8.1 Consolidate Stream Factory Patterns

Multiple files create streams differently: some use `StreamHelper.makeTrackedStream()`, others use raw `AsyncThrowingStream { continuation in Task { ... } }`. Standardize on `StreamHelper` across all stream creation sites.

**Files affected:** `MultiProvider.swift`, `StreamOperations.swift:retry()`, various agent `stream()` methods.

### 8.2 Extract Error Conversion to Centralized Mapper

Error conversion from arbitrary errors to `AgentError` is scattered across multiple files with inconsistent patterns. Some use `error as? AgentError ?? .internalError(...)`, others have richer matching. Centralize in a single `AgentError.from(_ error: Error)` factory method.

### 8.3 Remove Stub Files

Delete the three stub files (`Tracing.swift`, `Integration.swift`, `Extensions.swift`) or implement their declared functionality. Shipping empty "to be implemented" files in a framework library is unprofessional.

### 8.4 Rename `try?` to `try` + Explicit Error Handling

Audit all 30+ `try?` usages in Sources. Replace silent failures with:
- `do { try ... } catch { Log.agents.warning("...") }` for recoverable paths
- `try` for paths where failure should propagate

### 8.5 Simplify `SendableValue` Dictionary Literal

**File:** `Sources/Swarm/Core/SendableValue.swift:134`

Replace `Dictionary(uniqueKeysWithValues:)` (which crashes on duplicates) with `reduce(into:)` that handles duplicates gracefully:

```swift
let dict = elements.reduce(into: [Key: Value]()) { $0[$1.key] = $1.value }
```

### 8.6 Reduce ArithmeticParser Nesting Depth

**File:** `Sources/Swarm/Tools/ArithmeticParser.swift:223`

`maxNestingDepth = 200` is excessive. Reduce to 50 (still supports all practical formulas) to limit stack consumption under parallel tool execution.

---

## 9. Dependency Review

| Dependency | Pin Strategy | Risk |
|------------|-------------|------|
| swift-syntax | Range `600.0.0..<603.0.0` | Low — wide range may pull breaking changes |
| swift-log | `from: "1.5.0"` | Low — stable API |
| swift-sdk (MCP) | `from: "0.10.0"` | **Medium** — pre-1.0 dependency, API may change |
| Conduit | `exact: "0.3.5"` | Low — exact pin, but blocks minor fixes |
| Wax | `from: "0.1.3"` | **Medium** — pre-1.0, used for embeddings |
| Membrane | `.branch("main")` | **HIGH** — non-reproducible builds |
| Hive | `from: "0.1.0"` | **Medium** — pre-1.0, core execution engine |

**Key concern:** Three pre-1.0 dependencies (MCP SDK, Wax, Hive) plus one branch-pinned dependency (Membrane). Production builds depend on unstable APIs.

---

## 10. Build Configuration Review

### 10.1 Platform Requirements

```swift
.macOS(.v26), .iOS(.v26), .tvOS(.v26)
```

macOS 26 / iOS 26 are **unreleased platforms** (expected WWDC 2025 era). This means:
- Framework cannot be used on any shipping OS today
- All testing must occur on beta toolchains
- tvOS is declared but has no dedicated test coverage

### 10.2 StrictConcurrency Enabled Everywhere

All targets have `.enableExperimentalFeature("StrictConcurrency")`. This is **correct and good** — ensures the compiler catches Sendable violations.

### 10.3 HiveSwarmTests Always Compiled

```swift
packageTargets.append(
    .testTarget(name: "HiveSwarmTests", ...)
)
```

This target is appended unconditionally (not gated by any flag), while `SwarmDemo` and `SwarmMCPServerDemo` are correctly gated behind `SWARM_INCLUDE_DEMO`. Consistent gating would be cleaner.

---

## 11. Summary of Findings by Severity

| Severity | Count | Categories |
|----------|-------|------------|
| **BLOCKER** | 5 | Runtime crash, NSLock deadlocks, infinite loops, stack overflow, PlanAndExecuteAgent untested |
| **MAJOR** | 20 | Data loss, race conditions, missing tests (7 critical gaps), weak assertions, error swallowing, path traversal, info disclosure, injection |
| **MINOR** | 12 | Config validation, unnecessary wrappers, stub files, performance, guardrail composition |
| **Total** | 37 | |

---

## 12. Recommended Remediation Priority

### Immediate (Pre-Production, Week 1)

1. **Fix `Dictionary(uniqueKeysWithValues:)` crash** — validate tool call ID uniqueness before dictionary construction
2. **Convert `AgentResult.Builder` and `TraceEvent.Builder` to actors** — eliminate NSLock deadlock risk
3. **Add timeout guards to infinite loops** — MCP client name dedup, retry policy, arithmetic parser
4. **Add recursion depth limit to tool argument normalization** — cap at 50 levels
5. **Fix HiveBackedAgent stream race** — use `withThrowingTaskGroup` for coordinated completion

### Short-Term (Week 2-3)

6. Fix task cancellation race in `Agent.run()` and `ReActAgent.run()`
7. Add WebSearchTool input validation (query length, response size limits)
8. Add handoff context key validation/whitelisting
9. Replace critical `try?` patterns with proper error handling
10. Standardize stream creation on `StreamHelper.makeTrackedStream()`
11. Fix path traversal bypass in HTTPMCPServer — use canonical path resolution
12. Sanitize error messages — remove raw API responses, server names from thrown errors
13. Validate model names in MultiProvider against safe character pattern
14. Add tool result size limits in MCP error mapper

### Medium-Term (Week 4-6)

15. Write tests for PlanAndExecuteAgent (40+), ChatAgent (15+), VectorMemory (20+), RelayAgent (10+)
16. Add MCP error recovery tests (25+)
17. Add resilience stress tests — concurrent CircuitBreaker/RateLimiter (20+)
18. Add cancellation stress tests and stream termination tests
19. Replace all 47 `Issue.record()` / `#expect(true)` patterns with proper assertions
20. Optimize DAG cycle detection and MetricsSnapshot percentile computation
21. Remove stub files, clean up deprecated DSL layer

### Long-Term

16. Pin Membrane to a tagged release
17. Evaluate pre-1.0 dependency stability
18. Add PII redaction mechanism to memory systems
19. Add property-based/fuzz testing for parsers and tool argument handling

---

## 13. Conclusion

The Swarm framework has **strong architectural DNA**: protocol-first design, comprehensive actor isolation, modern Swift concurrency, and good test coverage (~161 test files for ~200 source files). The core abstractions (`AgentRuntime`, `InferenceProvider`, `Tracer`, `Memory`) are well-designed and composable.

However, **4 blockers and 12 major issues** must be addressed before production deployment. The most critical are runtime crashes from unvalidated input, deadlock-prone `@unchecked Sendable` builders, and infinite loop vectors. These are all fixable within 2-3 focused engineering weeks.

**Verdict:** Not production-ready as-is. With the recommended Week 1 fixes applied, the framework would reach a **7.5/10** readiness score — suitable for controlled production use with monitoring. Full remediation would bring it to **8.5+/10**.

---

*This audit was conducted through adversarial static analysis of the full source tree (200 source files, 161 test files). Findings are based on code review only — no runtime testing was performed. False positives have been cross-checked and marked where identified.*
