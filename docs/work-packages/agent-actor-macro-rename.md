Prompt:
Implement the plan in `docs/plans/AGENT_ACTOR_MACRO_RENAME_PLAN.md` by renaming the public macro attribute from `@Agent` to `@AgentActor` across declarations, implementation docs/diagnostics, tests, and documentation, while keeping macro expansion behavior unchanged.

Goal:
Deliver a clean public macro rename that unblocks a future `Agent` runtime type. Ensure `@AgentActor` is the only public macro name; remove `@Agent` entirely with no alias.

Task Breakdown:
- Update macro declarations to expose only `public macro AgentActor(...)` overloads; adjust doc comments/examples to `@AgentActor`.
- Update macro implementation diagnostics/comments to reference `@AgentActor`.
- Update macro tests and registries to use `AgentActor`; fix expected diagnostics strings.
- Update docs/examples to reference `@AgentActor`.
- Run `swift test` and fix failures.

Expected Output:
- `@AgentActor` is the only public macro name; `@Agent` is removed (no alias).
- Macro behavior is unchanged; only the attribute name changes.
- Tests pass.
- Docs/examples show `@AgentActor`.

Constraints:
- DO NOT modify the plan document.
- Use Swift Testing (not XCTest) for tests.
- Keep visibility tight; avoid introducing new public API beyond the rename.
- Do not change macro expansion behavior.

Concrete File List (likely to change):
- `Sources/SwiftAgents/Macros/MacroDeclarations.swift`
- `Sources/SwiftAgentsMacros/AgentMacro.swift`
- `Tests/SwiftAgentsMacrosTests/` (macro tests and registries)
- `README.md`
- `MIGRATION_GUIDE.md`
- `CLAUDE.md`
- `docs/` (any additional references to `@Agent`)
