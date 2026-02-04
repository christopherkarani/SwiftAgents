Prompt:
Update documentation so coding agents (Codex/Claude Code) can adopt SwiftAgents quickly with minimal confusion.

Goal:
Make “the happy path” obvious: define tools with `@Tool`, define an agent with `@AgentActor`, wire provider/memory with `.environment`, compose with `AgentBlueprint`.

Task Breakdown:
1. Update `Sources/SwiftAgents/Macros/MacroDeclarations.swift` docs for `@AgentActor`:
   - correct tool type (`AnyJSONTool`)
   - correct run/stream signatures (session/hooks)
   - remove/replace references to non-existent `@Tools`
2. Add/adjust one doc page in `docs/` (or extend `docs/agents.md`) with a “Copy/paste for coding agents” section:
   - “minimal agent” example
   - “tool-using agent” example with `@Tool`
   - “compose agents” example with `AgentBlueprint` (`Sequential/Parallel/Router`)
3. Ensure examples compile with Swift 6.2 and align with current API names.

Expected Output:
- Updated doc comments and at least one docs page with a concrete quick-start.

Constraints:
- Keep examples minimal, deterministic, and consistent with the framework’s preferred DSL (`AgentBlueprint`).

