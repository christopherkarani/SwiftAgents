import CryptoKit
import Foundation
import HiveCore
import Swarm

public enum HiveAgentsToolApprovalPolicy: Sendable, Equatable {
    case never
    case always
    case allowList(Set<String>)
}

public enum HiveAgents {
    public static let removeAllMessagesID = "__remove_all__"

    public enum ToolApprovalDecision: String, Codable, Sendable, Equatable {
        case approved
        case rejected
        case cancelled
    }

    public enum Interrupt: Codable, Sendable {
        case toolApprovalRequired(toolCalls: [HiveToolCall])
    }

    public enum Resume: Codable, Sendable {
        case toolApproval(decision: ToolApprovalDecision)
    }

    /// Builds a compiled Hive graph for a tool-using chat agent.
    ///
    /// The graph implements a model→tools loop: the model generates tool calls, tools execute,
    /// results are added to the message history, and the cycle repeats until no more tool calls.
    ///
    /// - Parameters:
    ///   - preModel: Optional node that runs before each model invocation. Receives input with
    ///     `messagesKey` (the conversation history) and should produce `llmInputMessagesKey`
    ///     (the messages actually sent to the model). Use for compaction, context selection, or
    ///     injecting system prompts. If nil, a default preModel handles compaction.
    ///   - postModel: Optional node that runs after each model invocation (before routing).
    ///     Receives the same input as preModel plus any tool results. Can be used for
    ///     guardrails, response filtering, or custom routing logic.
    /// - Returns: A compiled Hive graph ready for execution.
    public static func makeToolUsingChatAgent(
        context: HiveAgentsContext? = nil,
        preModel: HiveNode<Schema>? = nil,
        postModel: HiveNode<Schema>? = nil
    ) throws -> CompiledHiveGraph<Schema> {
        let nodeIDs = NodeID.all
        let modelCachePolicy: HiveCachePolicy<Schema>?
        let compactionCachePolicy: HiveCachePolicy<Schema>?
        if let context {
            modelCachePolicy = context.modelNodeCachePolicy
            compactionCachePolicy = context.compactionCachePolicy
        } else {
            modelCachePolicy = HiveAgentsContext.defaultModelNodeCachePolicy
            compactionCachePolicy = HiveAgentsContext.defaultCompactionCachePolicy
        }

        var builder = HiveGraphBuilder<Schema>(start: [nodeIDs.preModel])
        builder.addNode(
            nodeIDs.preModel,
            options: .deferred,
            cachePolicy: compactionCachePolicy,
            preModel ?? Self.builtInPreModel()
        )
        builder.addNode(nodeIDs.model, cachePolicy: modelCachePolicy, Self.modelNode())
        builder.addNode(nodeIDs.tools, Self.toolsNode())
        builder.addNode(nodeIDs.toolExecute, Self.toolExecuteNode())

        builder.addEdge(from: nodeIDs.preModel, to: nodeIDs.model)
        builder.addEdge(from: nodeIDs.tools, to: nodeIDs.toolExecute)
        builder.addEdge(from: nodeIDs.toolExecute, to: nodeIDs.model)

        let router: HiveRouter<Schema> = { store in
            do {
                let pending = try store.get(Schema.pendingToolCallsKey)
                return pending.isEmpty ? .end : .nodes([nodeIDs.tools])
            } catch {
                Log.agents.error("Router failed to read pendingToolCallsKey, ending graph: \(error)")
                return .end
            }
        }

        if let postModel {
            builder.addNode(nodeIDs.postModel, postModel)
            builder.addEdge(from: nodeIDs.model, to: nodeIDs.postModel)
            builder.addRouter(from: nodeIDs.postModel, router)
        } else {
            builder.addRouter(from: nodeIDs.model, router)
        }

        return try builder.compile()
    }
}

public protocol HiveTokenizer: Sendable {
    func countTokens(_ messages: [HiveChatMessage]) -> Int
}

public struct HiveCompactionPolicy: Sendable {
    public let maxTokens: Int
    public let preserveLastMessages: Int

    public init(maxTokens: Int, preserveLastMessages: Int) {
        if maxTokens < 1 {
            Log.agents.warning("HiveCompactionPolicy: maxTokens must be >= 1, got \(maxTokens). Clamping to 1.")
        }
        if preserveLastMessages < 0 {
            Log.agents.warning("HiveCompactionPolicy: preserveLastMessages must be >= 0, got \(preserveLastMessages). Clamping to 0.")
        }
        self.maxTokens = max(1, maxTokens)
        self.preserveLastMessages = max(0, preserveLastMessages)
    }
}

public struct HiveToolCircuitBreakerPolicy: Sendable, Equatable {
    public let failureThreshold: Int
    public let cooldownSteps: Int

    public init(failureThreshold: Int = 3, cooldownSteps: Int = 2) {
        self.failureThreshold = max(1, failureThreshold)
        self.cooldownSteps = max(1, cooldownSteps)
    }
}

public struct HiveAgentsContext: Sendable {
    public static var defaultModelNodeCachePolicy: HiveCachePolicy<HiveAgents.Schema>? {
        .lru(maxEntries: 64)
    }

    public static var defaultCompactionCachePolicy: HiveCachePolicy<HiveAgents.Schema>? {
        .channels(HiveChannelID("messages"), maxEntries: 32)
    }

    public let modelName: String
    public let toolApprovalPolicy: HiveAgentsToolApprovalPolicy
    public let compactionPolicy: HiveCompactionPolicy?
    public let tokenizer: (any HiveTokenizer)?
    public let retryPolicy: HiveRetryPolicy?
    public let modelRetryPolicy: HiveRetryPolicy?
    public let toolRetryPolicy: HiveRetryPolicy?
    public let toolCircuitBreakerPolicy: HiveToolCircuitBreakerPolicy?
    public let modelNodeCachePolicy: HiveCachePolicy<HiveAgents.Schema>?
    public let compactionCachePolicy: HiveCachePolicy<HiveAgents.Schema>?
    public let maxForkRetries: Int

    public init(
        modelName: String,
        toolApprovalPolicy: HiveAgentsToolApprovalPolicy,
        compactionPolicy: HiveCompactionPolicy? = nil,
        tokenizer: (any HiveTokenizer)? = nil,
        retryPolicy: HiveRetryPolicy? = nil,
        modelRetryPolicy: HiveRetryPolicy? = nil,
        toolRetryPolicy: HiveRetryPolicy? = nil,
        toolCircuitBreakerPolicy: HiveToolCircuitBreakerPolicy? = nil,
        modelNodeCachePolicy: HiveCachePolicy<HiveAgents.Schema>? = HiveAgentsContext.defaultModelNodeCachePolicy,
        compactionCachePolicy: HiveCachePolicy<HiveAgents.Schema>? = HiveAgentsContext.defaultCompactionCachePolicy,
        maxForkRetries: Int = 2
    ) {
        self.modelName = modelName
        self.toolApprovalPolicy = toolApprovalPolicy
        self.compactionPolicy = compactionPolicy
        self.tokenizer = tokenizer
        self.retryPolicy = retryPolicy
        self.modelRetryPolicy = modelRetryPolicy
        self.toolRetryPolicy = toolRetryPolicy
        self.toolCircuitBreakerPolicy = toolCircuitBreakerPolicy
        self.modelNodeCachePolicy = modelNodeCachePolicy
        self.compactionCachePolicy = compactionCachePolicy
        self.maxForkRetries = max(0, maxForkRetries)
    }
}

public struct HiveAgentsRuntime: Sendable {
    public let runControl: HiveAgentsRunController

    public init(runControl: HiveAgentsRunController) {
        self.runControl = runControl
    }

    /// Constructs a runtime from graph + environment dependencies.
    ///
    /// This initializer centralizes `HiveEnvironment` creation so checkpoint-store
    /// wiring lives with runtime construction (not adapter call sites).
    public init(
        graph: CompiledHiveGraph<HiveAgents.Schema>,
        context: HiveAgentsContext,
        clock: any HiveClock,
        logger: any HiveLogger,
        model: AnyHiveModelClient? = nil,
        modelRouter: (any HiveModelRouter)? = nil,
        inferenceHints: HiveInferenceHints? = nil,
        tools: AnyHiveToolRegistry? = nil,
        checkpointStore: AnyHiveCheckpointStore<HiveAgents.Schema>? = nil
    ) throws {
        let environment = HiveEnvironment<HiveAgents.Schema>(
            context: context,
            clock: clock,
            logger: logger,
            model: model,
            modelRouter: modelRouter,
            inferenceHints: inferenceHints,
            tools: tools,
            checkpointStore: checkpointStore
        )
        let runtime = try HiveRuntime(graph: graph, environment: environment)
        runControl = HiveAgentsRunController(runtime: runtime)
    }
}

public struct HiveAgentsRunStartRequest: Sendable {
    public var threadID: HiveThreadID
    public var input: String
    public var options: HiveRunOptions

    public init(threadID: HiveThreadID, input: String, options: HiveRunOptions) {
        self.threadID = threadID
        self.input = input
        self.options = options
    }
}

public struct HiveAgentsRunResumeRequest: Sendable {
    public var threadID: HiveThreadID
    public var interruptID: HiveInterruptID
    public var payload: HiveAgents.Resume
    public var options: HiveRunOptions

    public init(
        threadID: HiveThreadID,
        interruptID: HiveInterruptID,
        payload: HiveAgents.Resume,
        options: HiveRunOptions
    ) {
        self.threadID = threadID
        self.interruptID = interruptID
        self.payload = payload
        self.options = options
    }
}

public struct HiveAgentsRunController: Sendable {
    public let runtime: HiveRuntime<HiveAgents.Schema>

    public init(
        runtime: HiveRuntime<HiveAgents.Schema>
    ) {
        self.runtime = runtime
    }

    public func start(_ request: HiveAgentsRunStartRequest) async throws -> HiveRunHandle<HiveAgents.Schema> {
        try Self.preflight(environment: runtime.environmentSnapshot)
        return await runtime.run(
            threadID: request.threadID,
            input: request.input,
            options: request.options
        )
    }

    public func resume(_ request: HiveAgentsRunResumeRequest) async throws -> HiveRunHandle<HiveAgents.Schema> {
        try Self.preflight(environment: runtime.environmentSnapshot)
        return await runtime.resume(
            threadID: request.threadID,
            interruptID: request.interruptID,
            payload: request.payload,
            options: request.options
        )
    }

    private static func preflight(environment: HiveEnvironment<HiveAgents.Schema>) throws {
        if environment.modelRouter == nil, environment.model == nil {
            throw HiveRuntimeError.modelClientMissing
        }
        if environment.tools == nil {
            throw HiveRuntimeError.toolRegistryMissing
        }
        if environment.context.toolApprovalPolicy != .never, environment.checkpointStore == nil {
            throw HiveRuntimeError.checkpointStoreMissing
        }
        if let policy = environment.context.compactionPolicy {
            guard environment.context.tokenizer != nil else {
                throw HiveRuntimeError.invalidRunOptions("Compaction policy requires a tokenizer.")
            }
            if policy.maxTokens < 1 || policy.preserveLastMessages < 0 {
                throw HiveRuntimeError.invalidRunOptions("Invalid compaction policy bounds.")
            }
        }
    }
}

public extension HiveAgents {
    struct Schema: HiveSchema {
        public typealias Context = HiveAgentsContext
        public typealias Input = String
        public typealias InterruptPayload = HiveAgents.Interrupt
        public typealias ResumePayload = HiveAgents.Resume

        public static let messagesKey = HiveChannelKey<Self, [HiveChatMessage]>(HiveChannelID("messages"))
        public static let pendingToolCallsKey = HiveChannelKey<Self, [HiveToolCall]>(HiveChannelID("pendingToolCalls"))
        public static let finalAnswerKey = HiveChannelKey<Self, String?>(HiveChannelID("finalAnswer"))
        public static let llmInputMessagesKey = HiveChannelKey<Self, [HiveChatMessage]?>(HiveChannelID("llmInputMessages"))
        public static let tokenCountKey = HiveChannelKey<Self, Int>(HiveChannelID("tokenCount"))
        public static let toolFailureStreakKey = HiveChannelKey<Self, Int>(HiveChannelID("toolFailureStreak"))
        public static let toolCircuitOpenedAtStepKey = HiveChannelKey<Self, Int?>(HiveChannelID("toolCircuitOpenedAtStep"))

        public static var channelSpecs: [AnyHiveChannelSpec<Self>] {
            [
                AnyHiveChannelSpec(
                    HiveChannelSpec(
                        key: messagesKey,
                        scope: .global,
                        reducer: HiveReducer(MessagesReducer.reduce),
                        updatePolicy: .multi,
                        initial: { [] },
                        codec: HiveAnyCodec(HiveCodableJSONCodec<[HiveChatMessage]>()),
                        persistence: .checkpointed
                    )
                ),
                AnyHiveChannelSpec(
                    HiveChannelSpec(
                        key: pendingToolCallsKey,
                        scope: .global,
                        reducer: .lastWriteWins(),
                        updatePolicy: .single,
                        initial: { [] },
                        codec: HiveAnyCodec(HiveCodableJSONCodec<[HiveToolCall]>()),
                        persistence: .checkpointed
                    )
                ),
                AnyHiveChannelSpec(
                    HiveChannelSpec(
                        key: finalAnswerKey,
                        scope: .global,
                        reducer: .lastWriteWins(),
                        updatePolicy: .single,
                        initial: { Optional<String>.none },
                        codec: HiveAnyCodec(HiveCodableJSONCodec<String?>()),
                        persistence: .checkpointed
                    )
                ),
                AnyHiveChannelSpec(
                    HiveChannelSpec(
                        key: llmInputMessagesKey,
                        scope: .global,
                        reducer: .lastWriteWins(),
                        updatePolicy: .single,
                        initial: { Optional<[HiveChatMessage]>.none },
                        codec: HiveAnyCodec(HiveCodableJSONCodec<[HiveChatMessage]?>()),
                        persistence: .ephemeral // ephemeral: auto-resets after commit
                    )
                ),
                AnyHiveChannelSpec(
                    HiveChannelSpec(
                        key: tokenCountKey,
                        scope: .global,
                        reducer: .sum(),
                        updatePolicy: .multi,
                        initial: { 0 },
                        codec: HiveAnyCodec(HiveCodableJSONCodec<Int>()),
                        persistence: .untracked
                    )
                ),
                AnyHiveChannelSpec(
                    HiveChannelSpec(
                        key: toolFailureStreakKey,
                        scope: .global,
                        reducer: .lastWriteWins(),
                        updatePolicy: .single,
                        initial: { 0 },
                        codec: HiveAnyCodec(HiveCodableJSONCodec<Int>()),
                        persistence: .checkpointed
                    )
                ),
                AnyHiveChannelSpec(
                    HiveChannelSpec(
                        key: toolCircuitOpenedAtStepKey,
                        scope: .global,
                        reducer: .lastWriteWins(),
                        updatePolicy: .single,
                        initial: { Optional<Int>.none },
                        codec: HiveAnyCodec(HiveCodableJSONCodec<Int?>()),
                        persistence: .checkpointed
                    )
                )
            ]
        }

        public static func inputWrites(
            _ input: String,
            inputContext: HiveInputContext
        ) throws -> [AnyHiveWrite<Self>] {
            let messageID = try MessageID.user(runID: inputContext.runID, stepIndex: inputContext.stepIndex)
            let message = HiveChatMessage(
                id: messageID,
                role: .user,
                content: input,
                toolCalls: [],
                op: nil
            )
            return [
                AnyHiveWrite(messagesKey, [message]),
                AnyHiveWrite(finalAnswerKey, Optional<String>.none),
                AnyHiveWrite(tokenCountKey, 0)
            ]
        }
    }
}

extension HiveAgents {
    enum NodeID {
        static let preModel = HiveNodeID("preModel")
        static let model = HiveNodeID("model")
        static let tools = HiveNodeID("tools")
        static let toolExecute = HiveNodeID("toolExecute")
        static let postModel = HiveNodeID("postModel")
        static let all = NodeIDContainer(
            preModel: preModel,
            model: model,
            tools: tools,
            toolExecute: toolExecute,
            postModel: postModel
        )
    }

    struct NodeIDContainer {
        let preModel: HiveNodeID
        let model: HiveNodeID
        let tools: HiveNodeID
        let toolExecute: HiveNodeID
        let postModel: HiveNodeID
    }

    enum MessagesReducer {
        static func reduce(current: [HiveChatMessage], update: [HiveChatMessage]) throws -> [HiveChatMessage] {
            var merged = current
            var updates = update

            if updates.contains(where: { message in
                if case .some(.removeAll) = message.op {
                    return message.id != HiveAgents.removeAllMessagesID
                }
                return false
            }) {
                throw HiveRuntimeError.invalidMessagesUpdate
            }

            if let lastRemoveAllIndex = updates.lastIndex(where: { message in
                if case .some(.removeAll) = message.op { return true }
                return false
            }) {
                merged = []
                if lastRemoveAllIndex + 1 < updates.count {
                    updates = Array(updates[(lastRemoveAllIndex + 1)...])
                } else {
                    updates = []
                }
            }

            var indexByID: [String: Int] = [:]
            for (index, message) in merged.enumerated() where indexByID[message.id] == nil {
                indexByID[message.id] = index
            }

            var deleted = Set<String>()

            for message in updates {
                switch message.op {
                case .removeAll:
                    continue
                case .remove:
                    guard indexByID[message.id] != nil else {
                        throw HiveRuntimeError.invalidMessagesUpdate
                    }
                    deleted.insert(message.id)
                case nil:
                    if let index = indexByID[message.id] {
                        merged[index] = message
                        deleted.remove(message.id)
                    } else {
                        merged.append(message)
                        indexByID[message.id] = merged.count - 1
                    }
                }
            }

            if !deleted.isEmpty {
                merged.removeAll { deleted.contains($0.id) }
            }

            return merged.map { message in
                let cleaned = HiveChatMessage(
                    id: message.id,
                    role: message.role,
                    content: message.content,
                    name: message.name,
                    toolCallID: message.toolCallID,
                    toolCalls: message.toolCalls,
                    op: nil
                )
                return cleaned
            }
        }
    }

    enum MessageID {
        static func user(runID: HiveRunID, stepIndex: Int) throws -> String {
            guard let stepIndexValue = UInt32(exactly: stepIndex) else {
                throw HiveRuntimeError.invalidRunOptions("Invalid stepIndex.")
            }
            var data = Data()
            data.append(contentsOf: Array("HMSG1".utf8))
            data.append(contentsOf: runID.rawValue.bytes)
            data.append(contentsOf: stepIndexValue.bigEndianBytes)
            data.append(contentsOf: Array("user".utf8))
            data.append(contentsOf: UInt32(0).bigEndianBytes)
            return "msg:" + sha256HexLower(data)
        }

        static func assistant(taskID: HiveTaskID) -> String {
            roleBased(taskID: taskID, role: "assistant")
        }

        static func system(taskID: HiveTaskID) -> String {
            roleBased(taskID: taskID, role: "system")
        }

        private static func roleBased(taskID: HiveTaskID, role: String) -> String {
            var data = Data()
            data.append(contentsOf: Array("HMSG1".utf8))
            data.append(contentsOf: Array(taskID.rawValue.utf8))
            data.append(0x00)
            data.append(contentsOf: Array(role.utf8))
            data.append(contentsOf: UInt32(0).bigEndianBytes)
            return "msg:" + sha256HexLower(data)
        }

        private static func sha256HexLower(_ data: Data) -> String {
            let digest = SHA256.hash(data: data)
            return digest.map { String(format: "%02x", $0) }.joined()
        }
    }

    private static func builtInPreModel() -> HiveNode<Schema> {
        { input in
            let messages = try input.store.get(Schema.messagesKey)
            let accumulatedTokenCount = try input.store.get(Schema.tokenCountKey)
            input.emitStream(
                .customDebug(name: "swarm.cache.preModel.miss"),
                ["cacheKey": cacheSignature(for: messages)]
            )

            guard let policy = input.context.compactionPolicy else {
                return HiveNodeOutput(next: .useGraphEdges)
            }

            guard policy.maxTokens >= 1, policy.preserveLastMessages >= 0 else {
                throw HiveRuntimeError.invalidRunOptions("Invalid compaction policy bounds.")
            }

            guard let tokenizer = input.context.tokenizer else {
                throw HiveRuntimeError.invalidRunOptions("Compaction policy requires a tokenizer.")
            }

            let tokenCount: Int
            var writes: [AnyHiveWrite<Schema>] = []
            if accumulatedTokenCount == 0, !messages.isEmpty {
                let recomputed = tokenizer.countTokens(messages)
                tokenCount = recomputed
                writes.append(AnyHiveWrite(Schema.tokenCountKey, recomputed))
            } else {
                tokenCount = accumulatedTokenCount
            }

            if tokenCount <= policy.maxTokens {
                if writes.isEmpty {
                    return HiveNodeOutput(next: .useGraphEdges)
                }
                return HiveNodeOutput(writes: writes)
            }

            let trimmed = compactMessages(
                history: messages,
                policy: policy,
                tokenizer: tokenizer
            )

            writes.append(AnyHiveWrite(Schema.llmInputMessagesKey, Optional(trimmed)))
            return HiveNodeOutput(writes: writes)
        }
    }

    private static func modelNode() -> HiveNode<Schema> {
        { input in
            let messages = try input.store.get(Schema.messagesKey)
            let llmInputMessages = try input.store.get(Schema.llmInputMessagesKey)
            let inputMessages = llmInputMessages ?? messages
            input.emitStream(
                .customDebug(name: "swarm.cache.model.miss"),
                ["cacheKey": cacheSignature(for: inputMessages)]
            )
            guard let registry = input.environment.tools else {
                throw HiveRuntimeError.toolRegistryMissing
            }
            let sortedTools = registry.listTools().sorted(by: Self.toolDefinitionSort)

            let request = HiveChatRequest(
                model: input.context.modelName,
                messages: inputMessages,
                tools: sortedTools
            )

            let client: AnyHiveModelClient
            if let router = input.environment.modelRouter {
                client = router.route(request, hints: input.environment.inferenceHints)
            } else if let model = input.environment.model {
                client = model
            } else {
                throw HiveRuntimeError.modelClientMissing
            }

            // Wrap model invocation in retry if configured.
            let assistantMessage: HiveChatMessage = try await withRetry(
                policy: input.context.modelRetryPolicy ?? input.context.retryPolicy,
                clock: input.environment.clock
            ) {
                input.emitStream(.modelInvocationStarted(model: request.model), [:])

                var resultMessage: HiveChatMessage?
                var sawFinal = false

                for try await chunk in client.stream(request) {
                    if sawFinal {
                        throw HiveRuntimeError.modelStreamInvalid("Received token after final.")
                    }
                    switch chunk {
                    case let .token(text):
                        input.emitStream(.modelToken(text: text), [:])
                    case let .final(response):
                        if resultMessage != nil {
                            throw HiveRuntimeError.modelStreamInvalid("Received multiple final chunks.")
                        }
                        resultMessage = response.message
                        sawFinal = true
                    }
                }

                guard sawFinal, let resultMessage else {
                    throw HiveRuntimeError.modelStreamInvalid("Missing final chunk.")
                }

                input.emitStream(.modelInvocationFinished, [:])
                return resultMessage
            }

            let deterministicID = MessageID.assistant(taskID: input.run.taskID)
            let deterministicAssistant = HiveChatMessage(
                id: deterministicID,
                role: assistantMessage.role,
                content: assistantMessage.content,
                name: assistantMessage.name,
                toolCallID: assistantMessage.toolCallID,
                toolCalls: assistantMessage.toolCalls,
                op: assistantMessage.op
            )

            var writes: [AnyHiveWrite<Schema>] = [
                AnyHiveWrite(Schema.messagesKey, [deterministicAssistant]),
                AnyHiveWrite(Schema.pendingToolCallsKey, deterministicAssistant.toolCalls)
            ]
            if let delta = tokenDeltaForMessages([deterministicAssistant], tokenizer: input.context.tokenizer) {
                writes.append(AnyHiveWrite(Schema.tokenCountKey, delta))
            }

            if deterministicAssistant.toolCalls.isEmpty {
                writes.append(AnyHiveWrite(Schema.finalAnswerKey, Optional(deterministicAssistant.content)))
            }

            return HiveNodeOutput(writes: writes)
        }
    }

    private static func toolsNode() -> HiveNode<Schema> {
        { input in
            let pending = try input.store.get(Schema.pendingToolCallsKey)
            let calls = pending.sorted(by: HiveDeterministicSort.toolCalls)

            let approvalRequired: Bool
            switch input.context.toolApprovalPolicy {
            case .never:
                approvalRequired = false
            case .always:
                approvalRequired = true
            case let .allowList(allowed):
                approvalRequired = calls.contains { !allowed.contains($0.name) }
            }

            if approvalRequired {
                // Defense-in-depth: toolsNode handles approval flow, but if graph edges
                // are reconfigured, this ensures rejected/cancelled decisions are honored.
                if let resume = input.run.resume?.payload {
                    switch resume {
                    case let .toolApproval(decision):
                        if decision == .rejected {
                            return rejectedOutput(
                                taskID: input.run.taskID,
                                calls: calls,
                                tokenizer: input.context.tokenizer
                            )
                        }
                        if decision == .cancelled {
                            return cancelledOutput(
                                taskID: input.run.taskID,
                                calls: calls,
                                tokenizer: input.context.tokenizer
                            )
                        }
                    }
                } else {
                    return HiveNodeOutput(
                        interrupt: HiveInterruptRequest(payload: .toolApprovalRequired(toolCalls: calls))
                    )
                }
            }
            return HiveNodeOutput(next: .useGraphEdges)
        }
    }

    private static func makeApprovalOutput(
        taskID: HiveTaskID,
        calls _: [HiveToolCall],
        tokenizer: (any HiveTokenizer)?
    ) -> HiveNodeOutput<Schema> {
        let sysMsg = HiveChatMessage(
            id: MessageID.system(taskID: taskID),
            role: .system,
            content: systemMessage,
            toolCalls: [],
            op: nil
        )

        var writes: [AnyHiveWrite<Schema>] = [
            AnyHiveWrite(Schema.pendingToolCallsKey, []),
            AnyHiveWrite(Schema.messagesKey, [systemMessage])
        ]
        if let delta = tokenDeltaForMessages([systemMessage], tokenizer: tokenizer) {
            writes.append(AnyHiveWrite(Schema.tokenCountKey, delta))
        }

        return HiveNodeOutput(
            writes: writes,
            next: .nodes([NodeID.model])
        )
    }

    private static func cancelledOutput(
        taskID: HiveTaskID,
        calls: [HiveToolCall],
        tokenizer: (any HiveTokenizer)?
    ) -> HiveNodeOutput<Schema> {
        let systemMessage = HiveChatMessage(
            id: MessageID.system(taskID: taskID),
            role: .system,
            content: "Tool execution cancelled by user.",
            toolCalls: [],
            op: nil
        )

        let toolMessages = calls.map { call in
            HiveChatMessage(
                id: "tool:" + call.id + ":cancelled",
                role: .tool,
                content: "Tool call cancelled by user.",
                toolCallID: call.id,
                toolCalls: [],
                op: nil
            )
        }

        let allMessages = [systemMessage] + toolMessages
        var writes: [AnyHiveWrite<Schema>] = [
            AnyHiveWrite(Schema.pendingToolCallsKey, []),
            AnyHiveWrite(Schema.messagesKey, allMessages)
        ]
        if let delta = tokenDeltaForMessages(allMessages, tokenizer: tokenizer) {
            writes.append(AnyHiveWrite(Schema.tokenCountKey, delta))
        }

        return HiveNodeOutput(
            writes: writes,
            next: .nodes([NodeID.model])
        )
    }

    private static func toolExecuteNode() -> HiveNode<Schema> {
        { input in
            let pending = try input.store.get(Schema.pendingToolCallsKey)
            let calls = pending.sorted(by: Self.toolCallSort)
            let breakerPolicy = input.context.toolCircuitBreakerPolicy
            let existingFailureStreak = try input.store.get(Schema.toolFailureStreakKey)
            let existingOpenedAtStep = try input.store.get(Schema.toolCircuitOpenedAtStepKey)
            var circuitResetWrites: [AnyHiveWrite<Schema>] = []

            if let breakerPolicy, let openedAtStep = existingOpenedAtStep {
                let stepsSinceOpen = max(0, input.run.stepIndex - openedAtStep)
                if stepsSinceOpen < breakerPolicy.cooldownSteps {
                    return circuitBreakerCooldownOutput(
                        taskID: input.run.taskID,
                        openedAtStep: openedAtStep,
                        cooldownSteps: breakerPolicy.cooldownSteps,
                        failureStreak: existingFailureStreak,
                        tokenizer: input.context.tokenizer
                    )
                }
                circuitResetWrites.append(AnyHiveWrite(Schema.toolFailureStreakKey, 0))
                circuitResetWrites.append(AnyHiveWrite(Schema.toolCircuitOpenedAtStepKey, Optional<Int>.none))
            }

            if let resume = input.run.resume?.payload {
                switch resume {
                case let .toolApproval(decision):
                    switch decision {
                    case .approved:
                        break
                    case .rejected:
                        return rejectedOutput(
                            taskID: input.run.taskID,
                            calls: calls,
                            tokenizer: input.context.tokenizer
                        )
                    case .cancelled:
                        return cancelledOutput(
                            taskID: input.run.taskID,
                            calls: calls,
                            tokenizer: input.context.tokenizer
                        )
                    }
                }
            }

            guard calls.isEmpty == false else {
                if circuitResetWrites.isEmpty {
                    return HiveNodeOutput(next: .nodes([NodeID.model]))
                }
                return HiveNodeOutput(writes: circuitResetWrites, next: .nodes([NodeID.model]))
            }

            guard let registry = input.environment.tools else {
                throw HiveRuntimeError.toolRegistryMissing
            }

            var toolMessages: [HiveChatMessage] = []
            toolMessages.reserveCapacity(calls.count)
            var failureStreak = existingFailureStreak

            for call in calls {
                let metadata = ["toolCallID": call.id]
                input.emitStream(.toolInvocationStarted(name: call.name), metadata)
                do {
                    let result = try await withRetry(
                        policy: input.context.toolRetryPolicy ?? input.context.retryPolicy,
                        clock: input.environment.clock
                    ) {
                        try await registry.invoke(call)
                    }
                    input.emitStream(.toolInvocationFinished(name: call.name, success: true), metadata)
                    failureStreak = 0
                    toolMessages.append(
                        HiveChatMessage(
                            id: "tool:" + call.id,
                            role: .tool,
                            content: result.content,
                            toolCallID: call.id,
                            toolCalls: [],
                            op: nil
                        )
                    )
                } catch {
                    input.emitStream(.toolInvocationFinished(name: call.name, success: false), metadata)
                    failureStreak += 1
                    if let breakerPolicy, failureStreak >= breakerPolicy.failureThreshold {
                        return circuitBreakerOpenedOutput(
                            taskID: input.run.taskID,
                            failureStreak: failureStreak,
                            openedAtStep: input.run.stepIndex,
                            tokenizer: input.context.tokenizer
                        )
                    }
                    throw error
                }
                return results.sorted { $0.0 < $1.0 }.map(\.1)
            }

            var writes: [AnyHiveWrite<Schema>] = circuitResetWrites + [
                AnyHiveWrite(Schema.pendingToolCallsKey, []),
                AnyHiveWrite(Schema.messagesKey, toolMessages)
            ]
            if breakerPolicy != nil {
                writes.append(AnyHiveWrite(Schema.toolFailureStreakKey, 0))
                writes.append(AnyHiveWrite(Schema.toolCircuitOpenedAtStepKey, Optional<Int>.none))
            }
            if let delta = tokenDeltaForMessages(toolMessages, tokenizer: input.context.tokenizer) {
                writes.append(AnyHiveWrite(Schema.tokenCountKey, delta))
            }

            return HiveNodeOutput(
                writes: writes,
                next: .nodes([NodeID.model])
            )
        }
    }

    private static func tokenDeltaForMessages(
        _ messages: [HiveChatMessage],
        tokenizer: (any HiveTokenizer)?
    ) -> Int? {
        guard let tokenizer else { return nil }
        guard messages.isEmpty == false else { return nil }
        return tokenizer.countTokens(messages)
    }

    private static func circuitBreakerOpenedOutput(
        taskID: HiveTaskID,
        failureStreak: Int,
        openedAtStep: Int,
        tokenizer: (any HiveTokenizer)?
    ) -> HiveNodeOutput<Schema> {
        let systemMessage = HiveChatMessage(
            id: MessageID.system(taskID: taskID),
            role: .system,
            content: "Tool circuit breaker opened after \(failureStreak) consecutive failures.",
            toolCalls: [],
            op: nil
        )
        var writes: [AnyHiveWrite<Schema>] = [
            AnyHiveWrite(Schema.pendingToolCallsKey, []),
            AnyHiveWrite(Schema.messagesKey, [systemMessage]),
            AnyHiveWrite(Schema.toolFailureStreakKey, failureStreak),
            AnyHiveWrite(Schema.toolCircuitOpenedAtStepKey, Optional(openedAtStep))
        ]
        if let delta = tokenDeltaForMessages([systemMessage], tokenizer: tokenizer) {
            writes.append(AnyHiveWrite(Schema.tokenCountKey, delta))
        }
        return HiveNodeOutput(writes: writes, next: .nodes([NodeID.model]))
    }

    private static func circuitBreakerCooldownOutput(
        taskID: HiveTaskID,
        openedAtStep: Int,
        cooldownSteps: Int,
        failureStreak: Int,
        tokenizer: (any HiveTokenizer)?
    ) -> HiveNodeOutput<Schema> {
        let systemMessage = HiveChatMessage(
            id: MessageID.system(taskID: taskID),
            role: .system,
            content: "Tool circuit breaker is cooling down (opened at step \(openedAtStep), cooldown \(cooldownSteps) steps).",
            toolCalls: [],
            op: nil
        )
        var writes: [AnyHiveWrite<Schema>] = [
            AnyHiveWrite(Schema.pendingToolCallsKey, []),
            AnyHiveWrite(Schema.messagesKey, [systemMessage]),
            AnyHiveWrite(Schema.toolFailureStreakKey, failureStreak),
            AnyHiveWrite(Schema.toolCircuitOpenedAtStepKey, Optional(openedAtStep))
        ]
        if let delta = tokenDeltaForMessages([systemMessage], tokenizer: tokenizer) {
            writes.append(AnyHiveWrite(Schema.tokenCountKey, delta))
        }
        return HiveNodeOutput(writes: writes, next: .nodes([NodeID.model]))
    }

    /// Executes an operation with retry according to the given `HiveRetryPolicy`.
    ///
    /// Uses the Hive clock for deterministic backoff sleep — no jitter is applied.
    /// Returns immediately on the first success, or rethrows the last error
    /// after all attempts are exhausted.
    private static func withRetry<T>(
        policy: HiveRetryPolicy?,
        clock: any HiveClock,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        guard let policy else { return try await operation() }

        switch policy {
        case .none:
            return try await operation()
        case .exponentialBackoff(let initialNs, let factor, let maxAttempts, let maxNs):
            guard maxAttempts > 0 else { return try await operation() }

            var lastError: (any Error)?
            var delay = initialNs

            for attempt in 0 ..< maxAttempts {
                do {
                    return try await operation()
                } catch {
                    lastError = error
                    if attempt + 1 < maxAttempts {
                        let sleepNs = min(delay, maxNs)
                        if sleepNs > 0 {
                            try await clock.sleep(nanoseconds: sleepNs)
                        }
                        delay = UInt64(Double(delay) * factor)
                    }
                }
            }
            if let error = lastError {
                throw error
            } else {
                throw HiveRuntimeError.invalidRunOptions("Retry policy exhausted with no error recorded")
            }
        }
    }

    private static func compactMessages(
        history: [HiveChatMessage],
        policy: HiveCompactionPolicy,
        tokenizer: HiveTokenizer
    ) -> [HiveChatMessage] {
        let keepTailCount = min(policy.preserveLastMessages, history.count)
        let head = Array(history.dropLast(keepTailCount))
        var kept = Array(history.suffix(keepTailCount))

        while kept.count > 1, tokenizer.countTokens(kept) > policy.maxTokens {
            kept.removeFirst()
        }

        if tokenizer.countTokens(kept) <= policy.maxTokens {
            for message in head.reversed() {
                if tokenizer.countTokens([message] + kept) <= policy.maxTokens {
                    kept.insert(message, at: 0)
                } else {
                    break
                }
            }
        }

        if let first = history.first,
           first.role == .system,
           history.count > kept.count,
           kept.first?.id != first.id,
           tokenizer.countTokens([first] + kept) <= policy.maxTokens {
            kept.insert(first, at: 0)
        }

        return kept
    }

    private static func toolDefinitionSort(_ lhs: HiveToolDefinition, _ rhs: HiveToolDefinition) -> Bool {
        lhs.name.utf8.lexicographicallyPrecedes(rhs.name.utf8)
    }

    static func toolCalls(_ lhs: HiveToolCall, _ rhs: HiveToolCall) -> Bool {
        if lhs.name == rhs.name {
            return lhs.id.utf8.lexicographicallyPrecedes(rhs.id.utf8)
        }
        return lhs.name.utf8.lexicographicallyPrecedes(rhs.name.utf8)
    }

    private static func cacheSignature(for messages: [HiveChatMessage]) -> String {
        var data = Data()
        data.append(contentsOf: Array("HCS1".utf8))
        for message in messages {
            data.append(contentsOf: Array(message.id.utf8))
            data.append(0x00)
            data.append(contentsOf: Array(message.role.rawValue.utf8))
            data.append(0x00)
            data.append(contentsOf: Array(message.content.utf8))
            data.append(0x00)
            if let toolCallID = message.toolCallID {
                data.append(contentsOf: Array(toolCallID.utf8))
            }
            data.append(0x00)
            for toolCall in message.toolCalls.sorted(by: toolCallSort) {
                data.append(contentsOf: Array(toolCall.id.utf8))
                data.append(0x00)
                data.append(contentsOf: Array(toolCall.name.utf8))
                data.append(0x00)
                data.append(contentsOf: Array(toolCall.argumentsJSON.utf8))
                data.append(0x00)
            }
        }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private extension UUID {
    var bytes: [UInt8] {
        withUnsafeBytes(of: uuid) { Array($0) }
    }
}

private extension UInt32 {
    var bigEndianBytes: [UInt8] {
        let value = bigEndian
        return [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }
}
