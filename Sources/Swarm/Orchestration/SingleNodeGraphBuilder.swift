// SingleNodeGraphBuilder.swift
// Swarm Framework
//
// Factory that compiles a closure into a single-node CompiledHiveGraph<AgentHiveSchema>.

import Dispatch
import Foundation
import HiveCore

// MARK: - SingleNodeGraphBuilder

/// Compiles a single async closure into a one-node `CompiledHiveGraph<AgentHiveSchema>`
/// and provides a convenience method that executes the graph and translates the Hive
/// outcome into an `AgentResult`.
///
/// This is the foundation that `HiveAdaptable` agents rely on to route their execution
/// through Hive without changing their internal logic — they simply wrap it in a node body
/// and let `SingleNodeGraphBuilder` handle graph compilation, environment setup, and
/// result extraction.
///
/// Example:
/// ```swift
/// let graph = try SingleNodeGraphBuilder.build { input in
///     let text = try input.store.get(AgentHiveSchema.outputKey)
///     let output = try await myAgent._executeDirect(input: text, session: input.context.session, hooks: input.context.hooks)
///     return HiveNodeOutput(writes: [
///         AnyHiveWrite(AgentHiveSchema.outputKey, output.output),
///         AnyHiveWrite(AgentHiveSchema.accumulatorKey, AgentResultAccumulator(from: output))
///     ])
/// }
/// let result = try await SingleNodeGraphBuilder.execute(graph: graph, input: "Hello", context: context)
/// ```
enum SingleNodeGraphBuilder {
    // MARK: - Graph Construction

    /// Compiles a closure into a `CompiledHiveGraph<AgentHiveSchema>` containing a single node.
    ///
    /// - Parameters:
    ///   - nodeID: The Hive node ID to use. Defaults to `"agent"`.
    ///   - body: The async closure that performs the actual agent work.
    /// - Returns: A compiled graph ready for execution.
    static func build(
        nodeID: HiveNodeID = HiveNodeID("agent"),
        body: @escaping @Sendable (HiveNodeInput<AgentHiveSchema>) async throws -> HiveNodeOutput<AgentHiveSchema>
    ) throws -> CompiledHiveGraph<AgentHiveSchema> {
        var builder = HiveGraphBuilder<AgentHiveSchema>(start: [nodeID])
        builder.addNode(nodeID, body)
        builder.setOutputProjection(
            .channels([AgentHiveSchema.outputKey.id, AgentHiveSchema.accumulatorKey.id])
        )
        return try builder.compile()
    }

    // MARK: - Execution

    /// Runs a compiled single-node agent graph and translates the outcome into an `AgentResult`.
    ///
    /// - Parameters:
    ///   - graph: The compiled Hive graph to run.
    ///   - input: The string input to the agent.
    ///   - context: Session and hooks context for the run.
    ///   - maxSteps: Maximum Hive steps for this run. Defaults to `1`.
    ///   - runOptionsOverride: Optional Hive run options overrides.
    ///   - checkpointPolicy: Checkpoint save policy (used only when `checkpointStore` is provided).
    ///   - checkpointStore: Optional checkpoint store to enable runtime checkpoint persistence.
    ///   - threadID: Optional thread identifier. Defaults to a new UUID thread.
    /// - Returns: An `AgentResult` populated from the Hive channel store.
    static func execute(
        graph: CompiledHiveGraph<AgentHiveSchema>,
        input: String,
        context: AgentHiveContext,
        maxSteps: Int = 1,
        runOptionsOverride: SwarmHiveRunOptionsOverride? = nil,
        checkpointPolicy: HiveCheckpointPolicy = .disabled,
        checkpointStore: AnyHiveCheckpointStore<AgentHiveSchema>? = nil,
        threadID: HiveThreadID? = nil
    ) async throws -> AgentResult {
        let startTime = ContinuousClock.now
        let resolvedThreadID = threadID ?? HiveThreadID(UUID().uuidString)

        let environment = HiveEnvironment<AgentHiveSchema>(
            context: context,
            clock: SwarmHiveClock(),
            logger: SwarmHiveLogger(),
            checkpointStore: checkpointStore
        )

        let runtime = try HiveRuntime(graph: graph, environment: environment)

        let defaultOptions = HiveRunOptions(
            maxSteps: max(1, maxSteps),
            checkpointPolicy: checkpointStore != nil ? checkpointPolicy : .disabled
        )
        let options = HiveRunOptions(
            maxSteps: runOptionsOverride?.maxSteps ?? defaultOptions.maxSteps,
            maxConcurrentTasks: runOptionsOverride?.maxConcurrentTasks ?? defaultOptions.maxConcurrentTasks,
            checkpointPolicy: defaultOptions.checkpointPolicy,
            debugPayloads: runOptionsOverride?.debugPayloads ?? defaultOptions.debugPayloads,
            deterministicTokenStreaming: runOptionsOverride?.deterministicTokenStreaming ?? defaultOptions.deterministicTokenStreaming,
            eventBufferCapacity: runOptionsOverride?.eventBufferCapacity ?? defaultOptions.eventBufferCapacity,
            outputProjectionOverride: defaultOptions.outputProjectionOverride
        )

        let handle = await runtime.run(threadID: resolvedThreadID, input: input, options: options)

        let outcome: HiveRunOutcome<AgentHiveSchema>
        do {
            outcome = try await withTaskCancellationHandler {
                try await handle.outcome.value
            } onCancel: {
                handle.outcome.cancel()
            }
        } catch is CancellationError {
            throw AgentError.cancelled
        }

        switch outcome {
        case .finished(let output, _):
            return try extractResult(output, startTime: startTime)
        case .cancelled:
            throw AgentError.cancelled
        case .outOfSteps(let maxSteps, _, _):
            throw AgentError.internalError(
                reason: "Hive agent single-node graph exceeded maxSteps=\(maxSteps)."
            )
        case .interrupted:
            throw AgentError.internalError(
                reason: "Hive agent single-node graph interrupted unexpectedly."
            )
        }
    }

    // MARK: - Result Extraction

    private static func extractResult(
        _ output: HiveRunOutput<AgentHiveSchema>,
        startTime: ContinuousClock.Instant
    ) throws -> AgentResult {
        let agentOutput: String
        let accumulator: AgentResultAccumulator

        switch output {
        case .fullStore(let store):
            agentOutput = try store.get(AgentHiveSchema.outputKey)
            accumulator = try store.get(AgentHiveSchema.accumulatorKey)
        case .channels(let channels):
            agentOutput = try requireProjectedValue(channelID: AgentHiveSchema.outputKey.id, in: channels)
            accumulator = try requireProjectedValue(channelID: AgentHiveSchema.accumulatorKey.id, in: channels)
        }

        let duration = ContinuousClock.now - startTime
        var metadata = accumulator.metadata
        metadata["agent.engine"] = .string("hive")

        return AgentResult(
            output: agentOutput,
            toolCalls: accumulator.toolCalls,
            toolResults: accumulator.toolResults,
            iterationCount: accumulator.iterationCount,
            duration: duration,
            tokenUsage: nil,
            metadata: metadata
        )
    }

    private static func requireProjectedValue<Value: Sendable>(
        channelID: HiveChannelID,
        in channels: [HiveProjectedChannelValue]
    ) throws -> Value {
        guard let value = channels.first(where: { $0.id == channelID })?.value else {
            throw AgentError.internalError(
                reason: "Hive agent output missing channel '\(channelID.rawValue)'."
            )
        }
        guard let typed = value as? Value else {
            throw AgentError.internalError(
                reason: "Hive agent output type mismatch for channel '\(channelID.rawValue)'."
            )
        }
        return typed
    }
}
