// HTTPMCPServer.swift
// Swarm Framework
//
// HTTP-based MCP server client implementation.

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - HTTPMCPServer

/// An HTTP-based client for Model Context Protocol (MCP) servers.
///
/// HTTPMCPServer provides a stateless HTTP transport for communicating with
/// MCP-compliant servers. It handles JSON-RPC 2.0 request/response encoding,
/// automatic retries with exponential backoff, and capability negotiation.
///
/// ## Example Usage
///
/// ```swift
/// let server = HTTPMCPServer(
///     url: URL(string: "https://mcp.example.com/api")!,
///     name: "example-server",
///     apiKey: "sk-xxx"
/// )
///
/// // Initialize and discover capabilities
/// let capabilities = try await server.initialize()
///
/// // List available tools
/// if capabilities.tools {
///     let tools = try await server.listTools()
///     for tool in tools {
///         print("\(tool.name): \(tool.description)")
///     }
/// }
///
/// // Call a tool
/// let result = try await server.callTool(
///     name: "search",
///     arguments: ["query": .string("swift concurrency")]
/// )
/// ```
///
/// ## Thread Safety
///
/// HTTPMCPServer is implemented as an actor, ensuring thread-safe access
/// to mutable state such as cached capabilities.
public actor HTTPMCPServer: MCPServer {
    // MARK: Public

    // MARK: - Public Properties

    /// The name of this MCP server.
    public let name: String

    /// The capabilities of this MCP server.
    ///
    /// Returns cached capabilities if available, otherwise returns empty capabilities.
    /// Call `initialize()` to populate capabilities from the server.
    public var capabilities: MCPCapabilities {
        cachedCapabilities ?? MCPCapabilities()
    }

    // MARK: - Initialization

    /// Creates an HTTP MCP server client.
    ///
    /// - Parameters:
    ///   - url: The base URL of the MCP server.
    ///   - name: A name for this server instance (used for identification and logging).
    ///   - apiKey: An optional API key for Bearer token authentication.
    ///   - timeout: The request timeout interval in seconds. Default: 30.0
    ///   - maxRetries: The maximum number of retry attempts for failed requests. Default: 3
    ///   - session: The URLSession to use for requests. Default: .shared
    public init(
        url: URL,
        name: String,
        apiKey: String? = nil,
        timeout: TimeInterval = 30.0,
        maxRetries: Int = 3,
        session: URLSession = .shared
    ) {
        // Security: Enforce HTTPS when API keys are used to prevent credential exposure
        if apiKey != nil {
            precondition(
                url.scheme?.lowercased() == "https",
                "HTTPMCPServer: HTTPS is required when using API keys to prevent credential exposure. URL scheme: \(url.scheme ?? "nil")"
            )
        }

        baseURL = url
        self.name = name
        self.apiKey = apiKey
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.session = session
        cachedCapabilities = nil

        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    // MARK: - MCPServer Protocol Implementation

    /// Initializes the connection to the MCP server and negotiates capabilities.
    ///
    /// Sends an "initialize" request with protocol version and client information,
    /// then parses and caches the server's capabilities.
    ///
    /// - Returns: The capabilities supported by this server.
    /// - Throws: `MCPError` if initialization fails.
    public func initialize() async throws -> MCPCapabilities {
        let params: [String: SendableValue] = [
            "protocolVersion": .string("2024-11-05"),
            "clientInfo": .dictionary([
                "name": .string("Swarm"),
                "version": .string("1.0.0")
            ])
        ]

        let request = MCPRequest(method: "initialize", params: params)
        let response = try await sendRequest(request)

        if let error = response.error {
            throw MCPError(code: error.code, message: error.message, data: error.data)
        }

        guard let result = response.result else {
            throw MCPError.internalError("No result in initialize response")
        }

        let capabilities = try parseCapabilities(from: result)
        cachedCapabilities = capabilities
        return capabilities
    }

    /// Lists all tools available from this MCP server.
    ///
    /// - Returns: An array of tool schemas describing available tools.
    /// - Throws: `MCPError` if the request fails.
    public func listTools() async throws -> [ToolSchema] {
        let request = MCPRequest(method: "tools/list")
        let response = try await sendRequest(request)

        if let error = response.error {
            throw MCPError(code: error.code, message: error.message, data: error.data)
        }

        guard let result = response.result else {
            throw MCPError.internalError("No result in tools/list response")
        }

        return try parseTools(from: result)
    }

    /// Calls a tool on the MCP server with the specified arguments.
    ///
    /// - Parameters:
    ///   - name: The name of the tool to call.
    ///   - arguments: A dictionary of argument names to values.
    /// - Returns: The result of the tool execution.
    /// - Throws: `MCPError` if the request fails.
    public func callTool(name: String, arguments: [String: SendableValue]) async throws -> SendableValue {
        let params: [String: SendableValue] = [
            "name": .string(name),
            "arguments": .dictionary(arguments)
        ]

        let request = MCPRequest(method: "tools/call", params: params)
        let response = try await sendRequest(request)

        if let error = response.error {
            throw MCPError(code: error.code, message: error.message, data: error.data)
        }

        guard let result = response.result else {
            throw MCPError.internalError("No result in tools/call response")
        }

        return result
    }

    /// Lists all resources available from this MCP server.
    ///
    /// - Returns: An array of resource metadata objects.
    /// - Throws: `MCPError` if the request fails.
    public func listResources() async throws -> [MCPResource] {
        let request = MCPRequest(method: "resources/list")
        let response = try await sendRequest(request)

        if let error = response.error {
            throw MCPError(code: error.code, message: error.message, data: error.data)
        }

        guard let result = response.result else {
            throw MCPError.internalError("No result in resources/list response")
        }

        return try parseResources(from: result)
    }

    /// Reads the content of a resource from the MCP server.
    ///
    /// - Parameter uri: The URI of the resource to read.
    /// - Returns: The content of the resource.
    /// - Throws: `MCPError` if the request fails.
    public func readResource(uri: String) async throws -> MCPResourceContent {
        let params: [String: SendableValue] = [
            "uri": .string(uri)
        ]

        let request = MCPRequest(method: "resources/read", params: params)
        let response = try await sendRequest(request)

        if let error = response.error {
            throw MCPError(code: error.code, message: error.message, data: error.data)
        }

        guard let result = response.result else {
            throw MCPError.internalError("No result in resources/read response")
        }

        return try parseResourceContent(from: result)
    }

    /// Closes the connection to the MCP server.
    ///
    /// For HTTP, this simply clears the cached capabilities since the
    /// transport is stateless. It is safe to call multiple times.
    public func close() async throws {
        cachedCapabilities = nil
    }

    // MARK: Private

    // MARK: - Private Properties

    /// The base URL of the MCP server.
    private let baseURL: URL

    /// The URL session used for HTTP requests.
    private let session: URLSession

    /// The optional API key for authentication.
    private let apiKey: String?

    /// The request timeout interval.
    private let timeout: TimeInterval

    /// The maximum number of retry attempts.
    private let maxRetries: Int

    /// Cached capabilities from the server.
    private var cachedCapabilities: MCPCapabilities?

    /// JSON encoder for requests.
    private let encoder: JSONEncoder

    /// JSON decoder for responses.
    private let decoder: JSONDecoder

    // MARK: - Private Methods

    /// Sends an MCP request with retry logic.
    ///
    /// Implements exponential backoff for retryable errors. Client errors (4xx)
    /// are not retried.
    ///
    /// - Parameter mcpRequest: The MCP request to send.
    /// - Returns: The MCP response from the server.
    /// - Throws: `MCPError` if all retry attempts fail.
    private func sendRequest(_ mcpRequest: MCPRequest) async throws -> MCPResponse {
        var lastError: Error?

        for attempt in 0..<(maxRetries + 1) {
            do {
                return try await performRequest(mcpRequest)
            } catch let error as MCPError {
                lastError = error

                // Don't retry client errors (4xx range mapped to specific MCP errors)
                if error.code == MCPError.invalidRequestCode ||
                    error.code == MCPError.invalidParamsCode ||
                    error.code == MCPError.methodNotFoundCode {
                    throw error
                }

                // Don't retry if this was the last attempt
                if attempt == maxRetries {
                    throw error
                }

                // Check for cancellation before sleeping
                try Task.checkCancellation()

                // Exponential backoff: 1s, 2s, 4s, etc.
                let delay = pow(2.0, Double(attempt))
                try await Task.sleep(for: .seconds(delay))
            } catch {
                lastError = error

                if attempt == maxRetries {
                    // Preserve detailed error context for debugging
                    let errorData: [String: SendableValue] = [
                        "originalError": .string(String(describing: error)),
                        "errorType": .string(String(describing: type(of: error))),
                        "attempts": .int(attempt + 1),
                        "maxRetries": .int(maxRetries)
                    ]
                    throw MCPError(
                        code: MCPError.internalErrorCode,
                        message: "Request failed after \(maxRetries + 1) attempts: \(error.localizedDescription)",
                        data: .dictionary(errorData)
                    )
                }

                // Check for cancellation before sleeping
                try Task.checkCancellation()

                let delay = pow(2.0, Double(attempt))
                try await Task.sleep(for: .seconds(delay))
            }
        }

        throw lastError ?? MCPError.internalError("Request failed after \(maxRetries) retries")
    }

    /// Performs a single HTTP request to the MCP server.
    ///
    /// - Parameter mcpRequest: The MCP request to send.
    /// - Returns: The MCP response from the server.
    /// - Throws: `MCPError` if the request fails.
    private func performRequest(_ mcpRequest: MCPRequest) async throws -> MCPResponse {
        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = timeout

        if let apiKey {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        urlRequest.httpBody = try encoder.encode(mcpRequest)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.internalError("Invalid response type")
        }

        // Check for HTTP errors
        let statusCode = httpResponse.statusCode
        guard (200 ... 299).contains(statusCode) else {
            // Try to decode error message from response body
            let errorMessage = if let bodyString = String(data: data, encoding: .utf8), !bodyString.isEmpty {
                "HTTP \(statusCode): \(bodyString)"
            } else {
                "HTTP \(statusCode)"
            }

            throw MCPError(code: statusCode, message: errorMessage)
        }

        return try decoder.decode(MCPResponse.self, from: data)
    }

    // MARK: - Parsing Helpers

    /// Parses capabilities from an initialize response.
    ///
    /// - Parameter value: The result value from the initialize response.
    /// - Returns: The parsed MCPCapabilities.
    /// - Throws: `MCPError` if parsing fails.
    private func parseCapabilities(from value: SendableValue) throws -> MCPCapabilities {
        guard let dict = value.dictionaryValue else {
            throw MCPError.parseError("Expected dictionary in initialize result")
        }

        let capabilitiesDict = dict["capabilities"]?.dictionaryValue ?? [:]

        let hasTools = capabilitiesDict["tools"] != nil
        let hasResources = capabilitiesDict["resources"] != nil
        let hasPrompts = capabilitiesDict["prompts"] != nil
        let hasSampling = capabilitiesDict["sampling"] != nil

        return MCPCapabilities(
            tools: hasTools,
            resources: hasResources,
            prompts: hasPrompts,
            sampling: hasSampling
        )
    }

    /// Parses tool schemas from a tools/list response.
    ///
    /// - Parameter value: The result value from the tools/list response.
    /// - Returns: An array of ToolSchema objects.
    /// - Throws: `MCPError` if parsing fails.
    private func parseTools(from value: SendableValue) throws -> [ToolSchema] {
        guard let dict = value.dictionaryValue,
              let toolsArray = dict["tools"]?.arrayValue else {
            throw MCPError.parseError("Expected dictionary with 'tools' array in tools/list result")
        }

        var tools: [ToolSchema] = []

        for toolValue in toolsArray {
            guard let toolDict = toolValue.dictionaryValue,
                  let name = extractString(toolDict["name"]) else {
                continue
            }

            let description = extractString(toolDict["description"]) ?? ""
            let parameters = parseParameters(from: toolDict["inputSchema"])

            tools.append(ToolSchema(name: name, description: description, parameters: parameters))
        }

        return tools
    }

    /// Parses parameters from a JSON Schema inputSchema.
    ///
    /// - Parameter schema: The inputSchema value.
    /// - Returns: An array of ToolParameter objects.
    private func parseParameters(from schema: SendableValue?) -> [ToolParameter] {
        guard let schemaDict = schema?.dictionaryValue,
              let properties = schemaDict["properties"]?.dictionaryValue else {
            return []
        }

        let requiredSet = Set(schemaDict["required"]?.arrayValue?.compactMap(\.stringValue) ?? [])
        var parameters: [ToolParameter] = []

        for (name, propValue) in properties {
            guard let propDict = propValue.dictionaryValue else { continue }

            let description = extractString(propDict["description"]) ?? ""
            let typeString = extractString(propDict["type"]) ?? "any"
            let paramType = mapParameterType(typeString)
            let isRequired = requiredSet.contains(name)

            parameters.append(ToolParameter(
                name: name,
                description: description,
                type: paramType,
                isRequired: isRequired
            ))
        }

        return parameters
    }

    /// Maps a JSON Schema type string to a ToolParameter.ParameterType.
    ///
    /// - Parameter typeString: The JSON Schema type string.
    /// - Returns: The corresponding ParameterType.
    private func mapParameterType(_ typeString: String) -> ToolParameter.ParameterType {
        switch typeString.lowercased() {
        case "string": .string
        case "integer": .int
        case "number": .double
        case "boolean": .bool
        case "array": .array(elementType: .any)
        case "object": .object(properties: [])
        default: .any
        }
    }

    /// Parses resources from a resources/list response.
    ///
    /// - Parameter value: The result value from the resources/list response.
    /// - Returns: An array of MCPResource objects.
    /// - Throws: `MCPError` if parsing fails.
    private func parseResources(from value: SendableValue) throws -> [MCPResource] {
        guard let dict = value.dictionaryValue,
              let resourcesArray = dict["resources"]?.arrayValue else {
            throw MCPError.parseError("Expected dictionary with 'resources' array in resources/list result")
        }

        var resources: [MCPResource] = []

        for resourceValue in resourcesArray {
            guard let resourceDict = resourceValue.dictionaryValue,
                  let uri = extractString(resourceDict["uri"]),
                  let name = extractString(resourceDict["name"]) else {
                continue
            }

            let description = extractString(resourceDict["description"])
            let mimeType = extractString(resourceDict["mimeType"])

            resources.append(MCPResource(
                uri: uri,
                name: name,
                description: description,
                mimeType: mimeType
            ))
        }

        return resources
    }

    /// Parses resource content from a resources/read response.
    ///
    /// - Parameter value: The result value from the resources/read response.
    /// - Returns: The parsed MCPResourceContent.
    /// - Throws: `MCPError` if parsing fails.
    private func parseResourceContent(from value: SendableValue) throws -> MCPResourceContent {
        guard let dict = value.dictionaryValue,
              let contentsArray = dict["contents"]?.arrayValue,
              let firstContent = contentsArray.first,
              let contentDict = firstContent.dictionaryValue else {
            throw MCPError.parseError("Expected dictionary with 'contents' array in resources/read result")
        }

        let uri = extractString(contentDict["uri"]) ?? ""
        let mimeType = extractString(contentDict["mimeType"])
        let text = extractString(contentDict["text"])
        let blob = extractString(contentDict["blob"])

        return MCPResourceContent(
            uri: uri,
            mimeType: mimeType,
            text: text,
            blob: blob
        )
    }

    /// Extracts a string from a SendableValue.
    ///
    /// - Parameter value: The value to extract from.
    /// - Returns: The string value, or nil if not a string.
    private func extractString(_ value: SendableValue?) -> String? {
        value?.stringValue
    }
}
