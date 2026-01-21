// Orchestrator.swift
// SwiftAgents Framework
//
// Core protocol and helpers for multi-agent orchestration.

import Foundation

// MARK: - OrchestratorProtocol

/// Marker protocol for orchestrators coordinating multiple agents.
public protocol OrchestratorProtocol: AgentRuntime {
    /// Human-friendly name for this orchestrator, used in handoff metadata.
    nonisolated var orchestratorName: String { get }
}

public extension OrchestratorProtocol {
    nonisolated var orchestratorName: String {
        let configured = configuration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configured.isEmpty {
            return configured
        }
        return String(describing: type(of: self))
    }

    /// Finds a handoff configuration for the given target agent.
    func findHandoffConfiguration(for targetAgent: any AgentRuntime) -> AnyHandoffConfiguration? {
        handoffs.first { config in
            let configTargetType = type(of: config.targetAgent)
            let currentType = type(of: targetAgent)
            return configTargetType == currentType
        }
    }
}

// MARK: - Orchestrator Conformances

extension AgentRouter: OrchestratorProtocol {}
extension ParallelGroup: OrchestratorProtocol {}
extension SequentialChain: OrchestratorProtocol {}
extension SupervisorAgent: OrchestratorProtocol {}
