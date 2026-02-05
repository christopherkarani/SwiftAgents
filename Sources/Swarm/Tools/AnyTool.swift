// AnyTool.swift
// Swarm Framework
//
// Type-erased wrapper for heterogeneous tool collections.
//

import Foundation

// MARK: - AnyTool

/// Type-erased wrapper for any `AnyJSONTool`
///
/// Enables storing heterogeneous tools in collections without
/// losing type information at runtime:
/// ```swift
/// let tools: [AnyTool] = [
///     AnyTool(calculatorTool),
///     AnyTool(weatherTool),
///     AnyTool(searchTool)
/// ]
///
/// for tool in tools {
///     print("Tool: \(tool.name) - \(tool.description)")
/// }
/// ```
public struct AnyTool: AnyJSONTool, Sendable {
    // MARK: Public

    public var name: String { box.wrappedName }
    public var description: String { box.wrappedDescription }
    public var parameters: [ToolParameter] { box.wrappedParameters }
    public var inputGuardrails: [any ToolInputGuardrail] { box.wrappedInputGuardrails }
    public var outputGuardrails: [any ToolOutputGuardrail] { box.wrappedOutputGuardrails }

    public init(_ tool: some AnyJSONTool) {
        box = ToolBox(tool)
    }

    public init(_ tool: some Tool) {
        box = ToolBox(AnyJSONToolAdapter(tool))
    }

    public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        try await box.executeWrapped(arguments: arguments)
    }

    // MARK: Private

    private var box: any AnyToolBox
}

// MARK: - AnyToolBox

private protocol AnyToolBox: Sendable {
    var wrappedName: String { get }
    var wrappedDescription: String { get }
    var wrappedParameters: [ToolParameter] { get }
    var wrappedInputGuardrails: [any ToolInputGuardrail] { get }
    var wrappedOutputGuardrails: [any ToolOutputGuardrail] { get }

    func executeWrapped(arguments: [String: SendableValue]) async throws -> SendableValue
}

// MARK: - ToolBox

private struct ToolBox<T: AnyJSONTool>: AnyToolBox, Sendable {
    // MARK: Internal

    var wrappedName: String { tool.name }
    var wrappedDescription: String { tool.description }
    var wrappedParameters: [ToolParameter] { tool.parameters }
    var wrappedInputGuardrails: [any ToolInputGuardrail] { tool.inputGuardrails }
    var wrappedOutputGuardrails: [any ToolOutputGuardrail] { tool.outputGuardrails }

    init(_ tool: T) { self.tool = tool }

    func executeWrapped(arguments: [String: SendableValue]) async throws -> SendableValue {
        try await tool.execute(arguments: arguments)
    }

    // MARK: Private

    private var tool: T
}
