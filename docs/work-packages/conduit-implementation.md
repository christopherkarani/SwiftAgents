Prompt:
Implement the Conduit bridge fixes per `docs/plans/CONDUIT_FIX_PLAN.md` (do not edit the plan doc). Make the minimal, well-typed changes needed to pass the new failing tests, and keep API surface small and hard to misuse.

Goal:
Restore correct tool-call streaming behavior for `ConduitProviderSelection`, forward `InferenceOptions.topK` into Conduit generation config, and harden `toolChoice` application so empty-tools requests never set invalid provider configs.

Task Breakdown:
1) Forward tool-call streaming through `ConduitProviderSelection`:
   - Edit `Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift`.
   - Make `ConduitProviderSelection` conform to `ToolCallStreamingInferenceProvider`.
   - Implement:
     - `streamWithToolCalls(prompt:tools:options:) -> AsyncThrowingStream<InferenceStreamUpdate, Error>`
   - Behavior:
     - If `makeProvider()` can be downcast to `any ToolCallStreamingInferenceProvider`, forward the call.
     - Otherwise, return an `AsyncThrowingStream` that finishes by throwing `AgentError.generationFailed(...)`.
   - Mirror the behavior/shape already used in `Sources/Swarm/Providers/Conduit/LLM.swift` (but do not refactor `LLM` as part of this package).
2) Map `InferenceOptions.topK` into Conduit `GenerateConfig.topK`:
   - Edit `Sources/Swarm/Providers/Conduit/ConduitInferenceProvider.swift`.
   - In `apply(options:to:)`, add:
     - `if let topK = options.topK { updated = updated.topK(topK) }`
   - Keep the mapping consistent with existing option forwarding style.
3) Harden toolChoice application so it only applies when tools are non-empty:
   - Edit `Sources/Swarm/Providers/Conduit/ConduitInferenceProvider.swift`.
   - In both:
     - `generateWithToolCalls(prompt:tools:options:)`
     - `streamWithToolCalls(prompt:tools:options:)`
   - Gate toolChoice application:
     - only apply `options.toolChoice` when `!tools.isEmpty` (or equivalently when generated toolDefinitions is non-empty).
     - Ensure config remains valid when `tools` is empty.
4) Validate:
   - Run the narrow test filters introduced in `docs/work-packages/conduit-tests.md` until green.

Expected Output:
- `Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift` forwards `streamWithToolCalls(...)` and type-checks as `ToolCallStreamingInferenceProvider`.
- `Sources/Swarm/Providers/Conduit/ConduitInferenceProvider.swift` forwards `topK` and gates `toolChoice` on non-empty tools in both tool-call paths.
- All Conduit fix tests pass locally (`swift test` and/or targeted filters).

Constraints:
- Do NOT edit `docs/plans/CONDUIT_FIX_PLAN.md`.
- Preserve public API compatibility; keep visibility tight and avoid new public types unless required.
- Prefer compile-time guarantees; avoid `Any`/type erasure beyond the existing `any InferenceProvider` usage in `ConduitProviderSelection`.
- Keep behavior consistent with existing `LLM` forwarding semantics for streaming support.
