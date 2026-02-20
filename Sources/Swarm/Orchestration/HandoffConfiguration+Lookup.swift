// HandoffConfiguration+Lookup.swift
// Swarm Framework
//
// Shared handoff lookup helper to centralize runtime identity matching.

import Foundation

public extension Sequence where Element == AnyHandoffConfiguration {
    /// Finds the first handoff configuration matching the target agent runtime.
    func handoffConfiguration(for targetAgent: any AgentRuntime) -> AnyHandoffConfiguration? {
        first { config in
            areSameRuntime(config.targetAgent, targetAgent)
        }
    }
}
