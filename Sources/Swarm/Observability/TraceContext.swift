// TraceContext.swift
// Swarm Framework
//
// Context for grouping related traces together using task-local storage.

import Foundation

// MARK: - TraceContextStorage

/// Internal storage for task-local trace context.
private enum TraceContextStorage {
    @TaskLocal
    static var current: TraceContext?
}

// MARK: - TraceContext

/// Context for grouping related traces together using task-local storage.
///
/// `TraceContext` provides distributed tracing capabilities by maintaining a context
/// that propagates automatically through async call chains via Swift's `@TaskLocal` storage.
///
/// Example:
/// ```swift
/// await TraceContext.withTrace("agent-execution", groupId: "session-123") {
///     guard let context = TraceContext.current else { return }
///
///     let span = await context.startSpan("tool-call")
///     // ... perform operation ...
///     await context.endSpan(span, status: .ok)
/// }
/// ```
public actor TraceContext {
    // MARK: Public

    // MARK: - Static Task-Local Access

    /// The current trace context for this task, if any.
    ///
    /// Returns the `TraceContext` established by the nearest enclosing `withTrace` call,
    /// or `nil` if no trace context is active.
    ///
    /// This property uses `@TaskLocal` storage, so the context automatically propagates
    /// through async calls and child tasks.
    ///
    /// ## Actor Isolation
    ///
    /// `TraceContext` is an actor. When accessing its properties or methods,
    /// you must use `await` to respect actor isolation:
    ///
    /// ```swift
    /// if let context = TraceContext.current {
    ///     // Access actor-isolated properties with await
    ///     let spans = await context.getSpans()
    ///     let span = await context.startSpan("operation")
    ///
    ///     // These are nonisolated and don't need await
    ///     let id = context.traceId
    ///     let name = context.name
    /// }
    /// ```
    ///
    /// - Note: The context reference itself is safe to pass across isolation boundaries
    ///   because actors are `Sendable`. The returned context is always the same instance
    ///   within the `withTrace` scope.
    public static var current: TraceContext? {
        TraceContextStorage.current
    }

    /// Human-readable name for this trace.
    public let name: String

    /// Unique identifier for this trace.
    /// All spans within this context share the same traceId.
    public let traceId: UUID

    /// Optional group identifier for linking related traces.
    /// Useful for grouping traces within a session or conversation.
    public let groupId: String?

    /// Additional metadata associated with this trace.
    public let metadata: [String: SendableValue]

    /// Timestamp when this trace started.
    public let startTime: Date

    /// The total duration of this trace from start until now.
    ///
    /// Calculated as the time interval from `startTime` to the current time.
    public var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    /// Executes an operation within a new trace context.
    ///
    /// Creates a new `TraceContext` and makes it available via `TraceContext.current`
    /// for the duration of the operation. The context automatically propagates to
    /// child tasks and async calls.
    ///
    /// - Parameters:
    ///   - name: Human-readable name for this trace.
    ///   - groupId: Optional identifier for linking related traces.
    ///   - metadata: Additional metadata to attach to the trace.
    ///   - operation: The async operation to execute within the trace context.
    /// - Returns: The result of the operation.
    /// - Throws: Any error thrown by the operation.
    ///
    /// Example:
    /// ```swift
    /// let result = await TraceContext.withTrace("process-request", groupId: "session-1") {
    ///     // TraceContext.current is available here
    ///     return await processRequest()
    /// }
    /// ```
    public static func withTrace<T: Sendable>(
        _ name: String,
        groupId: String? = nil,
        metadata: [String: SendableValue] = [:],
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        let context = TraceContext(
            name: name,
            groupId: groupId,
            metadata: metadata
        )

        return try await TraceContextStorage.$current.withValue(context) {
            try await operation()
        }
    }

    // MARK: - Span Management

    /// Starts a new span within this trace context.
    ///
    /// Creates and records a new `TraceSpan` with the given name and metadata.
    /// The span is automatically added to the context's span collection.
    ///
    /// - Parameters:
    ///   - name: Human-readable name for this span.
    ///   - metadata: Additional metadata to attach to the span.
    /// - Returns: The newly created span.
    ///
    /// Example:
    /// ```swift
    /// let span = await context.startSpan("database-query", metadata: ["table": .string("users")])
    /// ```
    public func startSpan(_ name: String, metadata: [String: SendableValue] = [:]) -> TraceSpan {
        let span = TraceSpan(
            parentSpanId: currentSpanId,
            name: name,
            metadata: metadata
        )

        spans.append(span)
        spanStack.append(span.id)

        return span
    }

    /// Ends a span with the given status.
    ///
    /// Updates the span in the collection with an end time and final status.
    /// If the span is not found in the collection, this method has no effect.
    ///
    /// - Parameters:
    ///   - span: The span to end.
    ///   - status: The completion status. Defaults to `.ok`.
    ///
    /// Example:
    /// ```swift
    /// await context.endSpan(span, status: .ok)
    /// ```
    public func endSpan(_ span: TraceSpan, status: SpanStatus = .ok) {
        guard let index = spans.firstIndex(where: { $0.id == span.id }) else {
            return
        }

        let completedSpan = span.completed(status: status)
        spans[index] = completedSpan

        // Remove span from stack (allows out-of-order span completion)
        spanStack.removeAll { $0 == span.id }
    }

    /// Adds an external span to this context.
    ///
    /// Use this to add spans that were created outside this context,
    /// such as spans from instrumented libraries.
    ///
    /// - Parameter span: The span to add.
    public func addSpan(_ span: TraceSpan) {
        spans.append(span)
    }

    /// Returns all spans recorded within this context.
    ///
    /// - Returns: An array of all spans in the order they were added.
    public func getSpans() -> [TraceSpan] {
        spans
    }

    // MARK: Private

    /// Collection of spans recorded within this trace context.
    private var spans: [TraceSpan] = []

    /// Stack of active span IDs for proper parent tracking.
    /// Allows spans to end in any order while maintaining correct parent relationships.
    private var spanStack: [UUID] = []

    /// Current active span for parent tracking.
    /// Returns the most recently started span that has not yet ended.
    private var currentSpanId: UUID? {
        spanStack.last
    }

    // MARK: - Initialization

    /// Creates a new trace context.
    ///
    /// Note: This initializer is private. Use `withTrace` to create contexts.
    private init(
        name: String,
        traceId: UUID = UUID(),
        groupId: String? = nil,
        metadata: [String: SendableValue] = [:]
    ) {
        self.name = name
        self.traceId = traceId
        self.groupId = groupId
        self.metadata = metadata
        startTime = Date()
    }
}

// MARK: CustomStringConvertible

extension TraceContext: CustomStringConvertible {
    nonisolated public var description: String {
        "TraceContext(\(name))"
    }
}

// MARK: - Convenience Methods

public extension TraceContext {
    /// Executes an operation within a new span, automatically handling start and end.
    ///
    /// The span is automatically ended with `.ok` status on success, or `.error`
    /// if the operation throws.
    ///
    /// - Parameters:
    ///   - name: Name of the span.
    ///   - metadata: Optional metadata for the span.
    ///   - operation: The operation to execute within the span.
    /// - Returns: The result of the operation.
    /// - Throws: Any error thrown by the operation.
    ///
    /// Example:
    /// ```swift
    /// let result = try await context.withSpan("database-query") {
    ///     try await database.query("SELECT * FROM users")
    /// }
    /// ```
    func withSpan<T: Sendable>(
        _ name: String,
        metadata: [String: SendableValue] = [:],
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        let span = startSpan(name, metadata: metadata)
        do {
            let result = try await operation()
            endSpan(span, status: .ok)
            return result
        } catch {
            endSpan(span, status: .error)
            throw error
        }
    }
}
