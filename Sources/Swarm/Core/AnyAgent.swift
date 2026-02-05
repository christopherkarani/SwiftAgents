// AnyAgent.swift
// Swarm Framework
//
// Type-erased wrapper for heterogeneous agent collections.

import Foundation

// MARK: - AnyAgent

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
public struct AnyAgent: AgentRuntime, @unchecked Sendable {
    // MARK: Public

    // MARK: - Agent Protocol Properties

    /// The tools available to this agent.
    nonisolated public var tools: [any AnyJSONTool] {
        box.tools
    }

    /// Instructions that define the agent's behavior and role.
    nonisolated public var instructions: String {
        box.instructions
    }

    /// Configuration settings for the agent.
    nonisolated public var configuration: AgentConfiguration {
        box.configuration
    }

    /// Optional memory system for context management.
    nonisolated public var memory: (any Memory)? {
        box.memory
    }

    /// Optional custom inference provider.
    nonisolated public var inferenceProvider: (any InferenceProvider)? {
        box.inferenceProvider
    }

    /// Optional tracer for observability.
    nonisolated public var tracer: (any Tracer)? {
        box.tracer
    }

    /// Input guardrails that validate user input before processing.
    nonisolated public var inputGuardrails: [any InputGuardrail] {
        box.inputGuardrails
    }

    /// Output guardrails that validate agent responses before returning.
    nonisolated public var outputGuardrails: [any OutputGuardrail] {
        box.outputGuardrails
    }

    /// Configured handoffs for this agent.
    nonisolated public var handoffs: [AnyHandoffConfiguration] {
        box.handoffs
    }

    /// Creates a type-erased wrapper around the given agent.
    /// - Parameter agent: The agent to wrap.
    public init(_ agent: some AgentRuntime) {
        box = AgentBox(agent)
    }

    // MARK: - Agent Protocol Methods

    /// Executes the agent with the given input and returns a result.
    /// - Parameters:
    ///   - input: The user's input/query.
    ///   - session: Optional session for context persistence.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: The result of the agent's execution.
    /// - Throws: `AgentError` if execution fails.
    public func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) async throws -> AgentResult {
        try await box.run(input, session: session, hooks: hooks)
    }

    /// Streams the agent's execution, yielding events as they occur.
    /// - Parameters:
    ///   - input: The user's input/query.
    ///   - session: Optional session for context persistence.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: An async stream of agent events.
    nonisolated public func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        box.stream(input, session: session, hooks: hooks)
    }

    /// Cancels any ongoing execution.
    public func cancel() async {
        await box.cancel()
    }

    // MARK: Private

    private let box: any AnyAgentBox
}

// MARK: - AnyAgentBox

/// Private protocol for type erasure implementation.
private protocol AnyAgentBox: Sendable {
    // Properties
    var tools: [any AnyJSONTool] { get }
    var instructions: String { get }
    var configuration: AgentConfiguration { get }
    var memory: (any Memory)? { get }
    var inferenceProvider: (any InferenceProvider)? { get }
    var tracer: (any Tracer)? { get }
    var inputGuardrails: [any InputGuardrail] { get }
    var outputGuardrails: [any OutputGuardrail] { get }
    var handoffs: [AnyHandoffConfiguration] { get }

    // Methods
    func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult
    func stream(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) -> AsyncThrowingStream<AgentEvent, Error>
    func cancel() async
}

// MARK: - AgentBox

/// Private class that wraps a concrete Agent implementation.
private final class AgentBox<A: AgentRuntime>: AnyAgentBox, @unchecked Sendable {
    // MARK: Internal

    var tools: [any AnyJSONTool] {
        agent.tools
    }

    var instructions: String {
        agent.instructions
    }

    var configuration: AgentConfiguration {
        agent.configuration
    }

    var memory: (any Memory)? {
        agent.memory
    }

    var inferenceProvider: (any InferenceProvider)? {
        agent.inferenceProvider
    }

    var tracer: (any Tracer)? {
        agent.tracer
    }

    var inputGuardrails: [any InputGuardrail] {
        agent.inputGuardrails
    }

    var outputGuardrails: [any OutputGuardrail] {
        agent.outputGuardrails
    }

    var handoffs: [AnyHandoffConfiguration] {
        agent.handoffs
    }

    init(_ agent: A) {
        self.agent = agent
    }

    // MARK: - Methods

    func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult {
        try await agent.run(input, session: session, hooks: hooks)
    }

    func stream(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) -> AsyncThrowingStream<AgentEvent, Error> {
        agent.stream(input, session: session, hooks: hooks)
    }

    func cancel() async {
        await agent.cancel()
    }

    // MARK: Private

    private let agent: A
}
