// MockEmbeddingProvider.swift
// SwarmTests
//
// Mock embedding provider for testing purposes.

import Foundation
@testable import Swarm

/// A mock embedding provider for testing purposes.
///
/// Generates deterministic pseudo-random embeddings based on input text hash.
/// Useful for unit tests where actual embeddings aren't needed.
struct MockEmbeddingProvider: EmbeddingProvider {
    let dimensions: Int
    let modelIdentifier: String = "mock-embedding-v1"

    /// Creates a mock embedding provider.
    ///
    /// - Parameter dimensions: The dimensionality of generated embeddings (default: 384)
    init(dimensions: Int = 384) {
        self.dimensions = dimensions
    }

    func embed(_ text: String) async throws -> [Float] {
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
