// Tool.swift
// SwiftAgents Framework
//
// Tool protocol and supporting types for agent tool execution.

import Foundation

// MARK: - Tool

/// A tool that can be used by an agent to perform actions.
///
/// Tools encapsulate functionality that agents can invoke during execution.
/// Each tool has a name, description, parameters, and an execute method.
///
/// Example:
/// ```swift
/// struct WeatherTool: Tool {
///     let name = "weather"
///     let description = "Gets the current weather for a location"
///     let parameters: [ToolParameter] = [
///         ToolParameter(name: "location", description: "City name", type: .string)
///     ]
///
///     func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
///         guard let location = arguments["location"]?.stringValue else {
///             throw AgentError.invalidToolArguments(toolName: name, reason: "Missing location")
///         }
///         return .string("72°F and sunny in \(location)")
///     }
/// }
/// ```
public protocol Tool: Sendable {
    /// The unique name of the tool.
    var name: String { get }

    /// A description of what the tool does (used in prompts to help the model understand).
    var description: String { get }

    /// The parameters this tool accepts.
    var parameters: [ToolParameter] { get }

    /// Input guardrails for this tool.
    var inputGuardrails: [any ToolInputGuardrail] { get }

    /// Output guardrails for this tool.
    var outputGuardrails: [any ToolOutputGuardrail] { get }

    /// Executes the tool with the given arguments.
    /// - Parameter arguments: The arguments passed to the tool.
    /// - Returns: The result of the tool execution.
    /// - Throws: `AgentError.toolExecutionFailed` or `AgentError.invalidToolArguments` on failure.
    mutating func execute(arguments: [String: SendableValue]) async throws -> SendableValue
}

// MARK: - Tool Protocol Extensions

public extension Tool {
    /// Creates a ToolDefinition from this tool.
    var definition: ToolDefinition {
        ToolDefinition(from: self)
    }

    /// Default input guardrails (none).
    var inputGuardrails: [any ToolInputGuardrail] { [] }

    /// Default output guardrails (none).
    var outputGuardrails: [any ToolOutputGuardrail] { [] }

    /// Validates that the given arguments match this tool's parameters.
    /// - Parameter arguments: The arguments to validate.
    /// - Throws: `AgentError.invalidToolArguments` if validation fails.
    func validateArguments(_ arguments: [String: SendableValue]) throws {
        for param in parameters where param.isRequired {
            guard arguments[param.name] != nil else {
                throw AgentError.invalidToolArguments(
                    toolName: name,
                    reason: "Missing required parameter: \(param.name)"
                )
            }
        }
    }

    /// Gets a required string argument or throws.
    /// - Parameters:
    ///   - key: The argument key.
    ///   - arguments: The arguments dictionary.
    /// - Returns: The string value.
    /// - Throws: `AgentError.invalidToolArguments` if missing or wrong type.
    func requiredString(_ key: String, from arguments: [String: SendableValue]) throws -> String {
        guard let value = arguments[key]?.stringValue else {
            throw AgentError.invalidToolArguments(
                toolName: name,
                reason: "Missing or invalid string parameter: \(key)"
            )
        }
        return value
    }

    /// Gets an optional string argument.
    /// - Parameters:
    ///   - key: The argument key.
    ///   - arguments: The arguments dictionary.
    ///   - defaultValue: The default value if not present.
    /// - Returns: The string value or default.
    func optionalString(_ key: String, from arguments: [String: SendableValue], default defaultValue: String? = nil) -> String? {
        arguments[key]?.stringValue ?? defaultValue
    }
}

// MARK: - ToolParameter

/// Describes a parameter that a tool accepts.
public struct ToolParameter: Sendable, Equatable {
    /// The type of a tool parameter.
    indirect public enum ParameterType: Sendable, Equatable, CustomStringConvertible {
        // MARK: Public

        public var description: String {
            switch self {
            case .string: "string"
            case .int: "integer"
            case .double: "number"
            case .bool: "boolean"
            case let .array(elementType): "array<\(elementType)>"
            case .object: "object"
            case let .oneOf(options): "oneOf(\(options.joined(separator: "|")))"
            case .any: "any"
            }
        }

        case string
        case int
        case double
        case bool
        case array(elementType: ParameterType)
        case object(properties: [ToolParameter])
        case oneOf([String])
        case any
    }

    /// The name of the parameter.
    public let name: String

    /// A description of the parameter.
    public let description: String

    /// The type of the parameter.
    public let type: ParameterType

    /// Whether this parameter is required.
    public let isRequired: Bool

    /// The default value for this parameter, if any.
    public let defaultValue: SendableValue?

    /// Creates a new tool parameter.
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - description: A description of the parameter.
    ///   - type: The parameter type.
    ///   - isRequired: Whether the parameter is required. Default: true
    ///   - defaultValue: The default value. Default: nil
    public init(
        name: String,
        description: String,
        type: ParameterType,
        isRequired: Bool = true,
        defaultValue: SendableValue? = nil
    ) {
        self.name = name
        self.description = description
        self.type = type
        self.isRequired = isRequired
        self.defaultValue = defaultValue
    }
}

// MARK: - ToolDefinition

/// A definition of a tool that can be included in model prompts.
///
/// This is a serializable representation of a tool's interface without
/// the actual execution logic.
public struct ToolDefinition: Sendable, Equatable {
    /// The name of the tool.
    public let name: String

    /// A description of what the tool does.
    public let description: String

    /// The parameters this tool accepts.
    public let parameters: [ToolParameter]

    /// Creates a new tool definition.
    /// - Parameters:
    ///   - name: The tool name.
    ///   - description: The tool description.
    ///   - parameters: The tool parameters.
    public init(name: String, description: String, parameters: [ToolParameter]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    /// Creates a ToolDefinition from a Tool.
    /// - Parameter tool: The tool to create a definition from.
    public init(from tool: any Tool) {
        name = tool.name
        description = tool.description
        parameters = tool.parameters
    }
}

// MARK: - ToolRegistry

/// A registry for managing available tools.
///
/// ToolRegistry provides thread-safe tool registration and lookup.
/// Use it to manage the set of tools available to an agent.
///
/// Example:
/// ```swift
/// // Note: CalculatorTool is only available on Apple platforms
/// let registry = ToolRegistry(tools: [DateTimeTool(), StringTool()])
/// let result = try await registry.execute(toolNamed: "datetime", arguments: ["format": "iso8601"])
/// ```
public actor ToolRegistry {
    // MARK: Public

    /// Gets all registered tools.
    public var allTools: [any Tool] {
        Array(tools.values)
    }

    /// Gets all tool names.
    public var toolNames: [String] {
        Array(tools.keys)
    }

    /// Gets all tool definitions.
    public var definitions: [ToolDefinition] {
        tools.values.map { ToolDefinition(from: $0) }
    }

    /// The number of registered tools.
    public var count: Int {
        tools.count
    }

    /// Creates an empty tool registry.
    public init() {}

    /// Creates a tool registry with the given tools.
    /// - Parameter tools: The initial tools to register.
    public init(tools: [any Tool]) {
        for tool in tools {
            self.tools[tool.name] = tool
        }
    }

    /// Registers a tool.
    /// - Parameter tool: The tool to register.
    public func register(_ tool: any Tool) {
        tools[tool.name] = tool
    }

    /// Registers multiple tools.
    /// - Parameter newTools: The tools to register.
    public func register(_ newTools: [any Tool]) {
        for tool in newTools {
            tools[tool.name] = tool
        }
    }

    /// Unregisters a tool by name.
    /// - Parameter name: The name of the tool to unregister.
    public func unregister(named name: String) {
        tools.removeValue(forKey: name)
    }

    /// Gets a tool by name.
    /// - Parameter name: The tool name.
    /// - Returns: The tool, or nil if not found.
    public func tool(named name: String) -> (any Tool)? {
        tools[name]
    }

    /// Returns true if a tool with the given name is registered.
    /// - Parameter name: The tool name.
    /// - Returns: True if the tool exists.
    public func contains(named name: String) -> Bool {
        tools[name] != nil
    }

    /// Executes a tool by name with the given arguments.
    /// - Parameters:
    ///   - name: The name of the tool to execute.
    ///   - arguments: The arguments to pass to the tool.
    ///   - agent: Optional agent executing the tool (for guardrail validation).
    ///   - context: Optional agent context for guardrail validation.
    /// - Returns: The result of the tool execution.
    /// - Throws: `AgentError.toolNotFound` if the tool doesn't exist,
    ///           `AgentError.toolExecutionFailed` if execution fails,
    ///           `GuardrailError` if guardrails are triggered,
    ///           or `CancellationError` if the task is cancelled.
    public func execute(
        toolNamed name: String,
        arguments: [String: SendableValue],
        agent: (any Agent)? = nil,
        context: AgentContext? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> SendableValue {
        // Check for cancellation before proceeding
        try Task.checkCancellation()

        guard var tool = tools[name] else {
            throw AgentError.toolNotFound(name: name)
        }

        // Create a single GuardrailRunner instance for both input and output guardrails
        let runner = GuardrailRunner()
        let data = ToolGuardrailData(tool: tool, arguments: arguments, agent: agent, context: context)

        do {
            // Run input guardrails
            if !tool.inputGuardrails.isEmpty {
                _ = try await runner.runToolInputGuardrails(tool.inputGuardrails, data: data)
            }

            let result = try await tool.execute(arguments: arguments)

            // Run output guardrails
            if !tool.outputGuardrails.isEmpty {
                _ = try await runner.runToolOutputGuardrails(tool.outputGuardrails, data: data, output: result)
            }

            return result
        } catch {
            // Notify hooks for any error (guardrail, execution, or otherwise)
            if let agent, let hooks {
                let notificationError = (error as? AgentError) ?? AgentError.toolExecutionFailed(
                    toolName: name,
                    underlyingError: error.localizedDescription
                )
                await hooks.onError(context: context, agent: agent, error: notificationError)
            }

            // Re-throw original error or wrap it
            if let agentError = error as? AgentError {
                throw agentError
            } else {
                throw AgentError.toolExecutionFailed(
                    toolName: name,
                    underlyingError: error.localizedDescription
                )
            }
        }
    }

    // MARK: Private

    private var tools: [String: any Tool] = [:]
}
