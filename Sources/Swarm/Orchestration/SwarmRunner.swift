// SwarmRunner.swift
// Swarm Framework
//
// Lightweight multi-agent runner inspired by SwiftSwarm-style handoffs.

import Foundation

// MARK: - SwarmAgentProfile

/// Lightweight agent profile used by Swarm.
public struct SwarmAgentProfile: Sendable {
    public let name: String
    public let instructions: String
    public let tools: [any AnyJSONTool]
    public let configuration: AgentConfiguration
    public let inferenceProvider: any InferenceProvider
    public let handoffs: [AnyHandoffConfiguration]

    public init(
        name: String,
        instructions: String,
        tools: [any AnyJSONTool],
        configuration: AgentConfiguration,
        inferenceProvider: any InferenceProvider,
        handoffs: [AnyHandoffConfiguration] = []
    ) {
        self.name = name
        self.instructions = instructions
        self.tools = tools
        self.configuration = configuration
        self.inferenceProvider = inferenceProvider
        self.handoffs = handoffs
    }

    public init?(
        from agent: some AgentRuntime,
        fallbackProvider: (any InferenceProvider)? = nil
    ) {
        let agentName = SwarmAgentProfile.displayName(for: agent)
        guard let provider = agent.inferenceProvider ?? fallbackProvider else {
            return nil
        }

        self.init(
            name: agentName,
            instructions: agent.instructions,
            tools: agent.tools,
            configuration: agent.configuration,
            inferenceProvider: provider,
            handoffs: agent.handoffs
        )
    }

    static func displayName(for agent: any AgentRuntime) -> String {
        let configured = agent.configuration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configured.isEmpty {
            return configured
        }
        return String(describing: type(of: agent))
    }
}

// MARK: - SwarmResponse

/// Response produced by a Swarm run.
public struct SwarmResponse: Sendable {
    public let messages: [MemoryMessage]
    public let agentName: String
    public let context: [String: SendableValue]

    public init(messages: [MemoryMessage], agentName: String, context: [String: SendableValue]) {
        self.messages = messages
        self.agentName = agentName
        self.context = context
    }
}

// MARK: - SwarmToolCallDelta

/// Tool call delta for streaming UI updates.
public struct SwarmToolCallDelta: Sendable, Equatable {
    public let index: Int
    public let id: String?
    public let name: String?
    public let arguments: String

    public init(index: Int, id: String?, name: String?, arguments: String) {
        self.index = index
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

// MARK: - SwarmStreamChunk

/// Chunk emitted during Swarm streaming.
public struct SwarmStreamChunk: Sendable {
    public var content: String?
    public var toolCalls: [InferenceResponse.ParsedToolCall]?
    public var toolCallDelta: SwarmToolCallDelta?
    public var delim: String?
    public var response: SwarmResponse?
    public var agentName: String?

    public init(
        content: String? = nil,
        toolCalls: [InferenceResponse.ParsedToolCall]? = nil,
        toolCallDelta: SwarmToolCallDelta? = nil,
        delim: String? = nil,
        response: SwarmResponse? = nil,
        agentName: String? = nil
    ) {
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallDelta = toolCallDelta
        self.delim = delim
        self.response = response
        self.agentName = agentName
    }
}

// MARK: - SwarmError

public enum SwarmError: Error, Sendable {
    case agentNotFound(name: String)
    case missingInferenceProvider(agentName: String)
    case handoffTargetMissing(toolName: String)
    case invalidToolArguments(toolName: String, reason: String)
}

// MARK: - SwarmRunner

/// Lightweight multi-agent runner with tool-based handoffs.
public actor SwarmRunner {
    // MARK: Public

    public init(
        agents: [any AgentRuntime],
        fallbackProvider: (any InferenceProvider)? = nil
    ) throws {
        var profiles: [String: SwarmAgentProfile] = [:]
        for agent in agents {
            guard let profile = SwarmAgentProfile(from: agent, fallbackProvider: fallbackProvider) else {
                let name = SwarmAgentProfile.displayName(for: agent)
                throw SwarmError.missingInferenceProvider(agentName: name)
            }
            profiles[profile.name] = profile
        }
        profilesByName = profiles
    }

    /// Runs the swarm and returns the final response.
    public func run(
        agentName: String,
        messages: [MemoryMessage],
        context: [String: SendableValue] = [:],
        executeTools: Bool = true
    ) async throws -> SwarmResponse {
        var finalResponse: SwarmResponse?
        let stream = runStream(
            agentName: agentName,
            messages: messages,
            context: context,
            executeTools: executeTools
        )
        for try await chunk in stream {
            if let response = chunk.response {
                finalResponse = response
            }
        }
        guard let response = finalResponse else {
            throw AgentError.internalError(reason: "Swarm finished without a response")
        }
        return response
    }

    /// Runs the swarm and streams intermediate output.
    public func runStream(
        agentName: String,
        messages: [MemoryMessage],
        context: [String: SendableValue] = [:],
        executeTools: Bool = true
    ) -> AsyncThrowingStream<SwarmStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard var activeProfile = profilesByName[agentName] else {
                        throw SwarmError.agentNotFound(name: agentName)
                    }

                    var history = messages
                    let initialMessageCount = messages.count
                    let userInput = history.last(where: { $0.role == .user })?.content ?? ""
                    let swarmContext = AgentContext(input: userInput, initialValues: context)

                    continuation.yield(SwarmStreamChunk(delim: "start", agentName: activeProfile.name))

                    let (content, toolCalls) = try await streamCompletion(
                        profile: activeProfile,
                        history: &history,
                        continuation: continuation
                    )

                    if !content.isEmpty {
                        history.append(.assistant(content))
                    }

                    if let toolCalls, !toolCalls.isEmpty, executeTools {
                        let toolResult = try await handleToolCalls(
                            toolCalls,
                            activeProfile: &activeProfile,
                            history: &history,
                            context: swarmContext
                        )

                        if !toolResult.messages.isEmpty {
                            history.append(contentsOf: toolResult.messages)
                        }
                        // Context updates are stored in AgentContext; snapshot later.

                        // Run a final completion after tool execution.
                        let (finalContent, _) = try await streamCompletion(
                            profile: activeProfile,
                            history: &history,
                            continuation: continuation
                        )

                        if !finalContent.isEmpty {
                            history.append(.assistant(finalContent))
                        }
                    }

                    continuation.yield(SwarmStreamChunk(delim: "end", agentName: activeProfile.name))

                    let response = SwarmResponse(
                        messages: Array(history.dropFirst(initialMessageCount)),
                        agentName: activeProfile.name,
                        context: await swarmContext.snapshot
                    )
                    continuation.yield(SwarmStreamChunk(response: response, agentName: activeProfile.name))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: Private

    private struct ToolExecutionResult {
        let messages: [MemoryMessage]
        let context: [String: SendableValue]
    }

    private struct HandoffEntry {
        let config: AnyHandoffConfiguration
        let target: SwarmAgentProfile
    }

    private struct ToolCallAccumulator {
        struct AccumulatingToolCall {
            var id: String?
            var name: String?
            var arguments: String

            init() {
                id = nil
                name = nil
                arguments = ""
            }
        }

        private var toolCalls: [Int: AccumulatingToolCall] = [:]

        mutating func accumulate(index: Int, id: String?, name: String?, arguments: String) {
            var toolCall = toolCalls[index] ?? AccumulatingToolCall()
            if let id, !id.isEmpty {
                toolCall.id = id
            }
            if let name, !name.isEmpty {
                toolCall.name = name
            }
            toolCall.arguments += arguments
            toolCalls[index] = toolCall
        }

        func completedCalls() throws -> [InferenceResponse.ParsedToolCall] {
            try toolCalls
                .sorted { $0.key < $1.key }
                .compactMap { _, call -> InferenceResponse.ParsedToolCall? in
                    guard let id = call.id, let name = call.name else { return nil }
                    let arguments = try SwarmRunner.parseToolArguments(call.arguments, toolName: name)
                    return InferenceResponse.ParsedToolCall(id: id, name: name, arguments: arguments)
                }
        }
    }

    private let profilesByName: [String: SwarmAgentProfile]

    private func streamCompletion(
        profile: SwarmAgentProfile,
        history: inout [MemoryMessage],
        continuation: AsyncThrowingStream<SwarmStreamChunk, Error>.Continuation
    ) async throws -> (String, [InferenceResponse.ParsedToolCall]?) {
        let toolSchemas = buildToolSchemas(for: profile)
        let prompt = buildPrompt(with: history, instructions: profile.instructions)
        let options = profile.configuration.inferenceOptions
        let provider = profile.inferenceProvider

        if profile.configuration.enableStreaming {
            if !toolSchemas.isEmpty, let streamingProvider = provider as? any InferenceStreamingProvider {
                var accumulator = ToolCallAccumulator()
                var content = ""

                for try await event in streamingProvider.streamWithToolCalls(
                    prompt: prompt,
                    tools: toolSchemas,
                    options: options
                ) {
                    switch event {
                    case let .textDelta(text):
                        content += text
                        continuation.yield(SwarmStreamChunk(content: text, agentName: profile.name))
                    case let .toolCallDelta(index, id, name, arguments):
                        accumulator.accumulate(index: index, id: id, name: name, arguments: arguments)
                        continuation.yield(SwarmStreamChunk(
                            toolCallDelta: SwarmToolCallDelta(index: index, id: id, name: name, arguments: arguments),
                            agentName: profile.name
                        ))
                    case .finishReason, .usage:
                        break
                    case .done:
                        break
                    }
                }

                let toolCalls = try accumulator.completedCalls()
                return (content, toolCalls.isEmpty ? nil : toolCalls)
            }

            // Fallback to text-only streaming when tool-call streaming is not supported.
            if toolSchemas.isEmpty {
                var content = ""
                for try await token in provider.stream(prompt: prompt, options: options) {
                    content += token
                    continuation.yield(SwarmStreamChunk(content: token, agentName: profile.name))
                }
                return (content, nil)
            }
        }

        // Non-streaming fallback.
        if toolSchemas.isEmpty {
            let content = try await provider.generate(prompt: prompt, options: options)
            if !content.isEmpty {
                continuation.yield(SwarmStreamChunk(content: content, agentName: profile.name))
            }
            return (content, nil)
        }

        let response = try await provider.generateWithToolCalls(
            prompt: prompt,
            tools: toolSchemas,
            options: options
        )
        if let content = response.content, !content.isEmpty {
            continuation.yield(SwarmStreamChunk(content: content, agentName: profile.name))
        }
        return (response.content ?? "", response.toolCalls.isEmpty ? nil : response.toolCalls)
    }

    private func handleToolCalls(
        _ toolCalls: [InferenceResponse.ParsedToolCall],
        activeProfile: inout SwarmAgentProfile,
        history: inout [MemoryMessage],
        context: AgentContext
    ) async throws -> ToolExecutionResult {
        var messages: [MemoryMessage] = []
        var contextUpdates: [String: SendableValue] = [:]
        let handoffs = buildHandoffEntries(for: activeProfile)
        let registry = ToolRegistry(tools: activeProfile.tools)
        let toolEngine = ToolExecutionEngine()
        let builder = AgentResult.Builder()

        for toolCall in toolCalls {
            if let handoff = handoffs[toolCall.name] {
                if let isEnabled = handoff.config.isEnabled {
                    let enabled = await isEnabled(context, handoff.config.targetAgent)
                    if !enabled {
                        throw OrchestrationError.handoffSkipped(
                            from: activeProfile.name,
                            to: handoff.target.name,
                            reason: "Handoff disabled by isEnabled callback"
                        )
                    }
                }

                let inputData = HandoffInputData(
                    sourceAgentName: activeProfile.name,
                    targetAgentName: handoff.target.name,
                    input: history.last(where: { $0.role == .user })?.content ?? "",
                    context: await context.snapshot,
                    metadata: [:]
                )

                await context.set("handoff_source", value: .string(activeProfile.name))
                await context.set("handoff_target", value: .string(handoff.target.name))
                await context.recordExecution(agentName: handoff.target.name)

                let filteredInput = await applyHandoffConfiguration(
                    handoff: handoff,
                    inputData: inputData,
                    context: context,
                    updates: &contextUpdates
                )

                activeProfile = handoff.target
                if !filteredInput.input.isEmpty {
                    contextUpdates["handoff_input"] = .string(filteredInput.input)
                }

                messages.append(.tool("handoff_to_\(handoff.target.name)", toolName: toolCall.name))
                continue
            }

            let outcome = try await toolEngine.execute(
                toolName: toolCall.name,
                arguments: toolCall.arguments,
                providerCallId: toolCall.id,
                registry: registry,
                agent: DummyAgent(profile: activeProfile),
                context: nil,
                resultBuilder: builder,
                hooks: nil,
                tracing: nil,
                stopOnToolError: false
            )

            messages.append(.tool(outcome.result.output.description, toolName: toolCall.name))
        }

        return ToolExecutionResult(messages: messages, context: contextUpdates)
    }

    private func buildPrompt(with history: [MemoryMessage], instructions: String) -> String {
        let updatedHistory = updateSystemMessage(in: history, instructions: instructions)
        let formatted = updatedHistory.map { message in
            switch message.role {
            case .system:
                return "[System]: \(message.content)"
            case .user:
                return "[User]: \(message.content)"
            case .assistant:
                return "[Assistant]: \(message.content)"
            case .tool:
                let toolName = message.metadata["tool_name"] ?? "tool"
                return "[Tool Result - \(toolName)]: \(message.content)"
            }
        }
        return formatted.joined(separator: "\n\n")
    }

    private func updateSystemMessage(in history: [MemoryMessage], instructions: String) -> [MemoryMessage] {
        var updated = history
        if let lastSystemIndex = updated.lastIndex(where: { $0.role == .system }) {
            updated[lastSystemIndex] = .system(instructions)
        } else {
            updated.insert(.system(instructions), at: 0)
        }
        return updated
    }

    private func buildToolSchemas(for profile: SwarmAgentProfile) -> [ToolSchema] {
        let toolSchemas = profile.tools.map { $0.schema }
        let handoffSchemas = buildHandoffEntries(for: profile).values.map { entry in
            ToolSchema(
                name: entry.config.effectiveToolName,
                description: entry.config.effectiveToolDescription,
                parameters: [
                    ToolParameter(
                        name: "agent",
                        description: "Transfer to \(entry.target.name)",
                        type: .string
                    )
                ]
            )
        }
        return toolSchemas + handoffSchemas
    }

    private func buildHandoffEntries(for profile: SwarmAgentProfile) -> [String: HandoffEntry] {
        var entries: [String: HandoffEntry] = [:]
        for config in profile.handoffs {
            let targetName = SwarmAgentProfile.displayName(for: config.targetAgent)
            guard let target = profilesByName[targetName] else { continue }
            let entry = HandoffEntry(config: config, target: target)
            entries[config.effectiveToolName] = entry
        }
        return entries
    }

    private func applyHandoffConfiguration(
        handoff: HandoffEntry,
        inputData: HandoffInputData,
        context: AgentContext,
        updates: inout [String: SendableValue]
    ) async -> HandoffInputData {
        var inputData = inputData

        if let inputFilter = handoff.config.inputFilter {
            inputData = inputFilter(inputData)
        }

        if let onHandoff = handoff.config.onHandoff {
            do {
                try await onHandoff(context, inputData)
            } catch {
                Log.orchestration.warning(
                    "Swarm onHandoff callback failed for \(inputData.sourceAgentName) -> \(inputData.targetAgentName): \(error.localizedDescription)"
                )
            }
        }

        if !inputData.metadata.isEmpty {
            for (key, value) in inputData.metadata {
                updates[key] = value
                await context.set(key, value: value)
            }
        }

        return inputData
    }

    private static func parseToolArguments(
        _ jsonString: String,
        toolName: String
    ) throws -> [String: SendableValue] {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwarmError.invalidToolArguments(
                toolName: toolName,
                reason: "Failed to convert arguments to UTF-8"
            )
        }

        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SwarmError.invalidToolArguments(
                toolName: toolName,
                reason: "Arguments must be a JSON object"
            )
        }

        var result: [String: SendableValue] = [:]
        for (key, value) in jsonObject {
            result[key] = SendableValue.fromJSONValue(value)
        }
        return result
    }

    private struct DummyAgent: AgentRuntime {
        let profile: SwarmAgentProfile
        nonisolated var tools: [any AnyJSONTool] { profile.tools }
        nonisolated var instructions: String { profile.instructions }
        nonisolated var configuration: AgentConfiguration { profile.configuration }
        nonisolated var memory: (any Memory)? { nil }
        nonisolated var inferenceProvider: (any InferenceProvider)? { profile.inferenceProvider }
        nonisolated var tracer: (any Tracer)? { nil }
        nonisolated var inputGuardrails: [any InputGuardrail] { [] }
        nonisolated var outputGuardrails: [any OutputGuardrail] { [] }
        nonisolated var handoffs: [AnyHandoffConfiguration] { profile.handoffs }

        func run(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) async throws -> AgentResult {
            throw AgentError.internalError(reason: "Swarm DummyAgent does not execute")
        }

        nonisolated func stream(_ input: String, session: (any Session)?, hooks: (any RunHooks)?) -> AsyncThrowingStream<AgentEvent, Error> {
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        }

        func cancel() async {}
    }
}
