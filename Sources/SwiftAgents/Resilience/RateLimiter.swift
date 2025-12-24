//
//  RateLimiter.swift
//  SwiftAgents
//
//  Created as part of audit remediation - Phase 5
//

import Foundation

/// Token bucket rate limiter for API calls
///
/// Implements the token bucket algorithm for rate limiting:
/// - Tokens are added at a fixed rate
/// - Each request consumes one token
/// - If no tokens available, the request waits
///
/// Usage:
/// ```swift
/// let limiter = RateLimiter(maxRequestsPerMinute: 60)
///
/// // In your API calls
/// try await limiter.acquire()  // Waits if rate limit reached
/// let response = try await apiClient.call()
///
/// // Or check without waiting
/// if limiter.tryAcquire() {
///     let response = try await apiClient.call()
/// }
/// ```
public actor RateLimiter {
    private let maxTokens: Int
    private let refillRate: Double  // tokens per second
    private var availableTokens: Double
    private var lastRefillTime: ContinuousClock.Instant

    /// Create rate limiter with requests per minute
    public init(maxRequestsPerMinute: Int) {
        precondition(maxRequestsPerMinute > 0, "maxRequestsPerMinute must be positive")
        self.maxTokens = maxRequestsPerMinute
        self.refillRate = Double(maxRequestsPerMinute) / 60.0
        self.availableTokens = Double(maxRequestsPerMinute)
        self.lastRefillTime = .now
    }

    /// Create rate limiter with custom token bucket parameters
    public init(maxTokens: Int, refillRatePerSecond: Double) {
        precondition(maxTokens > 0, "maxTokens must be positive")
        precondition(refillRatePerSecond > 0, "refillRatePerSecond must be positive")
        self.maxTokens = maxTokens
        self.refillRate = refillRatePerSecond
        self.availableTokens = Double(maxTokens)
        self.lastRefillTime = .now
    }

    /// Acquire a token, waiting if necessary
    public func acquire() async throws {
        try Task.checkCancellation()
        
        // Fixed: Restructure loop to make check-and-decrement atomic
        // This eliminates the reentrancy window where another task could
        // interleave between the while condition check and the decrement
        while true {
            refill()
            if availableTokens >= 1 {
                availableTokens -= 1
                return  // SUCCESS - check and decrement are atomic within actor
            }
            
            // Calculate wait time and suspend
            let waitTime = (1 - availableTokens) / refillRate
            try await Task.sleep(for: .seconds(waitTime))
            try Task.checkCancellation()
        }
    }

    /// Try to acquire without waiting
    public func tryAcquire() -> Bool {
        refill()
        if availableTokens >= 1 {
            availableTokens -= 1
            return true
        }
        return false
    }

    /// Current available tokens.
    /// - Warning: Due to actor isolation, the returned value may be stale by the time
    ///   the caller uses it. For guaranteed acquisition, use `tryAcquire()` instead.
    public var available: Int {
        refill()
        return Int(availableTokens)
    }

    /// Reset the limiter to full capacity.
    /// - Warning: Calling this while other tasks are waiting in `acquire()` may cause
    ///   unexpected behavior. Ensure no concurrent operations are in progress.
    public func reset() {
        availableTokens = Double(maxTokens)
        lastRefillTime = .now
    }

    private func refill() {
        let now = ContinuousClock.now
        let elapsed = now - lastRefillTime
        let tokensToAdd = elapsed.seconds * refillRate
        availableTokens = min(Double(maxTokens), availableTokens + tokensToAdd)
        lastRefillTime = now
    }
}

private extension Duration {
    var seconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1_000_000_000_000_000_000
    }
}
