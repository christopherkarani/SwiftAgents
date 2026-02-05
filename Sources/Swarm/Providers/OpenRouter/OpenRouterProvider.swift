// OpenRouterProvider.swift
// Swarm Framework
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
public actor OpenRouterProvider: InferenceProvider, InferenceStreamingProvider {
    // MARK: Public

    // MARK: - Initialization

    /// Creates an OpenRouter provider with the given configuration.
    /// - Parameter configuration: The provider configuration.
    public init(configuration: OpenRouterConfiguration) {
        self.configuration = configuration
        modelDescription = configuration.model.identifier

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout.timeInterval
        sessionConfig.timeoutIntervalForResource = configuration.timeout.timeInterval * 2
        session = URLSession(configuration: sessionConfig)

        encoder = JSONEncoder()
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
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
                let chatResponse: OpenRouterResponse
                do {
                    chatResponse = try decoder.decode(OpenRouterResponse.self, from: data)
                } catch {
                    // Log the raw response for debugging
                    let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode response as UTF-8"
                    throw AgentError.generationFailed(reason: "Failed to decode response: \(error.localizedDescription). Raw response: \(rawResponse.prefix(500))")
                }

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
    nonisolated public func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error> {
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

    /// Streams a response with tool-call deltas for the given prompt.
    /// - Parameters:
    ///   - prompt: The input prompt.
    ///   - tools: Available tool schemas.
    ///   - options: Generation options.
    /// - Returns: An async stream of inference events.
    nonisolated public func streamWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) -> AsyncThrowingStream<InferenceStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.performToolCallStream(
                        prompt: prompt,
                        tools: tools,
                        options: options,
                        continuation: continuation
                    )
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
    ///   - tools: Available tool schemas.
    ///   - options: Generation options.
    /// - Returns: The inference response which may include tool calls.
    /// - Throws: `AgentError` if generation fails.
    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
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
                if let responseUsage = chatResponse.usage,
                   let promptTokens = responseUsage.promptTokens,
                   let completionTokens = responseUsage.completionTokens {
                    usage = InferenceResponse.TokenUsage(
                        inputTokens: promptTokens,
                        outputTokens: completionTokens
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

    // MARK: Private

    private let configuration: OpenRouterConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var rateLimitInfo: OpenRouterRateLimitInfo?

    /// Cached model description for nonisolated access.
    private let modelDescription: String

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
                let completed = try await executeStreamRequest(request: request, attempt: attempt, maxRetries: maxRetries, continuation: continuation)
                if completed {
                    return
                }
                // If not completed, continue to retry
            } catch let error as AgentError {
                try handleStreamError(error: error, attempt: attempt, maxRetries: maxRetries)
            } catch is CancellationError {
                throw AgentError.cancelled
            } catch {
                try await handleGenericStreamError(error: error, attempt: attempt, maxRetries: maxRetries)
            }
        }

        throw AgentError.generationFailed(reason: "Max retries exceeded")
    }

    private func performToolCallStream(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions,
        continuation: AsyncThrowingStream<InferenceStreamEvent, Error>.Continuation
    ) async throws {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput(reason: "Prompt cannot be empty")
        }

        let request = try buildRequest(prompt: prompt, options: options, stream: true, tools: tools)
        let maxRetries = configuration.retryStrategy.maxRetries

        for attempt in 0..<(maxRetries + 1) {
            try Task.checkCancellation()

            do {
                let completed = try await executeToolCallStreamRequest(
                    request: request,
                    attempt: attempt,
                    maxRetries: maxRetries,
                    continuation: continuation
                )
                if completed {
                    return
                }
            } catch let error as AgentError {
                try handleStreamError(error: error, attempt: attempt, maxRetries: maxRetries)
            } catch is CancellationError {
                throw AgentError.cancelled
            } catch {
                try await handleGenericStreamError(error: error, attempt: attempt, maxRetries: maxRetries)
            }
        }

        throw AgentError.generationFailed(reason: "Max retries exceeded")
    }

    /// Executes a single stream request attempt.
    /// - Returns: `true` if the stream completed successfully, `false` if a retry is needed.
    private func executeStreamRequest(
        request: URLRequest,
        attempt: Int,
        maxRetries: Int,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws -> Bool {
        #if canImport(FoundationNetworking)
            return try await executeLinuxStreamRequest(request: request, attempt: attempt, maxRetries: maxRetries, continuation: continuation)
        #else
            return try await executeAppleStreamRequest(request: request, attempt: attempt, maxRetries: maxRetries, continuation: continuation)
        #endif
    }

    private func executeToolCallStreamRequest(
        request: URLRequest,
        attempt: Int,
        maxRetries: Int,
        continuation: AsyncThrowingStream<InferenceStreamEvent, Error>.Continuation
    ) async throws -> Bool {
        #if canImport(FoundationNetworking)
            return try await executeLinuxToolCallStreamRequest(
                request: request,
                attempt: attempt,
                maxRetries: maxRetries,
                continuation: continuation
            )
        #else
            return try await executeAppleToolCallStreamRequest(
                request: request,
                attempt: attempt,
                maxRetries: maxRetries,
                continuation: continuation
            )
        #endif
    }

    #if canImport(FoundationNetworking)
        /// Linux-specific stream execution using data(for:) and manual line splitting.
        private func executeLinuxStreamRequest(
            request: URLRequest,
            attempt: Int,
            maxRetries: Int,
            continuation: AsyncThrowingStream<String, Error>.Continuation
        ) async throws -> Bool {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AgentError.generationFailed(reason: "Invalid response type")
            }

            rateLimitInfo = OpenRouterRateLimitInfo.parse(from: httpResponse.allHeaderFields)

            if httpResponse.statusCode != 200 {
                try handleHTTPError(statusCode: httpResponse.statusCode, data: data, attempt: attempt, maxRetries: maxRetries)
                return false // Retry needed
            }

            guard let responseString = String(data: data, encoding: .utf8) else {
                throw AgentError.generationFailed(reason: "Invalid UTF-8 data")
            }

            try processSSELines(responseString.components(separatedBy: .newlines), continuation: continuation)
            return true
        }

        /// Linux-specific tool-call stream execution using data(for:) and manual line splitting.
        private func executeLinuxToolCallStreamRequest(
            request: URLRequest,
            attempt: Int,
            maxRetries: Int,
            continuation: AsyncThrowingStream<InferenceStreamEvent, Error>.Continuation
        ) async throws -> Bool {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AgentError.generationFailed(reason: "Invalid response type")
            }

            rateLimitInfo = OpenRouterRateLimitInfo.parse(from: httpResponse.allHeaderFields)

            if httpResponse.statusCode != 200 {
                try handleHTTPError(statusCode: httpResponse.statusCode, data: data, attempt: attempt, maxRetries: maxRetries)
                return false // Retry needed
            }

            guard let responseString = String(data: data, encoding: .utf8) else {
                throw AgentError.generationFailed(reason: "Invalid UTF-8 data")
            }

            let parser = OpenRouterStreamParser()
            try processToolCallSSELines(
                responseString.components(separatedBy: .newlines),
                parser: parser,
                continuation: continuation
            )
            return true
        }
    #else
        /// Apple platforms stream execution using bytes(for:) with async line iterator.
        private func executeAppleStreamRequest(
            request: URLRequest,
            attempt: Int,
            maxRetries: Int,
            continuation: AsyncThrowingStream<String, Error>.Continuation
        ) async throws -> Bool {
            let (bytes, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AgentError.generationFailed(reason: "Invalid response type")
            }

            rateLimitInfo = OpenRouterRateLimitInfo.parse(from: httpResponse.allHeaderFields)

            if httpResponse.statusCode != 200 {
                let errorData = try await collectErrorData(from: bytes)
                try handleHTTPError(statusCode: httpResponse.statusCode, data: errorData, attempt: attempt, maxRetries: maxRetries)
                return false // Retry needed
            }

            try await processAsyncSSEStream(bytes: bytes, continuation: continuation)
            return true
        }

        /// Apple platforms tool-call stream execution using bytes(for:) with async line iterator.
        private func executeAppleToolCallStreamRequest(
            request: URLRequest,
            attempt: Int,
            maxRetries: Int,
            continuation: AsyncThrowingStream<InferenceStreamEvent, Error>.Continuation
        ) async throws -> Bool {
            let (bytes, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AgentError.generationFailed(reason: "Invalid response type")
            }

            rateLimitInfo = OpenRouterRateLimitInfo.parse(from: httpResponse.allHeaderFields)

            if httpResponse.statusCode != 200 {
                let errorData = try await collectErrorData(from: bytes)
                try handleHTTPError(statusCode: httpResponse.statusCode, data: errorData, attempt: attempt, maxRetries: maxRetries)
                return false // Retry needed
            }

            let parser = OpenRouterStreamParser()
            try await processAsyncToolCallSSEStream(
                bytes: bytes,
                parser: parser,
                continuation: continuation
            )
            return true
        }

        /// Collects error data from an async byte stream.
        private func collectErrorData(from bytes: URLSession.AsyncBytes) async throws -> Data {
            var errorData = Data()
            errorData.reserveCapacity(10000)
            for try await byte in bytes {
                errorData.append(byte)
                if errorData.count >= 10000 { break }
            }
            return errorData
        }

        /// Processes an async SSE stream from Apple platforms.
        private func processAsyncSSEStream(
            bytes: URLSession.AsyncBytes,
            continuation: AsyncThrowingStream<String, Error>.Continuation
        ) async throws {
            for try await line in bytes.lines {
                try Task.checkCancellation()
                if try processSSELine(line, continuation: continuation) {
                    return
                }
            }
            continuation.finish()
        }

        /// Processes an async SSE tool-call stream from Apple platforms.
        private func processAsyncToolCallSSEStream(
            bytes: URLSession.AsyncBytes,
            parser: OpenRouterStreamParser,
            continuation: AsyncThrowingStream<InferenceStreamEvent, Error>.Continuation
        ) async throws {
            for try await line in bytes.lines {
                try Task.checkCancellation()
                if try processToolCallSSELine(line, parser: parser, continuation: continuation) {
                    return
                }
            }
            continuation.finish()
        }
    #endif

    /// Processes an array of SSE lines (Linux path).
    private func processSSELines(
        _ lines: [String],
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) throws {
        for line in lines {
            try Task.checkCancellation()
            if try processSSELine(line, continuation: continuation) {
                return
            }
        }
        continuation.finish()
    }

    /// Processes an array of SSE lines for tool-call streaming (Linux path).
    private func processToolCallSSELines(
        _ lines: [String],
        parser: OpenRouterStreamParser,
        continuation: AsyncThrowingStream<InferenceStreamEvent, Error>.Continuation
    ) throws {
        for line in lines {
            try Task.checkCancellation()
            if try processToolCallSSELine(line, parser: parser, continuation: continuation) {
                return
            }
        }
        continuation.finish()
    }

    /// Processes a single SSE line and yields content to continuation.
    /// - Returns: `true` if stream is done, `false` to continue processing.
    private func processSSELine(
        _ line: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) throws -> Bool {
        guard line.hasPrefix("data: ") else { return false }
        let jsonString = String(line.dropFirst(6))

        if jsonString == "[DONE]" {
            continuation.finish()
            return true
        }

        guard let jsonData = jsonString.data(using: .utf8) else { return false }

        do {
            let chunk = try decoder.decode(OpenRouterStreamChunk.self, from: jsonData)
            if let content = chunk.choices?.first?.delta?.content {
                continuation.yield(content)
            }
        } catch {
            // Skip malformed chunks
        }
        return false
    }

    /// Processes a single SSE line and yields tool-call stream events.
    /// - Returns: `true` if stream is done, `false` to continue processing.
    private func processToolCallSSELine(
        _ line: String,
        parser: OpenRouterStreamParser,
        continuation: AsyncThrowingStream<InferenceStreamEvent, Error>.Continuation
    ) throws -> Bool {
        guard let events = parser.parse(line: line) else {
            return false
        }

        for event in events {
            switch event {
            case let .textDelta(text):
                continuation.yield(.textDelta(text))
            case let .toolCallDelta(index, id, name, arguments):
                continuation.yield(.toolCallDelta(index: index, id: id, name: name, arguments: arguments))
            case let .finishReason(reason):
                continuation.yield(.finishReason(reason))
            case let .usage(prompt, completion):
                continuation.yield(.usage(promptTokens: prompt, completionTokens: completion))
            case .done:
                continuation.yield(.done)
                continuation.finish()
                return true
            case let .error(providerError):
                throw providerError.toAgentError()
            }
        }

        return false
    }

    /// Handles AgentError during streaming with retry logic.
    private func handleStreamError(error: AgentError, attempt: Int, maxRetries: Int) throws {
        if attempt == maxRetries {
            throw error
        }
        if case .rateLimitExceeded = error {
            // Let the caller handle retry delay
            return
        }
        throw error
    }

    /// Handles generic errors during streaming with retry delay.
    private func handleGenericStreamError(error: Error, attempt: Int, maxRetries: Int) async throws {
        if attempt == maxRetries {
            throw AgentError.generationFailed(reason: error.localizedDescription)
        }
        let delay = configuration.retryStrategy.delay(forAttempt: attempt + 1)
        try await Task.sleep(for: .seconds(delay))
    }

    private func buildRequest(
        prompt: String,
        options: InferenceOptions,
        stream: Bool,
        tools: [ToolSchema]? = nil
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

        let openRouterToolChoice: OpenRouterToolChoice? = if let tools,
                                                             !tools.isEmpty,
                                                             let choice = options.toolChoice {
            OpenRouterToolChoice(from: choice)
        } else {
            nil
        }

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
            tools: tools?.toOpenRouterTools(),
            toolChoice: openRouterToolChoice
        )

        // Encode the typed request
        request.httpBody = try encoder.encode(openRouterRequest)
        return request
    }

    private func handleHTTPError(statusCode: Int, data: Data, attempt: Int, maxRetries: Int) throws {
        let errorMessage: String = if let errorResponse = try? decoder.decode(OpenRouterErrorResponse.self, from: data) {
            errorResponse.error.message
        } else if let rawMessage = String(data: data, encoding: .utf8) {
            rawMessage
        } else {
            "Unknown error"
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
            if configuration.retryStrategy.retryableStatusCodes.contains(statusCode), attempt < maxRetries {
                return // Will retry
            }
            if statusCode >= 500, statusCode < 600 {
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
        case nil,
             "stop": .completed
        default: .completed
        }
    }
}

// MARK: CustomStringConvertible

extension OpenRouterProvider: CustomStringConvertible {
    nonisolated public var description: String {
        "OpenRouterProvider(model: \(modelDescription))"
    }
}

// MARK: - ToolChoice Mapping

private extension OpenRouterToolChoice {
    init(from toolChoice: ToolChoice) {
        switch toolChoice {
        case .auto:
            self = .auto
        case .none:
            self = .none
        case .required:
            self = .required
        case let .specific(toolName):
            self = .function(name: toolName)
        }
    }
}
