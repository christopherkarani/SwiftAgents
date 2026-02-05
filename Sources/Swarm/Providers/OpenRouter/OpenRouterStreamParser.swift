// OpenRouterStreamParser.swift
// Swarm Framework
//
// OpenAI-compatible SSE parser for OpenRouter streaming responses.

import Foundation

// MARK: - OpenRouterStreamEvent

/// Events emitted during OpenRouter streaming responses.
///
/// These events represent the different types of data that can be received
/// from an OpenAI-compatible streaming API.
public enum OpenRouterStreamEvent: Sendable, Equatable {
    /// A text content delta.
    case textDelta(String)

    /// A tool call delta with streaming fragments.
    /// - Parameters:
    ///   - index: The index of the tool call in the array.
    ///   - id: The tool call ID (may be nil for subsequent deltas).
    ///   - name: The function name (may be nil for subsequent deltas).
    ///   - arguments: The partial arguments JSON string.
    case toolCallDelta(index: Int, id: String?, name: String?, arguments: String)

    /// The finish reason for the response.
    case finishReason(String)

    /// Token usage information.
    /// - Parameters:
    ///   - prompt: Number of prompt tokens used.
    ///   - completion: Number of completion tokens used.
    case usage(prompt: Int, completion: Int)

    /// Stream has completed (received `data: [DONE]`).
    case done

    /// An error occurred during streaming.
    case error(OpenRouterProviderError)
}

// MARK: - OpenRouterStreamChunk

/// Decodable structure for parsing OpenAI-compatible streaming JSON chunks.
///
/// This structure mirrors the OpenAI chat completion chunk format used by OpenRouter.
public struct OpenRouterStreamChunk: Decodable, Sendable {
    // MARK: - StreamChoice

    /// A single choice in the streaming response.
    public struct StreamChoice: Decodable, Sendable {
        // MARK: Public

        /// Index of this choice.
        public let index: Int

        /// The delta content for this chunk.
        public let delta: Delta?

        /// Reason the generation finished (if applicable).
        public let finishReason: String?

        /// Log probabilities (if requested).
        public let logprobs: LogProbs?

        // MARK: Private

        private enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
            case logprobs
        }
    }

    // MARK: - Delta

    /// The incremental content in a streaming chunk.
    public struct Delta: Decodable, Sendable {
        // MARK: Public

        /// Role of the message (usually only in first chunk).
        public let role: String?

        /// Text content delta.
        public let content: String?

        /// Tool calls being streamed.
        public let toolCalls: [ToolCallDelta]?

        /// Function call (legacy format).
        public let functionCall: FunctionCallDelta?

        // MARK: Private

        private enum CodingKeys: String, CodingKey {
            case role
            case content
            case toolCalls = "tool_calls"
            case functionCall = "function_call"
        }
    }

    // MARK: - ToolCallDelta

    /// A streaming tool call delta.
    public struct ToolCallDelta: Decodable, Sendable {
        /// Index of this tool call.
        public let index: Int

        /// Tool call ID (present in first delta).
        public let id: String?

        /// Type of tool call (typically "function").
        public let type: String?

        /// Function details.
        public let function: FunctionDelta?
    }

    // MARK: - FunctionDelta

    /// A streaming function call delta.
    public struct FunctionDelta: Decodable, Sendable {
        /// Function name (present in first delta).
        public let name: String?

        /// Partial arguments JSON string.
        public let arguments: String?
    }

    // MARK: - FunctionCallDelta (Legacy)

    /// Legacy function call delta format.
    public struct FunctionCallDelta: Decodable, Sendable {
        /// Function name.
        public let name: String?

        /// Partial arguments.
        public let arguments: String?
    }

    // MARK: - StreamUsage

    /// Token usage information.
    public struct StreamUsage: Decodable, Sendable {
        // MARK: Public

        /// Number of tokens in the prompt.
        public let promptTokens: Int

        /// Number of tokens in the completion.
        public let completionTokens: Int

        /// Total tokens used.
        public let totalTokens: Int

        // MARK: Private

        private enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }

    // MARK: - LogProbs

    /// Log probability information.
    public struct LogProbs: Decodable, Sendable {
        /// Token log probability detail.
        public struct TokenLogProb: Decodable, Sendable {
            /// The token.
            public let token: String

            /// Log probability of the token.
            public let logprob: Double

            /// Byte representation.
            public let bytes: [Int]?
        }

        /// Content log probabilities.
        public let content: [TokenLogProb]?
    }

    // MARK: - StreamError

    /// Error information in a stream chunk.
    public struct StreamError: Decodable, Sendable {
        /// Error message.
        public let message: String

        /// Error type.
        public let type: String?

        /// Error code.
        public let code: String?
    }

    /// Unique identifier for the chunk.
    public let id: String?

    /// Object type (typically "chat.completion.chunk").
    public let object: String?

    /// Unix timestamp of creation.
    public let created: Int?

    /// Model used for generation.
    public let model: String?

    /// Array of choices containing the actual content.
    public let choices: [StreamChoice]?

    /// Token usage information (usually only in final chunk).
    public let usage: StreamUsage?

    /// Error information if the chunk represents an error.
    public let error: StreamError?
}

// MARK: - OpenRouterStreamParser

/// Parser for OpenAI-compatible Server-Sent Events (SSE) streams.
///
/// This parser handles the SSE format used by OpenRouter and other OpenAI-compatible APIs:
/// - Lines starting with `data: ` contain JSON payloads
/// - `data: [DONE]` indicates stream completion
/// - Lines starting with `:` are comments/keep-alives and should be ignored
/// - Empty lines are chunk separators and should be ignored
///
/// Example usage:
/// ```swift
/// let parser = OpenRouterStreamParser()
/// for line in sseLines {
///     if let events = parser.parse(line: line) {
///         for event in events {
///             switch event {
///             case .textDelta(let text):
///                 print(text)
///             case .done:
///                 print("Stream complete")
///             default:
///                 break
///             }
///         }
///     }
/// }
/// ```
public struct OpenRouterStreamParser: Sendable {
    // MARK: Public

    /// Creates a new stream parser.
    public init() {}

    /// Parses a single SSE line and returns any events it contains.
    ///
    /// - Parameter line: A single line from the SSE stream.
    /// - Returns: An array of events parsed from the line, or nil if the line should be ignored.
    ///
    /// The parser handles the following line types:
    /// - Empty lines: Ignored (returns nil)
    /// - Lines starting with `:`: SSE comments/keep-alives, ignored (returns nil)
    /// - `data: [DONE]`: Returns `.done` event
    /// - `data: {...}`: Parses JSON and returns appropriate events
    public func parse(line: String) -> [OpenRouterStreamEvent]? {
        // Ignore empty lines (chunk separators)
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLine.isEmpty {
            return nil
        }

        // Ignore SSE comments (keep-alive signals)
        if trimmedLine.hasPrefix(":") {
            return nil
        }

        // Check for data prefix
        // Handle both "data: " (with space) and "data:" (without space) formats
        guard trimmedLine.hasPrefix("data:") else {
            // Not a data line, ignore
            return nil
        }

        // Extract the data payload
        let dataPayload = if trimmedLine.hasPrefix("data: ") {
            String(trimmedLine.dropFirst(6))
        } else {
            String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        }
        let data = dataPayload

        // Check for stream termination
        if data == "[DONE]" {
            return [.done]
        }

        // Parse JSON data
        guard let jsonData = data.data(using: .utf8) else {
            return [.error(.decodingError(SendableErrorWrapper(description: "Failed to convert data to UTF-8")))]
        }

        // Create a new JSONDecoder for each parse call to ensure thread safety
        // JSONDecoder is not Sendable, so we create it locally
        let decoder = JSONDecoder()

        do {
            let chunk = try decoder.decode(OpenRouterStreamChunk.self, from: jsonData)
            return extractEvents(from: chunk)
        } catch {
            let errorType = String(describing: type(of: error))
            return [.error(.decodingError(SendableErrorWrapper(description: "JSON decode failed: \(errorType)")))]
        }
    }

    // MARK: Private

    /// Extracts events from a parsed stream chunk.
    ///
    /// - Parameter chunk: The parsed stream chunk.
    /// - Returns: An array of events extracted from the chunk.
    private func extractEvents(from chunk: OpenRouterStreamChunk) -> [OpenRouterStreamEvent] {
        var events: [OpenRouterStreamEvent] = []

        // Check for errors first
        if let error = chunk.error {
            let providerError = mapStreamError(error)
            events.append(.error(providerError))
            return events
        }

        // Process choices
        if let choices = chunk.choices {
            for choice in choices {
                // Extract text content delta
                if let content = choice.delta?.content, !content.isEmpty {
                    events.append(.textDelta(content))
                }

                // Extract tool call deltas
                if let toolCalls = choice.delta?.toolCalls {
                    for toolCall in toolCalls {
                        events.append(.toolCallDelta(
                            index: toolCall.index,
                            id: toolCall.id,
                            name: toolCall.function?.name,
                            arguments: toolCall.function?.arguments ?? ""
                        ))
                    }
                }

                // Extract legacy function call (if present)
                // Only process legacy functionCall if no modern toolCalls exist
                if choice.delta?.toolCalls == nil, let functionCall = choice.delta?.functionCall {
                    events.append(.toolCallDelta(
                        index: 0,
                        id: nil,
                        name: functionCall.name,
                        arguments: functionCall.arguments ?? ""
                    ))
                }

                // Extract finish reason
                if let finishReason = choice.finishReason {
                    events.append(.finishReason(finishReason))
                }
            }
        }

        // Extract usage information
        if let usage = chunk.usage {
            events.append(.usage(
                prompt: usage.promptTokens,
                completion: usage.completionTokens
            ))
        }

        return events
    }

    /// Maps a stream error to a provider error.
    ///
    /// - Parameter error: The stream error from the chunk.
    /// - Returns: The corresponding provider error.
    private func mapStreamError(_ error: OpenRouterStreamChunk.StreamError) -> OpenRouterProviderError {
        let errorType = error.type ?? ""
        let errorCode = error.code ?? ""

        switch errorType {
        case "invalid_api_key":
            return .authenticationFailed
        case "invalid_request_error":
            return .apiError(code: "invalid_request", message: error.message, statusCode: 400)
        case "rate_limit_error":
            return .rateLimitExceeded(retryAfter: nil)
        case "context_length_exceeded":
            return .apiError(code: "context_length", message: "Context length exceeded", statusCode: 400)
        case "content_filter":
            return .contentFiltered
        default:
            if errorCode == "model_not_found" {
                return .modelNotAvailable(model: error.message)
            }
            return .unknownError(statusCode: 0)
        }
    }
}

// MARK: - OpenRouterToolCallAccumulator

/// Accumulates streaming tool call fragments into complete tool calls.
///
/// OpenAI-compatible APIs stream tool calls in fragments across multiple chunks.
/// This accumulator collects these fragments by index and reconstructs the
/// complete tool calls once all fragments have been received.
///
/// - Important: This type is NOT thread-safe. Use only from a single isolation context.
///
/// Example usage:
/// ```swift
/// var accumulator = OpenRouterToolCallAccumulator()
///
/// for event in streamEvents {
///     if case .toolCallDelta(let index, let id, let name, let args) = event {
///         accumulator.accumulate(index: index, id: id, name: name, arguments: args)
///     }
/// }
///
/// let completedCalls = accumulator.getCompletedToolCalls()
/// for call in completedCalls {
///     print("Tool: \(call.name), Args: \(call.arguments)")
/// }
/// ```
public struct OpenRouterToolCallAccumulator {
    // MARK: Public

    /// Represents a completed tool call.
    public struct CompletedToolCall: Sendable, Equatable {
        /// The tool call ID.
        public let id: String

        /// The function name.
        public let name: String

        /// The complete arguments JSON string.
        public let arguments: String

        /// Creates a new completed tool call.
        public init(id: String, name: String, arguments: String) {
            self.id = id
            self.name = name
            self.arguments = arguments
        }
    }

    /// Checks if there are any tool calls being accumulated.
    public var hasToolCalls: Bool {
        !toolCalls.isEmpty
    }

    /// Returns the number of tool calls being accumulated.
    public var count: Int {
        toolCalls.count
    }

    /// Creates a new tool call accumulator.
    public init() {
        toolCalls = [:]
    }

    /// Accumulates a tool call delta.
    ///
    /// - Parameters:
    ///   - index: The index of the tool call.
    ///   - id: The tool call ID (usually present in first delta).
    ///   - name: The function name (usually present in first delta).
    ///   - arguments: Partial arguments JSON string to append.
    public mutating func accumulate(
        index: Int,
        id: String?,
        name: String?,
        arguments: String
    ) {
        var toolCall = toolCalls[index] ?? AccumulatingToolCall()

        // Set ID if provided (usually in first delta)
        if let id, !id.isEmpty {
            toolCall.id = id
        }

        // Set name if provided (usually in first delta)
        if let name, !name.isEmpty {
            toolCall.name = name
        }

        // Append arguments
        toolCall.arguments += arguments

        toolCalls[index] = toolCall
    }

    /// Returns all completed tool calls.
    ///
    /// A tool call is considered complete when it has both an ID and a name.
    /// The calls are returned sorted by their index.
    ///
    /// - Returns: Array of completed tool calls sorted by index.
    public func getCompletedToolCalls() -> [CompletedToolCall] {
        toolCalls
            .sorted { $0.key < $1.key }
            .compactMap { _, call -> CompletedToolCall? in
                // Incomplete tool calls (missing ID or name) are filtered out
                if call.id == nil {
                    return nil
                }

                if call.name == nil {
                    return nil
                }

                guard let id = call.id, let name = call.name else {
                    return nil
                }

                return CompletedToolCall(
                    id: id,
                    name: name,
                    arguments: call.arguments
                )
            }
    }

    /// Returns all tool calls, including incomplete ones.
    ///
    /// Incomplete tool calls will have empty strings for missing ID or name.
    /// Use this method when you need to inspect partially accumulated state.
    ///
    /// - Returns: Array of all tool calls sorted by index.
    public func getAllToolCalls() -> [CompletedToolCall] {
        toolCalls
            .sorted { $0.key < $1.key }
            .map { _, call in
                CompletedToolCall(
                    id: call.id ?? "",
                    name: call.name ?? "",
                    arguments: call.arguments
                )
            }
    }

    /// Resets the accumulator, clearing all accumulated tool calls.
    public mutating func reset() {
        toolCalls.removeAll()
    }

    /// Returns the tool call at a specific index, if it exists.
    ///
    /// - Parameter index: The index of the tool call.
    /// - Returns: The completed tool call at that index, or nil if not present or incomplete.
    public func toolCall(at index: Int) -> CompletedToolCall? {
        guard let call = toolCalls[index],
              let id = call.id,
              let name = call.name else {
            return nil
        }
        return CompletedToolCall(id: id, name: name, arguments: call.arguments)
    }

    // MARK: Private

    /// Internal storage for accumulating tool calls by index.
    private struct AccumulatingToolCall: Sendable {
        var id: String?
        var name: String?
        var arguments: String

        init() {
            id = nil
            name = nil
            arguments = ""
        }
    }

    /// Tool calls being accumulated, keyed by index.
    private var toolCalls: [Int: AccumulatingToolCall]
}
