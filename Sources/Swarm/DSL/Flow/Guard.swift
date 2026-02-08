// Guard.swift
// Swarm Framework
//
// Structural input/output validation steps for orchestrations.

import Foundation

/// Indicates whether a `Guard` validates input or output.
public enum GuardPhase: Sendable {
    case input
    case output
}

@resultBuilder
public struct GuardrailBuilder {
    public static func buildBlock(_ components: [any Guardrail]...) -> [any Guardrail] {
        components.flatMap(\.self)
    }

    public static func buildOptional(_ component: [any Guardrail]?) -> [any Guardrail] {
        component ?? []
    }

    public static func buildEither(first component: [any Guardrail]) -> [any Guardrail] { component }
    public static func buildEither(second component: [any Guardrail]) -> [any Guardrail] { component }

    public static func buildArray(_ components: [[any Guardrail]]) -> [any Guardrail] {
        components.flatMap(\.self)
    }

    public static func buildExpression(_ expression: any Guardrail) -> [any Guardrail] {
        [expression]
    }

    public static func buildExpression(_ expression: [any Guardrail]) -> [any Guardrail] {
        expression
    }
}

/// Validates input or output using guardrails.
///
/// `Guard` is an `OrchestrationStep` so it can be placed inline in an `Orchestration`
/// or `AgentBlueprint` to make validation visible in the execution flow.
///
/// - `Guard(.input)` validates the current input.
/// - `Guard(.output)` validates the current value as "output from the previous step".
public struct Guard: OrchestrationStep {
    public let phase: GuardPhase
    public let guardrails: [any Guardrail]
    public let runnerConfiguration: GuardrailRunnerConfiguration

    public init(
        _ phase: GuardPhase,
        configuration: GuardrailRunnerConfiguration = .default,
        @GuardrailBuilder _ content: () -> [any Guardrail]
    ) {
        self.phase = phase
        guardrails = content()
        runnerConfiguration = configuration
    }

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        let startTime = ContinuousClock.now
        let runner = GuardrailRunner(configuration: runnerConfiguration, hooks: context.hooks)

        switch phase {
        case .input:
            let inputGuardrails = guardrails.compactMap { $0 as? any InputGuardrail }
            if !inputGuardrails.isEmpty {
                _ = try await runner.runInputGuardrails(inputGuardrails, input: input, context: context.agentContext)
            }
        case .output:
            let outputGuardrails = guardrails.compactMap { $0 as? any OutputGuardrail }
            if !outputGuardrails.isEmpty {
                let agent = context.orchestrator ?? GuardDummyAgent()
                _ = try await runner.runOutputGuardrails(
                    outputGuardrails,
                    output: input,
                    agent: agent,
                    context: context.agentContext
                )
            }
        }

        let duration = ContinuousClock.now - startTime

        return AgentResult(
            output: input,
            toolCalls: [],
            toolResults: [],
            iterationCount: 1,
            duration: duration,
            tokenUsage: nil,
            metadata: [
                "guard.phase": .string(String(describing: phase)),
                "guard.count": .int(guardrails.count),
                "guard.duration": .double(
                    Double(duration.components.seconds) +
                        Double(duration.components.attoseconds) / 1e18
                ),
            ]
        )
    }
}

// MARK: - GuardDummyAgent

private struct GuardDummyAgent: AgentRuntime {
    var tools: [any AnyJSONTool] { [] }
    var instructions: String { "GuardDummyAgent" }
    var configuration: AgentConfiguration { AgentConfiguration(name: "Guard") }

    func run(_ input: String, session _: (any Session)?, hooks _: (any RunHooks)?) async throws -> AgentResult {
        AgentResult(output: input)
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            continuation.yield(.completed(result: AgentResult(output: input)))
            continuation.finish()
        }
    }

    func cancel() async {}
}
