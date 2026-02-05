// ToolParameterBuilderTests.swift
// SwarmTests
//
// Tests for ToolParameterBuilder DSL result builder.

import Foundation
@testable import Swarm
import Testing

// MARK: - ToolParameterBuilderTests

@Suite("ToolParameterBuilder DSL Tests")
struct ToolParameterBuilderTests {
    // MARK: - Basic Builder Usage

    @Test("Build single parameter")
    func buildSingleParameter() {
        @ToolParameterBuilder
        func makeParams() -> [ToolParameter] {
            Parameter("location", description: "City name", type: .string)
        }

        let params = makeParams()
        #expect(params.count == 1)
        #expect(params[0].name == "location")
        #expect(params[0].type == .string)
        #expect(params[0].isRequired == true)
    }

    @Test("Build multiple parameters")
    func buildMultipleParameters() {
        @ToolParameterBuilder
        func makeParams() -> [ToolParameter] {
            Parameter("location", description: "City name", type: .string)
            Parameter("units", description: "Temperature units", type: .oneOf(["C", "F"]))
            Parameter("detailed", description: "Include details", type: .bool, required: false)
        }

        let params = makeParams()
        #expect(params.count == 3)
        #expect(params[0].name == "location")
        #expect(params[1].name == "units")
        #expect(params[2].name == "detailed")
        #expect(params[2].isRequired == false)
    }

    @Test("Build with default values")
    func buildWithDefaultValues() {
        @ToolParameterBuilder
        func makeParams() -> [ToolParameter] {
            Parameter("limit", description: "Max results", type: .int, required: false, default: 10)
            Parameter("format", description: "Output format", type: .string, default: "json")
        }

        let params = makeParams()
        #expect(params.count == 2)
        #expect(params[0].defaultValue == .int(10))
        #expect(params[1].defaultValue == .string("json"))
    }

    // MARK: - Conditional Building

    @Test("Build with if condition - true branch")
    func buildWithIfConditionTrue() {
        let includeTimezone = true

        @ToolParameterBuilder
        func makeParams() -> [ToolParameter] {
            Parameter("location", description: "City name", type: .string)
            if includeTimezone {
                Parameter("timezone", description: "Timezone offset", type: .int)
            }
        }

        let params = makeParams()
        #expect(params.count == 2)
        #expect(params[1].name == "timezone")
    }

    @Test("Build with if condition - false branch")
    func buildWithIfConditionFalse() {
        let includeTimezone = false

        @ToolParameterBuilder
        func makeParams() -> [ToolParameter] {
            Parameter("location", description: "City name", type: .string)
            if includeTimezone {
                Parameter("timezone", description: "Timezone offset", type: .int)
            }
        }

        let params = makeParams()
        #expect(params.count == 1)
        #expect(params[0].name == "location")
    }

    @Test("Build with if-else condition")
    func buildWithIfElseCondition() {
        let useDetailedMode = true

        @ToolParameterBuilder
        func makeParams() -> [ToolParameter] {
            Parameter("query", description: "Search query", type: .string)
            if useDetailedMode {
                Parameter("depth", description: "Search depth", type: .int)
            } else {
                Parameter("quick", description: "Quick mode", type: .bool)
            }
        }

        let params = makeParams()
        #expect(params.count == 2)
        #expect(params[1].name == "depth")
    }

    // MARK: - Loop Building

    @Test("Build with for loop")
    func buildWithForLoop() {
        let fieldNames = ["field1", "field2", "field3"]

        @ToolParameterBuilder
        func makeParams() -> [ToolParameter] {
            for name in fieldNames {
                Parameter(name, description: "Dynamic field \(name)", type: .string)
            }
        }

        let params = makeParams()
        #expect(params.count == 3)
        #expect(params[0].name == "field1")
        #expect(params[1].name == "field2")
        #expect(params[2].name == "field3")
    }

    // MARK: - Complex Types

    @Test("Build with array parameter type")
    func buildWithArrayType() {
        @ToolParameterBuilder
        func makeParams() -> [ToolParameter] {
            Parameter("tags", description: "List of tags", type: .array(elementType: .string))
            Parameter("numbers", description: "List of numbers", type: .array(elementType: .int))
        }

        let params = makeParams()
        #expect(params.count == 2)
        #expect(params[0].type == .array(elementType: .string))
        #expect(params[1].type == .array(elementType: .int))
    }

    @Test("Build with object parameter type")
    func buildWithObjectType() {
        @ToolParameterBuilder
        func makeParams() -> [ToolParameter] {
            Parameter("address", description: "Address object", type: .object(properties: [
                ToolParameter(name: "street", description: "Street", type: .string),
                ToolParameter(name: "city", description: "City", type: .string),
                ToolParameter(name: "zip", description: "ZIP code", type: .string)
            ]))
        }

        let params = makeParams()
        #expect(params.count == 1)
        if case let .object(properties) = params[0].type {
            #expect(properties.count == 3)
        } else {
            Issue.record("Expected object type")
        }
    }

    @Test("Build with oneOf parameter type")
    func buildWithOneOfType() {
        @ToolParameterBuilder
        func makeParams() -> [ToolParameter] {
            Parameter("priority", description: "Task priority", type: .oneOf(["low", "medium", "high"]))
        }

        let params = makeParams()
        #expect(params[0].type == .oneOf(["low", "medium", "high"]))
    }

    // MARK: - Tool Integration

    @Test("Tool uses ToolParameterBuilder for parameters")
    func toolUsesBuilder() async throws {
        let tool = BuilderBasedTool()

        #expect(tool.parameters.count == 3)
        #expect(tool.parameters[0].name == "query")
        #expect(tool.parameters[1].name == "limit")
        #expect(tool.parameters[2].name == "filters")
    }

    // MARK: - Parameter Factory Function

    @Test("Parameter factory with all options")
    func parameterFactoryAllOptions() {
        let param = Parameter(
            "email",
            description: "Email address",
            type: .string,
            required: true,
            default: nil
        )

        #expect(param.name == "email")
        #expect(param.description == "Email address")
        #expect(param.type == .string)
        #expect(param.isRequired == true)
        #expect(param.defaultValue == nil)
    }

    @Test("Parameter factory with minimal options")
    func parameterFactoryMinimalOptions() {
        let param = Parameter("name", description: "User name", type: .string)

        #expect(param.name == "name")
        #expect(param.isRequired == true) // Default
    }

    // MARK: - Empty Builder

    @Test("Build empty parameter list")
    func buildEmptyParameterList() {
        @ToolParameterBuilder
        func makeParams() -> [ToolParameter] {
            // Empty
        }

        let params = makeParams()
        #expect(params.isEmpty)
    }

    // MARK: - Nested Builders

    @Test("Nested conditionals in builder")
    func nestedConditionalsInBuilder() {
        let hasAuth = true
        let isAdmin = true

        @ToolParameterBuilder
        func makeParams() -> [ToolParameter] {
            Parameter("action", description: "Action to perform", type: .string)
            if hasAuth {
                Parameter("token", description: "Auth token", type: .string)
                if isAdmin {
                    Parameter("adminKey", description: "Admin key", type: .string)
                }
            }
        }

        let params = makeParams()
        #expect(params.count == 3)
        #expect(params.map(\.name) == ["action", "token", "adminKey"])
    }
}

// MARK: - BuilderBasedTool

/// A tool that uses ToolParameterBuilder for its parameters
struct BuilderBasedTool: AnyJSONTool {
    let name = "builder_tool"
    let description = "A tool using builder DSL"

    @ToolParameterBuilder
    var parameters: [ToolParameter] {
        Parameter("query", description: "Search query", type: .string)
        Parameter("limit", description: "Max results", type: .int, required: false, default: 10)
        Parameter("filters", description: "Search filters", type: .array(elementType: .string), required: false)
    }

    func execute(arguments _: [String: SendableValue]) async throws -> SendableValue {
        .string("executed")
    }
}

// MARK: - Parameter Factory Function (to be implemented)

// swiftlint:disable identifier_name

/// Convenience function for creating ToolParameter with builder DSL syntax
/// This needs to be implemented in the main source
func Parameter(
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

/// Overload for integer default values
func Parameter(
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

/// Overload for string default values
func Parameter(
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

// swiftlint:enable identifier_name
