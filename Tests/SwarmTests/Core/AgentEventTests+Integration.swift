// AgentEventTests+Integration.swift
// SwarmTests
//
// Integration tests for AgentEvent event sequences

import Foundation
@testable import Swarm
import Testing

// MARK: - Integration Tests

@Suite("AgentEvent Integration Tests")
struct AgentEventIntegrationTests {
    @Test("Complete event sequence")
    func completeEventSequence() {
        // Simulate a complete agent execution event sequence
        let events: [AgentEvent] = [
            .started(input: "Calculate 2+2"),
            .iterationStarted(number: 1),
            .thinking(thought: "I need to use the calculator"),
            .toolCallStarted(call: ToolCall(
                toolName: "calculator",
                arguments: ["expression": .string("2+2")]
            )),
            .toolCallCompleted(
                call: ToolCall(toolName: "calculator"),
                result: ToolResult.success(
                    callId: UUID(),
                    output: .int(4),
                    duration: .milliseconds(50)
                )
            ),
            .iterationCompleted(number: 1),
            .outputChunk(chunk: "The answer is 4"),
            .completed(result: AgentResult(output: "The answer is 4"))
        ]

        #expect(events.count == 8)

        // Verify first event is started
        if case let .started(input) = events[0] {
            #expect(input == "Calculate 2+2")
        } else {
            Issue.record("Expected first event to be .started")
        }

        // Verify last event is completed
        if case let .completed(result) = events[7] {
            #expect(result.output == "The answer is 4")
        } else {
            Issue.record("Expected last event to be .completed")
        }
    }

    @Test("Error event sequence")
    func errorEventSequence() {
        // Simulate an error during execution
        let events: [AgentEvent] = [
            .started(input: "Use invalid tool"),
            .iterationStarted(number: 1),
            .thinking(thought: "I'll call the missing tool"),
            .failed(error: .toolNotFound(name: "missing_tool"))
        ]

        #expect(events.count == 4)

        // Verify error event
        if case let .failed(error) = events[3] {
            #expect(error == .toolNotFound(name: "missing_tool"))
        } else {
            Issue.record("Expected .failed event")
        }
    }

    @Test("Streaming output sequence")
    func streamingOutputSequence() {
        // Simulate streaming token output
        let tokens = ["Hello", ", ", "world", "!"]
        var events: [AgentEvent] = [.started(input: "Say hello")]

        for token in tokens {
            events.append(.outputToken(token: token))
        }

        events.append(.completed(result: AgentResult(output: "Hello, world!")))

        #expect(events.count == 6) // 1 started + 4 tokens + 1 completed

        // Verify all tokens
        var collectedTokens: [String] = []
        for event in events {
            if case let .outputToken(token) = event {
                collectedTokens.append(token)
            }
        }

        #expect(collectedTokens == tokens)
    }

    @Test("Multi-iteration sequence")
    func multiIterationSequence() {
        // Simulate multiple reasoning iterations
        let events: [AgentEvent] = [
            .started(input: "Complex task"),
            .iterationStarted(number: 1),
            .thinking(thought: "First thought"),
            .iterationCompleted(number: 1),
            .iterationStarted(number: 2),
            .thinking(thought: "Second thought"),
            .iterationCompleted(number: 2),
            .iterationStarted(number: 3),
            .thinking(thought: "Final thought"),
            .iterationCompleted(number: 3),
            .completed(result: AgentResult(output: "Done", iterationCount: 3))
        ]

        #expect(events.count == 11)

        // Count iterations
        var iterationStarts = 0
        var iterationEnds = 0

        for event in events {
            if case .iterationStarted = event {
                iterationStarts += 1
            }
            if case .iterationCompleted = event {
                iterationEnds += 1
            }
        }

        #expect(iterationStarts == 3)
        #expect(iterationEnds == 3)
    }
}
