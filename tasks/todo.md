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
