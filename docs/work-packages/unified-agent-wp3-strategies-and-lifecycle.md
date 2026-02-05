Prompt:
Implement Phase 3 of `docs/plans/UNIFIED_AGENT_LONG_TERM_API_PLAN.md` (do not edit the plan doc): unify lifecycle internals across runtime agents by extracting a shared execution pipeline, then make legacy agents and the unified `Agent` reuse it. Preserve behavior; make memory seeding policy an explicit strategy decision.

Goal:
Reduce duplication across `ReActAgent`, `ToolCallingAgent`, `PlanAndExecuteAgent`, and `ChatAgent` by consolidating the shared lifecycle (validation, tracing, hooks, guardrails, session history, memory seeding/writeback, cancellation), while maintaining behavioral parity.

Task Breakdown:
1) Inventory shared lifecycle responsibilities (before changing code):
   - Identify the overlapping steps in:
     - `Sources/Swarm/Agents/ReActAgent.swift`
     - `Sources/Swarm/Agents/ToolCallingAgent.swift`
     - `Sources/Swarm/Agents/PlanAndExecuteAgent.swift`
     - `Sources/Swarm/Agents/Chat.swift` (ChatAgent)
   - Specifically map: input validation, tracer setup, hooks callbacks, guardrails, session history fetch, memory seeding, inference call(s), tool execution, output guardrails, session/memory writeback, and cancellation.
2) Extract a shared lifecycle pipeline (internal-only API):
   - Create a small internal "lifecycle core" (name is flexible, but keep it narrow):
     - Suggested new path: `Sources/Swarm/Agents/Lifecycle/AgentLifecycle.swift`
   - The lifecycle core should:
     - take an `AgentRuntime`-like configuration surface (tools/instructions/config/memory/provider/tracer/guardrails/handoffs),
     - accept a per-strategy "loop executor" closure or protocol to run the strategy-specific logic,
     - own standardized tracing/hook/guardrail/session/memory sequencing,
     - and return `AgentResult` (and optionally streaming events if you tackle streaming in the same core).
3) Strategy-specific logic boundaries:
   - Define explicit, testable strategy engines (internal types) that plug into the lifecycle core:
     - Tool-calling iteration logic (today in ToolCallingAgent)
     - ReAct parsing/iteration logic (today in ReActAgent)
     - Plan-and-execute phases (planning/execution/replanning)
     - Chat single-shot behavior
   - Make memory seeding policy explicit per strategy to preserve current behavior (document why).
4) Wire agents to the shared lifecycle:
   - Update each legacy agent to call the shared lifecycle core rather than duplicating pipeline code.
   - Option A: legacy agents become thin wrappers around unified `Agent` configured to a strategy.
   - Option B: legacy agents keep their public surface but delegate to lifecycle core + strategy engine.
   - Choose the option that minimizes behavior changes and keeps API stable.
5) Streaming alignment:
   - If streaming event emission is duplicated across agents today, unify it via the lifecycle core.
   - Ensure streaming event shape stays stable (existing tests must remain green; parity tests will cover drift).
6) Validate parity:
   - Run `swift test` and ensure existing tests stay green.
   - If you need to adjust behavior, stop and add parity tests first (WP5 will formalize, but do not regress existing semantics).

Expected Output:
- Shared lifecycle internals exist (internal-only) and are used by legacy agents and/or unified `Agent`.
- Substantial duplicate lifecycle code is eliminated or reduced, without observable behavior changes.
- Memory seeding/writeback decisions are explicit per strategy (documented in code where non-obvious).

Constraints:
- Do NOT edit `docs/plans/UNIFIED_AGENT_LONG_TERM_API_PLAN.md`.
- Preserve public API compatibility for legacy agents (no source-breaking renames here).
- Avoid premature abstraction: keep the lifecycle core small, explicit, and easy to reason about.
- Maintain strict concurrency correctness; avoid `@unchecked Sendable` unless unavoidable and justified.

