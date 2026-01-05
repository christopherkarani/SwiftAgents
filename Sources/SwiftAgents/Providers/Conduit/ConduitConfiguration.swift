// ConduitConfiguration.swift
// SwiftAgents Framework
//
// Configuration types for Conduit provider integration.

import Conduit
import Foundation

// MARK: - ConduitConfigurationError

/// Errors that can occur during Conduit configuration.
public enum ConduitConfigurationError: Error, Sendable, LocalizedError {
    /// The API key is empty or contains only whitespace.
    case emptyAPIKey

    /// The HuggingFace token is empty or contains only whitespace.
    case emptyToken

    /// The timeout value is not positive.
    case invalidTimeout(TimeInterval)

    /// The max retries value is negative.
    case invalidMaxRetries(Int)

    /// The temperature value is outside the valid range (0.0-2.0).
    case invalidTemperature(Double)

    /// The topP value is outside the valid range (0.0-1.0).
    case invalidTopP(Double)

    /// The topK value is not positive.
    case invalidTopK(Int)

    /// The maxTokens value is not positive.
    case invalidMaxTokens(Int)

    public var errorDescription: String? {
        switch self {
        case .emptyAPIKey:
            return "ConduitConfiguration: apiKey cannot be empty"
        case .emptyToken:
            return "ConduitConfiguration: token cannot be empty"
        case let .invalidTimeout(value):
            return "ConduitConfiguration: timeout must be positive, got \(value)"
        case let .invalidMaxRetries(value):
            return "ConduitConfiguration: maxRetries cannot be negative, got \(value)"
        case let .invalidTemperature(value):
            return "ConduitConfiguration: temperature must be 0.0-2.0, got \(value)"
        case let .invalidTopP(value):
            return "ConduitConfiguration: topP must be 0.0-1.0, got \(value)"
        case let .invalidTopK(value):
            return "ConduitConfiguration: topK must be positive, got \(value)"
        case let .invalidMaxTokens(value):
            return "ConduitConfiguration: maxTokens must be positive, got \(value)"
        }
    }
}

// MARK: - ConduitRetryStrategy

/// Retry strategy configuration for Conduit requests.
///
/// Configures how failed requests are retried with exponential backoff.
///
/// Example:
/// ```swift
/// let retry = ConduitRetryStrategy.default
/// let aggressive = ConduitRetryStrategy(maxRetries: 5, baseDelay: 0.5)
/// ```
public struct ConduitRetryStrategy: Sendable, Equatable {
    // MARK: - Static Presets

    /// Default retry strategy with 3 retries and exponential backoff.
    public static let `default` = ConduitRetryStrategy(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0
    )

    /// No retry strategy - fails immediately on error.
    public static let none = ConduitRetryStrategy(
        maxRetries: 0,
        baseDelay: 0,
        maxDelay: 0,
        backoffMultiplier: 1.0
    )

    /// Aggressive retry strategy for high-reliability scenarios.
    public static let aggressive = ConduitRetryStrategy(
        maxRetries: 5,
        baseDelay: 0.5,
        maxDelay: 60.0,
        backoffMultiplier: 2.0
    )

    // MARK: - Properties

    /// Maximum number of retry attempts.
    public let maxRetries: Int

    /// Base delay between retries in seconds.
    public let baseDelay: TimeInterval

    /// Maximum delay between retries in seconds.
    public let maxDelay: TimeInterval

    /// Multiplier applied to delay after each retry.
    public let backoffMultiplier: Double

    // MARK: - Initialization

    /// Creates a new retry strategy.
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts. Default: 3
    ///   - baseDelay: Base delay between retries in seconds. Default: 1.0
    ///   - maxDelay: Maximum delay between retries in seconds. Default: 30.0
    ///   - backoffMultiplier: Multiplier for exponential backoff. Default: 2.0
    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        backoffMultiplier: Double = 2.0
    ) {
        self.maxRetries = max(0, maxRetries)
        self.baseDelay = max(0, baseDelay)
        self.maxDelay = max(baseDelay, maxDelay)
        self.backoffMultiplier = max(1.0, backoffMultiplier)
    }

    // MARK: - Delay Calculation

    /// Calculates the delay for a given retry attempt.
    /// - Parameter attempt: The retry attempt number (1-indexed).
    /// - Returns: The delay in seconds before the next retry.
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return baseDelay }
        let exponent = Double(min(attempt - 1, 62)) // Prevent overflow
        let exponentialDelay = baseDelay * pow(backoffMultiplier, exponent)
        guard exponentialDelay.isFinite else { return maxDelay }
        return min(exponentialDelay, maxDelay)
    }
}

// MARK: - ConduitConfiguration

/// Configuration for the Conduit inference provider.
///
/// Use this to configure the provider type, system prompt, timeout, and
/// retry behavior for Conduit API requests.
///
/// Example:
/// ```swift
/// // MLX local provider
/// let mlxConfig = ConduitConfiguration.mlx(model: .llama3_2_1B)
///
/// // Anthropic with custom settings
/// let anthropicConfig = try ConduitConfiguration.anthropic(
///     apiKey: "sk-ant-...",
///     model: .claudeSonnet45,
///     systemPrompt: "You are a helpful assistant."
/// )
/// ```
public struct ConduitConfiguration: Sendable {
    // MARK: - Default Values

    /// Default timeout for requests.
    public static let defaultTimeout: TimeInterval = 120.0

    /// Default maximum number of retries.
    public static let defaultMaxRetries: Int = 3

    // MARK: - Properties

    /// The provider type including model and credentials.
    public let providerType: ConduitProviderType

    /// Optional system prompt for the model.
    public let systemPrompt: String?

    /// Request timeout in seconds.
    public let timeout: TimeInterval

    /// Maximum number of retry attempts.
    public let maxRetries: Int

    /// Retry strategy configuration.
    public let retryStrategy: ConduitRetryStrategy

    /// Optional temperature for generation (0.0 - 2.0).
    public let temperature: Double?

    /// Optional top-p (nucleus) sampling parameter.
    public let topP: Double?

    /// Optional top-k sampling parameter.
    public let topK: Int?

    /// Optional maximum tokens to generate.
    public let maxTokens: Int?

    // MARK: - Initialization

    /// Creates a new Conduit configuration.
    /// - Parameters:
    ///   - providerType: The provider type with model and credentials.
    ///   - systemPrompt: Optional system prompt for the model.
    ///   - timeout: Request timeout in seconds. Default: 120
    ///   - maxRetries: Maximum retry attempts. Default: 3
    ///   - retryStrategy: Retry strategy configuration. Default: .default
    ///   - temperature: Temperature for generation (0.0 - 2.0).
    ///   - topP: Top-p sampling parameter (0.0 - 1.0).
    ///   - topK: Top-k sampling parameter (positive integer).
    ///   - maxTokens: Maximum tokens to generate (positive integer).
    /// - Throws: `ConduitConfigurationError` if any validation fails.
    public init(
        providerType: ConduitProviderType,
        systemPrompt: String? = nil,
        timeout: TimeInterval = defaultTimeout,
        maxRetries: Int = defaultMaxRetries,
        retryStrategy: ConduitRetryStrategy = .default,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        maxTokens: Int? = nil
    ) throws {
        // Validate timeout
        guard timeout > 0 else {
            throw ConduitConfigurationError.invalidTimeout(timeout)
        }

        // Validate maxRetries
        guard maxRetries >= 0 else {
            throw ConduitConfigurationError.invalidMaxRetries(maxRetries)
        }

        // Validate temperature if provided
        if let temp = temperature {
            guard temp >= 0.0, temp <= 2.0 else {
                throw ConduitConfigurationError.invalidTemperature(temp)
            }
        }

        // Validate topP if provided
        if let top = topP {
            guard top > 0.0, top <= 1.0 else {
                throw ConduitConfigurationError.invalidTopP(top)
            }
        }

        // Validate topK if provided
        if let k = topK {
            guard k > 0 else {
                throw ConduitConfigurationError.invalidTopK(k)
            }
        }

        // Validate maxTokens if provided
        if let tokens = maxTokens {
            guard tokens > 0 else {
                throw ConduitConfigurationError.invalidMaxTokens(tokens)
            }
        }

        // Validate API key/token for cloud providers
        try Self.validateCredentials(for: providerType)

        self.providerType = providerType
        self.systemPrompt = systemPrompt
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.retryStrategy = retryStrategy
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.maxTokens = maxTokens
    }

    // MARK: - Private Helpers

    /// Validates credentials for the given provider type.
    private static func validateCredentials(for providerType: ConduitProviderType) throws {
        switch providerType {
        case .anthropic(model: _, apiKey: let apiKey):
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw ConduitConfigurationError.emptyAPIKey
            }
        case .openAI(model: _, apiKey: let apiKey):
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw ConduitConfigurationError.emptyAPIKey
            }
        case .huggingFace(model: _, token: let token):
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw ConduitConfigurationError.emptyToken
            }
        case .mlx, .foundationModels:
            // No credentials required for local providers
            break
        }
    }
}

// MARK: - Factory Methods

public extension ConduitConfiguration {
    /// Creates a configuration for MLX local inference.
    ///
    /// MLX runs on Apple Silicon devices with zero network traffic.
    ///
    /// - Parameters:
    ///   - model: The MLX model identifier.
    ///   - systemPrompt: Optional system prompt.
    ///   - timeout: Request timeout in seconds. Default: 120
    ///   - maxRetries: Maximum retry attempts. Default: 3
    /// - Returns: A configured `ConduitConfiguration` for MLX.
    /// - Throws: `ConduitConfigurationError` if timeout or maxRetries are invalid.
    static func mlx(
        model: ModelIdentifier,
        systemPrompt: String? = nil,
        timeout: TimeInterval = defaultTimeout,
        maxRetries: Int = defaultMaxRetries
    ) throws -> ConduitConfiguration {
        try ConduitConfiguration(
            providerType: .mlx(model: model),
            systemPrompt: systemPrompt,
            timeout: timeout,
            maxRetries: maxRetries
        )
    }

    /// Creates a configuration for Anthropic Claude models.
    ///
    /// - Parameters:
    ///   - apiKey: The Anthropic API key.
    ///   - model: The Claude model identifier. Default: `.claudeSonnet45`
    ///   - systemPrompt: Optional system prompt.
    ///   - timeout: Request timeout in seconds. Default: 120
    ///   - maxRetries: Maximum retry attempts. Default: 3
    /// - Returns: A configured `ConduitConfiguration` for Anthropic.
    /// - Throws: `ConduitConfigurationError.emptyAPIKey` if the API key is empty.
    static func anthropic(
        apiKey: String,
        model: AnthropicModelID = .claudeSonnet45,
        systemPrompt: String? = nil,
        timeout: TimeInterval = defaultTimeout,
        maxRetries: Int = defaultMaxRetries
    ) throws -> ConduitConfiguration {
        try ConduitConfiguration(
            providerType: .anthropic(model: model, apiKey: apiKey),
            systemPrompt: systemPrompt,
            timeout: timeout,
            maxRetries: maxRetries
        )
    }

    /// Creates a configuration for OpenAI models.
    ///
    /// - Parameters:
    ///   - apiKey: The OpenAI API key.
    ///   - model: The OpenAI model identifier.
    ///   - systemPrompt: Optional system prompt.
    ///   - timeout: Request timeout in seconds. Default: 120
    ///   - maxRetries: Maximum retry attempts. Default: 3
    /// - Returns: A configured `ConduitConfiguration` for OpenAI.
    /// - Throws: `ConduitConfigurationError.emptyAPIKey` if the API key is empty.
    static func openAI(
        apiKey: String,
        model: OpenAIModelID,
        systemPrompt: String? = nil,
        timeout: TimeInterval = defaultTimeout,
        maxRetries: Int = defaultMaxRetries
    ) throws -> ConduitConfiguration {
        try ConduitConfiguration(
            providerType: .openAI(model: model, apiKey: apiKey),
            systemPrompt: systemPrompt,
            timeout: timeout,
            maxRetries: maxRetries
        )
    }

    /// Creates a configuration for HuggingFace Inference API.
    ///
    /// - Parameters:
    ///   - token: The HuggingFace API token.
    ///   - model: The HuggingFace model identifier.
    ///   - systemPrompt: Optional system prompt.
    ///   - timeout: Request timeout in seconds. Default: 120
    ///   - maxRetries: Maximum retry attempts. Default: 3
    /// - Returns: A configured `ConduitConfiguration` for HuggingFace.
    /// - Throws: `ConduitConfigurationError.emptyToken` if the token is empty.
    static func huggingFace(
        token: String,
        model: ModelIdentifier,
        systemPrompt: String? = nil,
        timeout: TimeInterval = defaultTimeout,
        maxRetries: Int = defaultMaxRetries
    ) throws -> ConduitConfiguration {
        try ConduitConfiguration(
            providerType: .huggingFace(model: model, token: token),
            systemPrompt: systemPrompt,
            timeout: timeout,
            maxRetries: maxRetries
        )
    }

    /// Creates a configuration for Apple Foundation Models.
    ///
    /// Foundation Models are system-integrated on iOS 26+ with zero setup.
    ///
    /// - Parameters:
    ///   - systemPrompt: Optional system prompt.
    ///   - timeout: Request timeout in seconds. Default: 120
    /// - Returns: A configured `ConduitConfiguration` for Foundation Models.
    /// - Throws: `ConduitConfigurationError` if timeout is invalid.
    static func foundationModels(
        systemPrompt: String? = nil,
        timeout: TimeInterval = defaultTimeout
    ) throws -> ConduitConfiguration {
        try ConduitConfiguration(
            providerType: .foundationModels,
            systemPrompt: systemPrompt,
            timeout: timeout,
            maxRetries: 0 // Foundation Models typically don't need retries
        )
    }
}

// MARK: - Equatable

extension ConduitConfiguration: Equatable {
    public static func == (lhs: ConduitConfiguration, rhs: ConduitConfiguration) -> Bool {
        lhs.providerType == rhs.providerType &&
            lhs.systemPrompt == rhs.systemPrompt &&
            lhs.timeout == rhs.timeout &&
            lhs.maxRetries == rhs.maxRetries &&
            lhs.retryStrategy == rhs.retryStrategy &&
            lhs.temperature == rhs.temperature &&
            lhs.topP == rhs.topP &&
            lhs.topK == rhs.topK &&
            lhs.maxTokens == rhs.maxTokens
    }
}

// MARK: - CustomStringConvertible

extension ConduitConfiguration: CustomStringConvertible {
    public var description: String {
        "ConduitConfiguration(provider: \(providerType.displayName), timeout: \(timeout)s)"
    }
}

// MARK: - CustomDebugStringConvertible

extension ConduitConfiguration: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        ConduitConfiguration(
            providerType: \(providerType),
            systemPrompt: \(systemPrompt ?? "nil"),
            timeout: \(timeout),
            maxRetries: \(maxRetries),
            temperature: \(temperature.map { String($0) } ?? "nil"),
            topP: \(topP.map { String($0) } ?? "nil"),
            topK: \(topK.map { String($0) } ?? "nil"),
            maxTokens: \(maxTokens.map { String($0) } ?? "nil")
        )
        """
    }
}
