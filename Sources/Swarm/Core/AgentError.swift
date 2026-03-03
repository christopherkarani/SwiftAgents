// AgentError.swift
// Swarm Framework
//
// Comprehensive error types for agent operations.

import Foundation

// MARK: - AgentError

/// Errors that can occur during agent execution.
public enum AgentError: Error, Sendable, Equatable {
    // MARK: - Input Errors

    /// The input provided to the agent was empty or invalid.
    case invalidInput(reason: String)

    // MARK: - Execution Errors

    /// The agent was cancelled before completion.
    case cancelled

    /// The agent exceeded the maximum number of iterations.
    case maxIterationsExceeded(iterations: Int)

    /// The agent execution timed out.
    case timeout(duration: Duration)

    /// The agent's declarative loop is invalid.
    case invalidLoop(reason: String)

    // MARK: - Tool Errors

    /// A tool with the given name was not found.
    case toolNotFound(name: String)

    /// A tool failed to execute.
    case toolExecutionFailed(toolName: String, underlyingError: String)

    /// Invalid arguments were provided to a tool.
    case invalidToolArguments(toolName: String, reason: String)

    // MARK: - Model Errors

    /// The inference provider is not available.
    case inferenceProviderUnavailable(reason: String)

    /// The model context window was exceeded.
    case contextWindowExceeded(tokenCount: Int, limit: Int)

    /// The model response violated content guidelines.
    case guardrailViolation(reason: String)

    /// Content was filtered by the model's safety systems.
    case contentFiltered(reason: String)

    /// The language is not supported by the model.
    case unsupportedLanguage(language: String)

    /// The model failed to generate a response.
    case generationFailed(reason: String)

    /// The requested model is not available.
    case modelNotAvailable(model: String)

    // MARK: - Rate Limiting Errors

    /// Rate limit was exceeded.
    case rateLimitExceeded(retryAfter: TimeInterval?)

    // MARK: - Embedding Errors

    /// Embedding operation failed.
    case embeddingFailed(reason: String)

    // MARK: - Internal Errors

    /// An agent with the specified name was not registered.
    case agentNotFound(name: String)

    /// An internal error occurred.
    case internalError(reason: String)

    /// Tool calling was requested but Foundation Models do not support it.
    case toolCallingRequiresCloudProvider
}

// MARK: LocalizedError

extension AgentError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidInput(reason):
            "Invalid input: \(reason)"
        case .cancelled:
            "Agent execution was cancelled"
        case let .maxIterationsExceeded(iterations):
            "Agent exceeded maximum iterations (\(iterations))"
        case let .timeout(duration):
            "Agent execution timed out after \(duration)"
        case let .invalidLoop(reason):
            "Invalid agent loop: \(reason)"
        case let .toolNotFound(name):
            "Tool not found: \(name)"
        case let .toolExecutionFailed(toolName, error):
            "Tool '\(toolName)' failed: \(error)"
        case let .invalidToolArguments(toolName, reason):
            "Invalid arguments for tool '\(toolName)': \(reason)"
        case let .inferenceProviderUnavailable(reason):
            "Inference provider unavailable: \(reason)"
        case let .contextWindowExceeded(count, limit):
            "Context window exceeded: \(count) tokens (limit: \(limit))"
        case let .guardrailViolation(reason):
            "Response violated content guidelines: \(reason)"
        case let .contentFiltered(reason):
            "Content filtered: \(reason)"
        case let .unsupportedLanguage(language):
            "Language not supported: \(language)"
        case let .generationFailed(reason):
            "Generation failed: \(reason)"
        case let .modelNotAvailable(model):
            "Model not available: \(model)"
        case let .rateLimitExceeded(retryAfter):
            if let retryAfter {
                "Rate limit exceeded, retry after \(retryAfter) seconds"
            } else {
                "Rate limit exceeded"
            }
        case let .embeddingFailed(reason):
            "Embedding failed: \(reason)"
        case let .agentNotFound(name):
            "Agent not found: '\(name)'"
        case let .internalError(reason):
            "Internal error: \(reason)"
        case .toolCallingRequiresCloudProvider:
            "Foundation Models do not support tool calling. A cloud provider is required."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .toolCallingRequiresCloudProvider:
            "Call `await Swarm.configure(cloudProvider:)` or pass a tool-calling-capable provider explicitly to `Agent(...)`."
        default:
            nil
        }
    }
}

// MARK: CustomDebugStringConvertible

extension AgentError: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .invalidInput(reason):
            "AgentError.invalidInput(reason: \(reason))"
        case .cancelled:
            "AgentError.cancelled"
        case let .maxIterationsExceeded(iterations):
            "AgentError.maxIterationsExceeded(iterations: \(iterations))"
        case let .timeout(duration):
            "AgentError.timeout(duration: \(duration))"
        case let .invalidLoop(reason):
            "AgentError.invalidLoop(reason: \(reason))"
        case let .toolNotFound(name):
            "AgentError.toolNotFound(name: \(name))"
        case let .toolExecutionFailed(toolName, underlyingError):
            "AgentError.toolExecutionFailed(toolName: \(toolName), underlyingError: \(underlyingError))"
        case let .invalidToolArguments(toolName, reason):
            "AgentError.invalidToolArguments(toolName: \(toolName), reason: \(reason))"
        case let .inferenceProviderUnavailable(reason):
            "AgentError.inferenceProviderUnavailable(reason: \(reason))"
        case let .contextWindowExceeded(tokenCount, limit):
            "AgentError.contextWindowExceeded(tokenCount: \(tokenCount), limit: \(limit))"
        case let .guardrailViolation(reason):
            "AgentError.guardrailViolation(reason: \(reason))"
        case let .contentFiltered(reason):
            "AgentError.contentFiltered(reason: \(reason))"
        case let .unsupportedLanguage(language):
            "AgentError.unsupportedLanguage(language: \(language))"
        case let .generationFailed(reason):
            "AgentError.generationFailed(reason: \(reason))"
        case let .modelNotAvailable(model):
            "AgentError.modelNotAvailable(model: \(model))"
        case let .rateLimitExceeded(retryAfter):
            "AgentError.rateLimitExceeded(retryAfter: \(String(describing: retryAfter)))"
        case let .embeddingFailed(reason):
            "AgentError.embeddingFailed(reason: \(reason))"
        case let .agentNotFound(name):
            "AgentError.agentNotFound(name: \(name))"
        case let .internalError(reason):
            "AgentError.internalError(reason: \(reason))"
        case .toolCallingRequiresCloudProvider:
            "AgentError.toolCallingRequiresCloudProvider"
        }
    }
}
