// AgentRouter.swift
// SwiftAgents Framework
//
// Condition-based deterministic routing for multi-agent orchestration.

import Foundation

// MARK: - Route Condition

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
    private let evaluate: @Sendable (String, AgentContext?) async -> Bool

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
}

// MARK: - Built-in Conditions

extension RouteCondition {
    /// A condition that checks if the input contains a substring.
    ///
    /// - Parameters:
    ///   - substring: The substring to search for.
    ///   - caseSensitive: Whether the search is case-sensitive. Default: false
    /// - Returns: A condition that matches if the substring is found.
    ///
    /// Example:
    /// ```swift
    /// let condition = RouteCondition.contains("weather", caseSensitive: false)
    /// ```
    public static func contains(_ substring: String, caseSensitive: Bool = false) -> RouteCondition {
        RouteCondition { input, _ in
            if caseSensitive {
                return input.contains(substring)
            } else {
                return input.localizedCaseInsensitiveContains(substring)
            }
        }
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
    public static func matches(pattern: String) -> RouteCondition {
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
    public static func startsWith(_ prefix: String) -> RouteCondition {
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
    public static func endsWith(_ suffix: String) -> RouteCondition {
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
    public static func lengthInRange(_ range: ClosedRange<Int>) -> RouteCondition {
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
    public static func contextHas(key: String) -> RouteCondition {
        RouteCondition { _, context in
            guard let context = context else { return false }
            return await context.get(key) != nil
        }
    }

    /// A condition that always matches.
    ///
    /// Useful as a fallback route or default condition.
    ///
    /// Example:
    /// ```swift
    /// Route(condition: .always, agent: fallbackAgent)
    /// ```
    public static let always: RouteCondition = RouteCondition { _, _ in true }

    /// A condition that never matches.
    ///
    /// Useful for temporarily disabling routes during development.
    ///
    /// Example:
    /// ```swift
    /// Route(condition: .never, agent: debugAgent)
    /// ```
    public static let never: RouteCondition = RouteCondition { _, _ in false }
}

// MARK: - Condition Combinators

extension RouteCondition {
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
    public func and(_ other: RouteCondition) -> RouteCondition {
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
    public func or(_ other: RouteCondition) -> RouteCondition {
        RouteCondition { input, context in
            let firstMatch = await self.matches(input: input, context: context)
            if firstMatch { return true }
            let secondMatch = await other.matches(input: input, context: context)
            return secondMatch
        }
    }

    /// Negates this condition.
    ///
    /// - Returns: A new condition that matches when this condition doesn't.
    ///
    /// Example:
    /// ```swift
    /// let condition = RouteCondition.contains("admin").not
    /// ```
    public var not: RouteCondition {
        RouteCondition { input, context in
            !(await self.matches(input: input, context: context))
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
    public let agent: any Agent

    /// Optional name for debugging and logging.
    public let name: String?

    /// Creates a new route.
    ///
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

// MARK: - Route Builder

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
        routes.flatMap { $0 }
    }
}

// MARK: - Agent Router

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
public actor AgentRouter: Agent {
    // MARK: - Agent Protocol Properties

    public nonisolated let tools: [any Tool] = []
    public nonisolated let instructions: String
    public nonisolated let configuration: AgentConfiguration
    public nonisolated var memory: (any AgentMemory)? { nil }
    public nonisolated var inferenceProvider: (any InferenceProvider)? { nil }

    // MARK: - Private Properties

    private let routes: [Route]
    private let fallbackAgent: (any Agent)?
    private var isCancelled: Bool = false

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
    public init(
        routes: [Route],
        fallbackAgent: (any Agent)? = nil,
        configuration: AgentConfiguration = .default
    ) {
        self.routes = routes
        self.fallbackAgent = fallbackAgent
        self.configuration = configuration
        self.instructions = "Routes requests to specialized agents based on conditions."
    }

    /// Creates a new agent router using result builder syntax.
    ///
    /// This initializer enables a declarative DSL for defining routes.
    ///
    /// - Parameters:
    ///   - fallbackAgent: Optional agent to use when no route matches. Default: nil
    ///   - configuration: Router configuration. Default: .default
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
        fallbackAgent: (any Agent)? = nil,
        configuration: AgentConfiguration = .default,
        @RouteBuilder routes: () -> [Route]
    ) {
        self.routes = routes()
        self.fallbackAgent = fallbackAgent
        self.configuration = configuration
        self.instructions = "Routes requests to specialized agents based on conditions."
    }

    // MARK: - Agent Protocol Methods

    /// Executes the router by finding a matching route and delegating to its agent.
    ///
    /// - Parameter input: The user's input/query.
    /// - Returns: The result from the selected agent.
    /// - Throws: `OrchestrationError.routingFailed` if no route matches and no fallback exists.
    public func run(_ input: String) async throws -> AgentResult {
        if isCancelled {
            throw AgentError.cancelled
        }

        let startTime = ContinuousClock.now

        // Find the first matching route
        let selectedRoute = await findMatchingRoute(input: input, context: nil)

        guard let route = selectedRoute else {
            // No route matched - try fallback
            if let fallback = fallbackAgent {
                return try await fallback.run(input)
            } else {
                throw OrchestrationError.routingFailed(
                    reason: "No route matched input and no fallback agent configured"
                )
            }
        }

        // Execute the matched route's agent
        let result = try await route.agent.run(input)

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
    /// - Parameter input: The user's input/query.
    /// - Returns: An async stream of agent events.
    public nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(.started(input: input))

                    if await self.isCancelled {
                        continuation.yield(.cancelled)
                        continuation.finish()
                        return
                    }

                    // Find the first matching route
                    let selectedRoute = await self.findMatchingRoute(input: input, context: nil)

                    guard let route = selectedRoute else {
                        // No route matched - try fallback
                        if let fallback = fallbackAgent {
                            for try await event in fallback.stream(input) {
                                continuation.yield(event)
                            }
                        } else {
                            let error = OrchestrationError.routingFailed(
                                reason: "No route matched input and no fallback agent configured"
                            )
                            continuation.yield(.failed(error: .internalError(reason: error.localizedDescription)))
                        }
                        continuation.finish()
                        return
                    }

                    // Stream from the matched route's agent
                    for try await event in route.agent.stream(input) {
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch {
                    if let agentError = error as? AgentError {
                        continuation.yield(.failed(error: agentError))
                    } else {
                        continuation.yield(.failed(error: .internalError(reason: error.localizedDescription)))
                    }
                    continuation.finish()
                }
            }
        }
    }

    /// Cancels any ongoing routing execution.
    public func cancel() async {
        isCancelled = true
    }

    // MARK: - Private Methods

    /// Finds the first route that matches the input and context.
    ///
    /// - Parameters:
    ///   - input: The input string to evaluate.
    ///   - context: Optional agent context for context-based routing.
    /// - Returns: The first matching route, or nil if none match.
    private func findMatchingRoute(input: String, context: AgentContext?) async -> Route? {
        for route in routes {
            if await route.condition.matches(input: input, context: context) {
                return route
            }
        }
        return nil
    }
}

// MARK: - CustomStringConvertible

extension AgentRouter: CustomStringConvertible {
    public nonisolated var description: String {
        """
        AgentRouter(
            routes: \(routes.count),
            hasFallback: \(fallbackAgent != nil)
        )
        """
    }
}
