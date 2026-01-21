// AgentBlueprint.swift
// SwiftAgents Framework
//
// SwiftUI-style "blueprint" protocol for declarative agent/workflow definitions.

import Foundation

// MARK: - AgentBlueprint

/// A SwiftUI-style declarative definition of an agent/workflow.
///
/// `AgentBlueprint` is intended to be the primary high-level API long-term:
/// users define a value type with a `body` that describes execution order.
///
/// The blueprint compiles down to existing orchestration primitives
/// (`OrchestrationStep` and `Orchestration`) at execution time.
public protocol AgentBlueprint: Sendable {
    /// Declarative workflow content.
    @OrchestrationBuilder var body: [OrchestrationStep] { get }

    /// Configuration used when wrapping the blueprint in an `Orchestration`.
    nonisolated var configuration: AgentConfiguration { get }

    /// Handoff configurations applied by the blueprint's orchestration.
    nonisolated var handoffs: [AnyHandoffConfiguration] { get }
}

public extension AgentBlueprint {
    nonisolated var configuration: AgentConfiguration {
        AgentConfiguration(name: String(describing: Self.self))
    }

    nonisolated var handoffs: [AnyHandoffConfiguration] { [] }

    /// Builds an executable orchestration from this blueprint.
    func makeOrchestration() -> Orchestration {
        Orchestration(steps: body, configuration: configuration, handoffs: handoffs)
    }

    /// Executes the blueprint with the given input.
    func run(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        try await makeOrchestration().run(input, session: session, hooks: hooks)
    }

    /// Streams the blueprint's execution.
    func stream(
        _ input: String,
        session: (any Session)? = nil,
        hooks: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        makeOrchestration().stream(input, session: session, hooks: hooks)
    }
}

// MARK: - BlueprintAgent

/// An `AgentRuntime` adapter for executing an `AgentBlueprint`.
///
/// This is used to lift blueprints into APIs that expect an `AgentRuntime`
/// (like `Router` routes or nested orchestrations).
public actor BlueprintAgent<Blueprint: AgentBlueprint>: AgentRuntime {
    // MARK: Public

    nonisolated public let blueprint: Blueprint

    nonisolated public var tools: [any AnyJSONTool] { [] }
    nonisolated public var instructions: String {
        "Blueprint \(String(describing: Blueprint.self))"
    }
    nonisolated public var configuration: AgentConfiguration { blueprint.configuration }
    nonisolated public var handoffs: [AnyHandoffConfiguration] { blueprint.handoffs }

    public init(_ blueprint: Blueprint) {
        self.blueprint = blueprint
    }

    public func run(
        _ input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?
    ) async throws -> AgentResult {
        let orchestration = blueprint.makeOrchestration()
        let task = Task { try await orchestration.run(input, session: session, hooks: hooks) }
        runningTask = task
        defer { runningTask = nil }
        return try await task.value
    }

    nonisolated public func stream(
        _ input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        blueprint.makeOrchestration().stream(input, session: session, hooks: hooks)
    }

    public func cancel() async {
        runningTask?.cancel()
        runningTask = nil
    }

    // MARK: Private

    private var runningTask: Task<AgentResult, Error>?
}

