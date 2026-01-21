// DeclarativeAgentDSLTests.swift
// SwiftAgentsTests
//
// Tests for the new SwiftUI-style `Agent` + `AgentLoop` DSL.

@testable import SwiftAgents
import Testing

// MARK: - Test Agents

private struct SampleSequentialAgent: Agent {
    var loop: some AgentLoop {
        Generate()
        Transform { input in "A\(input)" }
        Transform { input in "B\(input)" }
    }
}

private struct BillingAgent: Agent {
    var instructions: String { "You are billing support." }

    var loop: some AgentLoop {
        Generate()
    }
}

private struct GeneralSupportAgent: Agent {
    var loop: some AgentLoop {
        Generate()
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
        let provider = MockInferenceProvider(responses: ["x"])

        let result = try await SampleSequentialAgent()
            .environment(\.inferenceProvider, provider)
            .run("ignored")

        #expect(result.output == "BAx")
    }

    @Test("Generate uses environment inference provider and configuration")
    func generateUsesEnvironmentAndConfig() async throws {
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

    @Test("Generate fails if no inference provider is set")
    func generateFailsWithoutProvider() async throws {
        do {
            _ = try await BillingAgent().run("Hi")
            Issue.record("Expected inference provider missing error")
        } catch let error as AgentError {
            switch error {
            case .inferenceProviderUnavailable(let reason):
                #expect(reason.contains("Generate()"))
            default:
                Issue.record("Unexpected AgentError: \(error)")
            }
        }
    }

    @Test("AgentLoop must contain at least one Generate call")
    func agentLoopRequiresGenerate() async throws {
        struct NoGenerateAgent: Agent {
            var loop: some AgentLoop {
                Transform { _ in "ok" }
            }
        }

        do {
            _ = try await NoGenerateAgent().run("Hi")
            Issue.record("Expected invalid loop error")
        } catch let error as AgentError {
            switch error {
            case .invalidLoop(let reason):
                #expect(reason.contains("Generate()"))
            default:
                Issue.record("Unexpected AgentError: \(error)")
            }
        }
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
