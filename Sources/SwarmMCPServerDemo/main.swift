import Foundation
import Swarm
import SwarmMCP

@main
struct SwarmMCPServerDemo {
    static func main() async throws {
        Log.bootstrap()

        let registry = ToolRegistry(
            tools: [
                DateTimeTool(),
                StringTool(),
            ]
        )

        let adapter = SwarmMCPToolRegistryAdapter(registry: registry)
        let service = SwarmMCPServerService(
            name: "swarm-mcp-demo",
            version: Swarm.version,
            instructions: "Swarm MCP demo server exposing built-in tools.",
            toolCatalog: adapter,
            toolExecutor: adapter
        )

        try await service.startStdio()
        await service.waitUntilCompleted()
    }
}
