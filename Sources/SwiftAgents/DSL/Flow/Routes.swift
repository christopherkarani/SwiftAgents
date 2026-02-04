// Routes.swift
// SwiftAgents Framework
//
// SwiftUI-style deterministic routing helpers for orchestration DSLs.

import Foundation

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
public struct RouterBuilder {
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
    @OrchestrationBuilder _ content: () -> OrchestrationStep
) -> RouteEntry {
    .when(RouteBranch(condition: condition, step: content(), name: name))
}

/// Creates a `When` route entry using a concrete step.
public func When(
    _ condition: RouteCondition,
    name: String? = nil,
    use step: OrchestrationStep
) -> RouteEntry {
    .when(RouteBranch(condition: condition, step: step, name: name))
}

/// Creates a `When` route entry using an agent.
public func When(
    _ condition: RouteCondition,
    name: String? = nil,
    use agent: any AgentRuntime
) -> RouteEntry {
    .when(RouteBranch(condition: condition, step: AgentStep(agent), name: name))
}

/// Creates a `When` route entry using a blueprint.
public func When<B: AgentBlueprint>(
    _ condition: RouteCondition,
    name: String? = nil,
    use blueprint: B
) -> RouteEntry {
    .when(RouteBranch(condition: condition, step: AgentStep(BlueprintAgent(blueprint)), name: name))
}

public func Otherwise(
    @OrchestrationBuilder _ content: () -> OrchestrationStep
) -> RouteEntry {
    .otherwise(content())
}

/// Creates an `Otherwise` route entry using a concrete step.
public func Otherwise(use step: OrchestrationStep) -> RouteEntry {
    .otherwise(step)
}

/// Creates an `Otherwise` route entry using an agent.
public func Otherwise(use agent: any AgentRuntime) -> RouteEntry {
    .otherwise(AgentStep(agent))
}

/// Creates an `Otherwise` route entry using a blueprint.
public func Otherwise<B: AgentBlueprint>(use blueprint: B) -> RouteEntry {
    .otherwise(AgentStep(BlueprintAgent(blueprint)))
}
