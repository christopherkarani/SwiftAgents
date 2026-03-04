import Foundation

/// Fluent multi-agent workflow API.
public struct Workflow: Sendable {
    enum Step: @unchecked Sendable {
        case single(any AgentRuntime)
        case parallel([any AgentRuntime], merge: MergeStrategy)
        case route(@Sendable (String) -> (any AgentRuntime)?)
        case fallback(primary: any AgentRuntime, backup: any AgentRuntime, retries: Int)
    }

    public enum MergeStrategy: @unchecked Sendable {
        /// Merges results into a JSON object: `{"0": "output0", "1": "output1", ...}`.
        /// Use this when downstream agents or tools need machine-parseable parallel output.
        case structured
        /// Merges results as a numbered list: `[0]: output0\n[1]: output1\n...`.
        /// Readable by both humans and LLMs without JSON parsing.
        case indexed
        /// Returns the output of the first agent to complete.
        case first
        /// Applies a custom merge function to combine all parallel results.
        case custom(@Sendable ([AgentResult]) -> String)
    }

    public init() {}

    public func step(_ agent: some AgentRuntime) -> Workflow {
        var copy = self
        copy.steps.append(.single(agent))
        return copy
    }

    public func parallel(_ agents: [any AgentRuntime], merge: MergeStrategy = .structured) -> Workflow {
        var copy = self
        copy.steps.append(.parallel(agents, merge: merge))
        return copy
    }

    public func route(_ condition: @escaping @Sendable (String) -> (any AgentRuntime)?) -> Workflow {
        var copy = self
        copy.steps.append(.route(condition))
        return copy
    }

    public func repeatUntil(
        maxIterations: Int = 100,
        _ condition: @escaping @Sendable (AgentResult) -> Bool
    ) -> Workflow {
        var copy = self
        copy.repeatCondition = condition
        copy.maxRepeatIterations = maxIterations
        return copy
    }

    public func timeout(_ duration: Duration) -> Workflow {
        var copy = self
        copy.timeoutDuration = duration
        return copy
    }

    public func observed(by observer: some AgentObserver) -> Workflow {
        var copy = self
        copy.observer = observer
        return copy
    }

    public func run(_ input: String) async throws -> AgentResult {
        try await executeWithTimeout {
            try await executeDirect(input: input)
        }
    }

    public func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            do {
                let result = try await run(input)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch let error as AgentError {
                continuation.yield(.failed(error: error))
                continuation.finish(throwing: error)
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    struct AdvancedConfiguration: Sendable {
        var checkpoint: CheckpointConfiguration?
        var checkpointing: WorkflowCheckpointing?
    }

    struct CheckpointConfiguration: Sendable {
        let id: String
        let policy: Durable.CheckpointPolicy
    }

    var steps: [Step] = []
    var repeatCondition: (@Sendable (AgentResult) -> Bool)?
    var maxRepeatIterations = 100
    var timeoutDuration: Duration?
    var observer: (any AgentObserver)?
    var advancedConfiguration = AdvancedConfiguration()

    func executeWithTimeout(
        _ operation: @escaping @Sendable () async throws -> AgentResult
    ) async throws -> AgentResult {
        if let timeoutDuration {
            return try await withThrowingTaskGroup(of: AgentResult.self) { group in
                group.addTask { try await operation() }
                group.addTask {
                    try await Task.sleep(for: timeoutDuration)
                    throw AgentError.timeout(duration: timeoutDuration)
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        }
        return try await operation()
    }

    func executeDirect(input: String) async throws -> AgentResult {
        if let repeatCondition {
            var lastResult: AgentResult?

            for _ in 0 ..< maxRepeatIterations {
                let currentInput = lastResult?.output ?? input
                lastResult = try await runSinglePass(input: currentInput)
                if repeatCondition(lastResult!) {
                    return lastResult!
                }
            }

            return lastResult ?? AgentResult(output: "")
        }

        return try await runSinglePass(input: input)
    }

    func runSinglePass(input: String) async throws -> AgentResult {
        var currentInput = input
        var lastResult = AgentResult(output: "")

        for step in steps {
            lastResult = try await execute(step: step, withInput: currentInput)
            currentInput = lastResult.output
        }

        return lastResult
    }

    func execute(step: Step, withInput input: String) async throws -> AgentResult {
        switch step {
        case .single(let agent):
            return try await agent.run(input, session: nil, observer: observer)

        case .parallel(let agents, let merge):
            let inputSnapshot = input
            let results = try await withThrowingTaskGroup(of: AgentResult.self, returning: [AgentResult].self) { group in
                for agent in agents {
                    group.addTask {
                        try await agent.run(inputSnapshot, session: nil, observer: nil)
                    }
                }

                var collected: [AgentResult] = []
                for try await result in group {
                    collected.append(result)
                }
                return collected
            }

            let mergedOutput = mergeResults(results, strategy: merge)
            return AgentResult(output: mergedOutput)

        case .route(let route):
            guard let selected = route(input) else {
                throw WorkflowError.routingFailed(reason: "Workflow route did not match any agent for input")
            }
            return try await selected.run(input, session: nil, observer: observer)

        case .fallback(let primary, let backup, let retries):
            var lastError: (any Error)?
            let attempts = max(1, retries + 1)

            for _ in 0 ..< attempts {
                do {
                    return try await primary.run(input, session: nil, observer: observer)
                } catch {
                    lastError = error
                }
            }

            let fallbackResult = try await backup.run(input, session: nil, observer: observer)
            var metadata = fallbackResult.metadata
            metadata["workflow.fallback.used"] = .bool(true)
            if let lastError {
                metadata["workflow.fallback.error"] = .string(String(describing: lastError))
            }
            return AgentResult(
                output: fallbackResult.output,
                toolCalls: fallbackResult.toolCalls,
                toolResults: fallbackResult.toolResults,
                iterationCount: fallbackResult.iterationCount,
                duration: fallbackResult.duration,
                tokenUsage: fallbackResult.tokenUsage,
                metadata: metadata
            )
        }
    }

    func mergeResults(_ results: [AgentResult], strategy: MergeStrategy) -> String {
        switch strategy {
        case .structured:
            // Produce a JSON object keyed by index for machine-parseable output.
            let dict = results.enumerated().reduce(into: [String: String]()) { acc, pair in
                acc["\(pair.offset)"] = pair.element.output
            }
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: .sortedKeys),
               let json = String(data: data, encoding: .utf8)
            {
                return json
            }
            // Fallback: indexed format if JSON serialization fails (non-UTF-8 content).
            fallthrough
        case .indexed:
            return results.enumerated().map { idx, result in
                "[\(idx)]: \(result.output)"
            }.joined(separator: "\n")
        case .first:
            return results.first?.output ?? ""
        case .custom(let transform):
            return transform(results)
        }
    }

    var workflowSignature: String {
        let parts: [String] = steps.enumerated().map { index, step in
            switch step {
            case .single(let agent):
                return "\(index):single:\(agent.name)"
            case .parallel(let agents, let merge):
                let names = agents.map(\.name).joined(separator: ",")
                let mergeSignature: String
                switch merge {
                case .structured:
                    mergeSignature = "structured"
                case .indexed:
                    mergeSignature = "indexed"
                case .first:
                    mergeSignature = "first"
                case .custom:
                    mergeSignature = "custom"
                }
                return "\(index):parallel:\(names):\(mergeSignature)"
            case .route:
                return "\(index):route"
            case .fallback(let primary, let backup, let retries):
                return "\(index):fallback:\(primary.name):\(backup.name):\(retries)"
            }
        }

        let repeatSignature = "repeat:\(repeatCondition != nil):\(maxRepeatIterations)"
        return (parts + [repeatSignature]).joined(separator: "|")
    }
}
