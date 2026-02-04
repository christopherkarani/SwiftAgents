Prompt:
Update AgentBlueprint.body to return some OrchestrationStep and adjust orchestration creation.

Goal:
Make blueprints return a single-root step while keeping builder ergonomics.

Task Breakdown:
- Change body signature to `@OrchestrationBuilder var body: some OrchestrationStep`.
- Update makeOrchestration to use new Orchestration(root:).
- Update any blueprint usages affected.

Expected Output:
- AgentBlueprint compiles with new body signature.
- Updated blueprint call sites.

Constraints:
- Builder should allow multiple statements.
