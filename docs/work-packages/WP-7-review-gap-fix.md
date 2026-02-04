Prompt:
Review the `@AgentActor` macro changes, tests, and docs for correctness, type safety, and API misuse resistance; identify gaps and drive fixes.

Goal:
Ship a macro-based “easy mode” that coding agents can rely on without encountering signature mismatches or confusing docs.

Task Breakdown:
1. Review generated code shape for:
   - `Sendable` correctness and actor isolation
   - protocol conformance completeness (`AgentRuntime`)
   - environment fallback behavior consistency
   - session + hooks integration correctness
2. Review builder ergonomics:
   - typed tool bridging (no type erasure)
   - defaults and override behavior
3. Review docs/examples for drift and compilation plausibility.
4. Produce a short “gap checklist” with concrete fixes (file paths + deltas).

Expected Output:
- Review notes + gap checklist.
- Follow-up patch (if needed) to close gaps.

Constraints:
- Do not expand scope beyond `@AgentActor`/docs/tests unless a correctness issue forces it.

