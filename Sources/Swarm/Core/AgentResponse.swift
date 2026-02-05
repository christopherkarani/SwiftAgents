// AgentResponse.swift
// Swarm Framework
//
// Response type for agent execution with enhanced tracking capabilities.

import Foundation

// MARK: - ToolCallRecord

/// Record of a tool call execution with its result.
///
/// `ToolCallRecord` provides a complete picture of a single tool invocation,
/// including the tool name, arguments passed, result received, and timing information.
/// This is useful for debugging, logging, and analyzing agent behavior.
///
/// Example:
/// ```swift
/// let record = ToolCallRecord(
///     toolName: "calculator",
///     arguments: ["operation": "add", "a": 5, "b": 3],
///     result: .int(8),
///     duration: .seconds(0.05),
///     timestamp: Date()
/// )
///
/// print("Tool: \(record.toolName)")        // "calculator"
/// print("Result: \(record.result)")        // "8"
/// print("Duration: \(record.duration)")    // "0.05 seconds"
/// ```
public struct ToolCallRecord: Sendable, Equatable, Codable {
    /// The name of the tool that was called.
    public let toolName: String

    /// The arguments passed to the tool.
    public let arguments: [String: SendableValue]

    /// The result returned by the tool.
    public let result: SendableValue

    /// How long the tool execution took.
    public let duration: Duration

    /// When the tool call was initiated.
    public let timestamp: Date

    /// Whether the tool execution was successful.
    public let isSuccess: Bool

    /// Error message if the tool execution failed.
    public let errorMessage: String?

    /// Creates a new tool call record.
    ///
    /// - Parameters:
    ///   - toolName: The name of the tool that was called.
    ///   - arguments: The arguments passed to the tool. Default: `[:]`
    ///   - result: The result returned by the tool. Default: `.null`
    ///   - duration: How long the tool execution took. Default: `.zero`
    ///   - timestamp: When the tool call was initiated. Default: now
    ///   - isSuccess: Whether the tool execution was successful. Default: `true`
    ///   - errorMessage: Error message if the tool execution failed. Default: `nil`
    public init(
        toolName: String,
        arguments: [String: SendableValue] = [:],
        result: SendableValue = .null,
        duration: Duration = .zero,
        timestamp: Date = Date(),
        isSuccess: Bool = true,
        errorMessage: String? = nil
    ) {
        self.toolName = toolName
        self.arguments = arguments
        self.result = result
        self.duration = duration
        self.timestamp = timestamp
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
    }
}

// MARK: CustomStringConvertible

extension ToolCallRecord: CustomStringConvertible {
    public var description: String {
        "ToolCallRecord(\(toolName), result: \(result), duration: \(duration))"
    }
}

// MARK: CustomDebugStringConvertible

extension ToolCallRecord: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        ToolCallRecord(
            toolName: "\(toolName)",
            arguments: \(arguments),
            result: \(result),
            duration: \(duration),
            timestamp: \(timestamp)
        )
        """
    }
}

// MARK: - AgentResponse

/// Response from an agent execution with tracking metadata.
///
/// `AgentResponse` extends the information in `AgentResult` with response
/// tracking capabilities including unique IDs and timestamps. It provides
/// a complete picture of an agent's execution including output, metadata,
/// tool calls made, and token usage.
///
/// Use `AgentResponse` when you need:
/// - Unique response identification for logging or tracking
/// - Agent attribution for multi-agent systems
/// - Detailed tool call records with results
/// - Easy conversion to `AgentResult` for backward compatibility
///
/// Example:
/// ```swift
/// let response = AgentResponse(
///     output: "The answer is 42",
///     agentName: "CalculatorAgent",
///     metadata: ["confidence": 0.95],
///     toolCalls: [
///         ToolCallRecord(
///             toolName: "calculator",
///             arguments: ["expression": "6 * 7"],
///             result: .int(42),
///             duration: .milliseconds(50)
///         )
///     ],
///     usage: TokenUsage(inputTokens: 100, outputTokens: 25)
/// )
///
/// print(response.responseId)        // "550e8400-e29b-41d4-a716-446655440000"
/// print(response.output)            // "The answer is 42"
/// print(response.agentName)         // "CalculatorAgent"
/// print(response.toolCalls.count)   // 1
///
/// // Convert to AgentResult for backward compatibility
/// let result = response.asResult
/// ```
public struct AgentResponse: Sendable {
    /// Unique identifier for this response.
    ///
    /// Automatically generated if not provided. Useful for tracking
    /// and correlating responses in logs or databases.
    public let responseId: String

    /// The agent's output text.
    public let output: String

    /// Name of the agent that produced this response.
    public let agentName: String

    /// When this response was created.
    public let timestamp: Date

    /// Additional metadata about the response.
    ///
    /// Can contain any `SendableValue` data for custom tracking,
    /// debugging information, or application-specific needs.
    public let metadata: [String: SendableValue]

    /// Tool calls made during execution with their results.
    ///
    /// Each `ToolCallRecord` contains the complete information about
    /// a tool invocation including arguments, result, and timing.
    public let toolCalls: [ToolCallRecord]

    /// Token usage if available from the underlying model.
    public let usage: TokenUsage?

    /// Number of agent iterations during execution.
    ///
    /// An iteration represents one complete reasoning cycle, which may include
    /// zero or more tool calls. This provides an accurate count rather than
    /// deriving it from tool call count.
    public let iterationCount: Int

    /// Converts this response to an `AgentResult` for backward compatibility.
    ///
    /// This computed property allows `AgentResponse` to be used in contexts
    /// that expect `AgentResult`. The conversion maps:
    /// - `output` -> `output`
    /// - `toolCalls` -> converted to `[ToolCall]` and `[ToolResult]`
    /// - `usage` -> `tokenUsage`
    /// - `metadata` -> `metadata`
    ///
    /// Note: Some information is lost in conversion (responseId, agentName,
    /// timestamp at the response level).
    ///
    /// Example:
    /// ```swift
    /// let response = AgentResponse(output: "Hello", agentName: "Greeter")
    /// let result: AgentResult = response.asResult
    /// print(result.output)  // "Hello"
    /// ```
    public var asResult: AgentResult {
        // Convert ToolCallRecords to ToolCalls and ToolResults
        var convertedToolCalls: [ToolCall] = []
        var convertedToolResults: [ToolResult] = []

        for record in toolCalls {
            let callId = UUID()
            let toolCall = ToolCall(
                id: callId,
                toolName: record.toolName,
                arguments: record.arguments,
                timestamp: record.timestamp
            )
            convertedToolCalls.append(toolCall)

            let toolResult = ToolResult(
                callId: callId,
                isSuccess: record.isSuccess,
                output: record.result,
                duration: record.duration,
                errorMessage: record.errorMessage
            )
            convertedToolResults.append(toolResult)
        }

        // Calculate total duration from tool calls
        let totalDuration = toolCalls.reduce(Duration.zero) { $0 + $1.duration }

        return AgentResult(
            output: output,
            toolCalls: convertedToolCalls,
            toolResults: convertedToolResults,
            iterationCount: iterationCount,
            duration: totalDuration,
            tokenUsage: usage,
            metadata: metadata
        )
    }

    /// Creates a new agent response.
    ///
    /// - Parameters:
    ///   - responseId: Unique identifier for this response. Default: new UUID string
    ///   - output: The agent's output text.
    ///   - agentName: Name of the agent that produced this response.
    ///   - timestamp: When this response was created. Default: now
    ///   - metadata: Additional metadata about the response. Default: `[:]`
    ///   - toolCalls: Tool calls made during execution. Default: `[]`
    ///   - usage: Token usage if available. Default: `nil`
    ///   - iterationCount: Number of agent iterations. Default: `1`
    public init(
        responseId: String = UUID().uuidString,
        output: String,
        agentName: String,
        timestamp: Date = Date(),
        metadata: [String: SendableValue] = [:],
        toolCalls: [ToolCallRecord] = [],
        usage: TokenUsage? = nil,
        iterationCount: Int = 1
    ) {
        self.responseId = responseId
        self.output = output
        self.agentName = agentName
        self.timestamp = timestamp
        self.metadata = metadata
        self.toolCalls = toolCalls
        self.usage = usage
        self.iterationCount = iterationCount
    }
}

// MARK: Equatable

extension AgentResponse: Equatable {
    public static func == (lhs: AgentResponse, rhs: AgentResponse) -> Bool {
        lhs.responseId == rhs.responseId &&
            lhs.output == rhs.output &&
            lhs.agentName == rhs.agentName &&
            lhs.timestamp == rhs.timestamp &&
            lhs.metadata == rhs.metadata &&
            lhs.toolCalls == rhs.toolCalls &&
            lhs.usage == rhs.usage &&
            lhs.iterationCount == rhs.iterationCount
    }
}

// MARK: CustomStringConvertible

extension AgentResponse: CustomStringConvertible {
    public var description: String {
        """
        AgentResponse(
            id: "\(responseId.prefix(8))...",
            agent: "\(agentName)",
            output: "\(output.prefix(100))\(output.count > 100 ? "..." : "")",
            toolCalls: \(toolCalls.count),
            usage: \(usage?.description ?? "nil")
        )
        """
    }
}

// MARK: CustomDebugStringConvertible

extension AgentResponse: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        AgentResponse(
            responseId: "\(responseId)",
            output: "\(output)",
            agentName: "\(agentName)",
            timestamp: \(timestamp),
            metadata: \(metadata),
            toolCalls: \(toolCalls),
            usage: \(String(describing: usage))
        )
        """
    }
}
