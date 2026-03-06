// SwarmConfiguration.swift
// Swarm Framework
//
// Global configuration entry point for the Swarm framework.

import Foundation

/// Global configuration for the Swarm framework.
///
/// Call `Swarm.configure(provider:)` once at app launch to set the default
/// inference provider for all agents:
///
/// ```swift
/// await Swarm.configure(provider: AnthropicProvider(apiKey: key))
/// ```
///
/// For hybrid setups where Foundation Models handle chat but a cloud provider
/// handles tool calling:
///
/// ```swift
/// await Swarm.configure(cloudProvider: AnthropicProvider(apiKey: key))
/// ```
public extension Swarm {
    // MARK: - Internal Storage

    actor Configuration {
        static let shared = Configuration()

        private(set) var provider: (any InferenceProvider)?
        private(set) var cloud: (any InferenceProvider)?

        func setProvider(_ provider: some InferenceProvider) {
            self.provider = provider
        }

        func setCloudProvider(_ cloudProvider: some InferenceProvider) {
            cloud = cloudProvider
        }

        func reset() {
            provider = nil
            cloud = nil
        }
    }

    /// The currently configured default provider, if any.
    static var defaultProvider: (any InferenceProvider)? {
        get async { await Configuration.shared.provider }
    }

    /// The currently configured cloud provider for tool calling, if any.
    static var cloudProvider: (any InferenceProvider)? {
        get async { await Configuration.shared.cloud }
    }

    // MARK: - Public API

    /// Sets the default inference provider for all agents.
    ///
    /// Agents resolve providers in this order:
    /// 1. Explicit provider on the agent
    /// 2. TaskLocal via `.environment(\.inferenceProvider, ...)`
    /// 3. `Swarm.defaultProvider` (set here)
    /// 4. `Swarm.cloudProvider` (if tool calling is required)
    /// 5. Foundation Models (if no tools, on Apple platform)
    /// 6. Throw `AgentError.inferenceProviderUnavailable`
    static func configure(provider: some InferenceProvider) async {
        await Configuration.shared.setProvider(provider)
    }

    /// Sets a cloud provider for tool-calling agents.
    ///
    /// Foundation Models do not support tool calling. Use this to configure
    /// a cloud provider (Anthropic, OpenAI, Ollama) specifically for agents
    /// that use tools, while letting Foundation Models handle plain chat.
    static func configure(cloudProvider: some InferenceProvider) async {
        await Configuration.shared.setCloudProvider(cloudProvider)
    }

    /// Resets all configuration. Intended for testing only.
    static func reset() async {
        await Configuration.shared.reset()
    }
}
