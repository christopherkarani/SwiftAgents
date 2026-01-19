// StreamingEventTests.swift
// SwiftAgentsTests
//
// Tests for streaming events in agents.

import Foundation
@testable import SwiftAgents
import Testing

@Suite("Streaming Event Tests")
struct StreamingEventTests {
    
    @Test("ReActAgent stream emits thinking and tool call events")
    func reactAgentStreamEvents() async throws {
        // 1. Setup mock provider for a tool call sequence
        let mockProvider = MockInferenceProvider()
        await mockProvider.configureReActSequence(
            toolCalls: [("test_tool", "arg: 1")],
            finalAnswer: "Done"
        )
        
        // 2. Setup agent with a mock tool
        let tool = MockTool(name: "test_tool", description: "Test tool")
        let agent = ReActAgent(
            tools: [tool],
            instructions: "You are a test assistant.",
            inferenceProvider: mockProvider
        )
        
        // 3. Collect events from stream
        var events: [AgentEvent] = []
        for try await event in agent.stream("Start") {
            events.append(event)
        }
        
        // 4. Verify events
        // Expected sequence:
        // .started
        // .iterationStarted(1)
        // .llmStarted (from run hooks)
        // .llmCompleted (from run hooks)
        // .toolCallStarted
        // .iterationCompleted(1)
        // .iterationStarted(2)
        // .thinking
        // .iterationCompleted(2)
        // .completed
        
        #expect(events.contains { if case .started = $0 { return true }; return false })
        #expect(events.contains { if case .iterationStarted(let n) = $0 { return n == 1 }; return false })
        #expect(events.contains { if case .toolCallStarted(let call) = $0 { return call.toolName == "test_tool" }; return false })
        #expect(events.contains { if case .thinking = $0 { return true }; return false })
        #expect(events.contains { if case .completed = $0 { return true }; return false })
    }
    
    @Test("ToolCallingAgent stream emits iteration events")
    func toolCallingAgentStreamEvents() async throws {
        // 1. Setup mock provider (ToolCallingAgent uses generateWithToolCalls)
        let mockProvider = MockInferenceProvider()
        await mockProvider.setResponses(["Final answer directly"])
        
        // 2. Setup agent
        let agent = ToolCallingAgent(
            tools: [],
            instructions: "You are a test assistant.",
            inferenceProvider: mockProvider
        )
        
        // 3. Collect events from stream
        var events: [AgentEvent] = []
        for try await event in agent.stream("Start") {
            events.append(event)
        }
        
        // 4. Verify events
        #expect(events.contains { if case .started = $0 { return true }; return false })
        #expect(events.contains { if case .iterationStarted(let n) = $0 { return n == 1 }; return false })
        #expect(events.contains { if case .completed = $0 { return true }; return false })
    }
}
