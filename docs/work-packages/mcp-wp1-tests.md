Prompt:
Author test-first coverage for MCP server support using the official MCP Swift SDK integration boundary.

Goal:
Create failing Swift Testing tests that specify contract behavior for `ListTools` and `CallTool` via `SwarmMCPServerService` adapters and deterministic mappings.

Task Breakdown:
1. Add test mocks/stubs for `SwarmMCPToolCatalog` and `SwarmMCPToolExecutor`.
2. Add contract tests for:
- `ListTools` returns stable deterministic tool ordering and schemas.
- `CallTool` success returns deterministic content.
- Unknown tool mapping.
- Invalid argument mapping.
- Execution failure mapping.
- Approval-required mapping with actionable metadata.
- Timeout/cancellation mapping.
- Parallel `CallTool` requests.
3. Ensure tests target new service/mapper interfaces rather than transport internals.
4. Keep tests deterministic and isolated with no network dependencies.

Expected Output:
- New/updated Swift Testing files under `Tests/SwarmTests/MCP/`.
- Tests fail initially due to missing implementation (or explicit `TODO` placeholders removed once implementation lands).

Constraints:
- Do not modify plan documents.
- Use `import Testing`.
- Do not introduce transport coupling in test assertions.

