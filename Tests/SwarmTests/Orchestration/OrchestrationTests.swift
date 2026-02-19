// OrchestrationTests.swift
// Swarm Framework
//
// Tests for orchestration DSL and shared context behavior.

@testable import Swarm
import Testing

// MARK: - Test Agents

struct EchoAgent: AgentRuntime {
    let tools: [any AnyJSONTool] = []
    let instructions = "Echo agent"
    let configuration: AgentConfiguration = .default

    func run(
        _ input: String,
        session _: (any Session)? = nil,
        hooks _: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        AgentResult(output: input)
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)? = nil,
        hooks _: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            continuation.yield(.completed(result: AgentResult(output: input)))
            continuation.finish()
        }
    }

    func cancel() async {}
}

struct FailingAgent: AgentRuntime {
    let tools: [any AnyJSONTool] = []
    let instructions = "Failing agent"
    let configuration: AgentConfiguration = .default

    func run(
        _ input: String,
        session _: (any Session)? = nil,
        hooks _: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        throw AgentError.invalidInput(reason: "forced failure")
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)? = nil,
        hooks _: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            continuation.yield(.failed(error: AgentError.invalidInput(reason: "forced failure")))
            continuation.finish(throwing: AgentError.invalidInput(reason: "forced failure"))
        }
    }

    func cancel() async {}
}

// MARK: - Test Steps

struct ContextWriteStep: OrchestrationStep {
    func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        await context.agentContext.set("marker", value: .string("set"))
        return AgentResult(output: input)
    }
}

struct ContextReadStep: OrchestrationStep {
    func execute(_ input: String, context: OrchestrationStepContext) async throws -> AgentResult {
        let value = await context.agentContext.get("marker")?.stringValue ?? "missing"
        return AgentResult(output: value)
    }
}

struct DelayedStep: OrchestrationStep {
    let nanoseconds: UInt64

    func execute(_ input: String, context _: OrchestrationStepContext) async throws -> AgentResult {
        try await Task.sleep(nanoseconds: nanoseconds)
        return AgentResult(output: input)
    }
}

struct MetadataStep: OrchestrationStep {
    let output: String
    let metadata: [String: SendableValue]

    func execute(_ input: String, context _: OrchestrationStepContext) async throws -> AgentResult {
        AgentResult(output: "\(input)\(output)", metadata: metadata)
    }
}

@Suite("Orchestration Tests")
struct OrchestrationTests {
    @Test("Shared context persists across steps")
    func sharedContextAcrossSteps() async throws {
        let workflow = Orchestration {
            ContextWriteStep()
            ContextReadStep()
        }

        let result = try await workflow.run("input")
        #expect(result.output == "set")
    }

    @Test("Handoff configuration applies input filter")
    func handoffInputFilterApplied() async throws {
        let agent = EchoAgent()
        let config = AnyHandoffConfiguration(handoff(
            to: agent,
            inputFilter: { data in
                var updated = data
                updated = HandoffInputData(
                    sourceAgentName: data.sourceAgentName,
                    targetAgentName: data.targetAgentName,
                    input: "filtered: \(data.input)",
                    context: data.context,
                    metadata: data.metadata
                )
                return updated
            }
        ))

        let workflow = Orchestration(handoffs: [config]) {
            agent
        }

        let result = try await workflow.run("hello")
        #expect(result.output == "filtered: hello")
    }

    @Test("Parallel continues on partial failure by default")
    func parallelContinuesOnPartialFailure() async throws {
        let success = EchoAgent()
        let failure = FailingAgent()

        let workflow = Orchestration {
            Parallel {
                success.named("ok")
                failure.named("fail")
            }
        }

        let result = try await workflow.run("ping")
        #expect(result.output == "ping")
        #expect(result.metadata["parallel.error_count"]?.intValue == 1)
    }

    @Test("Orchestration preserves top-level and namespaced step metadata")
    func orchestrationPreservesTopLevelAndNamespacedMetadata() async throws {
        let workflow = Orchestration {
            MetadataStep(
                output: "1",
                metadata: [
                    "shared": .string("first"),
                    "first_only": .int(1)
                ]
            )
            MetadataStep(
                output: "2",
                metadata: [
                    "shared": .string("second"),
                    "second_only": .bool(true)
                ]
            )
        }

        let result = try await workflow.run("x")

        #expect(result.output == "x12")
        #expect(result.metadata["shared"]?.stringValue == "second")
        #expect(result.metadata["first_only"]?.intValue == 1)
        #expect(result.metadata["second_only"]?.boolValue == true)
        #expect(result.metadata["orchestration.step_0.shared"]?.stringValue == "first")
        #expect(result.metadata["orchestration.step_1.shared"]?.stringValue == "second")
        #expect(result.metadata["orchestration.step_0.first_only"]?.intValue == 1)
        #expect(result.metadata["orchestration.step_1.second_only"]?.boolValue == true)
    }


    @Test("Orchestration records engine metadata")
    func orchestrationRecordsEngineMetadata() async throws {
        let workflow = Orchestration {
            Transform { $0 }
        }

        let result = try await workflow.run("ping")
        #expect(result.metadata["orchestration.engine"]?.stringValue == "hive")
    }

    @Test("Orchestration runtimeMode.swift remains source-compatible and executes on Hive")
    func orchestrationRuntimeModeSwiftExecutesOnHive() async throws {
        let workflow = Orchestration(
            configuration: AgentConfiguration(runtimeMode: .swift)
        ) {
            Transform { $0 }
        }

        let result = try await workflow.run("ping")
        #expect(result.metadata["orchestration.engine"]?.stringValue == "hive")
    }

    @Test("Orchestration runtimeMode.requireHive executes on Hive")
    func orchestrationRuntimeModeRequireHiveExecutesOnHive() async throws {
        let workflow = Orchestration(
            configuration: AgentConfiguration(runtimeMode: .requireHive)
        ) {
            Transform { $0 }
        }

        let result = try await workflow.run("ping")
        #expect(result.metadata["orchestration.engine"]?.stringValue == "hive")
    }

    @Test("Orchestration Hive run options override is passed through")
    func orchestrationHiveRunOptionsOverridePassesThrough() async throws {
        let workflow = Orchestration(
            configuration: AgentConfiguration(
                runtimeMode: .hive,
                hiveRunOptionsOverride: .init(maxSteps: 1)
            )
        ) {
            Transform { $0 + "1" }
            Transform { $0 + "2" }
            Transform { $0 + "3" }
        }

        do {
            _ = try await workflow.run("x")
            Issue.record("Expected maxSteps=1 override to terminate early in Hive mode.")
        } catch let error as AgentError {
            if case let .internalError(reason) = error {
                #expect(reason.contains("maxSteps=1"))
            } else {
                Issue.record("Expected internal out-of-steps error, got \(error).")
            }
        }
    }

    @Test("Orchestration DAG uses compiled graph node count for Hive maxSteps")
    func orchestrationDAGUsesCompiledGraphNodeCountForMaxSteps() async throws {
        let workflow = Orchestration {
            DAG {
                DAGNode("left", step: Transform { "\($0)L" })
                DAGNode("right", step: Transform { "\($0)R" })
                DAGNode("join", step: Transform { "\($0)|J" })
                    .dependsOn("left", "right")
            }
        }

        let result = try await workflow.run("x")

        #expect(result.output.contains("xL"))
        #expect(result.output.contains("xR"))
        #expect(result.output.contains("|J"))
        let nodeCount = try #require(result.metadata["orchestration.graph.node_count"]?.intValue)
        let maxSteps = try #require(result.metadata["orchestration.run.max_steps"]?.intValue)
        #expect(nodeCount >= 3)
        #expect(maxSteps == nodeCount)
    }

    @Test("Orchestration DAG derives Hive concurrency from graph parallelism")
    func orchestrationDAGDerivesHiveConcurrencyFromGraphParallelism() async throws {
        let workflow = Orchestration {
            DAG {
                DAGNode("left", step: Transform { "\($0)L" })
                DAGNode("right", step: Transform { "\($0)R" })
                DAGNode("join", step: Transform { "\($0)|J" })
                    .dependsOn("left", "right")
            }
        }

        let result = try await workflow.run("x")

        #expect(result.metadata["orchestration.graph.max_parallelism"]?.intValue == 2)
        #expect(result.metadata["orchestration.run.max_concurrent_tasks"]?.intValue == 2)

        let serializedWorkflow = Orchestration(
            configuration: AgentConfiguration(
                hiveRunOptionsOverride: SwarmHiveRunOptionsOverride(maxConcurrentTasks: 1)
            )
        ) {
            DAG {
                DAGNode("left", step: Transform { "\($0)L" })
                DAGNode("right", step: Transform { "\($0)R" })
                DAGNode("join", step: Transform { "\($0)|J" })
                    .dependsOn("left", "right")
            }
        }

        let serializedResult = try await serializedWorkflow.run("x")
        #expect(serializedResult.metadata["orchestration.graph.max_parallelism"]?.intValue == 2)
        #expect(serializedResult.metadata["orchestration.run.max_concurrent_tasks"]?.intValue == 1)
    }

    @Test("Orchestration inferencePolicy maps to Hive inference hints")
    func orchestrationInferencePolicyMapsToHiveHints() {
        let policy = InferencePolicy(
            latencyTier: .background,
            privacyRequired: true,
            tokenBudget: 2048,
            networkState: .metered
        )
        let hints = OrchestrationHiveEngine.makeInferenceHints(from: policy)

        #expect(hints?.latencyTier.rawValue == "background")
        #expect(hints?.privacyRequired == true)
        #expect(hints?.tokenBudget == 2048)
        #expect(hints?.networkState.rawValue == "metered")
    }

    @Test("Orchestration stream emits per-step iteration events")
    func orchestrationStreamIterationEvents() async throws {
        let workflow = Orchestration {
            Transform { $0 + "1" }
            Transform { $0 + "2" }
            Transform { $0 + "3" }
        }

        var started: [Int] = []
        var completed: [Int] = []
        var finalOutput: String? = nil

        for try await event in workflow.stream("x") {
            switch event {
            case .iterationStarted(let number):
                started.append(number)
            case .iterationCompleted(let number):
                completed.append(number)
            case .completed(let result):
                finalOutput = result.output
            default:
                break
            }
        }

        #expect(started == [1, 2, 3])
        #expect(completed == [1, 2, 3])
        #expect(finalOutput == "x123")
    }

    @Test("Orchestration cancel stops active run")
    func orchestrationCancelStopsActiveRun() async throws {
        let workflow = Orchestration {
            DelayedStep(nanoseconds: 5_000_000_000)
            Transform { $0 + "done" }
        }

        let runTask = Task {
            try await workflow.run("start")
        }

        try await Task.sleep(nanoseconds: 50_000_000)
        await workflow.cancel()

        do {
            _ = try await runTask.value
            Issue.record("Expected orchestration run to be cancelled.")
        } catch let error as AgentError {
            #expect(error == .cancelled)
        } catch is CancellationError {
            // Accept native task cancellation surface as equivalent behavior.
        } catch {
            Issue.record("Expected cancellation, got \(error)")
        }
    }
}
