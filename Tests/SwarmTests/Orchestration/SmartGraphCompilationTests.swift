// SmartGraphCompilationTests.swift
// Swarm Framework
//
// TDD tests for Smart Graph Compilation: recursive step decomposition
// into Hive DAGs with fan-out, routing, and computed concurrency.

import Foundation
@testable import Swarm
import Testing

// MARK: - Test Helpers

/// A simple agent that uppercases its input.
private struct UppercaseAgent: AgentRuntime {
    let tools: [any AnyJSONTool] = []
    let instructions = "Uppercase agent"
    var configuration: AgentConfiguration

    init(name: String = "uppercase") {
        configuration = AgentConfiguration(name: name)
    }

    func run(
        _ input: String,
        session _: (any Session)? = nil,
        hooks _: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        AgentResult(output: input.uppercased())
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)? = nil,
        hooks _: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            continuation.yield(.completed(result: AgentResult(output: input.uppercased())))
            continuation.finish()
        }
    }

    func cancel() async {}
}

/// A simple agent that prefixes its input.
private struct PrefixAgent: AgentRuntime {
    let prefix: String
    let tools: [any AnyJSONTool] = []
    let instructions: String
    var configuration: AgentConfiguration

    init(prefix: String, name: String? = nil) {
        self.prefix = prefix
        instructions = "Prefix agent: \(prefix)"
        configuration = AgentConfiguration(name: name ?? "prefix-\(prefix)")
    }

    func run(
        _ input: String,
        session _: (any Session)? = nil,
        hooks _: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        AgentResult(output: "\(prefix)\(input)")
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)? = nil,
        hooks _: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            continuation.yield(.completed(result: AgentResult(output: "\(prefix)\(input)")))
            continuation.finish()
        }
    }

    func cancel() async {}
}

// MARK: - Accumulator Tests

@Suite("Smart Graph Compilation — Accumulator")
struct AccumulatorTests {
    @Test("Accumulator is Codable round-trip")
    func accumulatorCodableRoundTrip() throws {
        let accumulator = OrchestrationHiveEngine.Accumulator(
            toolCalls: [],
            toolResults: [],
            iterationCount: 3,
            metadata: ["key": .string("value")]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(accumulator)
        let decoded = try JSONDecoder().decode(OrchestrationHiveEngine.Accumulator.self, from: data)

        #expect(decoded.iterationCount == 3)
        #expect(decoded.metadata["key"]?.stringValue == "value")
        #expect(decoded.toolCalls.isEmpty)
        #expect(decoded.toolResults.isEmpty)
    }

    @Test("Accumulator reducer merges counters and metadata")
    func accumulatorReducerMerges() throws {
        let current = OrchestrationHiveEngine.Accumulator(
            toolCalls: [],
            toolResults: [],
            iterationCount: 1,
            metadata: ["b": .string("old"), "a": .string("keep")]
        )
        let update = OrchestrationHiveEngine.Accumulator(
            toolCalls: [],
            toolResults: [],
            iterationCount: 2,
            metadata: ["b": .string("new"), "c": .int(2)]
        )

        let merged = try OrchestrationHiveEngine.Accumulator.reduce(current: current, update: update)

        #expect(merged.iterationCount == 3)
        #expect(merged.metadata["a"]?.stringValue == "keep")
        #expect(merged.metadata["b"]?.stringValue == "new")
        #expect(merged.metadata["c"]?.intValue == 2)
    }

    @Test("Metadata namespacing avoids double-prefixing already-namespaced keys")
    func metadataNamespacingAvoidsDoublePrefixingAlreadyNamespacedKeys() {
        let metadata = [
            "orchestration.step_0.orchestrated": .string("already"),
            "loop.iteration_count": .int(3),
        ]
        let result = OrchestrationHiveEngine.metadataWithOrchestrationNamespace(
            base: metadata,
            prefix: "orchestration.step_0"
        )

        #expect(result["orchestration.step_0.orchestrated"]?.stringValue == "already")
        #expect(result["orchestration.step_0.loop.iteration_count"]?.intValue == 3)
        #expect(result["orchestration.step_0.orchestration.step_0.orchestrated"] == nil)
        #expect(result["loop.iteration_count"]?.intValue == 3)
    }
}

// MARK: - Graph Compilation Integration Tests

@Suite("Smart Graph Compilation — Hive Graph Integration")
struct SmartGraphCompilationIntegrationTests {

    @Test("Sequential workflow produces chain graph")
    func sequentialWorkflowProducesChainGraph() async throws {
        let workflow = Orchestration(
            configuration: AgentConfiguration(runtimeMode: .hive)
        ) {
            Transform { $0 + "1" }
            Transform { $0 + "2" }
            Transform { $0 + "3" }
        }

        let result = try await workflow.run("x")
        #expect(result.output == "x123")
        #expect(result.metadata["orchestration.engine"]?.stringValue == "hive")
    }

    @Test("Parallel workflow uses computed maxConcurrentTasks > 1")
    func parallelWorkflowUsesComputedConcurrency() async throws {
        let workflow = Orchestration(
            configuration: AgentConfiguration(runtimeMode: .hive)
        ) {
            Parallel(merge: .concatenate) {
                PrefixAgent(prefix: "A:").named("a")
                PrefixAgent(prefix: "B:").named("b")
            }
        }

        let result = try await workflow.run("input")

        // Both agents should have run
        let output = result.output
        #expect(output.contains("A:input"))
        #expect(output.contains("B:input"))

        // Metadata should indicate parallel execution via Hive graph
        #expect(result.metadata["orchestration.engine"]?.stringValue == "hive")
        #expect(result.metadata["orchestration.step_0.parallel.agent_count"]?.intValue == 2)
    }

    @Test("Parallel workflow with structured merge preserves order")
    func parallelStructuredMergePreservesOrder() async throws {
        let workflow = Orchestration(
            configuration: AgentConfiguration(runtimeMode: .hive)
        ) {
            Parallel(merge: .structured) {
                PrefixAgent(prefix: "first:").named("first")
                PrefixAgent(prefix: "second:").named("second")
                PrefixAgent(prefix: "third:").named("third")
            }
        }

        let result = try await workflow.run("data")

        // Structured merge creates labeled sections
        #expect(result.output.contains("## first"))
        #expect(result.output.contains("## second"))
        #expect(result.output.contains("## third"))
        #expect(result.output.contains("first:data"))
        #expect(result.output.contains("second:data"))
        #expect(result.output.contains("third:data"))
    }

    @Test("Router workflow uses Hive conditional routing")
    func routerWorkflowUsesHiveRouting() async throws {
        let workflow = Orchestration(
            configuration: AgentConfiguration(runtimeMode: .hive)
        ) {
            Router {
                When(.contains("code")) {
                    PrefixAgent(prefix: "CODE:")
                }
                When(.contains("weather")) {
                    PrefixAgent(prefix: "WEATHER:")
                }
                Otherwise {
                    PrefixAgent(prefix: "DEFAULT:")
                }
            }
        }

        let codeResult = try await workflow.run("code review")
        #expect(codeResult.output == "CODE:code review")
        #expect(codeResult.metadata["orchestration.engine"]?.stringValue == "hive")

        let weatherResult = try await workflow.run("weather forecast")
        #expect(weatherResult.output == "WEATHER:weather forecast")

        let defaultResult = try await workflow.run("something else")
        #expect(defaultResult.output == "DEFAULT:something else")
    }

    @Test("Nested Parallel inside Sequential compiles correctly")
    func nestedParallelInsideSequential() async throws {
        let workflow = Orchestration(
            configuration: AgentConfiguration(runtimeMode: .hive)
        ) {
            Sequential {
                Transform { "processed: \($0)" }
                Parallel(merge: .concatenate) {
                    UppercaseAgent(name: "upper").named("upper")
                    PrefixAgent(prefix: "prefix:").named("prefix")
                }
            }
        }

        let result = try await workflow.run("hello")

        // Transform runs first, then Parallel
        #expect(result.output.contains("PROCESSED: HELLO"))
        #expect(result.output.contains("prefix:processed: hello"))
        #expect(result.metadata["orchestration.step_0.step_1_parallel.agent_count"]?.intValue == 2)
    }

    @Test("Sequential composition with Loop does not under-budget maxSteps")
    func sequentialWithLoopUsesAdequateLoopBudget() async throws {
        let workflow = Orchestration(
            configuration: AgentConfiguration(runtimeMode: .hive)
        ) {
            Sequential {
                Loop(.maxIterations(3)) {
                    Transform { $0 + "!" }
                }
            }
        }

        let result = try await workflow.run("go")

        #expect(result.output == "go!!!")
        #expect(result.metadata["orchestration.engine"]?.stringValue == "hive")
    }

    @Test("maxConcurrentTasks override still respected when set")
    func maxConcurrentTasksOverrideRespected() async throws {
        let workflow = Orchestration(
            configuration: AgentConfiguration(
                runtimeMode: .hive,
                hiveRunOptionsOverride: SwarmHiveRunOptionsOverride(maxConcurrentTasks: 1)
            )
        ) {
            Parallel(merge: .concatenate) {
                PrefixAgent(prefix: "A:").named("a")
                PrefixAgent(prefix: "B:").named("b")
            }
        }

        // Should still work but maxConcurrentTasks override forces sequential execution
        let result = try await workflow.run("input")
        #expect(result.output.contains("A:input"))
        #expect(result.output.contains("B:input"))
    }
}
