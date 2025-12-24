//
//  AnyTool.swift
//  SwiftAgents
//
//  Created as part of audit remediation - Phase 4
//

import Foundation

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
    private let box: any AnyToolBox

    public init<T: Tool>(_ tool: T) {
        self.box = ToolBox(tool)
    }

    public var name: String { box._name }
    public var description: String { box._description }
    public var parameters: [ToolParameter] { box._parameters }

    public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        try await box._execute(arguments: arguments)
    }
}

private protocol AnyToolBox: Sendable {
    var _name: String { get }
    var _description: String { get }
    var _parameters: [ToolParameter] { get }
    func _execute(arguments: [String: SendableValue]) async throws -> SendableValue
}

private struct ToolBox<T: Tool>: AnyToolBox, Sendable {
    private let tool: T

    init(_ tool: T) { self.tool = tool }

    var _name: String { tool.name }
    var _description: String { tool.description }
    var _parameters: [ToolParameter] { tool.parameters }

    func _execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        try await tool.execute(arguments: arguments)
    }
}
