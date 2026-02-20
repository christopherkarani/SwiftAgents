// Orchestrator.swift
// Swarm Framework
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
        handoffDisplayName(for: self, fallbackTypeName: "Orchestrator")
    }

    /// Finds a handoff configuration for the given target agent.
    func findHandoffConfiguration(for targetAgent: any AgentRuntime) -> AnyHandoffConfiguration? {
        resolveHandoffConfiguration(for: targetAgent, in: handoffs)
    }
}

// MARK: - Orchestrator Conformances

extension AgentRouter: OrchestratorProtocol {}
extension ParallelGroup: OrchestratorProtocol {}
extension SequentialChain: OrchestratorProtocol {}
extension SupervisorAgent: OrchestratorProtocol {}
