// SupervisorAgentTests.swift
// SwarmTests
//
// Comprehensive tests for SupervisorAgent orchestration

import Foundation
@testable import Swarm
import Testing

// MARK: - MockSupervisorTestAgent

/// Simple mock agent for testing supervisor routing
actor MockSupervisorTestAgent: AgentRuntime {
    let agentName: String
    let responsePrefix: String

    nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions: String
    nonisolated let configuration: AgentConfiguration = .default
    private(set) var runCallCount = 0
    private(set) var lastInput: String?

    nonisolated var memory: (any Memory)? { nil }
    nonisolated var inferenceProvider: (any InferenceProvider)? { nil }

    init(name: String, responsePrefix: String = "Response from", instructions: String = "") {
        agentName = name
        self.responsePrefix = responsePrefix
        self.instructions = instructions.isEmpty ? "I am \(name)" : instructions
    }

    func run(_ input: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) async throws -> AgentResult {
        runCallCount += 1
        lastInput = input

        let builder = AgentResult.Builder()
        builder.start()
        builder.setOutput("\(responsePrefix) \(agentName): \(input)")
        return builder.build()
    }

    nonisolated func stream(_ input: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream<AgentEvent, Error>.makeStream()
        Task { @Sendable [weak self] in
            guard let self else {
                continuation.finish()
                return
            }
            do {
                continuation.yield(.started(input: input))
                continuation.yield(.thinking(thought: "Thinking about: \(input)"))
                let result = try await run(input)
                continuation.yield(.completed(result: result))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return stream
    }

    func cancel() async {}

    func getCallCount() -> Int {
        runCallCount
    }

    func getLastInput() -> String? {
        lastInput
    }
}

// MARK: - SupervisorAgentInitializationTests

@Suite("SupervisorAgent Initialization Tests")
struct SupervisorAgentInitializationTests {
    @Test("Initializes with agents and routing strategy")
    func initialization() async {
        let calcAgent = MockSupervisorTestAgent(name: "calculator")
        let weatherAgent = MockSupervisorTestAgent(name: "weather")

        let calcDesc = AgentDescription(
            name: "calculator",
            description: "Does math"
        )
        let weatherDesc = AgentDescription(
            name: "weather",
            description: "Weather info"
        )

        let supervisor = SupervisorAgent(
            agents: [
                (name: "calculator", agent: calcAgent, description: calcDesc),
                (name: "weather", agent: weatherAgent, description: weatherDesc)
            ],
            routingStrategy: KeywordRoutingStrategy()
        )

        let available = await supervisor.availableAgents
        #expect(available.count == 2)
        #expect(available.contains("calculator"))
        #expect(available.contains("weather"))
    }

    @Test("Returns available agents")
    func availableAgents() async {
        let agent1 = MockSupervisorTestAgent(name: "agent1")
        let agent2 = MockSupervisorTestAgent(name: "agent2")
        let agent3 = MockSupervisorTestAgent(name: "agent3")

        let supervisor = SupervisorAgent(
            agents: [
                (name: "agent1", agent: agent1, description: AgentDescription(name: "agent1", description: "First")),
                (name: "agent2", agent: agent2, description: AgentDescription(name: "agent2", description: "Second")),
                (name: "agent3", agent: agent3, description: AgentDescription(name: "agent3", description: "Third"))
            ],
            routingStrategy: KeywordRoutingStrategy()
        )

        let available = await supervisor.availableAgents
        #expect(available == ["agent1", "agent2", "agent3"])
    }

    @Test("Custom instructions are set correctly")
    func customInstructions() async {
        let agent = MockSupervisorTestAgent(name: "test")

        let supervisor = SupervisorAgent(
            agents: [
                (
                    name: "test",
                    agent: agent,
                    description: AgentDescription(name: "test", description: "Test")
                )
            ],
            routingStrategy: KeywordRoutingStrategy(),
            instructions: "Custom supervisor instructions"
        )

        #expect(supervisor.instructions == "Custom supervisor instructions")
    }

    @Test("Auto-generated instructions include agent list")
    func autoGeneratedInstructions() async {
        let agent1 = MockSupervisorTestAgent(name: "agent1")
        let agent2 = MockSupervisorTestAgent(name: "agent2")

        let supervisor = SupervisorAgent(
            agents: [
                (
                    name: "agent1",
                    agent: agent1,
                    description: AgentDescription(name: "agent1", description: "First agent")
                ),
                (
                    name: "agent2",
                    agent: agent2,
                    description: AgentDescription(name: "agent2", description: "Second agent")
                )
            ],
            routingStrategy: KeywordRoutingStrategy()
        )

        let instructions = supervisor.instructions
        #expect(instructions.contains("supervisor"))
        #expect(instructions.contains("agent1"))
        #expect(instructions.contains("agent2"))
        #expect(instructions.contains("First agent"))
        #expect(instructions.contains("Second agent"))
    }
}

// MARK: - SupervisorAgentDescriptionTests

@Suite("SupervisorAgent Description Tests")
struct SupervisorAgentDescriptionTests {
    @Test("Returns agent description by name")
    func descriptionForAgent() async {
        let agent = MockSupervisorTestAgent(name: "test")
        let desc = AgentDescription(
            name: "test",
            description: "Test agent",
            capabilities: ["cap1"]
        )

        let supervisor = SupervisorAgent(
            agents: [(name: "test", agent: agent, description: desc)],
            routingStrategy: KeywordRoutingStrategy()
        )

        let retrieved = await supervisor.description(for: "test")
        #expect(retrieved == desc)
    }

    @Test("Returns nil for unknown agent description")
    func descriptionForUnknownAgent() async {
        let agent = MockSupervisorTestAgent(name: "test")
        let supervisor = SupervisorAgent(
            agents: [(name: "test", agent: agent, description: AgentDescription(name: "test", description: "Test"))],
            routingStrategy: KeywordRoutingStrategy()
        )

        let retrieved = await supervisor.description(for: "unknown")
        #expect(retrieved == nil)
    }
}

// MARK: - SupervisorAgentRoutingTests

@Suite("SupervisorAgent Routing Tests")
struct SupervisorAgentRoutingTests {
    @Test("Routes to correct agent via keyword strategy")
    func routesToCorrectAgent() async throws {
        let calcAgent = MockSupervisorTestAgent(name: "calculator")
        let weatherAgent = MockSupervisorTestAgent(name: "weather")

        let supervisor = SupervisorAgent(
            agents: [
                (
                    name: "calculator",
                    agent: calcAgent,
                    description: AgentDescription(
                        name: "calculator",
                        description: "Math",
                        keywords: ["calculate", "math"]
                    )
                ),
                (
                    name: "weather",
                    agent: weatherAgent,
                    description: AgentDescription(
                        name: "weather",
                        description: "Weather",
                        keywords: ["weather", "forecast"]
                    )
                )
            ],
            routingStrategy: KeywordRoutingStrategy()
        )

        let result = try await supervisor.run("calculate 2+2")

        #expect(result.output.contains("calculator"))

        let calcCount = await calcAgent.getCallCount()
        let weatherCount = await weatherAgent.getCallCount()

        #expect(calcCount == 1)
        #expect(weatherCount == 0)
    }

    @Test("Returns result from delegated agent")
    func returnsAgentResult() async throws {
        let agent = MockSupervisorTestAgent(name: "test", responsePrefix: "Custom response")

        let supervisor = SupervisorAgent(
            agents: [
                (
                    name: "test",
                    agent: agent,
                    description: AgentDescription(name: "test", description: "Test")
                )
            ],
            routingStrategy: KeywordRoutingStrategy()
        )

        let result = try await supervisor.run("input")

        #expect(result.output == "Custom response test: input")
    }

    @Test("Includes routing metadata in result")
    func includesRoutingMetadata() async throws {
        let agent = MockSupervisorTestAgent(name: "test")

        let supervisor = SupervisorAgent(
            agents: [
                (
                    name: "test",
                    agent: agent,
                    description: AgentDescription(
                        name: "test",
                        description: "Test",
                        keywords: ["test"]
                    )
                )
            ],
            routingStrategy: KeywordRoutingStrategy()
        )

        let result = try await supervisor.run("test input")

        #expect(result.metadata["selected_agent"] == .string("test"))
        #expect(result.metadata["routing_confidence"] != nil)
    }

    @Test("Integration with KeywordRoutingStrategy")
    func keywordStrategyIntegration() async throws {
        let mathAgent = MockSupervisorTestAgent(name: "math")
        let codeAgent = MockSupervisorTestAgent(name: "code")

        let supervisor = SupervisorAgent(
            agents: [
                (
                    name: "math",
                    agent: mathAgent,
                    description: AgentDescription(
                        name: "math",
                        description: "Math operations",
                        keywords: ["calculate", "math", "sum", "multiply"]
                    )
                ),
                (
                    name: "code",
                    agent: codeAgent,
                    description: AgentDescription(
                        name: "code",
                        description: "Code generation",
                        keywords: ["code", "program", "function", "class"]
                    )
                )
            ],
            routingStrategy: KeywordRoutingStrategy()
        )

        let mathResult = try await supervisor.run("calculate the sum of 5 and 10")
        #expect(mathResult.output.contains("math"))

        let codeResult = try await supervisor.run("write a function to sort an array")
        #expect(codeResult.output.contains("code"))
    }

    @Test("Integration with LLMRoutingStrategy")
    func llmStrategyIntegration() async throws {
        let agent1 = MockSupervisorTestAgent(name: "agent1")
        let agent2 = MockSupervisorTestAgent(name: "agent2")

        let mock = MockInferenceProvider()
        await mock.setResponses(["agent1"])

        let supervisor = SupervisorAgent(
            agents: [
                (
                    name: "agent1",
                    agent: agent1,
                    description: AgentDescription(name: "agent1", description: "First")
                ),
                (
                    name: "agent2",
                    agent: agent2,
                    description: AgentDescription(name: "agent2", description: "Second")
                )
            ],
            routingStrategy: LLMRoutingStrategy(inferenceProvider: mock)
        )

        let result = try await supervisor.run("test input")

        #expect(result.output.contains("agent1"))

        let agent1Count = await agent1.getCallCount()
        #expect(agent1Count == 1)
    }
}

// MARK: - SupervisorAgentDirectExecutionTests

@Suite("SupervisorAgent Direct Execution Tests")
struct SupervisorAgentDirectExecutionTests {
    @Test("Executes specific agent by name")
    func executeAgentByName() async throws {
        let agent1 = MockSupervisorTestAgent(name: "agent1")
        let agent2 = MockSupervisorTestAgent(name: "agent2")

        let supervisor = SupervisorAgent(
            agents: [
                (name: "agent1", agent: agent1, description: AgentDescription(name: "agent1", description: "First")),
                (name: "agent2", agent: agent2, description: AgentDescription(name: "agent2", description: "Second"))
            ],
            routingStrategy: KeywordRoutingStrategy()
        )

        let result = try await supervisor.executeAgent(named: "agent2", input: "test")

        #expect(result.output.contains("agent2"))

        let agent1Count = await agent1.getCallCount()
        let agent2Count = await agent2.getCallCount()

        #expect(agent1Count == 0)
        #expect(agent2Count == 1)
    }

    @Test("Throws when executing unknown agent")
    func throwsForUnknownAgentExecution() async throws {
        let agent = MockSupervisorTestAgent(name: "test")

        let supervisor = SupervisorAgent(
            agents: [
                (name: "test", agent: agent, description: AgentDescription(name: "test", description: "Test"))
            ],
            routingStrategy: KeywordRoutingStrategy()
        )

        await #expect(throws: AgentError.self, performing: {
            _ = try await supervisor.executeAgent(named: "unknown", input: "test")
        })
    }
}

// MARK: - SupervisorAgentFallbackTests

@Suite("SupervisorAgent Fallback Tests")
struct SupervisorAgentFallbackTests {
    /// A routing strategy that always fails - for testing fallback behavior
    struct AlwaysFailingRoutingStrategy: RoutingStrategy, Sendable {
        func selectAgent(
            for _: String,
            from _: [AgentDescription],
            context _: AgentContext?
        ) async throws -> RoutingDecision {
            throw AgentError.internalError(reason: "Routing always fails")
        }
    }

    @Test("Uses fallback agent when routing fails")
    func usesFallbackAgent() async throws {
        let regularAgent = MockSupervisorTestAgent(name: "regular")
        let fallbackAgent = MockSupervisorTestAgent(name: "fallback")

        // Use a strategy that always throws to trigger fallback
        let supervisor = SupervisorAgent(
            agents: [
                (
                    name: "regular",
                    agent: regularAgent,
                    description: AgentDescription(name: "regular", description: "Regular")
                )
            ],
            routingStrategy: AlwaysFailingRoutingStrategy(),
            fallbackAgent: fallbackAgent
        )

        let result = try await supervisor.run("test")

        #expect(result.output.contains("fallback"))
        #expect(result.metadata["routing_decision"] == .string("fallback_after_error"))
    }

    @Test("Throws when routing fails and no fallback")
    func throwsWhenNoFallback() async throws {
        let agent = MockSupervisorTestAgent(name: "test")

        // Use a strategy that always throws
        let supervisor = SupervisorAgent(
            agents: [
                (
                    name: "test",
                    agent: agent,
                    description: AgentDescription(name: "test", description: "Test")
                )
            ],
            routingStrategy: AlwaysFailingRoutingStrategy(),
            fallbackAgent: nil
        )

        await #expect(throws: AgentError.self, performing: {
            _ = try await supervisor.run("input")
        })
    }

    @Test("Handles agent execution errors with fallback")
    func handlesAgentExecutionErrors() async throws {
        // Create an agent that throws an error
        actor ErrorAgent: AgentRuntime {
            nonisolated let tools: [any AnyJSONTool] = []
            nonisolated let instructions: String = "Error agent"
            nonisolated let configuration: AgentConfiguration = .default
            nonisolated var memory: (any Memory)? { nil }
            nonisolated var inferenceProvider: (any InferenceProvider)? { nil }

            func run(_: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) async throws -> AgentResult {
                throw AgentError.internalError(reason: "Test error")
            }

            nonisolated func stream(_: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
                AsyncThrowingStream { $0.finish(throwing: AgentError.internalError(reason: "Test error")) }
            }

            func cancel() async {}
        }

        let errorAgent = ErrorAgent()
        let fallbackAgent = MockSupervisorTestAgent(name: "fallback")

        let supervisor = SupervisorAgent(
            agents: [
                (
                    name: "error",
                    agent: errorAgent,
                    description: AgentDescription(name: "error", description: "Error")
                )
            ],
            routingStrategy: KeywordRoutingStrategy(),
            fallbackAgent: fallbackAgent
        )

        let result = try await supervisor.run("test")

        // Should use fallback after error
        #expect(result.output.contains("fallback"))
    }
}

// MARK: - SupervisorAgentStreamingTests

@Suite("SupervisorAgent Streaming Tests")
struct SupervisorAgentStreamingTests {
    @Test("Streams events from delegated agent")
    func streamsDelegatedAgentEvents() async throws {
        let agent = MockSupervisorTestAgent(name: "test")

        let supervisor = SupervisorAgent(
            agents: [
                (
                    name: "test",
                    agent: agent,
                    description: AgentDescription(
                        name: "test",
                        description: "Test",
                        keywords: ["test"]
                    )
                )
            ],
            routingStrategy: KeywordRoutingStrategy()
        )

        var events: [AgentEvent] = []
        for try await event in supervisor.stream("test input") {
            events.append(event)
        }

        #expect(!events.isEmpty)
        #expect(events.contains(where: {
            if case .started = $0 { true } else { false }
        }))
        #expect(events.contains(where: {
            if case .thinking = $0 { true } else { false }
        }))
        #expect(events.contains(where: {
            if case .completed = $0 { true } else { false }
        }))
    }
}

// MARK: - SupervisorAgentToolCallTests

@Suite("SupervisorAgent Tool Call Tests")
struct SupervisorAgentToolCallTests {
    @Test("Copies tool calls from sub-agent to result")
    func copiesToolCalls() async throws {
        // Create an agent that returns tool calls
        actor ToolAgent: AgentRuntime {
            nonisolated let tools: [any AnyJSONTool] = []
            nonisolated let instructions: String = "Tool agent"
            nonisolated let configuration: AgentConfiguration = .default
            nonisolated var memory: (any Memory)? { nil }
            nonisolated var inferenceProvider: (any InferenceProvider)? { nil }

            func run(_: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) async throws -> AgentResult {
                let builder = AgentResult.Builder()
                builder.start()
                builder.setOutput("Result with tools")

                let toolCall = ToolCall(
                    toolName: "test_tool",
                    arguments: ["arg": .string("value")]
                )
                builder.addToolCall(toolCall)
                builder.addToolResult(.success(
                    callId: toolCall.id,
                    output: "Tool result",
                    duration: .seconds(1)
                ))

                return builder.build()
            }

            nonisolated func stream(_: String, session _: (any Session)? = nil, hooks _: (any RunHooks)? = nil) -> AsyncThrowingStream<AgentEvent, Error> {
                AsyncThrowingStream { $0.finish() }
            }

            func cancel() async {}
        }

        let toolAgent = ToolAgent()

        let supervisor = SupervisorAgent(
            agents: [
                (
                    name: "tool_agent",
                    agent: toolAgent,
                    description: AgentDescription(name: "tool_agent", description: "Has tools")
                )
            ],
            routingStrategy: KeywordRoutingStrategy()
        )

        let result = try await supervisor.run("test")

        #expect(result.toolCalls.count == 1)
        #expect(result.toolResults.count == 1)
        #expect(result.toolCalls[0].toolName == "test_tool")
    }
}

// MARK: - SupervisorAgentCancellationTests

@Suite("SupervisorAgent Cancellation Tests")
struct SupervisorAgentCancellationTests {
    @Test("Cancel method completes without error")
    func cancelMethodCompletes() async {
        let agent = MockSupervisorTestAgent(name: "test")

        let supervisor = SupervisorAgent(
            agents: [
                (
                    name: "test",
                    agent: agent,
                    description: AgentDescription(name: "test", description: "Test")
                )
            ],
            routingStrategy: KeywordRoutingStrategy()
        )

        await supervisor.cancel()

        // Should complete without error
        #expect(Bool(true))
    }
}
