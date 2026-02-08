// OpenRouterConfigurationBuilder.swift
// Swarm Framework
//
// Builder pattern implementation for OpenRouterConfiguration.

import Foundation

// MARK: - OpenRouterConfiguration.Builder

public extension OpenRouterConfiguration {
    /// Builder for creating OpenRouter configurations.
    ///
    /// Example:
    /// ```swift
    /// let config = OpenRouterConfiguration.Builder()
    ///     .apiKey("sk-or-...")
    ///     .model(.claude35Sonnet)
    ///     .temperature(0.7)
    ///     .maxTokens(8192)
    ///     .build()
    /// ```
    struct Builder: Sendable {
        // MARK: Public

        // MARK: - Initialization

        /// Creates a new builder with default values.
        public init() {
            _apiKey = ""
            _model = .gpt4o
            _baseURL = OpenRouterConfiguration.defaultBaseURL
            _timeout = OpenRouterConfiguration.defaultTimeout
            _maxTokens = OpenRouterConfiguration.defaultMaxTokens
            _systemPrompt = nil
            _temperature = nil
            _topP = nil
            _topK = nil
            _appName = nil
            _siteURL = nil
            _providerPreferences = nil
            _fallbackModels = []
            _routingStrategy = .fallback
            _retryStrategy = .default
        }

        // MARK: - Builder Methods

        /// Sets the API key.
        @discardableResult
        public func apiKey(_ value: String) -> Builder {
            Builder(
                apiKey: value,
                model: _model,
                baseURL: _baseURL,
                timeout: _timeout,
                maxTokens: _maxTokens,
                systemPrompt: _systemPrompt,
                temperature: _temperature,
                topP: _topP,
                topK: _topK,
                appName: _appName,
                siteURL: _siteURL,
                providerPreferences: _providerPreferences,
                fallbackModels: _fallbackModels,
                routingStrategy: _routingStrategy,
                retryStrategy: _retryStrategy
            )
        }

        /// Sets the primary model.
        @discardableResult
        public func model(_ value: OpenRouterModel) -> Builder {
            Builder(
                apiKey: _apiKey,
                model: value,
                baseURL: _baseURL,
                timeout: _timeout,
                maxTokens: _maxTokens,
                systemPrompt: _systemPrompt,
                temperature: _temperature,
                topP: _topP,
                topK: _topK,
                appName: _appName,
                siteURL: _siteURL,
                providerPreferences: _providerPreferences,
                fallbackModels: _fallbackModels,
                routingStrategy: _routingStrategy,
                retryStrategy: _retryStrategy
            )
        }

        /// Sets the base URL.
        @discardableResult
        public func baseURL(_ value: URL) -> Builder {
            Builder(
                apiKey: _apiKey,
                model: _model,
                baseURL: value,
                timeout: _timeout,
                maxTokens: _maxTokens,
                systemPrompt: _systemPrompt,
                temperature: _temperature,
                topP: _topP,
                topK: _topK,
                appName: _appName,
                siteURL: _siteURL,
                providerPreferences: _providerPreferences,
                fallbackModels: _fallbackModels,
                routingStrategy: _routingStrategy,
                retryStrategy: _retryStrategy
            )
        }

        /// Sets the request timeout.
        @discardableResult
        public func timeout(_ value: Duration) -> Builder {
            Builder(
                apiKey: _apiKey,
                model: _model,
                baseURL: _baseURL,
                timeout: value,
                maxTokens: _maxTokens,
                systemPrompt: _systemPrompt,
                temperature: _temperature,
                topP: _topP,
                topK: _topK,
                appName: _appName,
                siteURL: _siteURL,
                providerPreferences: _providerPreferences,
                fallbackModels: _fallbackModels,
                routingStrategy: _routingStrategy,
                retryStrategy: _retryStrategy
            )
        }

        /// Sets the maximum tokens.
        @discardableResult
        public func maxTokens(_ value: Int) -> Builder {
            Builder(
                apiKey: _apiKey,
                model: _model,
                baseURL: _baseURL,
                timeout: _timeout,
                maxTokens: value,
                systemPrompt: _systemPrompt,
                temperature: _temperature,
                topP: _topP,
                topK: _topK,
                appName: _appName,
                siteURL: _siteURL,
                providerPreferences: _providerPreferences,
                fallbackModels: _fallbackModels,
                routingStrategy: _routingStrategy,
                retryStrategy: _retryStrategy
            )
        }

        /// Sets the system prompt.
        @discardableResult
        public func systemPrompt(_ value: String?) -> Builder {
            Builder(
                apiKey: _apiKey,
                model: _model,
                baseURL: _baseURL,
                timeout: _timeout,
                maxTokens: _maxTokens,
                systemPrompt: value,
                temperature: _temperature,
                topP: _topP,
                topK: _topK,
                appName: _appName,
                siteURL: _siteURL,
                providerPreferences: _providerPreferences,
                fallbackModels: _fallbackModels,
                routingStrategy: _routingStrategy,
                retryStrategy: _retryStrategy
            )
        }

        /// Sets the temperature.
        @discardableResult
        public func temperature(_ value: Double?) -> Builder {
            Builder(
                apiKey: _apiKey,
                model: _model,
                baseURL: _baseURL,
                timeout: _timeout,
                maxTokens: _maxTokens,
                systemPrompt: _systemPrompt,
                temperature: value,
                topP: _topP,
                topK: _topK,
                appName: _appName,
                siteURL: _siteURL,
                providerPreferences: _providerPreferences,
                fallbackModels: _fallbackModels,
                routingStrategy: _routingStrategy,
                retryStrategy: _retryStrategy
            )
        }

        /// Sets the top-p parameter.
        @discardableResult
        public func topP(_ value: Double?) -> Builder {
            Builder(
                apiKey: _apiKey,
                model: _model,
                baseURL: _baseURL,
                timeout: _timeout,
                maxTokens: _maxTokens,
                systemPrompt: _systemPrompt,
                temperature: _temperature,
                topP: value,
                topK: _topK,
                appName: _appName,
                siteURL: _siteURL,
                providerPreferences: _providerPreferences,
                fallbackModels: _fallbackModels,
                routingStrategy: _routingStrategy,
                retryStrategy: _retryStrategy
            )
        }

        /// Sets the top-k parameter.
        @discardableResult
        public func topK(_ value: Int?) -> Builder {
            Builder(
                apiKey: _apiKey,
                model: _model,
                baseURL: _baseURL,
                timeout: _timeout,
                maxTokens: _maxTokens,
                systemPrompt: _systemPrompt,
                temperature: _temperature,
                topP: _topP,
                topK: value,
                appName: _appName,
                siteURL: _siteURL,
                providerPreferences: _providerPreferences,
                fallbackModels: _fallbackModels,
                routingStrategy: _routingStrategy,
                retryStrategy: _retryStrategy
            )
        }

        /// Sets the application name.
        @discardableResult
        public func appName(_ value: String?) -> Builder {
            Builder(
                apiKey: _apiKey,
                model: _model,
                baseURL: _baseURL,
                timeout: _timeout,
                maxTokens: _maxTokens,
                systemPrompt: _systemPrompt,
                temperature: _temperature,
                topP: _topP,
                topK: _topK,
                appName: value,
                siteURL: _siteURL,
                providerPreferences: _providerPreferences,
                fallbackModels: _fallbackModels,
                routingStrategy: _routingStrategy,
                retryStrategy: _retryStrategy
            )
        }

        /// Sets the site URL.
        @discardableResult
        public func siteURL(_ value: URL?) -> Builder {
            Builder(
                apiKey: _apiKey,
                model: _model,
                baseURL: _baseURL,
                timeout: _timeout,
                maxTokens: _maxTokens,
                systemPrompt: _systemPrompt,
                temperature: _temperature,
                topP: _topP,
                topK: _topK,
                appName: _appName,
                siteURL: value,
                providerPreferences: _providerPreferences,
                fallbackModels: _fallbackModels,
                routingStrategy: _routingStrategy,
                retryStrategy: _retryStrategy
            )
        }

        /// Sets the provider preferences.
        @discardableResult
        public func providerPreferences(_ value: OpenRouterProviderPreferences?) -> Builder {
            Builder(
                apiKey: _apiKey,
                model: _model,
                baseURL: _baseURL,
                timeout: _timeout,
                maxTokens: _maxTokens,
                systemPrompt: _systemPrompt,
                temperature: _temperature,
                topP: _topP,
                topK: _topK,
                appName: _appName,
                siteURL: _siteURL,
                providerPreferences: value,
                fallbackModels: _fallbackModels,
                routingStrategy: _routingStrategy,
                retryStrategy: _retryStrategy
            )
        }

        /// Sets the fallback models.
        @discardableResult
        public func fallbackModels(_ value: [OpenRouterModel]) -> Builder {
            Builder(
                apiKey: _apiKey,
                model: _model,
                baseURL: _baseURL,
                timeout: _timeout,
                maxTokens: _maxTokens,
                systemPrompt: _systemPrompt,
                temperature: _temperature,
                topP: _topP,
                topK: _topK,
                appName: _appName,
                siteURL: _siteURL,
                providerPreferences: _providerPreferences,
                fallbackModels: value,
                routingStrategy: _routingStrategy,
                retryStrategy: _retryStrategy
            )
        }

        /// Sets the routing strategy.
        @discardableResult
        public func routingStrategy(_ value: OpenRouterRoutingStrategy) -> Builder {
            Builder(
                apiKey: _apiKey,
                model: _model,
                baseURL: _baseURL,
                timeout: _timeout,
                maxTokens: _maxTokens,
                systemPrompt: _systemPrompt,
                temperature: _temperature,
                topP: _topP,
                topK: _topK,
                appName: _appName,
                siteURL: _siteURL,
                providerPreferences: _providerPreferences,
                fallbackModels: _fallbackModels,
                routingStrategy: value,
                retryStrategy: _retryStrategy
            )
        }

        /// Sets the retry strategy.
        @discardableResult
        public func retryStrategy(_ value: OpenRouterRetryStrategy) -> Builder {
            Builder(
                apiKey: _apiKey,
                model: _model,
                baseURL: _baseURL,
                timeout: _timeout,
                maxTokens: _maxTokens,
                systemPrompt: _systemPrompt,
                temperature: _temperature,
                topP: _topP,
                topK: _topK,
                appName: _appName,
                siteURL: _siteURL,
                providerPreferences: _providerPreferences,
                fallbackModels: _fallbackModels,
                routingStrategy: _routingStrategy,
                retryStrategy: value
            )
        }

        /// Builds the configuration.
        /// - Returns: A new OpenRouterConfiguration instance.
        /// - Throws: `OpenRouterConfigurationError` if any validation fails.
        public func build() throws -> OpenRouterConfiguration {
            try OpenRouterConfiguration(
                apiKey: _apiKey,
                model: _model,
                baseURL: _baseURL,
                timeout: _timeout,
                maxTokens: _maxTokens,
                systemPrompt: _systemPrompt,
                temperature: _temperature,
                topP: _topP,
                topK: _topK,
                appName: _appName,
                siteURL: _siteURL,
                providerPreferences: _providerPreferences,
                fallbackModels: _fallbackModels,
                routingStrategy: _routingStrategy,
                retryStrategy: _retryStrategy
            )
        }

        // MARK: Private

        private let _apiKey: String
        private let _model: OpenRouterModel
        private let _baseURL: URL
        private let _timeout: Duration
        private let _maxTokens: Int
        private let _systemPrompt: String?
        private let _temperature: Double?
        private let _topP: Double?
        private let _topK: Int?
        private let _appName: String?
        private let _siteURL: URL?
        private let _providerPreferences: OpenRouterProviderPreferences?
        private let _fallbackModels: [OpenRouterModel]
        private let _routingStrategy: OpenRouterRoutingStrategy
        private let _retryStrategy: OpenRouterRetryStrategy

        /// Private initializer for copy-on-write pattern.
        private init(
            apiKey: String,
            model: OpenRouterModel,
            baseURL: URL,
            timeout: Duration,
            maxTokens: Int,
            systemPrompt: String?,
            temperature: Double?,
            topP: Double?,
            topK: Int?,
            appName: String?,
            siteURL: URL?,
            providerPreferences: OpenRouterProviderPreferences?,
            fallbackModels: [OpenRouterModel],
            routingStrategy: OpenRouterRoutingStrategy,
            retryStrategy: OpenRouterRetryStrategy
        ) {
            _apiKey = apiKey
            _model = model
            _baseURL = baseURL
            _timeout = timeout
            _maxTokens = maxTokens
            _systemPrompt = systemPrompt
            _temperature = temperature
            _topP = topP
            _topK = topK
            _appName = appName
            _siteURL = siteURL
            _providerPreferences = providerPreferences
            _fallbackModels = fallbackModels
            _routingStrategy = routingStrategy
            _retryStrategy = retryStrategy
        }
    }
}
