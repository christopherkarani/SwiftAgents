import Conduit
import Foundation

/// Opinionated, beginner-friendly inference presets backed by Conduit.
///
/// Use with any API that accepts an `InferenceProvider`:
/// ```swift
/// let agent = Agent(.openAI(key: "..."))
/// ```
///
/// Advanced customization is intentionally hidden behind `.advanced { ... }`.
public enum LLM: Sendable, InferenceProvider {
    case openAI(OpenAIConfig)
    case anthropic(AnthropicConfig)
    case openRouter(OpenRouterConfig)

    // MARK: - Presets

    public static func openAI(
        apiKey: String,
        model: String = "gpt-4o-mini"
    ) -> LLM {
        .openAI(OpenAIConfig(apiKey: apiKey, model: model))
    }

    public static func openAI(
        key: String,
        model: String = "gpt-4o-mini"
    ) -> LLM {
        openAI(apiKey: key, model: model)
    }

    public static func anthropic(
        apiKey: String,
        model: String = AnthropicModelID.claude35Sonnet.rawValue
    ) -> LLM {
        .anthropic(AnthropicConfig(apiKey: apiKey, model: model))
    }

    public static func anthropic(
        key: String,
        model: String = AnthropicModelID.claude35Sonnet.rawValue
    ) -> LLM {
        anthropic(apiKey: key, model: model)
    }

    public static func openRouter(
        apiKey: String,
        model: String = "anthropic/claude-3.5-sonnet"
    ) -> LLM {
        .openRouter(OpenRouterConfig(apiKey: apiKey, model: model))
    }

    public static func openRouter(
        key: String,
        model: String = "anthropic/claude-3.5-sonnet"
    ) -> LLM {
        openRouter(apiKey: key, model: model)
    }

    // MARK: - Progressive Disclosure

    /// Applies advanced configuration for experts.
    public func advanced(_ update: (inout AdvancedOptions) -> Void) -> LLM {
        switch self {
        case var .openAI(config):
            update(&config.advanced)
            return .openAI(config)
        case var .anthropic(config):
            update(&config.advanced)
            return .anthropic(config)
        case var .openRouter(config):
            update(&config.advanced)
            return .openRouter(config)
        }
    }

    // MARK: - InferenceProvider

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

    // MARK: - Internals

    private func makeProvider() -> any InferenceProvider {
        switch self {
        case let .openAI(config):
            let provider = OpenAIProvider(configuration: .openAI(apiKey: config.apiKey))
            let modelID = OpenAIModelID(config.model)
            return ConduitInferenceProvider(
                provider: provider,
                model: modelID,
                baseConfig: config.advanced.baseConfig
            )
        case let .anthropic(config):
            let provider = AnthropicProvider(apiKey: config.apiKey)
            let modelID = AnthropicModelID(config.model)
            return ConduitInferenceProvider(
                provider: provider,
                model: modelID,
                baseConfig: config.advanced.baseConfig
            )
        case let .openRouter(config):
            var configuration = OpenAIConfiguration.openRouter(apiKey: config.apiKey)
            if let routing = config.advanced.openRouter.routing {
                configuration = configuration.routing(routing.toConduit())
            }
            let provider = OpenAIProvider(configuration: configuration)
            let modelID = OpenAIModelID.openRouter(config.model)
            return ConduitInferenceProvider(
                provider: provider,
                model: modelID,
                baseConfig: config.advanced.baseConfig
            )
        }
    }
}

#if DEBUG
extension LLM {
    // Test hook: keep Conduit types out of the public API, but allow the package's
    // unit tests to validate that presets are backed by Conduit providers.
    func _makeProviderForTesting() -> any InferenceProvider {
        makeProvider()
    }
}
#endif

extension LLM: ToolCallStreamingInferenceProvider {
    public func streamWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) -> AsyncThrowingStream<InferenceStreamUpdate, Error> {
        let provider = makeProvider()
        guard let streaming = provider as? any ToolCallStreamingInferenceProvider else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: AgentError.generationFailed(reason: "Provider does not support tool-call streaming"))
            }
        }
        return streaming.streamWithToolCalls(prompt: prompt, tools: tools, options: options)
    }
}

// MARK: - Dot-syntax Entry Points

public extension InferenceProvider where Self == LLM {
    static func openAI(apiKey: String, model: String = "gpt-4o-mini") -> LLM {
        LLM.openAI(apiKey: apiKey, model: model)
    }

    static func openAI(key: String, model: String = "gpt-4o-mini") -> LLM {
        LLM.openAI(key: key, model: model)
    }

    static func anthropic(apiKey: String, model: String = AnthropicModelID.claude35Sonnet.rawValue) -> LLM {
        LLM.anthropic(apiKey: apiKey, model: model)
    }

    static func anthropic(key: String, model: String = AnthropicModelID.claude35Sonnet.rawValue) -> LLM {
        LLM.anthropic(key: key, model: model)
    }

    static func openRouter(apiKey: String, model: String = "anthropic/claude-3.5-sonnet") -> LLM {
        LLM.openRouter(apiKey: apiKey, model: model)
    }

    static func openRouter(key: String, model: String = "anthropic/claude-3.5-sonnet") -> LLM {
        LLM.openRouter(key: key, model: model)
    }
}

// MARK: - Configuration Types

public extension LLM {
    struct OpenAIConfig: Sendable {
        public var apiKey: String
        public var model: String
        public var advanced: AdvancedOptions = .default

        public init(apiKey: String, model: String) {
            self.apiKey = apiKey
            self.model = model
        }
    }

    struct AnthropicConfig: Sendable {
        public var apiKey: String
        public var model: String
        public var advanced: AdvancedOptions = .default

        public init(apiKey: String, model: String) {
            self.apiKey = apiKey
            self.model = model
        }
    }

    struct OpenRouterConfig: Sendable {
        public var apiKey: String
        public var model: String
        public var advanced: AdvancedOptions = .default

        public init(apiKey: String, model: String) {
            self.apiKey = apiKey
            self.model = model
        }
    }

    struct AdvancedOptions: Sendable {
        public static let `default` = AdvancedOptions()

        /// Baseline Conduit generation configuration.
        ///
        /// Swarm still applies `InferenceOptions` (temperature/maxTokens/etc) per request.
        public var baseConfig: Conduit.GenerateConfig

        public var openRouter: OpenRouterOptions

        public init(
            baseConfig: Conduit.GenerateConfig = .default,
            openRouter: OpenRouterOptions = .default
        ) {
            self.baseConfig = baseConfig
            self.openRouter = openRouter
        }
    }

    struct OpenRouterOptions: Sendable {
        public static let `default` = OpenRouterOptions()

        public var routing: OpenRouterRouting?

        public init(routing: OpenRouterRouting? = nil) {
            self.routing = routing
        }
    }
}
