# Hive -> Swarm Support Hardening (Non-Fork) — Execution Prompt

You are acting as a principal Swift engineer in the Hive repository.

## Mission
Implement the Hive runtime features required to make Swarm integration production-grade, deterministic, and contract-safe, excluding fork support (already in progress elsewhere).

## Plan Reference (absolute path)
`/Users/chriskarani/CodingProjects/AIStack/Swarm/docs/plans/hive-swarm-nonfork-implementation-plan.md`

Use that plan as the implementation source of truth.

## Constraints
- Swift 6.2, strict concurrency, `Sendable` correctness.
- TDD required: failing tests first, then minimal implementation, then refactor.
- Deterministic behavior is mandatory.
- No silent fallback for unsupported features or invalid options.
- Typed errors for all contract failures.
- No SwiftAgents references.
- Do not implement fork in this task.

## Scope (In)
Implement all of the following in Hive runtime/core APIs:

1. First-class typed state snapshot API (`getState`)
2. Checkpoint capability discovery / contract (query support and typed unsupported)
3. Deterministic transcript export + hashing utility
4. Explicit cancellation semantics when cancellation races with checkpoint persistence
5. Strong interrupt/resume contracts (pending interrupt and mismatch behavior)
6. External writes validation + atomicity guarantees
7. Stable event schema versioning for replay compatibility
8. Run options preflight validator API (typed fail-fast)

## Scope (Out)
- Native `fork` runtime API and implementation (already being handled separately)

---

## Required Feature Details

### 1) Typed `getState` API
Add runtime state read APIs that are stable and explicit:
- `getState(threadID:) async throws -> HiveRuntimeStateSnapshot<Schema>?`
- Snapshot must include at minimum:
  - thread ID, run ID
  - step index
  - interruption metadata (if present)
  - checkpoint ID (if present)
  - global channel values (or hashes + optional typed projection)
  - frontier summary (stable representation suitable for deterministic comparisons)
- Define clear null behavior: missing thread returns `nil`, not error.

Acceptance:
- Snapshot is deterministic for same state.
- No schema leakage via untyped/`Any` payloads unless explicitly marked debug-only.

### 2) Checkpoint Capability Contract
Introduce explicit capability APIs to avoid runtime guesswork:
- Query support should be discoverable (e.g., capability enum/flags).
- Calling query APIs on unsupported store must throw typed `unsupported` error.
- Ensure list/load by ID paths have clear typed failures.

Acceptance:
- No silent degrade to latest-checkpoint behavior when ID lookup unsupported.
- Error typing distinguishes unsupported vs missing data.

### 3) Deterministic Transcript + Hash
Add standardized transcript export:
- Canonical event projection (stable field ordering, schema-version tagged).
- Deterministic normalization for allowed nondeterministic metadata.
- Hash utility:
  - transcript hash
  - final state hash
- Minimal structured diff utility for first mismatch.

Acceptance:
- Repeated identical seeded runs produce identical hashes.
- Mismatch report points to first divergent event/state key path.

### 4) Cancellation During Checkpoint Persistence
Define and enforce explicit outcome semantics:
- If cancellation races with checkpoint persistence, outcome must be deterministic and typed.
- Avoid ambiguous generic thrown errors.
- Preserve partial output/state semantics consistently.

Acceptance:
- Contract tests prove deterministic outcome class on repeated runs.
- Event stream clearly reflects cancellation lifecycle.

### 5) Interrupt/Resume Contract Hardening
Guarantee explicit behavior for:
- pending interrupt handling
- interrupt ID mismatch
- no interrupt to resume
- checkpoint version mismatch on resume

Acceptance:
- All resume failure classes are typed and tested.
- No implicit continuation without valid interrupt context.

### 6) External Writes Validation + Atomicity
Harden `applyExternalWrites` semantics:
- Validate channel existence, scope correctness, and payload shape.
- Reject malformed/unknown/task-local-mismatch writes.
- Enforce all-or-nothing commit behavior.
- Preserve frontier + step index semantics.

Acceptance:
- Negative tests confirm no partial commit on invalid write batches.
- Deterministic event emission for successful external write application.

### 7) Event Schema Versioning
Introduce explicit event schema version marker:
- Each event/transcript should carry schema version (or stream-level metadata).
- Versioning strategy must support replay compatibility checks across releases.

Acceptance:
- Consumers can detect incompatible event schema versions.
- Replay utilities fail typed when version incompatibility is detected.

### 8) Run Options Preflight Validation API
Add explicit options validation entrypoint:
- `validateRunOptions(_:) throws`
- Typed error granularity:
  - invalid bounds
  - unsupported combinations
  - missing required runtime components (e.g., store for checkpoint policies)
- Preflight can be used before run/resume/external writes.

Acceptance:
- Runtime paths use shared validation logic.
- No hidden clamping or implicit conversion in critical options.

---

## Test Requirements (Mandatory)

### Unit
- state snapshot shape and determinism
- capability detection and unsupported-path errors
- option preflight validation (valid, invalid, unsupported combinations)
- event schema version markers and compatibility checks
- transcript canonicalization + hashing

### Integration
- run happy path with state snapshot assertions
- interrupt/resume happy and mismatch/failure paths
- cancel during checkpoint save
- external writes valid + invalid + atomicity
- checkpoint query supported/unsupported behaviors
- streaming mode variants and event ordering

### Determinism/Soak
- seeded orchestration workload with:
  - interruptions/resumes
  - periodic external writes
  - cancellation injection points
- run repeated trials and compare:
  - transcript hash
  - final state hash
- fail on divergence with minimal first-diff output

---

## CI Expectations
Add stable invocation paths:
- focused contract suite job (fast gate)
- determinism suite job (repeat runs, required gate)
- keep full suite job alongside these

---

## Deliverables
1. Runtime API changes + implementation
2. Tests (unit/integration/determinism)
3. concise docs update for:
   - new APIs
   - guarantees
   - typed error semantics
4. execution evidence:
   - targeted test command + result
   - full suite command + result
   - determinism hash evidence
5. ranked remaining backlog:
   - severity
   - user impact
   - implementation complexity
   - recommended order

## Quality Bar
- Production-grade semantics.
- Deterministic and replay-safe.
- No silent data loss.
- No behavior regressions.
- Explicit typed contracts over implicit behavior.
