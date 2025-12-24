// AgentConfiguration.swift
// SwiftAgents Framework
//
// Runtime configuration settings for agent execution.

import Foundation

// MARK: - AgentConfiguration

/// Configuration settings for agent execution.
///
/// Use this struct to customize agent behavior including iteration limits,
/// timeouts, model parameters, and execution options.
///
/// Example:
/// ```swift
/// let config = AgentConfiguration.default
///     .maxIterations(15)
///     .temperature(0.8)
///     .timeout(.seconds(120))
/// ```
@Builder
public struct AgentConfiguration: Sendable, Equatable {
    // MARK: - Default Configuration

    /// Default configuration with sensible defaults.
    public static let `default` = AgentConfiguration()

    // MARK: - Iteration Limits

    /// Maximum number of reasoning iterations before stopping.
    /// Default: 10
    public var maxIterations: Int

    /// Maximum time allowed for the entire execution.
    /// Default: 60 seconds
    public var timeout: Duration

    // MARK: - Model Settings

    /// Temperature for model generation (0.0 = deterministic, 2.0 = creative).
    /// Default: 1.0
    public var temperature: Double

    /// Maximum tokens to generate per response.
    /// Default: nil (model default)
    public var maxTokens: Int?

    /// Sequences that will stop generation when encountered.
    /// Default: empty
    public var stopSequences: [String]

    // MARK: - Behavior Settings

    /// Whether to stream responses.
    /// Default: true
    public var enableStreaming: Bool

    /// Whether to include tool call details in the result.
    /// Default: true
    public var includeToolCallDetails: Bool

    /// Whether to stop after the first tool error.
    /// Default: false
    public var stopOnToolError: Bool

    /// Whether to include the agent's reasoning in events.
    /// Default: true
    public var includeReasoning: Bool

    // MARK: - Initialization

    /// Creates a new agent configuration.
    /// - Parameters:
    ///   - maxIterations: Maximum reasoning iterations. Default: 10
    ///   - timeout: Maximum execution time. Default: 60 seconds
    ///   - temperature: Model temperature (0.0-2.0). Default: 1.0
    ///   - maxTokens: Maximum tokens per response. Default: nil
    ///   - stopSequences: Generation stop sequences. Default: []
    ///   - enableStreaming: Enable response streaming. Default: true
    ///   - includeToolCallDetails: Include tool details in results. Default: true
    ///   - stopOnToolError: Stop on first tool error. Default: false
    ///   - includeReasoning: Include reasoning in events. Default: true
    public init(
        maxIterations: Int = 10,
        timeout: Duration = .seconds(60),
        temperature: Double = 1.0,
        maxTokens: Int? = nil,
        stopSequences: [String] = [],
        enableStreaming: Bool = true,
        includeToolCallDetails: Bool = true,
        stopOnToolError: Bool = false,
        includeReasoning: Bool = true
    ) {
        self.maxIterations = maxIterations
        self.timeout = timeout
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stopSequences = stopSequences
        self.enableStreaming = enableStreaming
        self.includeToolCallDetails = includeToolCallDetails
        self.stopOnToolError = stopOnToolError
        self.includeReasoning = includeReasoning
    }

}

// MARK: CustomStringConvertible

extension AgentConfiguration: CustomStringConvertible {
    public var description: String {
        """
        AgentConfiguration(
            maxIterations: \(maxIterations),
            timeout: \(timeout),
            temperature: \(temperature),
            maxTokens: \(maxTokens.map(String.init) ?? "nil"),
            stopSequences: \(stopSequences),
            enableStreaming: \(enableStreaming),
            includeToolCallDetails: \(includeToolCallDetails),
            stopOnToolError: \(stopOnToolError),
            includeReasoning: \(includeReasoning)
        )
        """
    }
}
