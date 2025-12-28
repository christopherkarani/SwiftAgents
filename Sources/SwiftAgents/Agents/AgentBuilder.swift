// AgentBuilder.swift
// SwiftAgents Framework
//
// Result builder DSL for declaratively constructing agents.

import Foundation

// MARK: - AgentComponent

/// Marker protocol for agent builder components.
///
/// Components conforming to this protocol can be used within the `AgentBuilder` DSL.
public protocol AgentComponent {}

// MARK: - Instructions

/// Instructions component for defining agent behavior.
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("You are a helpful assistant.")
/// }
/// ```
public struct Instructions: AgentComponent {
    /// The instruction text.
    public let text: String

    /// Creates an instructions component.
    ///
    /// - Parameter text: The system instructions for the agent.
    public init(_ text: String) {
        self.text = text
    }
}

// MARK: - Tools

/// Tools container component for providing agent capabilities.
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("Calculator agent.")
///     Tools {
///         CalculatorTool()
///         DateTimeTool()
///     }
/// }
/// ```
public struct Tools: AgentComponent {
    /// The tools to provide to the agent.
    public let tools: [any Tool]

    /// Creates a tools container using the builder DSL.
    ///
    /// - Parameter content: A closure that builds the tool array.
    public init(@ToolArrayBuilder _ content: () -> [any Tool]) {
        tools = content()
    }

    /// Creates a tools container from an array.
    ///
    /// - Parameter tools: The tools to include.
    public init(_ tools: [any Tool]) {
        self.tools = tools
    }
}

// MARK: - AgentMemoryComponent

/// Memory component for agent context management.
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("Memory-enabled agent.")
///     AgentMemoryComponent(ConversationMemory(maxMessages: 50))
/// }
/// ```
public struct AgentMemoryComponent: AgentComponent {
    /// The memory system.
    public let memory: any Memory

    /// Creates a memory component.
    ///
    /// - Parameter memory: The memory system to use.
    public init(_ memory: any Memory) {
        self.memory = memory
    }
}

// MARK: - Configuration

/// Configuration component for agent settings.
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("Configured agent.")
///     Configuration(.default.maxIterations(5).temperature(0.7))
/// }
/// ```
public struct Configuration: AgentComponent {
    /// The agent configuration.
    public let configuration: AgentConfiguration

    /// Creates a configuration component.
    ///
    /// - Parameter configuration: The configuration to use.
    public init(_ configuration: AgentConfiguration) {
        self.configuration = configuration
    }
}

// MARK: - InferenceProviderComponent

/// Inference provider component for custom model backends.
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("Custom provider agent.")
///     InferenceProviderComponent(myCustomProvider)
/// }
/// ```
public struct InferenceProviderComponent: AgentComponent {
    /// The inference provider.
    public let provider: any InferenceProvider

    /// Creates an inference provider component.
    ///
    /// - Parameter provider: The inference provider to use.
    public init(_ provider: any InferenceProvider) {
        self.provider = provider
    }
}

// MARK: - TracerComponent

/// Tracer component for agent observability.
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("Observable agent.")
///     TracerComponent(ConsoleTracer())
/// }
/// ```
public struct TracerComponent: AgentComponent {
    /// The tracer.
    public let tracer: any Tracer

    /// Creates a tracer component.
    ///
    /// - Parameter tracer: The tracer to use for observability.
    public init(_ tracer: any Tracer) {
        self.tracer = tracer
    }
}

// MARK: - InputGuardrailsComponent

/// Input guardrails component for validating agent inputs.
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("Secure agent.")
///     InputGuardrailsComponent(sensitiveDataGuardrail, piiDetectionGuardrail)
/// }
/// ```
public struct InputGuardrailsComponent: AgentComponent {
    /// The input guardrails.
    public let guardrails: [any InputGuardrail]

    /// Creates an input guardrails component from an array.
    ///
    /// - Parameter guardrails: The input guardrails to apply.
    public init(_ guardrails: [any InputGuardrail]) {
        self.guardrails = guardrails
    }

    /// Creates an input guardrails component from variadic parameters.
    ///
    /// - Parameter guardrails: The input guardrails to apply.
    public init(_ guardrails: any InputGuardrail...) {
        self.guardrails = guardrails
    }
}

// MARK: - OutputGuardrailsComponent

/// Output guardrails component for validating agent outputs.
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("Safe agent.")
///     OutputGuardrailsComponent(profanityFilterGuardrail, toxicityGuardrail)
/// }
/// ```
public struct OutputGuardrailsComponent: AgentComponent {
    /// The output guardrails.
    public let guardrails: [any OutputGuardrail]

    /// Creates an output guardrails component from an array.
    ///
    /// - Parameter guardrails: The output guardrails to apply.
    public init(_ guardrails: [any OutputGuardrail]) {
        self.guardrails = guardrails
    }

    /// Creates an output guardrails component from variadic parameters.
    ///
    /// - Parameter guardrails: The output guardrails to apply.
    public init(_ guardrails: any OutputGuardrail...) {
        self.guardrails = guardrails
    }
}

// MARK: - HandoffsComponent

/// Component providing handoff configurations for an agent.
///
/// Handoffs define how this agent can transfer execution to other agents,
/// including callbacks, filters, and enablement checks.
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("Coordinator agent.")
///     HandoffsComponent([
///         AnyHandoffConfiguration(handoff(to: plannerAgent)),
///         AnyHandoffConfiguration(handoff(to: executorAgent))
///     ])
/// }
/// ```
public struct HandoffsComponent: AgentComponent, Sendable {
    /// The handoff configurations.
    public let handoffs: [AnyHandoffConfiguration]

    /// Creates a handoffs component with an array of configurations.
    ///
    /// - Parameter handoffs: The handoff configurations to include.
    public init(_ handoffs: [AnyHandoffConfiguration]) {
        self.handoffs = handoffs
    }

    /// Creates a handoffs component from variadic type-erased configurations.
    ///
    /// - Parameter handoffs: The handoff configurations to include.
    public init(_ handoffs: AnyHandoffConfiguration...) {
        self.handoffs = handoffs
    }

    /// Creates a handoffs component from typed configurations.
    ///
    /// This initializer uses parameter packs to accept multiple typed
    /// `HandoffConfiguration` instances and type-erase them automatically.
    ///
    /// - Parameter configs: The typed handoff configurations.
    public init<each T: Agent>(_ configs: repeat HandoffConfiguration<each T>) {
        var result: [AnyHandoffConfiguration] = []
        repeat result.append(AnyHandoffConfiguration(each configs))
        handoffs = result
    }
}

// MARK: - ParallelToolCalls

/// Enables parallel tool call execution.
///
/// When enabled, if the agent requests multiple tool calls in a single turn,
/// they will be executed concurrently using Swift's structured concurrency.
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("Fast parallel agent.")
///     ParallelToolCalls()
/// }
/// ```
public struct ParallelToolCalls: AgentComponent {
    /// Whether parallel tool calls are enabled.
    public let enabled: Bool

    /// Creates a parallel tool calls component.
    ///
    /// - Parameter enabled: Whether to enable parallel tool execution. Default: true
    public init(_ enabled: Bool = true) {
        self.enabled = enabled
    }
}

// MARK: - PreviousResponseId

/// Sets previous response ID for conversation continuation.
///
/// Use this to continue a conversation from a specific response.
/// The agent will use this to maintain context across sessions.
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("Continuation agent.")
///     PreviousResponseId("resp_abc123")
/// }
/// ```
public struct PreviousResponseId: AgentComponent {
    /// The previous response ID.
    public let responseId: String?

    /// Creates a previous response ID component.
    ///
    /// - Parameter responseId: The response ID to continue from.
    public init(_ responseId: String?) {
        self.responseId = responseId
    }
}

// MARK: - AutoPreviousResponseId

/// Enables automatic previous response ID tracking.
///
/// When enabled, the agent automatically tracks response IDs
/// and uses them for conversation continuation within a session.
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("Auto-tracking agent.")
///     AutoPreviousResponseId()
/// }
/// ```
public struct AutoPreviousResponseId: AgentComponent {
    /// Whether auto tracking is enabled.
    public let enabled: Bool

    /// Creates an auto previous response ID component.
    ///
    /// - Parameter enabled: Whether to enable auto tracking. Default: true
    public init(_ enabled: Bool = true) {
        self.enabled = enabled
    }
}

// MARK: - ModelSettingsComponent

/// Model settings component for fine-grained model control.
///
/// Provides comprehensive control over model behavior including
/// sampling parameters, tool usage, and advanced options.
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("Precise agent.")
///     ModelSettingsComponent(.precise
///         .maxTokens(2000)
///         .toolChoice(.required)
///     )
/// }
/// ```
public struct ModelSettingsComponent: AgentComponent {
    /// The model settings.
    public let settings: ModelSettings

    /// Creates a model settings component.
    ///
    /// - Parameter settings: The model settings to use.
    public init(_ settings: ModelSettings) {
        self.settings = settings
    }
}

// MARK: - MCPClientComponent

/// MCP client component for dynamic tool discovery.
///
/// When provided, tools from connected MCP servers are automatically
/// registered with the agent, enabling seamless remote tool usage.
///
/// Example:
/// ```swift
/// let mcpClient = MCPClient()
/// try await mcpClient.addServer(myMCPServer)
///
/// let agent = ReActAgent {
///     Instructions("MCP-enabled agent.")
///     MCPClientComponent(mcpClient)
/// }
/// ```
public struct MCPClientComponent: AgentComponent {
    /// The MCP client for tool discovery.
    public let client: MCPClient

    /// Creates an MCP client component.
    ///
    /// - Parameter client: The MCP client to use for tool discovery.
    public init(_ client: MCPClient) {
        self.client = client
    }
}

// MARK: - AgentBuilder

/// A result builder for creating agents declaratively.
///
/// `AgentBuilder` enables a SwiftUI-like syntax for constructing agents
/// with their components (instructions, tools, memory, configuration).
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("You are a helpful math assistant.")
///
///     Tools {
///         CalculatorTool()
///         DateTimeTool()
///     }
///
///     AgentMemoryComponent(ConversationMemory(maxMessages: 100))
///
///     Configuration(.default
///         .maxIterations(10)
///         .temperature(0.7)
///     )
/// }
/// ```
@resultBuilder
public struct AgentBuilder {
    // MARK: Public

    /// The aggregated components from the builder.
    public struct Components {
        var instructions: String?
        var tools: [any Tool] = []
        var memory: (any Memory)?
        var configuration: AgentConfiguration?
        var inferenceProvider: (any InferenceProvider)?
        var tracer: (any Tracer)?
        var inputGuardrails: [any InputGuardrail] = []
        var outputGuardrails: [any OutputGuardrail] = []
        var guardrailRunnerConfiguration: GuardrailRunnerConfiguration?
        var handoffs: [AnyHandoffConfiguration] = []

        // MARK: - Phase 5 Settings

        /// Whether parallel tool calls are enabled.
        var parallelToolCalls: Bool?

        /// Previous response ID for conversation continuation.
        var previousResponseId: String?

        /// Whether auto previous response ID tracking is enabled.
        var autoPreviousResponseId: Bool?

        // MARK: - Phase 6 Settings

        /// Extended model settings for fine-grained control.
        var modelSettings: ModelSettings?

        /// MCP client for dynamic tool discovery.
        var mcpClient: MCPClient?
    }

    /// Builds a block of components.
    public static func buildBlock(_ components: Components...) -> Components {
        var result = Components()
        for component in components {
            // Merge each Components into the result
            if let instructions = component.instructions {
                result.instructions = instructions
            }
            result.tools.append(contentsOf: component.tools)
            if let memory = component.memory {
                result.memory = memory
            }
            if let configuration = component.configuration {
                result.configuration = configuration
            }
            if let provider = component.inferenceProvider {
                result.inferenceProvider = provider
            }
            if let tracer = component.tracer {
                result.tracer = tracer
            }
            result.inputGuardrails.append(contentsOf: component.inputGuardrails)
            result.outputGuardrails.append(contentsOf: component.outputGuardrails)
            if let guardrailRunnerConfiguration = component.guardrailRunnerConfiguration {
                result.guardrailRunnerConfiguration = guardrailRunnerConfiguration
            }
            result.handoffs.append(contentsOf: component.handoffs)
            // Phase 5 settings
            if let parallelToolCalls = component.parallelToolCalls {
                result.parallelToolCalls = parallelToolCalls
            }
            if let previousResponseId = component.previousResponseId {
                result.previousResponseId = previousResponseId
            }
            if let autoPreviousResponseId = component.autoPreviousResponseId {
                result.autoPreviousResponseId = autoPreviousResponseId
            }
            // Phase 6 settings
            if let modelSettings = component.modelSettings {
                result.modelSettings = modelSettings
            }
            if let mcpClient = component.mcpClient {
                result.mcpClient = mcpClient
            }
        }
        return result
    }

    /// Builds an empty block.
    public static func buildBlock() -> Components {
        Components()
    }

    /// Builds an optional component.
    public static func buildOptional(_ component: Components?) -> Components {
        component ?? Components()
    }

    /// Builds the first branch of an if-else.
    public static func buildEither(first component: Components) -> Components {
        component
    }

    /// Builds the second branch of an if-else.
    public static func buildEither(second component: Components) -> Components {
        component
    }

    /// Converts a single component to Components.
    public static func buildExpression(_ expression: AgentComponent) -> Components {
        var result = Components()
        merge(expression, into: &result)
        return result
    }

    // MARK: Private

    /// Merges a component into the aggregated result.
    private static func merge(_ component: AgentComponent, into result: inout Components) {
        switch component {
        case let instructions as Instructions:
            result.instructions = instructions.text
        case let tools as Tools:
            result.tools.append(contentsOf: tools.tools)
        case let memory as AgentMemoryComponent:
            result.memory = memory.memory
        case let config as Configuration:
            result.configuration = config.configuration
        case let provider as InferenceProviderComponent:
            result.inferenceProvider = provider.provider
        case let tracerComponent as TracerComponent:
            result.tracer = tracerComponent.tracer
        case let inputGuardrails as InputGuardrailsComponent:
            result.inputGuardrails.append(contentsOf: inputGuardrails.guardrails)
        case let outputGuardrails as OutputGuardrailsComponent:
            result.outputGuardrails.append(contentsOf: outputGuardrails.guardrails)
        case let handoffsComponent as HandoffsComponent:
            result.handoffs.append(contentsOf: handoffsComponent.handoffs)
        // Phase 5 components
        case let parallelToolCalls as ParallelToolCalls:
            result.parallelToolCalls = parallelToolCalls.enabled
        case let previousResponseId as PreviousResponseId:
            result.previousResponseId = previousResponseId.responseId
        case let autoPreviousResponseId as AutoPreviousResponseId:
            result.autoPreviousResponseId = autoPreviousResponseId.enabled
        // Phase 6 components
        case let modelSettingsComponent as ModelSettingsComponent:
            result.modelSettings = modelSettingsComponent.settings
        case let mcpClientComponent as MCPClientComponent:
            result.mcpClient = mcpClientComponent.client
        default:
            break
        }
    }
}

// MARK: - ReActAgent DSL Extension

public extension ReActAgent {
    /// Creates a ReActAgent using the declarative builder DSL.
    ///
    /// Example:
    /// ```swift
    /// let agent = ReActAgent {
    ///     Instructions("You are a helpful assistant.")
    ///
    ///     Tools {
    ///         CalculatorTool()
    ///         DateTimeTool()
    ///     }
    ///
    ///     AgentMemoryComponent(ConversationMemory(maxMessages: 50))
    ///
    ///     Configuration(.default.maxIterations(10))
    /// }
    /// ```
    ///
    /// - Parameter content: A closure that builds the agent components.
    init(@AgentBuilder _ content: () -> AgentBuilder.Components) {
        let components = content()

        // Build configuration with Phase 5 overrides
        var config = components.configuration ?? .default
        if let parallelToolCalls = components.parallelToolCalls {
            config = config.parallelToolCalls(parallelToolCalls)
        }
        if let previousResponseId = components.previousResponseId {
            config = config.previousResponseId(previousResponseId)
        }
        if let autoPreviousResponseId = components.autoPreviousResponseId {
            config = config.autoPreviousResponseId(autoPreviousResponseId)
        }
        // Phase 6: Apply model settings
        if let modelSettings = components.modelSettings {
            config = config.modelSettings(modelSettings)
        }

        self.init(
            tools: components.tools,
            instructions: components.instructions ?? "",
            configuration: config,
            memory: components.memory,
            inferenceProvider: components.inferenceProvider,
            tracer: components.tracer,
            inputGuardrails: components.inputGuardrails,
            outputGuardrails: components.outputGuardrails,
            handoffs: components.handoffs
        )
    }
}
