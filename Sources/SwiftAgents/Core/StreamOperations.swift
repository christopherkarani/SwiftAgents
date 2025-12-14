// StreamOperations.swift
// SwiftAgents Framework
//
// Functional operations on AsyncThrowingStream<AgentEvent, Error> for reactive stream processing.

import Foundation

// MARK: - Type Aliases for Compatibility

/// Type alias for tool call information.
/// Provides compatibility with various API naming conventions.
public typealias ToolCallInfo = ToolCall

/// Type alias for tool result information.
/// Provides compatibility with various API naming conventions.
public typealias ToolResultInfo = ToolResult

// MARK: - AgentEvent Stream Operations

extension AsyncThrowingStream where Element == AgentEvent, Failure == Error {

    // MARK: - Filtering

    /// Filters the stream to only include thinking events.
    ///
    /// Example:
    /// ```swift
    /// for try await event in agent.stream("query").filterThinking() {
    ///     // Only thinking events
    /// }
    /// ```
    public func filterThinking() -> AsyncThrowingStream<AgentEvent, Error> {
        filter { event in
            if case .thinking = event { return true }
            return false
        }
    }

    /// Filters the stream to only include tool-related events.
    ///
    /// Example:
    /// ```swift
    /// for try await event in agent.stream("query").filterToolEvents() {
    ///     // Only tool call/result events
    /// }
    /// ```
    public func filterToolEvents() -> AsyncThrowingStream<AgentEvent, Error> {
        filter { event in
            switch event {
            case .toolCallStarted, .toolCallCompleted, .toolCallFailed:
                return true
            default:
                return false
            }
        }
    }

    /// Filters the stream with a custom predicate.
    ///
    /// - Parameter predicate: A closure that determines whether to include an event.
    /// - Returns: A filtered stream.
    ///
    /// Example:
    /// ```swift
    /// let filtered = stream.filter { event in
    ///     if case .thinking(let thought) = event {
    ///         return thought.count > 10
    ///     }
    ///     return false
    /// }
    /// ```
    public func filter(
        _ predicate: @escaping @Sendable (AgentEvent) -> Bool
    ) -> AsyncThrowingStream<AgentEvent, Error> {
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

    // MARK: - Mapping

    /// Maps events to a different type.
    ///
    /// - Parameter transform: A closure that transforms each event.
    /// - Returns: A stream of transformed values.
    ///
    /// Example:
    /// ```swift
    /// let uppercased = stream.map { event -> String in
    ///     if case .thinking(let thought) = event {
    ///         return thought.uppercased()
    ///     }
    ///     return ""
    /// }
    /// ```
    public func map<T: Sendable>(
        _ transform: @escaping @Sendable (AgentEvent) -> T
    ) -> AsyncThrowingStream<T, Error> {
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

    /// Maps events to thought strings only.
    ///
    /// - Returns: A stream of thought strings (non-thinking events are skipped).
    ///
    /// Example:
    /// ```swift
    /// for try await thought in stream.mapToThoughts() {
    ///     print("Agent thinking: \(thought)")
    /// }
    /// ```
    public func mapToThoughts() -> AsyncThrowingStream<String, Error> {
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

    // MARK: - Property Accessors

    /// Extracts only thinking content from the stream.
    ///
    /// Example:
    /// ```swift
    /// for try await thought in stream.thoughts {
    ///     print(thought)
    /// }
    /// ```
    public var thoughts: AsyncThrowingStream<String, Error> {
        mapToThoughts()
    }

    /// Extracts tool calls from the stream.
    ///
    /// Example:
    /// ```swift
    /// for try await call in stream.toolCalls {
    ///     print("Called tool: \(call.toolName)")
    /// }
    /// ```
    public var toolCalls: AsyncThrowingStream<ToolCall, Error> {
        AsyncThrowingStream<ToolCall, Error> { continuation in
            Task {
                do {
                    for try await event in self {
                        if case .toolCallStarted(let call) = event {
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

    /// Extracts tool results from the stream.
    ///
    /// Example:
    /// ```swift
    /// for try await result in stream.toolResults {
    ///     print("Tool result: \(result)")
    /// }
    /// ```
    public var toolResults: AsyncThrowingStream<ToolResult, Error> {
        AsyncThrowingStream<ToolResult, Error> { continuation in
            Task {
                do {
                    for try await event in self {
                        if case .toolCallCompleted(_, let result) = event {
                            continuation.yield(result)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Collection Operations

    /// Collects all events into an array.
    ///
    /// - Returns: An array of all events.
    /// - Throws: Any error from the stream.
    ///
    /// Example:
    /// ```swift
    /// let allEvents = try await stream.collect()
    /// ```
    public func collect() async throws -> [AgentEvent] {
        var results: [AgentEvent] = []
        for try await event in self {
            results.append(event)
        }
        return results
    }

    /// Collects events up to a maximum count.
    ///
    /// - Parameter maxCount: Maximum number of events to collect.
    /// - Returns: An array of events up to the limit.
    /// - Throws: Any error from the stream.
    ///
    /// Example:
    /// ```swift
    /// let firstFive = try await stream.collect(maxCount: 5)
    /// ```
    public func collect(maxCount: Int) async throws -> [AgentEvent] {
        var results: [AgentEvent] = []
        for try await event in self {
            results.append(event)
            if results.count >= maxCount { break }
        }
        return results
    }

    // MARK: - First/Last

    /// Gets the first event matching a predicate.
    ///
    /// - Parameter predicate: A closure that determines a match.
    /// - Returns: The first matching event, or nil if none found.
    /// - Throws: Any error from the stream.
    ///
    /// Example:
    /// ```swift
    /// let firstThinking = try await stream.first { event in
    ///     if case .thinking = event { return true }
    ///     return false
    /// }
    /// ```
    public func first(
        where predicate: @escaping @Sendable (AgentEvent) -> Bool
    ) async throws -> AgentEvent? {
        for try await event in self {
            if predicate(event) { return event }
        }
        return nil
    }

    /// Gets the last event from the stream.
    ///
    /// - Returns: The last event, or nil if the stream is empty.
    /// - Throws: Any error from the stream.
    ///
    /// Example:
    /// ```swift
    /// if let lastEvent = try await stream.last() {
    ///     print("Last event: \(lastEvent)")
    /// }
    /// ```
    public func last() async throws -> AgentEvent? {
        var lastEvent: AgentEvent?
        for try await event in self {
            lastEvent = event
        }
        return lastEvent
    }

    // MARK: - Reduce

    /// Reduces the stream to a single value.
    ///
    /// - Parameters:
    ///   - initial: The initial accumulator value.
    ///   - combine: A closure that combines the accumulator with each event.
    /// - Returns: The final accumulated value.
    /// - Throws: Any error from the stream.
    ///
    /// Example:
    /// ```swift
    /// let combined = try await stream.reduce("") { acc, event in
    ///     if case .thinking(let thought) = event {
    ///         return acc + thought
    ///     }
    ///     return acc
    /// }
    /// ```
    public func reduce<T: Sendable>(
        _ initial: T,
        _ combine: @escaping @Sendable (T, AgentEvent) -> T
    ) async throws -> T {
        var result = initial
        for try await event in self {
            result = combine(result, event)
        }
        return result
    }

    // MARK: - Take/Drop

    /// Takes the first N events from the stream.
    ///
    /// - Parameter count: The number of events to take.
    /// - Returns: A stream limited to the first N events.
    ///
    /// Example:
    /// ```swift
    /// for try await event in stream.take(3) {
    ///     // Only first 3 events
    /// }
    /// ```
    public func take(_ count: Int) -> AsyncThrowingStream<AgentEvent, Error> {
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

    /// Drops the first N events from the stream.
    ///
    /// - Parameter count: The number of events to drop.
    /// - Returns: A stream starting after the first N events.
    ///
    /// Example:
    /// ```swift
    /// for try await event in stream.drop(2) {
    ///     // Events after the first 2
    /// }
    /// ```
    public func drop(_ count: Int) -> AsyncThrowingStream<AgentEvent, Error> {
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

    // MARK: - Timeout

    /// Adds a timeout to the stream.
    ///
    /// - Parameter duration: The timeout duration.
    /// - Returns: A stream that throws AgentError.timeout if exceeded.
    ///
    /// Example:
    /// ```swift
    /// for try await event in stream.timeout(after: .seconds(30)) {
    ///     // Throws after 30 seconds
    /// }
    /// ```
    public func timeout(after duration: Duration) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let timeoutTask = Task {
                try await Task.sleep(for: duration)
                continuation.finish(throwing: AgentError.timeout(duration: duration))
            }

            Task {
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

    // MARK: - Side Effects

    /// Executes a side effect for each event.
    ///
    /// - Parameter action: A closure to execute for each event.
    /// - Returns: A stream that passes through all events.
    ///
    /// Example:
    /// ```swift
    /// let logged = stream.onEach { event in
    ///     print("Event: \(event)")
    /// }
    /// ```
    public func onEach(
        _ action: @escaping @Sendable (AgentEvent) -> Void
    ) -> AsyncThrowingStream<AgentEvent, Error> {
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

    /// Executes a callback when a completion event occurs.
    ///
    /// - Parameter action: A closure to execute with the result.
    /// - Returns: A stream that passes through all events.
    ///
    /// Example:
    /// ```swift
    /// let stream = agent.stream("query").onComplete { result in
    ///     print("Completed with: \(result.output)")
    /// }
    /// ```
    public func onComplete(
        _ action: @escaping @Sendable (AgentResult) -> Void
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        onEach { event in
            if case .completed(let result) = event {
                action(result)
            }
        }
    }

    /// Executes a callback when a failure event occurs.
    ///
    /// - Parameter action: A closure to execute with the error.
    /// - Returns: A stream that passes through all events.
    ///
    /// Example:
    /// ```swift
    /// let stream = agent.stream("query").onError { error in
    ///     print("Error: \(error)")
    /// }
    /// ```
    public func onError(
        _ action: @escaping @Sendable (AgentError) -> Void
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        onEach { event in
            if case .failed(let error) = event {
                action(error)
            }
        }
    }

    // MARK: - Error Handling

    /// Catches errors and provides a fallback event.
    ///
    /// - Parameter handler: A closure that transforms errors to fallback events.
    /// - Returns: A stream that handles errors gracefully.
    ///
    /// Example:
    /// ```swift
    /// let safe = stream.catchErrors { error in
    ///     .failed(error: .internalError(reason: "Recovered"))
    /// }
    /// ```
    public func catchErrors(
        _ handler: @escaping @Sendable (Error) -> AgentEvent
    ) -> AsyncThrowingStream<AgentEvent, Error> {
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

    // MARK: - Debounce

    /// Debounces rapid events by the specified duration.
    ///
    /// - Parameter duration: The debounce window.
    /// - Returns: A debounced stream.
    ///
    /// Example:
    /// ```swift
    /// for try await event in stream.debounce(for: .milliseconds(100)) {
    ///     // Rapid events are collapsed
    /// }
    /// ```
    public func debounce(for duration: Duration) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var lastEvent: AgentEvent?
                var lastTime: ContinuousClock.Instant?
                let durationSeconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18

                do {
                    for try await event in self {
                        let now = ContinuousClock.now

                        if let last = lastTime {
                            let elapsed = now - last
                            let elapsedSeconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18

                            if elapsedSeconds >= durationSeconds {
                                if let pending = lastEvent {
                                    continuation.yield(pending)
                                }
                                lastEvent = event
                            } else {
                                lastEvent = event
                            }
                        } else {
                            lastEvent = event
                        }

                        lastTime = now
                    }

                    // Yield final event
                    if let final = lastEvent {
                        continuation.yield(final)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - AgentEventStream Namespace

/// Strategy for handling errors when merging multiple streams.
public enum MergeErrorStrategy: Sendable {
    /// Fail immediately on the first error from any stream.
    case failFast

    /// Continue processing other streams and collect errors as events.
    /// Errors are yielded as `.failed` events.
    case continueAndCollect

    /// Ignore all errors from individual streams (legacy behavior).
    /// Use with caution - errors will be silently swallowed.
    case ignoreErrors
}

/// Namespace for stream utility functions.
public enum AgentEventStream {
    /// Merges multiple agent event streams into one.
    ///
    /// Events from all streams are yielded as they arrive, in any order.
    ///
    /// - Parameters:
    ///   - streams: The streams to merge.
    ///   - errorStrategy: How to handle errors from individual streams. Defaults to `.continueAndCollect`.
    /// - Returns: A merged stream of all events.
    ///
    /// Example:
    /// ```swift
    /// // Default: errors become .failed events
    /// let merged = AgentEventStream.merge(stream1, stream2, stream3)
    /// for try await event in merged {
    ///     // Events from all streams, errors as .failed events
    /// }
    ///
    /// // Fail fast on first error
    /// let strictMerge = AgentEventStream.merge(stream1, stream2, errorStrategy: .failFast)
    /// ```
    ///
    /// - Note: When using `.continueAndCollect`, errors are converted to `.failed` events,
    ///   allowing other streams to continue processing. Use `.failFast` for critical workflows
    ///   where any error should stop all processing.
    public static func merge(
        _ streams: AsyncThrowingStream<AgentEvent, Error>...,
        errorStrategy: MergeErrorStrategy = .continueAndCollect
    ) -> AsyncThrowingStream<AgentEvent, Error> {
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
                                switch errorStrategy {
                                case .failFast:
                                    continuation.finish(throwing: error)
                                case .continueAndCollect:
                                    // Convert error to a failed event
                                    let agentError = error as? AgentError ?? .internalError(reason: error.localizedDescription)
                                    continuation.yield(.failed(error: agentError))
                                case .ignoreErrors:
                                    // Silently ignore - legacy behavior
                                    break
                                }
                            }
                        }
                    }
                }
                continuation.finish()
            }
        }
    }

    /// Creates an empty stream that completes immediately.
    ///
    /// - Returns: An empty stream.
    public static func empty() -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    /// Creates a stream from an array of events.
    ///
    /// - Parameter events: The events to emit.
    /// - Returns: A stream that emits all events then completes.
    ///
    /// Example:
    /// ```swift
    /// let stream = AgentEventStream.from([
    ///     .started(input: "test"),
    ///     .thinking(thought: "Processing..."),
    ///     .completed(result: result)
    /// ])
    /// ```
    public static func from(_ events: [AgentEvent]) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    /// Creates a stream that emits a single event.
    ///
    /// - Parameter event: The event to emit.
    /// - Returns: A stream that emits one event then completes.
    public static func just(_ event: AgentEvent) -> AsyncThrowingStream<AgentEvent, Error> {
        from([event])
    }

    /// Creates a stream that fails with an error.
    ///
    /// - Parameter error: The error to throw.
    /// - Returns: A stream that immediately fails.
    public static func fail(_ error: Error) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }
}
