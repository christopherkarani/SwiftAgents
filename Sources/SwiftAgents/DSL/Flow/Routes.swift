// Routes.swift
// SwiftAgents Framework
//
// SwiftUI-style deterministic routing for declarative agent loops.

import Foundation

// MARK: - Routes

/// Routes input to the first matching branch.
///
/// `Routes` is an `OrchestrationStep` so it can be placed inline in an `AgentLoop`
/// to make routing visible in execution flow.
///
/// Example:
/// ```swift
/// Routes {
///     When(.contains("billing")) { BillingAgent() }
///     When(.contains("refund")) { RefundsAgent() }
///     Otherwise { GeneralSupportAgent() }
/// }
/// ```
public struct Routes: OrchestrationStep {
    public let routes: [RouteBranch]
    public let fallback: OrchestrationStep?

    public init(@RoutesBuilder _ content: () -> [RouteEntry]) {
        var builtRoutes: [RouteBranch] = []
        var builtFallback: OrchestrationStep?

        for entry in content() {
            switch entry {
            case .when(let branch):
                builtRoutes.append(branch)
            case .otherwise(let step):
                builtFallback = step
            }
        }

        routes = builtRoutes
        fallback = builtFallback
    }

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        let startTime = ContinuousClock.now

        var selected: RouteBranch?
        for route in routes where await route.condition.matches(input: input, context: context.agentContext) {
            selected = route
            break
        }

        let result: AgentResult
        let matchedName: String

        if let route = selected {
            result = try await route.step.execute(input, context: context)
            matchedName = route.name ?? "route"
        } else if let fallback {
            result = try await fallback.execute(input, context: context)
            matchedName = "fallback"
        } else {
            throw OrchestrationError.routingFailed(
                reason: "No route matched input and no fallback step configured"
            )
        }

        let duration = ContinuousClock.now - startTime
        var metadata = result.metadata
        metadata["routes.matched_route"] = .string(matchedName)
        metadata["routes.total_routes"] = .int(routes.count)
        metadata["routes.duration"] = .double(
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

extension Routes: _AgentLoopNestedSteps {
    var _nestedSteps: [OrchestrationStep] {
        routes.map(\.step) + (fallback.map { [$0] } ?? [])
    }
}

// MARK: - RouteBranch

public struct RouteBranch: Sendable {
    public let condition: RouteCondition
    public let step: OrchestrationStep
    public let name: String?

    public init(condition: RouteCondition, step: OrchestrationStep, name: String? = nil) {
        self.condition = condition
        self.step = step
        self.name = name
    }
}

// MARK: - RouteEntry

public enum RouteEntry: Sendable {
    case when(RouteBranch)
    case otherwise(OrchestrationStep)
}

// MARK: - Builders

@resultBuilder
public struct RoutesBuilder {
    public static func buildBlock(_ components: [RouteEntry]...) -> [RouteEntry] {
        components.flatMap(\.self)
    }

    public static func buildOptional(_ component: [RouteEntry]?) -> [RouteEntry] {
        component ?? []
    }

    public static func buildEither(first component: [RouteEntry]) -> [RouteEntry] { component }
    public static func buildEither(second component: [RouteEntry]) -> [RouteEntry] { component }

    public static func buildArray(_ components: [[RouteEntry]]) -> [RouteEntry] {
        components.flatMap(\.self)
    }

    public static func buildExpression(_ entry: RouteEntry) -> [RouteEntry] {
        [entry]
    }
}

// MARK: - DSL Helpers

public func When(
    _ condition: RouteCondition,
    name: String? = nil,
    @AgentLoopBuilder _ content: () -> AgentLoopSequence
) -> RouteEntry {
    .when(RouteBranch(condition: condition, step: AgentLoopStep(content()), name: name))
}

public func Otherwise(
    @AgentLoopBuilder _ content: () -> AgentLoopSequence
) -> RouteEntry {
    .otherwise(AgentLoopStep(content()))
}
