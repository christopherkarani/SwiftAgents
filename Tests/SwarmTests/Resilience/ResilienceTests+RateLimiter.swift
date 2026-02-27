import Foundation
@testable import Swarm
import Testing

@Suite("RateLimiter Safety Tests")
struct RateLimiterSafetyTests {
    @Test("Invalid maxRequestsPerMinute is sanitized to avoid hangs")
    func invalidRequestsPerMinuteIsSanitized() async throws {
        let limiter = RateLimiter(maxRequestsPerMinute: 0)
        let task = Task { try await limiter.acquire() }
        let completed = await completesWithin(task, timeout: .seconds(1))
        #expect(completed == true)
    }

    @Test("Invalid refill rate is sanitized to avoid hangs")
    func invalidRefillRateIsSanitized() async throws {
        let limiter = RateLimiter(maxTokens: 0, refillRatePerSecond: 0)
        let task = Task { try await limiter.acquire() }
        let completed = await completesWithin(task, timeout: .seconds(1))
        #expect(completed == true)
    }
}

private func completesWithin<T: Sendable>(_ task: Task<T, Error>, timeout: Duration) async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
        group.addTask {
            _ = try? await task.value
            return true
        }
        group.addTask {
            try? await Task.sleep(for: timeout)
            task.cancel()
            return false
        }
        let result = await group.next() ?? false
        group.cancelAll()
        return result
    }
}
