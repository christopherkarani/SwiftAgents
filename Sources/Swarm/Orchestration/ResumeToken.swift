// ResumeToken.swift
// Swarm Framework
//
// A non-copyable token that represents a suspended orchestration point.

import Foundation
import HiveCore

// MARK: - ResumeToken

/// A non-copyable token that represents a suspended orchestration point.
///
/// `ResumeToken` captures the state of an orchestration at the point of
/// interruption, allowing it to be resumed later. Because it conforms to
/// `~Copyable`, the compiler ensures the token can only be consumed once --
/// preventing double-resume bugs at compile time.
///
/// Example:
/// ```swift
/// // Create a token when suspending an orchestration
/// var token = ResumeToken(
///     suspensionPoint: "approval-gate",
///     capturedInput: currentInput,
///     capturedStep: nextStep,
///     capturedContext: context
/// )
///
/// // Later, resume the orchestration
/// let result = try await token.resume(with: "approved")
///
/// // Or cancel it
/// // token.cancel()
/// ```
public struct ResumeToken: ~Copyable, Sendable {
    private let orchestrationID: UUID
    private let suspensionPoint: String
    private let capturedInput: String
    private let capturedStep: OrchestrationStep
    private let capturedContext: OrchestrationStepContext
    private let hiveStringResumer: (@Sendable (String) async throws -> AgentResult)?
    private let hiveApprovalResumer: (@Sendable (ApprovalResponse) async throws -> AgentResult)?
    private let hiveStateProvider: (@Sendable () async throws -> AgentExecutionSnapshot?)?

    /// The Hive interrupt ID for resuming an interrupted Hive orchestration.
    public let hiveInterruptID: HiveInterruptID?

    /// The Hive thread ID of the interrupted run.
    public let hiveThreadID: HiveThreadID?

    /// Creates a new resume token for a suspended orchestration.
    ///
    /// - Parameters:
    ///   - orchestrationID: Unique identifier for this suspension. Default: new UUID.
    ///   - suspensionPoint: A description of where the orchestration was suspended.
    ///   - capturedInput: The input at the point of suspension.
    ///   - capturedStep: The step to execute on resumption.
    ///   - capturedContext: The orchestration context at the point of suspension.
    ///   - hiveInterruptID: Optional Hive interrupt ID for Hive-native resume.
    ///   - hiveThreadID: Optional Hive thread ID for Hive-native resume.
    public init(
        orchestrationID: UUID = UUID(),
        suspensionPoint: String,
        capturedInput: String,
        capturedStep: OrchestrationStep,
        capturedContext: OrchestrationStepContext,
        hiveInterruptID: HiveInterruptID? = nil,
        hiveThreadID: HiveThreadID? = nil
    ) {
        self.orchestrationID = orchestrationID
        self.suspensionPoint = suspensionPoint
        self.capturedInput = capturedInput
        self.capturedStep = capturedStep
        self.capturedContext = capturedContext
        self.hiveInterruptID = hiveInterruptID
        self.hiveThreadID = hiveThreadID
        hiveStringResumer = nil
        hiveApprovalResumer = nil
        hiveStateProvider = nil
    }

    init(
        orchestrationID: UUID = UUID(),
        suspensionPoint: String,
        capturedInput: String,
        capturedStep: OrchestrationStep,
        capturedContext: OrchestrationStepContext,
        hiveInterruptID: HiveInterruptID?,
        hiveThreadID: HiveThreadID?,
        hiveStringResumer: (@Sendable (String) async throws -> AgentResult)?,
        hiveApprovalResumer: (@Sendable (ApprovalResponse) async throws -> AgentResult)?,
        hiveStateProvider: (@Sendable () async throws -> AgentExecutionSnapshot?)?
    ) {
        self.orchestrationID = orchestrationID
        self.suspensionPoint = suspensionPoint
        self.capturedInput = capturedInput
        self.capturedStep = capturedStep
        self.capturedContext = capturedContext
        self.hiveInterruptID = hiveInterruptID
        self.hiveThreadID = hiveThreadID
        self.hiveStringResumer = hiveStringResumer
        self.hiveApprovalResumer = hiveApprovalResumer
        self.hiveStateProvider = hiveStateProvider
    }

    /// Resumes the suspended orchestration with new input.
    ///
    /// This is a consuming operation -- the token is invalidated after use.
    /// The compiler prevents calling this method more than once on the same token.
    ///
    /// - Parameter input: The new input to resume with.
    /// - Returns: The result of executing the captured step.
    /// - Throws: Any error from the captured step's execution.
    public consuming func resume(with input: String) async throws -> AgentResult {
        if let hiveStringResumer {
            return try await hiveStringResumer(input)
        }
        if let hiveApprovalResumer {
            let normalized = normalizedApproval(from: input)
            return try await hiveApprovalResumer(normalized)
        }
        let step = capturedStep
        let context = capturedContext
        return try await step.execute(input, context: context)
    }

    /// Resumes a Hive-backed interruption with a structured approval response.
    ///
    /// For non-Hive tokens, this maps the approval into string input and executes
    /// the captured step body to preserve legacy behavior.
    public consuming func resume(approval response: ApprovalResponse) async throws -> AgentResult {
        if let hiveApprovalResumer {
            return try await hiveApprovalResumer(response)
        }

        let mappedInput: String
        switch response {
        case .approved:
            mappedInput = capturedInput
        case .modified(let newInput):
            mappedInput = newInput
        case .rejected(let reason):
            throw OrchestrationError.humanApprovalRejected(prompt: suspensionPoint, reason: reason)
        }
        let step = capturedStep
        let context = capturedContext
        return try await step.execute(mappedInput, context: context)
    }

    /// Returns a live execution snapshot for Hive-backed tokens when available.
    ///
    /// For non-Hive tokens this returns `nil`.
    public func currentExecutionSnapshot() async throws -> AgentExecutionSnapshot? {
        try await hiveStateProvider?()
    }

    /// Cancels the suspended orchestration without resuming.
    ///
    /// This is a consuming operation -- the token is invalidated after use.
    /// No cleanup is needed since the token doesn't hold external resources.
    public consuming func cancel() {
        // Token is consumed -- no resources to clean up
    }

    /// The unique identifier of this orchestration suspension.
    public var id: UUID { orchestrationID }

    /// A description of where the orchestration was suspended.
    public var suspension: String { suspensionPoint }

    private func normalizedApproval(from input: String) -> ApprovalResponse {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        if lower == "approved" || lower == "approve" {
            return .approved
        }

        if lower == "rejected" || lower == "reject" {
            return .rejected(reason: "Rejected by operator.")
        }

        if lower.hasPrefix("rejected:"), let idx = trimmed.firstIndex(of: ":") {
            let reason = trimmed[trimmed.index(after: idx)...].trimmingCharacters(in: .whitespacesAndNewlines)
            return .rejected(reason: reason.isEmpty ? "Rejected by operator." : reason)
        }

        return .modified(newInput: input)
    }
}
