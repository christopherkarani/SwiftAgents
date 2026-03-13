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
            .lifecycle(.started(input: "Calculate 2+2")),
            .lifecycle(.iterationStarted(number: 1)),
            .output(.thinking(thought: "I need to use the calculator")),
            .tool(.started(call: ToolCall(
                toolName: "calculator",
                arguments: ["expression": .string("2+2")]
            ))),
            .tool(.completed(
                call: ToolCall(toolName: "calculator"),
                result: ToolResult.success(
                    callId: UUID(),
                    output: .int(4),
                    duration: .milliseconds(50)
                )
            )),
            .lifecycle(.iterationCompleted(number: 1)),
            .output(.chunk("The answer is 4")),
            .lifecycle(.completed(result: AgentResult(output: "The answer is 4")))
        ]

        #expect(events.count == 8)

        // Verify first event is started
        if case let .lifecycle(.started(input: input)) = events[0] {
            #expect(input == "Calculate 2+2")
        } else {
            Issue.record("Expected first event to be .lifecycle(.started)")
        }

        // Verify last event is completed
        if case let .lifecycle(.completed(result: result)) = events[7] {
            #expect(result.output == "The answer is 4")
        } else {
            Issue.record("Expected last event to be .lifecycle(.completed)")
        }
    }

    @Test("Error event sequence")
    func errorEventSequence() {
        // Simulate an error during execution
        let events: [AgentEvent] = [
            .lifecycle(.started(input: "Use invalid tool")),
            .lifecycle(.iterationStarted(number: 1)),
            .output(.thinking(thought: "I'll call the missing tool")),
            .lifecycle(.failed(error: .toolNotFound(name: "missing_tool")))
        ]

        #expect(events.count == 4)

        // Verify error event
        if case let .lifecycle(.failed(error: error)) = events[3] {
            #expect(error == .toolNotFound(name: "missing_tool"))
        } else {
            Issue.record("Expected .lifecycle(.failed) event")
        }
    }

    @Test("Streaming output sequence")
    func streamingOutputSequence() {
        // Simulate streaming token output
        let tokens = ["Hello", ", ", "world", "!"]
        var events: [AgentEvent] = [.lifecycle(.started(input: "Say hello"))]

        for token in tokens {
            events.append(.output(.token(token)))
        }

        events.append(.lifecycle(.completed(result: AgentResult(output: "Hello, world!"))))

        #expect(events.count == 6) // 1 started + 4 tokens + 1 completed

        // Verify all tokens
        var collectedTokens: [String] = []
        for event in events {
            if case let .output(.token(token)) = event {
                collectedTokens.append(token)
            }
        }

        #expect(collectedTokens == tokens)
    }

    @Test("Multi-iteration sequence")
    func multiIterationSequence() {
        // Simulate multiple reasoning iterations
        let events: [AgentEvent] = [
            .lifecycle(.started(input: "Complex task")),
            .lifecycle(.iterationStarted(number: 1)),
            .output(.thinking(thought: "First thought")),
            .lifecycle(.iterationCompleted(number: 1)),
            .lifecycle(.iterationStarted(number: 2)),
            .output(.thinking(thought: "Second thought")),
            .lifecycle(.iterationCompleted(number: 2)),
            .lifecycle(.iterationStarted(number: 3)),
            .output(.thinking(thought: "Final thought")),
            .lifecycle(.iterationCompleted(number: 3)),
            .lifecycle(.completed(result: AgentResult(output: "Done", iterationCount: 3)))
        ]

        #expect(events.count == 11)

        // Count iterations
        var iterationStarts = 0
        var iterationEnds = 0

        for event in events {
            if case .lifecycle(.iterationStarted) = event {
                iterationStarts += 1
            }
            if case .lifecycle(.iterationCompleted) = event {
                iterationEnds += 1
            }
        }

        #expect(iterationStarts == 3)
        #expect(iterationEnds == 3)
    }
}
