Prompt:
Confirm API shape changes, deletions, and impacted files for the new single-root orchestration and DSL updates.

Goal:
Lock down signatures, breaking changes, and file touch list before implementation.

Task Breakdown:
- Enumerate new signatures/types and confirm naming.
- Confirm deletions: Routes, helpers, tuple ParallelBuilder, Orchestration(steps:).
- Validate impacted files list for code/tests/docs.

Expected Output:
- Short checklist of finalized signatures and removal targets.
- Verified list of files likely to change.

Constraints:
- Do not modify plan.
- Keep API names Swifty and minimal.
