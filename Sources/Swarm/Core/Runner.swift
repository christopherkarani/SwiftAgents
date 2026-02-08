// Runner.swift
// SwiftAgents Framework
//
// Static entry point for agent execution, separating agent definition from execution.

import Foundation

// MARK: - Runner

/// A static entry point for executing agents.
///
/// `Runner` provides an alternative API for agent execution that separates
/// the agent definition from execution concerns. This pattern is inspired by
/// the OpenAI Agent SDK's `Runner.run(agent, input)` approach.
///
/// The agent remains the source of truth for configuration, tools, and behavior.
/// `Runner` simply provides a convenient way to execute agents with optional
/// session and hooks overrides.
///
/// Example:
/// ```swift
/// let agent = Agent(name: "assistant", instructions: "You are helpful.")
///
/// // Simple execution:
/// let result = try await Runner.run(agent, input: "Hello!")
///
/// // With session:
/// let result = try await Runner.run(agent, input: "Hello!", session: mySession)
///
/// // Streaming:
/// for try await event in Runner.stream(agent, input: "What's the weather?") {
///     switch event {
///     case .outputToken(_, _, let token):
///         print(token, terminator: "")
///     default:
///         break
///     }
/// }
/// ```
public enum Runner {
    /// Executes an agent with the given input and returns a result.
    ///
    /// This is a convenience wrapper around `agent.run()` that provides
    /// a cleaner API for simple execution scenarios.
    ///
    /// - Parameters:
    ///   - agent: The agent to execute.
    ///   - input: The user's input/query.
    ///   - session: Optional session for conversation history management.
    ///   - hooks: Optional run hooks for observing agent execution events.
    /// - Returns: The result of the agent's execution.
    /// - Throws: `AgentError` if execution fails, or `GuardrailError` if guardrails trigger.
    @discardableResult
    public static func run(
        _ agent: any AgentRuntime,
        input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        try await agent.run(input, session: session, hooks: hooks)
    }

    /// Streams an agent's execution, yielding events as they occur.
    ///
    /// This is a convenience wrapper around `agent.stream()` that provides
    /// a cleaner API for streaming scenarios.
    ///
    /// - Parameters:
    ///   - agent: The agent to stream.
    ///   - input: The user's input/query.
    ///   - session: Optional session for conversation history management.
    ///   - hooks: Optional run hooks for observing agent execution events.
    /// - Returns: An async stream of agent events.
    public static func stream(
        _ agent: any AgentRuntime,
        input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        agent.stream(input, session: session, hooks: hooks)
    }

    /// Executes an agent and returns a detailed response with tracking ID.
    ///
    /// - Parameters:
    ///   - agent: The agent to execute.
    ///   - input: The user's input/query.
    ///   - session: Optional session for conversation history management.
    ///   - hooks: Optional run hooks for observing agent execution events.
    /// - Returns: An `AgentResponse` with unique ID and detailed metadata.
    /// - Throws: `AgentError` if execution fails, or `GuardrailError` if guardrails trigger.
    @discardableResult
    public static func runWithResponse(
        _ agent: any AgentRuntime,
        input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> AgentResponse {
        try await agent.runWithResponse(input, session: session, hooks: hooks)
    }
}
