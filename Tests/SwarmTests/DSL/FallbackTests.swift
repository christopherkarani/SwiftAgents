// FallbackTests.swift
// SwarmTests
//
// Tests for FallbackStep orchestration step.

@testable import Swarm
import Foundation
import Testing

// MARK: - Test Agents

private struct FallbackEchoAgent: AgentRuntime {
    let tools: [any AnyJSONTool] = []
    let instructions: String
    let configuration: AgentConfiguration

    init(name: String = "Echo", prefix: String = "echo") {
        instructions = "\(name) agent"
        configuration = AgentConfiguration(name: name)
        self.prefix = prefix
    }

    let prefix: String

    func run(
        _ input: String,
        session _: (any Session)? = nil,
        hooks _: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        AgentResult(output: "\(prefix): \(input)")
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)? = nil,
        hooks _: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        let p = prefix
        return StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            continuation.yield(.completed(result: AgentResult(output: "\(p): \(input)")))
            continuation.finish()
        }
    }

    func cancel() async {}
}

private struct FallbackFailingAgent: AgentRuntime {
    let tools: [any AnyJSONTool] = []
    let instructions = "Failing agent"
    let configuration: AgentConfiguration

    init(name: String = "Failing") {
        configuration = AgentConfiguration(name: name)
    }

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
            continuation.finish(throwing: AgentError.invalidInput(reason: "forced failure"))
        }
    }

    func cancel() async {}
}

/// Agent that fails N times then succeeds.
private final class FallbackCountingAgent: AgentRuntime, @unchecked Sendable {
    let tools: [any AnyJSONTool] = []
    let instructions = "Counting agent"
    let configuration: AgentConfiguration
    private let failCount: Int
    private let lock = NSLock()
    private var _callCount = 0

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }

    init(name: String = "Counting", failCount: Int) {
        configuration = AgentConfiguration(name: name)
        self.failCount = failCount
    }

    func run(
        _ input: String,
        session _: (any Session)? = nil,
        hooks _: (any RunHooks)? = nil
    ) async throws -> AgentResult {
        let count = lock.withLock {
            _callCount += 1
            return _callCount
        }

        if count <= failCount {
            throw AgentError.invalidInput(reason: "attempt \(count) failed")
        }
        return AgentResult(output: "success on attempt \(count): \(input)")
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)? = nil,
        hooks _: (any RunHooks)? = nil
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.started(input: input))
            continuation.finish()
        }
    }

    func cancel() async {}
}

// MARK: - FallbackTests

@Suite("FallbackStep Tests")
struct FallbackTests {
    // MARK: - Primary succeeds

    @Test("FallbackStep uses primary when it succeeds")
    func fallbackUsesPrimaryOnSuccess() async throws {
        let primary = FallbackEchoAgent(name: "Primary", prefix: "primary")
        let backup = FallbackEchoAgent(name: "Backup", prefix: "backup")

        let step = FallbackStep(AgentStep(primary), or: AgentStep(backup))

        let context = OrchestrationStepContext(
            agentContext: AgentContext(input: "test"),
            session: nil,
            hooks: nil,
            orchestrator: nil,
            orchestratorName: "Test",
            handoffs: []
        )

        let result = try await step.execute("hello", context: context)
        #expect(result.output == "primary: hello")
    }

    // MARK: - Primary fails, backup used

    @Test("FallbackStep uses backup when primary fails")
    func fallbackUsesBackupOnPrimaryFailure() async throws {
        let primary = FallbackFailingAgent(name: "Primary")
        let backup = FallbackEchoAgent(name: "Backup", prefix: "backup")

        let step = FallbackStep(AgentStep(primary), or: AgentStep(backup))

        let context = OrchestrationStepContext(
            agentContext: AgentContext(input: "test"),
            session: nil,
            hooks: nil,
            orchestrator: nil,
            orchestratorName: "Test",
            handoffs: []
        )

        let result = try await step.execute("hello", context: context)
        #expect(result.output == "backup: hello")
        #expect(result.metadata["fallback.used"]?.boolValue == true)
    }

    // MARK: - Retry logic

    @Test("FallbackStep retries primary before falling back")
    func fallbackRetriesPrimaryBeforeFallbackStep() async throws {
        let countingAgent = FallbackCountingAgent(name: "Counting", failCount: 2)
        let backup = FallbackEchoAgent(name: "Backup", prefix: "backup")

        // 2 retries means 3 total attempts (0, 1, 2)
        let step = FallbackStep(AgentStep(countingAgent), or: AgentStep(backup), retries: 2)

        let context = OrchestrationStepContext(
            agentContext: AgentContext(input: "test"),
            session: nil,
            hooks: nil,
            orchestrator: nil,
            orchestratorName: "Test",
            handoffs: []
        )

        let result = try await step.execute("hello", context: context)
        // Agent fails on attempts 1 and 2, succeeds on attempt 3
        #expect(result.output.contains("success on attempt 3"))
        #expect(countingAgent.callCount == 3)
    }

    @Test("FallbackStep with retries falls back when all retries fail")
    func fallbackRetriesExhaustedFallsBack() async throws {
        let countingAgent = FallbackCountingAgent(name: "Counting", failCount: 5)
        let backup = FallbackEchoAgent(name: "Backup", prefix: "backup")

        // Only 1 retry means 2 total attempts, but agent fails 5 times
        let step = FallbackStep(AgentStep(countingAgent), or: AgentStep(backup), retries: 1)

        let context = OrchestrationStepContext(
            agentContext: AgentContext(input: "test"),
            session: nil,
            hooks: nil,
            orchestrator: nil,
            orchestratorName: "Test",
            handoffs: []
        )

        let result = try await step.execute("hello", context: context)
        #expect(result.output == "backup: hello")
        #expect(result.metadata["fallback.used"]?.boolValue == true)
        #expect(countingAgent.callCount == 2) // 1 initial + 1 retry
    }

    // MARK: - Metadata tracking

    @Test("FallbackStep tracks retries before success in metadata")
    func fallbackTracksRetriesMetadata() async throws {
        let countingAgent = FallbackCountingAgent(name: "Counting", failCount: 1)
        let backup = FallbackEchoAgent(name: "Backup", prefix: "backup")

        let step = FallbackStep(AgentStep(countingAgent), or: AgentStep(backup), retries: 2)

        let context = OrchestrationStepContext(
            agentContext: AgentContext(input: "test"),
            session: nil,
            hooks: nil,
            orchestrator: nil,
            orchestratorName: "Test",
            handoffs: []
        )

        let result = try await step.execute("hello", context: context)
        // Succeeds on attempt 2 (after 1 retry)
        #expect(result.output.contains("success on attempt 2"))
        #expect(result.metadata["fallback.retries_before_success"]?.intValue == 1)
    }

    @Test("FallbackStep metadata records primary error when backup used")
    func fallbackMetadataRecordsPrimaryError() async throws {
        let primary = FallbackFailingAgent(name: "Primary")
        let backup = FallbackEchoAgent(name: "Backup", prefix: "backup")

        let step = FallbackStep(AgentStep(primary), or: AgentStep(backup))

        let context = OrchestrationStepContext(
            agentContext: AgentContext(input: "test"),
            session: nil,
            hooks: nil,
            orchestrator: nil,
            orchestratorName: "Test",
            handoffs: []
        )

        let result = try await step.execute("hello", context: context)
        #expect(result.metadata["fallback.primary_error"] != nil)
    }

    // MARK: - Composition in Orchestration

    @Test("FallbackStep composes in Sequential")
    func fallbackComposesInSequential() async throws {
        let primary = FallbackFailingAgent(name: "Primary")
        let backup = FallbackEchoAgent(name: "Backup", prefix: "backup")
        let postProcess = FallbackEchoAgent(name: "Post", prefix: "post")

        let workflow = Orchestration {
            Sequential {
                FallbackStep(AgentStep(primary), or: AgentStep(backup))
                AgentStep(postProcess)
            }
        }

        let result = try await workflow.run("hello")
        // backup produces "backup: hello", then post processes that
        #expect(result.output == "post: backup: hello")
    }

    // MARK: - Builder-style init

    @Test("FallbackStep builder-style init with trailing closures")
    func fallbackBuilderStyleInit() async throws {
        let primaryAgent = FallbackFailingAgent(name: "Primary")
        let backupAgent = FallbackEchoAgent(name: "Backup", prefix: "backup")

        let step = FallbackStep {
            AgentStep(primaryAgent)
        } fallback: {
            AgentStep(backupAgent)
        }

        let context = OrchestrationStepContext(
            agentContext: AgentContext(input: "test"),
            session: nil,
            hooks: nil,
            orchestrator: nil,
            orchestratorName: "Test",
            handoffs: []
        )

        let result = try await step.execute("hello", context: context)
        #expect(result.output == "backup: hello")
    }

    // MARK: - Convenience run/stream

    @Test("Orchestration.run static convenience works")
    func orchestrationStaticRunConvenience() async throws {
        let agent = FallbackEchoAgent(name: "Agent", prefix: "result")

        let workflow = Orchestration {
            agent
        }
        let result = try await workflow.run("hello")

        #expect(result.output == "result: hello")
    }

    @Test("Orchestration.stream static convenience works")
    func orchestrationStaticStreamConvenience() async throws {
        let agent = FallbackEchoAgent(name: "Agent", prefix: "result")

        var lastResult: AgentResult?
        let workflow = Orchestration {
            agent
        }
        let stream = workflow.stream("hello")

        for try await event in stream {
            if case .completed(let result) = event {
                lastResult = result
            }
        }

        #expect(lastResult?.output == "result: hello")
    }

    // MARK: - Auto-naming in ParallelBuilder

    @Test("ParallelBuilder auto-naming uses agent config name")
    func parallelBuilderAutoNaming() async throws {
        let namedAgent = FallbackEchoAgent(name: "NamedAgent", prefix: "named")
        let defaultAgent = FallbackEchoAgent(name: "Agent", prefix: "default")

        let workflow = Orchestration {
            Parallel(merge: .structured) {
                namedAgent
                defaultAgent
            }
        }

        let result = try await workflow.run("test")
        // With auto-naming, NamedAgent should appear as a section header
        #expect(result.output.contains("## NamedAgent"))
    }
}
