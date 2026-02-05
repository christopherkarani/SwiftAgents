// ToolSchema.swift
// Swarm Framework
//
// Schema/value types used for provider tool calling and typed tool bridging.

import Foundation

/// JSON-like value used at the tool-calling boundary.
///
/// Swarm uses `SendableValue` as its canonical JSON value representation.
public typealias JSONValue = SendableValue

/// Describes a tool interface in a provider-friendly, schema-first format.
///
/// This is the public-facing schema type used across providers and agents.
public struct ToolSchema: Sendable, Equatable {
    public let name: String
    public let description: String
    public let parameters: [ToolParameter]

    public init(name: String, description: String, parameters: [ToolParameter]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}
