Prompt:
Implement Phase 4 of `docs/plans/UNIFIED_AGENT_LONG_TERM_API_PLAN.md` (do not edit the plan doc): ensure orchestration integrates cleanly with unified runtime `Agent`, `AgentBlueprint`, and the deprecated legacy loop DSL (renamed to `AgentLoopDefinition`). Add a convenience `handoff(to blueprint:)` overload and tighten builder ergonomics where appropriate.

Goal:
Make the "happy path" orchestration story be `AgentBlueprint` + runtime `Agent` steps, while keeping legacy loop DSL integration available as a deprecated compatibility path.

Task Breakdown:
1) OrchestrationBuilder integration points:
   - Edit `Sources/SwiftAgents/Orchestration/OrchestrationBuilder.swift`:
     - Ensure `buildExpression(_ agent: any AgentRuntime)` continues to work for unified runtime `Agent`.
     - Ensure `buildExpression<B: AgentBlueprint>(_ blueprint: B)` is present (it is) and remains stable.
     - Update the legacy overload `buildExpression<A: Agent>(_ agent: A)` to the renamed protocol:
       - `buildExpression<A: AgentLoopDefinition>(_ agent: A) -> OrchestrationStep`
     - Mark the legacy overload deprecated (migration message to `AgentBlueprint` + runtime `Agent` steps).
2) Handoff ergonomics for blueprints:
   - Edit `Sources/SwiftAgents/Orchestration/HandoffBuilder.swift`:
     - Add: `public func handoff<B: AgentBlueprint>(to blueprint: B, ...) -> HandoffConfiguration<BlueprintAgent<B>>`
     - Ensure default tool name/description follow existing conventions (`handoff_to_<snake_case>` and `Hand off execution to ...`).
   - Keep the existing runtime overload `handoff<T: AgentRuntime>(to: T, ...)` unchanged.
   - Update the legacy overload `handoff<A: Agent>(to: A, ...)` to `A: AgentLoopDefinition` and deprecate it.
3) Tests for blueprint handoff:
   - Extend existing tests to cover the new overload:
     - `Tests/SwiftAgentsTests/Orchestration/HandoffConfigurationTests.swift`
     - and/or `Tests/SwiftAgentsTests/Orchestration/HandoffConfigurationTests+Builder.swift`
   - Add a small `AgentBlueprint` test blueprint and assert:
     - the returned config targets a `BlueprintAgent`,
     - the default effective tool name/description are correct,
     - and the config is `Sendable`.
4) Example ergonomics (code-level only; docs in WP6):
   - Add doc comments where needed in:
     - `Sources/SwiftAgents/Orchestration/HandoffBuilder.swift`
     - `Sources/SwiftAgents/Orchestration/OrchestrationBuilder.swift`
   - Keep examples small and compilable.

Expected Output:
- Orchestrations can embed unified runtime `Agent` directly (via `any AgentRuntime` buildExpression).
- Orchestrations can embed `AgentBlueprint` directly (existing behavior) and can create handoffs to blueprints with `handoff(to blueprint:)`.
- Legacy loop DSL values can still be used in orchestrations/handoffs, but are clearly deprecated and provide migration guidance.
- New/updated tests cover blueprint handoff ergonomics.

Constraints:
- Do NOT edit `docs/plans/UNIFIED_AGENT_LONG_TERM_API_PLAN.md`.
- Keep changes tightly scoped to orchestration/builder APIs; do not refactor agent runtime internals here.
- Use Swift Testing (`import Testing`) for new tests.

