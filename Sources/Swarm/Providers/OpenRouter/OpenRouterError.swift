// OpenRouterError.swift
// Swarm Framework
//
// Error types for OpenRouter provider operations.

import Foundation

// MARK: - SendableErrorWrapper

/// A Sendable wrapper for non-Sendable errors.
/// Stores the error description as a string to ensure thread-safety.
public struct SendableErrorWrapper: Sendable, Equatable, CustomStringConvertible {
    /// The error description extracted from the original error.
    public let errorDescription: String

    public var description: String {
        errorDescription
    }

    /// Creates a wrapper from any error.
    /// - Parameter error: The error to wrap.
    public init(_ error: any Error) {
        errorDescription = error.localizedDescription
    }

    /// Creates a wrapper from an error description string.
    /// - Parameter description: The error description.
    public init(description: String) {
        errorDescription = description
    }
}

// MARK: - OpenRouterProviderError

/// Errors specific to OpenRouter API operations.
public enum OpenRouterProviderError: Error, Sendable, Equatable {
    // MARK: - Response Errors

    /// The API response was invalid or malformed.
    case invalidResponse

    /// An API error occurred with the given code, message, and HTTP status.
    case apiError(code: String, message: String, statusCode: Int)

    /// Rate limit was exceeded.
    /// - Parameter retryAfter: Seconds to wait before retrying, if provided by the API.
    case rateLimitExceeded(retryAfter: TimeInterval?)

    /// Authentication failed (invalid or missing API key).
    case authenticationFailed

    // MARK: - Network Errors

    /// A network error occurred.
    case networkError(SendableErrorWrapper)

    /// Failed to decode the API response.
    case decodingError(SendableErrorWrapper)

    /// An unknown error occurred with the given HTTP status code.
    case unknownError(statusCode: Int)

    // MARK: - Model/Provider Errors

    /// The requested model is not available.
    case modelNotAvailable(model: String)

    /// Insufficient credits to complete the request.
    case insufficientCredits

    /// Content was filtered by safety systems.
    case contentFiltered

    /// One or more providers are unavailable.
    case providerUnavailable(providers: [String])

    /// All fallback providers have been exhausted.
    case fallbackExhausted(reason: String)

    // MARK: - Streaming Errors

    /// An error occurred during streaming.
    case streamingError(message: String)

    // MARK: - Execution Errors

    /// The request was cancelled.
    case cancelled

    /// The request timed out.
    case timeout(duration: Duration)

    /// The prompt was empty or invalid.
    case emptyPrompt
}

// MARK: LocalizedError

extension OpenRouterProviderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenRouter API"

        case let .apiError(code, message, statusCode):
            return "OpenRouter API error [\(code)] (HTTP \(statusCode)): \(message)"

        case let .rateLimitExceeded(retryAfter):
            if let retryAfter {
                return "Rate limit exceeded, retry after \(Int(retryAfter)) seconds"
            }
            return "Rate limit exceeded"

        case .authenticationFailed:
            return "Authentication failed: invalid or missing API key"

        case let .networkError(wrapper):
            return "Network error: \(wrapper.errorDescription)"

        case let .decodingError(wrapper):
            return "Failed to decode response: \(wrapper.errorDescription)"

        case let .unknownError(statusCode):
            return "Unknown error (HTTP \(statusCode))"

        case let .modelNotAvailable(model):
            return "Model not available: \(model)"

        case .insufficientCredits:
            return "Insufficient credits to complete the request"

        case .contentFiltered:
            return "Content was filtered by safety systems"

        case let .providerUnavailable(providers):
            let providerList = providers.joined(separator: ", ")
            return "Provider(s) unavailable: \(providerList)"

        case let .fallbackExhausted(reason):
            return "All fallback providers exhausted: \(reason)"

        case let .streamingError(message):
            return "Streaming error: \(message)"

        case .cancelled:
            return "Request was cancelled"

        case let .timeout(duration):
            return "Request timed out after \(duration)"

        case .emptyPrompt:
            return "Prompt cannot be empty"
        }
    }
}

// MARK: - AgentError Conversion

public extension OpenRouterProviderError {
    /// Converts this provider error to a generic AgentError.
    /// - Returns: The corresponding AgentError.
    func toAgentError() -> AgentError {
        switch self {
        case .invalidResponse:
            return .generationFailed(reason: "Invalid response from OpenRouter API")

        case let .apiError(code, message, statusCode):
            return .generationFailed(reason: "API error [\(code)] (HTTP \(statusCode)): \(message)")

        case let .rateLimitExceeded(retryAfter):
            return .rateLimitExceeded(retryAfter: retryAfter)

        case .authenticationFailed:
            return .inferenceProviderUnavailable(reason: "Authentication failed")

        case let .networkError(wrapper):
            return .inferenceProviderUnavailable(reason: "Network error: \(wrapper.errorDescription)")

        case let .decodingError(wrapper):
            return .generationFailed(reason: "Decoding error: \(wrapper.errorDescription)")

        case let .unknownError(statusCode):
            return .generationFailed(reason: "Unknown error (HTTP \(statusCode))")

        case let .modelNotAvailable(model):
            return .modelNotAvailable(model: model)

        case .insufficientCredits:
            return .inferenceProviderUnavailable(reason: "Insufficient credits")

        case .contentFiltered:
            return .contentFiltered(reason: "Content filtered by OpenRouter safety systems")

        case let .providerUnavailable(providers):
            let providerList = providers.joined(separator: ", ")
            return .inferenceProviderUnavailable(reason: "Provider(s) unavailable: \(providerList)")

        case let .fallbackExhausted(reason):
            return .inferenceProviderUnavailable(reason: "Fallback exhausted: \(reason)")

        case let .streamingError(message):
            return .generationFailed(reason: "Streaming error: \(message)")

        case .cancelled:
            return .cancelled

        case let .timeout(duration):
            return .timeout(duration: duration)

        case .emptyPrompt:
            return .invalidInput(reason: "Prompt cannot be empty")
        }
    }
}

// MARK: - Factory Methods

public extension OpenRouterProviderError {
    /// Creates an error from an HTTP status code and response body.
    /// - Parameters:
    ///   - statusCode: The HTTP status code.
    ///   - body: The response body data, if available.
    ///   - headers: The HTTP response headers, if available.
    /// - Returns: The corresponding OpenRouterProviderError.
    static func fromHTTPStatus(
        _ statusCode: Int,
        body: Data?,
        headers: [AnyHashable: Any]? = nil
    ) -> OpenRouterProviderError {
        let (errorCode, errorMessage) = parseErrorDetails(from: body)

        switch statusCode {
        case 400:
            return handleBadRequest(errorCode: errorCode, errorMessage: errorMessage, statusCode: statusCode)
        case 401:
            return .authenticationFailed
        case 402:
            return .insufficientCredits
        case 403:
            return handleForbidden(errorMessage: errorMessage)
        case 404:
            return .modelNotAvailable(model: errorMessage)
        case 429:
            return handleRateLimited(body: body, headers: headers)
        case 408,
             504:
            return .timeout(duration: .seconds(60))
        case 502:
            return .providerUnavailable(providers: ["upstream_provider"])
        case 503:
            return .providerUnavailable(providers: [])
        case 500,
             505...599:
            return handleServerError(errorCode: errorCode, errorMessage: errorMessage, statusCode: statusCode)
        default:
            return .unknownError(statusCode: statusCode)
        }
    }

    /// Creates an error from a URLError.
    /// - Parameter urlError: The URLError to convert.
    /// - Returns: The corresponding OpenRouterProviderError.
    static func fromURLError(_ urlError: URLError) -> OpenRouterProviderError {
        switch urlError.code {
        case .cancelled:
            .cancelled
        case .timedOut:
            .timeout(duration: .seconds(60))
        case .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .networkConnectionLost,
             .notConnectedToInternet:
            .networkError(SendableErrorWrapper(urlError))
        case .userAuthenticationRequired:
            .authenticationFailed
        case .cannotDecodeContentData,
             .cannotDecodeRawData,
             .cannotParseResponse:
            .decodingError(SendableErrorWrapper(urlError))
        default:
            .networkError(SendableErrorWrapper(urlError))
        }
    }
}

// MARK: - Private HTTP Status Helpers

private extension OpenRouterProviderError {
    /// Parses error details from response body JSON.
    static func parseErrorDetails(from body: Data?) -> (errorCode: String, errorMessage: String) {
        var errorCode = "unknown"
        var errorMessage = "An error occurred"

        guard let body, let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return (errorCode, errorMessage)
        }

        if let error = json["error"] as? [String: Any] {
            errorCode = error["code"] as? String ?? errorCode
            errorMessage = error["message"] as? String ?? errorMessage
        } else if let message = json["message"] as? String {
            errorMessage = message
        } else if let error = json["error"] as? String {
            errorMessage = error
        }

        return (errorCode, errorMessage)
    }

    /// Handles HTTP 400 Bad Request errors.
    static func handleBadRequest(errorCode: String, errorMessage: String, statusCode: Int) -> OpenRouterProviderError {
        let lowercased = errorMessage.lowercased()
        if lowercased.contains("prompt") || lowercased.contains("empty") {
            return .emptyPrompt
        }
        return .apiError(code: errorCode, message: errorMessage, statusCode: statusCode)
    }

    /// Handles HTTP 403 Forbidden errors.
    static func handleForbidden(errorMessage: String) -> OpenRouterProviderError {
        let lowercased = errorMessage.lowercased()
        if lowercased.contains("content") || lowercased.contains("filter") {
            return .contentFiltered
        }
        return .authenticationFailed
    }

    /// Handles HTTP 429 Rate Limited errors.
    static func handleRateLimited(body: Data?, headers: [AnyHashable: Any]?) -> OpenRouterProviderError {
        let retryAfter = extractRetryAfter(from: headers) ?? extractRetryAfterFromBody(body)
        return .rateLimitExceeded(retryAfter: retryAfter)
    }

    /// Extracts retry-after value from HTTP headers.
    static func extractRetryAfter(from headers: [AnyHashable: Any]?) -> TimeInterval? {
        guard let headers else { return nil }
        for (key, value) in headers {
            if let keyStr = key as? String,
               keyStr.lowercased() == "retry-after",
               let valueStr = value as? String,
               let seconds = TimeInterval(valueStr) {
                return seconds
            }
        }
        return nil
    }

    /// Extracts retry-after value from JSON body.
    static func extractRetryAfterFromBody(_ body: Data?) -> TimeInterval? {
        guard let body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return nil
        }
        if let retry = json["retry_after"] as? TimeInterval {
            return retry
        } else if let retry = json["retry_after"] as? Int {
            return TimeInterval(retry)
        }
        return nil
    }

    /// Handles HTTP 5xx Server errors.
    static func handleServerError(errorCode: String, errorMessage: String, statusCode: Int) -> OpenRouterProviderError {
        if errorMessage.lowercased().contains("provider") {
            return .providerUnavailable(providers: ["unknown"])
        }
        return .apiError(code: errorCode, message: errorMessage, statusCode: statusCode)
    }
}

// MARK: CustomDebugStringConvertible

extension OpenRouterProviderError: CustomDebugStringConvertible {
    public var debugDescription: String {
        "OpenRouterProviderError.\(self)"
    }
}
