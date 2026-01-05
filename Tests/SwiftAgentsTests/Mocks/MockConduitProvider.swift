// MockConduitProvider.swift
// SwiftAgentsTests
//
// Mock Conduit provider for testing without actual LLM backends.

import Foundation
@testable import SwiftAgents

// MARK: - MockConduitProvider

// No Conduit import needed - this mock only uses SwiftAgents types

/// A mock Conduit provider for testing agents without real LLM backends.
///
/// This mock simulates the behavior of ConduitProvider to enable comprehensive
/// agent testing without network calls or actual model inference.
///
/// Example:
/// ```swift
/// let mock = await MockConduitProvider()
/// await mock.setResponses([
///     "Thought: I need to search.\nAction: search(query: 'Swift')",
///     "Final Answer: Swift is a programming language."
/// ])
///
/// let agent = ReActAgent(tools: [SearchTool()], inferenceProvider: mock)
/// let result = try await agent.run("What is Swift?")
/// ```
public actor MockConduitProvider: InferenceProvider {
    // MARK: Public

    // MARK: - Configurable Behavior

    /// Responses to return in sequence. Each call to `generate` consumes one response.
    public var responses: [String] = []

    /// Error to throw on the next call. Set to nil to proceed normally.
    public var errorToThrow: Error?

    /// Delay to simulate network latency.
    public var responseDelay: Duration = .zero

    /// Default response when responses array is exhausted.
    public var defaultResponse = "Final Answer: Mock Conduit response"

    /// Simulated tool calls to return from generateWithToolCalls.
    public var mockToolCalls: [InferenceResponse.ParsedToolCall] = []

    /// Simulated finish reason for responses.
    public var mockFinishReason: InferenceResponse.FinishReason = .completed

    /// Simulated token usage for responses.
    public var mockUsage: InferenceResponse.TokenUsage?

    // MARK: - Call Recording

    /// Recorded generate calls for verification.
    public private(set) var generateCalls: [(prompt: String, options: InferenceOptions)] = []

    /// Recorded stream calls for verification.
    public private(set) var streamCalls: [(prompt: String, options: InferenceOptions)] = []

    /// Recorded tool call generations for verification.
    public private(set) var toolCallCalls: [(prompt: String, tools: [ToolDefinition], options: InferenceOptions)] = []

    /// Gets the number of generate calls made.
    public var generateCallCount: Int {
        generateCalls.count
    }

    /// Gets the last generate call, if any.
    public var lastGenerateCall: (prompt: String, options: InferenceOptions)? {
        generateCalls.last
    }

    /// Gets the number of stream calls made.
    public var streamCallCount: Int {
        streamCalls.count
    }

    /// Gets the number of tool call generations made.
    public var toolCallCount: Int {
        toolCallCalls.count
    }

    // MARK: - Initialization

    /// Creates a new mock Conduit provider.
    public init() {}

    /// Creates a mock with predefined responses.
    /// - Parameter responses: The responses to return in sequence.
    public init(responses: [String]) {
        self.responses = responses
    }

    // MARK: - Configuration Methods

    /// Sets the responses to return in sequence.
    public func setResponses(_ responses: [String]) {
        self.responses = responses
        responseIndex = 0
    }

    /// Sets an error to throw on the next call.
    public func setError(_ error: Error?) {
        errorToThrow = error
    }

    /// Sets the response delay to simulate network latency.
    public func setDelay(_ delay: Duration) {
        responseDelay = delay
    }

    /// Sets the mock tool calls to return.
    public func setMockToolCalls(_ toolCalls: [InferenceResponse.ParsedToolCall]) {
        mockToolCalls = toolCalls
    }

    /// Sets the mock finish reason.
    public func setFinishReason(_ reason: InferenceResponse.FinishReason) {
        mockFinishReason = reason
    }

    /// Sets the mock token usage.
    public func setUsage(_ usage: InferenceResponse.TokenUsage?) {
        mockUsage = usage
    }

    // MARK: - InferenceProvider Implementation

    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        generateCalls.append((prompt, options))

        if let error = errorToThrow {
            errorToThrow = nil // Clear after throwing once
            throw error
        }

        if responseDelay > .zero {
            try await Task.sleep(for: responseDelay)
        }

        if responseIndex < responses.count {
            let response = responses[responseIndex]
            responseIndex += 1
            return response
        }

        return defaultResponse
    }

    nonisolated public func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()

        Task { @Sendable [weak self] in
            guard let self else {
                continuation.finish()
                return
            }

            do {
                await recordStreamCall(prompt: prompt, options: options)

                if let error = await errorToThrow {
                    await clearError()
                    continuation.finish(throwing: error)
                    return
                }

                let response = try await generate(prompt: prompt, options: options)

                // Stream character by character to simulate real streaming
                for char in response {
                    continuation.yield(String(char))
                    try await Task.sleep(for: .milliseconds(1))
                }

                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }

        return stream
    }

    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolDefinition],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        toolCallCalls.append((prompt, tools, options))

        if let error = errorToThrow {
            errorToThrow = nil
            throw error
        }

        if responseDelay > .zero {
            try await Task.sleep(for: responseDelay)
        }

        let content: String?
        if responseIndex < responses.count {
            content = responses[responseIndex]
            responseIndex += 1
        } else {
            content = mockToolCalls.isEmpty ? defaultResponse : nil
        }

        return InferenceResponse(
            content: content,
            toolCalls: mockToolCalls,
            finishReason: mockFinishReason,
            usage: mockUsage
        )
    }

    // MARK: - Test Helpers

    /// Resets all recorded calls and response index.
    public func reset() {
        responseIndex = 0
        generateCalls = []
        streamCalls = []
        toolCallCalls = []
        errorToThrow = nil
        mockToolCalls = []
        mockFinishReason = .completed
        mockUsage = nil
    }

    /// Configures the mock for a simple ReAct sequence.
    /// - Parameters:
    ///   - toolCalls: Tool calls to simulate, with tool name and arguments.
    ///   - finalAnswer: The final answer to return.
    public func configureReActSequence(
        toolCalls: [(name: String, args: String)] = [],
        finalAnswer: String
    ) {
        responses = []

        for (name, args) in toolCalls {
            responses.append("Thought: I need to use the \(name) tool.\nAction: \(name)(\(args))")
        }

        responses.append("Final Answer: \(finalAnswer)")
        responseIndex = 0
    }

    /// Configures the mock to simulate rate limiting.
    /// - Parameters:
    ///   - afterCalls: Number of successful calls before rate limiting.
    ///   - retryAfter: Retry delay hint in seconds.
    public func configureRateLimiting(afterCalls: Int = 1, retryAfter: TimeInterval = 60) {
        // This would need more sophisticated state management
        // For now, users can manually set error after N calls
        if generateCallCount >= afterCalls {
            errorToThrow = AgentError.rateLimitExceeded(retryAfter: retryAfter)
        }
    }

    /// Configures the mock to return tool calls.
    /// - Parameter toolCalls: The tool calls to return.
    public func configureToolCalls(_ toolCalls: [InferenceResponse.ParsedToolCall]) {
        mockToolCalls = toolCalls
        mockFinishReason = .toolCall
    }

    /// Configures the mock to simulate context window exceeded.
    public func configureContextWindowExceeded() {
        errorToThrow = AgentError.contextWindowExceeded(
            tokenCount: 10000,
            limit: 8000
        )
    }

    /// Configures the mock to simulate authentication failure.
    public func configureAuthenticationFailure() {
        errorToThrow = AgentError.inferenceProviderUnavailable(
            reason: "Authentication failed: Invalid API key"
        )
    }

    /// Configures the mock to simulate network error.
    public func configureNetworkError() {
        let networkError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "Network connection lost"]
        )
        errorToThrow = AgentError.inferenceProviderUnavailable(
            reason: "Network error: \(networkError.localizedDescription)"
        )
    }

    /// Configures the mock to simulate streaming with delays.
    /// - Parameters:
    ///   - response: The response to stream.
    ///   - chunkDelay: Delay between chunks in milliseconds.
    public func configureStreamingWithDelay(response: String, chunkDelay: Int = 10) {
        responses = [response]
        responseDelay = .milliseconds(chunkDelay)
    }

    // MARK: Private

    /// Current index in the responses array.
    private var responseIndex = 0

    private func recordStreamCall(prompt: String, options: InferenceOptions) {
        streamCalls.append((prompt, options))
    }

    private func clearError() {
        errorToThrow = nil
    }
}

// MARK: - Convenience Extensions for Testing

public extension MockConduitProvider {
    /// Gets all prompts from generate calls.
    var allPrompts: [String] {
        generateCalls.map(\.prompt)
    }

    /// Gets all tool names from tool call generations.
    var allToolNames: [String] {
        toolCallCalls.flatMap { call in
            call.tools.map(\.name)
        }
    }

    /// Verifies that a generate call was made with the expected prompt.
    /// - Parameter prompt: The expected prompt (partial match).
    /// - Returns: True if a call with matching prompt was found.
    func verifyGenerateCalled(withPrompt prompt: String) -> Bool {
        generateCalls.contains { $0.prompt.contains(prompt) }
    }

    /// Verifies that a tool call generation was made with the expected tool.
    /// - Parameter toolName: The expected tool name.
    /// - Returns: True if a call with the tool was found.
    func verifyToolCallCalled(withTool toolName: String) -> Bool {
        toolCallCalls.contains { call in
            call.tools.contains { $0.name == toolName }
        }
    }
}
