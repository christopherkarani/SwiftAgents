// HiveAdaptable.swift
// Swarm Framework
//
// Protocol providing a default Hive-backed run() for agent types.

import Foundation
import HiveCore

// MARK: - HiveAdaptable

/// A protocol that agent types conform to in order to route their `run()` call
/// through a single-node Hive graph, gaining checkpointing, structured event
/// tracing, and graph-level retry without changing their internal execution logic.
///
/// ## Conformance Pattern
///
/// 1. Rename the existing `run()` body to `_executeDirect(input:session:hooks:)`.
/// 2. Implement `hiveNodeBody(input:context:)` that delegates to `_executeDirect()`.
/// 3. Replace `run(...)` with a call to `hiveRun(_:session:hooks:)`.
///
/// ```swift
/// extension Agent: HiveAdaptable {
///     func hiveNodeBody(
///         input: String,
///         context: AgentHiveContext
///     ) async throws -> (output: String, accumulator: AgentResultAccumulator) {
///         let result = try await _executeDirect(
///             input: input,
///             session: context.session,
///             hooks: context.hooks
///         )
///         return (result.output, AgentResultAccumulator(from: result))
///     }
/// }
/// ```
public protocol HiveAdaptable: AgentRuntime {
    /// The agent's internal execution logic, wrapped for Hive node execution.
    ///
    /// - Parameters:
    ///   - input: The input string for this invocation.
    ///   - context: The `AgentHiveContext` carrying session and hooks.
    /// - Returns: A tuple of the final output string and accumulated execution state.
    func hiveNodeBody(
        input: String,
        context: AgentHiveContext
    ) async throws -> (output: String, accumulator: AgentResultAccumulator)
}

// MARK: - Default Implementation

public extension HiveAdaptable {
    /// Builds a single-node Hive graph wrapping `hiveNodeBody()` and executes it,
    /// returning a standard `AgentResult`.
    ///
    /// This replaces the agent's `run(_:session:hooks:)` call site. The internal
    /// logic is unchanged — Hive wraps it as an execution substrate.
    func hiveRun(
        _ input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?
    ) async throws -> AgentResult {
        let context = AgentHiveContext(session: session, hooks: hooks)
        let agentName = name
        let graph = try SingleNodeGraphBuilder.build(
            nodeID: HiveNodeID("agent.\(agentName)"),
            body: { [self] nodeInput in
                let currentInput = try nodeInput.store.get(AgentHiveSchema.outputKey)
                let (output, accumulator) = try await hiveNodeBody(
                    input: currentInput,
                    context: nodeInput.context
                )
                return HiveNodeOutput(writes: [
                    AnyHiveWrite(AgentHiveSchema.outputKey, output),
                    AnyHiveWrite(AgentHiveSchema.accumulatorKey, accumulator),
                ])
            }
        )
        return try await SingleNodeGraphBuilder.execute(
            graph: graph,
            input: input,
            context: context,
            maxSteps: max(1, configuration.maxIterations),
            runOptionsOverride: configuration.hiveRunOptionsOverride
        )
    }
}
