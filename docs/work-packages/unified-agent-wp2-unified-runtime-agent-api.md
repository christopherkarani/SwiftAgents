Prompt:
Implement Phase 2 of `docs/plans/UNIFIED_AGENT_LONG_TERM_API_PLAN.md` (do not edit the plan doc): introduce a new unified runtime `public actor Agent: AgentRuntime` with an explicit strategy selection API, defaulting to ToolCalling semantics. Keep this change focused on the public API surface and correctness; do not attempt lifecycle unification beyond simple forwarding/wrapping.

Goal:
Provide a single, ergonomic runtime entry point (`Agent`) that can replace the common cases of `ToolCallingAgent` / `ReActAgent` / `ChatAgent` / `PlanAndExecuteAgent` via a strategy selection, without changing provider/tool semantics.

Task Breakdown:
0) Likely files to touch (confirm with `rg` before editing):
   - New type:
     - `Sources/SwiftAgents/Agents/Agent.swift` (or `Sources/SwiftAgents/Agents/UnifiedAgent.swift`)
   - Existing runtime agents used as underlying implementations:
     - `Sources/SwiftAgents/Agents/ToolCallingAgent.swift`
     - `Sources/SwiftAgents/Agents/ReActAgent.swift`
     - `Sources/SwiftAgents/Agents/Chat.swift` (ChatAgent)
     - `Sources/SwiftAgents/Agents/PlanAndExecuteAgent.swift`
   - Tests:
     - `Tests/SwiftAgentsTests/Agents/UnifiedAgentAPITests.swift` (new)
   - Optional (only if needed for build/export hygiene):
     - `Package.swift` (should not be required)
1) Add unified runtime type:
   - Create a new source file for the type declaration (avoid colliding with `Sources/SwiftAgents/Core/Agent.swift` which contains `AgentRuntime`):
     - Suggested: `Sources/SwiftAgents/Agents/Agent.swift` (type name `Agent`, file name ok), or `Sources/SwiftAgents/Agents/UnifiedAgent.swift` (preferred if your toolchain/tools get confused by two `Agent.swift` files).
   - Define: `public actor Agent: AgentRuntime`.
2) Strategy API design (keep it hard to misuse):
   - Add a nested strategy enum:
     - `public enum Strategy: Sendable { case toolCalling, react, chat, planAndExecute }`
   - Default strategy MUST be `.toolCalling`.
3) Initializers (ergonomic, consistent with existing agents):
   - Provide a primary initializer matching current usage patterns:
     - tools, instructions, configuration, memory, inferenceProvider, tracer, guardrails, handoffs, and strategy.
   - If existing agents have both "untyped tools" and "typed tools" initializers, mirror those overloads for `Agent` to minimize migration friction.
   - Ensure `Agent` can be constructed without passing `inferenceProvider` (environment fallback remains the same as today).
4) Implementation approach (keep it simple for this package):
   - Internally wrap an underlying concrete agent chosen by strategy:
     - `.toolCalling` -> `ToolCallingAgent(...)`
     - `.react` -> `ReActAgent(...)`
     - `.chat` -> `ChatAgent(...)` (ignores tools; document behavior)
     - `.planAndExecute` -> `PlanAndExecuteAgent(...)`
   - Store the selected implementation behind `any AgentRuntime` and forward:
     - `nonisolated var tools/instructions/configuration/memory/inferenceProvider/tracer/inputGuardrails/outputGuardrails/handoffs`
     - `run(_:session:hooks:)`, `stream(_:session:hooks:)`, and `cancel()`
   - Do not attempt to unify lifecycle logic here; forwarding is acceptable if behavior matches existing agents.
5) Concurrency correctness:
   - Ensure `AgentRuntime` requirements are satisfied with correct `nonisolated` usage.
   - Avoid leaking non-Sendable state across actor boundaries.
6) Basic tests (compile + default strategy behavior):
   - Add a minimal Swift Testing suite proving the default strategy uses ToolCalling semantics (i.e., tool-call generation path) with `MockInferenceProvider`.
   - Suggested new file:
     - `Tests/SwiftAgentsTests/Agents/UnifiedAgentAPITests.swift`
   - Keep parity/deeper coverage for WP5; this package just needs to lock the default and verify the type is usable end-to-end.

Expected Output:
- A new `public actor Agent: AgentRuntime` exists with `Agent.Strategy` and defaults to `.toolCalling`.
- Users can migrate common constructions from legacy concrete runtime agents to `Agent(...)` with the same tools/instructions/provider inputs.
- Minimal tests prove default strategy behavior and protect the public API from accidental breakage.

Constraints:
- Do NOT edit `docs/plans/UNIFIED_AGENT_LONG_TERM_API_PLAN.md`.
- Do not change provider/tool-calling semantics; this should be a wrapper/unified API layer.
- Keep public API surface minimal and documented (doc comments on `Agent` and `Agent.Strategy`).
- Ensure this compiles cleanly with Swift 6.2 strict concurrency.
