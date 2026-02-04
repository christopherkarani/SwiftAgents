// HandoffBuilder.swift
// SwiftAgents Framework
//
// Fluent builder API for creating handoff configurations.

import Foundation

// MARK: - HandoffBuilder

/// A fluent builder for creating handoff configurations.
///
/// `HandoffBuilder` provides a chainable API for constructing
/// `HandoffConfiguration` instances with various options. Each method
/// returns a new builder instance, enabling fluent chaining.
///
/// Example:
/// ```swift
/// let config = HandoffBuilder(to: executorAgent)
///     .toolName("execute_task")
///     .toolDescription("Execute the planned task")
///     .onHandoff { context, data in
///         Log.agents.info("Handoff to \(data.targetAgentName)")
///     }
///     .inputFilter { data in
///         var modified = data
///         modified.metadata["timestamp"] = .double(Date().timeIntervalSince1970)
///         return modified
///     }
///     .isEnabled { context, _ in
///         await context.get("ready")?.boolValue ?? false
///     }
///     .nestHistory(true)
///     .build()
/// ```
public struct HandoffBuilder<Target: AgentRuntime>: Sendable {
    // MARK: Public

    // MARK: - Initialization

    /// Creates a new handoff builder targeting the specified agent.
    ///
    /// - Parameter target: The agent to hand off to.
    public init(to target: Target) {
        targetAgent = target
    }

    // MARK: - Builder Methods

    /// Sets a custom tool name for this handoff.
    ///
    /// The tool name is used when generating tool schemas for the
    /// handoff. If not set, a name is generated from the target agent's
    /// type name.
    ///
    /// - Parameter name: The custom tool name.
    /// - Returns: A new builder with the tool name set.
    ///
    /// Example:
    /// ```swift
    /// let builder = HandoffBuilder(to: agent)
    ///     .toolName("transfer_to_specialist")
    /// ```
    public func toolName(_ name: String) -> HandoffBuilder<Target> {
        var copy = self
        copy.toolNameOverride = name
        return copy
    }

    /// Sets the description for the handoff tool.
    ///
    /// The description helps the model understand when to use this
    /// handoff option. Provide clear, actionable descriptions.
    ///
    /// - Parameter description: The tool description.
    /// - Returns: A new builder with the description set.
    ///
    /// Example:
    /// ```swift
    /// let builder = HandoffBuilder(to: agent)
    ///     .toolDescription("Transfer complex calculations to the math specialist")
    /// ```
    public func toolDescription(_ description: String) -> HandoffBuilder<Target> {
        var copy = self
        copy.toolDescriptionValue = description
        return copy
    }

    /// Sets the callback invoked before handoff execution.
    ///
    /// The callback receives the shared `AgentContext` and `HandoffInputData`,
    /// allowing you to log, validate, or perform side effects. Throw an
    /// error to abort the handoff.
    ///
    /// - Parameter callback: The pre-handoff callback.
    /// - Returns: A new builder with the callback set.
    ///
    /// Example:
    /// ```swift
    /// let builder = HandoffBuilder(to: agent)
    ///     .onHandoff { context, data in
    ///         Log.agents.info("Handoff: \(data.sourceAgentName) -> \(data.targetAgentName)")
    ///         await context.set("last_handoff", value: .string(data.targetAgentName))
    ///     }
    /// ```
    public func onHandoff(_ callback: @escaping OnHandoffCallback) -> HandoffBuilder<Target> {
        var copy = self
        copy.onHandoffCallback = callback
        return copy
    }

    /// Sets the input filter for transforming handoff data.
    ///
    /// The filter is applied before the handoff executes, allowing you
    /// to modify metadata, transform inputs, or add computed values.
    ///
    /// - Parameter filter: The input data filter.
    /// - Returns: A new builder with the filter set.
    ///
    /// Example:
    /// ```swift
    /// let builder = HandoffBuilder(to: agent)
    ///     .inputFilter { data in
    ///         var modified = data
    ///         modified.metadata["processed"] = .bool(true)
    ///         return modified
    ///     }
    /// ```
    public func inputFilter(_ filter: @escaping InputFilterCallback) -> HandoffBuilder<Target> {
        var copy = self
        copy.inputFilterCallback = filter
        return copy
    }

    /// Sets the enablement check callback.
    ///
    /// The callback determines whether this handoff should be available.
    /// Return `false` to disable the handoff based on context or agent state.
    ///
    /// - Parameter check: The enablement check callback.
    /// - Returns: A new builder with the check set.
    ///
    /// Example:
    /// ```swift
    /// let builder = HandoffBuilder(to: agent)
    ///     .isEnabled { context, agent in
    ///         // Only enable when prerequisites are met
    ///         await context.get("prerequisites_met")?.boolValue ?? false
    ///     }
    /// ```
    public func isEnabled(_ check: @escaping IsEnabledCallback) -> HandoffBuilder<Target> {
        var copy = self
        copy.isEnabledCallback = check
        return copy
    }

    /// Sets whether to nest handoff history.
    ///
    /// When `true`, the source agent's conversation history is nested
    /// within the target agent's context. When `false`, only the direct
    /// input is passed.
    ///
    /// - Parameter nest: Whether to nest history.
    /// - Returns: A new builder with the setting applied.
    ///
    /// Example:
    /// ```swift
    /// let builder = HandoffBuilder(to: agent)
    ///     .nestHistory(true)
    /// ```
    public func nestHistory(_ nest: Bool) -> HandoffBuilder<Target> {
        var copy = self
        copy.nestHandoffHistory = nest
        return copy
    }

    /// Builds the handoff configuration.
    ///
    /// Call this method after configuring all desired options to
    /// create the final `HandoffConfiguration` instance.
    ///
    /// - Returns: The configured handoff configuration.
    ///
    /// Example:
    /// ```swift
    /// let config = HandoffBuilder(to: agent)
    ///     .toolName("my_handoff")
    ///     .build()
    /// ```
    public func build() -> HandoffConfiguration<Target> {
        HandoffConfiguration(
            targetAgent: targetAgent,
            toolNameOverride: toolNameOverride,
            toolDescription: toolDescriptionValue,
            onHandoff: onHandoffCallback,
            inputFilter: inputFilterCallback,
            isEnabled: isEnabledCallback,
            nestHandoffHistory: nestHandoffHistory
        )
    }

    // MARK: Private

    // MARK: - Private Properties

    private let targetAgent: Target
    private var toolNameOverride: String?
    private var toolDescriptionValue: String?
    private var onHandoffCallback: OnHandoffCallback?
    private var inputFilterCallback: InputFilterCallback?
    private var isEnabledCallback: IsEnabledCallback?
    private var nestHandoffHistory: Bool = false
}

// MARK: - Convenience Function

/// Creates a handoff configuration using the builder pattern.
///
/// This convenience function provides a direct way to create a
/// `HandoffConfiguration` with all options specified inline,
/// without explicitly using `HandoffBuilder`.
///
/// For more complex configurations or when reusing partial configurations,
/// prefer using `HandoffBuilder` directly.
///
/// Example:
/// ```swift
/// let config = handoff(
///     to: executorAgent,
///     toolName: "execute_task",
///     toolDescription: "Execute the planned task",
///     onHandoff: { context, data in
///         Log.agents.info("Executing handoff")
///     },
///     inputFilter: { data in
///         var modified = data
///         modified.metadata["timestamp"] = .double(Date().timeIntervalSince1970)
///         return modified
///     },
///     isEnabled: { context, _ in
///         await context.get("ready")?.boolValue ?? false
///     },
///     nestHistory: true
/// )
/// ```
///
/// - Parameters:
///   - target: The agent to hand off to.
///   - toolName: Custom tool name. Default: nil
///   - toolDescription: Tool description. Default: nil
///   - onHandoff: Pre-handoff callback. Default: nil
///   - inputFilter: Input data filter. Default: nil
///   - isEnabled: Enablement check. Default: nil
///   - nestHistory: Whether to nest history. Default: false
/// - Returns: The configured handoff configuration.
public func handoff<T: AgentRuntime>(
    to target: T,
    toolName: String? = nil,
    toolDescription: String? = nil,
    onHandoff: OnHandoffCallback? = nil,
    inputFilter: InputFilterCallback? = nil,
    isEnabled: IsEnabledCallback? = nil,
    nestHistory: Bool = false
) -> HandoffConfiguration<T> {
    HandoffConfiguration(
        targetAgent: target,
        toolNameOverride: toolName,
        toolDescription: toolDescription,
        onHandoff: onHandoff,
        inputFilter: inputFilter,
        isEnabled: isEnabled,
        nestHandoffHistory: nestHistory
    )
}

/// Creates a handoff configuration targeting a legacy loop DSL definition.
///
/// This overload lifts the agent into a `LoopAgent` runtime adapter so it can be
/// used anywhere `HandoffConfiguration` expects an `AgentRuntime`.
@available(
    *,
    deprecated,
    message: "Deprecated legacy loop DSL. Prefer handoff(to: AgentRuntime) or handoff(to: AgentBlueprint) for orchestration; embed runtime AgentRuntime steps for model turns."
)
public func handoff<A: AgentLoopDefinition>(
    to target: A,
    toolName: String? = nil,
    toolDescription: String? = nil,
    onHandoff: OnHandoffCallback? = nil,
    inputFilter: InputFilterCallback? = nil,
    isEnabled: IsEnabledCallback? = nil,
    nestHistory: Bool = false
) -> HandoffConfiguration<LoopAgent<A>> {
    let runtime = LoopAgent(target)

    let resolvedToolName = toolName ?? "handoff_to_\(String(describing: A.self).camelCaseToSnakeCase())"
    let resolvedDescription = toolDescription ?? "Hand off execution to \(target.name)"

    return HandoffConfiguration(
        targetAgent: runtime,
        toolNameOverride: resolvedToolName,
        toolDescription: resolvedDescription,
        onHandoff: onHandoff,
        inputFilter: inputFilter,
        isEnabled: isEnabled,
        nestHandoffHistory: nestHistory
    )
}

// MARK: - AnyHandoffConfiguration

/// A type-erased wrapper for handoff configurations.
///
/// Use `AnyHandoffConfiguration` when you need to store heterogeneous
/// handoff configurations in a collection or pass them through APIs
/// that cannot work with generic types.
///
/// Example:
/// ```swift
/// let configurations: [AnyHandoffConfiguration] = [
///     AnyHandoffConfiguration(handoff(to: plannerAgent)),
///     AnyHandoffConfiguration(handoff(to: executorAgent))
/// ]
/// ```
public struct AnyHandoffConfiguration: Sendable {
    /// The target agent (type-erased).
    public let targetAgent: any AgentRuntime

    /// Custom tool name for this handoff.
    public let toolNameOverride: String?

    /// Description for the handoff tool.
    public let toolDescription: String?

    /// Callback invoked before handoff execution.
    public let onHandoff: OnHandoffCallback?

    /// Filter to transform input data before handoff.
    public let inputFilter: InputFilterCallback?

    /// Callback to determine if handoff is enabled.
    public let isEnabled: IsEnabledCallback?

    /// Whether to nest handoff history.
    public let nestHandoffHistory: Bool

    // MARK: - Initialization

    /// Creates a type-erased handoff configuration from a typed configuration.
    ///
    /// - Parameter configuration: The typed configuration to wrap.
    public init(_ configuration: HandoffConfiguration<some AgentRuntime>) {
        targetAgent = configuration.targetAgent
        toolNameOverride = configuration.toolNameOverride
        toolDescription = configuration.toolDescription
        onHandoff = configuration.onHandoff
        inputFilter = configuration.inputFilter
        isEnabled = configuration.isEnabled
        nestHandoffHistory = configuration.nestHandoffHistory
    }

    /// Creates a type-erased handoff configuration directly.
    ///
    /// - Parameters:
    ///   - targetAgent: The agent to hand off to.
    ///   - toolNameOverride: Custom tool name. Default: nil
    ///   - toolDescription: Tool description. Default: nil
    ///   - onHandoff: Pre-handoff callback. Default: nil
    ///   - inputFilter: Input data filter. Default: nil
    ///   - isEnabled: Enablement check. Default: nil
    ///   - nestHandoffHistory: Whether to nest history. Default: false
    public init(
        targetAgent: any AgentRuntime,
        toolNameOverride: String? = nil,
        toolDescription: String? = nil,
        onHandoff: OnHandoffCallback? = nil,
        inputFilter: InputFilterCallback? = nil,
        isEnabled: IsEnabledCallback? = nil,
        nestHandoffHistory: Bool = false
    ) {
        self.targetAgent = targetAgent
        self.toolNameOverride = toolNameOverride
        self.toolDescription = toolDescription
        self.onHandoff = onHandoff
        self.inputFilter = inputFilter
        self.isEnabled = isEnabled
        self.nestHandoffHistory = nestHandoffHistory
    }
}

// MARK: - AnyHandoffConfiguration + Computed Properties

public extension AnyHandoffConfiguration {
    /// The effective tool name for this handoff.
    var effectiveToolName: String {
        if let override = toolNameOverride {
            return override
        }
        let typeName = String(describing: type(of: targetAgent))
        return "handoff_to_\(typeName.camelCaseToSnakeCase())"
    }

    /// The effective description for this handoff tool.
    var effectiveToolDescription: String {
        if let description = toolDescription {
            return description
        }
        let typeName = String(describing: type(of: targetAgent))
        return "Hand off execution to \(typeName)"
    }
}
