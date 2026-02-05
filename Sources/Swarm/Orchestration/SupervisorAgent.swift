// SupervisorAgent.swift
// Swarm Framework
//
// Multi-agent orchestration via supervisor pattern with LLM-based routing.

import Foundation

// MARK: - RoutingStrategy

/// Protocol for agent routing strategies used by SupervisorAgent.
///
/// Routing strategies determine which agent should handle a given input
/// by analyzing the input against available agent descriptions.
///
/// Example:
/// ```swift
/// let strategy = LLMRoutingStrategy(inferenceProvider: myProvider)
/// let decision = try await strategy.selectAgent(
///     for: "Calculate the sum of 2 and 3",
///     from: agentDescriptions,
///     context: nil
/// )
/// print(decision.selectedAgentName) // "calculator_agent"
/// ```
public protocol RoutingStrategy: Sendable {
    /// Selects an agent to handle the given input.
    ///
    /// - Parameters:
    ///   - input: The user input to route.
    ///   - agents: Available agent descriptions.
    ///   - context: Optional shared context.
    /// - Returns: A routing decision indicating which agent to use.
    /// - Throws: `AgentError` if routing fails.
    func selectAgent(
        for input: String,
        from agents: [AgentDescription],
        context: AgentContext?
    ) async throws -> RoutingDecision
}

// MARK: - AgentDescription

/// Describes an agent's capabilities for routing decisions.
///
/// AgentDescription provides metadata about an agent that routing
/// strategies can use to determine which agent should handle a request.
///
/// Example:
/// ```swift
/// let description = AgentDescription(
///     name: "calculator",
///     description: "Performs mathematical calculations",
///     capabilities: ["arithmetic", "algebra", "trigonometry"],
///     keywords: ["calculate", "math", "compute", "sum", "multiply"]
/// )
/// ```
public struct AgentDescription: Sendable, Equatable {
    /// The unique name of the agent.
    public let name: String

    /// A description of what the agent does.
    public let description: String

    /// The capabilities this agent provides.
    public let capabilities: [String]

    /// Keywords that indicate this agent should be used.
    public let keywords: [String]

    /// Creates a new agent description.
    ///
    /// - Parameters:
    ///   - name: The agent's unique name.
    ///   - description: A description of the agent's purpose.
    ///   - capabilities: List of capabilities. Default: []
    ///   - keywords: Trigger keywords. Default: []
    public init(
        name: String,
        description: String,
        capabilities: [String] = [],
        keywords: [String] = []
    ) {
        self.name = name
        self.description = description
        self.capabilities = capabilities
        self.keywords = keywords
    }
}

// MARK: - RoutingDecision

/// The result of a routing decision.
///
/// Contains information about which agent was selected and
/// the confidence level of that decision.
///
/// Example:
/// ```swift
/// let decision = RoutingDecision(
///     selectedAgentName: "weather_agent",
///     confidence: 0.95,
///     reasoning: "Input requests weather information for a location"
/// )
/// ```
public struct RoutingDecision: Sendable, Equatable {
    /// The name of the selected agent.
    public let selectedAgentName: String

    /// Confidence level in the decision (0.0-1.0).
    public let confidence: Double

    /// Optional explanation of why this agent was selected.
    public let reasoning: String?

    /// Creates a new routing decision.
    ///
    /// - Parameters:
    ///   - selectedAgentName: The name of the selected agent.
    ///   - confidence: Confidence level (0.0-1.0). Default: 1.0
    ///   - reasoning: Optional explanation. Default: nil
    public init(
        selectedAgentName: String,
        confidence: Double = 1.0,
        reasoning: String? = nil
    ) {
        self.selectedAgentName = selectedAgentName
        self.confidence = min(max(confidence, 0.0), 1.0) // Clamp to 0.0-1.0
        self.reasoning = reasoning
    }
}

// MARK: - LLMRoutingStrategy

/// Routes requests using an LLM to analyze input and select the best agent.
///
/// This strategy uses a language model to intelligently determine which
/// agent is best suited to handle a given input. It works with any LLM
/// via the `InferenceProvider` protocol.
///
/// Example:
/// ```swift
/// let strategy = LLMRoutingStrategy(
///     inferenceProvider: myProvider,
///     shouldFallbackToKeyword: true
/// )
/// ```
public struct LLMRoutingStrategy: RoutingStrategy {
    // MARK: Public

    /// The inference provider to use for routing decisions.
    public let inferenceProvider: any InferenceProvider

    /// Whether to fall back to keyword matching if LLM fails.
    public let shouldFallbackToKeyword: Bool

    /// Temperature for LLM generation (lower = more deterministic).
    public let temperature: Double

    /// Creates a new LLM-based routing strategy.
    ///
    /// - Parameters:
    ///   - inferenceProvider: The LLM provider for routing decisions.
    ///   - shouldFallbackToKeyword: Fall back to keyword matching on failure. Default: true
    ///   - temperature: Generation temperature. Default: 0.3 (more deterministic)
    public init(
        inferenceProvider: any InferenceProvider,
        shouldFallbackToKeyword: Bool = true,
        temperature: Double = 0.3
    ) {
        self.inferenceProvider = inferenceProvider
        self.shouldFallbackToKeyword = shouldFallbackToKeyword
        self.temperature = temperature
    }

    /// Creates a new LLM-based routing strategy.
    ///
    /// - Parameters:
    ///   - inferenceProvider: The LLM provider for routing decisions.
    ///   - fallbackToKeyword: Fall back to keyword matching on failure.
    ///   - temperature: Generation temperature. Default: 0.3 (more deterministic)
    @available(*, deprecated, message: "Use shouldFallbackToKeyword instead of fallbackToKeyword")
    public init(
        inferenceProvider: any InferenceProvider,
        fallbackToKeyword: Bool,
        temperature: Double = 0.3
    ) {
        self.init(
            inferenceProvider: inferenceProvider,
            shouldFallbackToKeyword: fallbackToKeyword,
            temperature: temperature
        )
    }

    public func selectAgent(
        for input: String,
        from agents: [AgentDescription],
        context: AgentContext?
    ) async throws -> RoutingDecision {
        guard !agents.isEmpty else {
            throw AgentError.internalError(reason: "No agents available for routing")
        }

        guard agents.count > 1 else {
            // Only one agent, no routing needed
            return RoutingDecision(
                selectedAgentName: agents[0].name,
                confidence: 1.0,
                reasoning: "Only one agent available"
            )
        }

        do {
            let prompt = buildRoutingPrompt(input: input, agents: agents)
            let options = InferenceOptions(
                temperature: temperature,
                maxTokens: 500,
                stopSequences: []
            )

            let response = try await inferenceProvider.generate(
                prompt: prompt,
                options: options
            )

            return try await parseRoutingResponse(response, availableAgents: agents)

        } catch {
            // If LLM fails and fallback is enabled, use keyword matching
            if shouldFallbackToKeyword {
                let keywordStrategy = KeywordRoutingStrategy()
                return try await keywordStrategy.selectAgent(
                    for: input,
                    from: agents,
                    context: context
                )
            } else {
                throw AgentError.generationFailed(
                    reason: "LLM routing failed: \(error.localizedDescription)"
                )
            }
        }
    }

    // MARK: Private

    /// Builds the routing prompt for the LLM.
    private func buildRoutingPrompt(input: String, agents: [AgentDescription]) -> String {
        var prompt = """
        You are a routing agent. Your task is to select the most appropriate agent to handle the user's request.

        User Request: "\(input)"

        Available Agents:

        """

        for (index, agent) in agents.enumerated() {
            prompt += "\(index + 1). \(agent.name)\n"
            prompt += "   Description: \(agent.description)\n"
            if !agent.capabilities.isEmpty {
                prompt += "   Capabilities: \(agent.capabilities.joined(separator: ", "))\n"
            }
            if !agent.keywords.isEmpty {
                prompt += "   Keywords: \(agent.keywords.joined(separator: ", "))\n"
            }
            prompt += "\n"
        }

        prompt += """

        Respond with ONLY the exact agent name that should handle this request.
        Do not include any explanation or additional text.

        Selected Agent:
        """

        return prompt
    }

    /// Parses the LLM response to extract the selected agent.
    private func parseRoutingResponse(
        _ response: String,
        availableAgents: [AgentDescription]
    ) async throws -> RoutingDecision {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Try exact match first
        for agent in availableAgents where cleaned == agent.name.lowercased() {
            return RoutingDecision(
                selectedAgentName: agent.name,
                confidence: 0.95,
                reasoning: "LLM selected agent by exact name match"
            )
        }

        // Try partial match
        for agent in availableAgents where cleaned.contains(agent.name.lowercased()) {
            return RoutingDecision(
                selectedAgentName: agent.name,
                confidence: 0.85,
                reasoning: "LLM selected agent by partial name match"
            )
        }

        // If no match, use keyword fallback
        let keywordStrategy = KeywordRoutingStrategy()
        var decision = try await keywordStrategy.selectAgent(
            for: cleaned,
            from: availableAgents,
            context: nil
        )

        // Reduce confidence since we had to fall back
        decision = RoutingDecision(
            selectedAgentName: decision.selectedAgentName,
            confidence: decision.confidence * 0.7,
            reasoning: "LLM response unclear, used keyword fallback"
        )

        return decision
    }
}

// MARK: - KeywordRoutingStrategy

/// Routes requests using simple keyword matching.
///
/// This strategy analyzes the input for keywords associated with each
/// agent and selects the agent with the highest keyword match score.
/// It does not require an LLM and is very fast.
///
/// Example:
/// ```swift
/// let strategy = KeywordRoutingStrategy(isCaseSensitive: false)
/// let decision = try await strategy.selectAgent(
///     for: "What's the weather like?",
///     from: agentDescriptions,
///     context: nil
/// )
/// ```
public struct KeywordRoutingStrategy: RoutingStrategy {
    /// Whether keyword matching is case-sensitive.
    public let isCaseSensitive: Bool

    /// Minimum confidence threshold to select an agent.
    public let minimumConfidence: Double

    /// Creates a new keyword-based routing strategy.
    ///
    /// - Parameters:
    ///   - isCaseSensitive: Whether matching is case-sensitive. Default: false
    ///   - minimumConfidence: Minimum confidence threshold. Default: 0.1
    public init(isCaseSensitive: Bool = false, minimumConfidence: Double = 0.1) {
        self.isCaseSensitive = isCaseSensitive
        self.minimumConfidence = minimumConfidence
    }

    /// Creates a new keyword-based routing strategy.
    ///
    /// - Parameters:
    ///   - caseSensitive: Whether matching is case-sensitive.
    ///   - minimumConfidence: Minimum confidence threshold. Default: 0.1
    @available(*, deprecated, message: "Use isCaseSensitive instead of caseSensitive")
    public init(caseSensitive: Bool, minimumConfidence: Double = 0.1) {
        self.init(isCaseSensitive: caseSensitive, minimumConfidence: minimumConfidence)
    }

    public func selectAgent(
        for input: String,
        from agents: [AgentDescription],
        context _: AgentContext?
    ) async throws -> RoutingDecision {
        guard !agents.isEmpty else {
            throw AgentError.internalError(reason: "No agents available for routing")
        }

        guard agents.count > 1 else {
            // Only one agent, no routing needed
            return RoutingDecision(
                selectedAgentName: agents[0].name,
                confidence: 1.0,
                reasoning: "Only one agent available"
            )
        }

        let normalizedInput = isCaseSensitive ? input : input.lowercased()
        var scores: [(agent: AgentDescription, score: Int)] = []

        for agent in agents {
            var score = 0

            // Check keywords
            for keyword in agent.keywords {
                let normalizedKeyword = isCaseSensitive ? keyword : keyword.lowercased()
                if normalizedInput.contains(normalizedKeyword) {
                    score += 10 // High weight for keyword matches
                }
            }

            // Check capabilities (lower weight)
            for capability in agent.capabilities {
                let normalizedCapability = isCaseSensitive ? capability : capability.lowercased()
                if normalizedInput.contains(normalizedCapability) {
                    score += 5
                }
            }

            // Check agent name
            let normalizedName = isCaseSensitive ? agent.name : agent.name.lowercased()
            if normalizedInput.contains(normalizedName) {
                score += 3
            }

            scores.append((agent, score))
        }

        // Sort by score descending
        scores.sort { $0.score > $1.score }

        guard let best = scores.first, best.score > 0 else {
            // No matches found, use first agent as fallback
            return RoutingDecision(
                selectedAgentName: agents[0].name,
                confidence: 0.0,
                reasoning: "No keyword matches found, using fallback agent"
            )
        }

        // Calculate confidence based on score
        let maxPossibleScore = best.agent.keywords.count * 10 +
            best.agent.capabilities.count * 5 + 3
        let confidence = min(Double(best.score) / Double(max(maxPossibleScore, 1)), 1.0)

        guard confidence >= minimumConfidence else {
            // Confidence too low, use first agent as fallback
            return RoutingDecision(
                selectedAgentName: agents[0].name,
                confidence: 0.0,
                reasoning: "Confidence too low (\(confidence)), using fallback agent"
            )
        }

        return RoutingDecision(
            selectedAgentName: best.agent.name,
            confidence: confidence,
            reasoning: "Keyword matching score: \(best.score)"
        )
    }
}

// MARK: - SupervisorAgent

/// A supervisor agent that routes requests to specialized sub-agents.
///
/// SupervisorAgent implements the supervisor pattern for multi-agent
/// orchestration. It maintains a registry of specialized agents and
/// uses a routing strategy to determine which agent should handle
/// each request.
///
/// The supervisor is LLM-agnostic and can work with any routing strategy,
/// including LLM-based intelligent routing or simple keyword matching.
///
/// Example:
/// ```swift
/// let supervisor = SupervisorAgent(
///     agents: [
///         (name: "calculator", agent: calcAgent, description: calcDesc),
///         (name: "weather", agent: weatherAgent, description: weatherDesc)
///     ],
///     routingStrategy: LLMRoutingStrategy(inferenceProvider: myProvider),
///     fallbackAgent: generalAgent
/// )
///
/// let result = try await supervisor.run("What's 2+2?")
/// ```
public actor SupervisorAgent: AgentRuntime {
    // MARK: Public

    // MARK: - Agent Protocol Properties

    nonisolated public let tools: [any AnyJSONTool] = []
    nonisolated public let instructions: String
    nonisolated public let configuration: AgentConfiguration

    nonisolated public var memory: (any Memory)? { nil }
    nonisolated public var inferenceProvider: (any InferenceProvider)? { nil }

    /// Tracer for this supervisor. Returns `nil` as orchestrators delegate tracing to their sub-agents.
    nonisolated public var tracer: (any Tracer)? { nil }

    /// Configured handoffs for this supervisor.
    nonisolated public var handoffs: [AnyHandoffConfiguration] { _handoffs }

    // MARK: - Supervisor-Specific Methods

    /// Gets the list of available agents.
    public var availableAgents: [String] {
        agentRegistry.map(\.name)
    }

    // MARK: - Initialization

    /// Creates a new supervisor agent.
    ///
    /// - Parameters:
    ///   - agents: Tuples of (name, agent, description) for each sub-agent.
    ///   - routingStrategy: The strategy to use for routing requests.
    ///   - fallbackAgent: Optional agent to use when routing fails. Default: nil
    ///   - configuration: Agent configuration. Default: .default
    ///   - instructions: Custom instructions. Default: auto-generated
    ///   - enableContextTracking: Track execution in AgentContext. Default: true
    ///   - handoffs: Handoff configurations for sub-agents. Default: []
    public init(
        agents: [(name: String, agent: any AgentRuntime, description: AgentDescription)],
        routingStrategy: any RoutingStrategy,
        fallbackAgent: (any AgentRuntime)? = nil,
        configuration: AgentConfiguration = .default,
        instructions: String? = nil,
        enableContextTracking: Bool = true,
        handoffs: [AnyHandoffConfiguration] = []
    ) {
        agentRegistry = agents
        self.routingStrategy = routingStrategy
        self.fallbackAgent = fallbackAgent
        self.configuration = configuration
        self.enableContextTracking = enableContextTracking
        _handoffs = handoffs

        // Generate instructions if not provided
        if let instructions {
            self.instructions = instructions
        } else {
            var generatedInstructions = "You are a supervisor agent that routes requests to specialized agents.\n\nAvailable agents:\n"
            for (name, _, description) in agents {
                generatedInstructions += "- \(name): \(description.description)\n"
            }
            self.instructions = generatedInstructions
        }
    }

    // MARK: - Agent Protocol Methods

    public func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) async throws -> AgentResult {
        let builder = AgentResult.Builder()
        builder.start()

        do {
            // Get agent descriptions for routing
            let descriptions = agentRegistry.map(\.description)

            // Create context if tracking is enabled
            let context: AgentContext? = enableContextTracking ? AgentContext(input: input) : nil

            // Select the appropriate agent
            let decision = try await routingStrategy.selectAgent(
                for: input,
                from: descriptions,
                context: context
            )

            // Find the selected agent
            guard let selectedEntry = agentRegistry.first(where: { $0.name == decision.selectedAgentName }) else {
                // Agent not found, use fallback if available
                return try await handleFallback(
                    input: input,
                    session: session,
                    hooks: hooks,
                    context: context,
                    builder: builder,
                    reason: "agent_not_found"
                )
            }

            // Track execution in context
            if let context {
                await context.recordExecution(agentName: decision.selectedAgentName)
            }

            // Apply handoff configuration and get effective input
            let effectiveInput = try await applyHandoffConfiguration(
                for: selectedEntry.agent,
                name: selectedEntry.name,
                input: input,
                context: context
            )

            // Notify hooks of handoff to selected agent
            if let context {
                await hooks?.onHandoff(context: context, fromAgent: self, toAgent: selectedEntry.agent)
            }

            // Execute the selected agent with potentially modified input
            let result = try await selectedEntry.agent.run(effectiveInput, session: session, hooks: hooks)

            // Update context with result
            if let context {
                await context.setPreviousOutput(result)
            }

            // Build and return final result
            return buildResultFromExecution(
                decision: decision,
                subAgentResult: result,
                builder: builder
            )

        } catch {
            return try await handleRoutingError(
                error,
                input: input,
                session: session,
                hooks: hooks,
                builder: builder
            )
        }
    }

    nonisolated public func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream(for: self) { actor, continuation in
            continuation.yield(.started(input: input))

            let supervisorName = actor.configuration.name.isEmpty ? "SupervisorAgent" : actor.configuration.name

            func forwardStream(
                toAgentName: String,
                agent: any AgentRuntime,
                input: String
            ) async throws -> AgentResult {
                continuation.yield(.handoffStarted(from: supervisorName, to: toAgentName, input: input))
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
                    throw AgentError.internalError(reason: "Supervisor sub-agent stream ended without completion")
                }

                continuation.yield(.handoffCompletedWithResult(
                    from: supervisorName,
                    to: toAgentName,
                    result: finalResult
                ))

                return finalResult
            }

            do {
                let builder = AgentResult.Builder()
                builder.start()

                let registry = actor.agentRegistry
                let routingStrategy = actor.routingStrategy
                let fallbackAgent = actor.fallbackAgent
                let enableContextTracking = actor.enableContextTracking

                let descriptions = registry.map(\.description)
                let context: AgentContext? = enableContextTracking ? AgentContext(input: input) : nil

                let decision = try await routingStrategy.selectAgent(
                    for: input,
                    from: descriptions,
                    context: context
                )

                guard let selectedEntry = registry.first(where: { $0.name == decision.selectedAgentName }) else {
                    if let fallback = fallbackAgent {
                        if let context {
                            await hooks?.onHandoff(context: context, fromAgent: actor, toAgent: fallback)
                        }

                        let fallbackName = fallback.configuration.name.isEmpty ? String(describing: type(of: fallback)) : fallback.configuration.name
                        let fallbackResult = try await forwardStream(
                            toAgentName: fallbackName,
                            agent: fallback,
                            input: input
                        )

                        builder.setOutput(fallbackResult.output)
                        builder.setMetadata("routing_decision", .string("fallback"))
                        builder.setMetadata("fallback_reason", .string("agent_not_found"))
                        builder.setMetadata("routing_confidence", .double(0.0))
                        let result = builder.build()
                        continuation.yield(.completed(result: result))
                        continuation.finish()
                        return
                    }

                    throw AgentError.internalError(
                        reason: "No suitable agent found and no fallback configured"
                    )
                }

                if let context {
                    await context.recordExecution(agentName: decision.selectedAgentName)
                }

                let effectiveInput = try await actor.applyHandoffConfiguration(
                    for: selectedEntry.agent,
                    name: selectedEntry.name,
                    input: input,
                    context: context
                )

                if let context {
                    await hooks?.onHandoff(context: context, fromAgent: actor, toAgent: selectedEntry.agent)
                }

                let subResult = try await forwardStream(
                    toAgentName: selectedEntry.name,
                    agent: selectedEntry.agent,
                    input: effectiveInput
                )

                if let context {
                    await context.setPreviousOutput(subResult)
                }

                let result = await actor.buildResultFromExecution(
                    decision: decision,
                    subAgentResult: subResult,
                    builder: builder
                )
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch {
                do {
                    if let fallback = actor.fallbackAgent {
                        let fallbackName = fallback.configuration.name.isEmpty ? String(describing: type(of: fallback)) : fallback.configuration.name
                        let fallbackResult = try await forwardStream(
                            toAgentName: fallbackName,
                            agent: fallback,
                            input: input
                        )

                        let builder = AgentResult.Builder()
                        builder.start()
                        builder.setOutput(fallbackResult.output)
                        builder.setMetadata("routing_decision", .string("fallback_after_error"))
                        builder.setMetadata("routing_error", .string(error.localizedDescription))
                        for toolCall in fallbackResult.toolCalls {
                            builder.addToolCall(toolCall)
                        }
                        for toolResult in fallbackResult.toolResults {
                            builder.addToolResult(toolResult)
                        }
                        continuation.yield(.completed(result: builder.build()))
                        continuation.finish()
                        return
                    }
                } catch {
                    // Fall through to error handling below.
                }

                if let agentError = error as? AgentError {
                    continuation.yield(.failed(error: agentError))
                    continuation.finish(throwing: agentError)
                } else {
                    let agentError = AgentError.internalError(reason: error.localizedDescription)
                    continuation.yield(.failed(error: agentError))
                    continuation.finish(throwing: agentError)
                }
            }
        }
    }

    public func cancel() async {
        // Cancellation is handled via continuation.onTermination
    }

    /// Gets the description for a specific agent.
    ///
    /// - Parameter name: The agent name.
    /// - Returns: The agent description, or nil if not found.
    public func description(for name: String) -> AgentDescription? {
        agentRegistry.first(where: { $0.name == name })?.description
    }

    /// Executes a specific agent by name, bypassing routing.
    ///
    /// - Parameters:
    ///   - agentName: The name of the agent to execute.
    ///   - input: The input to pass to the agent.
    ///   - session: Optional session for conversation context.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: The agent's result.
    /// - Throws: `AgentError.internalError` if agent not found.
    public func executeAgent(
        named agentName: String,
        input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        guard let entry = agentRegistry.first(where: { $0.name == agentName }) else {
            throw AgentError.internalError(reason: "Agent '\(agentName)' not found")
        }

        return try await entry.agent.run(input, session: session, hooks: hooks)
    }

    // MARK: Private

    // MARK: - Supervisor Properties

    /// Registry of sub-agents with their descriptions.
    private let agentRegistry: [(name: String, agent: any AgentRuntime, description: AgentDescription)]

    /// Strategy for routing requests to agents.
    private let routingStrategy: any RoutingStrategy

    /// Optional fallback agent when routing fails.
    private let fallbackAgent: (any AgentRuntime)?

    /// Whether to track execution in a shared context.
    private let enableContextTracking: Bool

    /// Handoff configurations for sub-agents.
    private let _handoffs: [AnyHandoffConfiguration]

    // MARK: - Run Helper Methods

    /// Applies handoff configuration for the target agent.
    /// - Parameters:
    ///   - targetAgent: The agent to hand off to.
    ///   - name: The name of the target agent.
    ///   - input: The original input.
    ///   - context: The agent context.
    /// - Returns: The effective input after applying handoff configuration.
    /// - Throws: `OrchestrationError` if handoff is disabled.
    private func applyHandoffConfiguration(
        for targetAgent: any AgentRuntime,
        name: String,
        input: String,
        context: AgentContext?
    ) async throws -> String {
        var effectiveInput = input
        let handoffContext = context ?? AgentContext(input: input)

        guard let config = findHandoffConfiguration(for: targetAgent) else {
            return effectiveInput
        }

        // Check isEnabled callback
        if let isEnabled = config.isEnabled {
            let enabled = await isEnabled(handoffContext, targetAgent)
            if !enabled {
                throw OrchestrationError.handoffSkipped(
                    from: "SupervisorAgent",
                    to: name,
                    reason: "Handoff disabled by isEnabled callback"
                )
            }
        }

        // Create HandoffInputData for callbacks
        var inputData = HandoffInputData(
            sourceAgentName: "SupervisorAgent",
            targetAgentName: name,
            input: input,
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
                    "onHandoff callback failed for SupervisorAgent -> \(name): \(error.localizedDescription)"
                )
            }
        }

        return effectiveInput
    }

    /// Builds the final result from a successful sub-agent execution.
    /// - Parameters:
    ///   - decision: The routing decision.
    ///   - subAgentResult: The result from the sub-agent.
    ///   - builder: The result builder.
    /// - Returns: The final agent result.
    private func buildResultFromExecution(
        decision: RoutingDecision,
        subAgentResult: AgentResult,
        builder: AgentResult.Builder
    ) -> AgentResult {
        builder.setOutput(subAgentResult.output)
        builder.setMetadata("selected_agent", .string(decision.selectedAgentName))
        builder.setMetadata("routing_confidence", .double(decision.confidence))
        if let reasoning = decision.reasoning {
            builder.setMetadata("routing_reasoning", .string(reasoning))
        }

        // Copy tool calls from sub-agent result
        for toolCall in subAgentResult.toolCalls {
            builder.addToolCall(toolCall)
        }
        for toolResult in subAgentResult.toolResults {
            builder.addToolResult(toolResult)
        }

        return builder.build()
    }

    /// Handles fallback when no suitable agent is found.
    /// - Parameters:
    ///   - input: The original input.
    ///   - session: The session.
    ///   - hooks: The run hooks.
    ///   - context: The agent context.
    ///   - builder: The result builder.
    ///   - reason: The reason for fallback.
    /// - Returns: The fallback agent result.
    /// - Throws: `AgentError` if no fallback is configured.
    private func handleFallback(
        input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?,
        context: AgentContext?,
        builder: AgentResult.Builder,
        reason: String
    ) async throws -> AgentResult {
        guard let fallback = fallbackAgent else {
            throw AgentError.internalError(
                reason: "No suitable agent found and no fallback configured"
            )
        }

        // Notify hooks of handoff to fallback agent
        if let context {
            await hooks?.onHandoff(context: context, fromAgent: self, toAgent: fallback)
        }

        let result = try await fallback.run(input, session: session, hooks: hooks)
        builder.setOutput(result.output)
        builder.setMetadata("routing_decision", .string("fallback"))
        builder.setMetadata("fallback_reason", .string(reason))
        builder.setMetadata("routing_confidence", .double(0.0))
        return builder.build()
    }

    /// Handles errors during routing or execution.
    /// - Parameters:
    ///   - error: The error that occurred.
    ///   - input: The original input.
    ///   - session: The session.
    ///   - hooks: The run hooks.
    ///   - builder: The result builder.
    /// - Returns: The fallback result.
    /// - Throws: The original error if no fallback is available.
    private func handleRoutingError(
        _ error: Error,
        input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?,
        builder: AgentResult.Builder
    ) async throws -> AgentResult {
        // If routing fails and we have a fallback, use it
        if let fallback = fallbackAgent, error is AgentError {
            // Notify hooks of handoff to fallback agent after error
            let errorContext = AgentContext(input: input)
            await hooks?.onHandoff(context: errorContext, fromAgent: self, toAgent: fallback)

            let result = try await fallback.run(input, session: session, hooks: hooks)
            builder.setOutput(result.output)
            builder.setMetadata("routing_decision", .string("fallback_after_error"))
            builder.setMetadata("routing_error", .string(error.localizedDescription))
            return builder.build()
        } else {
            // Convert to AgentError if needed
            if let agentError = error as? AgentError {
                throw agentError
            } else {
                throw AgentError.internalError(reason: error.localizedDescription)
            }
        }
    }

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
}

// MARK: - RoutingDecision + CustomStringConvertible

extension RoutingDecision: CustomStringConvertible {
    public var description: String {
        var desc = "RoutingDecision(agent: \(selectedAgentName), confidence: \(confidence)"
        if let reasoning {
            desc += ", reasoning: \(reasoning)"
        }
        desc += ")"
        return desc
    }
}
