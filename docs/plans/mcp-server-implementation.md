# MCP Server Implementation Plan

## Overview

Add MCP server capability to SwiftAgents, enabling existing `Tool` implementations to be exposed as standard MCP tools consumable by any MCP-compliant client via stdio transport.

The implementation follows the Model Context Protocol (MCP) specification and uses JSON-RPC 2.0 over stdio, making it compatible with any MCP client including Claude Desktop, custom clients, and future MCP implementations.

## Architecture

### Component Hierarchy
```
External MCP Client (any MCP-compliant client)
          ↓ stdio (newline-delimited JSON-RPC 2.0)
    StdioMCPServerTransport (actor)
          ↓ MCPRequest stream
    MCPServerRequestHandler (actor)
          ↓ method routing
    ToolRegistry → Tool execution
          ↓ SendableValue result
    MCPResponse → stdout
```

### Core Components

**1. MCPServerTransport Protocol**
- Abstraction for stdio, HTTP, SSE transports
- Provides `AsyncStream<Result<MCPRequest, MCPError>>`
- Sends `MCPResponse` back to client
- Manages connection lifecycle

**2. StdioMCPServerTransport (v1)**
- Reads newline-delimited JSON from injected `FileHandle` (defaults to stdin)
- Writes newline-delimited JSON to injected `FileHandle` (defaults to stdout)
- Actor isolation prevents concurrent stdout writes
- Dependency injection enables testing with in-memory pipes
- Robust edge case handling: partial reads, empty lines, trailing whitespace, EOF
- Deserializes JSON → `MCPRequest`, serializes `MCPResponse` → JSON

**3. MCPServerRequestHandler**
- Routes requests by `method` field: `initialize`, `tools/list`, `tools/call`
- Validates capabilities before processing requests
- Converts `Tool` → MCP tool format (JSON Schema)
- Executes tools via `ToolRegistry.execute()` with cancellation support
- Tracks in-flight tool executions for graceful cancellation
- All errors converted to `MCPResponse.failure()` (no throws to transport)

**4. MCPServerHost (actor)**
- Public API for server lifecycle
- Actor isolation for state management
- Coordinates transport and handler
- Manages server state using existing `MCPServerState` enum
- Provides factory method: `MCPServerHost.stdio(toolRegistry:)`

## Public API

### Basic Usage
```swift
// Create tools
let registry = ToolRegistry(tools: [
    DateTimeTool(),
    StringTool(),
    CustomTool()
])

// Create and start server
let server = try await MCPServerHost.stdio(toolRegistry: registry)
try await server.start()

// Wait for completion (blocks until stopped)
await server.waitForCompletion()
```

### MCP Client Integration

The server is compatible with any MCP client that supports stdio transport. Below are examples:

#### Example 1: Claude Desktop
**Config:** `~/Library/Application Support/Claude/claude_desktop_config.json`
```json
{
  "mcpServers": {
    "swiftagents-tools": {
      "command": "/path/to/mcp-server-executable",
      "args": []
    }
  }
}
```

#### Example 2: Custom MCP Client
```swift
// Any MCP client using stdio transport
let process = Process()
process.executableURL = URL(fileURLWithPath: "/path/to/mcp-server-executable")
process.standardInput = Pipe()
process.standardOutput = Pipe()

try process.run()

// Send JSON-RPC requests to stdin
// Read JSON-RPC responses from stdout
```

#### Example 3: Command-Line Testing
```bash
# Direct stdio interaction for testing
echo '{"jsonrpc":"2.0","id":"1","method":"tools/list","params":null}' | ./mcp-server-executable
```

### Server Executable Template
```swift
@main
struct MCPServerApp {
    static func main() async throws {
        // Configure logging (use StreamLogHandler for stderr)
        // CRITICAL: stdout reserved for JSON-RPC protocol
        Log.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = .info
            return handler
        }

        let registry = ToolRegistry(tools: [DateTimeTool(), StringTool()])
        let server = try await MCPServerHost.stdio(toolRegistry: registry)

        // Graceful shutdown on SIGTERM
        let signalSource = DispatchSource.makeSignalSource(signal: SIGTERM)
        signalSource.setEventHandler { Task { await server.stop() } }
        signalSource.resume()
        signal(SIGTERM, SIG_IGN)

        try await server.start()
        await server.waitForCompletion()
    }
}
```

## Data Flow

### Initialize Request
1. Client sends: `{"jsonrpc":"2.0","id":"0","method":"initialize","params":{"protocolVersion":"2024-11-05","clientInfo":{"name":"MCP Client","version":"1.0"}}}\n`
2. Transport reads line, trims whitespace, parses → `MCPRequest`
3. Handler routes to `handleInitialize()`
4. Handler builds response with **full structure**:
   ```swift
   SendableValue.dictionary([
       "protocolVersion": .string("2024-11-05"),
       "serverInfo": .dictionary([
           "name": .string("SwiftAgents MCP Server"),
           "version": .string("1.0.0")
       ]),
       "capabilities": .dictionary([
           "tools": .dictionary([:])  // Empty dict indicates tools supported
       ])
   ])
   ```
5. Handler returns `MCPResponse.success(id: "0", result: initializeResult)`
6. Transport serializes and writes to stdout with newline

**CRITICAL**: Initialize response must include all three fields or clients may reject negotiation.

### Tool List Request
1. Client sends: `{"jsonrpc":"2.0","id":"1","method":"tools/list"}\n`
2. Transport reads line, trims whitespace
3. Transport parses → `MCPRequest` (or `MCPError.parseError()` if malformed)
4. Handler routes to `handleToolsList()`
5. Handler calls `toolRegistry.definitions`
6. Handler converts each `ToolDefinition` to JSON Schema format
7. Handler returns `MCPResponse.success(id: "1", result: tools array)`
8. Transport serializes and writes to stdout with newline: `{...}\n`

### Tool Execution Request
1. Client sends: `{"jsonrpc":"2.0","id":"2","method":"tools/call","params":{"name":"datetime","arguments":{}}}\n`
2. Transport reads line, trims whitespace, parses → `MCPRequest`
3. Handler routes to `handleToolsCall()`
4. Handler extracts tool name and arguments from params
5. Handler creates Task for tool execution, stores in tracking dictionary
6. Handler calls `toolRegistry.execute(toolNamed:arguments:)`
7. Tool executes asynchronously, returns `SendableValue`
8. Handler removes Task from tracking dictionary
9. Handler wraps result in `MCPResponse.success(id: "2", result: value)`
10. Transport serializes and writes to stdout with newline: `{...}\n`

**Cancellation Flow:**
- If EOF occurs during step 7: Task is cancelled via `Task.cancel()`
- Tool execution should check `Task.isCancelled` periodically
- Cancelled tools throw `CancellationError`
- Handler converts to `MCPError.internalError("Request cancelled")`

### Error Handling
- All errors converted to JSON-RPC 2.0 error responses
- Tool execution errors → `MCPError.internalError()`
- Invalid parameters → `MCPError.invalidParams()`
- Unknown methods → `MCPError.methodNotFound()`
- Malformed JSON → `MCPError.parseError()` with request ID = empty string ""
  - **JSON-RPC 2.0 spec**: Recommends `null` for parse errors when request ID cannot be determined
  - **Our approach**: Consistently use empty string `""` for all parse errors
  - Rationale: Existing `MCPResponse.id` is `String` (not optional), changing to `String?` would be breaking
  - This deviates from JSON-RPC 2.0 spec but is pragmatic and avoids type changes
  - Empty string is a valid JSON string per spec, though unconventional
  - **CRITICAL**: Use `""` consistently throughout - never mix with other strategies
- Never throw to transport layer - always return MCPResponse

## Type Conversions

### ToolParameter.ParameterType → JSON Schema

```swift
extension ToolParameter.ParameterType {
    /// Converts parameter type to JSON Schema type string
    func toJSONSchemaType() -> String {
        switch self {
        case .string: return "string"
        case .int: return "integer"
        case .double: return "number"
        case .bool: return "boolean"
        case .array: return "array"
        case .object: return "object"
        case .oneOf: return "string"  // with enum constraint
        case .any: return "object"  // most flexible JSON Schema type
        }
    }

    /// Converts parameter type to full JSON Schema definition (recursive)
    func toJSONSchema() -> SendableValue {
        switch self {
        case .string:
            return .dictionary(["type": .string("string")])

        case .int:
            return .dictionary(["type": .string("integer")])

        case .double:
            return .dictionary(["type": .string("number")])

        case .bool:
            return .dictionary(["type": .string("boolean")])

        case .array(let elementType):
            // Recursive: convert element type
            return .dictionary([
                "type": .string("array"),
                "items": elementType.toJSONSchema()
            ])

        case .object(let properties):
            // Recursive: convert nested properties
            var propDict: [String: SendableValue] = [:]
            var requiredArray: [SendableValue] = []

            for prop in properties {
                propDict[prop.name] = prop.type.toJSONSchema()
                if prop.isRequired {
                    requiredArray.append(.string(prop.name))
                }
            }

            return .dictionary([
                "type": .string("object"),
                "properties": .dictionary(propDict),
                "required": .array(requiredArray)
            ])

        case .oneOf(let options):
            // Use enum constraint for string with predefined values
            // This assumes ToolParameter.oneOf semantics mean "one of these string values"
            // If oneOf has different semantics in your codebase, adjust accordingly
            // **Verify**: Check existing ToolParameter usage for oneOf behavior
            return .dictionary([
                "type": .string("string"),
                "enum": .array(options.map { .string($0) })
            ])

        case .any:
            // No type constraint - accepts any JSON value
            // Empty object {} is valid JSON Schema (matches any type)
            // Alternative: .dictionary(["type": .array([.string("string"), .string("number"), ...])])
            // We choose empty object for maximum flexibility and simplicity
            // **NOTE**: Some strict clients may expect explicit type array
            // If compatibility issues arise, consider using type array instead
            return .dictionary([:])
        }
    }
}
```

### ToolDefinition → MCP Format
```swift
extension ToolDefinition {
    func toMCPFormat() -> SendableValue {
        .dictionary([
            "name": .string(name),
            "description": .string(description),
            "inputSchema": parametersToJSONSchema()
        ])
    }

    private func parametersToJSONSchema() -> SendableValue {
        var properties: [String: SendableValue] = [:]
        var required: [SendableValue] = []

        for param in parameters {
            // Use recursive JSON Schema conversion
            var schema = param.type.toJSONSchema()

            // Add description to schema
            if case .dictionary(var schemaDict) = schema {
                schemaDict["description"] = .string(param.description)
                schema = .dictionary(schemaDict)
            }

            properties[param.name] = schema

            if param.isRequired {
                required.append(.string(param.name))
            }
        }

        return .dictionary([
            "type": .string("object"),
            "properties": .dictionary(properties),
            "required": .array(required)
        ])
    }
}
```

## Implementation Steps (TDD)

### Phase 1: Transport Layer
1. **Test**: Write `StdioMCPServerTransportTests` with in-memory pipes (see testing strategy below)
2. **Implement**: `MCPServerTransport` protocol
3. **Implement**: `StdioMCPServerTransport` with dependency-injected FileHandles
4. **Verify**: JSON parsing, newline framing, actor isolation

**Stdio Testing Strategy:**
```swift
// StdioMCPServerTransport implementation with dependency injection
public actor StdioMCPServerTransport: MCPServerTransport {
    private let input: FileHandle
    private let output: FileHandle

    public init(
        input: FileHandle = .standardInput,
        output: FileHandle = .standardOutput
    ) {
        self.input = input
        self.output = output
    }

    // ... implementation
}

// Test example using in-memory pipes
func testStdioTransport() async throws {
    let inputPipe = Pipe()
    let outputPipe = Pipe()

    let transport = StdioMCPServerTransport(
        input: inputPipe.fileHandleForReading,
        output: outputPipe.fileHandleForWriting
    )

    try await transport.start()

    // Write test request to input
    let request = MCPRequest(method: "tools/list")
    let jsonData = try JSONEncoder().encode(request)
    inputPipe.fileHandleForWriting.write(jsonData)
    inputPipe.fileHandleForWriting.write(Data("\n".utf8))

    // Read response from output
    let responseData = outputPipe.fileHandleForReading.availableData
    let response = try JSONDecoder().decode(MCPResponse.self, from: responseData)

    XCTAssertNotNil(response.result)
}
```

### Phase 2: Request Handler
1. **Test**: `MCPServerRequestHandlerTests.testInitialize()`
   - **CRITICAL**: Validate full initialize response structure
   - Must include: `protocolVersion`, `serverInfo` {name, version}, `capabilities`
   - Verify JSON structure matches MCP client expectations
2. **Implement**: `handleInitialize()` method with complete response
3. **Test**: `testToolsList()` with mock ToolRegistry
4. **Implement**: `handleToolsList()` + `ToolDefinition.toMCPFormat()`
5. **Test**: `testToolsCall()` with real tools
6. **Implement**: `handleToolsCall()` with error handling
7. **Test**: Error cases (unknown method, invalid params, tool errors)
8. **Test**: Parse error handling (no valid request ID, use `""` consistently)

### Phase 3: Server Host
1. **Test**: `MCPServerHostTests` with mock transport
2. **Implement**: `MCPServerHost` lifecycle methods
3. **Implement**: Request processing loop
4. **Test**: Graceful shutdown with in-flight requests
5. **Implement**: `MCPServerHost.stdio()` factory method

### Phase 4: Integration & Examples
1. Create `Examples/MCPServer/` executable package
2. Manual test with MCP clients (Claude Desktop, command-line, custom client)
3. Write end-to-end integration tests
4. Add documentation and usage examples

### Phase 5: Code Review & Polish
1. Run `code-reviewer` agent
2. Run `swift package plugin --allow-writing-to-package-directory swiftformat`
3. Run `swiftlint lint`
4. Add API documentation comments
5. Update framework README

## Files to Create

### Source Files
- `Sources/SwiftAgents/MCP/Server/MCPServerTransport.swift` (~50 lines)
  - Protocol for transport abstraction

- `Sources/SwiftAgents/MCP/Server/StdioMCPServerTransport.swift` (~250 lines)
  - Stdio transport with FileHandle, newline-delimited JSON
  - Robust buffered line reading with edge case handling
  - EOF detection and graceful shutdown

- `Sources/SwiftAgents/MCP/Server/MCPServerRequestHandler.swift` (~350 lines)
  - Method routing, tool registry integration, response construction
  - Request tracking dictionary for cancellation support
  - Handles parse errors without valid request IDs

- `Sources/SwiftAgents/MCP/Server/MCPServerHost.swift` (~150 lines)
  - Public API, lifecycle management, processing loop

- `Sources/SwiftAgents/MCP/Server/ToolDefinition+MCP.swift` (~150 lines)
  - Extension with `toMCPFormat()` and recursive JSON Schema generation
  - Extension on `ToolParameter.ParameterType` with `toJSONSchema()`

- `Sources/SwiftAgents/Core/Logger+SwiftAgents.swift` (modify existing)
  - Add new logger category: `public static let mcpServer = Logger(label: "com.swiftagents.mcp.server")`

### Test Files
- `Tests/SwiftAgentsTests/MCP/Server/StdioMCPServerTransportTests.swift` (~250 lines)
  - Basic line reading tests
  - **Edge case tests**: partial reads, empty lines, trailing whitespace
  - EOF handling test
  - Line length limit test
  - Malformed UTF-8 test

- `Tests/SwiftAgentsTests/MCP/Server/MCPServerRequestHandlerTests.swift` (~300 lines)
  - Method routing tests
  - Tool execution tests
  - **Request cancellation tests**
  - Parse error handling (no valid request ID)
  - Error conversion tests (AgentError → MCPError)

- `Tests/SwiftAgentsTests/MCP/Server/MCPServerHostTests.swift` (~250 lines)
  - Lifecycle tests
  - Graceful shutdown test with in-flight requests
  - EOF triggering shutdown test

### Example (Separate Package)
Create standalone example package in repository root:
- `Examples/MCPServer/Package.swift` (~40 lines)
  - Swift 6.2 executable package depending on SwiftAgents
- `Examples/MCPServer/Sources/MCPServerExample/main.swift` (~60 lines)
  - Complete server implementation with signal handling
  - Example tool registration
  - Logging configuration

## Reused Existing Types

**Reused without modification:**
- `MCPRequest` - Request deserialization
- `MCPResponse` - Response serialization (`.success()`, `.failure()`)
- `MCPError` - Error codes and factory methods
- `MCPErrorObject` - JSON-RPC error format
- `MCPCapabilities` - Capability negotiation
- `ToolRegistry` - Tool management and execution
- `ToolDefinition` - Tool metadata
- `ToolParameter` - Parameter definitions
- `SendableValue` - Type-safe dynamic values

## Key Design Decisions

1. **Actors everywhere**: All server components are actors for data-race safety
2. **Never throw to transport**: All errors converted to JSON-RPC error responses
3. **Newline-delimited JSON**: Standard MCP stdio format with robust line parsing
4. **Buffered line reading**: Accumulate bytes until complete line (handles partial reads)
5. **Logging to stderr**: stdout reserved for JSON-RPC, use stderr or file logging
6. **Graceful shutdown**: Cancel in-flight requests on EOF, 5-second timeout
7. **Dependency injection**: FileHandles injected for testability
8. **Request cancellation tracking**: Track Tasks in dictionary for cancellation support
9. **10MB line limit**: Prevent memory exhaustion from malicious clients
10. **Empty line tolerance**: Silently ignore empty lines for robustness

## Security & Performance

### Input Validation
- **Maximum request size**: 10MB (configurable in future)
  - Prevents memory exhaustion from malicious clients
  - JSON parser will fail gracefully on oversized payloads
- **Tool execution timeout**: 60 seconds default (configurable via ToolRegistry)
  - Prevents infinite loops or hanging tools
  - Uses Task cancellation for clean timeout handling

### Error Handling Safety
- **No sensitive data in errors**: Tool errors sanitized before sending to client
  - `AgentError` messages included but stack traces excluded
  - File paths and system details not exposed
- **Graceful degradation**: Server continues running even if individual tools fail

### Concurrency Controls & Request Cancellation
- **Actor isolation**: Prevents race conditions in server state
- **No explicit rate limiting** in v1 (stdio is inherently single-client)
  - Future HTTP transport will need rate limiting per client

- **In-flight request tracking**: Handler tracks pending tool executions
  - Uses `Task` handles stored in `[RequestID: Task<SendableValue, Error>]` dictionary
  - On graceful shutdown: Cancel all tasks via `Task.cancel()`
  - Timeout: 5 seconds to complete in-flight requests
  - After timeout, server closes immediately

- **EOF handling**: When stdin closes (client disconnect):
  - Stop reading from stdin immediately
  - Cancel all in-flight tool executions via `Task.cancel()`
  - **Check if stdout is still writable** before attempting flush
  - If stdout writable: Best-effort flush of pending responses (2-second timeout)
  - If stdout closed or timeout: Drop pending responses
  - Log: "Client disconnected (EOF), flushed N responses, dropped M responses"
  - Clean shutdown within 5 seconds total

### Stdio Edge Cases

**Critical Production Concerns:**

1. **Partial Reads / Line Atomicity**
   - `FileHandle.bytes.lines` in Swift does NOT guarantee atomic line reads
   - A partial JSON could be read if stdin buffer is flushed mid-line
   - **Solution**: Use internal buffer to accumulate data until newline is found
   - Read raw bytes, accumulate in buffer, split on `\n`, process complete lines

2. **Empty Lines**
   - **Strategy**: Silently ignore empty lines (common with manual testing)
   - Trim whitespace before checking if line is empty
   - Do NOT send error responses for empty lines

3. **Trailing Whitespace**
   - JSON may have trailing spaces/tabs: `{"jsonrpc":"2.0",...}  \n`
   - **Solution**: Trim whitespace from each line before JSON parsing
   - Use `line.trimmingCharacters(in: .whitespacesAndNewlines)`

4. **Malformed JSON**
   - Client sends invalid JSON or non-JSON text
   - **Strategy**: Send JSON-RPC parse error response
   - Error code: -32700 (Parse error)
   - Challenge: Can't parse request ID from malformed request
   - **Solution**: Use `null` as request ID per JSON-RPC 2.0 spec for parse errors

5. **EOF (End of File)**
   - MCP client exits → stdin closes → EOF on read
   - **Strategy**: Treat EOF as graceful shutdown signal
   - Stop reading immediately (input closed)
   - Cancel in-flight requests via `Task.cancel()`
   - **Best-effort response flush**:
     - Check if stdout `FileHandle` is still writable (may still be open)
     - If yes: Attempt to send pending responses (2-second timeout)
     - If no or timeout: Drop responses and log count
   - Log shutdown: "Client disconnected (EOF), flushed X, dropped Y"
   - **Test both scenarios**: stdout writable after EOF, stdout closed with EOF

6. **Very Long Lines**
   - Malicious client sends 100MB single-line JSON
   - **Strategy**: Enforce line length limit (10MB)
   - If line exceeds limit:
     1. Attempt to partially parse first 1KB to extract request ID
     2. If ID extracted: Return `MCPResponse.failure(id: extractedId, error: "Request too large")`
     3. If no ID: Return `MCPResponse.failure(id: "", error: parseError("Request exceeds 10MB limit"))`
     4. Log distinct error: `"Request exceeded size limit: {size}MB"`
   - **Never skip without response** - clients will hang waiting
   - Prevents memory exhaustion while maintaining protocol compliance

**Implementation Pattern:**
```swift
// Robust line reading with buffering
private func readLines() -> AsyncStream<Result<String, OversizeLineError>> {
    AsyncStream { continuation in
        Task {
            var buffer = Data()

            while !Task.isCancelled {
                do {
                    let chunk = try input.read(upToCount: 4096) ?? Data()

                    // EOF detected
                    guard !chunk.isEmpty else {
                        Log.mcpServer.info("EOF detected, closing input stream")
                        continuation.finish()
                        return
                    }

                    buffer.append(chunk)

                    // Process complete lines
                    while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                        let lineData = buffer[..<newlineIndex]
                        buffer = buffer[buffer.index(after: newlineIndex)...]

                        // Check line length limit (10MB)
                        if lineData.count > 10_485_760 {
                            Log.mcpServer.error("Line exceeds 10MB limit: \(lineData.count) bytes")
                            // Yield error with partial line (first 1KB for ID extraction)
                            let partial = lineData.prefix(1024)
                            continuation.yield(.failure(OversizeLineError(partialData: partial, totalSize: lineData.count)))
                            continue
                        }

                        guard let lineString = String(data: lineData, encoding: .utf8) else {
                            Log.mcpServer.error("Invalid UTF-8 in line")
                            // Invalid UTF-8 is a parse error - yield failure
                            continuation.yield(.failure(OversizeLineError(partialData: lineData.prefix(1024), totalSize: lineData.count)))
                            continue
                        }

                        let trimmed = lineString.trimmingCharacters(in: .whitespacesAndNewlines)

                        // Ignore empty lines silently
                        guard !trimmed.isEmpty else { continue }

                        continuation.yield(.success(trimmed))
                    }
                } catch {
                    Log.mcpServer.error("Read error: \(error)")
                    continuation.finish()
                    return
                }
            }
        }
    }
}

struct OversizeLineError: Error {
    let partialData: Data
    let totalSize: Int
}
```

### Logging Security
- **No stdout pollution**: All logs go to stderr or file
- **Log level control**: Separate logger category `Log.mcpServer`
- **No credential logging**: Tool arguments may contain sensitive data
  - Only log tool names and result success/failure, not actual values

## v1 Limitations

**Not Supported:**
- ❌ Resources (no `MCPResourceProvider` yet)
- ❌ Prompts (no prompt template system)
- ❌ Sampling (requires SwiftAI SDK integration)
- ❌ Server→client notifications (stdio is request/response)
- ❌ Progress reporting for long-running tools
- ❌ HTTP/SSE transports

**Supported:**
- ✅ Tool discovery (`tools/list`)
- ✅ Tool execution (`tools/call`)
- ✅ Capability negotiation (`initialize`)
- ✅ Stdio transport (MCP protocol compliant, works with any MCP client)
- ✅ JSON-RPC 2.0 error handling

## Future Enhancements

### v2: HTTP/SSE Transport
```swift
public actor HTTPMCPServerTransport: MCPServerTransport {
    private let port: Int
    // HTTP POST for requests, SSE for notifications
}
```

### v3: Resource Support
```swift
public protocol MCPResourceProvider: Sendable {
    var uri: String { get }
    func read() async throws -> MCPResourceContent
}

public actor MCPResourceRegistry {
    func register(_ provider: any MCPResourceProvider)
}
```

### v4: Advanced Features
- Runtime log level control via `logging/setLevel`
- Progress notifications for long-running tools
- Prompt template system

## Verification Plan

**Unit Tests:**
```bash
swift test --filter MCPServerTransportTests
swift test --filter MCPServerRequestHandlerTests
swift test --filter MCPServerHostTests
```

**Manual Testing with MCP Clients:**

*Option 1: Claude Desktop*
1. Build example server executable
2. Add to Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`)
3. Restart Claude Desktop
4. Verify tools appear in tool list
5. Test tool execution and error handling

*Option 2: Command-Line Testing*
1. Build example server executable
2. Test initialize: `echo '{"jsonrpc":"2.0","id":"1","method":"initialize","params":{}}' | ./mcp-server`
3. Test tools/list: `echo '{"jsonrpc":"2.0","id":"2","method":"tools/list"}' | ./mcp-server`
4. Test tools/call: `echo '{"jsonrpc":"2.0","id":"3","method":"tools/call","params":{"name":"datetime","arguments":{}}}' | ./mcp-server`

*Option 3: Custom MCP Client*
1. Implement custom client using stdio Process interaction
2. Send JSON-RPC requests via stdin
3. Read JSON-RPC responses from stdout
4. Verify protocol compliance

**Integration Tests:**
- End-to-end request/response flow with real tools
- Error conditions (malformed JSON, invalid methods)
- Concurrent requests (actor isolation)
- Graceful shutdown with in-flight requests
- **Edge case tests** (CRITICAL):
  - Partial line reads (send data in small chunks)
  - Empty lines between requests
  - Trailing whitespace on lines
  - Very long lines (>10MB)
  - EOF during tool execution
  - Malformed JSON (missing quotes, truncated)
  - Multiple newlines in JSON strings
  - Request cancellation when stdin closes

## Critical Files Reference

- **MCPProtocol.swift** - Existing JSON-RPC types (read-only)
- **Tool.swift** - Existing Tool protocol (read-only)
- **MCPError.swift** - Existing error codes (read-only)
- **ToolDefinition** location - `Sources/SwiftAgents/Tools/ToolDefinition.swift`
- **ConduitToolConverter.swift** - Reference for recursive parameter type conversion pattern
- **MCPServerState** enum - Reuse from existing `MCPServer.swift` for lifecycle management

## Critical Clarifications & Design Decisions

### 1. Parse Error ID Strategy (Resolved)
**Decision**: Consistently use empty string `""` for parse error request IDs

**Rationale**:
- Existing `MCPResponse.id` is `String` (not optional)
- Changing to `String?` would be breaking change to existing types
- JSON-RPC 2.0 spec recommends `null`, but we prioritize type safety
- Empty string is valid JSON string per spec, though unconventional
- **CRITICAL**: Must be consistent - never mix strategies

**Implementation**:
- All parse errors: `MCPResponse.failure(id: "", error: parseError(...))`
- Document deviation from spec in code comments
- Future v2 could make `id` optional for stricter compliance

### 2. Oversize Line Handling (Resolved)
**Decision**: Always send error response, never skip silently

**Rationale**:
- Skipping without response causes client hangs
- Client expects response for every request
- Protocol compliance requires responding even to malformed requests

**Implementation**:
- Lines >10MB: Attempt partial parse of first 1KB to extract ID
- If ID found: `MCPResponse.failure(id: extractedId, error: "Request too large")`
- If no ID: `MCPResponse.failure(id: "", error: parseError("Request exceeds 10MB"))`
- Log: "Request exceeded size limit: {size}MB"
- Return `Result<String, OversizeLineError>` from line reader

### 3. Initialize Response Structure (Resolved)
**Decision**: Return complete MCP initialize response with 3 required fields

**Required Fields**:
1. `protocolVersion`: "2024-11-05"
2. `serverInfo`: {name, version}
3. `capabilities`: {tools: {}, resources: null, ...}

**Rationale**:
- MCP clients expect full structure (verified from HTTPMCPServer.parseCapabilities)
- Missing fields may cause negotiation rejection
- Capabilities indicated by presence (`tools: {}`) or absence (omit key)

**Implementation**:
```swift
SendableValue.dictionary([
    "protocolVersion": .string("2024-11-05"),
    "serverInfo": .dictionary([
        "name": .string("SwiftAgents MCP Server"),
        "version": .string("1.0.0")
    ]),
    "capabilities": .dictionary([
        "tools": .dictionary([:])
    ])
])
```

### 4. JSON Schema for `any` Type (Resolved)
**Decision**: Use empty object `{}` for maximum flexibility

**Rationale**:
- Empty JSON Schema object matches any JSON value (valid per spec)
- Simpler than explicit type array `["string", "number", "object", ...]`
- If compatibility issues arise with strict clients, can switch to type array

**Implementation**:
- `ToolParameter.ParameterType.any` → `.dictionary([:])`
- Document potential compatibility concern
- Add test validating schema generation

**oneOf Semantics**:
- Assumes oneOf means "one of these string values"
- Verify existing ToolParameter usage matches this assumption
- Maps to JSON Schema `enum` constraint

### 5. EOF and Response Flushing (Resolved)
**Decision**: Best-effort flush if stdout still writable, with timeout

**Rationale**:
- EOF on stdin doesn't guarantee stdout is closed
- Client may still receive responses if stdout writable
- But must timeout to avoid hanging on closed output

**Implementation**:
- EOF detected → stop reading immediately
- Cancel all in-flight tasks
- Check stdout `FileHandle.isWritable` (if available) or attempt write with error handling
- Flush pending responses with 2-second timeout
- Log: "Client disconnected (EOF), flushed X, dropped Y"
- Tests must verify both scenarios: stdout open, stdout closed

**Edge Cases**:
- Stdout closed with stdin: Drop all responses
- Stdout open after stdin EOF: Attempt flush
- Flush timeout: Drop remaining responses after 2 seconds
