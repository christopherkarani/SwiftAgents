// ConduitProvider.swift
// SwiftAgents Framework
//
// Unified inference provider using Conduit for multi-backend LLM access.

import Conduit
import Foundation
import OrderedCollections

// MARK: - ConduitProvider

/// Unified inference provider using Conduit for multi-backend LLM access.
///
/// ConduitProvider wraps the Conduit SDK to provide a consistent interface
/// for SwiftAgents regardless of the underlying LLM backend (Anthropic, OpenAI,
/// MLX, HuggingFace, or Apple Foundation Models).
///
/// Example:
/// ```swift
/// // Create a provider for Anthropic Claude
/// let config = try ConduitConfiguration.anthropic(
///     apiKey: "sk-ant-...",
///     model: .claudeSonnet45,
///     systemPrompt: "You are a helpful assistant."
/// )
/// let provider = try ConduitProvider(configuration: config)
///
/// // Generate a response
/// let response = try await provider.generate(
///     prompt: "What is Swift concurrency?",
///     options: .default
/// )
///
/// // Stream a response
/// for try await chunk in provider.stream(prompt: "Explain actors", options: .default) {
///     print(chunk, terminator: "")
/// }
/// ```
public actor ConduitProvider: InferenceProvider {
    // MARK: - Types

    /// Internal backend representation for different provider types.
    ///
    /// This enum is `@unchecked Sendable` because all associated values are actors
    /// (which are inherently `Sendable`) or value types that conform to `Sendable`:
    /// - `AnthropicProvider`, `OpenAIProvider`, `MLXProvider`, `HuggingFaceProvider` are actors
    /// - `AnthropicModelID`, `OpenAIModelID`, `ModelIdentifier` are `Sendable` value types
    ///
    /// The `@unchecked` annotation is required because the Swift compiler cannot verify
    /// Sendable conformance through conditional compilation (`#if canImport`) blocks.
    private enum Backend: @unchecked Sendable {
        case anthropic(AnthropicProvider, AnthropicModelID)
        case openAI(OpenAIProvider, OpenAIModelID)
        #if canImport(MLX)
        case mlx(MLXProvider, ModelIdentifier)
        #endif
        case huggingFace(HuggingFaceProvider, ModelIdentifier)
        // Note: Foundation Models not yet supported in Conduit
        // case foundationModels(FoundationModelsProvider)
    }

    // MARK: - Properties

    /// The configuration used to create this provider.
    public let configuration: ConduitConfiguration

    /// The underlying Conduit backend.
    private let backend: Backend

    /// Cached provider description for nonisolated access.
    private let providerDescription: String

    // MARK: - Initialization

    /// Creates a Conduit provider with the given configuration.
    ///
    /// - Parameter configuration: The provider configuration including backend type,
    ///   model, and optional settings.
    /// - Throws: `AgentError.inferenceProviderUnavailable` if the provider cannot be created.
    public init(configuration: ConduitConfiguration) throws {
        self.configuration = configuration
        self.backend = try Self.createBackend(for: configuration.providerType)
        self.providerDescription = "ConduitProvider(\(configuration.providerType.displayName))"
    }

    /// Convenience initializer for creating a provider from a provider type.
    ///
    /// - Parameter providerType: The type of provider to create.
    /// - Throws: `AgentError.inferenceProviderUnavailable` if the provider cannot be created.
    public init(providerType: ConduitProviderType) throws {
        let config = try ConduitConfiguration(providerType: providerType)
        try self.init(configuration: config)
    }

    // MARK: - InferenceProvider Conformance

    /// Generates a response for the given prompt.
    ///
    /// Implements retry logic based on the configuration's retry strategy
    /// for transient failures.
    ///
    /// - Parameters:
    ///   - prompt: The input prompt.
    ///   - options: Generation options including temperature, max tokens, etc.
    /// - Returns: The generated text response.
    /// - Throws: `AgentError` if generation fails.
    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput(reason: "Prompt cannot be empty")
        }

        let messages = buildMessages(prompt: prompt)
        let config = buildGenerateConfig(from: options)
        let maxRetries = configuration.retryStrategy.maxRetries

        for attempt in 0..<(maxRetries + 1) {
            try Task.checkCancellation()

            do {
                let result = try await performGeneration(messages: messages, config: config)
                return result.text
            } catch {
                let agentError = mapError(error)

                // Check if we should retry
                if attempt < maxRetries, shouldRetry(error: agentError) {
                    let delay = computeRetryDelay(
                        forAttempt: attempt + 1,
                        error: agentError
                    )
                    try Task.checkCancellation()
                    try await Task.sleep(for: .seconds(delay))
                    continue
                }

                throw agentError
            }
        }

        throw AgentError.generationFailed(reason: "Max retries exceeded")
    }

    /// Streams a response for the given prompt.
    ///
    /// This method is `nonisolated` to allow creating the stream without
    /// blocking on actor isolation. The actual streaming work happens
    /// asynchronously within a task.
    ///
    /// - Parameters:
    ///   - prompt: The input prompt.
    ///   - options: Generation options including temperature, max tokens, etc.
    /// - Returns: An async stream of response tokens.
    nonisolated public func stream(
        prompt: String,
        options: InferenceOptions
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.performStream(
                        prompt: prompt,
                        options: options,
                        continuation: continuation
                    )
                } catch is CancellationError {
                    continuation.finish(throwing: AgentError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    /// Generates a response with potential tool calls.
    ///
    /// This method includes tool definitions in the generation request and
    /// parses any tool calls from the model's response. Implements retry logic
    /// based on the configuration's retry strategy.
    ///
    /// - Parameters:
    ///   - prompt: The input prompt.
    ///   - tools: Available tool definitions.
    ///   - options: Generation options.
    /// - Returns: The inference response which may include tool calls.
    /// - Throws: `AgentError` if generation fails.
    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolDefinition],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput(reason: "Prompt cannot be empty")
        }

        let messages = buildMessages(prompt: prompt)
        var config = buildGenerateConfig(from: options)

        // Add tools to the configuration if provided
        if !tools.isEmpty {
            config = config.tools(tools.map { $0.toConduitToolDefinition() })
        }

        let maxRetries = configuration.retryStrategy.maxRetries

        for attempt in 0..<(maxRetries + 1) {
            try Task.checkCancellation()

            do {
                let result = try await performGeneration(messages: messages, config: config)
                return try result.toInferenceResponse()
            } catch {
                let agentError = mapError(error)

                // Check if we should retry
                if attempt < maxRetries, shouldRetry(error: agentError) {
                    let delay = computeRetryDelay(
                        forAttempt: attempt + 1,
                        error: agentError
                    )
                    try Task.checkCancellation()
                    try await Task.sleep(for: .seconds(delay))
                    continue
                }

                throw agentError
            }
        }

        throw AgentError.generationFailed(reason: "Max retries exceeded")
    }

    // MARK: - Private Methods

    /// Creates the appropriate backend for the given provider type.
    private static func createBackend(for providerType: ConduitProviderType) throws -> Backend {
        switch providerType {
        case let .mlx(model):
            #if canImport(MLX)
            let provider = MLXProvider()
            return .mlx(provider, model)
            #else
            throw AgentError.inferenceProviderUnavailable(
                reason: "MLX is only available on Apple Silicon. Use cloud providers instead."
            )
            #endif

        case let .anthropic(model, apiKey):
            let provider = AnthropicProvider(apiKey: apiKey)
            return .anthropic(provider, model)

        case let .openAI(model, apiKey):
            let provider = OpenAIProvider(apiKey: apiKey)
            return .openAI(provider, model)

        case let .huggingFace(model, token):
            let provider = HuggingFaceProvider(token: token)
            return .huggingFace(provider, model)

        case .foundationModels:
            // Foundation Models are not yet supported in Conduit
            throw AgentError.inferenceProviderUnavailable(
                reason: "Foundation Models are not yet supported. Use MLX for local inference."
            )
        }
    }

    /// Builds Conduit messages from the prompt.
    private func buildMessages(prompt: String) -> [Message] {
        var messages: [Message] = []

        // Add system prompt if configured
        if let systemPrompt = configuration.systemPrompt, !systemPrompt.isEmpty {
            messages.append(Message.system(systemPrompt))
        }

        // Add user prompt
        messages.append(Message.user(prompt))

        return messages
    }

    /// Builds a Conduit GenerateConfig from InferenceOptions.
    private func buildGenerateConfig(from options: InferenceOptions) -> GenerateConfig {
        // Start with the options conversion
        var config = options.toConduitConfig()

        // Override with configuration defaults if options don't specify values
        if let temp = configuration.temperature, options.temperature == 1.0 {
            config = GenerateConfig(
                maxTokens: config.maxTokens,
                temperature: Float(temp),
                topP: config.topP,
                topK: config.topK,
                frequencyPenalty: config.frequencyPenalty,
                presencePenalty: config.presencePenalty,
                stopSequences: config.stopSequences
            )
        }

        return config
    }

    /// Performs the actual generation using the appropriate backend.
    private func performGeneration(
        messages: [Message],
        config: GenerateConfig
    ) async throws -> GenerationResult {
        switch backend {
        case let .anthropic(provider, model):
            return try await provider.generate(messages: messages, model: model, config: config)

        case let .openAI(provider, model):
            return try await provider.generate(messages: messages, model: model, config: config)

        #if canImport(MLX)
        case let .mlx(provider, model):
            return try await provider.generate(messages: messages, model: model, config: config)
        #endif

        case let .huggingFace(provider, model):
            return try await provider.generate(messages: messages, model: model, config: config)
        }
    }

    /// Performs streaming generation with retry logic.
    ///
    /// Streaming retries are only attempted before any chunks have been yielded
    /// to prevent duplicate content from being sent to the consumer.
    private func performStream(
        prompt: String,
        options: InferenceOptions,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput(reason: "Prompt cannot be empty")
        }

        let messages = buildMessages(prompt: prompt)
        let config = buildGenerateConfig(from: options)
        let maxRetries = configuration.retryStrategy.maxRetries

        // Track whether we've started yielding chunks to prevent mid-stream retries
        // that would cause duplicate content
        var hasYieldedChunks = false

        for attempt in 0..<(maxRetries + 1) {
            try Task.checkCancellation()

            do {
                let stream = try await createStream(messages: messages, config: config)

                for try await chunk in stream {
                    try Task.checkCancellation()
                    hasYieldedChunks = true
                    continuation.yield(chunk.text)
                }

                continuation.finish()
                return
            } catch is CancellationError {
                throw AgentError.cancelled
            } catch {
                let agentError = mapError(error)

                // Only retry if streaming has not yet started (no chunks yielded)
                if !hasYieldedChunks, attempt < maxRetries, shouldRetry(error: agentError) {
                    let delay = computeRetryDelay(
                        forAttempt: attempt + 1,
                        error: agentError
                    )
                    try Task.checkCancellation()
                    try await Task.sleep(for: .seconds(delay))
                    continue
                }

                throw agentError
            }
        }

        throw AgentError.generationFailed(reason: "Max retries exceeded")
    }

    /// Creates a stream for the appropriate backend.
    private func createStream(
        messages: [Message],
        config: GenerateConfig
    ) async throws -> AsyncThrowingStream<GenerationChunk, Error> {
        switch backend {
        case let .anthropic(provider, model):
            return provider.stream(messages: messages, model: model, config: config)

        case let .openAI(provider, model):
            return provider.stream(messages: messages, model: model, config: config)

        #if canImport(MLX)
        case let .mlx(provider, model):
            return provider.stream(messages: messages, model: model, config: config)
        #endif

        case let .huggingFace(provider, model):
            return provider.stream(messages: messages, model: model, config: config)
        }
    }

    /// Determines if a retry should be attempted for the given error.
    ///
    /// Retries are appropriate for transient failures like rate limits
    /// and temporary network issues.
    ///
    /// - Parameter error: The error to evaluate.
    /// - Returns: `true` if a retry is appropriate.
    private func shouldRetry(error: AgentError) -> Bool {
        switch error {
        case .rateLimitExceeded:
            return true
        case .inferenceProviderUnavailable(let reason):
            // Retry on network errors
            let lowerReason = reason.lowercased()
            return lowerReason.contains("network") || lowerReason.contains("timeout")
        case .timeout:
            return true
        default:
            return false
        }
    }

    /// Computes the retry delay for a given attempt, respecting rate limit hints.
    ///
    /// If the error is a rate limit with a `retryAfter` hint from the server,
    /// this method returns the maximum of the configured delay and the server hint.
    /// This ensures we respect the server's requested wait time while still
    /// applying our exponential backoff strategy.
    ///
    /// - Parameters:
    ///   - attempt: The retry attempt number (1-indexed).
    ///   - error: The error that triggered the retry.
    /// - Returns: The delay in seconds before the next retry.
    private func computeRetryDelay(forAttempt attempt: Int, error: AgentError) -> TimeInterval {
        let configuredDelay = configuration.retryStrategy.delay(forAttempt: attempt)

        // Respect retryAfter hint from rate limit errors
        if case .rateLimitExceeded(let retryAfter) = error, let serverHint = retryAfter {
            return max(configuredDelay, serverHint)
        }

        return configuredDelay
    }

    /// Maps Conduit errors to AgentError.
    private func mapError(_ error: Error) -> AgentError {
        if let aiError = error as? AIError {
            return ConduitProviderError.toAgentError(from: aiError)
        }

        if let conduitError = error as? ConduitProviderError {
            return conduitError.toAgentError()
        }

        if error is CancellationError {
            return .cancelled
        }

        return .generationFailed(reason: error.localizedDescription)
    }
}

// MARK: - CustomStringConvertible

extension ConduitProvider: CustomStringConvertible {
    nonisolated public var description: String {
        providerDescription
    }
}

// MARK: - ToolDefinition Extension

extension ToolDefinition {
    /// Converts a SwiftAgents ToolDefinition to a Conduit ToolDefinition.
    ///
    /// This maps the SwiftAgents tool definition format to Conduit's
    /// expected tool definition format for LLM tool calling.
    ///
    /// - Returns: A Conduit `ToolDefinition` with equivalent properties.
    func toConduitToolDefinition() -> Conduit.ToolDefinition {
        Conduit.ToolDefinition(
            name: name,
            description: description,
            parameters: buildConduitSchema()
        )
    }

    /// Builds a Conduit Schema from the tool parameters.
    ///
    /// Conduit uses JSON Schema-style definitions for tool parameters,
    /// represented by the `Schema` type.
    private func buildConduitSchema() -> Conduit.Schema {
        // Build the object schema with named properties
        var namedProperties: OrderedDictionary<String, Conduit.Schema.Property> = [:]

        for param in parameters {
            let property = Conduit.Schema.Property(
                schema: param.type.toConduitSchema(),
                description: param.description,
                isRequired: param.isRequired
            )
            namedProperties[param.name] = property
        }

        return .object(
            name: name,
            description: description,
            properties: namedProperties
        )
    }
}

// MARK: - ParameterType Extension

extension ToolParameter.ParameterType {
    /// Converts a SwiftAgents ParameterType to a Conduit Schema.
    ///
    /// This maps SwiftAgents parameter types to Conduit's JSON Schema
    /// representation for tool parameter definitions.
    ///
    /// - Returns: A Conduit `Schema` representing this parameter type.
    func toConduitSchema() -> Conduit.Schema {
        switch self {
        case .string:
            return .string(constraints: [])
        case .int:
            return .integer(constraints: [])
        case .double:
            return .number(constraints: [])
        case .bool:
            return .boolean(constraints: [])
        case let .array(elementType):
            return .array(items: elementType.toConduitSchema(), constraints: [])
        case let .object(properties):
            var namedProperties: OrderedDictionary<String, Conduit.Schema.Property> = [:]
            for param in properties {
                namedProperties[param.name] = Conduit.Schema.Property(
                    schema: param.type.toConduitSchema(),
                    description: param.description,
                    isRequired: param.isRequired
                )
            }
            return .object(
                name: "Object",
                description: nil,
                properties: namedProperties
            )
        case let .oneOf(options):
            // Use string with anyOf constraint for enum-like values
            return .string(constraints: [.anyOf(options)])
        case .any:
            // Fallback to string for any type
            return .string(constraints: [])
        }
    }
}

