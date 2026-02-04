import Foundation
import HiveCore
import SwiftAgents

public enum SwiftAgentsToolRegistryError: Error, Equatable, Sendable {
    case invalidArgumentsJSON
    case argumentsMustBeJSONObject
    case resultEncodingFailed
    case schemaEncodingFailed
}

/// Bridges SwiftAgents tools into HiveCore's `HiveToolRegistry` interface.
///
/// This adapter snapshots tools at initialization time so `listTools()` can remain synchronous.
public struct SwiftAgentsToolRegistry: HiveToolRegistry, Sendable {
    private let registry: ToolRegistry
    private let toolDefinitions: [HiveToolDefinition]

    public init(tools: [any AnyJSONTool]) throws {
        let registry = ToolRegistry(tools: tools)
        self.registry = registry
        var byName: [String: any AnyJSONTool] = [:]
        for tool in tools {
            byName[tool.name] = tool
        }
        self.toolDefinitions = try byName.values
            .map { try Self.makeToolDefinition(for: $0.schema) }
            .sorted { $0.name.utf8.lexicographicallyPrecedes($1.name.utf8) }
    }

    public static func fromRegistry(_ registry: ToolRegistry) async throws -> Self {
        let schemas = await registry.schemas
        let definitions = try schemas
            .map { try Self.makeToolDefinition(for: $0) }
            .sorted { $0.name.utf8.lexicographicallyPrecedes($1.name.utf8) }
        return SwiftAgentsToolRegistry(registry: registry, toolDefinitions: definitions)
    }

    public func listTools() -> [HiveToolDefinition] {
        toolDefinitions
    }

    public func invoke(_ call: HiveToolCall) async throws -> HiveToolResult {
        let arguments = try Self.parseArgumentsJSON(call.argumentsJSON)
        let output = try await registry.execute(toolNamed: call.name, arguments: arguments)
        let content = try Self.encodeJSONFragment(output)

        return HiveToolResult(toolCallID: call.id, content: content)
    }
}

extension SwiftAgentsToolRegistry {
    private init(registry: ToolRegistry, toolDefinitions: [HiveToolDefinition]) {
        self.registry = registry
        self.toolDefinitions = toolDefinitions
    }

    private static func parseArgumentsJSON(_ json: String) throws -> [String: SendableValue] {
        guard let data = json.data(using: .utf8) else {
            throw SwiftAgentsToolRegistryError.invalidArgumentsJSON
        }

        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        guard let dict = jsonObject as? [String: Any] else {
            throw SwiftAgentsToolRegistryError.argumentsMustBeJSONObject
        }

        var result: [String: SendableValue] = [:]
        for (key, value) in dict {
            result[key] = SendableValue.fromJSONValue(value)
        }
        return result
    }

    private static func encodeJSONFragment(_ value: SendableValue) throws -> String {
        let object = value.toJSONObject()
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed])
        guard let json = String(data: data, encoding: .utf8) else {
            throw SwiftAgentsToolRegistryError.resultEncodingFailed
        }
        return json
    }

    private static func makeToolDefinition(for schema: ToolSchema) throws -> HiveToolDefinition {
        let schemaObject = makeParametersSchema(toolName: schema.name, parameters: schema.parameters)
        let data = try JSONSerialization.data(withJSONObject: schemaObject, options: [.sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw SwiftAgentsToolRegistryError.schemaEncodingFailed
        }
        return HiveToolDefinition(
            name: schema.name,
            description: schema.description,
            parametersJSONSchema: json
        )
    }

    private static func makeParametersSchema(toolName: String, parameters: [ToolParameter]) -> [String: Any] {
        var properties: [String: Any] = [:]
        var required: [String] = []

        for parameter in parameters {
            var schema = jsonSchema(for: parameter.type)
            schema["description"] = parameter.description
            if let defaultValue = parameter.defaultValue {
                schema["default"] = defaultValue.toJSONObject()
            }
            properties[parameter.name] = schema
            if parameter.isRequired, parameter.defaultValue == nil {
                required.append(parameter.name)
            }
        }

        required.sort { $0.utf8.lexicographicallyPrecedes($1.utf8) }

        var root: [String: Any] = [
            "type": "object",
            "description": "Tool parameters for \(toolName)",
            "properties": properties,
            "additionalProperties": false
        ]

        if !required.isEmpty {
            root["required"] = required
        }

        return root
    }

    private static func jsonSchema(for type: ToolParameter.ParameterType) -> [String: Any] {
        switch type {
        case .string:
            return ["type": "string"]
        case .int:
            return ["type": "integer"]
        case .double:
            return ["type": "number"]
        case .bool:
            return ["type": "boolean"]
        case .array(let elementType):
            return [
                "type": "array",
                "items": jsonSchema(for: elementType)
            ]
        case .object(let properties):
            var props: [String: Any] = [:]
            var required: [String] = []
            for property in properties {
                var schema = jsonSchema(for: property.type)
                schema["description"] = property.description
                if let defaultValue = property.defaultValue {
                    schema["default"] = defaultValue.toJSONObject()
                }
                props[property.name] = schema
                if property.isRequired, property.defaultValue == nil {
                    required.append(property.name)
                }
            }

            required.sort { $0.utf8.lexicographicallyPrecedes($1.utf8) }

            var object: [String: Any] = [
                "type": "object",
                "properties": props,
                "additionalProperties": false
            ]
            if !required.isEmpty {
                object["required"] = required
            }
            return object
        case .oneOf(let options):
            return [
                "type": "string",
                "enum": options
            ]
        case .any:
            return [
                "anyOf": [
                    ["type": "string"],
                    ["type": "number"],
                    ["type": "integer"],
                    ["type": "boolean"],
                    ["type": "object"],
                    ["type": "array"]
                ]
            ]
        }
    }
}

extension SendableValue {
    fileprivate func toJSONObject() -> Any {
        switch self {
        case .null:
            return NSNull()
        case let .bool(value):
            return value
        case let .int(value):
            return value
        case let .double(value):
            return value
        case let .string(value):
            return value
        case let .array(values):
            return values.map { $0.toJSONObject() }
        case let .dictionary(values):
            var result: [String: Any] = [:]
            for (key, value) in values {
                result[key] = value.toJSONObject()
            }
            return result
        }
    }
}
