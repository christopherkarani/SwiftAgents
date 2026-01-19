// MCPClient.swift
// SwiftAgents Framework
//
// A client for managing multiple MCP server connections and aggregating their tools and resources.

import Foundation

// MARK: - MCPClient

/// A client that manages multiple Model Context Protocol (MCP) server connections.
///
/// MCPClient provides a unified interface for working with multiple MCP servers,
/// aggregating their tools and resources into a single point of access. It handles
/// server lifecycle management, tool caching, and resource discovery.
///
/// ## Features
///
/// - **Multi-Server Management**: Connect to and manage multiple MCP servers simultaneously
/// - **Tool Aggregation**: Discover and cache tools from all connected servers
/// - **Resource Access**: Query resources across all servers with automatic server resolution
/// - **Lifecycle Management**: Properly initialize and close server connections
///
/// ## Example Usage
///
/// ```swift
/// // Create the client
/// let client = MCPClient()
///
/// // Add servers
/// let filesystemServer = HTTPMCPServer(name: "filesystem", baseURL: filesystemURL)
/// let databaseServer = HTTPMCPServer(name: "database", baseURL: databaseURL)
///
/// try await client.addServer(filesystemServer)
/// try await client.addServer(databaseServer)
///
/// // Discover all available tools
/// let tools = try await client.getAllTools()
/// print("Available tools: \(tools.map { $0.name })")
///
/// // Access resources
/// let resources = try await client.getAllResources()
/// for resource in resources {
///     let content = try await client.readResource(uri: resource.uri)
///     print("\(resource.name): \(content)")
/// }
///
/// // Clean up when done
/// try await client.closeAll()
/// ```
///
/// ## Thread Safety
///
/// MCPClient is implemented as an actor, ensuring thread-safe access to all
/// mutable state. All methods are safe to call concurrently from multiple
/// async contexts.
public actor MCPClient {
    // MARK: Public

    /// The names of all currently connected servers.
    ///
    /// Use this property to check which servers are registered with the client.
    ///
    /// ## Example
    /// ```swift
    /// let serverNames = await client.connectedServers
    /// print("Connected to: \(serverNames.joined(separator: ", "))")
    /// ```
    public var connectedServers: [String] {
        Array(servers.keys)
    }

    // MARK: - Initialization

    /// Creates a new MCP client with no connected servers.
    ///
    /// After creating the client, use `addServer(_:)` to connect to MCP servers.
    public init() {}

    // MARK: - Server Management

    /// Adds and initializes an MCP server.
    ///
    /// This method initializes the server connection and registers it with the client.
    /// The server becomes available for tool and resource queries after this call completes.
    ///
    /// - Parameter server: The MCP server to add.
    /// - Throws: `MCPError` if the server fails to initialize.
    ///
    /// ## Example
    /// ```swift
    /// let server = HTTPMCPServer(name: "my-server", baseURL: serverURL)
    /// try await client.addServer(server)
    /// print("Connected to \(server.name)")
    /// ```
    ///
    /// ## Note
    /// Adding a server with the same name as an existing server will replace
    /// the existing server after closing it.
    public func addServer(_ server: any MCPServer) async throws {
        // Close existing server with same name if present
        if let existing = servers[server.name] {
            try? await existing.close()
        }

        // Initialize the new server
        _ = try await server.initialize()

        // Register the server
        servers[server.name] = server

        // Invalidate both caches since we have a new server
        cacheValid = false
        resourceCacheValid = false
        resourceCacheTimestamp = nil
    }

    /// Removes and closes an MCP server by name.
    ///
    /// This method gracefully closes the server connection and removes it
    /// from the client's registry. Tools from this server will no longer
    /// be available after this call.
    ///
    /// - Parameter name: The name of the server to remove.
    /// - Throws: `MCPError` if the server fails to close cleanly.
    ///
    /// ## Example
    /// ```swift
    /// try await client.removeServer(named: "my-server")
    /// print("Disconnected from my-server")
    /// ```
    ///
    /// ## Note
    /// If no server with the given name exists, this method completes
    /// silently without throwing an error.
    public func removeServer(named name: String) async throws {
        guard let server = servers[name] else {
            return
        }

        // Close the server connection
        try await server.close()

        // Remove from registry
        servers.removeValue(forKey: name)

        // Invalidate both caches
        cacheValid = false
        resourceCacheValid = false
        resourceCacheTimestamp = nil
    }

    // MARK: - Tool Discovery

    /// Returns all tools from all connected servers.
    ///
    /// This method aggregates tools from all registered MCP servers. Results
    /// are cached for performance; subsequent calls return the cached tools
    /// until the cache is invalidated (by adding or removing servers).
    ///
    /// - Returns: An array of all available tools from all connected servers.
    /// - Throws: `MCPError` if tool discovery fails for any server.
    ///
    /// ## Example
    /// ```swift
    /// let tools = try await client.getAllTools()
    /// for tool in tools {
    ///     print("\(tool.name): \(tool.description)")
    /// }
    /// ```
    ///
    /// ## Caching Behavior
    /// Tools are cached after the first call. Use `refreshTools()` or
    /// `invalidateCache()` to force a refresh.
    public func getAllTools() async throws -> [any AnyJSONTool] {
        // Return cached tools if valid
        if cacheValid {
            return Array(toolCache.values)
        }

        // If a refresh is already in progress, wait for it instead of starting a new one.
        // This prevents concurrent cache rebuilds (race condition).
        if let ongoing = refreshTask {
            return try await ongoing.value
        }

        // Start a new refresh task
        let task = Task<[any AnyJSONTool], Error> {
            // Clear the cache
            toolCache.removeAll()

            // Collect tools from all servers
            for (_, server) in servers {
                let capabilities = await server.capabilities
                guard capabilities.tools else {
                    continue
                }

                let toolDefinitions = try await server.listTools()
                for definition in toolDefinitions {
                    let bridgedTool = MCPBridgedTool(
                        definition: definition,
                        server: server
                    )
                    toolCache[bridgedTool.name] = bridgedTool
                }
            }

            // Mark cache as valid
            cacheValid = true

            return Array(toolCache.values)
        }

        // Store the task for deduplication
        refreshTask = task

        do {
            let result = try await task.value
            refreshTask = nil
            return result
        } catch {
            refreshTask = nil
            throw error
        }
    }

    /// Refreshes the tool cache and returns all available tools.
    ///
    /// This method invalidates the current cache and performs a fresh
    /// discovery of tools from all connected servers. Use this when you
    /// need to ensure the tool list is up-to-date.
    ///
    /// - Returns: An array of all available tools from all connected servers.
    /// - Throws: `MCPError` if tool discovery fails for any server.
    ///
    /// ## Example
    /// ```swift
    /// // Force refresh of tools after server-side changes
    /// let tools = try await client.refreshTools()
    /// print("Found \(tools.count) tools after refresh")
    /// ```
    public func refreshTools() async throws -> [any AnyJSONTool] {
        cacheValid = false
        return try await getAllTools()
    }

    /// Invalidates the tool cache.
    ///
    /// After calling this method, the next call to `getAllTools()` will
    /// perform a fresh discovery of tools from all servers.
    ///
    /// ## Example
    /// ```swift
    /// await client.invalidateCache()
    /// // Next call will refresh from servers
    /// let tools = try await client.getAllTools()
    /// ```
    public func invalidateCache() {
        cacheValid = false
    }

    // MARK: - Resource Access

    /// Returns all resources from all connected servers.
    ///
    /// This method aggregates resources from all registered MCP servers. Results
    /// are cached for performance based on the configured TTL; subsequent calls
    /// return cached resources until the cache expires or is invalidated.
    ///
    /// - Returns: An array of all available resources from all connected servers.
    /// - Throws: `MCPError` if resource discovery fails for any server.
    ///
    /// ## Caching Behavior
    ///
    /// Resources are cached after the first call for the duration specified by
    /// the TTL (default: 60 seconds). The cache is automatically invalidated when:
    /// - The TTL expires
    /// - A server is added or removed
    /// - `refreshResources()` or `invalidateResourceCache()` is called
    ///
    /// To disable caching entirely, set the TTL to 0 via `setResourceCacheTTL(0)`.
    /// For indefinite caching, set TTL to `.infinity`.
    ///
    /// ## Example
    /// ```swift
    /// // Default caching with 60-second TTL
    /// let resources = try await client.getAllResources()
    /// print("Found \(resources.count) resources")
    ///
    /// // Custom TTL (cache for 5 minutes)
    /// await client.setResourceCacheTTL(300)
    /// let cachedResources = try await client.getAllResources()
    ///
    /// // Disable caching
    /// await client.setResourceCacheTTL(0)
    /// let freshResources = try await client.getAllResources()
    /// ```
    ///
    /// ## Thread Safety
    /// This method is safe to call concurrently. Concurrent calls during a cache
    /// refresh will wait for the same refresh task rather than triggering
    /// duplicate server queries.
    public func getAllResources() async throws -> [MCPResource] {
        // Check if caching is disabled (TTL = 0)
        if resourceCacheTTL == 0 {
            return try await refreshResourcesInternal()
        }

        // Check if cache is valid and not expired
        if resourceCacheValid, let timestamp = resourceCacheTimestamp {
            let elapsed = Date().timeIntervalSince(timestamp)
            if elapsed < resourceCacheTTL {
                return Array(resourceCache.values)
            }
            // Cache expired
            resourceCacheValid = false
        }

        // Return cached resources if still valid (non-TTL invalidation)
        if resourceCacheValid {
            return Array(resourceCache.values)
        }

        // If a refresh is already in progress, wait for it instead of starting a new one.
        // This prevents concurrent cache rebuilds (race condition).
        if let ongoing = resourceRefreshTask {
            return try await ongoing.value
        }

        // Start a new refresh task
        let task = Task<[MCPResource], Error> {
            try await refreshResourcesInternal()
        }

        // Store the task for deduplication
        resourceRefreshTask = task

        do {
            let result = try await task.value
            resourceRefreshTask = nil
            return result
        } catch {
            resourceRefreshTask = nil
            throw error
        }
    }

    /// Refreshes the resource cache and returns all available resources.
    ///
    /// This method invalidates the current cache and performs a fresh
    /// discovery of resources from all connected servers. Use this when you
    /// need to ensure the resource list is up-to-date, regardless of TTL.
    ///
    /// - Returns: An array of all available resources from all connected servers.
    /// - Throws: `MCPError` if resource discovery fails for any server.
    ///
    /// ## Example
    /// ```swift
    /// // Force refresh after server-side changes
    /// let resources = try await client.refreshResources()
    /// print("Found \(resources.count) resources after refresh")
    /// ```
    ///
    /// ## Note
    /// This method resets the cache timestamp, starting a new TTL period.
    public func refreshResources() async throws -> [MCPResource] {
        resourceCacheValid = false
        resourceCacheTimestamp = nil
        return try await getAllResources()
    }

    /// Invalidates the resource cache.
    ///
    /// After calling this method, the next call to `getAllResources()` will
    /// perform a fresh discovery of resources from all servers.
    ///
    /// ## Example
    /// ```swift
    /// await client.invalidateResourceCache()
    /// // Next call will refresh from servers
    /// let resources = try await client.getAllResources()
    /// ```
    ///
    /// ## Note
    /// This method does not cancel any in-flight refresh operations.
    /// If a refresh is in progress, the cache will be marked invalid but
    /// the ongoing refresh will complete normally.
    public func invalidateResourceCache() {
        resourceCacheValid = false
        resourceCacheTimestamp = nil
    }

    /// Sets the time-to-live (TTL) for the resource cache.
    ///
    /// - Parameter ttl: The cache TTL in seconds. Set to 0 to disable caching,
    ///   or `.infinity` for indefinite caching.
    ///
    /// ## Example
    /// ```swift
    /// // Cache for 5 minutes
    /// await client.setResourceCacheTTL(300)
    ///
    /// // Disable caching
    /// await client.setResourceCacheTTL(0)
    ///
    /// // Cache indefinitely
    /// await client.setResourceCacheTTL(.infinity)
    /// ```
    public func setResourceCacheTTL(_ ttl: TimeInterval) {
        resourceCacheTTL = ttl
    }

    /// Reads the content of a resource by URI.
    ///
    /// This method searches all connected servers for a resource matching
    /// the given URI and returns its content. The first server that
    /// successfully returns the resource content is used.
    ///
    /// - Parameter uri: The URI of the resource to read.
    /// - Returns: The content of the resource.
    /// - Throws: `MCPError.invalidParams` if the resource is not found on any server.
    ///
    /// ## Example
    /// ```swift
    /// let content = try await client.readResource(uri: "file:///config.json")
    /// if let text = content.text {
    ///     print("Config: \(text)")
    /// }
    /// ```
    public func readResource(uri: String) async throws -> MCPResourceContent {
        for (_, server) in servers {
            let capabilities = await server.capabilities
            guard capabilities.resources else {
                continue
            }

            do {
                let content = try await server.readResource(uri: uri)
                return content
            } catch {
                // Try next server
                continue
            }
        }

        throw MCPError.invalidParams("Resource not found: \(uri)")
    }

    /// Closes all server connections and clears all state.
    ///
    /// This method gracefully closes all connected servers and clears
    /// the server registry and tool cache. After calling this method,
    /// the client is ready for new server connections.
    ///
    /// - Throws: `MCPError` if any server fails to close cleanly.
    ///           The error includes details about all servers that failed,
    ///           not just the last one. All servers are attempted to close
    ///           even if some fail.
    ///
    /// ## Example
    /// ```swift
    /// defer {
    ///     try? await client.closeAll()
    /// }
    /// // Use client...
    /// ```
    ///
    /// ## Error Handling
    /// If multiple servers fail to close, the thrown error contains aggregated
    /// failure information in its `data` field for debugging purposes.
    public func closeAll() async throws {
        var errors: [(serverName: String, error: Error)] = []

        // Attempt to close all servers concurrently
        try await withThrowingTaskGroup(of: (String, Error?).self) { group in
            for (name, server) in servers {
                group.addTask {
                    do {
                        try await server.close()
                        return (name, nil)
                    } catch {
                        return (name, error)
                    }
                }
            }

            // Collect all results (successes and failures)
            for try await (name, error) in group {
                if let error {
                    errors.append((serverName: name, error: error))
                }
            }
        }

        // Always clear state regardless of errors
        servers.removeAll()
        toolCache.removeAll()
        cacheValid = false
        resourceCache.removeAll()
        resourceCacheValid = false
        resourceCacheTimestamp = nil

        // Report all errors with detailed context
        if !errors.isEmpty {
            let errorDetails = errors.map { "\($0.serverName): \($0.error.localizedDescription)" }
                .joined(separator: "; ")
            let failedServers = errors.map(\.serverName)

            throw MCPError(
                code: MCPError.internalErrorCode,
                message: "Failed to close \(errors.count) server(s): \(failedServers.joined(separator: ", "))",
                data: .dictionary([
                    "failureCount": .int(errors.count),
                    "failedServers": .array(failedServers.map { .string($0) }),
                    "details": .string(errorDetails)
                ])
            )
        }
    }

    // MARK: Private

    /// Registry of connected MCP servers, keyed by server name.
    private var servers: [String: any MCPServer] = [:]

    /// Cache of tools from all connected servers, keyed by tool name.
    private var toolCache: [String: any AnyJSONTool] = [:]

    /// Whether the tool cache is currently valid.
    private var cacheValid: Bool = false

    /// Ongoing tool refresh task to prevent concurrent cache rebuilds.
    /// Used for request deduplication - if a refresh is in progress,
    /// subsequent calls wait for the same task instead of starting new ones.
    private var refreshTask: Task<[any AnyJSONTool], Error>?

    /// Cache of resources from all connected servers, keyed by resource URI.
    /// URIs are used as keys since they uniquely identify resources across servers.
    private var resourceCache: [String: MCPResource] = [:]

    /// Whether the resource cache is currently valid.
    /// Set to `false` when servers are added/removed or when the cache expires.
    private var resourceCacheValid: Bool = false

    /// Timestamp when the resource cache was last refreshed.
    /// Used in conjunction with `resourceCacheTTL` to determine cache expiry.
    private var resourceCacheTimestamp: Date?

    /// Time-to-live (TTL) for the resource cache in seconds.
    /// Resources are cached for this duration before automatic invalidation.
    /// Default: 60 seconds (resources change more frequently than tools).
    ///
    /// Set to `0` to disable caching entirely.
    /// Set to `.infinity` for indefinite caching (until manual invalidation).
    private var resourceCacheTTL: TimeInterval = 60

    /// Ongoing resource refresh task to prevent concurrent cache rebuilds.
    /// Used for request deduplication - if a refresh is in progress,
    /// subsequent calls wait for the same task instead of starting new ones.
    private var resourceRefreshTask: Task<[MCPResource], Error>?

    /// Internal method that performs the actual resource discovery and cache update.
    /// This is called by both `getAllResources()` and `refreshResources()`.
    private func refreshResourcesInternal() async throws -> [MCPResource] {
        // Clear the cache
        resourceCache.removeAll()

        // Collect resources from all servers
        for (_, server) in servers {
            let capabilities = await server.capabilities
            guard capabilities.resources else {
                continue
            }

            let resources = try await server.listResources()
            for resource in resources {
                // Use URI as the key since it uniquely identifies the resource
                resourceCache[resource.uri] = resource
            }
        }

        // Mark cache as valid and set timestamp
        resourceCacheValid = true
        resourceCacheTimestamp = Date()

        return Array(resourceCache.values)
    }
}
