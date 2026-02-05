Prompt:
Goal:
Implement Router multi-Otherwise support and optional DSL overloads.
Task Breakdown:
- Update Router handling in `Sources/Swarm/Orchestration/OrchestrationBuilder.swift`:
  - Replace `precondition` with collection of all `.otherwise` steps.
  - If multiple fallbacks, wrap in `OrchestrationGroup(steps:)` preserving order.
- Update Router doc comment to describe multi-Otherwise behavior.
- (Optional) Add `When(..., use:)` and `Otherwise(use:)` overloads in `Sources/Swarm/DSL/Flow/Routes.swift`.
Expected Output:
- Passing implementation for multi-Otherwise and optional ergonomic overloads.
Constraints:
- Preserve deterministic order semantics.
- Keep API surface minimal and Swifty.
- Do not edit plan documents.
