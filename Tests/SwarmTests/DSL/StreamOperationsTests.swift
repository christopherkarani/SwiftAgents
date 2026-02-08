// StreamOperationsTests.swift
// SwarmTests
//
// Tests for stream operations DSL on AsyncThrowingStream<AgentEvent, Error>.

import Foundation
@testable import Swarm
import Testing

// MARK: - SideEffectCollector

actor SideEffectCollector {
    // MARK: Internal

    func append(_ effect: String) {
        effects.append(effect)
    }

    func getAll() -> [String] {
        effects
    }

    // MARK: Private

    private var effects: [String] = []
}

// MARK: - CompletionFlag

actor CompletionFlag {
    // MARK: Internal

    func markComplete() {
        completed = true
    }

    func isComplete() -> Bool {
        completed
    }

    // MARK: Private

    private var completed = false
}

// MARK: - StreamOperationsTests

@Suite("Stream Operations DSL Tests")
struct StreamOperationsTests {
    // MARK: - Filter Operations

    @Test("Filter stream by event type")
    func filterStreamByEventType() async throws {
        let events = makeTestEventStream([
            .started(input: "test"),
            .thinking(thought: "Analyzing..."),
            .thinking(thought: "Processing..."),
            .completed(result: makeTestResult("Done"))
        ])

        var thinkingEvents: [AgentEvent] = []
        for try await event in events.filterThinking() {
            thinkingEvents.append(event)
        }

        #expect(thinkingEvents.count == 2)
    }

    @Test("Filter stream with predicate")
    func filterStreamWithPredicate() async throws {
        let events = makeTestEventStream([
            .thinking(thought: "Short"),
            .thinking(thought: "This is a longer thought"),
            .thinking(thought: "Medium length")
        ])

        var filtered: [AgentEvent] = []
        for try await event in events.filter({ event in
            if case let .thinking(thought) = event {
                return thought.count > 10
            }
            return false
        }) {
            filtered.append(event)
        }

        #expect(filtered.count == 2)
    }

    // MARK: - Map Operations

    @Test("Map stream events to strings")
    func mapStreamEventsToStrings() async throws {
        let events = makeTestEventStream([
            .thinking(thought: "First thought"),
            .thinking(thought: "Second thought")
        ])

        var thoughts: [String] = []
        for try await thought in events.mapToThoughts() {
            thoughts.append(thought)
        }

        #expect(thoughts == ["First thought", "Second thought"])
    }

    @Test("Map stream with transform")
    func mapStreamWithTransform() async throws {
        let events = makeTestEventStream([
            .thinking(thought: "hello"),
            .thinking(thought: "world")
        ])

        var results: [String] = []
        for try await result in events.map({ event -> String in
            if case let .thinking(thought) = event {
                return thought.uppercased()
            }
            return ""
        }) {
            results.append(result)
        }

        #expect(results.contains("HELLO"))
        #expect(results.contains("WORLD"))
    }

    // MARK: - Collect Operations

    @Test("Collect all events")
    func collectAllEvents() async throws {
        let events = makeTestEventStream([
            .started(input: "test"),
            .thinking(thought: "Processing"),
            .completed(result: makeTestResult("Done"))
        ])

        let collected = try await events.collect()

        #expect(collected.count == 3)
    }

    @Test("Collect with limit")
    func collectWithLimit() async throws {
        let events = makeTestEventStream([
            .thinking(thought: "1"),
            .thinking(thought: "2"),
            .thinking(thought: "3"),
            .thinking(thought: "4"),
            .thinking(thought: "5")
        ])

        let collected = try await events.collect(maxCount: 3)

        #expect(collected.count == 3)
    }

    // MARK: - Extraction Operations

    @Test("Extract thoughts from stream")
    func extractThoughtsFromStream() async throws {
        let events = makeTestEventStream([
            .started(input: "test"),
            .thinking(thought: "First"),
            .thinking(thought: "Second"),
            .completed(result: makeTestResult("Done"))
        ])

        var thoughts: [String] = []
        for try await thought in events.thoughts {
            thoughts.append(thought)
        }

        #expect(thoughts == ["First", "Second"])
    }

    @Test("Extract tool calls from stream")
    func extractToolCallsFromStream() async throws {
        let toolCall1 = ToolCall(toolName: "calculator", arguments: ["expr": .string("2+2")])
        let toolCall2 = ToolCall(toolName: "weather", arguments: ["city": .string("NYC")])

        let events = makeTestEventStream([
            .started(input: "test"),
            .toolCallStarted(call: toolCall1),
            .thinking(thought: "Processing"),
            .toolCallStarted(call: toolCall2),
            .completed(result: makeTestResult("Done"))
        ])

        var toolCalls: [ToolCallInfo] = []
        for try await call in events.toolCalls {
            toolCalls.append(call)
        }

        #expect(toolCalls.count == 2)
        #expect(toolCalls[0].toolName == "calculator")
        #expect(toolCalls[1].toolName == "weather")
    }

    // MARK: - First/Last Operations

    @Test("Get first event of type")
    func getFirstEventOfType() async throws {
        let events = makeTestEventStream([
            .started(input: "test"),
            .thinking(thought: "First thinking"),
            .thinking(thought: "Second thinking")
        ])

        let first = try await events.first(where: { event in
            if case .thinking = event { return true }
            return false
        })

        if case let .thinking(thought) = first {
            #expect(thought == "First thinking")
        } else {
            Issue.record("Expected thinking event")
        }
    }

    @Test("Get last event")
    func getLastEvent() async throws {
        let events = makeTestEventStream([
            .started(input: "test"),
            .thinking(thought: "Processing"),
            .completed(result: makeTestResult("Final"))
        ])

        let last = try await events.last()

        if case let .completed(result) = last {
            #expect(result.output == "Final")
        } else {
            Issue.record("Expected completed event")
        }
    }

    // MARK: - Reduce Operations

    @Test("Reduce stream to single value")
    func reduceStreamToSingleValue() async throws {
        let events = makeTestEventStream([
            .thinking(thought: "A"),
            .thinking(thought: "B"),
            .thinking(thought: "C")
        ])

        let combined = try await events.reduce("") { acc, event in
            if case let .thinking(thought) = event {
                return acc + thought
            }
            return acc
        }

        #expect(combined == "ABC")
    }

    // MARK: - Take/Drop Operations

    @Test("Take first n events")
    func takeFirstNEvents() async throws {
        let events = makeTestEventStream([
            .thinking(thought: "1"),
            .thinking(thought: "2"),
            .thinking(thought: "3"),
            .thinking(thought: "4")
        ])

        var taken: [AgentEvent] = []
        for try await event in events.take(2) {
            taken.append(event)
        }

        #expect(taken.count == 2)
    }

    @Test("Drop first n events")
    func dropFirstNEvents() async throws {
        let events = makeTestEventStream([
            .thinking(thought: "1"),
            .thinking(thought: "2"),
            .thinking(thought: "3"),
            .thinking(thought: "4")
        ])

        var remaining: [AgentEvent] = []
        for try await event in events.drop(2) {
            remaining.append(event)
        }

        #expect(remaining.count == 2)
    }

    // MARK: - Timeout Operations

    @Test("Stream with timeout")
    func streamWithTimeout() async throws {
        let slowEvents = makeSlowEventStream(count: 10, delay: .milliseconds(100))

        var collected: [AgentEvent] = []
        do {
            for try await event in slowEvents.timeout(after: .milliseconds(250)) {
                collected.append(event)
            }
        } catch {
            // Timeout expected
        }

        // Should have collected some but not all events
        #expect(collected.count < 10)
    }

    // MARK: - Combine Streams

    @Test("Merge multiple streams")
    func mergeMultipleStreams() async throws {
        let stream1 = makeTestEventStream([.thinking(thought: "A")])
        let stream2 = makeTestEventStream([.thinking(thought: "B")])

        var collected: [AgentEvent] = []
        for try await event in AgentEventStream.merge(stream1, stream2) {
            collected.append(event)
        }

        #expect(collected.count == 2)
    }

    // MARK: - Side Effects

    @Test("On each event callback")
    func onEachEventCallback() async throws {
        let events = makeTestEventStream([
            .thinking(thought: "A"),
            .thinking(thought: "B")
        ])

        let collector = SideEffectCollector()
        let stream = events.onEach { event in
            if case let .thinking(thought) = event {
                Task { @Sendable in await collector.append(thought) }
            }
        }

        // Consume the stream
        for try await _ in stream {}

        // Allow spawned tasks to complete
        try await Task.sleep(for: .milliseconds(50))

        let sideEffects = await collector.getAll()
        #expect(sideEffects == ["A", "B"])
    }

    @Test("On complete callback")
    func onCompleteCallback() async throws {
        let events = makeTestEventStream([
            .started(input: "test"),
            .completed(result: makeTestResult("Done"))
        ])

        let completionFlag = CompletionFlag()
        let stream = events.onComplete { result in
            Task { @Sendable in
                await completionFlag.markComplete()
                #expect(result.output == "Done")
            }
        }

        // Consume the stream
        for try await _ in stream {}

        // Allow spawned task to complete
        try await Task.sleep(for: .milliseconds(50))

        let wasCompleted = await completionFlag.isComplete()
        #expect(wasCompleted)
    }

    // MARK: - Error Handling

    @Test("Catch errors in stream")
    func catchErrorsInStream() async throws {
        let failingStream = makeFailingEventStream(failAfter: 2)

        var collected: [AgentEvent] = []
        for try await event in failingStream.catchErrors { _ in
            // Return a fallback event
            .failed(error: .internalError(reason: "Recovered"))
        } {
            collected.append(event)
        }

        #expect(collected.count >= 2)
    }

    // MARK: - Debounce

    @Test("Debounce rapid events")
    func debounceRapidEvents() async throws {
        // Create rapidly firing events
        let events = makeRapidEventStream(count: 10, interval: .milliseconds(10))

        var collected: [AgentEvent] = []
        for try await event in events.debounce(for: .milliseconds(50)) {
            collected.append(event)
        }

        // Should have fewer events due to debouncing
        #expect(collected.count < 10)
    }
}

// MARK: - Test Helpers

func makeTestEventStream(_ events: [AgentEvent]) -> AsyncThrowingStream<AgentEvent, Error> {
    let (stream, continuation) = AsyncThrowingStream<AgentEvent, Error>.makeStream()
    Task { @Sendable in
        for event in events {
            continuation.yield(event)
        }
        continuation.finish()
    }
    return stream
}

func makeSlowEventStream(count: Int, delay: Duration) -> AsyncThrowingStream<AgentEvent, Error> {
    let (stream, continuation) = AsyncThrowingStream<AgentEvent, Error>.makeStream()
    Task { @Sendable in
        do {
            for i in 0..<count {
                try await Task.sleep(for: delay)
                continuation.yield(.thinking(thought: "Event \(i)"))
            }
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }
    return stream
}

func makeFailingEventStream(failAfter count: Int) -> AsyncThrowingStream<AgentEvent, Error> {
    let (stream, continuation) = AsyncThrowingStream<AgentEvent, Error>.makeStream()
    Task { @Sendable in
        for i in 0..<count {
            continuation.yield(.thinking(thought: "Event \(i)"))
        }
        continuation.finish(throwing: TestStreamError.intentionalFailure)
    }
    return stream
}

func makeRapidEventStream(count: Int, interval: Duration) -> AsyncThrowingStream<AgentEvent, Error> {
    let (stream, continuation) = AsyncThrowingStream<AgentEvent, Error>.makeStream()
    Task { @Sendable in
        do {
            for i in 0..<count {
                try await Task.sleep(for: interval)
                continuation.yield(.thinking(thought: "Rapid \(i)"))
            }
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }
    return stream
}

func makeTestResult(_ output: String) -> AgentResult {
    AgentResult(
        output: output,
        toolCalls: [],
        toolResults: [],
        iterationCount: 1,
        duration: .zero,
        tokenUsage: nil,
        metadata: [:]
    )
}

// MARK: - TestStreamError

enum TestStreamError: Error {
    case intentionalFailure
}
