Prompt:
Write failing Swift Testing tests for the Conduit bridge fixes described in `docs/plans/CONDUIT_FIX_PLAN.md` (do not edit the plan doc). Focus on observable behavior (agent streaming selection + Conduit config mapping), keep tests deterministic, and prefer small mock providers that capture inputs.

Goal:
Lock in correctness with failing tests that reproduce the 3 gaps:
1) tool-call streaming works when the provider is wrapped via `ConduitProviderSelection`,
2) `InferenceOptions.topK` is forwarded into Conduit `GenerateConfig.topK`,
3) `toolChoice` is only applied when tools are non-empty.

Task Breakdown:
1) Add agent-level test proving streaming is selected through `ConduitProviderSelection`:
   - Edit `Tests/SwiftAgentsTests/Agents/ToolCallingAgentLiveToolCallStreamingTests.swift`.
   - Add a new `@Test` that:
     - defines a `ToolCallStreamingInferenceProvider` mock that *throws* if `generateWithToolCalls(...)` is called,
     - yields at least one `.toolCallPartial` + `.toolCallsCompleted(...)` via `streamWithToolCalls(...)`,
     - wraps the mock in `ConduitProviderSelection.provider(mock)` and passes it to `ToolCallingAgent(inferenceProvider:)`,
     - asserts `.toolCallPartial` events are observed (or that `generateWithToolCalls` was not called).
2) Add provider-bridge tests for topK forwarding into Conduit config:
   - Create `Tests/SwiftAgentsTests/Providers/ConduitInferenceProviderOptionsMappingTests.swift`.
   - Implement a minimal `Conduit.TextGenerator` mock that records the last `Conduit.GenerateConfig` passed to:
     - `generate(_ prompt:model:config:)` (for the plain `generate` path), and/or
     - `generate(messages:model:config:)` (for the tool-call path).
   - Call `ConduitInferenceProvider.generate(prompt:options:)` (and/or `generateWithToolCalls`) with `InferenceOptions.default.topK(…)` and assert `recordedConfig.topK == expected`.
3) Add hardening tests for toolChoice gating when tools are empty:
   - Extend `Tests/SwiftAgentsTests/Providers/ConduitInferenceProviderOptionsMappingTests.swift`.
   - Using the same recording `Conduit.TextGenerator` mock:
     - call `ConduitInferenceProvider.generateWithToolCalls(prompt: tools: [], options: .default.toolChoice(.required))` and assert `recordedConfig.toolChoice` remains the base/default value (i.e., not `.required`).
     - call `ConduitInferenceProvider.streamWithToolCalls(prompt: tools: [], options: .default.toolChoice(.required))` and assert the config passed to `streamWithMetadata(...)` similarly does not set `.required`.
4) Ensure the new tests fail on `main` prior to implementation changes:
   - Run `swift test --filter Conduit` and `swift test --filter ToolCallingAgent` (or the narrowest filters that hit the new tests).

Expected Output:
- New/updated tests that fail before implementation:
  - `Tests/SwiftAgentsTests/Agents/ToolCallingAgentLiveToolCallStreamingTests.swift` has a new failing test for `ConduitProviderSelection` + streaming.
  - `Tests/SwiftAgentsTests/Providers/ConduitInferenceProviderOptionsMappingTests.swift` exists and contains failing tests for `topK` forwarding and `toolChoice` gating.
- Clear assertions that will pass once the fixes are implemented, without relying on network calls.

Constraints:
- Do NOT edit `docs/plans/CONDUIT_FIX_PLAN.md`.
- Use Swift Testing (`import Testing`), not XCTest.
- Keep mocks minimal, local to the test file(s), and deterministic.
- Avoid testing private implementation details directly; assert via captured inputs/observable events.
