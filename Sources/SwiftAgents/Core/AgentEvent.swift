// AgentEvent.swift
// SwiftAgents Framework
//
// Events emitted during agent execution for streaming and observation.

import Foundation

// MARK: - AgentEvent

/// Events emitted during agent execution, used for streaming responses.
///
/// These events allow observers to track the agent's progress through
/// its reasoning and action cycle.
///
/// Example:
/// ```swift
/// for try await event in agent.stream("What's 2+2?") {
///     switch event {
///     case .started(let input):
///         print("Started with: \(input)")
///     case .thinking(let thought):
///         print("Thinking: \(thought)")
///     case .toolCallStarted(let call):
///         print("Calling tool: \(call.toolName)")
///     case .completed(let result):
///         print("Result: \(result.output)")
///     default:
///         break
///     }
/// }
/// ```
public enum AgentEvent: Sendable {
    // MARK: - Lifecycle Events

    /// Agent execution has started.
    case started(input: String)

    /// Agent execution has completed successfully.
    case completed(result: AgentResult)

    /// Agent execution failed with an error.
    case failed(error: AgentError)

    /// Agent execution was cancelled.
    case cancelled

    // MARK: - Thinking Events

    /// Agent is thinking/reasoning (ReAct "Thought" step).
    case thinking(thought: String)

    /// Partial thought during streaming.
    case thinkingPartial(partialThought: String)

    // MARK: - Tool Events

    /// Agent is calling a tool (ReAct "Action" step).
    case toolCallStarted(call: ToolCall)

    /// Tool execution completed (ReAct "Observation" step).
    case toolCallCompleted(call: ToolCall, result: ToolResult)

    /// Tool execution failed.
    case toolCallFailed(call: ToolCall, error: AgentError)

    // MARK: - Output Events

    /// Final output token (for streaming).
    case outputToken(token: String)

    /// Final output chunk (larger than single token).
    case outputChunk(chunk: String)

    // MARK: - Iteration Events

    /// New iteration started in the reasoning loop.
    case iterationStarted(number: Int)

    /// Iteration completed.
    case iterationCompleted(number: Int)
}

// MARK: - ToolCall

/// Represents a tool call made by the agent.
///
/// A ToolCall captures all the information about an agent's decision
/// to invoke a particular tool with specific arguments.
public struct ToolCall: Sendable, Equatable, Identifiable, Codable {
    /// Unique identifier for this tool call.
    public let id: UUID

    /// Name of the tool being called.
    public let toolName: String

    /// Arguments passed to the tool.
    public let arguments: [String: SendableValue]

    /// Timestamp when the call was initiated.
    public let timestamp: Date

    /// Creates a new tool call.
    /// - Parameters:
    ///   - id: Unique identifier. Default: new UUID
    ///   - toolName: The name of the tool.
    ///   - arguments: Arguments for the tool.
    ///   - timestamp: When the call was made. Default: now
    public init(
        id: UUID = UUID(),
        toolName: String,
        arguments: [String: SendableValue] = [:],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.toolName = toolName
        self.arguments = arguments
        self.timestamp = timestamp
    }
}

// MARK: - ToolResult

/// Represents the result of a tool execution.
///
/// A ToolResult captures the outcome of a tool invocation, including
/// success/failure status, the output value, and timing information.
public struct ToolResult: Sendable, Equatable, Codable {
    /// The tool call that produced this result.
    public let callId: UUID

    /// Whether the tool execution was successful.
    public let isSuccess: Bool

    /// The output value from the tool.
    public let output: SendableValue

    /// Duration of the tool execution.
    public let duration: Duration

    /// Error message if the tool failed.
    public let errorMessage: String?

    /// Creates a new tool result.
    /// - Parameters:
    ///   - callId: The ID of the tool call.
    ///   - isSuccess: Whether execution succeeded.
    ///   - output: The output value.
    ///   - duration: Execution duration.
    ///   - errorMessage: Error message on failure.
    public init(
        callId: UUID,
        isSuccess: Bool,
        output: SendableValue,
        duration: Duration,
        errorMessage: String? = nil
    ) {
        self.callId = callId
        self.isSuccess = isSuccess
        self.output = output
        self.duration = duration
        self.errorMessage = errorMessage
    }

    /// Creates a successful result.
    /// - Parameters:
    ///   - callId: The ID of the tool call.
    ///   - output: The output value.
    ///   - duration: Execution duration.
    /// - Returns: A successful ToolResult.
    public static func success(callId: UUID, output: SendableValue, duration: Duration) -> ToolResult {
        ToolResult(callId: callId, isSuccess: true, output: output, duration: duration)
    }

    /// Creates a failed result.
    /// - Parameters:
    ///   - callId: The ID of the tool call.
    ///   - error: The error message.
    ///   - duration: Execution duration.
    /// - Returns: A failed ToolResult.
    public static func failure(callId: UUID, error: String, duration: Duration) -> ToolResult {
        ToolResult(callId: callId, isSuccess: false, output: .null, duration: duration, errorMessage: error)
    }
}

// MARK: - ToolCall + CustomStringConvertible

extension ToolCall: CustomStringConvertible {
    public var description: String {
        "ToolCall(\(toolName), args: \(arguments))"
    }
}

// MARK: - ToolResult + CustomStringConvertible

extension ToolResult: CustomStringConvertible {
    public var description: String {
        if isSuccess {
            "ToolResult(success: \(output), duration: \(duration))"
        } else {
            "ToolResult(failure: \(errorMessage ?? "unknown"), duration: \(duration))"
        }
    }
}

// MARK: - AgentEvent + Equatable

extension AgentEvent: Equatable {
    public static func == (lhs: AgentEvent, rhs: AgentEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.started(lhsInput), .started(rhsInput)):
            lhsInput == rhsInput
        case let (.completed(lhsResult), .completed(rhsResult)):
            lhsResult == rhsResult
        case let (.failed(lhsError), .failed(rhsError)):
            lhsError == rhsError
        case (.cancelled, .cancelled):
            true
        case let (.thinking(lhsThought), .thinking(rhsThought)):
            lhsThought == rhsThought
        case let (.thinkingPartial(lhsPartial), .thinkingPartial(rhsPartial)):
            lhsPartial == rhsPartial
        case let (.toolCallStarted(lhsCall), .toolCallStarted(rhsCall)):
            lhsCall == rhsCall
        case let (.toolCallCompleted(lhsCall, lhsResult), .toolCallCompleted(rhsCall, rhsResult)):
            lhsCall == rhsCall && lhsResult == rhsResult
        case let (.toolCallFailed(lhsCall, lhsError), .toolCallFailed(rhsCall, rhsError)):
            lhsCall == rhsCall && lhsError == rhsError
        case let (.outputToken(lhsToken), .outputToken(rhsToken)):
            lhsToken == rhsToken
        case let (.outputChunk(lhsChunk), .outputChunk(rhsChunk)):
            lhsChunk == rhsChunk
        case let (.iterationStarted(lhsNumber), .iterationStarted(rhsNumber)):
            lhsNumber == rhsNumber
        case let (.iterationCompleted(lhsNumber), .iterationCompleted(rhsNumber)):
            lhsNumber == rhsNumber
        default:
            false
        }
    }
}

// MARK: - AgentEvent + Comparison Helper

extension AgentEvent {
    /// Compares this event to another for equality.
    ///
    /// This is a convenience method that enables comparison in contexts
    /// where the static `==` operator is inconvenient.
    ///
    /// - Parameter other: The event to compare with.
    /// - Returns: True if the events are equal.
    func isEqual(to other: AgentEvent) -> Bool {
        self == other
    }
}
