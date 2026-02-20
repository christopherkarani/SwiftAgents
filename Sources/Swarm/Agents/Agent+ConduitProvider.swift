// Agent+ConduitProvider.swift
// Swarm Framework
//
// Convenience initializers that enable dot-shorthand provider syntax:
//   Agent(name: "x", instructions: "...", provider: .anthropic(apiKey: "..."))

extension Agent {

    /// Creates a named agent backed by a Conduit inference provider.
    ///
    /// Using a concrete `ConduitProviderSelection` parameter enables Swift's
    /// dot-shorthand syntax at the call site:
    /// ```swift
    /// let agent = Agent(
    ///     name: "stellar-agent",
    ///     instructions: "You are a Stellar blockchain assistant.",
    ///     tools: kit.tools(),
    ///     provider: .anthropic(apiKey: "sk-ant-...")
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - name: The display name of the agent.
    ///   - instructions: System instructions defining agent behavior. Default: ""
    ///   - tools: Tools available to the agent. Default: []
    ///   - provider: A `ConduitProviderSelection` value (e.g. `.anthropic(apiKey:)`).
    ///   - memory: Optional memory system. Default: nil
    ///   - tracer: Optional tracer for observability. Default: nil
    ///   - configuration: Agent configuration settings. Default: .default
    ///   - inputGuardrails: Input validation guardrails. Default: []
    ///   - outputGuardrails: Output validation guardrails. Default: []
    ///   - guardrailRunnerConfiguration: Configuration for guardrail runner. Default: .default
    ///   - handoffs: Handoff configurations for multi-agent orchestration. Default: []
    public init(
        name: String,
        instructions: String = "",
        tools: [any AnyJSONTool] = [],
        provider: ConduitProviderSelection,
        memory: (any Memory)? = nil,
        tracer: (any Tracer)? = nil,
        configuration: AgentConfiguration = .default,
        inputGuardrails: [any InputGuardrail] = [],
        outputGuardrails: [any OutputGuardrail] = [],
        guardrailRunnerConfiguration: GuardrailRunnerConfiguration = .default,
        handoffs: [AnyHandoffConfiguration] = []
    ) {
        self.init(
            name: name,
            instructions: instructions,
            tools: tools,
            inferenceProvider: provider,
            memory: memory,
            tracer: tracer,
            configuration: configuration,
            inputGuardrails: inputGuardrails,
            outputGuardrails: outputGuardrails,
            guardrailRunnerConfiguration: guardrailRunnerConfiguration,
            handoffs: handoffs
        )
    }

    /// Creates an unnamed agent backed by a Conduit inference provider.
    ///
    /// Using a concrete `ConduitProviderSelection` parameter enables Swift's
    /// dot-shorthand syntax at the call site:
    /// ```swift
    /// let agent = Agent(
    ///     instructions: "You are a helpful assistant.",
    ///     provider: .anthropic(apiKey: "sk-ant-...")
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - tools: Tools available to the agent. Default: []
    ///   - instructions: System instructions defining agent behavior. Default: ""
    ///   - provider: A `ConduitProviderSelection` value (e.g. `.anthropic(apiKey:)`).
    ///   - memory: Optional memory system. Default: nil
    ///   - tracer: Optional tracer for observability. Default: nil
    ///   - configuration: Agent configuration settings. Default: .default
    ///   - inputGuardrails: Input validation guardrails. Default: []
    ///   - outputGuardrails: Output validation guardrails. Default: []
    ///   - guardrailRunnerConfiguration: Configuration for guardrail runner. Default: .default
    ///   - handoffs: Handoff configurations for multi-agent orchestration. Default: []
    public init(
        tools: [any AnyJSONTool] = [],
        instructions: String = "",
        provider: ConduitProviderSelection,
        memory: (any Memory)? = nil,
        tracer: (any Tracer)? = nil,
        configuration: AgentConfiguration = .default,
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
            inferenceProvider: provider,
            tracer: tracer,
            inputGuardrails: inputGuardrails,
            outputGuardrails: outputGuardrails,
            guardrailRunnerConfiguration: guardrailRunnerConfiguration,
            handoffs: handoffs
        )
    }
}
