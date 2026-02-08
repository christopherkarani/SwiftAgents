// AgentRouter.swift
// Swarm Framework
//
// Condition-based deterministic routing for multi-agent orchestration.

import Foundation

// MARK: - RouteCondition

/// A condition that determines whether a route should be taken.
///
/// `RouteCondition` wraps a closure that evaluates whether a given input
/// and context match the routing criteria. Conditions can be combined using
/// logical operators (`and`, `or`, `not`) to create complex routing logic.
///
/// Example:
/// ```swift
/// let condition = RouteCondition.contains("weather")
///     .and(.lengthInRange(5...100))
///     .or(.contextHas(key: "location"))
/// ```
public struct RouteCondition: Sendable {
    // MARK: Public

    /// Creates a new route condition.
    ///
    /// - Parameter evaluate: A closure that evaluates the condition.
    public init(_ evaluate: @escaping @Sendable (String, AgentContext?) async -> Bool) {
        self.evaluate = evaluate
    }

    /// Evaluates whether this condition matches the input and context.
    ///
    /// - Parameters:
    ///   - input: The input string to evaluate.
    ///   - context: Optional agent context for context-based conditions.
    /// - Returns: True if the condition matches.
    public func matches(input: String, context: AgentContext?) async -> Bool {
        await evaluate(input, context)
    }

    // MARK: Private

    private let evaluate: @Sendable (String, AgentContext?) async -> Bool
}

// MARK: - Built-in Conditions

public extension RouteCondition {
    /// A condition that always matches.
    ///
    /// Useful as a fallback route or default condition.
    ///
    /// Example:
    /// ```swift
    /// Route(condition: .always, agent: fallbackAgent)
    /// ```
    static let always = RouteCondition { _, _ in true }

    /// A condition that never matches.
    ///
    /// Useful for temporarily disabling routes during development.
    ///
    /// Example:
    /// ```swift
    /// Route(condition: .never, agent: debugAgent)
    /// ```
    static let never = RouteCondition { _, _ in false }

    /// A condition that checks if the input contains a substring.
    ///
    /// - Parameters:
    ///   - substring: The substring to search for.
    ///   - isCaseSensitive: Whether the search is case-sensitive. Default: false
    /// - Returns: A condition that matches if the substring is found.
    ///
    /// Example:
    /// ```swift
    /// let condition = RouteCondition.contains("weather", isCaseSensitive: false)
    /// ```
    static func contains(_ substring: String, isCaseSensitive: Bool = false) -> RouteCondition {
        RouteCondition { input, _ in
            if isCaseSensitive {
                input.contains(substring)
            } else {
                input.localizedCaseInsensitiveContains(substring)
            }
        }
    }

    /// A condition that checks if the input contains a substring.
    ///
    /// - Parameters:
    ///   - substring: The substring to search for.
    ///   - caseSensitive: Whether the search is case-sensitive.
    /// - Returns: A condition that matches if the substring is found.
    @available(*, deprecated, message: "Use isCaseSensitive instead of caseSensitive")
    static func contains(_ substring: String, caseSensitive: Bool) -> RouteCondition {
        contains(substring, isCaseSensitive: caseSensitive)
    }

    /// A condition that matches the input against a regular expression pattern.
    ///
    /// - Parameter pattern: The regex pattern to match.
    /// - Returns: A condition that matches if the pattern is found.
    ///
    /// Example:
    /// ```swift
    /// let condition = RouteCondition.matches(pattern: #"\d{3}-\d{4}"#)
    /// ```
    static func matches(pattern: String) -> RouteCondition {
        RouteCondition { input, _ in
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return false
            }
            let range = NSRange(input.startIndex..., in: input)
            return regex.firstMatch(in: input, range: range) != nil
        }
    }

    /// A condition that checks if the input starts with a prefix.
    ///
    /// - Parameter prefix: The prefix to check for.
    /// - Returns: A condition that matches if the input starts with the prefix.
    ///
    /// Example:
    /// ```swift
    /// let condition = RouteCondition.startsWith("calculate")
    /// ```
    static func startsWith(_ prefix: String) -> RouteCondition {
        RouteCondition { input, _ in
            input.lowercased().hasPrefix(prefix.lowercased())
        }
    }

    /// A condition that checks if the input ends with a suffix.
    ///
    /// - Parameter suffix: The suffix to check for.
    /// - Returns: A condition that matches if the input ends with the suffix.
    ///
    /// Example:
    /// ```swift
    /// let condition = RouteCondition.endsWith("?")
    /// ```
    static func endsWith(_ suffix: String) -> RouteCondition {
        RouteCondition { input, _ in
            input.lowercased().hasSuffix(suffix.lowercased())
        }
    }

    /// A condition that checks if the input length is within a range.
    ///
    /// - Parameter range: The valid length range (inclusive).
    /// - Returns: A condition that matches if the input length is in range.
    ///
    /// Example:
    /// ```swift
    /// let condition = RouteCondition.lengthInRange(10...100)
    /// ```
    static func lengthInRange(_ range: ClosedRange<Int>) -> RouteCondition {
        RouteCondition { input, _ in
            range.contains(input.count)
        }
    }

    /// A condition that checks if the agent context has a specific key.
    ///
    /// - Parameter key: The context key to check for.
    /// - Returns: A condition that matches if the key exists in context.
    ///
    /// Example:
    /// ```swift
    /// let condition = RouteCondition.contextHas(key: "user_id")
    /// ```
    static func contextHas(key: String) -> RouteCondition {
        RouteCondition { _, context in
            guard let context else { return false }
            return await context.get(key) != nil
        }
    }
}

// MARK: - Condition Combinators

public extension RouteCondition {
    /// Negates this condition.
    ///
    /// - Returns: A new condition that matches when this condition doesn't.
    ///
    /// Example:
    /// ```swift
    /// let condition = RouteCondition.contains("admin").not
    /// ```
    var not: RouteCondition {
        RouteCondition { input, context in
            await !(self.matches(input: input, context: context))
        }
    }

    /// Combines this condition with another using logical AND.
    ///
    /// - Parameter other: The condition to combine with.
    /// - Returns: A new condition that matches only if both conditions match.
    ///
    /// Example:
    /// ```swift
    /// let condition = RouteCondition.contains("weather")
    ///     .and(.lengthInRange(10...100))
    /// ```
    func and(_ other: RouteCondition) -> RouteCondition {
        RouteCondition { input, context in
            let firstMatch = await self.matches(input: input, context: context)
            guard firstMatch else { return false }
            let secondMatch = await other.matches(input: input, context: context)
            return secondMatch
        }
    }

    /// Combines this condition with another using logical OR.
    ///
    /// - Parameter other: The condition to combine with.
    /// - Returns: A new condition that matches if either condition matches.
    ///
    /// Example:
    /// ```swift
    /// let condition = RouteCondition.contains("help")
    ///     .or(.contains("support"))
    /// ```
    func or(_ other: RouteCondition) -> RouteCondition {
        RouteCondition { input, context in
            let firstMatch = await self.matches(input: input, context: context)
            if firstMatch { return true }
            let secondMatch = await other.matches(input: input, context: context)
            return secondMatch
        }
    }
}

// MARK: - Route

/// A route that associates a condition with an agent.
///
/// Routes define the mapping between input conditions and the agents
/// that should handle them. The router evaluates routes in order and
/// selects the first matching route.
///
/// Example:
/// ```swift
/// let route = Route(
///     condition: .contains("weather"),
///     agent: weatherAgent,
///     name: "WeatherRoute"
/// )
/// ```
public struct Route: Sendable {
    /// The condition that determines if this route matches.
    public let condition: RouteCondition

    /// The agent to execute if this route matches.
    public let agent: any AgentRuntime

    /// Optional name for debugging and logging.
    public let name: String?

    /// Creates a new route.
    ///
    /// - Parameters:
    ///   - condition: The condition for this route.
    ///   - agent: The agent to execute if matched.
    ///   - name: Optional name for the route. Default: nil
    public init(condition: RouteCondition, agent: any AgentRuntime, name: String? = nil) {
        self.condition = condition
        self.agent = agent
        self.name = name
    }
}

// MARK: - RouteBuilder

/// A result builder for constructing route arrays with DSL syntax.
///
/// `RouteBuilder` enables a declarative syntax for defining routes,
/// similar to SwiftUI's view builders.
///
/// Example:
/// ```swift
/// AgentRouter {
///     Route(condition: .contains("weather"), agent: weatherAgent)
///     Route(condition: .contains("news"), agent: newsAgent)
///     if includeDebug {
///         Route(condition: .contains("debug"), agent: debugAgent)
///     }
/// }
/// ```
@resultBuilder
public struct RouteBuilder {
    /// Builds a route array from multiple routes.
    public static func buildBlock(_ routes: Route...) -> [Route] {
        routes
    }

    /// Builds a route array from an optional route.
    public static func buildOptional(_ route: Route?) -> [Route] {
        route.map { [$0] } ?? []
    }

    /// Builds a route array from the first branch of an if-else.
    public static func buildEither(first route: Route) -> [Route] {
        [route]
    }

    /// Builds a route array from the second branch of an if-else.
    public static func buildEither(second route: Route) -> [Route] {
        [route]
    }

    /// Builds a route array from nested arrays.
    public static func buildArray(_ routes: [[Route]]) -> [Route] {
        routes.flatMap(\.self)
    }
}

// MARK: - AgentRouter

/// An agent that routes requests to other agents based on conditions.
///
/// `AgentRouter` implements deterministic, logic-based routing without
/// requiring LLM calls. It evaluates routes in order and delegates to
/// the first matching agent.
///
/// Example:
/// ```swift
/// let router = AgentRouter {
///     Route(
///         condition: .contains("weather").and(.lengthInRange(5...100)),
///         agent: weatherAgent,
///         name: "WeatherRoute"
///     )
///     Route(
///         condition: .contains("news"),
///         agent: newsAgent,
///         name: "NewsRoute"
///     )
/// } fallbackAgent: fallbackAgent
///
/// let result = try await router.run("What's the weather?")
/// ```
public actor AgentRouter: AgentRuntime {
    // MARK: Public

    // MARK: - Agent Protocol Properties

    nonisolated public let tools: [any AnyJSONTool] = []
    nonisolated public let instructions: String
    nonisolated public let configuration: AgentConfiguration

    nonisolated public var memory: (any Memory)? { nil }
    nonisolated public var inferenceProvider: (any InferenceProvider)? { nil }

    /// Tracer for this router. Returns `nil` as orchestrators delegate tracing to their sub-agents.
    nonisolated public var tracer: (any Tracer)? { nil }

    /// Configured handoffs for this router.
    nonisolated public var handoffs: [AnyHandoffConfiguration] { _handoffs }

    // MARK: - Initialization

    /// Creates a new agent router with an array of routes.
    ///
    /// Routes are evaluated in order. The first route whose condition
    /// matches will handle the request.
    ///
    /// - Parameters:
    ///   - routes: The routes to evaluate.
    ///   - fallbackAgent: Optional agent to use when no route matches. Default: nil
    ///   - configuration: Router configuration. Default: .default
    ///   - handoffs: Handoff configurations for routed agents. Default: []
    public init(
        routes: [Route],
        fallbackAgent: (any AgentRuntime)? = nil,
        configuration: AgentConfiguration = .default,
        handoffs: [AnyHandoffConfiguration] = []
    ) {
        self.routes = routes
        self.fallbackAgent = fallbackAgent
        self.configuration = configuration
        _handoffs = handoffs
        instructions = "Routes requests to specialized agents based on conditions."
    }

    /// Creates a new agent router using result builder syntax.
    ///
    /// This initializer enables a declarative DSL for defining routes.
    ///
    /// - Parameters:
    ///   - fallbackAgent: Optional agent to use when no route matches. Default: nil
    ///   - configuration: Router configuration. Default: .default
    ///   - handoffs: Handoff configurations for routed agents. Default: []
    ///   - routes: A closure that builds the route array.
    ///
    /// Example:
    /// ```swift
    /// let router = AgentRouter {
    ///     Route(condition: .contains("weather"), agent: weatherAgent)
    ///     Route(condition: .contains("news"), agent: newsAgent)
    /// }
    /// ```
    public init(
        fallbackAgent: (any AgentRuntime)? = nil,
        configuration: AgentConfiguration = .default,
        handoffs: [AnyHandoffConfiguration] = [],
        @RouteBuilder routes: () -> [Route]
    ) {
        self.routes = routes()
        self.fallbackAgent = fallbackAgent
        self.configuration = configuration
        _handoffs = handoffs
        instructions = "Routes requests to specialized agents based on conditions."
    }

    // MARK: - Agent Protocol Methods

    /// Executes the router by finding a matching route and delegating to its agent.
    ///
    /// - Parameters:
    ///   - input: The user's input/query.
    ///   - session: Optional session for state persistence.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: The result from the selected agent.
    /// - Throws: `OrchestrationError.routingFailed` if no route matches and no fallback exists.
    public func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) async throws -> AgentResult {
        if isCancelled {
            throw AgentError.cancelled
        }

        let startTime = ContinuousClock.now

        // Create context for this routing operation
        let routingContext = AgentContext(input: input)

        // Find the first matching route
        let selectedRoute = await findMatchingRoute(input: input, context: routingContext)

        guard let route = selectedRoute else {
            // No route matched - try fallback
            if let fallback = fallbackAgent {
                // Notify hooks of handoff to fallback agent
                await hooks?.onHandoff(context: routingContext, fromAgent: self, toAgent: fallback)

                return try await fallback.run(input, session: session, hooks: hooks)
            } else {
                throw OrchestrationError.routingFailed(
                    reason: "No route matched input and no fallback agent configured"
                )
            }
        }

        // Apply handoff configuration if available
        var effectiveInput = input
        let routeName = route.name ?? String(describing: type(of: route.agent))

        if let config = findHandoffConfiguration(for: route.agent) {
            // Check isEnabled callback
            if let isEnabled = config.isEnabled {
                let enabled = await isEnabled(routingContext, route.agent)
                if !enabled {
                    throw OrchestrationError.handoffSkipped(
                        from: "AgentRouter",
                        to: routeName,
                        reason: "Handoff disabled by isEnabled callback"
                    )
                }
            }

            // Create HandoffInputData for callbacks
            var inputData = HandoffInputData(
                sourceAgentName: "AgentRouter",
                targetAgentName: routeName,
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
                    try await onHandoff(routingContext, inputData)
                } catch {
                    // Log callback errors but don't fail the handoff
                    Log.orchestration.warning(
                        "onHandoff callback failed for AgentRouter -> \(routeName): \(error.localizedDescription)"
                    )
                }
            }
        }

        // Notify hooks of handoff to matched route's agent
        await hooks?.onHandoff(context: routingContext, fromAgent: self, toAgent: route.agent)

        // Execute the matched route's agent with potentially modified input
        let result = try await route.agent.run(effectiveInput, session: session, hooks: hooks)

        // Add routing metadata
        let duration = ContinuousClock.now - startTime
        var metadata = result.metadata
        metadata["router.matched_route"] = .string(route.name ?? "unnamed")
        metadata["router.duration"] = .double(Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18)

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

    /// Streams the execution by delegating to the matched route's agent.
    ///
    /// - Parameters:
    ///   - input: The user's input/query.
    ///   - session: Optional session for state persistence.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: An async stream of agent events.
    nonisolated public func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream(for: self) { actor, continuation in
            continuation.yield(.started(input: input))

            let routerName = actor.configuration.name.isEmpty ? "AgentRouter" : actor.configuration.name

            func forwardStream(
                toAgentName: String,
                agent: any AgentRuntime,
                input: String
            ) async throws -> AgentResult {
                continuation.yield(.handoffStarted(from: routerName, to: toAgentName, input: input))
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
                    throw AgentError.internalError(reason: "AgentRouter stream ended without completion")
                }

                continuation.yield(.handoffCompletedWithResult(
                    from: routerName,
                    to: toAgentName,
                    result: finalResult
                ))

                return finalResult
            }

            do {
                if await actor.isCancelled {
                    throw AgentError.cancelled
                }

                let startTime = ContinuousClock.now
                let routingContext = AgentContext(input: input)
                let selectedRoute = await actor.findMatchingRoute(input: input, context: routingContext)

                guard let route = selectedRoute else {
                    if let fallback = actor.fallbackAgent {
                        await hooks?.onHandoff(context: routingContext, fromAgent: actor, toAgent: fallback)
                        let fallbackName = fallback.configuration.name.isEmpty ? String(describing: type(of: fallback)) : fallback.configuration.name
                        let result = try await forwardStream(
                            toAgentName: fallbackName,
                            agent: fallback,
                            input: input
                        )
                        continuation.yield(.completed(result: result))
                        continuation.finish()
                        return
                    }

                    throw OrchestrationError.routingFailed(
                        reason: "No route matched input and no fallback agent configured"
                    )
                }

                var effectiveInput = input
                let routeName = route.name ?? String(describing: type(of: route.agent))

                if let config = await actor.findHandoffConfiguration(for: route.agent) {
                    if let isEnabled = config.isEnabled {
                        let enabled = await isEnabled(routingContext, route.agent)
                        if !enabled {
                            throw OrchestrationError.handoffSkipped(
                                from: "AgentRouter",
                                to: routeName,
                                reason: "Handoff disabled by isEnabled callback"
                            )
                        }
                    }

                    var inputData = HandoffInputData(
                        sourceAgentName: "AgentRouter",
                        targetAgentName: routeName,
                        input: input,
                        context: [:],
                        metadata: [:]
                    )

                    if let inputFilter = config.inputFilter {
                        inputData = inputFilter(inputData)
                        effectiveInput = inputData.input
                    }

                    if let onHandoff = config.onHandoff {
                        do {
                            try await onHandoff(routingContext, inputData)
                        } catch {
                            Log.orchestration.warning(
                                "onHandoff callback failed for AgentRouter -> \(routeName): \(error.localizedDescription)"
                            )
                        }
                    }
                }

                await hooks?.onHandoff(context: routingContext, fromAgent: actor, toAgent: route.agent)

                let agentResult = try await forwardStream(
                    toAgentName: routeName,
                    agent: route.agent,
                    input: effectiveInput
                )

                let duration = ContinuousClock.now - startTime
                var metadata = agentResult.metadata
                metadata["router.matched_route"] = .string(route.name ?? "unnamed")
                metadata["router.duration"] = .double(Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18)

                let result = AgentResult(
                    output: agentResult.output,
                    toolCalls: agentResult.toolCalls,
                    toolResults: agentResult.toolResults,
                    iterationCount: agentResult.iterationCount,
                    duration: agentResult.duration,
                    tokenUsage: agentResult.tokenUsage,
                    metadata: metadata
                )

                continuation.yield(.completed(result: result))
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

    /// Cancels any ongoing routing execution.
    public func cancel() async {
        isCancelled = true
    }

    // MARK: Private

    // MARK: - Private Properties

    private let routes: [Route]
    private let fallbackAgent: (any AgentRuntime)?
    private var isCancelled: Bool = false

    /// Handoff configurations for routed agents.
    private let _handoffs: [AnyHandoffConfiguration]

    // MARK: - Private Methods

    /// Finds the first route that matches the input and context.
    ///
    /// - Parameters:
    ///   - input: The input string to evaluate.
    ///   - context: Optional agent context for context-based routing.
    /// - Returns: The first matching route, or nil if none match.
    private func findMatchingRoute(input: String, context: AgentContext?) async -> Route? {
        for route in routes where await route.condition.matches(input: input, context: context) {
            return route
        }
        return nil
    }

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

// MARK: CustomStringConvertible

extension AgentRouter: CustomStringConvertible {
    nonisolated public var description: String {
        """
        AgentRouter(
            routes: \(routes.count),
            hasFallback: \(fallbackAgent != nil)
        )
        """
    }
}
