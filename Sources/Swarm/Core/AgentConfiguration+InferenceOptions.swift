// AgentConfiguration+InferenceOptions.swift
// Swarm Framework
//
// Bridges AgentConfiguration + ModelSettings to InferenceOptions.

import Foundation

public extension AgentConfiguration {
    /// Resolves the context profile used at runtime after applying context mode.
    var effectiveContextProfile: ContextProfile {
        switch contextMode {
        case .adaptive:
            contextProfile
        case .strict4k:
            .strict4k
        }
    }

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
                toolChoice: settings.toolChoice,
                seed: settings.seed,
                parallelToolCalls: settings.parallelToolCalls ?? parallelToolCalls,
                truncation: settings.truncation,
                verbosity: settings.verbosity,
                providerSettings: settings.providerSettings
            )
        }

        return InferenceOptions(
            temperature: temperature,
            maxTokens: maxTokens,
            stopSequences: stopSequences,
            parallelToolCalls: parallelToolCalls
        )
    }
}
