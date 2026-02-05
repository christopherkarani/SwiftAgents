// OrchestrationHiveEngine.swift
// Swarm Framework
//
// Hive-backed orchestration executor.

#if SWARM_HIVE_RUNTIME && canImport(HiveCore)

import Dispatch
import Foundation
import HiveCore
import Logging

enum OrchestrationHiveEngine {
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
                        persistence: .untracked
                    )
                ),
                AnyHiveChannelSpec(
                    HiveChannelSpec(
                        key: accumulatorKey,
                        scope: .global,
                        reducer: HiveReducer(Accumulator.reduce),
                        updatePolicy: .single,
                        initial: { Accumulator() },
                        persistence: .untracked
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
        onIterationStart: ((Int) -> Void)?,
        onIterationEnd: ((Int) -> Void)?
    ) async throws -> AgentResult {
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
            logger: SwarmHiveLogger()
        )

        let runtime = HiveRuntime(graph: graph, environment: environment)
        let threadID = HiveThreadID(UUID().uuidString)

        let options = HiveRunOptions(
            maxSteps: steps.count,
            maxConcurrentTasks: 1,
            checkpointPolicy: .disabled,
            debugPayloads: false,
            deterministicTokenStreaming: false,
            eventBufferCapacity: max(64, steps.count * 8),
            outputProjectionOverride: .fullStore
        )

        let handle = await runtime.run(threadID: threadID, input: input, options: options)

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
        } catch {
            // Ignore stream errors; outcome handles the terminal error path.
        }

        let outcome = try await handle.outcome.value

        switch outcome {
        case .finished(let output, _):
            let store = try requireFullStore(output)
            let currentInput = try store.get(Schema.currentInputKey)
            let accumulator = try store.get(Schema.accumulatorKey)

            let duration = ContinuousClock.now - startTime
            var metadata = accumulator.metadata
            metadata["orchestration.engine"] = .string("hive")
            metadata["orchestration.total_steps"] = .int(steps.count)
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

        case .interrupted:
            throw AgentError.internalError(reason: "Hive orchestration interrupted unexpectedly.")
        }
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
                let result = try await step.execute(currentInput, context: stepContext)

                var metadataUpdate = result.metadata
                for (key, value) in result.metadata {
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

        builder.setOutputProjection(.fullStore)
        return try builder.compile()
    }

    private static func requireFullStore(_ output: HiveRunOutput<Schema>) throws -> HiveGlobalStore<Schema> {
        switch output {
        case .fullStore(let store):
            return store
        case .channels:
            throw AgentError.internalError(reason: "Hive orchestration output projection mismatch.")
        }
    }
}

private struct SwarmHiveClock: HiveClock {
    func nowNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    func sleep(nanoseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: nanoseconds)
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

#endif
