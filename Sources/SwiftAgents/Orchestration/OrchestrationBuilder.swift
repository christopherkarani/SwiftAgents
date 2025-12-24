// OrchestrationBuilder.swift
// SwiftAgents Framework
//
// Declarative DSL for multi-agent workflow orchestration.

import Foundation

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
    /// - Parameter input: The input string to process.
    /// - Returns: The result of executing this step.
    /// - Throws: `AgentError` or `OrchestrationError` if execution fails.
    func execute(_ input: String) async throws -> AgentResult
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
        components.flatMap { $0 }
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
    // MARK: Public

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

    public func execute(_ input: String) async throws -> AgentResult {
        try await agent.run(input)
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

    // MARK: Public

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
        self.steps = content()
        self.transformer = transformer
    }

    public func execute(_ input: String) async throws -> AgentResult {
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
            let result = try await step.execute(currentInput)

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

    // MARK: Public

    /// The named agents to execute in parallel.
    public let agents: [(String, any Agent)]

    /// The strategy for merging results.
    public let mergeStrategy: MergeStrategy

    /// Optional limit on concurrent executions.
    public let maxConcurrency: Int?

    /// Creates a new parallel orchestration.
    /// - Parameters:
    ///   - merge: How to merge parallel results. Default: `.concatenate`
    ///   - maxConcurrency: Maximum number of concurrent executions. Default: nil (unlimited)
    ///   - content: A builder closure that produces named agents to execute.
    public init(
        merge: MergeStrategy = .concatenate,
        maxConcurrency: Int? = nil,
        @ParallelBuilder _ content: () -> [(String, any Agent)]
    ) {
        self.agents = content()
        self.mergeStrategy = merge
        self.maxConcurrency = maxConcurrency
    }

    public func execute(_ input: String) async throws -> AgentResult {
        guard !agents.isEmpty else {
            return AgentResult(output: input)
        }

        let startTime = ContinuousClock.now

        // Execute agents in parallel using task group
        let results = try await withThrowingTaskGroup(
            of: (String, AgentResult).self,
            returning: [(String, AgentResult)].self
        ) { group in
            var pendingAgents = agents
            var completedResults: [(String, AgentResult)] = []

            // Add initial tasks up to maxConcurrency limit
            let initialCount = maxConcurrency.map { min($0, agents.count) } ?? agents.count
            for agent in pendingAgents.prefix(initialCount) {
                group.addTask {
                    let result = try await agent.1.run(input)
                    return (agent.0, result)
                }
            }
            pendingAgents.removeFirst(initialCount)

            // Collect results and add more tasks as they complete
            while let result = try await group.next() {
                completedResults.append(result)

                // If there are more agents and we haven't hit the limit, add another task
                if !pendingAgents.isEmpty {
                    let nextAgent = pendingAgents.removeFirst()
                    group.addTask {
                        let result = try await nextAgent.1.run(input)
                        return (nextAgent.0, result)
                    }
                }
            }

            return completedResults
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
        allMetadata["parallel.total_duration"] = .double(
            Double(duration.components.seconds) +
                Double(duration.components.attoseconds) / 1e18
        )

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
    // MARK: Public

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
        self.routes = content()
        self.fallbackAgent = fallback
    }

    public func execute(_ input: String) async throws -> AgentResult {
        let startTime = ContinuousClock.now

        // Find the first matching route
        var selectedRoute: RouteDefinition?
        for route in routes {
            if await route.condition.matches(input: input, context: nil) {
                selectedRoute = route
                break
            }
        }

        // Execute matched agent or fallback
        let result: AgentResult
        let routeName: String

        if let route = selectedRoute {
            result = try await route.agent.run(input)
            routeName = route.name ?? "unnamed"
        } else if let fallback = fallbackAgent {
            result = try await fallback.run(input)
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
/// Route(.contains("weather"), to: weatherAgent)
/// ```
public func OrchestrationRoute(_ condition: RouteCondition, to agent: @escaping @autoclosure () -> any Agent) -> RouteDefinition {
    RouteDefinition(condition: condition, agent: agent())
}

/// Convenience alias for creating a route definition.
/// - Note: Use this within an OrchestrationBuilder Router context.
public func RouteWhen(_ condition: RouteCondition, to agent: @escaping @autoclosure () -> any Agent) -> RouteDefinition {
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
        components.flatMap { $0 }
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
    // MARK: Public

    /// The transformation function to apply.
    public let transformer: @Sendable (String) async throws -> String

    /// Creates a new transform step.
    /// - Parameter transformer: A closure that transforms the input string.
    public init(_ transformer: @escaping @Sendable (String) async throws -> String) {
        self.transformer = transformer
    }

    public func execute(_ input: String) async throws -> AgentResult {
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
public struct Orchestration: Sendable {
    // MARK: Public

    /// The steps in this orchestration.
    public let steps: [OrchestrationStep]

    /// Creates a new orchestration.
    /// - Parameter content: A builder closure that produces the orchestration steps.
    public init(@OrchestrationBuilder _ content: () -> [OrchestrationStep]) {
        self.steps = content()
    }

    /// Executes the orchestration workflow.
    /// - Parameter input: The input string to process.
    /// - Returns: The final result after all steps complete.
    /// - Throws: `AgentError` or `OrchestrationError` if execution fails.
    public func run(_ input: String) async throws -> AgentResult {
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
            let result = try await step.execute(currentInput)

            // Accumulate results
            allToolCalls.append(contentsOf: result.toolCalls)
            allToolResults.append(contentsOf: result.toolResults)
            totalIterations += result.iterationCount

            // Merge metadata
            for (key, value) in result.metadata {
                allMetadata["orchestration.step_\(index).\(key)"] = value
            }

            // Use output as input for next step
            currentInput = result.output
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

    /// Streams the execution of the orchestration workflow.
    /// - Parameter input: The input string to process.
    /// - Returns: An async stream of agent events from all steps.
    public func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        let stepsCopy = steps
        return StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            do {
                var currentInput = input
                for (index, step) in stepsCopy.enumerated() {
                    continuation.yield(.iterationStarted(number: index + 1))

                    let result = try await step.execute(currentInput)
                    currentInput = result.output

                    continuation.yield(.iterationCompleted(number: index + 1))
                }

                let finalResult = AgentResult(output: currentInput)
                continuation.yield(.completed(result: finalResult))
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
