// MCPClientTests+Caching.swift
// SwarmTests
//
// Resource caching tests for MCPClient.

import Foundation
@testable import Swarm
import Testing

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
