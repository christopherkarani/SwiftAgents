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

        await #expect(throws: OrchestrationError.self) {
            _ = try await dag.execute("input", hooks: nil)
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
        } catch let error as OrchestrationError {
            guard case let .invalidGraph(validationError) = error else {
                Issue.record("Expected invalidGraph, got \(error)")
                return
            }
            guard case let .unknownDependency(node, dependency, _) = validationError else {
                Issue.record("Expected unknownDependency, got \(validationError)")
                return
            }
            #expect(node == "a")
            #expect(dependency == "missing")
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
        } catch let error as OrchestrationError {
            guard case let .invalidGraph(validationError) = error else {
                Issue.record("Expected invalidGraph, got \(error)")
                return
            }
            guard case let .cycleDetected(nodes) = validationError else {
                Issue.record("Expected cycleDetected, got \(validationError)")
                return
            }
            #expect(nodes.contains("a"))
            #expect(nodes.contains("b"))
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
        // b and c are peer sink nodes; assert on set membership to avoid order dependency.
        let outputs = Set(result.output.components(separatedBy: "\n"))
        #expect(outputs == Set(["B", "C"]))
    }
}
