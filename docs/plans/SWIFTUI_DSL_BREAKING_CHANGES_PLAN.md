1) Scope + API shape confirmation (breaking changes mapping)
- Define new signatures and types:
  - `AgentBlueprint.body: some OrchestrationStep`
  - `OrchestrationBuilder` returns `OrchestrationGroup` (single root step)
  - `Orchestration` init takes single `OrchestrationStep` root
  - Router DSL: `Router { When/Otherwise }` using `RouteBranch/RouteEntry`
  - Parallel DSL: `ParallelItem` + `.named`, remove tuple builder
  - `ConfiguredAgent` preserves `Base.Loop` (no `AgentLoopSequence` erasure)
- Identify deletion targets:
  - `Routes` type + `routeWhen`/`orchestrationRoute` helpers + tuple-based `ParallelBuilder` + `Orchestration(steps:)` init
- Files likely touched:
  - `Sources/SwiftAgents/DSL/AgentBlueprint.swift`
  - `Sources/SwiftAgents/Orchestration/OrchestrationBuilder.swift`
  - `Sources/SwiftAgents/DSL/Flow/Routes.swift`
  - `Sources/SwiftAgents/DSL/Modifiers/DeclarativeAgentModifiers.swift`
  - Tests: `Tests/SwiftAgentsTests/DSL/AgentBlueprintTests.swift`, `Tests/SwiftAgentsTests/DSL/DeclarativeAgentDSLTests.swift`, `Tests/SwiftAgentsTests/DSL/SwiftUIDSLIntegrationTests.swift`, `Tests/SwiftAgentsTests/Orchestration/AgentRouterTests.swift`
  - Docs: `README.md`, `docs/dsl.md`, `docs/agents.md`, `docs/orchestration.md`

2) Introduce `OrchestrationGroup` + single-root orchestration
- `Sources/SwiftAgents/Orchestration/OrchestrationBuilder.swift`
  - Add `public struct OrchestrationGroup: OrchestrationStep` that wraps `[OrchestrationStep]` and executes them sequentially (reuse existing sequential execution logic from `Orchestration.executeSteps` or mirror it).
  - Update `@resultBuilder OrchestrationBuilder`:
    - `buildBlock` returns `OrchestrationGroup` instead of `[OrchestrationStep]`.
    - Update `buildOptional/buildEither/buildArray/buildExpression` to produce `OrchestrationGroup` or `OrchestrationStep` as appropriate.
    - Ensure `buildExpression(_ agent:)`, `buildExpression(_ blueprint:)`, `buildExpression(_ step:)` still compile.
  - Update `Orchestration`:
    - Replace `steps: [OrchestrationStep]` with `root: OrchestrationStep`.
    - Init signature: `init(configuration:..., handoffs:..., @OrchestrationBuilder _ content: () -> OrchestrationGroup)` and `init(root: OrchestrationStep, configuration:..., handoffs:...)`.
    - Update execution to run `root.execute(...)` (or run group and then apply orchestration metadata).
    - Update `collectAgents(from:)` to traverse a single root (add `OrchestrationGroup` case).
    - Update `instructions` to reflect a single root or group count.
  - Update `AgentBlueprint.makeOrchestration` to pass root step (see step 3).
- Edge cases:
  - Empty builder should still yield a no-op root (decide: `OrchestrationGroup([])` returning input).
  - Ensure metadata keys remain identical to previous `Orchestration` behavior.

3) AgentBlueprint body + Orchestration init changes
- `Sources/SwiftAgents/DSL/AgentBlueprint.swift`
  - Change `body` to `@OrchestrationBuilder var body: some OrchestrationStep`.
  - Update `makeOrchestration()` to use new `Orchestration(root: body, ...)`.
- Update any blueprint usages in tests/docs to drop `[OrchestrationStep]` and return a single step (builder allows multiple statements).
- Edge cases:
  - If body is a single agent, still compile (builder expression -> `OrchestrationGroup` or direct `AgentStep`).

4) Routing unification: Router { When/Otherwise } + remove Routes/routeWhen
- `Sources/SwiftAgents/DSL/Flow/Routes.swift`
  - Replace `Routes` with `Router`-compatible helpers only, or delete file and move `RouteBranch/RouteEntry/When/Otherwise` into `OrchestrationBuilder.swift` (preferred for a single routing DSL).
  - Ensure `When/Otherwise` build `RouteEntry` that Router’s builder consumes.
- `Sources/SwiftAgents/Orchestration/OrchestrationBuilder.swift`
  - Replace `RouteDefinition`/`RouterBuilder` with `RouteBranch/RouteEntry` (align with existing `Routes.swift`).
  - Router stores `[RouteBranch]` + `fallback: OrchestrationStep?` (step-based) or `any AgentRuntime`? Decide: follow `RouteBranch.step` to support arbitrary steps and blueprints.
  - Replace `routeWhen`/`orchestrationRoute` functions with `When/Otherwise`.
  - Router initializer signature: `Router(@RouterBuilder _ content: () -> [RouteEntry])` or `Router(fallback:) { When/Otherwise }`.
  - Update Router execution to run selected branch’s `OrchestrationStep`.
- Update `AgentRouter` (actor) only if public API references `Route` vs new `RouteBranch`—if `AgentRouter` is separate deterministic router, keep it as-is.
- Edge cases:
  - Multiple `Otherwise` entries: last-wins or assert? (define behavior).
  - No routes + no fallback -> `OrchestrationError.routingFailed` stays.

5) Parallel DSL: ParallelItem + `.named`
- `Sources/SwiftAgents/Orchestration/OrchestrationBuilder.swift`
  - Add `public struct ParallelItem: Sendable { name: String; agent: any AgentRuntime }`.
  - Update `Parallel` to store `[ParallelItem]` (rename `agents` to `items`).
  - Update `Parallel` init to use `@ParallelBuilder _ content: () -> [ParallelItem]`.
  - Rework `ParallelBuilder` to build `[ParallelItem]` (remove tuple-based `buildExpression`).
  - Update `AgentRuntime.named(_:)` to return `ParallelItem` (or add `.named` on `ParallelItem` if desired).
- Edge cases:
  - Enforce unique names? (optional: document if duplicates allowed).
  - Update metadata naming to use `item.name`.

6) ConfiguredAgent preserves Base.Loop
- `Sources/SwiftAgents/DSL/Modifiers/DeclarativeAgentModifiers.swift`
  - Change `ConfiguredAgent` to preserve `associatedtype Loop = Base.Loop`.
  - `var loop: Base.Loop { base.loop }` instead of `AgentLoopSequence`.
- Edge cases:
  - Ensure `AgentLoopBuilder` still handles `Base.Loop` without erasure.

7) Update tests to new DSLs and single-root orchestration
- `Tests/SwiftAgentsTests/DSL/AgentBlueprintTests.swift`
  - Update blueprint bodies to `some OrchestrationStep`.
  - Update Router usage to `Router { When(...) { ... } Otherwise { ... } }`.
- `Tests/SwiftAgentsTests/DSL/DeclarativeAgentDSLTests.swift`
  - Replace `Routes { When/Otherwise }` with `Router { When/Otherwise }` (if routing moved).
- `Tests/SwiftAgentsTests/DSL/SwiftUIDSLIntegrationTests.swift`
  - Update blueprint body signature.
- `Tests/SwiftAgentsTests/Orchestration/AgentRouterTests.swift`
  - Only if `AgentRouter` API changed (likely not); otherwise keep.
- Add new tests (Swift Testing):
  - `OrchestrationGroup` executes sequentially and preserves metadata count.
  - `Orchestration` accepts single root and runs.
  - `Parallel` uses `ParallelItem` + `.named`.
  - Router `When/Otherwise` works with step bodies (not just agents).
  - `ConfiguredAgent.loop` preserves concrete type (compile-time check).

8) Docs and examples updates
- `README.md` and `docs/dsl.md`:
  - Update all `AgentBlueprint.body` examples to `some OrchestrationStep`.
  - Replace `routeWhen` and `Routes` examples with `Router { When/Otherwise }`.
  - Replace tuple-based `Parallel` with `.named` / `ParallelItem`.
  - Update `Orchestration` examples to single-root (no `steps:` init).
- `docs/agents.md`, `docs/orchestration.md`:
  - Update routing DSL and orchestration init.

9) Compatibility notes and migration guidance
- Add a short “Breaking changes” section in `README.md` or `docs/dsl.md`:
  - “Replace `Routes` with `Router` and `When/Otherwise`.”
  - “Use `Parallel { agent.named(\"x\") }` instead of `(“x”, agent)`.”
  - “Blueprint `body` is `some OrchestrationStep`.”
  - “Orchestration now takes a single root step.”

10) Test run plan (Swift Testing)
- `swift test --filter AgentBlueprintTests`
- `swift test --filter DeclarativeAgentDSLTests`
- `swift test --filter SwiftUIDSLIntegrationTests`
- `swift test --filter AgentRouterTests` (if touched)
- Full `swift test` if needed
