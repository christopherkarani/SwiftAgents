// AgentTests.swift
// SwiftAgentsTests
//
// Tests for agent implementations.

import Foundation
@testable import SwiftAgents
import Testing

// MARK: - ReActAgentTests

@Suite("ReActAgent Tests")
struct ReActAgentTests {
    @Test("Simple query returns final answer")
    func simpleQuery() async throws {
        // Create a mock provider that immediately returns a final answer
        let mockProvider = MockInferenceProvider(responses: [
            "Final Answer: 42"
        ])

        // Create agent with the mock provider
        let agent = ReActAgent(
            tools: [],
            instructions: "You are a helpful assistant.",
            inferenceProvider: mockProvider
        )

        // Run the agent
        let result = try await agent.run("What is the answer?")

        // Verify the output
        #expect(result.output == "42")
        #expect(result.iterationCount == 1)
        #expect(await mockProvider.generateCallCount == 1)
    }

    @Test("Tool call execution")
    func toolCallExecution() async throws {
        // Create a spy tool to verify it gets called
        let spyTool = await SpyTool(
            name: "test_tool",
            result: .string("Tool result")
        )

        // Create mock provider that first calls the tool, then provides final answer
        let mockProvider = MockInferenceProvider(responses: [
            "Thought: I need to use the test_tool.\nAction: test_tool()",
            "Final Answer: The tool returned: Tool result"
        ])

        // Create agent with the spy tool
        let agent = ReActAgent(
            tools: [spyTool],
            instructions: "You are a helpful assistant.",
            inferenceProvider: mockProvider
        )

        // Run the agent
        let result = try await agent.run("Use the tool")

        // Verify the tool was called
        let callCount = await spyTool.callCount
        #expect(callCount == 1)

        // Verify the final answer
        #expect(result.output.contains("Tool result"))
        #expect(result.toolCalls.count == 1)
        #expect(result.toolCalls[0].toolName == "test_tool")
    }

    @Test("Native tool calling executes provider tool calls")
    func nativeToolCallingExecutesToolCalls() async throws {
        let spyTool = await SpyTool(
            name: "test_tool",
            result: .string("Tool result")
        )

        let mockProvider = MockInferenceProvider()
        await mockProvider.setToolCallResponses([
            InferenceResponse(
                content: nil,
                toolCalls: [
                    InferenceResponse.ParsedToolCall(
                        id: "call_123",
                        name: "test_tool",
                        arguments: ["location": .string("NYC")]
                    )
                ],
                finishReason: .toolCall,
                usage: nil
            ),
            InferenceResponse(
                content: "Final Answer: Done",
                toolCalls: [],
                finishReason: .completed,
                usage: nil
            )
        ])

        let config = AgentConfiguration.default
            .modelSettings(ModelSettings.default.toolChoice(.required))

        let agent = ReActAgent(
            tools: [spyTool],
            instructions: "You are a helpful assistant.",
            configuration: config,
            inferenceProvider: mockProvider
        )

        let result = try await agent.run("Use the tool")

        #expect(result.output == "Done")
        #expect(result.toolCalls.count == 1)
        #expect(result.toolCalls[0].providerCallId == "call_123")

        #expect(await spyTool.callCount == 1)
        #expect(await spyTool.wasCalledWith(argument: "location", value: .string("NYC")))

        let recordedToolCalls = await mockProvider.toolCallCalls
        #expect(recordedToolCalls.count == 2)
        #expect(recordedToolCalls.first?.options.toolChoice == .required)
        #expect(recordedToolCalls.first?.tools.contains { $0.name == "test_tool" } == true)
    }

    @Test("Max iterations exceeded")
    func maxIterationsExceeded() async {
        // Create mock provider that never provides a final answer
        let mockProvider = MockInferenceProvider()
        await mockProvider.configureInfiniteThinking(thoughts: ["Still thinking..."])

        // Create agent with maxIterations=1
        let config = AgentConfiguration.default.maxIterations(1)
        let agent = ReActAgent(
            tools: [],
            instructions: "You are a helpful assistant.",
            configuration: config,
            inferenceProvider: mockProvider
        )

        // Verify that maxIterationsExceeded error is thrown
        do {
            _ = try await agent.run("Think forever")
            Issue.record("Expected maxIterationsExceeded error but succeeded")
        } catch let error as AgentError {
            switch error {
            case let .maxIterationsExceeded(iterations):
                #expect(iterations == 1)
            default:
                Issue.record("Expected maxIterationsExceeded but got: \(error)")
            }
        } catch {
            Issue.record("Expected AgentError but got: \(error)")
        }
    }
}

// MARK: - BuiltInToolsTests

@Suite("Built-in Tools Tests")
struct BuiltInToolsTests {
    #if canImport(Darwin)
        @Test("Calculator tool")
        func calculatorTool() async throws {
            var calculator = CalculatorTool()

            // Test basic arithmetic with operator precedence
            let result = try await calculator.execute(arguments: [
                "expression": .string("2+3*4")
            ])

            // Verify result (3*4=12, 12+2=14)
            #expect(result == .double(14.0))
        }
    #endif

    @Test("DateTime tool")
    func dateTimeTool() async throws {
        var dateTime = DateTimeTool()

        // Test unix timestamp format
        let result = try await dateTime.execute(arguments: [
            "format": .string("unix")
        ])

        // Verify we get a double (unix timestamp)
        switch result {
        case let .double(timestamp):
            // Verify it's a reasonable timestamp (not zero, not too far in the past/future)
            #expect(timestamp > 0)
            #expect(timestamp < Date.distantFuture.timeIntervalSince1970)
        default:
            Issue.record("Expected double result but got: \(result)")
        }
    }

    @Test("String tool")
    func stringTool() async throws {
        var stringTool = StringTool()

        // Test uppercase operation
        let result = try await stringTool.execute(arguments: [
            "operation": .string("uppercase"),
            "input": .string("hello")
        ])

        // Verify result
        #expect(result == .string("HELLO"))
    }
}

// MARK: - ToolRegistryTests

@Suite("Tool Registry Tests")
struct ToolRegistryTests {
    @Test("Register and lookup tools")
    func registerAndLookup() async {
        // Create an empty registry
        let registry = ToolRegistry()

        // Verify it's empty
        let initialCount = await registry.count
        #expect(initialCount == 0)

        // Create and register a mock tool
        let mockTool = MockTool(name: "test_tool", description: "A test tool")
        await registry.register(mockTool)

        // Verify the tool was registered
        let afterRegisterCount = await registry.count
        #expect(afterRegisterCount == 1)

        // Lookup the tool
        let lookedUpTool = await registry.tool(named: "test_tool")
        #expect(lookedUpTool != nil)
        #expect(lookedUpTool?.name == "test_tool")

        // Verify contains
        let contains = await registry.contains(named: "test_tool")
        #expect(contains == true)

        // Unregister the tool
        await registry.unregister(named: "test_tool")

        // Verify it was removed
        let afterUnregisterCount = await registry.count
        #expect(afterUnregisterCount == 0)

        let notFound = await registry.tool(named: "test_tool")
        #expect(notFound == nil)
    }
}
