// DeclarativeAgent.swift
// SwiftAgents Framework
//
// SwiftUI-style declarative agent definitions backed by `AgentLoop`.

import Foundation

/// A SwiftUI-style declarative definition of an agent loop.
///
/// This is the legacy SwiftUI loop DSL. Conformers describe execution flow in
/// `loop` using a sequential `AgentLoop`.
///
/// Prefer `AgentBlueprint` for SwiftUI-style orchestration/workflows. When you
/// need a model turn inside a blueprint, embed a runtime agent step (an
/// `any AgentRuntime`) rather than using `Generate()` / `Relay()`.
/// Configuration (instructions, tools, guardrails, etc.) lives on the agent type,
/// while the `loop` describes *how* the agent runs.
@available(
    *,
    deprecated,
    message: "Deprecated legacy loop DSL. Prefer AgentBlueprint for orchestration/workflows; embed runtime AgentRuntime steps for model turns instead of Generate()/Relay()."
)
public protocol AgentLoopDefinition: Sendable {
    associatedtype Loop: AgentLoop

    /// Human-friendly agent name used for tracing, handoffs, and observability.
    var name: String { get }

    /// System instructions defining the agent's behavior.
    var instructions: String { get }

    /// Tools available to this agent when running `Generate()`.
    var tools: [any AnyJSONTool] { get }

    /// Runtime configuration for this agent when running `Generate()`.
    var configuration: AgentConfiguration { get }

    /// Default environment values for this agent's execution.
    ///
    /// Values set here are treated as defaults and can be overridden by the
    /// task-local environment set at the call site (see `.environment(...)`).
    var environment: AgentEnvironment { get }

    /// Input guardrails applied when running `Generate()`.
    var inputGuardrails: [any InputGuardrail] { get }

    /// Output guardrails applied when running `Generate()`.
    var outputGuardrails: [any OutputGuardrail] { get }

    /// Handoff configurations applied to sub-agents in this agent's loop.
    var handoffs: [AnyHandoffConfiguration] { get }

    /// Declarative execution flow for this agent.
    var loop: Loop { get }
}

public extension AgentLoopDefinition {
    var name: String { String(describing: Self.self) }
    var instructions: String { "" }
    var tools: [any AnyJSONTool] { [] }
    var configuration: AgentConfiguration { AgentConfiguration(name: name) }
    var environment: AgentEnvironment { AgentEnvironment() }
    var inputGuardrails: [any InputGuardrail] { [] }
    var outputGuardrails: [any OutputGuardrail] { [] }
    var handoffs: [AnyHandoffConfiguration] { [] }

    /// Builds an executable `AgentRuntime` adapter for this declarative agent.
    func asRuntime() -> LoopAgent<Self> {
        LoopAgent(self)
    }

    /// Executes the agent loop with the given input.
    func run(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        try await asRuntime().run(input, session: session, hooks: hooks)
    }

    /// Streams the agent's execution.
    func stream(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        asRuntime().stream(input, session: session, hooks: hooks)
    }
}
