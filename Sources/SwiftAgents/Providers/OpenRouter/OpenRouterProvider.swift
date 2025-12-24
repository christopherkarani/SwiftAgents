// OpenRouterProvider.swift
// SwiftAgents Framework
//
// OpenRouter inference provider for accessing multiple LLM backends.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - OpenRouterProvider

/// OpenRouter inference provider for accessing multiple LLM backends.
///
/// OpenRouter provides unified access to models from OpenAI, Anthropic, Google,
/// Meta, Mistral, and other providers through a single API.
///
/// Example:
/// ```swift
/// let provider = OpenRouterProvider(
///     apiKey: "sk-or-v1-...",
///     model: .claude35Sonnet
/// )
///
/// let response = try await provider.generate(
///     prompt: "Explain quantum computing",
///     options: .default
/// )
/// ```
public actor OpenRouterProvider: InferenceProvider {
    // MARK: - Properties

    private let configuration: OpenRouterConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var rateLimitInfo: OpenRouterRateLimitInfo?

    /// Cached model description for nonisolated access.
    private let modelDescription: String

    // MARK: - Initialization

    /// Creates an OpenRouter provider with the given configuration.
    /// - Parameter configuration: The provider configuration.
    public init(configuration: OpenRouterConfiguration) {
        self.configuration = configuration
        self.modelDescription = configuration.model.identifier

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout.timeInterval
        sessionConfig.timeoutIntervalForResource = configuration.timeout.timeInterval * 2
        self.session = URLSession(configuration: sessionConfig)

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    /// Creates an OpenRouter provider with an API key and model.
    /// - Parameters:
    ///   - apiKey: The OpenRouter API key.
    ///   - model: The model to use. Default: .gpt4o
    /// - Throws: `OpenRouterConfigurationError` if configuration validation fails.
    public init(apiKey: String, model: OpenRouterModel = .gpt4o) throws {
        try self.init(configuration: OpenRouterConfiguration(apiKey: apiKey, model: model))
    }

    // MARK: - InferenceProvider Conformance

    /// Generates a response for the given prompt.
    /// - Parameters:
    ///   - prompt: The input prompt.
    ///   - options: Generation options.
    /// - Returns: The generated text.
    /// - Throws: `AgentError` if generation fails.
    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput(reason: "Prompt cannot be empty")
        }

        let request = try buildRequest(prompt: prompt, options: options, stream: false)
        let maxRetries = configuration.retryStrategy.maxRetries

        for attempt in 0..<(maxRetries + 1) {
            try Task.checkCancellation()

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AgentError.generationFailed(reason: "Invalid response type")
                }

                // Update rate limit info
                rateLimitInfo = OpenRouterRateLimitInfo.parse(from: httpResponse.allHeaderFields)

                // Handle HTTP errors
                if httpResponse.statusCode != 200 {
                    try handleHTTPError(statusCode: httpResponse.statusCode, data: data, attempt: attempt, maxRetries: maxRetries)
                    continue
                }

                // Parse response
                let chatResponse = try decoder.decode(OpenRouterResponse.self, from: data)

                guard let content = chatResponse.choices.first?.message.content else {
                    throw AgentError.generationFailed(reason: "No content in response")
                }

                return content

            } catch let error as AgentError {
                if attempt == maxRetries {
                    throw error
                }
                // Retry on retryable errors
                if case .rateLimitExceeded = error {
                    let delay = configuration.retryStrategy.delay(forAttempt: attempt + 1)
                    try await Task.sleep(for: .seconds(delay))
                    continue
                }
                throw error
            } catch is CancellationError {
                throw AgentError.cancelled
            } catch {
                if attempt == maxRetries {
                    throw AgentError.generationFailed(reason: error.localizedDescription)
                }
                let delay = configuration.retryStrategy.delay(forAttempt: attempt + 1)
                try await Task.sleep(for: .seconds(delay))
            }
        }

        throw AgentError.generationFailed(reason: "Max retries exceeded")
    }

    /// Streams a response for the given prompt.
    /// - Parameters:
    ///   - prompt: The input prompt.
    ///   - options: Generation options.
    /// - Returns: An async stream of response tokens.
    public nonisolated func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.performStream(prompt: prompt, options: options, continuation: continuation)
                } catch is CancellationError {
                    continuation.finish(throwing: AgentError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    /// Generates a response with potential tool calls.
    /// - Parameters:
    ///   - prompt: The input prompt.
    ///   - tools: Available tool definitions.
    ///   - options: Generation options.
    /// - Returns: The inference response which may include tool calls.
    /// - Throws: `AgentError` if generation fails.
    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolDefinition],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput(reason: "Prompt cannot be empty")
        }

        let request = try buildRequest(prompt: prompt, options: options, stream: false, tools: tools)
        let maxRetries = configuration.retryStrategy.maxRetries

        for attempt in 0..<(maxRetries + 1) {
            try Task.checkCancellation()

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AgentError.generationFailed(reason: "Invalid response type")
                }

                // Update rate limit info
                rateLimitInfo = OpenRouterRateLimitInfo.parse(from: httpResponse.allHeaderFields)

                // Handle HTTP errors
                if httpResponse.statusCode != 200 {
                    try handleHTTPError(statusCode: httpResponse.statusCode, data: data, attempt: attempt, maxRetries: maxRetries)
                    continue
                }

                // Parse response
                let chatResponse = try decoder.decode(OpenRouterResponse.self, from: data)

                guard let choice = chatResponse.choices.first else {
                    throw AgentError.generationFailed(reason: "No choices in response")
                }

                // Map finish reason
                let finishReason = mapFinishReason(choice.finishReason)

                // Parse tool calls if present
                var parsedToolCalls: [InferenceResponse.ParsedToolCall] = []
                if let toolCalls = choice.message.toolCalls {
                    // Validate all tool calls have required IDs
                    for toolCall in toolCalls {
                        guard !toolCall.id.isEmpty else {
                            throw AgentError.generationFailed(reason: "Tool call missing required ID")
                        }
                    }
                    // Use the public API to parse tool calls
                    parsedToolCalls = try OpenRouterToolCallParser.toParsedToolCalls(toolCalls)
                }

                // Parse usage statistics
                var usage: InferenceResponse.TokenUsage?
                if let responseUsage = chatResponse.usage {
                    usage = InferenceResponse.TokenUsage(
                        inputTokens: responseUsage.promptTokens,
                        outputTokens: responseUsage.completionTokens
                    )
                }

                return InferenceResponse(
                    content: choice.message.content,
                    toolCalls: parsedToolCalls,
                    finishReason: finishReason,
                    usage: usage
                )

            } catch let error as AgentError {
                if attempt == maxRetries {
                    throw error
                }
                if case .rateLimitExceeded = error {
                    let delay = configuration.retryStrategy.delay(forAttempt: attempt + 1)
                    try await Task.sleep(for: .seconds(delay))
                    continue
                }
                throw error
            } catch is CancellationError {
                throw AgentError.cancelled
            } catch {
                if attempt == maxRetries {
                    throw AgentError.generationFailed(reason: error.localizedDescription)
                }
                let delay = configuration.retryStrategy.delay(forAttempt: attempt + 1)
                try await Task.sleep(for: .seconds(delay))
            }
        }

        throw AgentError.generationFailed(reason: "Max retries exceeded")
    }

    // MARK: - Private Methods

    private func performStream(
        prompt: String,
        options: InferenceOptions,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput(reason: "Prompt cannot be empty")
        }

        let request = try buildRequest(prompt: prompt, options: options, stream: true)
        let maxRetries = configuration.retryStrategy.maxRetries

        for attempt in 0..<(maxRetries + 1) {
            try Task.checkCancellation()

            do {
                #if canImport(FoundationNetworking)
                // Linux: Use data(for:) and manual line splitting
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AgentError.generationFailed(reason: "Invalid response type")
                }

                // Update rate limit info
                rateLimitInfo = OpenRouterRateLimitInfo.parse(from: httpResponse.allHeaderFields)

                // Handle HTTP errors
                if httpResponse.statusCode != 200 {
                    try handleHTTPError(statusCode: httpResponse.statusCode, data: data, attempt: attempt, maxRetries: maxRetries)
                    continue
                }

                // Process SSE stream by splitting data into lines
                guard let responseString = String(data: data, encoding: .utf8) else {
                    throw AgentError.generationFailed(reason: "Invalid UTF-8 data")
                }

                let lines = responseString.components(separatedBy: .newlines)
                for line in lines {
                    try Task.checkCancellation()

                    guard line.hasPrefix("data: ") else { continue }
                    let jsonString = String(line.dropFirst(6))

                    if jsonString == "[DONE]" {
                        continuation.finish()
                        return
                    }

                    guard let jsonData = jsonString.data(using: .utf8) else { continue }

                    do {
                        let chunk = try decoder.decode(OpenRouterStreamChunk.self, from: jsonData)
                        if let content = chunk.choices?.first?.delta?.content {
                            continuation.yield(content)
                        }
                    } catch {
                        // Skip malformed chunks
                        continue
                    }
                }
                #else
                // Apple platforms: Use bytes(for:) with line iterator
                let (bytes, response) = try await session.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AgentError.generationFailed(reason: "Invalid response type")
                }

                // Update rate limit info
                rateLimitInfo = OpenRouterRateLimitInfo.parse(from: httpResponse.allHeaderFields)

                // Handle HTTP errors by collecting error data
                if httpResponse.statusCode != 200 {
                    var errorData = Data()
                    errorData.reserveCapacity(10000)  // Pre-allocate buffer to avoid reallocations
                    for try await byte in bytes {
                        errorData.append(byte)
                        if errorData.count >= 10000 { break }
                    }
                    try handleHTTPError(statusCode: httpResponse.statusCode, data: errorData, attempt: attempt, maxRetries: maxRetries)
                    continue
                }

                // Process SSE stream
                for try await line in bytes.lines {
                    try Task.checkCancellation()

                    guard line.hasPrefix("data: ") else { continue }
                    let jsonString = String(line.dropFirst(6))

                    if jsonString == "[DONE]" {
                        continuation.finish()
                        return
                    }

                    guard let jsonData = jsonString.data(using: String.Encoding.utf8) else { continue }

                    do {
                        let chunk = try decoder.decode(OpenRouterStreamChunk.self, from: jsonData)
                        if let content = chunk.choices?.first?.delta?.content {
                            continuation.yield(content)
                        }
                    } catch {
                        // Skip malformed chunks
                        continue
                    }
                }
                #endif

                continuation.finish()
                return

            } catch let error as AgentError {
                if attempt == maxRetries {
                    throw error
                }
                if case .rateLimitExceeded = error {
                    let delay = configuration.retryStrategy.delay(forAttempt: attempt + 1)
                    try await Task.sleep(for: .seconds(delay))
                    continue
                }
                throw error
            } catch is CancellationError {
                throw AgentError.cancelled
            } catch {
                if attempt == maxRetries {
                    throw AgentError.generationFailed(reason: error.localizedDescription)
                }
                let delay = configuration.retryStrategy.delay(forAttempt: attempt + 1)
                try await Task.sleep(for: .seconds(delay))
            }
        }

        throw AgentError.generationFailed(reason: "Max retries exceeded")
    }

    private func buildRequest(
        prompt: String,
        options: InferenceOptions,
        stream: Bool,
        tools: [ToolDefinition]? = nil
    ) throws -> URLRequest {
        let url = configuration.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        // OpenRouter-specific headers
        if let siteURL = configuration.siteURL {
            request.setValue(siteURL.absoluteString, forHTTPHeaderField: "HTTP-Referer")
        }
        if let appName = configuration.appName {
            request.setValue(appName, forHTTPHeaderField: "X-Title")
        }

        // Build messages array with typed OpenRouterMessage
        var messages: [OpenRouterMessage] = []
        if let systemPrompt = configuration.systemPrompt, !systemPrompt.isEmpty {
            messages.append(.system(systemPrompt))
        }
        messages.append(.user(prompt))

        // Build typed request
        let openRouterRequest = OpenRouterRequest(
            model: configuration.model.identifier,
            messages: messages,
            stream: stream,
            temperature: options.temperature,
            topP: options.topP,
            topK: options.topK ?? configuration.topK,
            frequencyPenalty: options.frequencyPenalty,
            presencePenalty: options.presencePenalty,
            maxTokens: options.maxTokens,
            stop: options.stopSequences.isEmpty ? nil : options.stopSequences,
            tools: tools?.toOpenRouterTools()
        )

        // Encode the typed request
        request.httpBody = try encoder.encode(openRouterRequest)
        return request
    }

    private func handleHTTPError(statusCode: Int, data: Data, attempt: Int, maxRetries: Int) throws {
        let errorMessage: String
        if let errorResponse = try? decoder.decode(OpenRouterErrorResponse.self, from: data) {
            errorMessage = errorResponse.error.message
        } else if let rawMessage = String(data: data, encoding: .utf8) {
            errorMessage = rawMessage
        } else {
            errorMessage = "Unknown error"
        }

        switch statusCode {
        case 401:
            throw AgentError.inferenceProviderUnavailable(reason: "Invalid API key")
        case 429:
            let retryAfter = configuration.retryStrategy.delay(forAttempt: attempt + 1)
            throw AgentError.rateLimitExceeded(retryAfter: retryAfter)
        case 400:
            throw AgentError.invalidInput(reason: errorMessage)
        case 404:
            throw AgentError.modelNotAvailable(model: configuration.model.identifier)
        default:
            // Use configured retryable status codes
            if configuration.retryStrategy.retryableStatusCodes.contains(statusCode) && attempt < maxRetries {
                return // Will retry
            }
            if statusCode >= 500 && statusCode < 600 {
                throw AgentError.inferenceProviderUnavailable(reason: "Server error: \(errorMessage)")
            }
            throw AgentError.generationFailed(reason: "HTTP \(statusCode): \(errorMessage)")
        }
    }

    private func mapFinishReason(_ reason: String?) -> InferenceResponse.FinishReason {
        switch reason {
        case "tool_calls": .toolCall
        case "length": .maxTokens
        case "content_filter": .contentFilter
        case "stop", nil: .completed
        default: .completed
        }
    }
}

// MARK: - CustomStringConvertible

extension OpenRouterProvider: CustomStringConvertible {
    public nonisolated var description: String {
        "OpenRouterProvider(model: \(modelDescription))"
    }
}
