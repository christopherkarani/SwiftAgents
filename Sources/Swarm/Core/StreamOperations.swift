// StreamOperations.swift
// Swarm Framework
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

public extension AsyncThrowingStream where Element == AgentEvent, Failure == Error {
    // MARK: - Property Accessors

    /// Extracts only thinking content from the stream.
    ///
    /// Example:
    /// ```swift
    /// for try await thought in stream.thoughts {
    ///     print(thought)
    /// }
    /// ```
    var thoughts: AsyncThrowingStream<String, Error> {
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
    var toolCalls: AsyncThrowingStream<ToolCall, Error> {
        StreamHelper.makeTrackedStream { continuation in
            for try await event in self {
                if case let .toolCallStarted(call) = event {
                    continuation.yield(call)
                }
            }
            continuation.finish()
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
    var toolResults: AsyncThrowingStream<ToolResult, Error> {
        StreamHelper.makeTrackedStream { continuation in
            for try await event in self {
                if case let .toolCallCompleted(_, result) = event {
                    continuation.yield(result)
                }
            }
            continuation.finish()
        }
    }

    // MARK: - Retry

    /// Retries stream creation on failure with optional delay between attempts.
    ///
    /// This operator accepts a factory closure that creates fresh streams for each retry attempt.
    /// When a stream throws an error, the factory is called again to create a new stream,
    /// up to the specified maximum attempts.
    ///
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts (including the initial attempt). Default: 3
    ///   - delay: Duration to wait between retry attempts. Default: zero
    ///   - factory: Closure that creates a new stream for each attempt
    /// - Returns: A stream from the first successful attempt.
    ///
    /// Example:
    /// ```swift
    /// // Retry agent execution up to 3 times with 1 second delay
    /// let stream = AsyncThrowingStream<AgentEvent, Error>.retry(
    ///     maxAttempts: 3,
    ///     delay: .seconds(1)
    /// ) {
    ///     await agent.stream(input: "query")
    /// }
    ///
    /// for try await event in stream {
    ///     print(event)
    /// }
    /// ```
    ///
    /// - Note: The factory closure is called once per attempt, allowing proper stream recreation.
    ///   For simple retry logic, consider using `ResilientAgent` instead.
    static func retry(
        maxAttempts: Int = 3,
        delay: Duration = .zero,
        factory: @escaping @Sendable () async -> AsyncThrowingStream<AgentEvent, Error>
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        let (stream, continuation): (AsyncThrowingStream<AgentEvent, Error>, AsyncThrowingStream<AgentEvent, Error>.Continuation) = StreamHelper.makeStream()

        let task = Task { @Sendable in
            var attempts = 0
            var lastError: Error?

            while attempts < maxAttempts {
                attempts += 1
                do {
                    let newStream = await factory()
                    for try await event in newStream {
                        continuation.yield(event)
                    }
                    // Stream completed successfully
                    continuation.finish()
                    return
                } catch {
                    lastError = error
                    if attempts < maxAttempts, delay != .zero {
                        try? await Task.sleep(for: delay)
                    }
                }
            }

            // All attempts exhausted
            if let error = lastError {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }

        continuation.onTermination = { @Sendable (_: AsyncThrowingStream<AgentEvent, Error>.Continuation.Termination) in
            task.cancel()
        }

        return stream
    }

    // MARK: - Filtering

    /// Filters the stream to only include thinking events.
    ///
    /// Example:
    /// ```swift
    /// for try await event in agent.stream("query").filterThinking() {
    ///     // Only thinking events
    /// }
    /// ```
    func filterThinking() -> AsyncThrowingStream<AgentEvent, Error> {
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
    func filterToolEvents() -> AsyncThrowingStream<AgentEvent, Error> {
        filter { event in
            switch event {
            case .toolCallCompleted,
                 .toolCallFailed,
                 .toolCallPartial,
                 .toolCallStarted:
                true
            default:
                false
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
    func filter(
        _ predicate: @escaping @Sendable (AgentEvent) -> Bool
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            for try await event in self where predicate(event) {
                continuation.yield(event)
            }
            continuation.finish()
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
    func map<T: Sendable>(
        _ transform: @escaping @Sendable (AgentEvent) -> T
    ) -> AsyncThrowingStream<T, Error> {
        StreamHelper.makeTrackedStream { continuation in
            for try await event in self {
                continuation.yield(transform(event))
            }
            continuation.finish()
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
    func mapToThoughts() -> AsyncThrowingStream<String, Error> {
        StreamHelper.makeTrackedStream { continuation in
            for try await event in self {
                if case let .thinking(thought) = event {
                    continuation.yield(thought)
                }
            }
            continuation.finish()
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
    func collect() async throws -> [AgentEvent] {
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
    func collect(maxCount: Int) async throws -> [AgentEvent] {
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
    func first(
        where predicate: @escaping @Sendable (AgentEvent) -> Bool
    ) async throws -> AgentEvent? {
        for try await event in self where predicate(event) {
            return event
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
    func last() async throws -> AgentEvent? {
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
    func reduce<T: Sendable>(
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
    func take(_ count: Int) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            var taken = 0
            for try await event in self {
                continuation.yield(event)
                taken += 1
                if taken >= count { break }
            }
            continuation.finish()
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
    func drop(_ count: Int) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            var dropped = 0
            for try await event in self {
                if dropped < count {
                    dropped += 1
                    continue
                }
                continuation.yield(event)
            }
            continuation.finish()
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
    func timeout(after duration: Duration) -> AsyncThrowingStream<AgentEvent, Error> {
        let (stream, continuation): (AsyncThrowingStream<AgentEvent, Error>, AsyncThrowingStream<AgentEvent, Error>.Continuation) = StreamHelper.makeStream()

        let timeoutTask = Task {
            try await Task.sleep(for: duration)
            continuation.finish(throwing: AgentError.timeout(duration: duration))
        }

        let processingTask = Task { @Sendable in
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

        continuation.onTermination = { @Sendable _ in
            timeoutTask.cancel()
            processingTask.cancel()
        }

        return stream
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
    func onEach(
        _ action: @escaping @Sendable (AgentEvent) -> Void
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            for try await event in self {
                action(event)
                continuation.yield(event)
            }
            continuation.finish()
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
    func onComplete(
        _ action: @escaping @Sendable (AgentResult) -> Void
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        onEach { event in
            if case let .completed(result) = event {
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
    func onError(
        _ action: @escaping @Sendable (AgentError) -> Void
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        onEach { event in
            if case let .failed(error) = event {
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
    func catchErrors(
        _ handler: @escaping @Sendable (Error) -> AgentEvent
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        let (stream, continuation): (AsyncThrowingStream<AgentEvent, Error>, AsyncThrowingStream<AgentEvent, Error>.Continuation) = StreamHelper.makeStream()

        let task = Task { @Sendable in
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

        continuation.onTermination = { @Sendable _ in
            task.cancel()
        }

        return stream
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
    func debounce(for duration: Duration) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            var lastEvent: AgentEvent?
            var lastTime: ContinuousClock.Instant?
            let durationSeconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18

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
        }
    }

    // MARK: - Throttle

    /// Limits the emission rate to one event per time interval.
    ///
    /// Events that arrive faster than the specified interval are dropped.
    /// The first event in each interval is always emitted.
    ///
    /// - Parameter interval: The minimum time between emitted events.
    /// - Returns: A throttled stream.
    ///
    /// Example:
    /// ```swift
    /// // Emit at most one event per second
    /// for try await event in stream.throttle(for: .seconds(1)) {
    ///     print(event)
    /// }
    /// ```
    func throttle(for interval: Duration) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            var lastEmitTime: ContinuousClock.Instant?
            let intervalSeconds = Double(interval.components.seconds) + Double(interval.components.attoseconds) / 1e18

            for try await event in self {
                let now = ContinuousClock.now

                if let lastTime = lastEmitTime {
                    let elapsed = now - lastTime
                    let elapsedSeconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18

                    if elapsedSeconds >= intervalSeconds {
                        continuation.yield(event)
                        lastEmitTime = now
                    }
                    // Events within the interval are dropped
                } else {
                    // First event is always emitted
                    continuation.yield(event)
                    lastEmitTime = now
                }
            }
            continuation.finish()
        }
    }

    // MARK: - Buffer

    /// Collects events into batches of the specified count before yielding.
    ///
    /// Events are buffered until the specified count is reached, then yielded
    /// as an array. Any remaining events when the stream completes are yielded
    /// as a final (possibly smaller) batch.
    ///
    /// - Parameter count: The number of events to collect before yielding.
    /// - Returns: A stream of event arrays.
    ///
    /// Example:
    /// ```swift
    /// // Process events in batches of 5
    /// for try await batch in stream.buffer(count: 5) {
    ///     print("Received batch of \(batch.count) events")
    /// }
    /// ```
    func buffer(count: Int) -> AsyncThrowingStream<[AgentEvent], Error> {
        StreamHelper.makeTrackedStream { continuation in
            var buffer: [AgentEvent] = []
            buffer.reserveCapacity(count)

            for try await event in self {
                buffer.append(event)
                if buffer.count >= count {
                    continuation.yield(buffer)
                    buffer.removeAll(keepingCapacity: true)
                }
            }

            // Yield any remaining events
            if !buffer.isEmpty {
                continuation.yield(buffer)
            }
            continuation.finish()
        }
    }

    // MARK: - CompactMap

    /// Maps events and filters out nil results.
    ///
    /// Applies the transform to each event and only yields non-nil results.
    /// This combines `map` and `filter` into a single operation.
    ///
    /// - Parameter transform: A closure that transforms events, returning nil to skip.
    /// - Returns: A stream of transformed non-nil values.
    ///
    /// Example:
    /// ```swift
    /// // Extract only thinking content as uppercase strings
    /// let thoughts = stream.compactMap { event -> String? in
    ///     if case .thinking(let thought) = event {
    ///         return thought.uppercased()
    ///     }
    ///     return nil
    /// }
    /// ```
    func compactMap<T: Sendable>(
        _ transform: @escaping @Sendable (AgentEvent) async throws -> T?
    ) -> AsyncThrowingStream<T, Error> {
        StreamHelper.makeTrackedStream { continuation in
            for try await event in self {
                if let transformed = try await transform(event) {
                    continuation.yield(transformed)
                }
            }
            continuation.finish()
        }
    }

    // MARK: - DistinctUntilChanged

    /// Skips consecutive duplicate events.
    ///
    /// Compares each event to the previous one using `Equatable` conformance
    /// and only emits events that differ from the previous.
    ///
    /// - Returns: A stream with consecutive duplicates removed.
    ///
    /// Example:
    /// ```swift
    /// for try await event in stream.distinctUntilChanged() {
    ///     // Only receives events different from the previous
    /// }
    /// ```
    func distinctUntilChanged() -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            var previousEvent: AgentEvent?

            for try await event in self {
                if let previous = previousEvent {
                    if !event.isEqual(to: previous) {
                        continuation.yield(event)
                        previousEvent = event
                    }
                } else {
                    continuation.yield(event)
                    previousEvent = event
                }
            }
            continuation.finish()
        }
    }

    // MARK: - Scan

    /// Reduces the stream while emitting intermediate values.
    ///
    /// Like `reduce`, but yields each intermediate accumulator value as it
    /// is computed, rather than only the final result.
    ///
    /// - Parameters:
    ///   - initial: The initial accumulator value.
    ///   - combine: A closure that combines the accumulator with each event.
    /// - Returns: A stream of intermediate accumulated values.
    ///
    /// Example:
    /// ```swift
    /// // Count events as they arrive
    /// for try await count in stream.scan(0) { acc, _ in acc + 1 } {
    ///     print("Events so far: \(count)")
    /// }
    /// ```
    ///
    /// Example:
    /// ```swift
    /// // Accumulate all thinking content
    /// for try await combined in stream.scan("") { acc, event in
    ///     if case .thinking(let thought) = event {
    ///         return acc + thought
    ///     }
    ///     return acc
    /// } {
    ///     print("Thoughts so far: \(combined)")
    /// }
    /// ```
    func scan<T: Sendable>(
        _ initial: T,
        _ combine: @escaping @Sendable (T, AgentEvent) async throws -> T
    ) -> AsyncThrowingStream<T, Error> {
        StreamHelper.makeTrackedStream { continuation in
            var accumulator = initial

            for try await event in self {
                accumulator = try await combine(accumulator, event)
                continuation.yield(accumulator)
            }
            continuation.finish()
        }
    }
}

// MARK: - MergeErrorStrategy

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

// MARK: - AgentEventStream

/// Namespace for stream utility functions.
public enum AgentEventStream {
    // MARK: Public

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
        let (stream, continuation): (AsyncThrowingStream<AgentEvent, Error>, AsyncThrowingStream<AgentEvent, Error>.Continuation) = StreamHelper.makeStream()
        let coordinator = MergeCoordinator(continuation: continuation)

        let task = Task { @Sendable in
            await withTaskGroup(of: Void.self) { group in
                for stream in streams {
                    group.addTask {
                        do {
                            for try await event in stream {
                                await coordinator.yield(event)
                            }
                        } catch {
                            switch errorStrategy {
                            case .failFast:
                                await coordinator.finish(throwing: error)
                            case .continueAndCollect:
                                // Convert error to a failed event
                                let agentError = error as? AgentError ?? .internalError(reason: error.localizedDescription)
                                await coordinator.yield(.failed(error: agentError))
                            case .ignoreErrors:
                                // Silently ignore - legacy behavior
                                break
                            }
                        }
                    }
                }
            }
            await coordinator.finish()
        }

        continuation.onTermination = { @Sendable _ in
            task.cancel()
        }

        return stream
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

    // MARK: Private

    /// Actor that serializes concurrent yield/finish calls to prevent race conditions
    private actor MergeCoordinator {
        // MARK: Internal

        init(continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation) {
            self.continuation = continuation
        }

        func yield(_ event: AgentEvent) {
            guard !hasFinished else { return }
            continuation.yield(event)
        }

        func finish(throwing error: Error? = nil) {
            guard !hasFinished else { return }
            hasFinished = true
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }

        // MARK: Private

        private var hasFinished = false
        private let continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    }
}
