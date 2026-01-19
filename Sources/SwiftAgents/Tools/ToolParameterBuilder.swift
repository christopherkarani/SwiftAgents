// ToolParameterBuilder.swift
// SwiftAgents Framework
//
// Result builder DSL for constructing tool parameters declaratively.

import Foundation

// MARK: - ToolParameterBuilder

/// A result builder for constructing tool parameter arrays with DSL syntax.
///
/// `ToolParameterBuilder` enables a declarative syntax for defining tool parameters,
/// similar to SwiftUI's view builders. It supports conditionals, loops, and optional
/// parameters.
///
/// Example:
/// ```swift
/// struct WeatherTool: Tool {
///     let name = "weather"
///     let description = "Gets weather for a location"
///
///     @ToolParameterBuilder
///     var parameters: [ToolParameter] {
///         Parameter("location", description: "City name", type: .string)
///         Parameter("units", description: "Temperature units", type: .oneOf(["C", "F"]), required: false)
///         if includeTimezone {
///             Parameter("timezone", description: "Timezone offset", type: .int)
///         }
///     }
///
///     func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
///         // Implementation
///     }
/// }
/// ```
@resultBuilder
public struct ToolParameterBuilder {
    /// Builds a parameter array from multiple parameters.
    public static func buildBlock(_ components: ToolParameter...) -> [ToolParameter] {
        components
    }

    /// Builds an empty parameter array for empty builder bodies.
    public static func buildBlock() -> [ToolParameter] {
        []
    }

    /// Builds a parameter array from an array of parameters.
    public static func buildBlock(_ components: [ToolParameter]...) -> [ToolParameter] {
        components.flatMap(\.self)
    }

    /// Builds a parameter array from an optional parameter.
    public static func buildOptional(_ component: [ToolParameter]?) -> [ToolParameter] {
        component ?? []
    }

    /// Builds a parameter array from the first branch of an if-else.
    public static func buildEither(first component: [ToolParameter]) -> [ToolParameter] {
        component
    }

    /// Builds a parameter array from the second branch of an if-else.
    public static func buildEither(second component: [ToolParameter]) -> [ToolParameter] {
        component
    }

    /// Builds a parameter array from a for-in loop.
    public static func buildArray(_ components: [[ToolParameter]]) -> [ToolParameter] {
        components.flatMap(\.self)
    }

    /// Converts a single parameter to an array.
    public static func buildExpression(_ expression: ToolParameter) -> [ToolParameter] {
        [expression]
    }

    /// Passes through an array of parameters.
    public static func buildExpression(_ expression: [ToolParameter]) -> [ToolParameter] {
        expression
    }

    /// Builds from a limited availability check.
    public static func buildLimitedAvailability(_ component: [ToolParameter]) -> [ToolParameter] {
        component
    }

    /// Builds the final result.
    public static func buildFinalResult(_ component: [ToolParameter]) -> [ToolParameter] {
        component
    }
}

// MARK: - Parameter Factory Functions

// swiftlint:disable identifier_name

/// Creates a tool parameter with the specified configuration.
///
/// This is a convenience function for use with `ToolParameterBuilder` that provides
/// a cleaner syntax than the full `ToolParameter` initializer.
///
/// - Parameters:
///   - name: The parameter name.
///   - description: A description of the parameter.
///   - type: The parameter type.
///   - required: Whether the parameter is required. Default: `true`
///   - defaultValue: The default value. Default: `nil`
/// - Returns: A configured `ToolParameter`.
///
/// Example:
/// ```swift
/// @ToolParameterBuilder
/// var parameters: [ToolParameter] {
///     Parameter("query", description: "Search query", type: .string)
///     Parameter("limit", description: "Max results", type: .int, required: false, default: 10)
/// }
/// ```
public func Parameter(
    _ name: String,
    description: String,
    type: ToolParameter.ParameterType,
    required: Bool = true,
    default defaultValue: SendableValue? = nil
) -> ToolParameter {
    ToolParameter(
        name: name,
        description: description,
        type: type,
        isRequired: required,
        defaultValue: defaultValue
    )
}

/// Creates a tool parameter with an integer default value.
///
/// - Parameters:
///   - name: The parameter name.
///   - description: A description of the parameter.
///   - type: The parameter type.
///   - required: Whether the parameter is required. Default: `true`
///   - defaultValue: The default integer value.
/// - Returns: A configured `ToolParameter`.
public func Parameter(
    _ name: String,
    description: String,
    type: ToolParameter.ParameterType,
    required: Bool = true,
    default defaultValue: Int
) -> ToolParameter {
    ToolParameter(
        name: name,
        description: description,
        type: type,
        isRequired: required,
        defaultValue: .int(defaultValue)
    )
}

/// Creates a tool parameter with a string default value.
///
/// - Parameters:
///   - name: The parameter name.
///   - description: A description of the parameter.
///   - type: The parameter type.
///   - required: Whether the parameter is required. Default: `true`
///   - defaultValue: The default string value.
/// - Returns: A configured `ToolParameter`.
public func Parameter(
    _ name: String,
    description: String,
    type: ToolParameter.ParameterType,
    required: Bool = true,
    default defaultValue: String
) -> ToolParameter {
    ToolParameter(
        name: name,
        description: description,
        type: type,
        isRequired: required,
        defaultValue: .string(defaultValue)
    )
}

/// Creates a tool parameter with a boolean default value.
///
/// - Parameters:
///   - name: The parameter name.
///   - description: A description of the parameter.
///   - type: The parameter type.
///   - required: Whether the parameter is required. Default: `true`
///   - defaultValue: The default boolean value.
/// - Returns: A configured `ToolParameter`.
public func Parameter(
    _ name: String,
    description: String,
    type: ToolParameter.ParameterType,
    required: Bool = true,
    default defaultValue: Bool
) -> ToolParameter {
    ToolParameter(
        name: name,
        description: description,
        type: type,
        isRequired: required,
        defaultValue: .bool(defaultValue)
    )
}

/// Creates a tool parameter with a double default value.
///
/// - Parameters:
///   - name: The parameter name.
///   - description: A description of the parameter.
///   - type: The parameter type.
///   - required: Whether the parameter is required. Default: `true`
///   - defaultValue: The default double value.
/// - Returns: A configured `ToolParameter`.
public func Parameter(
    _ name: String,
    description: String,
    type: ToolParameter.ParameterType,
    required: Bool = true,
    default defaultValue: Double
) -> ToolParameter {
    ToolParameter(
        name: name,
        description: description,
        type: type,
        isRequired: required,
        defaultValue: .double(defaultValue)
    )
}

// swiftlint:enable identifier_name

// MARK: - ToolArrayBuilder

/// A result builder for constructing arrays of tools.
///
/// Used by `AgentBuilder` to allow declarative tool registration.
///
/// Example:
/// ```swift
/// @ToolArrayBuilder
/// func makeTools() -> [any AnyJSONTool] {
///     CalculatorTool()
///     WeatherTool()
///     if includeDebug {
///         DebugTool()
///     }
/// }
/// ```
@resultBuilder
public struct ToolArrayBuilder {
    /// Builds a tool array from multiple tools.
    public static func buildBlock(_ components: (any AnyJSONTool)...) -> [any AnyJSONTool] {
        components
    }

    /// Builds a tool array from arrays of tools.
    public static func buildBlock(_ components: [any AnyJSONTool]...) -> [any AnyJSONTool] {
        components.flatMap(\.self)
    }

    /// Builds a tool array from an optional tool.
    public static func buildOptional(_ component: [any AnyJSONTool]?) -> [any AnyJSONTool] {
        component ?? []
    }

    /// Builds a tool array from the first branch of an if-else.
    public static func buildEither(first component: [any AnyJSONTool]) -> [any AnyJSONTool] {
        component
    }

    /// Builds a tool array from the second branch of an if-else.
    public static func buildEither(second component: [any AnyJSONTool]) -> [any AnyJSONTool] {
        component
    }

    /// Builds a tool array from a for-in loop.
    public static func buildArray(_ components: [[any AnyJSONTool]]) -> [any AnyJSONTool] {
        components.flatMap(\.self)
    }

    /// Converts a single tool to an array.
    public static func buildExpression(_ expression: any AnyJSONTool) -> [any AnyJSONTool] {
        [expression]
    }

    /// Converts a typed tool to a dynamic tool array.
    public static func buildExpression<T: Tool>(_ expression: T) -> [any AnyJSONTool] {
        [AnyTool(expression)]
    }

    /// Passes through an array of tools.
    public static func buildExpression(_ expression: [any AnyJSONTool]) -> [any AnyJSONTool] {
        expression
    }

    /// Builds from a limited availability check.
    public static func buildLimitedAvailability(_ component: [any AnyJSONTool]) -> [any AnyJSONTool] {
        component
    }
}
