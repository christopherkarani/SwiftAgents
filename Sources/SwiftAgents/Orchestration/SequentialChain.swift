// SequentialChain.swift
// SwiftAgents Framework
//
// Sequential agent chaining with custom operator and output transformers.

import Foundation

// MARK: - Custom Operators

infix operator -->: AdditionPrecedence

/// Chains two agents together sequentially.
///
/// Example:
/// ```swift
/// let chain = agentA --> agentB
/// let result = try await chain.run("input")
/// ```
///
/// - Parameters:
///   - lhs: The first agent.
///   - rhs: The second agent.
/// - Returns: A sequential chain of the two agents.
public func --> (lhs: any Agent, rhs: any Agent) -> SequentialChain {
    SequentialChain(agents: [lhs, rhs])
}

/// Chains an additional agent to an existing sequential chain.
///
/// Example:
/// ```swift
/// let chain = agentA --> agentB --> agentC
/// let result = try await chain.run("input")
/// ```
///
/// - Parameters:
///   - lhs: The existing sequential chain.
///   - rhs: The agent to append.
/// - Returns: A new sequential chain with the agent appended.
public func --> (lhs: SequentialChain, rhs: any Agent) -> SequentialChain {
    var agents = lhs.chainedAgents
    agents.append(rhs)
    return SequentialChain(
        agents: agents,
        configuration: lhs.configuration,
        transformers: lhs.transformers
    )
}

// MARK: - OutputTransformer

/// A transformer that modifies agent output before passing to the next agent.
///
/// OutputTransformer allows you to customize how results flow between
/// agents in a sequential chain. Use the static presets or create custom
/// transformations.
///
/// Example:
/// ```swift
/// let chain = agentA --> agentB
/// let configured = chain.withTransformer(after: 0, .withMetadata)
/// ```
public struct OutputTransformer: Sendable {
    // MARK: Public

    // MARK: - Predefined Transformers

    /// Passthrough transformer - uses the agent output directly.
    public static let passthrough = OutputTransformer { result in
        result.output
    }

    /// Metadata transformer - includes tool calls and iteration count.
    public static let withMetadata = OutputTransformer { result in
        var output = result.output

        if !result.toolCalls.isEmpty {
            output += "\n\nTools used: \(result.toolCalls.map(\.toolName).joined(separator: ", "))"
        }

        if result.iterationCount > 1 {
            output += "\n\nIterations: \(result.iterationCount)"
        }

        return output
    }

    /// Creates a new output transformer.
    ///
    /// - Parameter transform: The transformation function.
    public init(_ transform: @escaping @Sendable (AgentResult) -> String) {
        self.transform = transform
    }

    /// Applies the transformation to an agent result.
    ///
    /// - Parameter result: The agent result to transform.
    /// - Returns: The transformed output string.
    public func apply(_ result: AgentResult) -> String {
        transform(result)
    }

    // MARK: Private

    private let transform: @Sendable (AgentResult) -> String
}

// MARK: - SequentialChain

/// A sequential chain that executes agents one after another.
///
/// SequentialChain runs multiple agents in sequence, passing the output
/// of each agent as input to the next. This enables pipeline-style
/// orchestration where each agent builds on the previous agent's work.
///
/// Example:
/// ```swift
/// let chain = researchAgent --> summaryAgent --> validatorAgent
/// let result = try await chain.run("Analyze quarterly results")
/// ```
///
/// You can customize output transformation between agents:
/// ```swift
/// let chain = agentA --> agentB
/// let configured = chain.withTransformer(after: 0, .withMetadata)
/// ```
public actor SequentialChain: Agent {
    // MARK: Public

    /// Configuration for the chain execution.
    nonisolated public let configuration: AgentConfiguration

    // MARK: - Chain Properties (nonisolated)

    /// The agents in execution order.
    nonisolated public let chainedAgents: [any Agent]

    // MARK: - Agent Protocol Properties (nonisolated)

    /// Tools available to this chain (always empty - agents have their own tools).
    nonisolated public var tools: [any Tool] { [] }

    /// Instructions describing this sequential chain.
    nonisolated public var instructions: String {
        "Sequential chain executing \(chainedAgents.count) agents in order"
    }

    /// Memory system (chains don't maintain their own memory).
    nonisolated public var memory: (any Memory)? { nil }

    /// Inference provider (chains don't use inference directly).
    nonisolated public var inferenceProvider: (any InferenceProvider)? { nil }

    // MARK: - Initialization

    /// Creates a new sequential chain.
    ///
    /// - Parameters:
    ///   - agents: The agents to execute in order.
    ///   - configuration: Execution configuration. Default: `.default`
    ///   - transformers: Output transformers indexed by agent position. Default: [:]
    public init(
        agents: [any Agent],
        configuration: AgentConfiguration = .default,
        transformers: [Int: OutputTransformer] = [:]
    ) {
        chainedAgents = agents
        self.configuration = configuration
        self.transformers = transformers
    }

    // MARK: - Configuration

    /// Returns a new chain with a transformer applied after the specified agent.
    ///
    /// - Parameters:
    ///   - index: The index of the agent after which to apply the transformer.
    ///   - transformer: The transformer to apply.
    /// - Returns: A new configured chain.
    ///
    /// Example:
    /// ```swift
    /// let chain = agentA --> agentB --> agentC
    /// let configured = chain
    ///     .withTransformer(after: 0, .withMetadata)
    ///     .withTransformer(after: 1, .passthrough)
    /// ```
    nonisolated public func withTransformer(after index: Int, _ transformer: OutputTransformer) -> SequentialChain {
        var newTransformers = transformers
        newTransformers[index] = transformer
        return SequentialChain(
            agents: chainedAgents,
            configuration: configuration,
            transformers: newTransformers
        )
    }

    // MARK: - Agent Protocol Methods

    /// Executes the sequential chain.
    ///
    /// Runs each agent in sequence, passing the output of each agent
    /// as input to the next. Returns a combined result containing:
    /// - The final agent's output
    /// - All tool calls from all agents
    /// - Sum of all iteration counts
    /// - Total duration
    ///
    /// - Parameter input: The initial input for the first agent.
    /// - Returns: The combined result of all agents.
    /// - Throws: `OrchestrationError.noAgentsConfigured` if no agents are configured,
    ///           or `AgentError.cancelled` if execution was cancelled.
    public func run(_ input: String) async throws -> AgentResult {
        guard !chainedAgents.isEmpty else {
            throw AgentError.invalidInput(reason: "No agents configured in sequential chain")
        }

        // Create shared context
        context = AgentContext(input: input)

        let builder = AgentResult.Builder()
        _ = builder.start()

        var currentInput = input

        // Execute each agent in sequence
        for (index, agent) in chainedAgents.enumerated() {
            // Check for cancellation
            if isCancelled {
                throw AgentError.cancelled
            }

            // Record execution in context
            let agentName = String(describing: type(of: agent))
            await context?.recordExecution(agentName: agentName)

            // Run the agent
            let agentResult = try await agent.run(currentInput)

            // Accumulate tool calls and iterations
            for toolCall in agentResult.toolCalls {
                _ = builder.addToolCall(toolCall)
            }

            for toolResult in agentResult.toolResults {
                _ = builder.addToolResult(toolResult)
            }

            for _ in 0..<agentResult.iterationCount {
                _ = builder.incrementIteration()
            }

            // Store previous output in context
            await context?.setPreviousOutput(agentResult)

            // Apply transformer if configured, otherwise use passthrough
            let transformer = transformers[index] ?? .passthrough
            currentInput = transformer.apply(agentResult)

            // If this is the last agent, set the final output
            if index == chainedAgents.count - 1 {
                _ = builder.setOutput(agentResult.output)
            }
        }

        return builder.build()
    }

    /// Streams the sequential chain execution.
    ///
    /// Yields events from each agent as they execute in sequence.
    /// Each agent's stream is fully consumed before moving to the next.
    ///
    /// - Parameter input: The initial input for the first agent.
    /// - Returns: An async stream of agent events.
    nonisolated public func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream(for: self) { actor, continuation in
            continuation.yield(.started(input: input))
            do {
                let result = try await actor.run(input)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch let error as AgentError {
                continuation.yield(.failed(error: error))
                continuation.finish(throwing: error)
            } catch {
                let agentError = AgentError.internalError(reason: error.localizedDescription)
                continuation.yield(.failed(error: agentError))
                continuation.finish(throwing: error)
            }
        }
    }

    /// Cancels the chain execution.
    ///
    /// Propagates cancellation to all agents in the chain.
    public func cancel() async {
        isCancelled = true

        // Propagate cancellation to all agents
        for agent in chainedAgents {
            await agent.cancel()
        }
    }

    // MARK: - Context Access

    /// Gets the current execution context.
    ///
    /// - Returns: The shared context, or nil if no execution is in progress.
    public func getContext() -> AgentContext? {
        context
    }

    // MARK: Internal

    // MARK: - Internal Properties (nonisolated)

    /// Transformers to apply between agents (index -> transformer).
    nonisolated let transformers: [Int: OutputTransformer]

    // MARK: Private

    // MARK: - Private State

    /// Shared context for the chain execution.
    private var context: AgentContext?

    /// Whether execution has been cancelled.
    private var isCancelled: Bool = false
}

// MARK: CustomStringConvertible

extension SequentialChain: CustomStringConvertible {
    nonisolated public var description: String {
        "SequentialChain(\(chainedAgents.count) agents)"
    }
}
