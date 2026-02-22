// AgentStateInspection.swift
// Swarm Framework
//
// Optional protocol for runtime state inspection by orchestrators.

import Foundation

/// Public, transport-safe execution snapshot for orchestration decisions.
public struct AgentExecutionSnapshot: Sendable, Equatable {
    /// Node identifiers currently scheduled to run.
    public let activeNodes: [String]

    /// Current superstep index.
    public let stepIndex: Int

    /// Whether the agent is currently interrupted and awaiting an external resume.
    public let isInterrupted: Bool

    public init(
        activeNodes: [String],
        stepIndex: Int,
        isInterrupted: Bool
    ) {
        self.activeNodes = activeNodes
        self.stepIndex = stepIndex
        self.isInterrupted = isInterrupted
    }
}

/// Optional protocol for runtimes that can expose current execution state.
public protocol AgentStateInspectable: Sendable {
    func currentExecutionSnapshot() async throws -> AgentExecutionSnapshot?
}
