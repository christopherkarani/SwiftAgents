// DeclarativeAgentDSLTests.swift
// SwiftAgentsTests
//
// Tests for the legacy SwiftUI-style loop DSL (`AgentLoopDefinition` + `AgentLoop`).

@testable import SwiftAgents
import Testing

// MARK: - Test Agents

private struct SampleSequentialAgent: AgentLoopDefinition {
    @AgentLoopBuilder var loop: some AgentLoop {
        Generate()
        Transform { input in "A\(input)" }
        Transform { input in "B\(input)" }
    }
}

private struct BillingAgent: AgentLoopDefinition {
    var instructions: String { "You are billing support. Be concise." }

    @AgentLoopBuilder var loop: some AgentLoop {
        Generate()
    }
}

private struct GeneralSupportAgent: AgentLoopDefinition {
    var instructions: String { "You are general customer support." }
    @AgentLoopBuilder var loop: some AgentLoop { Generate() }
}

private struct MathSpecialistAgent: AgentLoopDefinition {
    var instructions: String { "Solve billing math crisply." }
    @AgentLoopBuilder var loop: some AgentLoop { Generate() }
}

private struct WeatherSpecialistAgent: AgentLoopDefinition {
    var instructions: String { "Report weather succinctly." }
    @AgentLoopBuilder var loop: some AgentLoop { Generate() }
}

private struct GuardedAgent: AgentLoopDefinition {
    var instructions: String { "Only pass safe content through." }

    @AgentLoopBuilder var loop: some AgentLoop {
        Guard(.input) {
            InputGuard("no_shouting") { input in
                input.contains("SHOUT") ? .tripwire(message: "Calm please") : .passed()
            }
        }

        Generate()

        Guard(.output) {
            OutputGuard("no_pii") { output in
                output.contains("SSN") ? .tripwire(message: "PII detected") : .passed()
            }
        }
    }
}

private struct ResearchAgent: AgentLoopDefinition {
    let toolsList: [any AnyJSONTool]

    var instructions: String { "Research the topic with tools." }
    var tools: [any AnyJSONTool] { toolsList }
    @AgentLoopBuilder var loop: some AgentLoop { Generate() }
}

private struct ToolUsingAgent: AgentLoopDefinition {
    var tools: [any AnyJSONTool] { [MockTool(name: "dsl_tool")] }
    @AgentLoopBuilder var loop: some AgentLoop { Generate() }
}

private struct CustomerServiceAgent: AgentLoopDefinition {
    var instructions: String { "You are a helpful customer service agent." }

    @AgentLoopBuilder var loop: some AgentLoop {
        Guard(.input) {
            InputGuard("no_secrets") { input in
                input.contains("password") ? .tripwire(message: "Sensitive data") : .passed()
            }
        }

        Router {
            When(.contains("billing"), name: "billing") {
                BillingAgent()
                    .temperature(0.2)
            }
            Otherwise {
                GeneralSupportAgent()
            }
        }

        Guard(.output) {
            OutputGuard("no_pii") { output in
                output.contains("SSN") ? .tripwire(message: "PII detected") : .passed()
            }
        }
    }
}

// MARK: - Tests

@Suite("Declarative Agent DSL Tests")
struct DeclarativeAgentDSLTests {
    @Test("AgentLoop runs steps sequentially")
    func agentLoopIsSequential() async throws {
        let provider = MockInferenceProvider(responses: ["x"])

        let result = try await SampleSequentialAgent()
            .environment(\.inferenceProvider, provider)
            .run("ignored")

        #expect(result.output == "BAx")
    }

    @Test("Generate uses environment inference provider and configuration")
    func generateUsesEnvironmentAndConfig() async throws {
        let provider = MockInferenceProvider(responses: ["OK"])

        let result = try await BillingAgent()
            .temperature(0.2)
            .environment(\.inferenceProvider, provider)
            .run("Hi")

        #expect(result.output == "OK")

        let calls = await provider.generateCalls
        #expect(calls.count == 1)
        #expect(calls[0].options.temperature == 0.2)
    }

    @Test("Generate fails if no inference provider is set")
    func generateFailsWithoutProvider() async throws {
        do {
            _ = try await BillingAgent().run("Hi")
            Issue.record("Expected inference provider missing error")
        } catch let error as AgentError {
            switch error {
            case .inferenceProviderUnavailable(let reason):
                #expect(reason.contains("Generate()") || reason.contains("Relay()"))
            default:
                Issue.record("Unexpected AgentError: \(error)")
            }
        }
    }

    @Test("AgentLoop must contain at least one Generate or Relay call")
    func agentLoopRequiresGenerateOrRelay() async throws {
        struct NoGenerateAgent: AgentLoopDefinition {
            @AgentLoopBuilder var loop: some AgentLoop {
                Transform { _ in "ok" }
            }
        }

        do {
            _ = try await NoGenerateAgent().run("Hi")
            Issue.record("Expected invalid loop error")
        } catch let error as AgentError {
            switch error {
            case .invalidLoop(let reason):
                #expect(reason.contains("Generate()") || reason.contains("Relay()"))
            default:
                Issue.record("Unexpected AgentError: \(error)")
            }
        }
    }

    @Test("Relay executes a single model turn")
    func relayExecutesModelTurn() async throws {
        struct RelayAgent: AgentLoopDefinition {
            @AgentLoopBuilder var loop: some AgentLoop { Relay() }
        }

        let provider = MockInferenceProvider(responses: ["relay:ok"])
        let result = try await RelayAgent()
            .environment(\.inferenceProvider, provider)
            .run("Hi")

        #expect(result.output == "relay:ok")
        let calls = await provider.generateCalls
        #expect(calls.count == 1)
    }

    @Test("Relay injects memory prompt guidance when provided")
    func relayUsesMemoryPromptDescriptor() async throws {
        actor PromptMemory: Memory, MemoryPromptDescriptor {
            nonisolated let memoryPromptTitle: String = "Wax Memory Context (primary)"
            nonisolated let memoryPriority: MemoryPriorityHint = .primary
            nonisolated let memoryPromptGuidance: String? = "Use Wax memory first. Only call tools if memory is insufficient."

            private var messages: [MemoryMessage] = []

            func add(_ message: MemoryMessage) async { messages.append(message) }
            func context(for _: String, tokenLimit _: Int) async -> String { "wax:context" }
            func allMessages() async -> [MemoryMessage] { messages }
            func clear() async { messages.removeAll() }
            var count: Int { messages.count }
            var isEmpty: Bool { messages.isEmpty }
        }

        struct MemoryAgent: AgentLoopDefinition {
            @AgentLoopBuilder var loop: some AgentLoop { Relay() }
        }

        let provider = MockInferenceProvider(responses: ["ok"])
        let memory = PromptMemory()

        _ = try await MemoryAgent()
            .environment(\.inferenceProvider, provider)
            .environment(\.memory, memory)
            .run("Hi")

        let prompt = await provider.lastGenerateCall?.prompt ?? ""
        #expect(prompt.contains("Wax Memory Context (primary)"))
        #expect(prompt.contains("Use Wax memory first. Only call tools if memory is insufficient."))
        #expect(prompt.contains("wax:context"))
    }

    @Test("Router selects the first matching branch")
    func routesSelectFirstMatch() async throws {
        let provider = MockInferenceProvider(responses: ["billing:ok"])

        let result = try await CustomerServiceAgent()
            .environment(\.inferenceProvider, provider)
            .run("billing help")

        #expect(result.output == "billing:ok")
        #expect(result.metadata["router.matched_route"]?.stringValue == "billing")
    }

    @Test("Guard(.input) trips using InputGuard")
    func inputGuardTrips() async throws {
        do {
            _ = try await CustomerServiceAgent().run("please password this")
            Issue.record("Expected input guardrail to trip")
        } catch let error as GuardrailError {
            switch error {
            case .inputTripwireTriggered(let guardrailName, _, _):
                #expect(guardrailName == "no_secrets")
            default:
                Issue.record("Unexpected GuardrailError: \(error)")
            }
        }
    }

    @Test("Guard(.output) trips using OutputGuard")
    func outputGuardTrips() async throws {
        let provider = MockInferenceProvider(responses: ["Your SSN is 123-45-6789"])

        do {
            _ = try await CustomerServiceAgent()
                .environment(\.inferenceProvider, provider)
                .run("billing help")
            Issue.record("Expected output guardrail to trip")
        } catch let error as GuardrailError {
            switch error {
            case .outputTripwireTriggered(let guardrailName, _, _, _):
                #expect(guardrailName == "no_pii")
            default:
                Issue.record("Unexpected GuardrailError: \(error)")
            }
        }
    }

    @Test("Agent handoffs emit RunHooks.onHandoff")
    func handoffEmitsHook() async throws {
        actor Recorder: RunHooks {
            var events: [(from: String, to: String)] = []

            func onHandoff(context _: AgentContext?, fromAgent: any AgentRuntime, toAgent: any AgentRuntime) async {
                events.append((from: fromAgent.configuration.name, to: toAgent.configuration.name))
            }
        }

        let provider = MockInferenceProvider(responses: ["billing:ok"])
        let hooks = Recorder()

        _ = try await CustomerServiceAgent()
            .environment(\.inferenceProvider, provider)
            .run("billing help", hooks: hooks)

        let events = await hooks.events
        #expect(events.contains { $0.from == "CustomerServiceAgent" && $0.to == "BillingAgent" })
    }

    @Test("Generate passes agent tools to inference provider")
    func generatePassesTools() async throws {
        let provider = MockInferenceProvider()
        await provider.setToolCallResponses([
            InferenceResponse(content: "Tool result", finishReason: .completed)
        ])

        let result = try await ToolUsingAgent()
            .environment(\.inferenceProvider, provider)
            .run("call tool")

        #expect(result.output == "Tool result")

        let recordedToolCall = await provider.toolCallCalls.first
        #expect(recordedToolCall?.tools.contains(where: { $0.name == "dsl_tool" }) == true)
    }

    @Test("Streaming exposes start and completion events")
    func streamingExposesLifecycleEvents() async throws {
        let provider = MockInferenceProvider(responses: ["streaming answer"])
        var sawStart = false
        var sawCompleted = false

        let streamingAgent = CustomerServiceAgent()
            .environment(\.inferenceProvider, provider)

        for try await event in streamingAgent.stream("billing help") {
            switch event {
            case .started:
                sawStart = true
            case .completed:
                sawCompleted = true
            default:
                break
            }
        }

        #expect(sawStart)
        #expect(sawCompleted)
    }

    @Test("Supervisor routes via keyword strategy")
    func supervisorRoutesViaKeywords() async throws {
        let provider = MockInferenceProvider(responses: ["math output"])
        let mathDesc = AgentDescription(
            name: "math",
            description: "Handles billing calculations",
            keywords: ["math", "calculate"]
        )
        let weatherDesc = AgentDescription(
            name: "weather",
            description: "Handles weather inquiries",
            keywords: ["weather", "forecast"]
        )

        let supervisor = SupervisorAgent(
            agents: [
                (name: mathDesc.name, agent: MathSpecialistAgent().asRuntime(), description: mathDesc),
                (name: weatherDesc.name, agent: WeatherSpecialistAgent().asRuntime(), description: weatherDesc)
            ],
            routingStrategy: KeywordRoutingStrategy()
        )

        let result = try await supervisor
            .environment(\AgentEnvironment.inferenceProvider, provider)
            .run("math question")

        #expect(result.output == "math output")
    }

    @Test("InMemorySession keeps conversation history between runs")
    func sessionPersistsConversationHistory() async throws {
        let provider = MockInferenceProvider(responses: ["remembered", "recalled"])
        let session = InMemorySession(sessionId: "user_123")

        let agent = CustomerServiceAgent()
            .environment(\.inferenceProvider, provider)

        _ = try await agent.run("Remember: my favorite color is blue", session: session, hooks: nil)
        _ = try await agent.run("What's my favorite color?", session: session, hooks: nil)

        let count = try await session.getItemCount()
        #expect(count == 4)
    }

    @Test("GuardedAgent input guard trips and blocks")
    func guardedAgentInputGuardTrips() async throws {
        do {
            _ = try await GuardedAgent().run("Please SHOUT this message")
            Issue.record("Expected input guardrail to trip")
        } catch let error as GuardrailError {
            switch error {
            case .inputTripwireTriggered(let guardrailName, _, _):
                #expect(guardrailName == "no_shouting")
            default:
                Issue.record("Unexpected GuardrailError: \(error)")
            }
        }
    }

    @Test("GuardedAgent output guard trips on PII")
    func guardedAgentOutputGuardTrips() async throws {
        let provider = MockInferenceProvider(responses: ["Your SSN is 123-45-6789"])

        do {
            _ = try await GuardedAgent()
                .environment(\.inferenceProvider, provider)
                .run("safe prompt")
            Issue.record("Expected output guardrail to trip")
        } catch let error as GuardrailError {
            switch error {
            case .outputTripwireTriggered(let guardrailName, _, _, _):
                #expect(guardrailName == "no_pii")
            default:
                Issue.record("Unexpected GuardrailError: \(error)")
            }
        }
    }

    @Test("Research agent exposes provided tools")
    func researchAgentExposesTools() async throws {
        let provider = MockInferenceProvider()
        await provider.setToolCallResponses([
            InferenceResponse(content: "summary", finishReason: .completed)
        ])

        let mcpTools: [any AnyJSONTool] = [MockTool(name: "mcp_tool")]
        let researchAgent = ResearchAgent(toolsList: mcpTools)
            .environment(\.inferenceProvider, provider)

        let result = try await researchAgent.run("Summarize the latest updates.")
        #expect(result.output == "summary")

        let recordedCall = await provider.toolCallCalls.first
        #expect(recordedCall?.tools.contains(where: { $0.name == "mcp_tool" }) == true)
    }

    @Test("Resilient agent stack runs with DSL sample")
    func resilientAgentStackRuns() async throws {
        let provider = MockInferenceProvider(responses: ["resilient"])

        let resilientAgent = CustomerServiceAgent()
            .environment(\.inferenceProvider, provider)
            .retry(.exponentialBackoff(maxAttempts: 3, baseDelay: .seconds(1)))
            .withCircuitBreaker(threshold: 5, resetTimeout: .seconds(60))
            .withFallback(GeneralSupportAgent().asRuntime())
            .timeout(.seconds(30))

        let result = try await resilientAgent.run("Handle billing help urgently.")
        #expect(result.output == "resilient")
    }
}
