// MCPCapabilities.swift
// SwiftAgents Framework
//
// MCP server capability declarations.

import Foundation

// MARK: - MCPCapabilities

/// Capabilities supported by an MCP server.
///
/// MCPCapabilities describes what features an MCP server supports,
/// enabling clients to understand available functionality and
/// configure their behavior accordingly.
///
/// Example:
/// ```swift
/// let capabilities = MCPCapabilities(
///     tools: true,
///     resources: true,
///     prompts: false,
///     sampling: false
/// )
///
/// if capabilities.tools {
///     // Server supports tool discovery and execution
/// }
/// ```
public struct MCPCapabilities: Sendable, Codable, Equatable {
    /// Empty capabilities with all features disabled.
    ///
    /// Use this as a baseline or when no capabilities are available.
    public static let empty = MCPCapabilities()

    /// Whether the server supports tool discovery and execution.
    ///
    /// When `true`, the server can list available tools and execute
    /// tool calls requested by the client.
    public let tools: Bool

    /// Whether the server supports resource access.
    ///
    /// When `true`, the server can provide access to resources
    /// such as files, databases, or external data sources.
    public let resources: Bool

    /// Whether the server supports prompt templates.
    ///
    /// When `true`, the server can provide and manage
    /// reusable prompt templates.
    public let prompts: Bool

    /// Whether the server supports sampling.
    ///
    /// When `true`, the server can perform sampling operations
    /// for model generation.
    public let sampling: Bool

    // MARK: - Initialization

    /// Creates MCP capabilities with the specified features.
    ///
    /// - Parameters:
    ///   - tools: Whether tool discovery and execution is supported. Default: `false`
    ///   - resources: Whether resource access is supported. Default: `false`
    ///   - prompts: Whether prompt templates are supported. Default: `false`
    ///   - sampling: Whether sampling is supported. Default: `false`
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

// MARK: CustomStringConvertible

extension MCPCapabilities: CustomStringConvertible {
    public var description: String {
        """
        MCPCapabilities(
            tools: \(tools),
            resources: \(resources),
            prompts: \(prompts),
            sampling: \(sampling)
        )
        """
    }
}
