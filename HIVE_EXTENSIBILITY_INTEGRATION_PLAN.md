# HiveSwarm Extensibility Integration Plan (Colony Compatibility, No API Breaks)

## Objective
Complete HiveSwarm integration of Colony-style extensibility points as **generic Swarm hooks** so Colony can use HiveSwarm directly and no longer require `Sources/Colony/ColonyAgent.swift` for this behavior.

## Non-Negotiable Constraints
- Preserve backwards compatibility for all existing public APIs.
- Keep default behavior identical when hooks are not provided.
- Add no Colony-specific types, logic, or imports to Swarm modules.
- Keep changes minimal and limited to requested files.
- Build must pass with:

```bash
cd /Users/chriskarani/CodingProjects/AIStack/Swarm && swift build
```

## Required Files

### Primary edit targets
1. `Sources/HiveSwarm/HiveAgents.swift`
2. `Sources/HiveSwarm/HiveBackedAgent.swift`
3. `Sources/HiveSwarm/CHANGESET.md` (new)

### Read-only context targets
1. `Sources/HiveSwarm/SwarmToolRegistry.swift`
2. `Sources/Swarm/Core/RunHooks.swift`
3. `Sources/Swarm/Core/AgentConfiguration.swift`
4. `Tests/HiveSwarmTests/HiveSwarmTests.swift` (if present)
5. `Sources/Colony/ColonyAgent.swift`
6. `Sources/Colony/ColonyAgentFactory.swift`

## Extension Points to Finalize
The following four extensibility hooks must exist and be fully wired as generic mechanisms:

1. `HiveAgentsPreModelHook`
2. `HiveAgentsToolProvider` (`@Sendable () async -> [HiveToolDefinition]`)
3. `HiveAgentsMessageIDFactory`
4. `HiveAgentsToolResultTransformer`

## Detailed Execution Plan

## Phase 1: Baseline API and Behavior Audit
- Read each required file once.
- Confirm current partial state in `HiveAgents.swift` and identify missing hook plumbing.
- Record existing signatures for:
  - `HiveAgents.makeToolUsingChatAgent(...)`
  - `HiveBackedAgent` public initializers/convenience initializers
- Confirm current error semantics around model-client/tool-registry availability.
- Confirm where assistant messages are created and where IDs are currently generated.

### Phase 1 acceptance
- A concrete map exists from each hook to exact runtime invocation points.
- All public initializer/function signatures that must remain stable are identified.

## Phase 2: Complete `HiveAgents.swift` Hook Wiring

### 2.1 Signature and defaults
- Ensure `makeToolUsingChatAgent(...)` exposes optional parameters for all four hook points.
- Ensure defaults preserve existing behavior exactly:
  - pre-model hook default: pass-through/no-op behavior
  - tool provider default: current static tool behavior
  - message ID factory default: existing message ID generation mechanism
  - tool result transformer default: identity transform/no mutation

### 2.2 Runtime execution order guarantees
- Ensure pre-model hook executes **before model input persistence**.
- Ensure model node resolves tools dynamically by calling `toolProvider` **per loop iteration**.
- Ensure tool execution node applies `toolResultTransformer` **before publishing tool output**.
- Ensure assistant message creation path uses `messageIDFactory` consistently.

### 2.3 Error-path correctness
- Review `toolProvider` + `toolRegistry` logic for regression.
- Preserve expected thrown error when model client is unavailable.
- Avoid changing existing error types/messages unless necessary for correctness.

### 2.4 Schema compatibility
- Keep existing schema stable where possible.
- Introduce schema parameterization only if hook data flow requires it.
- Prefer additive, optional shape changes over structural breaks.

### Phase 2 acceptance
- All four hooks are injected and executed at the right graph stages.
- Default call path remains behaviorally unchanged.
- Error path remains compatible and deterministic.

## Phase 3: Update `HiveBackedAgent.swift` (API-Compatible Wiring)

### 3.1 Initializer strategy
- Add new initializer overloads or optional parameters to accept hook implementations.
- Keep existing initializers intact for current callers.
- Ensure call sites not using hooks compile without any code changes.

### 3.2 Forwarding strategy
- Wire hook params through runtime creation into `HiveAgents.makeToolUsingChatAgent(...)`.
- Ensure forwarding is explicit and uses safe defaults when omitted.

### Phase 3 acceptance
- Existing `HiveBackedAgent` usage compiles unchanged.
- New hooks are usable from `HiveBackedAgent` API surface.

## Phase 4: Add `Sources/HiveSwarm/CHANGESET.md`
Document each extension point with:
- Exact signature/protocol/typealias.
- Default behavior.
- Short usage snippet.
- Notes on intended generic use.

Include Colony only as a **consumer example** (e.g., custom message IDs, dynamic tool injection), not as Swarm implementation detail.

### Phase 4 acceptance
- Document is complete, concise, and implementation-accurate.
- No Colony coupling language that implies Swarm-side Colony logic.

## Phase 5: Verification
Run exactly:

```bash
cd /Users/chriskarani/CodingProjects/AIStack/Swarm && swift build
```

Capture:
- build exit status
- warnings/errors (if any)
- confirmation no new failures introduced by edits

### Phase 5 acceptance
- Build succeeds.

## Final Acceptance Checklist
- [ ] `swift build` succeeds.
- [ ] Existing `HiveBackedAgent` call patterns still compile.
- [ ] New hook types are visible in public API.
- [ ] No `Colony` type/import/reference appears in Swarm source.
- [ ] Defaults preserve existing behavior when hooks are omitted.
- [ ] `CHANGESET.md` documents all four hooks with examples.

## Risk Register and Mitigations

### Risk 1: Silent behavior drift due to default hook behavior
- Mitigation: implement explicit no-op/identity defaults mirroring old code path.

### Risk 2: API ambiguity from initializer overloads
- Mitigation: prefer additive optional parameters with defaults where possible; if overloads are needed, keep signatures unambiguous.

### Risk 3: Error-path regression in missing model-client branch
- Mitigation: preserve existing throw path and guard ordering; validate during code review before build step.

### Risk 4: Accidental Colony coupling
- Mitigation: search touched Swarm files for `Colony` references before handoff and remove any accidental linkage.

## Expected Deliverables
1. Updated `Sources/HiveSwarm/HiveAgents.swift` with complete hook plumbing and safe defaults.
2. Updated `Sources/HiveSwarm/HiveBackedAgent.swift` with non-breaking hook forwarding APIs.
3. New `Sources/HiveSwarm/CHANGESET.md` documenting extension points.
4. Build verification result from exact command.
5. Handoff summary with:
   - per-file changes
   - exact signature changes
   - build result
   - edge cases handled

## Out of Scope
- Refactoring unrelated Swarm modules.
- Introducing new Colony abstractions into Swarm.
- Behavioral redesign beyond required extensibility points.
- Broad test rewrites unless directly required by compile or public API integrity.

## Implementation Sequence (Strict)
1. Read required files once.
2. Edit `HiveAgents.swift`.
3. Edit `HiveBackedAgent.swift`.
4. Add `CHANGESET.md`.
5. Run `swift build` exactly as requested.
6. Perform acceptance checks and deliver summary.
