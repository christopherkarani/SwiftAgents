# Agent Protocol Rename Plan

## Goal

Rename:

- **Protocol**: `Agent` → `AgentType`
- **Tool-calling concrete agent**: `ToolCallingAgent` → `Agent`

This plan is **analysis + execution steps only**. No implementation is performed until approval.

## Why

- `Agent` is currently a protocol, but several docs already read as if `Agent` is a concrete, default agent type (e.g. `let agent = Agent(...)`).
- Renaming the protocol frees the `Agent` type name for the default “tool-calling” implementation, improving ergonomics and matching documentation intent.

## Scope / Non-Goals

- In scope: rename symbols, update all internal references, update docs/tests/playgrounds/macros that mention the protocol or `ToolCallingAgent`.
- Out of scope: behavioral changes, refactors, performance work, or API redesign beyond renames.
- Out of scope unless requested: changes inside `SwiftSwarm-main/` (separate library in this repo).

## Impact Summary (Breaking Change)

This is a **source-breaking** public API change.

- Any downstream usage of `Agent` (protocol) will need to migrate to `AgentType`.
- Any downstream usage of `ToolCallingAgent` will migrate to `Agent` (or use a deprecation alias if we add one).

## Where `Agent` (protocol) exists today

### Protocol definition (actual code)

- `Sources/SwiftAgents/Core/Agent.swift` (`public protocol Agent: Sendable`)

### Protocol shown in docs (duplicated signatures)

- `docs/API_REFERENCE.md`
- `docs/agents.md`

### Other docs that reference the protocol (examples, signatures, DSL)

These docs include `: Agent`, `any Agent`, `protocol …: Agent`, or `extension Agent` in code blocks and will need to be updated:

- `docs/BEST_PRACTICES.md`
- `docs/dsl.md`
- `docs/guardrails.md`
- `docs/Handoffs.md`
- `docs/MIGRATION_GUIDE.md`
- `docs/orchestration.md`
- `docs/TROUBLESHOOTING.md`
- `docs/VOICE_AGENT_IMPLEMENTATION_PLAN.md` (plan doc; update if we want it to stay accurate)
- `docs/plans/SWIFTAGENTS_VS_OPENAI_SDK_PLAN.md` (plan doc; contains Swift snippets with `Agent`)

## Where `Agent` (protocol) is referenced (code inventory)

The protocol appears via:

- Conformance: `: Agent`
- Existentials: `any Agent`
- Opaque existentials: `some Agent`
- Extensions: `extension Agent`
- Macro attach points: `@attached(extension, conformances: Agent)`

### Core + type erasure

- `Sources/SwiftAgents/Core/AnyAgent.swift` (`AnyAgent: Agent`, `AgentBox<A: Agent>`, `init(_ agent: some Agent)`)
- `Sources/SwiftAgents/Core/Agent.swift` (protocol + `extension Agent` blocks)
- `Sources/SwiftAgents/Core/RunHooks.swift` (hook methods take `agent: any Agent`)
- `Sources/SwiftAgents/Core/EventStreamHooks.swift` (takes `any Agent`)

### Agents (conformers)

- `Sources/SwiftAgents/Agents/ReActAgent.swift` (`public actor ReActAgent: Agent`)
- `Sources/SwiftAgents/Agents/PlanAndExecuteAgent.swift` (`public actor PlanAndExecuteAgent: Agent`)
- `Sources/SwiftAgents/Agents/ToolCallingAgent.swift` (`public actor ToolCallingAgent: Agent`)
- `Sources/SwiftAgents/Resilience/ResilientAgent.swift` (`public actor ResilientAgent: Agent`)

### Orchestration / DSL / routing

Protocol is used heavily for multi-agent composition:

- `Sources/SwiftAgents/Orchestration/OrchestrationBuilder.swift` (`any Agent` + `public extension Agent`)
- `Sources/SwiftAgents/Orchestration/Handoff.swift` (`HandoffReceiver: Agent`, stores `any Agent`)
- `Sources/SwiftAgents/Orchestration/HandoffBuilder.swift` (`HandoffBuilder<Target: Agent>`, `handoff<T: Agent>`, `some Agent`)
- `Sources/SwiftAgents/Orchestration/HandoffConfiguration.swift` (`HandoffConfiguration<Target: Agent>`, callbacks with `any Agent`)
- `Sources/SwiftAgents/Orchestration/SequentialChain.swift` (`SequentialChain: Agent`, operators with `any Agent`)
- `Sources/SwiftAgents/Orchestration/AgentOperators.swift` (compositions: `ParallelComposition: Agent`, etc.)
- `Sources/SwiftAgents/Orchestration/ParallelGroup.swift` (`ParallelGroup: Agent`)
- `Sources/SwiftAgents/Orchestration/AgentRouter.swift` (`AgentRouter: Agent`, stores `any Agent`)
- `Sources/SwiftAgents/Orchestration/SupervisorAgent.swift` (`SupervisorAgent: Agent`, operates over `any Agent`)
- `Sources/SwiftAgents/Orchestration/Pipeline.swift` (`public extension Agent`, pipelines)

### Tools / guardrails (agent passed for validation + hooks)

- `Sources/SwiftAgents/Tools/Tool.swift` (`agent: (any Agent)?` in execution path)
- `Sources/SwiftAgents/Tools/ParallelToolExecutor.swift` (`agent: any Agent`)
- `Sources/SwiftAgents/Tools/ToolExecutionEngine.swift` (`agent: any Agent`)
- `Sources/SwiftAgents/Tools/ToolCallGoal.swift` (`agent: any Agent`)
- `Sources/SwiftAgents/Guardrails/ToolGuardrails.swift` (uses `any Agent`)
- `Sources/SwiftAgents/Guardrails/OutputGuardrail.swift` (uses `any Agent`)
- `Sources/SwiftAgents/Guardrails/GuardrailRunner.swift` (uses `any Agent`)

### Macros (must be updated or builds will fail)

Macro declarations in the main library reference protocol conformance:

- `Sources/SwiftAgents/Macros/MacroDeclarations.swift` (`@attached(extension, conformances: Agent)` appears twice)

Macro expansion emits protocol conformance directly:

- `Sources/SwiftAgentsMacros/AgentMacro.swift` (generates `extension <Type>: Agent {}`)

Macro tests assert that emitted expansion text matches the old protocol name:

- `Tests/SwiftAgentsMacrosTests/AgentMacroTests.swift`
- `Tests/SwiftAgentsMacrosTests/MacroIntegrationTests.swift` (likely via macro usage; needs audit)

### Examples / playgrounds

- `Sources/SwiftAgents/Examples/Playground.swift` (hooks accept `any Agent`)
- `Playground.playground/Pages/Main.xcplaygroundpage/Contents.swift` (hooks accept `any Agent`)

### Tests

Representative (non-exhaustive) test areas that reference the protocol directly:

- `Tests/SwiftAgentsTests/Core/RunHooksTests.swift` (`any Agent`)
- `Tests/SwiftAgentsTests/DSL/AgentCompositionTests.swift` (`any Agent`, `: Agent`)
- `Tests/SwiftAgentsTests/Orchestration/*` (handoffs, supervisor, router; `: Agent` and `any Agent`)
- `Tests/SwiftAgentsTests/Tools/ParallelToolExecutorTests+Mocks.swift` (`: Agent`)
- `Tests/SwiftAgentsTests/Guardrails/*` (guardrails reference `any Agent`)

## Where `ToolCallingAgent` exists today (inventory)

### Concrete implementation

- `Sources/SwiftAgents/Agents/ToolCallingAgent.swift`

### Docs + plans

- `docs/agents.md`
- `docs/tools.md`
- `docs/plans/PLAN_REVIEW_FINDINGS.md`
- `docs/plans/SWIFTAGENTS_VS_OPENAI_SDK_PLAN.md`

### Tests

- `Tests/SwiftAgentsTests/Agents/StreamingEventTests.swift`

## Docs that already assume a concrete `Agent` type

These examples currently read as if `Agent` is instantiable; they should become correct once `ToolCallingAgent` is renamed to `Agent`:

- `docs/streaming.md` (SwiftUI view model uses `private let agent: Agent`)
- `docs/memory.md` (shows `let agent = Agent(name:..., memory: ...)`)
- `docs/resilience.md` (wraps `private let agent: Agent`)
- `docs/observability.md` (shows `let agent = Agent(tracer: NoOpTracer())`)

## Proposed execution plan (after approval)

### Phase 0 — Preconditions

1. Confirm naming decisions:
   - Protocol spelling: `AgentType` (Swift identifier; “Agent Type” in prose).
   - Concrete type name: `Agent` (renamed from `ToolCallingAgent`).
2. Decide compatibility posture:
   - **Recommended**: keep `ToolCallingAgent` as a deprecated typealias to `Agent` for one release cycle.
   - Note: we cannot provide a deprecated alias for the old `Agent` protocol name if we also create a concrete `Agent` type.
3. Confirm whether we keep the macro name `@Agent` (recommended: keep) while changing its conformance target to `AgentType`.

### Phase 1 — Rename the protocol (`Agent` → `AgentType`)

1. Update `Sources/SwiftAgents/Core/Agent.swift`:
   - Rename protocol declaration.
   - Rename all `extension Agent` blocks to `extension AgentType`.
2. Update all internal references:
   - `any Agent` → `any AgentType`
   - `some Agent` → `some AgentType`
   - `T: Agent` → `T: AgentType`
   - `protocol X: Agent` → `protocol X: AgentType`
3. Update type erasure:
   - `AnyAgent: Agent` → `AnyAgent: AgentType`
   - `AgentBox<A: Agent>` → `AgentBox<A: AgentType>`

### Phase 2 — Update macros to target `AgentType`

1. Update macro declarations:
   - `Sources/SwiftAgents/Macros/MacroDeclarations.swift`: change `@attached(extension, conformances: Agent)` → `AgentType`.
2. Update macro expansion:
   - `Sources/SwiftAgentsMacros/AgentMacro.swift`: emit `extension <Type>: AgentType {}`.
3. Update macro tests:
   - `Tests/SwiftAgentsMacrosTests/AgentMacroTests.swift` expected expansions.
   - Audit `Tests/SwiftAgentsMacrosTests/MacroIntegrationTests.swift` if it asserts text containing `Agent`.

### Phase 3 — Rename tool-calling agent (`ToolCallingAgent` → `Agent`)

1. Rename the type:
   - `public actor ToolCallingAgent` → `public actor Agent`
   - Update nested builder names / extensions currently on `ToolCallingAgent`.
2. Update references throughout sources/tests/docs:
   - `ToolCallingAgent(` → `Agent(`
   - `ToolCallingAgent.Builder` → `Agent.Builder`
   - DSL usage `ToolCallingAgent { ... }` → `Agent { ... }`
3. (Recommended) Add compatibility alias:
   - `@available(*, deprecated, renamed: "Agent") public typealias ToolCallingAgent = Agent`

### Phase 4 — Documentation updates

1. Update protocol docs/snippets:
   - `docs/agents.md` (“Agent protocol” → “AgentType protocol”, and code blocks).
   - `docs/API_REFERENCE.md` signature blocks.
2. Update all docs that reference protocol types:
   - Replace `any Agent` → `any AgentType` in docs code blocks.
   - Replace `: Agent` conformances in examples with `: AgentType`.
3. Update “tool-calling agent” docs to new type name:
   - `docs/tools.md` and `docs/agents.md`: rename sections and examples.
4. Double-check docs that already assume `Agent` is concrete:
   - `docs/streaming.md`, `docs/memory.md`, `docs/resilience.md`, `docs/observability.md`

### Phase 5 — Build + test verification

1. Run `swift test` for `SwiftAgentsTests` and `SwiftAgentsMacrosTests`.
2. Build `SwiftAgentsDemo` to ensure the executable target still compiles.
3. If the repo has an Xcode workspace flow, build the workspace scheme(s).

## Search/replace checklist (safe patterns)

Use targeted replacements rather than naive global `Agent` → `AgentType`:

- `protocol Agent` → `protocol AgentType`
- `extension Agent` → `extension AgentType`
- `any Agent` → `any AgentType`
- `some Agent` → `some AgentType`
- `: Agent` / `<T: Agent>` → `: AgentType` / `<T: AgentType>`
- `@attached(extension, conformances: Agent)` → `...AgentType`
- Macro-generated `extension X: Agent {}` → `extension X: AgentType {}`

Separately:

- `ToolCallingAgent` (type name) → `Agent` (type name)

## Approval Questions (need decisions before implementation)

1. Do you want to keep `@Agent` macro name as-is (recommended), even though it will generate `AgentType` conformance?
2. Do you want a deprecated `ToolCallingAgent` alias to `Agent` for migration, or a hard break?
3. Should we rename file names for clarity (e.g., `Sources/SwiftAgents/Core/Agent.swift` → `AgentType.swift`, `ToolCallingAgent.swift` → `Agent.swift`), or keep filenames unchanged and only rename symbols?
4. In docs/examples, should `Agent` type annotations mean the new concrete default `Agent`, or should we prefer `any AgentType` to make examples work with any agent implementation?
