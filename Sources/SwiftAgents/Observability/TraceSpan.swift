// TraceSpan.swift
// SwiftAgents Framework
//
// Represents a single operation span within a trace for distributed tracing.

import Foundation

// MARK: - SpanStatus

/// Status of a trace span.
public enum SpanStatus: String, Sendable, Codable, CaseIterable {
    /// Span is currently active/in-progress.
    case active
    /// Span completed successfully.
    case ok
    /// Span completed with an error.
    case error
    /// Span was cancelled before completion.
    case cancelled
}

// MARK: - TraceSpan

/// Represents a single operation span within a trace.
///
/// A span tracks a single unit of work within a distributed trace. Spans can be
/// nested to form a tree structure representing the call hierarchy of operations.
///
/// Example:
/// ```swift
/// let parentSpan = TraceSpan(name: "agent-execution")
/// let childSpan = TraceSpan(
///     parentSpanId: parentSpan.id,
///     name: "tool-call",
///     metadata: ["toolName": .string("calculator")]
/// )
/// ```
public struct TraceSpan: Sendable, Identifiable, Equatable, Hashable {
    /// Unique identifier for this span.
    public let id: UUID

    /// ID of the parent span, if any.
    /// Used to build the span hierarchy within a trace.
    public let parentSpanId: UUID?

    /// Human-readable name describing this operation.
    public let name: String

    /// Timestamp when this span started.
    public let startTime: Date

    /// Timestamp when this span ended.
    /// Nil if the span is still active.
    public let endTime: Date?

    /// Current status of this span.
    public let status: SpanStatus

    /// Additional metadata associated with this span.
    public let metadata: [String: SendableValue]

    /// Calculated duration of this span in seconds.
    ///
    /// Returns `nil` if the span is still active (no endTime).
    /// Returns the time interval between startTime and endTime otherwise.
    public var duration: TimeInterval? {
        guard let endTime else {
            return nil
        }
        return endTime.timeIntervalSince(startTime)
    }

    // MARK: - Initialization

    /// Creates a new trace span.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this span. Defaults to a new UUID.
    ///   - parentSpanId: ID of the parent span, if any.
    ///   - name: Human-readable name for this operation.
    ///   - startTime: When this span started. Defaults to now.
    ///   - endTime: When this span ended. Nil for active spans.
    ///   - status: Current status. Defaults to `.active`.
    ///   - metadata: Additional key-value metadata.
    public init(
        id: UUID = UUID(),
        parentSpanId: UUID? = nil,
        name: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        status: SpanStatus = .active,
        metadata: [String: SendableValue] = [:]
    ) {
        self.id = id
        self.parentSpanId = parentSpanId
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.metadata = metadata
    }

    // MARK: - Methods

    /// Returns a completed copy of this span with the given status.
    ///
    /// Creates a new span with the same properties but with `endTime` set to now
    /// and `status` set to the provided value. The original span is unchanged.
    ///
    /// - Parameter status: The completion status. Defaults to `.ok`.
    /// - Returns: A new span with endTime and status updated.
    ///
    /// Example:
    /// ```swift
    /// let activeSpan = TraceSpan(name: "operation")
    /// let completedSpan = activeSpan.completed()
    /// let errorSpan = activeSpan.completed(status: .error)
    /// ```
    public func completed(status: SpanStatus = .ok) -> TraceSpan {
        TraceSpan(
            id: id,
            parentSpanId: parentSpanId,
            name: name,
            startTime: startTime,
            endTime: Date(),
            status: status,
            metadata: metadata
        )
    }
}

// MARK: CustomStringConvertible

extension TraceSpan: CustomStringConvertible {
    public var description: String {
        var parts = ["TraceSpan(\(name))"]
        parts.append("status=\(status.rawValue)")

        if let duration {
            parts.append(String(format: "duration=%.3fms", duration * 1000))
        }

        if parentSpanId != nil {
            parts.append("hasParent=true")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: CustomDebugStringConvertible

extension TraceSpan: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        TraceSpan(
            id: \(id),
            parentSpanId: \(parentSpanId?.uuidString ?? "nil"),
            name: "\(name)",
            startTime: \(startTime),
            endTime: \(endTime?.description ?? "nil"),
            status: .\(status.rawValue),
            metadata: \(metadata)
        )
        """
    }
}
