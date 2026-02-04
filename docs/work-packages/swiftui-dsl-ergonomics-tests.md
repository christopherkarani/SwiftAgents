Prompt:
Goal:
Create failing Swift Testing coverage for Router multi-Otherwise behavior.
Task Breakdown:
- Inspect current Router/DSL behavior in `Sources/SwiftAgents/Orchestration/OrchestrationBuilder.swift` and `Sources/SwiftAgents/DSL/Flow/Routes.swift`.
- Add tests in `Tests/SwiftAgentsTests/DSL/BreakingAPIChangesTests.swift` for:
  - Multiple `Otherwise` branches run sequentially in deterministic order.
  - Single `Otherwise` still works (regression).
- Ensure tests fail against current behavior.
Expected Output:
- New failing tests in `Tests/SwiftAgentsTests/DSL/BreakingAPIChangesTests.swift`.
Constraints:
- Use Swift Testing (`import Testing`) only.
- Tests must be deterministic and behavior-focused.
- Do not edit plan documents.
