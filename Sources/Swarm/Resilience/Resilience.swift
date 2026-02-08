// Resilience.swift
// Swarm Framework
//
// Resilience patterns for robust agent execution.
// Includes:
// - Retry policies with exponential backoff (see RetryPolicy.swift)
// - Fallback chains for graceful degradation (see FallbackChain.swift)
// - Circuit breaker pattern (to be implemented)
// - Timeout handling (to be implemented)

// Re-export key resilience types
@_exported import struct Foundation.TimeInterval

/// Re-export resilience types for convenient access
public typealias Retry = RetryPolicy
public typealias Fallback = FallbackChain
