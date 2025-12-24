// AgentError.swift
// SwiftAgents Framework
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

    /// An internal error occurred.
    case internalError(reason: String)
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
        case let .internalError(reason):
            "Internal error: \(reason)"
        }
    }
}

// MARK: CustomDebugStringConvertible

extension AgentError: CustomDebugStringConvertible {
    public var debugDescription: String {
        "AgentError.\(self)"
    }
}
