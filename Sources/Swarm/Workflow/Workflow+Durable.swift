import Foundation
import HiveCore

public extension Workflow {
    /// Namespaced access to durable workflow APIs.
    var durable: Durable { Durable(workflow: self) }

    struct Durable: Sendable {
        fileprivate let workflow: Workflow

        enum CheckpointPolicy: Sendable {
            case onCompletion
            case everyStep
        }

        /// Enables workflow checkpointing for this workflow.
        func checkpoint(id: String, policy: CheckpointPolicy = .onCompletion) -> Workflow {
            var copy = workflow
            copy.advancedConfiguration.checkpoint = Workflow.CheckpointConfiguration(
                id: id,
                policy: policy
            )
            return copy
        }

        /// Configures checkpoint persistence for durable workflow execution.
        func checkpointing(_ checkpointing: WorkflowCheckpointing) -> Workflow {
            var copy = workflow
            copy.advancedConfiguration.checkpointing = checkpointing
            return copy
        }

        /// Adds a workflow-level fallback step.
        func fallback(
            primary: some AgentRuntime,
            to backup: some AgentRuntime,
            retries: Int = 0
        ) -> Workflow {
            var copy = workflow
            copy.steps.append(.fallback(primary: primary, backup: backup, retries: retries))
            return copy
        }

        /// Executes a durable workflow, optionally resuming from a checkpoint ID.
        func execute(_ input: String, resumeFrom checkpointID: String? = nil) async throws -> AgentResult {
            try await workflow.executeDurable(input, resumeFrom: checkpointID)
        }

        /// Backward-compatible alias for `execute(_:resumeFrom:)`.
        @available(*, deprecated, renamed: "execute(_:resumeFrom:)")
        func run(_ input: String, resumeFrom checkpointID: String? = nil) async throws -> AgentResult {
            try await execute(input, resumeFrom: checkpointID)
        }
    }
}

extension Workflow {
    func executeDurable(_ input: String, resumeFrom checkpointID: String?) async throws -> AgentResult {
        guard let checkpoint = advancedConfiguration.checkpoint else {
            if checkpointID != nil {
                throw WorkflowError.invalidWorkflow(
                    reason: "Cannot resume a workflow without durable checkpoint configuration"
                )
            }
            return try await executeWithTimeout {
                try await executeDirect(input: input)
            }
        }

        guard let checkpointing = advancedConfiguration.checkpointing else {
            throw WorkflowError.checkpointStoreRequired
        }

        let resolvedCheckpointID = checkpointID ?? checkpoint.id
        let threadID = HiveThreadID(resolvedCheckpointID)

        if checkpointID != nil {
            let latest = try await checkpointing.store.loadLatest(threadID: threadID)
            guard latest != nil else {
                throw WorkflowError.checkpointNotFound(id: resolvedCheckpointID)
            }
        }

        let engine = WorkflowHiveEngine(
            workflow: self,
            checkpointing: checkpointing,
            checkpointID: resolvedCheckpointID,
            policy: checkpoint.policy,
            resume: checkpointID != nil
        )

        return try await executeWithTimeout {
            try await engine.run(startInput: input)
        }
    }
}
