// AgentLoop.swift
// SwiftAgents Framework
//
// SwiftUI-style sequential loop container for declarative agent definitions.

import Foundation

/// A sequential loop of steps.
///
/// `AgentLoop` is the core building block of the declarative DSL. Code order
/// matches execution order: each step receives the previous step's output as input.
public struct AgentLoop: Sendable {
    // MARK: Internal

    let steps: [OrchestrationStep]

    // MARK: Public

    public init(steps: [OrchestrationStep]) {
        self.steps = steps
    }

    // MARK: Internal Execution

    func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
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
            if Task.isCancelled {
                throw AgentError.cancelled
            }

            let result = try await step.execute(currentInput, context: context)

            allToolCalls.append(contentsOf: result.toolCalls)
            allToolResults.append(contentsOf: result.toolResults)
            totalIterations += result.iterationCount

            for (key, value) in result.metadata {
                // Preserve last-write-wins metadata at top-level for convenience.
                // Namespaced copies are also stored for provenance.
                allMetadata[key] = value
                allMetadata["loop.step_\(index).\(key)"] = value
            }

            await context.agentContext.setPreviousOutput(result)
            currentInput = result.output
        }

        let duration = ContinuousClock.now - startTime
        allMetadata["loop.total_steps"] = .int(steps.count)
        allMetadata["loop.total_duration"] = .double(
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

