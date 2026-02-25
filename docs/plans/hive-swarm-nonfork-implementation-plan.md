# Hive -> Swarm Support Hardening (Non-Fork) — Implementation Plan

## Summary
This plan delivers all Hive runtime hardening needed by Swarm except native fork, with strict typed contracts and deterministic replay/stability guarantees.

## Non-Goals
- Implementing native `fork` (already in progress)

## Assumptions
- Existing `HiveRuntime.run/resume/applyExternalWrites` remain primary execution entrypoints.
- Existing event stream infrastructure remains in place and will be extended, not replaced.
- Existing checkpoint store abstractions remain and gain explicit capability semantics.

---

## Phase 0 — Baseline Contract Freeze
### Goals
- Freeze current behavior and identify all ambiguous semantics.

### Tasks
1. Inventory current run/resume/cancel/external writes/state/checkpoint/event option behavior.
2. Create baseline matrix: `surface -> current behavior -> desired behavior`.
3. Tag high-risk semantics:
   - cancel/checkpoint race
   - interrupt pending/mismatch
   - external write partial-commit risk
   - event replay compatibility

### Exit Criteria
- Contract matrix complete with no unknowns.

---

## Phase 1 — Preflight + Typed Error Foundations
### Goals
- Establish strict fail-fast boundary.

### Tasks
1. Add/extend typed error taxonomy for:
   - unsupported capability
   - invalid options
   - malformed state/checkpoint
   - resume mismatch classes
2. Add `validateRunOptions(_:)` API.
3. Ensure run/resume/external writes paths use shared preflight validator.

### Tests
- Unit: option bounds, unsupported combinations, missing required components.

### Exit Criteria
- Preflight API and typed errors are production-ready and used everywhere.

---

## Phase 2 — State Snapshot + Capability Contract
### Goals
- Make state introspection explicit and stable.

### Tasks
1. Add `HiveRuntimeStateSnapshot` model.
2. Add `getState(threadID:)`.
3. Add checkpoint capability detection model (query support contract).
4. Ensure unsupported query paths throw typed unsupported errors.

### Tests
- Unit: snapshot shape and deterministic serialization.
- Integration: state exists after run; nil when thread missing; unsupported query behavior typed.

### Exit Criteria
- Swarm can reliably query runtime state and detect query capabilities.

---

## Phase 3 — Interrupt/Resume + Cancellation Semantics Hardening
### Goals
- Deterministic lifecycle behavior under stress.

### Tasks
1. Harden pending interrupt rules and mismatch checks.
2. Define deterministic cancel-during-checkpoint outcome semantics.
3. Ensure event stream captures lifecycle transitions consistently.

### Tests
- Integration:
  - valid resume
  - wrong interrupt ID
  - no interrupt to resume
  - cancel during checkpoint persistence
- Negative: version mismatch, malformed resume state.

### Exit Criteria
- Lifecycle outcomes are deterministic and typed.

---

## Phase 4 — External Writes Validation + Atomicity
### Goals
- Prevent silent corruption and partial commit states.

### Tasks
1. Validate external writes:
   - channel exists
   - scope compatibility
   - payload decode/type correctness
2. Enforce atomic application for write batches.
3. Preserve frontier and step-index semantics.

### Tests
- Integration:
  - valid external write then continuation
  - malformed write rejected
  - unknown channel rejected
  - task-local mismatch rejected
  - assert no partial commit on failure

### Exit Criteria
- External write contract is safe, typed, and atomic.

---

## Phase 5 — Event Schema Versioning + Transcript Tooling
### Goals
- Replay-safe observability and deterministic comparison.

### Tasks
1. Add event schema version marker.
2. Implement canonical transcript projection format.
3. Implement transcript hash + final state hash utilities.
4. Add first-diff structured comparator.

### Tests
- Unit: schema version compatibility checks.
- Unit: canonicalization stable ordering.
- Integration: transcript/hash generation in representative flows.

### Exit Criteria
- Deterministic transcript and state comparison utilities available and tested.

---

## Phase 6 — Determinism Soak Suite
### Goals
- Prove runtime determinism under repeated seeded workloads.

### Tasks
1. Build seeded workload generator with:
   - long-running loops
   - controlled interruptions/resumes
   - periodic external writes
   - cancellation injection points
2. Repeat same seed N times.
3. Compare transcript hash and final state hash.
4. Fail on first mismatch with minimal diff output.

### Tests
- Determinism suite integrated into test target.

### Exit Criteria
- No divergence across repeated seeded runs.

---

## Phase 7 — CI Hardening
### Goals
- Reliable PR gate for runtime semantics.

### Tasks
1. Add dedicated fast contract test invocation.
2. Add deterministic suite invocation path.
3. Keep full suite path in parallel.
4. Document commands in repo docs/CI notes.

### CI Gate Recommendation
- Required:
  - contract suite
  - determinism suite
- Also run full suite (required/advisory based on repo policy)

### Exit Criteria
- PR pipeline enforces semantic correctness and determinism reliably.

---

## Test Matrix (Condensed)

### Unit
1. run option preflight valid/invalid/unsupported combos
2. typed error mapping classes
3. capability support detection and unsupported errors
4. state snapshot deterministic projection
5. event schema version compatibility
6. transcript canonicalization + hashing

### Integration
1. run happy path
2. interrupt -> resume happy path
3. resume mismatch typed failure
4. cancel during checkpoint save deterministic outcome
5. external writes valid continuation
6. external writes invalid atomic rejection
7. getState behavior (present/missing)
8. checkpoint query behavior (supported/unsupported)
9. streaming mode and event ordering checks

### Determinism
1. repeated seeded workload: transcript hash equality
2. repeated seeded workload: final state hash equality
3. mismatch diff quality assertions

---

## Deliverables Checklist
- [ ] typed preflight + errors
- [ ] state snapshot APIs
- [ ] capability contract APIs
- [ ] lifecycle semantics hardening
- [ ] external writes validation/atomicity
- [ ] event schema versioning
- [ ] transcript/hash/diff tooling
- [ ] determinism soak suite
- [ ] CI invocation paths
- [ ] evidence summary (tests + hashes + residual risks)

---

## Ranked Backlog Template (Post-Execution)
| Rank | Item | Severity | User Impact | Complexity | Recommended Order |
|---|---|---|---|---|---|
| 1 | Cancel/checkpoint race edge behavior | High | High | Medium | Immediate |
| 2 | External writes strictness gaps | High | High | Medium | Immediate |
| 3 | Event schema compatibility migration | Medium | High | Medium | Next |
| 4 | Transcript diff ergonomics | Medium | Medium | Low | Next |
| 5 | Additional observability polish | Low | Medium | Low | Last |
