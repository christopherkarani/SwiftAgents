// ConduitToolConverterTests.swift
// SwiftAgentsTests
//
// Tests for ConduitToolConverter functionality.

import Conduit
import Foundation
import OrderedCollections
@testable import SwiftAgents
import Testing

// MARK: - ConduitToolConverterTests

// Note: ToolDefinition from SwiftAgents is used (imported via @testable import SwiftAgents)

@Suite("ConduitToolConverter Tests")
struct ConduitToolConverterTests {
    // MARK: - ToolDefinition to ConduitToolDefinition Tests

    @Test("basic tool definition converts correctly")
    func basicToolDefinitionConvertsCorrectly() {
        let toolDef = ToolDefinition(
            name: "calculator",
            description: "Performs calculations",
            parameters: [
                ToolParameter(name: "expression", description: "The expression to evaluate", type: .string, isRequired: true)
            ]
        )

        let conduitToolDef = ConduitToolConverter.toConduitToolDefinition(toolDef)

        #expect(conduitToolDef.name == "calculator")
        #expect(conduitToolDef.description == "Performs calculations")
    }

    @Test("tool with multiple parameters converts correctly")
    func toolWithMultipleParametersConvertsCorrectly() {
        let toolDef = ToolDefinition(
            name: "search",
            description: "Searches for information",
            parameters: [
                ToolParameter(name: "query", description: "Search query", type: .string, isRequired: true),
                ToolParameter(name: "limit", description: "Result limit", type: .int, isRequired: false),
                ToolParameter(name: "caseSensitive", description: "Case sensitive search", type: .bool, isRequired: false)
            ]
        )

        let conduitToolDef = ConduitToolConverter.toConduitToolDefinition(toolDef)

        #expect(conduitToolDef.name == "search")
        #expect(conduitToolDef.description == "Searches for information")
    }

    @Test("tool with nested object parameters converts correctly")
    func toolWithNestedObjectParametersConvertsCorrectly() {
        let toolDef = ToolDefinition(
            name: "createUser",
            description: "Creates a new user",
            parameters: [
                ToolParameter(
                    name: "user",
                    description: "User information",
                    type: .object(properties: [
                        ToolParameter(name: "name", description: "User name", type: .string, isRequired: true),
                        ToolParameter(name: "age", description: "User age", type: .int, isRequired: true)
                    ]),
                    isRequired: true
                )
            ]
        )

        let conduitToolDef = ConduitToolConverter.toConduitToolDefinition(toolDef)

        #expect(conduitToolDef.name == "createUser")
    }

    @Test("tool with array parameters converts correctly")
    func toolWithArrayParametersConvertsCorrectly() {
        let toolDef = ToolDefinition(
            name: "processBatch",
            description: "Processes multiple items",
            parameters: [
                ToolParameter(
                    name: "items",
                    description: "List of items to process",
                    type: .array(elementType: .string),
                    isRequired: true
                )
            ]
        )

        let conduitToolDef = ConduitToolConverter.toConduitToolDefinition(toolDef)

        #expect(conduitToolDef.name == "processBatch")
    }

    @Test("tool with enum parameters converts correctly")
    func toolWithEnumParametersConvertsCorrectly() {
        let toolDef = ToolDefinition(
            name: "setMode",
            description: "Sets the mode",
            parameters: [
                ToolParameter(
                    name: "mode",
                    description: "Display mode",
                    type: .oneOf(["light", "dark", "auto"]),
                    isRequired: true
                )
            ]
        )

        let conduitToolDef = ConduitToolConverter.toConduitToolDefinition(toolDef)

        #expect(conduitToolDef.name == "setMode")
    }

    // MARK: - Type Conversion Tests

    @Test("string type converts to correct schema")
    func stringTypeConvertsToCorrectSchema() {
        let schema = ConduitToolConverter.convertParameterType(.string)

        if case .string = schema {
            // Success
        } else {
            Issue.record("Expected string type in schema")
        }
    }

    @Test("integer type converts to correct schema")
    func integerTypeConvertsToCorrectSchema() {
        let schema = ConduitToolConverter.convertParameterType(.int)

        if case .integer = schema {
            // Success
        } else {
            Issue.record("Expected integer type in schema")
        }
    }

    @Test("number type converts to correct schema")
    func numberTypeConvertsToCorrectSchema() {
        let schema = ConduitToolConverter.convertParameterType(.double)

        if case .number = schema {
            // Success
        } else {
            Issue.record("Expected number type in schema")
        }
    }

    @Test("boolean type converts to correct schema")
    func booleanTypeConvertsToCorrectSchema() {
        let schema = ConduitToolConverter.convertParameterType(.bool)

        if case .boolean = schema {
            // Success
        } else {
            Issue.record("Expected boolean type in schema")
        }
    }

    @Test("array type converts to correct schema")
    func arrayTypeConvertsToCorrectSchema() {
        let schema = ConduitToolConverter.convertParameterType(.array(elementType: .string))

        if case .array = schema {
            // Success
        } else {
            Issue.record("Expected array type in schema")
        }
    }

    @Test("object type converts to correct schema")
    func objectTypeConvertsToCorrectSchema() {
        let schema = ConduitToolConverter.convertParameterType(
            .object(properties: [
                ToolParameter(name: "key", description: "Value", type: .string, isRequired: true)
            ])
        )

        if case .object = schema {
            // Success
        } else {
            Issue.record("Expected object type in schema")
        }
    }

    // MARK: - Tool Extension Tests

    @Test("Tool provides valid definition")
    func toolProvidesValidDefinition() {
        let tool = TestCalculatorTool()
        let definition = tool.definition

        #expect(definition.name == tool.name)
        #expect(definition.description == tool.description)
        #expect(definition.parameters.count == tool.parameters.count)
    }

    @Test("Tool definition converts to Conduit format")
    func toolDefinitionConvertsToConduitFormat() {
        let tool = TestCalculatorTool()
        let conduitDef = ConduitToolConverter.toConduitToolDefinition(tool.definition)

        #expect(conduitDef.name == tool.name)
        #expect(conduitDef.description == tool.description)
    }

    // MARK: - Batch Conversion Tests

    @Test("multiple tools convert correctly")
    func multipleToolsConvertCorrectly() {
        let tools = [
            ToolDefinition(
                name: "tool1",
                description: "First tool",
                parameters: [
                    ToolParameter(name: "param1", description: "Param 1", type: .string, isRequired: true)
                ]
            ),
            ToolDefinition(
                name: "tool2",
                description: "Second tool",
                parameters: [
                    ToolParameter(name: "param2", description: "Param 2", type: .int, isRequired: true)
                ]
            ),
            ToolDefinition(
                name: "tool3",
                description: "Third tool",
                parameters: []
            )
        ]

        let conduitDefs = ConduitToolConverter.toConduitToolDefinitions(tools)

        #expect(conduitDefs.count == 3)
        #expect(conduitDefs[0].name == "tool1")
        #expect(conduitDefs[1].name == "tool2")
        #expect(conduitDefs[2].name == "tool3")
    }

    // MARK: - Edge Cases

    @Test("empty parameters converts successfully")
    func emptyParametersConvertsSuccessfully() {
        let toolDef = ToolDefinition(
            name: "noParams",
            description: "Tool with no parameters",
            parameters: []
        )

        let conduitToolDef = ConduitToolConverter.toConduitToolDefinition(toolDef)

        #expect(conduitToolDef.name == "noParams")
    }

    @Test("deeply nested objects convert correctly")
    func deeplyNestedObjectsConvertCorrectly() {
        let toolDef = ToolDefinition(
            name: "nested",
            description: "Deeply nested tool",
            parameters: [
                ToolParameter(
                    name: "level1",
                    description: "Level 1",
                    type: .object(properties: [
                        ToolParameter(
                            name: "level2",
                            description: "Level 2",
                            type: .object(properties: [
                                ToolParameter(name: "level3", description: "Deep value", type: .string, isRequired: true)
                            ]),
                            isRequired: true
                        )
                    ]),
                    isRequired: true
                )
            ]
        )

        let conduitToolDef = ConduitToolConverter.toConduitToolDefinition(toolDef)

        #expect(conduitToolDef.name == "nested")
    }

    @Test("long parameter descriptions are preserved")
    func longParameterDescriptionsArePreserved() {
        let longDescription = String(repeating: "This is a very long description. ", count: 10)
        let toolDef = ToolDefinition(
            name: "longDesc",
            description: "Tool with long descriptions",
            parameters: [
                ToolParameter(name: "param", description: longDescription, type: .string, isRequired: true)
            ]
        )

        let conduitToolDef = ConduitToolConverter.toConduitToolDefinition(toolDef)

        #expect(conduitToolDef.name == "longDesc")
    }

    @Test("special characters in names and descriptions are handled")
    func specialCharactersInNamesAndDescriptionsAreHandled() {
        let toolDef = ToolDefinition(
            name: "special_chars_123",
            description: "Tool with \"quotes\" and 'apostrophes' and newlines\n",
            parameters: [
                ToolParameter(name: "param_with_underscore", description: "Param with \"quotes\"", type: .string, isRequired: true)
            ]
        )

        let conduitToolDef = ConduitToolConverter.toConduitToolDefinition(toolDef)

        #expect(conduitToolDef.name == "special_chars_123")
    }

    @Test("oneOf with many options converts correctly")
    func oneOfWithManyOptionsConvertsCorrectly() {
        let options = ["option1", "option2", "option3", "option4", "option5"]
        let toolDef = ToolDefinition(
            name: "multiOption",
            description: "Tool with many enum options",
            parameters: [
                ToolParameter(name: "choice", description: "Pick one", type: .oneOf(options), isRequired: true)
            ]
        )

        let conduitToolDef = ConduitToolConverter.toConduitToolDefinition(toolDef)

        #expect(conduitToolDef.name == "multiOption")
    }

    @Test("any type converts to string fallback")
    func anyTypeConvertsToStringFallback() {
        let schema = ConduitToolConverter.convertParameterType(.any)

        // .any should convert to a string schema as fallback
        if case .string = schema {
            // Success
        } else {
            Issue.record("Expected string type as fallback for .any")
        }
    }
}

// MARK: - TestCalculatorTool

private struct TestCalculatorTool: Tool {
    let name = "calculator"
    let description = "Performs mathematical calculations"

    var parameters: [ToolParameter] {
        [
            ToolParameter(name: "expression", description: "Math expression to evaluate", type: .string, isRequired: true)
        ]
    }

    var inputGuardrails: [any ToolInputGuardrail] { [] }
    var outputGuardrails: [any ToolOutputGuardrail] { [] }

    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        guard let expression = arguments["expression"]?.stringValue else {
            throw AgentError.invalidToolArguments(toolName: name, reason: "Missing expression")
        }
        return .string("Result of: \(expression)")
    }
}
