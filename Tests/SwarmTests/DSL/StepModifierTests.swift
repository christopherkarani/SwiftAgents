// StepModifierTests.swift
// SwarmTests
//
// Tests for StepModifier protocol and built-in modifiers.

import Foundation
@testable import Swarm
import Testing

// MARK: - Test Helpers

/// A simple step that echoes input, useful for modifier tests.
private struct EchoStep: OrchestrationStep {
    func execute(_ input: String, context _: OrchestrationStepContext) async throws -> AgentResult {
        AgentResult(output: "echo:\(input)")
    }
}

/// A step that fails a configurable number of times before succeeding.
private struct FlakeyStep: OrchestrationStep {
    let failCount: Int
    let callCounter: CallCounter

    final class CallCounter: @unchecked Sendable {
        private var _count = 0
        private let lock = NSLock()

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return _count
        }

        func increment() -> Int {
            lock.lock()
            defer { lock.unlock() }
            _count += 1
            return _count
        }
    }

    func execute(_ input: String, context _: OrchestrationStepContext) async throws -> AgentResult {
        let current = callCounter.increment()
        if current <= failCount {
            throw AgentError.internalError(reason: "attempt \(current) failed")
        }
        return AgentResult(output: "success:\(input)", metadata: ["attempt": .int(current)])
    }
}

/// A step that always fails.
private struct AlwaysFailStep: OrchestrationStep {
    func execute(_: String, context _: OrchestrationStepContext) async throws -> AgentResult {
        throw AgentError.internalError(reason: "always fails")
    }
}

/// A step that sleeps for a given duration.
private struct SlowStep: OrchestrationStep {
    let sleepDuration: Duration

    func execute(_ input: String, context _: OrchestrationStepContext) async throws -> AgentResult {
        try await Task.sleep(for: sleepDuration)
        return AgentResult(output: "slow:\(input)")
    }
}

/// Creates a minimal OrchestrationStepContext for testing.
private func makeTestContext() -> OrchestrationStepContext {
    OrchestrationStepContext(
        agentContext: AgentContext(input: "test"),
        session: nil,
        hooks: nil,
        orchestrator: nil,
        orchestratorName: "TestOrchestration",
        handoffs: []
    )
}

// MARK: - RetryModifier Tests

@Suite("RetryModifier Tests")
struct RetryModifierTests {
    @Test("Retries on failure up to maxAttempts then throws")
    func retryExhaustsAttempts() async throws {
        let step = AlwaysFailStep()
            .retry(maxAttempts: 3, delay: .milliseconds(10))

        await #expect(throws: AgentError.self) {
            try await step.execute("input", context: makeTestContext())
        }
    }

    @Test("Succeeds on second attempt")
    func retrySucceedsOnSecondAttempt() async throws {
        let counter = FlakeyStep.CallCounter()
        let step = FlakeyStep(failCount: 1, callCounter: counter)
            .retry(maxAttempts: 3, delay: .milliseconds(10))

        let result = try await step.execute("hello", context: makeTestContext())
        #expect(result.output == "success:hello")
        #expect(counter.count == 2)
    }

    @Test("Succeeds immediately without retry")
    func retrySucceedsFirstAttempt() async throws {
        let counter = FlakeyStep.CallCounter()
        let step = FlakeyStep(failCount: 0, callCounter: counter)
            .retry(maxAttempts: 3, delay: .milliseconds(10))

        let result = try await step.execute("hello", context: makeTestContext())
        #expect(result.output == "success:hello")
        #expect(counter.count == 1)
    }

    @Test("Retry metadata tracks attempt count")
    func retryMetadataTracksAttempts() async throws {
        let counter = FlakeyStep.CallCounter()
        let step = FlakeyStep(failCount: 2, callCounter: counter)
            .retry(maxAttempts: 5, delay: .milliseconds(10))

        let result = try await step.execute("test", context: makeTestContext())
        #expect(result.metadata["retry.attempts"]?.intValue == 3)
        #expect(result.metadata["retry.succeeded"]?.boolValue == true)
    }

    @Test("Invalid maxAttempts is coerced to a single attempt without crashing")
    func retryCoercesInvalidAttempts() async throws {
        let counter = FlakeyStep.CallCounter()
        let step = FlakeyStep(failCount: 0, callCounter: counter)
            .retry(maxAttempts: 0, delay: .milliseconds(10))

        let result = try await step.execute("safe", context: makeTestContext())
        #expect(result.output == "success:safe")
        #expect(counter.count == 1)
        #expect(result.metadata["retry.attempts"]?.intValue == 1)
    }
}

// MARK: - TimeoutModifier Tests

@Suite("TimeoutModifier Tests")
struct TimeoutModifierTests {
    @Test("Cancels step after deadline")
    func timeoutCancels() async throws {
        let step = SlowStep(sleepDuration: .seconds(10))
            .timeout(.milliseconds(50))

        await #expect(throws: (any Error).self) {
            try await step.execute("input", context: makeTestContext())
        }
    }

    @Test("Allows fast step to complete")
    func timeoutAllowsFastStep() async throws {
        let step = EchoStep()
            .timeout(.seconds(5))

        let result = try await step.execute("fast", context: makeTestContext())
        #expect(result.output == "echo:fast")
    }
}

// MARK: - NamedModifier Tests

@Suite("NamedModifier Tests")
struct NamedModifierTests {
    @Test("Adds name to metadata")
    func namedAddsMetadata() async throws {
        let step = EchoStep()
            .named("my-step")

        let result = try await step.execute("input", context: makeTestContext())
        #expect(result.output == "echo:input")
        #expect(result.metadata["step.name"]?.stringValue == "my-step")
    }
}

// MARK: - LoggingModifier Tests

@Suite("LoggingModifier Tests")
struct LoggingModifierTests {
    @Test("Records input and output in metadata")
    func loggingRecordsMetadata() async throws {
        let step = EchoStep()
            .logged(label: "test-step")

        let result = try await step.execute("hello world", context: makeTestContext())
        #expect(result.output == "echo:hello world")
        #expect(result.metadata["logging.label"]?.stringValue == "test-step")
        #expect(result.metadata["logging.input"]?.stringValue == "hello world")
        #expect(result.metadata["logging.output"]?.stringValue == "echo:hello world")
    }

    @Test("Uses default label when none provided")
    func loggingUsesDefaultLabel() async throws {
        let step = EchoStep()
            .logged()

        let result = try await step.execute("data", context: makeTestContext())
        #expect(result.metadata["logging.label"]?.stringValue == "OrchestrationStep")
    }
}

// MARK: - Modifier Composition Tests

@Suite("StepModifier Composition Tests")
struct StepModifierCompositionTests {
    @Test("Modifiers compose via chaining")
    func modifiersChain() async throws {
        let counter = FlakeyStep.CallCounter()
        let step = FlakeyStep(failCount: 1, callCounter: counter)
            .retry(maxAttempts: 3, delay: .milliseconds(10))
            .timeout(.seconds(5))

        let result = try await step.execute("chain", context: makeTestContext())
        #expect(result.output == "success:chain")
    }

    @Test("Named + logged compose")
    func namedAndLoggedCompose() async throws {
        let step = EchoStep()
            .named("composed-step")
            .logged(label: "compose-log")

        let result = try await step.execute("compose", context: makeTestContext())
        #expect(result.output == "echo:compose")
        #expect(result.metadata["logging.label"]?.stringValue == "compose-log")
    }

    @Test("ModifiedStep works inside Sequential")
    func modifiedStepInSequential() async throws {
        let step1 = Transform { input in "step1:\(input)" }
            .named("transform-1")
        let step2 = EchoStep()
            .named("echo-step")

        let sequential = Sequential {
            step1
            step2
        }

        let result = try await sequential.execute("begin", context: makeTestContext())
        #expect(result.output == "echo:step1:begin")
    }

    @Test("ModifiedStep conforms to OrchestrationStep for builder")
    func modifiedStepInOrchestrationBuilder() async throws {
        let workflow = Orchestration {
            EchoStep().named("first")
            Transform { input in "transformed:\(input)" }.logged()
        }

        let result = try await workflow.run("start")
        #expect(result.output == "transformed:echo:start")
    }
}
