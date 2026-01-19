// MockInferenceProvider.swift
// SwiftAgentsTests
//
// Mock inference provider for testing agents without Foundation Models.

import Foundation
@testable import SwiftAgents

/// A mock inference provider for testing agents without Foundation Models.
///
/// Configure responses and verify calls for comprehensive agent testing.
///
/// Example:
/// ```swift
/// let mock = await MockInferenceProvider()
/// await mock.setResponses([
///     "Thought: I need to calculate.\nAction: calculator(expression: 2+2)",
///     "Final Answer: The result is 4"
/// ])
///
/// let agent = ReActAgent(tools: [CalculatorTool()], inferenceProvider: mock)
/// let result = try await agent.run("What is 2+2?")
/// ```
public actor MockInferenceProvider: InferenceProvider {
    // MARK: Public

    // MARK: - Configurable Behavior

    /// Responses to return in sequence. Each call to `generate` consumes one response.
    public var responses: [String] = []

    /// Structured responses to return for `generateWithToolCalls`.
    ///
    /// When set, calls to `generateWithToolCalls` will return these responses in order.
    /// If exhausted, the mock falls back to using `responses` (text-only).
    public var toolCallResponses: [InferenceResponse] = []

    /// Error to throw on the next call. Set to nil to proceed normally.
    public var errorToThrow: Error?

    /// Delay to simulate network latency.
    public var responseDelay: Duration = .zero

    /// Default response when responses array is exhausted.
    public var defaultResponse = "Final Answer: Mock response"

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

    // MARK: - Initialization

    /// Creates a new mock inference provider.
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

    /// Sets structured responses to return from `generateWithToolCalls`.
    public func setToolCallResponses(_ responses: [InferenceResponse]) {
        toolCallResponses = responses
        toolCallResponseIndex = 0
    }

    /// Sets an error to throw on the next call.
    public func setError(_ error: Error?) {
        errorToThrow = error
    }

    /// Sets the response delay.
    public func setDelay(_ delay: Duration) {
        responseDelay = delay
    }

    // MARK: - InferenceProvider Implementation

    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        generateCalls.append((prompt, options))

        if let error = errorToThrow {
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
                let response = try await generate(prompt: prompt, options: options)
                // Stream character by character
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
            throw error
        }

        if responseDelay > .zero {
            try await Task.sleep(for: responseDelay)
        }

        if toolCallResponseIndex < toolCallResponses.count {
            let response = toolCallResponses[toolCallResponseIndex]
            toolCallResponseIndex += 1
            return response
        }

        // Fall back to text generation when no structured responses are configured.
        let content = try await generate(prompt: prompt, options: options)
        return InferenceResponse(content: content, finishReason: .completed)
    }

    // MARK: - Test Helpers

    /// Resets all recorded calls and response index.
    public func reset() {
        responseIndex = 0
        toolCallResponseIndex = 0
        generateCalls = []
        streamCalls = []
        toolCallCalls = []
        toolCallResponses = []
        errorToThrow = nil
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

    /// Configures the mock to always think (never finish).
    /// - Parameter thoughts: The thoughts to cycle through.
    public func configureInfiniteThinking(thoughts: [String] = ["Still thinking..."]) {
        responses = thoughts.map { "Thought: \($0)" }
        defaultResponse = "Thought: \(thoughts.first ?? "thinking...")"
        responseIndex = 0
    }

    // MARK: Private

    /// Current index in the responses array.
    private var responseIndex = 0

    /// Current index in the tool call responses array.
    private var toolCallResponseIndex = 0

    private func recordStreamCall(prompt: String, options: InferenceOptions) {
        streamCalls.append((prompt, options))
    }
}
