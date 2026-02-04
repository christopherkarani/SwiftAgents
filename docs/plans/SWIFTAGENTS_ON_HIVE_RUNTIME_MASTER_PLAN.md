# SwiftAgents → Hive Runtime Migration (Master Plan)

Date: 2026-02-03

Status: Draft for implementation (plan-of-record once you confirm open questions).

This plan consolidates:
- `plans/SWIFTAGENTS_ON_HIVE_RUNTIME_MIGRATION_PLAN.md`
- `plans/SWIFTAGENTS_ON_HIVE_RUNTIME_MIGRATION_VALIDATION_ADDENDUM.md`

Primary requirement (locked):
> Hive (`HiveCore`) is the one and only runtime. SwiftAgents must not ship a parallel/embedded runtime implementation.

---

## 0) Scope & Deliverables

### Goals (must-haves)
1) `HiveSwiftAgents` (in SwiftAgents repo) depends on `HiveCore` and uses `HiveRuntime` for all execution.
2) Remove the embedded/stub runtime/types from SwiftAgents (`Sources/HiveSwiftAgents/HiveCore.swift`).
3) `HiveAgents` prebuilt tool-using chat agent graph compiles via `HiveGraphBuilder` and runs via `HiveRuntime`.
4) Tool bridging preserves SwiftAgents tool semantics:
   - argument normalization and guardrails (via `ToolRegistry.execute`)
5) Tests pass in SwiftAgents with HiveCore runtime (Swift Testing framework).

### Non-goals
- Rewrite SwiftAgents’ internal agent frameworks (ReAct, PlanAndExecute, orchestration, memory) to run on Hive.
- Extend HiveCore semantics beyond what exists in `/Hive/libs/hive/Sources/HiveCore`.

### End-state ownership & dependency direction
- SwiftAgents ships `HiveSwiftAgents` integration + prebuilt graph.
- Hive ships `HiveCore` runtime (and optional `HiveConduit`, `HiveCheckpointWax`) and does not ship any product that imports SwiftAgents.

---

## 1) Repository Truths (Key Facts)

### SwiftAgents today
- `HiveSwiftAgents` target currently embeds a Hive-like runtime (`Sources/HiveSwiftAgents/HiveCore.swift`) and a stub `HiveRuntime`.
- Prebuilt graph + façade are in `Sources/HiveSwiftAgents/HiveAgents.swift`.
- Tool bridge exists in `Sources/HiveSwiftAgents/SwiftAgentsToolRegistry.swift` but must be updated to preserve `ToolRegistry.execute` semantics.

### Hive today
- The real runtime package is `Hive/libs/hive` (not Hive repo root `Package.swift`).
- HiveCore enforces:
  - deterministic supersteps
  - interrupt selection and resume
  - checkpointing hooks
  - codec requirements for task-local and checkpointed channels
  - interrupt → checkpoint store required (even if checkpoint policy is “disabled”)

---

## 2) Hard Blockers (Must Solve Before Implementation)

### 2.1 SwiftPM dependency identity alignment (BLOCKER)

Problem:
- SwiftAgents depends on Conduit + Wax via URL in `SwiftAgents/Package.swift`.
- Hive depends on Conduit + Wax via local path in `Hive/libs/hive/Package.swift`.
- Once SwiftAgents depends on Hive, SwiftPM will encounter identity conflicts for the same dependency coming from URL vs path.

Recommendation (preferred):
- Make Hive (`Hive/libs/hive/Package.swift`) depend on Conduit and Wax by URL identity matching SwiftAgents.
- For local development, use SwiftPM overrides (mirrors / editable checkouts) rather than path dependencies inside the published package.

Fallback (local-only, not publishable):
- Convert SwiftAgents to use path dependencies for Conduit/Wax matching Hive’s path identities.

Decision required: see “Open Questions”.

### 2.2 Messages reducer signature mismatch (BLOCKER)

SwiftAgents’ current messages reducer is “batch reduce” (`left` + `[[update]]`).
HiveCore reducers are binary (`reduce(current:update:)`) applied sequentially.

Required change:
- Rewrite `MessagesReducer` to be binary while preserving semantics (removeAll marker handling, remove/update rules).

### 2.3 Interrupts require checkpoint store (BLOCKER for tool approval)

HiveCore guarantees interrupts are checkpoint-backed.
If an interrupt occurs and `checkpointStore` is nil, HiveCore throws `HiveRuntimeError.checkpointStoreMissing`.

Required change:
- If `toolApprovalPolicy` can interrupt, enforce `checkpointStore != nil` at façade creation/preflight.

### 2.4 Codecs required for task-local and checkpointed channels (BLOCKER)

HiveCore requires codecs for:
- all `taskLocal` channels, and
- all `global checkpointed` channels.

Required change:
- Provide deterministic codecs for `HiveAgents.Schema` channels.
  - Recommendation: a standard `HiveCodableJSONCodec<T: Codable & Sendable>` in HiveCore (reusable across modules).
  - Acceptable alternative: define codecs in `HiveSwiftAgents` and use them only from schema specs.

---

## 3) Architecture Decisions to Lock (Recommendations)

### 3.1 Tool definitions source-of-truth: registry, not context

Current SwiftAgents prebuilt graph stores:
- `HiveAgentsContext.tools: [HiveToolDefinition]` for model calls, and
- `environment.tools: AnyHiveToolRegistry?` for invocation.

This can diverge and is easy to misuse.

Recommendation:
- Remove `tools: [HiveToolDefinition]` from `HiveAgentsContext`.
- Model node uses `environment.tools?.listTools()` as the single source of tool definitions.

### 3.2 Prebuilt graph shape: use a router instead of a route node

Recommendation:
- Remove the dedicated `routeAfterModel` node.
- Attach a router to either:
  - `model` (when no `postModel`) or
  - `postModel` (when present)
  Router reads `pendingToolCalls` and chooses `.end` vs `.nodes([tools])`.

Benefits:
- fewer nodes
- matches HiveCore routing semantics (`router` runs when task’s `next` is `.useGraphEdges`)

### 3.3 Façade API: return HiveCore `HiveRunHandle` (events + outcome)

Recommendation:
- Make `HiveAgentsRuntime.sendUserMessage` and `resumeToolApproval` return HiveCore `HiveRunHandle`.
- Prefer “fail fast via throwing” for preflight errors (simpler and Swifty), but provide a compatibility `failed handle` helper if you want non-throw call sites.

### 3.4 Preserve SwiftAgents ToolRegistry semantics

Recommendation:
- The adapter backing `AnyHiveToolRegistry` should be built around SwiftAgents `ToolRegistry` and use `ToolRegistry.execute(...)` so:
  - argument normalization (defaults/coercion) happens
  - guardrails run
  - hook/error reporting is consistent

---

## 4) Implementation Plan (Tier 2 / Test-First)

### Phase 0 — Lock “Dependency Identity” Strategy
Owner: Planning + Implementation (Hive + SwiftAgents package maintainers)

Tasks:
1) Choose and implement one dependency identity strategy (see §2.1).
2) Verify SwiftPM can resolve the unified graph:
   - SwiftAgents depends on HiveCore
   - Both resolve the same Conduit identity
   - Both resolve the same Wax identity

Exit criteria:
- `swift package describe` succeeds in SwiftAgents after adding Hive dependency (no identity conflicts).

### Phase 1 — Create Failing Tests for HiveSwiftAgents-on-HiveCore
Owner: Test Agent (SwiftAgents repo)

Principle:
- No implementation edits until tests are in place.

Tasks:
1) Add new runtime-driven tests that do not rely on manual store construction.
2) Use:
   - `HiveRuntime.applyExternalWrites(...)` to seed channels
   - `HiveRunOptions(maxSteps: 1)` for focused assertions
   - `HiveOutputProjection.channels([ids])` to read specific outputs
3) Encode expected behaviors:
   - messages reducer semantics (pure tests)
   - compaction behavior (“llmInputMessages is derived and does not mutate messages”)
   - tool approval interrupt + resume flow (requires checkpoint store)
   - deterministic message IDs derived from real runtime task IDs (via emitted events)

Exit criteria:
- Tests compile but fail for the right reasons (API mismatches / stub runtime removal not yet done).

### Phase 2 — Remove Embedded Runtime from SwiftAgents
Owner: Implementation Agent (SwiftAgents repo)

Tasks:
1) Delete `Sources/HiveSwiftAgents/HiveCore.swift`.
2) Replace with a minimal module entrypoint that re-exports HiveCore:
   - `@_exported import HiveCore`
3) Fix compile errors by updating imports and type usage to HiveCore equivalents.

Exit criteria:
- SwiftAgents compiles against HiveCore types (even if tests still fail).

### Phase 3 — Port HiveAgents Schema + Graph Compilation to HiveCore
Owner: Implementation Agent (SwiftAgents repo)

Tasks:
1) Rewrite `HiveAgents.Schema` channel keys:
   - `HiveChannelKey<HiveAgents.Schema, Value>`
2) Rewrite channel specs to HiveCore `HiveChannelSpec` and `AnyHiveChannelSpec`.
3) Provide codecs for all task-local and checkpointed channels.
4) Rewrite reducer(s) with HiveCore binary reducer signature.
5) Rebuild `makeToolUsingChatAgent` using `HiveGraphBuilder`:
   - Nodes: `preModel`, `model`, `tools`, `toolExecute`, optional `postModel`
   - Router on `model` or `postModel` for “pending tool calls?”
   - Static edges for linear flow and tool loop (`toolExecute` back to `model`)

Exit criteria:
- Graph compiles and can execute with `HiveRuntime` (smoke).

### Phase 4 — Implement the Tool Registry Adapter Correctly
Owner: Implementation Agent (SwiftAgents repo)

Tasks:
1) Build a `HiveToolRegistry` implementation backed by SwiftAgents `ToolRegistry`.
2) Ensure `listTools()` is deterministic and returns definitions matching SwiftAgents tool params (including defaults).
3) Ensure `invoke(_ call:)`:
   - parses JSON arguments → `[String: SendableValue]`
   - executes via `ToolRegistry.execute(...)`
   - encodes `SendableValue` result back to stable JSON string

Exit criteria:
- Tool invocation path matches SwiftAgents semantics (guardrails + normalization).

### Phase 5 — Update the Façade (`HiveAgentsRuntime`)
Owner: Implementation Agent (SwiftAgents repo)

Tasks:
1) Remove reliance on `HiveRuntime.environment` internals.
2) Implement preflight rules:
   - if model client missing → fail/throw
   - if tools missing → fail/throw
   - if tool approval can interrupt → require checkpoint store
   - validate compaction config (tokenizer presence; numeric bounds)
3) Return HiveCore `HiveRunHandle` (events + outcome).

Exit criteria:
- Public façade is hard to misuse and has deterministic failure modes.

### Phase 6 — Make the Tests Pass (TDD loop)
Owner: Test Agent + Fix/Gap Agent

Tasks:
1) Iterate until all new tests pass.
2) Remove or rewrite the old tests that depended on embedded types and manual store construction.

Exit criteria:
- `swift test` passes in SwiftAgents for `HiveSwiftAgentsTests`.

### Phase 7 — Hive Repo Hygiene (Enforce One-Way Dependency)
Owner: Implementation Agent (Hive repo)

Tasks:
1) Ensure Hive does not ship a product that imports SwiftAgents.
2) Remove or clearly mark any internal-only HiveSwiftAgents code in Hive repo (if it exists for experiments).

Exit criteria:
- Published surfaces are clean; SwiftAgents is the integration owner.

### Phase 8 — Reviews (Mandatory)
Owner: Review Agents (2)

Review checklist:
- No parallel runtime types exist in SwiftAgents.
- All runtime semantics are HiveCore.
- Tool adapter preserves `ToolRegistry.execute` semantics.
- Interrupt/resume always checkpoint-backed (and preflight enforces store).
- Codecs are present for all required channels.
- Determinism assumptions are preserved (ordering, IDs, event invariants).

---

## 5) Success Criteria

1) SwiftAgents builds with `HiveCore` and removes embedded runtime/types.
2) The prebuilt `HiveAgents` graph runs on HiveCore:
   - model calls stream tokens
   - tool approval interrupts + resume work (with checkpoint store)
   - tool execution produces tool messages and loops correctly
3) Tests validate correctness without relying on internal runtime constructs.

---

## 6) Open Questions (Need Your Confirmation)

1) Dependency identity strategy (Conduit/Wax):
   - Do you want Hive (`Hive/libs/hive`) to switch to URL dependencies (recommended, publishable), or do you prefer path dependencies everywhere for now (local-only)?
2) Do you want `HiveAgentsRuntime` to `throw` on preflight failure (recommended), or return a “failed handle” for non-throw call sites?
3) Is it acceptable to add a small reusable JSON codec type to HiveCore (recommended), or should codecs live only inside SwiftAgents’ `HiveSwiftAgents` module?

---

## 7) Recommendations Summary (Why these choices)

- Aligning dependency identities early prevents a multi-day SwiftPM integration failure later.
- Routing via HiveCore routers reduces graph surface area and matches the runtime’s execution model.
- Using SwiftAgents `ToolRegistry.execute` preserves guardrails and argument normalization, avoiding subtle behavior regressions.
- Enforcing checkpoint store presence for interrupts is required by HiveCore and avoids runtime-time surprises for tool approval flows.

