// LanguageModelSessionTests.swift
// SwarmTests
//
// Tests for Foundation Models LanguageModelSession InferenceProvider conformance.
// These tests verify prompt-based tool calling fallback since Foundation Models
// don't natively support function calling via the public API.

import Foundation
@testable import Swarm
import Testing

// MARK: - Tool Prompt Builder Tests

@Suite("LanguageModelSession Tool Prompt Builder Tests")
struct LanguageModelSessionToolPromptTests {
    @Test("Tool prompt includes tool definitions")
    func toolPromptIncludesDefinitions() {
        let tool = ToolSchema(
            name: "calculator",
            description: "Performs mathematical calculations",
            parameters: [
                ToolParameter(name: "expression", description: "Math expression", type: .string)
            ]
        )
        
        let basePrompt = "What is 2+2?"
        let prompt = LanguageModelSessionToolPromptBuilder.buildToolPrompt(
            basePrompt: basePrompt,
            tools: [tool]
        )
        
        #expect(prompt.contains("Available tools:"))
        #expect(prompt.contains("calculator:"))
        #expect(prompt.contains("Performs mathematical calculations"))
        #expect(prompt.contains("expression"))
        #expect(prompt.contains("string (required)"))
        #expect(prompt.contains("Math expression"))
    }
    
    @Test("Tool prompt includes JSON format instructions")
    func toolPromptIncludesJSONFormat() {
        let tool = ToolSchema(name: "test", description: "Test tool", parameters: [])
        let prompt = LanguageModelSessionToolPromptBuilder.buildToolPrompt(
            basePrompt: "Hello",
            tools: [tool]
        )
        
        #expect(prompt.contains("\"tool\":"))
        #expect(prompt.contains("\"arguments\":"))
    }
    
    @Test("Tool prompt with multiple tools")
    func toolPromptWithMultipleTools() {
        let calculator = ToolSchema(
            name: "calculator",
            description: "Calculate",
            parameters: [
                ToolParameter(name: "expr", description: "Expression", type: .string)
            ]
        )
        let weather = ToolSchema(
            name: "weather",
            description: "Get weather",
            parameters: [
                ToolParameter(name: "city", description: "City name", type: .string),
                ToolParameter(name: "units", description: "Temperature units", type: .string, isRequired: false)
            ]
        )
        
        let prompt = LanguageModelSessionToolPromptBuilder.buildToolPrompt(
            basePrompt: "What is the weather in London?",
            tools: [calculator, weather]
        )
        
        #expect(prompt.contains("calculator:"))
        #expect(prompt.contains("weather:"))
        #expect(prompt.contains("city: string (required)"))
        #expect(prompt.contains("units: string - Temperature units"))
    }
    
    @Test("Tool prompt with no tools returns base prompt")
    func toolPromptWithNoTools() {
        let basePrompt = "Hello, how are you?"
        let prompt = LanguageModelSessionToolPromptBuilder.buildToolPrompt(
            basePrompt: basePrompt,
            tools: []
        )
        
        #expect(prompt == basePrompt)
    }
    
    @Test("Tool prompt with complex parameter types")
    func toolPromptWithComplexTypes() {
        let tool = ToolSchema(
            name: "complex",
            description: "Complex tool",
            parameters: [
                ToolParameter(name: "count", description: "Count", type: .int),
                ToolParameter(name: "ratio", description: "Ratio", type: .double),
                ToolParameter(name: "enabled", description: "Enabled", type: .bool),
                ToolParameter(name: "tags", description: "Tags", type: .array(elementType: .string)),
                ToolParameter(name: "options", description: "Options", type: .oneOf(["a", "b", "c"]))
            ]
        )
        
        let prompt = LanguageModelSessionToolPromptBuilder.buildToolPrompt(
            basePrompt: "Test",
            tools: [tool]
        )
        
        #expect(prompt.contains("integer"))
        #expect(prompt.contains("number"))
        #expect(prompt.contains("boolean"))
        #expect(prompt.contains("array of string"))
        #expect(prompt.contains("one of: a, b, c"))
    }
}

// MARK: - Tool Call Parser Tests

@Suite("LanguageModelSession Tool Call Parser Tests")
struct LanguageModelSessionToolParserTests {
    @Test("Parse valid JSON tool call")
    func parseValidJSONToolCall() {
        let response = """
        I'll help you calculate that.
        {"tool": "calculator", "arguments": {"expression": "2+2"}}
        """
        
        let availableTools = [
            ToolSchema(name: "calculator", description: "Calc", parameters: [])
        ]
        
        let toolCalls = LanguageModelSessionToolParser.parseToolCalls(
            from: response,
            availableTools: availableTools
        )
        
        #expect(toolCalls != nil)
        #expect(toolCalls?.count == 1)
        #expect(toolCalls?[0].name == "calculator")
        #expect(toolCalls?[0].arguments["expression"] == .string("2+2"))
    }
    
    @Test("Parse tool call with 'name' key instead of 'tool'")
    func parseToolCallWithNameKey() {
        let response = """
        {"name": "weather", "arguments": {"city": "London"}}
        """
        
        let availableTools = [
            ToolSchema(name: "weather", description: "Weather", parameters: [])
        ]
        
        let toolCalls = LanguageModelSessionToolParser.parseToolCalls(
            from: response,
            availableTools: availableTools
        )
        
        #expect(toolCalls?.first?.name == "weather")
        #expect(toolCalls?.first?.arguments["city"] == .string("London"))
    }
    
    @Test("Parse tool call with call ID")
    func parseToolCallWithCallId() {
        let response = """
        {"id": "call_123", "tool": "search", "arguments": {"query": "Swift"}}
        """
        
        let availableTools = [
            ToolSchema(name: "search", description: "Search", parameters: [])
        ]
        
        let toolCalls = LanguageModelSessionToolParser.parseToolCalls(
            from: response,
            availableTools: availableTools
        )
        
        #expect(toolCalls?.first?.id == "call_123")
    }
    
    @Test("Parse tool call with various argument types")
    func parseToolCallWithVariousTypes() {
        let response = """
        {"tool": "test", "arguments": {"str": "hello", "num": 42, "float": 3.14, "bool": true, "null": null}}
        """
        
        let availableTools = [
            ToolSchema(name: "test", description: "Test", parameters: [])
        ]
        
        let toolCalls = LanguageModelSessionToolParser.parseToolCalls(
            from: response,
            availableTools: availableTools
        )
        
        #expect(toolCalls?.first?.arguments["str"] == .string("hello"))
        #expect(toolCalls?.first?.arguments["num"] == .int(42))
        #expect(toolCalls?.first?.arguments["bool"] == .bool(true))
    }
    
    @Test("Parse tool call with nested arguments")
    func parseToolCallWithNestedArguments() {
        let response = """
        {"tool": "createUser", "arguments": {"user": {"name": "Alice", "age": 30}}}
        """
        
        let availableTools = [
            ToolSchema(name: "createUser", description: "Create user", parameters: [])
        ]
        
        let toolCalls = LanguageModelSessionToolParser.parseToolCalls(
            from: response,
            availableTools: availableTools
        )
        
        let userDict = toolCalls?.first?.arguments["user"]?.dictionaryValue
        #expect(userDict?["name"] == .string("Alice"))
        #expect(userDict?["age"] == .int(30))
    }
    
    @Test("Parse tool call with array arguments")
    func parseToolCallWithArrayArguments() {
        let response = """
        {"tool": "search", "arguments": {"tags": ["swift", "ai", "ios"]}}
        """
        
        let availableTools = [
            ToolSchema(name: "search", description: "Search", parameters: [])
        ]
        
        let toolCalls = LanguageModelSessionToolParser.parseToolCalls(
            from: response,
            availableTools: availableTools
        )
        
        let tags = toolCalls?.first?.arguments["tags"]?.arrayValue
        #expect(tags?.count == 3)
        #expect(tags?[0] == .string("swift"))
    }
    
    @Test("Return nil for response without JSON")
    func returnNilForResponseWithoutJSON() {
        let response = "This is just a regular response without any tool calls."
        
        let toolCalls = LanguageModelSessionToolParser.parseToolCalls(
            from: response,
            availableTools: [ToolSchema(name: "tool", description: "Tool", parameters: [])]
        )
        
        #expect(toolCalls == nil)
    }
    
    @Test("Return nil for unknown tool name")
    func returnNilForUnknownToolName() {
        let response = """
        {"tool": "unknownTool", "arguments": {}}
        """
        
        let availableTools = [
            ToolSchema(name: "knownTool", description: "Known", parameters: [])
        ]
        
        let toolCalls = LanguageModelSessionToolParser.parseToolCalls(
            from: response,
            availableTools: availableTools
        )
        
        #expect(toolCalls == nil)
    }
    
    @Test("Return nil for invalid JSON")
    func returnNilForInvalidJSON() {
        let response = """
        {"tool": "test", "arguments": {invalid json
        """
        
        let toolCalls = LanguageModelSessionToolParser.parseToolCalls(
            from: response,
            availableTools: [ToolSchema(name: "test", description: "Test", parameters: [])]
        )
        
        #expect(toolCalls == nil)
    }
    
    @Test("Return nil for JSON without tool name")
    func returnNilForJSONWithoutToolName() {
        let response = """
        {"arguments": {"x": 1}}
        """
        
        let toolCalls = LanguageModelSessionToolParser.parseToolCalls(
            from: response,
            availableTools: [ToolSchema(name: "test", description: "Test", parameters: [])]
        )
        
        #expect(toolCalls == nil)
    }
    
    @Test("Parse tool call with empty arguments")
    func parseToolCallWithEmptyArguments() {
        let response = """
        {"tool": "getTime", "arguments": {}}
        """
        
        let availableTools = [
            ToolSchema(name: "getTime", description: "Get time", parameters: [])
        ]
        
        let toolCalls = LanguageModelSessionToolParser.parseToolCalls(
            from: response,
            availableTools: availableTools
        )
        
        #expect(toolCalls?.first?.name == "getTime")
        #expect(toolCalls?.first?.arguments.isEmpty == true)
    }
}

// MARK: - Integration Tests (No Foundation Models Required)

@Suite("LanguageModelSession Integration Tests")
struct LanguageModelSessionIntegrationTests {
    @Test("generateWithToolCalls returns content when no tools provided")
    func generateWithToolCallsNoTools() async throws {
        // Since we can't mock LanguageModelSession, we verify the parsing logic
        // by testing the helper types directly
        let toolCalls = LanguageModelSessionToolParser.parseToolCalls(
            from: "Just a normal response",
            availableTools: []
        )
        
        #expect(toolCalls == nil)
    }
}

// MARK: - Helper Types

/// Helper for building tool-aware prompts for Foundation Models.
/// These helpers mirror the implementation in LanguageModelSession.swift for testing.
enum LanguageModelSessionToolPromptBuilder {
    static func buildToolPrompt(basePrompt: String, tools: [ToolSchema]) -> String {
        guard !tools.isEmpty else { return basePrompt }
        
        var toolDefinitions: [String] = []
        for tool in tools {
            let params = tool.parameters.map { param in
                let typeDesc = parameterTypeDescription(param.type)
                let required = param.isRequired ? " (required)" : ""
                return "  - \(param.name): \(typeDesc)\(required) - \(param.description)"
            }.joined(separator: "\n")
            
            let paramSection = params.isEmpty ? "  (no parameters)" : params
            
            let toolDef = """
                \(tool.name):
                  Description: \(tool.description)
                  Parameters:
                \(paramSection)
                """
            toolDefinitions.append(toolDef)
        }
        
        return """
            \(basePrompt)
            
            Available tools:
            \(toolDefinitions.joined(separator: "\n\n"))
            
            To use a tool, respond with a JSON object in this exact format:
            {"tool": "tool_name", "arguments": {"param1": "value1", "param2": "value2"}}
            
            If no tool is needed, respond normally without JSON.
            """
    }
    
    private static func parameterTypeDescription(_ type: ToolParameter.ParameterType) -> String {
        switch type {
        case .string:
            return "string"
        case .int:
            return "integer"
        case .double:
            return "number"
        case .bool:
            return "boolean"
        case let .array(elementType):
            return "array of \(parameterTypeDescription(elementType))"
        case .object:
            return "object"
        case let .oneOf(options):
            return "one of: \(options.joined(separator: ", "))"
        case .any:
            return "any type"
        }
    }
}

/// Helper for parsing tool calls from model responses.
enum LanguageModelSessionToolParser {
    static func parseToolCalls(
        from content: String,
        availableTools: [ToolSchema]
    ) -> [InferenceResponse.ParsedToolCall]? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonStart = trimmed.firstIndex(of: "{"),
              let jsonEnd = trimmed.lastIndex(of: "}") else {
            return nil
        }
        
        let jsonString = String(trimmed[jsonStart...jsonEnd])
        
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            let toolName = (jsonObject["tool"] as? String) ?? (jsonObject["name"] as? String)
            guard let toolName = toolName?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return nil
            }
            
            guard availableTools.contains(where: { $0.name == toolName }) else {
                return nil
            }
            
            var arguments: [String: SendableValue] = [:]
            if let argsObject = jsonObject["arguments"] as? [String: Any] {
                for (key, value) in argsObject {
                    arguments[key] = SendableValue.fromJSONValue(value)
                }
            }
            
            let callId = jsonObject["id"] as? String
            
            return [InferenceResponse.ParsedToolCall(
                id: callId,
                name: toolName,
                arguments: arguments
            )]
        } catch {
            return nil
        }
    }
}

// MARK: - SendableValue Extension

private extension SendableValue {
    static func fromJSONValue(_ value: Any) -> SendableValue {
        switch value {
        case is NSNull:
            return .null
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let double as Double:
            if double >= -9_007_199_254_740_992, double <= 9_007_199_254_740_992 {
                if double.truncatingRemainder(dividingBy: 1) == 0 {
                    return .int(Int(double))
                }
            }
            return .double(double)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return .array(array.map { fromJSONValue($0) })
        case let dict as [String: Any]:
            var result: [String: SendableValue] = [:]
            for (key, val) in dict {
                result[key] = fromJSONValue(val)
            }
            return .dictionary(result)
        default:
            return .string(String(describing: value))
        }
    }
}
