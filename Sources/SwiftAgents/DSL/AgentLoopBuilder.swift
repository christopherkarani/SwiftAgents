// AgentLoopBuilder.swift
// SwiftAgents Framework
//
// Result builder for constructing sequential `AgentLoop` values.

import Foundation

/// A result builder that constructs a sequential `AgentLoop`.
///
/// Within an `AgentLoopBuilder` block, each statement is executed in order.
@resultBuilder
public struct AgentLoopBuilder {
    public static func buildBlock(_ components: AgentLoopSequence...) -> AgentLoopSequence {
        AgentLoopSequence(steps: components.flatMap(\.steps))
    }

    public static func buildOptional(_ component: AgentLoopSequence?) -> AgentLoopSequence {
        component ?? AgentLoopSequence(steps: [])
    }

    public static func buildEither(first component: AgentLoopSequence) -> AgentLoopSequence { component }
    public static func buildEither(second component: AgentLoopSequence) -> AgentLoopSequence { component }

    public static func buildArray(_ components: [AgentLoopSequence]) -> AgentLoopSequence {
        AgentLoopSequence(steps: components.flatMap(\.steps))
    }

    public static func buildExpression(_ loop: AgentLoopSequence) -> AgentLoopSequence { loop }

    public static func buildExpression<L: AgentLoop>(_ loop: L) -> AgentLoopSequence {
        AgentLoopSequence(steps: loop.steps)
    }

    public static func buildExpression(_ step: OrchestrationStep) -> AgentLoopSequence {
        AgentLoopSequence(steps: [step])
    }

    public static func buildExpression(_ agent: any AgentRuntime) -> AgentLoopSequence {
        AgentLoopSequence(steps: [AgentStep(agent)])
    }

    public static func buildExpression<A: AgentLoopDefinition>(_ agent: A) -> AgentLoopSequence {
        AgentLoopSequence(steps: [LoopAgentStep(agent)])
    }
}
