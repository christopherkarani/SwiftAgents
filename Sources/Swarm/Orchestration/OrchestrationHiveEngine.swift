// OrchestrationHiveEngine.swift
// Swarm Framework
//
// Hive-backed orchestration executor.

#if canImport(HiveCore)

import Dispatch
import Foundation
import HiveCore
import Logging

enum OrchestrationHiveEngine {
    struct ResumeRequest: Sendable {
        let workflowID: String
        let interruptID: String
        let payload: String
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
        typealias InterruptPayload = String
        typealias ResumePayload = String

        static let currentInputKey = HiveChannelKey<Self, String>(HiveChannelID("currentInput"))
        static let accumulatorKey = HiveChannelKey<Self, Accumulator>(HiveChannelID("accumulator"))

        static var channelSpecs: [AnyHiveChannelSpec<Self>] {
            [
                AnyHiveChannelSpec(
                    HiveChannelSpec(
                        key: currentInputKey,
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
                        reducer: HiveReducer(Accumulator.reduce),
                        updatePolicy: .single,
                        initial: { Accumulator() },
                        codec: HiveAnyCodec(JSONCodec<Accumulator>()),
                        persistence: .checkpointed
                    )
                )
            ]
        }

        static func inputWrites(_ input: String, inputContext _: HiveInputContext) throws -> [AnyHiveWrite<Self>] {
            [
                AnyHiveWrite(currentInputKey, input),
                AnyHiveWrite(accumulatorKey, Accumulator())
            ]
        }
    }

    static func execute(
        steps: [OrchestrationStep],
        input: String,
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
        workflowID: String = UUID().uuidString,
        resumeRequest: ResumeRequest? = nil,
        onIterationStart: (@Sendable (Int) -> Void)?,
        onIterationEnd: (@Sendable (Int) -> Void)?
    ) async throws -> WorkflowExecutionOutcome {
        let startTime = ContinuousClock.now

        let context = AgentContext(input: input)
        let stepContext = OrchestrationStepContext(
            agentContext: context,
            session: session,
            hooks: hooks,
            orchestrator: orchestrator,
            orchestratorName: orchestratorName,
            handoffs: handoffs
        )
        await context.recordExecution(agentName: orchestratorName)

        let graph = try makeGraph(steps: steps)
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

        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let threadID = HiveThreadID(resumeRequest?.workflowID ?? workflowID)

        let options = makeRunOptions(
            stepCount: steps.count,
            checkpointPolicy: checkpointPolicy,
            override: hiveRunOptionsOverride
        )

        let handle: HiveRunHandle<Schema>
        if let resumeRequest {
            handle = await runtime.resume(
                threadID: threadID,
                interruptID: HiveInterruptID(resumeRequest.interruptID),
                payload: resumeRequest.payload,
                options: options
            )
        } else {
            handle = await runtime.run(threadID: threadID, input: input, options: options)
        }
        let eventsTask = Task<String?, Never> {
            do {
                for try await event in handle.events {
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
            metadata["orchestration.total_duration"] = .double(
                Double(duration.components.seconds) +
                    Double(duration.components.attoseconds) / 1e18
            )

            return .completed(
                AgentResult(
                    output: currentInput,
                    toolCalls: accumulator.toolCalls,
                    toolResults: accumulator.toolResults,
                    iterationCount: accumulator.iterationCount,
                    duration: duration,
                    tokenUsage: nil,
                    metadata: metadata
                )
            )

        case .cancelled:
            throw AgentError.cancelled

        case .outOfSteps(let maxSteps, _, _):
            throw AgentError.internalError(reason: "Hive orchestration exceeded maxSteps=\(maxSteps).")

        case .interrupted(let interruption):
            let handle = try await buildWorkflowResumeHandle(
                interruption: interruption,
                threadID: threadID,
                fallbackInput: input,
                checkpointStore: checkpointStore
            )
            return .interrupted(handle)
        }
    }

    static func makeHiveCheckpointPolicy(_ policy: WorkflowCheckpointPolicy) -> HiveCheckpointPolicy {
        switch policy {
        case .disabled:
            .disabled
        case .everyStep:
            .everyStep
        case let .everyNSteps(value):
            .every(steps: max(1, value))
        case .onInterrupt:
            .onInterrupt
        }
    }

    static func makeDefaultCheckpointStore() -> AnyHiveCheckpointStore<Schema> {
        AnyHiveCheckpointStore(InMemoryCheckpointStore<Schema>())
    }

    private static func buildWorkflowResumeHandle(
        interruption: HiveInterruption<Schema>,
        threadID: HiveThreadID,
        fallbackInput: String,
        checkpointStore: AnyHiveCheckpointStore<Schema>?
    ) async throws -> WorkflowResumeHandle {
        let checkpointState = await makeCheckpointState(
            interruption: interruption,
            threadID: threadID,
            fallbackInput: fallbackInput,
            checkpointStore: checkpointStore
        )

        let reason = interruptReason(from: interruption.interrupt.payload)
        return WorkflowResumeHandle(
            workflowID: threadID.rawValue,
            checkpoint: checkpointState,
            interruptReason: reason,
            threadID: threadID.rawValue,
            interruptID: interruption.interrupt.id.rawValue,
            checkpointID: interruption.checkpointID.rawValue,
            suggestedResumePayload: "approved",
            interruptPayload: interruption.interrupt.payload
        )
    }

    private static func makeCheckpointState(
        interruption: HiveInterruption<Schema>,
        threadID: HiveThreadID,
        fallbackInput: String,
        checkpointStore: AnyHiveCheckpointStore<Schema>?
    ) async -> WorkflowCheckpointState {
        var stepIndex = 0
        var intermediateOutput = fallbackInput

        if let checkpointStore,
           let checkpoint = try? await checkpointStore.loadCheckpoint(threadID: threadID, id: interruption.checkpointID)
        {
            stepIndex = checkpoint.stepIndex
            if let value = decodeCurrentInput(from: checkpoint) {
                intermediateOutput = value
            }
        }

        let metadata: [String: SendableValue] = [
            "hive.thread_id": .string(threadID.rawValue),
            "hive.interrupt_id": .string(interruption.interrupt.id.rawValue),
            "hive.checkpoint_id": .string(interruption.checkpointID.rawValue),
        ]

        return WorkflowCheckpointState(
            workflowID: threadID.rawValue,
            stepIndex: stepIndex,
            intermediateOutput: intermediateOutput,
            metadata: metadata,
            timestamp: Date()
        )
    }

    private static func decodeCurrentInput(from checkpoint: HiveCheckpoint<Schema>) -> String? {
        guard let payload = checkpoint.globalDataByChannelID[Schema.currentInputKey.id.rawValue] else {
            return nil
        }
        return try? JSONDecoder().decode(String.self, from: payload)
    }

    private static func interruptReason(from payload: String) -> WorkflowInterruptReason {
        let prefix = "human-approval-required:"
        if payload.hasPrefix(prefix) {
            return .humanApprovalRequired(prompt: String(payload.dropFirst(prefix.count)))
        }
        return .externalInterrupt
    }

    private static func makeRunOptions(
        stepCount: Int,
        checkpointPolicy: HiveCheckpointPolicy,
        override optionsOverride: SwarmHiveRunOptionsOverride?
    ) -> HiveRunOptions {
        let defaultOptions = HiveRunOptions(
            maxSteps: stepCount,
            maxConcurrentTasks: 1,
            checkpointPolicy: checkpointPolicy,
            debugPayloads: false,
            deterministicTokenStreaming: false,
            eventBufferCapacity: max(64, stepCount * 8)
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

    private static func makeGraph(steps: [OrchestrationStep]) throws -> CompiledHiveGraph<Schema> {
        precondition(!steps.isEmpty)

        let nodeIDs = steps.indices.map { HiveNodeID("orchestration.step_\($0)") }

        var builder = HiveGraphBuilder<Schema>(start: [nodeIDs[0]])

        for (index, step) in steps.enumerated() {
            let nodeID = nodeIDs[index]
            builder.addNode(nodeID) { input in
                let stepContext = input.context
                let currentInput = try input.store.get(Schema.currentInputKey)
                let result: AgentResult
                if let approvalStep = step as? HumanApproval, approvalStep.handler == nil {
                    if let resumePayload = input.run.resume?.payload {
                        result = try synthesizeApprovalResumeResult(
                            step: approvalStep,
                            currentInput: currentInput,
                            payload: resumePayload
                        )
                    } else {
                        return HiveNodeOutput(
                            interrupt: HiveInterruptRequest(
                                payload: "human-approval-required:\(approvalStep.prompt)"
                            )
                        )
                    }
                } else {
                    do {
                        result = try await step.execute(currentInput, context: stepContext)
                    } catch let error as OrchestrationError {
                        if case let .workflowInterrupted(reason) = error {
                            if shouldResumeFromInterruption(input.run.resume?.payload) {
                                result = AgentResult(output: currentInput)
                            } else {
                                return HiveNodeOutput(
                                    interrupt: HiveInterruptRequest(payload: reason)
                                )
                            }
                        } else {
                            throw error
                        }
                    }
                }

                var metadataUpdate: [String: SendableValue] = [:]
                for (key, value) in result.metadata {
                    metadataUpdate[key] = value
                    metadataUpdate["orchestration.step_\(index).\(key)"] = value
                }

                let delta = Accumulator(
                    toolCalls: result.toolCalls,
                    toolResults: result.toolResults,
                    iterationCount: result.iterationCount,
                    metadata: metadataUpdate
                )

                await stepContext.agentContext.setPreviousOutput(result)

                return HiveNodeOutput(
                    writes: [
                        AnyHiveWrite(Schema.currentInputKey, result.output),
                        AnyHiveWrite(Schema.accumulatorKey, delta)
                    ]
                )
            }

            if index > 0 {
                builder.addEdge(from: nodeIDs[index - 1], to: nodeID)
            }
        }

        builder.setOutputProjection(.channels([Schema.currentInputKey.id, Schema.accumulatorKey.id]))
        return try builder.compile()
    }

    private static func shouldResumeFromInterruption(_ payload: String?) -> Bool {
        guard let payload else { return false }
        let normalized = payload.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        switch normalized {
        case "reject", "rejected", "cancel", "cancelled", "no":
            return false
        default:
            return true
        }
    }

    private static func synthesizeApprovalResumeResult(
        step: HumanApproval,
        currentInput: String,
        payload: String
    ) throws -> AgentResult {
        let normalized = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = normalized.lowercased()

        if ["reject", "rejected", "cancel", "cancelled", "no"].contains(lower) {
            throw OrchestrationError.humanApprovalRejected(
                prompt: step.prompt,
                reason: "Rejected through resume payload."
            )
        }

        let output: String
        let responseValue: String

        if normalized.hasPrefix("modified:") {
            output = String(normalized.dropFirst("modified:".count))
            responseValue = "modified"
        } else {
            output = currentInput
            responseValue = "approved"
        }

        let metadata: [String: SendableValue] = [
            "approval.prompt": .string(step.prompt),
            "approval.wait_duration": .double(0),
            "approval.response": .string(responseValue),
        ]

        return AgentResult(
            output: output,
            toolCalls: [],
            toolResults: [],
            iterationCount: 0,
            duration: .zero,
            tokenUsage: nil,
            metadata: metadata
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

private actor InMemoryCheckpointStore<Schema: HiveSchema>: HiveCheckpointQueryableStore {
    private var checkpoints: [HiveCheckpoint<Schema>] = []

    func save(_ checkpoint: HiveCheckpoint<Schema>) async throws {
        checkpoints.append(checkpoint)
    }

    func loadLatest(threadID: HiveThreadID) async throws -> HiveCheckpoint<Schema>? {
        checkpoints.last(where: { $0.threadID == threadID })
    }

    func listCheckpoints(threadID: HiveThreadID, limit: Int?) async throws -> [HiveCheckpointSummary] {
        let summaries = checkpoints
            .filter { $0.threadID == threadID }
            .map { checkpoint in
                HiveCheckpointSummary(
                    id: checkpoint.id,
                    threadID: checkpoint.threadID,
                    runID: checkpoint.runID,
                    stepIndex: checkpoint.stepIndex
                )
            }
            .sorted(by: { $0.stepIndex < $1.stepIndex })

        if let limit, limit > 0 {
            return Array(summaries.suffix(limit))
        }
        return summaries
    }

    func loadCheckpoint(threadID: HiveThreadID, id: HiveCheckpointID) async throws -> HiveCheckpoint<Schema>? {
        checkpoints.last(where: { $0.threadID == threadID && $0.id == id })
    }
}

private struct SwarmHiveClock: HiveClock {
    func nowNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    func sleep(nanoseconds: UInt64) async throws {
        try await Task.sleep(for: .nanoseconds(nanoseconds))
    }
}

private struct SwarmHiveLogger: HiveLogger {
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
private struct JSONCodec<Value: Codable & Sendable>: HiveCodec {
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

#endif
