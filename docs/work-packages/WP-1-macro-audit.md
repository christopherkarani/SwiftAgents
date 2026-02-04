Prompt:
Audit the `@AgentActor` macro against the current `AgentRuntime` protocol and identify concrete mismatches that block real-world use.

Goal:
Produce an actionable spec for the corrected macro expansion (properties, initializers, required methods, builder surface).

Task Breakdown:
1. Compare current macro-generated members in `Sources/SwiftAgentsMacros/AgentMacro.swift` against `Sources/SwiftAgents/Core/Agent.swift`.
2. List all protocol requirements the macro must satisfy directly vs. those satisfied via protocol extensions.
3. Define the corrected generated surface:
   - Tools type (`[any AnyJSONTool]`)
   - Required methods (`run(session:hooks:)`, `stream(session:hooks:)`, `cancel()`)
   - Optional stored properties (memory/provider/tracer) and environment fallback.
   - Initializers (including typed-tool bridging via `AnyJSONToolAdapter`).
   - Builder defaults and setter overloads.
4. Identify any doc/example drift (MacroDeclarations + docs).

Expected Output:
- A short “delta list” of required fixes with file paths and signatures.
- A reference expansion outline (pseudo-code) for the updated macro output.

Constraints:
- Swift 6.2 strict concurrency; generated public API must be `Sendable`-correct.
- Prefer additive API changes; avoid breaking user-authored members if already present.

