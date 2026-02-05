// TypedToolProtocol.swift
// Swarm Framework
//
// Primary developer-facing typed tool API.

import Foundation

// MARK: - Tool (Typed)

/// A strongly-typed tool with Codable input and Encodable output.
///
/// `Tool` is the primary developer-facing tool API in Swarm.
/// At the model boundary, tools are invoked with JSON-like values; typed tools
/// are bridged to that boundary via adapters.
public protocol Tool: Sendable {
    associatedtype Input: Codable & Sendable
    associatedtype Output: Encodable & Sendable

    /// The unique name of the tool.
    var name: String { get }

    /// A description of what the tool does (used in prompts to help the model understand).
    var description: String { get }

    /// The parameters this tool accepts (provider-facing schema).
    var parameters: [ToolParameter] { get }

    /// Input guardrails for this tool.
    var inputGuardrails: [any ToolInputGuardrail] { get }

    /// Output guardrails for this tool.
    var outputGuardrails: [any ToolOutputGuardrail] { get }

    /// Executes the tool with a strongly-typed input.
    func execute(_ input: Input) async throws -> Output
}

public extension Tool {
    var inputGuardrails: [any ToolInputGuardrail] { [] }
    var outputGuardrails: [any ToolOutputGuardrail] { [] }

    var schema: ToolSchema {
        ToolSchema(name: name, description: description, parameters: parameters)
    }
}
