import Foundation
import Testing
@testable import Swarm

@Suite("Supervisor interruption-aware routing")
struct SupervisorInterruptionRoutingTests {
    @Test("Supervisor does not fallback when selected sub-agent is interrupted")
    func supervisorSkipsFallbackForInterruptedSubAgent() async throws {
        let primary = InterruptingInspectableAgent(name: "primary")
        let fallback = StaticResultAgent(name: "fallback", output: "fallback-output")
        let strategy = FixedRoutingStrategy(selected: "primary")

        let supervisor = SupervisorAgent(
            agents: [
                ("primary", primary, AgentDescription(name: "primary", description: "Primary agent")),
            ],
            routingStrategy: strategy,
            fallbackAgent: fallback
        )

        await #expect(throws: (any Error).self) {
            _ = try await supervisor.run("hello")
        }
    }

    @Test("Supervisor fallback policy routes interrupted sub-agent to fallback")
    func supervisorFallbackPolicyUsesFallbackOnInterrupt() async throws {
        let primary = InterruptingInspectableAgent(name: "primary")
        let fallback = StaticResultAgent(name: "fallback", output: "fallback-output")
        let strategy = FixedRoutingStrategy(selected: "primary")

        let supervisor = SupervisorAgent(
            agents: [
                ("primary", primary, AgentDescription(name: "primary", description: "Primary agent")),
            ],
            routingStrategy: strategy,
            fallbackAgent: fallback,
            interruptionPolicy: .fallback
        )

        let result = try await supervisor.run("hello")
        #expect(result.output == "fallback-output")
        #expect(result.metadata["routing_decision"]?.stringValue == "fallback")
    }

    @Test("Supervisor timeout-then-fallback policy routes after interruption timeout")
    func supervisorTimeoutThenFallbackPolicy() async throws {
        let primary = InterruptingInspectableAgent(name: "primary")
        let fallback = StaticResultAgent(name: "fallback", output: "timeout-fallback-output")
        let strategy = FixedRoutingStrategy(selected: "primary")

        let supervisor = SupervisorAgent(
            agents: [
                ("primary", primary, AgentDescription(name: "primary", description: "Primary agent")),
            ],
            routingStrategy: strategy,
            fallbackAgent: fallback,
            interruptionPolicy: .timeoutThenFallback(timeout: .milliseconds(50), pollInterval: .milliseconds(10))
        )

        let result = try await supervisor.run("hello")
        #expect(result.output == "timeout-fallback-output")
        #expect(result.metadata["routing_decision"]?.stringValue == "fallback")
    }

    @Test("Supervisor parallel-race policy prefers fallback when sub-agent stays interrupted")
    func supervisorParallelRacePolicyFallsBack() async throws {
        let primary = InterruptingInspectableAgent(name: "primary")
        let fallback = StaticResultAgent(name: "fallback", output: "race-fallback-output")
        let strategy = FixedRoutingStrategy(selected: "primary")

        let supervisor = SupervisorAgent(
            agents: [
                ("primary", primary, AgentDescription(name: "primary", description: "Primary agent")),
            ],
            routingStrategy: strategy,
            fallbackAgent: fallback,
            interruptionPolicy: .parallelRace(timeout: .milliseconds(50), pollInterval: .milliseconds(10))
        )

        let result = try await supervisor.run("hello")
        #expect(result.output == "race-fallback-output")
    }
}

private struct FixedRoutingStrategy: RoutingStrategy {
    let selected: String

    func selectAgent(
        for _: String,
        from _: [AgentDescription],
        context _: AgentContext?
    ) async throws -> RoutingDecision {
        RoutingDecision(selectedAgentName: selected, confidence: 1.0, reasoning: "test")
    }
}

private actor InterruptingInspectableAgent: AgentRuntime, AgentStateInspectable {
    nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions: String = ""
    nonisolated let configuration: AgentConfiguration

    init(name: String) {
        configuration = AgentConfiguration(name: name)
    }

    func run(
        _: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) async throws -> AgentResult {
        throw AgentError.internalError(reason: "tool approval pending")
    }

    nonisolated func stream(
        _: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.failed(error: AgentError.internalError(reason: "tool approval pending")))
            continuation.finish(throwing: AgentError.internalError(reason: "tool approval pending"))
        }
    }

    func cancel() async {}

    func currentExecutionSnapshot() async throws -> AgentExecutionSnapshot? {
        AgentExecutionSnapshot(activeNodes: [], stepIndex: 2, isInterrupted: true)
    }
}

private actor StaticResultAgent: AgentRuntime {
    nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions: String = ""
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
