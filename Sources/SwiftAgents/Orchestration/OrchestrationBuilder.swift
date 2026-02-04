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
    public let orchestrator: (any AgentRuntime)?

    /// The orchestrator name used for handoff metadata.
    public let orchestratorName: String

    /// Handoff configurations applied by the orchestrator.
    public let handoffs: [AnyHandoffConfiguration]

    /// Creates a new orchestration step context.
    public init(
        agentContext: AgentContext,
        session: (any Session)?,
        hooks: (any RunHooks)?,
        orchestrator: (any AgentRuntime)?,
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
    func agentName(for agent: any AgentRuntime) -> String {
        let configured = agent.configuration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configured.isEmpty {
            return configured
        }
        return String(describing: type(of: agent))
    }

    /// Finds a handoff configuration for the given target agent.
    func findHandoffConfiguration(for targetAgent: any AgentRuntime) -> AnyHandoffConfiguration? {
        handoffs.first { config in
            let configTargetType = type(of: config.targetAgent)
            let currentType = type(of: targetAgent)
            return configTargetType == currentType
        }
    }

    /// Applies handoff configuration for the target agent if present.
    func applyHandoffConfiguration(
        for targetAgent: any AgentRuntime,
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

// MARK: - OrchestrationGroup

/// A step that executes a group of orchestration steps sequentially.
///
/// `OrchestrationGroup` is produced by `OrchestrationBuilder` when multiple
/// statements are present, preserving SwiftUI-style composition while
/// keeping a single root step.
public struct OrchestrationGroup: OrchestrationStep, Sendable {
    public let steps: [OrchestrationStep]

    public init(steps: [OrchestrationStep]) {
        self.steps = steps
    }

    public init(@OrchestrationBuilder _ content: () -> OrchestrationStep) {
        steps = OrchestrationBuilder.steps(from: content())
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

            allToolCalls.append(contentsOf: result.toolCalls)
            allToolResults.append(contentsOf: result.toolResults)
            totalIterations += result.iterationCount

            for (key, value) in result.metadata {
                allMetadata[key] = value
                allMetadata["group.step_\(index).\(key)"] = value
            }

            currentInput = result.output
        }

        let duration = ContinuousClock.now - startTime
        allMetadata["group.total_steps"] = .int(steps.count)
        allMetadata["group.total_duration"] = .double(
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

extension OrchestrationGroup: _AgentLoopNestedSteps {
    var _nestedSteps: [OrchestrationStep] { steps }
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
///         analysisAgent.named("analysis")
///         summaryAgent.named("summary")
///     }
///
///     Router {
///         When(.contains("weather")) { weatherAgent }
///         Otherwise { defaultAgent }
///     }
/// }
/// ```
@resultBuilder
public struct OrchestrationBuilder {
    /// Builds a group of orchestration steps from multiple components.
    public static func buildBlock(_ components: OrchestrationStep...) -> OrchestrationGroup {
        OrchestrationGroup(steps: components.flatMap(steps(from:)))
    }

    /// Builds an empty block.
    public static func buildBlock() -> OrchestrationGroup {
        OrchestrationGroup(steps: [])
    }

    /// Builds a group from an optional step.
    public static func buildOptional(_ component: OrchestrationStep?) -> OrchestrationGroup {
        OrchestrationGroup(steps: component.map { steps(from: $0) } ?? [])
    }

    /// Builds a group from the first branch of a conditional.
    public static func buildEither(first component: OrchestrationStep) -> OrchestrationGroup {
        OrchestrationGroup(steps: steps(from: component))
    }

    /// Builds a group from the second branch of a conditional.
    public static func buildEither(second component: OrchestrationStep) -> OrchestrationGroup {
        OrchestrationGroup(steps: steps(from: component))
    }

    /// Builds a group from nested arrays (for loops).
    public static func buildArray(_ components: [OrchestrationStep]) -> OrchestrationGroup {
        OrchestrationGroup(steps: components.flatMap(steps(from:)))
    }

    /// Converts an agent into an orchestration step.
    public static func buildExpression(_ agent: any AgentRuntime) -> OrchestrationStep {
        AgentStep(agent)
    }

    /// Converts an `AgentBlueprint` into an orchestration step.
    public static func buildExpression<B: AgentBlueprint>(_ blueprint: B) -> OrchestrationStep {
        AgentStep(BlueprintAgent(blueprint))
    }

    /// Converts a legacy loop DSL definition into an orchestration step.
    @available(
        *,
        deprecated,
        message: "Deprecated legacy loop DSL. Prefer AgentBlueprint for orchestration; embed runtime AgentRuntime steps for model turns instead of Generate()/Relay()."
    )
    public static func buildExpression<A: AgentLoopDefinition>(_ agent: A) -> OrchestrationStep {
        LoopAgentStep(agent)
    }

    /// Passes through an existing orchestration step.
    public static func buildExpression(_ step: OrchestrationStep) -> OrchestrationStep {
        step
    }

    /// Converts an array of steps into a group.
    public static func buildExpression(_ steps: [OrchestrationStep]) -> OrchestrationStep {
        OrchestrationGroup(steps: steps)
    }

    fileprivate static func steps(from step: OrchestrationStep) -> [OrchestrationStep] {
        if let group = step as? OrchestrationGroup {
            return group.steps
        }
        return [step]
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
    public let agent: any AgentRuntime

    /// Optional name for debugging and logging.
    public let name: String?

    /// Creates a new agent step.
    /// - Parameters:
    ///   - agent: The agent to execute.
    ///   - name: Optional name for the step. Default: nil
    public init(_ agent: any AgentRuntime, name: String? = nil) {
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
        @OrchestrationBuilder _ content: () -> OrchestrationStep
    ) {
        steps = OrchestrationBuilder.steps(from: content())
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

/// An item representing an agent in a parallel execution group.
public struct ParallelItem: Sendable {
    public let name: String?
    public let agent: any AgentRuntime

    public init(name: String? = nil, agent: any AgentRuntime) {
        self.name = name
        self.agent = agent
    }
}

public extension AgentRuntime {
    /// Assigns a name to an agent for use in `Parallel`.
    func named(_ name: String) -> ParallelItem {
        ParallelItem(name: name, agent: self)
    }
}

public extension AgentBlueprint {
    /// Assigns a name to a blueprint when used in `Parallel`.
    func named(_ name: String) -> ParallelItem {
        ParallelItem(name: name, agent: BlueprintAgent(self))
    }
}

/// A step that executes multiple agents concurrently and merges their results.
///
/// `Parallel` runs agents simultaneously using structured concurrency,
/// then combines their outputs according to the specified merge strategy.
///
/// Example:
/// ```swift
/// Parallel(merge: .concatenate) {
///     analysisAgent.named("analysis")
///     summaryAgent.named("summary")
///     critiqueAgent.named("critique")
/// }
/// ```
///
/// With concurrency limit:
/// ```swift
/// Parallel(merge: .structured, maxConcurrency: 2) {
///     agent1.named("task1")
///     agent2.named("task2")
///     agent3.named("task3")
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

    /// The items to execute in parallel.
    public let items: [ParallelItem]

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
    ///   - content: A builder closure that produces parallel items to execute.
    public init(
        merge: MergeStrategy = .concatenate,
        maxConcurrency: Int? = nil,
        errorHandling: ParallelErrorHandling = .continueOnPartialFailure,
        @ParallelBuilder _ content: () -> [ParallelItem]
    ) {
        items = content()
        mergeStrategy = merge
        self.maxConcurrency = maxConcurrency
        self.errorHandling = errorHandling
    }

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        guard !items.isEmpty else {
            return AgentResult(output: input)
        }

        let startTime = ContinuousClock.now

        var results: [(Int, String, AgentResult)] = []
        var errors: [String: Error] = [:]

        let namedItems = items.enumerated().map { index, item in
            let resolvedName = item.name ?? context.agentName(for: item.agent)
            return (index, resolvedName, item.agent)
        }
        let concurrencyLimit = maxConcurrency.map { min($0, namedItems.count) } ?? namedItems.count
        var pendingAgents = namedItems

        await withTaskGroup(of: (Int, String, Result<AgentResult, Error>).self) { group in
            func addTask(index: Int, name: String, agent: any AgentRuntime) {
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
                        return (index, name, .success(result))
                    } catch {
                        return (index, name, .failure(error))
                    }
                }
            }

            let initialCount = min(concurrencyLimit, pendingAgents.count)
            for _ in 0..<initialCount {
                let next = pendingAgents.removeFirst()
                addTask(index: next.0, name: next.1, agent: next.2)
            }

            while let (index, name, result) = await group.next() {
                switch result {
                case let .success(agentResult):
                    results.append((index, name, agentResult))
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
                    addTask(index: next.0, name: next.1, agent: next.2)
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
        let orderedResults = results.sorted { $0.0 < $1.0 }
        let orderedPairs = orderedResults.map { ($0.1, $0.2) }
        let completionPairs = results.map { ($0.1, $0.2) }

        // Merge results according to strategy
        let mergedOutput: String
        switch mergeStrategy {
        case .concatenate:
            mergedOutput = orderedPairs.map { $0.1.output }.joined(separator: "\n\n")
        case .first:
            mergedOutput = completionPairs.first?.1.output ?? ""
        case .longest:
            mergedOutput = orderedPairs.max(by: { $0.1.output.count < $1.1.output.count })?.1.output ?? ""
        case .structured:
            var output = ""
            for (name, result) in orderedPairs {
                output += "## \(name)\n\n\(result.output)\n\n"
            }
            mergedOutput = output
        case let .custom(merger):
            mergedOutput = merger(orderedPairs)
        }

        // Accumulate all tool calls and results
        var allToolCalls: [ToolCall] = []
        var allToolResults: [ToolResult] = []
        var totalIterations = 0
        var allMetadata: [String: SendableValue] = [:]

        for (name, result) in orderedPairs {
            allToolCalls.append(contentsOf: result.toolCalls)
            allToolResults.append(contentsOf: result.toolResults)
            totalIterations += result.iterationCount

            // Namespace metadata by agent name
            for (key, value) in result.metadata {
                allMetadata["parallel.\(name).\(key)"] = value
            }
        }

        allMetadata["parallel.agent_count"] = .int(items.count)
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
    /// Builds an array of parallel items from multiple components.
    public static func buildBlock(_ components: [ParallelItem]...) -> [ParallelItem] {
        components.flatMap(\.self)
    }

    /// Builds an array from an optional item.
    public static func buildOptional(_ component: [ParallelItem]?) -> [ParallelItem] {
        component ?? []
    }

    /// Builds an array from the first branch of a conditional.
    public static func buildEither(first component: [ParallelItem]) -> [ParallelItem] {
        component
    }

    /// Builds an array from the second branch of a conditional.
    public static func buildEither(second component: [ParallelItem]) -> [ParallelItem] {
        component
    }

    /// Builds an array from nested arrays.
    public static func buildArray(_ components: [[ParallelItem]]) -> [ParallelItem] {
        components.flatMap(\.self)
    }

    /// Passes through a parallel item.
    public static func buildExpression(_ item: ParallelItem) -> [ParallelItem] {
        [item]
    }

    /// Wraps an agent as an unnamed parallel item.
    public static func buildExpression(_ agent: any AgentRuntime) -> [ParallelItem] {
        [ParallelItem(agent: agent)]
    }

    /// Wraps a blueprint as an unnamed parallel item.
    public static func buildExpression<B: AgentBlueprint>(_ blueprint: B) -> [ParallelItem] {
        [ParallelItem(agent: BlueprintAgent(blueprint))]
    }
}

// MARK: - Router

/// A step that routes input to different branches based on conditions.
///
/// `Router` evaluates conditions in order and delegates to the first
/// matching branch. If no condition matches and one or more fallbacks are
/// provided, the fallback branches are executed in declaration order.
///
/// Example:
/// ```swift
/// Router {
///     When(.contains("weather")) { weatherAgent }
///     When(.contains("code")) { codeAgent }
///     Otherwise { defaultAgent }
/// }
/// ```
public struct Router: OrchestrationStep {
    /// The routes to evaluate in order.
    public let routes: [RouteBranch]

    /// Optional fallback step when no route matches.
    public let fallback: OrchestrationStep?

    /// Creates a new router.
    /// - Parameter content: A builder closure that produces route entries.
    public init(@RouterBuilder _ content: () -> [RouteEntry]) {
        var builtRoutes: [RouteBranch] = []
        var fallbackSteps: [OrchestrationStep] = []

        for entry in content() {
            switch entry {
            case .when(let branch):
                builtRoutes.append(branch)
            case .otherwise(let step):
                fallbackSteps.append(step)
            }
        }

        routes = builtRoutes
        switch fallbackSteps.count {
        case 0:
            fallback = nil
        case 1:
            fallback = fallbackSteps[0]
        default:
            fallback = OrchestrationGroup(steps: fallbackSteps)
        }
    }

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        let startTime = ContinuousClock.now

        var selected: RouteBranch?
        var selectedIndex: Int?
        for (index, route) in routes.enumerated()
            where await route.condition.matches(input: input, context: context.agentContext) {
            selected = route
            selectedIndex = index
            break
        }

        let result: AgentResult
        let routeName: String

        if let route = selected, let index = selectedIndex {
            result = try await route.step.execute(input, context: context)
            routeName = resolvedRouteName(for: route, index: index, context: context)
        } else if let fallback {
            result = try await fallback.execute(input, context: context)
            routeName = resolvedFallbackName(for: fallback, context: context)
        } else {
            throw OrchestrationError.routingFailed(
                reason: "No route matched input and no fallback step configured"
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

    private func resolvedRouteName(
        for route: RouteBranch,
        index: Int,
        context: OrchestrationStepContext
    ) -> String {
        if let name = route.name {
            return name
        }
        if let agentStep = route.step as? AgentStep {
            let agentName = agentStep.name ?? context.agentName(for: agentStep.agent)
            return "route.\(index).\(agentName)"
        }
        return "route.\(index)"
    }

    private func resolvedFallbackName(
        for step: OrchestrationStep,
        context: OrchestrationStepContext
    ) -> String {
        if let agentStep = step as? AgentStep {
            let agentName = agentStep.name ?? context.agentName(for: agentStep.agent)
            return "fallback.\(agentName)"
        }
        return "fallback"
    }
}

extension Router: _AgentLoopNestedSteps {
    var _nestedSteps: [OrchestrationStep] {
        routes.map(\.step) + (fallback.map { [$0] } ?? [])
    }
}

// MARK: - Transform

/// A step that transforms the current input into a new string.
///
/// `Transform` lets you inject custom processing logic into an orchestration
/// workflow by mapping a string input to a string output.
///
/// Example:
/// ```swift
/// Transform { input in
///     "Processed: \(input.uppercased())"
/// }
/// ```
public struct Transform: OrchestrationStep {
    /// The transformation function to apply.
    public let transformer: @Sendable (String) async throws -> String

    /// Creates a new transform step.
    /// - Parameter transformer: A closure that maps input to the next input string.
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
///         analysisAgent.named("analysis")
///         summaryAgent.named("summary")
///     }
///
///     Router {
///         When(.contains("weather")) { weatherAgent }
///         When(.contains("code")) { codeAgent }
///         Otherwise { defaultAgent }
///     }
/// }
///
/// let result = try await workflow.run("Process this data")
/// ```
public struct Orchestration: Sendable, OrchestratorProtocol {
    /// The root step in this orchestration.
    public let root: OrchestrationStep

    /// Configuration for this orchestration agent.
    public let configuration: AgentConfiguration

    /// Handoff configurations applied to sub-agents.
    public let handoffs: [AnyHandoffConfiguration]

    // MARK: - Agent Protocol Properties

    public var tools: [any AnyJSONTool] { [] }

    public var instructions: String {
        "Orchestration workflow with \(rootStepCount) steps"
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
        @OrchestrationBuilder _ content: () -> OrchestrationStep
    ) {
        root = content()
        self.configuration = configuration
        self.handoffs = handoffs
    }

    /// Creates a new orchestration from an existing root step.
    public init(
        root: OrchestrationStep,
        configuration: AgentConfiguration = .default,
        handoffs: [AnyHandoffConfiguration] = []
    ) {
        self.root = root
        self.configuration = configuration
        self.handoffs = handoffs
    }

    // MARK: - Agent Protocol Methods

    public func run(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        let result = try await executeSteps(
            steps: rootSteps,
            input: input,
            session: session,
            hooks: hooks,
            onIterationStart: nil,
            onIterationEnd: nil
        )
        return applyGroupMetadataIfNeeded(to: result)
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
                    steps: rootSteps,
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
                let finalized = applyGroupMetadataIfNeeded(to: result)
                continuation.yield(.completed(result: finalized))
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
        for agent in collectAgents(from: root) {
            await agent.cancel()
        }
    }

    // MARK: - Private Helpers

    private func executeSteps(
        steps: [OrchestrationStep],
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
                // Preserve last-write-wins metadata at top-level for convenience.
                // Namespaced copies are also stored for full provenance.
                allMetadata[key] = value
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

    private func applyGroupMetadataIfNeeded(to result: AgentResult) -> AgentResult {
        guard root is OrchestrationGroup else {
            return result
        }

        var metadata = result.metadata
        let prefix = "orchestration."
        for (key, value) in result.metadata where key.hasPrefix(prefix) {
            let suffix = key.dropFirst(prefix.count)
            metadata["group.\(suffix)"] = value
        }

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

    private func collectAgents(from step: OrchestrationStep) -> [any AgentRuntime] {
        if let group = step as? OrchestrationGroup {
            return group.steps.flatMap(collectAgents(from:))
        }
        if let agentStep = step as? AgentStep {
            return [agentStep.agent]
        }
        if let sequential = step as? Sequential {
            return sequential.steps.flatMap(collectAgents(from:))
        }
        if let parallel = step as? Parallel {
            return parallel.items.map(\.agent)
        }
        if let router = step as? Router {
            let routeAgents = router.routes.map(\.step).flatMap(collectAgents(from:))
            if let fallback = router.fallback {
                return routeAgents + collectAgents(from: fallback)
            }
            return routeAgents
        }
        return []
    }

    private var rootSteps: [OrchestrationStep] {
        OrchestrationBuilder.steps(from: root)
    }

    private var rootStepCount: Int {
        rootSteps.count
    }
}
