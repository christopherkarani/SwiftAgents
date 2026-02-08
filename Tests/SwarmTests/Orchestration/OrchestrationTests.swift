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


    @Test("Orchestration records engine metadata")
    func orchestrationRecordsEngineMetadata() async throws {
        let workflow = Orchestration {
            Transform { $0 }
        }

        let result = try await workflow.run("ping")
        #if SWARM_HIVE_RUNTIME && canImport(HiveCore)
        #expect(result.metadata["orchestration.engine"]?.stringValue == "hive")
        #else
        #expect(result.metadata["orchestration.engine"]?.stringValue == "swift")
        #endif
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
