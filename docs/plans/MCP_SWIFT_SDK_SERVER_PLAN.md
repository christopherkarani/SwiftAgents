# MCP Swift SDK Server Plan (Immutable)

Status: Locked  
Owner: Orchestrator  
Date: 2026-02-12

## Goals
- Add first-class MCP server support in Swarm using `modelcontextprotocol/swift-sdk` (`MCP` product).
- Expose `ListTools` and `CallTool` through a real MCP `Server` with `withMethodHandler(...)`.
- Keep protocol transport handling separate from Swarm tool business logic.
- Preserve deterministic behavior for approval/interrupt/error paths with actionable metadata.
- Ship tests, implementation, docs, and a runnable stdio example.

## Constraints
- Use adapter boundaries between MCP protocol layer and Swarm runtime.
- Keep transport pluggable; implement stdio first.
- Maintain strict concurrency safety and `Sendable` correctness.
- Tests must be written before implementation of new behavior.
- Existing MCP client APIs in Swarm must remain functional.

## Non-Goals
- Replacing existing `HTTPMCPServer` client transport.
- Implementing full MCP resources/prompts/sampling server methods in this change.
- Adding networked server transport unless already trivial from SDK APIs.

## Architecture Decisions
- Introduce protocol boundary:
  - `SwarmMCPToolCatalog`: source of MCP-compatible tool descriptors.
  - `SwarmMCPToolExecutor`: executes tool by stable name + args.
- Introduce deterministic mapper types:
  - Tool schema mapping from Swarm `ToolSchema` -> SDK tool input schema.
  - Value mapping between Swarm `SendableValue` and SDK JSON value type.
  - Error mapping from Swarm errors -> MCP `CallTool` error/result with metadata.
- Introduce service:
  - `SwarmMCPServerService` owns SDK `Server`.
  - Registers `ListTools` and `CallTool` handlers with `withMethodHandler(...)`.
  - Exposes start/stop lifecycle around stdio transport.
- Add observability hooks:
  - tools listed count
  - call latency
  - success/failure counts
  - approval-required/rejection counts

## Deterministic Error Semantics
- Unknown tool -> deterministic “unknown tool” response/error.
- Invalid arguments -> deterministic validation response/error.
- Execution failure -> deterministic internal failure response/error.
- Approval required/rejected -> deterministic response/error plus metadata:
  - machine-readable code
  - user-action hint
  - optional prompt/reason payload
- Timeout/cancellation -> deterministic timeout/cancel response/error.

## Work Packages
1. `docs/work-packages/mcp-wp1-tests.md`
2. `docs/work-packages/mcp-wp2-core-service.md`
3. `docs/work-packages/mcp-wp3-runtime-example-docs.md`
4. `docs/work-packages/mcp-wp4-review.md`

## Execution Order
1. SDK intake and API verification.
2. Tests first (failing).
3. Core implementation.
4. Runtime/example/docs.
5. Review and gap fixes.

## Task to Agent Mapping
- Context/research agents: done (MCP surface, tool semantics, test patterns).
- Test implementation agent: WP1.
- Core implementation agent: WP2.
- Runtime/docs implementation agent: WP3.
- Review agents: WP4 (2 reviewers).

## Acceptance Checks
- MCP client/inspector can connect to stdio server and call at least one tool.
- `ListTools` output is accurate and stable.
- `CallTool` routes correctly with deterministic error mapping.
- Concurrency safety validated in tests.
- Documentation includes enablement, transports, mapping rules, error semantics.

