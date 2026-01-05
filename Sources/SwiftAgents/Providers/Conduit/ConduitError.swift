// ConduitError.swift
// SwiftAgents Framework
//
// Error types and mappings for Conduit provider operations.

import Conduit
import Foundation

// MARK: - ConduitProviderError

/// Errors specific to Conduit provider operations.
///
/// This error type wraps and extends Conduit's `AIError` cases with additional
/// context for SwiftAgents integration. Use `toAgentError()` to convert to
/// the generic `AgentError` type for consistent error handling across providers.
public enum ConduitProviderError: Error, Sendable, Equatable {
    // MARK: - Model Errors

    /// The requested model is not cached and requires download.
    /// - Parameter model: The model identifier that needs to be downloaded.
    case modelNotCached(model: String)

    /// The requested model is not available or not found.
    /// - Parameter model: The model identifier that was not found.
    case modelNotAvailable(model: String)

    // MARK: - Provider Errors

    /// The provider is unavailable due to platform requirements.
    /// - Parameter reason: A description of why the provider is unavailable.
    case providerUnavailable(reason: String)

    /// The API key or token is invalid or missing.
    case authenticationFailed

    // MARK: - Token/Context Errors

    /// The input exceeded the model's token limit.
    /// - Parameters:
    ///   - count: The number of tokens in the input.
    ///   - limit: The maximum allowed token count.
    case tokenLimitExceeded(count: Int, limit: Int)

    // MARK: - Network Errors

    /// A network error occurred.
    /// - Parameter message: A description of the network error.
    case networkError(message: String)

    /// The request timed out.
    /// - Parameter duration: The timeout duration that was exceeded.
    case timeout(duration: TimeInterval)

    // MARK: - Content Errors

    /// Content was filtered by safety systems.
    /// - Parameter reason: A description of why content was filtered.
    case contentFiltered(reason: String)

    // MARK: - Generation Errors

    /// Generation failed for a specific reason.
    /// - Parameter reason: A description of why generation failed.
    case generationFailed(reason: String)

    /// The prompt was empty or invalid.
    case emptyPrompt

    // MARK: - Execution Errors

    /// The request was cancelled.
    case cancelled

    /// Rate limit was exceeded.
    /// - Parameter retryAfter: Seconds to wait before retrying, if known.
    case rateLimitExceeded(retryAfter: TimeInterval?)

    // MARK: - Internal Errors

    /// An internal error occurred.
    /// - Parameter reason: A description of the internal error.
    case internalError(reason: String)

    /// An unknown error occurred.
    /// - Parameter underlyingError: The original error description.
    case unknown(underlyingError: String)
}

// MARK: - LocalizedError

extension ConduitProviderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .modelNotCached(model):
            return "Model '\(model)' is not cached and requires download"

        case let .modelNotAvailable(model):
            return "Model not available: \(model)"

        case let .providerUnavailable(reason):
            return "Provider unavailable: \(reason)"

        case .authenticationFailed:
            return "Authentication failed: invalid or missing API key"

        case let .tokenLimitExceeded(count, limit):
            return "Token limit exceeded: \(count) tokens (limit: \(limit))"

        case let .networkError(message):
            return "Network error: \(message)"

        case let .timeout(duration):
            return "Request timed out after \(duration) seconds"

        case let .contentFiltered(reason):
            return "Content filtered: \(reason)"

        case let .generationFailed(reason):
            return "Generation failed: \(reason)"

        case .emptyPrompt:
            return "Prompt cannot be empty"

        case .cancelled:
            return "Request was cancelled"

        case let .rateLimitExceeded(retryAfter):
            if let retryAfter {
                return "Rate limit exceeded, retry after \(Int(retryAfter)) seconds"
            }
            return "Rate limit exceeded"

        case let .internalError(reason):
            return "Internal error: \(reason)"

        case let .unknown(underlyingError):
            return "Unknown error: \(underlyingError)"
        }
    }
}

// MARK: - AgentError Conversion

public extension ConduitProviderError {
    /// Converts this provider error to a generic `AgentError`.
    ///
    /// This mapping provides consistent error handling across different
    /// inference providers in SwiftAgents.
    ///
    /// - Returns: The corresponding `AgentError`.
    func toAgentError() -> AgentError {
        switch self {
        case let .modelNotCached(model):
            return .modelNotAvailable(model: "\(model) (not cached)")

        case let .modelNotAvailable(model):
            return .modelNotAvailable(model: model)

        case let .providerUnavailable(reason):
            return .inferenceProviderUnavailable(reason: reason)

        case .authenticationFailed:
            return .inferenceProviderUnavailable(reason: "Authentication failed")

        case let .tokenLimitExceeded(count, limit):
            return .contextWindowExceeded(tokenCount: count, limit: limit)

        case let .networkError(message):
            return .inferenceProviderUnavailable(reason: "Network error: \(message)")

        case let .timeout(duration):
            return .timeout(duration: .seconds(Int64(duration)))

        case let .contentFiltered(reason):
            return .contentFiltered(reason: reason)

        case let .generationFailed(reason):
            return .generationFailed(reason: reason)

        case .emptyPrompt:
            return .invalidInput(reason: "Prompt cannot be empty")

        case .cancelled:
            return .cancelled

        case let .rateLimitExceeded(retryAfter):
            return .rateLimitExceeded(retryAfter: retryAfter)

        case let .internalError(reason):
            return .internalError(reason: reason)

        case let .unknown(underlyingError):
            return .internalError(reason: underlyingError)
        }
    }
}

// MARK: - AIError Mapping

public extension ConduitProviderError {
    /// Creates a `ConduitProviderError` from a Conduit `AIError`.
    ///
    /// This factory method maps Conduit's error types to SwiftAgents' error
    /// representation for consistent error handling.
    ///
    /// - Parameter aiError: The Conduit `AIError` to convert.
    /// - Returns: The corresponding `ConduitProviderError`.
    static func from(aiError: AIError) -> ConduitProviderError {
        switch aiError {
        case let .modelNotCached(model):
            return .modelNotCached(model: model.rawValue)

        case let .providerUnavailable(reason):
            return .providerUnavailable(reason: reason.description)

        case let .tokenLimitExceeded(count, limit):
            return .tokenLimitExceeded(count: count, limit: limit)

        case let .networkError(urlError):
            return .networkError(message: urlError.localizedDescription)

        case let .generationFailed(underlying):
            return .generationFailed(reason: underlying.localizedDescription)

        case .cancelled:
            return .cancelled

        case let .rateLimited(retryAfter):
            return .rateLimitExceeded(retryAfter: retryAfter)

        case let .authenticationFailed(message):
            return .providerUnavailable(reason: "Authentication failed: \(message)")

        case let .contentFiltered(reason):
            return .contentFiltered(reason: reason ?? "Content filtered")

        case let .timeout(duration):
            return .timeout(duration: duration)

        case let .serverError(statusCode, message):
            let errorMessage = message ?? "HTTP \(statusCode)"
            return .generationFailed(reason: "Server error: \(errorMessage)")

        case let .invalidInput(message):
            return .generationFailed(reason: "Invalid input: \(message)")

        case let .modelNotFound(model):
            return .modelNotAvailable(model: model.rawValue)

        case let .insufficientMemory(required, available):
            return .providerUnavailable(reason: "Insufficient memory: requires \(required.formatted), available \(available.formatted)")

        case let .downloadFailed(underlying):
            return .providerUnavailable(reason: "Download failed: \(underlying.localizedDescription)")

        case let .fileError(underlying):
            return .internalError(reason: "File error: \(underlying.localizedDescription)")

        case let .insufficientDiskSpace(required, available):
            return .providerUnavailable(reason: "Insufficient disk space: requires \(required.formatted), available \(available.formatted)")

        case let .checksumMismatch(expected, actual):
            return .internalError(reason: "Checksum mismatch: expected \(expected), got \(actual)")

        case let .unsupportedAudioFormat(format):
            return .generationFailed(reason: "Unsupported audio format: \(format)")

        case let .unsupportedLanguage(language):
            return .generationFailed(reason: "Unsupported language: \(language)")

        case let .invalidToolName(name, reason):
            return .generationFailed(reason: "Invalid tool name '\(name)': \(reason)")

        case let .unsupportedPlatform(message):
            return .providerUnavailable(reason: "Unsupported platform: \(message)")

        case let .modelNotLoaded(message):
            return .providerUnavailable(reason: "Model not loaded: \(message)")

        case let .incompatibleModel(model, reasons):
            let reasonList = reasons.joined(separator: ", ")
            return .providerUnavailable(reason: "Incompatible model '\(model.rawValue)': \(reasonList)")

        case let .billingError(message):
            return .providerUnavailable(reason: "Billing error: \(message)")

        case let .unsupportedModel(variant, reason):
            return .providerUnavailable(reason: "Unsupported model '\(variant)': \(reason)")
        }
    }

    /// Convenience method to convert Conduit `AIError` directly to `AgentError`.
    ///
    /// This is a shorthand for `ConduitProviderError.from(aiError:).toAgentError()`.
    ///
    /// - Parameter aiError: The Conduit `AIError` to convert.
    /// - Returns: The corresponding `AgentError`.
    static func toAgentError(from aiError: AIError) -> AgentError {
        from(aiError: aiError).toAgentError()
    }
}

// MARK: - CustomDebugStringConvertible

extension ConduitProviderError: CustomDebugStringConvertible {
    public var debugDescription: String {
        "ConduitProviderError.\(self)"
    }
}

// MARK: - Error Extension

public extension Error {
    /// Attempts to convert this error to a `ConduitProviderError`.
    ///
    /// If the error is already a `ConduitProviderError`, returns it directly.
    /// If it's a Conduit `AIError`, maps it to the corresponding `ConduitProviderError`.
    /// Otherwise, wraps it as an unknown error.
    ///
    /// - Returns: A `ConduitProviderError` representation of this error.
    func toConduitProviderError() -> ConduitProviderError {
        if let conduitError = self as? ConduitProviderError {
            return conduitError
        }

        if let aiError = self as? AIError {
            return ConduitProviderError.from(aiError: aiError)
        }

        return .unknown(underlyingError: localizedDescription)
    }
}
