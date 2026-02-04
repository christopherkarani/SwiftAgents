Prompt:
Unify routing DSL to Router { When/Otherwise } and remove Routes/routeWhen helpers.

Goal:
Provide a single routing DSL that supports step-based branches and a fallback.

Task Breakdown:
- Replace Routes with Router + RouteBranch/RouteEntry.
- Move/merge routing definitions into OrchestrationBuilder scope as needed.
- Replace routeWhen/orchestrationRoute with When/Otherwise.
- Update Router execution to run selected OrchestrationStep.
- Define behavior for multiple Otherwise (last-wins or assert).

Expected Output:
- Router DSL compiles and routes to steps/blueprints.
- Removed legacy routing helpers.

Constraints:
- Keep AgentRouter actor unchanged unless API leaks.
- Maintain routing error behavior.
