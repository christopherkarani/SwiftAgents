import Foundation
import Wax
import WaxVectorSearch

/// Wax-backed memory implementation using the unified RAG orchestrator.
public actor WaxMemory: Memory, MemoryPromptDescriptor, MemorySessionLifecycle {
    // MARK: Public

    /// Configuration for Wax memory behavior.
    public struct Configuration: Sendable {
        public static let `default` = Configuration()

        public var orchestratorConfig: OrchestratorConfig
        public var queryEmbeddingPolicy: MemoryOrchestrator.QueryEmbeddingPolicy
        public var tokenEstimator: any TokenEstimator
        public var promptTitle: String
        public var promptGuidance: String?

        public init(
            orchestratorConfig: OrchestratorConfig = .default,
            queryEmbeddingPolicy: MemoryOrchestrator.QueryEmbeddingPolicy = .ifAvailable,
            tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared,
            promptTitle: String = "Wax Memory Context (primary)",
            promptGuidance: String? = "Use Wax memory context as the primary source of truth. Prefer it before calling tools."
        ) {
            self.orchestratorConfig = orchestratorConfig
            self.queryEmbeddingPolicy = queryEmbeddingPolicy
            self.tokenEstimator = tokenEstimator
            self.promptTitle = promptTitle
            self.promptGuidance = promptGuidance
        }
    }

    public var count: Int { messages.count }
    public var isEmpty: Bool { messages.isEmpty }

    public nonisolated let memoryPromptTitle: String
    public nonisolated let memoryPromptGuidance: String?
    public nonisolated let memoryPriority: MemoryPriorityHint = .primary

    /// Creates a Wax-backed memory store.
    /// - Parameters:
    ///   - url: Location of the Wax database.
    ///   - embedder: Optional Wax embedding provider for vector search.
    ///   - configuration: Wax memory configuration.
    public init(
        url: URL,
        embedder: (any WaxVectorSearch.EmbeddingProvider)? = nil,
        configuration: Configuration = .default
    ) async throws {
        // Progressive disclosure defaults:
        // - If no embedder is provided, disable vector search so Wax can still be used
        //   as a single-file text-search memory without additional setup.
        var effectiveConfiguration = configuration
        if embedder == nil {
            effectiveConfiguration.orchestratorConfig.enableVectorSearch = false
        }

        self.orchestrator = try await MemoryOrchestrator(
            at: url,
            config: effectiveConfiguration.orchestratorConfig,
            embedder: embedder
        )
        self.configuration = effectiveConfiguration
        self.memoryPromptTitle = effectiveConfiguration.promptTitle
        self.memoryPromptGuidance = effectiveConfiguration.promptGuidance
    }

    public func add(_ message: MemoryMessage) async {
        messages.append(message)

        var metadata = message.metadata
        metadata["role"] = message.role.rawValue
        metadata["timestamp"] = isoFormatter.string(from: message.timestamp)
        metadata["message_id"] = message.id.uuidString

        do {
            try await orchestrator.remember(message.content, metadata: metadata)
        } catch {
            Log.memory.error("WaxMemory: Failed to ingest message: \(error.localizedDescription)")
        }
    }

    public func context(for query: String, tokenLimit: Int) async -> String {
        do {
            let rag = try await orchestrator.recall(query: query, embeddingPolicy: configuration.queryEmbeddingPolicy)
            return formatRAGContext(rag, tokenLimit: tokenLimit)
        } catch {
            Log.memory.error("WaxMemory: Failed to recall context: \(error.localizedDescription)")
            return ""
        }
    }

    public func allMessages() async -> [MemoryMessage] {
        messages
    }

    public func clear() async {
        messages.removeAll()
    }

    // MARK: - MemorySessionLifecycle

    public func beginMemorySession() async {
        _ = await orchestrator.startSession()
    }

    public func endMemorySession() async {
        await orchestrator.endSession()
    }

    // MARK: Private

    private let orchestrator: MemoryOrchestrator
    private let configuration: Configuration
    private var messages: [MemoryMessage] = []
    private let isoFormatter = ISO8601DateFormatter()

    private func formatRAGContext(_ rag: RAGContext, tokenLimit: Int) -> String {
        guard tokenLimit > 0 else { return "" }

        var lines: [String] = []
        var usedTokens = 0

        for item in rag.items {
            let kind = switch item.kind {
            case .expanded: "expanded"
            case .surrogate: "surrogate"
            case .snippet: "snippet"
            }

            let sources = item.sources.map { source in
                switch source {
                case .text: return "text"
                case .vector: return "vector"
                case .timeline: return "timeline"
                case .structuredMemory: return "structuredMemory"
                }
            }.joined(separator: ",")

            let prefix = "[\(kind) frame:\(item.frameId) score:\(String(format: "%.2f", item.score)) sources:\(sources)]"
            let candidate = "\(prefix) \(item.text)"
            let tokens = configuration.tokenEstimator.estimateTokens(for: candidate)

            if usedTokens + tokens > tokenLimit { break }
            usedTokens += tokens
            lines.append(candidate)
        }

        return lines.joined(separator: "\n")
    }
}
