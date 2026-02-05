import Foundation
import HiveCore

/// Deterministic JSON codec for Hive checkpointing and task hashing.
///
/// - Important: Only use for types whose JSON encoding is deterministic under `JSONEncoder(outputFormatting: .sortedKeys)`.
public struct HiveCodableJSONCodec<Value: Codable & Sendable>: HiveCodec, Sendable {
    public let id: String

    public init(id: String? = nil) {
        self.id = id ?? "HiveSwarm.HiveCodableJSONCodec<\(String(reflecting: Value.self))>"
    }

    public func encode(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    public func decode(_ data: Data) throws -> Value {
        try JSONDecoder().decode(Value.self, from: data)
    }
}

