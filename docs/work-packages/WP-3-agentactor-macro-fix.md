Prompt:
Fix the `@AgentActor` macro to generate correct `AgentRuntime` conformance and ergonomic builders for coding agents.

Goal:
After applying the macro, user code should compile with `import Swarm` only and the generated actor should behave like a first-class runtime agent.

Task Breakdown:
1. Update `Sources/SwarmMacros/AgentMacro.swift` to generate:
   - `nonisolated public let tools: [any AnyJSONTool]` (unless user already defines `tools`)
   - `nonisolated public let instructions: String`
   - `nonisolated public let configuration: AgentConfiguration`
   - Optional stored values: `_memory`, `_inferenceProvider`, `_tracer` with environment fallback (or omit and rely on protocol defaults)
2. Generate required methods with correct signatures:
   - `run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult`
   - `nonisolated stream(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) -> AsyncThrowingStream<AgentEvent, Error>`
   - `cancel() async`
3. Make `run` integrate with:
   - session persistence (`MemoryMessage.user` + `.assistant`)
   - environment fallback (`AgentEnvironmentValues.current`) for memory/provider/tracer
   - hooks (`onAgentStart/onAgentEnd/onError`)
4. Update the generated `Builder`:
   - Default `_instructions` to the macro-provided default instructions literal.
   - Tools setters that accept:
     - `[any AnyJSONTool]`
     - `[T: Tool]` (bridged via `AnyJSONToolAdapter`)
     - `addTool(_ tool: any AnyJSONTool)`
     - `addTool<T: Tool>(_ tool: T)`
5. Update MacroDeclarations docs/examples to match the corrected surface.
6. Update macro snapshot tests as needed.

Expected Output:
- Edits to `Sources/SwarmMacros/AgentMacro.swift`
- Edits to `Sources/Swarm/Macros/MacroDeclarations.swift`
- Updated macro tests under `Tests/SwarmMacrosTests/`

Constraints:
- Preserve user-provided members (don’t duplicate existing `tools`, `init`, etc.).
- No `Any`, no runtime casting for tool bridging.

