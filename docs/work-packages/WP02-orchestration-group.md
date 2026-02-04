Prompt:
Implement OrchestrationGroup and refactor Orchestration to a single root step.

Goal:
Replace array-based orchestration with a single-root OrchestrationStep, preserving behavior and metadata.

Task Breakdown:
- Add OrchestrationGroup: OrchestrationStep executing sequentially.
- Refactor OrchestrationBuilder to return OrchestrationGroup.
- Update Orchestration to store root and execute it.
- Update agent collection traversal for root/group.
- Ensure empty builder is a no-op root.

Expected Output:
- Compiling OrchestrationGroup and single-root Orchestration.
- All usages updated to new init(s).

Constraints:
- Preserve metadata behavior.
- Keep public API minimal and explicit.
