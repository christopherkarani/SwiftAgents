// ConduitProviderTests.swift
// SwiftAgentsTests
//
// Comprehensive tests for ConduitProvider functionality.
//
// Note: These tests verify initialization, configuration, and error handling.
// Actual generation tests require running Conduit backends.

import Conduit
import Foundation
@testable import SwiftAgents
import Testing

@Suite("ConduitProvider Tests")
struct ConduitProviderTests {
    // MARK: - Initialization Tests

    @Test("init with valid Anthropic configuration succeeds")
    func initWithValidAnthropicConfigurationSucceeds() async throws {
        let config = try ConduitConfiguration.anthropic(
            apiKey: "sk-ant-test-key",
            model: .claudeSonnet45
        )

        let provider = try await ConduitProvider(configuration: config)

        // Verify provider was created successfully
        #expect(config.providerType.displayName == "Anthropic")
    }

    @Test("init with valid OpenAI configuration succeeds")
    func initWithValidOpenAIConfigurationSucceeds() async throws {
        let config = try ConduitConfiguration.openAI(
            apiKey: "sk-test-key",
            model: .gpt4o
        )

        let provider = try await ConduitProvider(configuration: config)

        #expect(config.providerType.displayName == "OpenAI")
    }

    @Test("init with MLX configuration succeeds")
    func initWithMLXConfigurationSucceeds() async throws {
        let config = try ConduitConfiguration.mlx(model: .llama3_2_1b)

        let provider = try await ConduitProvider(configuration: config)

        #expect(config.providerType.displayName == "MLX (Local)")
    }

    @Test("init with HuggingFace configuration succeeds")
    func initWithHuggingFaceConfigurationSucceeds() async throws {
        let config = try ConduitConfiguration.huggingFace(
            token: "hf_test_key",
            model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct")
        )

        let provider = try await ConduitProvider(configuration: config)

        #expect(config.providerType.displayName == "HuggingFace")
    }

    @Test("init with Foundation Models configuration throws unsupported error")
    func initWithFoundationModelsConfigurationThrowsUnsupportedError() throws {
        let config = try ConduitConfiguration.foundationModels(
            systemPrompt: "You are helpful"
        )

        #expect(throws: AgentError.self) {
            _ = try ConduitProvider(configuration: config)
        }

        #expect(config.providerType.displayName == "Apple Foundation Models")
    }

    // MARK: - Configuration Validation Tests

    @Test("empty Anthropic API key throws error")
    func emptyAnthropicAPIKeyThrowsError() throws {
        #expect(throws: ConduitConfigurationError.emptyAPIKey) {
            _ = try ConduitConfiguration.anthropic(
                apiKey: "",
                model: .claudeSonnet45
            )
        }
    }

    @Test("empty OpenAI API key throws error")
    func emptyOpenAIAPIKeyThrowsError() throws {
        #expect(throws: ConduitConfigurationError.emptyAPIKey) {
            _ = try ConduitConfiguration.openAI(
                apiKey: "",
                model: .gpt4o
            )
        }
    }

    @Test("empty HuggingFace token throws error")
    func emptyHuggingFaceTokenThrowsError() throws {
        #expect(throws: ConduitConfigurationError.emptyToken) {
            _ = try ConduitConfiguration.huggingFace(
                token: "",
                model: .huggingFace("test-model")
            )
        }
    }

    // MARK: - Configuration Tests

    @Test("configuration preserves timeout")
    func configurationPreservesTimeout() throws {
        let config = try ConduitConfiguration.anthropic(
            apiKey: "test-key",
            model: .claudeSonnet45,
            timeout: 90
        )

        #expect(config.timeout == 90)
    }

    @Test("configuration preserves max retries")
    func configurationPreservesMaxRetries() throws {
        let config = try ConduitConfiguration.anthropic(
            apiKey: "test-key",
            model: .claudeSonnet45,
            maxRetries: 5
        )

        #expect(config.maxRetries == 5)
    }

    @Test("configuration preserves system prompt")
    func configurationPreservesSystemPrompt() throws {
        let config = try ConduitConfiguration.anthropic(
            apiKey: "test-key",
            model: .claudeSonnet45,
            systemPrompt: "You are a helpful assistant"
        )

        #expect(config.systemPrompt == "You are a helpful assistant")
    }

    @Test("retry strategy from configuration is preserved")
    func retryStrategyFromConfigurationIsPreserved() throws {
        let config = try ConduitConfiguration(
            providerType: .foundationModels,
            retryStrategy: .aggressive
        )

        #expect(config.retryStrategy.maxRetries == 5)
    }

    @Test("configuration with no retry strategy has none preset")
    func configurationWithNoRetryStrategyHasNonePreset() throws {
        let config = try ConduitConfiguration(
            providerType: .foundationModels,
            retryStrategy: .none
        )

        #expect(config.retryStrategy.maxRetries == 0)
    }

    // MARK: - Error Mapping Tests

    @Test("ConduitProviderError maps networkError to AgentError correctly")
    func conduitProviderErrorMapsNetworkErrorToAgentErrorCorrectly() {
        let conduitError = ConduitProviderError.networkError(message: "Connection failed")
        let agentError = conduitError.toAgentError()

        if case let .inferenceProviderUnavailable(reason) = agentError {
            #expect(reason.contains("Network"))
        } else {
            Issue.record("Expected inferenceProviderUnavailable AgentError")
        }
    }

    @Test("rate limit error includes retry hint")
    func rateLimitErrorIncludesRetryHint() {
        let conduitError = ConduitProviderError.rateLimitExceeded(retryAfter: 60)
        let agentError = conduitError.toAgentError()

        if case let .rateLimitExceeded(retryAfter) = agentError {
            #expect(retryAfter == 60)
        } else {
            Issue.record("Expected rateLimitExceeded AgentError with retry hint")
        }
    }

    @Test("token limit error includes token counts")
    func tokenLimitErrorIncludesTokenCounts() {
        let conduitError = ConduitProviderError.tokenLimitExceeded(count: 10000, limit: 8000)
        let agentError = conduitError.toAgentError()

        if case let .contextWindowExceeded(tokenCount, limit) = agentError {
            #expect(tokenCount == 10000)
            #expect(limit == 8000)
        } else {
            Issue.record("Expected contextWindowExceeded AgentError")
        }
    }

    @Test("model not available error maps correctly")
    func modelNotAvailableErrorMapsCorrectly() {
        let conduitError = ConduitProviderError.modelNotAvailable(model: "test-model")
        let agentError = conduitError.toAgentError()

        if case let .modelNotAvailable(model) = agentError {
            #expect(model == "test-model")
        } else {
            Issue.record("Expected modelNotAvailable AgentError")
        }
    }

    @Test("cancelled error maps correctly")
    func cancelledErrorMapsCorrectly() {
        let conduitError = ConduitProviderError.cancelled
        let agentError = conduitError.toAgentError()

        if case .cancelled = agentError {
            // Success
        } else {
            Issue.record("Expected cancelled AgentError")
        }
    }

    // MARK: - Provider Type Tests

    @Test("Anthropic provider type has correct display name")
    func anthropicProviderTypeHasCorrectDisplayName() {
        let providerType = ConduitProviderType.anthropic(
            model: .claudeSonnet45,
            apiKey: "test"
        )

        #expect(providerType.displayName == "Anthropic")
    }

    @Test("OpenAI provider type has correct display name")
    func openAIProviderTypeHasCorrectDisplayName() {
        let providerType = ConduitProviderType.openAI(
            model: .gpt4o,
            apiKey: "test"
        )

        #expect(providerType.displayName == "OpenAI")
    }

    @Test("MLX provider type has correct display name")
    func mlxProviderTypeHasCorrectDisplayName() {
        let providerType = ConduitProviderType.mlx(model: .llama3_2_1b)

        #expect(providerType.displayName == "MLX (Local)")
    }

    @Test("HuggingFace provider type has correct display name")
    func huggingFaceProviderTypeHasCorrectDisplayName() {
        let providerType = ConduitProviderType.huggingFace(
            model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct"),
            token: "test"
        )

        #expect(providerType.displayName == "HuggingFace")
    }

    @Test("Foundation Models provider type has correct display name")
    func foundationModelsProviderTypeHasCorrectDisplayName() {
        let providerType = ConduitProviderType.foundationModels

        #expect(providerType.displayName == "Apple Foundation Models")
    }

    @Test("MLX provider requires network returns false")
    func mlxProviderRequiresNetworkReturnsFalse() {
        let providerType = ConduitProviderType.mlx(model: .llama3_2_1b)

        #expect(providerType.requiresNetwork == false)
        #expect(providerType.isOnDevice == true)
    }

    @Test("Foundation Models provider requires network returns false")
    func foundationModelsProviderRequiresNetworkReturnsFalse() {
        let providerType = ConduitProviderType.foundationModels

        #expect(providerType.requiresNetwork == false)
        #expect(providerType.isOnDevice == true)
    }

    @Test("Anthropic provider requires network returns true")
    func anthropicProviderRequiresNetworkReturnsTrue() {
        let providerType = ConduitProviderType.anthropic(
            model: .claudeSonnet45,
            apiKey: "test"
        )

        #expect(providerType.requiresNetwork == true)
        #expect(providerType.isOnDevice == false)
    }

    @Test("OpenAI provider requires network returns true")
    func openAIProviderRequiresNetworkReturnsTrue() {
        let providerType = ConduitProviderType.openAI(
            model: .gpt4o,
            apiKey: "test"
        )

        #expect(providerType.requiresNetwork == true)
    }

    @Test("HuggingFace provider requires network returns true")
    func huggingFaceProviderRequiresNetworkReturnsTrue() {
        let providerType = ConduitProviderType.huggingFace(
            model: .huggingFace("test-model"),
            token: "test"
        )

        #expect(providerType.requiresNetwork == true)
    }

    // MARK: - Model String Tests

    @Test("Anthropic model string is correct")
    func anthropicModelStringIsCorrect() {
        let providerType = ConduitProviderType.anthropic(
            model: .claudeSonnet45,
            apiKey: "test"
        )

        let modelString = providerType.modelString
        #expect(modelString.contains("claude-sonnet"))
    }

    @Test("OpenAI model string is correct")
    func openAIModelStringIsCorrect() {
        let providerType = ConduitProviderType.openAI(
            model: .gpt4o,
            apiKey: "test"
        )

        let modelString = providerType.modelString
        #expect(modelString == "gpt-4o")
    }

    @Test("MLX model string matches identifier")
    func mlxModelStringMatchesIdentifier() {
        let providerType = ConduitProviderType.mlx(model: .llama3_2_1b)

        let modelString = providerType.modelString
        #expect(!modelString.isEmpty)
    }

    @Test("HuggingFace model string matches identifier")
    func huggingFaceModelStringMatchesIdentifier() {
        let modelID = ModelIdentifier.huggingFace("test-hf-model")
        let providerType = ConduitProviderType.huggingFace(
            model: modelID,
            token: "test"
        )

        let modelString = providerType.modelString
        #expect(modelString.contains("test-hf-model"))
    }

    @Test("Foundation Models model string is set")
    func foundationModelsModelStringIsSet() {
        let providerType = ConduitProviderType.foundationModels

        let modelString = providerType.modelString
        #expect(!modelString.isEmpty)
    }

    // MARK: - Equatable Tests

    @Test("same provider types are equal")
    func sameProviderTypesAreEqual() {
        let type1 = ConduitProviderType.anthropic(model: .claudeSonnet45, apiKey: "test")
        let type2 = ConduitProviderType.anthropic(model: .claudeSonnet45, apiKey: "test")

        #expect(type1 == type2)
    }

    @Test("different provider types are not equal")
    func differentProviderTypesAreNotEqual() {
        let type1 = ConduitProviderType.anthropic(model: .claudeSonnet45, apiKey: "test")
        let type2 = ConduitProviderType.openAI(model: .gpt4o, apiKey: "test")

        #expect(type1 != type2)
    }

    @Test("same provider type with different API keys are not equal")
    func sameProviderTypeWithDifferentAPIKeysAreNotEqual() {
        let type1 = ConduitProviderType.anthropic(model: .claudeSonnet45, apiKey: "key1")
        let type2 = ConduitProviderType.anthropic(model: .claudeSonnet45, apiKey: "key2")

        #expect(type1 != type2)
    }

    @Test("same provider type with different models are not equal")
    func sameProviderTypeWithDifferentModelsAreNotEqual() {
        let type1 = ConduitProviderType.openAI(model: .gpt4o, apiKey: "test")
        let type2 = ConduitProviderType.openAI(model: .gpt4oMini, apiKey: "test")

        #expect(type1 != type2)
    }
}
