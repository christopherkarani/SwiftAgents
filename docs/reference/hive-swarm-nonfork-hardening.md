# Hive-Swarm Non-Fork Hardening Contract

This document defines the runtime hardening surface for Hive-in-Swarm without native fork support.

## Event Schema Version

- `HiveAgentsEventSchemaVersion.metadataKey`: `hive.eventSchemaVersion`
- `HiveAgentsEventSchemaVersion.current`: `hsw.v1`
- `HiveAgentsRunController` decorates emitted run events with this metadata key when absent.

## Run Control APIs

### Validation

```swift
public func validateRunOptions(_ options: HiveRunOptions) throws
```

Throws typed Hive errors:

- `HiveRuntimeError.modelClientMissing`
- `HiveRuntimeError.toolRegistryMissing`
- `HiveRuntimeError.checkpointStoreMissing`
- `HiveRuntimeError.invalidRunOptions(...)`

### External Writes

```swift
public struct HiveAgentsExternalWriteRequest: Sendable {
    public var threadID: HiveThreadID
    public var writes: [AnyHiveWrite<HiveAgents.Schema>]
    public var options: HiveRunOptions
}

public func applyExternalWrites(
    _ request: HiveAgentsExternalWriteRequest
) async throws -> HiveRunHandle<HiveAgents.Schema>
```

Validation and failure semantics:

- Unknown channel: `HiveRuntimeError.unknownChannelID`
- Task-local scope write attempt: `HiveRuntimeError.taskLocalWriteNotAllowed`
- Value type mismatch: `HiveRuntimeError.channelTypeMismatch`
- `.single` update-policy violation: `HiveRuntimeError.updatePolicyViolation`
- Pending interrupt state: `HiveRuntimeError.interruptPending`

Commit semantics are all-or-nothing: no runtime state publish occurs when validation fails.

### Resume Contract Prevalidation

`resume(_:)` now performs typed prevalidation before dispatch:

- No checkpoint store: `HiveRuntimeError.checkpointStoreMissing`
- No checkpoint: `HiveRuntimeError.noCheckpointToResume`
- No pending interrupt: `HiveRuntimeError.noInterruptToResume`
- Interrupt ID mismatch: `HiveRuntimeError.resumeInterruptMismatch`
- Unsupported checkpoint format tag: `HiveRuntimeError.checkpointCorrupt`

## Checkpoint Capability Contract

```swift
public enum HiveCheckpointQueryCapability: Sendable, Equatable {
    case unavailable
    case latestOnly
    case queryable
}

public func checkpointQueryCapability(
    probeThreadID: HiveThreadID = HiveThreadID("__hive_checkpoint_capability_probe__")
) async -> HiveCheckpointQueryCapability

public func getCheckpointHistory(
    threadID: HiveThreadID,
    limit: Int? = nil
) async throws -> [HiveCheckpointSummary]

public func getCheckpoint(
    threadID: HiveThreadID,
    id: HiveCheckpointID
) async throws -> HiveCheckpoint<HiveAgents.Schema>?
```

Unsupported query operations remain explicitly typed:

- `HiveCheckpointQueryError.unsupported`

## Typed Runtime State Snapshot

```swift
public struct HiveRuntimeStateSnapshot<Schema: HiveSchema>: Sendable, Equatable {
    public let threadID: HiveThreadID
    public let runID: HiveRunID?
    public let stepIndex: Int?
    public let interruption: HiveRuntimeInterruptionSummary<Schema>?
    public let checkpointID: HiveCheckpointID?
    public let frontier: HiveRuntimeFrontierSummary
    public let channelState: HiveRuntimeChannelStateSummary?
    public let eventSchemaVersion: String
    public let source: HiveStateSnapshotSource
}

public extension HiveRuntime where Schema == HiveAgents.Schema {
    func getState(
        threadID: HiveThreadID
    ) async throws -> HiveRuntimeStateSnapshot<Schema>?
}

public func getState(
    threadID: HiveThreadID
) async throws -> HiveRuntimeStateSnapshot<HiveAgents.Schema>?
```

Missing thread behavior:

- Returns `nil` when no checkpoint, no in-memory store, and no tracked attempt state exists for `threadID`.

## Determinism + Replay Utilities

```swift
public enum HiveDeterminism {
    public static func projectTranscript(
        _ events: [HiveEvent],
        expectedSchemaVersion: String = HiveAgentsEventSchemaVersion.current
    ) throws -> HiveCanonicalTranscript

    public static func transcriptHash(
        _ events: [HiveEvent],
        expectedSchemaVersion: String = HiveAgentsEventSchemaVersion.current
    ) throws -> String

    public static func finalStateHash<Schema: HiveSchema>(
        _ snapshot: HiveRuntimeStateSnapshot<Schema>,
        includeRuntimeIdentity: Bool = false
    ) throws -> String

    public static func firstTranscriptDiff(
        expected: HiveCanonicalTranscript,
        actual: HiveCanonicalTranscript
    ) -> HiveDeterminismDiff?

    public static func firstStateDiff<Schema: HiveSchema>(
        expected: HiveRuntimeStateSnapshot<Schema>,
        actual: HiveRuntimeStateSnapshot<Schema>,
        includeRuntimeIdentity: Bool = false
    ) -> HiveDeterminismDiff?
}
```

Replay compatibility checks are typed:

```swift
public enum HiveTranscriptCompatibilityError: Error, Sendable, Equatable {
    case missingSchemaVersion(eventIndex: Int)
    case incompatibleSchemaVersion(expected: String, found: String, eventIndex: Int)
}
```

## Cancel + Checkpoint Race Classification

```swift
public enum HiveCancelCheckpointResolution: Sendable, Equatable {
    case notCancelled
    case cancelledWithoutCheckpoint(latestCheckpointID: HiveCheckpointID?)
    case cancelledAfterCheckpointSaved(checkpointID: HiveCheckpointID)
}

public static func classifyCancelCheckpointRace<Schema: HiveSchema>(
    events: [HiveEvent],
    outcome: HiveRunOutcome<Schema>
) -> HiveCancelCheckpointResolution
```

This provides deterministic post-run classification when cancellation overlaps checkpoint persistence.
