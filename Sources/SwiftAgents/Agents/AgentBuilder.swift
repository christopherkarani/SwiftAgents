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
        self.handoffs = result
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
        self.init(
            tools: components.tools,
            instructions: components.instructions ?? "",
            configuration: components.configuration ?? .default,
            memory: components.memory,
            inferenceProvider: components.inferenceProvider,
            tracer: components.tracer,
            inputGuardrails: components.inputGuardrails,
            outputGuardrails: components.outputGuardrails,
            handoffs: components.handoffs
        )
    }
}
