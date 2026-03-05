// CallableAgent.swift
// Swarm Framework
//
// @dynamicCallable wrapper enabling callable syntax on any agent.

import Foundation

/// A wrapper that enables direct callable syntax on any agent.
///
/// `CallableAgent` uses Swift's `@dynamicCallable` attribute to allow
/// invoking an agent as if it were a function, with either positional
/// or keyword arguments.
///
/// Example:
/// ```swift
/// let callable = CallableAgent(myAgent)
/// let result = try await callable("What is 2+2?")
/// let result2 = try await callable(topic: "weather", location: "NYC")
/// ```
@dynamicCallable
public struct CallableAgent: Sendable {
    private let agent: any AgentRuntime

    /// Creates a callable wrapper around an agent.
    /// - Parameter agent: The agent to wrap.
    public init(_ agent: any AgentRuntime) {
        self.agent = agent
    }

    /// Calls the agent with positional string arguments joined by spaces.
    /// - Parameter args: Positional arguments to join as input.
    /// - Returns: The agent's execution result.
    public func dynamicallyCall(withArguments args: [String]) async throws -> AgentResult {
        let input = args.joined(separator: " ")
        return try await agent.run(input, session: nil, observer: nil)
    }

    /// Calls the agent with keyword arguments formatted as "key: value" lines.
    /// - Parameter args: Keyword arguments to format as input.
    /// - Returns: The agent's execution result.
    public func dynamicallyCall(
        withKeywordArguments args: KeyValuePairs<String, String>
    ) async throws -> AgentResult {
        let input = args.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        return try await agent.run(input, session: nil, observer: nil)
    }
}

// MARK: - AgentRuntime + callAsFunction

public extension AgentRuntime {
    /// Enables calling any agent directly as a function.
    ///
    /// Example:
    /// ```swift
    /// let result = try await myAgent("What is 2+2?")
    /// ```
    func callAsFunction(_ input: String) async throws -> AgentResult {
        try await run(input, session: nil, observer: nil)
    }
}
