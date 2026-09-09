// AgentHostToolBatchTests.swift
// SwarmTests
//
// Host-round batching for consecutive regular tools on ToolExecutionEngine.

import Foundation
@testable import Swarm
import Testing

@Suite("Agent host tool batch")
struct AgentHostToolBatchTests {
    private static let configuration = AgentConfiguration.default
        .enableStreaming(false)
        .timeout(.seconds(30))
        .defaultTracingEnabled(false)

    @Test("Two parallel-eligible regular tools both run; transcript order matches input")
    func twoRegularToolsBatchInInputOrder() async throws {
        let handshake = ToolHandshake()
        let search = HandshakeTool(name: "search", handshake: handshake)
        let calc = HandshakeTool(name: "calc", handshake: handshake)
        let provider = MockInferenceProvider()
        await provider.setToolCallResponses([
            InferenceResponse(
                content: nil,
                toolCalls: [
                    InferenceResponse.ParsedToolCall(id: "call_search", name: "search", arguments: [:]),
                    InferenceResponse.ParsedToolCall(id: "call_calc", name: "calc", arguments: [:]),
                ],
                finishReason: .toolCall,
                usage: nil
            ),
            InferenceResponse(content: "done", toolCalls: [], finishReason: .completed, usage: nil),
        ])
        let agent = try Agent(
            tools: [search, calc],
            configuration: Self.configuration,
            inferenceProvider: provider
        )

        let result = try await agent.run("search then calc")

        #expect(result.output == "done")
        #expect(result.toolCalls.map(\.toolName) == ["search", "calc"])
        #expect(result.toolCalls.map(\.providerCallId) == ["call_search", "call_calc"])
        #expect(result.toolResults.map(\.isSuccess) == [true, true])
        #expect(result.toolResults.map(\.output) == [.string("search"), .string("calc")])
        #expect(await handshake.arrivals == 2)
    }

    @Test("Successful handoff skips later regular tools")
    func successfulHandoffSkipsLaterRegularTools() async throws {
        let search = SpyTool(name: "search", result: .string("hits"))
        let calc = SpyTool(name: "calc", result: .string("should-not-run"))
        let provider = MockInferenceProvider()
        await provider.setToolCallResponses([
            InferenceResponse(
                content: nil,
                toolCalls: [
                    InferenceResponse.ParsedToolCall(id: "call_search", name: "search", arguments: [:]),
                    InferenceResponse.ParsedToolCall(
                        id: "call_handoff",
                        name: "handoff_to_writer",
                        arguments: ["reason": .string("write it")]
                    ),
                    InferenceResponse.ParsedToolCall(id: "call_calc", name: "calc", arguments: [:]),
                ],
                finishReason: .toolCall,
                usage: nil
            ),
        ])
        let target = HostBatchHandoffReceiver(name: "writer")
        let agent = try Agent(
            tools: [search, calc],
            instructions: "Route to writer.",
            configuration: AgentConfiguration(name: "source", defaultTracingEnabled: false)
                .enableStreaming(false)
                .timeout(.seconds(30)),
            inferenceProvider: provider,
            handoffs: [
                AnyHandoffConfiguration(
                    HandoffConfiguration(targetAgent: target, toolNameOverride: "handoff_to_writer")
                ),
            ]
        )

        let result = try await agent.run("search then hand off")

        #expect(result.output == "handled search then hand off")
        #expect(await search.callCount == 1)
        #expect(await calc.callCount == 0)
        #expect(await target.handoffCount == 1)
        #expect(result.toolCalls.map(\.toolName) == ["search", "handoff_to_writer"])
    }

    @Test("Membrane internal tools do not go through Engine batch")
    func membraneInternalToolsBypassEngineBatch() async throws {
        let weather = SpyTool(name: "weather", result: .string("72F"))
        let adapter = RecordingMembraneAdapter()
        let provider = MockInferenceProvider()
        await provider.setToolCallResponses([
            InferenceResponse(
                content: nil,
                toolCalls: [
                    InferenceResponse.ParsedToolCall(
                        id: "call_ptr",
                        name: MembraneInternalToolName.resolvePointer,
                        arguments: ["pointer_id": .string("ptr_test")]
                    ),
                    InferenceResponse.ParsedToolCall(id: "call_weather", name: "weather", arguments: [:]),
                ],
                finishReason: .toolCall,
                usage: nil
            ),
            InferenceResponse(content: "It is 72F", toolCalls: [], finishReason: .completed, usage: nil),
        ])
        let agent = try Agent(
            tools: [weather],
            configuration: Self.configuration,
            inferenceProvider: provider
        ).environment(
            \.membrane,
            MembraneEnvironment(isEnabled: true, adapter: adapter)
        )

        let result = try await agent.run("resolve then weather")

        #expect(result.output == "It is 72F")
        #expect(await adapter.internalCalls == [MembraneInternalToolName.resolvePointer])
        #expect(await weather.callCount == 1)
        #expect(result.toolCalls.map(\.toolName) == [MembraneInternalToolName.resolvePointer, "weather"])
        #expect(result.toolResults.first?.output == .string("internal-ok"))
        #expect(result.toolResults.last?.output == .string("72F"))
    }
}

private actor ToolHandshake {
    private(set) var arrivals = 0
    private var waiter: CheckedContinuation<Void, Never>?

    func arrive() async {
        arrivals += 1
        if arrivals >= 2 {
            waiter?.resume()
            waiter = nil
        } else {
            await withCheckedContinuation { continuation in
                waiter = continuation
            }
        }
    }
}

private struct HandshakeTool: AnyJSONTool {
    let name: String
    let handshake: ToolHandshake

    var description: String { "Handshake tool \(name)" }
    var parameters: [ToolParameter] { [] }
    var inputGuardrails: [any ToolInputGuardrail] { [] }
    var outputGuardrails: [any ToolOutputGuardrail] { [] }

    func execute(arguments _: [String: SendableValue]) async throws -> SendableValue {
        await handshake.arrive()
        return .string(name)
    }
}

private actor HostBatchHandoffReceiver: HandoffReceiver {
    nonisolated let tools: [any AnyJSONTool] = []
    nonisolated let instructions = "Record handoffs"
    nonisolated let configuration: AgentConfiguration
    nonisolated let memory: (any Memory)? = nil
    nonisolated let inferenceProvider: (any InferenceProvider)? = nil
    nonisolated let tracer: (any Tracer)? = nil
    nonisolated let inputGuardrails: [any InputGuardrail] = []
    nonisolated let outputGuardrails: [any OutputGuardrail] = []
    nonisolated let handoffs: [AnyHandoffConfiguration] = []

    private(set) var handoffCount = 0

    init(name: String) {
        configuration = AgentConfiguration(name: name, defaultTracingEnabled: false)
    }

    func run(_ input: String, session _: (any Session)?, observer _: (any AgentObserver)?) async throws -> AgentResult {
        AgentResult(output: "handled \(input)")
    }

    nonisolated func stream(
        _ input: String,
        session _: (any Session)?,
        observer _: (any AgentObserver)?
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        StreamHelper.makeTrackedStream { continuation in
            continuation.yield(.lifecycle(.completed(result: AgentResult(output: "handled \(input)"))))
            continuation.finish()
        }
    }

    func cancel() async {}

    func handleHandoff(_ request: HandoffRequest, context _: AgentContext) async throws -> AgentResult {
        handoffCount += 1
        return AgentResult(output: "handled \(request.input)")
    }
}

private actor RecordingMembraneAdapter: MembraneAgentAdapter {
    private(set) var internalCalls: [String] = []

    func plan(
        prompt: String,
        toolSchemas: [ToolSchema],
        profile _: ContextProfile
    ) async throws -> MembranePlannedBoundary {
        MembranePlannedBoundary(prompt: prompt, toolSchemas: toolSchemas, mode: "test")
    }

    func transformToolResult(
        toolName _: String,
        output: String,
        profile _: ContextProfile
    ) async throws -> MembraneToolResultBoundary {
        MembraneToolResultBoundary(textForConversation: output)
    }

    func handleInternalToolCall(
        name: String,
        arguments _: [String: SendableValue]
    ) async throws -> String? {
        internalCalls.append(name)
        return "internal-ok"
    }

    func restore(checkpointData _: Data?) async throws {}
    func snapshotCheckpointData() async throws -> Data? { nil }
}
