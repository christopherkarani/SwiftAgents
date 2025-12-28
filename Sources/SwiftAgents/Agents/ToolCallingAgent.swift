// ToolCallingAgent.swift
// SwiftAgents Framework
//
// Tool-calling agent that uses structured LLM tool calling APIs.

import Foundation

// MARK: - ToolCallingAgent

/// An agent that uses structured LLM tool calling APIs for reliable tool invocation.
///
/// Unlike ReActAgent which parses tool calls from text output, ToolCallingAgent
/// leverages the LLM's native tool calling capabilities via `generateWithToolCalls()`
/// for more reliable and type-safe tool invocation.
///
/// The agent follows a loop-based execution pattern:
/// 1. Build prompt with system instructions + conversation history
/// 2. Call provider with tool definitions
/// 3. If tool calls requested, execute each tool and add results to history
/// 4. If no tool calls, return content as final answer
/// 5. Repeat until done or max iterations reached
///
/// Example:
/// ```swift
/// let agent = ToolCallingAgent(
///     tools: [WeatherTool(), CalculatorTool()],
///     instructions: "You are a helpful assistant with access to tools."
/// )
///
/// let result = try await agent.run("What's the weather in Tokyo?")
/// print(result.output)
/// ```
public actor ToolCallingAgent: Agent {
    // MARK: Public

    // MARK: - Agent Protocol Properties

    nonisolated public let tools: [any Tool]
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

    /// Creates a new ToolCallingAgent.
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
        tools: [any Tool] = [],
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

        // Notify hooks of agent start
        await hooks?.onAgentStart(context: nil, agent: self, input: input)

        do {
            // Run input guardrails
            let runner = GuardrailRunner(configuration: guardrailRunnerConfiguration)
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
            if let mem = memory {
                // Add session history to memory
                for msg in sessionHistory {
                    await mem.add(msg)
                }
                await mem.add(userMessage)
            }

            // Execute the tool calling loop with session context
            let output = try await executeToolCallingLoop(
                input: input,
                sessionHistory: sessionHistory,
                resultBuilder: resultBuilder,
                hooks: hooks
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
            if let mem = memory {
                await mem.add(.assistant(output))
            }

            let result = resultBuilder.build()

            // Notify hooks of agent completion
            await hooks?.onAgentEnd(context: nil, agent: self, result: result)

            return result
        } catch {
            // Notify hooks of error
            await hooks?.onError(context: nil, agent: self, error: error)
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
            continuation.yield(.started(input: input))
            do {
                let result = try await agent.run(input, session: session, hooks: hooks)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch let error as AgentError {
                continuation.yield(.failed(error: error))
                continuation.finish(throwing: error)
            } catch {
                let agentError = AgentError.internalError(reason: error.localizedDescription)
                continuation.yield(.failed(error: agentError))
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

    // MARK: - Tool Calling Loop Implementation

    private func executeToolCallingLoop(
        input: String,
        sessionHistory: [MemoryMessage] = [],
        resultBuilder: AgentResult.Builder,
        hooks: (any RunHooks)? = nil
    ) async throws -> String {
        var iteration = 0
        var conversationHistory: [ConversationMessage] = []
        let startTime = ContinuousClock.now

        // Add system message with instructions
        let systemMessage = buildSystemMessage()
        conversationHistory.append(.system(systemMessage))

        // Add session history as conversation context
        for msg in sessionHistory {
            switch msg.role {
            case .user:
                conversationHistory.append(.user(msg.content))
            case .assistant:
                conversationHistory.append(.assistant(msg.content))
            case .system:
                conversationHistory.append(.system(msg.content))
            case .tool:
                conversationHistory.append(.toolResult(toolName: "previous", result: msg.content))
            }
        }

        // Add user input
        conversationHistory.append(.user(input))

        while iteration < configuration.maxIterations {
            iteration += 1
            _ = resultBuilder.incrementIteration()

            try Task.checkCancellation()
            if isCancelled {
                throw AgentError.cancelled
            }

            // Check timeout
            let elapsed = ContinuousClock.now - startTime
            if elapsed > configuration.timeout {
                throw AgentError.timeout(duration: configuration.timeout)
            }

            // Build prompt from conversation history
            let prompt = buildPrompt(from: conversationHistory)

            // Get tool definitions
            let toolDefinitions = await toolRegistry.definitions

            // If no tools defined, just generate normally without tool calling
            if toolDefinitions.isEmpty {
                guard let provider = inferenceProvider else {
                    throw AgentError.inferenceProviderUnavailable(reason: "No inference provider configured.")
                }

                // Notify hooks of LLM start
                await hooks?.onLLMStart(context: nil, agent: self, systemPrompt: systemMessage, inputMessages: [MemoryMessage.user(prompt)])

                let content = try await provider.generate(
                    prompt: prompt,
                    options: InferenceOptions(temperature: configuration.temperature, maxTokens: configuration.maxTokens)
                )

                // Notify hooks of LLM end
                await hooks?.onLLMEnd(context: nil, agent: self, response: content, usage: nil)

                // Return content - memory storage handled by run() after guardrails
                return content
            }

            // Generate response with tool calls
            let response = try await generateWithTools(
                prompt: prompt,
                tools: toolDefinitions,
                systemPrompt: systemMessage,
                hooks: hooks
            )

            // Check if model wants to call tools
            if response.hasToolCalls {
                // ALWAYS add assistant message indicating tool call intent BEFORE executing tools
                let toolCallSummary = response.toolCalls.map { "Calling tool: \($0.name)" }.joined(separator: ", ")
                let assistantMessage = response.content ?? toolCallSummary
                conversationHistory.append(.assistant(assistantMessage))

                // Execute each tool call
                for parsedCall in response.toolCalls {
                    let toolCall = ToolCall(
                        toolName: parsedCall.name,
                        arguments: parsedCall.arguments
                    )
                    _ = resultBuilder.addToolCall(toolCall)

                    let startTime = ContinuousClock.now
                    do {
                        // Get the tool for hook notification
                        if let tool = await toolRegistry.tool(named: parsedCall.name) {
                            // Notify hooks of tool start
                            await hooks?.onToolStart(context: nil, agent: self, tool: tool, arguments: parsedCall.arguments)
                        }

                        let toolOutput = try await toolRegistry.execute(
                            toolNamed: parsedCall.name,
                            arguments: parsedCall.arguments,
                            agent: self,
                            context: nil
                        )
                        let duration = ContinuousClock.now - startTime

                        // Notify hooks of tool end
                        if let tool = await toolRegistry.tool(named: parsedCall.name) {
                            await hooks?.onToolEnd(context: nil, agent: self, tool: tool, result: toolOutput)
                        }

                        let result = ToolResult.success(
                            callId: toolCall.id,
                            output: toolOutput,
                            duration: duration
                        )
                        _ = resultBuilder.addToolResult(result)

                        // Add tool result to conversation history
                        conversationHistory.append(.toolResult(
                            toolName: parsedCall.name,
                            result: toolOutput.description
                        ))

                    } catch {
                        let duration = ContinuousClock.now - startTime
                        let errorMessage = (error as? AgentError)?.localizedDescription ?? error.localizedDescription

                        let result = ToolResult.failure(
                            callId: toolCall.id,
                            error: errorMessage,
                            duration: duration
                        )
                        _ = resultBuilder.addToolResult(result)

                        // Add error to conversation history
                        conversationHistory.append(.toolResult(
                            toolName: parsedCall.name,
                            result: "[TOOL ERROR] Execution failed: \(errorMessage). Please try a different approach or tool."
                        ))

                        if configuration.stopOnToolError {
                            throw AgentError.toolExecutionFailed(
                                toolName: parsedCall.name,
                                underlyingError: errorMessage
                            )
                        }
                    }
                }

            } else {
                // No tool calls - return final answer
                if let content = response.content {
                    return content
                } else {
                    throw AgentError.generationFailed(reason: "Model returned no content or tool calls")
                }
            }
        }

        throw AgentError.maxIterationsExceeded(iterations: iteration)
    }

    // MARK: - Prompt Building

    private func buildSystemMessage() -> String {
        if instructions.isEmpty {
            "You are a helpful AI assistant with access to tools."
        } else {
            instructions
        }
    }

    private func buildPrompt(from history: [ConversationMessage]) -> String {
        history.map(\.formatted).joined(separator: "\n\n")
    }

    // MARK: - Response Generation

    private func generateWithTools(
        prompt: String,
        tools: [ToolDefinition],
        systemPrompt: String,
        hooks: (any RunHooks)? = nil
    ) async throws -> InferenceResponse {
        guard let provider = inferenceProvider else {
            throw AgentError.inferenceProviderUnavailable(
                reason: "No inference provider configured. Please provide an InferenceProvider."
            )
        }

        let options = InferenceOptions(
            temperature: configuration.temperature,
            maxTokens: configuration.maxTokens
        )

        // Notify hooks of LLM start
        await hooks?.onLLMStart(context: nil, agent: self, systemPrompt: systemPrompt, inputMessages: [MemoryMessage.user(prompt)])

        let response = try await provider.generateWithToolCalls(
            prompt: prompt,
            tools: tools,
            options: options
        )

        // Notify hooks of LLM end
        let responseContent = response.content ?? ""
        await hooks?.onLLMEnd(context: nil, agent: self, response: responseContent, usage: response.usage)

        return response
    }
}

// MARK: ToolCallingAgent.Builder

public extension ToolCallingAgent {
    /// Builder for creating ToolCallingAgent instances with a fluent API.
    ///
    /// Uses value semantics (struct) for Swift 6 concurrency safety.
    ///
    /// Example:
    /// ```swift
    /// let agent = ToolCallingAgent.Builder()
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
        public func tools(_ tools: [any Tool]) -> Builder {
            var copy = self
            copy._tools = tools
            return copy
        }

        /// Adds a tool.
        /// - Parameter tool: The tool to add.
        /// - Returns: A new builder with the tool added.
        @discardableResult
        public func addTool(_ tool: any Tool) -> Builder {
            var copy = self
            copy._tools.append(tool)
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
        /// - Returns: A new ToolCallingAgent instance.
        public func build() -> ToolCallingAgent {
            ToolCallingAgent(
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

        private var _tools: [any Tool] = []
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

// MARK: - ToolCallingAgent DSL Extension

public extension ToolCallingAgent {
    /// Creates a ToolCallingAgent using the declarative builder DSL.
    ///
    /// Example:
    /// ```swift
    /// let agent = ToolCallingAgent {
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
    init(@AgentBuilder _ content: () -> AgentBuilder.Components) {
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
