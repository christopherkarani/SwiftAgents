// Generate.swift
// SwiftAgents Framework
//
// Core LLM execution step for declarative `Agent` loops.

import Foundation

/// Executes the current `Agent`'s core model step.
///
/// Place `Generate()` in an agent's `loop` to make the "model turn" explicit.
/// The generated output becomes the next step's input.
public struct Generate: OrchestrationStep {
    public init() {}

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        guard let orchestrator = context.orchestrator as? any _LoopOrchestrator else {
            throw AgentError.internalError(reason: "Generate() can only be used inside an Agent loop")
        }

        return try await orchestrator._generate(input, session: context.session, hooks: context.hooks)
    }
}

@available(*, deprecated, renamed: "Generate")
public typealias Respond = Generate
