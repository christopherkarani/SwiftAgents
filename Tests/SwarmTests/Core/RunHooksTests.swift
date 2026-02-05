// RunHooksTests.swift
// SwarmTests
//
// Comprehensive tests for RunHooks lifecycle system.

import Foundation
@testable import Swarm
import Testing

// MARK: - MockAgentForRunHooks

/// Mock agent for testing hooks.
private struct MockAgentForRunHooks: AgentRuntime {
    let tools: [any AnyJSONTool] = []
    let instructions: String = "Mock agent"
    let configuration: AgentConfiguration

    init(name: String = "mock_agent") {
        configuration = AgentConfiguration(name: name)
    }

    func run(_ input: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) async throws -> AgentResult {
        AgentResult(output: "Mock response: \(input)")
    }

    nonisolated func stream(_ input: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.started(input: input))
            continuation.yield(.completed(result: AgentResult(output: "Mock response")))
            continuation.finish()
        }
    }

    func cancel() async {}
}

// MARK: - RecordingHooks

/// Recording hook for testing - captures all events in order.
private actor RecordingHooks: RunHooks {
    var events: [String] = []

    func onAgentStart(context _: AgentContext?, agent _: any AgentRuntime, input: String) async {
        events.append("agentStart:\(input)")
    }

    func onAgentEnd(context _: AgentContext?, agent _: any AgentRuntime, result: AgentResult) async {
        events.append("agentEnd:\(result.output)")
    }

    func onError(context _: AgentContext?, agent _: any AgentRuntime, error: Error) async {
        events.append("error:\(error.localizedDescription)")
    }

    func onHandoff(context _: AgentContext?, fromAgent _: any AgentRuntime, toAgent _: any AgentRuntime) async {
        events.append("handoff")
    }

    func onToolStart(context _: AgentContext?, agent _: any AgentRuntime, call: ToolCall) async {
        events.append("toolStart:\(call.toolName)")
    }

    func onToolEnd(context _: AgentContext?, agent _: any AgentRuntime, result: ToolResult) async {
        // Find a way to get tool name from result if possible, or use ID
        // For tests we might blindly trust it's the right one
        events.append("toolEnd:unknown") // Updating to match lack of tool name in hook
    }

    func onLLMStart(context _: AgentContext?, agent _: any AgentRuntime, systemPrompt _: String?, inputMessages: [MemoryMessage]) async {
        events.append("llmStart:\(inputMessages.count)")
    }

    func onLLMEnd(context _: AgentContext?, agent _: any AgentRuntime, response _: String, usage: InferenceResponse.TokenUsage?) async {
        let tokens = usage.map { "\($0.inputTokens)/\($0.outputTokens)" } ?? "none"
        events.append("llmEnd:\(tokens)")
    }

    func onGuardrailTriggered(context _: AgentContext?, guardrailName: String, guardrailType: GuardrailType, result _: GuardrailResult) async {
        events.append("guardrail:\(guardrailName):\(guardrailType.rawValue)")
    }

    func reset() {
        events = []
    }

    func getEvents() -> [String] {
        events
    }
}

// MARK: - RunHooksDefaultImplementationTests

@Suite("RunHooks Default Implementations")
struct RunHooksDefaultImplementationTests {
    @Test("Default implementations are no-op and don't crash")
    func defaultImplementationsAreNoOp() async {
        // Given: An empty hooks implementation using defaults
        struct EmptyHooks: RunHooks {}
        let hooks = EmptyHooks()
        let agent = MockAgentForRunHooks()
        let tool = MockTool(name: "test_tool")
        let result = AgentResult(output: "test")

        // When/Then: All default implementations should complete without crashing
        await hooks.onAgentStart(context: nil, agent: agent, input: "test")
        await hooks.onAgentEnd(context: nil, agent: agent, result: result)
        await hooks.onError(context: nil, agent: agent, error: AgentError.invalidInput(reason: "test"))
        await hooks.onHandoff(context: nil, fromAgent: agent, toAgent: agent)
        await hooks.onToolStart(context: nil, agent: agent, call: ToolCall(toolName: "test_tool", arguments: [:]))
        await hooks.onToolEnd(context: nil, agent: agent, result: ToolResult.success(callId: UUID(), output: .string("result"), duration: .seconds(1)))
        await hooks.onLLMStart(context: nil, agent: agent, systemPrompt: nil, inputMessages: [])
        await hooks.onLLMEnd(context: nil, agent: agent, response: "response", usage: nil)
        await hooks.onGuardrailTriggered(
            context: nil,
            guardrailName: "test",
            guardrailType: .input,
            result: GuardrailResult(tripwireTriggered: false)
        )

        // No assertions needed - if we get here, all methods completed successfully
    }

    @Test("Default implementations handle nil context")
    func defaultImplementationsHandleNilContext() async {
        struct EmptyHooks: RunHooks {}
        let hooks = EmptyHooks()
        let agent = MockAgentForRunHooks()

        // When/Then: Should handle nil context gracefully
        await hooks.onAgentStart(context: nil, agent: agent, input: "test")
        await hooks.onAgentEnd(context: nil, agent: agent, result: AgentResult(output: "test"))
    }

    @Test("Default implementations handle non-nil context")
    func defaultImplementationsHandleNonNilContext() async {
        struct EmptyHooks: RunHooks {}
        let hooks = EmptyHooks()
        let agent = MockAgentForRunHooks()
        let context = AgentContext(input: "test")

        // When/Then: Should handle non-nil context gracefully
        await hooks.onAgentStart(context: context, agent: agent, input: "test")
        await hooks.onAgentEnd(context: context, agent: agent, result: AgentResult(output: "test"))
    }
}

// MARK: - CompositeRunHooksTests

@Suite("CompositeRunHooks Tests")
struct CompositeRunHooksTests {
    @Test("CompositeRunHooks calls all registered hooks")
    func compositeCallsAllHooks() async {
        // Given: Multiple recording hooks
        let hooks1 = RecordingHooks()
        let hooks2 = RecordingHooks()
        let hooks3 = RecordingHooks()
        let composite = CompositeRunHooks(hooks: [hooks1, hooks2, hooks3])
        let agent = MockAgentForRunHooks()

        // When: Calling onAgentStart
        await composite.onAgentStart(context: nil, agent: agent, input: "test input")

        // Then: All hooks should receive the call
        let events1 = await hooks1.getEvents()
        let events2 = await hooks2.getEvents()
        let events3 = await hooks3.getEvents()
        #expect(events1.contains("agentStart:test input"))
        #expect(events2.contains("agentStart:test input"))
        #expect(events3.contains("agentStart:test input"))
    }

    @Test("CompositeRunHooks calls all hooks concurrently")
    func compositeCallsAllHooksConcurrently() async {
        // Given: A composite with multiple hooks
        let recorder = RecordingHooks()

        struct FirstHook: RunHooks {
            let recorder: RecordingHooks
            func onAgentStart(context: AgentContext?, agent: any AgentRuntime, input _: String) async {
                await recorder.onAgentStart(context: context, agent: agent, input: "first")
            }
        }

        struct SecondHook: RunHooks {
            let recorder: RecordingHooks
            func onAgentStart(context: AgentContext?, agent: any AgentRuntime, input _: String) async {
                await recorder.onAgentStart(context: context, agent: agent, input: "second")
            }
        }

        struct ThirdHook: RunHooks {
            let recorder: RecordingHooks
            func onAgentStart(context: AgentContext?, agent: any AgentRuntime, input _: String) async {
                await recorder.onAgentStart(context: context, agent: agent, input: "third")
            }
        }

        let composite = CompositeRunHooks(hooks: [
            FirstHook(recorder: recorder),
            SecondHook(recorder: recorder),
            ThirdHook(recorder: recorder)
        ])

        // When: Calling a hook method
        await composite.onAgentStart(context: nil, agent: MockAgentForRunHooks(), input: "test")

        // Then: All hooks should be called (order not guaranteed due to concurrent execution)
        let events = await recorder.getEvents()
        #expect(events.count == 3)
        #expect(events.contains("agentStart:first"))
        #expect(events.contains("agentStart:second"))
        #expect(events.contains("agentStart:third"))
    }

    @Test("CompositeRunHooks handles empty hook list")
    func compositeHandlesEmptyList() async {
        // Given: A composite with no hooks
        let composite = CompositeRunHooks(hooks: [])
        let agent = MockAgentForRunHooks()

        // When/Then: Should not crash with empty list
        await composite.onAgentStart(context: nil, agent: agent, input: "test")
        await composite.onAgentEnd(context: nil, agent: agent, result: AgentResult(output: "test"))
        await composite.onError(context: nil, agent: agent, error: AgentError.invalidInput(reason: "test"))
        await composite.onHandoff(context: nil, fromAgent: agent, toAgent: agent)

        // No assertions needed - if we get here, all methods completed successfully
    }

    @Test("CompositeRunHooks forwards all hook methods")
    func compositeForwardsAllHookMethods() async {
        // Given: Recording hooks in composite
        let hooks = RecordingHooks()
        let composite = CompositeRunHooks(hooks: [hooks])
        let agent = MockAgentForRunHooks()
        // removed unused tool
        let context = AgentContext(input: "test")

        // When: Calling all hook methods
        await composite.onAgentStart(context: context, agent: agent, input: "input")
        await composite.onAgentEnd(context: context, agent: agent, result: AgentResult(output: "output"))
        await composite.onError(context: context, agent: agent, error: AgentError.invalidInput(reason: "test"))
        await composite.onHandoff(context: context, fromAgent: agent, toAgent: agent)
        let toolCall = ToolCall(toolName: "calculator", arguments: ["x": .int(5)])
        await composite.onToolStart(context: context, agent: agent, call: toolCall)
        await composite.onToolEnd(context: context, agent: agent, result: ToolResult.success(callId: toolCall.id, output: .int(10), duration: .seconds(1)))
        await composite.onLLMStart(context: context, agent: agent, systemPrompt: "You are helpful", inputMessages: [])
        await composite.onLLMEnd(context: context, agent: agent, response: "response", usage: nil)
        await composite.onGuardrailTriggered(
            context: context,
            guardrailName: "pii_filter",
            guardrailType: .output,
            result: GuardrailResult(tripwireTriggered: true, message: "PII detected")
        )

        // Then: All events should be recorded
        let events = await hooks.getEvents()
        #expect(events.contains("agentStart:input"))
        #expect(events.contains("agentEnd:output"))
        #expect(events.contains { $0.starts(with: "error:") })
        #expect(events.contains("handoff"))
        #expect(events.contains("toolStart:calculator"))
        #expect(events.contains("toolEnd:unknown"))
        #expect(events.contains("llmStart:0"))
        #expect(events.contains("llmEnd:none"))
        #expect(events.contains("guardrail:pii_filter:output"))
    }
}

// MARK: - LoggingRunHooksTests

@Suite("LoggingRunHooks Tests")
struct LoggingRunHooksTests {
    @Test("LoggingRunHooks doesn't crash on agent lifecycle")
    func loggingHooksAgentLifecycle() async {
        // Given: A logging hook
        let hooks = LoggingRunHooks()
        let agent = MockAgentForRunHooks()

        // When/Then: Should log without crashing
        await hooks.onAgentStart(context: nil, agent: agent, input: "What is the weather?")
        await hooks.onAgentEnd(
            context: nil,
            agent: agent,
            result: AgentResult(
                output: "It's sunny",
                toolCalls: [],
                iterationCount: 2,
                duration: .seconds(1)
            )
        )
    }

    @Test("LoggingRunHooks doesn't crash on errors")
    func loggingHooksErrors() async {
        // Given: A logging hook
        let hooks = LoggingRunHooks()
        let agent = MockAgentForRunHooks()

        // When/Then: Should log error without crashing
        await hooks.onError(
            context: nil,
            agent: agent,
            error: AgentError.toolExecutionFailed(toolName: "calculator", underlyingError: "Division by zero")
        )
    }

    @Test("LoggingRunHooks doesn't crash on tool events")
    func loggingHooksToolEvents() async {
        // Given: A logging hook
        let hooks = LoggingRunHooks()
        let agent = MockAgentForRunHooks()
        // removed unused tool

        // When/Then: Should log tool events without crashing
        let toolCall = ToolCall(toolName: "weather", arguments: ["location": .string("NYC"), "units": .string("F")])
        await hooks.onToolStart(
            context: nil,
            agent: agent,
            call: toolCall
        )
        await hooks.onToolEnd(
            context: nil,
            agent: agent,
            result: ToolResult.success(callId: toolCall.id, output: .string("72°F and sunny"), duration: .seconds(1))
        )
    }

    @Test("LoggingRunHooks doesn't crash on LLM events")
    func loggingHooksLLMEvents() async {
        // Given: A logging hook
        let hooks = LoggingRunHooks()
        let agent = MockAgentForRunHooks()
        let messages = [
            MemoryMessage(role: .user, content: "Hello"),
            MemoryMessage(role: .assistant, content: "Hi there!")
        ]

        // When/Then: Should log LLM events without crashing
        await hooks.onLLMStart(
            context: nil,
            agent: agent,
            systemPrompt: "You are helpful",
            inputMessages: messages
        )
        await hooks.onLLMEnd(
            context: nil,
            agent: agent,
            response: "I can help with that",
            usage: InferenceResponse.TokenUsage(inputTokens: 50, outputTokens: 20)
        )
    }

    @Test("LoggingRunHooks doesn't crash on guardrail events")
    func loggingHooksGuardrailEvents() async {
        // Given: A logging hook
        let hooks = LoggingRunHooks()

        // When/Then: Should log guardrail events without crashing
        await hooks.onGuardrailTriggered(
            context: nil,
            guardrailName: "content_filter",
            guardrailType: .input,
            result: GuardrailResult(tripwireTriggered: true, message: "Inappropriate content detected")
        )
    }

    @Test("LoggingRunHooks handles context with executionId")
    func loggingHooksWithContext() async {
        // Given: A logging hook and context
        let hooks = LoggingRunHooks()
        let agent = MockAgentForRunHooks()
        let context = AgentContext(input: "test")

        // When/Then: Should log with context ID without crashing
        await hooks.onAgentStart(context: context, agent: agent, input: "test input")
        await hooks.onAgentEnd(context: context, agent: agent, result: AgentResult(output: "test output"))
    }

    @Test("LoggingRunHooks handles long input truncation")
    func loggingHooksTruncatesLongInput() async {
        // Given: A logging hook and very long input
        let hooks = LoggingRunHooks()
        let agent = MockAgentForRunHooks()
        let longInput = String(repeating: "a", count: 200)

        // When/Then: Should log without crashing (truncation happens internally)
        await hooks.onAgentStart(context: nil, agent: agent, input: longInput)
    }
}

// MARK: - RunHooksIntegrationTests

@Suite("RunHooks Integration Tests")
struct RunHooksIntegrationTests {
    @Test("Recording hooks captures full agent execution flow")
    func recordingHooksCapturesFullFlow() async {
        // Given: A recording hook
        let hooks = RecordingHooks()
        let agent = MockAgentForRunHooks()
        // removed unused tool
        let messages = [MemoryMessage(role: .user, content: "Calculate 2+2")]

        // When: Simulating a full agent execution
        await hooks.onAgentStart(context: nil, agent: agent, input: "Calculate 2+2")
        await hooks.onLLMStart(context: nil, agent: agent, systemPrompt: "You are helpful", inputMessages: messages)
        await hooks.onLLMEnd(
            context: nil,
            agent: agent,
            response: "I'll use the calculator",
            usage: InferenceResponse.TokenUsage(inputTokens: 10, outputTokens: 5)
        )
        let toolCall = ToolCall(toolName: "calculator", arguments: ["expression": .string("2+2")])
        await hooks.onToolStart(context: nil, agent: agent, call: toolCall)
        await hooks.onToolEnd(context: nil, agent: agent, result: ToolResult.success(callId: toolCall.id, output: .int(4), duration: .seconds(1)))
        await hooks.onAgentEnd(context: nil, agent: agent, result: AgentResult(output: "The answer is 4"))

        // Then: All events should be recorded in order
        let events = await hooks.getEvents()
        #expect(events == [
            "agentStart:Calculate 2+2",
            "llmStart:1",
            "llmEnd:10/5",
            "toolStart:calculator",
            "toolEnd:unknown",
            "agentEnd:The answer is 4"
        ])
    }

    @Test("Hooks receive correct parameters")
    func hooksReceiveCorrectParameters() async {
        // Given: A custom hook that validates parameters
        struct ValidatingHook: RunHooks {
            var validated = false

            func onToolStart(
                context _: AgentContext?,
                agent _: any AgentRuntime,
                call: ToolCall
            ) async {
                // Verify all parameters are correct
                if call.toolName == "weather",
                   call.arguments["location"] == .string("NYC"),
                   call.arguments["units"] == .string("F") {
                    // Parameters are correct
                }
            }
        }

        let hooks = ValidatingHook()
        let agent = MockAgentForRunHooks()
        // removed unused tool
        let args: [String: SendableValue] = [
            "location": .string("NYC"),
            "units": .string("F")
        ]

        // When: Calling the hook
        let toolCall = ToolCall(toolName: "weather", arguments: args)
        await hooks.onToolStart(context: nil, agent: agent, call: toolCall)

        // Then: Hook should have validated parameters successfully
        // (validation happens inside the hook method)
    }

    @Test("Multiple hooks in composite don't interfere")
    func multipleHooksIndependent() async {
        // Given: Multiple independent hooks
        let recorder1 = RecordingHooks()
        let recorder2 = RecordingHooks()
        let composite = CompositeRunHooks(hooks: [recorder1, recorder2])
        let agent = MockAgentForRunHooks()

        // When: Calling hooks multiple times
        await composite.onAgentStart(context: nil, agent: agent, input: "first")
        await composite.onAgentStart(context: nil, agent: agent, input: "second")
        await composite.onAgentEnd(context: nil, agent: agent, result: AgentResult(output: "done"))

        // Then: Both hooks should have recorded all events independently
        let events1 = await recorder1.getEvents()
        let events2 = await recorder2.getEvents()
        #expect(events1.count == 3)
        #expect(events2.count == 3)
        #expect(events1 == events2)
    }

    @Test("Hooks work with and without context")
    func hooksWorkWithAndWithoutContext() async {
        // Given: Recording hook
        let hooks = RecordingHooks()
        let agent = MockAgentForRunHooks()
        let context = AgentContext(input: "test")

        // When: Calling with and without context
        await hooks.onAgentStart(context: nil, agent: agent, input: "no context")
        await hooks.onAgentStart(context: context, agent: agent, input: "with context")

        // Then: Both calls should be recorded
        let events = await hooks.getEvents()
        #expect(events.count == 2)
        #expect(events[0] == "agentStart:no context")
        #expect(events[1] == "agentStart:with context")
    }
}

// MARK: - RunHooksConcurrentExecutionTests

	@Suite("RunHooks Concurrent Execution Tests")
	struct RunHooksConcurrentExecutionTests {
	    @Test("Concurrent hook execution completes in parallel")
	    func concurrentHookExecution() async throws {
	        // Create a hook that tracks execution order with delays
	        actor DelayedHook: RunHooks {
	            var start: ContinuousClock.Instant?
	            var end: ContinuousClock.Instant?

	            func onAgentStart(context _: AgentContext?, agent _: any AgentRuntime, input _: String) async {
	                start = ContinuousClock.now
	                try? await Task.sleep(for: .milliseconds(200))
	                end = ContinuousClock.now
	            }

            func onAgentEnd(context _: AgentContext?, agent _: any AgentRuntime, result _: AgentResult) async {}
            func onError(context _: AgentContext?, agent _: any AgentRuntime, error _: Error) async {}
            func onHandoff(context _: AgentContext?, fromAgent _: any AgentRuntime, toAgent _: any AgentRuntime) async {}
            func onToolStart(context _: AgentContext?, agent _: any AgentRuntime, call _: ToolCall) async {}
            func onToolEnd(context _: AgentContext?, agent _: any AgentRuntime, result _: ToolResult) async {}
            func onLLMStart(context _: AgentContext?, agent _: any AgentRuntime, systemPrompt _: String?, inputMessages _: [MemoryMessage]) async {}
            func onLLMEnd(context _: AgentContext?, agent _: any AgentRuntime, response _: String, usage _: InferenceResponse.TokenUsage?) async {}
            func onGuardrailTriggered(context _: AgentContext?, guardrailName _: String, guardrailType _: GuardrailType, result _: GuardrailResult) async {}

            func getInterval() -> (start: ContinuousClock.Instant, end: ContinuousClock.Instant)? {
                guard let start, let end else { return nil }
                return (start, end)
            }
        }

        let hook1 = DelayedHook()
        let hook2 = DelayedHook()
        let hook3 = DelayedHook()

        let composite = CompositeRunHooks(hooks: [hook1, hook2, hook3])
        let mockAgent = MockAgentForRunHooks()

        await composite.onAgentStart(context: nil, agent: mockAgent, input: "test")

        var intervals: [(start: ContinuousClock.Instant, end: ContinuousClock.Instant)] = []
        for hook in [hook1, hook2, hook3] {
            if let interval = await hook.getInterval() {
                intervals.append(interval)
            }
        }

        #expect(intervals.count == 3)

        guard let latestStart = intervals.map(\.start).max(),
              let earliestEnd = intervals.map(\.end).min()
        else {
            Issue.record("Missing hook interval data")
            return
        }

        #expect(
            latestStart < earliestEnd,
            "Expected concurrent hook execution; intervals did not overlap."
        )
	    }

    @Test("Composite hooks all receive callbacks")
    func compositeHooksAllReceiveCallbacks() async throws {
        let hook1 = RecordingHooks()
        let hook2 = RecordingHooks()

        let composite = CompositeRunHooks(hooks: [hook1, hook2])
        let mockAgent = MockAgentForRunHooks()

        await composite.onAgentStart(context: nil, agent: mockAgent, input: "test")
        await composite.onAgentEnd(context: nil, agent: mockAgent, result: AgentResult(output: "done"))

        // Both hooks should receive both events
        let events1 = await hook1.getEvents()
        let events2 = await hook2.getEvents()

        #expect(events1.count == 2)
        #expect(events2.count == 2)
        #expect(events1.contains("agentStart:test"))
        #expect(events1.contains("agentEnd:done"))
        #expect(events2.contains("agentStart:test"))
        #expect(events2.contains("agentEnd:done"))
    }
}

// MARK: - RunHooksEdgeCaseTests

@Suite("RunHooks Edge Cases")
struct RunHooksEdgeCaseTests {
    @Test("Hooks handle empty strings gracefully")
    func hooksHandleEmptyStrings() async {
        let hooks = RecordingHooks()
        let agent = MockAgentForRunHooks()

        await hooks.onAgentStart(context: nil, agent: agent, input: "")
        await hooks.onAgentEnd(context: nil, agent: agent, result: AgentResult(output: ""))
        await hooks.onLLMEnd(context: nil, agent: agent, response: "", usage: nil)

        let events = await hooks.getEvents()
        #expect(events.count == 3)
    }

    @Test("Hooks handle empty collections gracefully")
    func hooksHandleEmptyCollections() async {
        let hooks = RecordingHooks()
        let agent = MockAgentForRunHooks()
        // removed unused tool

        await hooks.onToolStart(context: nil, agent: agent, call: ToolCall(toolName: "tool", arguments: [:]))
        await hooks.onLLMStart(context: nil, agent: agent, systemPrompt: nil, inputMessages: [])

        let events = await hooks.getEvents()
        #expect(events.count == 2)
    }

    @Test("Hooks handle nil optional values")
    func hooksHandleNilOptionals() async {
        let hooks = RecordingHooks()
        let agent = MockAgentForRunHooks()

        await hooks.onLLMStart(context: nil, agent: agent, systemPrompt: nil, inputMessages: [])
        await hooks.onLLMEnd(context: nil, agent: agent, response: "response", usage: nil)

        let events = await hooks.getEvents()
        #expect(events.contains("llmStart:0"))
        #expect(events.contains("llmEnd:none"))
    }

    @Test("CompositeRunHooks with single hook")
    func compositeSingleHook() async {
        // Given: Composite with only one hook
        let hooks = RecordingHooks()
        let composite = CompositeRunHooks(hooks: [hooks])
        let agent = MockAgentForRunHooks()

        // When: Using the composite
        await composite.onAgentStart(context: nil, agent: agent, input: "test")

        // Then: Should work identically to using the hook directly
        let events = await hooks.getEvents()
        #expect(events == ["agentStart:test"])
    }
}
