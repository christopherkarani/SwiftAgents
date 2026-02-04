import CryptoKit
import Foundation
import Testing
@testable import HiveSwiftAgents

@Suite("HiveAgents (HiveSwiftAgents) — HiveCore runtime")
struct HiveAgentsTests {
    @Test("Messages reducer: removeAll uses last marker")
    func messagesReducer_removeAll_usesLastMarker() throws {
        let left: [HiveChatMessage] = [
            message(id: "a", role: .user, content: "A"),
            message(id: "b", role: .assistant, content: "B")
        ]

        let update: [HiveChatMessage] = [
            message(id: "c", role: .user, content: "C"),
            removeAllMarker(),
            message(id: "d", role: .assistant, content: "D"),
            removeAllMarker(),
            message(id: "e", role: .user, content: "E")
        ]

        let reduced = try HiveAgents.MessagesReducer.reduce(current: left, update: update)
        #expect(reduced.count == 1)
        #expect(reduced[0].id == "e")
        #expect(reduced[0].role.rawValue == "user")
        #expect(reduced[0].content == "E")
        #expect(reduced.allSatisfy { message in
            if case .none = message.op { return true }
            return false
        })
    }

    @Test("Compaction: llmInputMessages derived, messages preserved (runtime-driven)")
    func compaction_llmInputDerived_messagesPreserved() async throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()

        let context = HiveAgentsContext(
            modelName: "test-model",
            toolApprovalPolicy: .never,
            compactionPolicy: HiveCompactionPolicy(maxTokens: 3, preserveLastMessages: 2),
            tokenizer: MessageCountTokenizer()
        )

        let environment = HiveEnvironment<HiveAgents.Schema>(
            context: context,
            clock: NoopClock(),
            logger: NoopLogger(),
            model: nil,
            modelRouter: nil,
            tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "ok")),
            checkpointStore: nil
        )

        let runtime = HiveRuntime(graph: graph, environment: environment)
        let threadID = HiveThreadID("compaction-thread")

        // Seed canonical history without invoking nodes.
        let history: [HiveChatMessage] = [
            message(id: "sys", role: .system, content: "System"),
            message(id: "u1", role: .user, content: "U1"),
            message(id: "a1", role: .assistant, content: "A1"),
            message(id: "u2", role: .user, content: "U2"),
            message(id: "a2", role: .assistant, content: "A2")
        ]

        _ = try await waitOutcome(
            await runtime.applyExternalWrites(
                threadID: threadID,
                writes: [AnyHiveWrite(HiveAgents.Schema.messagesKey, history)],
                options: HiveRunOptions(maxSteps: 1, checkpointPolicy: .disabled)
            )
        )

        // Step 0 runs `preModel` only; compaction must not mutate `messages`.
        let outcome = try await waitOutcome(
            await runtime.run(
                threadID: threadID,
                input: "Hello",
                options: HiveRunOptions(maxSteps: 1, checkpointPolicy: .disabled)
            )
        )

        let store = try requireFullStore(outcome: outcome)
        let messages = try store.get(HiveAgents.Schema.messagesKey)
        let llmInput = try store.get(HiveAgents.Schema.llmInputMessagesKey)

        // Canonical messages must contain history + inputWrites user message.
        #expect(messages.count == history.count + 1)
        #expect(messages.prefix(history.count).map(\.id) == history.map(\.id))
        #expect(messages.prefix(history.count).map(\.content) == history.map(\.content))

        // llmInputMessages must be derived (non-nil) when over budget.
        let trimmed = try #require(llmInput)
        #expect(trimmed.count <= messages.count)
        #expect(trimmed.count == 3)
        #expect(trimmed.map(\.content) == ["U2", "A2", "Hello"])
    }

    @Test("Tool approval: requires checkpoint store (facade preflight)")
    func toolApproval_requiresCheckpointStore() async throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()
        let context = HiveAgentsContext(modelName: "test-model", toolApprovalPolicy: .always)

        let environment = HiveEnvironment<HiveAgents.Schema>(
            context: context,
            clock: NoopClock(),
            logger: NoopLogger(),
            model: AnyHiveModelClient(StubModelClient(chunks: [
                .final(HiveChatResponse(message: message(
                    id: "m",
                    role: .assistant,
                    content: "",
                    toolCalls: [HiveToolCall(id: "c1", name: "calc", argumentsJSON: "{}")]
                )))
            ])),
            modelRouter: nil,
            tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "42")),
            checkpointStore: nil
        )

        let runtime = HiveRuntime(graph: graph, environment: environment)
        let agents = HiveAgentsRuntime(threadID: HiveThreadID("t"), runtime: runtime)

        await #expect(throws: HiveRuntimeError.checkpointStoreMissing) {
            _ = try await agents.sendUserMessage("Hello")
        }
    }

    @Test("Tool approval: interrupt + resume executes tools (runtime-driven)")
    func toolApproval_interruptAndResume_executesTool() async throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()
        let store = InMemoryCheckpointStore<HiveAgents.Schema>()

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
                )))],
                [.final(HiveChatResponse(message: message(id: "m2", role: .assistant, content: "done")))]
            ]))),
            modelRouter: nil,
            tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "42")),
            checkpointStore: AnyHiveCheckpointStore(store)
        )

        let runtime = HiveRuntime(graph: graph, environment: environment)
        let agents = HiveAgentsRuntime(
            threadID: HiveThreadID("approval-thread"),
            runtime: runtime,
            options: HiveRunOptions(maxSteps: 10, checkpointPolicy: .disabled)
        )

        let handle = try await agents.sendUserMessage("Hello")
        let outcome = try await handle.outcome.value

        let interruption = try requireInterruption(outcome: outcome)
        switch interruption.interrupt.payload {
        case let .toolApprovalRequired(toolCalls):
            #expect(toolCalls.map(\.name) == ["calc"])
        }

        let resumeHandle = try await agents.resumeToolApproval(
            interruptID: interruption.interrupt.id,
            decision: .approved
        )
        let resumed = try await resumeHandle.outcome.value

        let finalStore = try requireFullStore(outcome: resumed)
        let messages = try finalStore.get(HiveAgents.Schema.messagesKey)
        #expect(messages.contains(where: { $0.role.rawValue == "tool" && $0.content == "42" && $0.toolCallID == "c1" }))
    }

    @Test("Deterministic message IDs: model taskID drives assistant message id")
    func deterministicMessageID_fromModelTaskID() async throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()

        let context = HiveAgentsContext(modelName: "test-model", toolApprovalPolicy: .never)
        let environment = HiveEnvironment<HiveAgents.Schema>(
            context: context,
            clock: NoopClock(),
            logger: NoopLogger(),
            model: AnyHiveModelClient(StubModelClient(chunks: [
                .final(HiveChatResponse(message: message(id: "m", role: .assistant, content: "ok")))
            ])),
            modelRouter: nil,
            tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "ok")),
            checkpointStore: nil
        )

        let runtime = HiveRuntime(graph: graph, environment: environment)
        let handle = await runtime.run(
            threadID: HiveThreadID("id-thread"),
            input: "Hello",
            options: HiveRunOptions(maxSteps: 2, checkpointPolicy: .disabled)
        )

        let events = await collectEvents(handle.events)
        let outcome = try await handle.outcome.value
        let store = try requireFullStore(outcome: outcome)

        let modelTaskID = try #require(
            events.compactMap { event in
                guard case let .taskStarted(node, taskID) = event.kind else { return nil }
                return node == HiveNodeID("model") ? taskID : nil
            }.first
        )

        let expectedID = expectedRoleBasedMessageID(taskID: modelTaskID.rawValue, role: "assistant")
        let messages = try store.get(HiveAgents.Schema.messagesKey)
        #expect(messages.contains(where: { $0.id == expectedID && $0.role.rawValue == "assistant" && $0.content == "ok" }))
    }
}

// MARK: - Helpers

private func message(
    id: String,
    role: HiveChatRole,
    content: String,
    toolCalls: [HiveToolCall] = [],
    toolCallID: String? = nil,
    name: String? = nil,
    op: HiveChatMessageOp? = nil
) -> HiveChatMessage {
    HiveChatMessage(
        id: id,
        role: role,
        content: content,
        name: name,
        toolCallID: toolCallID,
        toolCalls: toolCalls,
        op: op
    )
}

private func removeAllMarker() -> HiveChatMessage {
    message(
        id: HiveAgents.removeAllMessagesID,
        role: .system,
        content: "",
        toolCalls: [],
        toolCallID: nil,
        name: nil,
        op: .removeAll
    )
}

private struct MessageCountTokenizer: HiveTokenizer {
    func countTokens(_ messages: [HiveChatMessage]) -> Int { messages.count }
}

private struct StubModelClient: HiveModelClient {
    let chunks: [HiveChatStreamChunk]

    func complete(_ request: HiveChatRequest) async throws -> HiveChatResponse {
        for chunk in chunks {
            if case let .final(response) = chunk { return response }
        }
        return HiveChatResponse(message: HiveChatMessage(id: "empty", role: .assistant, content: ""))
    }

    func stream(_ request: HiveChatRequest) -> AsyncThrowingStream<HiveChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            for chunk in chunks { continuation.yield(chunk) }
            continuation.finish()
        }
    }
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

    func complete(_ request: HiveChatRequest) async throws -> HiveChatResponse {
        let chunks = await script.nextChunks()
        for chunk in chunks {
            if case let .final(response) = chunk { return response }
        }
        throw HiveRuntimeError.modelStreamInvalid("Missing final chunk.")
    }

    func stream(_ request: HiveChatRequest) -> AsyncThrowingStream<HiveChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let chunks = await script.nextChunks()
                for chunk in chunks { continuation.yield(chunk) }
                continuation.finish()
            }
        }
    }
}

private struct StubToolRegistry: HiveToolRegistry, Sendable {
    let resultContent: String
    func listTools() -> [HiveToolDefinition] { [] }
    func invoke(_ call: HiveToolCall) async throws -> HiveToolResult {
        HiveToolResult(toolCallID: call.id, content: resultContent)
    }
}

private struct NoopClock: HiveClock {
    func nowNanoseconds() -> UInt64 { 0 }
    func sleep(nanoseconds: UInt64) async throws { try await Task.sleep(nanoseconds: nanoseconds) }
}

private struct NoopLogger: HiveLogger {
    func debug(_ message: String, metadata: [String: String]) {}
    func info(_ message: String, metadata: [String: String]) {}
    func error(_ message: String, metadata: [String: String]) {}
}

private actor InMemoryCheckpointStore<Schema: HiveSchema>: HiveCheckpointStore {
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
}

private func collectEvents(_ stream: AsyncThrowingStream<HiveEvent, Error>) async -> [HiveEvent] {
    var events: [HiveEvent] = []
    do {
        for try await event in stream { events.append(event) }
    } catch {
        return events
    }
    return events
}

private func waitOutcome<Schema: HiveSchema>(
    _ handle: HiveRunHandle<Schema>
) async throws -> HiveRunOutcome<Schema> {
    try await handle.outcome.value
}

private func requireFullStore<Schema: HiveSchema>(outcome: HiveRunOutcome<Schema>) throws -> HiveGlobalStore<Schema> {
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
        throw TestFailure("Expected finished/cancelled/outOfSteps, got interrupted.")
    }
}

private func requireInterruption<Schema: HiveSchema>(outcome: HiveRunOutcome<Schema>) throws -> HiveInterruption<Schema> {
    switch outcome {
    case let .interrupted(interruption):
        return interruption
    default:
        throw TestFailure("Expected interrupted outcome.")
    }
}

private func expectedRoleBasedMessageID(taskID: String, role: String) -> String {
    var data = Data()
    data.append(contentsOf: Array("HMSG1".utf8))
    data.append(contentsOf: Array(taskID.utf8))
    data.append(0x00)
    data.append(contentsOf: Array(role.utf8))
    data.append(contentsOf: [UInt8(0), UInt8(0), UInt8(0), UInt8(0)])
    let digest = SHA256.hash(data: data)
    let hex = digest.map { String(format: "%02x", $0) }.joined()
    return "msg:" + hex
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
