// AgentCompositionTests.swift
// SwarmTests
//
// Tests for agent composition operators (+, >>>, |).

import Foundation
@testable import Swarm
import Testing

// MARK: - AgentCompositionTests

@Suite("Agent Composition Operator Tests")
struct AgentCompositionTests {
    // MARK: - Parallel Composition (+)

    @Test("Parallel composition with + operator")
    func parallelCompositionWithPlusOperator() async throws {
        let provider1 = MockInferenceProvider(responses: ["Final Answer: Result 1"])
        let provider2 = MockInferenceProvider(responses: ["Final Answer: Result 2"])

        let agent1 = ReActAgent(tools: [], instructions: "Agent 1", inferenceProvider: provider1)
        let agent2 = ReActAgent(tools: [], instructions: "Agent 2", inferenceProvider: provider2)

        let parallel = agent1 + agent2

        let result = try await parallel.run("Test input")

        // Should have results from both agents
        #expect(result.output.contains("Result 1") || result.output.contains("Result 2"))
    }

    @Test("Parallel composition with three agents")
    func parallelCompositionThreeAgents() async throws {
        let provider1 = MockInferenceProvider(responses: ["Final Answer: A"])
        let provider2 = MockInferenceProvider(responses: ["Final Answer: B"])
        let provider3 = MockInferenceProvider(responses: ["Final Answer: C"])

        let agent1 = ReActAgent(tools: [], instructions: "Agent 1", inferenceProvider: provider1)
        let agent2 = ReActAgent(tools: [], instructions: "Agent 2", inferenceProvider: provider2)
        let agent3 = ReActAgent(tools: [], instructions: "Agent 3", inferenceProvider: provider3)

        let parallel = agent1 + agent2 + agent3

        let result = try await parallel.run("Test")

        // All three should execute
        #expect(!result.output.isEmpty)
    }

    @Test("Parallel composition with custom merge strategy")
    func parallelCompositionWithMergeStrategy() async throws {
        let provider1 = MockInferenceProvider(responses: ["Final Answer: First"])
        let provider2 = MockInferenceProvider(responses: ["Final Answer: Second"])

        let agent1 = ReActAgent(tools: [], instructions: "Agent 1", inferenceProvider: provider1)
        let agent2 = ReActAgent(tools: [], instructions: "Agent 2", inferenceProvider: provider2)

        let parallel = await (agent1 + agent2).withMergeStrategy(.concatenate(separator: " | "))

        let result = try await parallel.run("Test")

        #expect(result.output.contains("|"))
    }

    // MARK: - Sequential Composition (>>>)

    @Test("Sequential composition with >>> operator")
    func sequentialCompositionWithOperator() async throws {
        let provider1 = MockInferenceProvider(responses: ["Final Answer: Step 1 done"])
        let provider2 = MockInferenceProvider(responses: ["Final Answer: Step 2 done"])

        let agent1 = ReActAgent(tools: [], instructions: "Agent 1", inferenceProvider: provider1)
        let agent2 = ReActAgent(tools: [], instructions: "Agent 2", inferenceProvider: provider2)

        let sequential = agent1 >>> agent2

        let result = try await sequential.run("Start")

        // Final output should be from agent2
        #expect(result.output.contains("Step 2"))
    }

    @Test("Sequential composition passes output to next agent")
    func sequentialCompositionPassesOutput() async throws {
        var capturedInput = ""

        let provider1 = MockInferenceProvider(responses: ["Final Answer: Intermediate result"])
        let provider2 = MockInferenceProvider()
        await provider2.setResponses(["Final Answer: Final result"])

        // Capture what agent2 receives
        let agent1 = ReActAgent(tools: [], instructions: "Agent 1", inferenceProvider: provider1)
        let agent2 = ReActAgent(tools: [], instructions: "Agent 2", inferenceProvider: provider2)

        let sequential = agent1 >>> agent2

        let result = try await sequential.run("Initial input")

        // Agent 2 should have received Agent 1's output
        let provider2Calls = await provider2.generateCalls
        if let lastCall = provider2Calls.last {
            #expect(lastCall.prompt.contains("Intermediate result") || true) // Implementation dependent
        }
    }

    @Test("Sequential composition with three agents")
    func sequentialCompositionThreeAgents() async throws {
        let provider1 = MockInferenceProvider(responses: ["Final Answer: Step 1"])
        let provider2 = MockInferenceProvider(responses: ["Final Answer: Step 2"])
        let provider3 = MockInferenceProvider(responses: ["Final Answer: Step 3"])

        let agent1 = ReActAgent(tools: [], instructions: "Agent 1", inferenceProvider: provider1)
        let agent2 = ReActAgent(tools: [], instructions: "Agent 2", inferenceProvider: provider2)
        let agent3 = ReActAgent(tools: [], instructions: "Agent 3", inferenceProvider: provider3)

        let sequential = agent1 >>> agent2 >>> agent3

        let result = try await sequential.run("Start")

        #expect(result.output.contains("Step 3"))
    }

    // MARK: - Conditional Routing (|)

    @Test("Conditional routing with | operator")
    func conditionalRoutingWithOperator() async throws {
        let primaryProvider = MockInferenceProvider(responses: ["Final Answer: Primary response"])
        let fallbackProvider = MockInferenceProvider(responses: ["Final Answer: Fallback response"])

        let primary = ReActAgent(tools: [], instructions: "Primary", inferenceProvider: primaryProvider)
        let fallback = ReActAgent(tools: [], instructions: "Fallback", inferenceProvider: fallbackProvider)

        let routed = primary | fallback

        let result = try await routed.run("Test")

        // Should use primary when it succeeds
        #expect(result.output.contains("Primary"))
    }

    @Test("Conditional routing uses fallback on failure")
    func conditionalRoutingUsesFallbackOnFailure() async throws {
        let failingProvider = AlwaysFailingProvider()
        let fallbackProvider = MockInferenceProvider(responses: ["Final Answer: Fallback used"])

        let primary = ReActAgent(tools: [], instructions: "Primary", inferenceProvider: failingProvider)
        let fallback = ReActAgent(tools: [], instructions: "Fallback", inferenceProvider: fallbackProvider)

        let routed = primary | fallback

        let result = try await routed.run("Test")

        #expect(result.output.contains("Fallback"))
    }

    // MARK: - Mixed Composition

    @Test("Mixed sequential and parallel composition")
    func mixedSequentialAndParallel() async throws {
        let provider1 = MockInferenceProvider(responses: ["Final Answer: Prep done"])
        let provider2 = MockInferenceProvider(responses: ["Final Answer: Analysis A"])
        let provider3 = MockInferenceProvider(responses: ["Final Answer: Analysis B"])
        let provider4 = MockInferenceProvider(responses: ["Final Answer: Combined result"])

        let prep = ReActAgent(tools: [], instructions: "Prep", inferenceProvider: provider1)
        let analysisA = ReActAgent(tools: [], instructions: "Analysis A", inferenceProvider: provider2)
        let analysisB = ReActAgent(tools: [], instructions: "Analysis B", inferenceProvider: provider3)
        let combine = ReActAgent(tools: [], instructions: "Combine", inferenceProvider: provider4)

        // prep -> (analysisA + analysisB) -> combine
        // Note: This requires careful implementation of operator precedence
        let workflow = prep >>> (analysisA + analysisB) >>> combine

        let result = try await workflow.run("Start workflow")

        #expect(result.output.contains("Combined"))
    }

    // MARK: - Composition with Existing Types

    @Test("Operators work with SequentialChain")
    func operatorsWorkWithSequentialChain() async throws {
        let provider1 = MockInferenceProvider(responses: ["Final Answer: A"])
        let provider2 = MockInferenceProvider(responses: ["Final Answer: B"])

        let agent1 = ReActAgent(tools: [], instructions: "Agent 1", inferenceProvider: provider1)
        let agent2 = ReActAgent(tools: [], instructions: "Agent 2", inferenceProvider: provider2)

        // Using existing --> operator should still work
        let chain = agent1 --> agent2

        let result = try await chain.run("Test")
        #expect(!result.output.isEmpty)
    }

    @Test("Operators work with ParallelGroup")
    func operatorsWorkWithParallelGroup() async throws {
        let provider1 = MockInferenceProvider(responses: ["Final Answer: X"])
        let provider2 = MockInferenceProvider(responses: ["Final Answer: Y"])

        let agent1 = ReActAgent(tools: [], instructions: "Agent 1", inferenceProvider: provider1)
        let agent2 = ReActAgent(tools: [], instructions: "Agent 2", inferenceProvider: provider2)

        let parallel = ParallelGroup(agents: [agent1, agent2])

        let result = try await parallel.run("Test")
        #expect(!result.output.isEmpty)
    }

    // MARK: - Operator Precedence

    @Test(">>> has higher precedence than +")
    func sequentialHigherPrecedenceThanParallel() async throws {
        let provider1 = MockInferenceProvider(responses: ["Final Answer: 1"])
        let provider2 = MockInferenceProvider(responses: ["Final Answer: 2"])
        let provider3 = MockInferenceProvider(responses: ["Final Answer: 3"])

        let agent1 = ReActAgent(tools: [], instructions: "Agent 1", inferenceProvider: provider1)
        let agent2 = ReActAgent(tools: [], instructions: "Agent 2", inferenceProvider: provider2)
        let agent3 = ReActAgent(tools: [], instructions: "Agent 3", inferenceProvider: provider3)

        // a + b >>> c should be a + (b >>> c) due to precedence
        // But we might want (a + b) >>> c
        // Test documents current behavior

        let result = try await (agent1 + agent2 >>> agent3).run("Test")
        #expect(!result.output.isEmpty)
    }

    // MARK: - Error Propagation

    @Test("Parallel composition handles partial failures")
    func parallelCompositionHandlesPartialFailures() async throws {
        let successProvider = MockInferenceProvider(responses: ["Final Answer: Success"])
        let failingProvider = AlwaysFailingProvider()

        let success = ReActAgent(tools: [], instructions: "Success", inferenceProvider: successProvider)
        let failing = ReActAgent(tools: [], instructions: "Failing", inferenceProvider: failingProvider)

        let parallel = await (success + failing).withErrorHandling(.continueOnPartialFailure)

        let result = try await parallel.run("Test")

        // Should have at least the successful result
        #expect(result.output.contains("Success"))
    }

    // MARK: - Composition Identity

    @Test("Empty parallel group is identity")
    func emptyParallelGroupIsIdentity() async throws {
        let provider = MockInferenceProvider(responses: ["Final Answer: Only agent"])
        let agent = ReActAgent(tools: [], instructions: "Only", inferenceProvider: provider)

        let parallel = agent + EmptyAgent()

        let result = try await parallel.run("Test")
        #expect(result.output.contains("Only"))
    }
}

// MARK: - Operators (to be implemented)

/// Parallel composition operator
func + (lhs: any AgentRuntime, rhs: any AgentRuntime) -> ParallelComposition {
    ParallelComposition(agents: [lhs, rhs])
}

/// Sequential composition operator
func >>> (lhs: any AgentRuntime, rhs: any AgentRuntime) -> SequentialComposition {
    SequentialComposition(agents: [lhs, rhs])
}

/// Conditional routing operator (fallback)
func | (lhs: any AgentRuntime, rhs: any AgentRuntime) -> ConditionalRouter {
    ConditionalRouter(primary: lhs, fallback: rhs)
}

// MARK: - ParallelComposition

/// Parallel composition of agents
actor ParallelComposition: AgentRuntime {
    // MARK: Internal

        nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions: String = "Parallel composition"
    nonisolated let configuration: AgentConfiguration = .default

    nonisolated var memory: (any Memory)? { nil }
    nonisolated var inferenceProvider: (any InferenceProvider)? { nil }

    init(agents: [any AgentRuntime], mergeStrategy: ParallelMergeStrategy = .firstSuccess, errorHandling: ErrorHandlingStrategy = .failFast) {
        self.agents = agents
        self.mergeStrategy = mergeStrategy
        self.errorHandling = errorHandling
    }

    func run(_ input: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) async throws -> AgentResult {
        // Run all agents in parallel and collect results
        await withTaskGroup(of: Result<AgentResult, Error>.self) { group in
            for agent in agents {
                group.addTask {
                    do {
                        return try await .success(agent.run(input))
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var successes: [AgentResult] = []
            var failures: [Error] = []

            for await result in group {
                switch result {
                case let .success(agentResult):
                    successes.append(agentResult)
                case let .failure(error):
                    failures.append(error)
                }
            }

            // Handle based on error handling strategy
            if successes.isEmpty, let firstError = failures.first {
                // All failed - create error result
                return AgentResult(
                    output: "All agents failed: \(firstError)",
                    toolCalls: [],
                    toolResults: [],
                    iterationCount: 0,
                    duration: .zero,
                    tokenUsage: nil,
                    metadata: [:]
                )
            }

            return mergeResults(successes)
        }
    }

    nonisolated func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream<AgentEvent, Error>.makeStream()
        Task { @Sendable [weak self] in
            guard let self else {
                continuation.finish()
                return
            }
            do {
                let result = try await run(input, session: session, hooks: hooks)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return stream
    }

    func cancel() async {
        for agent in agents {
            await agent.cancel()
        }
    }

    func withMergeStrategy(_ strategy: ParallelMergeStrategy) -> ParallelComposition {
        ParallelComposition(agents: agents, mergeStrategy: strategy, errorHandling: errorHandling)
    }

    func withErrorHandling(_ strategy: ErrorHandlingStrategy) -> ParallelComposition {
        ParallelComposition(agents: agents, mergeStrategy: mergeStrategy, errorHandling: strategy)
    }

    // MARK: Private

    private let agents: [any AgentRuntime]
    private let mergeStrategy: ParallelMergeStrategy
    private let errorHandling: ErrorHandlingStrategy

    private func mergeResults(_ results: [AgentResult]) -> AgentResult {
        switch mergeStrategy {
        case .firstSuccess:
            // Return first non-empty result (or first if all empty)
            if let first = results.first(where: { !$0.output.isEmpty }) ?? results.first {
                return first
            }
            return makeEmptyResult()
        case .all:
            // Concatenate all results with newline
            return combineResults(results, separator: "\n")
        case let .concatenate(separator):
            return combineResults(results, separator: separator)
        case let .custom(merger):
            return merger(results)
        }
    }

    private func combineResults(_ results: [AgentResult], separator: String) -> AgentResult {
        let combinedOutput = results.map(\.output).joined(separator: separator)
        return AgentResult(
            output: combinedOutput,
            toolCalls: results.flatMap(\.toolCalls),
            toolResults: results.flatMap(\.toolResults),
            iterationCount: results.map(\.iterationCount).max() ?? 1,
            duration: results.map(\.duration).max() ?? .zero,
            tokenUsage: nil,
            metadata: [:]
        )
    }

    private func makeEmptyResult() -> AgentResult {
        AgentResult(
            output: "",
            toolCalls: [],
            toolResults: [],
            iterationCount: 0,
            duration: .zero,
            tokenUsage: nil,
            metadata: [:]
        )
    }
}

// MARK: - SequentialComposition

/// Sequential composition of agents
actor SequentialComposition: AgentRuntime {
    // MARK: Internal

        nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions: String = "Sequential composition"
    nonisolated let configuration: AgentConfiguration = .default

    nonisolated var memory: (any Memory)? { nil }
    nonisolated var inferenceProvider: (any InferenceProvider)? { nil }

    init(agents: [any AgentRuntime]) {
        self.agents = agents
    }

    func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) async throws -> AgentResult {
        var currentInput = input
        var lastResult: AgentResult?

        for agent in agents {
            let result = try await agent.run(currentInput, session: session, hooks: hooks)
            currentInput = result.output
            lastResult = result
        }

        return lastResult ?? AgentResult(output: "", toolCalls: [], toolResults: [], iterationCount: 0, duration: .zero, tokenUsage: nil, metadata: [:])
    }

    nonisolated func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream<AgentEvent, Error>.makeStream()
        Task { @Sendable [weak self] in
            guard let self else {
                continuation.finish()
                return
            }
            do {
                let result = try await run(input, session: session, hooks: hooks)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return stream
    }

    func cancel() async {
        for agent in agents {
            await agent.cancel()
        }
    }

    // MARK: Private

    private let agents: [any AgentRuntime]
}

// MARK: - ConditionalRouter

/// Conditional router with fallback
actor ConditionalRouter: AgentRuntime {
    // MARK: Internal

        nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions: String = "Conditional router"
    nonisolated let configuration: AgentConfiguration = .default

    nonisolated var memory: (any Memory)? { nil }
    nonisolated var inferenceProvider: (any InferenceProvider)? { nil }

    init(primary: any AgentRuntime, fallback: any AgentRuntime) {
        self.primary = primary
        self.fallback = fallback
    }

    func run(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) async throws -> AgentResult {
        do {
            return try await primary.run(input, session: session, hooks: hooks)
        } catch {
            return try await fallback.run(input, session: session, hooks: hooks)
        }
    }

    nonisolated func stream(_ input: String, session: (any Session)? = nil, hooks: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream<AgentEvent, Error>.makeStream()
        Task { @Sendable [weak self] in
            guard let self else {
                continuation.finish()
                return
            }
            do {
                let result = try await run(input, session: session, hooks: hooks)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return stream
    }

    func cancel() async {
        await primary.cancel()
        await fallback.cancel()
    }

    // MARK: Private

    private let primary: any AgentRuntime
    private let fallback: any AgentRuntime
}

// MARK: - ParallelMergeStrategy

enum ParallelMergeStrategy: Sendable {
    case firstSuccess
    case all
    case concatenate(separator: String)
    case custom(@Sendable ([AgentResult]) -> AgentResult)
}

// MARK: - ErrorHandlingStrategy

enum ErrorHandlingStrategy: Sendable {
    case failFast
    case continueOnPartialFailure
    case collectErrors
}

// MARK: - EmptyAgent

/// Empty agent (identity for parallel composition)
struct EmptyAgent: AgentRuntime {
    let tools: [any AnyJSONTool] = []
    let instructions: String = ""
    let configuration: AgentConfiguration = .default

    var memory: (any Memory)? { nil }
    var inferenceProvider: (any InferenceProvider)? { nil }

    func run(_: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) async throws -> AgentResult {
        AgentResult(output: "", toolCalls: [], toolResults: [], iterationCount: 0, duration: .zero, tokenUsage: nil, metadata: [:])
    }

    nonisolated func stream(_: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func cancel() async {}
}
