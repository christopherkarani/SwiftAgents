// WorkflowCheckpoint.swift
// Swarm Framework
//
// Checkpoint and resume infrastructure for long-running orchestration workflows.

import Foundation

// MARK: - WorkflowCheckpointPolicy

/// Policy controlling when workflow state is checkpointed.
public enum WorkflowCheckpointPolicy: Sendable, Equatable {
    /// Checkpointing is disabled (default).
    case disabled

    /// Checkpoint after every step completes.
    case everyStep

    /// Checkpoint after every N steps.
    case everyNSteps(Int)

    /// Checkpoint only when an interruption is raised.
    case onInterrupt
}

// MARK: - WorkflowCheckpointState

/// Serializable snapshot of workflow execution state at a checkpoint.
public struct WorkflowCheckpointState: Sendable, Codable, Equatable {
    /// Unique identifier for the workflow run.
    public let workflowID: String

    /// Index of the last completed step.
    public let stepIndex: Int

    /// Output from the last completed step.
    public let intermediateOutput: String

    /// Accumulated metadata at checkpoint time.
    public let metadata: [String: SendableValue]

    /// When this checkpoint was created.
    public let timestamp: Date

    public init(
        workflowID: String,
        stepIndex: Int,
        intermediateOutput: String,
        metadata: [String: SendableValue] = [:],
        timestamp: Date = Date()
    ) {
        self.workflowID = workflowID
        self.stepIndex = stepIndex
        self.intermediateOutput = intermediateOutput
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

// MARK: - WorkflowInterruptReason

/// Reason a workflow was interrupted and paused.
public enum WorkflowInterruptReason: Sendable, Equatable {
    /// Human approval was requested at this step.
    case humanApprovalRequired(prompt: String)

    /// Workflow was interrupted by an external signal.
    case externalInterrupt

    /// Workflow timed out.
    case timeout
}

// MARK: - WorkflowResumeHandle

/// Handle returned when a workflow is interrupted, containing state needed for resumption.
public struct WorkflowResumeHandle: Sendable {
    /// Unique identifier for the interrupted workflow run.
    public let workflowID: String

    /// The checkpoint state at the point of interruption.
    public let checkpoint: WorkflowCheckpointState

    /// Why the workflow was interrupted.
    public let interruptReason: WorkflowInterruptReason

    /// Runtime thread identifier required for Hive resume.
    public let threadID: String

    /// Interrupt identifier required for Hive resume.
    public let interruptID: String

    /// Checkpoint identifier persisted by Hive at interruption time.
    public let checkpointID: String

    /// Suggested resume payload for callers that do not need custom decisions.
    public let suggestedResumePayload: String?

    /// Raw interrupt payload emitted by Hive.
    public let interruptPayload: String

    public init(
        workflowID: String,
        checkpoint: WorkflowCheckpointState,
        interruptReason: WorkflowInterruptReason,
        threadID: String,
        interruptID: String,
        checkpointID: String,
        suggestedResumePayload: String? = nil,
        interruptPayload: String = ""
    ) {
        self.workflowID = workflowID
        self.checkpoint = checkpoint
        self.interruptReason = interruptReason
        self.threadID = threadID
        self.interruptID = interruptID
        self.checkpointID = checkpointID
        self.suggestedResumePayload = suggestedResumePayload
        self.interruptPayload = interruptPayload
    }
}

/// Result of a workflow execution attempt.
public enum WorkflowExecutionOutcome: Sendable {
    /// Workflow finished normally with a final agent result.
    case completed(AgentResult)

    /// Workflow paused for an interruption and can be resumed with the handle.
    case interrupted(WorkflowResumeHandle)
}

public extension WorkflowInterruptReason {
    /// Human-readable message for diagnostics and error propagation.
    var message: String {
        switch self {
        case let .humanApprovalRequired(prompt):
            "Human approval required: \(prompt)"
        case .externalInterrupt:
            "Workflow interrupted by external signal."
        case .timeout:
            "Workflow timed out."
        }
    }
}

// MARK: - WorkflowCheckpointStore

/// Protocol for persisting workflow checkpoint state.
///
/// Implementations must be safe for concurrent access since workflows
/// may checkpoint from multiple task contexts.
public protocol WorkflowCheckpointStore: Sendable {
    /// Save a checkpoint for the given workflow.
    func save(_ state: WorkflowCheckpointState) async throws

    /// Load the latest checkpoint for a workflow.
    func load(workflowID: String) async throws -> WorkflowCheckpointState?

    /// Load the most recent checkpoint across all workflows.
    func latestCheckpoint() async throws -> WorkflowCheckpointState?

    /// Remove all checkpoints for a workflow.
    func clear(workflowID: String) async throws
}

// MARK: - InMemoryWorkflowCheckpointStore

/// In-memory checkpoint store for testing and short-lived workflows.
///
/// Checkpoints are lost when the process exits. Use `FileSystemWorkflowCheckpointStore`
/// for crash recovery across app launches.
public actor InMemoryWorkflowCheckpointStore: WorkflowCheckpointStore {
    private var checkpoints: [String: [WorkflowCheckpointState]] = [:]

    public init() {}

    public func save(_ state: WorkflowCheckpointState) async throws {
        checkpoints[state.workflowID, default: []].append(state)
    }

    public func load(workflowID: String) async throws -> WorkflowCheckpointState? {
        checkpoints[workflowID]?.last
    }

    public func latestCheckpoint() async throws -> WorkflowCheckpointState? {
        checkpoints.values
            .compactMap(\.last)
            .max(by: { $0.timestamp < $1.timestamp })
    }

    public func clear(workflowID: String) async throws {
        checkpoints.removeValue(forKey: workflowID)
    }

    /// Returns all checkpoints for a workflow, ordered by creation time.
    public func allCheckpoints(workflowID: String) -> [WorkflowCheckpointState] {
        checkpoints[workflowID] ?? []
    }
}

// MARK: - FileSystemWorkflowCheckpointStore

/// File-based checkpoint store for crash recovery across app launches.
///
/// Each checkpoint is written as a JSON file in the specified directory.
/// Files are named `{workflowID}_{stepIndex}_{timestamp}.json`.
public actor FileSystemWorkflowCheckpointStore: WorkflowCheckpointStore {
    private let directory: URL
    private let standardizedDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a file-system-backed checkpoint store.
    /// - Parameter directory: The directory to store checkpoint files in.
    ///   Created automatically if it doesn't exist.
    public init(directory: URL) {
        self.directory = directory
        standardizedDirectory = directory.standardizedFileURL
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func save(_ state: WorkflowCheckpointState) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let timestamp = Int(state.timestamp.timeIntervalSince1970)
        let safeWorkflowID = sanitizeWorkflowID(state.workflowID)
        let filename = "\(safeWorkflowID)_\(state.stepIndex)_\(timestamp).json"
        let fileURL = try secureFileURL(for: filename)

        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }

    public func load(workflowID: String) async throws -> WorkflowCheckpointState? {
        let files = try checkpointFiles(for: workflowID)
        guard let latestFile = files.last else { return nil }
        let data = try Data(contentsOf: latestFile)
        return try decoder.decode(WorkflowCheckpointState.self, from: data)
    }

    public func latestCheckpoint() async throws -> WorkflowCheckpointState? {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return nil
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let jsonFiles = contents
            .filter { $0.pathExtension == "json" }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate < rhsDate
            }

        guard let latestFile = jsonFiles.last else { return nil }
        let data = try Data(contentsOf: latestFile)
        return try decoder.decode(WorkflowCheckpointState.self, from: data)
    }

    public func clear(workflowID: String) async throws {
        let files = try checkpointFiles(for: workflowID)
        for file in files {
            try FileManager.default.removeItem(at: file)
        }
    }

    private func checkpointFiles(for workflowID: String) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }

        let safeWorkflowID = sanitizeWorkflowID(workflowID)

        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        return contents
            .filter { $0.lastPathComponent.hasPrefix("\(safeWorkflowID)_") && $0.pathExtension == "json" }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate < rhsDate
            }
    }

    private func secureFileURL(for filename: String) throws -> URL {
        let candidate = directory.appendingPathComponent(filename).standardizedFileURL
        let rootPath = standardizedDirectory.path
        let candidatePath = candidate.path
        guard candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/") else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        return candidate
    }

    private func sanitizeWorkflowID(_ workflowID: String) -> String {
        let sanitized = workflowID.unicodeScalars.map { scalar in
            switch scalar {
            case "a"..."z", "A"..."Z", "0"..."9", "-", "_", ".":
                Character(scalar)
            default:
                "_"
            }
        }
        let value = String(sanitized)
        return value.isEmpty ? "workflow" : value
    }
}
