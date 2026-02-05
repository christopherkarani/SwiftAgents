import Conduit
import Testing
@testable import Swarm

@Suite("Conduit Streaming Tool Call Bridge")
struct ConduitToolCallStreamingBridgeTests {
    @Test("Streams partial tool call fragments and completed calls through Swarm updates")
    func streamsToolCallAssembly() async throws {
        struct MockModelID: Conduit.ModelIdentifying {
            let rawValue: String
            var displayName: String { rawValue }
            var provider: Conduit.ProviderType { .openAI }
            var description: String { rawValue }
            init(_ rawValue: String) { self.rawValue = rawValue }
        }

        struct MockTextGenerator: Conduit.TextGenerator {
            typealias ModelID = MockModelID

            let chunks: [Conduit.GenerationChunk]

            func generate(_ prompt: String, model _: ModelID, config _: Conduit.GenerateConfig) async throws -> String {
                ""
            }

            func generate(messages _: [Conduit.Message], model _: ModelID, config _: Conduit.GenerateConfig) async throws -> Conduit.GenerationResult {
                Conduit.GenerationResult(
                    text: "",
                    tokenCount: 0,
                    generationTime: 0,
                    tokensPerSecond: 0,
                    finishReason: .stop
                )
            }

            func stream(_ prompt: String, model _: ModelID, config _: Conduit.GenerateConfig) -> AsyncThrowingStream<String, Error> {
                StreamHelper.makeTrackedStream { continuation in
                    continuation.finish()
                }
            }

            func streamWithMetadata(
                messages _: [Conduit.Message],
                model _: ModelID,
                config _: Conduit.GenerateConfig
            ) -> AsyncThrowingStream<Conduit.GenerationChunk, Error> {
                StreamHelper.makeTrackedStream { continuation in
                    for chunk in chunks {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                }
            }
        }

        let partial = Conduit.PartialToolCall(
            id: "call_1",
            toolName: "echo",
            index: 0,
            argumentsFragment: #"{"text":"#
        )
        let callArgs = try Conduit.GeneratedContent(json: #"{"text":"hi"}"#)
        let completedCall = Conduit.Transcript.ToolCall(id: "call_1", toolName: "echo", arguments: callArgs)

        let chunks: [Conduit.GenerationChunk] = [
            Conduit.GenerationChunk(text: "", partialToolCall: partial),
            Conduit.GenerationChunk(
                text: "",
                usage: Conduit.UsageStats(promptTokens: 3, completionTokens: 2),
                completedToolCalls: [completedCall]
            ),
        ]

        let provider = MockTextGenerator(chunks: chunks)
        let bridge = ConduitInferenceProvider(provider: provider, model: MockModelID("mock"))

        let schema = ToolSchema(
            name: "echo",
            description: "Echo tool",
            parameters: [ToolParameter(name: "text", description: "Text", type: .string)]
        )

        var updates: [InferenceStreamUpdate] = []
        for try await update in bridge.streamWithToolCalls(
            prompt: "hi",
            tools: [schema],
            options: .default
        ) {
            updates.append(update)
        }

        #expect(updates.contains { u in
            if case let .toolCallPartial(update) = u {
                return update.providerCallId == "call_1"
                    && update.toolName == "echo"
                    && update.index == 0
                    && update.argumentsFragment.contains(#"{"text":"#)
            }
            return false
        })

        #expect(updates.contains { u in
            if case let .usage(usage) = u {
                return usage.inputTokens == 3 && usage.outputTokens == 2
            }
            return false
        })

        #expect(updates.contains { u in
            if case let .toolCallsCompleted(calls) = u {
                return calls.count == 1
                    && calls[0].id == "call_1"
                    && calls[0].name == "echo"
                    && calls[0].arguments["text"]?.stringValue == "hi"
            }
            return false
        })
    }
}
