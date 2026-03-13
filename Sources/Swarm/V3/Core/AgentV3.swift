import Foundation

/// V3 agent type with modifier chain API. Struct (value type), ONE init.
///
/// ```swift
/// let agent = AgentV3("You are a helpful assistant.") {
///     SearchTool()
///     CalculatorTool()
/// }
/// .named("assistant")
/// .options(.precise)
/// .memory(.conversation(limit: 50))
/// .provider(myProvider)
/// ```
///
/// Note: Coexists with the primary `Agent` struct during migration.
/// Will replace `Agent` once all callers are migrated.
public struct AgentV3: Sendable {
    public let instructions: String
    public let tools: [any ToolV3]
    public let name: String
    public let options: RunOptions
    public let memoryOption: MemoryOption
    public let guardrails: [GuardrailSpec]
    public let handoffAgents: [AgentV3]
    let _provider: (any InferenceProvider)?

    /// Create an agent. This is the ONLY public init.
    public init(
        _ instructions: String,
        @ToolV3Builder tools: () -> [any ToolV3] = { [] }
    ) {
        self.instructions = instructions
        self.tools = tools()
        self.name = "agent"
        self.options = .default
        self.memoryOption = .none
        self.guardrails = []
        self.handoffAgents = []
        self._provider = nil
    }

    // Internal memberwise init for modifier chain
    init(
        instructions: String,
        tools: [any ToolV3],
        name: String,
        options: RunOptions,
        memoryOption: MemoryOption,
        guardrails: [GuardrailSpec],
        handoffAgents: [AgentV3],
        provider: (any InferenceProvider)?
    ) {
        self.instructions = instructions
        self.tools = tools
        self.name = name
        self.options = options
        self.memoryOption = memoryOption
        self.guardrails = guardrails
        self.handoffAgents = handoffAgents
        self._provider = provider
    }
}

// MARK: - Modifier Chain

extension AgentV3 {
    public func named(_ name: String) -> AgentV3 {
        AgentV3(
            instructions: instructions, tools: tools, name: name,
            options: options, memoryOption: memoryOption, guardrails: guardrails,
            handoffAgents: handoffAgents, provider: _provider
        )
    }

    public func options(_ options: RunOptions) -> AgentV3 {
        AgentV3(
            instructions: instructions, tools: tools, name: name,
            options: options, memoryOption: memoryOption, guardrails: guardrails,
            handoffAgents: handoffAgents, provider: _provider
        )
    }

    public func memory(_ memory: MemoryOption) -> AgentV3 {
        AgentV3(
            instructions: instructions, tools: tools, name: name,
            options: options, memoryOption: memory, guardrails: guardrails,
            handoffAgents: handoffAgents, provider: _provider
        )
    }

    public func guardrails(_ guardrails: GuardrailSpec...) -> AgentV3 {
        AgentV3(
            instructions: instructions, tools: tools, name: name,
            options: options, memoryOption: memoryOption, guardrails: guardrails,
            handoffAgents: handoffAgents, provider: _provider
        )
    }

    public func handoffs(_ agents: AgentV3...) -> AgentV3 {
        AgentV3(
            instructions: instructions, tools: tools, name: name,
            options: options, memoryOption: memoryOption, guardrails: guardrails,
            handoffAgents: agents, provider: _provider
        )
    }

    public func provider(_ provider: some InferenceProvider) -> AgentV3 {
        AgentV3(
            instructions: instructions, tools: tools, name: name,
            options: options, memoryOption: memoryOption, guardrails: guardrails,
            handoffAgents: handoffAgents, provider: provider
        )
    }
}

// MARK: - Execution (Bridge to Agent struct)

extension AgentV3 {
    /// Run the agent with the given input. Returns the final result.
    public func run(_ input: String) async throws -> AgentResult {
        let runtime = try makeRuntime()
        return try await runtime.run(input)
    }

    /// Stream agent events as they occur.
    public func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        guard let runtime = try? makeRuntime() else {
            return AsyncThrowingStream { $0.finish(throwing: AgentError.internalError(reason: "Failed to create runtime")) }
        }
        return runtime.stream(input)
    }

    /// Bridge: creates an `Agent` struct from V3 config.
    func makeRuntime() throws -> Agent {
        let config = AgentConfiguration(
            name: name,
            maxIterations: options.maxIterations,
            temperature: options.temperature,
            maxTokens: options.maxTokens
        )

        return try Agent(
            tools: tools.map { $0.toAnyJSONTool() },
            instructions: instructions,
            configuration: config,
            memory: memoryOption.makeMemory(),
            inferenceProvider: _provider
        )
    }
}
