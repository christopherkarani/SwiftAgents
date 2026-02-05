// AgentEventTests.swift
// SwarmTests
//
// Comprehensive tests for AgentEvent, ToolCall, and ToolResult types.

import Foundation
@testable import Swarm
import Testing

// MARK: - AgentEvent Tests

@Suite("AgentEvent Tests")
struct AgentEventTests {
    // MARK: - Lifecycle Events

    @Test("AgentEvent.started creation")
    func startedEventCreation() {
        let event = AgentEvent.started(input: "What is 2+2?")

        // Verify the event can be pattern-matched
        if case let .started(input) = event {
            #expect(input == "What is 2+2?")
        } else {
            Issue.record("Expected .started event")
        }
    }

    @Test("AgentEvent.completed creation")
    func completedEventCreation() {
        let result = AgentResult(
            output: "The answer is 4",
            iterationCount: 2,
            duration: .seconds(1)
        )

        let event = AgentEvent.completed(result: result)

        // Verify the event can be pattern-matched
        if case let .completed(capturedResult) = event {
            #expect(capturedResult.output == "The answer is 4")
            #expect(capturedResult.iterationCount == 2)
        } else {
            Issue.record("Expected .completed event")
        }
    }

    @Test("AgentEvent.failed creation")
    func failedEventCreation() {
        let error = AgentError.toolNotFound(name: "calculator")
        let event = AgentEvent.failed(error: error)

        // Verify the event can be pattern-matched
        if case let .failed(capturedError) = event {
            #expect(capturedError == error)
        } else {
            Issue.record("Expected .failed event")
        }
    }

    @Test("AgentEvent.cancelled creation")
    func cancelledEventCreation() {
        let event = AgentEvent.cancelled

        // Verify the event can be pattern-matched
        if case .cancelled = event {
            // Success
        } else {
            Issue.record("Expected .cancelled event")
        }
    }

    // MARK: - Thinking Events

    @Test("AgentEvent.thinking creation")
    func thinkingEventCreation() {
        let event = AgentEvent.thinking(thought: "I need to calculate 2+2")

        // Verify the event can be pattern-matched
        if case let .thinking(thought) = event {
            #expect(thought == "I need to calculate 2+2")
        } else {
            Issue.record("Expected .thinking event")
        }
    }

    @Test("AgentEvent.thinkingPartial creation")
    func thinkingPartialEventCreation() {
        let event = AgentEvent.thinkingPartial(partialThought: "I need to")

        // Verify the event can be pattern-matched
        if case let .thinkingPartial(partial) = event {
            #expect(partial == "I need to")
        } else {
            Issue.record("Expected .thinkingPartial event")
        }
    }

    // MARK: - Tool Events

    @Test("AgentEvent.toolCallStarted creation")
    func toolCallStartedEventCreation() {
        let toolCall = ToolCall(
            toolName: "calculator",
            arguments: ["expression": .string("2+2")]
        )

        let event = AgentEvent.toolCallStarted(call: toolCall)

        // Verify the event can be pattern-matched
        if case let .toolCallStarted(call) = event {
            #expect(call.toolName == "calculator")
            #expect(call.arguments["expression"] == .string("2+2"))
        } else {
            Issue.record("Expected .toolCallStarted event")
        }
    }

    @Test("AgentEvent.toolCallCompleted creation")
    func toolCallCompletedEventCreation() {
        let toolCall = ToolCall(
            toolName: "calculator",
            arguments: ["expression": .string("2+2")]
        )

        let result = ToolResult.success(
            callId: toolCall.id,
            output: .int(4),
            duration: .milliseconds(100)
        )

        let event = AgentEvent.toolCallCompleted(call: toolCall, result: result)

        // Verify the event can be pattern-matched
        if case let .toolCallCompleted(call, capturedResult) = event {
            #expect(call.toolName == "calculator")
            #expect(capturedResult.isSuccess == true)
            #expect(capturedResult.output == .int(4))
        } else {
            Issue.record("Expected .toolCallCompleted event")
        }
    }

    @Test("AgentEvent.toolCallFailed creation")
    func toolCallFailedEventCreation() {
        let toolCall = ToolCall(
            toolName: "calculator",
            arguments: ["expression": .string("invalid")]
        )

        let error = AgentError.toolExecutionFailed(
            toolName: "calculator",
            underlyingError: "Invalid expression"
        )

        let event = AgentEvent.toolCallFailed(call: toolCall, error: error)

        // Verify the event can be pattern-matched
        if case let .toolCallFailed(call, capturedError) = event {
            #expect(call.toolName == "calculator")
            #expect(capturedError == error)
        } else {
            Issue.record("Expected .toolCallFailed event")
        }
    }

    // MARK: - Output Events

    @Test("AgentEvent.outputToken creation")
    func outputTokenEventCreation() {
        let event = AgentEvent.outputToken(token: "Hello")

        // Verify the event can be pattern-matched
        if case let .outputToken(token) = event {
            #expect(token == "Hello")
        } else {
            Issue.record("Expected .outputToken event")
        }
    }

    @Test("AgentEvent.outputChunk creation")
    func outputChunkEventCreation() {
        let event = AgentEvent.outputChunk(chunk: "Hello, world!")

        // Verify the event can be pattern-matched
        if case let .outputChunk(chunk) = event {
            #expect(chunk == "Hello, world!")
        } else {
            Issue.record("Expected .outputChunk event")
        }
    }

    // MARK: - Iteration Events

    @Test("AgentEvent.iterationStarted creation")
    func iterationStartedEventCreation() {
        let event = AgentEvent.iterationStarted(number: 1)

        // Verify the event can be pattern-matched
        if case let .iterationStarted(number) = event {
            #expect(number == 1)
        } else {
            Issue.record("Expected .iterationStarted event")
        }
    }

    @Test("AgentEvent.iterationCompleted creation")
    func iterationCompletedEventCreation() {
        let event = AgentEvent.iterationCompleted(number: 5)

        // Verify the event can be pattern-matched
        if case let .iterationCompleted(number) = event {
            #expect(number == 5)
        } else {
            Issue.record("Expected .iterationCompleted event")
        }
    }

    // MARK: - All Event Cases

    @Test("All AgentEvent cases are Sendable")
    func allEventCasesAreSendable() {
        // This test verifies compilation - all events should conform to Sendable
        let events: [AgentEvent] = [
            .started(input: "test"),
            .completed(result: AgentResult(output: "done")),
            .failed(error: .cancelled),
            .cancelled,
            .thinking(thought: "thinking"),
            .thinkingPartial(partialThought: "think"),
            .toolCallStarted(call: ToolCall(toolName: "test")),
            .toolCallCompleted(
                call: ToolCall(toolName: "test"),
                result: ToolResult.success(callId: UUID(), output: .null, duration: .zero)
            ),
            .toolCallFailed(call: ToolCall(toolName: "test"), error: .cancelled),
            .outputToken(token: "hi"),
            .outputChunk(chunk: "hello"),
            .iterationStarted(number: 1),
            .iterationCompleted(number: 1)
        ]

        #expect(events.count == 13)
    }
}
