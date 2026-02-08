// OpenRouterRouting.swift
// Swarm Framework
//
// Lightweight OpenRouter routing configuration without exposing Conduit types.

import Conduit
import Foundation

/// OpenRouter routing preferences.
public struct OpenRouterRouting: Sendable, Hashable {
    public enum Provider: String, Sendable, Hashable, CaseIterable {
        case openai
        case anthropic
        case google
        case googleAIStudio
        case together
        case fireworks
        case perplexity
        case mistral
        case groq
        case deepseek
        case cohere
        case ai21
        case bedrock
        case azure
    }

    public enum DataCollection: String, Sendable, Hashable, CaseIterable {
        case allow
        case deny
    }

    public var providers: [Provider]?
    public var fallbacks: Bool
    public var routeByLatency: Bool
    public var siteURL: URL?
    public var appName: String?
    public var dataCollection: DataCollection?

    public init(
        providers: [Provider]? = nil,
        fallbacks: Bool = true,
        routeByLatency: Bool = false,
        siteURL: URL? = nil,
        appName: String? = nil,
        dataCollection: DataCollection? = nil
    ) {
        self.providers = providers
        self.fallbacks = fallbacks
        self.routeByLatency = routeByLatency
        self.siteURL = siteURL
        self.appName = appName
        self.dataCollection = dataCollection
    }

    func toConduit() -> OpenRouterRoutingConfig {
        let mappedProviders = providers?.map { $0.toConduit() }
        return OpenRouterRoutingConfig(
            providers: mappedProviders,
            fallbacks: fallbacks,
            routeByLatency: routeByLatency,
            siteURL: siteURL,
            appName: appName,
            dataCollection: dataCollection?.toConduit()
        )
    }
}

private extension OpenRouterRouting.Provider {
    func toConduit() -> Conduit.OpenRouterProvider {
        switch self {
        case .openai:
            return .openai
        case .anthropic:
            return .anthropic
        case .google:
            return .google
        case .googleAIStudio:
            return .googleAIStudio
        case .together:
            return .together
        case .fireworks:
            return .fireworks
        case .perplexity:
            return .perplexity
        case .mistral:
            return .mistral
        case .groq:
            return .groq
        case .deepseek:
            return .deepseek
        case .cohere:
            return .cohere
        case .ai21:
            return .ai21
        case .bedrock:
            return .bedrock
        case .azure:
            return .azure
        }
    }
}

private extension OpenRouterRouting.DataCollection {
    func toConduit() -> Conduit.OpenRouterDataCollection {
        switch self {
        case .allow:
            return .allow
        case .deny:
            return .deny
        }
    }
}
