// MCPProtocol.swift
// Swarm Framework
//
// JSON-RPC 2.0 request/response types for Model Context Protocol (MCP) operations.

import Foundation

// MARK: - MCPRequest

/// A JSON-RPC 2.0 request object for MCP operations.
///
/// This struct represents a JSON-RPC 2.0 compliant request that can be sent
/// to an MCP server. Every request includes the protocol version, a unique
/// identifier, the method to invoke, and optional parameters.
///
/// ## JSON-RPC 2.0 Compliance
/// - `jsonrpc` is always "2.0"
/// - `id` uniquely identifies the request for correlating responses
/// - `method` specifies the remote procedure to call
/// - `params` contains optional structured arguments
///
/// ## Example Usage
/// ```swift
/// // Simple request without parameters
/// let request = MCPRequest(method: "tools/list")
///
/// // Request with parameters
/// let callRequest = MCPRequest(
///     method: "tools/call",
///     params: [
///         "name": "calculator",
///         "arguments": ["expression": "2 + 2"]
///     ]
/// )
///
/// // Request with custom ID
/// let customRequest = MCPRequest(
///     id: "request-001",
///     method: "resources/read",
///     params: ["uri": "file:///example.txt"]
/// )
/// ```
public struct MCPRequest: Sendable, Codable, Equatable {
    // MARK: Public

    /// The JSON-RPC protocol version. Always "2.0".
    public let jsonrpc: String

    /// A unique identifier for this request.
    ///
    /// Used to correlate responses with their corresponding requests.
    /// Defaults to a new UUID string if not specified.
    public let id: String

    /// The name of the method to invoke.
    ///
    /// MCP defines standard methods such as:
    /// - `initialize` - Initialize the connection
    /// - `tools/list` - List available tools
    /// - `tools/call` - Execute a tool
    /// - `resources/list` - List available resources
    /// - `resources/read` - Read a resource
    /// - `prompts/list` - List available prompts
    /// - `prompts/get` - Get a prompt
    public let method: String

    /// Optional parameters for the method.
    ///
    /// The structure of parameters depends on the method being called.
    /// Use `nil` for methods that do not require parameters.
    public let params: [String: SendableValue]?

    // MARK: - Initialization

    /// Creates a new JSON-RPC 2.0 request.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the request. Defaults to a new UUID string.
    ///         Must be non-empty per JSON-RPC 2.0 specification.
    ///   - method: The name of the method to invoke. Must be non-empty.
    ///   - params: Optional parameters for the method. Defaults to `nil`.
    ///
    /// - Precondition: `id` must be non-empty.
    /// - Precondition: `method` must be non-empty.
    public init(
        id: String = UUID().uuidString,
        method: String,
        params: [String: SendableValue]? = nil
    ) {
        precondition(!id.isEmpty, "MCPRequest: id cannot be empty per JSON-RPC 2.0 specification")
        precondition(!method.isEmpty, "MCPRequest: method cannot be empty")

        jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Validate jsonrpc version
        let version = try container.decode(String.self, forKey: .jsonrpc)
        guard version == "2.0" else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [CodingKeys.jsonrpc],
                    debugDescription: "Invalid JSON-RPC version: expected '2.0', got '\(version)'"
                )
            )
        }
        jsonrpc = version

        let decodedId = try container.decode(String.self, forKey: .id)
        guard !decodedId.isEmpty else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [CodingKeys.id],
                    debugDescription: "Request ID cannot be empty"
                )
            )
        }
        id = decodedId

        let decodedMethod = try container.decode(String.self, forKey: .method)
        guard !decodedMethod.isEmpty else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [CodingKeys.method],
                    debugDescription: "Method name cannot be empty"
                )
            )
        }
        method = decodedMethod

        params = try container.decodeIfPresent([String: SendableValue].self, forKey: .params)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encode(method, forKey: .method)
        try container.encodeIfPresent(params, forKey: .params)
    }

    // MARK: Private

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case method
        case params
    }
}

// MARK: - MCPResponse

/// A JSON-RPC 2.0 response object for MCP operations.
///
/// This struct represents a JSON-RPC 2.0 compliant response received from
/// an MCP server. A response contains either a result (on success) or an
/// error (on failure), but never both.
///
/// ## JSON-RPC 2.0 Compliance
/// - `jsonrpc` is always "2.0"
/// - `id` matches the request that triggered this response
/// - `result` is present on success, absent on error
/// - `error` is present on failure, absent on success
///
/// ## Example Usage
/// ```swift
/// // Decoding a response
/// let response = try JSONDecoder().decode(MCPResponse.self, from: data)
///
/// if let error = response.error {
///     print("Error: \(error.message)")
/// } else if let result = response.result {
///     print("Success: \(result)")
/// }
/// ```
public struct MCPResponse: Sendable, Codable, Equatable {
    // MARK: Public

    /// The JSON-RPC protocol version. Always "2.0".
    public let jsonrpc: String

    /// The identifier matching the corresponding request.
    public let id: String

    /// The result of the method invocation, if successful.
    ///
    /// Present when the request was processed successfully.
    /// `nil` when an error occurred.
    public let result: SendableValue?

    /// The error object, if the request failed.
    ///
    /// Present when an error occurred during processing.
    /// `nil` when the request was successful.
    public let error: MCPErrorObject?

    // MARK: - Initialization

    /// Creates a new JSON-RPC 2.0 response.
    ///
    /// According to JSON-RPC 2.0, a response must contain either a `result`
    /// (on success) or an `error` (on failure), but not both. This initializer
    /// enforces this constraint by throwing an error.
    ///
    /// - Parameters:
    ///   - jsonrpc: The protocol version. Should always be "2.0".
    ///   - id: The identifier matching the corresponding request.
    ///   - result: The result of successful execution, or `nil` on error.
    ///   - error: The error object on failure, or `nil` on success.
    ///
    /// - Throws: `MCPError.invalidRequest` if both `result` and `error` are `nil`,
    ///   or if both are non-nil, which violates JSON-RPC 2.0 specification.
    public init(
        jsonrpc: String = "2.0",
        id: String,
        result: SendableValue? = nil,
        error: MCPErrorObject? = nil
    ) throws {
        guard (result == nil) != (error == nil) else {
            throw MCPError.invalidRequest(
                "MCPResponse must have exactly one of result or error set, not both or neither"
            )
        }
        self.jsonrpc = jsonrpc
        self.id = id
        self.result = result
        self.error = error
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let jsonrpc = try container.decode(String.self, forKey: .jsonrpc)
        let id = try container.decode(String.self, forKey: .id)
        let result = try container.decodeIfPresent(SendableValue.self, forKey: .result)
        let error = try container.decodeIfPresent(MCPErrorObject.self, forKey: .error)

        // Validate JSON-RPC 2.0 mutual exclusivity
        guard (result == nil) != (error == nil) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "MCPResponse must have exactly one of result or error, not both or neither"
                )
            )
        }

        // Use private initializer that bypasses the throwing check
        // since we've already validated above
        self.jsonrpc = jsonrpc
        self.id = id
        self.result = result
        self.error = error
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(result, forKey: .result)
        try container.encodeIfPresent(error, forKey: .error)
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case result
        case error
    }
}

// MARK: - MCPResponse Factory Methods

public extension MCPResponse {
    /// Creates a successful response with the given result.
    ///
    /// - Parameters:
    ///   - id: The identifier matching the corresponding request.
    ///   - result: The result value to include in the response.
    /// - Returns: An MCPResponse with the result set and error as `nil`.
    ///
    /// - Note: This method cannot fail as it guarantees valid inputs.
    static func success(id: String, result: SendableValue) -> MCPResponse {
        // Safe: we guarantee exactly one of result/error is set
        do {
            return try MCPResponse(id: id, result: result, error: nil)
        } catch {
            // This should never happen given our invariants, but handle gracefully
            fatalError("MCPResponse.success: unexpected validation failure - \(error)")
        }
    }

    /// Creates an error response with the given error object.
    ///
    /// - Parameters:
    ///   - id: The identifier matching the corresponding request.
    ///   - error: The error object describing what went wrong.
    /// - Returns: An MCPResponse with the error set and result as `nil`.
    ///
    /// - Note: This method cannot fail as it guarantees valid inputs.
    static func failure(id: String, error: MCPErrorObject) -> MCPResponse {
        // Safe: we guarantee exactly one of result/error is set
        do {
            return try MCPResponse(id: id, result: nil, error: error)
        } catch {
            // This should never happen given our invariants, but handle gracefully
            fatalError("MCPResponse.failure: unexpected validation failure - \(error)")
        }
    }
}

// MARK: - MCPErrorObject

/// A JSON-RPC 2.0 error object for MCP responses.
///
/// This struct represents the error object within a JSON-RPC 2.0 response.
/// It contains a numeric error code, a human-readable message, and optional
/// additional data about the error.
///
/// ## Standard Error Codes
/// The following error codes are defined by JSON-RPC 2.0:
/// - `-32700`: Parse error - Invalid JSON was received
/// - `-32600`: Invalid Request - The JSON sent is not a valid Request object
/// - `-32601`: Method not found - The method does not exist or is not available
/// - `-32602`: Invalid params - Invalid method parameter(s)
/// - `-32603`: Internal error - Internal JSON-RPC error
///
/// Server-defined errors should use codes in the range -32000 to -32099.
/// Application-defined errors should use codes outside the reserved ranges.
///
/// ## Example Usage
/// ```swift
/// // Create an error object
/// let error = MCPErrorObject(
///     code: MCPError.methodNotFoundCode,
///     message: "Method 'unknown' not found"
/// )
///
/// // Create from MCPError
/// let mcpError = MCPError.invalidParams("Missing required parameter 'name'")
/// let errorObject = MCPErrorObject.from(mcpError)
/// ```
public struct MCPErrorObject: Sendable, Codable, Equatable {
    /// The error code as defined by JSON-RPC 2.0.
    ///
    /// Standard codes are in the range -32700 to -32600.
    /// Server-defined codes are in the range -32000 to -32099.
    /// Application-defined codes should be outside these ranges.
    public let code: Int

    /// A short description of the error.
    ///
    /// This should be a concise, human-readable message describing
    /// the error condition.
    public let message: String

    /// Optional structured data containing additional information about the error.
    ///
    /// This can contain any JSON-serializable data that provides
    /// additional context about the error, such as stack traces,
    /// validation details, or retry information.
    public let data: SendableValue?

    // MARK: - Initialization

    /// Creates a new error object with the specified code, message, and optional data.
    ///
    /// - Parameters:
    ///   - code: The error code as defined by JSON-RPC 2.0.
    ///   - message: A short description of the error.
    ///   - data: Optional structured data containing additional information.
    public init(code: Int, message: String, data: SendableValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    // MARK: - Factory Methods

    /// Creates an MCPErrorObject from an MCPError.
    ///
    /// This factory method converts the framework's `MCPError` type into
    /// the JSON-RPC 2.0 error object format suitable for responses.
    ///
    /// - Parameter error: The MCPError to convert.
    /// - Returns: An MCPErrorObject with the same code, message, and data.
    public static func from(_ error: MCPError) -> MCPErrorObject {
        MCPErrorObject(
            code: error.code,
            message: error.message,
            data: error.data
        )
    }
}

// MARK: MCPErrorObject.CodingKeys

extension MCPErrorObject {
    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case data
    }
}

// MARK: CustomDebugStringConvertible

extension MCPErrorObject: CustomDebugStringConvertible {
    public var debugDescription: String {
        if let data {
            "MCPErrorObject(code: \(code), message: \"\(message)\", data: \(data.debugDescription))"
        } else {
            "MCPErrorObject(code: \(code), message: \"\(message)\")"
        }
    }
}
