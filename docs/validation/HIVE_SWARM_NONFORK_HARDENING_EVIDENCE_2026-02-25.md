# Hive-Swarm Non-Fork Hardening Evidence (2026-02-25)

## Targeted Verification Commands

1. `swift test --filter HiveAgentsTests`
2. `swift test --filter HiveBackedAgentStreamingTests`
3. `swift test --filter MembraneHiveCheckpointTests`
4. `swift test --filter ModelRouterTests`
5. `swift test --filter RetryPolicyBridgeTests`

## Outcomes (current)

- Commands 1–5: **FAILED at compile** in `ConduitInferenceProviderOptionsMappingTests` because `Conduit.GenerateConfig` no longer exposes `runtimeFeatures` or `runtimePolicyOverride` (Conduit API drift).
  - Error examples:
    - `GenerateConfig` has no member `runtimeFeatures` (Tests/SwarmTests/Providers/ConduitInferenceProviderOptionsMappingTests.swift:348)
    - `GenerateConfig` has no member `runtimePolicyOverride` (Tests/SwarmTests/Providers/ConduitInferenceProviderOptionsMappingTests.swift:433)

## Determinism/Replay Evidence Status

- Transcript hash evidence: **NOT PRODUCED** (blocked by Conduit compile error).
- Final state hash evidence: **NOT PRODUCED** (blocked by Conduit compile error).
- First-diff mismatch proof: implemented in tests (`HiveAgentsTests.determinismUtilities_hashesAndFirstDiff`) but execution blocked until Conduit bridge/test fix lands.

## Remaining Risks

1. Hive suites cannot run until Conduit option mapping tests are fixed to the current API surface.
2. Event-stream decoration behavior (`HiveAgentsRunController.decorate`) still needs runtime/stream verification once tests compile.
3. Cancel/checkpoint race assertions need runtime confirmation with `SlowCheckpointStore` after the Conduit fix.

## Mitigations

1. Update Conduit option mapping tests/bridge to match current `GenerateConfig` (no `runtimeFeatures`/`runtimePolicyOverride`).
2. Re-run all targeted commands after the Conduit fix.
3. Follow-ups once unblocked:
   - `swift test --filter HiveAgentsTests`
   - `swift test --filter HiveBackedAgentStreamingTests`
   - `swift test --filter MembraneHiveCheckpointTests`
   - `swift test --filter ModelRouterTests`
   - `swift test --filter RetryPolicyBridgeTests`
