// OrchestrationHiveEngine.swift
// Swarm Framework
//
// Hive-backed orchestration executor.

import Dispatch
import Foundation
import HiveCore
import Logging

enum OrchestrationHiveEngine {
    struct GraphMetrics: Sendable, Equatable {
        let nodeCount: Int
        let maxParallelism: Int
        let recommendedMaxSteps: Int
    }

    struct CompiledGraph {
        let graph: CompiledHiveGraph<Schema>
        let metrics: GraphMetrics
    }

    struct ParallelBranchResult: Codable, Sendable, Equatable {
        let groupID: String
        let branchIndex: Int
        let branchName: String
        let output: String?
        let toolCalls: [ToolCall]
        let toolResults: [ToolResult]
        let iterationCount: Int
        let metadata: [String: SendableValue]
        let error: String?

        var isSuccess: Bool { error == nil }

        static func success(
            groupID: String,
            branchIndex: Int,
            branchName: String,
            result: AgentResult
        ) -> ParallelBranchResult {
            ParallelBranchResult(
                groupID: groupID,
                branchIndex: branchIndex,
                branchName: branchName,
                output: result.output,
                toolCalls: result.toolCalls,
                toolResults: result.toolResults,
                iterationCount: result.iterationCount,
                metadata: result.metadata,
                error: nil
            )
        }

        static func failure(
            groupID: String,
            branchIndex: Int,
            branchName: String,
            error: String
        ) -> ParallelBranchResult {
            ParallelBranchResult(
                groupID: groupID,
                branchIndex: branchIndex,
                branchName: branchName,
                output: nil,
                toolCalls: [],
                toolResults: [],
                iterationCount: 0,
                metadata: [:],
                error: error
            )
        }
    }

    struct ParallelBranchResultsAccumulator {
        static func reduce(
            current: [ParallelBranchResult],
            update: [ParallelBranchResult]
        ) throws -> [ParallelBranchResult] {
            current + update
        }
    }

    struct Accumulator: Codable, Sendable, Equatable {
        var toolCalls: [ToolCall]
        var toolResults: [ToolResult]
        var iterationCount: Int
        var metadata: [String: SendableValue]

        init(
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

        static func reduce(current: Accumulator, update: Accumulator) throws -> Accumulator {
            var merged = current
            merged.toolCalls.append(contentsOf: update.toolCalls)
            merged.toolResults.append(contentsOf: update.toolResults)
            merged.iterationCount += update.iterationCount

            let sortedKeys = update.metadata.keys.sorted { lhs, rhs in
                lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
            }
            for key in sortedKeys {
                if let value = update.metadata[key] {
                    merged.metadata[key] = value
                }
            }
            return merged
        }
    }

    enum Schema: HiveSchema {
        typealias Context = OrchestrationStepContext
        typealias Input = String
        typealias InterruptPayload = OrchestrationInterrupt
        typealias ResumePayload = OrchestrationResume

        static let currentInputKey = HiveChannelKey<Self, String>(HiveChannelID("currentInput"))
        static let accumulatorKey = HiveChannelKey<Self, Accumulator>(HiveChannelID("accumulator"))
        static let parallelBranchResultsKey = HiveChannelKey<Self, [ParallelBranchResult]>(
            HiveChannelID("parallelBranchResults")
        )

        static var channelSpecs: [AnyHiveChannelSpec<Self>] {
            [
                AnyHiveChannelSpec(
                    HiveChannelSpec(
                        key: currentInputKey,
                        scope: .global,
                        reducer: .lastWriteWins(),
                        updatePolicy: .multi,
                        initial: { "" },
                        codec: HiveAnyCodec(JSONCodec<String>()),
                        persistence: .checkpointed
                    )
                ),
                AnyHiveChannelSpec(
                    HiveChannelSpec(
                        key: accumulatorKey,
                        scope: .global,
                        reducer: HiveReducer(Accumulator.reduce),
                        updatePolicy: .multi,
                        initial: { Accumulator() },
                        codec: HiveAnyCodec(JSONCodec<Accumulator>()),
                        persistence: .checkpointed
                    )
                ),
                AnyHiveChannelSpec(
                    HiveChannelSpec(
                        key: parallelBranchResultsKey,
                        scope: .global,
                        reducer: HiveReducer(ParallelBranchResultsAccumulator.reduce),
                        updatePolicy: .multi,
                        initial: { [] },
                        codec: HiveAnyCodec(JSONCodec<[ParallelBranchResult]>()),
                        persistence: .checkpointed
                    )
                )
            ]
        }

        static func inputWrites(_ input: String, inputContext _: HiveInputContext) throws -> [AnyHiveWrite<Self>] {
            [
                AnyHiveWrite(currentInputKey, input),
                AnyHiveWrite(accumulatorKey, Accumulator()),
                AnyHiveWrite(parallelBranchResultsKey, [])
            ]
        }
    }

    static func execute(
        steps: [OrchestrationStep],
        input: String,
        threadID: HiveThreadID,
        session: (any Session)?,
        hooks: (any RunHooks)?,
        orchestrator: (any AgentRuntime)?,
        orchestratorName: String,
        handoffs: [AnyHandoffConfiguration],
        inferencePolicy: InferencePolicy?,
        hiveRunOptionsOverride: SwarmHiveRunOptionsOverride?,
        checkpointPolicy: HiveCheckpointPolicy = .disabled,
        checkpointStore: AnyHiveCheckpointStore<Schema>? = nil,
        modelClient: AnyHiveModelClient? = nil,
        modelRouter: (any HiveModelRouter)? = nil,
        toolRegistry: AnyHiveToolRegistry? = nil,
        inferenceHints: HiveInferenceHints? = nil,
        onIterationStart: (@Sendable (Int) -> Void)?,
        onIterationEnd: (@Sendable (Int) -> Void)?,
        onHiveEvent: (@Sendable (HiveEvent) -> Void)?
    ) async throws -> AgentResult {
        let startTime = ContinuousClock.now

        let context = AgentContext(input: input)
        let stepContext = OrchestrationStepContext(
            agentContext: context,
            session: session,
            hooks: hooks,
            orchestrator: orchestrator,
            orchestratorName: orchestratorName,
            handoffs: handoffs,
            channels: ChannelBagStorage()
        )
        await context.recordExecution(agentName: orchestratorName)

        let compiledGraph = try makeGraph(steps: steps, stepContext: stepContext)
        let environment = HiveEnvironment<Schema>(
            context: stepContext,
            clock: SwarmHiveClock(),
            logger: SwarmHiveLogger(),
            model: modelClient,
            modelRouter: modelRouter,
            inferenceHints: inferenceHints ?? makeInferenceHints(from: inferencePolicy),
            tools: toolRegistry,
            checkpointStore: checkpointStore
        )

        let runtime = try HiveRuntime(graph: compiledGraph.graph, environment: environment)

        let options = makeRunOptions(
            graphMetrics: compiledGraph.metrics,
            checkpointPolicy: checkpointPolicy,
            override: hiveRunOptionsOverride
        )

        let handle = await runtime.run(threadID: threadID, input: input, options: options)
        let (outcome, eventError) = try await awaitOutcome(
            handle,
            onIterationStart: onIterationStart,
            onIterationEnd: onIterationEnd,
            onHiveEvent: onHiveEvent
        )
        if let eventError {
            Log.orchestration.error(
                "Hive orchestration event stream terminated with error.",
                metadata: ["error": .string(eventError)]
            )
        }

        switch outcome {
        case .finished(let output, _):
            let result = try extractResult(output)
            let currentInput = result.currentInput
            let accumulator = result.accumulator

            let duration = ContinuousClock.now - startTime
            var metadata = accumulator.metadata
            metadata["orchestration.engine"] = .string("hive")
            metadata["orchestration.total_steps"] = .int(steps.count)
            metadata["orchestration.graph.node_count"] = .int(compiledGraph.metrics.nodeCount)
            metadata["orchestration.graph.max_parallelism"] = .int(compiledGraph.metrics.maxParallelism)
            metadata["orchestration.run.max_steps"] = .int(options.maxSteps)
            metadata["orchestration.run.max_concurrent_tasks"] = .int(options.maxConcurrentTasks)
            metadata["orchestration.run.thread_id"] = .string(threadID.rawValue)
            metadata["orchestration.total_duration"] = .double(
                Double(duration.components.seconds) +
                    Double(duration.components.attoseconds) / 1e18
            )

            return AgentResult(
                output: currentInput,
                toolCalls: accumulator.toolCalls,
                toolResults: accumulator.toolResults,
                iterationCount: accumulator.iterationCount,
                duration: duration,
                tokenUsage: nil,
                metadata: metadata
            )

        case .cancelled:
            throw AgentError.cancelled

        case .outOfSteps(let maxSteps, _, _):
            throw AgentError.internalError(reason: "Hive orchestration exceeded maxSteps=\(maxSteps).")

        case .interrupted(let interruption):
            throw OrchestrationError.workflowInterrupted(reason: interruptionReason(interruption))
        }
    }

    static func executeInterruptible(
        steps: [OrchestrationStep],
        input: String,
        threadID: HiveThreadID,
        session: (any Session)?,
        hooks: (any RunHooks)?,
        orchestrator: (any AgentRuntime)?,
        orchestratorName: String,
        handoffs: [AnyHandoffConfiguration],
        inferencePolicy: InferencePolicy?,
        hiveRunOptionsOverride: SwarmHiveRunOptionsOverride?,
        checkpointPolicy: HiveCheckpointPolicy = .disabled,
        checkpointStore: AnyHiveCheckpointStore<Schema>? = nil,
        modelClient: AnyHiveModelClient? = nil,
        modelRouter: (any HiveModelRouter)? = nil,
        toolRegistry: AnyHiveToolRegistry? = nil,
        inferenceHints: HiveInferenceHints? = nil,
        onIterationStart: (@Sendable (Int) -> Void)?,
        onIterationEnd: (@Sendable (Int) -> Void)?
    ) async throws -> OrchestrationRunOutcome {
        let startTime = ContinuousClock.now

        let context = AgentContext(input: input)
        let stepContext = OrchestrationStepContext(
            agentContext: context,
            session: session,
            hooks: hooks,
            orchestrator: orchestrator,
            orchestratorName: orchestratorName,
            handoffs: handoffs,
            channels: ChannelBagStorage()
        )
        await context.recordExecution(agentName: orchestratorName)

        let compiledGraph = try makeGraph(steps: steps, stepContext: stepContext)
        let environment = HiveEnvironment<Schema>(
            context: stepContext,
            clock: SwarmHiveClock(),
            logger: SwarmHiveLogger(),
            model: modelClient,
            modelRouter: modelRouter,
            inferenceHints: inferenceHints ?? makeInferenceHints(from: inferencePolicy),
            tools: toolRegistry,
            checkpointStore: checkpointStore
        )

        let runtime = try HiveRuntime(graph: compiledGraph.graph, environment: environment)
        let options = makeRunOptions(
            graphMetrics: compiledGraph.metrics,
            checkpointPolicy: checkpointPolicy,
            override: hiveRunOptionsOverride
        )

        let handle = await runtime.run(threadID: threadID, input: input, options: options)
        let (outcome, eventError) = try await awaitOutcome(
            handle,
            onIterationStart: onIterationStart,
            onIterationEnd: onIterationEnd,
            onHiveEvent: nil
        )
        if let eventError {
            Log.orchestration.error(
                "Hive orchestration event stream terminated with error.",
                metadata: ["error": .string(eventError)]
            )
        }

        switch outcome {
        case .interrupted(let interruption):
            let reason = interruptionReason(interruption)
            let resumeToken = ResumeToken(
                suspensionPoint: reason,
                capturedInput: input,
                capturedStep: OrchestrationGroup(steps: steps),
                capturedContext: stepContext,
                hiveInterruptID: interruption.interrupt.id,
                hiveThreadID: threadID,
                hiveStringResumer: { input in
                    let response = approvalResponse(from: input)
                    return try await resumeWithApproval(
                        runtime: runtime,
                        threadID: threadID,
                        interruptID: interruption.interrupt.id,
                        response: response,
                        options: options,
                        steps: steps,
                        graphMetrics: compiledGraph.metrics,
                        startTime: startTime
                    )
                },
                hiveApprovalResumer: { response in
                    try await resumeWithApproval(
                        runtime: runtime,
                        threadID: threadID,
                        interruptID: interruption.interrupt.id,
                        response: response,
                        options: options,
                        steps: steps,
                        graphMetrics: compiledGraph.metrics,
                        startTime: startTime
                    )
                },
                hiveStateProvider: {
                    guard let snapshot = try await runtime.getState(threadID: threadID) else { return nil }
                    return AgentExecutionSnapshot(
                        activeNodes: snapshot.nextNodes.map(\.rawValue),
                        stepIndex: snapshot.stepIndex,
                        isInterrupted: true
                    )
                }
            )
            return .interrupted(resumeToken)

        case .finished, .cancelled, .outOfSteps:
            let result = try terminalResult(
                outcome: outcome,
                steps: steps,
                graphMetrics: compiledGraph.metrics,
                runOptions: options,
                threadID: threadID,
                startTime: startTime
            )
            return .completed(result)
        }
    }

    private static func resumeWithApproval(
        runtime: HiveRuntime<Schema>,
        threadID: HiveThreadID,
        interruptID: HiveInterruptID,
        response: ApprovalResponse,
        options: HiveRunOptions,
        steps: [OrchestrationStep],
        graphMetrics: GraphMetrics,
        startTime: ContinuousClock.Instant
    ) async throws -> AgentResult {
        let handle = await runtime.resume(
            threadID: threadID,
            interruptID: interruptID,
            payload: .humanApproval(response: response),
            options: options
        )
        let (outcome, eventError) = try await awaitOutcome(
            handle,
            onIterationStart: nil,
            onIterationEnd: nil,
            onHiveEvent: nil
        )
        if let eventError {
            Log.orchestration.error(
                "Hive orchestration resume stream terminated with error.",
                metadata: ["error": .string(eventError)]
            )
        }
        switch outcome {
        case .interrupted(let interruption):
            throw OrchestrationError.workflowInterrupted(reason: interruptionReason(interruption))
        case .finished, .cancelled, .outOfSteps:
            return try terminalResult(
                outcome: outcome,
                steps: steps,
                graphMetrics: graphMetrics,
                runOptions: options,
                threadID: threadID,
                startTime: startTime
            )
        }
    }

    private static func terminalResult(
        outcome: HiveRunOutcome<Schema>,
        steps: [OrchestrationStep],
        graphMetrics: GraphMetrics,
        runOptions: HiveRunOptions,
        threadID: HiveThreadID,
        startTime: ContinuousClock.Instant
    ) throws -> AgentResult {
        switch outcome {
        case .finished(let output, _):
            let result = try extractResult(output)
            let currentInput = result.currentInput
            let accumulator = result.accumulator

            let duration = ContinuousClock.now - startTime
            var metadata = accumulator.metadata
            metadata["orchestration.engine"] = .string("hive")
            metadata["orchestration.total_steps"] = .int(steps.count)
            metadata["orchestration.graph.node_count"] = .int(graphMetrics.nodeCount)
            metadata["orchestration.graph.max_parallelism"] = .int(graphMetrics.maxParallelism)
            metadata["orchestration.run.max_steps"] = .int(runOptions.maxSteps)
            metadata["orchestration.run.max_concurrent_tasks"] = .int(runOptions.maxConcurrentTasks)
            metadata["orchestration.run.thread_id"] = .string(threadID.rawValue)
            metadata["orchestration.total_duration"] = .double(
                Double(duration.components.seconds) +
                    Double(duration.components.attoseconds) / 1e18
            )

            return AgentResult(
                output: currentInput,
                toolCalls: accumulator.toolCalls,
                toolResults: accumulator.toolResults,
                iterationCount: accumulator.iterationCount,
                duration: duration,
                tokenUsage: nil,
                metadata: metadata
            )

        case .cancelled:
            throw AgentError.cancelled

        case .outOfSteps(let maxSteps, _, _):
            throw AgentError.internalError(reason: "Hive orchestration exceeded maxSteps=\(maxSteps).")

        case .interrupted(let interruption):
            throw OrchestrationError.workflowInterrupted(reason: interruptionReason(interruption))
        }
    }

    private static func awaitOutcome(
        _ handle: HiveRunHandle<Schema>,
        onIterationStart: (@Sendable (Int) -> Void)?,
        onIterationEnd: (@Sendable (Int) -> Void)?,
        onHiveEvent: (@Sendable (HiveEvent) -> Void)?
    ) async throws -> (HiveRunOutcome<Schema>, String?) {
        let eventsTask = Task<String?, Never> {
            do {
                for try await event in handle.events {
                    onHiveEvent?(event)
                    switch event.kind {
                    case .stepStarted(let stepIndex, _):
                        onIterationStart?(stepIndex + 1)
                    case .stepFinished(let stepIndex, _):
                        onIterationEnd?(stepIndex + 1)
                    default:
                        break
                    }
                }
                return nil
            } catch {
                return error.localizedDescription
            }
        }

        let outcome: HiveRunOutcome<Schema>
        do {
            outcome = try await withTaskCancellationHandler {
                try await handle.outcome.value
            } onCancel: {
                handle.outcome.cancel()
                eventsTask.cancel()
            }
        } catch is CancellationError {
            eventsTask.cancel()
            _ = await eventsTask.value
            throw AgentError.cancelled
        }

        let eventError = await eventsTask.value
        return (outcome, eventError)
    }

    private static func interruptionReason(_ interruption: HiveInterruption<Schema>) -> String {
        switch interruption.interrupt.payload {
        case .humanApprovalRequired(let prompt, _):
            return "human_approval_required:\(prompt)"
        }
    }

    private static func approvalResponse(from input: String) -> ApprovalResponse {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        if lower == "approved" || lower == "approve" {
            return .approved
        }
        if lower == "rejected" || lower == "reject" {
            return .rejected(reason: "Rejected by operator.")
        }
        if lower.hasPrefix("rejected:"), let index = trimmed.firstIndex(of: ":") {
            let reason = trimmed[trimmed.index(after: index)...].trimmingCharacters(in: .whitespacesAndNewlines)
            return .rejected(reason: reason.isEmpty ? "Rejected by operator." : reason)
        }
        return .modified(newInput: input)
    }

    private static func makeRunOptions(
        graphMetrics: GraphMetrics,
        checkpointPolicy: HiveCheckpointPolicy,
        override optionsOverride: SwarmHiveRunOptionsOverride?
    ) -> HiveRunOptions {
        let defaultOptions = HiveRunOptions(
            maxSteps: max(1, graphMetrics.recommendedMaxSteps),
            maxConcurrentTasks: max(1, graphMetrics.maxParallelism),
            checkpointPolicy: checkpointPolicy,
            debugPayloads: false,
            deterministicTokenStreaming: false,
            eventBufferCapacity: max(64, graphMetrics.nodeCount * 8)
        )

        guard let optionsOverride else {
            return defaultOptions
        }

        return HiveRunOptions(
            maxSteps: optionsOverride.maxSteps ?? defaultOptions.maxSteps,
            maxConcurrentTasks: optionsOverride.maxConcurrentTasks ?? defaultOptions.maxConcurrentTasks,
            checkpointPolicy: checkpointPolicy,
            debugPayloads: optionsOverride.debugPayloads ?? defaultOptions.debugPayloads,
            deterministicTokenStreaming: optionsOverride.deterministicTokenStreaming ?? defaultOptions.deterministicTokenStreaming,
            eventBufferCapacity: optionsOverride.eventBufferCapacity ?? defaultOptions.eventBufferCapacity,
            outputProjectionOverride: defaultOptions.outputProjectionOverride
        )
    }

    static func makeInferenceHints(from policy: InferencePolicy?) -> HiveInferenceHints? {
        guard let policy else { return nil }

        let latencyTier: HiveLatencyTier = switch policy.latencyTier {
        case .interactive:
            .interactive
        case .background:
            .background
        }

        let networkState: HiveNetworkState = switch policy.networkState {
        case .offline:
            .offline
        case .online:
            .online
        case .metered:
            .metered
        }

        return HiveInferenceHints(
            latencyTier: latencyTier,
            privacyRequired: policy.privacyRequired,
            tokenBudget: policy.tokenBudget,
            networkState: networkState
        )
    }

    private static func makeGraph(
        steps: [OrchestrationStep],
        stepContext: OrchestrationStepContext
    ) throws -> CompiledGraph {
        precondition(!steps.isEmpty)

        let startNodeIDs = try entryNodeIDs(for: steps[0], nodePrefix: "step_0")

        var builder = HiveGraphBuilder<Schema>(start: startNodeIDs)
        var previousExitNodes: [HiveNodeID] = []
        var totalNodeCount = 0
        var maxParallelism = 1
        var maxStepBudget = 0

        for (index, step) in steps.enumerated() {
            let fragment = try compileTopLevelStep(
                step,
                into: &builder,
                stepContext: stepContext,
                nodePrefix: "step_\(index)",
                orchestrationStepPrefix: "orchestration.step_\(index)"
            )

            if index > 0 {
                for exitNode in previousExitNodes {
                    for entryNode in fragment.entryNodes {
                        builder.addEdge(from: exitNode, to: entryNode)
                    }
                }
            }

            previousExitNodes = fragment.exitNodes
            totalNodeCount += fragment.nodeCount
            maxParallelism = max(maxParallelism, fragment.maxParallelism)
            let budgetForStep = recommendedMaxSteps(for: step)
            if maxStepBudget > Int.max - budgetForStep {
                maxStepBudget = Int.max
            } else {
                maxStepBudget += budgetForStep
            }
        }

        maxParallelism = max(maxParallelism, declaredMaxParallelism(in: steps))
        builder.setOutputProjection(.channels([Schema.currentInputKey.id, Schema.accumulatorKey.id]))
        return CompiledGraph(
            graph: try builder.compile(),
            metrics: GraphMetrics(
                nodeCount: totalNodeCount,
                maxParallelism: maxParallelism,
                recommendedMaxSteps: maxStepBudget
            )
        )
    }

    private static func extractResult(
        _ output: HiveRunOutput<Schema>
    ) throws -> (currentInput: String, accumulator: Accumulator) {
        switch output {
        case .fullStore(let store):
            return (
                currentInput: try store.get(Schema.currentInputKey),
                accumulator: try store.get(Schema.accumulatorKey)
            )
        case .channels(let channels):
            let currentInput: String = try requireProjectedValue(
                channelID: Schema.currentInputKey.id,
                in: channels
            )
            let accumulator: Accumulator = try requireProjectedValue(
                channelID: Schema.accumulatorKey.id,
                in: channels
            )
            return (currentInput: currentInput, accumulator: accumulator)
        }
    }

    private static func requireProjectedValue<Value: Sendable>(
        channelID: HiveChannelID,
        in channels: [HiveProjectedChannelValue]
    ) throws -> Value {
        guard let value = channels.first(where: { $0.id == channelID })?.value else {
            throw AgentError.internalError(reason: "Hive orchestration output missing channel '\(channelID.rawValue)'.")
        }
        guard let typed = value as? Value else {
            throw AgentError.internalError(reason: "Hive orchestration output type mismatch for channel '\(channelID.rawValue)'.")
        }
        return typed
    }
}

struct SwarmHiveClock: HiveClock {
    func nowNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    func sleep(nanoseconds: UInt64) async throws {
        try await Task.sleep(for: .nanoseconds(nanoseconds))
    }
}

struct SwarmHiveLogger: HiveLogger {
    private let logger: Logger

    init(logger: Logger = Log.orchestration) {
        self.logger = logger
    }

    func debug(_ message: String, metadata: [String: String]) {
        logger.debug(Logger.Message(stringLiteral: message), metadata: swiftLogMetadata(metadata))
    }

    func info(_ message: String, metadata: [String: String]) {
        logger.info(Logger.Message(stringLiteral: message), metadata: swiftLogMetadata(metadata))
    }

    func error(_ message: String, metadata: [String: String]) {
        logger.error(Logger.Message(stringLiteral: message), metadata: swiftLogMetadata(metadata))
    }

    private func swiftLogMetadata(_ metadata: [String: String]) -> Logger.Metadata {
        var swiftMetadata: Logger.Metadata = [:]
        swiftMetadata.reserveCapacity(metadata.count)
        for (key, value) in metadata {
            swiftMetadata[key] = .string(value)
        }
        return swiftMetadata
    }
}

/// Deterministic JSON codec for Hive checkpointing within the Swarm target.
struct JSONCodec<Value: Codable & Sendable>: HiveCodec {
    let id: String

    init() {
        self.id = "Swarm.JSONCodec<\(String(reflecting: Value.self))>"
    }

    func encode(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    func decode(_ data: Data) throws -> Value {
        try JSONDecoder().decode(Value.self, from: data)
    }
}
