# Unified Agent Long-Term API Plan

Date: 2026-02-01

## Goal

Simplify the public API by introducing a single, strong runtime base agent named `Agent` while making `AgentBlueprint` the preferred SwiftUI-style DSL for orchestration/workflows.

Key outcomes:

- Runtime: `public actor Agent: AgentRuntime` becomes the default way to build and run agents.
- Runtime protocol: keep `AgentRuntime` as the canonical protocol contract.
- SwiftUI DSL: `AgentBlueprint` is the preferred high-level declarative API.
- Legacy SwiftUI DSL (today’s `protocol Agent` + `LoopAgent` + `Generate/Relay`) is renamed to avoid symbol collision and deprecated with a clear migration path.
- Legacy runtime agents (`ReActAgent`, `ToolCallingAgent`, `PlanAndExecuteAgent`, `ChatAgent`) become thin wrappers over the unified `Agent` (or share a unified lifecycle core) and are eventually deprecated.

Non-goals (initial rollout):

- Fully removing legacy agents/DSL in the same change.
- Rewriting every internal loop to a brand-new engine in one step.
- Changing provider/tool calling semantics.

## Current State (Why This Change)

1) **Runtime duplication**

`ReActAgent`, `ToolCallingAgent`, `PlanAndExecuteAgent`, and `ChatAgent` duplicate the same run/stream lifecycle pipeline (validation, tracing, hooks, guardrails, session history, memory writeback, cancellation). The loop logic differs, but the lifecycle is nearly identical.

2) **Naming collision**

The module previously had a SwiftUI-style legacy loop DSL protocol named `Agent` (now renamed to `AgentLoopDefinition`, deprecated) in `Sources/Swarm/DSL/DeclarativeAgent.swift`. Long-term we want a unified runtime concrete type named `Agent`, so the legacy DSL must remain non-colliding.

3) **Two DSL layers**

- `AgentBlueprint` already exists and is explicitly intended to be the primary high-level API long-term (`Sources/Swarm/DSL/AgentBlueprint.swift`).
- The legacy loop DSL (`protocol Agent` + `@AgentLoopBuilder`) provides `Generate/Relay` model-turn steps by implicitly constructing a relay runtime agent. AgentBlueprint does not include `Generate/Relay` today; within blueprints, model turns should be explicit runtime `Agent` steps (or a later convenience layer).

## Naming Decisions (Long-Term)

- `AgentRuntime`: keep as the runtime protocol contract (requirements: tools/instructions/config/memory/provider/tracer/guardrails/handoffs + run/stream/cancel).
- `Agent` (NEW): unified runtime actor users instantiate.
- `AgentBlueprint`: preferred SwiftUI-style orchestration/workflow authoring model.
- Legacy loop DSL:
  - Rename `protocol Agent` → `AgentLoopDefinition` (exact name TBD, but must avoid colliding with `Agent`).
  - Deprecate legacy loop DSL types and `Generate/Relay` steps in favor of `AgentBlueprint` + runtime `Agent` steps inside orchestrations.

## Migration Guidance (High-Level)

- Runtime:
  - Old: `ReActAgent(...)`, `ToolCallingAgent(...)`, `ChatAgent(...)`, `PlanAndExecuteAgent(...)`
  - New: `Agent(...)` + explicit strategy selection (e.g. `.toolCalling`, `.react`, `.chat`, `.planAndExecute`)

- SwiftUI-style orchestration:
  - Old: `struct MyFlow: AgentLoopDefinition { @AgentLoopBuilder var loop: ... }`
  - New: `struct MyFlow: AgentBlueprint { @OrchestrationBuilder var body: ... }`
  - Model turns: embed a runtime `Agent` step in the blueprint body (e.g. `Agent(...)`) rather than `Generate()/Relay()`.

## Phases

### Phase 1 — Rename & Deprecate Legacy Loop DSL (Unblock `Agent` Runtime Type)

To-do:

- Rename legacy DSL protocol `Agent` (in `Sources/Swarm/DSL/DeclarativeAgent.swift`) to `AgentLoopDefinition` (or final chosen name).
- Rename related types/extensions/tests accordingly:
  - `LoopAgentStep` builder overloads in `OrchestrationBuilder` currently accept `A: Agent`; update to new name.
  - Any `handoff(to: A)` overloads or builder utilities referencing `Agent` (legacy DSL) updated similarly.
- Mark the legacy DSL protocol and adapters as deprecated with migration messages pointing to `AgentBlueprint`.
- Update docs/examples that refer to `struct X: Agent` to use `AgentBlueprint` (or explicitly label legacy DSL as deprecated where retained).

Success criteria:

- `swift build` succeeds with no symbol collision.
- Existing legacy DSL behavior remains intact (tests updated) but emits deprecation warnings.

### Phase 2 — Introduce Unified Runtime `Agent`

To-do:

- Add `public actor Agent: AgentRuntime` with a strategy/behavior selection:
  - Default behavior should be structured tool-calling (today’s `ToolCallingAgent` semantics).
  - Support explicit strategies: `.toolCalling`, `.react`, `.chat`, `.planAndExecute`.
- Provide ergonomic initializers that match existing patterns (tools array, typed tools, instructions, configuration, memory/provider/tracer, guardrails, handoffs).
- Ensure strict concurrency correctness (`Sendable` boundaries, `nonisolated` properties consistent with `AgentRuntime`).

Success criteria:

- Users can replace common cases with `Agent(...)` without touching providers/tools.
- Behavior matches ToolCallingAgent for default configuration.

### Phase 3 — Unify Lifecycle Internals (Reduce Duplication)

To-do:

- Extract a shared lifecycle pipeline (input validation, tracing, hooks, guardrails, session history, memory seeding, output guardrails, session/memory writeback, error handling).
- Make all legacy agents call the shared lifecycle, or wrap the unified `Agent` and forward.
- Normalize memory seeding policy as an explicit per-strategy decision to preserve current behavior.

Success criteria:

- Duplicate logic is eliminated or reduced substantially.
- Behavior parity maintained across agents.

### Phase 4 — Update Orchestration & Blueprint Integrations

To-do:

- Ensure `@OrchestrationBuilder` supports:
  - `any AgentRuntime` steps (already supported).
  - `AgentBlueprint` steps (already supported).
  - Legacy DSL steps via renamed `AgentLoopDefinition` adapter (deprecated path).
- Add ergonomics (optional but recommended):
  - `handoff(to blueprint: B)` overload that wraps `BlueprintAgent(blueprint)`.
  - Clear examples showing blueprint + runtime `Agent` step as the replacement for `Generate/Relay`.

Success criteria:

- Orchestrations can embed unified runtime `Agent` directly.
- Blueprint-based orchestration covers primary docs/examples.

### Phase 5 — Tests (Contract + Parity)

To-do:

- Add a small test kit that can run the same scenarios against:
  - legacy agents (ReAct/ToolCalling/Chat/PlanAndExecute as relevant)
  - unified runtime `Agent` configured to equivalent strategies
- Cover: run output, iteration counts, tool calls/results, guardrails, sessions/memory, streaming event shape, cancellation.

Success criteria:

- `swift test` passes.
- New tests prevent semantic drift between legacy and unified behavior.

### Phase 6 — Docs + Migration Guide

To-do:

- Make docs present:
  - `Agent` (runtime) as the default entry point.
  - `AgentBlueprint` as the SwiftUI-style DSL.
  - legacy loop DSL as deprecated.
- Update code snippets in docs/README/demo to compile against the new API.

Success criteria:

- No “preferred path” docs mention legacy loop DSL.
- Examples compile and match reality.

## Work Packages (Implementation Slices)

These will be produced as separate focused `docs/work-packages/*.md` files:

- WP1: Legacy DSL rename + deprecations + test updates.
- WP2: Unified runtime `Agent` public API + initial default strategy.
- WP3: Strategy implementations + lifecycle unification.
- WP4: Orchestration/blueprint ergonomics (handoff overloads, builder updates).
- WP5: Contract/parity tests.
- WP6: Docs/README/demo updates.
