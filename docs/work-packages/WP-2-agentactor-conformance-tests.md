Prompt:
Add compile-time and behavioral tests that prove `@AgentActor`-generated actors truly conform to `AgentRuntime` and can be used like other runtime agents.

Goal:
Create failing tests (with current code) that pass once the macro is corrected.

Task Breakdown:
1. Add a Swift Testing suite under `Tests/SwiftAgentsTests/` that:
   - Declares an `@AgentActor` actor with a `process(_:)` method.
   - Verifies it can be used as `any AgentRuntime`.
   - Calls `run(_:, session:, hooks:)` and `stream(_:, session:, hooks:)` successfully.
2. Add a second test exercising the generated `Builder` (if enabled):
   - Bridged typed tools (`Tool` → `AnyJSONTool`) via builder overloads.
3. Keep tests deterministic; use an `InMemorySession` when needed.

Expected Output:
- New test file(s) under `Tests/SwiftAgentsTests/` that fail to compile/run before WP-3.

Constraints:
- Use Swift Testing (`import Testing`) for new tests.
- No network calls; no external dependencies.

