// Agent.swift
// SwiftAgents Framework
//
// Core Agent protocol defining the fundamental agent behavior contract.

import Foundation

// MARK: - Agent Protocol

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
    var tools: [any Tool] { get }

    /// Instructions that define the agent's behavior and role.
    var instructions: String { get }

    /// Configuration settings for the agent.
    var configuration: AgentConfiguration { get }

    /// Optional memory system for context management.
    var memory: (any AgentMemory)? { get }

    /// Optional custom inference provider.
    var inferenceProvider: (any InferenceProvider)? { get }

    /// Executes the agent with the given input and returns a result.
    /// - Parameter input: The user's input/query.
    /// - Returns: The result of the agent's execution.
    /// - Throws: `AgentError` if execution fails.
    func run(_ input: String) async throws -> AgentResult

    /// Streams the agent's execution, yielding events as they occur.
    /// - Parameter input: The user's input/query.
    /// - Returns: An async stream of agent events.
    func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error>

    /// Cancels any ongoing execution.
    func cancel() async
}

// MARK: - Agent Protocol Extensions

extension Agent {
    /// Default memory implementation (none).
    public var memory: (any AgentMemory)? { nil }

    /// Default inference provider (none, uses Foundation Models).
    public var inferenceProvider: (any InferenceProvider)? { nil }
}

// MARK: - InferenceProvider Protocol

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

// MARK: - Inference Options

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
public struct InferenceOptions: Sendable, Equatable {
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

    /// Default inference options.
    public static let `default` = InferenceOptions()

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

    // MARK: - Fluent Builder Methods

    /// Sets the temperature for generation.
    /// - Parameter value: The temperature (0.0-2.0). Values are clamped to valid range.
    /// - Returns: A modified options instance.
    public func temperature(_ value: Double) -> InferenceOptions {
        var copy = self
        copy.temperature = max(0.0, min(2.0, value))
        return copy
    }

    /// Sets the maximum tokens to generate.
    /// - Parameter value: The maximum token count, or nil for model default.
    /// - Returns: A modified options instance.
    public func maxTokens(_ value: Int?) -> InferenceOptions {
        var copy = self
        copy.maxTokens = value.flatMap { $0 > 0 ? $0 : nil }
        return copy
    }

    /// Sets the stop sequences.
    /// - Parameter sequences: Sequences that stop generation.
    /// - Returns: A modified options instance.
    public func stopSequences(_ sequences: String...) -> InferenceOptions {
        var copy = self
        copy.stopSequences = sequences
        return copy
    }

    /// Sets the stop sequences from an array.
    /// - Parameter sequences: Sequences that stop generation.
    /// - Returns: A modified options instance.
    public func stopSequences(_ sequences: [String]) -> InferenceOptions {
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

    /// Sets the top-p (nucleus) sampling parameter.
    /// - Parameter value: The top-p value (0.0-1.0).
    /// - Returns: A modified options instance.
    public func topP(_ value: Double?) -> InferenceOptions {
        var copy = self
        copy.topP = value.map { max(0.0, min(1.0, $0)) }
        return copy
    }

    /// Sets the top-k sampling parameter.
    /// - Parameter value: The top-k value.
    /// - Returns: A modified options instance.
    public func topK(_ value: Int?) -> InferenceOptions {
        var copy = self
        copy.topK = value.flatMap { $0 > 0 ? $0 : nil }
        return copy
    }

    /// Sets the presence penalty.
    /// - Parameter value: The presence penalty (-2.0 to 2.0).
    /// - Returns: A modified options instance.
    public func presencePenalty(_ value: Double?) -> InferenceOptions {
        var copy = self
        copy.presencePenalty = value.map { max(-2.0, min(2.0, $0)) }
        return copy
    }

    /// Sets the frequency penalty.
    /// - Parameter value: The frequency penalty (-2.0 to 2.0).
    /// - Returns: A modified options instance.
    public func frequencyPenalty(_ value: Double?) -> InferenceOptions {
        var copy = self
        copy.frequencyPenalty = value.map { max(-2.0, min(2.0, $0)) }
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
}

// MARK: - Inference Response

/// Response from an inference provider that may include tool calls.
///
/// This captures the model's output which can be either direct text
/// content, a request to call tools, or both.
public struct InferenceResponse: Sendable, Equatable {
    /// The text content of the response, if any.
    public let content: String?

    /// Tool calls requested by the model.
    public let toolCalls: [ParsedToolCall]

    /// The reason generation finished.
    public let finishReason: FinishReason

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
        /// The name of the tool to call.
        public let name: String
        /// The arguments for the tool.
        public let arguments: [String: SendableValue]

        /// Creates a parsed tool call.
        /// - Parameters:
        ///   - name: The tool name.
        ///   - arguments: The tool arguments.
        public init(name: String, arguments: [String: SendableValue]) {
            self.name = name
            self.arguments = arguments
        }
    }

    /// Creates an inference response.
    /// - Parameters:
    ///   - content: Text content. Default: nil
    ///   - toolCalls: Tool calls. Default: []
    ///   - finishReason: Finish reason. Default: .completed
    public init(
        content: String? = nil,
        toolCalls: [ParsedToolCall] = [],
        finishReason: FinishReason = .completed
    ) {
        self.content = content
        self.toolCalls = toolCalls
        self.finishReason = finishReason
    }

    /// Whether this response includes tool calls.
    public var hasToolCalls: Bool {
        !toolCalls.isEmpty
    }
}
