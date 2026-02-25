import Foundation
@testable import Swarm
import Testing

@Suite("SwarmRunner Tool Context Tests")
struct SwarmRunnerToolContextTests {
    @Test("Tool guardrails receive context during tool execution")
    func toolGuardrailsReceiveContext() async throws {
        let provider = ToolCallTestProvider()
        let tool = ContextCheckingTool(expectedKey: "guardrail_key", expectedValue: "present")
        let agent = SwarmRunnerToolContextAgent(
            name: "context-agent",
            provider: provider,
            tools: [tool]
        )

        let runner = try SwarmRunner(agents: [agent])
        let response = try await runner.run(
            agentName: "context-agent",
            messages: [.user("hello")],
            context: ["guardrail_key": .string("present")],
            executeTools: true
        )

        let toolMessages = response.messages.filter { $0.role == .tool }
        #expect(!toolMessages.isEmpty)
    }
}

private struct ContextCheckingTool: AnyJSONTool, Sendable {
    let expectedKey: String
    let expectedValue: String

    var name: String { "context_tool" }
    var description: String { "Tool that requires AgentContext via guardrails." }
    var parameters: [ToolParameter] { [] }
    var inputGuardrails: [any ToolInputGuardrail] {
        [ContextRequiredGuardrail(expectedKey: expectedKey, expectedValue: expectedValue)]
    }

    func execute(arguments _: [String: SendableValue]) async throws -> SendableValue {
        .string("ok")
    }
}

private struct ContextRequiredGuardrail: ToolInputGuardrail, Sendable {
    let name: String = "context_required_guardrail"
    let expectedKey: String
    let expectedValue: String

    func validate(_ data: ToolGuardrailData) async throws -> GuardrailResult {
        guard let context = data.context else {
            return .tripwire(message: "Missing context")
        }
        let value = await context.get(expectedKey)?.stringValue
        guard value == expectedValue else {
            return .tripwire(message: "Missing expected context value")
        }
        return .passed()
    }
}

private actor ToolCallTestProvider: InferenceProvider {
    private var callCount: Int = 0

    func generate(prompt _: String, options _: InferenceOptions) async throws -> String {
        "unused"
    }

    nonisolated func stream(prompt _: String, options _: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func generateWithToolCalls(
        prompt _: String,
        tools _: [ToolSchema],
        options _: InferenceOptions
    ) async throws -> InferenceResponse {
        callCount += 1
        if callCount == 1 {
            return InferenceResponse(
                content: nil,
                toolCalls: [InferenceResponse.ParsedToolCall(name: "context_tool", arguments: [:])],
                finishReason: .toolCall,
                usage: nil
            )
        }

        return InferenceResponse(
            content: "done",
            toolCalls: [],
            finishReason: .completed,
            usage: nil
        )
    }
}

private struct SwarmRunnerToolContextAgent: AgentRuntime {
    let name: String
    let provider: any InferenceProvider
    let tools: [any AnyJSONTool]
    let instructions: String = "Tool context agent"
    let configuration: AgentConfiguration

    init(name: String, provider: any InferenceProvider, tools: [any AnyJSONTool]) {
        self.name = name
        self.provider = provider
        self.tools = tools
        var config = AgentConfiguration.default
        config.name = name
        configuration = config
    }

    nonisolated var inferenceProvider: (any InferenceProvider)? { provider }

    func run(_: String, session _: (any Session)?, hooks _: (any RunHooks)?) async throws -> AgentResult {
        AgentResult(output: "unused")
    }

    nonisolated func stream(
        _: String,
        session _: (any Session)?,
        hooks _: (any RunHooks)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func cancel() async {}
}
