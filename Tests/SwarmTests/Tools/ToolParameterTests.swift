// ToolParameterTests.swift
// SwarmTests
//
// Comprehensive tests for ToolParameter, ToolParameter.ParameterType, ToolSchema, and tool protocol extensions

import Foundation
@testable import Swarm
import Testing

// MARK: - ToolParameterTests

@Suite("ToolParameter Tests")
struct ToolParameterTests {
    @Test("Basic initialization with required parameter")
    func basicRequiredInitialization() {
        let param = ToolParameter(
            name: "location",
            description: "The city name",
            type: .string
        )

        #expect(param.name == "location")
        #expect(param.description == "The city name")
        #expect(param.type == .string)
        #expect(param.isRequired == true)
        #expect(param.defaultValue == nil)
    }

    @Test("Initialization with optional parameter")
    func optionalParameterInitialization() {
        let param = ToolParameter(
            name: "units",
            description: "Temperature units",
            type: .string,
            isRequired: false
        )

        #expect(param.name == "units")
        #expect(param.description == "Temperature units")
        #expect(param.type == .string)
        #expect(param.isRequired == false)
        #expect(param.defaultValue == nil)
    }

    @Test("Initialization with default value")
    func defaultValueInitialization() {
        let param = ToolParameter(
            name: "limit",
            description: "Maximum results",
            type: .int,
            isRequired: false,
            defaultValue: .int(10)
        )

        #expect(param.name == "limit")
        #expect(param.description == "Maximum results")
        #expect(param.type == .int)
        #expect(param.isRequired == false)
        #expect(param.defaultValue == .int(10))
    }

    @Test("All parameter types initialization")
    func allTypesInitialization() {
        let stringParam = ToolParameter(name: "str", description: "String param", type: .string)
        let intParam = ToolParameter(name: "num", description: "Int param", type: .int)
        let doubleParam = ToolParameter(name: "dbl", description: "Double param", type: .double)
        let boolParam = ToolParameter(name: "flag", description: "Bool param", type: .bool)
        let arrayParam = ToolParameter(name: "arr", description: "Array param", type: .array(elementType: .string))
        let objectParam = ToolParameter(name: "obj", description: "Object param", type: .object(properties: []))
        let oneOfParam = ToolParameter(name: "choice", description: "OneOf param", type: .oneOf(["A", "B"]))
        let anyParam = ToolParameter(name: "any", description: "Any param", type: .any)

        #expect(stringParam.type == .string)
        #expect(intParam.type == .int)
        #expect(doubleParam.type == .double)
        #expect(boolParam.type == .bool)
        #expect(arrayParam.type == .array(elementType: .string))
        #expect(objectParam.type == .object(properties: []))
        #expect(oneOfParam.type == .oneOf(["A", "B"]))
        #expect(anyParam.type == .any)
    }

    @Test("Equatable conformance: equal instances")
    func equatableEqual() {
        let param1 = ToolParameter(
            name: "test",
            description: "Test param",
            type: .string,
            isRequired: true,
            defaultValue: .string("default")
        )
        let param2 = ToolParameter(
            name: "test",
            description: "Test param",
            type: .string,
            isRequired: true,
            defaultValue: .string("default")
        )

        #expect(param1 == param2)
    }

    @Test("Equatable conformance: different name")
    func equatableDifferentName() {
        let param1 = ToolParameter(name: "name1", description: "Desc", type: .string)
        let param2 = ToolParameter(name: "name2", description: "Desc", type: .string)

        #expect(param1 != param2)
    }

    @Test("Equatable conformance: different description")
    func equatableDifferentDescription() {
        let param1 = ToolParameter(name: "test", description: "Desc1", type: .string)
        let param2 = ToolParameter(name: "test", description: "Desc2", type: .string)

        #expect(param1 != param2)
    }

    @Test("Equatable conformance: different type")
    func equatableDifferentType() {
        let param1 = ToolParameter(name: "test", description: "Desc", type: .string)
        let param2 = ToolParameter(name: "test", description: "Desc", type: .int)

        #expect(param1 != param2)
    }

    @Test("Equatable conformance: different isRequired")
    func equatableDifferentIsRequired() {
        let param1 = ToolParameter(name: "test", description: "Desc", type: .string, isRequired: true)
        let param2 = ToolParameter(name: "test", description: "Desc", type: .string, isRequired: false)

        #expect(param1 != param2)
    }

    @Test("Equatable conformance: different defaultValue")
    func equatableDifferentDefaultValue() {
        let param1 = ToolParameter(name: "test", description: "Desc", type: .int, defaultValue: .int(1))
        let param2 = ToolParameter(name: "test", description: "Desc", type: .int, defaultValue: .int(2))

        #expect(param1 != param2)
    }
}

// MARK: - ParameterTypeTests

@Suite("ParameterType Tests")
struct ParameterTypeTests {
    @Test("String type description")
    func stringTypeDescription() {
        let type = ToolParameter.ParameterType.string
        #expect(type.description == "string")
    }

    @Test("Int type description")
    func intTypeDescription() {
        let type = ToolParameter.ParameterType.int
        #expect(type.description == "integer")
    }

    @Test("Double type description")
    func doubleTypeDescription() {
        let type = ToolParameter.ParameterType.double
        #expect(type.description == "number")
    }

    @Test("Bool type description")
    func boolTypeDescription() {
        let type = ToolParameter.ParameterType.bool
        #expect(type.description == "boolean")
    }

    @Test("Array type description")
    func arrayTypeDescription() {
        let type = ToolParameter.ParameterType.array(elementType: .string)
        #expect(type.description == "array<string>")
    }

    @Test("Nested array type description")
    func nestedArrayTypeDescription() {
        let type = ToolParameter.ParameterType.array(elementType: .array(elementType: .int))
        #expect(type.description == "array<array<integer>>")
    }

    @Test("Object type description")
    func objectTypeDescription() {
        let properties = [
            ToolParameter(name: "field1", description: "First field", type: .string)
        ]
        let type = ToolParameter.ParameterType.object(properties: properties)
        #expect(type.description == "object")
    }

    @Test("OneOf type description with single option")
    func oneOfSingleOptionDescription() {
        let type = ToolParameter.ParameterType.oneOf(["option1"])
        #expect(type.description == "oneOf(option1)")
    }

    @Test("OneOf type description with multiple options")
    func oneOfMultipleOptionsDescription() {
        let type = ToolParameter.ParameterType.oneOf(["celsius", "fahrenheit", "kelvin"])
        #expect(type.description == "oneOf(celsius|fahrenheit|kelvin)")
    }

    @Test("Any type description")
    func anyTypeDescription() {
        let type = ToolParameter.ParameterType.any
        #expect(type.description == "any")
    }

    @Test("All parameter types are equatable")
    func allTypesEquatable() {
        #expect(ToolParameter.ParameterType.string == .string)
        #expect(ToolParameter.ParameterType.int == .int)
        #expect(ToolParameter.ParameterType.double == .double)
        #expect(ToolParameter.ParameterType.bool == .bool)
        #expect(ToolParameter.ParameterType.any == .any)

        // Array equality
        #expect(ToolParameter.ParameterType.array(elementType: .string) == .array(elementType: .string))
        #expect(ToolParameter.ParameterType.array(elementType: .string) != .array(elementType: .int))

        // OneOf equality
        #expect(ToolParameter.ParameterType.oneOf(["A", "B"]) == .oneOf(["A", "B"]))
        #expect(ToolParameter.ParameterType.oneOf(["A", "B"]) != .oneOf(["A", "C"]))
    }

    @Test("Object type equality with properties")
    func objectTypeEquality() {
        let prop1 = ToolParameter(name: "field", description: "Desc", type: .string)
        let prop2 = ToolParameter(name: "field", description: "Desc", type: .string)
        let prop3 = ToolParameter(name: "other", description: "Desc", type: .string)

        let type1 = ToolParameter.ParameterType.object(properties: [prop1])
        let type2 = ToolParameter.ParameterType.object(properties: [prop2])
        let type3 = ToolParameter.ParameterType.object(properties: [prop3])

        #expect(type1 == type2)
        #expect(type1 != type3)
    }

    @Test("Complex nested type description")
    func complexNestedTypeDescription() {
        let innerObject = ToolParameter.ParameterType.object(properties: [
            ToolParameter(name: "inner", description: "Inner field", type: .string)
        ])
        let arrayOfObjects = ToolParameter.ParameterType.array(elementType: innerObject)

        #expect(arrayOfObjects.description == "array<object>")
    }
}

// MARK: - ToolSchemaTests

@Suite("ToolSchema Tests")
struct ToolSchemaTests {
    @Test("Direct initialization")
    func directInitialization() {
        let params = [
            ToolParameter(name: "query", description: "Search query", type: .string)
        ]
        let schema = ToolSchema(
            name: "search",
            description: "Search the web",
            parameters: params
        )

        #expect(schema.name == "search")
        #expect(schema.description == "Search the web")
        #expect(schema.parameters.count == 1)
        #expect(schema.parameters[0].name == "query")
    }

    @Test("Schema derived from AnyJSONTool")
    func schemaFromAnyJSONTool() {
        let tool = MockTool(
            name: "calculator",
            description: "Performs calculations",
            parameters: [
                ToolParameter(name: "expression", description: "Math expression", type: .string)
            ]
        )

        let schema = tool.schema

        #expect(schema.name == "calculator")
        #expect(schema.description == "Performs calculations")
        #expect(schema.parameters.count == 1)
        #expect(schema.parameters[0].name == "expression")
    }

    @Test("Initialization with empty parameters")
    func emptyParametersInitialization() {
        let schema = ToolSchema(
            name: "getCurrentTime",
            description: "Gets the current time",
            parameters: []
        )

        #expect(schema.name == "getCurrentTime")
        #expect(schema.description == "Gets the current time")
        #expect(schema.parameters.isEmpty)
    }

    @Test("Initialization with multiple parameters")
    func multipleParametersInitialization() {
        let params = [
            ToolParameter(name: "location", description: "City name", type: .string),
            ToolParameter(name: "units", description: "Temperature units", type: .string, isRequired: false),
            ToolParameter(name: "detailed", description: "Include details", type: .bool, isRequired: false)
        ]
        let schema = ToolSchema(
            name: "weather",
            description: "Gets weather information",
            parameters: params
        )

        #expect(schema.parameters.count == 3)
        #expect(schema.parameters[0].name == "location")
        #expect(schema.parameters[1].name == "units")
        #expect(schema.parameters[2].name == "detailed")
    }

    @Test("Equatable conformance: equal instances")
    func equatableEqual() {
        let params = [
            ToolParameter(name: "input", description: "Input value", type: .string)
        ]
        let schema1 = ToolSchema(name: "test", description: "Test tool", parameters: params)
        let schema2 = ToolSchema(name: "test", description: "Test tool", parameters: params)

        #expect(schema1 == schema2)
    }

    @Test("Equatable conformance: different name")
    func equatableDifferentName() {
        let params = [
            ToolParameter(name: "input", description: "Input value", type: .string)
        ]
        let schema1 = ToolSchema(name: "tool1", description: "Test tool", parameters: params)
        let schema2 = ToolSchema(name: "tool2", description: "Test tool", parameters: params)

        #expect(schema1 != schema2)
    }

    @Test("Equatable conformance: different description")
    func equatableDifferentDescription() {
        let params = [
            ToolParameter(name: "input", description: "Input value", type: .string)
        ]
        let schema1 = ToolSchema(name: "test", description: "Description 1", parameters: params)
        let schema2 = ToolSchema(name: "test", description: "Description 2", parameters: params)

        #expect(schema1 != schema2)
    }

    @Test("Equatable conformance: different parameters")
    func equatableDifferentParameters() {
        let params1 = [
            ToolParameter(name: "input1", description: "Input value", type: .string)
        ]
        let params2 = [
            ToolParameter(name: "input2", description: "Input value", type: .string)
        ]
        let schema1 = ToolSchema(name: "test", description: "Test tool", parameters: params1)
        let schema2 = ToolSchema(name: "test", description: "Test tool", parameters: params2)

        #expect(schema1 != schema2)
    }
}

// MARK: - ToolProtocolExtensionTests

@Suite("Tool Protocol Extension Tests")
struct ToolProtocolExtensionTests {
    // MARK: - schema property

    @Test("Tool schema property creates ToolSchema")
    func toolSchemaProperty() {
        let tool = MockTool(
            name: "testTool",
            description: "A test tool",
            parameters: [
                ToolParameter(name: "param1", description: "First param", type: .string)
            ]
        )

        let schema = tool.schema

        #expect(schema.name == "testTool")
        #expect(schema.description == "A test tool")
        #expect(schema.parameters.count == 1)
        #expect(schema.parameters[0].name == "param1")
    }

    // MARK: - validateArguments

    @Test("validateArguments succeeds with all required parameters")
    func validateArgumentsSuccess() throws {
        let tool = MockTool(
            name: "weather",
            parameters: [
                ToolParameter(name: "location", description: "City name", type: .string, isRequired: true),
                ToolParameter(name: "units", description: "Units", type: .string, isRequired: false)
            ]
        )

        let arguments: [String: SendableValue] = [
            "location": .string("New York")
        ]

        // Should not throw
        try tool.validateArguments(arguments)
    }

    @Test("validateArguments succeeds with all parameters including optional")
    func validateArgumentsWithOptional() throws {
        let tool = MockTool(
            name: "weather",
            parameters: [
                ToolParameter(name: "location", description: "City name", type: .string, isRequired: true),
                ToolParameter(name: "units", description: "Units", type: .string, isRequired: false)
            ]
        )

        let arguments: [String: SendableValue] = [
            "location": .string("New York"),
            "units": .string("celsius")
        ]

        // Should not throw
        try tool.validateArguments(arguments)
    }

    @Test("validateArguments fails when required parameter is missing")
    func validateArgumentsMissingRequired() {
        let tool = MockTool(
            name: "weather",
            parameters: [
                ToolParameter(name: "location", description: "City name", type: .string, isRequired: true),
                ToolParameter(name: "units", description: "Units", type: .string, isRequired: false)
            ]
        )

        let arguments: [String: SendableValue] = [
            "units": .string("celsius")
        ]

        var thrownError: AgentError?
        do {
            try tool.validateArguments(arguments)
        } catch let error as AgentError {
            thrownError = error
        } catch {
            #expect(Bool(false), "Expected AgentError")
        }

        #expect(thrownError == .invalidToolArguments(
            toolName: "weather",
            reason: "Missing required parameter: location"
        ))
    }

    @Test("validateArguments succeeds with no required parameters")
    func validateArgumentsNoRequiredParams() throws {
        let tool = MockTool(
            name: "getCurrentTime",
            parameters: [
                ToolParameter(name: "format", description: "Time format", type: .string, isRequired: false)
            ]
        )

        let arguments: [String: SendableValue] = [:]

        // Should not throw
        try tool.validateArguments(arguments)
    }

    @Test("validateArguments fails with multiple missing required parameters")
    func validateArgumentsMultipleMissing() {
        let tool = MockTool(
            name: "complexTool",
            parameters: [
                ToolParameter(name: "param1", description: "First param", type: .string, isRequired: true),
                ToolParameter(name: "param2", description: "Second param", type: .int, isRequired: true),
                ToolParameter(name: "param3", description: "Third param", type: .bool, isRequired: false)
            ]
        )

        let arguments: [String: SendableValue] = [
            "param3": .bool(true)
        ]

        var caughtError = false
        do {
            try tool.validateArguments(arguments)
        } catch {
            caughtError = true
            // Should throw for the first missing required parameter it finds
        }

        #expect(caughtError)
    }

    // MARK: - requiredString

    @Test("requiredString extracts string value")
    func requiredStringSuccess() throws {
        let tool = MockTool(name: "test")
        let arguments: [String: SendableValue] = [
            "location": .string("San Francisco")
        ]

        let value = try tool.requiredString("location", from: arguments)

        #expect(value == "San Francisco")
    }

    @Test("requiredString throws when parameter is missing")
    func requiredStringMissing() {
        let tool = MockTool(name: "test")
        let arguments: [String: SendableValue] = [:]

        var thrownError: AgentError?
        do {
            _ = try tool.requiredString("location", from: arguments)
        } catch let error as AgentError {
            thrownError = error
        } catch {
            #expect(Bool(false), "Expected AgentError")
        }

        #expect(thrownError == .invalidToolArguments(
            toolName: "test",
            reason: "Missing or invalid string parameter: location"
        ))
    }

    @Test("requiredString throws when parameter is wrong type")
    func requiredStringWrongType() {
        let tool = MockTool(name: "test")
        let arguments: [String: SendableValue] = [
            "count": .int(42)
        ]

        var thrownError: AgentError?
        do {
            _ = try tool.requiredString("count", from: arguments)
        } catch let error as AgentError {
            thrownError = error
        } catch {
            #expect(Bool(false), "Expected AgentError")
        }

        #expect(thrownError == .invalidToolArguments(
            toolName: "test",
            reason: "Missing or invalid string parameter: count"
        ))
    }

    @Test("requiredString extracts from nested dictionary")
    func requiredStringFromDictionary() throws {
        let tool = MockTool(name: "test")
        let arguments: [String: SendableValue] = [
            "name": .string("Alice"),
            "age": .int(30),
            "active": .bool(true)
        ]

        let name = try tool.requiredString("name", from: arguments)

        #expect(name == "Alice")
    }

    // MARK: - optionalString

    @Test("optionalString returns string value when present")
    func optionalStringPresent() {
        let tool = MockTool(name: "test")
        let arguments: [String: SendableValue] = [
            "message": .string("Hello World")
        ]

        let value = tool.optionalString("message", from: arguments)

        #expect(value == "Hello World")
    }

    @Test("optionalString returns nil when parameter is missing")
    func optionalStringMissing() {
        let tool = MockTool(name: "test")
        let arguments: [String: SendableValue] = [:]

        let value = tool.optionalString("message", from: arguments)

        #expect(value == nil)
    }

    @Test("optionalString returns default value when parameter is missing")
    func optionalStringMissingWithDefault() {
        let tool = MockTool(name: "test")
        let arguments: [String: SendableValue] = [:]

        let value = tool.optionalString("units", from: arguments, default: "celsius")

        #expect(value == "celsius")
    }

    @Test("optionalString returns nil when parameter is wrong type")
    func optionalStringWrongType() {
        let tool = MockTool(name: "test")
        let arguments: [String: SendableValue] = [
            "count": .int(42)
        ]

        let value = tool.optionalString("count", from: arguments)

        #expect(value == nil)
    }

    @Test("optionalString returns default when parameter is wrong type")
    func optionalStringWrongTypeWithDefault() {
        let tool = MockTool(name: "test")
        let arguments: [String: SendableValue] = [
            "count": .int(42)
        ]

        let value = tool.optionalString("count", from: arguments, default: "defaultValue")

        #expect(value == "defaultValue")
    }

    @Test("optionalString with nil default explicitly")
    func optionalStringNilDefault() {
        let tool = MockTool(name: "test")
        let arguments: [String: SendableValue] = [:]

        let value = tool.optionalString("missing", from: arguments, default: nil)

        #expect(value == nil)
    }

    @Test("optionalString prefers actual value over default")
    func optionalStringPrefersActualValue() {
        let tool = MockTool(name: "test")
        let arguments: [String: SendableValue] = [
            "units": .string("fahrenheit")
        ]

        let value = tool.optionalString("units", from: arguments, default: "celsius")

        #expect(value == "fahrenheit")
    }
}
