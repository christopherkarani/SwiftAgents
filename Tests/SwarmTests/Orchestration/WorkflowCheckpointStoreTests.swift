import Foundation
@testable import Swarm
import Testing

@Suite("Workflow Checkpoint Store Tests")
struct WorkflowCheckpointStoreTests {
    @Test("FileSystem store sanitizes workflow IDs and keeps writes inside directory")
    func filesystemStoreSanitizesWorkflowIDs() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swarm-checkpoint-tests-\(UUID().uuidString)", isDirectory: true)
        let storeDirectory = root.appendingPathComponent("store", isDirectory: true)
        let siblingDirectory = root.appendingPathComponent("outside", isDirectory: true)

        try FileManager.default.createDirectory(at: siblingDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let store = FileSystemWorkflowCheckpointStore(directory: storeDirectory)
        let state = WorkflowCheckpointState(
            workflowID: "../outside/escape:attempt",
            stepIndex: 1,
            intermediateOutput: "ok"
        )

        try await store.save(state)

        let storeFiles = try FileManager.default.contentsOfDirectory(atPath: storeDirectory.path)
        let siblingFiles = try FileManager.default.contentsOfDirectory(atPath: siblingDirectory.path)

        #expect(storeFiles.count == 1)
        #expect(siblingFiles.isEmpty)
        #expect(storeFiles[0].contains("..") == false)
        #expect(storeFiles[0].contains("/") == false)
        #expect(storeFiles[0].contains(":") == false)

        let loaded = try await store.load(workflowID: "../outside/escape:attempt")
        #expect(loaded?.workflowID == "../outside/escape:attempt")
    }
}
