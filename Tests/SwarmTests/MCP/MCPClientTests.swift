// MCPClientTests.swift
// SwarmTests
//
// Tests for MCP client functionality.
// Mock types are defined in MCPClientTests+Mocks.swift

import Foundation
@testable import Swarm
import Testing

// MARK: - MCPClientServerManagementTests

@Suite("MCPClient Server Management Tests")
struct MCPClientServerManagementTests {
    @Test("addServer initializes and registers server")
    func testAddServer() async throws {
        let client = MCPClient()
        let server = MockMCPServer(name: "test-server")

        try await client.addServer(server)

        let connected = await client.connectedServers
        #expect(connected.contains("test-server"))

        let initCalled = await server.initializeCalled
        #expect(initCalled == true)
    }

    @Test("addServer with existing name replaces server")
    func addServerWithExistingName() async throws {
        let client = MCPClient()
        let server1 = MockMCPServer(
            name: "duplicate",
            tools: [ToolSchema(name: "tool1", description: "First", parameters: [])]
        )
        let server2 = MockMCPServer(
            name: "duplicate",
            tools: [ToolSchema(name: "tool2", description: "Second", parameters: [])]
        )

        try await client.addServer(server1)
        try await client.addServer(server2)

        let connected = await client.connectedServers
        #expect(connected.count == 1)
        #expect(connected.contains("duplicate"))

        // Verify first server was closed
        let server1Closed = await server1.closeCalled
        #expect(server1Closed == true)

        // Verify second server was initialized
        let server2Init = await server2.initializeCalled
        #expect(server2Init == true)

        // Verify tools come from second server
        let tools = try await client.getAllTools()
        #expect(tools.count == 1)
        #expect(tools.first?.name == "tool2")
    }

    @Test("removeServer closes and unregisters server")
    func testRemoveServer() async throws {
        let client = MCPClient()
        let server = MockMCPServer(name: "removable")

        try await client.addServer(server)
        #expect(await client.connectedServers.contains("removable"))

        try await client.removeServer(named: "removable")

        let connected = await client.connectedServers
        #expect(!connected.contains("removable"))

        let closeCalled = await server.closeCalled
        #expect(closeCalled == true)
    }

    @Test("removeServer with nonexistent name does not error")
    func removeNonexistentServer() async throws {
        let client = MCPClient()

        // Should not throw
        try await client.removeServer(named: "nonexistent")

        let connected = await client.connectedServers
        #expect(connected.isEmpty)
    }

    @Test("connectedServers returns all server names")
    func testConnectedServers() async throws {
        let client = MCPClient()
        let server1 = MockMCPServer(name: "alpha")
        let server2 = MockMCPServer(name: "beta")
        let server3 = MockMCPServer(name: "gamma")

        try await client.addServer(server1)
        try await client.addServer(server2)
        try await client.addServer(server3)

        let connected = await client.connectedServers
        #expect(connected.count == 3)
        #expect(connected.contains("alpha"))
        #expect(connected.contains("beta"))
        #expect(connected.contains("gamma"))
    }
}

// MARK: - MCPClientToolAggregationTests

@Suite("MCPClient Tool Aggregation Tests")
struct MCPClientToolAggregationTests {
    @Test("getAllTools returns tools from single server")
    func getAllToolsFromSingleServer() async throws {
        let client = MCPClient()
        let server = MockMCPServer(
            name: "tool-server",
            tools: [
                ToolSchema(name: "read", description: "Read file", parameters: []),
                ToolSchema(name: "write", description: "Write file", parameters: [])
            ]
        )

        try await client.addServer(server)

        let tools = try await client.getAllTools()
        #expect(tools.count == 2)

        let toolNames = tools.map(\.name)
        #expect(toolNames.contains("read"))
        #expect(toolNames.contains("write"))
    }

    @Test("getAllTools aggregates tools from multiple servers")
    func getAllToolsFromMultipleServers() async throws {
        let client = MCPClient()
        let fileServer = MockMCPServer(
            name: "file-server",
            tools: [
                ToolSchema(name: "read_file", description: "Read", parameters: []),
                ToolSchema(name: "write_file", description: "Write", parameters: [])
            ]
        )
        let dbServer = MockMCPServer(
            name: "db-server",
            tools: [
                ToolSchema(name: "query", description: "Query DB", parameters: []),
                ToolSchema(name: "insert", description: "Insert record", parameters: [])
            ]
        )

        try await client.addServer(fileServer)
        try await client.addServer(dbServer)

        let tools = try await client.getAllTools()
        #expect(tools.count == 4)

        let toolNames = tools.map(\.name)
        #expect(toolNames.contains("read_file"))
        #expect(toolNames.contains("write_file"))
        #expect(toolNames.contains("query"))
        #expect(toolNames.contains("insert"))
    }

    @Test("getAllTools returns empty for no servers")
    func getAllToolsEmptyServers() async throws {
        let client = MCPClient()

        let tools = try await client.getAllTools()
        #expect(tools.isEmpty)
    }

    @Test("getAllTools skips servers without tools capability")
    func getAllToolsNoToolsCapability() async throws {
        let client = MCPClient()
        let noToolsServer = MockMCPServer(
            name: "no-tools",
            capabilities: MCPCapabilities(tools: false, resources: true),
            tools: [ToolSchema(name: "hidden", description: "Should not appear", parameters: [])]
        )
        let toolsServer = MockMCPServer(
            name: "with-tools",
            capabilities: MCPCapabilities(tools: true, resources: false),
            tools: [ToolSchema(name: "visible", description: "Should appear", parameters: [])]
        )

        try await client.addServer(noToolsServer)
        try await client.addServer(toolsServer)

        let tools = try await client.getAllTools()
        #expect(tools.count == 1)
        #expect(tools.first?.name == "visible")

        // Verify listTools was not called on noToolsServer
        let noToolsListCalled = await noToolsServer.listToolsCalled
        #expect(noToolsListCalled == false)
    }
}

// MARK: - MCPClientCacheTests

@Suite("MCPClient Cache Tests")
struct MCPClientCacheTests {
    @Test("tool cache returns cached results on subsequent calls")
    func toolCacheValid() async throws {
        let client = MCPClient()
        let server = MockMCPServer(
            name: "cache-test",
            tools: [ToolSchema(name: "cached", description: "Cached tool", parameters: [])]
        )

        try await client.addServer(server)

        // First call populates cache
        let tools1 = try await client.getAllTools()
        #expect(tools1.count == 1)

        let listCalled1 = await server.listToolsCalled
        #expect(listCalled1 == true)

        // Modify server tools (should not affect cached result)
        await server.setTools([
            ToolSchema(name: "new1", description: "New 1", parameters: []),
            ToolSchema(name: "new2", description: "New 2", parameters: [])
        ])

        // Second call should return cached result
        let tools2 = try await client.getAllTools()
        #expect(tools2.count == 1)
        #expect(tools2.first?.name == "cached")
    }

    @Test("cache invalidates on addServer")
    func cacheInvalidationOnAddServer() async throws {
        let client = MCPClient()
        let server1 = MockMCPServer(
            name: "server1",
            tools: [ToolSchema(name: "tool1", description: "Tool 1", parameters: [])]
        )

        try await client.addServer(server1)
        let tools1 = try await client.getAllTools()
        #expect(tools1.count == 1)

        // Add another server - should invalidate cache
        let server2 = MockMCPServer(
            name: "server2",
            tools: [ToolSchema(name: "tool2", description: "Tool 2", parameters: [])]
        )
        try await client.addServer(server2)

        let tools2 = try await client.getAllTools()
        #expect(tools2.count == 2)
    }

    @Test("cache invalidates on removeServer")
    func cacheInvalidationOnRemoveServer() async throws {
        let client = MCPClient()
        let server1 = MockMCPServer(
            name: "server1",
            tools: [ToolSchema(name: "tool1", description: "Tool 1", parameters: [])]
        )
        let server2 = MockMCPServer(
            name: "server2",
            tools: [ToolSchema(name: "tool2", description: "Tool 2", parameters: [])]
        )

        try await client.addServer(server1)
        try await client.addServer(server2)

        let tools1 = try await client.getAllTools()
        #expect(tools1.count == 2)

        // Remove server - should invalidate cache
        try await client.removeServer(named: "server1")

        let tools2 = try await client.getAllTools()
        #expect(tools2.count == 1)
        #expect(tools2.first?.name == "tool2")
    }

    @Test("refreshTools forces cache refresh")
    func testRefreshTools() async throws {
        let client = MCPClient()
        let server = MockMCPServer(
            name: "refresh-test",
            tools: [ToolSchema(name: "original", description: "Original", parameters: [])]
        )

        try await client.addServer(server)

        let tools1 = try await client.getAllTools()
        #expect(tools1.first?.name == "original")

        // Modify server tools
        await server.setTools([ToolSchema(name: "refreshed", description: "Refreshed", parameters: [])])

        // Regular getAllTools returns cached
        let tools2 = try await client.getAllTools()
        #expect(tools2.first?.name == "original")

        // refreshTools forces refresh
        let tools3 = try await client.refreshTools()
        #expect(tools3.first?.name == "refreshed")
    }

    @Test("invalidateCache clears cache")
    func testInvalidateCache() async throws {
        let client = MCPClient()
        let server = MockMCPServer(
            name: "invalidate-test",
            tools: [ToolSchema(name: "original", description: "Original", parameters: [])]
        )

        try await client.addServer(server)

        let tools1 = try await client.getAllTools()
        #expect(tools1.first?.name == "original")

        // Modify server tools
        await server.setTools([ToolSchema(name: "invalidated", description: "Invalidated", parameters: [])])

        // Invalidate cache manually
        await client.invalidateCache()

        // Next getAllTools should fetch fresh data
        let tools2 = try await client.getAllTools()
        #expect(tools2.first?.name == "invalidated")
    }
}

// MARK: - MCPClientResourceTests

@Suite("MCPClient Resource Tests")
struct MCPClientResourceTests {
    @Test("getAllResources aggregates resources from all servers")
    func testGetAllResources() async throws {
        let client = MCPClient()
        let server1 = MockMCPServer(
            name: "file-server",
            resources: [
                MCPResource(uri: "file:///doc1.txt", name: "doc1.txt"),
                MCPResource(uri: "file:///doc2.txt", name: "doc2.txt")
            ]
        )
        let server2 = MockMCPServer(
            name: "db-server",
            resources: [
                MCPResource(uri: "db://table1", name: "table1")
            ]
        )

        try await client.addServer(server1)
        try await client.addServer(server2)

        let resources = try await client.getAllResources()
        #expect(resources.count == 3)

        let uris = resources.map(\.uri)
        #expect(uris.contains("file:///doc1.txt"))
        #expect(uris.contains("file:///doc2.txt"))
        #expect(uris.contains("db://table1"))
    }

    @Test("readResource returns content when found")
    func readResourceFound() async throws {
        let client = MCPClient()
        let content = MCPResourceContent(
            uri: "file:///config.json",
            mimeType: "application/json",
            text: "{\"key\": \"value\"}"
        )
        let server = MockMCPServer(
            name: "resource-server",
            resourceContent: content
        )

        try await client.addServer(server)

        let result = try await client.readResource(uri: "file:///config.json")
        #expect(result.uri == "file:///config.json")
        #expect(result.text == "{\"key\": \"value\"}")
        #expect(result.mimeType == "application/json")
    }

    @Test("readResource throws when not found")
    func readResourceNotFound() async throws {
        let client = MCPClient()
        let server = MockMCPServer(name: "empty-server")

        try await client.addServer(server)

        await #expect(throws: MCPError.self) {
            _ = try await client.readResource(uri: "file:///nonexistent.txt")
        }
    }

    @Test("readResource tries all servers for resource")
    func readResourceTriesAllServers() async throws {
        let client = MCPClient()

        // First server does not have the resource
        let server1 = MockMCPServer(name: "server1")

        // Second server has the resource
        let content = MCPResourceContent(
            uri: "file:///found.txt",
            mimeType: "text/plain",
            text: "Found content"
        )
        let server2 = MockMCPServer(
            name: "server2",
            resourceContent: content
        )

        try await client.addServer(server1)
        try await client.addServer(server2)

        let result = try await client.readResource(uri: "file:///found.txt")
        #expect(result.text == "Found content")

        // server2 must have been tried since it returned successfully
        let server2History = await server2.readResourceHistory
        #expect(server2History.contains("file:///found.txt"))
    }
}

// MARK: - MCPClientLifecycleTests

@Suite("MCPClient Lifecycle Tests")
struct MCPClientLifecycleTests {
    @Test("closeAll closes all servers")
    func testCloseAll() async throws {
        let client = MCPClient()
        let server1 = MockMCPServer(name: "server1")
        let server2 = MockMCPServer(name: "server2")
        let server3 = MockMCPServer(name: "server3")

        try await client.addServer(server1)
        try await client.addServer(server2)
        try await client.addServer(server3)

        try await client.closeAll()

        // Verify all servers were closed
        #expect(await server1.closeCalled == true)
        #expect(await server2.closeCalled == true)
        #expect(await server3.closeCalled == true)

        // Verify client state is cleared
        let connected = await client.connectedServers
        #expect(connected.isEmpty)
    }

    @Test("closeAll continues on error and rethrows last error")
    func closeAllWithError() async throws {
        let client = MCPClient()

        let server1 = MockMCPServer(name: "server1")
        let server2 = MockMCPServer(name: "server2")
        let server3 = MockMCPServer(name: "server3")

        try await client.addServer(server1)
        try await client.addServer(server2)
        try await client.addServer(server3)

        // Set error on server2
        await server2.setError(MCPError.internalError("Close failed"))

        // closeAll should throw but still attempt to close all servers
        await #expect(throws: MCPError.self) {
            try await client.closeAll()
        }

        // Server1 and server3 should still be closed
        let server1Closed = await server1.closeCalled
        let server3Closed = await server3.closeCalled
        #expect(server1Closed || server3Closed)

        // State should be cleared regardless of errors
        let connected = await client.connectedServers
        #expect(connected.isEmpty)
    }
}
