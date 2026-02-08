// TracingHelper.swift
// Swarm Framework
//
// Helper for standardized trace event emission across agents.

import Foundation

// MARK: - TracingHelper

/// Helper for standardized trace event emission across agents
///
/// TracingHelper provides a consistent interface for emitting trace events
/// during agent execution. It encapsulates the trace context (traceId, agentName)
/// and provides typed methods for common trace operations.
///
/// Usage:
/// ```swift
/// func run(_ input: String) async throws -> AgentResult {
///     let tracing = TracingHelper(tracer: tracer, agentName: "ReActAgent")
///     await tracing.traceStart(input: input)
///
///     // ... agent work ...
///
///     await tracing.traceComplete(result: result)
///     return result
/// }
/// ```
public struct TracingHelper: Sendable {
    // MARK: Public

    /// The underlying tracer (may be nil for no-op behavior)
    public let tracer: (any Tracer)?

    /// Unique identifier for this trace
    public let traceId: UUID

    /// Name of the agent being traced
    public let agentName: String

    /// Creates a new tracing helper
    ///
    /// - Parameters:
    ///   - tracer: The tracer to emit events to (nil for no-op)
    ///   - agentName: The name of the agent for trace identification
    public init(tracer: (any Tracer)?, agentName: String) {
        self.tracer = tracer
        traceId = UUID()
        self.agentName = agentName
        startTime = .now
    }

    // MARK: - Lifecycle Events

    /// Trace agent execution start
    ///
    /// - Parameter input: The input being processed
    public func traceStart(input: String) async {
        guard let tracer else { return }
        await tracer.trace(TraceEvent(
            traceId: traceId,
            kind: .agentStart,
            message: "Agent \(agentName) started",
            metadata: [
                "input_length": .int(input.count),
                "input_preview": .string(String(input.prefix(100)))
            ],
            agentName: agentName
        ))
    }

    /// Trace agent execution completion
    ///
    /// - Parameter result: The result of execution
    public func traceComplete(result: AgentResult) async {
        guard let tracer else { return }
        let duration = ContinuousClock.now - startTime
        await tracer.trace(TraceEvent(
            traceId: traceId,
            duration: duration.timeInterval,
            kind: .agentComplete,
            message: "Agent \(agentName) completed",
            metadata: [
                "duration_ms": .double(duration.milliseconds),
                "iterations": .int(result.iterationCount),
                "tool_calls_count": .int(result.toolCalls.count),
                "output_length": .int(result.output.count)
            ],
            agentName: agentName
        ))
    }

    /// Trace agent execution error
    ///
    /// - Parameter error: The error that occurred
    public func traceError(_ error: Error) async {
        guard let tracer else { return }
        let duration = ContinuousClock.now - startTime
        await tracer.trace(TraceEvent(
            traceId: traceId,
            duration: duration.timeInterval,
            kind: .agentError,
            level: .error,
            message: "Agent \(agentName) error: \(error.localizedDescription)",
            metadata: [
                "duration_ms": .double(duration.milliseconds),
                "error_type": .string(String(describing: type(of: error))),
                "error_message": .string(error.localizedDescription)
            ],
            agentName: agentName,
            error: ErrorInfo(from: error)
        ))
    }

    // MARK: - Reasoning Events

    /// Trace a thought/reasoning step
    ///
    /// - Parameter thought: The thought content
    public func traceThought(_ thought: String) async {
        guard let tracer else { return }
        await tracer.trace(TraceEvent(
            traceId: traceId,
            kind: .thought,
            level: .trace,
            message: thought,
            metadata: [
                "thought_length": .int(thought.count),
                "thought": .string(thought)
            ],
            agentName: agentName
        ))
    }

    /// Trace a planning step
    ///
    /// - Parameter plan: The plan content
    public func tracePlan(_ plan: String) async {
        guard let tracer else { return }
        await tracer.trace(TraceEvent(
            traceId: traceId,
            kind: .plan,
            message: "Plan created",
            metadata: [
                "plan": .string(plan)
            ],
            agentName: agentName
        ))
    }

    // MARK: - Tool Events

    /// Trace a tool call start
    ///
    /// - Parameters:
    ///   - name: The tool name
    ///   - arguments: The tool arguments
    /// - Returns: A span ID to correlate with the result
    public func traceToolCall(name: String, arguments: [String: SendableValue]) async -> UUID {
        let spanId = UUID()
        guard let tracer else { return spanId }

        await tracer.trace(TraceEvent(
            traceId: traceId,
            spanId: spanId,
            kind: .toolCall,
            level: .debug,
            message: "Tool call: \(name)",
            metadata: [
                "tool_name": .string(name),
                "arguments": .dictionary(arguments)
            ],
            agentName: agentName,
            toolName: name
        ))
        return spanId
    }

    /// Trace a tool result
    ///
    /// - Parameters:
    ///   - spanId: The span ID from traceToolCall
    ///   - name: The tool name
    ///   - result: The tool result
    ///   - duration: The execution duration
    public func traceToolResult(
        spanId: UUID,
        name: String,
        result: String,
        duration: Duration
    ) async {
        guard let tracer else { return }
        await tracer.trace(TraceEvent(
            traceId: traceId,
            spanId: spanId,
            duration: duration.timeInterval,
            kind: .toolResult,
            level: .debug,
            message: "Tool result: \(name)",
            metadata: [
                "tool_name": .string(name),
                "result_length": .int(result.count),
                "duration_ms": .double(duration.milliseconds),
                "result_preview": .string(String(result.prefix(200)))
            ],
            agentName: agentName,
            toolName: name
        ))
    }

    /// Trace a tool error
    ///
    /// - Parameters:
    ///   - spanId: The span ID from traceToolCall
    ///   - name: The tool name
    ///   - error: The error that occurred
    public func traceToolError(spanId: UUID, name: String, error: Error) async {
        guard let tracer else { return }
        await tracer.trace(TraceEvent(
            traceId: traceId,
            spanId: spanId,
            kind: .toolError,
            level: .error,
            message: "Tool error: \(name)",
            metadata: [
                "tool_name": .string(name),
                "error_type": .string(String(describing: type(of: error))),
                "error_message": .string(error.localizedDescription)
            ],
            agentName: agentName,
            toolName: name,
            error: ErrorInfo(from: error)
        ))
    }

    // MARK: - Memory Events

    /// Trace a memory read operation
    ///
    /// - Parameters:
    ///   - count: Number of items read
    ///   - source: The memory source name
    public func traceMemoryRead(count: Int, source: String) async {
        guard let tracer else { return }
        await tracer.trace(TraceEvent(
            traceId: traceId,
            kind: .memoryRead,
            level: .debug,
            message: "Memory read from \(source)",
            metadata: [
                "count": .int(count),
                "source": .string(source)
            ],
            agentName: agentName
        ))
    }

    /// Trace a memory write operation
    ///
    /// - Parameters:
    ///   - count: Number of items written
    ///   - destination: The memory destination name
    public func traceMemoryWrite(count: Int, destination: String) async {
        guard let tracer else { return }
        await tracer.trace(TraceEvent(
            traceId: traceId,
            kind: .memoryWrite,
            level: .debug,
            message: "Memory write to \(destination)",
            metadata: [
                "count": .int(count),
                "destination": .string(destination)
            ],
            agentName: agentName
        ))
    }

    // MARK: - Decision Events

    /// Trace a decision point
    ///
    /// - Parameters:
    ///   - decision: The decision made
    ///   - options: Available options considered
    public func traceDecision(_ decision: String, options: [String] = []) async {
        guard let tracer else { return }
        var metadata: [String: SendableValue] = [
            "decision": .string(decision)
        ]
        if !options.isEmpty {
            metadata["options"] = .array(options.map { .string($0) })
        }
        await tracer.trace(TraceEvent(
            traceId: traceId,
            kind: .decision,
            message: "Decision: \(decision)",
            metadata: metadata,
            agentName: agentName
        ))
    }

    // MARK: - Checkpoint Events

    /// Trace a checkpoint
    ///
    /// - Parameters:
    ///   - name: The checkpoint name
    ///   - metadata: Additional metadata
    public func traceCheckpoint(name: String, metadata: [String: SendableValue] = [:]) async {
        guard let tracer else { return }
        var meta = metadata
        meta["checkpoint_name"] = .string(name)
        await tracer.trace(TraceEvent(
            traceId: traceId,
            kind: .checkpoint,
            message: "Checkpoint: \(name)",
            metadata: meta,
            agentName: agentName
        ))
    }

    // MARK: - Custom Events

    /// Trace a custom event
    ///
    /// - Parameters:
    ///   - kind: The event kind
    ///   - message: The event message
    ///   - metadata: Additional metadata
    public func traceCustom(
        kind: EventKind,
        message: String,
        metadata: [String: SendableValue] = [:]
    ) async {
        guard let tracer else { return }
        await tracer.trace(TraceEvent(
            traceId: traceId,
            kind: kind,
            message: message,
            metadata: metadata,
            agentName: agentName
        ))
    }

    // MARK: Private

    /// Start time of the traced operation
    private let startTime: ContinuousClock.Instant
}

// MARK: - Duration Extension

private extension Duration {
    var milliseconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) * 1000 + Double(attoseconds) / 1_000_000_000_000_000
    }
}
