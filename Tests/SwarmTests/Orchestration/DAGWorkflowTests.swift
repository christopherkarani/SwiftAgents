import Foundation
@testable import Swarm
import Testing

@Suite("DAG Workflow Tests")
struct DAGWorkflowTests {
    private func makeContext() -> OrchestrationStepContext {
        OrchestrationStepContext(
            agentContext: AgentContext(input: "test"),
            session: nil,
            hooks: nil,
            orchestrator: nil,
            orchestratorName: "DAGWorkflowTests",
            handoffs: []
        )
    }

    @Test("Validation rejects duplicate node names")
    func validationRejectsDuplicateNames() throws {
        let nodes = [
            DAGNode("dup", step: Transform { $0 }),
            DAGNode("dup", step: Transform { $0 })
        ]

        do {
            try DAG.validateNodes(nodes)
            #expect(Bool(false), "Expected DAG.validateNodes to throw on duplicate names.")
        } catch let error as DAGValidationError {
            #expect(error == .duplicateNames(["dup"]))
        }
    }

    @Test("Execution combines terminal node outputs")
    func executionCombinesTerminalOutputs() async throws {
        let workflow = DAG {
            DAGNode("root", step: Transform { $0 })
            DAGNode("left", step: Transform { "L:\($0)" })
                .dependsOn("root")
            DAGNode("right", step: Transform { "R:\($0)" })
                .dependsOn("root")
        }

        let result = try await workflow.execute("input", context: makeContext())
        #expect(result.output == "L:input\nR:input")
    }
}
