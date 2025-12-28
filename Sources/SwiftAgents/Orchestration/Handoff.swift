// Handoff.swift
// SwiftAgents Framework
//
// Agent handoff system for multi-agent orchestration.

import Foundation

// MARK: - HandoffRequest

/// A request to transfer execution from one agent to another.
///
/// HandoffRequest encapsulates all information needed to hand off
/// control from a source agent to a target agent, including the
/// input for the target and any contextual information.
///
/// Example:
/// ```swift
/// let request = HandoffRequest(
///     sourceAgentName: "planner",
///     targetAgentName: "executor",
///     input: "Execute step 1: Fetch data",
///     reason: "Planning complete, ready to execute",
///     context: [
///         "plan_id": .string("plan-123"),
///         "step": .int(1)
///     ]
/// )
/// ```
public struct HandoffRequest: Sendable {
    /// The name of the agent initiating the handoff.
    public let sourceAgentName: String

    /// The name of the agent receiving the handoff.
    public let targetAgentName: String

    /// The input to provide to the target agent.
    public let input: String

    /// Optional reason explaining why the handoff is happening.
    public let reason: String?

    /// Additional context to transfer to the target agent.
    public let context: [String: SendableValue]

    /// Creates a new handoff request.
    ///
    /// - Parameters:
    ///   - sourceAgentName: The agent initiating the handoff.
    ///   - targetAgentName: The agent receiving the handoff.
    ///   - input: The input for the target agent.
    ///   - reason: Optional reason for the handoff. Default: nil
    ///   - context: Additional context to transfer. Default: [:]
    public init(
        sourceAgentName: String,
        targetAgentName: String,
        input: String,
        reason: String? = nil,
        context: [String: SendableValue] = [:]
    ) {
        self.sourceAgentName = sourceAgentName
        self.targetAgentName = targetAgentName
        self.input = input
        self.reason = reason
        self.context = context
    }
}

// MARK: - HandoffResult

/// The result of a completed agent handoff.
///
/// HandoffResult captures the outcome of transferring execution
/// from one agent to another, including the target agent's result
/// and metadata about the handoff.
///
/// Example:
/// ```swift
/// let result = try await coordinator.executeHandoff(request, context: context)
/// print("Target: \(result.targetAgentName)")
/// print("Output: \(result.result.output)")
/// print("Context transferred: \(result.transferredContext)")
/// ```
public struct HandoffResult: Sendable, Equatable {
    /// The name of the agent that received the handoff.
    public let targetAgentName: String

    /// The input that was provided to the target agent.
    public let input: String

    /// The result from the target agent's execution.
    public let result: AgentResult

    /// Context that was transferred to the target agent.
    public let transferredContext: [String: SendableValue]

    /// When the handoff was completed.
    public let timestamp: Date

    /// Creates a new handoff result.
    ///
    /// - Parameters:
    ///   - targetAgentName: The agent that received the handoff.
    ///   - input: The input provided to the target.
    ///   - result: The target agent's execution result.
    ///   - transferredContext: Context that was transferred.
    ///   - timestamp: When the handoff completed. Default: now
    public init(
        targetAgentName: String,
        input: String,
        result: AgentResult,
        transferredContext: [String: SendableValue],
        timestamp: Date = Date()
    ) {
        self.targetAgentName = targetAgentName
        self.input = input
        self.result = result
        self.transferredContext = transferredContext
        self.timestamp = timestamp
    }
}

// MARK: - HandoffReceiver

/// A protocol for agents that can receive handoffs from other agents.
///
/// Agents conforming to this protocol gain the ability to handle
/// control being transferred to them by other agents, including
/// receiving context and input from the source agent.
///
/// This protocol extends `Agent`, adding specialized handoff handling
/// while maintaining compatibility with standard agent execution.
///
/// Example:
/// ```swift
/// struct ExecutorAgent: Agent, HandoffReceiver {
///     let tools: [any Tool] = []
///     let instructions = "Execute tasks"
///     let configuration = AgentConfiguration.default
///
///     func run(_ input: String) async throws -> AgentResult {
///         // Standard execution
///         return AgentResult(output: "Executed: \(input)")
///     }
///
///     func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
///         // Standard streaming
///         AsyncThrowingStream { continuation in
///             continuation.finish()
///         }
///     }
///
///     func cancel() async {
///         // Standard cancellation
///     }
///
///     // HandoffReceiver can use the default implementation
/// }
/// ```
public protocol HandoffReceiver: Agent {
    /// Handles a handoff from another agent.
    ///
    /// This method is called when another agent transfers control
    /// to this agent. It receives the handoff request and the
    /// orchestration context.
    ///
    /// The default implementation merges the handoff context into
    /// the orchestration context and executes the agent normally.
    ///
    /// - Parameters:
    ///   - request: The handoff request containing input and context.
    ///   - context: The shared orchestration context.
    /// - Returns: The result of handling the handoff.
    /// - Throws: `AgentError` if execution fails.
    func handleHandoff(
        _ request: HandoffRequest,
        context: AgentContext
    ) async throws -> AgentResult
}

// MARK: - HandoffReceiver Default Implementation

public extension HandoffReceiver {
    /// Default implementation of handoff handling.
    ///
    /// This implementation:
    /// 1. Merges the handoff context into the orchestration context
    /// 2. Records the handoff in the execution path
    /// 3. Executes the agent with the provided input
    ///
    /// Override this method to provide custom handoff behavior.
    ///
    /// - Parameters:
    ///   - request: The handoff request.
    ///   - context: The shared orchestration context.
    /// - Returns: The agent's execution result.
    /// - Throws: `AgentError` if execution fails.
    func handleHandoff(
        _ request: HandoffRequest,
        context: AgentContext
    ) async throws -> AgentResult {
        // Merge handoff context into orchestration context
        for (key, value) in request.context {
            await context.set(key, value: value)
        }

        // Record the handoff source in context
        await context.set(
            "handoff_source",
            value: .string(request.sourceAgentName)
        )

        if let reason = request.reason {
            await context.set("handoff_reason", value: .string(reason))
        }

        // Record this agent's execution
        await context.recordExecution(agentName: request.targetAgentName)

        // Execute the agent normally
        return try await run(request.input)
    }
}

// MARK: - HandoffCoordinator

/// Coordinates agent handoffs in a multi-agent system.
///
/// HandoffCoordinator manages a registry of agents and facilitates
/// transferring execution from one agent to another. It ensures
/// thread-safe access to agents and handles context propagation
/// during handoffs.
///
/// Example:
/// ```swift
/// let coordinator = HandoffCoordinator()
///
/// // Register agents
/// await coordinator.register(plannerAgent, as: "planner")
/// await coordinator.register(executorAgent, as: "executor")
///
/// // Execute a handoff
/// let request = HandoffRequest(
///     sourceAgentName: "planner",
///     targetAgentName: "executor",
///     input: "Execute task",
///     context: ["plan_id": .string("123")]
/// )
/// let result = try await coordinator.executeHandoff(request, context: context)
/// print(result.result.output)
/// ```
public actor HandoffCoordinator {
    // MARK: Public

    /// Returns the names of all registered agents.
    ///
    /// - Returns: Array of agent names in no particular order.
    public var registeredAgents: [String] {
        Array(agents.keys)
    }

    // MARK: - Initialization

    /// Creates a new handoff coordinator.
    public init() {}

    // MARK: - Agent Registration

    /// Registers an agent with a specific name.
    ///
    /// The name is used to identify the agent in handoff requests.
    /// If an agent with the same name already exists, it will be replaced.
    ///
    /// - Parameters:
    ///   - agent: The agent to register.
    ///   - name: The name to register the agent under.
    public func register(_ agent: any Agent, as name: String) {
        agents[name] = agent
    }

    /// Unregisters an agent by name.
    ///
    /// - Parameter name: The name of the agent to unregister.
    public func unregister(_ name: String) {
        agents.removeValue(forKey: name)
    }

    /// Retrieves an agent by name.
    ///
    /// - Parameter name: The name of the agent to retrieve.
    /// - Returns: The agent, or nil if not found.
    public func agent(named name: String) -> (any Agent)? {
        agents[name]
    }

    // MARK: - Handoff Execution

    /// Executes a handoff from one agent to another.
    ///
    /// This method:
    /// 1. Looks up the target agent by name
    /// 2. If the target implements `HandoffReceiver`, calls its `handleHandoff` method
    /// 3. Otherwise, executes the target agent normally with the handoff input
    /// 4. Returns a `HandoffResult` with the outcome
    ///
    /// - Parameters:
    ///   - request: The handoff request specifying source, target, and context.
    ///   - context: The shared orchestration context.
    /// - Returns: The result of the handoff.
    /// - Throws: `OrchestrationError.agentNotFound` if the target agent is not registered,
    ///           or `AgentError` if the target agent's execution fails.
    ///
    /// Example:
    /// ```swift
    /// let request = HandoffRequest(
    ///     sourceAgentName: "planner",
    ///     targetAgentName: "executor",
    ///     input: "Execute plan step 1"
    /// )
    /// let result = try await coordinator.executeHandoff(request, context: context)
    /// ```
    public func executeHandoff(
        _ request: HandoffRequest,
        context: AgentContext
    ) async throws -> HandoffResult {
        // Look up the target agent
        guard let targetAgent = agents[request.targetAgentName] else {
            throw OrchestrationError.agentNotFound(name: request.targetAgentName)
        }

        // Execute handoff based on agent capabilities
        let result: AgentResult

        if let handoffReceiver = targetAgent as? HandoffReceiver {
            // Agent implements HandoffReceiver, use specialized handling
            result = try await handoffReceiver.handleHandoff(request, context: context)
        } else {
            // Agent doesn't implement HandoffReceiver, use standard execution
            // Merge context manually
            for (key, value) in request.context {
                await context.set(key, value: value)
            }

            // Record execution
            await context.recordExecution(agentName: request.targetAgentName)

            // Execute normally
            result = try await targetAgent.run(request.input)
        }

        // Store the result in context
        await context.setPreviousOutput(result)

        // Create and return handoff result
        return HandoffResult(
            targetAgentName: request.targetAgentName,
            input: request.input,
            result: result,
            transferredContext: request.context,
            timestamp: Date()
        )
    }

    /// Executes a handoff with configuration callbacks.
    ///
    /// This method extends the basic handoff with support for:
    /// - Dynamic enablement checks via `isEnabled` callback
    /// - Input transformation via `inputFilter` callback
    /// - Pre-handoff notification via `onHandoff` callback
    /// - Integration with `RunHooks` for observability
    ///
    /// - Parameters:
    ///   - request: The handoff request specifying source, target, and context.
    ///   - context: The shared orchestration context.
    ///   - configuration: Optional handoff configuration with callbacks.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: The result of the handoff.
    /// - Throws: `OrchestrationError.agentNotFound` if the target agent is not registered,
    ///           `OrchestrationError.handoffSkipped` if the handoff is disabled,
    ///           or `AgentError` if the target agent's execution fails.
    ///
    /// Example:
    /// ```swift
    /// let config = handoff(
    ///     to: executorAgent,
    ///     onHandoff: { context, data in
    ///         Log.agents.info("Handoff: \(data.sourceAgentName) -> \(data.targetAgentName)")
    ///     },
    ///     isEnabled: { context, agent in
    ///         await context.get("ready")?.boolValue ?? false
    ///     }
    /// )
    /// let result = try await coordinator.executeHandoff(
    ///     request,
    ///     context: context,
    ///     configuration: AnyHandoffConfiguration(config),
    ///     hooks: myHooks
    /// )
    /// ```
    public func executeHandoff(
        _ request: HandoffRequest,
        context: AgentContext,
        configuration: AnyHandoffConfiguration?,
        hooks: (any RunHooks)?
    ) async throws -> HandoffResult {
        // Look up the target agent
        guard let targetAgent = agents[request.targetAgentName] else {
            throw OrchestrationError.agentNotFound(name: request.targetAgentName)
        }

        // Process configuration callbacks if provided
        var effectiveInput = request.input
        var effectiveContext = request.context

        if let config = configuration {
            // Check if handoff is enabled
            if let isEnabled = config.isEnabled {
                let enabled = await isEnabled(context, targetAgent)
                if !enabled {
                    Log.orchestration.info(
                        "Handoff skipped: \(request.sourceAgentName) -> \(request.targetAgentName) (disabled by isEnabled callback)"
                    )
                    throw OrchestrationError.handoffSkipped(
                        from: request.sourceAgentName,
                        to: request.targetAgentName,
                        reason: "Handoff disabled by isEnabled callback"
                    )
                }
            }

            // Create HandoffInputData for callbacks
            var inputData = HandoffInputData(
                sourceAgentName: request.sourceAgentName,
                targetAgentName: request.targetAgentName,
                input: request.input,
                context: request.context,
                metadata: [:]
            )

            // Apply input filter if present
            if let inputFilter = config.inputFilter {
                inputData = inputFilter(inputData)
            }

            // Call onHandoff callback if present
            if let onHandoff = config.onHandoff {
                do {
                    try await onHandoff(context, inputData)
                } catch {
                    // Log callback errors but don't fail the handoff
                    Log.orchestration.warning(
                        "onHandoff callback failed for \(request.sourceAgentName) -> \(request.targetAgentName): \(error.localizedDescription)"
                    )
                }
            }

            // Use potentially modified input from filter
            effectiveInput = inputData.input

            // Merge filter metadata into context
            for (key, value) in inputData.metadata {
                effectiveContext[key] = value
            }
        }

        // Invoke RunHooks.onHandoff if hooks provided
        if let hooks, let sourceAgent = agents[request.sourceAgentName] {
            await hooks.onHandoff(context: context, fromAgent: sourceAgent, toAgent: targetAgent)
        }

        // Execute handoff based on agent capabilities
        let result: AgentResult

        // Create modified request with effective values
        let effectiveRequest = HandoffRequest(
            sourceAgentName: request.sourceAgentName,
            targetAgentName: request.targetAgentName,
            input: effectiveInput,
            reason: request.reason,
            context: effectiveContext
        )

        if let handoffReceiver = targetAgent as? HandoffReceiver {
            // Agent implements HandoffReceiver, use specialized handling
            result = try await handoffReceiver.handleHandoff(effectiveRequest, context: context)
        } else {
            // Agent doesn't implement HandoffReceiver, use standard execution
            // Merge context manually
            for (key, value) in effectiveContext {
                await context.set(key, value: value)
            }

            // Record execution
            await context.recordExecution(agentName: request.targetAgentName)

            // Execute normally
            result = try await targetAgent.run(effectiveInput)
        }

        // Store the result in context
        await context.setPreviousOutput(result)

        // Create and return handoff result
        return HandoffResult(
            targetAgentName: request.targetAgentName,
            input: effectiveInput,
            result: result,
            transferredContext: effectiveContext,
            timestamp: Date()
        )
    }

    // MARK: Private

    // MARK: - Private Storage

    /// Registry of agents by name.
    private var agents: [String: any Agent] = [:]
}

// MARK: - HandoffRequest + CustomStringConvertible

extension HandoffRequest: CustomStringConvertible {
    public var description: String {
        """
        HandoffRequest(
            from: "\(sourceAgentName)",
            to: "\(targetAgentName)",
            input: "\(input.prefix(50))\(input.count > 50 ? "..." : "")",
            reason: \(reason ?? "none")
        )
        """
    }
}

// MARK: - HandoffResult + CustomStringConvertible

extension HandoffResult: CustomStringConvertible {
    public var description: String {
        """
        HandoffResult(
            target: "\(targetAgentName)",
            output: "\(result.output.prefix(50))\(result.output.count > 50 ? "..." : "")",
            timestamp: \(timestamp)
        )
        """
    }
}
