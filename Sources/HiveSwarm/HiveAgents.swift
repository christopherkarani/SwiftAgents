import CryptoKit
import Foundation
import HiveCore

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

    public static func makeToolUsingChatAgent(
        preModel: HiveNode<Schema>? = nil,
        postModel: HiveNode<Schema>? = nil
    ) throws -> CompiledHiveGraph<Schema> {
        let nodeIDs = NodeID.all

        var builder = HiveGraphBuilder<Schema>(start: [nodeIDs.preModel])
        builder.addNode(nodeIDs.preModel, preModel ?? Self.builtInPreModel())
        builder.addNode(nodeIDs.model, Self.modelNode())
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
        self.maxTokens = maxTokens
        self.preserveLastMessages = preserveLastMessages
    }
}

public struct HiveAgentsContext: Sendable {
    public let modelName: String
    public let toolApprovalPolicy: HiveAgentsToolApprovalPolicy
    public let compactionPolicy: HiveCompactionPolicy?
    public let tokenizer: (any HiveTokenizer)?
    public let retryPolicy: HiveRetryPolicy?

    public init(
        modelName: String,
        toolApprovalPolicy: HiveAgentsToolApprovalPolicy,
        compactionPolicy: HiveCompactionPolicy? = nil,
        tokenizer: (any HiveTokenizer)? = nil,
        retryPolicy: HiveRetryPolicy? = nil
    ) {
        self.modelName = modelName
        self.toolApprovalPolicy = toolApprovalPolicy
        self.compactionPolicy = compactionPolicy
        self.tokenizer = tokenizer
        self.retryPolicy = retryPolicy
    }
}

public struct HiveAgentsRuntime: Sendable {
    public let runControl: HiveAgentsRunController

    public init(runControl: HiveAgentsRunController) {
        self.runControl = runControl
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
                AnyHiveWrite(finalAnswerKey, Optional<String>.none)
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

            return merged.filter { message in
                if case .none = message.op { return true }
                return false
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
            _ = try input.store.get(Schema.llmInputMessagesKey)

            guard let policy = input.context.compactionPolicy else {
                return HiveNodeOutput(writes: [AnyHiveWrite(Schema.llmInputMessagesKey, Optional<[HiveChatMessage]>.none)])
            }

            guard policy.maxTokens >= 1, policy.preserveLastMessages >= 0 else {
                throw HiveRuntimeError.invalidRunOptions("Invalid compaction policy bounds.")
            }

            guard let tokenizer = input.context.tokenizer else {
                throw HiveRuntimeError.invalidRunOptions("Compaction policy requires a tokenizer.")
            }

            if tokenizer.countTokens(messages) <= policy.maxTokens {
                return HiveNodeOutput(writes: [AnyHiveWrite(Schema.llmInputMessagesKey, Optional<[HiveChatMessage]>.none)])
            }

            let trimmed = compactMessages(
                history: messages,
                policy: policy,
                tokenizer: tokenizer
            )

            return HiveNodeOutput(writes: [AnyHiveWrite(Schema.llmInputMessagesKey, Optional(trimmed))])
        }
    }

    private static func modelNode() -> HiveNode<Schema> {
        { input in
            let messages = try input.store.get(Schema.messagesKey)
            let llmInputMessages = try input.store.get(Schema.llmInputMessagesKey)
            let inputMessages = llmInputMessages ?? messages
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
                policy: input.context.retryPolicy,
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
                AnyHiveWrite(Schema.pendingToolCallsKey, deterministicAssistant.toolCalls),
                AnyHiveWrite(Schema.llmInputMessagesKey, Optional<[HiveChatMessage]>.none)
            ]

            if deterministicAssistant.toolCalls.isEmpty {
                writes.append(AnyHiveWrite(Schema.finalAnswerKey, Optional(deterministicAssistant.content)))
            }

            return HiveNodeOutput(writes: writes)
        }
    }

    private static func toolsNode() -> HiveNode<Schema> {
        { input in
            let pending = try input.store.get(Schema.pendingToolCallsKey)
            let calls = pending.sorted(by: Self.toolCallSort)

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
                if let resume = input.run.resume?.payload {
                    switch resume {
                    case let .toolApproval(decision):
                        if decision == .rejected {
                            return rejectedOutput(taskID: input.run.taskID, calls: calls)
                        }
                        if decision == .cancelled {
                            return cancelledOutput(taskID: input.run.taskID, calls: calls)
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

    private static func rejectedOutput(
        taskID: HiveTaskID,
        calls _: [HiveToolCall]
    ) -> HiveNodeOutput<Schema> {
        let systemMessage = HiveChatMessage(
            id: MessageID.system(taskID: taskID),
            role: .system,
            content: "Tool execution rejected by user.",
            toolCalls: [],
            op: nil
        )

        return HiveNodeOutput(
            writes: [
                AnyHiveWrite(Schema.pendingToolCallsKey, []),
                AnyHiveWrite(Schema.messagesKey, [systemMessage])
            ],
            next: .nodes([NodeID.model])
        )
    }

    private static func cancelledOutput(
        taskID: HiveTaskID,
        calls: [HiveToolCall]
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

        return HiveNodeOutput(
            writes: [
                AnyHiveWrite(Schema.pendingToolCallsKey, []),
                AnyHiveWrite(Schema.messagesKey, [systemMessage] + toolMessages)
            ],
            next: .nodes([NodeID.model])
        )
    }

    private static func toolExecuteNode() -> HiveNode<Schema> {
        { input in
            let pending = try input.store.get(Schema.pendingToolCallsKey)
            let calls = pending.sorted(by: Self.toolCallSort)

            if let resume = input.run.resume?.payload {
                switch resume {
                case let .toolApproval(decision):
                    switch decision {
                    case .approved:
                        break
                    case .rejected:
                        return rejectedOutput(taskID: input.run.taskID, calls: calls)
                    case .cancelled:
                        return cancelledOutput(taskID: input.run.taskID, calls: calls)
                    }
                }
            }

            guard calls.isEmpty == false else {
                return HiveNodeOutput(next: .nodes([NodeID.model]))
            }

            guard let registry = input.environment.tools else {
                throw HiveRuntimeError.toolRegistryMissing
            }

            var toolMessages: [HiveChatMessage] = []
            toolMessages.reserveCapacity(calls.count)

            for call in calls {
                let metadata = ["toolCallID": call.id]
                input.emitStream(.toolInvocationStarted(name: call.name), metadata)
                do {
                    let result = try await withRetry(
                        policy: input.context.retryPolicy,
                        clock: input.environment.clock
                    ) {
                        try await registry.invoke(call)
                    }
                    input.emitStream(.toolInvocationFinished(name: call.name, success: true), metadata)
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
                    throw error
                }
            }

            return HiveNodeOutput(
                writes: [
                    AnyHiveWrite(Schema.pendingToolCallsKey, []),
                    AnyHiveWrite(Schema.messagesKey, toolMessages)
                ],
                next: .nodes([NodeID.model])
            )
        }
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
            throw lastError!
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
           first.role.rawValue == "system",
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

    private static func toolCallSort(_ lhs: HiveToolCall, _ rhs: HiveToolCall) -> Bool {
        if lhs.name == rhs.name {
            return lhs.id.utf8.lexicographicallyPrecedes(rhs.id.utf8)
        }
        return lhs.name.utf8.lexicographicallyPrecedes(rhs.name.utf8)
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
