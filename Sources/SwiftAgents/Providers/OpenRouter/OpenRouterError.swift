// OpenRouterError.swift
// SwiftAgents Framework
//
// Error types for OpenRouter provider operations.

import Foundation

// MARK: - SendableErrorWrapper

/// A Sendable wrapper for non-Sendable errors.
/// Stores the error description as a string to ensure thread-safety.
public struct SendableErrorWrapper: Sendable, Equatable, CustomStringConvertible {
    /// The error description extracted from the original error.
    public let errorDescription: String

    /// Creates a wrapper from any error.
    /// - Parameter error: The error to wrap.
    public init(_ error: any Error) {
        self.errorDescription = error.localizedDescription
    }

    /// Creates a wrapper from an error description string.
    /// - Parameter description: The error description.
    public init(description: String) {
        self.errorDescription = description
    }

    public var description: String {
        errorDescription
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

// MARK: - LocalizedError

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

extension OpenRouterProviderError {
    /// Converts this provider error to a generic AgentError.
    /// - Returns: The corresponding AgentError.
    public func toAgentError() -> AgentError {
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

extension OpenRouterProviderError {
    /// Creates an error from an HTTP status code and response body.
    /// - Parameters:
    ///   - statusCode: The HTTP status code.
    ///   - body: The response body data, if available.
    ///   - headers: The HTTP response headers, if available.
    /// - Returns: The corresponding OpenRouterProviderError.
    public static func fromHTTPStatus(
        _ statusCode: Int,
        body: Data?,
        headers: [AnyHashable: Any]? = nil
    ) -> OpenRouterProviderError {
        // Try to parse error details from body
        var errorCode = "unknown"
        var errorMessage = "An error occurred"

        if let body, let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            if let error = json["error"] as? [String: Any] {
                errorCode = error["code"] as? String ?? errorCode
                errorMessage = error["message"] as? String ?? errorMessage
            } else if let message = json["message"] as? String {
                errorMessage = message
            } else if let error = json["error"] as? String {
                errorMessage = error
            }
        }

        switch statusCode {
        case 400:
            // Bad request - could be empty prompt or invalid parameters
            if errorMessage.lowercased().contains("prompt") || errorMessage.lowercased().contains("empty") {
                return .emptyPrompt
            }
            return .apiError(code: errorCode, message: errorMessage, statusCode: statusCode)

        case 401:
            return .authenticationFailed

        case 402:
            return .insufficientCredits

        case 403:
            // Forbidden - could be content filtered or auth issue
            if errorMessage.lowercased().contains("content") || errorMessage.lowercased().contains("filter") {
                return .contentFiltered
            }
            return .authenticationFailed

        case 404:
            // Model not found
            return .modelNotAvailable(model: errorMessage)

        case 429:
            // Rate limited - try to extract retry-after
            var retryAfter: TimeInterval? = nil

            // First check HTTP headers (standard Retry-After header)
            if let headers = headers {
                for (key, value) in headers {
                    if let keyStr = key as? String,
                       keyStr.lowercased() == "retry-after",
                       let valueStr = value as? String,
                       let seconds = TimeInterval(valueStr) {
                        retryAfter = seconds
                        break
                    }
                }
            }

            // Fall back to JSON body
            if retryAfter == nil, let body,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                if let retry = json["retry_after"] as? TimeInterval {
                    retryAfter = retry
                } else if let retry = json["retry_after"] as? Int {
                    retryAfter = TimeInterval(retry)
                }
            }
            return .rateLimitExceeded(retryAfter: retryAfter)

        case 408:
            return .timeout(duration: .seconds(60))

        case 502:
            return .providerUnavailable(providers: ["upstream_provider"])

        case 503:
            return .providerUnavailable(providers: [])

        case 504:
            return .timeout(duration: .seconds(60))

        case 500, 505...599:
            if errorMessage.lowercased().contains("provider") {
                return .providerUnavailable(providers: ["unknown"])
            }
            return .apiError(code: errorCode, message: errorMessage, statusCode: statusCode)

        default:
            return .unknownError(statusCode: statusCode)
        }
    }

    /// Creates an error from a URLError.
    /// - Parameter urlError: The URLError to convert.
    /// - Returns: The corresponding OpenRouterProviderError.
    public static func fromURLError(_ urlError: URLError) -> OpenRouterProviderError {
        switch urlError.code {
        case .cancelled:
            return .cancelled

        case .timedOut:
            // URLError doesn't provide duration, use a default
            return .timeout(duration: .seconds(60))

        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed:
            return .networkError(SendableErrorWrapper(urlError))

        case .userAuthenticationRequired:
            return .authenticationFailed

        case .cannotDecodeRawData,
             .cannotDecodeContentData,
             .cannotParseResponse:
            return .decodingError(SendableErrorWrapper(urlError))

        default:
            return .networkError(SendableErrorWrapper(urlError))
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension OpenRouterProviderError: CustomDebugStringConvertible {
    public var debugDescription: String {
        "OpenRouterProviderError.\(self)"
    }
}
