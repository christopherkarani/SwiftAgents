// AgentEvent.swift
// Swarm Framework
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

    /// Guardrail validation failed.
    case guardrailFailed(error: GuardrailError)

    // MARK: - Thinking Events

    /// Agent is thinking/reasoning (ReAct "Thought" step).
    case thinking(thought: String)

    /// Partial thought during streaming.
    case thinkingPartial(partialThought: String)

    // MARK: - Tool Events

    /// Agent is calling a tool (ReAct "Action" step).
    case toolCallStarted(call: ToolCall)

    /// Tool call arguments are being streamed (partial JSON fragments).
    ///
    /// This event is emitted before tool execution begins and is intended for live UI.
    case toolCallPartial(update: PartialToolCallUpdate)

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

    // MARK: - Decision Events

    /// Agent made a decision
    case decision(decision: String, options: [String]?)

    /// Agent created or updated a plan
    case planUpdated(plan: String, stepCount: Int)

    // MARK: - Handoff Events

    /// Agent handoff initiated
    case handoffRequested(fromAgent: String, toAgent: String, reason: String?)

    /// Agent handoff completed
    case handoffCompleted(fromAgent: String, toAgent: String)

    /// A handoff to another agent started with input.
    case handoffStarted(from: String, to: String, input: String)

    /// A handoff to another agent completed with result.
    case handoffCompletedWithResult(from: String, to: String, result: AgentResult)

    /// A handoff was skipped because it was disabled.
    case handoffSkipped(from: String, to: String, reason: String)

    // MARK: - Guardrail Events

    /// Guardrail check started
    case guardrailStarted(name: String, type: GuardrailType)

    /// Guardrail check passed
    case guardrailPassed(name: String, type: GuardrailType)

    /// Guardrail tripwire triggered
    case guardrailTriggered(name: String, type: GuardrailType, message: String?)

    // MARK: - Memory Events

    /// Memory was accessed
    case memoryAccessed(operation: MemoryOperation, count: Int)

    // MARK: - LLM Events

    /// LLM call started
    case llmStarted(model: String?, promptTokens: Int?)

    /// LLM call completed
    case llmCompleted(model: String?, promptTokens: Int?, completionTokens: Int?, duration: TimeInterval)
}

// MARK: - GuardrailType

/// Type of guardrail check
public enum GuardrailType: String, Sendable, Codable {
    case input
    case output
    case toolInput
    case toolOutput
}

// MARK: - MemoryOperation

/// Type of memory operation
public enum MemoryOperation: String, Sendable, Codable {
    case read
    case write
    case search
    case clear
}

// MARK: - ToolCall

/// Represents a tool call made by the agent.
///
/// A ToolCall captures all the information about an agent's decision
/// to invoke a particular tool with specific arguments.
public struct ToolCall: Sendable, Equatable, Identifiable, Codable {
    /// Unique identifier for this tool call.
    public let id: UUID

    /// Provider-assigned tool call identifier, if available (e.g. OpenAI/Anthropic tool call IDs).
    ///
    /// This enables correlation across provider-native tool calling flows and multi-turn tool interactions.
    public let providerCallId: String?

    /// Name of the tool being called.
    public let toolName: String

    /// Arguments passed to the tool.
    public let arguments: [String: SendableValue]

    /// Timestamp when the call was initiated.
    public let timestamp: Date

    /// Creates a new tool call.
    /// - Parameters:
    ///   - id: Unique identifier. Default: new UUID
    ///   - providerCallId: Provider-assigned tool call identifier. Default: nil
    ///   - toolName: The name of the tool.
    ///   - arguments: Arguments for the tool.
    ///   - timestamp: When the call was made. Default: now
    public init(
        id: UUID = UUID(),
        providerCallId: String? = nil,
        toolName: String,
        arguments: [String: SendableValue] = [:],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.providerCallId = providerCallId
        self.toolName = toolName
        self.arguments = arguments
        self.timestamp = timestamp
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case providerCallId
        case toolName
        case arguments
        case timestamp
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        providerCallId = try container.decodeIfPresent(String.self, forKey: .providerCallId)
        toolName = try container.decode(String.self, forKey: .toolName)
        arguments = try container.decode([String: SendableValue].self, forKey: .arguments)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(providerCallId, forKey: .providerCallId)
        try container.encode(toolName, forKey: .toolName)
        try container.encode(arguments, forKey: .arguments)
        try container.encode(timestamp, forKey: .timestamp)
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
    // MARK: Public

    public static func == (lhs: AgentEvent, rhs: AgentEvent) -> Bool {
        switch (lhs, rhs) {
        // Lifecycle events
        case let (.started(lhsInput), .started(rhsInput)):
            lhsInput == rhsInput

        case let (.completed(lhsResult), .completed(rhsResult)):
            lhsResult == rhsResult

        case let (.failed(lhsError), .failed(rhsError)):
            lhsError == rhsError

        case (.cancelled, .cancelled):
            true

        case let (.guardrailFailed(lhsError), .guardrailFailed(rhsError)):
            lhsError == rhsError

        // Thinking events - delegated to helper
        case (.thinking, .thinking),
             (.thinkingPartial, .thinkingPartial):
            lhs.isEqualThinkingEvent(rhs)

        // Tool events - delegated to helper
        case (.toolCallCompleted, .toolCallCompleted),
             (.toolCallFailed, .toolCallFailed),
             (.toolCallPartial, .toolCallPartial),
             (.toolCallStarted, .toolCallStarted):
            lhs.isEqualToolEvent(rhs)

        // Output events - delegated to helper
        case (.outputChunk, .outputChunk),
             (.outputToken, .outputToken):
            lhs.isEqualOutputEvent(rhs)

        // Iteration events - delegated to helper
        case (.iterationCompleted, .iterationCompleted),
             (.iterationStarted, .iterationStarted):
            lhs.isEqualIterationEvent(rhs)

        // Decision events
        case let (.decision(lhsDecision, lhsOptions), .decision(rhsDecision, rhsOptions)):
            lhsDecision == rhsDecision && lhsOptions == rhsOptions

        case let (.planUpdated(lhsPlan, lhsCount), .planUpdated(rhsPlan, rhsCount)):
            lhsPlan == rhsPlan && lhsCount == rhsCount

        // Handoff events - delegated to helper
        case (.handoffCompleted, .handoffCompleted),
             (.handoffCompletedWithResult, .handoffCompletedWithResult),
             (.handoffRequested, .handoffRequested),
             (.handoffSkipped, .handoffSkipped),
             (.handoffStarted, .handoffStarted):
            lhs.isEqualHandoffEvent(rhs)

        // Guardrail events - delegated to helper
        case (.guardrailPassed, .guardrailPassed),
             (.guardrailStarted, .guardrailStarted),
             (.guardrailTriggered, .guardrailTriggered):
            lhs.isEqualGuardrailEvent(rhs)

        // LLM and memory events - delegated to helper
        case (.llmCompleted, .llmCompleted),
             (.llmStarted, .llmStarted),
             (.memoryAccessed, .memoryAccessed):
            lhs.isEqualLLMAndMemoryEvent(rhs)

        default:
            false
        }
    }

    // MARK: Private

    // MARK: - Private Equality Helpers

    /// Compares thinking events for equality.
    private func isEqualThinkingEvent(_ other: AgentEvent) -> Bool {
        switch (self, other) {
        case let (.thinking(lhsThought), .thinking(rhsThought)):
            lhsThought == rhsThought
        case let (.thinkingPartial(lhsPartial), .thinkingPartial(rhsPartial)):
            lhsPartial == rhsPartial
        default:
            false
        }
    }

    /// Compares tool events for equality.
    private func isEqualToolEvent(_ other: AgentEvent) -> Bool {
        switch (self, other) {
        case let (.toolCallStarted(lhsCall), .toolCallStarted(rhsCall)):
            lhsCall == rhsCall
        case let (.toolCallPartial(lhsUpdate), .toolCallPartial(rhsUpdate)):
            lhsUpdate == rhsUpdate
        case let (.toolCallCompleted(lhsCall, lhsResult), .toolCallCompleted(rhsCall, rhsResult)):
            lhsCall == rhsCall && lhsResult == rhsResult
        case let (.toolCallFailed(lhsCall, lhsError), .toolCallFailed(rhsCall, rhsError)):
            lhsCall == rhsCall && lhsError == rhsError
        default:
            false
        }
    }

    /// Compares output events for equality.
    private func isEqualOutputEvent(_ other: AgentEvent) -> Bool {
        switch (self, other) {
        case let (.outputToken(lhsToken), .outputToken(rhsToken)):
            lhsToken == rhsToken
        case let (.outputChunk(lhsChunk), .outputChunk(rhsChunk)):
            lhsChunk == rhsChunk
        default:
            false
        }
    }

    /// Compares iteration events for equality.
    private func isEqualIterationEvent(_ other: AgentEvent) -> Bool {
        switch (self, other) {
        case let (.iterationStarted(lhsNumber), .iterationStarted(rhsNumber)):
            lhsNumber == rhsNumber
        case let (.iterationCompleted(lhsNumber), .iterationCompleted(rhsNumber)):
            lhsNumber == rhsNumber
        default:
            false
        }
    }

    /// Compares handoff events for equality.
    private func isEqualHandoffEvent(_ other: AgentEvent) -> Bool {
        switch (self, other) {
        case let (.handoffRequested(lhsFrom, lhsTo, lhsReason), .handoffRequested(rhsFrom, rhsTo, rhsReason)):
            lhsFrom == rhsFrom && lhsTo == rhsTo && lhsReason == rhsReason
        case let (.handoffCompleted(lhsFrom, lhsTo), .handoffCompleted(rhsFrom, rhsTo)):
            lhsFrom == rhsFrom && lhsTo == rhsTo
        case let (.handoffStarted(lhsFrom, lhsTo, lhsInput), .handoffStarted(rhsFrom, rhsTo, rhsInput)):
            lhsFrom == rhsFrom && lhsTo == rhsTo && lhsInput == rhsInput
        case let (.handoffCompletedWithResult(lhsFrom, lhsTo, lhsResult), .handoffCompletedWithResult(rhsFrom, rhsTo, rhsResult)):
            lhsFrom == rhsFrom && lhsTo == rhsTo && lhsResult == rhsResult
        case let (.handoffSkipped(lhsFrom, lhsTo, lhsReason), .handoffSkipped(rhsFrom, rhsTo, rhsReason)):
            lhsFrom == rhsFrom && lhsTo == rhsTo && lhsReason == rhsReason
        default:
            false
        }
    }

    /// Compares guardrail events for equality.
    private func isEqualGuardrailEvent(_ other: AgentEvent) -> Bool {
        switch (self, other) {
        case let (.guardrailStarted(lhsName, lhsType), .guardrailStarted(rhsName, rhsType)):
            lhsName == rhsName && lhsType == rhsType
        case let (.guardrailPassed(lhsName, lhsType), .guardrailPassed(rhsName, rhsType)):
            lhsName == rhsName && lhsType == rhsType
        case let (.guardrailTriggered(lhsName, lhsType, lhsMsg), .guardrailTriggered(rhsName, rhsType, rhsMsg)):
            lhsName == rhsName && lhsType == rhsType && lhsMsg == rhsMsg
        default:
            false
        }
    }

    /// Compares LLM and memory events for equality.
    private func isEqualLLMAndMemoryEvent(_ other: AgentEvent) -> Bool {
        switch (self, other) {
        case let (.memoryAccessed(lhsOp, lhsCount), .memoryAccessed(rhsOp, rhsCount)):
            lhsOp == rhsOp && lhsCount == rhsCount
        case let (.llmStarted(lhsModel, lhsTokens), .llmStarted(rhsModel, rhsTokens)):
            lhsModel == rhsModel && lhsTokens == rhsTokens
        case let (.llmCompleted(lhsModel, lhsPrompt, lhsCompletion, lhsDuration), .llmCompleted(rhsModel, rhsPrompt, rhsCompletion, rhsDuration)):
            lhsModel == rhsModel && lhsPrompt == rhsPrompt && lhsCompletion == rhsCompletion && lhsDuration == rhsDuration
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
