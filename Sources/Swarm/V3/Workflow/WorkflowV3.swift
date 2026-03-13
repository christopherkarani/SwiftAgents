import Foundation

/// Composable, value-type orchestration primitive for V3.
///
/// ```swift
/// let result = try await WorkflowV3()
///     .step(researchAgent)
///     .step(writerAgent)
///     .run(input: "Write about Swift concurrency")
/// ```
public struct WorkflowV3: Sendable {

    // MARK: - Internal step representation

    enum StepKind: @unchecked Sendable {
        case single(AgentV3)
        case parallel([AgentV3], merge: Workflow.MergeStrategy)
        case route(@Sendable (String) -> AgentV3?)
        case repeatUntil(AgentV3, condition: @Sendable (String) -> Bool, maxIterations: Int)
        case transform(@Sendable (String) async throws -> String)
    }

    var steps: [StepKind] = []

    /// Number of workflow steps.
    public var stepCount: Int { steps.count }

    public init() {}

    // MARK: - Step builders (each returns a NEW WorkflowV3 — value semantics)

    /// Add a single agent step.
    public func step(_ agent: AgentV3) -> WorkflowV3 {
        var copy = self
        copy.steps.append(.single(agent))
        return copy
    }

    /// Add a parallel execution step with multiple agents.
    public func parallel(
        _ agents: AgentV3...,
        merge: Workflow.MergeStrategy = .indexed
    ) -> WorkflowV3 {
        var copy = self
        copy.steps.append(.parallel(agents, merge: merge))
        return copy
    }

    /// Add a transform step (pure function, no LLM call).
    public func map(_ transform: @escaping @Sendable (String) async throws -> String) -> WorkflowV3 {
        var copy = self
        copy.steps.append(.transform(transform))
        return copy
    }

    /// Add a routing step that selects an agent based on input.
    public func route(_ selector: @escaping @Sendable (String) -> AgentV3?) -> WorkflowV3 {
        var copy = self
        copy.steps.append(.route(selector))
        return copy
    }

    /// Add a loop step that repeats until a condition is met.
    public func repeatUntil(
        _ agent: AgentV3,
        maxIterations: Int = 5,
        until condition: @escaping @Sendable (String) -> Bool
    ) -> WorkflowV3 {
        var copy = self
        copy.steps.append(.repeatUntil(agent, condition: condition, maxIterations: maxIterations))
        return copy
    }
}

// MARK: - Execution

extension WorkflowV3 {
    /// Execute the workflow sequentially, passing output from each step to the next.
    public func run(
        input: String,
        observer: (any AgentObserver)? = nil
    ) async throws -> AgentResult {
        var currentInput = input
        var lastResult = AgentResult(output: input)
        let startTime = ContinuousClock.now

        for step in steps {
            lastResult = try await executeStep(step, input: currentInput, observer: observer)
            currentInput = lastResult.output
        }

        let duration = ContinuousClock.now - startTime
        return AgentResult(
            output: lastResult.output,
            toolCalls: lastResult.toolCalls,
            toolResults: lastResult.toolResults,
            iterationCount: lastResult.iterationCount,
            duration: duration,
            tokenUsage: lastResult.tokenUsage,
            metadata: lastResult.metadata
        )
    }

    private func executeStep(
        _ step: StepKind,
        input: String,
        observer: (any AgentObserver)?
    ) async throws -> AgentResult {
        switch step {
        case .single(let agent):
            return try await agent.run(input)

        case .parallel(let agents, _):
            var outputs: [String] = []
            try await withThrowingTaskGroup(of: AgentResult.self) { group in
                for agent in agents {
                    group.addTask {
                        try await agent.run(input)
                    }
                }
                for try await result in group {
                    outputs.append(result.output)
                }
            }
            return AgentResult(output: outputs.joined(separator: "\n\n"))

        case .route(let selector):
            guard let selected = selector(input) else {
                throw WorkflowError.routingFailed(reason: "No route matched input")
            }
            return try await selected.run(input)

        case .repeatUntil(let agent, let condition, let maxIterations):
            var currentInput = input
            var result = AgentResult(output: input)
            for _ in 0..<maxIterations {
                result = try await agent.run(currentInput)
                if condition(result.output) { break }
                currentInput = result.output
            }
            return result

        case .transform(let fn):
            let output = try await fn(input)
            return AgentResult(output: output)
        }
    }
}
