import Foundation
@testable import Swarm

// MARK: - SwarmConfigurationTestMutex

private actor SwarmConfigurationTestMutex {
    // MARK: Internal

    static let shared = SwarmConfigurationTestMutex()

    func withLock<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
        await acquire()
        defer { release() }
        return try await operation()
    }

    // MARK: Private

    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private func acquire() async {
        guard !isLocked else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
            return
        }

        isLocked = true
    }

    private func release() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }

        let next = waiters.removeFirst()
        next.resume()
    }
}

func withSwarmConfigurationIsolation<T: Sendable>(
    _ operation: @Sendable () async throws -> T
) async rethrows -> T {
    try await SwarmConfigurationTestMutex.shared.withLock {
        await Swarm.reset()
        do {
            let result = try await operation()
            await Swarm.reset()
            return result
        } catch {
            await Swarm.reset()
            throw error
        }
    }
}
