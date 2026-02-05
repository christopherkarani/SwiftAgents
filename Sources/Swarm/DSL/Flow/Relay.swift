// Relay.swift
// Swarm Framework
//
// Unified model execution step for declarative `Agent` loops.

import Foundation

@available(
    *,
    deprecated,
    message: "Deprecated legacy loop DSL step. Prefer AgentBlueprint and embed a runtime AgentRuntime step for model turns (eventually the unified runtime Agent)."
)
/// Executes the current `Agent`'s unified model turn.
///
/// Place `Relay()` in an agent's `loop` to make the "model turn" explicit.
/// The generated output becomes the next step's input.
public struct Relay: OrchestrationStep {
    public init() {}

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        guard let orchestrator = context.orchestrator as? any _LoopOrchestrator else {
            throw AgentError.internalError(reason: "Relay() can only be used inside an Agent loop")
        }

        return try await orchestrator._generate(input, session: context.session, hooks: context.hooks)
    }
}
