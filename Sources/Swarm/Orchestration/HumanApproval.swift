// HumanApproval.swift
// Swarm Framework
//
// Human-in-the-loop approval primitive for orchestration workflows.

import Foundation

// MARK: - HumanApprovalHandler

/// Protocol for providing human approval responses.
public protocol HumanApprovalHandler: Sendable {
    /// Request approval from a human operator.
    /// - Parameter request: The approval request with context.
    /// - Returns: The human's approval response.
    func requestApproval(_ request: ApprovalRequest) async throws -> ApprovalResponse
}

// MARK: - ApprovalRequest

/// Data sent when human approval is needed.
public struct ApprovalRequest: Sendable {
    /// The approval prompt shown to the human.
    public let prompt: String

    /// The current workflow output at this point.
    public let currentOutput: String

    /// Additional context metadata from the workflow.
    public let metadata: [String: SendableValue]

    public init(prompt: String, currentOutput: String, metadata: [String: SendableValue] = [:]) {
        self.prompt = prompt
        self.currentOutput = currentOutput
        self.metadata = metadata
    }
}

// MARK: - ApprovalResponse

/// Human's response to an approval request.
public enum ApprovalResponse: Codable, Sendable {
    /// Approved — workflow continues with current input.
    case approved

    /// Rejected — workflow throws OrchestrationError.humanApprovalRejected.
    case rejected(reason: String)

    /// Modified — workflow continues with the provided new input.
    case modified(newInput: String)
}

/// Typed interrupt payload for orchestration runs.
public enum OrchestrationInterrupt: Codable, Sendable {
    case humanApprovalRequired(prompt: String, currentOutput: String)
}

/// Typed resume payload for orchestration runs.
public enum OrchestrationResume: Codable, Sendable {
    case humanApproval(response: ApprovalResponse)
}

// MARK: - AutoApproveHandler

/// A handler that automatically approves all requests. Useful for testing.
public struct AutoApproveHandler: HumanApprovalHandler {
    public init() {}

    public func requestApproval(_ request: ApprovalRequest) async throws -> ApprovalResponse {
        .approved
    }
}

// MARK: - HumanApproval

/// A step that pauses workflow execution for human review and approval.
///
/// When a `handler` is provided, it's called to get the approval response.
/// Without a handler, the step auto-approves (for Hive runtime, it will
/// use Hive's interrupt mechanism in the future).
///
/// Example:
/// ```swift
/// Orchestration {
///     researchAgent
///     HumanApproval("Review findings before analysis?")
///     analysisAgent
/// }
/// ```
public struct HumanApproval: OrchestrationStep, Sendable {
    /// The prompt shown to the human operator.
    public let prompt: String

    /// Optional timeout for the approval response.
    public let timeout: Duration?

    /// The handler that provides approval responses.
    public let handler: (any HumanApprovalHandler)?

    public init(
        _ prompt: String,
        timeout: Duration? = nil,
        handler: (any HumanApprovalHandler)? = nil
    ) {
        self.prompt = prompt
        self.timeout = timeout
        self.handler = handler
    }

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        let startTime = ContinuousClock.now

        let request = ApprovalRequest(
            prompt: prompt,
            currentOutput: input,
            metadata: [:]
        )

        let response: ApprovalResponse

        if let handler = handler {
            // If timeout is set, race between handler and timeout
            if let timeout = timeout {
                response = try await withThrowingTaskGroup(of: ApprovalResponse.self) { group in
                    group.addTask {
                        try await handler.requestApproval(request)
                    }
                    group.addTask {
                        try await Task.sleep(for: timeout)
                        throw OrchestrationError.humanApprovalTimeout(prompt: prompt)
                    }
                    // Return first to complete
                    let result = try await group.next()!
                    group.cancelAll()
                    return result
                }
            } else {
                response = try await handler.requestApproval(request)
            }
        } else {
            // No handler — auto-approve (in future, Hive interrupt will be used)
            response = .approved
        }

        let duration = ContinuousClock.now - startTime
        let durationSeconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18

        var metadata: [String: SendableValue] = [
            "approval.prompt": .string(prompt),
            "approval.wait_duration": .double(durationSeconds),
        ]

        let output: String
        switch response {
        case .approved:
            metadata["approval.response"] = .string("approved")
            output = input

        case .rejected(let reason):
            metadata["approval.response"] = .string("rejected")
            metadata["approval.rejection_reason"] = .string(reason)
            throw OrchestrationError.humanApprovalRejected(prompt: prompt, reason: reason)

        case .modified(let newInput):
            metadata["approval.response"] = .string("modified")
            output = newInput
        }

        return AgentResult(
            output: output,
            toolCalls: [],
            toolResults: [],
            iterationCount: 0,
            duration: duration,
            tokenUsage: nil,
            metadata: metadata
        )
    }
}
