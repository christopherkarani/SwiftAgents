Prompt:
Replace tuple-based Parallel builder with ParallelItem + .named.

Goal:
Modernize parallel DSL with explicit naming and type safety.

Task Breakdown:
- Add ParallelItem struct with name + agent.
- Update Parallel to hold [ParallelItem] and new builder.
- Remove tuple-based buildExpression.
- Update AgentRuntime.named to return ParallelItem (or alternative).

Expected Output:
- Parallel DSL compiles with `.named`.
- Metadata uses item names.

Constraints:
- Decide and document duplicate-name behavior.
