// AgentLoop.swift
// Swarm Framework
//
// SwiftUI-style sequential loop protocol for declarative agent definitions.

import Foundation

/// A sequential loop of steps.
///
/// `AgentLoop` is the core building block of the declarative DSL. Code order
/// matches execution order: each step receives the previous step's output as input.
public protocol AgentLoop: Sendable {
    /// The concrete orchestration steps represented by this loop.
    var steps: [OrchestrationStep] { get }
}

/// The default concrete loop implementation produced by `@AgentLoopBuilder`.
public struct AgentLoopSequence: AgentLoop, Sendable {
    public let steps: [OrchestrationStep]

    public init(steps: [OrchestrationStep]) {
        self.steps = steps
    }
}

public extension AgentLoop {
    func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        guard !steps.isEmpty else {
            throw AgentError.invalidLoop(
                reason: "AgentLoop for '\(context.orchestratorName)' has no steps. Add at least one Generate() or Relay() call."
            )
        }

        var visitedAgents: Set<ObjectIdentifier> = []
        let hasGenerate = try _agentLoopContainsGenerate(steps: steps, visitedAgents: &visitedAgents)
        guard hasGenerate else {
            throw AgentError.invalidLoop(
                reason: "AgentLoop for '\(context.orchestratorName)' must include at least one Generate() or Relay() call."
            )
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

// MARK: - Validation

protocol _AgentLoopNestedSteps {
    var _nestedSteps: [OrchestrationStep] { get }
}

protocol _AgentLoopNestedAgentSteps: _AgentLoopNestedSteps {
    var _agentType: ObjectIdentifier { get }
}

private func _agentLoopContainsGenerate(
    steps: [OrchestrationStep],
    visitedAgents: inout Set<ObjectIdentifier>
) throws -> Bool {
    for step in steps {
        if step is Generate || step is Relay { return true }

        if let nestedAgent = step as? any _AgentLoopNestedAgentSteps {
            let id = nestedAgent._agentType
            if visitedAgents.contains(id) {
                throw AgentError.invalidLoop(
                    reason: "Cyclic agent reference detected while validating Generate() calls."
                )
            }
            visitedAgents.insert(id)
            defer { visitedAgents.remove(id) }

            if try _agentLoopContainsGenerate(steps: nestedAgent._nestedSteps, visitedAgents: &visitedAgents) {
                return true
            }
            continue
        }

        if let nested = step as? any _AgentLoopNestedSteps {
            if try _agentLoopContainsGenerate(steps: nested._nestedSteps, visitedAgents: &visitedAgents) {
                return true
            }
        }
    }
    return false
}
