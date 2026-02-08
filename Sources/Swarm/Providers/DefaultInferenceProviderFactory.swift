// DefaultInferenceProviderFactory.swift
// Swarm Framework
//
// Opinionated default inference provider selection.
//
// Agent (the default tool-calling runtime) uses this factory to attempt
// Apple Foundation Models when no explicit inference provider is configured.

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum DefaultInferenceProviderFactory {
    static func makeFoundationModelsProviderIfAvailable() -> (any InferenceProvider)? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.availability == .available else {
                return nil
            }
            return FoundationModelsInferenceProvider()
        }
        #endif

        return nil
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
private struct FoundationModelsInferenceProvider: InferenceProvider {
    func generate(prompt: String, options: InferenceOptions) async throws -> String {
        let session = LanguageModelSession()
        return try await session.generate(prompt: prompt, options: options)
    }

    func stream(prompt: String, options: InferenceOptions) -> AsyncThrowingStream<String, Error> {
        let session = LanguageModelSession()
        return session.stream(prompt: prompt, options: options)
    }

    func generateWithToolCalls(
        prompt: String,
        tools: [ToolSchema],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        let session = LanguageModelSession()
        return try await session.generateWithToolCalls(prompt: prompt, tools: tools, options: options)
    }
}
#endif

