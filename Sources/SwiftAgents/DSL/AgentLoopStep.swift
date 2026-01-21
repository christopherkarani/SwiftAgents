// AgentLoopStep.swift
// SwiftAgents Framework
//
// OrchestrationStep adapter for executing an `AgentLoop` inline.

import Foundation

/// Executes an `AgentLoop` inline within an orchestration.
public struct AgentLoopStep: OrchestrationStep {
    public let loop: AgentLoopSequence

    public init<L: AgentLoop>(_ loop: L) {
        self.loop = AgentLoopSequence(steps: loop.steps)
    }

    public init(@AgentLoopBuilder _ content: () -> AgentLoopSequence) {
        loop = content()
    }

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        try await loop.execute(input, context: context)
    }
}

extension AgentLoopStep: _AgentLoopNestedSteps {
    var _nestedSteps: [OrchestrationStep] { loop.steps }
}
