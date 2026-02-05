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
    nonisolated public var handoffs: [AnyHandoffConfiguration] { _handoffs }

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
    ) {
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
        toolRegistry = ToolRegistry(tools: tools)
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
    ) {
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
    ) {
        let bridged = tools.map { AnyJSONToolAdapter($0) }
        self.init(
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

        let activeTracer = tracer ?? AgentEnvironmentValues.current.tracer
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

            // Store in memory (for AI context) if available
            if let mem = activeMemory {
                // Seed session history only once for a fresh memory instance.
                if session != nil, await mem.isEmpty, !sessionHistory.isEmpty {
                    for msg in sessionHistory {
                        await mem.add(msg)
                    }
                }
                await mem.add(userMessage)
            }

            // Execute the tool calling loop with session context
            let output = try await executeToolCallingLoop(
                input: input,
                sessionHistory: sessionHistory,
                resultBuilder: resultBuilder,
                hooks: hooks,
                tracing: tracing
            )

            _ = resultBuilder.setOutput(output)

            // Run output guardrails BEFORE storing in memory/session
            _ = try await runner.runOutputGuardrails(outputGuardrails, output: output, agent: self, context: nil)

            // Store turn in session (user + assistant messages)
            if let session {
                let assistantMessage = MemoryMessage.assistant(output)
                try await session.addItems([userMessage, assistantMessage])
            }

            // Only store output in memory if validation passed
            if let mem = activeMemory {
                await mem.add(.assistant(output))
            }

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
            let combinedHooks: any RunHooks
            if let userHooks = hooks {
                combinedHooks = CompositeRunHooks(hooks: [userHooks, streamHooks])
            } else {
                combinedHooks = streamHooks
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
            let toolSchemas = await toolRegistry.schemas

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
                try await processToolCalls(
                    response: response,
                    conversationHistory: &conversationHistory,
                    resultBuilder: resultBuilder,
                    hooks: hooks,
                    tracing: tracing
                )
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
        public func tools<T: Tool>(_ tools: [T]) -> Builder {
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
        public func addTool<T: Tool>(_ tool: T) -> Builder {
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
    init(@LegacyAgentBuilder _ content: () -> LegacyAgentBuilder.Components) {
        let components = content()
        self.init(
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
