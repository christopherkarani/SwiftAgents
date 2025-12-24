// Agent.swift
// SwiftAgents Framework
//
// Core Agent protocol defining the fundamental agent behavior contract.

import Foundation

// MARK: - Agent

/// A protocol defining the core behavior of an AI agent.
///
/// Agents are autonomous entities that can reason about tasks, use tools,
/// and maintain context across interactions. This protocol defines the
/// minimal interface that all agent implementations must support.
///
/// Example:
/// ```swift
/// let agent = ReActAgent(
///     tools: [CalculatorTool(), DateTimeTool()],
///     instructions: "You are a helpful assistant."
/// )
/// let result = try await agent.run("What's 2+2?")
/// print(result.output)
/// ```
public protocol Agent: Sendable {
    /// The tools available to this agent.
    nonisolated var tools: [any Tool] { get }

    /// Instructions that define the agent's behavior and role.
    nonisolated var instructions: String { get }

    /// Configuration settings for the agent.
    nonisolated var configuration: AgentConfiguration { get }

    /// Optional memory system for context management.
    nonisolated var memory: (any Memory)? { get }

    /// Optional custom inference provider.
    nonisolated var inferenceProvider: (any InferenceProvider)? { get }

    /// Optional tracer for observability.
    nonisolated var tracer: (any Tracer)? { get }

    /// Executes the agent with the given input and returns a result.
    /// - Parameter input: The user's input/query.
    /// - Returns: The result of the agent's execution.
    /// - Throws: `AgentError` if execution fails.
    func run(_ input: String) async throws -> AgentResult

    /// Streams the agent's execution, yielding events as they occur.
    /// - Parameter input: The user's input/query.
    /// - Returns: An async stream of agent events.
    nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error>

    /// Cancels any ongoing execution.
    func cancel() async
}

// MARK: - Agent Protocol Extensions

public extension Agent {
    /// Default memory implementation (none).
    nonisolated var memory: (any Memory)? { nil }

    /// Default inference provider (none, uses Foundation Models).
    nonisolated var inferenceProvider: (any InferenceProvider)? { nil }

    /// Default tracer implementation (none).
    nonisolated var tracer: (any Tracer)? { nil }
}

// MARK: - InferenceProvider

/// Protocol for inference providers.
///
/// Inference providers abstract the underlying language model, allowing
/// agents to work with different model backends (Foundation Models,
/// SwiftAI SDK, etc.).
///
/// > Note: Full implementations are provided in Phase 6 (Integration).
public protocol InferenceProvider: Sendable {
    /// Generates a response for the given prompt.
    /// - Parameters:
    ///   - prompt: The input prompt.
    ///   - options: Generation options.
    /// - Returns: The generated text.
    /// - Throws: `AgentError` if generation fails.
    func generate(prompt: String, options: InferenceOptions) async throws -> String

    /// Streams a response for the given prompt.
    /// - Parameters:
    ///   - prompt: The input prompt.
    ///   - options: Generation options.
    /// - Returns: An async stream of response tokens.
    func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error>

    /// Generates a response with potential tool calls.
    /// - Parameters:
    ///   - prompt: The input prompt.
    ///   - tools: Available tool definitions.
    ///   - options: Generation options.
    /// - Returns: The inference response which may include tool calls.
    /// - Throws: `AgentError` if generation fails.
    func generateWithToolCalls(
        prompt: String,
        tools: [ToolDefinition],
        options: InferenceOptions
    ) async throws -> InferenceResponse
}

// MARK: - InferenceOptions

/// Options for inference generation.
///
/// Customize model behavior including temperature, token limits,
/// and stop sequences. Supports fluent builder pattern for easy configuration.
///
/// Example:
/// ```swift
/// let options = InferenceOptions.default
///     .temperature(0.7)
///     .maxTokens(2000)
///     .stopSequences("END", "STOP")
/// ```
@Builder
public struct InferenceOptions: Sendable, Equatable {
    /// Default inference options.
    public static let `default` = InferenceOptions()

    // MARK: - Preset Configurations

    /// Creative preset with high temperature for diverse outputs.
    public static var creative: InferenceOptions {
        InferenceOptions(temperature: 1.2, topP: 0.95)
    }

    /// Precise preset with low temperature for deterministic outputs.
    public static var precise: InferenceOptions {
        InferenceOptions(temperature: 0.2, topP: 0.9)
    }

    /// Balanced preset for general use.
    public static var balanced: InferenceOptions {
        InferenceOptions(temperature: 0.7, topP: 0.9)
    }

    /// Code generation preset optimized for programming tasks.
    public static var codeGeneration: InferenceOptions {
        InferenceOptions(
            temperature: 0.1,
            maxTokens: 4000,
            stopSequences: ["```", "###"],
            topP: 0.95
        )
    }

    /// Chat preset optimized for conversational interactions.
    public static var chat: InferenceOptions {
        InferenceOptions(temperature: 0.8, topP: 0.9, presencePenalty: 0.6)
    }

    /// Temperature for generation (0.0 = deterministic, 2.0 = creative).
    public var temperature: Double

    /// Maximum tokens to generate.
    public var maxTokens: Int?

    /// Sequences that will stop generation.
    public var stopSequences: [String]

    /// Top-p (nucleus) sampling parameter.
    public var topP: Double?

    /// Top-k sampling parameter.
    public var topK: Int?

    /// Presence penalty for reducing repetition.
    public var presencePenalty: Double?

    /// Frequency penalty for reducing repetition.
    public var frequencyPenalty: Double?

    /// Creates inference options.
    /// - Parameters:
    ///   - temperature: Generation temperature. Default: 1.0
    ///   - maxTokens: Maximum tokens. Default: nil
    ///   - stopSequences: Stop sequences. Default: []
    ///   - topP: Top-p sampling. Default: nil
    ///   - topK: Top-k sampling. Default: nil
    ///   - presencePenalty: Presence penalty. Default: nil
    ///   - frequencyPenalty: Frequency penalty. Default: nil
    public init(
        temperature: Double = 1.0,
        maxTokens: Int? = nil,
        stopSequences: [String] = [],
        topP: Double? = nil,
        topK: Int? = nil,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stopSequences = stopSequences
        self.topP = topP
        self.topK = topK
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
    }

    // MARK: - Special Builder Methods

    /// Sets the stop sequences from variadic arguments.
    /// - Parameter sequences: Sequences that stop generation.
    /// - Returns: A modified options instance.
    public func stopSequences(_ sequences: String...) -> InferenceOptions {
        var copy = self
        copy.stopSequences = sequences
        return copy
    }

    /// Adds a single stop sequence.
    /// - Parameter sequence: The sequence to add.
    /// - Returns: A modified options instance.
    public func addStopSequence(_ sequence: String) -> InferenceOptions {
        var copy = self
        copy.stopSequences.append(sequence)
        return copy
    }

    /// Clears all stop sequences.
    /// - Returns: A modified options instance.
    public func clearStopSequences() -> InferenceOptions {
        var copy = self
        copy.stopSequences = []
        return copy
    }

    /// Creates a copy with custom modifications.
    /// - Parameter modifications: A closure that modifies the options.
    /// - Returns: A modified options instance.
    public func with(_ modifications: (inout InferenceOptions) -> Void) -> InferenceOptions {
        var copy = self
        modifications(&copy)
        return copy
    }
}

// MARK: - InferenceResponse

/// Response from an inference provider that may include tool calls.
///
/// This captures the model's output which can be either direct text
/// content, a request to call tools, or both.
public struct InferenceResponse: Sendable, Equatable {
    /// Why generation stopped.
    public enum FinishReason: String, Sendable, Codable {
        /// Generation completed normally.
        case completed
        /// Model requested tool calls.
        case toolCall
        /// Hit maximum token limit.
        case maxTokens
        /// Content was filtered.
        case contentFilter
        /// Generation was cancelled.
        case cancelled
    }

    /// A parsed tool call from the model's response.
    public struct ParsedToolCall: Sendable, Equatable {
        /// Unique identifier for this tool call (required for multi-turn tool conversations).
        public let id: String?

        /// The name of the tool to call.
        public let name: String

        /// The arguments for the tool.
        public let arguments: [String: SendableValue]

        /// Creates a parsed tool call.
        /// - Parameters:
        ///   - id: Unique identifier for the tool call. Default: nil
        ///   - name: The tool name.
        ///   - arguments: The tool arguments.
        public init(id: String? = nil, name: String, arguments: [String: SendableValue]) {
            self.id = id
            self.name = name
            self.arguments = arguments
        }
    }

    /// Token usage statistics from inference.
    public struct TokenUsage: Sendable, Equatable {
        /// Number of tokens in the input/prompt.
        public let inputTokens: Int

        /// Number of tokens in the output/response.
        public let outputTokens: Int

        /// Total tokens used.
        public var totalTokens: Int { inputTokens + outputTokens }

        /// Creates token usage statistics.
        /// - Parameters:
        ///   - inputTokens: Number of tokens in the input/prompt.
        ///   - outputTokens: Number of tokens in the output/response.
        public init(inputTokens: Int, outputTokens: Int) {
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
        }
    }

    /// The text content of the response, if any.
    public let content: String?

    /// Tool calls requested by the model.
    public let toolCalls: [ParsedToolCall]

    /// The reason generation finished.
    public let finishReason: FinishReason

    /// Token usage statistics, if available.
    public let usage: TokenUsage?

    /// Whether this response includes tool calls.
    public var hasToolCalls: Bool {
        !toolCalls.isEmpty
    }

    /// Creates an inference response.
    /// - Parameters:
    ///   - content: Text content. Default: nil
    ///   - toolCalls: Tool calls. Default: []
    ///   - finishReason: Finish reason. Default: .completed
    ///   - usage: Token usage statistics. Default: nil
    public init(
        content: String? = nil,
        toolCalls: [ParsedToolCall] = [],
        finishReason: FinishReason = .completed,
        usage: TokenUsage? = nil
    ) {
        self.content = content
        self.toolCalls = toolCalls
        self.finishReason = finishReason
        self.usage = usage
    }
}
