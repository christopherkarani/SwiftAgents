// HiveSubAgentGroup.swift
// Swarm Framework
//
// Parallel sub-agent executor using Hive's join-edge barrier pattern.

import Foundation
import HiveCore

// MARK: - HiveSubAgentGroup

/// A parallel sub-agent executor that compiles a fan-out/join graph using Hive's DAG runtime.
///
/// `HiveSubAgentGroup` runs multiple agents concurrently as separate Hive start nodes,
/// then uses a `addJoinEdge` barrier to gate a single merge node that combines results
/// via a `ResultMergeStrategy`.
///
/// Unlike `ParallelGroup` (which uses Swift structured concurrency directly),
/// `HiveSubAgentGroup` routes execution through the Hive runtime, gaining
/// checkpointing, deterministic replay, and structured event tracing.
///
/// Example:
/// ```swift
/// let group = HiveSubAgentGroup(
///     agents: [
///         ("summarizer", summarizerAgent),
///         ("translator", translatorAgent),
///     ],
///     mergeStrategy: MergeStrategies.Concatenate(shouldIncludeAgentNames: true)
/// )
///
/// let result = try await group.execute("Analyze this text", context: stepContext)
/// ```
public struct HiveSubAgentGroup: OrchestrationStep, Sendable {
    /// The sub-agents to execute in parallel, each with a unique name.
    public let agents: [(name: String, agent: any AgentRuntime)]

    /// Strategy for merging results from all sub-agents into a single result.
    public let mergeStrategy: any ResultMergeStrategy

    /// Strategy for handling errors during parallel execution.
    public let errorHandling: ParallelErrorHandling

    /// Creates a new Hive-backed parallel sub-agent group.
    ///
    /// - Parameters:
    ///   - agents: Array of (name, agent) tuples. Names must be unique.
    ///   - mergeStrategy: Strategy for merging results. Default: `Concatenate()`
    ///   - errorHandling: Strategy for handling errors. Default: `.continueOnPartialFailure`
    public init(
        agents: [(name: String, agent: any AgentRuntime)],
        mergeStrategy: any ResultMergeStrategy = MergeStrategies.Concatenate(),
        errorHandling: ParallelErrorHandling = .continueOnPartialFailure
    ) {
        self.agents = agents
        self.mergeStrategy = mergeStrategy
        self.errorHandling = errorHandling
    }

    // MARK: - OrchestrationStep Conformance

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        guard !agents.isEmpty else {
            return AgentResult(output: input)
        }

        let startTime = ContinuousClock.now

        let graph = try buildGraph()

        let hiveContext = AgentHiveContext(
            session: context.session,
            hooks: context.hooks
        )

        let environment = HiveEnvironment<AgentHiveSchema>(
            context: hiveContext,
            clock: SwarmHiveClock(),
            logger: SwarmHiveLogger()
        )

        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let threadID = HiveThreadID(UUID().uuidString)

        // Allow all sub-agent nodes + merge node to execute, with concurrency = agent count.
        let totalNodes = agents.count + 1
        let options = HiveRunOptions(
            maxSteps: totalNodes,
            maxConcurrentTasks: agents.count,
            checkpointPolicy: .disabled,
            eventBufferCapacity: max(64, totalNodes * 8)
        )

        let handle = await runtime.run(threadID: threadID, input: input, options: options)

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
            return try extractMergedResult(output, startTime: startTime)
        case .cancelled:
            throw AgentError.cancelled
        case .outOfSteps(let maxSteps, _, _):
            throw AgentError.internalError(
                reason: "HiveSubAgentGroup exceeded maxSteps=\(maxSteps)."
            )
        case .interrupted:
            throw AgentError.internalError(
                reason: "HiveSubAgentGroup interrupted unexpectedly."
            )
        }
    }

    // MARK: - Graph Construction

    /// Builds a Hive graph with fan-out start nodes and a join-edge merge node.
    ///
    /// Topology:
    /// ```
    /// [agent_0] ─┐
    /// [agent_1] ─┼─ joinEdge ─→ [merge]
    /// [agent_N] ─┘
    /// ```
    private func buildGraph() throws -> CompiledHiveGraph<AgentHiveSchema> {
        let agentNodeIDs = agents.map { HiveNodeID("subagent.\($0.name)") }
        let mergeNodeID = HiveNodeID("subagent.merge")

        var builder = HiveGraphBuilder<AgentHiveSchema>(start: agentNodeIDs)

        // Add a node for each sub-agent.
        for (index, (name, agent)) in agents.enumerated() {
            let nodeID = agentNodeIDs[index]
            let errorMode = errorHandling
            builder.addNode(nodeID) { nodeInput in
                let currentInput = try nodeInput.store.get(AgentHiveSchema.outputKey)
                let hiveCtx = nodeInput.context

                do {
                    let result = try await agent.run(
                        currentInput,
                        session: hiveCtx.session,
                        hooks: hiveCtx.hooks
                    )

                    // Store this agent's result as metadata keyed by name.
                    var accumulator = AgentResultAccumulator(from: result)
                    accumulator.metadata["result.\(name)"] = .string(result.output)

                    return HiveNodeOutput(writes: [
                        AnyHiveWrite(AgentHiveSchema.outputKey, result.output),
                        AnyHiveWrite(AgentHiveSchema.accumulatorKey, accumulator),
                    ])
                } catch {
                    switch errorMode {
                    case .failFast:
                        throw error
                    case .continueOnPartialFailure, .collectErrors:
                        // Store error in metadata so the merge node can detect it.
                        let errorAccumulator = AgentResultAccumulator(
                            metadata: [
                                "error.\(name)": .string(error.localizedDescription)
                            ]
                        )
                        return HiveNodeOutput(writes: [
                            AnyHiveWrite(AgentHiveSchema.accumulatorKey, errorAccumulator),
                        ])
                    }
                }
            }
        }

        // Add the merge node.
        let mergeStrat = mergeStrategy
        let agentNames = agents.map(\.name)
        builder.addNode(mergeNodeID) { nodeInput in
            let accumulator = try nodeInput.store.get(AgentHiveSchema.accumulatorKey)

            // Reconstruct per-agent results from metadata keys.
            var resultsByName: [String: AgentResult] = [:]
            var errors: [String: String] = [:]

            for agentName in agentNames {
                if let outputValue = accumulator.metadata["result.\(agentName)"],
                   case .string(let output) = outputValue
                {
                    resultsByName[agentName] = AgentResult(output: output)
                } else if let errorValue = accumulator.metadata["error.\(agentName)"],
                          case .string(let errorMsg) = errorValue
                {
                    errors[agentName] = errorMsg
                }
            }

            // If all agents failed, throw.
            if resultsByName.isEmpty, !errors.isEmpty {
                let messages = errors.map { "\($0.key): \($0.value)" }
                throw OrchestrationError.allAgentsFailed(errors: messages)
            }

            let merged = try await mergeStrat.merge(resultsByName)

            var mergedAccumulator = AgentResultAccumulator(from: merged)
            mergedAccumulator.metadata["hive_sub_agent_group.agent_count"] = .int(agentNames.count)
            mergedAccumulator.metadata["hive_sub_agent_group.success_count"] = .int(resultsByName.count)
            mergedAccumulator.metadata["hive_sub_agent_group.error_count"] = .int(errors.count)
            if !errors.isEmpty {
                let errorMessages = errors.map { "\($0.key): \($0.value)" }
                mergedAccumulator.metadata["hive_sub_agent_group.errors"] = .array(
                    errorMessages.map { .string($0) }
                )
            }

            return HiveNodeOutput(writes: [
                AnyHiveWrite(AgentHiveSchema.outputKey, merged.output),
                AnyHiveWrite(AgentHiveSchema.accumulatorKey, mergedAccumulator),
            ])
        }

        // Wire fan-out → join barrier → merge node.
        builder.addJoinEdge(parents: agentNodeIDs, target: mergeNodeID)

        builder.setOutputProjection(
            .channels([AgentHiveSchema.outputKey.id, AgentHiveSchema.accumulatorKey.id])
        )

        return try builder.compile()
    }

    // MARK: - Result Extraction

    private func extractMergedResult(
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
            agentOutput = try requireProjectedValue(
                channelID: AgentHiveSchema.outputKey.id,
                in: channels
            )
            accumulator = try requireProjectedValue(
                channelID: AgentHiveSchema.accumulatorKey.id,
                in: channels
            )
        }

        let duration = ContinuousClock.now - startTime
        var metadata = accumulator.metadata
        metadata["hive_sub_agent_group.engine"] = .string("hive")

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

    private func requireProjectedValue<Value: Sendable>(
        channelID: HiveChannelID,
        in channels: [HiveProjectedChannelValue]
    ) throws -> Value {
        guard let value = channels.first(where: { $0.id == channelID })?.value else {
            throw AgentError.internalError(
                reason: "HiveSubAgentGroup output missing channel '\(channelID.rawValue)'."
            )
        }
        guard let typed = value as? Value else {
            throw AgentError.internalError(
                reason: "HiveSubAgentGroup output type mismatch for channel '\(channelID.rawValue)'."
            )
        }
        return typed
    }
}
