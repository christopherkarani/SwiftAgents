import Foundation
import Testing
@testable import HiveSwarm

@Suite("HiveSwarm enhancement tasks")
struct HiveSwarmEnhancementTasksTests {
    @Test("Task 1: llmInputMessages channel is ephemeral")
    func task1_llmInputMessagesChannelIsEphemeral() throws {
        let registry = try HiveSchemaRegistry<HiveAgents.Schema>()
        let spec = try #require(registry.channelSpecsByID[HiveAgents.Schema.llmInputMessagesKey.id])
        #expect(spec.persistence == .ephemeral)
    }

    @Test("Task 2: tokenCount accumulates message token deltas")
    func task2_tokenCountAccumulates() async throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()
        let context = HiveAgentsContext(
            modelName: "test-model",
            toolApprovalPolicy: .never,
            compactionPolicy: HiveCompactionPolicy(maxTokens: 100, preserveLastMessages: 4),
            tokenizer: MessageCountTokenizer()
        )

        let environment = HiveEnvironment<HiveAgents.Schema>(
            context: context,
            clock: NoopClock(),
            logger: NoopLogger(),
            model: AnyHiveModelClient(ScriptedModelClient(script: ModelScript(chunksByInvocation: [
                [.final(HiveChatResponse(message: message(
                    id: "m1",
                    role: .assistant,
                    content: "",
                    toolCalls: [HiveToolCall(id: "c1", name: "calc", argumentsJSON: "{}")]
                )))],
                [.final(HiveChatResponse(message: message(id: "m2", role: .assistant, content: "done")))],
            ]))),
            modelRouter: nil,
            tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "42")),
            checkpointStore: nil
        )

        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let outcome = try await waitOutcome(
            await runtime.run(
                threadID: HiveThreadID("token-count"),
                input: "Hello",
                options: HiveRunOptions(maxSteps: 12, checkpointPolicy: .disabled)
            )
        )

        let store = try requireFullStore(outcome: outcome)
        let messages = try store.get(HiveAgents.Schema.messagesKey)
        let tokenCount = try store.get(HiveAgents.Schema.tokenCountKey)
        #expect(tokenCount == messages.count)
    }

    @Test("Task 3: preModel node is deferred")
    func task3_preModelNodeIsDeferred() throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()
        let preModel = try #require(graph.nodesByID[HiveNodeID("preModel")])
        #expect(preModel.options.contains(.deferred))

        let toolExecuteEdges = graph.staticEdgesByFrom[HiveNodeID("toolExecute")] ?? []
        #expect(toolExecuteEdges.contains(HiveNodeID("preModel")) == false)
    }

    @Test("Task 4: cache policies are default-on and can be disabled")
    func task4_cachePoliciesDefaultAndDisable() throws {
        let defaultGraph = try HiveAgents.makeToolUsingChatAgent()
        #expect(defaultGraph.nodesByID[HiveNodeID("model")]?.cachePolicy != nil)
        #expect(defaultGraph.nodesByID[HiveNodeID("preModel")]?.cachePolicy != nil)

        let context = HiveAgentsContext(
            modelName: "test-model",
            toolApprovalPolicy: .never,
            modelNodeCachePolicy: nil,
            compactionCachePolicy: nil
        )
        let disabledGraph = try HiveAgents.makeToolUsingChatAgent(context: context)
        #expect(disabledGraph.nodesByID[HiveNodeID("model")]?.cachePolicy == nil)
        #expect(disabledGraph.nodesByID[HiveNodeID("preModel")]?.cachePolicy == nil)
    }

    @Test("Task 5a: currentState returns interruption snapshot")
    func task5a_currentStateReturnsInterruptionSnapshot() async throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()
        let checkpointStore = QueryableCheckpointStore<HiveAgents.Schema>()
        let context = HiveAgentsContext(modelName: "test-model", toolApprovalPolicy: .always)

        let environment = HiveEnvironment<HiveAgents.Schema>(
            context: context,
            clock: NoopClock(),
            logger: NoopLogger(),
            model: AnyHiveModelClient(ScriptedModelClient(script: ModelScript(chunksByInvocation: [
                [.final(HiveChatResponse(message: message(
                    id: "m1",
                    role: .assistant,
                    content: "",
                    toolCalls: [HiveToolCall(id: "c1", name: "calc", argumentsJSON: "{}")]
                )))]
            ]))),
            modelRouter: nil,
            tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "42")),
            checkpointStore: AnyHiveCheckpointStore(checkpointStore)
        )

        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let hiveRuntime = HiveAgentsRuntime(runControl: HiveAgentsRunController(runtime: runtime))
        let threadID = HiveThreadID("current-state-interrupt")
        let agent = HiveBackedAgent(
            runtime: hiveRuntime,
            name: "bridge",
            threadID: threadID,
            runOptions: HiveRunOptions(maxSteps: 10, checkpointPolicy: .onInterrupt)
        )

        await #expect(throws: (any Error).self) {
            _ = try await agent.run("Hello")
        }

        let snapshot = try #require(try await agent.currentState())
        #expect(snapshot.isInterrupted)
        #expect(snapshot.activeNodes.contains("toolExecute"))
        #expect(snapshot.messages.contains { !$0.toolCalls.isEmpty })
    }

    @Test("Task 6: fork recovery retries from pre-tool checkpoint")
    func task6_forkRecoveryRetriesFromCheckpoint() async throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()
        let checkpointStore = QueryableCheckpointStore<HiveAgents.Schema>()
        let flakyBackend = FlakyToolBackend()
        let context = HiveAgentsContext(
            modelName: "test-model",
            toolApprovalPolicy: .never,
            maxForkRetries: 1
        )

        let environment = HiveEnvironment<HiveAgents.Schema>(
            context: context,
            clock: NoopClock(),
            logger: NoopLogger(),
            model: AnyHiveModelClient(ScriptedModelClient(script: ModelScript(chunksByInvocation: [
                [.final(HiveChatResponse(message: message(
                    id: "m1",
                    role: .assistant,
                    content: "",
                    toolCalls: [HiveToolCall(id: "c1", name: "calc", argumentsJSON: "{}")]
                )))],
                [.final(HiveChatResponse(message: message(id: "m2", role: .assistant, content: "done")))],
            ]))),
            modelRouter: nil,
            tools: AnyHiveToolRegistry(FlakyToolRegistry(backend: flakyBackend)),
            checkpointStore: AnyHiveCheckpointStore(checkpointStore)
        )

        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let hiveRuntime = HiveAgentsRuntime(runControl: HiveAgentsRunController(runtime: runtime))
        let agent = HiveBackedAgent(
            runtime: hiveRuntime,
            name: "bridge",
            threadID: HiveThreadID("fork-recovery"),
            runOptions: HiveRunOptions(maxSteps: 20, checkpointPolicy: .everyStep)
        )

        let result = try await agent.run("Recover from tool failure")
        #expect(result.output == "done")
        #expect(result.toolResults.contains { $0.isSuccess })
        #expect(await flakyBackend.invocationCount == 2)
    }
}

private func message(
    id: String,
    role: HiveChatRole,
    content: String,
    toolCalls: [HiveToolCall] = [],
    toolCallID: String? = nil
) -> HiveChatMessage {
    HiveChatMessage(
        id: id,
        role: role,
        content: content,
        toolCallID: toolCallID,
        toolCalls: toolCalls
    )
}

private struct MessageCountTokenizer: HiveTokenizer {
    func countTokens(_ messages: [HiveChatMessage]) -> Int { messages.count }
}

private actor ModelScript {
    private var chunksByInvocation: [[HiveChatStreamChunk]]

    init(chunksByInvocation: [[HiveChatStreamChunk]]) {
        self.chunksByInvocation = chunksByInvocation
    }

    func nextChunks() -> [HiveChatStreamChunk] {
        guard chunksByInvocation.isEmpty == false else { return [] }
        return chunksByInvocation.removeFirst()
    }
}

private struct ScriptedModelClient: HiveModelClient {
    let script: ModelScript

    func complete(_: HiveChatRequest) async throws -> HiveChatResponse {
        let chunks = await script.nextChunks()
        for chunk in chunks {
            if case let .final(response) = chunk { return response }
        }
        throw HiveRuntimeError.modelStreamInvalid("Missing final chunk.")
    }

    func stream(_: HiveChatRequest) -> AsyncThrowingStream<HiveChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let chunks = await script.nextChunks()
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }
}

private struct StubToolRegistry: HiveToolRegistry, Sendable {
    let resultContent: String

    func listTools() -> [HiveToolDefinition] {
        [
            HiveToolDefinition(
                name: "calc",
                description: "calculator",
                parametersJSONSchema: "{}"
            )
        ]
    }

    func invoke(_ call: HiveToolCall) async throws -> HiveToolResult {
        HiveToolResult(toolCallID: call.id, content: resultContent)
    }
}

private actor FlakyToolBackend {
    private var hasFailedOnce = false
    private(set) var invocationCount = 0

    func invoke(call: HiveToolCall) throws -> HiveToolResult {
        invocationCount += 1
        if !hasFailedOnce {
            hasFailedOnce = true
            throw TestFailure("intentional first failure")
        }
        return HiveToolResult(toolCallID: call.id, content: "42")
    }
}

private struct FlakyToolRegistry: HiveToolRegistry, Sendable {
    let backend: FlakyToolBackend

    func listTools() -> [HiveToolDefinition] {
        [
            HiveToolDefinition(
                name: "calc",
                description: "calculator",
                parametersJSONSchema: "{}"
            )
        ]
    }

    func invoke(_ call: HiveToolCall) async throws -> HiveToolResult {
        try await backend.invoke(call: call)
    }
}

private actor QueryableCheckpointStore<Schema: HiveSchema>: HiveCheckpointQueryableStore {
    private var checkpoints: [HiveCheckpoint<Schema>] = []

    func save(_ checkpoint: HiveCheckpoint<Schema>) async throws {
        checkpoints.append(checkpoint)
    }

    func loadLatest(threadID: HiveThreadID) async throws -> HiveCheckpoint<Schema>? {
        checkpoints
            .filter { $0.threadID == threadID }
            .max { lhs, rhs in
                if lhs.stepIndex == rhs.stepIndex { return lhs.id.rawValue < rhs.id.rawValue }
                return lhs.stepIndex < rhs.stepIndex
            }
    }

    func listCheckpoints(threadID: HiveThreadID, limit: Int?) async throws -> [HiveCheckpointSummary] {
        let summaries = checkpoints
            .filter { $0.threadID == threadID }
            .map { checkpoint in
                HiveCheckpointSummary(
                    id: checkpoint.id,
                    threadID: checkpoint.threadID,
                    runID: checkpoint.runID,
                    stepIndex: checkpoint.stepIndex,
                    schemaVersion: checkpoint.schemaVersion,
                    graphVersion: checkpoint.graphVersion
                )
            }
            .sorted { lhs, rhs in
                if lhs.stepIndex == rhs.stepIndex { return lhs.id.rawValue < rhs.id.rawValue }
                return lhs.stepIndex < rhs.stepIndex
            }
        if let limit {
            return Array(summaries.suffix(limit))
        }
        return summaries
    }

    func loadCheckpoint(threadID: HiveThreadID, id: HiveCheckpointID) async throws -> HiveCheckpoint<Schema>? {
        checkpoints.first { $0.threadID == threadID && $0.id == id }
    }
}

private struct NoopClock: HiveClock {
    func nowNanoseconds() -> UInt64 { 0 }
    func sleep(nanoseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

private struct NoopLogger: HiveLogger {
    func debug(_: String, metadata _: [String: String]) {}
    func info(_: String, metadata _: [String: String]) {}
    func error(_: String, metadata _: [String: String]) {}
}

private func waitOutcome<Schema: HiveSchema>(
    _ handle: HiveRunHandle<Schema>
) async throws -> HiveRunOutcome<Schema> {
    try await handle.outcome.value
}

private func requireFullStore<Schema: HiveSchema>(
    outcome: HiveRunOutcome<Schema>
) throws -> HiveGlobalStore<Schema> {
    switch outcome {
    case let .finished(output, _),
         let .cancelled(output, _),
         let .outOfSteps(_, output, _):
        switch output {
        case let .fullStore(store):
            return store
        case .channels:
            throw TestFailure("Expected full store output.")
        }
    case .interrupted:
        throw TestFailure("Expected non-interrupted outcome.")
    }
}

private struct TestFailure: Error, Sendable, CustomStringConvertible {
    let description: String
    init(_ description: String) {
        self.description = description
    }
}
