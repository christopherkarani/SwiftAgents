// BreakingAPIChangesTests.swift
// SwarmTests
//
// Tests for breaking DSL changes (single-root orchestration, routing, parallel items).

@testable import Swarm
import Testing

@Suite("DSL Breaking Changes Tests")
struct BreakingAPIChangesTests {
    // MARK: - Helpers

    struct AppendStep: OrchestrationStep {
        let suffix: String

        func execute(_ input: String, context _: OrchestrationStepContext) async throws -> AgentResult {
            AgentResult(output: input + suffix)
        }
    }

    struct MetadataStep: OrchestrationStep {
        let key: String
        let value: String

        func execute(_ input: String, context _: OrchestrationStepContext) async throws -> AgentResult {
            AgentResult(output: input, metadata: [key: .string(value)])
        }
    }

    struct ConstantAgent: AgentRuntime {
        let output: String

        var tools: [any AnyJSONTool] { [] }
        var instructions: String { "ConstantAgent" }
        var configuration: AgentConfiguration { AgentConfiguration(name: "ConstantAgent") }

        func run(
            _ input: String,
            session _: (any Session)?,
            hooks _: (any RunHooks)?
        ) async throws -> AgentResult {
            AgentResult(output: "\(output): \(input)", metadata: ["id": .string(output)])
        }

        nonisolated func stream(
            _ input: String,
            session _: (any Session)?,
            hooks _: (any RunHooks)?
        ) -> AsyncThrowingStream<AgentEvent, Error> {
            StreamHelper.makeTrackedStream { continuation in
                continuation.yield(.started(input: input))
                continuation.yield(
                    .completed(result: AgentResult(output: "\(output): \(input)", metadata: ["id": .string(output)]))
                )
                continuation.finish()
            }
        }

        func cancel() async {}
    }

    // MARK: - Tests

    @Test("OrchestrationGroup runs sequentially")
    func orchestrationGroupRunsSequentially() async throws {
        let group = OrchestrationGroup {
            AppendStep(suffix: "A")
            AppendStep(suffix: "B")
        }

        let context = OrchestrationStepContext(
            agentContext: AgentContext(input: "x"),
            session: nil,
            hooks: nil,
            orchestrator: nil,
            orchestratorName: "Test",
            handoffs: []
        )

        let result = try await group.execute("x", context: context)
        #expect(result.output == "xAB")
        #expect(result.metadata["group.total_steps"]?.intValue == 2)
    }

    @Test("Orchestration accepts a single root step")
    func orchestrationAcceptsSingleRoot() async throws {
        let workflow = Orchestration(root: AppendStep(suffix: "!"))
        let result = try await workflow.run("hello")
        #expect(result.output == "hello!")
    }

    @Test("Orchestration group root preserves group metadata")
    func orchestrationGroupRootPreservesMetadata() async throws {
        let workflow = Orchestration {
            MetadataStep(key: "note", value: "first")
            AppendStep(suffix: "A")
        }

        let result = try await workflow.run("x")
        #expect(result.metadata["group.total_steps"]?.intValue == 2)
        #expect(result.metadata["group.step_0.note"]?.stringValue == "first")
        #expect(result.metadata["orchestration.step_0.note"]?.stringValue == "first")
    }

    @Test("Parallel uses named items")
    func parallelUsesNamedItems() async throws {
        let one = ConstantAgent(output: "one")
        let two = ConstantAgent(output: "two")

        let workflow = Orchestration {
            Parallel {
                one.named("first")
                two.named("second")
            }
        }

        let result = try await workflow.run("ping")
        #expect(result.metadata["parallel.first.id"]?.stringValue == "one")
        #expect(result.metadata["parallel.second.id"]?.stringValue == "two")
        #expect(result.metadata["parallel.agent_count"]?.intValue == 2)
    }

    @Test("Parallel concatenate preserves declaration order")
    func parallelConcatenatePreservesOrder() async throws {
        struct DelayedAgent: AgentRuntime {
            let name: String
            let delay: UInt64

            var tools: [any AnyJSONTool] { [] }
            var instructions: String { "DelayedAgent" }
            var configuration: AgentConfiguration { AgentConfiguration(name: name) }

            func run(
                _ input: String,
                session _: (any Session)?,
                hooks _: (any RunHooks)?
            ) async throws -> AgentResult {
                try await Task.sleep(nanoseconds: delay)
                return AgentResult(output: name)
            }

            nonisolated func stream(
                _ input: String,
                session _: (any Session)?,
                hooks _: (any RunHooks)?
            ) -> AsyncThrowingStream<AgentEvent, Error> {
                StreamHelper.makeTrackedStream { continuation in
                    continuation.yield(.started(input: input))
                    Task {
                        try await Task.sleep(nanoseconds: delay)
                        continuation.yield(.completed(result: AgentResult(output: name)))
                        continuation.finish()
                    }
                }
            }

            func cancel() async {}
        }

        let slow = DelayedAgent(name: "first", delay: 100_000_000)
        let fast = DelayedAgent(name: "second", delay: 0)

        let workflow = Orchestration {
            Parallel {
                slow.named("first")
                fast.named("second")
            }
        }

        let result = try await workflow.run("ping")
        #expect(result.output == "first\n\nsecond")
    }

    @Test("Router routes to step branches")
    func routerRoutesToStepBranches() async throws {
        let workflow = Orchestration {
            Router {
                When(.contains("go")) { AppendStep(suffix: "A") }
                Otherwise { AppendStep(suffix: "B") }
            }
        }

        let matched = try await workflow.run("go")
        #expect(matched.output == "goA")

        let fallback = try await workflow.run("stop")
        #expect(fallback.output == "stopB")
    }

    @Test("Router supports multiple Otherwise branches in order")
    func routerSupportsMultipleOtherwiseBranchesInOrder() async throws {
        let workflow = Orchestration {
            Router {
                When(.contains("go")) { AppendStep(suffix: "A") }
                Otherwise { AppendStep(suffix: "B") }
                Otherwise { AppendStep(suffix: "C") }
            }
        }

        let fallback = try await workflow.run("stop")
        #expect(fallback.output == "stopBC")
    }

    @Test("Router single Otherwise regression")
    func routerSingleOtherwiseRegression() async throws {
        let workflow = Orchestration {
            Router {
                When(.contains("go")) { AppendStep(suffix: "A") }
                Otherwise { AppendStep(suffix: "B") }
            }
        }

        let fallback = try await workflow.run("stop")
        #expect(fallback.output == "stopB")
        #expect(fallback.metadata["router.matched_route"]?.stringValue == "fallback")
    }

    @Test("ConfiguredAgent preserves loop type")
    func configuredAgentPreservesLoopType() {
        struct CustomLoop: AgentLoop {
            let steps: [OrchestrationStep]
        }

        struct CustomLoopAgent: AgentLoopDefinition {
            var loop: CustomLoop { CustomLoop(steps: [Generate()]) }
        }

        func assertLoopType<A: AgentLoopDefinition, L: AgentLoop>(
            _: A,
            _: L.Type
        ) where A.Loop == L {}

        let configured = ConfiguredAgent(base: CustomLoopAgent()) { $0 }
        assertLoopType(configured, CustomLoop.self)
    }
}
