// EmbeddingProvider.swift
// Swarm Framework
//
// Protocol for text-to-vector embeddings for semantic search.

import Foundation

// MARK: - EmbeddingProvider

/// Protocol for embedding text into vectors for semantic search
///
/// Embedding providers convert text into dense vector representations
/// that capture semantic meaning. These vectors enable similarity search
/// in VectorMemory for retrieval-augmented generation (RAG) applications.
///
/// Implementations might include:
/// - OpenAI embeddings API
/// - Sentence transformers
/// - On-device models (e.g., via MLX)
/// - Foundation Models embeddings (when available)
///
/// Example Implementation:
/// ```swift
/// struct OpenAIEmbeddingProvider: EmbeddingProvider {
///     let apiKey: String
///     let model: String = "text-embedding-3-small"
///
///     var dimensions: Int { 1536 }
///
///     func embed(_ text: String) async throws -> [Float] {
///         // Call OpenAI embeddings API
///     }
/// }
/// ```
public protocol EmbeddingProvider: Sendable {
    /// The dimensionality of embeddings produced by this provider
    ///
    /// All embeddings from this provider will have this many dimensions.
    /// Common values: 384, 768, 1024, 1536, 3072
    var dimensions: Int { get }

    /// Optional: The model identifier used for embeddings
    var modelIdentifier: String { get }

    /// Embed a single text into a vector
    ///
    /// - Parameter text: The text to embed
    /// - Returns: A vector of floats representing the text's semantic meaning
    /// - Throws: `EmbeddingError` if embedding fails
    func embed(_ text: String) async throws -> [Float]

    /// Batch embed multiple texts
    ///
    /// Default implementation calls `embed(_:)` sequentially.
    /// Override for optimized batch processing.
    ///
    /// - Parameter texts: Array of texts to embed
    /// - Returns: Array of embedding vectors (same order as input)
    /// - Throws: `EmbeddingError` if any embedding fails
    func embed(_ texts: [String]) async throws -> [[Float]]
}

// MARK: - Default Implementations

public extension EmbeddingProvider {
    /// Default model identifier
    var modelIdentifier: String { "unknown" }

    /// Default batch implementation - sequential embedding
    ///
    /// Override this for providers that support native batch operations.
    func embed(_ texts: [String]) async throws -> [[Float]] {
        var results: [[Float]] = []
        results.reserveCapacity(texts.count)

        for text in texts {
            try Task.checkCancellation()
            let embedding = try await embed(text)
            results.append(embedding)
        }

        return results
    }
}

// MARK: - EmbeddingError

/// Errors specific to embedding operations
public enum EmbeddingError: Error, Sendable, CustomStringConvertible {
    // MARK: Public

    public var description: String {
        switch self {
        case let .modelUnavailable(reason):
            return "Embedding model unavailable: \(reason)"
        case let .dimensionMismatch(expected, got):
            return "Embedding dimension mismatch: expected \(expected), got \(got)"
        case .emptyInput:
            return "Cannot embed empty input"
        case let .batchTooLarge(size, limit):
            return "Batch size \(size) exceeds limit \(limit)"
        case let .networkError(error):
            return "Network error: \(error.localizedDescription)"
        case let .rateLimitExceeded(retryAfter):
            if let retry = retryAfter {
                return "Rate limit exceeded, retry after \(retry)s"
            }
            return "Rate limit exceeded"
        case .authenticationFailed:
            return "Authentication failed"
        case let .embeddingFailed(reason):
            return "Embedding failed: \(reason)"
        }
    }

    /// The embedding model is not available
    case modelUnavailable(reason: String)

    /// Embedding dimensions don't match expected
    case dimensionMismatch(expected: Int, got: Int)

    /// Input text is empty or invalid
    case emptyInput

    /// Batch size exceeds provider limits
    case batchTooLarge(size: Int, limit: Int)

    /// Network or API error
    case networkError(underlying: any Error & Sendable)

    /// Rate limit exceeded
    case rateLimitExceeded(retryAfter: TimeInterval?)

    /// Invalid API key or authentication failure
    case authenticationFailed

    /// Generic embedding failure
    case embeddingFailed(reason: String)
}

// MARK: - MockEmbeddingProvider

/// A mock embedding provider for testing purposes
///
/// Generates deterministic pseudo-random embeddings based on input text hash.
/// Useful for unit tests where actual embeddings aren't needed.
public struct MockEmbeddingProvider: EmbeddingProvider {
    public let dimensions: Int
    public let modelIdentifier: String = "mock-embedding-v1"

    /// Creates a mock embedding provider
    ///
    /// - Parameter dimensions: The dimensionality of generated embeddings (default: 384)
    public init(dimensions: Int = 384) {
        self.dimensions = dimensions
    }

    public func embed(_ text: String) async throws -> [Float] {
        guard !text.isEmpty else {
            throw EmbeddingError.emptyInput
        }

        // Generate deterministic pseudo-random embedding based on text hash
        var embedding = [Float](repeating: 0, count: dimensions)
        let hash = text.hashValue

        for i in 0..<dimensions {
            // Use hash and index to generate reproducible values
            let seed = hash &+ i
            embedding[i] = Float(sin(Double(seed))) * 0.5 + 0.5
        }

        // Normalize to unit vector
        let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            embedding = embedding.map { $0 / magnitude }
        }

        return embedding
    }
}

// MARK: - EmbeddingUtils

/// Utility functions for working with embeddings
public enum EmbeddingUtils {
    /// Calculate cosine similarity between two vectors
    ///
    /// - Parameters:
    ///   - vec1: First vector
    ///   - vec2: Second vector
    /// - Returns: Similarity score between -1 and 1 (1 = identical)
    public static func cosineSimilarity(_ vec1: [Float], _ vec2: [Float]) -> Float {
        guard vec1.count == vec2.count, !vec1.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var norm1: Float = 0
        var norm2: Float = 0

        for i in 0..<vec1.count {
            dotProduct += vec1[i] * vec2[i]
            norm1 += vec1[i] * vec1[i]
            norm2 += vec2[i] * vec2[i]
        }

        let denominator = sqrt(norm1) * sqrt(norm2)
        return denominator > 0 ? dotProduct / denominator : 0
    }

    /// Calculate Euclidean distance between two vectors
    ///
    /// - Parameters:
    ///   - embedding1: First vector
    ///   - embedding2: Second vector
    /// - Returns: Euclidean distance (lower = more similar)
    public static func euclideanDistance(_ embedding1: [Float], _ embedding2: [Float]) -> Float {
        guard embedding1.count == embedding2.count else { return Float.infinity }

        var sum: Float = 0
        for i in 0..<embedding1.count {
            let diff = embedding1[i] - embedding2[i]
            sum += diff * diff
        }

        return sqrt(sum)
    }

    /// Normalize a vector to unit length
    ///
    /// - Parameter vector: The vector to normalize
    /// - Returns: Unit vector (magnitude = 1)
    public static func normalize(_ vector: [Float]) -> [Float] {
        let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }
}
