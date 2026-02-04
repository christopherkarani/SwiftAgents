// DeclarativeAgentModifiers.swift
// SwiftAgents Framework
//
// SwiftUI-style sugar modifiers for declarative legacy loop DSL definitions.

import Foundation

// MARK: - Configuration Modifiers

public extension AgentLoopDefinition {
    /// Overrides the agent's configuration with a transform.
    func configuration(
        _ transform: @escaping @Sendable (AgentConfiguration) -> AgentConfiguration
    ) -> some AgentLoopDefinition {
        ConfiguredAgent(base: self, transform: transform)
    }

    /// Sets the agent's name (also stored in `configuration.name`).
    func named(_ name: String) -> some AgentLoopDefinition {
        configuration { config in
            var copy = config
            copy.name = name
            return copy
        }
    }

    /// Sets model temperature for `Generate()`.
    func temperature(_ value: Double) -> some AgentLoopDefinition {
        configuration { config in
            var copy = config
            copy.temperature = value
            return copy
        }
    }

    /// Sets max iterations for `Generate()`.
    func maxIterations(_ value: Int) -> some AgentLoopDefinition {
        configuration { config in
            var copy = config
            copy.maxIterations = value
            return copy
        }
    }

    /// Sets timeout for `Generate()`.
    func timeout(_ duration: Duration) -> some AgentLoopDefinition {
        configuration { config in
            var copy = config
            copy.timeout = duration
            return copy
        }
    }
}

public struct ConfiguredAgent<Base: AgentLoopDefinition>: AgentLoopDefinition {
    public typealias Loop = Base.Loop

    public let base: Base
    public let transform: @Sendable (AgentConfiguration) -> AgentConfiguration

    public init(
        base: Base,
        transform: @escaping @Sendable (AgentConfiguration) -> AgentConfiguration
    ) {
        self.base = base
        self.transform = transform
    }

    public var name: String {
        let configured = configuration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configured.isEmpty {
            return configured
        }
        return base.name
    }

    public var instructions: String { base.instructions }
    public var tools: [any AnyJSONTool] { base.tools }
    public var configuration: AgentConfiguration { transform(base.configuration) }
    public var environment: AgentEnvironment { base.environment }
    public var inputGuardrails: [any InputGuardrail] { base.inputGuardrails }
    public var outputGuardrails: [any OutputGuardrail] { base.outputGuardrails }
    public var handoffs: [AnyHandoffConfiguration] { base.handoffs }

    public var loop: Base.Loop { base.loop }
}
