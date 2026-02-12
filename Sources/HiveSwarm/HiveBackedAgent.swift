// HiveBackedAgent.swift
// HiveSwarm
//
// Bridge adapter that exposes a Hive-native agent graph as a Swarm `AgentRuntime`.

import Foundation
import HiveCore
import Swarm

// MARK: - HiveBackedAgent

/// Bridges a Hive-native agent graph into Swarm's `AgentRuntime` protocol.
///
/// This allows `HiveAgentsRuntime` (which uses Hive's deterministic graph engine
/// for the model-tool loop) to participate in Swarm orchestrations as a regular agent step.
///
/// The adapter translates between the two execution models:
/// - Hive's channel-based results (`finalAnswerKey`, `messagesKey`, `pendingToolCallsKey`)
///   are mapped to `AgentResult` fields (`output`, `toolCalls`, `toolResults`).
/// - Hive's `HiveEvent` stream is mapped to Swarm's `AgentEvent` enum for streaming.
///
/// Example:
/// ```swift
/// let hiveAgent = HiveBackedAgent(
///     runtime: hiveAgentsRuntime,
///     name: "research-agent",
///     instructions: "You are a research assistant."
/// )
///
/// // Use in an orchestration alongside native Swarm agents
/// let result = try await hiveAgent.run("Summarize the latest findings.")
/// print(result.output)
/// ```
public struct HiveBackedAgent: AgentRuntime, Sendable {
    // MARK: - Properties

    /// The wrapped Hive agents runtime.
    private let runtime: HiveAgentsRuntime

    /// The thread ID used for Hive run invocations.
    private let threadID: HiveThreadID

    /// Hive run options applied to each invocation.
    private let runOptions: HiveRunOptions

    /// The current cancellation task handle (actor-isolated for safe mutation).
    private let cancellation: CancellationController

    // MARK: - AgentRuntime Properties

    nonisolated public let tools: [any AnyJSONTool]
    nonisolated public let instructions: String
    nonisolated public let configuration: AgentConfiguration

    // MARK: - Initialization

    /// Creates a new Hive-backed agent bridge.
    ///
    /// - Parameters:
    ///   - runtime: The `HiveAgentsRuntime` to delegate execution to.
    ///   - name: Display name for this agent in Swarm orchestrations.
    ///   - instructions: Agent instructions (for display/logging; the actual
    ///     system prompt is managed by the Hive graph's `preModel` node).
    ///   - threadID: The Hive thread to run on. Default: a new UUID-based thread.
    ///   - runOptions: Hive run options. Default: 20 max steps, checkpointing disabled.
    ///   - configuration: Swarm agent configuration. If not provided, a default
    ///     is created using the given name.
    public init(
        runtime: HiveAgentsRuntime,
        name: String,
        instructions: String = "",
        threadID: HiveThreadID = HiveThreadID(UUID().uuidString),
        runOptions: HiveRunOptions = HiveRunOptions(maxSteps: 20, checkpointPolicy: .disabled),
        configuration: AgentConfiguration? = nil
    ) {
        self.runtime = runtime
        self.threadID = threadID
        self.runOptions = runOptions
        self.instructions = instructions
        self.cancellation = CancellationController()
        tools = []

        var config = configuration ?? .default
        config.name = name
        self.configuration = config
    }

    // MARK: - AgentRuntime Methods

    /// Executes the Hive agent graph with the given input.
    ///
    /// This sends a user message through `HiveAgentsRunController.start()`,
    /// waits for the outcome, and translates the final channel state into an `AgentResult`.
    ///
    /// - Parameters:
    ///   - input: The user's input/query.
    ///   - session: Ignored. Hive manages its own thread-based state.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: The translated `AgentResult`.
    /// - Throws: `AgentError` wrapping any `HiveRuntimeError`.
    public func run(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput(reason: "Input cannot be empty")
        }

        let resultBuilder = AgentResult.Builder()
        _ = resultBuilder.start()

        await hooks?.onAgentStart(context: nil, agent: self, input: input)

        do {
            let request = HiveAgentsRunStartRequest(
                threadID: threadID,
                input: input,
                options: runOptions
            )

            let handle = try await runtime.runControl.start(request)
            await cancellation.track(handle)

            let outcome = try await handle.outcome.value
            let result = try buildResult(from: outcome, builder: resultBuilder)

            await hooks?.onAgentEnd(context: nil, agent: self, result: result)
            return result
        } catch let error as HiveRuntimeError {
            let agentError = mapHiveError(error)
            await hooks?.onError(context: nil, agent: self, error: agentError)
            throw agentError
        } catch {
            await hooks?.onError(context: nil, agent: self, error: error)
            throw error
        }
    }

    /// Streams the agent's execution, mapping Hive events to Swarm `AgentEvent`.
    ///
    /// Unlike `run()`, this method consumes the Hive event stream (`handle.events`)
    /// and maps each `HiveEventKind` to the corresponding `AgentEvent`, providing
    /// real-time visibility into model token generation, tool invocations, and
    /// step lifecycle.
    ///
    /// - Parameters:
    ///   - input: The user's input/query.
    ///   - session: Ignored. Hive manages its own thread-based state.
    ///   - hooks: Optional hooks for lifecycle callbacks.
    /// - Returns: An async stream of `AgentEvent`.
    nonisolated public func stream(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { [self] continuation in
            guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                let error = AgentError.invalidInput(reason: "Input cannot be empty")
                continuation.yield(.failed(error: error))
                continuation.finish(throwing: error)
                return
            }

            continuation.yield(.started(input: input))

            let resultBuilder = AgentResult.Builder()
            _ = resultBuilder.start()

            await hooks?.onAgentStart(context: nil, agent: self, input: input)

            do {
                let request = HiveAgentsRunStartRequest(
                    threadID: threadID,
                    input: input,
                    options: runOptions
                )

                let handle = try await runtime.runControl.start(request)
                await cancellation.track(handle)

                // Fork a task to consume Hive events and yield mapped AgentEvents.
                let eventsTask = Task<Void, Never> {
                    do {
                        for try await event in handle.events {
                            if let agentEvent = Self.mapHiveEvent(event) {
                                continuation.yield(agentEvent)
                            }
                        }
                    } catch {
                        Log.agents.debug("Hive event stream ended: \(error.localizedDescription)")
                    }
                }

                let outcome = try await handle.outcome.value

                // Wait for all events to be consumed before building the result.
                await eventsTask.value

                let result = try buildResult(from: outcome, builder: resultBuilder)

                await hooks?.onAgentEnd(context: nil, agent: self, result: result)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch let error as HiveRuntimeError {
                let agentError = mapHiveError(error)
                await hooks?.onError(context: nil, agent: self, error: agentError)
                continuation.yield(.failed(error: agentError))
                continuation.finish(throwing: agentError)
            } catch {
                await hooks?.onError(context: nil, agent: self, error: error)
                let wrapped = AgentError.internalError(reason: error.localizedDescription)
                continuation.yield(.failed(error: wrapped))
                continuation.finish(throwing: error)
            }
        }
    }

    /// Cancels any ongoing Hive run.
    public func cancel() async {
        await cancellation.cancelCurrent()
    }

    // MARK: - Event Mapping

    /// Maps a `HiveEvent` to an `AgentEvent`, returning `nil` for events
    /// that have no meaningful Swarm equivalent (e.g., checkpoint, write-applied).
    private static func mapHiveEvent(_ event: HiveEvent) -> AgentEvent? {
        switch event.kind {
        case .modelInvocationStarted(let model):
            return .llmStarted(model: model, promptTokens: nil)

        case .modelToken(let text):
            return .outputToken(token: text)

        case .modelInvocationFinished:
            return .llmCompleted(model: nil, promptTokens: nil, completionTokens: nil, duration: 0)

        case .toolInvocationStarted(let name):
            let call = ToolCall(toolName: name, arguments: [:])
            return .toolCallStarted(call: call)

        case .toolInvocationFinished(let name, let success):
            let call = ToolCall(toolName: name, arguments: [:])
            if success {
                let result = ToolResult(callId: call.id, isSuccess: true, output: .null, duration: .zero)
                return .toolCallCompleted(call: call, result: result)
            } else {
                let error = AgentError.toolExecutionFailed(toolName: name, underlyingError: "Tool invocation failed")
                return .toolCallFailed(call: call, error: error)
            }

        case .stepStarted(let stepIndex, _):
            return .iterationStarted(number: stepIndex + 1)

        case .stepFinished(let stepIndex, _):
            return .iterationCompleted(number: stepIndex + 1)

        default:
            return nil
        }
    }

    // MARK: - Private Methods

    /// Extracts an `AgentResult` from a `HiveRunOutcome`.
    private func buildResult(
        from outcome: HiveRunOutcome<HiveAgents.Schema>,
        builder: AgentResult.Builder
    ) throws -> AgentResult {
        let store: HiveGlobalStore<HiveAgents.Schema>

        switch outcome {
        case let .finished(output, _):
            switch output {
            case let .fullStore(s):
                store = s
            case .channels:
                throw AgentError.internalError(reason: "Hive returned channel-only output; full store required.")
            }

        case let .outOfSteps(maxSteps, output, _):
            switch output {
            case let .fullStore(s):
                store = s
                Log.agents.warning("Hive run hit max steps (\(maxSteps)); returning partial result.")
            case .channels:
                throw AgentError.maxIterationsExceeded(iterations: maxSteps)
            }

        case .interrupted:
            throw AgentError.internalError(reason: "Hive run was interrupted (tool approval required).")

        case let .cancelled(output, _):
            switch output {
            case let .fullStore(s):
                store = s
                Log.agents.info("Hive run was cancelled; returning partial result.")
            case .channels:
                throw AgentError.cancelled
            }
        }

        // Extract final answer
        let finalAnswer: String
        do {
            let answer = try store.get(HiveAgents.Schema.finalAnswerKey)
            finalAnswer = answer ?? ""
        } catch {
            Log.agents.error("Failed to read finalAnswerKey from Hive store: \(error)")
            throw AgentError.internalError(reason: "Failed to extract final answer from Hive: \(error.localizedDescription)")
        }
        _ = builder.setOutput(finalAnswer)

        // Extract tool call information from messages.
        // We correlate ToolCall.id and ToolResult.callId using the Hive tool call ID
        // so that runWithResponse() can build proper ToolCallRecords.
        do {
            let messages = try store.get(HiveAgents.Schema.messagesKey)

            // Map from Hive tool call ID → Swarm UUID for correlation.
            var hiveToSwarmID: [String: UUID] = [:]

            for message in messages where !message.toolCalls.isEmpty {
                for hiveToolCall in message.toolCalls {
                    let swarmID = UUID()
                    hiveToSwarmID[hiveToolCall.id] = swarmID
                    let toolCall = ToolCall(
                        id: swarmID,
                        providerCallId: hiveToolCall.id,
                        toolName: hiveToolCall.name,
                        arguments: parseToolArguments(hiveToolCall.argumentsJSON)
                    )
                    _ = builder.addToolCall(toolCall)
                }
            }

            for message in messages where message.role.rawValue == "tool" {
                guard let hiveCallID = message.toolCallID else { continue }
                let callID: UUID
                if let existing = hiveToSwarmID[hiveCallID] {
                    callID = existing
                } else {
                    // Preserve ToolCall/ToolResult linkage for replayed or partial histories.
                    let syntheticID = UUID()
                    hiveToSwarmID[hiveCallID] = syntheticID
                    let syntheticCall = ToolCall(
                        id: syntheticID,
                        providerCallId: hiveCallID,
                        toolName: "unknown_tool",
                        arguments: [:]
                    )
                    _ = builder.addToolCall(syntheticCall)
                    callID = syntheticID
                }

                let toolResult = ToolResult(
                    callId: callID,
                    isSuccess: true,
                    output: .string(message.content),
                    duration: .zero
                )
                _ = builder.addToolResult(toolResult)
            }

            // Count model invocations as iterations (assistant messages)
            let assistantCount = messages.filter { $0.role.rawValue == "assistant" }.count
            for _ in 0 ..< max(assistantCount, 1) {
                _ = builder.incrementIteration()
            }
        } catch {
            Log.agents.error("Failed to extract tool calls from Hive messages: \(error)")
            // Set metadata to indicate extraction failure
            _ = builder.setMetadata("extraction_error", .string("Failed to extract tool calls: \(error.localizedDescription)"))
            _ = builder.incrementIteration()
        }

        return builder.build()
    }

    /// Parses Hive tool call argument JSON string into a Swarm-compatible dictionary.
    private func parseToolArguments(_ jsonString: String) -> [String: SendableValue] {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ["raw": .string(jsonString)]
        }

        var result: [String: SendableValue] = [:]
        for (key, value) in json {
            result[key] = convertToSendableValue(value)
        }
        return result
    }

    /// Converts a JSON-deserialized value to `SendableValue`.
    private func convertToSendableValue(_ value: Any) -> SendableValue {
        switch value {
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if CFBooleanGetTypeID() == CFGetTypeID(number) {
                return .bool(number.boolValue)
            }
            if number.doubleValue == Double(number.intValue) {
                return .int(number.intValue)
            }
            return .double(number.doubleValue)
        case let array as [Any]:
            return .array(array.map { convertToSendableValue($0) })
        case let dict as [String: Any]:
            var mapped: [String: SendableValue] = [:]
            for (k, v) in dict {
                mapped[k] = convertToSendableValue(v)
            }
            return .dictionary(mapped)
        case is NSNull:
            return .null
        default:
            return .string(String(describing: value))
        }
    }

    /// Maps a `HiveRuntimeError` to an appropriate `AgentError`.
    private func mapHiveError(_ error: HiveRuntimeError) -> AgentError {
        switch error {
        case .modelClientMissing:
            return .inferenceProviderUnavailable(reason: "Hive model client is not configured.")
        case .toolRegistryMissing:
            return .internalError(reason: "Hive tool registry is not configured.")
        case .checkpointStoreMissing:
            return .internalError(reason: "Hive checkpoint store required for tool approval policy.")
        case let .invalidRunOptions(reason):
            return .invalidInput(reason: "Invalid Hive run options: \(reason)")
        case let .modelStreamInvalid(reason):
            return .generationFailed(reason: "Hive model stream error: \(reason)")
        case .invalidMessagesUpdate:
            return .internalError(reason: "Hive messages channel received invalid update.")
        default:
            return .internalError(reason: "Hive runtime error: \(error)")
        }
    }
}

// MARK: - CancellationController

/// Actor that safely tracks and cancels the current Hive run handle.
///
/// Stores the actual `HiveRunHandle` so cancellation propagates to the Hive runtime,
/// not just to an awaiting wrapper task.
private actor CancellationController {
    private var currentHandle: HiveRunHandle<HiveAgents.Schema>?

    /// Records a new run handle for potential cancellation.
    func track(_ handle: HiveRunHandle<HiveAgents.Schema>) {
        // Cancel any previously tracked run.
        currentHandle?.outcome.cancel()
        currentHandle = handle
    }

    /// Cancels the currently tracked run.
    func cancelCurrent() {
        currentHandle?.outcome.cancel()
        currentHandle = nil
    }
}
