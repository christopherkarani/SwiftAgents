// ConduitToolConverter.swift
// SwiftAgents Framework
//
// Converts SwiftAgents tool definitions to Conduit's tool format.

import Conduit
import Foundation
import OrderedCollections

// MARK: - ConduitToolConverter

/// Converts SwiftAgents tool definitions to Conduit's type-safe tool format.
///
/// This converter handles the transformation of SwiftAgents' `ToolDefinition` and
/// `ToolParameter` types into Conduit's `Schema`-based tool representation.
///
/// ## Type Mappings
///
/// The following type conversions are performed:
///
/// | SwiftAgents Type | Conduit Schema |
/// |------------------|----------------|
/// | `.string` | `.string(constraints: [])` |
/// | `.int` | `.integer(constraints: [])` |
/// | `.double` | `.number(constraints: [])` |
/// | `.bool` | `.boolean(constraints: [])` |
/// | `.array(elementType)` | `.array(items: <converted>, constraints: [])` |
/// | `.object(properties)` | `.object(name:, description:, properties:)` |
/// | `.oneOf([String])` | `.string(constraints: [.anyOf(options)])` |
/// | `.any` | `.string(constraints: [])` (fallback) |
///
/// ## Usage
///
/// ```swift
/// let swiftAgentsTools = [weatherTool.definition, searchTool.definition]
/// let conduitToolDefs = ConduitToolConverter.toConduitToolDefinitions(swiftAgentsTools)
///
/// // Use with Conduit provider
/// let result = try await provider.generate(
///     prompt: prompt,
///     tools: conduitToolDefs
/// )
/// ```
///
/// ## Thread Safety
///
/// All methods are thread-safe and can be called from any context.
/// The converter uses only pure functions with no mutable state.
public enum ConduitToolConverter {

    // MARK: - Public Methods

    /// Converts an array of SwiftAgents tool definitions to Conduit tool definitions.
    ///
    /// This is the primary entry point for batch tool conversion. Each tool's
    /// parameters are converted to a Conduit `Schema.object` representation.
    ///
    /// - Parameter definitions: The SwiftAgents tool definitions to convert.
    /// - Returns: An array of Conduit `AnyAITool` wrappers containing the converted definitions.
    public static func toConduitToolDefinitions(_ definitions: [ToolDefinition]) -> [ConduitToolDefinition] {
        definitions.map { toConduitToolDefinition($0) }
    }

    /// Converts a single SwiftAgents tool definition to a Conduit tool definition.
    ///
    /// The conversion creates an object schema where each parameter becomes
    /// a property with its type, description, and required status preserved.
    ///
    /// - Parameter definition: The SwiftAgents tool definition to convert.
    /// - Returns: A Conduit `ConduitToolDefinition` with equivalent schema.
    public static func toConduitToolDefinition(_ definition: ToolDefinition) -> ConduitToolDefinition {
        let parametersSchema = convertParametersToSchema(definition.parameters, objectName: definition.name)

        return ConduitToolDefinition(
            name: definition.name,
            description: definition.description,
            parameters: parametersSchema
        )
    }

    /// Converts a SwiftAgents parameter type to a Conduit schema.
    ///
    /// This method handles recursive types like arrays and objects,
    /// as well as enum-like types via `.oneOf`.
    ///
    /// - Parameter type: The SwiftAgents parameter type to convert.
    /// - Returns: The equivalent Conduit `Schema`.
    public static func convertParameterType(_ type: ToolParameter.ParameterType) -> Schema {
        switch type {
        case .string:
            return .string(constraints: [])

        case .int:
            return .integer(constraints: [])

        case .double:
            return .number(constraints: [])

        case .bool:
            return .boolean(constraints: [])

        case let .array(elementType):
            let itemSchema = convertParameterType(elementType)
            return .array(items: itemSchema, constraints: [])

        case let .object(properties):
            return convertPropertiesToObjectSchema(properties, objectName: "Object")

        case let .oneOf(options):
            // Map oneOf to a string with anyOf constraint
            return .string(constraints: [.anyOf(options)])

        case .any:
            // No direct equivalent in Conduit Schema; fall back to string
            // This allows maximum flexibility for untyped parameters
            return .string(constraints: [])
        }
    }

    // MARK: - Internal Conversion Methods

    /// Converts an array of SwiftAgents parameters to a Conduit object schema.
    ///
    /// The resulting schema represents the tool's parameter structure as an
    /// object with typed properties, preserving descriptions and required status.
    ///
    /// - Parameters:
    ///   - parameters: The SwiftAgents parameters to convert.
    ///   - objectName: The name for the resulting object schema.
    /// - Returns: A Conduit `Schema.object` with all parameters as properties.
    static func convertParametersToSchema(_ parameters: [ToolParameter], objectName: String) -> Schema {
        var properties = OrderedDictionary<String, Schema.Property>()

        for param in parameters {
            let schema = convertParameterType(param.type)
            let wrappedSchema = param.isRequired ? schema : .optional(wrapped: schema)

            properties[param.name] = Schema.Property(
                schema: wrappedSchema,
                description: param.description,
                isRequired: param.isRequired
            )
        }

        return .object(
            name: objectName,
            description: nil,
            properties: properties
        )
    }

    /// Converts nested object properties to a Conduit object schema.
    ///
    /// This handles the recursive case where a parameter type is `.object`
    /// containing its own set of properties.
    ///
    /// - Parameters:
    ///   - properties: The nested SwiftAgents properties to convert.
    ///   - objectName: The name for the resulting object schema.
    /// - Returns: A Conduit `Schema.object` with converted properties.
    static func convertPropertiesToObjectSchema(_ properties: [ToolParameter], objectName: String) -> Schema {
        var schemaProperties = OrderedDictionary<String, Schema.Property>()

        for prop in properties {
            let schema = convertParameterType(prop.type)
            let wrappedSchema = prop.isRequired ? schema : .optional(wrapped: schema)

            schemaProperties[prop.name] = Schema.Property(
                schema: wrappedSchema,
                description: prop.description,
                isRequired: prop.isRequired
            )
        }

        return .object(
            name: objectName,
            description: nil,
            properties: schemaProperties
        )
    }
}

// MARK: - ConduitToolDefinition

/// A lightweight representation of a tool definition for Conduit integration.
///
/// This struct captures the essential elements needed to describe a tool
/// to Conduit's AI providers without requiring the full `AITool` protocol.
///
/// ## Usage
///
/// ```swift
/// let definition = ConduitToolDefinition(
///     name: "get_weather",
///     description: "Gets current weather for a location",
///     parameters: .object(
///         name: "get_weather",
///         description: nil,
///         properties: [
///             "location": .init(schema: .string(constraints: []), description: "City name")
///         ]
///     )
/// )
/// ```
public struct ConduitToolDefinition: Sendable {
    /// The unique name of the tool.
    public let name: String

    /// A description of what the tool does.
    public let description: String

    /// The schema describing the tool's parameters.
    public let parameters: Schema

    /// Creates a new Conduit tool definition.
    ///
    /// - Parameters:
    ///   - name: The unique name of the tool.
    ///   - description: A description of what the tool does.
    ///   - parameters: The schema describing the tool's parameters.
    public init(name: String, description: String, parameters: Schema) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

// MARK: - ToolDefinition Convenience Extension

extension ToolDefinition {
    /// Converts this SwiftAgents tool definition to a Conduit tool definition.
    ///
    /// This is a convenience method that delegates to `ConduitToolConverter`.
    ///
    /// - Returns: A Conduit-compatible tool definition.
    public func toConduitDefinition() -> ConduitToolDefinition {
        ConduitToolConverter.toConduitToolDefinition(self)
    }
}

// MARK: - Tool Convenience Extension

extension Tool {
    /// Converts this tool to a Conduit tool definition.
    ///
    /// This is a convenience method that creates a `ToolDefinition` from
    /// this tool and converts it to Conduit format.
    ///
    /// - Returns: A Conduit-compatible tool definition.
    public func toConduitDefinition() -> ConduitToolDefinition {
        definition.toConduitDefinition()
    }
}

// MARK: - Array Extensions

extension Array where Element == ToolDefinition {
    /// Converts all tool definitions to Conduit format.
    ///
    /// - Returns: An array of Conduit-compatible tool definitions.
    public func toConduitDefinitions() -> [ConduitToolDefinition] {
        ConduitToolConverter.toConduitToolDefinitions(self)
    }
}

extension Array where Element == any Tool {
    /// Converts all tools to Conduit definitions.
    ///
    /// - Returns: An array of Conduit-compatible tool definitions.
    public func toConduitDefinitions() -> [ConduitToolDefinition] {
        map { $0.definition }.toConduitDefinitions()
    }
}
