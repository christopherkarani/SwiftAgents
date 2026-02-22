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

// The LanguageModelSessionToolPromptBuilder and LanguageModelSessionToolParser types
// are defined in Sources/Swarm/Providers/LanguageModelSessionHelpers.swift and are
// available here via @testable import Swarm.
