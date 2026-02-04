Prompt:
Implement Phase 1 of `docs/plans/UNIFIED_AGENT_LONG_TERM_API_PLAN.md` (do not edit the plan doc): rename the legacy SwiftUI-style loop DSL `protocol Agent` to a non-colliding name (use `AgentLoopDefinition`), update all builder/handoff integration points, and deprecate the legacy loop DSL entry points with clear migration guidance to `AgentBlueprint`. Keep behavior identical; only rename + deprecation + test updates.

Goal:
Unblock introducing a new unified runtime concrete type named `Agent` by removing the legacy DSL symbol collision, while preserving existing legacy DSL behavior (now deprecated) and keeping `swift build` / `swift test` green.

Task Breakdown:
0) Preflight: identify all module-level `Agent` declarations that would collide with a future `public actor Agent`:
   - Confirm the legacy loop DSL protocol currently named `Agent` lives at:
     - `Sources/SwiftAgents/DSL/DeclarativeAgent.swift`
   - Also check for other top-level declarations named `Agent` (not part of this plan doc, but can block compilation), e.g.:
     - `public macro Agent(...)` in `Sources/SwiftAgents/Macros/MacroDeclarations.swift`
   - If a non-DSL `Agent` symbol exists that would collide with the new runtime type, flag it explicitly and coordinate a rename/deprecation as part of the collision-removal work (or spin it into a separate work package if you cannot keep this small).
1) Pick the final legacy DSL protocol name and apply it consistently:
   - Use `AgentLoopDefinition` as the renamed protocol (per plan).
   - Keep the legacy DSL in place, but mark it deprecated (with message) pointing users to `AgentBlueprint`.
2) Rename the legacy DSL protocol and update all constraints/overloads:
   - Edit `Sources/SwiftAgents/DSL/DeclarativeAgent.swift`:
     - Rename `public protocol Agent` -> `public protocol AgentLoopDefinition`.
     - Update the file-level docs to call this the "legacy loop DSL" and point to `AgentBlueprint`.
   - Edit `Sources/SwiftAgents/DSL/LoopAgent.swift`:
     - Update `LoopAgent<Definition: Agent>` -> `LoopAgent<Definition: AgentLoopDefinition>`.
     - Update `LoopAgentStep<A: Agent>` -> `LoopAgentStep<A: AgentLoopDefinition>`.
   - Edit `Sources/SwiftAgents/DSL/AgentLoopBuilder.swift`:
     - Update any references to `Agent` (legacy DSL) to `AgentLoopDefinition`.
   - Edit `Sources/SwiftAgents/Orchestration/OrchestrationBuilder.swift`:
     - Update `buildExpression<A: Agent>(_ agent: A)` to the new protocol name.
   - Edit `Sources/SwiftAgents/Orchestration/HandoffBuilder.swift`:
     - Update `public func handoff<A: Agent>(to target: A, ...)` to `A: AgentLoopDefinition`.
3) Deprecations + migration messages (must be precise and actionable):
   - Mark `AgentLoopDefinition` itself as deprecated (it is the legacy loop DSL):
     - Message should explicitly say: "Use AgentBlueprint for orchestration; embed runtime Agent/AgentRuntime steps instead of Generate/Relay."
   - Deprecate the legacy flow steps:
     - Edit `Sources/SwiftAgents/DSL/Flow/Generate.swift` and `Sources/SwiftAgents/DSL/Flow/Relay.swift`.
     - Add deprecation messages pointing to `AgentBlueprint` + a runtime `AgentRuntime` step (and eventually unified runtime `Agent`).
   - Do NOT introduce a `typealias Agent = AgentLoopDefinition` (this would reintroduce the symbol collision once runtime `Agent` lands).
4) Update modifiers/adapters that wrap legacy DSL:
   - Inspect and update:
     - `Sources/SwiftAgents/DSL/Modifiers/DeclarativeAgentModifiers.swift`
     - `Sources/SwiftAgents/DSL/Modifiers/EnvironmentAgent.swift`
     - Any other DSL utilities found via `rg -n \"\\bAgent\\b\" Sources/SwiftAgents/DSL` that are talking about the legacy protocol, not `AgentRuntime`.
5) Update tests to compile with the rename:
   - Update any test types declared as `struct X: Agent` (legacy DSL) to `struct X: AgentLoopDefinition`.
   - Likely files:
     - `Tests/SwiftAgentsTests/DSL/DeclarativeAgentDSLTests.swift`
     - `Tests/SwiftAgentsTests/DSL/SwiftUIDSLIntegrationTests.swift`
     - `Tests/SwiftAgentsTests/Orchestration/HandoffConfigurationTests.swift`
     - `Tests/SwiftAgentsTests/Orchestration/HandoffConfigurationTests+Builder.swift`
     - Any other hits from `rg -n \":\\s*Agent\\b\" Tests`.
6) Validate:
   - Run `swift build` and `swift test`.
   - Confirm there is no longer a module-level symbol collision blocking a future `public actor Agent`.

Expected Output:
- The legacy SwiftUI loop DSL protocol is renamed to `AgentLoopDefinition` and compiles across all call sites.
- `@OrchestrationBuilder` and `handoff(to:)` continue to accept legacy loop DSL values via adapters, but the path is deprecated and emits clear migration warnings.
- Legacy loop DSL behavior is preserved (tests updated and still passing).
- `swift build` succeeds without any `Agent` symbol collision from the legacy DSL.

Constraints:
- Do NOT edit `docs/plans/UNIFIED_AGENT_LONG_TERM_API_PLAN.md`.
- Create minimal changes: preserve runtime behavior; avoid refactors beyond rename + deprecations.
- Do NOT add any public symbol named `Agent` as a compatibility alias for the legacy DSL.
- Keep visibility tight and concurrency annotations correct (no new `@unchecked Sendable` unless strictly required).
