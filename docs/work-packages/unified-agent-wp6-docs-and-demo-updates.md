Prompt:
Implement Phase 6 of `docs/plans/UNIFIED_AGENT_LONG_TERM_API_PLAN.md` (do not edit the plan doc): update docs, README, and the demo/playground code so the "preferred path" presents unified runtime `Agent` as the default entry point and `AgentBlueprint` as the SwiftUI-style workflow DSL. Legacy loop DSL should be clearly marked deprecated (or removed from preferred examples).

Goal:
Align documentation and demo code with the new long-term API direction:
- Runtime default: `Agent` (unified runtime actor)
- Workflow DSL: `AgentBlueprint`
- Legacy loop DSL (`AgentLoopDefinition` + `Generate/Relay`) is deprecated and not presented as the recommended approach.

Task Breakdown:
1) README: update preferred examples to compile against the new API:
   - Edit `README.md`:
     - Replace `struct X: Agent { ... }` legacy DSL examples with `struct X: AgentBlueprint { ... }`.
     - Replace runtime constructions of legacy agents (where appropriate) with `Agent(...)` and explicit strategy selection when needed.
2) Docs: update "agents" and "dsl" docs to reflect the new preferred path:
   - Likely files:
     - `docs/agents.md`
     - `docs/dsl.md`
     - `docs/orchestration.md`
     - `docs/Handoffs.md`
     - `docs/BEST_PRACTICES.md`
     - `docs/MIGRATION_GUIDE.md` (add/adjust migration notes for legacy loop DSL and legacy runtime agents)
   - Requirements:
     - Any code block that uses the legacy loop DSL should be either removed from the "preferred" sections or explicitly labeled "Deprecated".
     - Show at least one example where an `AgentBlueprint` embeds a runtime `Agent` step (replacing `Generate/Relay` mental model).
3) Demo / playground:
   - Update the demo target to compile and demonstrate the preferred APIs:
     - `Sources/SwiftAgentsDemo/AgentTest.swift`
     - `Sources/SwiftAgentsDemo/SwiftAgentsPlayground.playground/contents.xcplayground`
   - Ensure examples run without relying on non-deterministic behavior (use mock providers where possible).
4) Verify compilation of docs snippets (manual sanity pass):
   - At minimum, ensure the docs snippets are syntactically valid and match real symbol names after WP1-WP4.
   - Run `swift build` to confirm demo target compiles.

Expected Output:
- README and docs consistently present unified runtime `Agent` + `AgentBlueprint` as the primary entry points.
- Legacy loop DSL is not shown as the recommended path; when present, it is labeled deprecated with migration guidance.
- Demo/playground code compiles against the new API surface.

Constraints:
- Do NOT edit `docs/plans/UNIFIED_AGENT_LONG_TERM_API_PLAN.md`.
- Keep docs examples accurate and compilable; do not invent APIs that don't exist.
- Prefer concise snippets over verbose prose; add migration notes only where they reduce confusion.

