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
public func --> (lhs: any AgentRuntime, rhs: any AgentRuntime) -> SequentialChain {
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
public func --> (lhs: SequentialChain, rhs: any AgentRuntime) -> SequentialChain {
    var agents = lhs.chainedAgents
    agents.append(rhs)
    return SequentialChain(
        agents: agents,
        configuration: lhs.configuration,
        transformers: lhs.transformers,
        handoffs: lhs.handoffs
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
public actor SequentialChain: AgentRuntime {
    // MARK: Public

    /// Configuration for the chain execution.
    nonisolated public let configuration: AgentConfiguration

    // MARK: - Chain Properties (nonisolated)

    /// The agents in execution order.
    nonisolated public let chainedAgents: [any AgentRuntime]

    // MARK: - Agent Protocol Properties (nonisolated)

    /// Tools available to this chain (always empty - agents have their own tools).
    nonisolated public var tools: [any AnyJSONTool] { [] }

    /// Instructions describing this sequential chain.
    nonisolated public var instructions: String {
        "Sequential chain executing \(chainedAgents.count) agents in order"
    }

    /// Memory system (chains don't maintain their own memory).
    nonisolated public var memory: (any Memory)? { nil }

    /// Inference provider (chains don't use inference directly).
    nonisolated public var inferenceProvider: (any InferenceProvider)? { nil }

    /// Tracer (chains don't use tracing directly).
    nonisolated public var tracer: (any Tracer)? { nil }

    /// Configured handoffs for this chain.
    nonisolated public var handoffs: [AnyHandoffConfiguration] { _handoffs }

    // MARK: - Initialization

    /// Creates a new sequential chain.
    ///
    /// - Parameters:
    ///   - agents: The agents to execute in order.
    ///   - configuration: Execution configuration. Default: `.default`
    ///   - transformers: Output transformers indexed by agent position. Default: [:]
    ///   - handoffs: Handoff configurations for chained agents. Default: []
    public init(
        agents: [any AgentRuntime],
        configuration: AgentConfiguration = .default,
        transformers: [Int: OutputTransformer] = [:],
        handoffs: [AnyHandoffConfiguration] = []
    ) {
        chainedAgents = agents
        self.configuration = configuration
        self.transformers = transformers
        _handoffs = handoffs
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
            transformers: newTransformers,
            handoffs: _handoffs
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
    /// - Parameters:
    ///   - input: The initial input for the first agent.
    ///   - session: Optional session for state persistence.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: The combined result of all agents.
    /// - Throws: `OrchestrationError.noAgentsConfigured` if no agents are configured,
    ///           or `AgentError.cancelled` if execution was cancelled.
    public func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) async throws -> AgentResult {
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

            // Apply handoff configuration if available
            var effectiveInput = currentInput
            let handoffContext = context ?? AgentContext(input: input)

            if let config = findHandoffConfiguration(for: agent) {
                // Check isEnabled callback
                if let isEnabled = config.isEnabled {
                    let enabled = await isEnabled(handoffContext, agent)
                    if !enabled {
                        throw OrchestrationError.handoffSkipped(
                            from: "SequentialChain",
                            to: agentName,
                            reason: "Handoff disabled by isEnabled callback"
                        )
                    }
                }

                // Create HandoffInputData for callbacks
                var inputData = HandoffInputData(
                    sourceAgentName: "SequentialChain",
                    targetAgentName: agentName,
                    input: currentInput,
                    context: [:],
                    metadata: [:]
                )

                // Apply inputFilter if present
                if let inputFilter = config.inputFilter {
                    inputData = inputFilter(inputData)
                    effectiveInput = inputData.input
                }

                // Call onHandoff callback if present
                if let onHandoff = config.onHandoff {
                    do {
                        try await onHandoff(handoffContext, inputData)
                    } catch {
                        // Log callback errors but don't fail the handoff
                        Log.orchestration.warning(
                            "onHandoff callback failed for SequentialChain -> \(agentName): \(error.localizedDescription)"
                        )
                    }
                }
            }

            // Notify hooks of handoff to next agent
            if let context {
                await hooks?.onHandoff(context: context, fromAgent: self, toAgent: agent)
            }

            // Run the agent with potentially modified input
            let agentResult = try await agent.run(effectiveInput, session: session, hooks: hooks)

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
    /// - Parameters:
    ///   - input: The initial input for the first agent.
    ///   - session: Optional session for state persistence.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: An async stream of agent events.
    nonisolated public func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream(for: self) { actor, continuation in
            continuation.yield(.started(input: input))

            let chainName = actor.configuration.name.isEmpty ? "SequentialChain" : actor.configuration.name

            func forwardStream(
                toAgentName: String,
                agent: any AgentRuntime,
                input: String
            ) async throws -> AgentResult {
                continuation.yield(.handoffStarted(from: chainName, to: toAgentName, input: input))
                var result: AgentResult?

                for try await event in agent.stream(input, session: session, hooks: hooks) {
                    switch event {
                    case .started:
                        continue
                    case let .completed(subResult):
                        result = subResult
                    case let .failed(error):
                        throw error
                    default:
                        continuation.yield(event)
                    }
                }

                guard let finalResult = result else {
                    throw AgentError.internalError(reason: "SequentialChain stream ended without completion")
                }

                continuation.yield(.handoffCompletedWithResult(
                    from: chainName,
                    to: toAgentName,
                    result: finalResult
                ))

                return finalResult
            }

            do {
                guard !actor.chainedAgents.isEmpty else {
                    throw AgentError.invalidInput(reason: "No agents configured in sequential chain")
                }

                let sharedContext = AgentContext(input: input)
                await actor.setContext(sharedContext)

                let builder = AgentResult.Builder()
                builder.start()

                var currentInput = input

                for (index, agent) in actor.chainedAgents.enumerated() {
                    if await actor.isCancelled {
                        throw AgentError.cancelled
                    }

                    let agentName = String(describing: type(of: agent))
                    await sharedContext.recordExecution(agentName: agentName)

                    var effectiveInput = currentInput
                    let handoffContext = sharedContext

                    if let config = await actor.findHandoffConfiguration(for: agent) {
                        if let isEnabled = config.isEnabled {
                            let enabled = await isEnabled(handoffContext, agent)
                            if !enabled {
                                throw OrchestrationError.handoffSkipped(
                                    from: "SequentialChain",
                                    to: agentName,
                                    reason: "Handoff disabled by isEnabled callback"
                                )
                            }
                        }

                        var inputData = HandoffInputData(
                            sourceAgentName: "SequentialChain",
                            targetAgentName: agentName,
                            input: currentInput,
                            context: [:],
                            metadata: [:]
                        )

                        if let inputFilter = config.inputFilter {
                            inputData = inputFilter(inputData)
                            effectiveInput = inputData.input
                        }

                        if let onHandoff = config.onHandoff {
                            do {
                                try await onHandoff(handoffContext, inputData)
                            } catch {
                                Log.orchestration.warning(
                                    "onHandoff callback failed for SequentialChain -> \(agentName): \(error.localizedDescription)"
                                )
                            }
                        }
                    }

                    await hooks?.onHandoff(context: sharedContext, fromAgent: actor, toAgent: agent)

                    let agentResult = try await forwardStream(
                        toAgentName: agentName,
                        agent: agent,
                        input: effectiveInput
                    )

                    for toolCall in agentResult.toolCalls {
                        builder.addToolCall(toolCall)
                    }

                    for toolResult in agentResult.toolResults {
                        builder.addToolResult(toolResult)
                    }

                    for _ in 0..<agentResult.iterationCount {
                        builder.incrementIteration()
                    }

                    await sharedContext.setPreviousOutput(agentResult)

                    let transformer = actor.transformers[index] ?? .passthrough
                    currentInput = transformer.apply(agentResult)

                    if index == actor.chainedAgents.count - 1 {
                        builder.setOutput(agentResult.output)
                    }
                }

                continuation.yield(.completed(result: builder.build()))
                continuation.finish()
            } catch let error as AgentError {
                continuation.yield(.failed(error: error))
                continuation.finish(throwing: error)
            } catch {
                let agentError = AgentError.internalError(reason: error.localizedDescription)
                continuation.yield(.failed(error: agentError))
                continuation.finish(throwing: agentError)
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

    /// Handoff configurations for chained agents.
    private let _handoffs: [AnyHandoffConfiguration]

    // MARK: - Private Methods

    /// Finds a handoff configuration for the given target agent.
    ///
    /// - Parameter targetAgent: The agent to find configuration for.
    /// - Returns: The matching handoff configuration, or nil if none found.
    private func findHandoffConfiguration(for targetAgent: any AgentRuntime) -> AnyHandoffConfiguration? {
        _handoffs.first { config in
            // Match by type - compare the target agent's type
            let configTargetType = type(of: config.targetAgent)
            let currentType = type(of: targetAgent)
            return configTargetType == currentType
        }
    }

    private func setContext(_ context: AgentContext?) {
        self.context = context
    }
}

// MARK: CustomStringConvertible

extension SequentialChain: CustomStringConvertible {
    nonisolated public var description: String {
        "SequentialChain(\(chainedAgents.count) agents)"
    }
}
