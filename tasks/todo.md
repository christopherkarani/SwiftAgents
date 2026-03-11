# Task Plan (Review Follow-up Fixes - 2026-03-03)
- [x] Confirm scope from review findings (P1 AgentRouter identity, P2 HiveRuntimeHardening stale interruption).
- [x] Add failing regression tests for struct runtime handoff matching and stale interruption clearing.
- [x] Implement targeted fixes in `AgentRouter` and `HiveRuntimeHardening`.
- [x] Run focused tests for new regressions and full `swift test`.
- [x] Document outcomes and verification.

# Review (Review Follow-up Fixes - 2026-03-03)
- Added failing-first regression coverage:
- `Tests/SwarmTests/Orchestration/AgentRouterTests.swift`: new struct runtime (`ValueRuntimeRouterAgent`) + test
  `handoffUsesValueRuntimeIdentityForStructAgents` proving handoff config lookup must work for value-type runtimes.
- `Tests/HiveSwarmTests/HiveAgentsTests.swift`: new test
  `getState_clearsStaleCheckpointInterruption_afterResumeCompletion` reproducing stale checkpoint interruption leakage and
  `interruptPending` on `applyExternalWrites` after successful resume completion.

- Fixed:
- `Sources/Swarm/Orchestration/AgentRouter.swift`: removed local boxed `AnyObject` runtime comparator and now uses shared
  `areSameRuntime` identity helper (`AgentRuntime+Identity`) for handoff config matching.
- `Sources/Swarm/HiveSwarm/HiveRuntimeHardening.swift`: updated `getState` interruption merge strategy to let tracker-cleared
  interruption state override stale checkpoint interruption summaries when tracker has lifecycle evidence.

- Verification:
- Red phase:
  - `swift test --filter AgentRouterHandoffIdentityTests` failed at
    `handoffUsesValueRuntimeIdentityForStructAgents` (missing filtered handoff input).
  - `swift test --filter "HiveAgentsTests/getState_clearsStaleCheckpointInterruption_afterResumeCompletion"` failed with
    stale `snapshot.interruption` + `HiveRuntimeError.interruptPending`.
- Green phase:
  - `swift test --filter AgentRouterHandoffIdentityTests` passed.
  - `swift test --filter "HiveAgentsTests/getState_clearsStaleCheckpointInterruption_afterResumeCompletion"` passed.
  - `swift test 2>&1 | tail -30` passed (1987 tests, 0 failures).

# Task Plan (Phase 1 Swarm Configuration + Error Improvement - 2026-03-03)
- [x] Confirm scope from approved `<proposed_plan>` and locked decisions.
- [x] Add failing tests for Swarm global config and AgentError recovery suggestion.
- [x] Implement `Swarm` global configuration storage and API surface.
- [x] Update `AgentError` with `toolCallingRequiresCloudProvider` and recovery suggestion.
- [x] Update provider resolution chain in `Agent` to async 6-step fallback.
- [x] Update Foundation Models tool-calling error mapping and impacted tests.
- [x] Run `swift build`, targeted suites, full `swift test`, and `swiftformat`.

# Review (Phase 1 Swarm Configuration + Error Improvement - 2026-03-03)
- Added:
- `Sources/Swarm/Core/SwarmConfiguration.swift` with global `Swarm.configure(provider:)`, `Swarm.configure(cloudProvider:)`, async getters for `defaultProvider` and `cloudProvider`, and `Swarm.reset()` backed by an actor singleton.
- `Tests/SwarmTests/Core/SwarmConfigurationTests.swift` with 8 TDD cases (including handoff-only cloud-provider resolution regression coverage).
- `Tests/SwarmTests/Core/AgentErrorTests.swift` with 4 cases for description, recovery suggestion, debug description, and nil suggestion for legacy errors.
- `Tests/SwarmTests/Mocks/SwarmConfigurationTestIsolation.swift` shared async lock + reset helper to serialize global Swarm config access across suites.

- Updated:
- `Sources/Swarm/Core/AgentError.swift` with new `toolCallingRequiresCloudProvider` case, description text, debug description, and `recoverySuggestion`.
- `Sources/Swarm/Providers/LanguageModelSession.swift` to throw `toolCallingRequiresCloudProvider` for tool-call requests and align platform availability annotations.
- `Sources/Swarm/Agents/Agent.swift` provider resolution to async 6-step chain:
  explicit > environment > `Swarm.defaultProvider` > `Swarm.cloudProvider` (tool calling required, including handoffs) > Foundation Models > unavailable error.
- Existing tests aligned to new error semantics:
  - `Tests/SwarmTests/Agents/AgentDefaultInferenceProviderTests.swift`
  - `Tests/SwarmTests/Providers/FoundationModelsToolCallingTests.swift`
  - `Tests/SwarmTests/Core/CoreTests.swift` (`allErrors` list includes new case)

- Verification:
- Red phase validated: initial new tests failed before implementation (missing `Swarm.configure` / new `AgentError` case).
- Green phase validated:
  - `swift build 2>&1 | head -50` passed (package warnings only).
  - `swift test --filter SwarmConfigurationTests` passed (8/8).
  - `swift test --filter ToolCallingErrorTests` passed (4/4).
  - `swift test 2>&1 | tail -30` passed (1985 tests, 0 failures).
- Formatting:
  - `swift package plugin --allow-writing-to-package-directory swiftformat` failed because no plugin is registered.
  - Applied fallback formatting with installed binary:
    `swiftformat Sources/Swarm/Core/SwarmConfiguration.swift Sources/Swarm/Core/AgentError.swift Sources/Swarm/Providers/LanguageModelSession.swift Sources/Swarm/Agents/Agent.swift Tests/SwarmTests/Core/SwarmConfigurationTests.swift Tests/SwarmTests/Core/AgentErrorTests.swift Tests/SwarmTests/Agents/AgentDefaultInferenceProviderTests.swift Tests/SwarmTests/Providers/FoundationModelsToolCallingTests.swift Tests/SwarmTests/Core/CoreTests.swift`

# Task Plan (Framework Issue Audit - 2026-02-26)
- [x] Confirm scope: mission-critical bug audit + fix-all + TDD verification + PR.
- [x] Reproduce baseline failure state with `swift test` and capture blocking errors.
- [x] Fix package/dependency wiring breakages that prevent compilation.
- [x] Add regression coverage for identified correctness defects.
- [x] Implement production-grade fixes in `Sources/Swarm` for audited defects.
- [ ] Run `swift build` and `swift test` to verify zero regressions. (`swift build` passes; `swift test` blocked by disk full in sandbox: `No space left on device`)
- [ ] Commit with detailed message(s), push branch, and open PR. (blocked pending successful build/test in this environment)

# Review
- Fixed:
- `Package.swift`: pinned `Conduit` to `exact: 0.3.5` with required traits (`OpenAI`, `OpenRouter`, `Anthropic`), avoiding broken `main` and restoring provider symbols.
- `Sources/Swarm/Tools/ArithmeticParser.swift`: added missing `.nestingDepthExceeded` `LocalizedError` mapping.
- `Sources/Swarm/Tools/ParallelToolExecutor.swift`: removed duplicate `.failFast` switch arm (invalid/extraneous branch).
- `Sources/Swarm/Resilience/RetryPolicy.swift`: sanitized backoff delays to avoid NaN/Infinity/overflow sleeps and removed dead `attempt` state.
- `Sources/Swarm/Resilience/RateLimiter.swift`: sanitized invalid token/refill configuration and guarded invalid wait-time math.
- `Sources/Swarm/Agents/AgentBuilder.swift`: removed stale `mcpClient` argument to `ReActAgent` initializer.

- Added tests:
- `Tests/SwarmTests/Tools/ArithmeticParserTests.swift`: nesting depth error test + localized description coverage.
- `Tests/SwarmTests/Resilience/ResilienceTests+Retry.swift`: invalid/infinite backoff safety tests.
- `Tests/SwarmTests/Resilience/ResilienceTests+RateLimiter.swift`: invalid constructor parameter sanitization tests.

- Verification status:
- `swift build` passes.
- `swift test` fails in this sandbox due filesystem exhaustion while compiling dependency test artifacts:
  `No space left on device`.

# Task Plan (Framework Issue Audit - 2026-03-11)
- [x] Reconfirm scope from automation memory and run baseline red phase.
- [x] Add failing tests for numeric argument-safety regressions in tool argument normalization.
- [x] Implement safe numeric coercion/validation in `ToolArgumentProcessor`.
- [x] Run targeted tests, then `swift build` + `swift test` (or document environment blockers).
- [x] Document review outcomes, commit with detailed message, and attempt push/PR. (Commit + push succeeded; PR creation blocked by `api.github.com` connectivity and missing `codex` label)

# Review (Framework Issue Audit - 2026-03-11)
- Findings fixed:
- `Sources/Swarm/Tools/Tool.swift`
  - Hardened `.double` validation/coercion to reject non-finite values (`nan`, `inf`, `-inf`) with explicit `invalidToolArguments`.
  - Replaced fragile integer-from-double checks with safe conversion (`Int(exactly:)`) to avoid overflow/trap risk at large numeric boundaries.

- Added tests (failing-first):
- `Tests/SwarmTests/Tools/ToolParameterTests.swift`
  - `normalizeArgumentsRejectsNaNStringForDouble`
  - `normalizeArgumentsRejectsNonFiniteDoubleValues`
  - Both tests failed in red phase before the fix (`thrownError == nil`), then passed after hardening numeric coercion.

- Verification:
- `swift test --filter ToolParameterTests` ✅
- `swift build` ✅
- `swift test` ✅ (1989 tests, 0 failures)
- Delivery:
- Commit: `a8107a1` (`Harden tool numeric argument coercion`)
- Branch pushed: `automation/check-frameworks-audit-20260311`
- PR creation blocked in this environment:
  - `error connecting to api.github.com`
  - repository does not currently have `codex` label (`could not add label: 'codex' not found`)
