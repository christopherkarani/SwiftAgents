// ConduitProviderSelection.swift
// Swarm Framework
//
// Minimal Conduit-backed provider selection for Swarm.

import Conduit

/// Convenience selection for Conduit-backed inference providers.
///
/// This hides Conduit types while keeping a lightweight call-site API.
public enum ConduitProviderSelection: Sendable, InferenceProvider {
    case provider(any InferenceProvider)

    /// Creates a Conduit-backed Anthropic provider.
    public static func anthropic(apiKey: String, model: String) -> ConduitProviderSelection {
        let provider = AnthropicProvider(apiKey: apiKey)
        let modelID = AnthropicModelID(model)
        let bridge = ConduitInferenceProvider(provider: provider, model: modelID)
        return .provider(bridge)
    }

    /// Creates a Conduit-backed OpenAI provider.
    public static func openAI(apiKey: String, model: String) -> ConduitProviderSelection {
        let configuration = OpenAIConfiguration.openAI(apiKey: apiKey)
        let provider = OpenAIProvider(configuration: configuration)
        let modelID = OpenAIModelID(model)
        let bridge = ConduitInferenceProvider(provider: provider, model: modelID)
        return .provider(bridge)
    }

    /// Creates a Conduit-backed OpenRouter provider.
    ///
    /// - Note: OpenRouter expects full `provider/model` strings.
    public static func openRouter(
        apiKey: String,
        model: String,
        routing: OpenRouterRouting? = nil
    ) -> ConduitProviderSelection {
        openrouter(apiKey: apiKey, model: model, routing: routing)
    }

    /// Creates a Conduit-backed OpenRouter provider.
    ///
    /// - Note: OpenRouter expects full `provider/model` strings.
    @available(*, deprecated, renamed: "openRouter(apiKey:model:routing:)")
    public static func openrouter(
        apiKey: String,
        model: String,
        routing: OpenRouterRouting? = nil
    ) -> ConduitProviderSelection {
        var configuration = OpenAIConfiguration.openRouter(apiKey: apiKey)
        if let routing {
            configuration = configuration.routing(routing.toConduit())
        }
        let provider = OpenAIProvider(configuration: configuration)
        let modelID = OpenAIModelID.openRouter(model)
        let bridge = ConduitInferenceProvider(provider: provider, model: modelID)
        return .provider(bridge)
    }

    /// Creates a Conduit-backed Ollama provider.
    public static func ollama(
        model: String,
        settings: OllamaSettings = .default
    ) -> ConduitProviderSelection {
        let configuration = OpenAIConfiguration.ollama(host: settings.host, port: settings.port)
            .ollama(settings.toConduit())
        let provider = OpenAIProvider(configuration: configuration)
        let modelID = OpenAIModelID.ollama(model)
        let bridge = ConduitInferenceProvider(provider: provider, model: modelID)
        return .provider(bridge)
    }

    /// Exposes the underlying inference provider.
    public func makeProvider() -> any InferenceProvider {
        switch self {
        case let .provider(provider):
            return provider
        }
    }

    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        try await makeProvider().generate(prompt: prompt, options: options)
    }

    public func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        makeProvider().stream(prompt: prompt, options: options)
    }

    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        try await makeProvider().generateWithToolCalls(prompt: prompt, tools: tools, options: options)
    }
}

// MARK: - Tool-call streaming forwarding

extension ConduitProviderSelection: ToolCallStreamingInferenceProvider {
    public func streamWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) -> AsyncThrowingStream<InferenceStreamUpdate, Error> {
        guard let streamingProvider = makeProvider() as? any ToolCallStreamingInferenceProvider else {
            return StreamHelper.makeTrackedStream { continuation in
                continuation.finish(throwing: AgentError.generationFailed(
                    reason: "Underlying provider does not support tool-call streaming"
                ))
            }
        }

        return streamingProvider.streamWithToolCalls(prompt: prompt, tools: tools, options: options)
    }
}
