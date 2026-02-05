// EnvironmentAgent.swift
// Swarm Framework
//
// Agent wrapper that applies task-local AgentEnvironment values.

import Foundation

/// Wraps an `AgentRuntime` and runs it with modified `AgentEnvironment` values.
public struct EnvironmentAgent: AgentRuntime, Sendable {
    private let base: any AgentRuntime
    private let modify: @Sendable (inout AgentEnvironment) -> Void

    public init(
        base: any AgentRuntime,
        modify: @escaping @Sendable (inout AgentEnvironment) -> Void
    ) {
        self.base = base
        self.modify = modify
    }

    // MARK: - AgentRuntime (forwarded)

    public var tools: [any AnyJSONTool] { base.tools }
    public var instructions: String { base.instructions }
    public var configuration: AgentConfiguration { base.configuration }
    public var memory: (any Memory)? { base.memory }
    public var inferenceProvider: (any InferenceProvider)? { base.inferenceProvider }
    public var tracer: (any Tracer)? { base.tracer }
    public var inputGuardrails: [any InputGuardrail] { base.inputGuardrails }
    public var outputGuardrails: [any OutputGuardrail] { base.outputGuardrails }
    public var handoffs: [AnyHandoffConfiguration] { base.handoffs }

    public func run(
        _ input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?
    ) async throws -> AgentResult {
        var env = AgentEnvironmentValues.current
        modify(&env)

        return try await AgentEnvironmentValues.$current.withValue(env) {
            try await base.run(input, session: session, hooks: hooks)
        }
    }

    public nonisolated func stream(
        _ input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            try await AgentEnvironmentValues.$current.withValue(envForStream()) {
                for try await event in base.stream(input, session: session, hooks: hooks) {
                    continuation.yield(event)
                }
            }
            continuation.finish()
        }
    }

    public func cancel() async {
        await base.cancel()
    }

    // MARK: - Private

    private func envForStream() -> AgentEnvironment {
        var env = AgentEnvironmentValues.current
        modify(&env)
        return env
    }
}

private struct SendableWritableKeyPath<Root, Value>: @unchecked Sendable {
    let keyPath: WritableKeyPath<Root, Value>

    init(_ keyPath: WritableKeyPath<Root, Value>) {
        self.keyPath = keyPath
    }
}

// MARK: - Modifiers

public extension AgentRuntime {
    /// Applies an environment value for the duration of this agent's execution.
    func environment<V: Sendable>(
        _ keyPath: WritableKeyPath<AgentEnvironment, V>,
        _ value: V
    ) -> EnvironmentAgent {
        let sendableKeyPath = SendableWritableKeyPath(keyPath)
        return EnvironmentAgent(base: self) { env in
            env[keyPath: sendableKeyPath.keyPath] = value
        }
    }

    /// Applies a memory implementation via the environment for the duration of execution.
    func memory(_ memory: any Memory) -> EnvironmentAgent {
        environment(\.memory, memory)
    }
}

public extension AgentBlueprint {
    /// Lifts this blueprint into an executable agent and applies an environment value.
    func environment<V: Sendable>(
        _ keyPath: WritableKeyPath<AgentEnvironment, V>,
        _ value: V
    ) -> EnvironmentAgent {
        BlueprintAgent(self).environment(keyPath, value)
    }

    /// Lifts this blueprint into an executable agent and applies environment memory.
    func memory(_ memory: any Memory) -> EnvironmentAgent {
        environment(\.memory, memory)
    }
}

public extension AgentLoopDefinition {
    /// Lifts this agent into an executable runtime and applies an environment value.
    func environment<V: Sendable>(
        _ keyPath: WritableKeyPath<AgentEnvironment, V>,
        _ value: V
    ) -> EnvironmentAgent {
        LoopAgent(self).environment(keyPath, value)
    }

    /// Lifts this agent into an executable runtime and applies environment memory.
    func memory(_ memory: any Memory) -> EnvironmentAgent {
        environment(\.memory, memory)
    }
}
