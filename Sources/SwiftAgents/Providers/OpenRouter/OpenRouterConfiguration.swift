// OpenRouterConfiguration.swift
// SwiftAgents Framework
//
// Configuration types for OpenRouter provider integration.

import Foundation

// MARK: - OpenRouterConfigurationError

/// Errors that can occur during OpenRouter configuration.
public enum OpenRouterConfigurationError: Error, Sendable, LocalizedError {
    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .emptyAPIKey:
            "OpenRouterConfiguration: apiKey cannot be empty"
        case .emptyModelIdentifier:
            "OpenRouterModel: identifier cannot be empty"
        case let .invalidMaxTokens(value):
            "OpenRouterConfiguration: maxTokens must be positive, got \(value)"
        case let .invalidTemperature(value):
            "OpenRouterConfiguration: temperature must be 0.0-2.0, got \(value)"
        case let .invalidTopP(value):
            "OpenRouterConfiguration: topP must be 0.0-1.0, got \(value)"
        case let .invalidTopK(value):
            "OpenRouterConfiguration: topK must be positive, got \(value)"
        case .conflictingProviderPreferences:
            "OpenRouterProviderPreferences: cannot specify both non-empty allowList and denyList"
        }
    }

    /// The API key is empty or contains only whitespace.
    case emptyAPIKey
    /// The model identifier is empty or contains only whitespace.
    case emptyModelIdentifier
    /// The maxTokens value is not positive.
    case invalidMaxTokens(Int)
    /// The temperature value is outside the valid range (0.0-2.0).
    case invalidTemperature(Double)
    /// The topP value is outside the valid range (0.0-1.0).
    case invalidTopP(Double)
    /// The topK value is not positive.
    case invalidTopK(Int)
    /// Both allowList and denyList are specified with non-empty values.
    case conflictingProviderPreferences
}

// MARK: - OpenRouterModel

/// A model identifier for OpenRouter.
///
/// Supports ExpressibleByStringLiteral for custom models and provides
/// static presets for common models.
///
/// Example:
/// ```swift
/// let model: OpenRouterModel = .claude35Sonnet
/// let customModel: OpenRouterModel = "meta-llama/llama-3.1-70b-instruct"
/// ```
public struct OpenRouterModel: Sendable, Hashable, ExpressibleByStringLiteral {
    // MARK: - Static Presets

    /// OpenAI GPT-4o model.
    public static let gpt4o: OpenRouterModel = "openai/gpt-4o"

    /// OpenAI GPT-4o mini model.
    public static let gpt4oMini: OpenRouterModel = "openai/gpt-4o-mini"

    /// OpenAI GPT-4 Turbo model.
    public static let gpt4Turbo: OpenRouterModel = "openai/gpt-4-turbo"

    /// Anthropic Claude 3.5 Sonnet model.
    public static let claude35Sonnet: OpenRouterModel = "anthropic/claude-3.5-sonnet"

    /// Anthropic Claude 4.5 Haiku model.
    public static let claude45Haiku: OpenRouterModel = "anthropic/claude-4.5-haiku"

    /// Anthropic Claude 4 Opus model.
    public static let claude45Opus: OpenRouterModel = "anthropic/claude-4-opus"

    /// Google Gemini Pro 2.5 model.
    public static let geminiPro3: OpenRouterModel = "google/gemini-pro-3.0"

    /// Google Gemini Flash 1.5 model.
    public static let geminiFlash3: OpenRouterModel = "google/gemini-flash-3.0"

    /// Meta Llama 3.1 405B Instruct model.
    public static let llama31405B: OpenRouterModel = "meta-llama/llama-3.1-405b-instruct"

    /// Meta Llama 3.1 70B Instruct model.
    public static let llama3170B: OpenRouterModel = "meta-llama/llama-3.1-70b-instruct"

    /// Mistral Large model.
    public static let mistralLarge: OpenRouterModel = "mistralai/mistral-large"

    /// DeepSeek Coder V2 model.
    public static let deepseekCoder: OpenRouterModel = "deepseek/deepseek-coder"

    /// The model identifier string.
    public let identifier: String

    // MARK: - Initialization

    /// Creates a model from a string identifier.
    /// - Parameter identifier: The OpenRouter model identifier.
    /// - Throws: `OpenRouterConfigurationError.emptyModelIdentifier` if the identifier is empty.
    public init(_ identifier: String) throws {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw OpenRouterConfigurationError.emptyModelIdentifier
        }
        self.identifier = trimmed
    }

    /// Creates a model from a string literal.
    public init(stringLiteral value: StringLiteralType) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // String literals are compile-time constants, so this is safe
        precondition(!trimmed.isEmpty, "OpenRouterModel: string literal identifier cannot be empty")
        identifier = trimmed
    }
}

// MARK: CustomStringConvertible

extension OpenRouterModel: CustomStringConvertible {
    public var description: String {
        identifier
    }
}

// MARK: - OpenRouterRetryStrategy

/// Retry strategy configuration for OpenRouter requests.
///
/// Configures how failed requests are retried with exponential backoff.
///
/// Example:
/// ```swift
/// let retry = OpenRouterRetryStrategy.default
/// let aggressive = OpenRouterRetryStrategy(maxRetries: 5, baseDelay: 0.5)
/// ```
public struct OpenRouterRetryStrategy: Sendable, Equatable {
    // MARK: - Static Presets

    /// Default retry strategy with 3 retries and exponential backoff.
    public static let `default` = OpenRouterRetryStrategy(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0,
        retryableStatusCodes: [429, 500, 502, 503, 504]
    )

    /// No retry strategy - fails immediately on error.
    public static let none = OpenRouterRetryStrategy(
        maxRetries: 0,
        baseDelay: 0,
        maxDelay: 0,
        backoffMultiplier: 1.0,
        retryableStatusCodes: []
    )

    /// Maximum number of retry attempts.
    public let maxRetries: Int

    /// Base delay between retries in seconds.
    public let baseDelay: TimeInterval

    /// Maximum delay between retries in seconds.
    public let maxDelay: TimeInterval

    /// Multiplier applied to delay after each retry.
    public let backoffMultiplier: Double

    /// HTTP status codes that should trigger a retry.
    public let retryableStatusCodes: Set<Int>

    // MARK: - Initialization

    /// Creates a new retry strategy.
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts. Default: 3
    ///   - baseDelay: Base delay between retries in seconds. Default: 1.0
    ///   - maxDelay: Maximum delay between retries in seconds. Default: 30.0
    ///   - backoffMultiplier: Multiplier for exponential backoff. Default: 2.0
    ///   - retryableStatusCodes: HTTP status codes to retry. Default: [429, 500, 502, 503, 504]
    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        backoffMultiplier: Double = 2.0,
        retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]
    ) {
        self.maxRetries = max(0, maxRetries)
        self.baseDelay = max(0, baseDelay)
        self.maxDelay = max(baseDelay, maxDelay)
        self.backoffMultiplier = max(1.0, backoffMultiplier)
        self.retryableStatusCodes = retryableStatusCodes
    }

    // MARK: - Delay Calculation

    /// Calculates the delay for a given retry attempt.
    /// - Parameter attempt: The retry attempt number (1-indexed).
    /// - Returns: The delay in seconds before the next retry.
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return baseDelay }
        let exponent = Double(min(attempt - 1, 62)) // Prevent overflow for very high attempt counts
        let exponentialDelay = baseDelay * pow(backoffMultiplier, exponent)
        guard exponentialDelay.isFinite else { return maxDelay }
        return min(exponentialDelay, maxDelay)
    }
}

// MARK: - OpenRouterProviderPreferences

/// Provider routing preferences for OpenRouter.
///
/// Controls which providers are used and how requests are routed.
///
/// Example:
/// ```swift
/// let prefs = OpenRouterProviderPreferences(
///     order: ["anthropic", "openai"],
///     allowFallbacks: true
/// )
/// ```
public struct OpenRouterProviderPreferences: Sendable, Equatable, Codable {
    // MARK: Public

    /// Data collection preference options.
    public enum DataCollectionPreference: String, Sendable, Codable {
        case allow
        case deny
    }

    /// Provider sorting preference options.
    public enum SortPreference: String, Sendable, Codable {
        case price
        case throughput
        case latency
    }

    /// Ordered list of preferred providers.
    public let order: [String]?

    /// List of allowed providers.
    public let allowList: [String]?

    /// List of denied providers.
    public let denyList: [String]?

    /// Data collection preference.
    public let dataCollection: DataCollectionPreference?

    /// Whether to allow fallback to other providers.
    public let allowFallbacks: Bool?

    /// Sorting preference for provider selection.
    public let sort: SortPreference?

    /// Maximum price per token (in USD).
    public let maxPrice: Double?

    // MARK: - Initialization

    /// Creates provider preferences.
    /// - Parameters:
    ///   - order: Ordered list of preferred providers.
    ///   - allowList: List of allowed providers.
    ///   - denyList: List of denied providers.
    ///   - dataCollection: Data collection preference.
    ///   - allowFallbacks: Whether to allow fallback providers.
    ///   - sort: Sorting preference for provider selection.
    ///   - maxPrice: Maximum price per token in USD.
    /// - Throws: `OpenRouterConfigurationError.conflictingProviderPreferences` if both allowList and denyList are
    /// non-empty.
    public init(
        order: [String]? = nil,
        allowList: [String]? = nil,
        denyList: [String]? = nil,
        dataCollection: DataCollectionPreference? = nil,
        allowFallbacks: Bool? = nil,
        sort: SortPreference? = nil,
        maxPrice: Double? = nil
    ) throws {
        // Validate conflicting lists
        if let allow = allowList, let deny = denyList, !allow.isEmpty, !deny.isEmpty {
            throw OpenRouterConfigurationError.conflictingProviderPreferences
        }

        self.order = order
        self.allowList = allowList
        self.denyList = denyList
        self.dataCollection = dataCollection
        self.allowFallbacks = allowFallbacks
        self.sort = sort
        self.maxPrice = maxPrice
    }

    // MARK: Internal

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case order
        case allowList = "allow_list"
        case denyList = "deny_list"
        case dataCollection = "data_collection"
        case allowFallbacks = "allow_fallbacks"
        case sort
        case maxPrice = "max_price"
    }
}

// MARK: - OpenRouterRoutingStrategy

/// Routing strategy for model fallbacks.
public enum OpenRouterRoutingStrategy: Sendable, Equatable {
    /// Fall back to next model in sequence on failure.
    case fallback

    /// Round-robin load balancing across models.
    case roundRobin
}

// MARK: - OpenRouterConfiguration

/// Configuration for OpenRouter provider.
///
/// Use this to configure authentication, model selection, request parameters,
/// and routing strategies for OpenRouter API requests.
///
/// Example:
/// ```swift
/// let config = OpenRouterConfiguration(
///     apiKey: "sk-or-...",
///     model: .claude35Sonnet
/// )
///
/// // Using Builder pattern
/// let config = OpenRouterConfiguration.Builder()
///     .apiKey("sk-or-...")
///     .model(.gpt4o)
///     .temperature(0.7)
///     .fallbackModels([.claude35Sonnet, .geminiPro15])
///     .build()
/// ```
public struct OpenRouterConfiguration: Sendable {
    // MARK: - Default Values

    // Default base URL for OpenRouter API.
    // swiftlint:disable:next force_unwrapping
    public static let defaultBaseURL = URL(string: "https://openrouter.ai/api/v1")!

    /// Default timeout duration.
    public static let defaultTimeout: Duration = .seconds(120)

    /// Default maximum tokens.
    public static let defaultMaxTokens: Int = 4096

    /// OpenRouter API key.
    public let apiKey: String

    /// The primary model to use.
    public let model: OpenRouterModel

    /// Base URL for the OpenRouter API.
    public let baseURL: URL

    /// Request timeout duration.
    public let timeout: Duration

    /// Maximum tokens to generate.
    public let maxTokens: Int

    /// System prompt for the model.
    public let systemPrompt: String?

    /// Temperature for generation (0.0 - 2.0).
    public let temperature: Double?

    /// Top-p (nucleus) sampling parameter.
    public let topP: Double?

    /// Top-k sampling parameter.
    public let topK: Int?

    /// Application name for OpenRouter headers.
    public let appName: String?

    /// Site URL for OpenRouter headers.
    public let siteURL: URL?

    /// Provider routing preferences.
    public let providerPreferences: OpenRouterProviderPreferences?

    /// Fallback models to try if primary fails.
    public let fallbackModels: [OpenRouterModel]

    /// Routing strategy for fallback models.
    public let routingStrategy: OpenRouterRoutingStrategy

    /// Retry strategy for failed requests.
    public let retryStrategy: OpenRouterRetryStrategy

    // MARK: - Initialization

    /// Creates a new OpenRouter configuration.
    /// - Parameters:
    ///   - apiKey: OpenRouter API key.
    ///   - model: The primary model to use.
    ///   - baseURL: Base URL for the API. Default: https://openrouter.ai/api/v1
    ///   - timeout: Request timeout. Default: 120 seconds
    ///   - maxTokens: Maximum tokens to generate. Default: 4096
    ///   - systemPrompt: System prompt for the model.
    ///   - temperature: Temperature for generation (0.0 - 2.0).
    ///   - topP: Top-p sampling parameter.
    ///   - topK: Top-k sampling parameter.
    ///   - appName: Application name for headers.
    ///   - siteURL: Site URL for headers.
    ///   - providerPreferences: Provider routing preferences.
    ///   - fallbackModels: Fallback models on failure.
    ///   - routingStrategy: Routing strategy for fallbacks. Default: .fallback
    ///   - retryStrategy: Retry strategy. Default: .default
    /// - Throws: `OpenRouterConfigurationError` if any validation fails.
    public init(
        apiKey: String,
        model: OpenRouterModel,
        baseURL: URL = defaultBaseURL,
        timeout: Duration = defaultTimeout,
        maxTokens: Int = defaultMaxTokens,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        appName: String? = nil,
        siteURL: URL? = nil,
        providerPreferences: OpenRouterProviderPreferences? = nil,
        fallbackModels: [OpenRouterModel] = [],
        routingStrategy: OpenRouterRoutingStrategy = .fallback,
        retryStrategy: OpenRouterRetryStrategy = .default
    ) throws {
        // Validate API key
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw OpenRouterConfigurationError.emptyAPIKey
        }

        // Validate maxTokens
        guard maxTokens > 0 else {
            throw OpenRouterConfigurationError.invalidMaxTokens(maxTokens)
        }

        // Validate temperature if provided
        if let temp = temperature {
            guard temp >= 0.0, temp <= 2.0 else {
                throw OpenRouterConfigurationError.invalidTemperature(temp)
            }
        }

        // Validate topP if provided
        if let top = topP {
            guard top > 0.0, top <= 1.0 else {
                throw OpenRouterConfigurationError.invalidTopP(top)
            }
        }

        // Validate topK if provided
        if let key = topK {
            guard key > 0 else {
                throw OpenRouterConfigurationError.invalidTopK(key)
            }
        }

        self.apiKey = trimmedKey
        self.model = model
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.appName = appName
        self.siteURL = siteURL
        self.providerPreferences = providerPreferences
        self.fallbackModels = fallbackModels
        self.routingStrategy = routingStrategy
        self.retryStrategy = retryStrategy
    }
}

// MARK: Equatable

extension OpenRouterConfiguration: Equatable {
    public static func == (lhs: OpenRouterConfiguration, rhs: OpenRouterConfiguration) -> Bool {
        lhs.apiKey == rhs.apiKey &&
            lhs.model == rhs.model &&
            lhs.baseURL == rhs.baseURL &&
            lhs.timeout == rhs.timeout &&
            lhs.maxTokens == rhs.maxTokens &&
            lhs.systemPrompt == rhs.systemPrompt &&
            lhs.temperature == rhs.temperature &&
            lhs.topP == rhs.topP &&
            lhs.topK == rhs.topK &&
            lhs.appName == rhs.appName &&
            lhs.siteURL == rhs.siteURL &&
            lhs.providerPreferences == rhs.providerPreferences &&
            lhs.fallbackModels == rhs.fallbackModels &&
            lhs.routingStrategy == rhs.routingStrategy &&
            lhs.retryStrategy == rhs.retryStrategy
    }
}

// MARK: CustomStringConvertible

extension OpenRouterConfiguration: CustomStringConvertible {
    public var description: String {
        "OpenRouterConfiguration(model: \(model.identifier), baseURL: \(baseURL), maxTokens: \(maxTokens))"
    }
}
