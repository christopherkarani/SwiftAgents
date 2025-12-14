// StreamOperationsTests.swift
// SwiftAgentsTests
//
// Tests for stream operations DSL on AsyncThrowingStream<AgentEvent, Error>.

import Testing
import Foundation
@testable import SwiftAgents

// MARK: - Stream Operations Tests

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
            if case .thinking(let thought) = event {
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
            if case .thinking(let thought) = event {
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
        let toolCall1 = ToolCallInfo(toolName: "calculator", arguments: ["expr": .string("2+2")], result: .string("4"))
        let toolCall2 = ToolCallInfo(toolName: "weather", arguments: ["city": .string("NYC")], result: .string("72F"))

        let events = makeTestEventStream([
            .started(input: "test"),
            .toolCall(call: toolCall1),
            .thinking(thought: "Processing"),
            .toolCall(call: toolCall2),
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

        if case .thinking(let thought) = first {
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

        if case .completed(let result) = last {
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
            if case .thinking(let thought) = event {
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

        var sideEffects: [String] = []
        let stream = events.onEach { event in
            if case .thinking(let thought) = event {
                sideEffects.append(thought)
            }
        }

        // Consume the stream
        for try await _ in stream {}

        #expect(sideEffects == ["A", "B"])
    }

    @Test("On complete callback")
    func onCompleteCallback() async throws {
        let events = makeTestEventStream([
            .started(input: "test"),
            .completed(result: makeTestResult("Done"))
        ])

        var completionCalled = false
        let stream = events.onComplete { result in
            completionCalled = true
            #expect(result.output == "Done")
        }

        // Consume the stream
        for try await _ in stream {}

        #expect(completionCalled)
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
    AsyncThrowingStream { continuation in
        for event in events {
            continuation.yield(event)
        }
        continuation.finish()
    }
}

func makeSlowEventStream(count: Int, delay: Duration) -> AsyncThrowingStream<AgentEvent, Error> {
    AsyncThrowingStream { continuation in
        Task {
            for i in 0..<count {
                try? await Task.sleep(for: delay)
                continuation.yield(.thinking(thought: "Event \(i)"))
            }
            continuation.finish()
        }
    }
}

func makeFailingEventStream(failAfter count: Int) -> AsyncThrowingStream<AgentEvent, Error> {
    AsyncThrowingStream { continuation in
        for i in 0..<count {
            continuation.yield(.thinking(thought: "Event \(i)"))
        }
        continuation.finish(throwing: TestStreamError.intentionalFailure)
    }
}

func makeRapidEventStream(count: Int, interval: Duration) -> AsyncThrowingStream<AgentEvent, Error> {
    AsyncThrowingStream { continuation in
        Task {
            for i in 0..<count {
                try? await Task.sleep(for: interval)
                continuation.yield(.thinking(thought: "Rapid \(i)"))
            }
            continuation.finish()
        }
    }
}

func makeTestResult(_ output: String) -> AgentResult {
    AgentResult(
        output: output,
        toolCalls: [],
        toolResults: [],
        iterationCount: 1,
        duration: 0,
        tokenUsage: nil,
        metadata: [:]
    )
}

enum TestStreamError: Error {
    case intentionalFailure
}

// MARK: - Stream Extensions (to be implemented)

extension AsyncThrowingStream where Element == AgentEvent {

    /// Filter to only thinking events
    func filterThinking() -> AsyncThrowingStream<AgentEvent, Error> {
        filter { event in
            if case .thinking = event { return true }
            return false
        }
    }

    /// Filter with predicate
    func filter(_ predicate: @escaping (AgentEvent) -> Bool) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await event in self {
                        if predicate(event) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Map events to different type
    func map<T>(_ transform: @escaping (AgentEvent) -> T) -> AsyncThrowingStream<T, Error> {
        AsyncThrowingStream<T, Error> { continuation in
            Task {
                do {
                    for try await event in self {
                        continuation.yield(transform(event))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Map to thought strings only
    func mapToThoughts() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream<String, Error> { continuation in
            Task {
                do {
                    for try await event in self {
                        if case .thinking(let thought) = event {
                            continuation.yield(thought)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Extract only thinking content
    var thoughts: AsyncThrowingStream<String, Error> {
        mapToThoughts()
    }

    /// Extract tool calls
    var toolCalls: AsyncThrowingStream<ToolCallInfo, Error> {
        AsyncThrowingStream<ToolCallInfo, Error> { continuation in
            Task {
                do {
                    for try await event in self {
                        if case .toolCall(let call) = event {
                            continuation.yield(call)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Collect all events into array
    func collect() async throws -> [AgentEvent] {
        var results: [AgentEvent] = []
        for try await event in self {
            results.append(event)
        }
        return results
    }

    /// Collect up to max count
    func collect(maxCount: Int) async throws -> [AgentEvent] {
        var results: [AgentEvent] = []
        for try await event in self {
            results.append(event)
            if results.count >= maxCount { break }
        }
        return results
    }

    /// Get first event matching predicate
    func first(where predicate: @escaping (AgentEvent) -> Bool) async throws -> AgentEvent? {
        for try await event in self {
            if predicate(event) { return event }
        }
        return nil
    }

    /// Get last event
    func last() async throws -> AgentEvent? {
        var lastEvent: AgentEvent?
        for try await event in self {
            lastEvent = event
        }
        return lastEvent
    }

    /// Reduce stream to single value
    func reduce<T>(_ initial: T, _ combine: @escaping (T, AgentEvent) -> T) async throws -> T {
        var result = initial
        for try await event in self {
            result = combine(result, event)
        }
        return result
    }

    /// Take first n events
    func take(_ count: Int) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var taken = 0
                    for try await event in self {
                        continuation.yield(event)
                        taken += 1
                        if taken >= count { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Drop first n events
    func drop(_ count: Int) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var dropped = 0
                    for try await event in self {
                        if dropped < count {
                            dropped += 1
                            continue
                        }
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Add timeout to stream
    func timeout(after duration: Duration) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let timeoutTask = Task {
                    try await Task.sleep(for: duration)
                    continuation.finish(throwing: AgentError.timeout)
                }

                do {
                    for try await event in self {
                        continuation.yield(event)
                    }
                    timeoutTask.cancel()
                    continuation.finish()
                } catch {
                    timeoutTask.cancel()
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Execute side effect for each event
    func onEach(_ action: @escaping (AgentEvent) -> Void) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await event in self {
                        action(event)
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Execute callback on completion event
    func onComplete(_ action: @escaping (AgentResult) -> Void) -> AsyncThrowingStream<AgentEvent, Error> {
        onEach { event in
            if case .completed(let result) = event {
                action(result)
            }
        }
    }

    /// Catch and handle errors
    func catchErrors(_ handler: @escaping (Error) -> AgentEvent) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await event in self {
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(handler(error))
                    continuation.finish()
                }
            }
        }
    }

    /// Debounce rapid events
    func debounce(for duration: Duration) -> AsyncThrowingStream<AgentEvent, Error> {
        // Simplified implementation
        self
    }
}

/// Namespace for stream utilities
enum AgentEventStream {
    /// Merge multiple streams
    static func merge(_ streams: AsyncThrowingStream<AgentEvent, Error>...) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for stream in streams {
                        group.addTask {
                            do {
                                for try await event in stream {
                                    continuation.yield(event)
                                }
                            } catch {
                                // Ignore errors from individual streams
                            }
                        }
                    }
                }
                continuation.finish()
            }
        }
    }
}
