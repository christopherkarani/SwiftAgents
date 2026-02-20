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

        self.url = url
        self.embedder = embedder
        messages = (try? await Self.loadPersistedMessages(from: url)) ?? []
        self.orchestrator = try await Self.makeOrchestrator(
            at: url,
            configuration: effectiveConfiguration,
            embedder: embedder
        )
        self.configuration = effectiveConfiguration
        self.memoryPromptTitle = effectiveConfiguration.promptTitle
        self.memoryPromptGuidance = effectiveConfiguration.promptGuidance
    }

    public func add(_ message: MemoryMessage) async {
        var metadata = message.metadata
        metadata["role"] = message.role.rawValue
        metadata["timestamp"] = isoFormatter.string(from: message.timestamp)
        metadata["message_id"] = message.id.uuidString

        do {
            try await orchestrator.remember(message.content, metadata: metadata)
            messages.append(message)
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
        do {
            try await orchestrator.close()
            try await Self.recreateStore(at: url)
            orchestrator = try await Self.makeOrchestrator(
                at: url,
                configuration: configuration,
                embedder: embedder
            )
            if sessionIsActive {
                _ = await orchestrator.startSession()
            }
            messages.removeAll()
        } catch {
            Log.memory.error("WaxMemory: Failed to clear persisted state: \(error.localizedDescription)")
            messages = (try? await Self.loadPersistedMessages(from: url)) ?? []
        }
    }

    // MARK: - MemorySessionLifecycle

    public func beginMemorySession() async {
        sessionIsActive = true
        _ = await orchestrator.startSession()
    }

    public func endMemorySession() async {
        sessionIsActive = false
        await orchestrator.endSession()
    }

    // MARK: Private

    private var orchestrator: MemoryOrchestrator
    private let configuration: Configuration
    private let url: URL
    private let embedder: (any WaxVectorSearch.EmbeddingProvider)?
    private var sessionIsActive = false
    private var messages: [MemoryMessage] = []
    private let isoFormatter = ISO8601DateFormatter()

    private static func makeOrchestrator(
        at url: URL,
        configuration: Configuration,
        embedder: (any WaxVectorSearch.EmbeddingProvider)?
    ) async throws -> MemoryOrchestrator {
        try await MemoryOrchestrator(
            at: url,
            config: configuration.orchestratorConfig,
            embedder: embedder
        )
    }

    private static func recreateStore(at url: URL) async throws {
        let wax = try await Wax.create(at: url)
        try await wax.close()
    }

    private static func loadPersistedMessages(from url: URL) async throws -> [MemoryMessage] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        let wax = try await Wax.open(at: url)
        do {
            let allMetas = await wax.frameMetas()
                .filter { $0.role == .document && $0.status == .active }
                .sorted { lhs, rhs in
                    if lhs.timestamp == rhs.timestamp {
                        return lhs.id < rhs.id
                    }
                    return lhs.timestamp < rhs.timestamp
                }

            let frameIds = allMetas.map(\.id)
            let contentsByID = try await wax.frameContents(frameIds: frameIds)
            let formatter = ISO8601DateFormatter()

            var restored: [MemoryMessage] = []
            restored.reserveCapacity(allMetas.count)

            for meta in allMetas {
                guard let payload = contentsByID[meta.id],
                      let content = String(data: payload, encoding: .utf8)
                else {
                    continue
                }

                let metadata = meta.metadata?.entries ?? [:]
                let role = metadata["role"].flatMap(MemoryMessage.Role.init(rawValue:)) ?? .user
                let timestamp = metadata["timestamp"].flatMap(formatter.date(from:))
                    ?? Date(timeIntervalSince1970: TimeInterval(meta.timestamp) / 1000)
                let id = metadata["message_id"].flatMap(UUID.init(uuidString:)) ?? UUID()

                restored.append(
                    MemoryMessage(
                        id: id,
                        role: role,
                        content: content,
                        timestamp: timestamp,
                        metadata: metadata
                    )
                )
            }

            try await wax.close()
            return restored
        } catch {
            try? await wax.close()
            throw error
        }
    }

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
