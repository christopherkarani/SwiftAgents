// SwiftUIDSLIntegrationTests.swift
// SwarmTests
//
// Integration tests for the SwiftUI-style DSL additions (environment + Guard).

@testable import Swarm
import Testing

@Suite("SwiftUI DSL Integration Tests")
struct SwiftUIDSLIntegrationTests {
    @Test("Environment provides inference provider to agents")
    func environmentProvidesInferenceProvider() async throws {
        let provider = MockInferenceProvider(responses: ["Final Answer: Hello"])
        let base = ReActAgent(tools: [], instructions: "Test agent")

        let result = try await base
            .environment(\.inferenceProvider, provider)
            .run("Hi")

        #expect(result.output.contains("Hello"))
        #expect(await provider.generateCallCount == 1)
    }

    @Test("Environment works through AgentBlueprint lifting")
    func environmentWorksThroughBlueprint() async throws {
        struct Blueprint: AgentBlueprint {
            @OrchestrationBuilder var body: some OrchestrationStep {
                ReActAgent(tools: [], instructions: "Blueprint agent")
            }
        }

        let provider = MockInferenceProvider(responses: ["Final Answer: OK"])
        let result = try await Blueprint()
            .environment(\.inferenceProvider, provider)
            .run("x")

        #expect(result.output.contains("OK"))
    }

    @Test("Guard(.input) trips input guardrails")
    func guardInputTrips() async throws {
        let guardrail = ClosureInputGuardrail(name: "block_input") { input, _ in
            input.contains("BLOCK") ? .tripwire(message: "blocked") : .passed()
        }

        let workflow = Orchestration {
            Guard(.input) { guardrail }
        }

        do {
            _ = try await workflow.run("please BLOCK this")
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

    @Test("Guard(.output) trips output guardrails")
    func guardOutputTrips() async throws {
        let guardrail = ClosureOutputGuardrail(name: "block_output") { output, _, _ in
            output.contains("BAD") ? .tripwire(message: "blocked") : .passed()
        }

        let workflow = Orchestration {
            Transform { _ in "BAD output" }
            Guard(.output) { guardrail }
        }

        do {
            _ = try await workflow.run("x")
            Issue.record("Expected output guardrail to trip")
        } catch let error as GuardrailError {
            switch error {
            case .outputTripwireTriggered(let guardrailName, _, _, _):
                #expect(guardrailName == "block_output")
            default:
                Issue.record("Unexpected GuardrailError: \(error)")
            }
        }
    }

    @Test("Chat uses environment inference provider")
    func chatUsesEnvironmentProvider() async throws {
        let provider = MockInferenceProvider(responses: ["Hello from Chat"])
        let chat = ChatAgent("Be brief.")

        let result = try await chat
            .environment(\.inferenceProvider, provider)
            .run("Hi")

        #expect(result.output == "Hello from Chat")
    }
}
