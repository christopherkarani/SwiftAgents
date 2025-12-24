//
//  AnyAgent.swift
//  SwiftAgents
//
//  Created as part of audit remediation - Phase 4
//

import Foundation

/// Type-erased wrapper for any Agent.
///
/// Enables storing heterogeneous agents in collections while preserving
/// full Agent protocol functionality:
///
/// ```swift
/// let agents: [AnyAgent] = [
///     AnyAgent(reActAgent),
///     AnyAgent(planExecuteAgent),
///     AnyAgent(customAgent)
/// ]
///
/// for agent in agents {
///     let result = try await agent.run("What's the weather?")
///     print(result.output)
/// }
/// ```
///
/// AnyAgent uses the box-protocol pattern to achieve type erasure while
/// maintaining protocol conformance and Sendable safety.
public struct AnyAgent: Agent, Sendable {
    private let box: any AnyAgentBox

    /// Creates a type-erased wrapper around the given agent.
    /// - Parameter agent: The agent to wrap.
    public init<A: Agent>(_ agent: A) {
        self.box = AgentBox(agent)
    }

    // MARK: - Agent Protocol Properties

    /// The tools available to this agent.
    public nonisolated var tools: [any Tool] {
        box.tools
    }

    /// Instructions that define the agent's behavior and role.
    public nonisolated var instructions: String {
        box.instructions
    }

    /// Configuration settings for the agent.
    public nonisolated var configuration: AgentConfiguration {
        box.configuration
    }

    /// Optional memory system for context management.
    public nonisolated var memory: (any Memory)? {
        box.memory
    }

    /// Optional custom inference provider.
    public nonisolated var inferenceProvider: (any InferenceProvider)? {
        box.inferenceProvider
    }

    /// Optional tracer for observability.
    public nonisolated var tracer: (any Tracer)? {
        box.tracer
    }

    // MARK: - Agent Protocol Methods

    /// Executes the agent with the given input and returns a result.
    /// - Parameter input: The user's input/query.
    /// - Returns: The result of the agent's execution.
    /// - Throws: `AgentError` if execution fails.
    public func run(_ input: String) async throws -> AgentResult {
        try await box.run(input)
    }

    /// Streams the agent's execution, yielding events as they occur.
    /// - Parameter input: The user's input/query.
    /// - Returns: An async stream of agent events.
    public nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        box.stream(input)
    }

    /// Cancels any ongoing execution.
    public func cancel() async {
        await box.cancel()
    }
}

// MARK: - Private Box Protocol

/// Private protocol for type erasure implementation.
private protocol AnyAgentBox: Sendable {
    // Properties
    nonisolated var tools: [any Tool] { get }
    nonisolated var instructions: String { get }
    nonisolated var configuration: AgentConfiguration { get }
    nonisolated var memory: (any Memory)? { get }
    nonisolated var inferenceProvider: (any InferenceProvider)? { get }
    nonisolated var tracer: (any Tracer)? { get }

    // Methods
    func run(_ input: String) async throws -> AgentResult
    nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error>
    func cancel() async
}

// MARK: - Private Box Implementation

/// Private struct that wraps a concrete Agent implementation.
private struct AgentBox<A: Agent>: AnyAgentBox, Sendable {
    private let agent: A

    init(_ agent: A) {
        self.agent = agent
    }

    // MARK: - Properties

    nonisolated var tools: [any Tool] {
        agent.tools
    }

    nonisolated var instructions: String {
        agent.instructions
    }

    nonisolated var configuration: AgentConfiguration {
        agent.configuration
    }

    nonisolated var memory: (any Memory)? {
        agent.memory
    }

    nonisolated var inferenceProvider: (any InferenceProvider)? {
        agent.inferenceProvider
    }

    nonisolated var tracer: (any Tracer)? {
        agent.tracer
    }

    // MARK: - Methods

    func run(_ input: String) async throws -> AgentResult {
        try await agent.run(input)
    }

    nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        agent.stream(input)
    }

    func cancel() async {
        await agent.cancel()
    }
}
