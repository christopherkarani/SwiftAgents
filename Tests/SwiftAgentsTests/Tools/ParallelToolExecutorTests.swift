// ParallelToolExecutorTests.swift
// SwiftAgentsTests
//
// Comprehensive unit tests for ParallelToolExecutor.

import Foundation
@testable import SwiftAgents
import Testing

// MARK: - MockDelayTool

/// A mock tool with configurable delay for testing parallel execution order.
struct MockDelayTool: Tool, Sendable {
    let name: String
    let delay: Duration
    let resultValue: SendableValue

    var description: String { "Mock tool with delay of \(delay)" }
    var parameters: [ToolParameter] { [] }
    var inputGuardrails: [any ToolInputGuardrail] { [] }
    var outputGuardrails: [any ToolOutputGuardrail] { [] }

    func execute(arguments _: [String: SendableValue]) async throws -> SendableValue {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        return resultValue
    }
}

// MARK: - MockErrorTool

/// A mock tool that always throws an error.
struct MockErrorTool: Tool, Sendable {
    let name: String
    let error: Error

    var description: String { "Mock tool that throws an error" }
    var parameters: [ToolParameter] { [] }
    var inputGuardrails: [any ToolInputGuardrail] { [] }
    var outputGuardrails: [any ToolOutputGuardrail] { [] }

    init(name: String, error: Error = AgentError.toolExecutionFailed(toolName: "mock_error", underlyingError: "Intentional failure")) {
        self.name = name
        self.error = error
    }

    func execute(arguments _: [String: SendableValue]) async throws -> SendableValue {
        throw error
    }
}

// MARK: - ParallelTestMockAgent

/// A minimal mock agent for testing parallel tool execution.
struct ParallelTestMockAgent: Agent {
    let tools: [any Tool]
    let instructions: String
    let configuration: AgentConfiguration
    let memory: (any Memory)?
    let inferenceProvider: (any InferenceProvider)?
    let tracer: (any Tracer)?
    let inputGuardrails: [any InputGuardrail]
    let outputGuardrails: [any OutputGuardrail]
    let handoffs: [AnyHandoffConfiguration]

    init(
        tools: [any Tool] = [],
        instructions: String = "Test agent",
        configuration: AgentConfiguration = .default,
        memory: (any Memory)? = nil,
        inferenceProvider: (any InferenceProvider)? = nil,
        tracer: (any Tracer)? = nil,
        inputGuardrails: [any InputGuardrail] = [],
        outputGuardrails: [any OutputGuardrail] = [],
        handoffs: [AnyHandoffConfiguration] = []
    ) {
        self.tools = tools
        self.instructions = instructions
        self.configuration = configuration
        self.memory = memory
        self.inferenceProvider = inferenceProvider
        self.tracer = tracer
        self.inputGuardrails = inputGuardrails
        self.outputGuardrails = outputGuardrails
        self.handoffs = handoffs
    }

    func run(_: String, session _: (any Session)?, hooks _: (any RunHooks)?) async throws -> AgentResult {
        AgentResult(output: "Mock result", toolCalls: [], toolResults: [], iterationCount: 1, duration: .zero)
    }

    nonisolated func stream(_: String, session _: (any Session)?, hooks _: (any RunHooks)?) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func cancel() async {}
}

// MARK: - ParallelToolExecutorTests

@Suite("ParallelToolExecutor Tests")
struct ParallelToolExecutorTests {
    // MARK: Internal

    // MARK: - Order Preservation Tests

    @Test("Parallel execution maintains order regardless of completion time")
    func parallelExecutionMaintainsOrder() async throws {
        // Create tools with different delays - tool3 finishes first, tool1 last
        let tool1 = MockDelayTool(name: "slow_tool", delay: .milliseconds(50), resultValue: .string("first"))
        let tool2 = MockDelayTool(name: "medium_tool", delay: .milliseconds(25), resultValue: .string("second"))
        let tool3 = MockDelayTool(name: "fast_tool", delay: .milliseconds(5), resultValue: .string("third"))

        let registry = await createRegistry(tools: [tool1, tool2, tool3])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        // Create calls in specific order: slow, medium, fast
        let calls = [
            ToolCall(toolName: "slow_tool", arguments: [:]),
            ToolCall(toolName: "medium_tool", arguments: [:]),
            ToolCall(toolName: "fast_tool", arguments: [:])
        ]

        // Execute in parallel
        let results = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: nil
        )

        // Verify results are in the SAME order as input, not completion order
        #expect(results.count == 3)
        #expect(results[0].toolName == "slow_tool")
        #expect(results[0].value == SendableValue.string("first"))
        #expect(results[1].toolName == "medium_tool")
        #expect(results[1].value == SendableValue.string("second"))
        #expect(results[2].toolName == "fast_tool")
        #expect(results[2].value == SendableValue.string("third"))
    }

    @Test("Order is maintained with many tools")
    func orderWithManyTools() async throws {
        // Create 10 tools with random-ish delays
        var tools: [MockDelayTool] = []
        for i in 0 ..< 10 {
            let delay = Duration.milliseconds((10 - i) * 5) // Reverse order delays
            tools.append(MockDelayTool(
                name: "tool_\(i)",
                delay: delay,
                resultValue: .int(i)
            ))
        }

        let registry = await createRegistry(tools: tools)
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = tools.map { ToolCall(toolName: $0.name, arguments: [:]) }

        let results = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: nil
        )

        // Verify order matches input
        #expect(results.count == 10)
        for i in 0 ..< 10 {
            #expect(results[i].toolName == "tool_\(i)")
            #expect(results[i].value == SendableValue.int(i))
        }
    }

    // MARK: - Error Handling Tests

    @Test("Parallel execution handles errors gracefully with default behavior")
    func parallelExecutionHandlesErrors() async throws {
        let successTool = MockDelayTool(name: "success_tool", delay: .zero, resultValue: .string("success"))
        let errorTool = MockErrorTool(name: "error_tool")

        let registry = await createRegistry(tools: [successTool, errorTool])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [
            ToolCall(toolName: "success_tool", arguments: [:]),
            ToolCall(toolName: "error_tool", arguments: [:])
        ]

        // Default behavior captures errors in results
        let results = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: nil
        )

        #expect(results.count == 2)

        // First result should be success
        #expect(results[0].isSuccess == true)
        #expect(results[0].toolName == "success_tool")
        #expect(results[0].value == SendableValue.string("success"))

        // Second result should be failure
        #expect(results[1].isSuccess == false)
        #expect(results[1].toolName == "error_tool")
        #expect(results[1].error != nil)
    }

    @Test("Error strategy .failFast throws on first error")
    func errorStrategyFailFast() async throws {
        let successTool1 = MockDelayTool(name: "success1", delay: .zero, resultValue: .string("ok1"))
        let errorTool = MockErrorTool(
            name: "error_tool",
            error: AgentError.toolExecutionFailed(toolName: "error_tool", underlyingError: "Test failure")
        )
        let successTool2 = MockDelayTool(name: "success2", delay: .zero, resultValue: .string("ok2"))

        let registry = await createRegistry(tools: [successTool1, errorTool, successTool2])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [
            ToolCall(toolName: "success1", arguments: [:]),
            ToolCall(toolName: "error_tool", arguments: [:]),
            ToolCall(toolName: "success2", arguments: [:])
        ]

        // Should throw the error from the first failing tool
        var thrownError: Error?
        do {
            _ = try await executor.executeInParallel(
                calls,
                using: registry,
                agent: agent,
                context: nil,
                errorStrategy: .failFast
            )
        } catch {
            thrownError = error
        }

        #expect(thrownError != nil)
        if let agentError = thrownError as? AgentError {
            if case let .toolExecutionFailed(toolName, _) = agentError {
                #expect(toolName == "error_tool")
            } else {
                Issue.record("Expected toolExecutionFailed error")
            }
        }
    }

    @Test("Error strategy .collectErrors throws composite error")
    func errorStrategyCollectErrors() async throws {
        let errorTool1 = MockErrorTool(
            name: "error1",
            error: AgentError.toolExecutionFailed(toolName: "error1", underlyingError: "First failure")
        )
        let errorTool2 = MockErrorTool(
            name: "error2",
            error: AgentError.toolExecutionFailed(toolName: "error2", underlyingError: "Second failure")
        )
        let successTool = MockDelayTool(name: "success", delay: .zero, resultValue: .string("ok"))

        let registry = await createRegistry(tools: [errorTool1, errorTool2, successTool])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [
            ToolCall(toolName: "error1", arguments: [:]),
            ToolCall(toolName: "success", arguments: [:]),
            ToolCall(toolName: "error2", arguments: [:])
        ]

        var thrownError: Error?
        do {
            _ = try await executor.executeInParallel(
                calls,
                using: registry,
                agent: agent,
                context: nil,
                errorStrategy: .collectErrors
            )
        } catch {
            thrownError = error
        }

        #expect(thrownError != nil)
        if let agentError = thrownError as? AgentError {
            if case let .toolExecutionFailed(toolName, underlyingError) = agentError {
                #expect(toolName == "parallel_execution")
                #expect(underlyingError.contains("Multiple tools failed"))
            } else {
                Issue.record("Expected toolExecutionFailed with parallel_execution")
            }
        }
    }

    @Test("Error strategy .continueOnError returns all results")
    func errorStrategyContinueOnError() async throws {
        let successTool1 = MockDelayTool(name: "success1", delay: .zero, resultValue: .string("result1"))
        let errorTool = MockErrorTool(name: "error_tool")
        let successTool2 = MockDelayTool(name: "success2", delay: .zero, resultValue: .string("result2"))

        let registry = await createRegistry(tools: [successTool1, errorTool, successTool2])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [
            ToolCall(toolName: "success1", arguments: [:]),
            ToolCall(toolName: "error_tool", arguments: [:]),
            ToolCall(toolName: "success2", arguments: [:])
        ]

        // Should NOT throw, returns results with failures included
        let results = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: nil,
            errorStrategy: .continueOnError
        )

        #expect(results.count == 3)

        // Check each result
        #expect(results[0].isSuccess == true)
        #expect(results[0].value == SendableValue.string("result1"))

        #expect(results[1].isSuccess == false)
        #expect(results[1].error != nil)

        #expect(results[2].isSuccess == true)
        #expect(results[2].value == SendableValue.string("result2"))
    }

    // MARK: - Tool Validation Tests

    @Test("Validates tools exist before execution")
    func validatesToolsExist() async throws {
        let existingTool = MockDelayTool(name: "existing", delay: .zero, resultValue: .string("ok"))
        let registry = await createRegistry(tools: [existingTool])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [
            ToolCall(toolName: "existing", arguments: [:]),
            ToolCall(toolName: "nonexistent", arguments: [:])
        ]

        var thrownError: AgentError?
        do {
            _ = try await executor.executeInParallel(
                calls,
                using: registry,
                agent: agent,
                context: nil
            )
        } catch let error as AgentError {
            thrownError = error
        }

        #expect(thrownError == .toolNotFound(name: "nonexistent"))
    }

    @Test("Tool validation fails fast before any execution")
    func toolValidationFailsFast() async throws {
        // Use a spy tool to verify it was NOT called
        let spyTool = await SpyTool(name: "spy_tool", result: .string("should not execute"))
        let registry = await createRegistry(tools: [spyTool])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [
            ToolCall(toolName: "spy_tool", arguments: [:]),
            ToolCall(toolName: "missing_tool", arguments: [:])
        ]

        do {
            _ = try await executor.executeInParallel(
                calls,
                using: registry,
                agent: agent,
                context: nil
            )
            Issue.record("Should have thrown toolNotFound error")
        } catch let error as AgentError {
            #expect(error == .toolNotFound(name: "missing_tool"))
        }

        // Verify spy tool was never called
        let callCount = await spyTool.callCount
        #expect(callCount == 0)
    }

    // MARK: - Empty Input Tests

    @Test("Empty calls array returns empty results")
    func emptyCallsArray() async throws {
        let registry = ToolRegistry()
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let results = try await executor.executeInParallel(
            [],
            using: registry,
            agent: agent,
            context: nil
        )

        #expect(results.isEmpty)
    }

    @Test("Empty calls array with error strategy returns empty results")
    func emptyCallsWithErrorStrategy() async throws {
        let registry = ToolRegistry()
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let results = try await executor.executeInParallel(
            [],
            using: registry,
            agent: agent,
            context: nil,
            errorStrategy: .failFast
        )

        #expect(results.isEmpty)
    }

    // MARK: - Single Tool Tests

    @Test("Single tool execution works correctly")
    func singleToolExecution() async throws {
        let tool = MockDelayTool(name: "single", delay: .zero, resultValue: .string("single_result"))
        let registry = await createRegistry(tools: [tool])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [ToolCall(toolName: "single", arguments: [:])]

        let results = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: nil
        )

        #expect(results.count == 1)
        #expect(results[0].isSuccess == true)
        #expect(results[0].toolName == "single")
        #expect(results[0].value == SendableValue.string("single_result"))
    }

    @Test("Single failing tool returns failure result")
    func singleFailingTool() async throws {
        let tool = MockErrorTool(name: "fail_single")
        let registry = await createRegistry(tools: [tool])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [ToolCall(toolName: "fail_single", arguments: [:])]

        let results = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: nil
        )

        #expect(results.count == 1)
        #expect(results[0].isSuccess == false)
        #expect(results[0].toolName == "fail_single")
        #expect(results[0].error != nil)
    }

    // MARK: - Arguments Passing Tests

    @Test("Arguments are passed correctly to tools")
    func argumentsPassing() async throws {
        let spyTool = await SpyTool(name: "spy", result: .string("received"))
        let registry = await createRegistry(tools: [spyTool])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let arguments: [String: SendableValue] = [
            "key1": .string("value1"),
            "key2": .int(42),
            "key3": .bool(true)
        ]

        let calls = [ToolCall(toolName: "spy", arguments: arguments)]

        _ = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: nil
        )

        // Verify the spy received the correct arguments
        let lastCall = await spyTool.lastCall
        #expect(lastCall != nil)
        #expect(lastCall?.arguments["key1"] == .string("value1"))
        #expect(lastCall?.arguments["key2"] == .int(42))
        #expect(lastCall?.arguments["key3"] == .bool(true))
    }

    // MARK: - Result Properties Tests

    @Test("Results include duration information")
    func resultsIncludeDuration() async throws {
        let tool = MockDelayTool(name: "delayed", delay: .milliseconds(50), resultValue: .string("done"))
        let registry = await createRegistry(tools: [tool])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [ToolCall(toolName: "delayed", arguments: [:])]

        let results = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: nil
        )

        #expect(results.count == 1)
        // Duration should be at least the delay time
        #expect(results[0].duration >= Duration.milliseconds(50))
    }

    @Test("Results include timestamp")
    func resultsIncludeTimestamp() async throws {
        let beforeExecution = Date()

        let tool = MockDelayTool(name: "timestamped", delay: .zero, resultValue: .string("ok"))
        let registry = await createRegistry(tools: [tool])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [ToolCall(toolName: "timestamped", arguments: [:])]

        let results = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: nil
        )

        let afterExecution = Date()

        #expect(results.count == 1)
        #expect(results[0].timestamp >= beforeExecution)
        #expect(results[0].timestamp <= afterExecution)
    }

    @Test("Results include tool arguments")
    func resultsIncludeArguments() async throws {
        let tool = MockDelayTool(name: "args_test", delay: .zero, resultValue: .string("ok"))
        let registry = await createRegistry(tools: [tool])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let arguments: [String: SendableValue] = ["param": .string("value")]
        let calls = [ToolCall(toolName: "args_test", arguments: arguments)]

        let results = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: nil
        )

        #expect(results.count == 1)
        #expect(results[0].arguments == arguments)
    }

    // MARK: - Convenience Method Tests

    @Test("executeAllCapturingErrors works correctly")
    func testExecuteAllCapturingErrors() async throws {
        let successTool = MockDelayTool(name: "success", delay: .zero, resultValue: .string("ok"))
        let errorTool = MockErrorTool(name: "error")

        let registry = await createRegistry(tools: [successTool, errorTool])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [
            ToolCall(toolName: "success", arguments: [:]),
            ToolCall(toolName: "error", arguments: [:])
        ]

        // Should not throw, errors are captured
        let results = try await executor.executeAllCapturingErrors(
            calls,
            using: registry,
            agent: agent
        )

        #expect(results.count == 2)
        #expect(results[0].isSuccess == true)
        #expect(results[1].isSuccess == false)
    }

    @Test("executeAllOrFail throws on first error")
    func testExecuteAllOrFail() async throws {
        let successTool = MockDelayTool(name: "success", delay: .zero, resultValue: .string("ok"))
        let errorTool = MockErrorTool(name: "error")

        let registry = await createRegistry(tools: [successTool, errorTool])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [
            ToolCall(toolName: "success", arguments: [:]),
            ToolCall(toolName: "error", arguments: [:])
        ]

        var didThrow = false
        do {
            _ = try await executor.executeAllOrFail(
                calls,
                using: registry,
                agent: agent
            )
        } catch {
            didThrow = true
        }

        #expect(didThrow == true)
    }

    // MARK: - All Successes Tests

    @Test("All successful tools return all success results")
    func allSuccessfulTools() async throws {
        let tool1 = MockDelayTool(name: "tool1", delay: .zero, resultValue: .string("result1"))
        let tool2 = MockDelayTool(name: "tool2", delay: .zero, resultValue: .int(42))
        let tool3 = MockDelayTool(name: "tool3", delay: .zero, resultValue: .bool(true))

        let registry = await createRegistry(tools: [tool1, tool2, tool3])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [
            ToolCall(toolName: "tool1", arguments: [:]),
            ToolCall(toolName: "tool2", arguments: [:]),
            ToolCall(toolName: "tool3", arguments: [:])
        ]

        let results = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: nil
        )

        #expect(results.count == 3)
        #expect(results.allSatisfy(\.isSuccess))
        #expect(results[0].value == SendableValue.string("result1"))
        #expect(results[1].value == SendableValue.int(42))
        #expect(results[2].value == SendableValue.bool(true))
    }

    @Test("All failing tools returns all failure results with continueOnError")
    func allFailingTools() async throws {
        let error1 = MockErrorTool(name: "fail1")
        let error2 = MockErrorTool(name: "fail2")
        let error3 = MockErrorTool(name: "fail3")

        let registry = await createRegistry(tools: [error1, error2, error3])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [
            ToolCall(toolName: "fail1", arguments: [:]),
            ToolCall(toolName: "fail2", arguments: [:]),
            ToolCall(toolName: "fail3", arguments: [:])
        ]

        let results = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: nil,
            errorStrategy: .continueOnError
        )

        #expect(results.count == 3)
        #expect(results.allSatisfy { !$0.isSuccess })
        #expect(results.allSatisfy { $0.error != nil })
    }

    // MARK: - Same Tool Multiple Calls Tests

    @Test("Same tool can be called multiple times")
    func sameToolMultipleCalls() async throws {
        let tool = MockDelayTool(name: "reusable", delay: .zero, resultValue: .string("result"))
        let registry = await createRegistry(tools: [tool])
        let executor = ParallelToolExecutor()
        let agent = createMockAgent()

        let calls = [
            ToolCall(toolName: "reusable", arguments: ["id": .int(1)]),
            ToolCall(toolName: "reusable", arguments: ["id": .int(2)]),
            ToolCall(toolName: "reusable", arguments: ["id": .int(3)])
        ]

        let results = try await executor.executeInParallel(
            calls,
            using: registry,
            agent: agent,
            context: nil
        )

        #expect(results.count == 3)
        #expect(results.allSatisfy { $0.toolName == "reusable" })
        #expect(results.allSatisfy(\.isSuccess))

        // Verify arguments are preserved for each call
        #expect(results[0].arguments["id"] == .int(1))
        #expect(results[1].arguments["id"] == .int(2))
        #expect(results[2].arguments["id"] == .int(3))
    }

    // MARK: Private

    // MARK: - Test Helpers

    private func createRegistry(tools: [any Tool]) async -> ToolRegistry {
        let registry = ToolRegistry()
        await registry.register(tools)
        return registry
    }

    private func createMockAgent() -> ParallelTestMockAgent {
        ParallelTestMockAgent()
    }
}

// MARK: - ParallelToolExecutorCancellationTests

@Suite("ParallelToolExecutor Cancellation Tests")
struct ParallelToolExecutorCancellationTests {
    @Test("Parallel execution respects task cancellation")
    func parallelExecutionRespectsCancellation() async throws {
        // Create a slow tool that takes 2 seconds
        let slowTool = DelayedTestTool(name: "slow", delay: .seconds(2), result: .string("completed"))
        let registry = ToolRegistry()
        await registry.register([slowTool])
        let executor = ParallelToolExecutor()
        let agent = ParallelTestMockAgent()

        let calls = [ToolCall(toolName: "slow", arguments: [:])]

        // Start execution in a cancellable task
        let task = Task {
            try await executor.executeInParallel(
                calls,
                using: registry,
                agent: agent,
                context: nil
            )
        }

        // Cancel after a short delay
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        // The task should throw CancellationError
        do {
            _ = try await task.value
            Issue.record("Expected CancellationError to be thrown")
        } catch is CancellationError {
            // Expected - cancellation was respected
        } catch {
            // Other errors are acceptable if they indicate cancellation
            #expect(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
        }
    }

    @Test("Multiple parallel tools with early cancellation")
    func multipleToolsWithEarlyCancellation() async throws {
        // Create multiple slow tools
        let tool1 = DelayedTestTool(name: "slow1", delay: .seconds(1), result: .string("one"))
        let tool2 = DelayedTestTool(name: "slow2", delay: .seconds(1), result: .string("two"))
        let tool3 = DelayedTestTool(name: "slow3", delay: .seconds(1), result: .string("three"))
        let registry = ToolRegistry()
        await registry.register([tool1, tool2, tool3])
        let executor = ParallelToolExecutor()
        let agent = ParallelTestMockAgent()

        let calls = [
            ToolCall(toolName: "slow1", arguments: [:]),
            ToolCall(toolName: "slow2", arguments: [:]),
            ToolCall(toolName: "slow3", arguments: [:])
        ]

        let task = Task {
            try await executor.executeInParallel(
                calls,
                using: registry,
                agent: agent,
                context: nil
            )
        }

        // Cancel almost immediately
        try await Task.sleep(for: .milliseconds(10))
        task.cancel()

        // Should complete quickly due to cancellation
        let startTime = ContinuousClock.now
        _ = try? await task.value
        let elapsed = ContinuousClock.now - startTime

        // If cancellation works, this should complete much faster than 1 second
        #expect(elapsed < .seconds(1), "Cancellation took too long: \(elapsed)")
    }
}

// MARK: - DelayedTestTool

/// A test tool that delays for a specified duration before returning
private struct DelayedTestTool: Tool, Sendable {
    let name: String
    let delay: Duration
    let result: SendableValue

    var description: String { "A tool that delays for \(delay)" }
    var parameters: [ToolParameter] { [] }

    func execute(arguments _: [String: SendableValue]) async throws -> SendableValue {
        try await Task.sleep(for: delay)
        return result
    }
}
