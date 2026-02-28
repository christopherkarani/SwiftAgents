// OrchestrationStepCircularDefaultTests.swift
// SwarmTests
//
// Verifies that execute(_:hooks:) delegates to execute(_:context:) without
// infinite recursion, which was the bug introduced by a circular default.

import Testing
@testable import Swarm

@Suite("OrchestrationStep default implementation")
struct OrchestrationStepDefaultTests {

    // A conformer that only implements execute(_:context:) — the required method.
    // Before the fix this would stack-overflow. After the fix it should work.
    struct ContextOnlyStep: OrchestrationStep {
        func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
            AgentResult(output: "context:\(input)")
        }
    }

    @Test("execute(_:hooks:) delegates to execute(_:context:) without recursion")
    func hooksOverloadDelegatesWithoutRecursion() async throws {
        let step = ContextOnlyStep()
        let result = try await step.execute("hello", hooks: nil)
        #expect(result.output == "context:hello")
    }
}
