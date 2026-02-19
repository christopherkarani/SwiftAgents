// DAGWorkflowTests.swift
// Swarm Framework
//
// Tests for DAG validation and output behavior.

@testable import Swarm
import Testing

private struct ConstantStep: OrchestrationStep {
    let output: String

    func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        AgentResult(output: output)
    }
}

@Suite("DAG Workflow")
struct DAGWorkflowTests {
    @Test("Empty DAG throws validation error on execute")
    func emptyDAGThrows() async {
        let dag = DAG { }

        do {
            _ = try await dag.execute("input", hooks: nil)
            #expect(false, "Expected empty DAG to throw")
        } catch let error as DAGValidationError {
            #expect(error == .emptyGraph)
        } catch {
            #expect(false, "Unexpected error: \(error)")
        }
    }

    @Test("Missing dependency is surfaced as validation error")
    func missingDependencyThrows() async {
        let dag = DAG {
            DAGNode("a", step: ConstantStep(output: "A"))
                .dependsOn("missing")
        }

        do {
            _ = try await dag.execute("input", hooks: nil)
            #expect(false, "Expected missing dependency to throw")
        } catch let error as DAGValidationError {
            switch error {
            case let .missingDependency(node, dependency, _):
                #expect(node == "a")
                #expect(dependency == "missing")
            default:
                #expect(false, "Unexpected DAGValidationError: \(error)")
            }
        } catch {
            #expect(false, "Unexpected error: \(error)")
        }
    }

    @Test("Cycles are surfaced as validation errors")
    func cycleThrows() async {
        let dag = DAG {
            DAGNode("a", step: ConstantStep(output: "A"))
                .dependsOn("b")
            DAGNode("b", step: ConstantStep(output: "B"))
                .dependsOn("a")
        }

        do {
            _ = try await dag.execute("input", hooks: nil)
            #expect(false, "Expected cycle to throw")
        } catch let error as DAGValidationError {
            switch error {
            case let .cycleDetected(nodes):
                #expect(nodes.contains("a"))
                #expect(nodes.contains("b"))
            default:
                #expect(false, "Unexpected DAGValidationError: \(error)")
            }
        } catch {
            #expect(false, "Unexpected error: \(error)")
        }
    }

    @Test("Outputs are derived from sink nodes in topological order")
    func sinkOutputConcatenation() async throws {
        let dag = DAG {
            DAGNode("a", step: ConstantStep(output: "A"))
            DAGNode("b", step: ConstantStep(output: "B"))
                .dependsOn("a")
            DAGNode("c", step: ConstantStep(output: "C"))
                .dependsOn("a")
        }

        let result = try await dag.execute("input", hooks: nil)
        #expect(result.output == "B\nC")
    }
}
