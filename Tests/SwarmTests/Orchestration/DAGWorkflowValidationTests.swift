// DAGWorkflowValidationTests.swift
// SwarmTests
//
// Validation tests for DAG and orchestration graph construction errors.

@testable import Swarm
import Testing

@Suite("DAG Workflow Validation Tests")
struct DAGWorkflowValidationTests {
    @Test("DAG throws for empty graph")
    func dagThrowsForEmptyGraph() {
        #expect(throws: OrchestrationError.self) {
            _ = try DAG {}
        }
    }

    @Test("DAG throws for missing dependency")
    func dagThrowsForMissingDependency() {
        #expect(throws: OrchestrationError.self) {
            _ = try DAG {
                DAGNode("summarize", step: Transform { $0 }).dependsOn("fetch")
            }
        }
    }

    @Test("DAG throws for cycle")
    func dagThrowsForCycle() {
        #expect(throws: OrchestrationError.self) {
            _ = try DAG {
                DAGNode("a", step: Transform { $0 }).dependsOn("b")
                DAGNode("b", step: Transform { $0 }).dependsOn("a")
            }
        }
    }
}
