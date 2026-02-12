Prompt:
Add runtime enablement docs and example executable wiring for stdio MCP server startup.

Goal:
Provide an actionable path for users to run Swarm as an MCP server and understand transports, mappings, and deterministic error semantics.

Task Breakdown:
1. Add or update docs with:
- How to enable/start MCP server service
- Supported transports (stdio minimum)
- Tool mapping rules
- Error semantics and approval-required metadata
2. Add a small executable/demo entrypoint showing stdio server startup and adapter wiring.
3. Ensure docs match implemented APIs and terminology.

Expected Output:
- Updated `docs/mcp.md` (and related docs as needed).
- Example code under an existing demo target or a focused example file.

Constraints:
- Do not modify plan documents.
- Keep examples minimal, compile-safe, and deterministic.

