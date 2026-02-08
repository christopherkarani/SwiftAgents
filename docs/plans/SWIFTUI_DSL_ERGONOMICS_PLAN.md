1) Confirm targets and current behavior
- Review Router + Transform in `Sources/Swarm/Orchestration/OrchestrationBuilder.swift`.
- Review routing helpers in `Sources/Swarm/DSL/Flow/Routes.swift`.
- Review docs: `docs/dsl.md`, `docs/orchestration.md`.

2) TDD: add failing tests for Router multi-Otherwise
- Add Swift Testing cases in `Tests/SwarmTests/DSL/BreakingAPIChangesTests.swift`:
  - Multiple `Otherwise` branches run sequentially (deterministic order).
  - Single `Otherwise` still works (regression coverage).

3) Implement Router multi-Otherwise handling
- Replace `precondition` with collection of all `.otherwise` steps.
- If multiple fallbacks, wrap in `OrchestrationGroup(steps:)` (preserve order).
- Update Router doc comment to reflect multi-Otherwise support.

4) Clarify Transform intent in docs
- Update Transform doc comment (input-in, string-out).
- Update `docs/dsl.md` and `docs/orchestration.md` to distinguish:
  - `Transform` (string step)
  - `OutputTransformer` (AgentResult-level shaping).

5) Optional additive ergonomics
- Add `When(..., use:)` and `Otherwise(use:)` overloads in `Sources/Swarm/DSL/Flow/Routes.swift`
  to reduce boilerplate for common agent-only branches.

6) Documentation updates for Router DSL
- Replace “single Otherwise only” note with multi-Otherwise behavior (runs in order).
- Add a short multi-Otherwise example.
- Include `use:` overload example if added.

7) Verification
- Run `swift test --filter BreakingAPIChangesTests` (or new suite if added).
