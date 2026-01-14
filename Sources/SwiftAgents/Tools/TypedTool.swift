// TypedTool.swift
// SwiftAgents Framework
//
// Generic tool protocol with type-safe outputs.

import Foundation

// MARK: - TypedTool

/// A tool with a strongly-typed output.
///
/// `TypedTool` extends the base `Tool` protocol with an associated `Output` type,
/// enabling compile-time type safety for tool results. Tools implementing this
/// protocol return concrete types instead of `SendableValue`.
///
/// Example:
/// ```swift
/// struct WeatherTool: TypedTool {
///     typealias Output = WeatherData
///
///     let name = "weather"
///     let description = "Gets weather for a location"
///     let parameters: [ToolParameter] = [
///         ToolParameter(name: "location", description: "City name", type: .string)
///     ]
///
///     mutating func executeTyped(arguments: [String: SendableValue]) async throws -> WeatherData {
///         guard let location = arguments["location"]?.stringValue else {
///             throw AgentError.invalidToolArguments(toolName: name, reason: "Missing location")
///         }
///         return WeatherData(temperature: 72.0, condition: "Sunny", location: location)
///     }
/// }
/// ```
public protocol TypedTool<Output>: Tool {
    /// The strongly-typed output of this tool.
    associatedtype Output: Sendable & Encodable

    /// Executes the tool and returns a strongly-typed result.
    ///
    /// - Parameter arguments: The arguments passed to the tool.
    /// - Returns: The typed result of the tool execution.
    /// - Throws: `AgentError.toolExecutionFailed` or `AgentError.invalidToolArguments` on failure.
    mutating func executeTyped(arguments: [String: SendableValue]) async throws -> Output
}

// MARK: - TypedTool Default Implementation

public extension TypedTool {
    /// Default implementation that bridges `executeTyped` to `execute`.
    ///
    /// This allows `TypedTool` to be used anywhere a `Tool` is expected,
    /// automatically converting the typed output to `SendableValue`.
    mutating func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        let result = try await executeTyped(arguments: arguments)
        return try SendableValue(encoding: result)
    }
}

// MARK: - TypedTool Registry Extensions

public extension ToolRegistry {
    /// Executes a typed tool and returns its strongly-typed output.
    ///
    /// - Parameters:
    ///   - name: The name of the tool to execute.
    ///   - arguments: The arguments to pass to the tool.
    /// - Returns: The typed result of the tool execution.
    /// - Throws: `AgentError.toolNotFound` if the tool doesn't exist,
    ///           or `AgentError.toolExecutionFailed` if execution fails.
    func executeTyped<T: TypedTool>(
        _: T.Type,
        toolNamed name: String,
        arguments: [String: SendableValue]
    ) async throws -> T.Output {
        guard var tool = tool(named: name) as? T else {
            throw AgentError.toolNotFound(name: name)
        }
        return try await tool.executeTyped(arguments: arguments)
    }
}