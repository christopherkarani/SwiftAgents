Prompt:
Review the Conduit bridge fix implementation against `docs/plans/CONDUIT_FIX_PLAN.md` (do not edit the plan doc). Verify behavior via tests and code inspection, focusing on correctness, API clarity, and Swift concurrency safety.

Goal:
Confirm the work is complete and aligned with the plan:
1) tool-call streaming works with `ConduitProviderSelection`,
2) `InferenceOptions.topK` is forwarded into Conduit `GenerateConfig.topK`,
3) `toolChoice` is only applied when tools are non-empty (both generate + streaming tool-call paths).

Task Breakdown:
1) Plan compliance check (no edits):
   - Read `docs/plans/CONDUIT_FIX_PLAN.md` for acceptance criteria.
2) Code inspection (focus areas):
   - Inspect `Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift`:
     - Confirms `ToolCallStreamingInferenceProvider` conformance.
     - Confirms forwarding behavior matches `Sources/Swarm/Providers/Conduit/LLM.swift` semantics (forward if supported; otherwise throw via stream).
   - Inspect `Sources/Swarm/Providers/Conduit/ConduitInferenceProvider.swift`:
     - Confirms `apply(options:to:)` maps `InferenceOptions.topK` -> `GenerateConfig.topK`.
     - Confirms `toolChoice` gating is applied in BOTH:
       - `generateWithToolCalls(prompt:tools:options:)`
       - `streamWithToolCalls(prompt:tools:options:)`
     - Confirms no behavioral regressions (tool definitions still applied, usage mapping unaffected, no accidental changes to tool-call conversion).
3) Test verification:
   - Ensure new tests exist and cover all 3 deliverables:
     - `Tests/SwarmTests/Agents/ToolCallingAgentLiveToolCallStreamingTests.swift`
     - `Tests/SwarmTests/Providers/ConduitInferenceProviderOptionsMappingTests.swift`
   - Run: `swift test` (or at minimum the filters used when authoring tests) and confirm green.
4) Review output:
   - If anything is missing or risky, provide a concrete follow-up checklist with file paths and exact changes needed.

Expected Output:
- A short review report listing:
  - Pass/fail for each plan deliverable,
  - any risks (API, concurrency, performance),
  - any missing tests or edge cases,
  - and an actionable fix list if gaps remain.

Constraints:
- Do NOT edit `docs/plans/CONDUIT_FIX_PLAN.md`.
- Review should prioritize correctness/regression risk first, then API elegance and maintainability.
- Prefer precise file-path references (include specific functions/types) over broad guidance.
