// HandoffIdentityTests.swift
// SwarmTests

import Foundation
@testable import Swarm
import Testing

@Suite("Handoff Identity Matching Tests")
struct HandoffIdentityMatchingTests {
    @Test("Matches handoff configuration by identity for same agent type")
    func matchesByIdentity() async throws {
        let agentA = IdentityAgent(name: "AgentA")
        let agentB = IdentityAgent(name: "AgentB")

        let handoffs = [
            AnyHandoffConfiguration(handoff(to: agentA)),
            AnyHandoffConfiguration(handoff(to: agentB))
        ]

        let context = OrchestrationStepContext(
            agentContext: AgentContext(input: "input"),
            session: nil,
            hooks: nil,
            orchestrator: nil,
            orchestratorName: "Orchestrator",
            handoffs: handoffs
        )

        let configA = context.findHandoffConfiguration(for: agentA)
        let configB = context.findHandoffConfiguration(for: agentB)

        #expect(configA?.targetName == "AgentA")
        #expect(configB?.targetName == "AgentB")
    }
}

private actor IdentityAgent: AgentRuntime {
    nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions: String = "Test"
    nonisolated let configuration: AgentConfiguration

    init(name: String) {
        var config = AgentConfiguration.default
        config.name = name
        configuration = config
    }

    func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult {
        AgentResult(output: input)
    }

    nonisolated func stream(
        _ input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func cancel() async {}
}
