// Agent.swift
// Swarm Framework
//
// Tool-calling agent that uses structured LLM tool calling APIs.

import Foundation

// MARK: - Agent

/// An agent that uses structured LLM tool calling APIs for reliable tool invocation.
///
/// Unlike ReActAgent which parses tool calls from text output, Agent
/// leverages the LLM's native tool calling capabilities via `generateWithToolCalls()`
/// for more reliable and type-safe tool invocation.
///
/// If no inference provider is configured, Agent will try to use Apple Foundation Models
/// (on-device) when available. If Foundation Models are unavailable and no provider is set,
/// Agent throws `AgentError.inferenceProviderUnavailable`.
///
/// Provider resolution order is:
/// 1. An explicit provider passed to `Agent(...)` (including `Agent(_:)`)
/// 2. A provider set via `.environment(\.inferenceProvider, ...)`
/// 3. Apple Foundation Models (on-device), if available
/// 4. Otherwise, throw `AgentError.inferenceProviderUnavailable`
///
/// The agent follows a loop-based execution pattern:
/// 1. Build prompt with system instructions + conversation history
/// 2. Call provider with tool schemas
/// 3. If tool calls requested, execute each tool and add results to history
/// 4. If no tool calls, return content as final answer
/// 5. Repeat until done or max iterations reached
///
/// Example:
/// ```swift
/// let agent = Agent(
///     tools: [WeatherTool(), CalculatorTool()],
///     instructions: "You are a helpful assistant with access to tools."
/// )
///
/// let result = try await agent.run("What's the weather in Tokyo?")
/// print(result.output)
/// ```
public actor Agent: AgentRuntime {
    // MARK: Public

    // MARK: - Agent Protocol Properties

    nonisolated public let tools: [any AnyJSONTool]
    nonisolated public let instructions: String
    nonisolated public let configuration: AgentConfiguration
    nonisolated public let memory: (any Memory)?
    nonisolated public let inferenceProvider: (any InferenceProvider)?
    nonisolated public let inputGuardrails: [any InputGuardrail]
    nonisolated public let outputGuardrails: [any OutputGuardrail]
    nonisolated public let tracer: (any Tracer)?
    nonisolated public let guardrailRunnerConfiguration: GuardrailRunnerConfiguration

    /// Configured handoffs for this agent.
    nonisolated public var handoffs: [AnyHandoffConfiguration] {
        _handoffs
    }

    // MARK: - Initialization

    /// Creates a new Agent.
    /// - Parameters:
    ///   - tools: Tools available to the agent. Default: []
    ///   - instructions: System instructions defining agent behavior. Default: ""
    ///   - configuration: Agent configuration settings. Default: .default
    ///   - memory: Optional memory system. Default: nil
    ///   - inferenceProvider: Optional custom inference provider. Default: nil
    ///   - tracer: Optional tracer for observability. Default: nil
    ///   - inputGuardrails: Input validation guardrails. Default: []
    ///   - outputGuardrails: Output validation guardrails. Default: []
    ///   - guardrailRunnerConfiguration: Configuration for guardrail runner. Default: .default
    ///   - handoffs: Handoff configurations for multi-agent orchestration. Default: []
    /// Creates a new Agent.
    /// - Parameters:
    ///   - tools: Tools available to the agent. Default: []
    ///   - instructions: System instructions defining agent behavior. Default: ""
    ///   - configuration: Agent configuration settings. Default: .default
    ///   - memory: Optional memory system. Default: nil
    ///   - inferenceProvider: Optional custom inference provider. Default: nil
    ///   - tracer: Optional tracer for observability. Default: nil
    ///   - inputGuardrails: Input validation guardrails. Default: []
    ///   - outputGuardrails: Output validation guardrails. Default: []
    ///   - guardrailRunnerConfiguration: Configuration for guardrail runner. Default: .default
    ///   - handoffs: Handoff configurations for multi-agent orchestration. Default: []
    /// - Throws: `ToolRegistryError.duplicateToolName` if duplicate tool names are provided.
    public init(
        tools: [any AnyJSONTool] = [],
        instructions: String = "",
        configuration: AgentConfiguration = .default,
        memory: (any Memory)? = nil,
        inferenceProvider: (any InferenceProvider)? = nil,
        tracer: (any Tracer)? = nil,
        inputGuardrails: [any InputGuardrail] = [],
        outputGuardrails: [any OutputGuardrail] = [],
        guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default,
        handoffs: [AnyHandoffConfiguration] = []
    ) throws {
        self.tools = tools
        self.instructions = instructions
        self.configuration = configuration
        self.memory = memory
        self.inferenceProvider = inferenceProvider
        self.tracer = tracer
        self.inputGuardrails = inputGuardrails
        self.outputGuardrails = outputGuardrails
        self.guardrailRunnerConfiguration = guardrailRunnerConfiguration
        _handoffs = handoffs
        toolRegistry = try ToolRegistry(tools: tools)
    }

    /// Convenience initializer that takes an unlabeled inference provider.
    ///
    /// This enables an opinionated, easy setup:
    /// ```swift
    /// let agent = Agent(.anthropic(key: "..."))
    /// ```
    public init(
        _ inferenceProvider: any InferenceProvider,
        tools: [any AnyJSONTool] = [],
        instructions: String = "",
        configuration: AgentConfiguration = .default,
        memory: (any Memory)? = nil,
        tracer: (any Tracer)? = nil,
        inputGuardrails: [any InputGuardrail] = [],
        outputGuardrails: [any OutputGuardrail] = [],
        guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default,
        handoffs: [AnyHandoffConfiguration] = []
    ) throws {
        self.init(
            tools: tools,
            instructions: instructions,
            configuration: configuration,
            memory: memory,
            inferenceProvider: inferenceProvider,
            tracer: tracer,
            inputGuardrails: inputGuardrails,
            outputGuardrails: outputGuardrails,
            guardrailRunnerConfiguration: guardrailRunnerConfiguration,
            handoffs: handoffs
        )
    }

    /// Creates a new Agent with typed tools.
    /// - Parameters:
    ///   - tools: Typed tools available to the agent. Default: []
    ///   - instructions: System instructions defining agent behavior. Default: ""
    ///   - configuration: Agent configuration settings. Default: .default
    ///   - memory: Optional memory system. Default: nil
    ///   - inferenceProvider: Optional custom inference provider. Default: nil
    ///   - tracer: Optional tracer for observability. Default: nil
    ///   - inputGuardrails: Input validation guardrails. Default: []
    ///   - outputGuardrails: Output validation guardrails. Default: []
    ///   - guardrailRunnerConfiguration: Configuration for guardrail runner. Default: .default
    ///   - handoffs: Handoff configurations for multi-agent orchestration. Default: []
    /// Creates a new Agent with typed tools.
    /// - Parameters:
    ///   - tools: Typed tools available to the agent. Default: []
    ///   - instructions: System instructions defining agent behavior. Default: ""
    ///   - configuration: Agent configuration settings. Default: .default
    ///   - memory: Optional memory system. Default: nil
    ///   - inferenceProvider: Optional custom inference provider. Default: nil
    ///   - tracer: Optional tracer for observability. Default: nil
    ///   - inputGuardrails: Input validation guardrails. Default: []
    ///   - outputGuardrails: Output validation guardrails. Default: []
    ///   - guardrailRunnerConfiguration: Configuration for guardrail runner. Default: .default
    ///   - handoffs: Handoff configurations for multi-agent orchestration. Default: []
    /// - Throws: `ToolRegistryError.duplicateToolName` if duplicate tool names are provided.
    public init<T: Tool>(
        tools: [T] = [],
        instructions: String = "",
        configuration: AgentConfiguration = .default,
        memory: (any Memory)? = nil,
        inferenceProvider: (any InferenceProvider)? = nil,
        tracer: (any Tracer)? = nil,
        inputGuardrails: [any InputGuardrail] = [],
        outputGuardrails: [any OutputGuardrail] = [],
        guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default,
        handoffs: [AnyHandoffConfiguration] = []
    ) throws {
        let bridged = tools.map { AnyJSONToolAdapter($0) }
        try self.init(
            tools: bridged,
            instructions: instructions,
            configuration: configuration,
            memory: memory,
            inferenceProvider: inferenceProvider,
            tracer: tracer,
            inputGuardrails: inputGuardrails,
            outputGuardrails: outputGuardrails,
            guardrailRunnerConfiguration: guardrailRunnerConfiguration,
            handoffs: handoffs
        )
    }

    /// Creates a new Agent with simplified handoff declaration.
    ///
    /// This convenience initializer accepts an array of `AgentRuntime` conforming agents
    /// and automatically wraps each one as an `AnyHandoffConfiguration`, simplifying
    /// multi-agent orchestration setup.
    ///
    /// Example:
    /// ```swift
    /// let triageAgent = Agent(
    ///     instructions: "Route requests to the right specialist.",
    ///     handoffAgents: [billingAgent, supportAgent, salesAgent]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - tools: Tools available to the agent. Default: []
    ///   - instructions: System instructions defining agent behavior. Default: ""
    ///   - configuration: Agent configuration settings. Default: .default
    ///   - memory: Optional memory system. Default: nil
    ///   - inferenceProvider: Optional custom inference provider. Default: nil
    ///   - tracer: Optional tracer for observability. Default: nil
    ///   - inputGuardrails: Input validation guardrails. Default: []
    ///   - outputGuardrails: Output validation guardrails. Default: []
    ///   - guardrailRunnerConfiguration: Configuration for guardrail runner. Default: .default
    ///   - handoffAgents: Agents to hand off to, automatically wrapped as handoff configurations.
    /// - Throws: `ToolRegistryError.duplicateToolName` if duplicate tool names are provided.
    public init(
        tools: [any AnyJSONTool] = [],
        instructions: String = "",
        configuration: AgentConfiguration = .default,
        memory: (any Memory)? = nil,
        inferenceProvider: (any InferenceProvider)? = nil,
        tracer: (any Tracer)? = nil,
        inputGuardrails: [any InputGuardrail] = [],
        outputGuardrails: [any OutputGuardrail] = [],
        guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default,
        handoffAgents: [any AgentRuntime]
    ) throws {
        let configs = handoffAgents.map { agent in
            AnyHandoffConfiguration(
                targetAgent: agent,
                toolNameOverride: nil,
                toolDescription: nil
            )
        }
        try self.init(
            tools: tools,
            instructions: instructions,
            configuration: configuration,
            memory: memory,
            inferenceProvider: inferenceProvider,
            tracer: tracer,
            inputGuardrails: inputGuardrails,
            outputGuardrails: outputGuardrails,
            guardrailRunnerConfiguration: guardrailRunnerConfiguration,
            handoffs: configs
        )
    }

    // MARK: - Agent Protocol Methods

    /// Executes the agent with the given input and returns a result.
    /// - Parameters:
    ///   - input: The user's input/query.
    ///   - session: Optional session for conversation history management.
    ///   - hooks: Optional run hooks for observing agent execution events.
    /// - Returns: The result of the agent's execution.
    /// - Throws: `AgentError` if execution fails, or `GuardrailError` if guardrails trigger.
    public func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) async throws -> AgentResult {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput(reason: "Input cannot be empty")
        }

        let activeTracer = tracer
            ?? AgentEnvironmentValues.current.tracer
            ?? (configuration.defaultTracingEnabled ? SwiftLogTracer(minimumLevel: .debug) : nil)
        let activeMemory = memory ?? AgentEnvironmentValues.current.memory
        let lifecycleMemory = activeMemory as? any MemorySessionLifecycle

        let tracing = TracingHelper(
            tracer: activeTracer,
            agentName: configuration.name.isEmpty ? "Agent" : configuration.name
        )
        await tracing.traceStart(input: input)

        // Notify hooks of agent start
        await hooks?.onAgentStart(context: nil, agent: self, input: input)

        if let lifecycleMemory {
            await lifecycleMemory.beginMemorySession()
        }

        do {
            // Run input guardrails (with hooks for event emission)
            let runner = GuardrailRunner(configuration: guardrailRunnerConfiguration, hooks: hooks)
            _ = try await runner.runInputGuardrails(inputGuardrails, input: input, context: nil)

            isCancelled = false
            let resultBuilder = AgentResult.Builder()
            _ = resultBuilder.start()

            // Load conversation history from session (limit to recent messages)
            var sessionHistory: [MemoryMessage] = []
            if let session {
                sessionHistory = try await session.getItems(limit: configuration.sessionHistoryLimit)
            }

            // Create user message for this turn
            let userMessage = MemoryMessage.user(input)

            // Execute the tool calling loop with session context
            let output = try await executeToolCallingLoop(
                input: input,
                sessionHistory: sessionHistory,
                resultBuilder: resultBuilder,
                hooks: hooks,
                tracing: tracing
            )

            _ = resultBuilder.setOutput(output)

            // Run output guardrails BEFORE storing in session/memory
            _ = try await runner.runOutputGuardrails(outputGuardrails, output: output, agent: self, context: nil)

            // Store turn in session for conversation persistence
            // Session is the source of truth for conversation history
            if let session {
                let assistantMessage = MemoryMessage.assistant(output)
                try await session.addItems([userMessage, assistantMessage])
            }

            // Memory provides additional context (RAG, summaries) - NOT for conversation storage
            // This avoids duplication: session stores conversation, memory provides context
            // Note: If using memory for conversation context, populate it from session on demand

            let result = resultBuilder.build()
            await tracing.traceComplete(result: result)

            // Notify hooks of agent completion
            await hooks?.onAgentEnd(context: nil, agent: self, result: result)

            if let lifecycleMemory {
                await lifecycleMemory.endMemorySession()
            }
            return result
        } catch {
            // Notify hooks of error
            await hooks?.onError(context: nil, agent: self, error: error)
            await tracing.traceError(error)
            if let lifecycleMemory {
                await lifecycleMemory.endMemorySession()
            }
            throw error
        }
    }

    /// Streams the agent's execution, yielding events as they occur.
    /// - Parameters:
    ///   - input: The user's input/query.
    ///   - session: Optional session for conversation history management.
    ///   - hooks: Optional run hooks for observing agent execution events.
    /// - Returns: An async stream of agent events.
    nonisolated public func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream(for: self) { agent, continuation in
            // Create event bridge hooks
            let streamHooks = EventStreamHooks(continuation: continuation)

            // Combine with user-provided hooks
            let combinedHooks: any RunHooks = if let userHooks = hooks {
                CompositeRunHooks(hooks: [userHooks, streamHooks])
            } else {
                streamHooks
            }

            do {
                _ = try await agent.run(input, session: session, hooks: combinedHooks)
                continuation.finish()
            } catch {
                // Error is handled by EventStreamHooks.onError
                continuation.finish(throwing: error)
            }
        }
    }

    /// Cancels any ongoing execution.
    public func cancel() async {
        isCancelled = true
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: Private

    // MARK: - Conversation History

    private enum ConversationMessage: Sendable {
        case system(String)
        case user(String)
        case assistant(String)
        case toolResult(toolName: String, result: String)

        var formatted: String {
            switch self {
            case let .system(content):
                "[System]: \(content)"
            case let .user(content):
                "[User]: \(content)"
            case let .assistant(content):
                "[Assistant]: \(content)"
            case let .toolResult(toolName, result):
                "[Tool Result - \(toolName)]: \(result)"
            }
        }
    }

    private let _handoffs: [AnyHandoffConfiguration]

    // MARK: - Internal State

    private var isCancelled: Bool = false
    private var currentTask: Task<Void, Never>?
    private let toolRegistry: ToolRegistry

    // MARK: - Inference Provider Resolution

    private func resolvedInferenceProvider() throws -> any InferenceProvider {
        if let inferenceProvider {
            return inferenceProvider
        }

        if let environmentProvider = AgentEnvironmentValues.current.inferenceProvider {
            return environmentProvider
        }

        if let foundationModelsProvider = DefaultInferenceProviderFactory.makeFoundationModelsProviderIfAvailable() {
            return foundationModelsProvider
        }

        throw AgentError.inferenceProviderUnavailable(
            reason: """
            No inference provider configured and Apple Foundation Models are unavailable.

            Provide an inference provider explicitly (e.g. `Agent(.anthropic(key: \"...\"))`) \
            or via `.environment(\\.inferenceProvider, ...)`.
            """
        )
    }

    // MARK: - Tool Calling Loop Implementation

    private func executeToolCallingLoop(
        input: String,
        sessionHistory: [MemoryMessage] = [],
        resultBuilder: AgentResult.Builder,
        hooks: (any RunHooks)? = nil,
        tracing: TracingHelper? = nil
    ) async throws -> String {
        var iteration = 0
        let startTime = ContinuousClock.now
        let provider = try resolvedInferenceProvider()

        // Retrieve relevant context from memory (enables RAG for VectorMemory)
        let activeMemory = memory ?? AgentEnvironmentValues.current.memory
        var memoryContext = ""
        if let mem = activeMemory {
            let tokenLimit = configuration.contextProfile.memoryTokenLimit
            memoryContext = await mem.context(for: input, tokenLimit: tokenLimit)
        }

        var conversationHistory = buildInitialConversationHistory(
            sessionHistory: sessionHistory,
            input: input,
            memory: activeMemory,
            memoryContext: memoryContext
        )
        let systemMessage = buildSystemMessage(memory: activeMemory, memoryContext: memoryContext)

        let enableStreaming = configuration.enableStreaming && hooks != nil
        let toolStreamingProvider = provider as? any ToolCallStreamingInferenceProvider
        let useToolStreaming = enableStreaming && toolStreamingProvider != nil

        while iteration < configuration.maxIterations {
            iteration += 1
            _ = resultBuilder.incrementIteration()
            await hooks?.onIterationStart(context: nil, agent: self, number: iteration)

            try checkCancellationAndTimeout(startTime: startTime)

            let prompt = buildPrompt(from: conversationHistory)
            let toolSchemas = await buildToolSchemasWithHandoffs()

            // If no tools defined, generate without tool calling
            if toolSchemas.isEmpty {
                return try await generateWithoutTools(
                    provider: provider,
                    prompt: prompt,
                    systemPrompt: systemMessage,
                    enableStreaming: enableStreaming,
                    hooks: hooks
                )
            }

            // Generate response with tool calls
            let response = if useToolStreaming, let provider = toolStreamingProvider {
                try await generateWithToolsStreaming(
                    provider: provider,
                    prompt: prompt,
                    tools: toolSchemas,
                    systemPrompt: systemMessage,
                    hooks: hooks
                )
            } else {
                try await generateWithTools(
                    provider: provider,
                    prompt: prompt,
                    tools: toolSchemas,
                    systemPrompt: systemMessage,
                    hooks: hooks,
                    emitOutputTokens: enableStreaming
                )
            }

            if response.hasToolCalls {
                let handoffResult = try await processToolCallsWithHandoffs(
                    response: response,
                    conversationHistory: &conversationHistory,
                    resultBuilder: resultBuilder,
                    hooks: hooks,
                    tracing: tracing
                )
                // If a handoff occurred, return the target agent's result
                if let handoffOutput = handoffResult {
                    return handoffOutput
                }
            } else {
                guard let content = response.content else {
                    throw AgentError.generationFailed(reason: "Model returned no content or tool calls")
                }
                return content
            }

            await hooks?.onIterationEnd(context: nil, agent: self, number: iteration)
        }

        throw AgentError.maxIterationsExceeded(iterations: iteration)
    }

    /// Builds the initial conversation history from session history and user input.
    private func buildInitialConversationHistory(
        sessionHistory: [MemoryMessage],
        input: String,
        memory: (any Memory)?,
        memoryContext: String = ""
    ) -> [ConversationMessage] {
        var history: [ConversationMessage] = []
        history.append(.system(buildSystemMessage(memory: memory, memoryContext: memoryContext)))

        for msg in sessionHistory {
            switch msg.role {
            case .user: history.append(.user(msg.content))
            case .assistant: history.append(.assistant(msg.content))
            case .system: history.append(.system(msg.content))
            case .tool: history.append(.toolResult(toolName: "previous", result: msg.content))
            }
        }

        history.append(.user(input))
        return history
    }

    /// Checks for cancellation and timeout conditions.
    private func checkCancellationAndTimeout(startTime: ContinuousClock.Instant) throws {
        try Task.checkCancellation()
        if isCancelled { throw AgentError.cancelled }

        let elapsed = ContinuousClock.now - startTime
        if elapsed > configuration.timeout {
            throw AgentError.timeout(duration: configuration.timeout)
        }
    }

    /// Generates a response without tool calling.
    private func generateWithoutTools(
        provider: any InferenceProvider,
        prompt: String,
        systemPrompt: String,
        enableStreaming: Bool = false,
        hooks: (any RunHooks)?
    ) async throws -> String {
        await hooks?.onLLMStart(context: nil, agent: self, systemPrompt: systemPrompt, inputMessages: [MemoryMessage.user(prompt)])

        let content: String
        if enableStreaming {
            var streamedContent = ""
            streamedContent.reserveCapacity(1024)
            let stream = provider.stream(prompt: prompt, options: configuration.inferenceOptions)
            for try await token in stream {
                if !token.isEmpty {
                    streamedContent += token
                }
                await hooks?.onOutputToken(context: nil, agent: self, token: token)
            }
            content = streamedContent
        } else {
            content = try await provider.generate(
                prompt: prompt,
                options: configuration.inferenceOptions
            )
        }

        await hooks?.onLLMEnd(context: nil, agent: self, response: content, usage: nil)
        return content
    }

    /// Processes tool calls from the model response.
    private func processToolCalls(
        response: InferenceResponse,
        conversationHistory: inout [ConversationMessage],
        resultBuilder: AgentResult.Builder,
        hooks: (any RunHooks)?,
        tracing: TracingHelper?
    ) async throws {
        let toolCallSummary = response.toolCalls.map { "Calling tool: \($0.name)" }.joined(separator: ", ")
        conversationHistory.append(.assistant(response.content ?? toolCallSummary))

        for parsedCall in response.toolCalls {
            try await executeSingleToolCall(
                parsedCall: parsedCall,
                conversationHistory: &conversationHistory,
                resultBuilder: resultBuilder,
                hooks: hooks,
                tracing: tracing
            )
        }
    }

    /// Executes a single tool call and updates conversation history.
    private func executeSingleToolCall(
        parsedCall: InferenceResponse.ParsedToolCall,
        conversationHistory: inout [ConversationMessage],
        resultBuilder: AgentResult.Builder,
        hooks: (any RunHooks)?,
        tracing: TracingHelper?
    ) async throws {
        let activeMemory = memory ?? AgentEnvironmentValues.current.memory
        let engine = ToolExecutionEngine()
        let outcome = try await engine.execute(
            parsedCall,
            registry: toolRegistry,
            agent: self,
            context: nil,
            resultBuilder: resultBuilder,
            hooks: hooks,
            tracing: tracing,
            stopOnToolError: false
        )

        if outcome.result.isSuccess {
            conversationHistory.append(.toolResult(toolName: parsedCall.name, result: outcome.result.output.description))
            if let activeMemory {
                await activeMemory.add(.tool(outcome.result.output.description, toolName: parsedCall.name))
            }
        } else {
            let errorMessage = outcome.result.errorMessage ?? "Unknown error"
            conversationHistory.append(.toolResult(
                toolName: parsedCall.name,
                result: "[TOOL ERROR] Execution failed: \(errorMessage). Please try a different approach or tool."
            ))
            if let activeMemory {
                await activeMemory.add(.tool("Error - \(errorMessage)", toolName: parsedCall.name))
            }

            if configuration.stopOnToolError {
                throw AgentError.toolExecutionFailed(toolName: parsedCall.name, underlyingError: errorMessage)
            }
        }
    }

    // MARK: - Handoff Tool Schema Integration

    /// Builds tool schemas including handoff tool schemas.
    ///
    /// This merges regular tool schemas with handoff-generated schemas,
    /// allowing handoffs to appear as callable tools in the LLM prompt.
    private func buildToolSchemasWithHandoffs() async -> [ToolSchema] {
        var schemas = await toolRegistry.schemas

        for handoff in _handoffs {
            let handoffSchema = ToolSchema(
                name: handoff.effectiveToolName,
                description: handoff.effectiveToolDescription,
                parameters: [
                    ToolParameter(
                        name: "reason",
                        description: "Reason for the handoff",
                        type: .string,
                        isRequired: false
                    ),
                ]
            )
            schemas.append(handoffSchema)
        }

        return schemas
    }

    /// Processes tool calls, handling both regular tools and handoff tools.
    ///
    /// When a tool call matches a handoff's `effectiveToolName`, the target agent
    /// is executed with the original user input and its result is returned.
    /// Returns the handoff output if a handoff was executed, nil otherwise.
    private func processToolCallsWithHandoffs(
        response: InferenceResponse,
        conversationHistory: inout [ConversationMessage],
        resultBuilder: AgentResult.Builder,
        hooks: (any RunHooks)?,
        tracing: TracingHelper?
    ) async throws -> String? {
        let handoffMap = Dictionary(
            uniqueKeysWithValues: _handoffs.map { ($0.effectiveToolName, $0) }
        )

        let toolCallSummary = response.toolCalls.map { "Calling tool: \($0.name)" }.joined(separator: ", ")
        conversationHistory.append(.assistant(response.content ?? toolCallSummary))

        for parsedCall in response.toolCalls {
            // Check if this is a handoff tool call
            if let handoffConfig = handoffMap[parsedCall.name] {
                let reason = parsedCall.arguments["reason"]?.stringValue ?? ""
                let targetAgent = handoffConfig.targetAgent

                let handoffStart = ContinuousClock.now
                let spanId = await tracing?.traceToolCall(name: parsedCall.name, arguments: parsedCall.arguments)

                // Find the last user message to use as handoff input
                let lastUserMessage = conversationHistory.last(where: {
                    if case .user = $0 { return true }
                    return false
                })
                let handoffInput: String = if case let .user(content) = lastUserMessage {
                    content
                } else {
                    reason.isEmpty ? "Continue the conversation" : reason
                }

                let result = try await targetAgent.run(handoffInput, session: nil, hooks: hooks)

                if let spanId {
                    let handoffDuration = ContinuousClock.now - handoffStart
                    await tracing?.traceToolResult(spanId: spanId, name: parsedCall.name, result: result.output, duration: handoffDuration)
                }

                // Merge handoff result metadata into current agent's result builder
                // This preserves token counts, tool calls, and metadata from the target agent
                for toolCall in result.toolCalls {
                    _ = resultBuilder.addToolCall(toolCall)
                }
                for toolResult in result.toolResults {
                    _ = resultBuilder.addToolResult(toolResult)
                }
                if let usage = result.tokenUsage {
                    _ = resultBuilder.setTokenUsage(usage)
                }
                for (key, value) in result.metadata {
                    _ = resultBuilder.setMetadata(key, value)
                }

                // Return the handoff output to be used as the final result
                return result.output
            }

            // Regular tool call
            try await executeSingleToolCall(
                parsedCall: parsedCall,
                conversationHistory: &conversationHistory,
                resultBuilder: resultBuilder,
                hooks: hooks,
                tracing: tracing
            )
        }

        return nil
    }

    // MARK: - Prompt Building

    private func buildSystemMessage(
        memory: (any Memory)?,
        memoryContext: String = ""
    ) -> String {
        let baseInstructions = instructions.isEmpty
            ? "You are a helpful AI assistant with access to tools."
            : instructions

        if memoryContext.isEmpty {
            return baseInstructions
        }

        let descriptor = memory as? any MemoryPromptDescriptor
        let title = descriptor?.memoryPromptTitle ?? "Relevant Context from Memory"
        let priority = descriptor?.memoryPriority
        let guidance = descriptor?.memoryPromptGuidance ?? {
            guard priority == .primary else { return nil }
            return "Use the memory context as primary source of truth before calling tools."
        }()

        let guidanceBlock = guidance.flatMap { $0.isEmpty ? nil : $0 }

        if let guidanceBlock {
            return """
            \(baseInstructions)

            \(guidanceBlock)

            \(title):
            \(memoryContext)
            """
        }

        return """
        \(baseInstructions)

        \(title):
        \(memoryContext)
        """
    }

    private func buildPrompt(from history: [ConversationMessage]) -> String {
        history.map(\.formatted).joined(separator: "\n\n")
    }

    // MARK: - Response Generation

    private func generateWithTools(
        provider: any InferenceProvider,
        prompt: String,
        tools: [ToolSchema],
        systemPrompt: String,
        hooks: (any RunHooks)? = nil,
        emitOutputTokens: Bool = false
    ) async throws -> InferenceResponse {
        let options = configuration.inferenceOptions

        // Notify hooks of LLM start
        await hooks?.onLLMStart(context: nil, agent: self, systemPrompt: systemPrompt, inputMessages: [MemoryMessage.user(prompt)])

        let response = try await provider.generateWithToolCalls(
            prompt: prompt,
            tools: tools,
            options: options
        )

        if emitOutputTokens, response.toolCalls.isEmpty, let content = response.content, !content.isEmpty {
            await hooks?.onOutputToken(context: nil, agent: self, token: content)
        }

        // Notify hooks of LLM end
        let responseContent = response.content ?? ""
        await hooks?.onLLMEnd(context: nil, agent: self, response: responseContent, usage: response.usage)

        return response
    }

    private func generateWithToolsStreaming(
        provider: any ToolCallStreamingInferenceProvider,
        prompt: String,
        tools: [ToolSchema],
        systemPrompt: String,
        hooks: (any RunHooks)? = nil
    ) async throws -> InferenceResponse {
        let options = configuration.inferenceOptions

        await hooks?.onLLMStart(context: nil, agent: self, systemPrompt: systemPrompt, inputMessages: [MemoryMessage.user(prompt)])

        var content = ""
        content.reserveCapacity(1024)
        var parsedToolCalls: [InferenceResponse.ParsedToolCall] = []
        var usage: InferenceResponse.TokenUsage?
        var stopStreaming = false

        let stream = provider.streamWithToolCalls(prompt: prompt, tools: tools, options: options)

        for try await update in stream {
            switch update {
            case let .outputChunk(chunk):
                if !chunk.isEmpty { content += chunk }
                await hooks?.onOutputToken(context: nil, agent: self, token: chunk)

            case let .toolCallPartial(partial):
                await hooks?.onToolCallPartial(context: nil, agent: self, update: partial)

            case let .toolCallsCompleted(calls):
                parsedToolCalls = calls
                // Tool call streaming is primarily used to reduce latency to tool execution.
                // Once we have completed calls, stop consuming the stream and execute tools.
                stopStreaming = true

            case let .usage(u):
                usage = u
            }

            if stopStreaming { break }
        }

        await hooks?.onLLMEnd(context: nil, agent: self, response: content, usage: usage)

        return InferenceResponse(
            content: content.isEmpty ? nil : content,
            toolCalls: parsedToolCalls,
            finishReason: parsedToolCalls.isEmpty ? .completed : .toolCall,
            usage: usage
        )
    }
}

// MARK: Agent.Builder

public extension Agent {
    /// Builder for creating Agent instances with a fluent API.
    ///
    /// Uses value semantics (struct) for Swift 6 concurrency safety.
    ///
    /// Example:
    /// ```swift
    /// let agent = Agent.Builder()
    ///     .tools([WeatherTool(), CalculatorTool()])
    ///     .instructions("You are a helpful assistant.")
    ///     .configuration(.default.maxIterations(5))
    ///     .build()
    /// ```
    struct Builder: Sendable {
        // MARK: Public

        // MARK: - Initialization

        /// Creates a new builder.
        public init() {}

        // MARK: - Builder Methods

        /// Sets the tools.
        /// - Parameter tools: The tools to use.
        /// - Returns: A new builder with the tools set.
        @discardableResult
        public func tools(_ tools: [any AnyJSONTool]) -> Builder {
            var copy = self
            copy._tools = tools
            return copy
        }

        /// Sets the tools from typed tool instances.
        /// - Parameter tools: The typed tools to use.
        /// - Returns: A new builder with the tools set.
        @discardableResult
        public func tools(_ tools: [some Tool]) -> Builder {
            var copy = self
            copy._tools = tools.map { AnyJSONToolAdapter($0) }
            return copy
        }

        /// Adds a tool.
        /// - Parameter tool: The tool to add.
        /// - Returns: A new builder with the tool added.
        @discardableResult
        public func addTool(_ tool: any AnyJSONTool) -> Builder {
            var copy = self
            copy._tools.append(tool)
            return copy
        }

        /// Adds a typed tool.
        /// - Parameter tool: The typed tool to add.
        /// - Returns: A new builder with the tool added.
        @discardableResult
        public func addTool(_ tool: some Tool) -> Builder {
            var copy = self
            copy._tools.append(AnyJSONToolAdapter(tool))
            return copy
        }

        /// Adds built-in tools.
        /// - Returns: A new builder with built-in tools added.
        @discardableResult
        public func withBuiltInTools() -> Builder {
            var copy = self
            copy._tools.append(contentsOf: BuiltInTools.all)
            return copy
        }

        /// Sets the instructions.
        /// - Parameter instructions: The system instructions.
        /// - Returns: A new builder with the instructions set.
        @discardableResult
        public func instructions(_ instructions: String) -> Builder {
            var copy = self
            copy._instructions = instructions
            return copy
        }

        /// Sets the configuration.
        /// - Parameter configuration: The agent configuration.
        /// - Returns: A new builder with the configuration set.
        @discardableResult
        public func configuration(_ configuration: AgentConfiguration) -> Builder {
            var copy = self
            copy._configuration = configuration
            return copy
        }

        /// Sets the memory system.
        /// - Parameter memory: The memory to use.
        /// - Returns: A new builder with the memory set.
        @discardableResult
        public func memory(_ memory: any Memory) -> Builder {
            var copy = self
            copy._memory = memory
            return copy
        }

        /// Sets the inference provider.
        /// - Parameter provider: The provider to use.
        /// - Returns: A new builder with the provider set.
        @discardableResult
        public func inferenceProvider(_ provider: any InferenceProvider) -> Builder {
            var copy = self
            copy._inferenceProvider = provider
            return copy
        }

        /// Sets the tracer for observability.
        /// - Parameter tracer: The tracer to use.
        /// - Returns: A new builder with the tracer set.
        @discardableResult
        public func tracer(_ tracer: any Tracer) -> Builder {
            var copy = self
            copy._tracer = tracer
            return copy
        }

        /// Sets the input guardrails.
        /// - Parameter guardrails: The input guardrails to use.
        /// - Returns: A new builder with the guardrails set.
        @discardableResult
        public func inputGuardrails(_ guardrails: [any InputGuardrail]) -> Builder {
            var copy = self
            copy._inputGuardrails = guardrails
            return copy
        }

        /// Adds an input guardrail.
        /// - Parameter guardrail: The guardrail to add.
        /// - Returns: A new builder with the guardrail added.
        @discardableResult
        public func addInputGuardrail(_ guardrail: any InputGuardrail) -> Builder {
            var copy = self
            copy._inputGuardrails.append(guardrail)
            return copy
        }

        /// Sets the output guardrails.
        /// - Parameter guardrails: The output guardrails to use.
        /// - Returns: A new builder with the guardrails set.
        @discardableResult
        public func outputGuardrails(_ guardrails: [any OutputGuardrail]) -> Builder {
            var copy = self
            copy._outputGuardrails = guardrails
            return copy
        }

        /// Adds an output guardrail.
        /// - Parameter guardrail: The guardrail to add.
        /// - Returns: A new builder with the guardrail added.
        @discardableResult
        public func addOutputGuardrail(_ guardrail: any OutputGuardrail) -> Builder {
            var copy = self
            copy._outputGuardrails.append(guardrail)
            return copy
        }

        /// Sets the guardrail runner configuration.
        /// - Parameter configuration: The guardrail runner configuration.
        /// - Returns: A new builder with the updated configuration.
        @discardableResult
        public func guardrailRunnerConfiguration(_ configuration: GuardrailRunnerConfiguration) -> Builder {
            var copy = self
            copy._guardrailRunnerConfiguration = configuration
            return copy
        }

        /// Sets the handoff configurations.
        /// - Parameter handoffs: The handoff configurations to use.
        /// - Returns: A new builder with the updated handoffs.
        @discardableResult
        public func handoffs(_ handoffs: [AnyHandoffConfiguration]) -> Builder {
            var copy = self
            copy._handoffs = handoffs
            return copy
        }

        /// Adds a handoff configuration.
        /// - Parameter handoff: The handoff configuration to add.
        /// - Returns: A new builder with the handoff added.
        @discardableResult
        public func addHandoff(_ handoff: AnyHandoffConfiguration) -> Builder {
            var copy = self
            copy._handoffs.append(handoff)
            return copy
        }

        /// Builds the agent.
        /// - Returns: A new Agent instance.
        public func build() -> Agent {
            Agent(
                tools: _tools,
                instructions: _instructions,
                configuration: _configuration,
                memory: _memory,
                inferenceProvider: _inferenceProvider,
                tracer: _tracer,
                inputGuardrails: _inputGuardrails,
                outputGuardrails: _outputGuardrails,
                guardrailRunnerConfiguration: _guardrailRunnerConfiguration,
                handoffs: _handoffs
            )
        }

        // MARK: Private

        private var _tools: [any AnyJSONTool] = []
        private var _instructions: String = ""
        private var _configuration: AgentConfiguration = .default
        private var _memory: (any Memory)?
        private var _inferenceProvider: (any InferenceProvider)?
        private var _tracer: (any Tracer)?
        private var _inputGuardrails: [any InputGuardrail] = []
        private var _outputGuardrails: [any OutputGuardrail] = []
        private var _guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default
        private var _handoffs: [AnyHandoffConfiguration] = []
    }
}

// MARK: - Agent DSL Extension

public extension Agent {
    /// Creates an Agent using the declarative builder DSL.
    ///
    /// Example:
    /// ```swift
    /// let agent = Agent {
    ///     Instructions("You are a helpful assistant.")
    ///
    ///     Tools {
    ///         WeatherTool()
    ///         CalculatorTool()
    ///     }
    ///
    ///     Configuration(.default.maxIterations(5))
    /// }
    /// ```
    ///
    /// - Parameter content: A closure that builds the agent components.
    /// - Throws: `ToolRegistryError.duplicateToolName` if duplicate tool names are provided.
    init(@LegacyAgentBuilder _ content: () -> LegacyAgentBuilder.Components) throws {
        let components = content()
        try self.init(
            tools: components.tools,
            instructions: components.instructions ?? "",
            configuration: components.configuration ?? .default,
            memory: components.memory,
            inferenceProvider: components.inferenceProvider,
            tracer: components.tracer,
            inputGuardrails: components.inputGuardrails,
            outputGuardrails: components.outputGuardrails,
            guardrailRunnerConfiguration: components.guardrailRunnerConfiguration ?? .default,
            handoffs: components.handoffs
        )
    }
}

// MARK: - Convenience Initializers

public extension Agent {
    /// Creates a new Agent with a name as the first parameter.
    ///
    /// This convenience initializer mirrors the OpenAI Agent SDK pattern
    /// where the agent name is a top-level parameter rather than nested
    /// inside configuration.
    ///
    /// Example:
    /// ```swift
    /// let agent = Agent(name: "Triage", instructions: "Route requests", tools: [weatherTool])
    /// ```
    ///
    /// - Parameters:
    ///   - name: The display name of the agent.
    ///   - instructions: System instructions defining agent behavior. Default: ""
    ///   - tools: Tools available to the agent. Default: []
    ///   - inferenceProvider: Optional custom inference provider. Default: nil
    ///   - memory: Optional memory system. Default: nil
    ///   - tracer: Optional tracer for observability. Default: nil
    ///   - configuration: Additional agent configuration settings. Default: .default
    ///   - inputGuardrails: Input validation guardrails. Default: []
    ///   - outputGuardrails: Output validation guardrails. Default: []
    ///   - guardrailRunnerConfiguration: Configuration for guardrail runner. Default: .default
    ///   - handoffs: Handoff configurations for multi-agent orchestration. Default: []
    /// - Throws: `ToolRegistryError.duplicateToolName` if duplicate tool names are provided.
    init(
        name: String,
        instructions: String = "",
        tools: [any AnyJSONTool] = [],
        inferenceProvider: (any InferenceProvider)? = nil,
        memory: (any Memory)? = nil,
        tracer: (any Tracer)? = nil,
        configuration: AgentConfiguration = .default,
        inputGuardrails: [any InputGuardrail] = [],
        outputGuardrails: [any OutputGuardrail] = [],
        guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default,
        handoffs: [AnyHandoffConfiguration] = []
    ) throws {
        // Merge the name into the configuration
        var config = configuration
        config.name = name
        try self.init(
            tools: tools,
            instructions: instructions,
            configuration: config,
            memory: memory,
            inferenceProvider: inferenceProvider,
            tracer: tracer,
            inputGuardrails: inputGuardrails,
            outputGuardrails: outputGuardrails,
            guardrailRunnerConfiguration: guardrailRunnerConfiguration,
            handoffs: handoffs
        )
    }
}

// MARK: - Simplified Handoff Declaration

public extension Agent {
    /// Creates an Agent with agents directly as handoff targets.
    ///
    /// This convenience initializer eliminates the need to wrap each agent
    /// in `AnyHandoffConfiguration`, inspired by the OpenAI SDK pattern
    /// where you pass agents directly: `Agent(handoffs=[billing, support])`.
    ///
    /// Example:
    /// ```swift
    /// let triage = Agent(
    ///     name: "Triage",
    ///     instructions: "Route requests",
    ///     handoffAgents: [billingAgent, supportAgent]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - name: The display name of the agent.
    ///   - instructions: System instructions. Default: ""
    ///   - tools: Tools available to the agent. Default: []
    ///   - inferenceProvider: Optional inference provider. Default: nil
    ///   - memory: Optional memory system. Default: nil
    ///   - tracer: Optional tracer. Default: nil
    ///   - configuration: Additional configuration. Default: .default
    ///   - inputGuardrails: Input guardrails. Default: []
    ///   - outputGuardrails: Output guardrails. Default: []
    ///   - guardrailRunnerConfiguration: Guardrail runner config. Default: .default
    ///   - handoffAgents: Agents to use as handoff targets.
    /// - Throws: `ToolRegistryError.duplicateToolName` if duplicate tool names are provided.
    init(
        name: String,
        instructions: String = "",
        tools: [any AnyJSONTool] = [],
        inferenceProvider: (any InferenceProvider)? = nil,
        memory: (any Memory)? = nil,
        tracer: (any Tracer)? = nil,
        configuration: AgentConfiguration = .default,
        inputGuardrails: [any InputGuardrail] = [],
        outputGuardrails: [any OutputGuardrail] = [],
        guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default,
        handoffAgents: [any AgentRuntime]
    ) throws {
        let handoffs = handoffAgents.map { agent in
            AnyHandoffConfiguration(targetAgent: agent)
        }
        try self.init(
            name: name,
            instructions: instructions,
            tools: tools,
            inferenceProvider: inferenceProvider,
            memory: memory,
            tracer: tracer,
            configuration: configuration,
            inputGuardrails: inputGuardrails,
            outputGuardrails: outputGuardrails,
            guardrailRunnerConfiguration: guardrailRunnerConfiguration,
            handoffs: handoffs
        )
    }
}
