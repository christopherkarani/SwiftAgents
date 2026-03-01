import CryptoKit
import Foundation
import Testing
@testable import Swarm

@Suite("HiveAgents (HiveSwarm) — HiveCore runtime")
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

        let runtime = try HiveRuntime(graph: graph, environment: environment)
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

        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let runControl = HiveAgentsRunController(runtime: runtime)

        let thrown = await #expect(throws: (any Error).self) {
            _ = try await runControl.start(
                HiveAgentsRunStartRequest(
                    threadID: HiveThreadID("t"),
                    input: "Hello",
                    options: HiveRunOptions(maxSteps: 10, checkpointPolicy: .disabled)
                )
            )
        }
        let runtimeError = try #require(thrown as? HiveRuntimeError)
        switch runtimeError {
        case .checkpointStoreMissing:
            break
        default:
            Issue.record("Expected checkpointStoreMissing, got \(runtimeError)")
        }
    }

    @Test("Model node throws modelClientMissing when neither model nor router is configured")
    func modelNode_missingModelClient_throwsTypedError() async throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()
        let context = HiveAgentsContext(modelName: "test-model", toolApprovalPolicy: .never)
        let environment = HiveEnvironment<HiveAgents.Schema>(
            context: context,
            clock: NoopClock(),
            logger: NoopLogger(),
            model: nil,
            modelRouter: nil,
            tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "ok")),
            checkpointStore: nil
        )

        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let handle = await runtime.run(
            threadID: HiveThreadID("missing-model-client"),
            input: "Hello",
            options: HiveRunOptions(maxSteps: 3, checkpointPolicy: .disabled)
        )

        let thrown = await #expect(throws: (any Error).self) {
            _ = try await handle.outcome.value
        }

        guard let runtimeError = thrown as? HiveRuntimeError else {
            Issue.record("Expected HiveRuntimeError, got \(String(describing: thrown))")
            return
        }
        switch runtimeError {
        case .modelClientMissing:
            break
        default:
            Issue.record("Expected modelClientMissing, got \(runtimeError)")
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
                [.final(HiveChatResponse(message: message(id: "m2", role: .assistant, content: "done")))],
                [.final(HiveChatResponse(message: message(
                    id: "m3",
                    role: .assistant,
                    content: "",
                    toolCalls: [HiveToolCall(id: "c2", name: "calc", argumentsJSON: "{}")]
                )))],
                [.final(HiveChatResponse(message: message(id: "m4", role: .assistant, content: "done")))]
            ]))),
            modelRouter: nil,
            tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "42")),
            checkpointStore: AnyHiveCheckpointStore(store)
        )

        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let runControl = HiveAgentsRunController(runtime: runtime)
        let startRequest = HiveAgentsRunStartRequest(
            threadID: HiveThreadID("approval-thread"),
            input: "Hello",
            options: HiveRunOptions(maxSteps: 10, checkpointPolicy: .disabled)
        )
        let handle = try await runControl.start(startRequest)
        let startEvents = await collectEvents(handle.events)
        #expect(startEvents.allSatisfy { event in event.id.runID == handle.runID })
        #expect(startEvents.allSatisfy { event in event.id.attemptID == handle.attemptID })

        let outcome = try await handle.outcome.value

        let interruption = try requireInterruption(outcome: outcome)
        switch interruption.interrupt.payload {
        case let .toolApprovalRequired(toolCalls):
            #expect(toolCalls.map(\.name) == ["calc"])
        }
        let interruptEventID = startEvents.compactMap { event -> HiveInterruptID? in
            guard case let .runInterrupted(interruptID) = event.kind else { return nil }
            return interruptID
        }.first
        #expect(interruptEventID == interruption.interrupt.id)

        let resumeHandle = try await runControl.resume(
            HiveAgentsRunResumeRequest(
                threadID: startRequest.threadID,
                interruptID: interruption.interrupt.id,
                payload: .toolApproval(decision: .approved),
                options: startRequest.options
            )
        )
        let resumeEvents = await collectEvents(resumeHandle.events)
        #expect(resumeEvents.allSatisfy { event in event.id.runID == resumeHandle.runID })
        #expect(resumeEvents.allSatisfy { event in event.id.attemptID == resumeHandle.attemptID })
        let resumed = try await resumeHandle.outcome.value

        let finalStore = try requireFullStore(outcome: resumed)
        let messages = try finalStore.get(HiveAgents.Schema.messagesKey)
        let hasToolReply = messages.contains { message in
            message.role.rawValue == "tool" &&
                message.content == "42" &&
                message.toolCallID == "c1"
        }
        #expect(hasToolReply)
    }

    @Test("Tool approval: cancelled decision skips tool execution")
    func toolApproval_cancelledDecision_skipsToolExecution() async throws {
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

        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let runControl = HiveAgentsRunController(runtime: runtime)

        let start = try await runControl.start(
            .init(
                threadID: HiveThreadID("approval-cancelled"),
                input: "Hello",
                options: HiveRunOptions(maxSteps: 10, checkpointPolicy: .disabled)
            )
        )
        let interrupted = try requireInterruption(outcome: try await start.outcome.value)

        let resumed = try await runControl.resume(
            .init(
                threadID: HiveThreadID("approval-cancelled"),
                interruptID: interrupted.interrupt.id,
                payload: .toolApproval(decision: .cancelled),
                options: HiveRunOptions(maxSteps: 10, checkpointPolicy: .disabled)
            )
        )
        let finalStore = try requireFullStore(outcome: try await resumed.outcome.value)
        let messages = try finalStore.get(HiveAgents.Schema.messagesKey)

        let hasCancellationSystem = messages.contains { message in
            message.role.rawValue == "system" && message.content == "Tool execution cancelled by user."
        }
        #expect(hasCancellationSystem)

        let hasCancelledToolMessage = messages.contains { message in
            message.role.rawValue == "tool" &&
                message.toolCallID == "c1" &&
                message.content.contains("cancelled")
        }
        #expect(hasCancelledToolMessage)

        let hasExecutedToolMessage = messages.contains { message in
            message.role.rawValue == "tool" &&
                message.toolCallID == "c1" &&
                message.content == "42"
        }
        #expect(hasExecutedToolMessage == false)
    }

    @Test("Tool approval: restart after interrupt resumes with single tool execution")
    func toolApproval_restartAfterInterrupt_executesToolOnce() async throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()
        let store = InMemoryCheckpointStore<HiveAgents.Schema>()
        let counter = ToolInvocationCounter()
        let registry = CountingToolRegistry(resultContent: "42", counter: counter)
        let script = ModelScript(chunksByInvocation: [
            [.final(HiveChatResponse(message: message(
                id: "m1",
                role: .assistant,
                content: "",
                toolCalls: [HiveToolCall(id: "c1", name: "calc", argumentsJSON: "{}")]
            )))],
            [.final(HiveChatResponse(message: message(id: "m2", role: .assistant, content: "done")))]
        ])

        let context = HiveAgentsContext(modelName: "test-model", toolApprovalPolicy: .always)
        let makeEnvironment = {
            HiveEnvironment<HiveAgents.Schema>(
                context: context,
                clock: NoopClock(),
                logger: NoopLogger(),
                model: AnyHiveModelClient(ScriptedModelClient(script: script)),
                modelRouter: nil,
                tools: AnyHiveToolRegistry(registry),
                checkpointStore: AnyHiveCheckpointStore(store)
            )
        }

        // First process run reaches interruption.
        let runtime1 = try HiveRuntime(graph: graph, environment: makeEnvironment())
        let runControl1 = HiveAgentsRunController(runtime: runtime1)
        let start = try await runControl1.start(
            .init(
                threadID: HiveThreadID("approval-restart"),
                input: "Hello",
                options: HiveRunOptions(maxSteps: 10, checkpointPolicy: .disabled)
            )
        )
        let interrupted = try requireInterruption(outcome: try await start.outcome.value)

        // Simulated process restart: new runtime/controller using same checkpoint store.
        let runtime2 = try HiveRuntime(graph: graph, environment: makeEnvironment())
        let runControl2 = HiveAgentsRunController(runtime: runtime2)
        let resumed = try await runControl2.resume(
            .init(
                threadID: HiveThreadID("approval-restart"),
                interruptID: interrupted.interrupt.id,
                payload: .toolApproval(decision: .approved),
                options: HiveRunOptions(maxSteps: 10, checkpointPolicy: .disabled)
            )
        )

        let finalStore = try requireFullStore(outcome: try await resumed.outcome.value)
        let messages = try finalStore.get(HiveAgents.Schema.messagesKey)
        let toolMessages = messages.filter { message in
            message.role.rawValue == "tool" && message.toolCallID == "c1" && message.content == "42"
        }

        #expect(toolMessages.count == 1)
        #expect(await counter.value() == 1)
    }

    @Test("Run control resume request options are passed through")
    func runControl_resumeOptions_passthrough() async throws {
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

        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let runControl = HiveAgentsRunController(runtime: runtime)
        let threadID = HiveThreadID("approval-options")

        let start = try await runControl.start(
            .init(
                threadID: threadID,
                input: "Hello",
                options: HiveRunOptions(maxSteps: 10, checkpointPolicy: .disabled)
            )
        )
        let interrupted = try requireInterruption(outcome: try await start.outcome.value)

        let resumed = try await runControl.resume(
            .init(
                threadID: threadID,
                interruptID: interrupted.interrupt.id,
                payload: .toolApproval(decision: .approved),
                options: HiveRunOptions(maxSteps: 0, checkpointPolicy: .disabled)
            )
        )
        let outcome = try await resumed.outcome.value
        guard case let .outOfSteps(maxSteps, _, _) = outcome else {
            Issue.record("Expected outOfSteps from maxSteps=0 resume override.")
            return
        }
        #expect(maxSteps == 0)
    }

    @Test("Run control validateRunOptions rejects invalid bounds")
    func runControl_validateRunOptions_rejectsInvalidBounds() throws {
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
        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let runControl = HiveAgentsRunController(runtime: runtime)

        let thrown = #expect(throws: (any Error).self) {
            try runControl.validateRunOptions(
                HiveRunOptions(maxSteps: 2, maxConcurrentTasks: 0, checkpointPolicy: .disabled)
            )
        }
        let runtimeError = try #require(thrown as? HiveRuntimeError)
        guard case .invalidRunOptions = runtimeError else {
            Issue.record("Expected invalidRunOptions, got \(runtimeError)")
            return
        }
    }

    @Test("Checkpoint capability discovery reports unavailable/latestOnly/queryable")
    func checkpointCapabilityDiscovery_reportsExpectedSupport() async throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()
        let context = HiveAgentsContext(modelName: "test-model", toolApprovalPolicy: .never)

        let noStoreEnv = HiveEnvironment<HiveAgents.Schema>(
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
        let noStoreRuntime = try HiveRuntime(graph: graph, environment: noStoreEnv)
        let noStoreRunControl = HiveAgentsRunController(runtime: noStoreRuntime)
        #expect(await noStoreRunControl.checkpointQueryCapability() == .unavailable)

        let nonQueryableStore = InMemoryCheckpointStore<HiveAgents.Schema>()
        let nonQueryableEnv = HiveEnvironment<HiveAgents.Schema>(
            context: context,
            clock: NoopClock(),
            logger: NoopLogger(),
            model: AnyHiveModelClient(StubModelClient(chunks: [
                .final(HiveChatResponse(message: message(id: "m2", role: .assistant, content: "ok")))
            ])),
            modelRouter: nil,
            tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "ok")),
            checkpointStore: AnyHiveCheckpointStore(nonQueryableStore)
        )
        let nonQueryableRuntime = try HiveRuntime(graph: graph, environment: nonQueryableEnv)
        let nonQueryableRunControl = HiveAgentsRunController(runtime: nonQueryableRuntime)
        #expect(await nonQueryableRunControl.checkpointQueryCapability() == .latestOnly)

        let queryableStore = QueryableCheckpointStore<HiveAgents.Schema>()
        let queryableEnv = HiveEnvironment<HiveAgents.Schema>(
            context: context,
            clock: NoopClock(),
            logger: NoopLogger(),
            model: AnyHiveModelClient(StubModelClient(chunks: [
                .final(HiveChatResponse(message: message(id: "m3", role: .assistant, content: "ok")))
            ])),
            modelRouter: nil,
            tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "ok")),
            checkpointStore: AnyHiveCheckpointStore(queryableStore)
        )
        let queryableRuntime = try HiveRuntime(graph: graph, environment: queryableEnv)
        let queryableRunControl = HiveAgentsRunController(runtime: queryableRuntime)
        #expect(await queryableRunControl.checkpointQueryCapability() == .queryable)
    }

    @Test("Checkpoint history query throws typed unsupported for non-queryable stores")
    func checkpointHistoryQuery_nonQueryableStore_throwsUnsupported() async throws {
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
            checkpointStore: AnyHiveCheckpointStore(InMemoryCheckpointStore<HiveAgents.Schema>())
        )
        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let runControl = HiveAgentsRunController(runtime: runtime)

        let thrown = await #expect(throws: (any Error).self) {
            _ = try await runControl.getCheckpointHistory(threadID: HiveThreadID("query-unsupported"), limit: 1)
        }
        let queryError = try #require(thrown as? HiveCheckpointQueryError)
        #expect(queryError == .unsupported)
    }

    @Test("getState returns nil for missing thread and deterministic snapshot for existing thread")
    func getState_missingAndExistingThread_behavesDeterministically() async throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()
        let context = HiveAgentsContext(modelName: "test-model", toolApprovalPolicy: .never)
        let environment = HiveEnvironment<HiveAgents.Schema>(
            context: context,
            clock: NoopClock(),
            logger: NoopLogger(),
            model: AnyHiveModelClient(StubModelClient(chunks: [
                .final(HiveChatResponse(message: message(id: "m", role: .assistant, content: "done")))
            ])),
            modelRouter: nil,
            tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "ok")),
            checkpointStore: nil
        )

        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let runControl = HiveAgentsRunController(runtime: runtime)
        #expect(try await runtime.getState(threadID: HiveThreadID("missing-thread")) == nil)
        #expect(try await runControl.getState(threadID: HiveThreadID("missing-thread")) == nil)

        let request = HiveAgentsRunStartRequest(
            threadID: HiveThreadID("state-thread"),
            input: "Hello",
            options: HiveRunOptions(maxSteps: 5, checkpointPolicy: .disabled)
        )
        let handle = try await runControl.start(request)
        _ = try await handle.outcome.value

        let runtimeSnapshot = try #require(try await runtime.getState(threadID: request.threadID))
        #expect(runtimeSnapshot.threadID == request.threadID)
        let snapshot = try #require(try await runControl.getState(threadID: request.threadID))
        #expect(snapshot.threadID == request.threadID)
        #expect(snapshot.runID == handle.runID)
        #expect(snapshot.stepIndex != nil)
        #expect(snapshot.frontier.count >= 0)
        #expect(snapshot.eventSchemaVersion == HiveAgentsEventSchemaVersion.current)
        let channelState = try #require(snapshot.channelState)
        #expect(channelState.entries.count == 5)
    }

    @Test("External writes validate schema and reject atomically")
    func externalWrites_validationAndAtomicity() async throws {
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
        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let runControl = HiveAgentsRunController(runtime: runtime)
        let threadID = HiveThreadID("external-write-thread")

        let seedMessage = message(id: "seed", role: .user, content: "seed")
        let seeded = try await runControl.applyExternalWrites(
            HiveAgentsExternalWriteRequest(
                threadID: threadID,
                writes: [AnyHiveWrite(HiveAgents.Schema.messagesKey, [seedMessage])],
                options: HiveRunOptions(maxSteps: 1, checkpointPolicy: .disabled)
            )
        )
        _ = try await seeded.outcome.value

        let unknownKey = HiveChannelKey<HiveAgents.Schema, Int>(HiveChannelID("unknown-channel"))
        let thrown = await #expect(throws: (any Error).self) {
            _ = try await runControl.applyExternalWrites(
                HiveAgentsExternalWriteRequest(
                    threadID: threadID,
                    writes: [
                        AnyHiveWrite(HiveAgents.Schema.finalAnswerKey, Optional("should-not-commit")),
                        AnyHiveWrite(unknownKey, 1)
                    ],
                    options: HiveRunOptions(maxSteps: 1, checkpointPolicy: .disabled)
                )
            )
        }
        let runtimeError = try #require(thrown as? HiveRuntimeError)
        guard case let .unknownChannelID(channelID) = runtimeError else {
            Issue.record("Expected unknownChannelID, got \(runtimeError)")
            return
        }
        #expect(channelID.rawValue == "unknown-channel")

        let store = try #require(await runtime.getLatestStore(threadID: threadID))
        let messages = try store.get(HiveAgents.Schema.messagesKey)
        let finalAnswer = try store.get(HiveAgents.Schema.finalAnswerKey)
        #expect(messages.count == 1)
        #expect(messages.first?.id == "seed")
        #expect(finalAnswer == nil)
    }

    @Test("Resume contract rejects missing interrupt and mismatch interrupt IDs")
    func resumeContract_missingAndMismatchedInterrupt_areTyped() async throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()
        let store = InMemoryCheckpointStore<HiveAgents.Schema>()

        let noInterruptContext = HiveAgentsContext(modelName: "test-model", toolApprovalPolicy: .never)
        let noInterruptEnvironment = HiveEnvironment<HiveAgents.Schema>(
            context: noInterruptContext,
            clock: NoopClock(),
            logger: NoopLogger(),
            model: AnyHiveModelClient(StubModelClient(chunks: [
                .final(HiveChatResponse(message: message(id: "m1", role: .assistant, content: "done")))
            ])),
            modelRouter: nil,
            tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "ok")),
            checkpointStore: AnyHiveCheckpointStore(store)
        )

        let noInterruptRuntime = try HiveRuntime(graph: graph, environment: noInterruptEnvironment)
        let noInterruptRunControl = HiveAgentsRunController(runtime: noInterruptRuntime)
        let noInterruptThread = HiveThreadID("resume-no-interrupt")
        let noInterruptRun = try await noInterruptRunControl.start(
            .init(
                threadID: noInterruptThread,
                input: "hello",
                options: HiveRunOptions(maxSteps: 10, checkpointPolicy: .everyStep)
            )
        )
        _ = try await noInterruptRun.outcome.value

        let noInterruptThrown = await #expect(throws: (any Error).self) {
            _ = try await noInterruptRunControl.resume(
                .init(
                    threadID: noInterruptThread,
                    interruptID: HiveInterruptID("wrong"),
                    payload: .toolApproval(decision: .approved),
                    options: HiveRunOptions(maxSteps: 5, checkpointPolicy: .everyStep)
                )
            )
        }
        let noInterruptError = try #require(noInterruptThrown as? HiveRuntimeError)
        guard case .noInterruptToResume = noInterruptError else {
            Issue.record("Expected noInterruptToResume, got \(noInterruptError)")
            return
        }

        let mismatchStore = InMemoryCheckpointStore<HiveAgents.Schema>()
        let mismatchContext = HiveAgentsContext(modelName: "test-model", toolApprovalPolicy: .always)
        let mismatchEnvironment = HiveEnvironment<HiveAgents.Schema>(
            context: mismatchContext,
            clock: NoopClock(),
            logger: NoopLogger(),
            model: AnyHiveModelClient(ScriptedModelClient(script: ModelScript(chunksByInvocation: [
                [.final(HiveChatResponse(message: message(
                    id: "mm1",
                    role: .assistant,
                    content: "",
                    toolCalls: [HiveToolCall(id: "c1", name: "calc", argumentsJSON: "{}")]
                )))]
            ]))),
            modelRouter: nil,
            tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "42")),
            checkpointStore: AnyHiveCheckpointStore(mismatchStore)
        )
        let mismatchRuntime = try HiveRuntime(graph: graph, environment: mismatchEnvironment)
        let mismatchRunControl = HiveAgentsRunController(runtime: mismatchRuntime)
        let mismatchStart = try await mismatchRunControl.start(
            .init(
                threadID: HiveThreadID("resume-mismatch"),
                input: "hello",
                options: HiveRunOptions(maxSteps: 10, checkpointPolicy: .everyStep)
            )
        )
        let interruption = try requireInterruption(outcome: try await mismatchStart.outcome.value)

        let mismatchThrown = await #expect(throws: (any Error).self) {
            _ = try await mismatchRunControl.resume(
                .init(
                    threadID: HiveThreadID("resume-mismatch"),
                    interruptID: HiveInterruptID(interruption.interrupt.id.rawValue + "-wrong"),
                    payload: .toolApproval(decision: .approved),
                    options: HiveRunOptions(maxSteps: 10, checkpointPolicy: .everyStep)
                )
            )
        }
        let mismatchError = try #require(mismatchThrown as? HiveRuntimeError)
        guard case .resumeInterruptMismatch = mismatchError else {
            Issue.record("Expected resumeInterruptMismatch, got \(mismatchError)")
            return
        }
    }

    @Test("Run events include schema version metadata")
    func runEvents_includeSchemaVersionMetadata() async throws {
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
        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let runControl = HiveAgentsRunController(runtime: runtime)

        let handle = try await runControl.start(
            .init(
                threadID: HiveThreadID("event-schema-version"),
                input: "hello",
                options: HiveRunOptions(maxSteps: 5, checkpointPolicy: .disabled)
            )
        )
        let events = await collectEvents(handle.events)
        _ = try await handle.outcome.value

        #expect(events.isEmpty == false)
        #expect(events.allSatisfy { event in
            event.metadata[HiveAgentsEventSchemaVersion.metadataKey] == HiveAgentsEventSchemaVersion.current
        })
    }

    @Test("Determinism utilities produce stable transcript/state hashes and first-diff path")
    func determinismUtilities_hashesAndFirstDiff() async throws {
        func runSeededWorkload() async throws -> (
            transcriptHash: String,
            stateHash: String,
            transcript: HiveCanonicalTranscript
        ) {
            let graph = try HiveAgents.makeToolUsingChatAgent()
            let context = HiveAgentsContext(modelName: "test-model", toolApprovalPolicy: .never)
            let environment = HiveEnvironment<HiveAgents.Schema>(
                context: context,
                clock: NoopClock(),
                logger: NoopLogger(),
                model: AnyHiveModelClient(ScriptedModelClient(script: ModelScript(chunksByInvocation: [
                    [.final(HiveChatResponse(message: message(
                        id: "d1",
                        role: .assistant,
                        content: "",
                        toolCalls: [HiveToolCall(id: "c1", name: "calc", argumentsJSON: "{}")]
                    )))],
                    [.final(HiveChatResponse(message: message(id: "d2", role: .assistant, content: "done")))]
                ]))),
                modelRouter: nil,
                tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "42")),
                checkpointStore: nil
            )
            let runtime = try HiveRuntime(graph: graph, environment: environment)
            let runControl = HiveAgentsRunController(runtime: runtime)
            let threadID = HiveThreadID("seeded-determinism-thread")

            let handle = try await runControl.start(
                .init(
                    threadID: threadID,
                    input: "hello",
                    options: HiveRunOptions(maxSteps: 10, checkpointPolicy: .disabled)
                )
            )
            let events = await collectEvents(handle.events)
            _ = try await handle.outcome.value
            let state = try #require(try await runControl.getState(threadID: threadID))
            let transcript = try HiveDeterminism.projectTranscript(events)
            return (
                transcriptHash: try HiveDeterminism.transcriptHash(events),
                stateHash: try HiveDeterminism.finalStateHash(state),
                transcript: transcript
            )
        }

        let first = try await runSeededWorkload()
        let second = try await runSeededWorkload()

        #expect(first.transcriptHash == second.transcriptHash)
        #expect(first.stateHash == second.stateHash)

        var mutatedEvents = second.transcript.events
        let firstEvent = try #require(mutatedEvents.first)
        mutatedEvents[0] = HiveCanonicalEventRecord(
            eventIndex: firstEvent.eventIndex,
            stepIndex: firstEvent.stepIndex,
            taskOrdinal: firstEvent.taskOrdinal,
            kind: firstEvent.kind + ".mutated",
            attributes: firstEvent.attributes,
            metadata: firstEvent.metadata
        )
        let mutatedTranscript = HiveCanonicalTranscript(
            schemaVersion: second.transcript.schemaVersion,
            events: mutatedEvents
        )
        let diff = HiveDeterminism.firstTranscriptDiff(expected: first.transcript, actual: mutatedTranscript)
        let firstDiff = try #require(diff)
        #expect(firstDiff.path == "events[0].kind")
    }

    @Test("Cancel/checkpoint race is classified deterministically")
    func cancelCheckpointRace_classifiesDeterministically() async throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()
        let checkpointStore = SlowCheckpointStore<HiveAgents.Schema>(saveDelayNanoseconds: 150_000_000)
        let context = HiveAgentsContext(modelName: "test-model", toolApprovalPolicy: .never)
        let environment = HiveEnvironment<HiveAgents.Schema>(
            context: context,
            clock: NoopClock(),
            logger: NoopLogger(),
            model: AnyHiveModelClient(ScriptedModelClient(script: ModelScript(chunksByInvocation: [
                [.final(HiveChatResponse(message: message(
                    id: "r1",
                    role: .assistant,
                    content: "",
                    toolCalls: [HiveToolCall(id: "race-call", name: "calc", argumentsJSON: "{}")]
                )))],
                [.final(HiveChatResponse(message: message(id: "r2", role: .assistant, content: "done")))]
            ]))),
            modelRouter: nil,
            tools: AnyHiveToolRegistry(StubToolRegistry(resultContent: "42")),
            checkpointStore: AnyHiveCheckpointStore(checkpointStore)
        )
        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let runControl = HiveAgentsRunController(runtime: runtime)
        let handle = try await runControl.start(
            .init(
                threadID: HiveThreadID("cancel-race-thread"),
                input: "hello",
                options: HiveRunOptions(maxSteps: 10, checkpointPolicy: .everyStep)
            )
        )

        let cancelTask = Task {
            await checkpointStore.waitForFirstSaveStart()
            handle.outcome.cancel()
        }

        let events = await collectEvents(handle.events)
        let outcome = try await handle.outcome.value
        _ = await cancelTask.value

        let resolution = HiveDeterminism.classifyCancelCheckpointRace(events: events, outcome: outcome)
        guard case .cancelledAfterCheckpointSaved = resolution else {
            Issue.record("Expected cancelledAfterCheckpointSaved, got \(resolution)")
            return
        }

        // Order-independence: classification should not depend on event array ordering.
        let shuffled = events.shuffled()
        let shuffledResolution = HiveDeterminism.classifyCancelCheckpointRace(events: shuffled, outcome: outcome)
        #expect(shuffledResolution == resolution)

        let checkpointIndex = events.firstIndex { event in
            if case .checkpointSaved = event.kind { return true }
            return false
        }
        let cancelledIndex = events.firstIndex { event in
            if case .runCancelled = event.kind { return true }
            return false
        }
        let firstCheckpointIndex = try #require(checkpointIndex)
        let firstCancelledIndex = try #require(cancelledIndex)
        #expect(firstCheckpointIndex < firstCancelledIndex)
    }

    @Test("HiveBackedAgent preserves ToolCall/ToolResult correlation IDs")
    func hiveBackedAgent_preservesToolCorrelationIDs() async throws {
        let graph = try HiveAgents.makeToolUsingChatAgent()
        let context = HiveAgentsContext(modelName: "test-model", toolApprovalPolicy: .never)
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
            checkpointStore: nil
        )

        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let hiveRuntime = HiveAgentsRuntime(runControl: HiveAgentsRunController(runtime: runtime))
        let agent = HiveBackedAgent(runtime: hiveRuntime, name: "bridge")

        let result = try await agent.run("hello")
        #expect(result.toolCalls.count == 1)
        #expect(result.toolResults.count == 1)
        #expect(result.toolResults.first?.callId == result.toolCalls.first?.id)
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

        let runtime = try HiveRuntime(graph: graph, environment: environment)
        let handle = await runtime.run(
            threadID: HiveThreadID("id-thread"),
            input: "Hello",
            options: HiveRunOptions(maxSteps: 2, checkpointPolicy: .disabled)
        )

        let events = await collectEvents(handle.events)
        let outcome = try await handle.outcome.value
        let store = try requireFullStore(outcome: outcome)

        let modelTaskIDs: [HiveTaskID] = events.compactMap { event -> HiveTaskID? in
            guard case let .taskStarted(node, taskID) = event.kind else { return nil }
            return node == HiveNodeID("model") ? taskID : nil
        }
        let modelTaskID = try #require(modelTaskIDs.first)

        let expectedID = expectedRoleBasedMessageID(taskID: modelTaskID.rawValue, role: "assistant")
        let messages = try store.get(HiveAgents.Schema.messagesKey)
        let hasExpectedAssistantMessage = messages.contains { message in
            message.id == expectedID &&
                message.role.rawValue == "assistant" &&
                message.content == "ok"
        }
        #expect(hasExpectedAssistantMessage)
    }

    @Test("SwarmToolRegistry throws duplicateToolName when given duplicate tools")
    func swarmToolRegistry_rejectsDuplicateToolNames() throws {
        let duplicateTools = [
            DuplicateTestTool(name: "calc"),
            DuplicateTestTool(name: "calc")
        ]

        let thrown = try? SwarmToolRegistry(tools: duplicateTools)
        #expect(thrown == nil)

        do {
            _ = try SwarmToolRegistry(tools: duplicateTools)
            Issue.record("Expected to throw duplicateToolName error")
        } catch let error as SwarmToolRegistryError {
            #expect(error == .duplicateToolName("calc"))
        }
    }

    @Test("SwarmToolRegistry invoke throws toolNotFound for unknown tool")
    func swarmToolRegistry_invokeUnknownTool() async throws {
        let registry = try SwarmToolRegistry(tools: [DuplicateTestTool(name: "calc")])

        do {
            _ = try await registry.invoke(
                HiveToolCall(id: "call-1", name: "missing", argumentsJSON: "{}")
            )
            Issue.record("Expected to throw toolNotFound.")
        } catch let error as SwarmToolRegistryError {
            #expect(error == .toolNotFound(name: "missing"))
        }
    }

    @Test("SwarmToolRegistry invoke throws invalidArgumentsJSON for malformed arguments")
    func swarmToolRegistry_invokeInvalidArgumentsJSON() async throws {
        let registry = try SwarmToolRegistry(tools: [DuplicateTestTool(name: "calc")])

        do {
            _ = try await registry.invoke(
                HiveToolCall(id: "call-2", name: "calc", argumentsJSON: "not-json")
            )
            Issue.record("Expected to throw invalidArgumentsJSON.")
        } catch let error as SwarmToolRegistryError {
            #expect(error == .invalidArgumentsJSON)
        }
    }

    @Test("SwarmToolRegistry invoke returns tool result on success")
    func swarmToolRegistry_invokeReturnsToolResult() async throws {
        let registry = try SwarmToolRegistry(tools: [DuplicateTestTool(name: "calc")])
        let result = try await registry.invoke(
            HiveToolCall(id: "call-3", name: "calc", argumentsJSON: "{}")
        )

        #expect(result.toolCallID == "call-3")
        #expect(result.content == "result")
    }

    @Test("SwarmToolRegistry invoke preserves cancellation errors")
    func swarmToolRegistry_invokePreservesCancellation() async throws {
        let registry = try SwarmToolRegistry(tools: [CancellableTestTool(name: "cancelled-tool")])

        do {
            _ = try await registry.invoke(
                HiveToolCall(id: "call-4", name: "cancelled-tool", argumentsJSON: "{}")
            )
            Issue.record("Expected CancellationError.")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Expected CancellationError, got \(error).")
        }
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

private actor ModelInvocationRecorder {
    private var requests: [HiveChatRequest] = []
    private var chunksByInvocation: [[HiveChatStreamChunk]]

    init(chunksByInvocation: [[HiveChatStreamChunk]]) {
        self.chunksByInvocation = chunksByInvocation
    }

    func record(_ request: HiveChatRequest) {
        requests.append(request)
    }

    func firstRequest() -> HiveChatRequest? {
        requests.first
    }

    func nextChunks() -> [HiveChatStreamChunk] {
        guard chunksByInvocation.isEmpty == false else {
            return [.final(HiveChatResponse(message: message(id: "fallback", role: .assistant, content: "ok")))]
        }
        return chunksByInvocation.removeFirst()
    }
}

private struct CapturingModelClient: HiveModelClient {
    let recorder: ModelInvocationRecorder

    func complete(_ request: HiveChatRequest) async throws -> HiveChatResponse {
        await recorder.record(request)
        let chunks = await recorder.nextChunks()
        for chunk in chunks {
            if case let .final(response) = chunk {
                return response
            }
        }
        throw HiveRuntimeError.modelStreamInvalid("Missing final chunk.")
    }

    func stream(_ request: HiveChatRequest) -> AsyncThrowingStream<HiveChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await recorder.record(request)
                let chunks = await recorder.nextChunks()
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }
}

private actor ToolInvocationCounter {
    private var count = 0

    func increment() {
        count += 1
    }

    func value() -> Int {
        count
    }
}

private struct CountingToolRegistry: HiveToolRegistry, Sendable {
    let resultContent: String
    let counter: ToolInvocationCounter

    func listTools() -> [HiveToolDefinition] { [] }

    func invoke(_ call: HiveToolCall) async throws -> HiveToolResult {
        await counter.increment()
        return HiveToolResult(toolCallID: call.id, content: resultContent)
    }
}

private struct StubToolRegistry: HiveToolRegistry, Sendable {
    let resultContent: String
    func listTools() -> [HiveToolDefinition] { [] }
    func invoke(_ call: HiveToolCall) async throws -> HiveToolResult {
        HiveToolResult(toolCallID: call.id, content: resultContent)
    }
}

private struct ListingToolRegistry: HiveToolRegistry, Sendable {
    let definitions: [HiveToolDefinition]
    let resultContent: String

    func listTools() -> [HiveToolDefinition] {
        definitions
    }

    func invoke(_ call: HiveToolCall) async throws -> HiveToolResult {
        HiveToolResult(toolCallID: call.id, content: resultContent)
    }
}

private struct InjectingPreModelHook: HiveAgentsPreModelHook {
    func transform(
        messages: [HiveChatMessage],
        systemPrompt _: String,
        context _: HiveAgentsContext
    ) async -> (messages: [HiveChatMessage], systemPrompt: String) {
        var modified = messages
        modified.append(message(id: "hook-user", role: .user, content: "Hook-injected user context"))
        return (modified, "Injected system prompt")
    }
}

private struct PrefixMessageIDFactory: HiveAgentsMessageIDFactory {
    func messageID(for role: String, taskID: HiveTaskID, stepIndex: Int) -> String {
        "custom-\(role)-\(taskID.rawValue)-\(stepIndex)"
    }
}

private struct PrefixToolResultTransformer: HiveAgentsToolResultTransformer {
    func transform(result: String, toolName: String, tokenEstimate _: Int) async -> String {
        "transformed:\(toolName):\(result)"
    }
}

private func makeToolDefinition(name: String) -> HiveToolDefinition {
    HiveToolDefinition(
        name: name,
        description: "\(name) description",
        parametersJSONSchema: #"{"type":"object"}"#
    )
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
        let all = checkpoints
            .filter { $0.threadID == threadID }
            .sorted { lhs, rhs in
                if lhs.stepIndex == rhs.stepIndex { return lhs.id.rawValue < rhs.id.rawValue }
                return lhs.stepIndex < rhs.stepIndex
            }
            .map { checkpoint in
                HiveCheckpointSummary(
                    id: checkpoint.id,
                    threadID: checkpoint.threadID,
                    runID: checkpoint.runID,
                    stepIndex: checkpoint.stepIndex,
                    schemaVersion: checkpoint.schemaVersion,
                    graphVersion: checkpoint.graphVersion,
                    createdAt: nil,
                    backendID: nil
                )
            }
        if let limit, limit >= 0 {
            return Array(all.suffix(limit))
        }
        return all
    }

    func loadCheckpoint(threadID: HiveThreadID, id: HiveCheckpointID) async throws -> HiveCheckpoint<Schema>? {
        checkpoints.first { checkpoint in
            checkpoint.threadID == threadID && checkpoint.id == id
        }
    }
}

private actor SlowCheckpointStore<Schema: HiveSchema>: HiveCheckpointStore {
    private var checkpoints: [HiveCheckpoint<Schema>] = []
    private let saveDelayNanoseconds: UInt64
    private var didSignalStart = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(saveDelayNanoseconds: UInt64) {
        self.saveDelayNanoseconds = saveDelayNanoseconds
    }

    func save(_ checkpoint: HiveCheckpoint<Schema>) async throws {
        if didSignalStart == false {
            didSignalStart = true
            let localWaiters = waiters
            waiters.removeAll()
            for waiter in localWaiters {
                waiter.resume()
            }
        }
        do {
            try await Task.sleep(nanoseconds: saveDelayNanoseconds)
        } catch {
            // Keep persistence deterministic even when cancellation overlaps save.
        }
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

    func waitForFirstSaveStart() async {
        if didSignalStart {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
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

private struct DuplicateTestTool: AnyJSONTool {
    let name: String
    let description: String = "Test tool"

    var parameters: [ToolParameter] { [] }

    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        .string("result")
    }
}

private struct CancellableTestTool: AnyJSONTool {
    let name: String
    let description: String = "Cancellation test tool"

    var parameters: [ToolParameter] { [] }

    func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        throw CancellationError()
    }
}
