// MCPResource.swift
// Swarm Framework
//
// Model Context Protocol resource types for representing server resources.

import Foundation

// MARK: - MCPResource

/// Represents a resource available from an MCP server.
///
/// Resources are identified by URIs and can represent any type of data
/// that an MCP server exposes, such as files, database records, or API endpoints.
///
/// Example:
/// ```swift
/// let resource = MCPResource(
///     uri: "file:///path/to/document.txt",
///     name: "document.txt",
///     description: "A text document",
///     mimeType: "text/plain"
/// )
/// ```
public struct MCPResource: Sendable, Codable, Equatable {
    /// The unique URI identifying this resource.
    ///
    /// URIs follow standard URI format and uniquely identify the resource
    /// within the MCP server's namespace.
    public let uri: String

    /// The human-readable name of the resource.
    ///
    /// This name is intended for display purposes and should be
    /// meaningful to users.
    public let name: String

    /// An optional description of the resource.
    ///
    /// Provides additional context about the resource's purpose or contents.
    public let description: String?

    /// The optional MIME type of the resource content.
    ///
    /// When present, indicates the format of the resource's content
    /// (e.g., "text/plain", "application/json", "image/png").
    public let mimeType: String?

    /// Creates a new MCP resource.
    ///
    /// - Parameters:
    ///   - uri: The unique URI identifying this resource.
    ///   - name: The human-readable name of the resource.
    ///   - description: An optional description of the resource. Default: nil
    ///   - mimeType: The optional MIME type of the resource content. Default: nil
    public init(
        uri: String,
        name: String,
        description: String? = nil,
        mimeType: String? = nil
    ) {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
    }
}

// MARK: - MCPResourceContent

/// Represents the content of an MCP resource.
///
/// Resource content can be either text or binary (Base64-encoded).
/// The `isText` and `isBinary` computed properties help determine
/// which type of content is present.
///
/// Example:
/// ```swift
/// // Text content
/// let textContent = MCPResourceContent(
///     uri: "file:///path/to/document.txt",
///     mimeType: "text/plain",
///     text: "Hello, World!"
/// )
///
/// // Binary content
/// let binaryContent = MCPResourceContent(
///     uri: "file:///path/to/image.png",
///     mimeType: "image/png",
///     blob: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk..."
/// )
/// ```
public struct MCPResourceContent: Sendable, Codable, Equatable {
    /// The URI of the resource this content belongs to.
    public let uri: String

    /// The optional MIME type of the content.
    ///
    /// Indicates the format of the content (e.g., "text/plain", "application/json").
    public let mimeType: String?

    /// The text content of the resource, if available.
    ///
    /// Mutually exclusive with `blob` - typically only one should be set.
    public let text: String?

    /// The Base64-encoded binary content of the resource, if available.
    ///
    /// Used for binary data such as images or other non-text content.
    /// Mutually exclusive with `text` - typically only one should be set.
    public let blob: String?

    /// Returns `true` if this content contains text data.
    ///
    /// Use this property to determine whether to access the `text` property.
    public var isText: Bool {
        text != nil
    }

    /// Returns `true` if this content contains binary (Base64-encoded) data.
    ///
    /// Use this property to determine whether to access the `blob` property.
    public var isBinary: Bool {
        blob != nil
    }

    /// Creates new MCP resource content.
    ///
    /// - Parameters:
    ///   - uri: The URI of the resource this content belongs to.
    ///   - mimeType: The optional MIME type of the content. Default: nil
    ///   - text: The text content, if available. Default: nil
    ///   - blob: The Base64-encoded binary content, if available. Default: nil
    public init(
        uri: String,
        mimeType: String? = nil,
        text: String? = nil,
        blob: String? = nil
    ) {
        self.uri = uri
        self.mimeType = mimeType
        self.text = text
        self.blob = blob
    }
}

// MARK: - MCPResource + CustomDebugStringConvertible

extension MCPResource: CustomDebugStringConvertible {
    public var debugDescription: String {
        var desc = "MCPResource(uri: \"\(uri)\", name: \"\(name)\""
        if let mimeType {
            desc += ", mimeType: \"\(mimeType)\""
        }
        desc += ")"
        return desc
    }
}

// MARK: - MCPResourceContent + CustomDebugStringConvertible

extension MCPResourceContent: CustomDebugStringConvertible {
    public var debugDescription: String {
        var desc = "MCPResourceContent(uri: \"\(uri)\""
        if let mimeType {
            desc += ", mimeType: \"\(mimeType)\""
        }
        if isText {
            let preview = text!.prefix(50)
            desc += ", text: \"\(preview)\(text!.count > 50 ? "..." : "")\""
        } else if isBinary {
            desc += ", blob: <\(blob!.count) chars>"
        }
        desc += ")"
        return desc
    }
}
