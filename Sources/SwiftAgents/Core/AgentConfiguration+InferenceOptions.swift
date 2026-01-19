// AgentConfiguration+InferenceOptions.swift
// SwiftAgents Framework
//
// Bridges AgentConfiguration + ModelSettings to InferenceOptions.

import Foundation

public extension AgentConfiguration {
    /// Resolves this agent configuration into provider-facing inference options.
    ///
    /// If `modelSettings` is set, its values take precedence where applicable.
    var inferenceOptions: InferenceOptions {
        if let settings = modelSettings {
            return InferenceOptions(
                temperature: settings.temperature ?? temperature,
                maxTokens: settings.maxTokens ?? maxTokens,
                stopSequences: settings.stopSequences ?? stopSequences,
                topP: settings.topP,
                topK: settings.topK,
                presencePenalty: settings.presencePenalty,
                frequencyPenalty: settings.frequencyPenalty,
                toolChoice: settings.toolChoice
            )
        }

        return InferenceOptions(
            temperature: temperature,
            maxTokens: maxTokens,
            stopSequences: stopSequences
        )
    }
}

