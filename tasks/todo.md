# Task Plan (Framework Mission-Critical Audit) — 2026-02-27
- [x] Review prior automation memory and current repository state.
- [x] Run a focused parallel audit for correctness/safety gaps in `Sources/Swarm`.
- [x] Convert each confirmed issue into a failing Swift Testing test first (TDD).
- [x] Implement minimal production-grade fixes for each failing test.
- [ ] Re-run targeted tests, then full `swift build` and `swift test`. (blocked: no space left on device)
- [ ] Commit with detailed message, push branch, and open/update PR.
- [x] Append review summary and residual risks below.

## Review Notes
- Fixed:
- Path traversal hardening for file checkpoint persistence.
- Deadlock prevention when `ParallelGroup.maxConcurrency <= 0`.
- Retry and rate-limiter invalid delay/rate sanitization.
- Cancellation semantics preservation in `ToolExecutionEngine` with `stopOnToolError`.
- Encoded traversal rejection in `HTTPMCPServer.readResource`.
- Runtime identity consistency cleanup by removing local `areSameRuntime` duplicates.
- Added regression tests for each area listed above.
- Verification blocker:
- `swift test` and compilation are currently blocked by filesystem exhaustion (`No space left on device`) before tests execute.
