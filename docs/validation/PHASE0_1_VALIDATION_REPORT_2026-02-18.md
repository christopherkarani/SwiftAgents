# Phase 0-1 Validation Report (2026-02-18)

## Scope
This report validates the three gating checks requested for early vNext execution:
1. Thin-slice replay path with restart simulation.
2. Pre-cutover drain gate dry-run (metrics + alert behavior).
3. Semantic-stability baseline scoring run.

All commands were run in:
`/Users/chriskarani/CodingProjects/AIStack/Swarm`

## 1) Thin-slice restart/replay validation

### Command
```bash
swift test --filter "HiveAgentsTests"
```

### Evidence excerpt
```text
Suite "HiveAgents (HiveSwarm) — HiveCore runtime" started.
Test "Tool approval: restart after interrupt resumes with single tool execution" started.
Test "Tool approval: requires checkpoint store (facade preflight)" started.
Test "Tool approval: interrupt + resume executes tools (runtime-driven)" started.
Test "Deterministic message IDs: model taskID drives assistant message id" started.
Test "Tool approval: restart after interrupt resumes with single tool execution" passed.
Test "Tool approval: interrupt + resume executes tools (runtime-driven)" passed.
Suite "HiveAgents (HiveSwarm) — HiveCore runtime" passed.
Test run with 9 tests in 1 suite passed.
```

### Result
`PASS`

### Notes
- Added a restart simulation test:
  `Tests/HiveSwarmTests/HiveAgentsTests.swift`
  `toolApproval_restartAfterInterrupt_executesToolOnce`
- The test recreates runtime/controller after interruption and verifies exactly one tool execution.

## 2) Pre-cutover drain gate dry-run validation

### Script
`/Users/chriskarani/CodingProjects/AIStack/Swarm/scripts/validate_drain_gate.sh`

### Fixtures
- `docs/validation/fixtures/drain_gate_staging_pass.csv`
- `docs/validation/fixtures/drain_gate_staging_fail.csv`

### Pass-case command + output
```bash
./scripts/validate_drain_gate.sh docs/validation/fixtures/drain_gate_staging_pass.csv 60
```

```text
rows_processed=80
max_zero_streak_minutes=65
required_zero_streak_minutes=60
new_start_violations=0
status=PASS
```

### Fail-case command + output
```bash
./scripts/validate_drain_gate.sh docs/validation/fixtures/drain_gate_staging_fail.csv 60
```

```text
rows_processed=80
max_zero_streak_minutes=30
required_zero_streak_minutes=60
new_start_violations=5
status=FAIL
```

### Result
`PASS` (harness behavior verified for both promotion and block paths)

### Notes
- This is a dry run harness validation with fixture data.
- For live staging validation, export minute-level metrics using plan metric names and run the same script.

## 3) Semantic-stability baseline scoring

### Test sweep command
```bash
swift test --filter "(RoutingStrategyTests|HandoffIntegrationTests|ToolSchemaIntegrationTests|HiveAgentsTests)"
```

### Evidence excerpt
```text
Suite "ToolSchema Integration Tests" passed.
Suite "KeywordRoutingStrategy Tests" passed.
Suite "HandoffCoordinator OnHandoff Callback Tests" passed.
Suite "HiveAgents (HiveSwarm) — HiveCore runtime" passed.
Test run with 72 tests in 13 suites passed.
```

### Scoring script
`/Users/chriskarani/CodingProjects/AIStack/Swarm/scripts/compute_semantic_stability.sh`

### Baseline input
`docs/validation/fixtures/semantic_baseline_2026-02-18.csv`

### Scoring command + output
```bash
./scripts/compute_semantic_stability.sh docs/validation/fixtures/semantic_baseline_2026-02-18.csv
```

```text
routing_coverage=1
routing_parity_pct=100.00
handoff_coverage=1
handoff_parity_pct=100.00
failure_class_coverage=1
failure_class_parity_pct=100.00
tool_args_coverage=1
tool_args_parity_pct=100.00
output_correct_coverage=1
output_correct_parity_pct=100.00
overall_semantic_stability_pct=100.00
status=PASS
```

### Result
`PASS`

## Overall status
- Thin-slice restart/replay: `PASS`
- Drain gate dry-run harness: `PASS`
- Semantic-stability baseline run: `PASS`

## Artifacts changed
- `Sources/Swarm/HiveSwarm/HiveAgents.swift`
- `Tests/HiveSwarmTests/HiveAgentsTests.swift`
- `scripts/validate_drain_gate.sh`
- `scripts/compute_semantic_stability.sh`
- `docs/validation/fixtures/drain_gate_staging_pass.csv`
- `docs/validation/fixtures/drain_gate_staging_fail.csv`
- `docs/validation/fixtures/semantic_baseline_2026-02-18.csv`
- `docs/validation/PHASE0_1_VALIDATION_REPORT_2026-02-18.md`
