// LoopAgent.swift
// Swarm Framework
//
// `AgentRuntime` adapter for executing a declarative legacy loop DSL definition.

import Foundation

protocol _LoopOrchestrator: OrchestratorProtocol {
    func _generate(
        _ input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?
    ) async throws -> AgentResult
}

/// An `AgentRuntime` adapter for executing a declarative legacy loop DSL definition.
///
/// This type exists to:
/// - Lift `AgentLoopDefinition` values into APIs that expect an `AgentRuntime`
/// - Provide a stable orchestrator identity for handoffs and hooks
/// - Execute `AgentLoop` steps sequentially
public actor LoopAgent<Definition: AgentLoopDefinition>: AgentRuntime, OrchestratorProtocol, _LoopOrchestrator {
    // MARK: Public

    nonisolated public let definition: Definition

    nonisolated public var tools: [any AnyJSONTool] { [] }
    nonisolated public var instructions: String { "LoopAgent(\(definition.name))" }
    nonisolated public var configuration: AgentConfiguration {
        var config = definition.configuration
        if config.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            config.name = definition.name
        }
        return config
    }

    nonisolated public var handoffs: [AnyHandoffConfiguration] { definition.handoffs }

    public init(_ definition: Definition) {
        self.definition = definition
    }

    public func run(
        _ input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?
    ) async throws -> AgentResult {
        let context = AgentContext(input: input)
        let stepContext = OrchestrationStepContext(
            agentContext: context,
            session: session,
            hooks: hooks,
            orchestrator: self,
            orchestratorName: orchestratorName,
            handoffs: handoffs
        )
        await context.recordExecution(agentName: orchestratorName)

        let env = mergedEnvironment(defaults: definition.environment)
        let task = Task {
            try await AgentEnvironmentValues.$current.withValue(env) {
                try await definition.loop.execute(input, context: stepContext)
            }
        }
        runningTask = task
        defer { runningTask = nil }
        return try await task.value
    }

    nonisolated public func stream(
        _ input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            do {
                let result = try await self.run(input, session: session, hooks: hooks)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch let error as AgentError {
                continuation.yield(.failed(error: error))
                continuation.finish(throwing: error)
            } catch {
                let agentError = AgentError.internalError(reason: error.localizedDescription)
                continuation.yield(.failed(error: agentError))
                continuation.finish(throwing: error)
            }
        }
    }

    public func cancel() async {
        runningTask?.cancel()
        runningTask = nil
    }

    // MARK: Internal

    func executeInOrchestration(
        _ input: String,
        parent: OrchestrationStepContext
    ) async throws -> AgentResult {
        let stepContext = OrchestrationStepContext(
            agentContext: parent.agentContext,
            session: parent.session,
            hooks: parent.hooks,
            orchestrator: self,
            orchestratorName: orchestratorName,
            handoffs: handoffs
        )

        let env = mergedEnvironment(defaults: definition.environment)
        return try await AgentEnvironmentValues.$current.withValue(env) {
            try await definition.loop.execute(input, context: stepContext)
        }
    }

    // MARK: _LoopOrchestrator

    func _generate(
        _ input: String,
        session: (any Session)?,
        hooks: (any RunHooks)?
    ) async throws -> AgentResult {
        let env = mergedEnvironment(defaults: definition.environment)
        guard env.inferenceProvider != nil else {
            throw AgentError.inferenceProviderUnavailable(
                reason: """
                Missing inference provider while executing Generate() for '\(orchestratorName)'.
                Set `.environment(\\.inferenceProvider, ...)` at the call site or provide a default via the agent's `environment`.
                """
            )
        }
        return try await AgentEnvironmentValues.$current.withValue(env) {
            let agent = RelayAgent(
                tools: definition.tools,
                instructions: definition.instructions,
                configuration: configuration,
                memory: AgentEnvironmentValues.current.memory,
                inferenceProvider: AgentEnvironmentValues.current.inferenceProvider,
                tracer: AgentEnvironmentValues.current.tracer,
                inputGuardrails: definition.inputGuardrails,
                outputGuardrails: definition.outputGuardrails,
                handoffs: []
            )

            return try await agent.run(input, session: session, hooks: hooks)
        }
    }

    // MARK: Private

    private var runningTask: Task<AgentResult, Error>?

    private func mergedEnvironment(defaults: AgentEnvironment) -> AgentEnvironment {
        var env = AgentEnvironmentValues.current
        if env.inferenceProvider == nil, let provider = defaults.inferenceProvider {
            env.inferenceProvider = provider
        }
        if env.tracer == nil, let tracer = defaults.tracer {
            env.tracer = tracer
        }
        if env.memory == nil, let memory = defaults.memory {
            env.memory = memory
        }
        return env
    }
}

// MARK: - LoopAgentStep

public struct LoopAgentStep<A: AgentLoopDefinition>: OrchestrationStep {
    public let agent: A
    public let name: String?

    public init(_ agent: A, name: String? = nil) {
        self.agent = agent
        self.name = name
    }

    public func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        let runtime = LoopAgent(agent)
        let agentName = name ?? agent.name

        await context.agentContext.recordExecution(agentName: agentName)

        let effectiveInput = try await context.applyHandoffConfiguration(
            for: runtime,
            input: input,
            targetName: agentName
        )

        if let orchestrator = context.orchestrator {
            await context.hooks?.onHandoff(
                context: context.agentContext,
                fromAgent: orchestrator,
                toAgent: runtime
            )
        }

        let result = try await runtime.executeInOrchestration(effectiveInput, parent: context)
        await context.agentContext.setPreviousOutput(result)
        return result
    }
}

extension LoopAgentStep: _AgentLoopNestedAgentSteps {
    var _nestedSteps: [OrchestrationStep] { agent.loop.steps }
    var _agentType: ObjectIdentifier { ObjectIdentifier(A.self) }
}
