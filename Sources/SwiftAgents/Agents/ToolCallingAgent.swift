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
    // MARK: - Agent Protocol Properties

    nonisolated public let tools: [any Tool]
    nonisolated public let instructions: String
    nonisolated public let configuration: AgentConfiguration
    nonisolated public let memory: (any Memory)?
    nonisolated public let inferenceProvider: (any InferenceProvider)?
    nonisolated public let inputGuardrails: [any InputGuardrail]
    nonisolated public let outputGuardrails: [any OutputGuardrail]

    // MARK: - Internal State

    private var isCancelled: Bool = false
    private var currentTask: Task<Void, Never>?
    private let toolRegistry: ToolRegistry

    // MARK: - Conversation History

    private enum ConversationMessage: Sendable {
        case system(String)
        case user(String)
        case assistant(String)
        case toolResult(toolName: String, result: String)

        var formatted: String {
            switch self {
            case let .system(content):
                return "[System]: \(content)"
            case let .user(content):
                return "[User]: \(content)"
            case let .assistant(content):
                return "[Assistant]: \(content)"
            case let .toolResult(toolName, result):
                return "[Tool Result - \(toolName)]: \(result)"
            }
        }
    }

    // MARK: - Initialization

    /// Creates a new ToolCallingAgent.
    /// - Parameters:
    ///   - tools: Tools available to the agent. Default: []
    ///   - instructions: System instructions defining agent behavior. Default: ""
    ///   - configuration: Agent configuration settings. Default: .default
    ///   - memory: Optional memory system. Default: nil
    ///   - inferenceProvider: Optional custom inference provider. Default: nil
    ///   - inputGuardrails: Input validation guardrails. Default: []
    ///   - outputGuardrails: Output validation guardrails. Default: []
    public init(
        tools: [any Tool] = [],
        instructions: String = "",
        configuration: AgentConfiguration = .default,
        memory: (any Memory)? = nil,
        inferenceProvider: (any InferenceProvider)? = nil,
        inputGuardrails: [any InputGuardrail] = [],
        outputGuardrails: [any OutputGuardrail] = []
    ) {
        self.tools = tools
        self.instructions = instructions
        self.configuration = configuration
        self.memory = memory
        self.inferenceProvider = inferenceProvider
        self.inputGuardrails = inputGuardrails
        self.outputGuardrails = outputGuardrails
        self.toolRegistry = ToolRegistry(tools: tools)
    }

    // MARK: - Agent Protocol Methods

    /// Executes the agent with the given input and returns a result.
    /// - Parameter input: The user's input/query.
    /// - Returns: The result of the agent's execution.
    /// - Throws: `AgentError` if execution fails, or `GuardrailError` if guardrails trigger.
    public func run(_ input: String) async throws -> AgentResult {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidInput(reason: "Input cannot be empty")
        }

        // Run input guardrails
        let runner = GuardrailRunner()
        _ = try await runner.runInputGuardrails(inputGuardrails, input: input, context: nil)

        isCancelled = false
        let resultBuilder = AgentResult.Builder()
        _ = resultBuilder.start()

        // Store input in memory if available
        if let mem = memory {
            await mem.add(.user(input))
        }

        // Execute the tool calling loop
        let output = try await executeToolCallingLoop(
            input: input,
            resultBuilder: resultBuilder
        )

        _ = resultBuilder.setOutput(output)

        // Run output guardrails BEFORE storing in memory
        try await runner.runOutputGuardrails(outputGuardrails, output: output, agent: self, context: nil)

        // Only store output in memory if validation passed
        if let mem = memory {
            await mem.add(.assistant(output))
        }

        return resultBuilder.build()
    }

    /// Streams the agent's execution, yielding events as they occur.
    /// - Parameter input: The user's input/query.
    /// - Returns: An async stream of agent events.
    nonisolated public func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream(for: self) { agent, continuation in
            continuation.yield(.started(input: input))
            do {
                let result = try await agent.run(input)
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

    // MARK: - Tool Calling Loop Implementation

    private func executeToolCallingLoop(
        input: String,
        resultBuilder: AgentResult.Builder
    ) async throws -> String {
        var iteration = 0
        var conversationHistory: [ConversationMessage] = []
        let startTime = ContinuousClock.now

        // Add system message with instructions
        let systemMessage = buildSystemMessage()
        conversationHistory.append(.system(systemMessage))

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
                let content = try await provider.generate(
                    prompt: prompt,
                    options: InferenceOptions(temperature: configuration.temperature, maxTokens: configuration.maxTokens)
                )
                // Store and return
                if let mem = memory {
                    await mem.add(.assistant(content))
                }
                return content
            }

            // Generate response with tool calls
            let response = try await generateWithTools(
                prompt: prompt,
                tools: toolDefinitions
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
                        let toolOutput = try await toolRegistry.execute(
                            toolNamed: parsedCall.name,
                            arguments: parsedCall.arguments
                        )
                        let duration = ContinuousClock.now - startTime

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
            return "You are a helpful AI assistant with access to tools."
        } else {
            return instructions
        }
    }

    private func buildPrompt(from history: [ConversationMessage]) -> String {
        history.map { $0.formatted }.joined(separator: "\n\n")
    }

    // MARK: - Response Generation

    private func generateWithTools(
        prompt: String,
        tools: [ToolDefinition]
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

        return try await provider.generateWithToolCalls(
            prompt: prompt,
            tools: tools,
            options: options
        )
    }
}

// MARK: - ToolCallingAgent.Builder

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
        // MARK: - Properties

        private var _tools: [any Tool] = []
        private var _instructions: String = ""
        private var _configuration: AgentConfiguration = .default
        private var _memory: (any Memory)?
        private var _inferenceProvider: (any InferenceProvider)?
        private var _inputGuardrails: [any InputGuardrail] = []
        private var _outputGuardrails: [any OutputGuardrail] = []

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

        /// Builds the agent.
        /// - Returns: A new ToolCallingAgent instance.
        public func build() -> ToolCallingAgent {
            ToolCallingAgent(
                tools: _tools,
                instructions: _instructions,
                configuration: _configuration,
                memory: _memory,
                inferenceProvider: _inferenceProvider,
                inputGuardrails: _inputGuardrails,
                outputGuardrails: _outputGuardrails
            )
        }
    }
}
