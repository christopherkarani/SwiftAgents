// TypedPipelineTests.swift
// SwiftAgentsTests
//
// Tests for typed Pipeline operators with generic input/output types.

import Testing
import Foundation
@testable import SwiftAgents

// MARK: - Typed Pipeline Tests

@Suite("Typed Pipeline Tests")
struct TypedPipelineTests {

    // MARK: - Basic Pipeline Creation

    @Test("Create pipeline from closure")
    func createPipelineFromClosure() async throws {
        let pipeline = Pipeline<String, Int> { input in
            input.count
        }

        let result = try await pipeline.execute("Hello")
        #expect(result == 5)
    }

    @Test("Create pipeline from agent")
    func createPipelineFromAgent() async throws {
        let mockProvider = MockInferenceProvider(responses: ["Final Answer: Processed"])
        let agent = ReActAgent(
            tools: [],
            instructions: "Process input",
            inferenceProvider: mockProvider
        )

        let pipeline = agent.asPipeline()
        let result = try await pipeline.execute("Test input")

        #expect(result.output.contains("Processed"))
    }

    // MARK: - Pipeline Chaining with >>> Operator

    @Test("Chain two pipelines with >>> operator")
    func chainTwoPipelines() async throws {
        let toUpper = Pipeline<String, String> { $0.uppercased() }
        let addExclaim = Pipeline<String, String> { $0 + "!" }

        let combined = toUpper >>> addExclaim
        let result = try await combined.execute("hello")

        #expect(result == "HELLO!")
    }

    @Test("Chain three pipelines")
    func chainThreePipelines() async throws {
        let step1 = Pipeline<String, Int> { $0.count }
        let step2 = Pipeline<Int, Double> { Double($0) * 1.5 }
        let step3 = Pipeline<Double, String> { "Result: \($0)" }

        let combined = step1 >>> step2 >>> step3
        let result = try await combined.execute("test")

        #expect(result == "Result: 6.0")
    }

    @Test("Chain pipelines with different types")
    func chainPipelinesWithDifferentTypes() async throws {
        let parse = Pipeline<String, [String]> { $0.components(separatedBy: ",") }
        let count = Pipeline<[String], Int> { $0.count }
        let format = Pipeline<Int, String> { "Found \($0) items" }

        let combined = parse >>> count >>> format
        let result = try await combined.execute("a,b,c,d")

        #expect(result == "Found 4 items")
    }

    // MARK: - Type Safety

    @Test("Pipeline preserves type information")
    func pipelinePreservesTypeInfo() async throws {
        let stringToInt = Pipeline<String, Int> { Int($0) ?? 0 }
        let intToDouble = Pipeline<Int, Double> { Double($0) }

        let combined = stringToInt >>> intToDouble

        // Combined should be Pipeline<String, Double>
        let result: Double = try await combined.execute("42")
        #expect(result == 42.0)
    }

    // MARK: - Pipeline Map and FlatMap

    @Test("Pipeline map transforms output")
    func pipelineMapTransformsOutput() async throws {
        let base = Pipeline<String, Int> { $0.count }
        let mapped = base.map { $0 * 2 }

        let result = try await mapped.execute("test")
        #expect(result == 8)
    }

    @Test("Pipeline flatMap chains with another pipeline")
    func pipelineFlatMapChains() async throws {
        let base = Pipeline<String, Int> { $0.count }
        let next = Pipeline<Int, String> { "Length: \($0)" }

        let combined = base.flatMap { _ in next }
        let result = try await combined.execute("hello")

        #expect(result == "Length: 5")
    }

    // MARK: - Pipeline with Async Operations

    @Test("Pipeline handles async operations")
    func pipelineHandlesAsyncOperations() async throws {
        let asyncPipeline = Pipeline<String, String> { input in
            try await Task.sleep(for: .milliseconds(10))
            return input.uppercased()
        }

        let result = try await asyncPipeline.execute("async")
        #expect(result == "ASYNC")
    }

    @Test("Chained pipelines execute sequentially")
    func chainedPipelinesExecuteSequentially() async throws {
        var executionOrder: [Int] = []

        let step1 = Pipeline<String, String> { input in
            executionOrder.append(1)
            return input
        }

        let step2 = Pipeline<String, String> { input in
            executionOrder.append(2)
            return input
        }

        let step3 = Pipeline<String, String> { input in
            executionOrder.append(3)
            return input
        }

        let combined = step1 >>> step2 >>> step3
        _ = try await combined.execute("test")

        #expect(executionOrder == [1, 2, 3])
    }

    // MARK: - Error Handling in Pipelines

    @Test("Pipeline propagates errors")
    func pipelinePropagatesErrors() async {
        let failingPipeline = Pipeline<String, String> { _ in
            throw TestError.intentionalFailure
        }

        do {
            _ = try await failingPipeline.execute("test")
            Issue.record("Expected error")
        } catch {
            #expect(error is TestError)
        }
    }

    @Test("Error in chain stops execution")
    func errorInChainStopsExecution() async {
        var step2Executed = false

        let step1 = Pipeline<String, String> { _ in
            throw TestError.intentionalFailure
        }

        let step2 = Pipeline<String, String> { input in
            step2Executed = true
            return input
        }

        let combined = step1 >>> step2

        do {
            _ = try await combined.execute("test")
            Issue.record("Expected error")
        } catch {
            #expect(!step2Executed)
        }
    }

    // MARK: - Transform Pipeline Helper

    @Test("TransformPipeline creates simple transformation")
    func transformPipelineCreatesSimpleTransformation() async throws {
        let transform = transformPipeline { (result: AgentResult) in
            result.output.uppercased()
        }

        let result = AgentResult(output: "hello", toolCalls: [], toolResults: [], iterationCount: 1, duration: 0, tokenUsage: nil, metadata: [:])
        let transformed = try await transform.execute(result)

        #expect(transformed == "HELLO")
    }

    // MARK: - Agent Pipeline Integration

    @Test("Chain agents using pipelines")
    func chainAgentsUsingPipelines() async throws {
        let mockProvider1 = MockInferenceProvider(responses: ["Final Answer: Step 1 complete"])
        let mockProvider2 = MockInferenceProvider(responses: ["Final Answer: Step 2 complete"])

        let agent1 = ReActAgent(tools: [], instructions: "Agent 1", inferenceProvider: mockProvider1)
        let agent2 = ReActAgent(tools: [], instructions: "Agent 2", inferenceProvider: mockProvider2)

        let pipeline1 = agent1.asPipeline()
        let outputExtractor = Pipeline<AgentResult, String> { $0.output }
        let pipeline2Wrapper = Pipeline<String, AgentResult> { input in
            try await agent2.run(input)
        }

        let combined = pipeline1 >>> outputExtractor >>> pipeline2Wrapper
        let result = try await combined.execute("Start")

        #expect(result.output.contains("Step 2"))
    }

    // MARK: - Pipeline Identity

    @Test("Identity pipeline passes through unchanged")
    func identityPipelinePassesThrough() async throws {
        let identity = Pipeline<String, String>.identity
        let result = try await identity.execute("unchanged")

        #expect(result == "unchanged")
    }

    // MARK: - Pipeline Composition Properties

    @Test("Pipeline composition is associative")
    func pipelineCompositionIsAssociative() async throws {
        let f = Pipeline<Int, Int> { $0 + 1 }
        let g = Pipeline<Int, Int> { $0 * 2 }
        let h = Pipeline<Int, Int> { $0 - 3 }

        // (f >>> g) >>> h should equal f >>> (g >>> h)
        let leftAssoc = (f >>> g) >>> h
        let rightAssoc = f >>> (g >>> h)

        let leftResult = try await leftAssoc.execute(5)
        let rightResult = try await rightAssoc.execute(5)

        #expect(leftResult == rightResult) // Both should be (5+1)*2-3 = 9
    }
}

// MARK: - Test Support Types

enum PipelineTestError: Error {
    case intentionalFailure
}

/// Extension to make Agent work as Pipeline (to be implemented)
extension Agent {
    func asPipeline() -> Pipeline<String, AgentResult> {
        Pipeline { input in
            try await self.run(input)
        }
    }
}

/// Helper function to create transform pipelines
func transformPipeline<Input, Output>(
    _ transform: @escaping @Sendable (Input) async throws -> Output
) -> Pipeline<Input, Output> {
    Pipeline(transform)
}

// MARK: - Pipeline Type (to be implemented in main source)

/// Type-safe pipeline with explicit input/output types
struct Pipeline<Input: Sendable, Output: Sendable>: Sendable {
    let execute: @Sendable (Input) async throws -> Output

    init(_ execute: @escaping @Sendable (Input) async throws -> Output) {
        self.execute = execute
    }

    func map<NewOutput: Sendable>(
        _ transform: @escaping @Sendable (Output) async throws -> NewOutput
    ) -> Pipeline<Input, NewOutput> {
        Pipeline<Input, NewOutput> { input in
            let output = try await self.execute(input)
            return try await transform(output)
        }
    }

    func flatMap<NewOutput: Sendable>(
        _ transform: @escaping @Sendable (Output) async throws -> Pipeline<Output, NewOutput>
    ) -> Pipeline<Input, NewOutput> {
        Pipeline<Input, NewOutput> { input in
            let output = try await self.execute(input)
            let nextPipeline = try await transform(output)
            return try await nextPipeline.execute(output)
        }
    }

    static var identity: Pipeline<Input, Input> {
        Pipeline<Input, Input> { $0 }
    }
}

/// Operator for chaining pipelines
func >>> <A: Sendable, B: Sendable, C: Sendable>(
    lhs: Pipeline<A, B>,
    rhs: Pipeline<B, C>
) -> Pipeline<A, C> {
    Pipeline { input in
        let intermediate = try await lhs.execute(input)
        return try await rhs.execute(intermediate)
    }
}
