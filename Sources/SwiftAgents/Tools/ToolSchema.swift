// ToolSchema.swift
// SwiftAgents Framework
//
// Schema/value types used for provider tool calling and typed tool bridging.

import Foundation

/// JSON-like value used at the tool-calling boundary.
///
/// SwiftAgents uses `SendableValue` as its canonical JSON value representation.
public typealias JSONValue = SendableValue

/// Describes a tool interface in a provider-friendly, schema-first format.
///
/// Today this mirrors `ToolDefinition` (name/description/parameters), but it exists
/// as a stable abstraction so we can later enrich it with full JSON Schema,
/// examples, constraints, and redaction metadata (e.g. via macros).
public struct ToolSchema: Sendable, Equatable {
    public let name: String
    public let description: String
    public let parameters: [ToolParameter]

    public init(name: String, description: String, parameters: [ToolParameter]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    public init(from definition: ToolDefinition) {
        self.name = definition.name
        self.description = definition.description
        self.parameters = definition.parameters
    }

    public var definition: ToolDefinition {
        ToolDefinition(name: name, description: description, parameters: parameters)
    }
}

