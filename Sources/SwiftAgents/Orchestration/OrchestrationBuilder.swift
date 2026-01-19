// OrchestrationBuilder.swift
// SwiftAgents Framework
//
// Declarative DSL for multi-agent workflow orchestration.

import Foundation

// MARK: - OrchestrationStepContext

/// Shared execution context passed to orchestration steps.
public struct OrchestrationStepContext: Sendable {
    /// Shared agent context for the orchestration run.
    public let agentContext: AgentContext

    /// Optional session for conversation history.
    public let session: (any Session)?

    /// Optional run hooks for lifecycle callbacks.
    public let hooks: (any RunHooks)?

    /// The orchestrator running this workflow.
    public let orchestrator: (any Agent)?

    /// The orchestrator name used for handoff metadata.
    public let orchestratorName: String

    /// Handoff configurations applied by the orchestrator.
    public let handoffs: [AnyHandoffConfiguration]

    /// Creates a new orchestration step context.
    public init(
        agentContext: AgentContext,
        session: (any Session)?,
        hooks: (any RunHooks)?,
        orchestrator: (any Agent)?,
        orchestratorName: String,
        handoffs: [AnyHandoffConfiguration]
    ) {
        self.agentContext = agentContext
        self.session = session
        self.hooks = hooks
        self.orchestrator = orchestrator
        self.orchestratorName = orchestratorName
        self.handoffs = handoffs
    }
}

public extension OrchestrationStepContext {
    /// Returns a stable display name for an agent.
    func agentName(for agent: any Agent) -> String {
        let configured = agent.configuration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configured.isEmpty {
            return configured
        }
        return String(describing: type(of: agent))
    }

    /// Finds a handoff configuration for the given target agent.
    func findHandoffConfiguration(for targetAgent: any Agent) -> AnyHandoffConfiguration? {
        handoffs.first { config in
            let configTargetType = type(of: config.targetAgent)
            let currentType = type(of: targetAgent)
            return configTargetType == currentType
        }
    }

    /// Applies handoff configuration for the target agent if present.
    func applyHandoffConfiguration(
        for targetAgent: any Agent,
        input: String,
        targetName: String? = nil
    ) async throws -> String {
        let resolvedName = targetName ?? agentName(for: targetAgent)

        guard let config = findHandoffConfiguration(for: targetAgent) else {
            return input
        }

        if let isEnabled = config.isEnabled {
            let enabled = await isEnabled(agentContext, targetAgent)
            if !enabled {
                throw OrchestrationError.handoffSkipped(
                    from: orchestratorName,
                    to: resolvedName,
                    reason: "Handoff disabled by isEnabled callback"
                )
            }
        }

        var inputData = HandoffInputData(
            sourceAgentName: orchestratorName,
            targetAgentName: resolvedName,
            input: input,
            context: await agentContext.snapshot,
            metadata: [:]
        )

        if let inputFilter = config.inputFilter {
            inputData = inputFilter(inputData)
        }

        if let onHandoff = config.onHandoff {
            do {
                try await onHandoff(agentContext, inputData)
            } catch {
                Log.orchestration.warning(
                    "onHandoff callback failed for \(orchestratorName) -> \(resolvedName): \(error.localizedDescription)"
                )
            }
        }

        return inputData.input
    }
}

// MARK: - OrchestrationStep

/// A step in an orchestrated multi-agent workflow.
///
/// `OrchestrationStep` defines a unit of work within a workflow that can be
/// composed with other steps to create complex agent interactions.
///
/// Built-in steps include:
/// - `AgentStep`: Execute a single agent
/// - `Sequential`: Run steps in sequence
/// - `Parallel`: Run agents in parallel and merge results
/// - `Router`: Route to agents based on conditions
/// - `Transform`: Apply custom transformations
public protocol OrchestrationStep: Sendable {
    /// Executes this step with the given input.
    /// - Parameters:
    ///   - input: The input string to process.
    ///   - context: Shared orchestration context.
    /// - Returns: The result of executing this step.
    /// - Throws: `AgentError` or `OrchestrationError` if execution fails.
    func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult

    /// Executes this step with the given input and hooks (legacy signature).
    func execute(_ input: String, hooks: (any RunHooks)?) async throws -> AgentResult
}

public extension OrchestrationStep {
    func execute(_ input: String, hooks: (any RunHooks)?) async throws -> AgentResult {
        let context = OrchestrationStepContext(
            agentContext: AgentContext(input: input),
            session: nil,
            hooks: hooks,
            orchestrator: nil,
            orchestratorName: "Orchestration",
            handoffs: []
        )
        return try await execute(input, context: context)
    }

    func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        try await execute(input, hooks: context.hooks)
    }
}

// MARK: - OrchestrationBuilder

/// A result builder for constructing orchestrated workflows declaratively.
///
/// `OrchestrationBuilder` enables a SwiftUI-like DSL for composing multi-agent
/// workflows. Use it with `Orchestration` to define complex agent interactions.
///
/// Example:
/// ```swift
/// let workflow = Orchestration {
///     Sequential {
///         preprocessAgent
///         mainAgent
///     }
///
///     Parallel(merge: .concatenate) {
///         ("analysis", analysisAgent)
///         ("summary", summaryAgent)
///     }
/// }
/// ```
@resultBuilder
public struct OrchestrationBuilder {
    /// Builds an array of orchestration steps from multiple components.
    public static func buildBlock(_ components: OrchestrationStep...) -> [OrchestrationStep] {
        components
    }

    /// Builds an array from an optional step.
    public static func buildOptional(_ component: [OrchestrationStep]?) -> [OrchestrationStep] {
        component ?? []
    }

    /// Builds an array from the first branch of a conditional.
    public static func buildEither(first component: [OrchestrationStep]) -> [OrchestrationStep] {
        component
    }

    /// Builds an array from the second branch of a conditional.
    public static func buildEither(second component: [OrchestrationStep]) -> [OrchestrationStep] {
        component
    }

    /// Builds an array from nested arrays (for loops).
    public static func buildArray(_ components: [[OrchestrationStep]]) -> [OrchestrationStep] {
        components.flatMap(\.self)
    }

    /// Converts an agent into an orchestration step.
    public static func buildExpression(_ agent: any Agent) -> OrchestrationStep {
        AgentStep(agent)
    }

    /// Passes through an existing orchestration step.
    public static func buildExpression(_ step: OrchestrationStep) -> OrchestrationStep {
        step
    }
}

// MARK: - AgentStep

/// A step that executes a single agent.
///
/// `AgentStep` wraps an agent for use within an orchestrated workflow.
/// You typically don't create these directly; they're created automatically
/// when you include an agent in an `OrchestrationBuilder` block.
///
/// Example:
/// ```swift
/// Orchestration {
///     myAgent  // Automatically wrapped in AgentStep
///     AgentStep(myAgent, name: "CustomName")  // Explicit with name
/// }
/// ```
public struct AgentStep: OrchestrationStep {
    /// The agent to execute.
    public let agent: any Agent

    /// Optional name for debugging and logging.
    public let name: String?

    /// Creates a new agent step.
    /// - Parameters:
    ///   - agent: The agent to execute.
    ///   - name: Optional name for the step. Default: nil
    public init(_ agent: any Agent, name: String? = nil) {
        self.agent = agent
        self.name = name
    }

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        let agentName = name ?? context.agentName(for: agent)
        await context.agentContext.recordExecution(agentName: agentName)

        let effectiveInput = try await context.applyHandoffConfiguration(
            for: agent,
            input: input,
            targetName: agentName
        )

        if let orchestrator = context.orchestrator {
            await context.hooks?.onHandoff(
                context: context.agentContext,
                fromAgent: orchestrator,
                toAgent: agent
            )
        }

        let result = try await agent.run(
            effectiveInput,
            session: context.session,
            hooks: context.hooks
        )

        await context.agentContext.setPreviousOutput(result)
        return result
    }
}

// MARK: - Sequential

/// A step that executes child steps sequentially, passing output between them.
///
/// `Sequential` runs steps in order, optionally transforming the output
/// of each step before passing it as input to the next step.
///
/// Example:
/// ```swift
/// Sequential {
///     preprocessAgent
///     analysisAgent
///     summaryAgent
/// }
/// ```
///
/// With transformation:
/// ```swift
/// Sequential(transformer: .withMetadata) {
///     agentA
///     agentB
/// }
/// ```
public struct Sequential: OrchestrationStep {
    /// Strategy for transforming output between sequential steps.
    public enum OutputTransformer: Sendable {
        /// Pass the output text directly to the next step (default).
        case passthrough

        /// Include metadata in the output passed to the next step.
        case withMetadata

        /// Apply a custom transformation to the result before passing to the next step.
        case custom(@Sendable (AgentResult) -> String)
    }

    /// The steps to execute sequentially.
    public let steps: [OrchestrationStep]

    /// The transformer to apply between steps.
    public let transformer: OutputTransformer

    /// Creates a new sequential orchestration.
    /// - Parameters:
    ///   - transformer: How to transform output between steps. Default: `.passthrough`
    ///   - content: A builder closure that produces the steps to execute.
    public init(
        transformer: OutputTransformer = .passthrough,
        @OrchestrationBuilder _ content: () -> [OrchestrationStep]
    ) {
        steps = content()
        self.transformer = transformer
    }

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        guard !steps.isEmpty else {
            return AgentResult(output: input)
        }

        let startTime = ContinuousClock.now

        var currentInput = input
        var allToolCalls: [ToolCall] = []
        var allToolResults: [ToolResult] = []
        var totalIterations = 0
        var allMetadata: [String: SendableValue] = [:]

        for (index, step) in steps.enumerated() {
            let result = try await step.execute(currentInput, context: context)

            // Accumulate tool calls and results
            allToolCalls.append(contentsOf: result.toolCalls)
            allToolResults.append(contentsOf: result.toolResults)
            totalIterations += result.iterationCount

            // Merge metadata
            for (key, value) in result.metadata {
                allMetadata["step_\(index)_\(key)"] = value
            }

            // Transform output for next step
            switch transformer {
            case .passthrough:
                currentInput = result.output
            case .withMetadata:
                var metadataString = result.output
                if !result.metadata.isEmpty {
                    metadataString += "\n\nMetadata: \(result.metadata)"
                }
                currentInput = metadataString
            case let .custom(transform):
                currentInput = transform(result)
            }
        }

        let duration = ContinuousClock.now - startTime
        allMetadata["sequential.step_count"] = .int(steps.count)
        allMetadata["sequential.total_duration"] = .double(
            Double(duration.components.seconds) +
                Double(duration.components.attoseconds) / 1e18
        )

        return AgentResult(
            output: currentInput,
            toolCalls: allToolCalls,
            toolResults: allToolResults,
            iterationCount: totalIterations,
            duration: duration,
            tokenUsage: nil,
            metadata: allMetadata
        )
    }
}

// MARK: - Parallel

/// A step that executes multiple agents concurrently and merges their results.
///
/// `Parallel` runs agents simultaneously using structured concurrency,
/// then combines their outputs according to the specified merge strategy.
///
/// Example:
/// ```swift
/// Parallel(merge: .concatenate) {
///     ("analysis", analysisAgent)
///     ("summary", summaryAgent)
///     ("critique", critiqueAgent)
/// }
/// ```
///
/// With concurrency limit:
/// ```swift
/// Parallel(merge: .structured, maxConcurrency: 2) {
///     ("task1", agent1)
///     ("task2", agent2)
///     ("task3", agent3)
/// }
/// ```
public struct Parallel: OrchestrationStep {
    /// Strategy for merging parallel agent results into a single output.
    public enum MergeStrategy: Sendable {
        /// Concatenate all outputs with newlines (default).
        case concatenate

        /// Return the first completed result.
        case first

        /// Return the longest output among all results.
        case longest

        /// Create a structured output with labeled sections.
        case structured

        /// Apply a custom merge function to all named results.
        case custom(@Sendable ([(String, AgentResult)]) -> String)
    }

    /// The named agents to execute in parallel.
    public let agents: [(String, any Agent)]

    /// The strategy for merging results.
    public let mergeStrategy: MergeStrategy

    /// Strategy for handling errors during parallel execution.
    public let errorHandling: ParallelErrorHandling

    /// Optional limit on concurrent executions.
    public let maxConcurrency: Int?

    /// Creates a new parallel orchestration.
    /// - Parameters:
    ///   - merge: How to merge parallel results. Default: `.concatenate`
    ///   - maxConcurrency: Maximum number of concurrent executions. Default: nil (unlimited)
    ///   - errorHandling: Strategy for handling errors. Default: `.continueOnPartialFailure`
    ///   - content: A builder closure that produces named agents to execute.
    public init(
        merge: MergeStrategy = .concatenate,
        maxConcurrency: Int? = nil,
        errorHandling: ParallelErrorHandling = .continueOnPartialFailure,
        @ParallelBuilder _ content: () -> [(String, any Agent)]
    ) {
        agents = content()
        mergeStrategy = merge
        self.maxConcurrency = maxConcurrency
        self.errorHandling = errorHandling
    }

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        guard !agents.isEmpty else {
            return AgentResult(output: input)
        }

        let startTime = ContinuousClock.now

        var results: [(String, AgentResult)] = []
        var errors: [String: Error] = [:]

        let concurrencyLimit = maxConcurrency.map { min($0, agents.count) } ?? agents.count
        var pendingAgents = agents

        await withTaskGroup(of: (String, Result<AgentResult, Error>).self) { group in
            func addTask(name: String, agent: any Agent) {
                group.addTask {
                    do {
                        await context.agentContext.recordExecution(agentName: name)

                        let effectiveInput = try await context.applyHandoffConfiguration(
                            for: agent,
                            input: input,
                            targetName: name
                        )

                        if let orchestrator = context.orchestrator {
                            await context.hooks?.onHandoff(
                                context: context.agentContext,
                                fromAgent: orchestrator,
                                toAgent: agent
                            )
                        }

                        let result = try await agent.run(
                            effectiveInput,
                            session: context.session,
                            hooks: context.hooks
                        )
                        return (name, .success(result))
                    } catch {
                        return (name, .failure(error))
                    }
                }
            }

            let initialCount = min(concurrencyLimit, pendingAgents.count)
            for _ in 0..<initialCount {
                let next = pendingAgents.removeFirst()
                addTask(name: next.0, agent: next.1)
            }

            while let (name, result) = await group.next() {
                switch result {
                case let .success(agentResult):
                    results.append((name, agentResult))
                case let .failure(error):
                    errors[name] = error
                    if case .failFast = errorHandling {
                        group.cancelAll()
                    }
                }

                if case .failFast = errorHandling, !errors.isEmpty {
                    continue
                }

                if !pendingAgents.isEmpty {
                    let next = pendingAgents.removeFirst()
                    addTask(name: next.0, agent: next.1)
                }
            }
        }

        if !errors.isEmpty {
            switch errorHandling {
            case .failFast:
                if let error = errors.values.first {
                    if let agentError = error as? AgentError {
                        throw agentError
                    }
                    throw AgentError.internalError(reason: error.localizedDescription)
                }
            case .continueOnPartialFailure, .collectErrors:
                if results.isEmpty {
                    let messages = errors.values.map { $0.localizedDescription }
                    throw OrchestrationError.allAgentsFailed(errors: messages)
                }
            }
        }

        let duration = ContinuousClock.now - startTime

        // Merge results according to strategy
        let mergedOutput: String
        switch mergeStrategy {
        case .concatenate:
            mergedOutput = results.map { "\($0.0): \($0.1.output)" }.joined(separator: "\n\n")
        case .first:
            mergedOutput = results.first?.1.output ?? ""
        case .longest:
            mergedOutput = results.max(by: { $0.1.output.count < $1.1.output.count })?.1.output ?? ""
        case .structured:
            var output = ""
            for (name, result) in results {
                output += "## \(name)\n\n\(result.output)\n\n"
            }
            mergedOutput = output
        case let .custom(merger):
            mergedOutput = merger(results)
        }

        // Accumulate all tool calls and results
        var allToolCalls: [ToolCall] = []
        var allToolResults: [ToolResult] = []
        var totalIterations = 0
        var allMetadata: [String: SendableValue] = [:]

        for (name, result) in results {
            allToolCalls.append(contentsOf: result.toolCalls)
            allToolResults.append(contentsOf: result.toolResults)
            totalIterations += result.iterationCount

            // Namespace metadata by agent name
            for (key, value) in result.metadata {
                allMetadata["parallel.\(name).\(key)"] = value
            }
        }

        allMetadata["parallel.agent_count"] = .int(agents.count)
        allMetadata["parallel.success_count"] = .int(results.count)
        allMetadata["parallel.error_count"] = .int(errors.count)
        allMetadata["parallel.total_duration"] = .double(
            Double(duration.components.seconds) +
                Double(duration.components.attoseconds) / 1e18
        )
        if !errors.isEmpty {
            let errorMessages = errors.map { "\($0.key): \($0.value.localizedDescription)" }
            allMetadata["parallel.errors"] = .array(errorMessages.map { .string($0) })
        }

        return AgentResult(
            output: mergedOutput,
            toolCalls: allToolCalls,
            toolResults: allToolResults,
            iterationCount: totalIterations,
            duration: duration,
            tokenUsage: nil,
            metadata: allMetadata
        )
    }
}

// MARK: - ParallelBuilder

/// A result builder for constructing parallel agent arrays.
@resultBuilder
public struct ParallelBuilder {
    /// Builds an array of named agents from multiple components.
    public static func buildBlock(_ components: (String, any Agent)...) -> [(String, any Agent)] {
        components
    }

    /// Passes through a tuple of name and agent.
    public static func buildExpression(_ tuple: (String, any Agent)) -> (String, any Agent) {
        tuple
    }
}

// MARK: - Router

/// A step that routes input to different agents based on conditions.
///
/// `Router` evaluates conditions in order and delegates to the first
/// matching agent. If no condition matches and a fallback is provided,
/// the fallback agent is executed.
///
/// Example:
/// ```swift
/// Router(fallback: defaultAgent) {
///     Route(.contains("weather"), to: weatherAgent)
///     Route(.contains("code"), to: codeAgent)
///     Route(.startsWith("calculate"), to: calculatorAgent)
/// }
/// ```
public struct Router: OrchestrationStep {
    /// The routes to evaluate in order.
    public let routes: [RouteDefinition]

    /// Optional fallback agent when no route matches.
    public let fallbackAgent: (any Agent)?

    /// Creates a new router.
    /// - Parameters:
    ///   - fallback: Optional agent to use when no route matches. Default: nil
    ///   - content: A builder closure that produces route definitions.
    public init(
        fallback: (any Agent)? = nil,
        @RouterBuilder _ content: () -> [RouteDefinition]
    ) {
        routes = content()
        fallbackAgent = fallback
    }

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        let startTime = ContinuousClock.now

        // Find the first matching route
        var selectedRoute: RouteDefinition?
        for route in routes where await route.condition.matches(input: input, context: context.agentContext) {
            selectedRoute = route
            break
        }

        // Execute matched agent or fallback
        let result: AgentResult
        let routeName: String

        if let route = selectedRoute {
            let agentName = context.agentName(for: route.agent)
            await context.agentContext.recordExecution(agentName: agentName)

            let effectiveInput = try await context.applyHandoffConfiguration(
                for: route.agent,
                input: input,
                targetName: route.name ?? agentName
            )

            if let orchestrator = context.orchestrator {
                await context.hooks?.onHandoff(
                    context: context.agentContext,
                    fromAgent: orchestrator,
                    toAgent: route.agent
                )
            }

            result = try await route.agent.run(
                effectiveInput,
                session: context.session,
                hooks: context.hooks
            )
            routeName = route.name ?? agentName
        } else if let fallback = fallbackAgent {
            let fallbackName = context.agentName(for: fallback)
            await context.agentContext.recordExecution(agentName: fallbackName)

            let effectiveInput = try await context.applyHandoffConfiguration(
                for: fallback,
                input: input,
                targetName: fallbackName
            )

            if let orchestrator = context.orchestrator {
                await context.hooks?.onHandoff(
                    context: context.agentContext,
                    fromAgent: orchestrator,
                    toAgent: fallback
                )
            }

            result = try await fallback.run(
                effectiveInput,
                session: context.session,
                hooks: context.hooks
            )
            routeName = "fallback"
        } else {
            throw OrchestrationError.routingFailed(
                reason: "No route matched input and no fallback agent configured"
            )
        }

        // Add routing metadata
        let duration = ContinuousClock.now - startTime
        var metadata = result.metadata
        metadata["router.matched_route"] = .string(routeName)
        metadata["router.total_routes"] = .int(routes.count)
        metadata["router.duration"] = .double(
            Double(duration.components.seconds) +
                Double(duration.components.attoseconds) / 1e18
        )

        return AgentResult(
            output: result.output,
            toolCalls: result.toolCalls,
            toolResults: result.toolResults,
            iterationCount: result.iterationCount,
            duration: result.duration,
            tokenUsage: result.tokenUsage,
            metadata: metadata
        )
    }
}

// MARK: - RouteDefinition

/// A route definition that associates a condition with an agent.
///
/// Use the `Route(_:to:)` function to create route definitions within
/// a `Router` builder block.
public struct RouteDefinition: Sendable {
    /// The condition that determines if this route matches.
    public let condition: RouteCondition

    /// The agent to execute if this route matches.
    public let agent: any Agent

    /// Optional name for debugging and logging.
    public let name: String?

    /// Creates a new route definition.
    /// - Parameters:
    ///   - condition: The condition for this route.
    ///   - agent: The agent to execute if matched.
    ///   - name: Optional name for the route. Default: nil
    public init(condition: RouteCondition, agent: any Agent, name: String? = nil) {
        self.condition = condition
        self.agent = agent
        self.name = name
    }
}

/// Creates a route definition for use in a `Router` builder.
///
/// - Parameters:
///   - condition: The condition that must match for this route.
///   - agent: The agent to execute if the condition matches.
/// - Returns: A route definition.
///
/// Example:
/// ```swift
/// orchestrationRoute(.contains("weather"), to: weatherAgent)
/// ```
public func orchestrationRoute(_ condition: RouteCondition, to agent: @escaping @autoclosure () -> any Agent) -> RouteDefinition {
    RouteDefinition(condition: condition, agent: agent())
}

/// Convenience alias for creating a route definition.
/// - Note: Use this within an OrchestrationBuilder Router context.
public func routeWhen(_ condition: RouteCondition, to agent: @escaping @autoclosure () -> any Agent) -> RouteDefinition {
    RouteDefinition(condition: condition, agent: agent())
}

// MARK: - RouterBuilder

/// A result builder for constructing route arrays.
@resultBuilder
public struct RouterBuilder {
    /// Builds an array of routes from multiple components.
    public static func buildBlock(_ components: RouteDefinition...) -> [RouteDefinition] {
        components
    }

    /// Builds an array from an optional route.
    public static func buildOptional(_ component: RouteDefinition?) -> [RouteDefinition] {
        component.map { [$0] } ?? []
    }

    /// Builds an array from the first branch of a conditional.
    public static func buildEither(first component: RouteDefinition) -> [RouteDefinition] {
        [component]
    }

    /// Builds an array from the second branch of a conditional.
    public static func buildEither(second component: RouteDefinition) -> [RouteDefinition] {
        [component]
    }

    /// Builds an array from nested arrays.
    public static func buildArray(_ components: [[RouteDefinition]]) -> [RouteDefinition] {
        components.flatMap(\.self)
    }

    /// Passes through a route definition.
    public static func buildExpression(_ route: RouteDefinition) -> RouteDefinition {
        route
    }
}

// MARK: - Transform

/// A step that applies a custom transformation to the input or result.
///
/// `Transform` allows you to inject custom processing logic into an
/// orchestration workflow.
///
/// Example:
/// ```swift
/// Transform { result in
///     "Processed: \(result.output.uppercased())"
/// }
/// ```
public struct Transform: OrchestrationStep {
    /// The transformation function to apply.
    public let transformer: @Sendable (String) async throws -> String

    /// Creates a new transform step.
    /// - Parameter transformer: A closure that transforms the input string.
    public init(_ transformer: @escaping @Sendable (String) async throws -> String) {
        self.transformer = transformer
    }

    public func execute(_ input: String, context _: OrchestrationStepContext) async throws -> AgentResult {
        let startTime = ContinuousClock.now
        let output = try await transformer(input)
        let duration = ContinuousClock.now - startTime

        return AgentResult(
            output: output,
            toolCalls: [],
            toolResults: [],
            iterationCount: 1,
            duration: duration,
            tokenUsage: nil,
            metadata: [
                "transform.duration": .double(
                    Double(duration.components.seconds) +
                        Double(duration.components.attoseconds) / 1e18
                )
            ]
        )
    }
}

// MARK: - Orchestration

/// A complete orchestrated workflow composed of multiple steps.
///
/// `Orchestration` is the top-level container for declaratively defining
/// multi-agent workflows using a SwiftUI-like DSL.
///
/// Example:
/// ```swift
/// let workflow = Orchestration {
///     Sequential {
///         preprocessAgent
///         mainAgent
///     }
///
///     Parallel(merge: .concatenate) {
///         ("analysis", analysisAgent)
///         ("summary", summaryAgent)
///     }
///
///     Router(fallback: defaultAgent) {
///         Route(.contains("weather"), to: weatherAgent)
///         Route(.contains("code"), to: codeAgent)
///     }
/// }
///
/// let result = try await workflow.run("Process this data")
/// ```
public struct Orchestration: Sendable, OrchestratorProtocol {
    /// The steps in this orchestration.
    public let steps: [OrchestrationStep]

    /// Configuration for this orchestration agent.
    public let configuration: AgentConfiguration

    /// Handoff configurations applied to sub-agents.
    public let handoffs: [AnyHandoffConfiguration]

    // MARK: - Agent Protocol Properties

    public var tools: [any AnyJSONTool] { [] }

    public var instructions: String {
        "Orchestration workflow with \(steps.count) steps"
    }

    public var memory: (any Memory)? { nil }

    public var inferenceProvider: (any InferenceProvider)? { nil }

    public var tracer: (any Tracer)? { nil }

    /// Creates a new orchestration.
    /// - Parameters:
    ///   - configuration: Agent configuration for this orchestration. Default: `.default`
    ///   - handoffs: Handoff configurations for sub-agents. Default: []
    ///   - content: A builder closure that produces the orchestration steps.
    public init(
        configuration: AgentConfiguration = .default,
        handoffs: [AnyHandoffConfiguration] = [],
        @OrchestrationBuilder _ content: () -> [OrchestrationStep]
    ) {
        steps = content()
        self.configuration = configuration
        self.handoffs = handoffs
    }

    // MARK: - Agent Protocol Methods

    public func run(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        try await executeSteps(
            input: input,
            session: session,
            hooks: hooks,
            onIterationStart: nil,
            onIterationEnd: nil
        )
    }

    public func stream(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            do {
                let result = try await executeSteps(
                    input: input,
                    session: session,
                    hooks: hooks,
                    onIterationStart: { iteration in
                        continuation.yield(.iterationStarted(number: iteration))
                    },
                    onIterationEnd: { iteration in
                        continuation.yield(.iterationCompleted(number: iteration))
                    }
                )
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

    public func cancel() async {
        for agent in collectAgents(from: steps) {
            await agent.cancel()
        }
    }

    // MARK: - Private Helpers

    private func executeSteps(
        input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?,
        onIterationStart: ((Int) -> Void)?,
        onIterationEnd: ((Int) -> Void)?
    ) async throws -> AgentResult {
        guard !steps.isEmpty else {
            return AgentResult(output: input)
        }

        let startTime = ContinuousClock.now
        let context = AgentContext(input: input)
        let stepContext = OrchestrationStepContext(
            agentContext: context,
            session: session,
            hooks: hooks,
            orchestrator: self,
            orchestratorName: orchestratorName,
            handoffs: handoffs
        )
        await context.recordExecution(agentName: orchestratorName)

        var currentInput = input
        var allToolCalls: [ToolCall] = []
        var allToolResults: [ToolResult] = []
        var totalIterations = 0
        var allMetadata: [String: SendableValue] = [:]

        for (index, step) in steps.enumerated() {
            if Task.isCancelled {
                throw AgentError.cancelled
            }

            onIterationStart?(index + 1)

            let result = try await step.execute(currentInput, context: stepContext)

            allToolCalls.append(contentsOf: result.toolCalls)
            allToolResults.append(contentsOf: result.toolResults)
            totalIterations += result.iterationCount

            for (key, value) in result.metadata {
                allMetadata["orchestration.step_\(index).\(key)"] = value
            }

            await context.setPreviousOutput(result)
            currentInput = result.output

            onIterationEnd?(index + 1)
        }

        let duration = ContinuousClock.now - startTime
        allMetadata["orchestration.total_steps"] = .int(steps.count)
        allMetadata["orchestration.total_duration"] = .double(
            Double(duration.components.seconds) +
                Double(duration.components.attoseconds) / 1e18
        )

        return AgentResult(
            output: currentInput,
            toolCalls: allToolCalls,
            toolResults: allToolResults,
            iterationCount: totalIterations,
            duration: duration,
            tokenUsage: nil,
            metadata: allMetadata
        )
    }

    private func collectAgents(from steps: [OrchestrationStep]) -> [any Agent] {
        steps.flatMap { step in
            if let agentStep = step as? AgentStep {
                return [agentStep.agent]
            }
            if let sequential = step as? Sequential {
                return collectAgents(from: sequential.steps)
            }
            if let parallel = step as? Parallel {
                return parallel.agents.map(\.1)
            }
            if let router = step as? Router {
                let routeAgents = router.routes.map(\.agent)
                if let fallback = router.fallbackAgent {
                    return routeAgents + [fallback]
                }
                return routeAgents
            }
            return []
        }
    }
}

// MARK: - Agent Extension

public extension Agent {
    /// Returns a tuple of the agent name and the agent itself for use in parallel execution.
    ///
    /// - Parameter name: The name to associate with this agent.
    /// - Returns: A tuple of the name and agent.
    ///
    /// Example:
    /// ```swift
    /// Parallel {
    ///     myAgent.named("analyzer")
    ///     otherAgent.named("summarizer")
    /// }
    /// ```
    func named(_ name: String) -> (String, any Agent) {
        (name, self)
    }
}
