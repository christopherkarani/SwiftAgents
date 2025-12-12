// SupervisorAgent.swift
// SwiftAgents Framework
//
// Multi-agent orchestration via supervisor pattern with LLM-based routing.

import Foundation

// MARK: - Routing Strategy Protocol

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

// MARK: - Agent Description

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

// MARK: - Routing Decision

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

// MARK: - LLM Routing Strategy

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
///     fallbackToKeyword: true
/// )
/// ```
public struct LLMRoutingStrategy: RoutingStrategy {
    /// The inference provider to use for routing decisions.
    public let inferenceProvider: any InferenceProvider

    /// Whether to fall back to keyword matching if LLM fails.
    public let fallbackToKeyword: Bool

    /// Temperature for LLM generation (lower = more deterministic).
    public let temperature: Double

    /// Creates a new LLM-based routing strategy.
    ///
    /// - Parameters:
    ///   - inferenceProvider: The LLM provider for routing decisions.
    ///   - fallbackToKeyword: Fall back to keyword matching on failure. Default: true
    ///   - temperature: Generation temperature. Default: 0.3 (more deterministic)
    public init(
        inferenceProvider: any InferenceProvider,
        fallbackToKeyword: Bool = true,
        temperature: Double = 0.3
    ) {
        self.inferenceProvider = inferenceProvider
        self.fallbackToKeyword = fallbackToKeyword
        self.temperature = temperature
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
            if fallbackToKeyword {
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
        for agent in availableAgents {
            if cleaned == agent.name.lowercased() {
                return RoutingDecision(
                    selectedAgentName: agent.name,
                    confidence: 0.95,
                    reasoning: "LLM selected agent by exact name match"
                )
            }
        }

        // Try partial match
        for agent in availableAgents {
            if cleaned.contains(agent.name.lowercased()) {
                return RoutingDecision(
                    selectedAgentName: agent.name,
                    confidence: 0.85,
                    reasoning: "LLM selected agent by partial name match"
                )
            }
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

// MARK: - Keyword Routing Strategy

/// Routes requests using simple keyword matching.
///
/// This strategy analyzes the input for keywords associated with each
/// agent and selects the agent with the highest keyword match score.
/// It does not require an LLM and is very fast.
///
/// Example:
/// ```swift
/// let strategy = KeywordRoutingStrategy(caseSensitive: false)
/// let decision = try await strategy.selectAgent(
///     for: "What's the weather like?",
///     from: agentDescriptions,
///     context: nil
/// )
/// ```
public struct KeywordRoutingStrategy: RoutingStrategy {
    /// Whether keyword matching is case-sensitive.
    public let caseSensitive: Bool

    /// Minimum confidence threshold to select an agent.
    public let minimumConfidence: Double

    /// Creates a new keyword-based routing strategy.
    ///
    /// - Parameters:
    ///   - caseSensitive: Whether matching is case-sensitive. Default: false
    ///   - minimumConfidence: Minimum confidence threshold. Default: 0.1
    public init(caseSensitive: Bool = false, minimumConfidence: Double = 0.1) {
        self.caseSensitive = caseSensitive
        self.minimumConfidence = minimumConfidence
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

        let normalizedInput = caseSensitive ? input : input.lowercased()
        var scores: [(agent: AgentDescription, score: Int)] = []

        for agent in agents {
            var score = 0

            // Check keywords
            for keyword in agent.keywords {
                let normalizedKeyword = caseSensitive ? keyword : keyword.lowercased()
                if normalizedInput.contains(normalizedKeyword) {
                    score += 10 // High weight for keyword matches
                }
            }

            // Check capabilities (lower weight)
            for capability in agent.capabilities {
                let normalizedCapability = caseSensitive ? capability : capability.lowercased()
                if normalizedInput.contains(normalizedCapability) {
                    score += 5
                }
            }

            // Check agent name
            let normalizedName = caseSensitive ? agent.name : agent.name.lowercased()
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

// MARK: - Supervisor Agent

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
public actor SupervisorAgent: Agent {
    // MARK: - Agent Protocol Properties

    public nonisolated let tools: [any Tool] = []
    public nonisolated let instructions: String
    public nonisolated let configuration: AgentConfiguration
    public nonisolated var memory: (any AgentMemory)? { nil }
    public nonisolated var inferenceProvider: (any InferenceProvider)? { nil }

    // MARK: - Supervisor Properties

    /// Registry of sub-agents with their descriptions.
    private let agentRegistry: [(name: String, agent: any Agent, description: AgentDescription)]

    /// Strategy for routing requests to agents.
    private let routingStrategy: any RoutingStrategy

    /// Optional fallback agent when routing fails.
    private let fallbackAgent: (any Agent)?

    /// Whether to track execution in a shared context.
    private let enableContextTracking: Bool

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
    public init(
        agents: [(name: String, agent: any Agent, description: AgentDescription)],
        routingStrategy: any RoutingStrategy,
        fallbackAgent: (any Agent)? = nil,
        configuration: AgentConfiguration = .default,
        instructions: String? = nil,
        enableContextTracking: Bool = true
    ) {
        self.agentRegistry = agents
        self.routingStrategy = routingStrategy
        self.fallbackAgent = fallbackAgent
        self.configuration = configuration
        self.enableContextTracking = enableContextTracking

        // Generate instructions if not provided
        if let instructions = instructions {
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

    public func run(_ input: String) async throws -> AgentResult {
        let builder = AgentResult.Builder()
        builder.start()

        do {
            // Get agent descriptions for routing
            let descriptions = agentRegistry.map { $0.description }

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
                if let fallback = fallbackAgent {
                    let result = try await fallback.run(input)
                    builder.setOutput(result.output)
                    builder.setMetadata("routing_decision", .string("fallback"))
                    builder.setMetadata("routing_confidence", .double(0.0))
                    return builder.build()
                } else {
                    throw AgentError.internalError(
                        reason: "Selected agent '\(decision.selectedAgentName)' not found and no fallback configured"
                    )
                }
            }

            // Track execution in context
            if let context = context {
                await context.recordExecution(agentName: decision.selectedAgentName)
            }

            // Execute the selected agent
            let result = try await selectedEntry.agent.run(input)

            // Update context with result
            if let context = context {
                await context.setPreviousOutput(result)
            }

            // Build final result
            builder.setOutput(result.output)
            builder.setMetadata("selected_agent", .string(decision.selectedAgentName))
            builder.setMetadata("routing_confidence", .double(decision.confidence))
            if let reasoning = decision.reasoning {
                builder.setMetadata("routing_reasoning", .string(reasoning))
            }

            // Copy tool calls from sub-agent result
            for toolCall in result.toolCalls {
                builder.addToolCall(toolCall)
            }
            for toolResult in result.toolResults {
                builder.addToolResult(toolResult)
            }

            return builder.build()

        } catch {
            // If routing fails and we have a fallback, use it
            if let fallback = fallbackAgent, error is AgentError {
                let result = try await fallback.run(input)
                builder.setOutput(result.output)
                builder.setMetadata("routing_decision", .string("fallback_after_error"))
                builder.setMetadata("routing_error", .string(error.localizedDescription))
                return builder.build()
            } else {
                throw error
            }
        }
    }

    public nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.started(input: input))

                    // Get agent descriptions for routing
                    let descriptions = agentRegistry.map { $0.description }

                    // Create context if tracking is enabled
                    let context: AgentContext? = enableContextTracking ? AgentContext(input: input) : nil

                    // Select the appropriate agent
                    let decision = try await routingStrategy.selectAgent(
                        for: input,
                        from: descriptions,
                        context: context
                    )

                    // Emit routing decision
                    continuation.yield(.thinking(
                        thought: "Routing to agent: \(decision.selectedAgentName) (confidence: \(decision.confidence))"
                    ))

                    // Find the selected agent
                    guard let selectedEntry = agentRegistry.first(where: { $0.name == decision.selectedAgentName }) else {
                        // Agent not found, use fallback if available
                        if let fallback = fallbackAgent {
                            for try await event in fallback.stream(input) {
                                continuation.yield(event)
                            }
                            continuation.finish()
                            return
                        } else {
                            throw AgentError.internalError(
                                reason: "Selected agent '\(decision.selectedAgentName)' not found and no fallback configured"
                            )
                        }
                    }

                    // Track execution in context
                    if let context = context {
                        await context.recordExecution(agentName: decision.selectedAgentName)
                    }

                    // Stream from the selected agent
                    for try await event in selectedEntry.agent.stream(input) {
                        continuation.yield(event)
                    }

                    continuation.finish()

                } catch {
                    // If routing fails and we have a fallback, use it
                    if let fallback = fallbackAgent {
                        do {
                            for try await event in fallback.stream(input) {
                                continuation.yield(event)
                            }
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func cancel() async {
        // Cancellation is handled via continuation.onTermination
    }

    // MARK: - Supervisor-Specific Methods

    /// Gets the list of available agents.
    public var availableAgents: [String] {
        agentRegistry.map { $0.name }
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
    /// - Returns: The agent's result.
    /// - Throws: `AgentError.internalError` if agent not found.
    public func executeAgent(named agentName: String, input: String) async throws -> AgentResult {
        guard let entry = agentRegistry.first(where: { $0.name == agentName }) else {
            throw AgentError.internalError(reason: "Agent '\(agentName)' not found")
        }

        return try await entry.agent.run(input)
    }
}

// MARK: - CustomStringConvertible

extension RoutingDecision: CustomStringConvertible {
    public var description: String {
        var desc = "RoutingDecision(agent: \(selectedAgentName), confidence: \(confidence)"
        if let reasoning = reasoning {
            desc += ", reasoning: \(reasoning)"
        }
        desc += ")"
        return desc
    }
}
