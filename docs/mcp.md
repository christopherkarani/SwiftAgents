# Model Context Protocol (MCP)

## Overview

The Model Context Protocol (MCP) module in Swarm provides comprehensive support for integrating with MCP-compatible servers and clients. MCP is a JSON-RPC 2.0 based protocol that enables agents to discover and execute tools, access resources, and communicate with external services in a standardized way.

Swarm implements MCP with the following components:

- **MCPClient**: A multi-server client that aggregates tools and resources from multiple MCP servers
- **MCPServer**: A protocol defining the interface for MCP server implementations
- **HTTPMCPServer**: An HTTP-based transport implementation for connecting to MCP servers
- **MCPProtocol**: JSON-RPC 2.0 request/response types for MCP operations

## MCP Client

### MCPClient

`MCPClient` is an actor that manages multiple MCP server connections and provides a unified interface for discovering and using tools and resources across all connected servers.

#### Features

- **Multi-Server Management**: Connect to and manage multiple MCP servers simultaneously
- **Tool Aggregation**: Discover and cache tools from all connected servers
- **Resource Access**: Query resources across all servers with automatic server resolution
- **Lifecycle Management**: Properly initialize and close server connections
- **Thread Safety**: Implemented as an actor for safe concurrent access

#### Connecting to MCP Servers

```swift
import Swarm

// Create the client
let client = MCPClient()

// Create server connections
let filesystemServer = HTTPMCPServer(
    url: URL(string: "https://mcp.example.com/filesystem")!,
    name: "filesystem-server",
    apiKey: "sk-xxx"
)

let databaseServer = HTTPMCPServer(
    url: URL(string: "https://mcp.example.com/database")!,
    name: "database-server",
    apiKey: "sk-xxx"
)

// Add servers to the client
try await client.addServer(filesystemServer)
try await client.addServer(databaseServer)

// Check connected servers
let serverNames = await client.connectedServers
print("Connected to: \(serverNames.joined(separator: ", "))")
```

#### Listing Tools

```swift
// Discover all available tools from all connected servers
let tools = try await client.getAllTools()

for tool in tools {
    print("\(tool.name): \(tool.description)")
}

// Force refresh of tools from servers
let refreshedTools = try await client.refreshTools()

// Manually invalidate the cache
await client.invalidateCache()
```

#### Tool Caching

MCPClient caches tools for performance. The cache is automatically invalidated when:
- A server is added or removed
- `refreshTools()` is called
- `invalidateCache()` is called

Concurrent calls during a cache refresh wait for the same refresh task rather than triggering duplicate server queries.

#### Integrating with Agents

```swift
// Get all tools from connected MCP servers
let mcpTools = try await client.getAllTools()

// Use tools with a ReActAgent
let agent = try ReActAgent.Builder()
    .name("MCP-Enabled Agent")
    .instructions("You are a helpful assistant with access to external tools.")
    .tools(mcpTools)
    .build()

// Run the agent
let response = try await agent.run(input: "Search for Swift concurrency documentation")
```

#### Resource Access

```swift
// List all resources from all servers
let resources = try await client.getAllResources()

for resource in resources {
    print("\(resource.name) (\(resource.uri))")
    if let description = resource.description {
        print("  \(description)")
    }
}

// Read a specific resource
let content = try await client.readResource(uri: "file:///config.json")
if let text = content.text {
    print("Config contents: \(text)")
}
```

#### Resource Caching

Resources are cached with a configurable TTL (default: 60 seconds):

```swift
// Cache for 5 minutes
await client.setResourceCacheTTL(300)

// Disable caching entirely
await client.setResourceCacheTTL(0)

// Cache indefinitely
await client.setResourceCacheTTL(.infinity)

// Force refresh regardless of TTL
let freshResources = try await client.refreshResources()

// Manually invalidate the cache
await client.invalidateResourceCache()
```

#### Cleanup

```swift
// Remove a specific server
try await client.removeServer(named: "filesystem-server")

// Close all server connections
try await client.closeAll()

// Best practice: use defer for cleanup
let client = MCPClient()
defer {
    Task {
        try? await client.closeAll()
    }
}
```

## MCP Server

### MCPServer Protocol

The `MCPServer` protocol defines the interface for MCP server implementations. It follows a lifecycle pattern where servers must be initialized before use and properly closed when no longer needed.

#### Server Lifecycle

```
Create -> Initialize -> Use (Tools/Resources) -> Close
```

1. **Create**: Instantiate the server with connection configuration
2. **Initialize**: Call `initialize()` to establish the connection and negotiate capabilities
3. **Use**: Call `listTools()`, `callTool()`, `listResources()`, `readResource()` as needed
4. **Close**: Call `close()` to gracefully shut down the connection

#### Protocol Requirements

```swift
public protocol MCPServer: Sendable {
    /// The name of this MCP server
    var name: String { get }

    /// The capabilities of this MCP server
    var capabilities: MCPCapabilities { get async }

    // Lifecycle Methods
    func initialize() async throws -> MCPCapabilities
    func close() async throws

    // Tool Methods
    func listTools() async throws -> [ToolSchema]
    func callTool(name: String, arguments: [String: SendableValue]) async throws -> SendableValue

    // Resource Methods
    func listResources() async throws -> [MCPResource]
    func readResource(uri: String) async throws -> MCPResourceContent
}
```

#### Server State

MCPServer implementations can use `MCPServerState` to track lifecycle state:

```swift
public enum MCPServerState: Sendable, Equatable {
    case created       // Server has been created but not yet initialized
    case initializing  // Server is currently initializing
    case ready         // Server is ready for use
    case closing       // Server is closing
    case closed        // Server has been closed
    case error(String) // Server encountered an error

    var isReady: Bool { ... }
    var isTerminated: Bool { ... }
}
```

### HTTPMCPServer

`HTTPMCPServer` provides an HTTP-based transport for communicating with MCP-compliant servers. It handles JSON-RPC 2.0 request/response encoding, automatic retries with exponential backoff, and capability negotiation.

#### Creating an HTTP MCP Server

```swift
let server = HTTPMCPServer(
    url: URL(string: "https://mcp.example.com/api")!,
    name: "example-server",
    apiKey: "sk-xxx",           // Optional API key for Bearer authentication
    timeout: 30.0,               // Request timeout in seconds (default: 30)
    maxRetries: 3,               // Maximum retry attempts (default: 3)
    session: .shared             // URLSession to use (default: .shared)
)
```

#### Security Requirements

When using API keys, HTTPS is required to prevent credential exposure:

```swift
// This will work (HTTPS)
let secureServer = HTTPMCPServer(
    url: URL(string: "https://mcp.example.com/api")!,
    name: "secure-server",
    apiKey: "sk-xxx"
)

// This will fail with a precondition error (HTTP with API key)
let insecureServer = HTTPMCPServer(
    url: URL(string: "http://mcp.example.com/api")!,  // HTTP not allowed with API key
    name: "insecure-server",
    apiKey: "sk-xxx"
)

// HTTP is allowed without API key (for local development)
let localServer = HTTPMCPServer(
    url: URL(string: "http://localhost:8080/api")!,
    name: "local-server"
)
```

#### Initializing and Using the Server

```swift
// Initialize the connection
let capabilities = try await server.initialize()
print("Server capabilities: \(capabilities)")

// Check capabilities before using features
if capabilities.tools {
    let tools = try await server.listTools()
    for tool in tools {
        print("\(tool.name): \(tool.description)")
    }
}

// Call a tool
let result = try await server.callTool(
    name: "search",
    arguments: [
        "query": .string("swift concurrency"),
        "limit": .int(10)
    ]
)

// Access resources
if capabilities.resources {
    let resources = try await server.listResources()
    for resource in resources {
        let content = try await server.readResource(uri: resource.uri)
        print("\(resource.name): \(content.text ?? "binary data")")
    }
}

// Close the connection
try await server.close()
```

#### Retry Behavior

HTTPMCPServer implements automatic retries with exponential backoff:

- Retryable errors (server errors, network issues) are retried up to `maxRetries` times
- Client errors (4xx) are not retried as they indicate invalid requests
- Backoff delays: 1s, 2s, 4s, etc.
- Cancellation is checked before each retry delay

```swift
// Configure retry behavior
let server = HTTPMCPServer(
    url: URL(string: "https://mcp.example.com/api")!,
    name: "retry-server",
    maxRetries: 5  // Retry up to 5 times
)
```

## MCP Protocol

### JSON-RPC Messages

MCP uses JSON-RPC 2.0 for communication. Swarm provides `MCPRequest` and `MCPResponse` types for encoding and decoding messages.

#### MCPRequest

```swift
// Simple request without parameters
let request = MCPRequest(method: "tools/list")

// Request with parameters
let callRequest = MCPRequest(
    method: "tools/call",
    params: [
        "name": .string("calculator"),
        "arguments": .dictionary(["expression": .string("2 + 2")])
    ]
)

// Request with custom ID
let customRequest = MCPRequest(
    id: "request-001",
    method: "resources/read",
    params: ["uri": .string("file:///example.txt")]
)
```

#### Standard MCP Methods

MCP defines the following standard methods:

| Method | Description |
|--------|-------------|
| `initialize` | Initialize the connection and negotiate capabilities |
| `tools/list` | List available tools |
| `tools/call` | Execute a tool |
| `resources/list` | List available resources |
| `resources/read` | Read a resource |
| `prompts/list` | List available prompts |
| `prompts/get` | Get a prompt |

#### MCPResponse

```swift
// Decoding a response
let response = try JSONDecoder().decode(MCPResponse.self, from: data)

if let error = response.error {
    print("Error: \(error.message)")
} else if let result = response.result {
    print("Success: \(result)")
}

// Creating responses (for server implementations)
let successResponse = MCPResponse.success(
    id: "request-001",
    result: .dictionary(["status": .string("ok")])
)

let errorResponse = MCPResponse.failure(
    id: "request-001",
    error: MCPErrorObject(
        code: MCPError.methodNotFoundCode,
        message: "Method 'unknown' not found"
    )
)
```

### Tool Schemas

Tools are described using `ToolSchema` with JSON Schema for parameters:

```swift
let toolDefinition = ToolSchema(
    name: "search",
    description: "Search for documents",
    parameters: [
        ToolParameter(
            name: "query",
            description: "The search query",
            type: .string,
            isRequired: true
        ),
        ToolParameter(
            name: "limit",
            description: "Maximum number of results",
            type: .int,
            isRequired: false
        )
    ]
)
```

#### Parameter Types

```swift
public enum ParameterType {
    case string
    case int
    case double
    case bool
    case array(elementType: ParameterType)
    case object(properties: [ToolParameter])
    case any
}
```

### Error Handling

MCP uses standard JSON-RPC 2.0 error codes:

| Code | Name | Description |
|------|------|-------------|
| -32700 | Parse error | Invalid JSON was received |
| -32600 | Invalid Request | The JSON sent is not a valid Request object |
| -32601 | Method not found | The method does not exist or is not available |
| -32602 | Invalid params | Invalid method parameter(s) |
| -32603 | Internal error | Internal JSON-RPC error |

```swift
// Creating MCP errors
let parseError = MCPError.parseError("Invalid JSON syntax")
let methodNotFound = MCPError.methodNotFound("tools/unknown - method does not exist")
let invalidParams = MCPError.invalidParams("Missing required parameter 'query'")
let internalError = MCPError.internalError("Database connection failed")

// Error with additional data
let detailedError = MCPError(
    code: MCPError.invalidParamsCode,
    message: "Validation failed",
    data: .dictionary([
        "field": .string("query"),
        "reason": .string("must be non-empty")
    ])
)
```

## Resources

### MCPResource

Resources are described using `MCPResource`:

```swift
public struct MCPResource: Sendable {
    public let uri: String           // Unique identifier for the resource
    public let name: String          // Human-readable name
    public let description: String?  // Optional description
    public let mimeType: String?     // Optional MIME type
}
```

### MCPResourceContent

Resource content can be text or binary (base64-encoded):

```swift
public struct MCPResourceContent: Sendable {
    public let uri: String           // URI of the resource
    public let mimeType: String?     // MIME type of the content
    public let text: String?         // Text content (if text-based)
    public let blob: String?         // Base64-encoded binary content
}
```

### Reading Resources

```swift
// List available resources
let resources = try await server.listResources()

for resource in resources {
    let content = try await server.readResource(uri: resource.uri)

    if let text = content.text {
        // Handle text content
        print("Text: \(text)")
    } else if let blob = content.blob {
        // Handle binary content
        if let data = Data(base64Encoded: blob) {
            print("Binary data: \(data.count) bytes")
        }
    }
}
```

## MCPCapabilities

Server capabilities indicate which features are supported:

```swift
public struct MCPCapabilities: Sendable {
    public let tools: Bool      // Server supports tool operations
    public let resources: Bool  // Server supports resource operations
    public let prompts: Bool    // Server supports prompt operations
    public let sampling: Bool   // Server supports sampling operations
}
```

```swift
let capabilities = try await server.initialize()

if capabilities.tools {
    // Safe to call listTools() and callTool()
}

if capabilities.resources {
    // Safe to call listResources() and readResource()
}
```

## Best Practices

### Security Considerations

1. **Always use HTTPS with API keys**: HTTPMCPServer enforces HTTPS when API keys are provided to prevent credential exposure over the network.

2. **Validate tool arguments**: Before calling tools, validate that arguments match expected types and constraints.

3. **Handle sensitive data carefully**: Be cautious when logging or displaying tool results that may contain sensitive information.

4. **Use short-lived API keys**: When possible, use API keys with limited scope and short expiration times.

```swift
// Good: HTTPS with API key
let secureServer = HTTPMCPServer(
    url: URL(string: "https://mcp.example.com/api")!,
    name: "secure-server",
    apiKey: loadApiKeyFromSecureStorage()
)

// Good: Local development without API key
let localServer = HTTPMCPServer(
    url: URL(string: "http://localhost:8080/api")!,
    name: "local-dev"
)
```

### Error Handling

1. **Check capabilities before calling methods**: Always verify server capabilities before calling tool or resource methods.

2. **Handle specific error codes**: Use MCP error codes to provide appropriate error handling.

3. **Implement graceful degradation**: If a server is unavailable, handle the failure gracefully.

```swift
do {
    let capabilities = try await server.initialize()

    guard capabilities.tools else {
        print("Server does not support tools")
        return
    }

    let result = try await server.callTool(name: "search", arguments: [...])
    // Handle result

} catch let error as MCPError {
    switch error.code {
    case MCPError.methodNotFoundCode:
        print("Tool not found: \(error.message)")
    case MCPError.invalidParamsCode:
        print("Invalid parameters: \(error.message)")
    case MCPError.internalErrorCode:
        print("Server error: \(error.message)")
    default:
        print("MCP error (\(error.code)): \(error.message)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

### Connection Management

1. **Always close connections**: Use `defer` or structured concurrency to ensure connections are closed.

2. **Handle connection failures**: Implement retry logic for transient failures.

3. **Monitor server health**: Track connection state and handle disconnections.

```swift
let client = MCPClient()

// Use defer for cleanup
defer {
    Task {
        try? await client.closeAll()
    }
}

// Or use structured concurrency
try await withTaskGroup(of: Void.self) { group in
    group.addTask {
        try await performMCPOperations(client: client)
    }

    group.addTask {
        // Cleanup when the task group completes
        defer {
            Task {
                try? await client.closeAll()
            }
        }
        await Task.yield()
    }
}
```

### Versioning

1. **Track protocol version**: MCP uses protocol versioning (e.g., "2024-11-05"). Ensure compatibility with server versions.

2. **Handle capability changes**: Server capabilities may change between protocol versions. Check capabilities at runtime.

3. **Test with multiple servers**: Validate your integration works with different MCP server implementations.

```swift
// HTTPMCPServer sends protocol version during initialization
let params: [String: SendableValue] = [
    "protocolVersion": .string("2024-11-05"),
    "clientInfo": .dictionary([
        "name": .string("Swarm"),
        "version": .string("1.0.0")
    ])
]
```

### Performance Optimization

1. **Use tool caching**: MCPClient caches tools automatically. Only call `refreshTools()` when necessary.

2. **Configure resource cache TTL**: Set appropriate TTL based on how frequently resources change.

3. **Batch operations when possible**: If performing multiple operations, consider grouping them.

```swift
// Configure caching based on your use case
let client = MCPClient()

// For frequently changing resources, use shorter TTL
await client.setResourceCacheTTL(30)  // 30 seconds

// For stable resources, use longer TTL
await client.setResourceCacheTTL(300)  // 5 minutes

// For critical operations, disable caching
await client.setResourceCacheTTL(0)
```

### Thread Safety

All MCP types in Swarm are designed for concurrent use:

- `MCPClient` is an actor, ensuring thread-safe access to mutable state
- `HTTPMCPServer` is an actor for safe concurrent request handling
- `MCPRequest`, `MCPResponse`, and related types are `Sendable`

```swift
// Safe to call from multiple tasks concurrently
await withTaskGroup(of: Void.self) { group in
    for query in queries {
        group.addTask {
            let tools = try? await client.getAllTools()
            // Use tools...
        }
    }
}
```
