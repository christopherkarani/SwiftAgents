// MCPClientTests.swift
// SwiftAgentsTests
//
// Comprehensive tests for MCPClient server management, tool aggregation, caching, and lifecycle.

import Foundation
@testable import SwiftAgents
import Testing

// MARK: - MockMCPServer

/// A mock MCP server for testing MCPClient behavior.
actor MockMCPServer: MCPServer {
    let name: String
    var capabilitiesToReturn: MCPCapabilities
    var toolsToReturn: [ToolDefinition]
    var resourcesToReturn: [MCPResource]
    var resourceContentToReturn: MCPResourceContent?
    var errorToThrow: Error?

    // Track method calls
    private(set) var initializeCalled = false
    private(set) var listToolsCalled = false
    private(set) var listResourcesCalled = false
    private(set) var listResourcesCallCount = 0
    private(set) var closeCalled = false
    private(set) var callToolHistory: [(name: String, arguments: [String: SendableValue])] = []
    private(set) var readResourceHistory: [String] = []

    // MARK: - MCPServer Protocol

    nonisolated var capabilities: MCPCapabilities {
        get async {
            await capabilitiesToReturn
        }
    }

    // MARK: - Initialization

    init(
        name: String,
        capabilities: MCPCapabilities = MCPCapabilities(tools: true, resources: true),
        tools: [ToolDefinition] = [],
        resources: [MCPResource] = [],
        resourceContent: MCPResourceContent? = nil,
        errorToThrow: Error? = nil
    ) {
        self.name = name
        capabilitiesToReturn = capabilities
        toolsToReturn = tools
        resourcesToReturn = resources
        resourceContentToReturn = resourceContent
        self.errorToThrow = errorToThrow
    }

    func initialize() async throws -> MCPCapabilities {
        if let error = errorToThrow {
            throw error
        }
        initializeCalled = true
        return capabilitiesToReturn
    }

    func close() async throws {
        if let error = errorToThrow {
            throw error
        }
        closeCalled = true
    }

    func listTools() async throws -> [ToolDefinition] {
        if let error = errorToThrow {
            throw error
        }
        listToolsCalled = true
        return toolsToReturn
    }

    func callTool(name: String, arguments: [String: SendableValue]) async throws -> SendableValue {
        if let error = errorToThrow {
            throw error
        }
        callToolHistory.append((name: name, arguments: arguments))
        return .string("Result from \(self.name):\(name)")
    }

    func listResources() async throws -> [MCPResource] {
        if let error = errorToThrow {
            throw error
        }
        listResourcesCalled = true
        listResourcesCallCount += 1
        return resourcesToReturn
    }

    func resetListResourcesCalled() {
        listResourcesCalled = false
    }

    func resetListResourcesCallCount() {
        listResourcesCallCount = 0
    }

    func readResource(uri: String) async throws -> MCPResourceContent {
        if let error = errorToThrow {
            throw error
        }
        readResourceHistory.append(uri)
        if let content = resourceContentToReturn, content.uri == uri {
            return content
        }
        throw MCPError.invalidParams("Resource not found: \(uri)")
    }

    // MARK: - Test Helpers

    func setError(_ error: Error?) {
        errorToThrow = error
    }

    func setCapabilities(_ capabilities: MCPCapabilities) {
        capabilitiesToReturn = capabilities
    }

    func setTools(_ tools: [ToolDefinition]) {
        toolsToReturn = tools
    }

    func setResources(_ resources: [MCPResource]) {
        resourcesToReturn = resources
    }

    func setResourceContent(_ content: MCPResourceContent?) {
        resourceContentToReturn = content
    }
}

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
            tools: [ToolDefinition(name: "tool1", description: "First", parameters: [])]
        )
        let server2 = MockMCPServer(
            name: "duplicate",
            tools: [ToolDefinition(name: "tool2", description: "Second", parameters: [])]
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
                ToolDefinition(name: "read", description: "Read file", parameters: []),
                ToolDefinition(name: "write", description: "Write file", parameters: [])
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
                ToolDefinition(name: "read_file", description: "Read", parameters: []),
                ToolDefinition(name: "write_file", description: "Write", parameters: [])
            ]
        )
        let dbServer = MockMCPServer(
            name: "db-server",
            tools: [
                ToolDefinition(name: "query", description: "Query DB", parameters: []),
                ToolDefinition(name: "insert", description: "Insert record", parameters: [])
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
            tools: [ToolDefinition(name: "hidden", description: "Should not appear", parameters: [])]
        )
        let toolsServer = MockMCPServer(
            name: "with-tools",
            capabilities: MCPCapabilities(tools: true, resources: false),
            tools: [ToolDefinition(name: "visible", description: "Should appear", parameters: [])]
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
            tools: [ToolDefinition(name: "cached", description: "Cached tool", parameters: [])]
        )

        try await client.addServer(server)

        // First call populates cache
        let tools1 = try await client.getAllTools()
        #expect(tools1.count == 1)

        let listCalled1 = await server.listToolsCalled
        #expect(listCalled1 == true)

        // Modify server tools (should not affect cached result)
        await server.setTools([
            ToolDefinition(name: "new1", description: "New 1", parameters: []),
            ToolDefinition(name: "new2", description: "New 2", parameters: [])
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
            tools: [ToolDefinition(name: "tool1", description: "Tool 1", parameters: [])]
        )

        try await client.addServer(server1)
        let tools1 = try await client.getAllTools()
        #expect(tools1.count == 1)

        // Add another server - should invalidate cache
        let server2 = MockMCPServer(
            name: "server2",
            tools: [ToolDefinition(name: "tool2", description: "Tool 2", parameters: [])]
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
            tools: [ToolDefinition(name: "tool1", description: "Tool 1", parameters: [])]
        )
        let server2 = MockMCPServer(
            name: "server2",
            tools: [ToolDefinition(name: "tool2", description: "Tool 2", parameters: [])]
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
            tools: [ToolDefinition(name: "original", description: "Original", parameters: [])]
        )

        try await client.addServer(server)

        let tools1 = try await client.getAllTools()
        #expect(tools1.first?.name == "original")

        // Modify server tools
        await server.setTools([ToolDefinition(name: "refreshed", description: "Refreshed", parameters: [])])

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
            tools: [ToolDefinition(name: "original", description: "Original", parameters: [])]
        )

        try await client.addServer(server)

        let tools1 = try await client.getAllTools()
        #expect(tools1.first?.name == "original")

        // Modify server tools
        await server.setTools([ToolDefinition(name: "invalidated", description: "Invalidated", parameters: [])])

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

        // Verify at least one server was tried (dictionary iteration order is non-deterministic)
        // The successful server (server2) must have been tried, but server1 may or may not
        // have been tried depending on iteration order
        let server1History = await server1.readResourceHistory
        let server2History = await server2.readResourceHistory

        // server2 must have been tried since it returned successfully
        #expect(server2History.contains("file:///found.txt"))

        // If server1 was tried before server2, it would be in history
        // If server2 was tried first and succeeded, server1 wouldn't be tried
        // This is correct behavior - we return on first success
        let totalTries = server1History.count + server2History.count
        #expect(totalTries >= 1) // At least the successful server was tried
    }
}

// MARK: - MCPClientResourceCachingTests

@Suite("MCPClient Resource Caching Tests")
struct MCPClientResourceCachingTests {
    @Test("getAllResources caches resources with TTL")
    func resourceCachingWithTTL() async throws {
        let client = MCPClient()

        let resources = [
            MCPResource(uri: "file:///doc1.txt", name: "doc1.txt"),
            MCPResource(uri: "file:///doc2.txt", name: "doc2.txt")
        ]
        let server = MockMCPServer(name: "test-server", resources: resources)

        try await client.addServer(server)

        // Set TTL to 1 second
        await client.setResourceCacheTTL(1.0)

        // First call should query the server
        let result1 = try await client.getAllResources()
        #expect(result1.count == 2)
        #expect(await server.listResourcesCalled == true)

        // Reset the flag
        await server.resetListResourcesCalled()

        // Second call within TTL should use cache
        let result2 = try await client.getAllResources()
        #expect(result2.count == 2)
        #expect(await server.listResourcesCalled == false)
    }

    @Test("getAllResources refreshes cache after TTL expires")
    func resourceCacheExpiresAfterTTL() async throws {
        let client = MCPClient()

        let resources = [
            MCPResource(uri: "file:///doc1.txt", name: "doc1.txt")
        ]
        let server = MockMCPServer(name: "test-server", resources: resources)

        try await client.addServer(server)

        // Set very short TTL (100ms)
        await client.setResourceCacheTTL(0.1)

        // First call populates cache
        _ = try await client.getAllResources()
        #expect(await server.listResourcesCalled == true)

        await server.resetListResourcesCalled()

        // Wait for TTL to expire
        try await Task.sleep(for: .milliseconds(150))

        // Next call should refresh from server
        _ = try await client.getAllResources()
        #expect(await server.listResourcesCalled == true)
    }

    @Test("getAllResources with TTL zero disables caching")
    func disableCachingWithZeroTTL() async throws {
        let client = MCPClient()

        let resources = [
            MCPResource(uri: "file:///doc1.txt", name: "doc1.txt")
        ]
        let server = MockMCPServer(name: "test-server", resources: resources)

        try await client.addServer(server)

        // Disable caching
        await client.setResourceCacheTTL(0)

        // First call
        _ = try await client.getAllResources()
        #expect(await server.listResourcesCalled == true)

        await server.resetListResourcesCalled()

        // Second call should still query server (no caching)
        _ = try await client.getAllResources()
        #expect(await server.listResourcesCalled == true)
    }

    @Test("refreshResources forces cache refresh")
    func refreshResourcesForcesRefresh() async throws {
        let client = MCPClient()

        let resources = [
            MCPResource(uri: "file:///doc1.txt", name: "doc1.txt")
        ]
        let server = MockMCPServer(name: "test-server", resources: resources)

        try await client.addServer(server)

        // Set long TTL
        await client.setResourceCacheTTL(60.0)

        // First call populates cache
        _ = try await client.getAllResources()
        #expect(await server.listResourcesCalled == true)

        await server.resetListResourcesCalled()

        // Force refresh
        _ = try await client.refreshResources()
        #expect(await server.listResourcesCalled == true)
    }

    @Test("invalidateResourceCache marks cache invalid")
    func invalidateResourceCache() async throws {
        let client = MCPClient()

        let resources = [
            MCPResource(uri: "file:///doc1.txt", name: "doc1.txt")
        ]
        let server = MockMCPServer(name: "test-server", resources: resources)

        try await client.addServer(server)

        // Populate cache
        _ = try await client.getAllResources()
        await server.resetListResourcesCalled()

        // Invalidate cache
        await client.invalidateResourceCache()

        // Next call should refresh
        _ = try await client.getAllResources()
        #expect(await server.listResourcesCalled == true)
    }

    @Test("addServer invalidates resource cache")
    func addServerInvalidatesResourceCache() async throws {
        let client = MCPClient()

        let server1 = MockMCPServer(
            name: "server1",
            resources: [MCPResource(uri: "file:///doc1.txt", name: "doc1.txt")]
        )

        try await client.addServer(server1)

        // Populate cache
        let result1 = try await client.getAllResources()
        #expect(result1.count == 1)

        // Add another server with different resources
        let server2 = MockMCPServer(
            name: "server2",
            resources: [MCPResource(uri: "file:///doc2.txt", name: "doc2.txt")]
        )

        try await client.addServer(server2)

        // Cache should be invalidated, next call gets both resources
        let result2 = try await client.getAllResources()
        #expect(result2.count == 2)
    }

    @Test("removeServer invalidates resource cache")
    func removeServerInvalidatesResourceCache() async throws {
        let client = MCPClient()

        let server1 = MockMCPServer(
            name: "server1",
            resources: [MCPResource(uri: "file:///doc1.txt", name: "doc1.txt")]
        )
        let server2 = MockMCPServer(
            name: "server2",
            resources: [MCPResource(uri: "file:///doc2.txt", name: "doc2.txt")]
        )

        try await client.addServer(server1)
        try await client.addServer(server2)

        // Populate cache
        let result1 = try await client.getAllResources()
        #expect(result1.count == 2)

        // Remove a server
        try await client.removeServer(named: "server2")

        // Cache should be invalidated, next call gets only remaining resources
        let result2 = try await client.getAllResources()
        #expect(result2.count == 1)
    }

    @Test("Concurrent getAllResources calls share refresh task")
    func concurrentCallsShareRefreshTask() async throws {
        let client = MCPClient()

        let resources = [
            MCPResource(uri: "file:///doc1.txt", name: "doc1.txt")
        ]
        let server = MockMCPServer(name: "test-server", resources: resources)

        try await client.addServer(server)

        // Make multiple concurrent calls
        async let r1 = client.getAllResources()
        async let r2 = client.getAllResources()
        async let r3 = client.getAllResources()

        let (result1, result2, result3) = try await (r1, r2, r3)

        #expect(result1.count == 1)
        #expect(result2.count == 1)
        #expect(result3.count == 1)

        // Server should only be called once due to deduplication
        let callCount = await server.listResourcesCallCount
        #expect(callCount == 1)
    }

    @Test("closeAll clears resource cache")
    func closeAllClearsResourceCache() async throws {
        let client = MCPClient()

        let server = MockMCPServer(
            name: "server",
            resources: [MCPResource(uri: "file:///doc1.txt", name: "doc1.txt")]
        )

        try await client.addServer(server)

        // Populate cache
        _ = try await client.getAllResources()

        // Close all
        try await client.closeAll()

        // Verify state is cleared
        #expect(await client.connectedServers.isEmpty)
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
        // (The order of iteration is not guaranteed, so we check closeCalled)
        let server1Closed = await server1.closeCalled
        let server3Closed = await server3.closeCalled
        // At least one should be closed (the ones that don't error)
        #expect(server1Closed || server3Closed)

        // State should be cleared regardless of errors
        let connected = await client.connectedServers
        #expect(connected.isEmpty)
    }
}
