Prompt:
Goal:
Clarify Transform intent and update Router DSL documentation.
Task Breakdown:
- Update Transform doc comment: input-in, string-out.
- Update `docs/dsl.md` and `docs/orchestration.md`:
  - Distinguish `Transform` vs `OutputTransformer`.
  - Replace “single Otherwise only” with ordered multi-Otherwise behavior.
  - Add a short multi-Otherwise example.
  - Include `use:` overload example if implemented.
- Run `swift test --filter BreakingAPIChangesTests` to verify changes.
Expected Output:
- Updated docs and verified test run command.
Constraints:
- Keep docs concise and example-driven.
- Do not edit plan documents.
