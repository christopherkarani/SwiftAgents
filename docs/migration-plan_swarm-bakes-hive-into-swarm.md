# Swarm + Hive Migration Plan (Non-Optional, Single-Substrate)

## Executive summary (<=10 lines)
- Goal: make Hive the mandatory execution runtime for all Swarm orchestration while keeping Swarm the product layer for agents, memory, tools, prompts, and RAG/tooling.
- Current code already has a working Hive execution path, but production remains bifurcated with legacy non-Hive loops.
- `Sources/Swarm/HiveSwarm` is the current integration seam and should be absorbed into internal Swarm modules.
- `Package.swift` already requires `HiveCore`; `HiveSwarmTests` is an added test target, not a production optionality switch.
- Tooling surfaces are duplicated in `SwarmToolRegistry` bridge + typed `ToolExecutionEngine` stack.
- RAG/memory/tooling are already in Swarm-owned `Sources/Swarm/Integration/Wax/*` and should remain there.
- Target state: one canonical orchestration boundary, typed tool bridge, single event stream, single policy/failure model.
- Phase 0/1 can ship with low behavior impact; full removal of legacy execution path is high impact.
- Determinism, Sendable, actor isolation, and cancellation safety are the hard constraints for every phase.
- No additional abstractions; remove layers, not add them.

---

## A) Current-state assessment

### A1) What already works
1. `Package.swift` hard-depends on `Hive` (`HiveCore`) for `Swarm` production target.
2. `Sources/Swarm/Orchestration/OrchestrationHiveEngine.swift` is a complete Hive execution runtime path with schema/channels, checkpoints, step hooks, and event hooks.
3. Swarm already owns memory/RAG integration in `Sources/Swarm/Integration/Wax/*`.
4. Tooling contracts are Swarm-owned and broad: `Sources/Swarm/Tools/Tool.swift`, `ToolExecutionEngine`, `ToolExecutionResult`, `ToolBridging`, `ParallelToolExecutor`.
5. Resilience and observability foundations are present in `Sources/Swarm/Resilience/*` and `Sources/Swarm/Observability/*`.
6. `Sources/Swarm/Tools/HiveTool?` style bridge artifacts are intentionally minimal and do not redefine full business logic.

### A2) What is duplicated
1. Runtime paths: canonical Hive engine exists, but ReAct/Plan-and-Execute/runner/supervisor/orchestrator flows still have local execution logic.
2. Tooling: bridge path uses JSON conversion in `Sources/Swarm/HiveSwarm/SwarmToolRegistry.swift`; typed execution path exists separately.
3. Error/cancellation/retry semantics are represented in both resilience modules and Hive-specific bridge modules.
4. Hook/event handling has multiple call paths and no single canonical ordering policy.

### A3) What is brittle
1. Hook fan-out and concurrency can produce non-deterministic ordering in some paths.
2. JSON bridge serialization for tool invocation can conceal argument/result contract drift.
3. Checkpoint/retry semantics differ by entrypoint during failure and interrupt handoff.
4. Dedicated Hive test target reinforces conceptual separation and complicates migration.

### A4) False-positive audit (important before implementation)
1. The requested top-level paths `Sources/HiveSwarm/*` and `Tests/HiveSwarmTests/*` exist only under the AIStack repo root, not `/Users/chriskarani/CodingProjects/Swarm`.
2. `Sources/Swarm/HiveSwarm` is the active seam, not an external product package.
3. There is no separate `ToolRegistry.swift`; equivalent execution surface is `ToolExecutionEngine` + `ToolExecutionResult` stack.
4. `HiveSwarmTests` is currently always included in `packageTargets` when appended, not behind compile flags.
5. No evidence that all hooks/observability currently run through one deterministic event bus yet.

### A5) Current integration seam inventory
- **Non-Hive paths still present**: legacy orchestration/agent code in `Sources/Swarm/Agents/*` and some orchestration orchestration call graphs.
- **Hive checkpoints/events used**: `OrchestrationHiveEngine` + checkpoint options + hook mapping.
- **Cross-module invocation**: tool calls cross into `Sources/Swarm/HiveSwarm/SwarmToolRegistry.swift`.
- **Handoff metadata**: created/consumed across `Orchestrator`, `SupervisorAgent`, `AgentRouter`, `SwarmRunner`.
- **Failure/cancel semantics divergence**: policy handling/interrupt flow split between general resilience and Hive bridge.

---

## B) Target architecture

### B1) Source-of-truth mapping: Swarm concept -> Hive primitive
- Swarm agent orchestration intent -> Hive graph schema + compiled graph execution.
- Swarm runtime context and agent contract -> `HiveRuntime` + `HiveRunOptions` via `OrchestrationHiveEngine`.
- Handoff routing and routing metadata -> Hive task transitions + deterministic handoff nodes.
- Tool discovery/invocation -> Swarm `ToolExecutionEngine`/`ToolExecutionResult` typed contracts invoked from Hive tool adapter.
- Memory/RAG prompt enrichment -> `Sources/Swarm/Integration/Wax` pre/post orchestration boundaries.
- Retry/cancel policies -> one `Resilience` policy layer feeding all runtime boundaries.
- Traces/stream/events -> one Swarm event envelope from one Hive event adapter.
- Checkpoint storage -> Hive checkpoint policy using Swarm checkpoint descriptors.

### B2) Event/streaming flow and deterministic boundaries
1. Build one canonical runtime graph from `OrchestrationBuilder`/`Agent` configs.
2. Execute exclusively through `OrchestrationHiveEngine`.
3. Normalize Hive events via one adapter into one canonical Swarm stream/event set.
4. Hook consumers receive events from that canonical stream only.
5. Resume uses checkpoint token only; no alternate “silent continuation state”.
6. Checkpoint writes are boundary events with explicit causal ordering.

### B3) Error model mapping
- Single envelope categories: `configuration`, `tool`, `runtime`, `handoff`, `checkpoint`, `interrupt`, `cancellation`, `retry`.
- Preserve root-cause details while keeping stable top-level error type for callers.
- Retry/recovery logic is centralized; no duplicate loops.
- Interrupt + resume errors are explicit, serialized in checkpoint metadata.

### B4) Where RAG/tooling should live
- Keep all retrieval/search integration in Swarm-owned modules:
  - `Sources/Swarm/Integration/Wax/*`
  - `Sources/Swarm/Tools/*`
- Hive path contains only orchestration and binding glue.

---

## C) Detailed phased plan (ordered by risk/impact)

### 1. Canonicalize core dependencies and package/API surface
- Validate package dependency graph and lock down required Hive runtime semantics.
- Remove ambiguity around “optional” by documenting and then implementing non-optional `HiveCore` usage.
- Fold `HiveSwarm` test logic into `SwarmTests` and remove dedicated target.

### 2. Merge HiveSwarm integration into Swarm target and remove public optionality
- Move bridge runtime files into `Sources/Swarm/Integration/Hive/*`.
- Keep reexports/compatibility only as temporary aliases where necessary.
- Update module-level references from `Sources/Swarm/HiveSwarm` path semantics.

### 3. Make Hive execution path canonical for agents and orchestration
- Refactor non-Hive execution entrypoints to call canonical Hive execution gateway.
- Keep behavior parity: same external event surface and output shape in first iteration.
- Remove legacy execution fallback paths in default builds.

### 4. Unify tools/tooling bridge and RAG integration as Swarm-owned tool contracts
- Make `ToolExecutionEngine` the single path for execution.
- Rewrite `SwarmToolRegistry` adapter to use typed arguments/results and minimal conversion.
- Keep any compatibility conversion only as transitional shim.

### 5. Standardize retry/cancel/interrupt/resume behavior
- Introduce one policy decision boundary for retries and one cancellation propagation policy.
- Normalize interrupt tokening and resume descriptors so every path resumes identically.

### 6. Unify observability/events/hooks
- Introduce one event-to-hook translation table.
- Make hook callback order deterministic at stream boundary.
- Enforce complete lifecycle event coverage for streaming, tool, checkpoint, handoff, and completion.

### 7. Public API migration and deprecation policy
- Publish compatibility shims briefly, then deprecate and remove.
- Explicitly note migration window and compile-time replacement guidance.

### 8. Failure, cancellation, and resume test matrix
- Add/adjust tests before final deprecation removal.
- Stress/resume/cancel matrix across normal, retry, interrupt, and handoff cases.

---

## D) File-level plan

### D1) Exact file moves
- `Sources/Swarm/HiveSwarm/SwarmToolRegistry.swift` -> `Sources/Swarm/Integration/Hive/SwarmToolRegistry.swift`
- `Sources/Swarm/HiveSwarm/HiveBackedAgent.swift` -> `Sources/Swarm/Integration/Hive/HiveBackedAgent.swift`
- `Sources/Swarm/HiveSwarm/HiveAgents.swift` -> `Sources/Swarm/Integration/Hive/HiveAgents.swift`
- `Sources/Swarm/HiveSwarm/RetryPolicyBridge.swift` -> `Sources/Swarm/Resilience/HiveRetryPolicyBridge.swift`
- `Sources/Swarm/HiveSwarm/HiveCodableJSONCodec.swift` -> `Sources/Swarm/Integration/Hive/HiveCodableJSONCodec.swift`
- `Sources/Swarm/HiveSwarm/HiveCoreReexports.swift` -> `Sources/Swarm/Integration/Hive/HiveCore.swift` (compat shim) or delete after migration.
- `Tests/HiveSwarmTests/HiveAgentsTests.swift` -> `Tests/SwarmTests/HiveIntegration/HiveAgentsTests.swift`
- `Tests/HiveSwarmTests/HiveBackedAgentStreamingTests.swift` -> `Tests/SwarmTests/HiveIntegration/HiveBackedAgentStreamingTests.swift`
- `Tests/HiveSwarmTests/ModelRouterTests.swift` -> `Tests/SwarmTests/HiveIntegration/ModelRouterTests.swift`
- `Tests/HiveSwarmTests/RetryPolicyBridgeTests.swift` -> `Tests/SwarmTests/HiveIntegration/RetryPolicyBridgeTests.swift`

### D2) Exact file edits by file
- `Package.swift`
  - remove `testTarget(name: "HiveSwarmTests")` and keep all moved Hive tests under `SwarmTests`.
  - preserve `HiveCore` dependency under `swarmDependencies`.
- `Sources/Swarm/Orchestration/OrchestrationHiveEngine.swift`
  - formalize canonical event adapter + deterministic hook boundary.
- `Sources/Swarm/Orchestration/OrchestrationBuilder.swift`, `Orchestrator.swift`, `SwarmRunner.swift`, `SupervisorAgent.swift`, `AgentRouter.swift`
  - route all execution into the canonical Hive gateway; remove duplicated execution branches.
- `Sources/Swarm/Agents/ReActAgent.swift`, `PlanAndExecuteAgent.swift`, `LoopAgent.swift`
  - replace local run loops where feasible with canonical builder+runtime invocation.
- `Sources/Swarm/Tools/SwarmToolRegistry.swift` equivalent layer (ToolExecutionEngine stack)
  - add/verify typed execution contract for Hive adapters.
- `Sources/Swarm/Tools/ToolBridging.swift`
  - align conversion rules with typed tool adapter and checkpoint-safe payload handling.
- `Sources/Swarm/Resilience/RetryPolicy.swift`, `ResilientAgent.swift`, `FallbackChain.swift`
  - consume one policy source; eliminate duplicated policy conversion in bridge layer.
- `Sources/Swarm/Observability/AgentTracer.swift`, `Tracing*.swift`, `TraceEvent.swift`
  - lock one event schema and deterministic lifecycle spans.

### D3) Target/module declarations
- `Swarm` target will include all integration runtime files post-move.
- `SwarmTests` includes all Hive integration tests after relocation.
- No separate runtime target/module for HiveSwarm.

### D4) Compile dependency impact
- Medium-high: import cleanups in any references to `Sources/Swarm/HiveSwarm` names.
- Medium: moved types changed by namespace may require compatibility aliases in transitional phase.
- Low: internal path reorganization under single package target.

### D5) Risk per change
- Very high: canonical execution swap (behavioral parity).
- High: tool schema typing conversion and compatibility.
- High: hook ordering change affecting consumer assumptions.
- Medium: API deprecation/removal timing.
- Low: moving tests and docs.

---

## E) Validation plan

### E1) Matrix by feature with confidence thresholds
1. Canonical execution parity: 95% before phase-3 completion, 99% before removal of legacy path.
2. Tooling parity: 100% tool contract tests in migrated path; zero JSON-only decode regressions where typed path is enforced.
3. Resume/interrupt correctness: deterministic state recovery over 100 resumes.
4. Retry/cancel semantics: single retry loop observed under failure fuzz tests.
5. Hook/order determinism: invariant snapshot of event ordering across 100 identical runs.
6. Observability completeness: every lifecycle event is emitted (start/step/tool/interruption/checkpoint/error/complete).

### E2) Required new/updated tests
- `Tests/SwarmTests/HiveIntegration/HiveCanonicalExecutionParityTests.swift`
- `Tests/SwarmTests/HiveIntegration/HiveToolTypedBridgeTests.swift`
- `Tests/SwarmTests/HiveIntegration/HiveRetryInterruptCancelTests.swift`
- `Tests/SwarmTests/HiveIntegration/HiveCheckpointResumeTests.swift`
- `Tests/SwarmTests/HiveIntegration/HiveHookOrderingTests.swift`
- `Tests/SwarmTests/Compatibility/ApiMigrationTests.swift`

### E3) Acceptance criteria
- All public agent runs execute through Hive runtime path.
- One schema/event contract is used for all stream consumers.
- Tool execution no longer relies on JSON-only conversion as the only path.
- Checkpoint boundaries and cancellation behavior are deterministic and tested.
- No non-trivial `HiveSwarm` public seam remains in runtime architecture docs.

---

## F) Rollout plan

### F1) Backwards compatibility and phasing
1. Phase A (safe): keep compatibility aliases + docs for two releases.
2. Phase B: emit deprecation warnings for old `HiveSwarm` entrypoints.
3. Phase C: remove aliases; keep migration guide and compile-time remediation.

### F2) What ships first without semantic change
- `Package.swift` cleanup and test target consolidation.
- Compatibility aliases for moved symbols.
- Event naming docs + deterministic ordering assertions only (disabled by default if needed).

### F3) What requires breaking-change handling
- Removal of legacy non-Hive execution path.
- Public type moves from `Sources/Swarm/HiveSwarm` names.
- Tool path serialization behavior changes if strict typed contracts replace permissive JSON round-tripping.

---

## G) Open questions & non-goals

### Open questions
1. Is temporary `JSON` conversion allowed for one compatibility release or should it be removed immediately?
2. Do we need strict total event ordering or causal ordering at public API level?
3. Which external integrations depend on direct `Sources/Swarm/HiveSwarm/*` type names?
4. Should hook ordering be globally total or per-step total?

### Non-goals
- New runtime abstractions beyond the existing Hive-Swarm bridge.
- Changes to `Conduit`, `Wax` internals, or provider-specific logic.
- New UI/UX or API surfaces beyond execution/runtime migration.

## H) Provenance and false-positive controls
- Repository files read for plan basis:
  - `Package.swift`
  - `Sources/Swarm/Orchestration/*`
  - `Sources/Swarm/Core/*`
  - `Sources/Swarm/Tools/*`
  - `Sources/Swarm/Integration/Wax/*`
  - `Sources/Swarm/Observability/*`
  - `Sources/Swarm/Resilience/*`
  - `Sources/Swarm/HiveSwarm/*`
  - `Tests/HiveSwarmTests/*`
  - `CLAUDE.md`, `HIVE_V1_PLAN.md`, `HIVE_EXTENSIBILITY_INTEGRATION_PLAN.md`
- False positives from prior drafts were corrected in A4 and are now documented explicitly.
