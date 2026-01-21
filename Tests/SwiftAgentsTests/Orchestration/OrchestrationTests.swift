// OrchestrationTests.swift
// SwiftAgents Framework
//
// Tests for orchestration DSL and shared context behavior.

@testable import SwiftAgents
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
                ("ok", success)
                ("fail", failure)
            }
        }

        let result = try await workflow.run("ping")
        #expect(result.output.contains("ok: ping"))
        #expect(result.metadata["parallel.error_count"]?.intValue == 1)
    }
}
