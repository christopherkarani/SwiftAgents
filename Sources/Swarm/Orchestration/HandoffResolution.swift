// HandoffResolution.swift
// Swarm Framework
//
// Shared utilities for resolving and applying handoff configuration semantics.

import Foundation

struct AppliedHandoffConfiguration: Sendable {
    let configuration: AnyHandoffConfiguration?
    let effectiveInput: String
    let metadata: [String: SendableValue]
}

func applyHandoffMetadata(_ metadata: [String: SendableValue], to result: AgentResult) -> AgentResult {
    guard !metadata.isEmpty else {
        return result
    }

    let mergedMetadata = result.metadata.merging(metadata) { current, _ in current }

    return AgentResult(
        output: result.output,
        toolCalls: result.toolCalls,
        toolResults: result.toolResults,
        iterationCount: result.iterationCount,
        duration: result.duration,
        tokenUsage: result.tokenUsage,
        metadata: mergedMetadata
    )
}

func handoffDisplayName(for agent: any AgentRuntime, fallbackTypeName: String = "") -> String {
    let configured = agent.configuration.name.trimmingCharacters(in: .whitespacesAndNewlines)
    if !configured.isEmpty {
        return configured
    }

    if !fallbackTypeName.isEmpty {
        return fallbackTypeName
    }

    return String(describing: type(of: agent))
}

func areSameRuntime(_ lhs: any AgentRuntime, _ rhs: any AgentRuntime) -> Bool {
    if let lhsObject = lhs as? AnyObject, let rhsObject = rhs as? AnyObject {
        return ObjectIdentifier(lhsObject) == ObjectIdentifier(rhsObject)
    }

    return type(of: lhs) == type(of: rhs)
}

func resolveHandoffConfiguration(
    for targetAgent: any AgentRuntime,
    in handoffs: [AnyHandoffConfiguration]
) -> AnyHandoffConfiguration? {
    if let exactMatch = handoffs.first(where: { areSameRuntime($0.targetAgent, targetAgent) }) {
        return exactMatch
    }

    let targetName = handoffDisplayName(for: targetAgent)
    if let nameMatch = handoffs.first(where: { handoffDisplayName(for: $0.targetAgent) == targetName }) {
        return nameMatch
    }

    let targetType = type(of: targetAgent)
    return handoffs.first(where: { type(of: $0.targetAgent) == targetType })
}

func applyResolvedHandoffConfiguration(
    sourceAgentName: String,
    to targetAgent: any AgentRuntime,
    targetName: String? = nil,
    input: String,
    handoffs: [AnyHandoffConfiguration],
    context: AgentContext,
    inputContextSnapshot: [String: SendableValue]? = nil
) async throws -> AppliedHandoffConfiguration {
    let resolvedTargetName = targetName ?? handoffDisplayName(for: targetAgent)

    guard let config = resolveHandoffConfiguration(for: targetAgent, in: handoffs) else {
        return AppliedHandoffConfiguration(
            configuration: nil,
            effectiveInput: input,
            metadata: [:]
        )
    }

    if let isEnabled = config.isEnabled {
        let enabled = await isEnabled(context, targetAgent)
        if !enabled {
            throw OrchestrationError.handoffSkipped(
                from: sourceAgentName,
                to: resolvedTargetName,
                reason: "Handoff disabled by isEnabled callback"
            )
        }
    }

    let resolvedContextSnapshot: [String: SendableValue]
    if let inputContextSnapshot {
        resolvedContextSnapshot = inputContextSnapshot
    } else {
        resolvedContextSnapshot = await context.snapshot
    }

    var inputData = HandoffInputData(
        sourceAgentName: sourceAgentName,
        targetAgentName: resolvedTargetName,
        input: input,
        context: resolvedContextSnapshot,
        metadata: [:]
    )

    if let inputFilter = config.inputFilter {
        inputData = inputFilter(inputData)
    }

    if let onHandoff = config.onHandoff {
        do {
            try await onHandoff(context, inputData)
        } catch {
            Log.orchestration.warning(
                "onHandoff callback failed for \(sourceAgentName) -> \(resolvedTargetName): \(error.localizedDescription)"
            )
        }
    }

    if !inputData.metadata.isEmpty {
        for (key, value) in inputData.metadata {
            await context.set(key, value: value)
        }
    }

    return AppliedHandoffConfiguration(
        configuration: config,
        effectiveInput: inputData.input,
        metadata: inputData.metadata
    )
}
