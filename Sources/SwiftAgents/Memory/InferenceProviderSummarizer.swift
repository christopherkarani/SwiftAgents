// InferenceProviderSummarizer.swift
// SwiftAgents Framework
//
// LLM-based summarizer using any InferenceProvider.

import Foundation

/// LLM-based summarizer using any `InferenceProvider`.
///
/// Works on all platforms - use for server deployments where
/// Apple's Foundation Models are not available.
///
/// ## Usage
///
/// ```swift
/// let provider = MyOpenAIProvider(apiKey: "...")
/// let summarizer = InferenceProviderSummarizer(provider: provider)
///
/// let memory = SummaryMemory(
///     shortTermCapacity: 10,
///     summarizer: summarizer
/// )
/// ```
///
/// ## Customization
///
/// The summarization prompt can be customized:
///
/// ```swift
/// let summarizer = InferenceProviderSummarizer(
///     provider: provider,
///     systemPrompt: "Create a brief summary focusing on action items:"
/// )
/// ```
public actor InferenceProviderSummarizer: Summarizer {
    private let provider: any InferenceProvider
    private let systemPrompt: String
    private let temperature: Double

    /// Creates a new inference provider-based summarizer.
    ///
    /// - Parameters:
    ///   - provider: The inference provider to use for summarization.
    ///   - systemPrompt: The prompt prefix for summarization requests.
    ///   - temperature: Temperature for generation (default: 0.3 for consistency).
    public init(
        provider: any InferenceProvider,
        systemPrompt: String = "Summarize the following conversation concisely, preserving key information and context:",
        temperature: Double = 0.3
    ) {
        self.provider = provider
        self.systemPrompt = systemPrompt
        self.temperature = temperature
    }

    // MARK: - Summarizer Protocol

    public func summarize(_ text: String, maxTokens: Int) async throws -> String {
        let prompt = """
        \(systemPrompt)

        \(text)

        Summary:
        """

        let options = InferenceOptions.default
            .temperature(temperature)
            .maxTokens(maxTokens)

        let response = try await provider.generate(prompt: prompt, options: options)
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isAvailable: Bool {
        get async { true }
    }
}

// MARK: - Convenience Extensions

extension InferenceProviderSummarizer {
    /// Creates a summarizer optimized for conversation summaries.
    ///
    /// - Parameter provider: The inference provider to use.
    /// - Returns: A summarizer configured for conversation summarization.
    public static func conversationSummarizer(
        provider: any InferenceProvider
    ) -> InferenceProviderSummarizer {
        InferenceProviderSummarizer(
            provider: provider,
            systemPrompt: """
            Summarize this conversation, capturing:
            - Main topics discussed
            - Key decisions or conclusions
            - Any action items or next steps
            - Important context for future reference

            Be concise but preserve essential information:
            """,
            temperature: 0.2
        )
    }

    /// Creates a summarizer optimized for agent reasoning traces.
    ///
    /// - Parameter provider: The inference provider to use.
    /// - Returns: A summarizer configured for reasoning trace summarization.
    public static func reasoningSummarizer(
        provider: any InferenceProvider
    ) -> InferenceProviderSummarizer {
        InferenceProviderSummarizer(
            provider: provider,
            systemPrompt: """
            Summarize this agent reasoning trace, capturing:
            - The original goal or question
            - Key observations and findings
            - Tools used and their results
            - Current state and next steps needed

            Format as a brief status report:
            """,
            temperature: 0.1
        )
    }
}
