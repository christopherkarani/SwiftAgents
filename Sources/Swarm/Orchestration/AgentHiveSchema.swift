// AgentHiveSchema.swift
// Swarm Framework
//
// Reusable HiveSchema for single-node agent graphs.

import Foundation
import HiveCore

// MARK: - AgentHiveContext

/// The Hive execution context for a single-agent run.
///
/// Holds the session and run hooks from the Swarm call site, making them
/// accessible inside the Hive node body via `input.context`.
public struct AgentHiveContext: Sendable {
    /// The conversation session, if any.
    public let session: (any Session)?

    /// Run lifecycle hooks, if any.
    public let hooks: (any RunHooks)?

    public init(
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) {
        self.session = session
        self.hooks = hooks
    }
}

// MARK: - AgentResultAccumulator

/// Accumulated tool-call and iteration state from a single-agent Hive node run.
///
/// Mirrors the internal accumulator used by `OrchestrationHiveEngine` but is
/// promoted to a named public type so agent adapters can build and inspect it.
/// The `reduce(current:update:)` function is deterministic (lexicographic key
/// ordering) so it can be used as a Hive channel reducer.
public struct AgentResultAccumulator: Codable, Sendable, Equatable {
    /// Tool calls made during the agent's execution loop.
    public var toolCalls: [ToolCall]

    /// Results of each tool execution.
    public var toolResults: [ToolResult]

    /// Number of model-call iterations performed.
    public var iterationCount: Int

    /// Free-form key-value metadata from the agent.
    public var metadata: [String: SendableValue]

    public init(
        toolCalls: [ToolCall] = [],
        toolResults: [ToolResult] = [],
        iterationCount: Int = 0,
        metadata: [String: SendableValue] = [:]
    ) {
        self.toolCalls = toolCalls
        self.toolResults = toolResults
        self.iterationCount = iterationCount
        self.metadata = metadata
    }

    /// Convenience initialiser that converts a finished `AgentResult` into an accumulator.
    public init(from result: AgentResult) {
        self.toolCalls = result.toolCalls
        self.toolResults = result.toolResults
        self.iterationCount = result.iterationCount
        self.metadata = result.metadata
    }

    /// Merges two accumulators:
    /// - Appends tool calls and tool results.
    /// - Sums iteration counts.
    /// - Merges metadata, applying updates in lexicographic key order for determinism.
    public static func reduce(current: Self, update: Self) throws -> Self {
        var merged = current
        merged.toolCalls.append(contentsOf: update.toolCalls)
        merged.toolResults.append(contentsOf: update.toolResults)
        merged.iterationCount += update.iterationCount
        for key in update.metadata.keys.sorted() {
            merged.metadata[key] = update.metadata[key]
        }
        return merged
    }
}

// MARK: - AgentHiveSchema

/// Hive channel schema for single-agent runs.
///
/// Defines two channels:
/// - `outputKey`: the latest string output produced by the agent node.
/// - `accumulatorKey`: merged tool calls, results, and iteration count.
///
/// `InterruptPayload` and `ResumePayload` are `String` placeholders; Phase 6A
/// (tool approval resume) will upgrade these to typed payloads.
public enum AgentHiveSchema: HiveSchema {
    public typealias Context = AgentHiveContext
    public typealias Input = String
    public typealias InterruptPayload = String
    public typealias ResumePayload = String

    /// The latest string output from the agent execution node.
    public static let outputKey = HiveChannelKey<Self, String>(HiveChannelID("agent.output"))

    /// Accumulated tool calls, tool results, and iteration count.
    public static let accumulatorKey = HiveChannelKey<Self, AgentResultAccumulator>(
        HiveChannelID("agent.accumulator")
    )

    public static var channelSpecs: [AnyHiveChannelSpec<Self>] {
        [
            AnyHiveChannelSpec(
                HiveChannelSpec(
                    key: outputKey,
                    scope: .global,
                    reducer: .lastWriteWins(),
                    updatePolicy: .single,
                    initial: { "" },
                    codec: HiveAnyCodec(JSONCodec<String>()),
                    persistence: .checkpointed
                )
            ),
            AnyHiveChannelSpec(
                HiveChannelSpec(
                    key: accumulatorKey,
                    scope: .global,
                    reducer: HiveReducer(AgentResultAccumulator.reduce),
                    updatePolicy: .single,
                    initial: { AgentResultAccumulator() },
                    codec: HiveAnyCodec(JSONCodec<AgentResultAccumulator>()),
                    persistence: .checkpointed
                )
            ),
        ]
    }

    public static func inputWrites(
        _ input: String,
        inputContext _: HiveInputContext
    ) throws -> [AnyHiveWrite<Self>] {
        [
            AnyHiveWrite(outputKey, input),
            AnyHiveWrite(accumulatorKey, AgentResultAccumulator()),
        ]
    }
}
