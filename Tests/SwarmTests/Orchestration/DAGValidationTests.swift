import Testing
@testable import Swarm

@Suite("DAG Validation")
struct DAGValidationTests {
    @Test("Empty DAG fails with typed validation error")
    func emptyDagFailsTyped() async {
        let dag = DAG {}

        await #expect(throws: OrchestrationError.self) {
            _ = try await dag.execute("input", context: makeContext())
        }
    }

    @Test("Unknown dependency fails with typed validation error")
    func unknownDependencyFailsTyped() async {
        let dag = DAG {
            DAGNode("a", step: EchoStep())
            DAGNode("b", step: EchoStep()).dependsOn("missing")
        }

        do {
            _ = try await dag.execute("input", context: makeContext())
            Issue.record("Expected typed DAG validation failure")
        } catch let error as OrchestrationError {
            guard case let .invalidGraph(validationError) = error else {
                Issue.record("Expected invalidGraph, got \(error)")
                return
            }
            guard case let .unknownDependency(node, dependency, _) = validationError else {
                Issue.record("Expected unknownDependency, got \(validationError)")
                return
            }
            #expect(node == "b")
            #expect(dependency == "missing")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Duplicate node name fails with typed validation error")
    func duplicateNodeFailsTyped() async {
        let dag = DAG {
            DAGNode("a", step: EchoStep())
            DAGNode("a", step: EchoStep())
        }

        do {
            _ = try await dag.execute("input", context: makeContext())
            Issue.record("Expected typed DAG validation failure")
        } catch let error as OrchestrationError {
            guard case let .invalidGraph(validationError) = error else {
                Issue.record("Expected invalidGraph, got \(error)")
                return
            }
            #expect(validationError == .duplicateNode(name: "a"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Cycle fails with typed validation error")
    func cycleFailsTyped() async {
        let dag = DAG {
            DAGNode("a", step: EchoStep()).dependsOn("b")
            DAGNode("b", step: EchoStep()).dependsOn("a")
        }

        do {
            _ = try await dag.execute("input", context: makeContext())
            Issue.record("Expected typed DAG validation failure")
        } catch let error as OrchestrationError {
            guard case let .invalidGraph(validationError) = error else {
                Issue.record("Expected invalidGraph, got \(error)")
                return
            }
            guard case let .cycleDetected(nodes) = validationError else {
                Issue.record("Expected cycleDetected, got \(validationError)")
                return
            }
            #expect(Set(nodes) == Set(["a", "b"]))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private struct EchoStep: OrchestrationStep {
    func execute(_ input: String, context _: OrchestrationStepContext) async throws -> AgentResult {
        AgentResult(output: input)
    }
}

private func makeContext() -> OrchestrationStepContext {
    OrchestrationStepContext(
        agentContext: AgentContext(input: "input"),
        session: nil,
        hooks: nil,
        orchestrator: nil,
        orchestratorName: "dag-test",
        handoffs: []
    )
}
