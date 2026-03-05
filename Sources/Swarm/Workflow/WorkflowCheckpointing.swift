import Foundation
import HiveCore

/// Checkpoint persistence configuration for advanced workflows.
public struct WorkflowCheckpointing: Sendable {
    let store: AnyHiveCheckpointStore<WorkflowHiveSchema>

    private init(store: AnyHiveCheckpointStore<WorkflowHiveSchema>) {
        self.store = store
    }

    /// In-memory checkpoint persistence.
    public static func inMemory() -> WorkflowCheckpointing {
        let store = WorkflowInMemoryCheckpointStore()
        return WorkflowCheckpointing(store: AnyHiveCheckpointStore(store))
    }

    /// File-system checkpoint persistence rooted at `directory`.
    public static func fileSystem(directory: URL) -> WorkflowCheckpointing {
        let store = WorkflowFileCheckpointStore(directory: directory)
        return WorkflowCheckpointing(store: AnyHiveCheckpointStore(store))
    }
}

actor WorkflowInMemoryCheckpointStore: HiveCheckpointStore {
    typealias Schema = WorkflowHiveSchema

    private var checkpoints: [HiveCheckpoint<WorkflowHiveSchema>] = []

    func save(_ checkpoint: HiveCheckpoint<WorkflowHiveSchema>) async throws {
        checkpoints.append(checkpoint)
    }

    func loadLatest(threadID: HiveThreadID) async throws -> HiveCheckpoint<WorkflowHiveSchema>? {
        checkpoints
            .filter { $0.threadID == threadID }
            .max { lhs, rhs in
                if lhs.stepIndex == rhs.stepIndex {
                    return lhs.id.rawValue < rhs.id.rawValue
                }
                return lhs.stepIndex < rhs.stepIndex
            }
    }
}

actor WorkflowFileCheckpointStore: HiveCheckpointStore {
    typealias Schema = WorkflowHiveSchema

    private let directory: URL
    private let fileManager = FileManager.default

    init(directory: URL) {
        self.directory = directory
    }

    func save(_ checkpoint: HiveCheckpoint<WorkflowHiveSchema>) async throws {
        try ensureDirectoryExists()
        let data = try JSONEncoder().encode(checkpoint)
        let url = checkpointFileURL(
            threadID: checkpoint.threadID,
            checkpointID: checkpoint.id
        )
        try data.write(to: url, options: .atomic)
    }

    func loadLatest(threadID: HiveThreadID) async throws -> HiveCheckpoint<WorkflowHiveSchema>? {
        try ensureDirectoryExists()

        let threadPrefix = filePrefix(for: threadID)
        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )

        let matching = files.filter { $0.lastPathComponent.hasPrefix(threadPrefix) }
        guard matching.isEmpty == false else { return nil }

        let decoder = JSONDecoder()
        var latest: HiveCheckpoint<WorkflowHiveSchema>?

        for fileURL in matching {
            let data = try Data(contentsOf: fileURL)
            let checkpoint = try decoder.decode(HiveCheckpoint<WorkflowHiveSchema>.self, from: data)
            guard checkpoint.threadID == threadID else { continue }

            if let existingLatest = latest {
                let isNewer = checkpoint.stepIndex > existingLatest.stepIndex ||
                    (checkpoint.stepIndex == existingLatest.stepIndex && checkpoint.id.rawValue > existingLatest.id.rawValue)
                if isNewer {
                    latest = checkpoint
                }
            } else {
                latest = checkpoint
            }
        }

        return latest
    }

    private func checkpointFileURL(threadID: HiveThreadID, checkpointID: HiveCheckpointID) -> URL {
        let name = "\(filePrefix(for: threadID))\(sanitize(checkpointID.rawValue)).json"
        return directory.appendingPathComponent(name, isDirectory: false)
    }

    private func filePrefix(for threadID: HiveThreadID) -> String {
        "workflow-\(sanitize(threadID.rawValue))-"
    }

    private func sanitize(_ raw: String) -> String {
        raw.replacingOccurrences(
            of: #"[^A-Za-z0-9._-]"#,
            with: "_",
            options: .regularExpression
        )
    }

    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}
