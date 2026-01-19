// AnyToolTests.swift
// SwiftAgentsTests
//
// Verifies AnyTool type-erasure preserves tool metadata and guardrails.

@testable import SwiftAgents
import Testing

@Suite("AnyTool Tests")
struct AnyToolTests {
    private struct GuardrailedTool: AnyJSONTool {
        let name: String = "guarded"
        let description: String = "A tool with guardrails"
        let parameters: [ToolParameter] = []
        let inputGuardrails: [any ToolInputGuardrail]
        let outputGuardrails: [any ToolOutputGuardrail]

        init(
            inputGuardrails: [any ToolInputGuardrail] = [],
            outputGuardrails: [any ToolOutputGuardrail] = []
        ) {
            self.inputGuardrails = inputGuardrails
            self.outputGuardrails = outputGuardrails
        }

        func execute(arguments _: [String: SendableValue]) async throws -> SendableValue {
            .string("ok")
        }
    }

    @Test("AnyTool forwards input/output guardrails")
    func forwardsGuardrails() {
        let input = ClosureToolInputGuardrail(name: "tripwire") { _ in
            .tripwire(message: "blocked")
        }
        let output = ClosureToolOutputGuardrail(name: "output_check") { _, _ in
            .passed()
        }

        let erased = AnyTool(GuardrailedTool(inputGuardrails: [input], outputGuardrails: [output]))

        #expect(erased.inputGuardrails.count == 1)
        #expect(erased.outputGuardrails.count == 1)
    }

    @Test("ToolRegistry executes guardrails for AnyTool-wrapped tools")
    func registryRunsGuardrailsForWrappedTool() async throws {
        let input = ClosureToolInputGuardrail(name: "tripwire") { _ in
            .tripwire(message: "blocked")
        }

        let tool = GuardrailedTool(inputGuardrails: [input])
        let registry = ToolRegistry(tools: [AnyTool(tool)])

        do {
            _ = try await registry.execute(toolNamed: tool.name, arguments: [:])
            Issue.record("Expected tool guardrail tripwire to throw")
        } catch let error as GuardrailError {
            #expect({
                if case .toolInputTripwireTriggered = error { return true }
                return false
            }(), "Expected GuardrailError.toolInputTripwireTriggered, got: \(error)")
        }
    }
}
