// HandoffConfiguration+Lookup.swift
// Swarm Framework
//
// Shared handoff lookup helper to centralize runtime identity matching.

import Foundation

extension Sequence where Element == AnyHandoffConfiguration {
    /// Finds the first handoff configuration matching the target agent runtime.
    ///
    /// This is an internal routing helper. External callers should use the
    /// orchestrator's public API to initiate or inspect handoffs.
    func handoffConfiguration(for targetAgent: any AgentRuntime) -> AnyHandoffConfiguration? {
        first { config in
            areSameRuntime(config.targetAgent, targetAgent)
        }
    }
}
