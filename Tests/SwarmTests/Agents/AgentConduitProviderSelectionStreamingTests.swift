import Testing
@testable import Swarm

@Suite("Agent ConduitProviderSelection Streaming")
struct AgentConduitProviderSelectionStreamingTests {
    @Test("Uses tool-call streaming when provider is wrapped in ConduitProviderSelection")
    func usesToolStreamingThroughProviderSelectionWrapper() async throws {
        struct EchoTool: AnyJSONTool, Sendable {
            let name = "echo"
            let description = "Echoes the input text"
            let parameters: [ToolParameter] = [
                ToolParameter(name: "text", description: "Text to echo", type: .string),
            ]

            func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
                .string(try requiredString("text", from: arguments))
            }
        }

        // NOTE: Keep this as a class, not an actor. `ToolCallStreamingInferenceProvider.streamWithToolCalls`
        // is synchronous and calling it through an existential can bypass actor isolation hops, triggering
        // "Incorrect actor executor assumption" crashes at runtime.
        final class ScriptedStreamingProvider: @preconcurrency ToolCallStreamingInferenceProvider, @unchecked Sendable {
            func generate(prompt _: String, options _: InferenceOptions) async throws -> String {
                throw AgentError.generationFailed(reason: "Unexpected call to generate() in provider-selection streaming test")
            }

            func stream(prompt _: String, options _: InferenceOptions) -> AsyncThrowingStream<String, Error> {
                StreamHelper.makeTrackedStream { continuation in
                    continuation.finish(throwing: AgentError.generationFailed(reason: "Unexpected call to stream() in provider-selection streaming test"))
                }
            }

            func generateWithToolCalls(
                prompt _: String,
                tools _: [ToolSchema],
                options _: InferenceOptions
            ) async throws -> InferenceResponse {
                // If this is called, Agent did not take the streaming tool-call path.
                throw AgentError.generationFailed(reason: "Unexpected call to generateWithToolCalls() in provider-selection streaming test")
            }

            func streamWithToolCalls(
                prompt _: String,
                tools _: [ToolSchema],
                options _: InferenceOptions
            ) -> AsyncThrowingStream<InferenceStreamUpdate, Error> {
                let partial = PartialToolCallUpdate(
                    providerCallId: "call_1",
                    toolName: "echo",
                    index: 0,
                    argumentsFragment: #"{"text":"hi"}"#
                )
                let completed = [
                    InferenceResponse.ParsedToolCall(
                        id: "call_1",
                        name: "echo",
                        arguments: ["text": .string("hi")]
                    ),
                ]

                return StreamHelper.makeTrackedStream { continuation in
                    continuation.yield(.toolCallPartial(partial))
                    continuation.yield(.toolCallsCompleted(completed))
                    continuation.finish()
                }
            }
        }

        let provider = ScriptedStreamingProvider()
        let wrapped: ConduitProviderSelection = .provider(provider)

        let agent = Agent(
            tools: [EchoTool()],
            configuration: .default.maxIterations(3),
            inferenceProvider: wrapped
        )

        var sawPartial = false
        for try await event in agent.stream("Hi") {
            if case .toolCallPartial = event {
                sawPartial = true
                break
            }
        }

        #expect(sawPartial == true)
    }
}
