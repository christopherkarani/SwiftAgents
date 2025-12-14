// AgentBuilder.swift
// SwiftAgents Framework
//
// Result builder DSL for declaratively constructing agents.

import Foundation

// MARK: - AgentComponent Protocol

/// Marker protocol for agent builder components.
///
/// Components conforming to this protocol can be used within the `AgentBuilder` DSL.
public protocol AgentComponent {}

// MARK: - Component Types

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
        self.tools = content()
    }

    /// Creates a tools container from an array.
    ///
    /// - Parameter tools: The tools to include.
    public init(_ tools: [any Tool]) {
        self.tools = tools
    }
}

/// Memory component for agent context management.
///
/// Example:
/// ```swift
/// let agent = ReActAgent {
///     Instructions("Memory-enabled agent.")
///     Memory(ConversationMemory(maxMessages: 50))
/// }
/// ```
public struct AgentMemoryComponent: AgentComponent {
    /// The memory system.
    public let memory: any AgentMemory

    /// Creates a memory component.
    ///
    /// - Parameter memory: The memory system to use.
    public init(_ memory: any AgentMemory) {
        self.memory = memory
    }
}

/// Type alias for cleaner DSL syntax.
public typealias Memory = AgentMemoryComponent

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

// MARK: - ToolArrayBuilder

/// A result builder for creating tool arrays declaratively.
///
/// Supports conditional inclusion and loops for dynamic tool configuration.
///
/// Example:
/// ```swift
/// Tools {
///     CalculatorTool()
///     if enableDebug {
///         DebugTool()
///     }
///     for name in customToolNames {
///         CustomTool(name: name)
///     }
/// }
/// ```
@resultBuilder
public struct ToolArrayBuilder {
    /// Builds a block of tools.
    public static func buildBlock(_ tools: any Tool...) -> [any Tool] {
        tools
    }

    /// Builds an empty block.
    public static func buildBlock() -> [any Tool] {
        []
    }

    /// Builds an optional tool.
    public static func buildOptional(_ tool: [any Tool]?) -> [any Tool] {
        tool ?? []
    }

    /// Builds the first branch of an if-else.
    public static func buildEither(first tool: [any Tool]) -> [any Tool] {
        tool
    }

    /// Builds the second branch of an if-else.
    public static func buildEither(second tool: [any Tool]) -> [any Tool] {
        tool
    }

    /// Builds an array of tools from a for-loop.
    public static func buildArray(_ components: [[any Tool]]) -> [any Tool] {
        components.flatMap { $0 }
    }

    /// Converts a single tool to an array.
    public static func buildExpression(_ expression: any Tool) -> [any Tool] {
        [expression]
    }

    /// Handles an array of tools.
    public static func buildExpression(_ expression: [any Tool]) -> [any Tool] {
        expression
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
///     Memory(ConversationMemory(maxMessages: 100))
///
///     Configuration(.default
///         .maxIterations(10)
///         .temperature(0.7)
///     )
/// }
/// ```
@resultBuilder
public struct AgentBuilder {
    /// The aggregated components from the builder.
    public struct Components {
        var instructions: String?
        var tools: [any Tool] = []
        var memory: (any AgentMemory)?
        var configuration: AgentConfiguration?
        var inferenceProvider: (any InferenceProvider)?
    }

    /// Builds a block of components.
    public static func buildBlock(_ components: AgentComponent...) -> Components {
        var result = Components()
        for component in components {
            merge(component, into: &result)
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
        default:
            break
        }
    }
}

// MARK: - ReActAgent DSL Extension

extension ReActAgent {
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
    ///     Memory(ConversationMemory(maxMessages: 50))
    ///
    ///     Configuration(.default.maxIterations(10))
    /// }
    /// ```
    ///
    /// - Parameter content: A closure that builds the agent components.
    public init(@AgentBuilder _ content: () -> AgentBuilder.Components) {
        let components = content()
        self.init(
            tools: components.tools,
            instructions: components.instructions ?? "",
            configuration: components.configuration ?? .default,
            memory: components.memory,
            inferenceProvider: components.inferenceProvider
        )
    }
}

// MARK: - AgentConfiguration Fluent Extensions

extension AgentConfiguration {
    /// Returns a new configuration with the specified maximum iterations.
    ///
    /// - Parameter count: Maximum iterations before timeout.
    /// - Returns: A modified configuration.
    public func maxIterations(_ count: Int) -> AgentConfiguration {
        var copy = self
        copy.maxIterations = max(1, count)
        return copy
    }

    /// Returns a new configuration with the specified temperature.
    ///
    /// - Parameter value: Temperature for generation (0.0-2.0).
    /// - Returns: A modified configuration.
    public func temperature(_ value: Double) -> AgentConfiguration {
        var copy = self
        copy.temperature = max(0.0, min(2.0, value))
        return copy
    }

    /// Returns a new configuration with the specified timeout.
    ///
    /// - Parameter duration: Maximum execution time.
    /// - Returns: A modified configuration.
    public func timeout(_ duration: Duration) -> AgentConfiguration {
        var copy = self
        copy.timeout = duration
        return copy
    }

    /// Returns a new configuration with streaming enabled or disabled.
    ///
    /// - Parameter enabled: Whether to enable streaming.
    /// - Returns: A modified configuration.
    public func enableStreaming(_ enabled: Bool) -> AgentConfiguration {
        var copy = self
        copy.enableStreaming = enabled
        return copy
    }

    /// Returns a new configuration with the specified maximum tokens.
    ///
    /// - Parameter count: Maximum tokens for generation.
    /// - Returns: A modified configuration.
    public func maxTokens(_ count: Int) -> AgentConfiguration {
        var copy = self
        copy.maxTokens = count > 0 ? count : nil
        return copy
    }

    /// Returns a new configuration with stop-on-error behavior.
    ///
    /// - Parameter stop: Whether to stop on tool errors.
    /// - Returns: A modified configuration.
    public func stopOnToolError(_ stop: Bool) -> AgentConfiguration {
        var copy = self
        copy.stopOnToolError = stop
        return copy
    }
}
