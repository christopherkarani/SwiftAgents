// FunctionTool.swift
// Swarm Framework

import Foundation

// MARK: - ToolArguments

/// A convenience wrapper for tool argument extraction.
public struct ToolArguments: Sendable {
    public let raw: [String: SendableValue]
    public let toolName: String

    public init(_ arguments: [String: SendableValue], toolName: String = "tool") {
        raw = arguments
        self.toolName = toolName
    }

    /// Gets a required argument of the specified type.
    public func require<T>(_ key: String, as type: T.Type = T.self) throws -> T {
        guard let value = raw[key] else {
            throw AgentError.invalidToolArguments(
                toolName: toolName,
                reason: "Missing required argument: \(key)"
            )
        }

        let extracted: Any? = switch value {
        case let .string(s) where type == String.self: s
        case let .int(i) where type == Int.self: i
        case let .double(d) where type == Double.self: d
        case let .bool(b) where type == Bool.self: b
        default: nil
        }

        guard let result = extracted as? T else {
            throw AgentError.invalidToolArguments(
                toolName: toolName,
                reason: "Argument '\(key)' is not of type \(T.self)"
            )
        }
        return result
    }

    /// Gets an optional argument of the specified type.
    public func optional<T>(_ key: String, as type: T.Type = T.self) -> T? {
        guard let value = raw[key] else { return nil }
        return switch value {
        case let .string(s) where type == String.self: s as? T
        case let .int(i) where type == Int.self: i as? T
        case let .double(d) where type == Double.self: d as? T
        case let .bool(b) where type == Bool.self: b as? T
        default: nil
        }
    }

    /// Gets a string argument or returns the default.
    public func string(_ key: String, default defaultValue: String = "") -> String {
        raw[key]?.stringValue ?? defaultValue
    }

    /// Gets an int argument or returns the default.
    public func int(_ key: String, default defaultValue: Int = 0) -> Int {
        raw[key]?.intValue ?? defaultValue
    }
}

// MARK: - FunctionTool

/// A closure-based tool for inline tool creation without dedicated structs.
///
/// `FunctionTool` enables quick tool definition using closures, ideal for
/// simple one-off tools that don't warrant a dedicated type.
///
/// Example:
/// ```swift
/// let getWeather = FunctionTool(
///     name: "get_weather",
///     description: "Gets weather for a city"
/// ) { args in
///     let city = try args.require("city", as: String.self)
///     return .string("72°F in \(city)")
/// }
///
/// // With explicit parameters:
/// let search = FunctionTool(
///     name: "search",
///     description: "Search the web",
///     parameters: [
///         ToolParameter(name: "query", description: "Search query", type: .string, isRequired: true)
///     ]
/// ) { args in
///     let query = try args.require("query", as: String.self)
///     return .string("Results for \(query)")
/// }
/// ```
public struct FunctionTool: AnyJSONTool, Sendable {
    // MARK: Public

    public let name: String
    public let description: String
    public let parameters: [ToolParameter]

    /// Creates a function tool with a closure handler.
    /// - Parameters:
    ///   - name: The unique name of the tool.
    ///   - description: A description of what the tool does.
    ///   - parameters: The parameters this tool accepts. Default: []
    ///   - handler: The closure that executes the tool logic.
    public init(
        name: String,
        description: String,
        parameters: [ToolParameter] = [],
        handler: @escaping @Sendable (ToolArguments) async throws -> SendableValue
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.handler = handler
    }

    public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        try await handler(ToolArguments(arguments, toolName: name))
    }

    // MARK: Private

    private let handler: @Sendable (ToolArguments) async throws -> SendableValue
}
