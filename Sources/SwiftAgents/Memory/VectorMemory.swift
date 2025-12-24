//
//  VectorMemory.swift
//  SwiftAgents
//
//  Created as part of audit remediation - Phase 4
//

import Foundation

#if canImport(Accelerate)
import Accelerate
#endif

// MARK: - VectorMemory

/// Memory implementation with semantic search via embeddings.
///
/// VectorMemory stores messages along with their vector embeddings,
/// enabling semantic similarity search for context retrieval.
/// This is essential for RAG (Retrieval-Augmented Generation) applications.
///
/// ## Usage
///
/// ```swift
/// let memory = VectorMemory(
///     embeddingProvider: MyEmbeddingProvider(),
///     similarityThreshold: 0.7,
///     maxResults: 10
/// )
///
/// await memory.add(.user("What is Swift concurrency?"))
/// // ... many more messages ...
///
/// // Retrieves semantically similar messages
/// let context = await memory.context(
///     for: "How do actors work?",
///     tokenLimit: 2000
/// )
/// ```
///
/// ## How It Works
///
/// 1. When messages are added, they are embedded using the provided `EmbeddingProvider`
/// 2. During context retrieval, the query is embedded and compared against stored embeddings
/// 3. Messages with similarity above the threshold are returned, ranked by similarity
/// 4. Results are limited by `maxResults` and `tokenLimit`
///
/// ## Performance
///
/// On Apple platforms, cosine similarity uses SIMD-optimized operations
/// via the Accelerate framework for efficient vector comparisons.
///
/// ## Thread Safety
///
/// As an actor, `VectorMemory` is automatically thread-safe.
/// All operations are serialized through the actor's executor.
public actor VectorMemory: Memory {
    // MARK: - Types

    /// A message paired with its embedding vector.
    private struct EmbeddedMessage: Sendable {
        let message: MemoryMessage
        let embedding: [Float]
    }

    /// Search result containing a message and its similarity score.
    public struct SearchResult: Sendable {
        /// The matched message.
        public let message: MemoryMessage
        /// Cosine similarity score (0 to 1, higher is more similar).
        public let similarity: Float
    }

    // MARK: - Configuration

    /// Minimum similarity score for results (0 to 1).
    public let similarityThreshold: Float

    /// Maximum number of results to return from similarity search.
    public let maxResults: Int

    /// The embedding provider used to vectorize messages.
    public let embeddingProvider: any EmbeddingProvider

    // MARK: - State

    /// Stored messages with their embeddings.
    private var embeddedMessages: [EmbeddedMessage] = []

    /// Token estimator for context retrieval.
    private let tokenEstimator: any TokenEstimator

    // MARK: - Memory Protocol Properties

    public var count: Int {
        embeddedMessages.count
    }

    public var isEmpty: Bool {
        embeddedMessages.isEmpty
    }

    // MARK: - Initialization

    /// Creates a new vector memory.
    ///
    /// - Parameters:
    ///   - embeddingProvider: Provider for generating text embeddings.
    ///   - similarityThreshold: Minimum similarity for results (0-1, default: 0.7).
    ///   - maxResults: Maximum results to return (default: 10).
    ///   - tokenEstimator: Estimator for token counting.
    public init(
        embeddingProvider: any EmbeddingProvider,
        similarityThreshold: Float = 0.7,
        maxResults: Int = 10,
        tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared
    ) {
        self.embeddingProvider = embeddingProvider
        self.similarityThreshold = max(0, min(1, similarityThreshold))
        self.maxResults = max(1, maxResults)
        self.tokenEstimator = tokenEstimator
    }

    // MARK: - Memory Protocol Implementation

    /// Adds a message to memory with its embedding.
    ///
    /// The message content is embedded using the configured `EmbeddingProvider`.
    /// If embedding fails, the error is logged but the message is not stored.
    ///
    /// - Parameter message: The message to store.
    public func add(_ message: MemoryMessage) async {
        do {
            let embedding = try await embeddingProvider.embed(message.content)
            let embeddedMessage = EmbeddedMessage(message: message, embedding: embedding)
            embeddedMessages.append(embeddedMessage)
        } catch {
            // Log error but don't throw - embedding failures shouldn't break the memory contract
            Log.memory.error("Failed to embed message: \(error.localizedDescription)")
        }
    }

    /// Retrieves context relevant to the query using semantic similarity.
    ///
    /// Embeds the query and finds the most similar messages in memory.
    /// Results are filtered by `similarityThreshold` and limited by `maxResults`
    /// and `tokenLimit`.
    ///
    /// - Parameters:
    ///   - query: The query to find relevant context for.
    ///   - tokenLimit: Maximum tokens to include in the context.
    /// - Returns: A formatted string containing relevant context, ordered by similarity.
    public func context(for query: String, tokenLimit: Int) async -> String {
        guard !embeddedMessages.isEmpty else {
            return ""
        }

        do {
            let queryEmbedding = try await embeddingProvider.embed(query)
            let results = search(queryEmbedding: queryEmbedding)

            // Format results within token limit
            return formatResultsForContext(results, tokenLimit: tokenLimit)
        } catch {
            Log.memory.error("Failed to embed query: \(error.localizedDescription)")
            // Fallback to simple recency-based context
            return formatMessagesForContext(
                embeddedMessages.map(\.message),
                tokenLimit: tokenLimit,
                tokenEstimator: tokenEstimator
            )
        }
    }

    /// Returns all messages currently in memory.
    ///
    /// - Returns: Array of all stored messages in chronological order.
    public func allMessages() async -> [MemoryMessage] {
        embeddedMessages.map(\.message)
    }

    /// Removes all messages from memory.
    public func clear() async {
        embeddedMessages.removeAll()
    }

    // MARK: - Semantic Search

    /// Performs semantic search across stored messages.
    ///
    /// - Parameter query: The text query to search for.
    /// - Returns: Array of search results sorted by similarity (highest first).
    public func search(query: String) async throws -> [SearchResult] {
        guard !embeddedMessages.isEmpty else {
            return []
        }

        let queryEmbedding = try await embeddingProvider.embed(query)
        return search(queryEmbedding: queryEmbedding)
    }

    /// Performs semantic search using a pre-computed query embedding.
    ///
    /// - Parameter queryEmbedding: The embedding vector to search with.
    /// - Returns: Array of search results sorted by similarity (highest first).
    public func search(queryEmbedding: [Float]) -> [SearchResult] {
        var results: [SearchResult] = []
        results.reserveCapacity(embeddedMessages.count)

        for embeddedMessage in embeddedMessages {
            let similarity = VectorMemory.cosineSimilarity(
                queryEmbedding,
                embeddedMessage.embedding
            )

            if similarity >= similarityThreshold {
                results.append(SearchResult(
                    message: embeddedMessage.message,
                    similarity: similarity
                ))
            }
        }

        // Sort by similarity (highest first) and limit results
        return results
            .sorted { $0.similarity > $1.similarity }
            .prefix(maxResults)
            .map { $0 }
    }

    // MARK: - Batch Operations

    /// Adds multiple messages at once.
    ///
    /// More efficient than adding messages individually when importing
    /// conversation history, as it uses batch embedding.
    ///
    /// - Parameter newMessages: Messages to add in order.
    public func addAll(_ newMessages: [MemoryMessage]) async {
        guard !newMessages.isEmpty else { return }

        do {
            let contents = newMessages.map(\.content)
            let embeddings = try await embeddingProvider.embed(contents)

            for (message, embedding) in zip(newMessages, embeddings) {
                embeddedMessages.append(EmbeddedMessage(
                    message: message,
                    embedding: embedding
                ))
            }
        } catch {
            Log.memory.error("Batch embedding failed: \(error.localizedDescription)")
            // Fallback to individual embedding
            for message in newMessages {
                await add(message)
            }
        }
    }

    /// Returns messages matching a predicate.
    ///
    /// - Parameter predicate: Closure to test each message.
    /// - Returns: Array of messages where predicate returns true.
    public func filter(_ predicate: @Sendable (MemoryMessage) -> Bool) async -> [MemoryMessage] {
        embeddedMessages.map(\.message).filter(predicate)
    }

    /// Returns messages with a specific role.
    ///
    /// - Parameter role: The role to filter by.
    /// - Returns: Array of messages with the specified role.
    public func messages(withRole role: MemoryMessage.Role) async -> [MemoryMessage] {
        embeddedMessages.filter { $0.message.role == role }.map(\.message)
    }

    // MARK: - Private Helpers

    /// Formats search results into a context string within token limits.
    private func formatResultsForContext(_ results: [SearchResult], tokenLimit: Int) -> String {
        var formatted: [String] = []
        var currentTokens = 0

        for result in results {
            let messageText = result.message.formattedContent
            let messageTokens = tokenEstimator.estimateTokens(for: messageText)

            if currentTokens + messageTokens <= tokenLimit {
                formatted.append(messageText)
                currentTokens += messageTokens
            } else {
                break
            }
        }

        return formatted.joined(separator: "\n\n")
    }

    // MARK: - SIMD-Optimized Vector Operations

    /// Calculates cosine similarity between two vectors.
    ///
    /// Uses SIMD-optimized operations via Accelerate on Apple platforms,
    /// with a portable fallback for other platforms.
    ///
    /// - Parameters:
    ///   - a: First vector.
    ///   - b: Second vector.
    /// - Returns: Cosine similarity score between -1 and 1 (1 = identical).
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        #if canImport(Accelerate)
        return accelerateCosineSimilarity(a, b)
        #else
        return fallbackCosineSimilarity(a, b)
        #endif
    }

    #if canImport(Accelerate)
    /// SIMD-optimized cosine similarity using Accelerate framework.
    private static func accelerateCosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        // Use vDSP for vectorized operations
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }
    #endif

    /// Portable fallback cosine similarity implementation.
    private static func fallbackCosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }
}

// MARK: - Diagnostic Information

public extension VectorMemory {
    /// Returns diagnostic information about memory state.
    func diagnostics() async -> VectorMemoryDiagnostics {
        VectorMemoryDiagnostics(
            messageCount: embeddedMessages.count,
            embeddingDimensions: embeddingProvider.dimensions,
            similarityThreshold: similarityThreshold,
            maxResults: maxResults,
            modelIdentifier: embeddingProvider.modelIdentifier,
            oldestTimestamp: embeddedMessages.first?.message.timestamp,
            newestTimestamp: embeddedMessages.last?.message.timestamp
        )
    }
}

// MARK: - VectorMemoryDiagnostics

/// Diagnostic information for vector memory.
public struct VectorMemoryDiagnostics: Sendable {
    /// Current number of messages stored.
    public let messageCount: Int
    /// Dimensionality of the embeddings.
    public let embeddingDimensions: Int
    /// Configured similarity threshold.
    public let similarityThreshold: Float
    /// Maximum results returned from search.
    public let maxResults: Int
    /// Identifier of the embedding model.
    public let modelIdentifier: String
    /// Timestamp of the oldest message.
    public let oldestTimestamp: Date?
    /// Timestamp of the newest message.
    public let newestTimestamp: Date?
}

// MARK: - VectorMemory Configuration Builder

/// Builder for fluent VectorMemory configuration.
public struct VectorMemoryBuilder: Sendable {
    private var embeddingProvider: (any EmbeddingProvider)?
    private var similarityThreshold: Float = 0.7
    private var maxResults: Int = 10
    private var tokenEstimator: any TokenEstimator = CharacterBasedTokenEstimator.shared

    /// Creates a new vector memory builder.
    public init() {}

    /// Sets the embedding provider.
    ///
    /// - Parameter provider: The embedding provider to use.
    /// - Returns: Updated builder.
    public func embeddingProvider(_ provider: any EmbeddingProvider) -> VectorMemoryBuilder {
        var copy = self
        copy.embeddingProvider = provider
        return copy
    }

    /// Sets the similarity threshold.
    ///
    /// - Parameter threshold: Minimum similarity for results (0-1).
    /// - Returns: Updated builder.
    public func similarityThreshold(_ threshold: Float) -> VectorMemoryBuilder {
        var copy = self
        copy.similarityThreshold = threshold
        return copy
    }

    /// Sets the maximum number of results.
    ///
    /// - Parameter max: Maximum results to return from search.
    /// - Returns: Updated builder.
    public func maxResults(_ max: Int) -> VectorMemoryBuilder {
        var copy = self
        copy.maxResults = max
        return copy
    }

    /// Sets the token estimator.
    ///
    /// - Parameter estimator: Token estimator for context retrieval.
    /// - Returns: Updated builder.
    public func tokenEstimator(_ estimator: any TokenEstimator) -> VectorMemoryBuilder {
        var copy = self
        copy.tokenEstimator = estimator
        return copy
    }

    /// Builds the VectorMemory instance.
    ///
    /// - Returns: Configured VectorMemory.
    /// - Throws: `VectorMemoryError.missingEmbeddingProvider` if no provider was set.
    public func build() throws -> VectorMemory {
        guard let provider = embeddingProvider else {
            throw VectorMemoryError.missingEmbeddingProvider
        }

        return VectorMemory(
            embeddingProvider: provider,
            similarityThreshold: similarityThreshold,
            maxResults: maxResults,
            tokenEstimator: tokenEstimator
        )
    }
}

// MARK: - VectorMemory Errors

/// Errors specific to VectorMemory operations.
public enum VectorMemoryError: Error, Sendable, CustomStringConvertible {
    /// Embedding provider was not configured.
    case missingEmbeddingProvider

    /// Search failed due to embedding error.
    case searchFailed(underlying: any Error & Sendable)

    public var description: String {
        switch self {
        case .missingEmbeddingProvider:
            return "VectorMemory requires an EmbeddingProvider"
        case let .searchFailed(error):
            return "Search failed: \(error.localizedDescription)"
        }
    }
}
