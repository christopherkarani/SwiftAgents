# AgentActor Macro Rename Plan

Date: 2026-02-01

## Goal

Rename the public macro from `@Agent` to `@AgentActor` to unblock introducing a unified runtime type named `Agent`, and update tests/docs to match.

## Scope

- Rename macro declarations in `Sources/Swarm/Macros/MacroDeclarations.swift`.
- Update macro diagnostics/docs in `Sources/SwarmMacros/AgentMacro.swift`.
- Update macro tests in `Tests/SwarmMacrosTests/*`.
- Update docs referencing `@Agent` (README/CLAUDE/MIGRATION_GUIDE/etc).

## Constraints

- Do **not** retain a `public macro Agent` alias (it would still collide with a future `public actor Agent`).
- Keep macro expansion behavior unchanged (only rename the public attribute).
- Use Swift Testing; update expected diagnostics as needed.

## Plan

1) **Rename macro declarations**
   - Replace `public macro Agent(...)` with `public macro AgentActor(...)` (both overloads).
   - Update doc comments/examples to use `@AgentActor`.

2) **Update macro implementation docs/diagnostics**
   - Update `Sources/SwarmMacros/AgentMacro.swift` comments and error messages to reference `@AgentActor`.

3) **Update tests**
   - Update macro registry in `AgentMacroTests` to `AgentActor`.
   - Update `@Agent` usages and expected diagnostics to `@AgentActor`.
   - Update macro integration test comments/strings for accuracy.

4) **Update docs**
   - Replace `@Agent` references in README/CLAUDE/MIGRATION_GUIDE/other docs with `@AgentActor`.

5) **Validate**
   - Run `swift test`.

## Acceptance Criteria

- `@AgentActor` is the only public macro exposed in Swarm (no `@Agent`).
- Macro behavior is unchanged; only the attribute name changes.
- All tests pass (`swift test`).
- Docs/examples show `@AgentActor`.

