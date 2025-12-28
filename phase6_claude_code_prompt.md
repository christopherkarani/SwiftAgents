# Claude Code Agent Prompt: Phase 6 Implementation

## Your Role

You are an expert Swift developer implementing Phase 6 (Future Enhancements) of the SwiftAgents framework. Your task is to add MCP (Model Context Protocol) integration and extended model settings, enabling dynamic tool discovery and fine-grained model control.

---

## Context: Model Context Protocol (MCP)

### What is MCP?

MCP is a protocol that allows AI applications to:
- **Discover tools dynamically** from external servers
- **Access resources** (files, databases, APIs) through a unified interface
- **Use prompt templates** defined by servers
- **Communicate via JSON-RPC 2.0** over HTTP/SSE

### MCP Architecture

```
┌──────────────┐
│ SwiftAgents  │
│    Agent     │
└──────┬───────┘
       │
       ├─── Built-in Tools (local)
       │
       └─── MCPClient ───┬─── HTTPMCPServer (GitHub)
                         │
                         ├─── HTTPMCPServer (Slack)
                         │
                         └─── HTTPMCPServer (Custom)
```

### Key MCP Concepts

1. **Server**: Exposes tools, resources, and prompts
2. **Client**: Discovers and uses server capabilities
3. **Tools**: Remote functions that can be called
4. **Resources**: External data sources (files, APIs)
5. **JSON-RPC**: Communication protocol

---

## Context: SwiftAgents Codebase

### Project Structure
```
Sources/SwiftAgents/
├── Core/              # Base protocols, errors
├── Agents/            # Agent implementations
├── Tools/             # Tool system
├── Providers/         # Inference providers
├── MCP/               # NEW - MCP integration
│   ├── MCPProtocol.swift
│   ├── MCPServer.swift
│   ├── MCPClient.swift
│   └── HTTPMCPServer.swift
└── ...

Tests/SwiftAgentsTests/
├── MCP/               # NEW - MCP tests
└── ...
```

### Existing Patterns

**Tool Protocol:**
```swift
public protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameters: ToolParameters { get }
    func execute(arguments: [String: SendableValue]) async throws -> SendableValue
}
```

**ToolDefinition:**
```swift
public struct ToolDefinition: Sendable, Codable {
    public let name: String
    public let description: String
    public let parameters: ToolParameters
}
```

**SendableValue:**
```swift
public enum SendableValue: Sendable, Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([SendableValue])
    case dictionary([String: SendableValue])
    case null
}
```

---

## Task: Implement Phase 6 Features

You will implement TWO main systems:

### System 1: MCP Integration

Complete Model Context Protocol support including:
- **Protocol Types**: JSON-RPC messages, capabilities, resources
- **Server Protocol**: Define MCPServer protocol
- **HTTP Transport**: HTTP-based MCP client implementation
- **Tool Bridge**: Convert MCP tools to SwiftAgents tools
- **Client**: Manage multiple MCP servers
- **Integration**: Connect MCP to agents

### System 2: Extended Model Settings

Fine-grained model control including:
- **Comprehensive Settings**: temperature, top_p, penalties, etc.
- **Tool Control**: toolChoice, parallelToolCalls
- **Advanced Options**: truncation, verbosity, caching
- **Validation**: Ensure settings are valid
- **Provider Integration**: Pass settings to providers

---

## Implementation Requirements

### 1. File Organization

Create files in this EXACT order:

**MCP Foundation (5 files):**
1. CREATE: `Sources/SwiftAgents/MCP/MCPProtocol.swift`
2. CREATE: `Sources/SwiftAgents/MCP/MCPCapabilities.swift`
3. CREATE: `Sources/SwiftAgents/MCP/MCPResource.swift`
4. CREATE: `Sources/SwiftAgents/MCP/MCPError.swift`
5. CREATE: `Sources/SwiftAgents/MCP/MCPServer.swift`

**MCP Implementation (3 files):**
6. CREATE: `Sources/SwiftAgents/MCP/HTTPMCPServer.swift`
7. CREATE: `Sources/SwiftAgents/MCP/MCPToolBridge.swift`
8. CREATE: `Sources/SwiftAgents/MCP/MCPClient.swift`

**Model Settings (1 file):**
9. CREATE: `Sources/SwiftAgents/Core/ModelSettings.swift`

**Integration (2 files):**
10. MODIFY: `Sources/SwiftAgents/Core/AgentConfiguration.swift`
11. MODIFY: `Sources/SwiftAgents/Agents/AgentBuilder.swift`

**Testing (5 files):**
12. CREATE: `Tests/SwiftAgentsTests/MCP/MCPProtocolTests.swift`
13. CREATE: `Tests/SwiftAgentsTests/MCP/HTTPMCPServerTests.swift`
14. CREATE: `Tests/SwiftAgentsTests/MCP/MCPClientTests.swift`
15. CREATE: `Tests/SwiftAgentsTests/Core/ModelSettingsTests.swift`
16. CREATE: `Tests/SwiftAgentsTests/Integration/MCPIntegrationTests.swift`

### 2. Code Quality Standards

**CRITICAL RULES:**

✅ **DO:**
- Use JSON-RPC 2.0 specification exactly
- Make all MCP types `Codable` for JSON serialization
- Use `actor` for MCPClient (manages mutable server registry)
- Use `URLSession` for HTTP transport
- Implement proper error handling for network failures
- Add retry logic for transient failures
- Cache discovered tools to reduce network calls
- Validate model settings before use
- Use fluent builder pattern for ModelSettings
- Add comprehensive documentation with examples
- Support both text and binary (base64) resource content
- Handle server initialization (capability negotiation)

❌ **DON'T:**
- Deviate from JSON-RPC 2.0 spec
- Use synchronous networking
- Forget to handle network timeouts
- Cache tools indefinitely (implement invalidation)
- Allow invalid model settings (validate ranges)
- Expose non-Sendable types across actors
- Use force unwraps for JSON parsing
- Ignore HTTP error codes
- Block waiting for network responses
- Create memory leaks with retain cycles

### 3. Specific Implementation Details

#### MCP Protocol Types

**JSON-RPC Request:**
```swift
import Foundation

/// JSON-RPC 2.0 request message
///
/// Represents a request sent to an MCP server following the JSON-RPC 2.0
/// specification.
///
/// - SeeAlso: [JSON-RPC 2.0](https://www.jsonrpc.org/specification)
public struct MCPRequest: Sendable, Codable {
    /// JSON-RPC version (always "2.0")
    public let jsonrpc: String = "2.0"
    
    /// Unique request identifier
    public let id: String
    
    /// Method name to invoke
    public let method: String
    
    /// Optional method parameters
    public let params: [String: SendableValue]?
    
    public init(
        id: String = UUID().uuidString,
        method: String,
        params: [String: SendableValue]? = nil
    ) {
        self.id = id
        self.method = method
        self.params = params
    }
}

/// JSON-RPC 2.0 response message
public struct MCPResponse: Sendable, Codable {
    public let jsonrpc: String = "2.0"
    public let id: String
    public let result: SendableValue?
    public let error: MCPErrorObject?
    
    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, result, error
    }
}

/// JSON-RPC error object
public struct MCPErrorObject: Sendable, Codable {
    public let code: Int
    public let message: String
    public let data: SendableValue?
}
```

**CRITICAL: JSON-RPC Compliance**

The protocol MUST follow JSON-RPC 2.0:
- Every request has `jsonrpc: "2.0"`, `id`, and `method`
- Response has `result` OR `error` (never both)
- Error codes follow JSON-RPC standard:
  - `-32700`: Parse error
  - `-32600`: Invalid request
  - `-32601`: Method not found
  - `-32602`: Invalid params
  - `-32603`: Internal error

#### MCP Capabilities

```swift
/// Capabilities exposed by an MCP server
///
/// Capabilities are negotiated during initialization to determine
/// what features the server supports.
public struct MCPCapabilities: Sendable, Codable {
    /// Server supports tool discovery and execution
    public let tools: Bool
    
    /// Server supports resource access
    public let resources: Bool
    
    /// Server supports prompt templates
    public let prompts: Bool
    
    /// Server supports sampling
    public let sampling: Bool
    
    public init(
        tools: Bool = false,
        resources: Bool = false,
        prompts: Bool = false,
        sampling: Bool = false
    ) {
        self.tools = tools
        self.resources = resources
        self.prompts = prompts
        self.sampling = sampling
    }
}
```

#### MCP Server Protocol

**CRITICAL: Server Lifecycle**

Servers follow this lifecycle:
1. Create server instance
2. Call `initialize()` - negotiate capabilities
3. Discover tools/resources
4. Execute operations
5. Call `close()` when done

```swift
/// Protocol for MCP server implementations
///
/// Implementations handle connection to MCP servers, capability negotiation,
/// and method dispatch following the Model Context Protocol.
///
/// ## Lifecycle
///
/// 1. Create server instance
/// 2. Call `initialize()` to negotiate capabilities
/// 3. Use `listTools()`, `listResources()`, etc.
/// 4. Call `close()` when finished
///
/// ## Example
///
/// ```swift
/// let server = HTTPMCPServer(
///     url: URL(string: "https://api.github.com/mcp")!,
///     name: "GitHub"
/// )
///
/// let capabilities = try await server.initialize()
/// if capabilities.tools {
///     let tools = try await server.listTools()
///     // Use tools...
/// }
///
/// try await server.close()
/// ```
public protocol MCPServer: Sendable {
    /// Server name for identification
    var name: String { get }
    
    /// Server capabilities (available after initialization)
    var capabilities: MCPCapabilities { get async }
    
    /// Initialize connection and negotiate capabilities
    /// - Returns: Negotiated capabilities
    /// - Throws: MCPError if initialization fails
    func initialize() async throws -> MCPCapabilities
    
    /// List available tools
    /// - Returns: Array of tool definitions
    /// - Throws: MCPError if server doesn't support tools
    func listTools() async throws -> [ToolDefinition]
    
    /// Execute a tool
    /// - Parameters:
    ///   - name: Tool name
    ///   - arguments: Tool arguments
    /// - Returns: Tool result
    /// - Throws: MCPError or tool execution error
    func callTool(
        name: String,
        arguments: [String: SendableValue]
    ) async throws -> SendableValue
    
    /// List available resources
    /// - Returns: Array of resources
    /// - Throws: MCPError if server doesn't support resources
    func listResources() async throws -> [MCPResource]
    
    /// Read resource content
    /// - Parameter uri: Resource URI
    /// - Returns: Resource content (text or binary)
    /// - Throws: MCPError if resource not found
    func readResource(uri: String) async throws -> MCPResourceContent
    
    /// Close connection
    func close() async throws
}
```

#### HTTP MCP Server Implementation

**CRITICAL: Network Error Handling**

Network calls can fail in many ways:
- Connection timeout
- DNS failure
- HTTP errors (4xx, 5xx)
- Invalid JSON response
- Server errors

All must be handled gracefully.

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP-based MCP server client
///
/// Implements MCP protocol over HTTP using JSON-RPC 2.0.
/// Handles connection management, request/response serialization,
/// and error mapping.
public actor HTTPMCPServer: MCPServer {
    public let name: String
    private let baseURL: URL
    private let session: URLSession
    private let apiKey: String?
    private var cachedCapabilities: MCPCapabilities?
    
    /// Timeout for network requests (seconds)
    private let timeout: TimeInterval
    
    /// Maximum retry attempts for transient failures
    private let maxRetries: Int
    
    public init(
        url: URL,
        name: String,
        apiKey: String? = nil,
        timeout: TimeInterval = 30.0,
        maxRetries: Int = 3,
        session: URLSession = .shared
    ) {
        self.baseURL = url
        self.name = name
        self.apiKey = apiKey
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.session = session
    }
    
    public var capabilities: MCPCapabilities {
        get async {
            cachedCapabilities ?? MCPCapabilities()
        }
    }
    
    // MARK: - MCPServer Implementation
    
    public func initialize() async throws -> MCPCapabilities {
        let request = MCPRequest(
            method: "initialize",
            params: [
                "protocolVersion": .string("2024-11-05"),
                "clientInfo": .dictionary([
                    "name": .string("SwiftAgents"),
                    "version": .string("1.0.0")
                ])
            ]
        )
        
        let response: MCPResponse = try await sendRequest(request)
        
        guard let result = response.result else {
            throw MCPError(
                code: -32603,
                message: "No capabilities returned from initialize",
                data: nil
            )
        }
        
        let capabilities = try parseCapabilities(from: result)
        self.cachedCapabilities = capabilities
        return capabilities
    }
    
    public func listTools() async throws -> [ToolDefinition] {
        let request = MCPRequest(
            method: "tools/list",
            params: nil
        )
        
        let response: MCPResponse = try await sendRequest(request)
        
        guard let result = response.result else {
            throw MCPError(
                code: -32603,
                message: "No tools returned",
                data: nil
            )
        }
        
        return try parseTools(from: result)
    }
    
    public func callTool(
        name: String,
        arguments: [String: SendableValue]
    ) async throws -> SendableValue {
        let request = MCPRequest(
            method: "tools/call",
            params: [
                "name": .string(name),
                "arguments": .dictionary(arguments)
            ]
        )
        
        let response: MCPResponse = try await sendRequest(request)
        
        // Check for error first
        if let error = response.error {
            throw MCPError(
                code: error.code,
                message: error.message,
                data: error.data
            )
        }
        
        guard let result = response.result else {
            throw MCPError(
                code: -32603,
                message: "No result returned from tool call",
                data: nil
            )
        }
        
        return result
    }
    
    public func listResources() async throws -> [MCPResource] {
        let request = MCPRequest(
            method: "resources/list",
            params: nil
        )
        
        let response: MCPResponse = try await sendRequest(request)
        
        guard let result = response.result else {
            throw MCPError(
                code: -32603,
                message: "No resources returned",
                data: nil
            )
        }
        
        return try parseResources(from: result)
    }
    
    public func readResource(uri: String) async throws -> MCPResourceContent {
        let request = MCPRequest(
            method: "resources/read",
            params: [
                "uri": .string(uri)
            ]
        )
        
        let response: MCPResponse = try await sendRequest(request)
        
        if let error = response.error {
            throw MCPError(
                code: error.code,
                message: error.message,
                data: error.data
            )
        }
        
        guard let result = response.result else {
            throw MCPError(
                code: -32603,
                message: "No content returned",
                data: nil
            )
        }
        
        return try parseResourceContent(from: result)
    }
    
    public func close() async throws {
        // HTTP is stateless, no connection to close
        cachedCapabilities = nil
    }
    
    // MARK: - Private Implementation
    
    private func sendRequest(_ mcpRequest: MCPRequest) async throws -> MCPResponse {
        var attempt = 0
        var lastError: Error?
        
        while attempt < maxRetries {
            do {
                return try await performRequest(mcpRequest)
            } catch let error as MCPError {
                // Don't retry client errors (4xx)
                if error.code >= 400 && error.code < 500 {
                    throw error
                }
                lastError = error
                attempt += 1
                
                if attempt < maxRetries {
                    // Exponential backoff
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                }
            } catch {
                lastError = error
                attempt += 1
                
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? MCPError(
            code: -32603,
            message: "Request failed after \(maxRetries) attempts",
            data: nil
        )
    }
    
    private func performRequest(_ mcpRequest: MCPRequest) async throws -> MCPResponse {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(mcpRequest)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError(
                code: -32603,
                message: "Invalid HTTP response",
                data: nil
            )
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MCPError(
                code: httpResponse.statusCode,
                message: "HTTP error: \(httpResponse.statusCode)",
                data: .string(String(data: data, encoding: .utf8) ?? "")
            )
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(MCPResponse.self, from: data)
    }
    
    // MARK: - Parsing Helpers
    
    private func parseCapabilities(from value: SendableValue) throws -> MCPCapabilities {
        guard case .dictionary(let dict) = value,
              case .dictionary(let caps)? = dict["capabilities"] else {
            return MCPCapabilities()
        }
        
        func getBool(_ key: String) -> Bool {
            if case .bool(let value) = caps[key] {
                return value
            }
            return false
        }
        
        return MCPCapabilities(
            tools: getBool("tools"),
            resources: getBool("resources"),
            prompts: getBool("prompts"),
            sampling: getBool("sampling")
        )
    }
    
    private func parseTools(from value: SendableValue) throws -> [ToolDefinition] {
        guard case .dictionary(let dict) = value,
              case .array(let toolsArray)? = dict["tools"] else {
            return []
        }
        
        return toolsArray.compactMap { toolValue -> ToolDefinition? in
            guard case .dictionary(let tool) = toolValue,
                  case .string(let name)? = tool["name"],
                  case .string(let description)? = tool["description"] else {
                return nil
            }
            
            // Parse input schema
            var properties: [String: SendableValue] = [:]
            if case .dictionary(let schema)? = tool["inputSchema"],
               case .dictionary(let props)? = schema["properties"] {
                properties = props
            }
            
            return ToolDefinition(
                name: name,
                description: description,
                parameters: ToolParameters(
                    type: "object",
                    properties: properties,
                    required: []
                )
            )
        }
    }
    
    private func parseResources(from value: SendableValue) throws -> [MCPResource] {
        guard case .dictionary(let dict) = value,
              case .array(let resourcesArray)? = dict["resources"] else {
            return []
        }
        
        return resourcesArray.compactMap { resourceValue -> MCPResource? in
            guard case .dictionary(let resource) = resourceValue,
                  case .string(let uri)? = resource["uri"],
                  case .string(let name)? = resource["name"] else {
                return nil
            }
            
            return MCPResource(
                uri: uri,
                name: name,
                description: extractString(resource["description"]),
                mimeType: extractString(resource["mimeType"])
            )
        }
    }
    
    private func parseResourceContent(from value: SendableValue) throws -> MCPResourceContent {
        guard case .dictionary(let dict) = value,
              case .string(let uri)? = dict["uri"] else {
            throw MCPError(
                code: -32603,
                message: "Invalid resource content format",
                data: nil
            )
        }
        
        return MCPResourceContent(
            uri: uri,
            mimeType: extractString(dict["mimeType"]),
            text: extractString(dict["text"]),
            blob: extractString(dict["blob"])
        )
    }
    
    private func extractString(_ value: SendableValue?) -> String? {
        if case .string(let str) = value {
            return str
        }
        return nil
    }
}
```

#### MCP Tool Bridge

```swift
/// Bridges MCP tools to SwiftAgents Tool protocol
///
/// Converts tools discovered from MCP servers into SwiftAgents tools
/// that can be used by agents.
public actor MCPToolBridge {
    private let server: any MCPServer
    
    public init(server: any MCPServer) {
        self.server = server
    }
    
    /// Convert all MCP tools to SwiftAgents tools
    /// - Returns: Array of bridged tools
    public func bridgeTools() async throws -> [any Tool] {
        let toolDefinitions = try await server.listTools()
        
        return toolDefinitions.map { definition in
            MCPBridgedTool(
                definition: definition,
                server: server
            )
        }
    }
}

/// Tool implementation that delegates to MCP server
private struct MCPBridgedTool: Tool {
    let definition: ToolDefinition
    let server: any MCPServer
    
    var name: String { definition.name }
    var description: String { definition.description }
    var parameters: ToolParameters { definition.parameters }
    
    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        try await server.callTool(name: name, arguments: arguments)
    }
}
```

#### MCP Client

**CRITICAL: Server Management**

The client manages multiple servers and must:
- Track server lifecycle
- Invalidate cache when servers change
- Aggregate tools from all servers
- Handle server failures gracefully

```swift
/// Manages multiple MCP servers
///
/// `MCPClient` acts as a registry for MCP servers and provides
/// unified access to tools and resources.
///
/// ## Example
///
/// ```swift
/// let client = MCPClient()
///
/// // Add servers
/// try await client.addServer(githubServer)
/// try await client.addServer(slackServer)
///
/// // Get aggregated tools
/// let tools = try await client.getAllTools()
/// ```
public actor MCPClient {
    private var servers: [String: any MCPServer] = [:]
    private var toolCache: [String: any Tool] = [:]
    private var cacheValid: Bool = false
    
    public init() {}
    
    /// Add an MCP server
    /// - Parameter server: Server to add
    /// - Throws: MCPError if initialization fails
    public func addServer(_ server: any MCPServer) async throws {
        // Initialize server (negotiate capabilities)
        _ = try await server.initialize()
        
        // Add to registry
        servers[server.name] = server
        
        // Invalidate cache
        cacheValid = false
    }
    
    /// Remove an MCP server
    /// - Parameter name: Server name
    public func removeServer(named name: String) async throws {
        if let server = servers.removeValue(forKey: name) {
            try await server.close()
            cacheValid = false
        }
    }
    
    /// Get all tools from all servers
    /// - Returns: Array of tools
    public func getAllTools() async throws -> [any Tool] {
        // Return cached if valid
        if cacheValid {
            return Array(toolCache.values)
        }
        
        // Clear cache
        toolCache.removeAll()
        
        // Fetch from all servers
        for (_, server) in servers {
            let bridge = MCPToolBridge(server: server)
            let tools = try await bridge.bridgeTools()
            
            // Add to cache
            for tool in tools {
                toolCache[tool.name] = tool
            }
        }
        
        cacheValid = true
        return Array(toolCache.values)
    }
    
    /// Get all resources from all servers
    /// - Returns: Array of resources
    public func getAllResources() async throws -> [MCPResource] {
        var allResources: [MCPResource] = []
        
        for (_, server) in servers {
            let resources = try await server.listResources()
            allResources.append(contentsOf: resources)
        }
        
        return allResources
    }
    
    /// Read a resource by URI
    /// - Parameter uri: Resource URI
    /// - Returns: Resource content
    /// - Throws: MCPError if resource not found
    public func readResource(uri: String) async throws -> MCPResourceContent {
        // Try each server
        for (_, server) in servers {
            do {
                return try await server.readResource(uri: uri)
            } catch {
                // Try next server
                continue
            }
        }
        
        throw MCPError(
            code: -32602,
            message: "Resource not found: \(uri)",
            data: nil
        )
    }
    
    /// Get names of connected servers
    public var connectedServers: [String] {
        Array(servers.keys)
    }
    
    /// Close all server connections
    public func closeAll() async throws {
        for (_, server) in servers {
            try await server.close()
        }
        servers.removeAll()
        toolCache.removeAll()
        cacheValid = false
    }
}
```

#### Model Settings

**CRITICAL: Parameter Validation**

All parameters must be validated:
- temperature: 0.0-2.0
- topP: 0.0-1.0
- frequencyPenalty: -2.0 to 2.0
- presencePenalty: -2.0 to 2.0
- maxTokens: > 0

```swift
/// Comprehensive model configuration
///
/// Provides fine-grained control over model behavior including
/// sampling parameters, tool usage, and provider-specific options.
///
/// ## Example
///
/// ```swift
/// let settings = ModelSettings()
///     .temperature(0.7)
///     .topP(0.9)
///     .maxTokens(2000)
///     .toolChoice(.required)
///
/// let agent = AgentBuilder()
///     .modelSettings(settings)
///     .build()
/// ```
public struct ModelSettings: Sendable {
    // Sampling parameters
    public var temperature: Double?
    public var topP: Double?
    public var maxTokens: Int?
    public var frequencyPenalty: Double?
    public var presencePenalty: Double?
    public var stopSequences: [String]?
    public var seed: Int?
    
    // Tool control
    public var toolChoice: ToolChoice?
    public var parallelToolCalls: Bool?
    
    // Advanced options
    public var truncation: TruncationStrategy?
    public var verbosity: Verbosity?
    public var promptCacheRetention: CacheRetention?
    
    // Additional parameters
    public var topK: Int?
    public var repetitionPenalty: Double?
    public var minP: Double?
    
    // Provider-specific
    public var providerSettings: [String: SendableValue]
    
    public init() {
        self.providerSettings = [:]
    }
    
    /// Validate all settings
    /// - Throws: ValidationError if any setting is invalid
    public func validate() throws {
        if let temp = temperature {
            guard (0.0...2.0).contains(temp) else {
                throw ValidationError.invalidTemperature(temp)
            }
        }
        
        if let p = topP {
            guard (0.0...1.0).contains(p) else {
                throw ValidationError.invalidTopP(p)
            }
        }
        
        if let freq = frequencyPenalty {
            guard (-2.0...2.0).contains(freq) else {
                throw ValidationError.invalidFrequencyPenalty(freq)
            }
        }
        
        if let pres = presencePenalty {
            guard (-2.0...2.0).contains(pres) else {
                throw ValidationError.invalidPresencePenalty(pres)
            }
        }
        
        if let tokens = maxTokens {
            guard tokens > 0 else {
                throw ValidationError.invalidMaxTokens(tokens)
            }
        }
        
        if let k = topK {
            guard k > 0 else {
                throw ValidationError.invalidTopK(k)
            }
        }
    }
}

// Fluent builder methods...
public extension ModelSettings {
    func temperature(_ value: Double?) -> ModelSettings {
        var copy = self
        copy.temperature = value
        return copy
    }
    
    // ... other builder methods
}

// Supporting types
public enum ToolChoice: Sendable {
    case auto
    case none
    case required
    case specific(toolName: String)
}

public enum TruncationStrategy: String, Sendable {
    case auto
    case disabled
}

public enum Verbosity: String, Sendable {
    case low
    case medium
    case high
}

public enum CacheRetention: String, Sendable {
    case inMemory = "in_memory"
    case twentyFourHours = "24h"
    case fiveMinutes = "5m"
}
```

### 4. Testing Requirements

#### Critical Test Cases

**MCP Protocol Tests:**
```swift
func testJSONRPCRequestEncoding() throws
func testJSONRPCResponseDecoding() throws
func testCapabilitiesNegotiation() throws
func testToolDiscovery() throws
func testResourceAccess() throws
```

**HTTP Server Tests:**
```swift
func testServerInitialization() async throws
func testToolExecution() async throws
func testNetworkErrorHandling() async throws
func testRetryLogic() async throws
func testTimeout() async throws
```

**MCP Client Tests:**
```swift
func testMultipleServers() async throws
func testToolAggregation() async throws
func testCacheInvalidation() async throws
func testServerRemoval() async throws
```

**Model Settings Tests:**
```swift
func testValidation() throws
func testFluentBuilder() throws
func testInvalidSettings() throws
```

#### Example Test

```swift
import XCTest
@testable import SwiftAgents

final class HTTPMCPServerTests: XCTestCase {
    
    func testInitialization() async throws {
        let server = HTTPMCPServer(
            url: URL(string: "https://example.com/mcp")!,
            name: "TestServer"
        )
        
        // Mock URLSession with successful response
        let mockSession = MockURLSession(
            data: """
            {
                "jsonrpc": "2.0",
                "id": "test",
                "result": {
                    "capabilities": {
                        "tools": true,
                        "resources": false
                    }
                }
            }
            """.data(using: .utf8)!,
            response: HTTPURLResponse(
                url: URL(string: "https://example.com/mcp")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )
        
        // Note: In real implementation, inject mock session
        let capabilities = try await server.initialize()
        
        XCTAssertTrue(capabilities.tools)
        XCTAssertFalse(capabilities.resources)
    }
    
    func testToolExecution() async throws {
        // Similar pattern with mock responses
    }
}
```

---

## Step-by-Step Implementation Guide

### Step 1: MCP Protocol Foundation (2-3 hours)

1. Create `MCPProtocol.swift` with request/response types
2. Create `MCPCapabilities.swift` with capability types
3. Create `MCPResource.swift` with resource types
4. Create `MCPError.swift` with error types
5. Ensure all types are Sendable and Codable
6. Add comprehensive documentation

**Success criteria:**
- All types compile
- JSON encoding/decoding works
- Documentation complete

### Step 2: MCP Server Protocol (1-2 hours)

1. Create `MCPServer.swift` with protocol definition
2. Add all required methods
3. Add default implementations where appropriate
4. Document lifecycle and usage

**Success criteria:**
- Protocol compiles
- Method signatures match MCP spec
- Documentation explains lifecycle

### Step 3: HTTP MCP Server (3-4 hours)

**MOST CRITICAL SECTION**

1. Create `HTTPMCPServer.swift` as actor
2. Implement initialization with capability negotiation
3. Implement tool discovery
4. Implement tool execution
5. Implement resource operations
6. Add retry logic with exponential backoff
7. Add timeout handling
8. Add comprehensive error handling

**Success criteria:**
- Network calls work correctly
- Retries function properly
- Timeouts are enforced
- Errors are properly mapped

### Step 4: Tool Bridge (1 hour)

1. Create `MCPToolBridge.swift`
2. Implement tool conversion
3. Create bridged tool type

**Success criteria:**
- MCP tools convert to SwiftAgents tools
- Execution delegates correctly

### Step 5: MCP Client (2-3 hours)

1. Create `MCPClient.swift` as actor
2. Implement server registry
3. Implement tool aggregation
4. Implement cache management
5. Implement resource operations

**Success criteria:**
- Multiple servers managed correctly
- Tool cache works and invalidates properly
- Resource discovery functions

### Step 6: Model Settings (2-3 hours)

1. Create `ModelSettings.swift`
2. Define all setting properties
3. Implement validation logic
4. Implement fluent builder
5. Add supporting enums

**Success criteria:**
- All settings validate correctly
- Builder pattern works
- Invalid settings rejected

### Step 7: Integration (2-3 hours)

1. Update `AgentConfiguration.swift`
2. Update `AgentBuilder.swift`
3. Add MCP tool registration to agents
4. Add model settings to provider calls

**Success criteria:**
- MCP integrates with agents
- Settings passed to providers
- Backward compatible

### Step 8: Testing (4-6 hours)

Write comprehensive tests for all components.

**Success criteria:**
- All tests pass
- Coverage > 80%
- Network scenarios tested
- Error cases covered

---

## Error Handling

### Define MCP Errors

```swift
public struct MCPError: Error, Sendable, LocalizedError {
    public let code: Int
    public let message: String
    public let data: SendableValue?
    
    public var errorDescription: String? {
        "MCP Error (\(code)): \(message)"
    }
}

// Standard JSON-RPC errors
public extension MCPError {
    static func parseError() -> MCPError {
        MCPError(code: -32700, message: "Parse error", data: nil)
    }
    
    static func invalidRequest() -> MCPError {
        MCPError(code: -32600, message: "Invalid request", data: nil)
    }
    
    static func methodNotFound() -> MCPError {
        MCPError(code: -32601, message: "Method not found", data: nil)
    }
    
    static func invalidParams() -> MCPError {
        MCPError(code: -32602, message: "Invalid params", data: nil)
    }
    
    static func internalError() -> MCPError {
        MCPError(code: -32603, message: "Internal error", data: nil)
    }
}
```

---

## Validation Checklist

Before submitting:

### Code Quality
- [ ] All files compile without errors/warnings
- [ ] JSON-RPC 2.0 compliance verified
- [ ] All MCP types are Sendable and Codable
- [ ] Network error handling is comprehensive
- [ ] Retry logic works correctly
- [ ] Validation catches all invalid settings
- [ ] Documentation complete

### Functionality
- [ ] MCP server initialization works
- [ ] Tool discovery functions
- [ ] Tool execution succeeds
- [ ] Resource access works
- [ ] Multi-server coordination functions
- [ ] Model settings validate correctly
- [ ] Integration with agents works

### Testing
- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] Network scenarios covered
- [ ] Error cases tested
- [ ] Coverage > 80%

---

## Common Pitfalls

### ❌ Don't Do This:

```swift
// DON'T: Parse JSON manually
let json = try JSONSerialization.jsonObject(with: data)  // ❌

// DON'T: Ignore HTTP errors
let (data, _) = try await session.data(for: request)  // ❌ Missing response check

// DON'T: Allow invalid settings
modelSettings.temperature = 5.0  // ❌ No validation

// DON'T: Cache indefinitely
var toolCache: [String: Tool] = [:]  // ❌ Never invalidates

// DON'T: Block on network
let result = server.callTool(...)  // ❌ Should be async
```

### ✅ Do This Instead:

```swift
// DO: Use Codable
let response = try decoder.decode(MCPResponse.self, from: data)  // ✅

// DO: Check HTTP response
guard (200...299).contains(httpResponse.statusCode) else {  // ✅
    throw MCPError(code: httpResponse.statusCode, ...)
}

// DO: Validate settings
public func validate() throws {  // ✅
    if let temp = temperature {
        guard (0.0...2.0).contains(temp) else {
            throw ValidationError.invalidTemperature(temp)
        }
    }
}

// DO: Invalidate cache
public func addServer(_ server: MCPServer) async throws {
    servers[server.name] = server
    cacheValid = false  // ✅ Invalidate
}

// DO: Async network calls
public func callTool(...) async throws -> SendableValue {  // ✅
    try await sendRequest(...)
}
```

---

## Output Format

For each file:

1. **State what you're creating**
2. **Show complete code**
3. **Explain key decisions**
4. **Run tests** (when applicable)

---

## Success Metrics

Implementation complete when:

1. ✅ All 16 files created/modified
2. ✅ Zero compiler warnings
3. ✅ All tests pass with >80% coverage
4. ✅ MCP servers connect successfully
5. ✅ Tools discovered and executed
6. ✅ Model settings validated
7. ✅ Integration works
8. ✅ Documentation complete

---

## Final Notes

- **Take time with HTTP implementation** - network code is tricky
- **Test thoroughly** - mock network responses
- **Validate everything** - don't trust user input
- **Document well** - MCP is complex
- **Follow JSON-RPC spec** - don't deviate

Begin with Step 1 and proceed sequentially. Good luck! 🚀
