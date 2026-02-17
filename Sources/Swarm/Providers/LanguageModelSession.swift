//
//  LanguageModelSession.swift
//  Swarm
//
//  Created by Chris Karani on 16/01/2026.
//

// Gate FoundationModels import for cross-platform builds (Linux, Windows, etc.)
#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, iOS 26.0, *)
extension LanguageModelSession: InferenceProvider {
    public func generate(prompt: String, options: InferenceOptions) async throws -> String {
        // Create a request with the prompt
        let response = try await self.respond(to: prompt)
        var content = response.content

        // Handle manual stop sequences since Foundation Models might not support them natively via this API
        for stopSequence in options.stopSequences {
            if let range = content.range(of: stopSequence) {
                content = String(content[..<range.lowerBound])
            }
        }

        return content
    }

    public func stream(prompt: String, options _: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // For streaming, we'll generate the full response and yield it
                    for try await stream in self.streamResponse(to: prompt) {
                        continuation.yield(stream.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        // FoundationModels currently does not expose stable tool-calling in this bridge.
        // Throw explicitly when tools are requested to avoid silent capability degradation.
        if !tools.isEmpty {
            throw AgentError.generationFailed(
                reason: "FoundationModels LanguageModelSession tool calling is not supported yet."
            )
        }

        let response = try await generate(prompt: prompt, options: options)

        return InferenceResponse(
            content: response,
            toolCalls: [],
            finishReason: .completed
        )
    }
}
#endif
