# Hive -> Swarm Hardening (Non-Fork) — Execution Prompt v2

You are a principal Swift 6.2 engineer.  
Your mission is to implement and verify the non-fork Hive hardening contract for Swarm with minimal behavioral ambiguity and deterministic outcomes.

## Objective

- Implement production-grade runtime semantics for Hive-in-Swarm execution.
- Exclude fork support.
- Keep changes scoped and typed.
- Preserve deterministic behavior and replay safety for prompt-driven workflows.

## Source-of-Truth Artifacts (must be authoritative)

- `docs/plans/hive-swarm-nonfork-implementation-plan.md`
- `Sources/Swarm/HiveSwarm/HiveAgents.swift`
- `Sources/Swarm/HiveSwarm/HiveBackedAgent.swift`
- `Sources/Swarm/Agents/Chat.swift`
- `Sources/Swarm/Agents/ReActAgent.swift`
- `Sources/Swarm/Core/PromptEnvelope.swift`
- `Sources/Swarm/Core/AgentError.swift`

## Observed Runtime Facts (Do not override unless explicitly required)

1. Run control entrypoints exist in `HiveAgents.swift`:
   - `HiveAgentsRunController.start(_:)` calls `runtime.run(threadID:input:options:)`.
   - `HiveAgentsRunController.resume(_:)` calls `runtime.resume(threadID:interruptID:payload:options:)`.
   - Both currently call `preflight(environment:)`.
2. Current preflight checks in `HiveAgentsRunController.preflight(...)` include:
   - model presence (`modelRouter` or `model`),
   - tool registry presence,
   - checkpoint store required when tool approval policy is not `.never`,
   - compaction policy bounds and tokenizer dependency.
3. `HiveAgents.Schema` currently defines global channels:
   - `messagesKey`, `pendingToolCallsKey`, `finalAnswerKey`, `llmInputMessagesKey`, `membraneCheckpointDataKey`.
4. `HiveBackedAgent` owns run lifecycle integration:
   - `run(_:)`, `stream(_:)`, and `cancel()`,
   - maps `HiveRuntimeError` to `AgentError` in `mapHiveError(_:)`.
5. Existing mapping in `HiveBackedAgent.mapHiveEvent(_:)` is partial:
   - checkpoint and write-applied style events currently yield `nil`.
6. `HiveAgents.Schema.inputWrites(...)` currently seeds `messagesKey` and resets `finalAnswerKey`.
7. `ChatAgent` and `ReActAgent` build prompts using plain string concatenation and call `PromptEnvelope.enforce(...)` prior to model invocation.

You should **not** assume behavior outside this list unless you locate direct evidence in the source files above.

## Prompt Design Instructions

1. Use strict, explicit decomposition:
   - constraints → implementation plan → validation → risks → evidence.
2. Keep all suggestions grounded to existing symbols.
3. Do not invent APIs, return types, or runtime behavior.
4. If needed context is missing, call it out as an assumption and propose a source lookup task.
5. Prioritize correctness and determinism over convenience.

## Required Scope (Contract Areas)

1. Typed state snapshot API
   - Add typed `getState(threadID:) async throws -> HiveRuntimeStateSnapshot<Schema>?`
   - Return `nil` for missing threads.
   - Snapshot must include deterministic fields (thread ID, run ID, step index, interruption metadata, checkpoint ID, frontier summary/hashes, and optional channel state summary).
2. Checkpoint capability contract
   - Add explicit discovery and typed unsupported failures for checkpoint query/load operations.
3. Deterministic transcript and hashes
   - Canonical event/state projection with stable ordering.
   - Add transcript hash + final-state hash utilities.
   - Add first-diff reporting for first mismatch path.
4. Cancel + checkpoint race semantics
   - Define deterministic outcomes when cancellation overlaps persistence.
   - Keep event lifecycle transitions observable.
5. Interrupt/resume contract hardening
   - Handle pending interrupt, missing interrupt, mismatch interrupt ID, and state/version mismatch explicitly.
6. External write validation and atomicity
   - Validate channel scope/schema/task locality.
   - All-or-nothing commit semantics.
   - Preserve frontier/step semantics on success only.
7. Event schema versioning
   - Emit explicit schema version metadata for events/transcripts.
   - Add compatibility checks on replay and typed compatibility errors.
8. `validateRunOptions(_:)`
   - Expose typed validation entrypoint for bounds, unsupported combinations, and dependencies.
   - Ensure existing preflight paths use this same validation logic.

## Non-Goals

- Native fork API (`native fork` runtime behavior) is out of scope.
- Avoid changing public semantics outside this hardening scope.
- Do not add implicit fallback behavior for unsupported capability branches.

## Quality and Safety Standards

- Swift 6.2 and strict concurrency discipline.
- Preserve `Sendable` correctness and typed error models.
- Deterministic ordering for all hash/handoff comparisons.
- Structured logging only for critical state transitions.

## Hard Prohibitions

- No speculative APIs without explicit "assumption + discovery task."
- No generic catch-all error paths in typed contract surfaces.
- No silent fallback when a capability is unsupported.
- No partial commits on failed external write batches.

## Required Deliverables

1. Code changes for all 8 contract areas.
2. Unit + integration + determinism tests with concrete assertions.
3. Docs updates that define API signatures and error semantics.
4. Evidence artifact with:
   - targeted test commands,
   - hash/replay evidence for determinism,
   - remaining risks and mitigations.

## Output Schema (You must return in this exact shape)

Return exactly these sections, in order, with no extra prose:

1. `Assumptions`  
   - include only what is unverifiable from the listed source-of-truth files.  
   - label any uncertain items as `High Risk`.
2. `Observed Facts`  
   - list concise, file-level evidence you are relying on (symbol + behavior).
3. `Implementation Plan`  
   - 8 numbered items mapped to the Contract Areas.
   - for each item include file edits and acceptance criteria.
4. `Test Plan`  
   - unit tests, integration tests, determinism tests.
   - include exact commands to run.
5. `Risk Register`  
   - race, replay compatibility, and schema migration risks.
6. `Evidence Checklist`  
   - explicit pass/fail outcomes.

## Verification Language (for each contract area)

For every contract area, include:
- expected behavior,
- success criteria,
- failure criteria,
- typed error mapping strategy.

## Style Expectations

- Keep changes minimal and reviewable.
- Use deterministic sorting helpers where order affects hashes.
- Prefer explicit enums/types over stringly-typed payload paths.
- Preserve existing control flow when possible; do not rewrite unrelated modules.

## Suggested Internal Sequence

1. Capture current state/behavior snapshots from observed facts.
2. Implement contract area in the narrowest dependency slice.
3. Add/adjust tests immediately for the new contract boundary.
4. Validate no regressions in existing event stream and tool-call behavior.
5. Extend replay/hash checks last, after contract boundaries are stable.
