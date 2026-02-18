import Foundation
@testable import Swarm
import Testing

@Suite("Orchestration Interruption + Resume")
struct OrchestrationInterruptionResumeTests {
    @Test("runWithOutcome returns interruption handle for human approval")
    func runWithOutcomeReturnsInterruptionHandle() async throws {
        let workflow = Orchestration(checkpointPolicy: .onInterrupt) {
            Transform { "prep:\($0)" }
            HumanApproval("Approve this workflow?")
            Transform { "\($0):done" }
        }

        let outcome = try await workflow.runWithOutcome("payload")
        guard case .interrupted(let handle) = outcome else {
            Issue.record("Expected interruption outcome")
            return
        }

        #expect(handle.threadID.isEmpty == false)
        #expect(handle.interruptID.isEmpty == false)
        #expect(handle.checkpointID.isEmpty == false)
        #expect(handle.checkpoint.workflowID == handle.workflowID)
        #expect(handle.checkpoint.intermediateOutput == "prep:payload")
        #expect(handle.interruptReason == .humanApprovalRequired(prompt: "Approve this workflow?"))
    }

    @Test("resume completes workflow after approval payload")
    func resumeCompletesWorkflowAfterApproval() async throws {
        let workflow = Orchestration(checkpointPolicy: .onInterrupt) {
            Transform { "prep:\($0)" }
            HumanApproval("Approve this workflow?")
            Transform { "\($0):done" }
        }

        let first = try await workflow.runWithOutcome("payload")
        guard case .interrupted(let handle) = first else {
            Issue.record("Expected interruption outcome")
            return
        }

        let resumed = try await workflow.resume(handle, payload: "approved")
        guard case .completed(let result) = resumed else {
            Issue.record("Expected completion outcome after resume")
            return
        }

        #expect(result.output == "prep:payload:done")
        #expect(result.metadata["orchestration.engine"]?.stringValue == "hive")
    }

    @Test("run throws workflowInterrupted for interruption workflows")
    func runThrowsWorkflowInterrupted() async throws {
        let workflow = Orchestration(checkpointPolicy: .onInterrupt) {
            HumanApproval("Gate")
            Transform { "\($0):done" }
        }

        do {
            _ = try await workflow.run("payload")
            Issue.record("Expected run() to throw workflowInterrupted")
        } catch let error as OrchestrationError {
            if case let .workflowInterrupted(reason) = error {
                #expect(reason.contains("Gate"))
            } else {
                Issue.record("Expected workflowInterrupted, got \(error)")
            }
        }
    }
}
