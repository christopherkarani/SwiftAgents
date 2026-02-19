import Foundation
import Testing
@testable import Swarm

@Suite("Orchestration performance smoke")
struct OrchestrationPerformanceSmokeTests {
    @Test("Supervisor fan-out smoke: routes across many agents repeatedly")
    func supervisorFanOutSmoke() async throws {
        let agents: [(name: String, agent: any AgentRuntime, description: AgentDescription)] = (0 ..< 64).map { index in
            let name = "agent-\(index)"
            return (
                name,
                StaticEchoAgent(name: name, output: "ok-\(index)"),
                AgentDescription(name: name, description: "agent \(index)", keywords: [name])
            )
        }

        let supervisor = SupervisorAgent(
            agents: agents,
            routingStrategy: ConstantRoutingStrategy(agentName: "agent-63")
        )

        let clock = ContinuousClock()
        let start = clock.now
        for _ in 0 ..< 100 {
            let result = try await supervisor.run("fanout")
            #expect(result.output == "ok-63")
        }
        let duration = clock.now - start
        #expect(duration < .seconds(10))
    }

    @Test("Supervisor interruption fallback policy smoke remains responsive")
    func supervisorInterruptionFallbackSmoke() async throws {
        let primary = InterruptingInspectablePerformanceAgent(name: "primary")
        let fallback = StaticEchoAgent(name: "fallback", output: "fallback")
        let supervisor = SupervisorAgent(
            agents: [("primary", primary, AgentDescription(name: "primary", description: "primary"))],
            routingStrategy: ConstantRoutingStrategy(agentName: "primary"),
            fallbackAgent: fallback,
            interruptionPolicy: .fallback
        )

        let clock = ContinuousClock()
        let start = clock.now
        for _ in 0 ..< 100 {
            let result = try await supervisor.run("interrupt")
            #expect(result.output == "fallback")
        }
        let duration = clock.now - start
        #expect(duration < .seconds(10))
    }
}

private struct ConstantRoutingStrategy: RoutingStrategy {
    let agentName: String

    func selectAgent(
        for _: String,
        from _: [AgentDescription],
        context _: AgentContext?
    ) async throws -> RoutingDecision {
        RoutingDecision(selectedAgentName: agentName)
    }
}

private actor StaticEchoAgent: AgentRuntime {
    nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions = ""
    nonisolated let configuration: AgentConfiguration
    private let output: String

    init(name: String, output: String) {
        configuration = AgentConfiguration(name: name)
        self.output = output
    }

    func run(
        _: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) async throws -> AgentResult {
        AgentResult(output: output)
    }

    nonisolated func stream(
        _: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.completed(result: AgentResult(output: output)))
            continuation.finish()
        }
    }

    func cancel() async {}
}

private actor InterruptingInspectablePerformanceAgent: AgentRuntime, AgentStateInspectable {
    nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions = ""
    nonisolated let configuration: AgentConfiguration

    init(name: String) {
        configuration = AgentConfiguration(name: name)
    }

    func run(
        _: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) async throws -> AgentResult {
        throw AgentError.internalError(reason: "interrupted")
    }

    nonisolated func stream(
        _: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.failed(error: AgentError.internalError(reason: "interrupted")))
            continuation.finish(throwing: AgentError.internalError(reason: "interrupted"))
        }
    }

    func currentExecutionSnapshot() async throws -> AgentExecutionSnapshot? {
        AgentExecutionSnapshot(activeNodes: ["toolExecute"], stepIndex: 1, isInterrupted: true)
    }

    func cancel() async {}
}
