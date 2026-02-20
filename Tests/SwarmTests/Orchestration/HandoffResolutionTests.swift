// HandoffResolutionTests.swift
// SwarmTests
//
// Tests for shared handoff resolution and application semantics.

import Foundation
@testable import Swarm
import Testing

@Suite("Handoff Resolution Tests")
struct HandoffResolutionTests {
    @Test("resolveHandoffConfiguration prioritizes exact runtime match")
    func exactRuntimeMatchTakesPrecedence() async {
        let targetForLookup = MockHandoffAgent(name: "target-1")
        let exactTarget = targetForLookup
        let nameMatchTarget = MockHandoffAgent(name: "target-1")
        let typeMatchTarget = MockHandoffAgent(name: "target-2")

        let handoffs: [AnyHandoffConfiguration] = [
            AnyHandoffConfiguration(targetAgent: nameMatchTarget),
            AnyHandoffConfiguration(targetAgent: typeMatchTarget),
            AnyHandoffConfiguration(targetAgent: exactTarget)
        ]

        let resolved = resolveHandoffConfiguration(for: targetForLookup, in: handoffs)
        #expect((resolved?.targetAgent as? MockHandoffAgent) === exactTarget)
    }

    @Test("resolveHandoffConfiguration falls back to configured name match")
    func nameMatchUsedWhenExactMatchMissing() async {
        let targetForLookup = MockHandoffAgent(name: "planner")
        let nameMatchTarget = MockHandoffAgent(name: "planner")
        let typeMatchTarget = MockHandoffAgent(name: "planner-type")

        let handoffs: [AnyHandoffConfiguration] = [
            AnyHandoffConfiguration(targetAgent: typeMatchTarget),
            AnyHandoffConfiguration(targetAgent: nameMatchTarget)
        ]

        let resolved = resolveHandoffConfiguration(for: targetForLookup, in: handoffs)
        #expect((resolved?.targetAgent as? MockHandoffAgent) === nameMatchTarget)
    }

    @Test("resolveHandoffConfiguration falls back to type match")
    func typeMatchUsedWhenExactAndNameMatchMissing() async {
        let targetForLookup = MockHandoffAgent(name: "type-lookup")
        let typeMatchTarget = MockHandoffAgent(name: "type-target")

        let handoffs: [AnyHandoffConfiguration] = [
            AnyHandoffConfiguration(targetAgent: typeMatchTarget)
        ]

        let resolved = resolveHandoffConfiguration(for: targetForLookup, in: handoffs)
        #expect((resolved?.targetAgent as? MockHandoffAgent) === typeMatchTarget)
    }

    @Test("applyResolvedHandoffConfiguration uses the provided input context snapshot")
    func applyResolvedHandoffConfigurationUsesProvidedInputContextSnapshot() async throws {
        let target = MockHandoffAgent(name: "executor")
        let liveContext = AgentContext(input: "agent input")

        await liveContext.set("live-key", value: .string("from-live-context"))

        let inputContextSnapshot: [String: SendableValue] = [
            "snapshot-key": .string("from-snapshot")
        ]

        let inputFilter: InputFilterCallback = { inputData in
            var modified = inputData
            if let snapshotValue = inputData.context["snapshot-key"] {
                modified.metadata["snapshot-key"] = snapshotValue
            }
            if let liveValue = inputData.context["live-key"] {
                modified.metadata["live-key"] = liveValue
            }
            return modified
        }

        let applied = try await applyResolvedHandoffConfiguration(
            sourceAgentName: "planner",
            to: target,
            input: "handoff payload",
            handoffs: [AnyHandoffConfiguration(targetAgent: target, inputFilter: inputFilter)],
            context: liveContext,
            inputContextSnapshot: inputContextSnapshot
        )

        #expect(applied.effectiveInput == "handoff payload")
        #expect(applied.metadata["snapshot-key"]?.stringValue == "from-snapshot")
        #expect(applied.metadata["live-key"] == nil)
        #expect(await liveContext.get("snapshot-key")?.stringValue == "from-snapshot")
        #expect(await liveContext.get("live-key")?.stringValue == "from-live-context")
    }
}
