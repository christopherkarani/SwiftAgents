// AnyTool.swift
// SwiftAgents Framework
//
// Type-erased wrapper for heterogeneous tool collections.
//

import Foundation

// MARK: - AnyTool

/// Type-erased wrapper for any Tool
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
public struct AnyTool: Tool, Sendable {
    // MARK: Public

    public var name: String { box.wrappedName }
    public var description: String { box.wrappedDescription }
    public var parameters: [ToolParameter] { box.wrappedParameters }

    public init(_ tool: some Tool) {
        box = ToolBox(tool)
    }

    public mutating func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
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

    mutating func executeWrapped(arguments: [String: SendableValue]) async throws -> SendableValue
}

// MARK: - ToolBox

private struct ToolBox<T: Tool>: AnyToolBox, Sendable {
    // MARK: Internal

    var wrappedName: String { tool.name }
    var wrappedDescription: String { tool.description }
    var wrappedParameters: [ToolParameter] { tool.parameters }

    init(_ tool: T) { self.tool = tool }

    mutating func executeWrapped(arguments: [String: SendableValue]) async throws -> SendableValue {
        try await tool.execute(arguments: arguments)
    }

    // MARK: Private

    private var tool: T
}