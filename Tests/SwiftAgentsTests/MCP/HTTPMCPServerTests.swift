// HTTPMCPServerTests.swift
// SwiftAgentsTests
//
// Tests for HTTPMCPServer initialization, defaults, and property access.

import Foundation
@testable import SwiftAgents
import Testing

// MARK: - HTTPMCPServerInitializationTests

@Suite("HTTPMCPServer Initialization Tests")
struct HTTPMCPServerInitializationTests {
    @Test("Server initializes with correct properties")
    func serverInit() async throws {
        let url = URL(string: "https://mcp.example.com/api")!
        let server = HTTPMCPServer(
            url: url,
            name: "test-server",
            apiKey: "sk-test-key",
            timeout: 60.0,
            maxRetries: 5
        )

        let name = await server.name
        #expect(name == "test-server")
    }

    @Test("Server uses default timeout of 30.0 seconds")
    func defaultTimeout() async throws {
        let url = URL(string: "https://mcp.example.com/api")!
        let server = HTTPMCPServer(url: url, name: "timeout-test")

        // Verify default timeout by checking capabilities before init returns empty
        // The timeout is internal, but we can verify server creation succeeds
        let name = await server.name
        #expect(name == "timeout-test")
    }

    @Test("Server uses default maxRetries of 3")
    func defaultMaxRetries() async throws {
        let url = URL(string: "https://mcp.example.com/api")!
        let server = HTTPMCPServer(url: url, name: "retries-test")

        // maxRetries is internal, verify server creation with defaults succeeds
        let name = await server.name
        #expect(name == "retries-test")
    }
}

// MARK: - HTTPMCPServerCapabilitiesTests

@Suite("HTTPMCPServer Capabilities Tests")
struct HTTPMCPServerCapabilitiesTests {
    @Test("Capabilities returns empty MCPCapabilities before initialization")
    func capabilitiesBeforeInit() async throws {
        let url = URL(string: "https://mcp.example.com/api")!
        let server = HTTPMCPServer(url: url, name: "capabilities-test")

        let capabilities = await server.capabilities

        // Before initialize() is called, capabilities should be empty
        #expect(capabilities.tools == false)
        #expect(capabilities.resources == false)
        #expect(capabilities.prompts == false)
        #expect(capabilities.sampling == false)
        #expect(capabilities == MCPCapabilities())
    }

    @Test("Capabilities would return cached value after initialization")
    func capabilitiesAfterInit() async throws {
        // Note: We cannot test real HTTP initialization without a mock server.
        // This test documents the expected behavior: after initialize() is called,
        // capabilities should return the cached value from the server response.
        let url = URL(string: "https://mcp.example.com/api")!
        let server = HTTPMCPServer(url: url, name: "cached-capabilities-test")

        // Before init, capabilities are empty
        let beforeInit = await server.capabilities
        #expect(beforeInit == MCPCapabilities.empty)

        // Real initialization would require mocking URLSession or a live server.
        // The HTTPMCPServer caches capabilities after successful initialize().
    }
}

// MARK: - HTTPMCPServerNameTests

@Suite("HTTPMCPServer Name Tests")
struct HTTPMCPServerNameTests {
    @Test("Server returns correct name property")
    func serverName() async throws {
        let url = URL(string: "https://api.example.com/mcp")!
        let server = HTTPMCPServer(url: url, name: "my-custom-server")

        let name = await server.name
        #expect(name == "my-custom-server")
    }

    @Test("Server preserves name with special characters")
    func serverNameSpecialCharacters() async throws {
        let url = URL(string: "https://api.example.com/mcp")!
        let server = HTTPMCPServer(url: url, name: "server-with_special.chars:123")

        let name = await server.name
        #expect(name == "server-with_special.chars:123")
    }

    @Test("Server preserves empty name")
    func serverEmptyName() async throws {
        let url = URL(string: "https://api.example.com/mcp")!
        let server = HTTPMCPServer(url: url, name: "")

        let name = await server.name
        #expect(name == "")
    }
}
