// ReActAgent.swift
// SwiftAgents Framework
//
// ReAct (Reasoning + Acting) agent implementation.
// Implements the ReAct paradigm for interleaved reasoning and action.

import Foundation

// MARK: - ReActAgent

/// A ReAct (Reasoning + Acting) agent that uses interleaved reasoning and action steps.
///
/// The ReAct paradigm follows a Thought-Action-Observation loop:
/// 1. **Thought**: The agent reasons about the current state and what to do next.
/// 2. **Action**: The agent decides to call a tool or provide a final answer.
/// 3. **Observation**: The result of the tool call is observed and added to context.
///
/// This loop continues until the agent decides to provide a final answer or
/// reaches the maximum iteration limit.
///
/// Example:
/// ```swift
/// let agent = ReActAgent(
///     tools: [CalculatorTool(), DateTimeTool()],
///     instructions: "You are a helpful assistant that can perform calculations."
/// )
///
/// let result = try await agent.run("What's 15% of 200?")
/// print(result.output)  // "30"
/// ```
public actor ReActAgent: Agent {
    // MARK: Public

    // MARK: - Agent Protocol Properties

    nonisolated public let tools: [any Tool]
    nonisolated public let instructions: String
    nonisolated public let configuration: AgentConfiguration
    nonisolated public let memory: (any Memory)?
    nonisolated public let inferenceProvider: (any InferenceProvider)?
    nonisolated public let tracer: (any Tracer)?
    nonisolated public let inputGuardrails: [any InputGuardrail]
    nonisolated public let outputGuardrails: [any OutputGuardrail]
    nonisolated public let guardrailRunnerConfiguration: GuardrailRunnerConfiguration

    /// Configured handoffs for this agent.
    nonisolated public var handoffs: [AnyHandoffConfiguration] { _handoffs }

    // MARK: - Initialization

    /// Creates a new ReActAgent.
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
    ///   - hooks: Optional hooks for observing agent execution events.
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

            // Execute the ReAct loop with session context
            let output = try await executeReActLoop(
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
            await hooks?.onAgentEnd(context: nil, agent: self, result: result)
            return result
        } catch {
            await hooks?.onError(context: nil, agent: self, error: error)
            throw error
        }
    }

    /// Streams the agent's execution, yielding events as they occur.
    /// - Parameters:
    ///   - input: The user's input/query.
    ///   - session: Optional session for conversation history management.
    ///   - hooks: Optional hooks for observing agent execution events.
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

    // MARK: - Response Parsing

    private enum ParsedResponse {
        case finalAnswer(String)
        case toolCall(name: String, arguments: [String: SendableValue])
        case thinking(String)
        case invalid(String)
    }

    private let _handoffs: [AnyHandoffConfiguration]

    // MARK: - Internal State

    private var currentTask: Task<Void, Never>?
    private var isCancelled: Bool = false
    private let toolRegistry: ToolRegistry

    // MARK: - ReAct Loop Implementation

    private func executeReActLoop(
        input: String,
        sessionHistory: [MemoryMessage] = [],
        resultBuilder: AgentResult.Builder,
        hooks: (any RunHooks)? = nil
    ) async throws -> String {
        var iteration = 0
        var scratchpad = "" // Accumulates Thought-Action-Observation history
        let startTime = ContinuousClock.now

        while iteration < configuration.maxIterations {
            // Check for cancellation
            try Task.checkCancellation()
            if isCancelled {
                throw AgentError.cancelled
            }

            // Check timeout
            let elapsed = ContinuousClock.now - startTime
            if elapsed > configuration.timeout {
                throw AgentError.timeout(duration: configuration.timeout)
            }

            iteration += 1
            _ = resultBuilder.incrementIteration()

            // Step 1: Build prompt with current context
            let prompt = buildPrompt(
                input: input,
                sessionHistory: sessionHistory,
                scratchpad: scratchpad,
                iteration: iteration
            )

            // Step 2: Generate response from model
            await hooks?.onLLMStart(context: nil, agent: self, systemPrompt: instructions, inputMessages: [MemoryMessage.user(prompt)])
            let response = try await generateResponse(prompt: prompt)
            await hooks?.onLLMEnd(context: nil, agent: self, response: response, usage: nil)

            // Step 3: Parse the response
            let parsed = parseResponse(response)

            switch parsed {
            case let .finalAnswer(answer):
                // Agent has decided on a final answer
                return answer

            case let .toolCall(toolName, arguments):
                // Agent wants to call a tool
                let toolCall = ToolCall(
                    toolName: toolName,
                    arguments: arguments
                )
                _ = resultBuilder.addToolCall(toolCall)

                // Step 4: Execute the tool
                let startTime = ContinuousClock.now
                do {
                    // Notify hooks before tool execution
                    if let tool = await toolRegistry.tool(named: toolName) {
                        await hooks?.onToolStart(context: nil, agent: self, tool: tool, arguments: arguments)
                    }

                    let toolResult = try await toolRegistry.execute(
                        toolNamed: toolName,
                        arguments: arguments,
                        agent: self,
                        context: nil
                    )
                    let duration = ContinuousClock.now - startTime

                    let result = ToolResult.success(
                        callId: toolCall.id,
                        output: toolResult,
                        duration: duration
                    )
                    _ = resultBuilder.addToolResult(result)

                    // Notify hooks after successful tool execution
                    if let tool = await toolRegistry.tool(named: toolName) {
                        await hooks?.onToolEnd(context: nil, agent: self, tool: tool, result: toolResult)
                    }

                    // Add to scratchpad
                    scratchpad += """

                    Thought: I need to use the \(toolName) tool.
                    Action: \(toolName)(\(formatArguments(arguments)))
                    Observation: \(toolResult.description)
                    """

                } catch {
                    let duration = ContinuousClock.now - startTime
                    let errorMessage = (error as? AgentError)?.localizedDescription ?? error.localizedDescription

                    let result = ToolResult.failure(
                        callId: toolCall.id,
                        error: errorMessage,
                        duration: duration
                    )
                    _ = resultBuilder.addToolResult(result)

                    // Add error to scratchpad
                    scratchpad += """

                    Thought: I need to use the \(toolName) tool.
                    Action: \(toolName)(\(formatArguments(arguments)))
                    Observation: Error - \(errorMessage)
                    """

                    if configuration.stopOnToolError {
                        throw AgentError.toolExecutionFailed(
                            toolName: toolName,
                            underlyingError: errorMessage
                        )
                    }
                }

            case let .thinking(thought):
                // Agent is just thinking, continue
                scratchpad += "\nThought: \(thought)"

            case let .invalid(raw):
                // Couldn't parse response, treat as thinking
                scratchpad += "\nThought: \(raw)"
            }
        }

        // Exceeded max iterations
        throw AgentError.maxIterationsExceeded(iterations: iteration)
    }

    // MARK: - Prompt Building

    private func buildPrompt(
        input: String,
        sessionHistory: [MemoryMessage] = [],
        scratchpad: String,
        iteration _: Int
    ) -> String {
        let toolDescriptions = buildToolDescriptions()
        let conversationContext = buildConversationContext(from: sessionHistory)

        let basePrompt = """
        \(instructions.isEmpty ? "You are a helpful AI assistant." : instructions)

        You are a ReAct agent that solves problems by interleaving Thought, Action, and Observation steps.

        \(toolDescriptions.isEmpty ? "No tools are available." : "Available Tools:\n\(toolDescriptions)")

        Format your response EXACTLY as follows:
        - To reason: Start with "Thought:" followed by your reasoning about what to do next.
        - To use a tool: Write "Action: tool_name(arg1: value1, arg2: value2)"
        - To give your final answer: Write "Final Answer:" followed by your complete response to the user.

        Rules:
        1. Always start with a Thought to reason about the problem.
        2. After an Observation, decide if you need another Action or can give the Final Answer.
        3. Only use tools that are available in the list above.
        4. When you have enough information, provide the Final Answer.
        \(conversationContext.isEmpty ? "" : "\nConversation History:\n\(conversationContext)")

        User Query: \(input)
        """

        if scratchpad.isEmpty {
            return basePrompt + "\n\nBegin with your first Thought:"
        } else {
            return basePrompt + "\n\nPrevious steps:" + scratchpad + "\n\nContinue with your next step:"
        }
    }

    private func buildConversationContext(from sessionHistory: [MemoryMessage]) -> String {
        guard !sessionHistory.isEmpty else { return "" }

        var lines: [String] = []
        for message in sessionHistory {
            switch message.role {
            case .user:
                lines.append("User: \(message.content)")
            case .assistant:
                lines.append("Assistant: \(message.content)")
            case .system:
                lines.append("System: \(message.content)")
            case .tool:
                lines.append("Tool: \(message.content)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func buildToolDescriptions() -> String {
        var descriptions: [String] = []
        for tool in tools {
            let toolDesc = formatToolDescription(tool)
            descriptions.append(toolDesc)
        }
        return descriptions.joined(separator: "\n\n")
    }

    private func formatToolDescription(_ tool: any Tool) -> String {
        let params = formatParameterDescriptions(tool.parameters)
        if params.isEmpty {
            return "- \(tool.name): \(tool.description)"
        } else {
            return "- \(tool.name): \(tool.description)\n  Parameters:\n\(params)"
        }
    }

    private func formatParameterDescriptions(_ parameters: [ToolParameter]) -> String {
        var lines: [String] = []
        for param in parameters {
            let name = param.name
            let desc = param.description
            let required = param.isRequired
            let reqStr = required ? "(required)" : "(optional)"
            let line = "    - " + name + " " + reqStr + ": " + desc
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Response Generation

    private func generateResponse(prompt: String) async throws -> String {
        // Use custom inference provider if available
        if let provider = inferenceProvider {
            let options = InferenceOptions(
                temperature: configuration.temperature,
                maxTokens: configuration.maxTokens
            )
            return try await provider.generate(prompt: prompt, options: options)
        }

        // Foundation Models is not available in this context
        // Throw an error indicating an inference provider is required
        throw AgentError.inferenceProviderUnavailable(
            reason: "No inference provider configured. Please provide an InferenceProvider."
        )
    }

    private func parseResponse(_ response: String) -> ParsedResponse {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for final answer
        if let finalAnswerRange = trimmed.range(of: "Final Answer:", options: .caseInsensitive) {
            let answer = String(trimmed[finalAnswerRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .finalAnswer(answer)
        }

        // Check for action/tool call
        if let actionRange = trimmed.range(of: "Action:", options: .caseInsensitive) {
            let actionPart = String(trimmed[actionRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")
                .first ?? ""

            if let parsed = parseToolCall(actionPart) {
                return .toolCall(name: parsed.name, arguments: parsed.arguments)
            }
        }

        // Check for thought
        if let thoughtRange = trimmed.range(of: "Thought:", options: .caseInsensitive) {
            var thought = String(trimmed[thoughtRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Stop at next section marker if present
            if let nextMarker = thought.range(of: "Action:", options: .caseInsensitive) {
                thought = String(thought[..<nextMarker.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let nextMarker = thought.range(of: "Final Answer:", options: .caseInsensitive) {
                thought = String(thought[..<nextMarker.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            return .thinking(thought)
        }

        // Couldn't parse - treat as thinking
        return .invalid(trimmed)
    }

    private func parseToolCall(_ text: String) -> (name: String, arguments: [String: SendableValue])? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse format: tool_name(arg1: value1, arg2: value2)
        guard let parenStart = trimmed.firstIndex(of: "("),
              let parenEnd = trimmed.lastIndex(of: ")") else {
            // Try simple format: tool_name with no args
            let name = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, !name.contains(" "), !name.contains(":") {
                return (name: name, arguments: [:])
            }
            return nil
        }

        let name = String(trimmed[..<parenStart]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let argsString = String(trimmed[trimmed.index(after: parenStart)..<parenEnd])

        var arguments: [String: SendableValue] = [:]

        // Parse arguments
        let argPairs = splitArguments(argsString)
        for pair in argPairs {
            let parts = pair.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let valueStr = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse value
            let value = parseValue(valueStr)
            arguments[key] = value
        }

        return (name: name, arguments: arguments)
    }

    /// Splits argument string by comma, respecting quotes and nested structures.
    private func splitArguments(_ str: String) -> [String] {
        var result: [String] = []
        var current = ""
        var depth = 0
        var inQuote = false
        var quoteChar: Character = "\""

        for char in str {
            if !inQuote, char == "\"" || char == "'" {
                inQuote = true
                quoteChar = char
                current.append(char)
            } else if inQuote, char == quoteChar {
                inQuote = false
                current.append(char)
            } else if !inQuote, char == "(" || char == "[" || char == "{" {
                depth += 1
                current.append(char)
            } else if !inQuote, char == ")" || char == "]" || char == "}" {
                depth -= 1
                current.append(char)
            } else if !inQuote, depth == 0, char == "," {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }

        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            result.append(current.trimmingCharacters(in: .whitespaces))
        }

        return result
    }

    private func parseValue(_ valueStr: String) -> SendableValue {
        let trimmed = valueStr.trimmingCharacters(in: .whitespacesAndNewlines)

        // Null
        if trimmed.lowercased() == "null" || trimmed.lowercased() == "nil" {
            return .null
        }

        // Boolean
        if trimmed.lowercased() == "true" { return .bool(true) }
        if trimmed.lowercased() == "false" { return .bool(false) }

        // Number
        if let intValue = Int(trimmed) { return .int(intValue) }
        if let doubleValue = Double(trimmed) { return .double(doubleValue) }

        // String (remove quotes if present)
        var str = trimmed
        if (str.hasPrefix("\"") && str.hasSuffix("\"")) ||
            (str.hasPrefix("'") && str.hasSuffix("'")) {
            str = String(str.dropFirst().dropLast())
        }
        return .string(str)
    }

    private func formatArguments(_ arguments: [String: SendableValue]) -> String {
        arguments.map { "\($0.key): \($0.value.description)" }.joined(separator: ", ")
    }
}

// MARK: ReActAgent.Builder

public extension ReActAgent {
    /// Builder for creating ReActAgent instances with a fluent API.
    /// Uses value semantics (struct) for Swift 6 concurrency safety.
    ///
    /// Example:
    /// ```swift
    /// let agent = ReActAgent.Builder()
    ///     .tools([CalculatorTool()])
    ///     .instructions("You are a math assistant.")
    ///     .configuration(.default.maxIterations(5))
    ///     .build()
    /// ```
    struct Builder: Sendable {
        // MARK: Public

        /// Creates a new builder.
        public init() {
            tools = []
            instructions = ""
            configuration = .default
            memory = nil
            inferenceProvider = nil
            tracer = nil
            inputGuardrails = []
            outputGuardrails = []
        }

        /// Sets the tools.
        /// - Parameter tools: The tools to use.
        /// - Returns: A new builder with the updated tools.
        @discardableResult
        public func tools(_ tools: [any Tool]) -> Builder {
            var copy = self
            copy.tools = tools
            return copy
        }

        /// Adds a tool.
        /// - Parameter tool: The tool to add.
        /// - Returns: A new builder with the tool added.
        @discardableResult
        public func addTool(_ tool: any Tool) -> Builder {
            var copy = self
            copy.tools.append(tool)
            return copy
        }

        /// Adds built-in tools.
        /// - Returns: A new builder with built-in tools added.
        @discardableResult
        public func withBuiltInTools() -> Builder {
            var copy = self
            copy.tools.append(contentsOf: BuiltInTools.all)
            return copy
        }

        /// Sets the instructions.
        /// - Parameter instructions: The system instructions.
        /// - Returns: A new builder with the updated instructions.
        @discardableResult
        public func instructions(_ instructions: String) -> Builder {
            var copy = self
            copy.instructions = instructions
            return copy
        }

        /// Sets the configuration.
        /// - Parameter configuration: The agent configuration.
        /// - Returns: A new builder with the updated configuration.
        @discardableResult
        public func configuration(_ configuration: AgentConfiguration) -> Builder {
            var copy = self
            copy.configuration = configuration
            return copy
        }

        /// Sets the memory system.
        /// - Parameter memory: The memory to use.
        /// - Returns: A new builder with the updated memory.
        @discardableResult
        public func memory(_ memory: any Memory) -> Builder {
            var copy = self
            copy.memory = memory
            return copy
        }

        /// Sets the inference provider.
        /// - Parameter provider: The provider to use.
        /// - Returns: A new builder with the updated provider.
        @discardableResult
        public func inferenceProvider(_ provider: any InferenceProvider) -> Builder {
            var copy = self
            copy.inferenceProvider = provider
            return copy
        }

        /// Sets the tracer for observability.
        /// - Parameter tracer: The tracer to use.
        /// - Returns: A new builder with the updated tracer.
        @discardableResult
        public func tracer(_ tracer: any Tracer) -> Builder {
            var copy = self
            copy.tracer = tracer
            return copy
        }

        /// Sets the input guardrails.
        /// - Parameter guardrails: The input guardrails to use.
        /// - Returns: A new builder with the updated guardrails.
        @discardableResult
        public func inputGuardrails(_ guardrails: [any InputGuardrail]) -> Builder {
            var copy = self
            copy.inputGuardrails = guardrails
            return copy
        }

        /// Adds an input guardrail.
        /// - Parameter guardrail: The guardrail to add.
        /// - Returns: A new builder with the guardrail added.
        @discardableResult
        public func addInputGuardrail(_ guardrail: any InputGuardrail) -> Builder {
            var copy = self
            copy.inputGuardrails.append(guardrail)
            return copy
        }

        /// Sets the output guardrails.
        /// - Parameter guardrails: The output guardrails to use.
        /// - Returns: A new builder with the updated guardrails.
        @discardableResult
        public func outputGuardrails(_ guardrails: [any OutputGuardrail]) -> Builder {
            var copy = self
            copy.outputGuardrails = guardrails
            return copy
        }

        /// Adds an output guardrail.
        /// - Parameter guardrail: The guardrail to add.
        /// - Returns: A new builder with the guardrail added.
        @discardableResult
        public func addOutputGuardrail(_ guardrail: any OutputGuardrail) -> Builder {
            var copy = self
            copy.outputGuardrails.append(guardrail)
            return copy
        }

        /// Sets the guardrail runner configuration.
        /// - Parameter configuration: The guardrail runner configuration.
        /// - Returns: A new builder with the updated configuration.
        @discardableResult
        public func guardrailRunnerConfiguration(_ configuration: GuardrailRunnerConfiguration) -> Builder {
            var copy = self
            copy.guardrailRunnerConfiguration = configuration
            return copy
        }

        /// Sets the handoff configurations.
        /// - Parameter handoffs: The handoff configurations to use.
        /// - Returns: A new builder with the updated handoffs.
        @discardableResult
        public func handoffs(_ handoffs: [AnyHandoffConfiguration]) -> Builder {
            var copy = self
            copy.handoffs = handoffs
            return copy
        }

        /// Adds a handoff configuration.
        /// - Parameter handoff: The handoff configuration to add.
        /// - Returns: A new builder with the handoff added.
        @discardableResult
        public func addHandoff(_ handoff: AnyHandoffConfiguration) -> Builder {
            var copy = self
            copy.handoffs.append(handoff)
            return copy
        }

        /// Builds the agent.
        /// - Returns: A new ReActAgent instance.
        public func build() -> ReActAgent {
            ReActAgent(
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

        // MARK: Private

        private var tools: [any Tool]
        private var instructions: String
        private var configuration: AgentConfiguration
        private var memory: (any Memory)?
        private var inferenceProvider: (any InferenceProvider)?
        private var tracer: (any Tracer)?
        private var inputGuardrails: [any InputGuardrail]
        private var outputGuardrails: [any OutputGuardrail]
        private var guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default
        private var handoffs: [AnyHandoffConfiguration] = []
    }
}
