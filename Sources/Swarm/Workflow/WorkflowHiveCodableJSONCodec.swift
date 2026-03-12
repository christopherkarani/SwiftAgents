import Foundation
import HiveCore

/// Deterministic JSON codec used by Workflow's Hive checkpointing engine.
///
/// This is kept internal to avoid exposing Hive codec plumbing on the main Swarm API.
struct WorkflowHiveCodableJSONCodec<Value: Codable & Sendable>: HiveCodec, Sendable {
    let id: String

    init(id: String? = nil) {
        self.id = id ?? "Swarm.WorkflowHiveCodableJSONCodec<\(String(describing: Value.self))>"
    }

    func encode(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    func decode(_ data: Data) throws -> Value {
        try JSONDecoder().decode(Value.self, from: data)
    }
}
