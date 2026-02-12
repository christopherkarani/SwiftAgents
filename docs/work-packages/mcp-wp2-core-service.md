Prompt:
Implement core MCP server service and adapter boundaries with the official MCP Swift SDK.

Goal:
Deliver `SwarmMCPServerService` with real SDK `Server` method handlers for `ListTools` and `CallTool`, using adapter protocols and deterministic mapping/error behavior.

Task Breakdown:
1. Add dependency wiring in `Package.swift` for `.product(name: "MCP", package: "swift-sdk")`.
2. Implement protocol boundaries:
- `SwarmMCPToolCatalog`
- `SwarmMCPToolExecutor`
3. Implement mapping types:
- Swarm `ToolSchema` -> SDK `Tool`
- SDK arguments -> Swarm `SendableValue`
- Swarm execution result -> SDK `CallTool` content
- Swarm errors -> deterministic MCP error/result with metadata
4. Implement `SwarmMCPServerService`:
- Own SDK `Server`.
- Register `withMethodHandler(ListTools.self)` and `withMethodHandler(CallTool.self)`.
- Lifecycle start/stop around stdio transport.
5. Add lightweight observability counters/logs for list/call events and outcomes.

Expected Output:
- New source files in `Sources/Swarm/MCP/` for service, protocols, mappings, and error semantics.
- Compilation passes for new MCP service APIs.

Constraints:
- Do not modify plan documents.
- Keep protocol layer separate from business logic.
- Preserve strict concurrency safety (`Sendable`, actor isolation where needed).

