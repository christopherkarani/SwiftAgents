// AgentResult.swift
// Swarm Framework
//
// Result type for agent execution.

import Foundation

// MARK: - AgentResult

/// The result of an agent execution.
///
/// AgentResult captures all information about a completed agent run,
/// including the output, tool calls made, timing, and optional metadata.
///
/// Example:
/// ```swift
/// let result = try await agent.run("Calculate 2+2")
/// print(result.output)              // "4"
/// print(result.iterationCount)      // 2
/// print(result.toolCalls.count)     // 1
/// print(result.duration)            // 1.234 seconds
/// ```
public struct AgentResult: Sendable, Equatable {
    /// The final output text from the agent.
    public let output: String

    /// All tool calls made during execution.
    public let toolCalls: [ToolCall]

    /// Results of all tool executions.
    public let toolResults: [ToolResult]

    /// The number of iterations performed.
    public let iterationCount: Int

    /// Total duration of the execution.
    public let duration: Duration

    /// Token usage statistics, if available.
    public let tokenUsage: TokenUsage?

    /// Metadata about the execution.
    public let metadata: [String: SendableValue]

    /// Creates a new agent result.
    /// - Parameters:
    ///   - output: The final output text.
    ///   - toolCalls: Tool calls made. Default: []
    ///   - toolResults: Tool execution results. Default: []
    ///   - iterationCount: Number of iterations. Default: 1
    ///   - duration: Execution duration. Default: .zero
    ///   - tokenUsage: Token usage stats. Default: nil
    ///   - metadata: Additional metadata. Default: [:]
    public init(
        output: String,
        toolCalls: [ToolCall] = [],
        toolResults: [ToolResult] = [],
        iterationCount: Int = 1,
        duration: Duration = .zero,
        tokenUsage: TokenUsage? = nil,
        metadata: [String: SendableValue] = [:]
    ) {
        self.output = output
        self.toolCalls = toolCalls
        self.toolResults = toolResults
        self.iterationCount = iterationCount
        self.duration = duration
        self.tokenUsage = tokenUsage
        self.metadata = metadata
    }
}

// MARK: - TokenUsage

/// Token usage statistics for a generation.
///
/// Tracks input and output token counts for monitoring
/// and cost estimation purposes.
public struct TokenUsage: Sendable, Equatable, Codable {
    /// Number of tokens in the input/prompt.
    public let inputTokens: Int

    /// Number of tokens in the output/response.
    public let outputTokens: Int

    /// Total tokens used (input + output).
    public var totalTokens: Int {
        inputTokens + outputTokens
    }

    /// Creates token usage statistics.
    /// - Parameters:
    ///   - inputTokens: Input token count.
    ///   - outputTokens: Output token count.
    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

// MARK: - AgentResult.Builder

public extension AgentResult {
    /// Builder for constructing AgentResult incrementally during execution.
    ///
    /// Use this builder to accumulate results as an agent runs, then
    /// call `build()` to create the final result.
    ///
    /// Example:
    /// ```swift
    /// let builder = AgentResult.Builder()
    /// _ = builder.start()
    /// _ = builder.addToolCall(call)
    /// _ = builder.setOutput("Final answer")
    /// let result = builder.build()
    /// ```
    final class Builder: @unchecked Sendable {
        // MARK: Public

        /// Creates a new result builder.
        public init() {}

        /// Sets the output text.
        /// - Parameter value: The output text.
        /// - Returns: Self for chaining.
        @discardableResult
        public func setOutput(_ value: String) -> Builder {
            lock.lock()
            defer { lock.unlock() }
            output = value
            return self
        }

        /// Appends to the output text.
        /// - Parameter value: Text to append.
        /// - Returns: Self for chaining.
        @discardableResult
        public func appendOutput(_ value: String) -> Builder {
            lock.lock()
            defer { lock.unlock() }
            output += value
            return self
        }

        /// Adds a tool call.
        /// - Parameter call: The tool call.
        /// - Returns: Self for chaining.
        @discardableResult
        public func addToolCall(_ call: ToolCall) -> Builder {
            lock.lock()
            defer { lock.unlock() }
            toolCalls.append(call)
            return self
        }

        /// Adds a tool result.
        /// - Parameter result: The tool result.
        /// - Returns: Self for chaining.
        @discardableResult
        public func addToolResult(_ result: ToolResult) -> Builder {
            lock.lock()
            defer { lock.unlock() }
            toolResults.append(result)
            return self
        }

        /// Increments the iteration count.
        /// - Returns: Self for chaining.
        @discardableResult
        public func incrementIteration() -> Builder {
            lock.lock()
            defer { lock.unlock() }
            iterationCount += 1
            return self
        }

        /// Marks the start time.
        /// - Returns: Self for chaining.
        @discardableResult
        public func start() -> Builder {
            lock.lock()
            defer { lock.unlock() }
            startTime = ContinuousClock.now
            return self
        }

        /// Sets the token usage.
        /// - Parameter usage: Token usage stats.
        /// - Returns: Self for chaining.
        @discardableResult
        public func setTokenUsage(_ usage: TokenUsage) -> Builder {
            lock.lock()
            defer { lock.unlock() }
            tokenUsage = usage
            return self
        }

        /// Sets a metadata value.
        /// - Parameters:
        ///   - key: The metadata key.
        ///   - value: The metadata value.
        /// - Returns: Self for chaining.
        @discardableResult
        public func setMetadata(_ key: String, _ value: SendableValue) -> Builder {
            lock.lock()
            defer { lock.unlock() }
            metadata[key] = value
            return self
        }

        /// Gets the current output.
        public func getOutput() -> String {
            lock.lock()
            defer { lock.unlock() }
            return output
        }

        /// Gets the current iteration count.
        public func getIterationCount() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return iterationCount
        }

        /// Builds the final AgentResult.
        /// - Returns: The completed result.
        public func build() -> AgentResult {
            lock.lock()
            defer { lock.unlock() }

            let duration: Duration = if let start = startTime {
                ContinuousClock.now - start
            } else {
                .zero
            }

            return AgentResult(
                output: output,
                toolCalls: toolCalls,
                toolResults: toolResults,
                iterationCount: iterationCount,
                duration: duration,
                tokenUsage: tokenUsage,
                metadata: metadata
            )
        }

        // MARK: Private

        private var output: String = ""
        private var toolCalls: [ToolCall] = []
        private var toolResults: [ToolResult] = []
        private var iterationCount: Int = 0
        private var startTime: ContinuousClock.Instant?
        private var tokenUsage: TokenUsage?
        private var metadata: [String: SendableValue] = [:]
        private let lock = NSLock()
    }
}

// MARK: - AgentResult + CustomStringConvertible

extension AgentResult: CustomStringConvertible {
    public var description: String {
        """
        AgentResult(
            output: "\(output.prefix(100))\(output.count > 100 ? "..." : "")",
            toolCalls: \(toolCalls.count),
            iterations: \(iterationCount),
            duration: \(duration)
        )
        """
    }
}

// MARK: - TokenUsage + CustomStringConvertible

extension TokenUsage: CustomStringConvertible {
    public var description: String {
        "TokenUsage(input: \(inputTokens), output: \(outputTokens), total: \(totalTokens))"
    }
}
