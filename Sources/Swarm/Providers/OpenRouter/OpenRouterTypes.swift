// OpenRouterTypes.swift
// Swarm Framework
//
// OpenAI-compatible request/response types for the OpenRouter API.

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - OpenRouterRequest

/// A request to the OpenRouter chat completions API.
public struct OpenRouterRequest: Codable, Sendable {
    // MARK: Public

    /// The model identifier (e.g., "anthropic/claude-3-opus").
    public let model: String

    /// The messages in the conversation.
    public let messages: [OpenRouterMessage]

    /// Whether to stream the response.
    public let stream: Bool?

    /// Sampling temperature (0-2).
    public let temperature: Double?

    /// Top-p sampling (nucleus sampling).
    public let topP: Double?

    /// Top-k sampling (only sample from top k tokens).
    public let topK: Int?

    /// Frequency penalty (-2.0 to 2.0).
    public let frequencyPenalty: Double?

    /// Presence penalty (-2.0 to 2.0).
    public let presencePenalty: Double?

    /// Maximum tokens to generate.
    public let maxTokens: Int?

    /// Stop sequences.
    public let stop: [String]?

    /// Tools available for the model to call.
    public let tools: [OpenRouterTool]?

    /// How the model should choose which tool to call.
    public let toolChoice: OpenRouterToolChoice?

    /// Creates a new OpenRouter request.
    public init(
        model: String,
        messages: [OpenRouterMessage],
        stream: Bool? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        maxTokens: Int? = nil,
        stop: [String]? = nil,
        tools: [OpenRouterTool]? = nil,
        toolChoice: OpenRouterToolChoice? = nil
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.maxTokens = maxTokens
        self.stop = stop
        self.tools = tools
        self.toolChoice = toolChoice
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case frequencyPenalty = "frequency_penalty"
        case presencePenalty = "presence_penalty"
        case maxTokens = "max_tokens"
        case stop
        case tools
        case toolChoice = "tool_choice"
    }
}

// MARK: - OpenRouterMessage

/// A message in the OpenRouter conversation.
public struct OpenRouterMessage: Codable, Sendable, Equatable {
    // MARK: Public

    /// The role of the message author.
    public let role: String

    /// The content of the message.
    public let content: OpenRouterMessageContent?

    /// Tool calls made by the assistant.
    public let toolCalls: [OpenRouterToolCall]?

    /// The ID of the tool call this message responds to.
    public let toolCallId: String?

    /// Creates a new message.
    public init(
        role: String,
        content: OpenRouterMessageContent?,
        toolCalls: [OpenRouterToolCall]? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }

    // MARK: - Factory Methods

    /// Creates a system message.
    public static func system(_ content: String) -> OpenRouterMessage {
        OpenRouterMessage(
            role: "system",
            content: .text(content)
        )
    }

    /// Creates a user message.
    public static func user(_ content: String) -> OpenRouterMessage {
        OpenRouterMessage(
            role: "user",
            content: .text(content)
        )
    }

    /// Creates a user message with multimodal content.
    public static func user(_ parts: [OpenRouterContentPart]) -> OpenRouterMessage {
        OpenRouterMessage(
            role: "user",
            content: .parts(parts)
        )
    }

    /// Creates an assistant message.
    public static func assistant(_ content: String) -> OpenRouterMessage {
        OpenRouterMessage(
            role: "assistant",
            content: .text(content)
        )
    }

    /// Creates an assistant message with tool calls.
    public static func assistant(toolCalls: [OpenRouterToolCall]) -> OpenRouterMessage {
        OpenRouterMessage(
            role: "assistant",
            content: nil,
            toolCalls: toolCalls
        )
    }

    /// Creates a tool result message.
    public static func tool(content: String, toolCallId: String) -> OpenRouterMessage {
        OpenRouterMessage(
            role: "tool",
            content: .text(content),
            toolCallId: toolCallId
        )
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}

// MARK: - OpenRouterMessageContent

/// The content of a message, which can be text or multimodal parts.
public enum OpenRouterMessageContent: Sendable, Equatable {
    // MARK: Public

    /// Extracts the text content, concatenating parts if necessary.
    public var textValue: String? {
        switch self {
        case let .text(string):
            return string
        case let .parts(parts):
            let texts = parts.compactMap { part -> String? in
                if case let .text(text) = part {
                    return text
                }
                return nil
            }
            return texts.isEmpty ? nil : texts.joined()
        }
    }

    /// Simple text content.
    case text(String)

    /// Multimodal content parts (text and/or images).
    case parts([OpenRouterContentPart])
}

// MARK: Codable

extension OpenRouterMessageContent: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try decoding as string first
        if let stringContent = try? container.decode(String.self) {
            self = .text(stringContent)
            return
        }

        // Try decoding as array of parts
        if let parts = try? container.decode([OpenRouterContentPart].self) {
            self = .parts(parts)
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Content must be either a string or an array of content parts"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .text(string):
            try container.encode(string)
        case let .parts(parts):
            try container.encode(parts)
        }
    }
}

// MARK: - OpenRouterContentPart

/// A content part for multimodal messages.
public enum OpenRouterContentPart: Codable, Sendable, Equatable {
    // MARK: Public

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image_url":
            let imageUrl = try container.decode(ImageUrlContent.self, forKey: .imageUrl)
            self = .imageUrl(url: imageUrl.url, detail: imageUrl.detail)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content part type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case let .imageUrl(url, detail):
            try container.encode("image_url", forKey: .type)
            try container.encode(ImageUrlContent(url: url, detail: detail), forKey: .imageUrl)
        }
    }

    /// Text content.
    case text(String)

    /// Image content with URL and optional detail level.
    case imageUrl(url: String, detail: String?)

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }

    private struct ImageUrlContent: Codable, Equatable {
        let url: String
        let detail: String?
    }
}

// MARK: - OpenRouterToolChoice

/// Specifies how the model should choose which tool to call.
public enum OpenRouterToolChoice: Sendable, Equatable {
    /// The model will not call any tools.
    case none

    /// The model can choose to call tools or respond directly.
    case auto

    /// The model must call at least one tool.
    case required

    /// The model must call a specific function.
    case function(name: String)
}

// MARK: Encodable

extension OpenRouterToolChoice: Encodable {
    // MARK: Public

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case .required:
            try container.encode("required")
        case let .function(name):
            try container.encode(FunctionChoice(type: "function", function: FunctionName(name: name)))
        }
    }

    // MARK: Private

    private struct FunctionChoice: Encodable {
        let type: String
        let function: FunctionName
    }

    private struct FunctionName: Encodable {
        let name: String
    }
}

// MARK: Decodable

extension OpenRouterToolChoice: Decodable {
    // MARK: Public

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try decoding as string first
        if let stringValue = try? container.decode(String.self) {
            switch stringValue {
            case "none":
                self = .none
            case "auto":
                self = .auto
            case "required":
                self = .required
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown tool choice: \(stringValue)"
                )
            }
            return
        }

        // Try decoding as object
        let object = try container.decode(FunctionChoiceDecoding.self)
        self = .function(name: object.function.name)
    }

    // MARK: Private

    private struct FunctionChoiceDecoding: Decodable {
        let type: String
        let function: FunctionNameDecoding
    }

    private struct FunctionNameDecoding: Decodable {
        let name: String
    }
}

// MARK: - OpenRouterTool

/// A tool definition for the OpenRouter API.
public struct OpenRouterTool: Codable, Sendable, Equatable {
    /// The type of tool (always "function").
    public let type: String

    /// The function definition.
    public let function: OpenRouterToolFunction

    /// Creates a new function tool.
    public init(function: OpenRouterToolFunction) {
        type = "function"
        self.function = function
    }

    /// Creates a new function tool with the given parameters.
    public static func function(
        name: String,
        description: String?,
        parameters: SendableValue?
    ) -> OpenRouterTool {
        OpenRouterTool(
            function: OpenRouterToolFunction(
                name: name,
                description: description,
                parameters: parameters
            )
        )
    }
}

// MARK: - OpenRouterToolFunction

/// A function definition for tool calling.
public struct OpenRouterToolFunction: Codable, Sendable, Equatable {
    /// The name of the function.
    public let name: String

    /// A description of what the function does.
    public let description: String?

    /// The JSON schema for the function parameters.
    public let parameters: SendableValue?

    /// Creates a new function definition.
    public init(
        name: String,
        description: String?,
        parameters: SendableValue?
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

// MARK: - OpenRouterResponse

/// A response from the OpenRouter chat completions API.
public struct OpenRouterResponse: Codable, Sendable {
    /// The unique identifier for this response.
    public let id: String

    /// The Unix timestamp when this response was created.
    public let created: Int

    /// The model used to generate this response.
    public let model: String

    /// The list of completion choices.
    public let choices: [OpenRouterChoice]

    /// Token usage statistics.
    public let usage: OpenRouterUsage?

    /// Creates a new response.
    public init(
        id: String,
        created: Int,
        model: String,
        choices: [OpenRouterChoice],
        usage: OpenRouterUsage?
    ) {
        self.id = id
        self.created = created
        self.model = model
        self.choices = choices
        self.usage = usage
    }
}

// MARK: - OpenRouterChoice

/// A single completion choice in an OpenRouter response.
public struct OpenRouterChoice: Codable, Sendable {
    // MARK: Public

    /// The index of this choice.
    public let index: Int

    /// The message generated by the model.
    public let message: OpenRouterResponseMessage

    /// The reason the model stopped generating.
    public let finishReason: String?

    /// Creates a new choice.
    public init(
        index: Int,
        message: OpenRouterResponseMessage,
        finishReason: String?
    ) {
        self.index = index
        self.message = message
        self.finishReason = finishReason
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
    }
}

// MARK: - OpenRouterResponseMessage

/// A message in an OpenRouter response.
public struct OpenRouterResponseMessage: Codable, Sendable {
    // MARK: Public

    /// The role of the message author.
    public let role: String

    /// The content of the message.
    public let content: String?

    /// Tool calls made by the assistant.
    public let toolCalls: [OpenRouterToolCall]?

    /// Creates a new response message.
    public init(
        role: String,
        content: String?,
        toolCalls: [OpenRouterToolCall]?
    ) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
    }
}

// MARK: - OpenRouterToolCall

/// A tool call made by the model.
public struct OpenRouterToolCall: Codable, Sendable, Equatable {
    /// The unique identifier for this tool call.
    public let id: String

    /// The type of tool call (always "function").
    public let type: String

    /// The function being called.
    public let function: OpenRouterFunctionCall

    /// Creates a new tool call.
    public init(
        id: String,
        type: String = "function",
        function: OpenRouterFunctionCall
    ) {
        self.id = id
        self.type = type
        self.function = function
    }
}

// MARK: - OpenRouterFunctionCall

/// The function call details in a tool call.
public struct OpenRouterFunctionCall: Codable, Sendable, Equatable {
    /// The name of the function being called.
    public let name: String

    /// The JSON-encoded arguments for the function.
    public let arguments: String

    /// Creates a new function call.
    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

// MARK: - OpenRouterUsage

/// Token usage statistics from an OpenRouter response.
public struct OpenRouterUsage: Codable, Sendable {
    // MARK: Public

    /// The number of tokens in the prompt.
    public let promptTokens: Int?

    /// The number of tokens in the completion.
    public let completionTokens: Int?

    /// The total number of tokens used.
    public let totalTokens: Int?

    /// Creates new usage statistics.
    public init(
        promptTokens: Int?,
        completionTokens: Int?,
        totalTokens: Int?
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - OpenRouterStreamChoice

// Note: OpenRouterStreamChunk is defined in OpenRouterStreamParser.swift with full streaming support

/// A streaming choice containing a delta.
public struct OpenRouterStreamChoice: Codable, Sendable {
    // MARK: Public

    /// The index of this choice.
    public let index: Int

    /// The delta content for this chunk.
    public let delta: OpenRouterDelta

    /// The reason the model stopped generating (present in final chunk).
    public let finishReason: String?

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case index
        case delta
        case finishReason = "finish_reason"
    }
}

// MARK: - OpenRouterDelta

/// The delta content in a streaming chunk.
public struct OpenRouterDelta: Codable, Sendable {
    // MARK: Public

    /// The role (present in first chunk).
    public let role: String?

    /// Content fragment.
    public let content: String?

    /// Tool call fragments.
    public let toolCalls: [OpenRouterDeltaToolCall]?

    // MARK: Private

    private enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
    }
}

// MARK: - OpenRouterDeltaToolCall

/// A partial tool call in a streaming delta.
public struct OpenRouterDeltaToolCall: Codable, Sendable {
    /// The index of the tool call being streamed.
    public let index: Int?

    /// The ID of the tool call (present in first chunk for this tool call).
    public let id: String?

    /// The type (present in first chunk).
    public let type: String?

    /// The function call fragment.
    public let function: OpenRouterDeltaFunction?
}

// MARK: - OpenRouterDeltaFunction

/// A partial function call in a streaming delta.
public struct OpenRouterDeltaFunction: Codable, Sendable {
    /// The function name (present in first chunk for this tool call).
    public let name: String?

    /// Arguments fragment.
    public let arguments: String?
}

// MARK: - OpenRouterRateLimitInfo

/// Rate limit information parsed from response headers.
public struct OpenRouterRateLimitInfo: Sendable, Equatable {
    // MARK: Public

    /// The rate limit ceiling for requests.
    public let requestsLimit: Int?

    /// The remaining requests in the current window.
    public let requestsRemaining: Int?

    /// When the request limit resets.
    public let requestsReset: Date?

    /// The rate limit ceiling for tokens.
    public let tokensLimit: Int?

    /// The remaining tokens in the current window.
    public let tokensRemaining: Int?

    /// When the token limit resets.
    public let tokensReset: Date?

    /// Creates rate limit info from empty values.
    public init() {
        requestsLimit = nil
        requestsRemaining = nil
        requestsReset = nil
        tokensLimit = nil
        tokensRemaining = nil
        tokensReset = nil
    }

    /// Creates rate limit info with explicit values.
    public init(
        requestsLimit: Int?,
        requestsRemaining: Int?,
        requestsReset: Date?,
        tokensLimit: Int?,
        tokensRemaining: Int?,
        tokensReset: Date?
    ) {
        self.requestsLimit = requestsLimit
        self.requestsRemaining = requestsRemaining
        self.requestsReset = requestsReset
        self.tokensLimit = tokensLimit
        self.tokensRemaining = tokensRemaining
        self.tokensReset = tokensReset
    }

    /// Parses rate limit info from HTTP response headers (case-insensitive).
    ///
    /// OpenRouter uses OpenAI-compatible headers:
    /// - `x-ratelimit-limit-requests`
    /// - `x-ratelimit-remaining-requests`
    /// - `x-ratelimit-reset-requests`
    /// - `x-ratelimit-limit-tokens`
    /// - `x-ratelimit-remaining-tokens`
    /// - `x-ratelimit-reset-tokens`
    ///
    /// - Parameter headers: The HTTP response headers dictionary.
    /// - Returns: Parsed rate limit information.
    public static func parse(from headers: [AnyHashable: Any]) -> OpenRouterRateLimitInfo {
        // Create case-insensitive lookup
        var normalizedHeaders: [String: String] = [:]
        for (key, value) in headers {
            if let keyString = key as? String, let valueString = value as? String {
                normalizedHeaders[keyString.lowercased()] = valueString
            }
        }

        return OpenRouterRateLimitInfo(
            requestsLimit: normalizedHeaders["x-ratelimit-limit-requests"].flatMap { Int($0) },
            requestsRemaining: normalizedHeaders["x-ratelimit-remaining-requests"].flatMap { Int($0) },
            requestsReset: parseResetTime(normalizedHeaders["x-ratelimit-reset-requests"]),
            tokensLimit: normalizedHeaders["x-ratelimit-limit-tokens"].flatMap { Int($0) },
            tokensRemaining: normalizedHeaders["x-ratelimit-remaining-tokens"].flatMap { Int($0) },
            tokensReset: parseResetTime(normalizedHeaders["x-ratelimit-reset-tokens"])
        )
    }

    /// Parses rate limit info from HTTPURLResponse headers.
    ///
    /// - Parameter response: The HTTP URL response.
    /// - Returns: Parsed rate limit information.
    public static func parse(from response: HTTPURLResponse) -> OpenRouterRateLimitInfo {
        parse(from: response.allHeaderFields)
    }

    // MARK: Private

    /// Parses a reset time string, which can be either:
    /// - A Unix timestamp (seconds since epoch)
    /// - A duration string like "1s", "1m", "1h"
    /// - An ISO 8601 date string
    private static func parseResetTime(_ value: String?) -> Date? {
        guard let value else { return nil }

        // Try parsing as Unix timestamp
        if let timestamp = Double(value) {
            return Date(timeIntervalSince1970: timestamp)
        }

        // Try parsing as duration (e.g., "1s", "30m", "1h")
        if let duration = parseDuration(value) {
            return Date().addingTimeInterval(duration)
        }

        // Try parsing as ISO 8601
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    /// Parses a duration string like "1s", "30m", "1h" to seconds.
    private static func parseDuration(_ value: String) -> TimeInterval? {
        let pattern = #"^(\d+(?:\.\d+)?)(ms|s|m|h)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(
                  in: value,
                  options: [],
                  range: NSRange(value.startIndex..., in: value)
              ),
              let numberRange = Range(match.range(at: 1), in: value),
              let unitRange = Range(match.range(at: 2), in: value),
              let number = Double(value[numberRange]) else {
            return nil
        }

        let unit = String(value[unitRange])
        switch unit {
        case "ms":
            return number / 1000.0
        case "s":
            return number
        case "m":
            return number * 60.0
        case "h":
            return number * 3600.0
        default:
            return nil
        }
    }
}

// MARK: - OpenRouterErrorResponse

/// An error response from the OpenRouter API.
public struct OpenRouterErrorResponse: Codable, Sendable {
    /// The error details.
    public let error: OpenRouterErrorDetail
}

// MARK: - OpenRouterErrorDetail

/// Error detail in an OpenRouter error response.
public struct OpenRouterErrorDetail: Codable, Sendable {
    /// The error message.
    public let message: String

    /// The error type.
    public let type: String?

    /// The parameter that caused the error.
    public let param: String?

    /// An error code.
    public let code: String?
}
