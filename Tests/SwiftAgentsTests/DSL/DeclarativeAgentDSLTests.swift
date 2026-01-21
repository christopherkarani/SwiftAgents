// DeclarativeAgentDSLTests.swift
// SwiftAgentsTests
//
// Tests for the new SwiftUI-style `Agent` + `AgentLoop` DSL.

@testable import SwiftAgents
import Testing

// MARK: - Test Agents

private struct PrefixAgent: Agent {
    let prefix: String

    var loop: some AgentLoop {
        Transform { input in "\(prefix)\(input)" }
    }
}

private struct SampleSequentialAgent: Agent {
    var loop: some AgentLoop {
        PrefixAgent(prefix: "A")
        PrefixAgent(prefix: "B")
    }
}

private struct BillingAgent: Agent {
    var instructions: String { "You are billing support." }

    var loop: some AgentLoop {
        Respond()
    }
}

private struct GeneralSupportAgent: Agent {
    var loop: some AgentLoop {
        Transform { input in "general:\(input)" }
    }
}

private struct CustomerServiceAgent: Agent {
    var loop: some AgentLoop {
        Guard(.input) {
            InputGuard("block_input") { input in
                input.contains("BLOCK") ? .tripwire(message: "blocked") : .passed()
            }
        }

        Routes {
            When(.contains("bill"), name: "billing") {
                BillingAgent()
                    .temperature(0.2)
            }
            Otherwise {
                GeneralSupportAgent()
            }
        }

        Guard(.output) {
            OutputGuard("block_bad_output") { output in
                output.contains("BAD") ? .tripwire(message: "blocked") : .passed()
            }
        }
    }
}

// MARK: - Tests

@Suite("Declarative Agent DSL Tests")
struct DeclarativeAgentDSLTests {
    @Test("AgentLoop runs steps sequentially")
    func agentLoopIsSequential() async throws {
        let result = try await SampleSequentialAgent().run("x")
        #expect(result.output == "BAx")
    }

    @Test("Respond uses environment inference provider and configuration")
    func respondUsesEnvironmentAndConfig() async throws {
        let provider = MockInferenceProvider(responses: ["OK"])

        let result = try await BillingAgent()
            .temperature(0.2)
            .environment(\.inferenceProvider, provider)
            .run("Hi")

        #expect(result.output == "OK")

        let calls = await provider.generateCalls
        #expect(calls.count == 1)
        #expect(calls[0].options.temperature == 0.2)
    }

    @Test("Routes selects the first matching branch")
    func routesSelectFirstMatch() async throws {
        let provider = MockInferenceProvider(responses: ["billing:ok"])

        let result = try await CustomerServiceAgent()
            .environment(\.inferenceProvider, provider)
            .run("billing help")

        #expect(result.output == "billing:ok")
        #expect(result.metadata["routes.matched_route"]?.stringValue == "billing")
    }

    @Test("Guard(.input) trips using InputGuard")
    func inputGuardTrips() async throws {
        do {
            _ = try await CustomerServiceAgent().run("please BLOCK this")
            Issue.record("Expected input guardrail to trip")
        } catch let error as GuardrailError {
            switch error {
            case .inputTripwireTriggered(let guardrailName, _, _):
                #expect(guardrailName == "block_input")
            default:
                Issue.record("Unexpected GuardrailError: \(error)")
            }
        }
    }

    @Test("Agent handoffs emit RunHooks.onHandoff")
    func handoffEmitsHook() async throws {
        actor Recorder: RunHooks {
            var events: [(from: String, to: String)] = []

            func onHandoff(context _: AgentContext?, fromAgent: any AgentRuntime, toAgent: any AgentRuntime) async {
                events.append((from: fromAgent.configuration.name, to: toAgent.configuration.name))
            }
        }

        let provider = MockInferenceProvider(responses: ["billing:ok"])
        let hooks = Recorder()

        _ = try await CustomerServiceAgent()
            .environment(\.inferenceProvider, provider)
            .run("billing help", hooks: hooks)

        let events = await hooks.events
        #expect(events.contains { $0.from == "CustomerServiceAgent" && $0.to == "BillingAgent" })
    }
}
