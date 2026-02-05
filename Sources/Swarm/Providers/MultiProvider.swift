// MultiProvider.swift
// Swarm Framework
//
// Multi-provider routing system for inference provider management.

import Foundation

// MARK: - MultiProviderError

/// Errors that can occur during MultiProvider operations.
public enum MultiProviderError: Error, Sendable, LocalizedError, Equatable {
    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .emptyPrefix:
            "MultiProvider: prefix cannot be empty"
        case let .providerNotFound(prefix):
            "MultiProvider: no provider registered for prefix '\(prefix)'"
        case let .invalidModelFormat(model):
            "MultiProvider: invalid model format '\(model)'"
        }
    }

    /// The prefix is empty or contains only whitespace.
    case emptyPrefix

    /// No provider is registered for the given prefix.
    case providerNotFound(prefix: String)

    /// The model name format is invalid.
    case invalidModelFormat(model: String)
}

// MARK: - MultiProvider

/// A provider that routes requests to different inference providers based on model name prefixes.
///
/// MultiProvider enables using multiple inference backends (Anthropic, OpenAI, Google, etc.)
/// within the same application by routing based on model name prefixes.
///
/// ## Model Name Format
///
/// Model names follow the format `prefix/model-name`:
/// - `anthropic/claude-3-5-sonnet-20241022` routes to the Anthropic provider
/// - `openai/gpt-4o` routes to the OpenAI provider
/// - `gpt-4` (no prefix) routes to the default provider
///
/// ## Usage
///
/// ```swift
/// // Create with a default provider for unmatched models
/// let multiProvider = MultiProvider(defaultProvider: openRouterProvider)
///
/// // Register providers for specific prefixes
/// await multiProvider.register(prefix: "anthropic", provider: anthropicProvider)
/// await multiProvider.register(prefix: "openai", provider: openAIProvider)
/// await multiProvider.register(prefix: "google", provider: googleProvider)
///
/// // Set the current model - subsequent calls use this model
/// await multiProvider.setModel("anthropic/claude-3-5-sonnet-20241022")
///
/// // Generate a response - routes to Anthropic provider
/// let response = try await multiProvider.generate(
///     prompt: "Hello, world!",
///     options: .default
/// )
/// ```
///
/// ## Thread Safety
///
/// MultiProvider is implemented as an actor, providing thread-safe access
/// to mutable state including the provider registry and current model.
public actor MultiProvider: InferenceProvider {
    // MARK: Public

    /// Returns all registered prefixes.
    public var registeredPrefixes: [String] {
        Array(providers.keys).sorted()
    }

    /// Returns the number of registered providers (excluding the default).
    public var providerCount: Int {
        providers.count
    }

    /// Returns the currently selected model, if any.
    public var model: String? {
        currentModel
    }

    // MARK: - Initialization

    /// Creates a MultiProvider with a default provider for unmatched prefixes.
    ///
    /// The default provider handles all requests when:
    /// - No model is set
    /// - The model has no prefix (e.g., "gpt-4" instead of "openai/gpt-4")
    /// - No provider is registered for the model's prefix
    ///
    /// - Parameter defaultProvider: The provider to use when no prefix matches.
    public init(defaultProvider: any InferenceProvider) {
        self.defaultProvider = defaultProvider
        providerDescription = "MultiProvider(default: \(type(of: defaultProvider)))"
    }

    // MARK: - Provider Registration

    /// Registers a provider for a specific prefix.
    ///
    /// After registration, any model starting with `prefix/` will be routed
    /// to the registered provider.
    ///
    /// - Parameters:
    ///   - prefix: The prefix to match (e.g., "anthropic", "openai").
    ///   - provider: The inference provider to use for this prefix.
    /// - Throws: `MultiProviderError.emptyPrefix` if the prefix is empty.
    public func register(prefix: String, provider: any InferenceProvider) throws {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MultiProviderError.emptyPrefix
        }
        providers[trimmed.lowercased()] = provider
    }

    /// Unregisters a provider for a specific prefix.
    ///
    /// After unregistration, models with this prefix will fall back to the default provider.
    ///
    /// - Parameter prefix: The prefix to unregister.
    public func unregister(prefix: String) {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        providers.removeValue(forKey: trimmed)
    }

    // MARK: - Model Selection

    /// Sets the current model for subsequent inference calls.
    ///
    /// The model name determines which provider handles requests:
    /// - `"anthropic/claude-3"` uses the provider registered for "anthropic"
    /// - `"gpt-4"` uses the default provider (no prefix)
    ///
    /// - Parameter model: The model identifier to use.
    public func setModel(_ model: String) {
        currentModel = model
    }

    /// Clears the current model selection.
    public func clearModel() {
        currentModel = nil
    }

    // MARK: - InferenceProvider Conformance

    /// Generates a response for the given prompt using the current model.
    ///
    /// Routes the request to the appropriate provider based on the current model's prefix.
    ///
    /// - Parameters:
    ///   - prompt: The input prompt.
    ///   - options: Generation options.
    /// - Returns: The generated text.
    /// - Throws: `AgentError` if generation fails.
    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        let provider = resolveProvider(for: currentModel)
        return try await provider.generate(prompt: prompt, options: options)
    }

    /// Streams a response for the given prompt using the current model.
    ///
    /// Routes the request to the appropriate provider based on the current model's prefix.
    ///
    /// - Parameters:
    ///   - prompt: The input prompt.
    ///   - options: Generation options.
    /// - Returns: An async stream of response tokens.
    nonisolated public func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.performStream(prompt: prompt, options: options, continuation: continuation)
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

    /// Generates a response with potential tool calls using the current model.
    ///
    /// Routes the request to the appropriate provider based on the current model's prefix.
    ///
    /// - Parameters:
    ///   - prompt: The input prompt.
    ///   - tools: Available tool schemas.
    ///   - options: Generation options.
    /// - Returns: The inference response which may include tool calls.
    /// - Throws: `AgentError` if generation fails.
    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        let provider = resolveProvider(for: currentModel)
        return try await provider.generateWithToolCalls(prompt: prompt, tools: tools, options: options)
    }

    /// Checks if a provider is registered for the given prefix.
    ///
    /// - Parameter prefix: The prefix to check.
    /// - Returns: `true` if a provider is registered for this prefix.
    public func hasProvider(for prefix: String) -> Bool {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return providers[trimmed] != nil
    }

    /// Returns the provider for a given prefix, if registered.
    ///
    /// - Parameter prefix: The prefix to look up.
    /// - Returns: The registered provider, or nil if not found.
    public func provider(for prefix: String) -> (any InferenceProvider)? {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return providers[trimmed]
    }

    // MARK: Private

    /// The default provider used when no prefix matches.
    private let defaultProvider: any InferenceProvider

    /// Registered providers keyed by their prefix.
    private var providers: [String: any InferenceProvider] = [:]

    /// The currently selected model name.
    private var currentModel: String?

    /// Cached description for nonisolated access.
    private let providerDescription: String

    // MARK: - Private Methods

    /// Performs the streaming operation within actor isolation.
    private func performStream(
        prompt: String,
        options: InferenceOptions,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let provider = resolveProvider(for: currentModel)

        for try await token in provider.stream(prompt: prompt, options: options) {
            try Task.checkCancellation()
            continuation.yield(token)
        }

        continuation.finish()
    }

    /// Parses a model name to extract prefix and actual model name.
    ///
    /// - Parameter model: The full model name (e.g., "anthropic/claude-3.5-sonnet").
    /// - Returns: A tuple containing the optional prefix and the model name.
    ///
    /// Examples:
    /// - `"anthropic/claude-3.5-sonnet"` returns `(prefix: "anthropic", modelName: "claude-3.5-sonnet")`
    /// - `"gpt-4"` returns `(prefix: nil, modelName: "gpt-4")`
    /// - `"openai/gpt-4o-mini"` returns `(prefix: "openai", modelName: "gpt-4o-mini")`
    private func parseModelName(_ model: String) -> (prefix: String?, modelName: String) {
        guard let slashIndex = model.firstIndex(of: "/") else {
            return (prefix: nil, modelName: model)
        }

        let prefix = String(model[..<slashIndex])
        let afterSlash = model.index(after: slashIndex)
        let modelName = String(model[afterSlash...])

        // If prefix is empty or model name is empty, treat as no prefix
        guard !prefix.isEmpty, !modelName.isEmpty else {
            return (prefix: nil, modelName: model)
        }

        return (prefix: prefix.lowercased(), modelName: modelName)
    }

    /// Resolves the provider for a given model name.
    ///
    /// - Parameter model: The model name to resolve, or nil to use the default provider.
    /// - Returns: The appropriate inference provider.
    private func resolveProvider(for model: String?) -> any InferenceProvider {
        guard let model else {
            return defaultProvider
        }

        let (prefix, _) = parseModelName(model)

        guard let prefix else {
            return defaultProvider
        }

        return providers[prefix] ?? defaultProvider
    }
}

// MARK: CustomStringConvertible

extension MultiProvider: CustomStringConvertible {
    nonisolated public var description: String {
        providerDescription
    }
}

// MARK: - Factory Methods

public extension MultiProvider {
    /// Creates a MultiProvider with OpenRouter as the default provider.
    ///
    /// This is a convenience factory for the common case of using OpenRouter
    /// as the default fallback for unmatched prefixes.
    ///
    /// - Parameters:
    ///   - apiKey: The OpenRouter API key.
    ///   - defaultModel: The default model to use. Default: `.gpt4o`
    /// - Returns: A configured MultiProvider instance.
    /// - Throws: `OpenRouterConfigurationError` if configuration fails.
    static func withOpenRouter(
        apiKey: String,
        defaultModel: OpenRouterModel = .gpt4o
    ) throws -> MultiProvider {
        let openRouter = try OpenRouterProvider(apiKey: apiKey, model: defaultModel)
        return MultiProvider(defaultProvider: openRouter)
    }
}
