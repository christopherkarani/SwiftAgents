# Resilience

## Overview

Building robust agents that handle failures gracefully is critical for production systems. The Swarm framework provides a comprehensive set of resilience patterns that help your agents recover from transient failures, protect against cascading failures, and degrade gracefully when services are unavailable.

The resilience module includes four core components:

- **RetryPolicy** - Configurable retry strategies with multiple backoff patterns
- **CircuitBreaker** - Fault tolerance pattern to prevent cascading failures
- **FallbackChain** - Graceful degradation with ordered fallback strategies
- **RateLimiter** - Token bucket rate limiting for API constraints

All resilience components are built with Swift 6.2 concurrency in mind, using actors for thread-safe state management and full `Sendable` conformance.

---

## Retry Policies

### RetryPolicy

The `RetryPolicy` struct provides configurable retry logic with multiple backoff strategies. It allows you to automatically retry failed operations with customizable delays between attempts.

#### Basic Usage

```swift
let policy = RetryPolicy(
    maxAttempts: 3,
    backoff: .exponential(base: 1.0, multiplier: 2.0, maxDelay: 60.0)
)

let result = try await policy.execute {
    try await apiClient.fetchData()
}
```

#### Pre-configured Policies

Swarm provides convenient pre-configured policies for common scenarios:

```swift
// No retry - fails immediately on first error
let noRetry = RetryPolicy.noRetry

// Standard: 3 retries with exponential backoff (max 60s delay)
let standard = RetryPolicy.standard

// Aggressive: 5 retries with jitter (max 30s delay)
let aggressive = RetryPolicy.aggressive
```

#### Custom Retry Conditions

You can specify which errors should trigger a retry:

```swift
let policy = RetryPolicy(
    maxAttempts: 5,
    backoff: .exponentialWithJitter(base: 0.5, multiplier: 2.0, maxDelay: 30.0),
    shouldRetry: { error in
        // Only retry on network errors
        if let urlError = error as? URLError {
            return urlError.code == .timedOut || urlError.code == .networkConnectionLost
        }
        return false
    }
)
```

#### Retry Callbacks

Monitor retry attempts with the `onRetry` callback:

```swift
let policy = RetryPolicy(
    maxAttempts: 3,
    backoff: .exponential(base: 1.0, multiplier: 2.0, maxDelay: 30.0),
    onRetry: { attempt, error in
        print("Retry attempt \(attempt) after error: \(error.localizedDescription)")
    }
)
```

### Backoff Strategies

The `BackoffStrategy` enum provides multiple strategies for calculating delays between retry attempts:

#### Fixed Delay

Constant delay between all retry attempts:

```swift
let backoff = BackoffStrategy.fixed(delay: 2.0)
// Delays: 2s, 2s, 2s, ...
```

#### Linear Backoff

Delay increases linearly with each attempt:

```swift
let backoff = BackoffStrategy.linear(
    initial: 1.0,
    increment: 2.0,
    maxDelay: 10.0
)
// Delays: 1s, 3s, 5s, 7s, 9s, 10s (capped), ...
```

#### Exponential Backoff

Delay doubles (or multiplies by a factor) with each attempt:

```swift
let backoff = BackoffStrategy.exponential(
    base: 1.0,
    multiplier: 2.0,
    maxDelay: 60.0
)
// Delays: 1s, 2s, 4s, 8s, 16s, 32s, 60s (capped), ...
```

#### Exponential Backoff with Jitter

Adds randomization to prevent the thundering herd problem:

```swift
let backoff = BackoffStrategy.exponentialWithJitter(
    base: 1.0,
    multiplier: 2.0,
    maxDelay: 30.0
)
// Delays vary randomly within exponential bounds
```

#### Decorrelated Jitter

Better distribution of retry attempts across clients:

```swift
let backoff = BackoffStrategy.decorrelatedJitter(
    base: 1.0,
    maxDelay: 30.0
)
```

#### Immediate Retry

No delay between retries (use with caution):

```swift
let backoff = BackoffStrategy.immediate
```

#### Custom Backoff

Define your own delay calculation:

```swift
let backoff = BackoffStrategy.custom { attempt in
    // Custom logic: Fibonacci-like delays
    return Double(fibonacci(attempt))
}
```

### ResilienceError

When all retry attempts are exhausted, a `ResilienceError.retriesExhausted` is thrown:

```swift
do {
    let result = try await policy.execute { try await riskyOperation() }
} catch let error as ResilienceError {
    switch error {
    case .retriesExhausted(let attempts, let lastError):
        print("Failed after \(attempts) attempts: \(lastError)")
    default:
        break
    }
}
```

---

## Circuit Breakers

### CircuitBreaker

The `CircuitBreaker` actor implements the circuit breaker pattern to prevent cascading failures when a service is experiencing problems. It monitors operation failures and automatically "opens" to stop allowing operations when a threshold is reached.

#### State Machine

The circuit breaker operates in three states:

```
    [CLOSED] -----> [OPEN] -----> [HALF-OPEN]
        ^             |               |
        |             | timeout       |
        |             v               |
        +---------- reset <-----------+
                   (success)
```

- **Closed**: Normal operation. Requests are allowed through. Failures are counted.
- **Open**: Circuit is tripped. Requests are immediately rejected with `circuitBreakerOpen` error.
- **Half-Open**: Testing recovery. Limited requests are allowed to test if the service has recovered.

#### Basic Usage

```swift
let breaker = CircuitBreaker(
    name: "payment-service",
    failureThreshold: 5,
    resetTimeout: 60.0
)

do {
    let result = try await breaker.execute {
        try await paymentService.charge(amount: 100)
    }
} catch ResilienceError.circuitBreakerOpen(let serviceName) {
    print("Circuit open for \(serviceName), using fallback")
}
```

#### Configuration Parameters

```swift
let breaker = CircuitBreaker(
    name: "api-service",           // Unique identifier
    failureThreshold: 5,           // Failures before opening (default: 5)
    successThreshold: 2,           // Successes to close from half-open (default: 2)
    resetTimeout: 60.0,            // Seconds before half-open (default: 60.0)
    halfOpenMaxRequests: 1         // Concurrent requests in half-open (default: 1)
)
```

#### Checking State

```swift
let state = await breaker.currentState()

switch state {
case .closed:
    print("Circuit is healthy")
case .open(let until):
    print("Circuit open until \(until)")
case .halfOpen:
    print("Circuit testing recovery")
}

// Convenience method
let isAllowing = await breaker.isAllowingRequests()
```

#### Manual Control

```swift
// Manually reset to closed state
await breaker.reset()

// Manually trip the circuit
await breaker.trip()
```

#### Statistics

Monitor circuit breaker health with statistics:

```swift
let stats = await breaker.statistics()

print("Service: \(stats.name)")
print("State: \(stats.state)")
print("Failures: \(stats.failureCount)")
print("Successes: \(stats.successCount)")
print("Last failure: \(stats.lastFailureTime ?? "never")")

if let rate = stats.successRate {
    print("Success rate: \(rate * 100)%")
}
```

### CircuitBreakerRegistry

For managing multiple circuit breakers across your application, use the `CircuitBreakerRegistry`:

```swift
let registry = CircuitBreakerRegistry()

// Get or create a breaker with default configuration
let apiBreaker = await registry.breaker(named: "api")

// Get or create with custom configuration
let dbBreaker = await registry.breaker(named: "database") { config in
    config.failureThreshold = 10
    config.resetTimeout = 120.0
    config.halfOpenMaxRequests = 3
}

// Reuse existing breaker
let sameApiBreaker = await registry.breaker(named: "api")
```

#### Registry Operations

```swift
// Get all registered breakers
let allBreakers = await registry.allBreakers()

// Reset all breakers
await registry.resetAll()

// Remove a specific breaker
await registry.remove(named: "old-service")

// Clear all breakers
await registry.removeAll()

// Collect statistics from all breakers
let allStats = await registry.allStatistics()
for stat in allStats {
    print("\(stat.name): \(stat.state)")
}
```

#### Default Configuration

Set default configuration for all new breakers:

```swift
var defaultConfig = CircuitBreakerRegistry.Configuration()
defaultConfig.failureThreshold = 10
defaultConfig.resetTimeout = 30.0

let registry = CircuitBreakerRegistry(defaultConfiguration: defaultConfig)
```

---

## Fallbacks

### FallbackChain

The `FallbackChain` struct provides a fluent builder pattern for creating ordered fallback strategies. When the primary operation fails, it automatically tries backup operations in sequence.

#### Basic Usage

```swift
let result = try await FallbackChain<String>()
    .attempt(name: "Primary API") {
        try await primaryService.fetch()
    }
    .attempt(name: "Secondary API") {
        try await secondaryService.fetch()
    }
    .fallback(name: "Cache") {
        cachedValue
    }
    .execute()
```

#### Builder Methods

**attempt** - Add a throwing operation:

```swift
.attempt(name: "Remote Service") {
    try await remoteService.getData()
}
```

**attemptIf** - Add a conditional operation:

```swift
.attemptIf(
    name: "Cache",
    condition: { await cacheService.isAvailable() }
) {
    try await cacheService.getData()
}
```

**fallback** - Add a guaranteed fallback value:

```swift
// Static value
.fallback(name: "Default") {
    DefaultResponse()
}

// Or dynamic operation
.fallback(name: "Default") {
    await generateDefaultResponse()
}
```

#### Failure Callbacks

Monitor failures as they occur:

```swift
let result = try await FallbackChain<Data>()
    .attempt(name: "Primary") { try await primary.fetch() }
    .attempt(name: "Secondary") { try await secondary.fetch() }
    .onFailure { stepName, error in
        logger.warning("Step '\(stepName)' failed: \(error)")
        metrics.recordFailure(step: stepName)
    }
    .execute()
```

#### Execution Results

Get detailed information about execution:

```swift
let result = try await FallbackChain<String>()
    .attempt(name: "Primary") { try await primary.fetch() }
    .attempt(name: "Secondary") { try await secondary.fetch() }
    .fallback(name: "Default") { "fallback value" }
    .executeWithResult()

print("Output: \(result.output)")
print("Succeeded at step: \(result.stepName) (index \(result.stepIndex))")
print("Total attempts: \(result.totalAttempts)")

for error in result.errors {
    print("Step '\(error.stepName)' failed: \(error.error)")
}
```

#### Static Factory

Create a chain from a list of operations:

```swift
let chain = FallbackChain<Data>.from(
    (name: "Primary", operation: { try await primary.fetch() }),
    (name: "Secondary", operation: { try await secondary.fetch() }),
    (name: "Tertiary", operation: { try await tertiary.fetch() })
)

let result = try await chain.execute()
```

---

## Rate Limiting

### RateLimiter

The `RateLimiter` actor implements the token bucket algorithm for controlling API call rates. Tokens are added at a fixed rate, and each request consumes one token.

#### Basic Usage

```swift
let limiter = RateLimiter(maxRequestsPerMinute: 60)

// Blocking acquire - waits if rate limit reached
try await limiter.acquire()
let response = try await apiClient.call()
```

#### Non-blocking Acquire

```swift
if await limiter.tryAcquire() {
    let response = try await apiClient.call()
} else {
    print("Rate limit reached, try again later")
}
```

#### Custom Token Bucket

For fine-grained control, configure the token bucket directly:

```swift
let limiter = RateLimiter(
    maxTokens: 100,           // Maximum burst capacity
    refillRatePerSecond: 10   // Steady-state rate
)
```

#### Monitoring and Reset

```swift
// Check available tokens
let available = await limiter.available
print("Available tokens: \(available)")

// Reset to full capacity
await limiter.reset()
```

#### Integration with Agent Calls

```swift
class RateLimitedAgent {
    private let limiter = RateLimiter(maxRequestsPerMinute: 60)
    private let agent: Agent

    func execute(_ prompt: String) async throws -> String {
        try await limiter.acquire()
        return try await agent.run(prompt)
    }
}
```

---

## Timeouts

Swarm resilience patterns work seamlessly with Swift's structured concurrency for timeout handling.

### Using Task.timeout (Swift 6+)

```swift
// With retry policy
let policy = RetryPolicy.standard

let result = try await withThrowingTaskGroup(of: String.self) { group in
    group.addTask {
        try await policy.execute {
            try await apiClient.fetch()
        }
    }

    group.addTask {
        try await Task.sleep(for: .seconds(30))
        throw TimeoutError()
    }

    let result = try await group.next()!
    group.cancelAll()
    return result
}
```

### Timeout Wrapper

```swift
func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw ResilienceError.retriesExhausted(attempts: 0, lastError: "Timeout")
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// Usage
let result = try await withTimeout(seconds: 10) {
    try await agent.run("Hello")
}
```

---

## Combining Strategies

The real power of resilience patterns comes from combining them. Here are common patterns:

### Retry with Circuit Breaker

```swift
let breaker = CircuitBreaker(name: "api", failureThreshold: 5)
let policy = RetryPolicy.standard

let result = try await breaker.execute {
    try await policy.execute {
        try await apiClient.fetch()
    }
}
```

### Full Resilience Stack

```swift
// Configure components
let breaker = CircuitBreaker(name: "primary-api", failureThreshold: 5)
let limiter = RateLimiter(maxRequestsPerMinute: 60)
let policy = RetryPolicy(
    maxAttempts: 3,
    backoff: .exponentialWithJitter(base: 1.0, multiplier: 2.0, maxDelay: 30.0)
)

// Build fallback chain with full resilience
let result = try await FallbackChain<Response>()
    .attempt(name: "Primary API") {
        try await limiter.acquire()
        return try await breaker.execute {
            try await policy.execute {
                try await primaryAPI.fetch()
            }
        }
    }
    .attempt(name: "Secondary API") {
        try await secondaryAPI.fetch()
    }
    .fallback(name: "Cached") {
        await cache.getLastKnown()
    }
    .onFailure { step, error in
        logger.warning("[\(step)] failed: \(error)")
    }
    .execute()
```

### Agent with Resilience Wrapper

```swift
actor ResilientAgentWrapper {
    private let agent: Agent
    private let breaker: CircuitBreaker
    private let limiter: RateLimiter
    private let retryPolicy: RetryPolicy

    init(agent: Agent) {
        self.agent = agent
        self.breaker = CircuitBreaker(name: "agent", failureThreshold: 3)
        self.limiter = RateLimiter(maxRequestsPerMinute: 30)
        self.retryPolicy = RetryPolicy.standard
    }

    func run(_ prompt: String) async throws -> String {
        try await limiter.acquire()

        return try await breaker.execute {
            try await retryPolicy.execute {
                try await agent.run(prompt)
            }
        }
    }
}
```

---

## Best Practices

### 1. Choose Appropriate Backoff Strategies

- Use **exponential backoff** for external APIs to avoid overwhelming services
- Use **jitter** when multiple clients might retry simultaneously (thundering herd)
- Use **fixed delay** for internal services with predictable recovery times
- Use **immediate** only for fast, idempotent operations

### 2. Configure Circuit Breakers Thoughtfully

```swift
// For critical services: lower threshold, shorter timeout
let criticalBreaker = CircuitBreaker(
    name: "payment",
    failureThreshold: 3,
    resetTimeout: 30.0
)

// For non-critical services: higher threshold, longer timeout
let nonCriticalBreaker = CircuitBreaker(
    name: "recommendations",
    failureThreshold: 10,
    resetTimeout: 120.0
)
```

### 3. Always Provide Fallbacks

```swift
// Bad: No fallback, user sees error
let result = try await apiClient.fetch()

// Good: Graceful degradation
let result = try await FallbackChain<Data>()
    .attempt(name: "API") { try await apiClient.fetch() }
    .attempt(name: "Cache") { try await cache.get() }
    .fallback(name: "Default") { defaultData }
    .execute()
```

### 4. Monitor Your Resilience Components

```swift
// Periodically log circuit breaker stats
Task {
    while !Task.isCancelled {
        try await Task.sleep(for: .minutes(5))

        let stats = await registry.allStatistics()
        for stat in stats {
            if case .open = stat.state {
                logger.warning("Circuit '\(stat.name)' is OPEN")
            }
            logger.info("""
                Circuit '\(stat.name)': \
                state=\(stat.state), \
                success_rate=\(stat.successRate ?? 0)
                """)
        }
    }
}
```

### 5. Use Rate Limiting Proactively

```swift
// Match your API's rate limits
let openAILimiter = RateLimiter(maxRequestsPerMinute: 60)
let anthropicLimiter = RateLimiter(maxRequestsPerMinute: 50)

// Share limiters across components
let sharedLimiter = RateLimiter(maxRequestsPerMinute: 100)
```

### 6. Handle ResilienceError Appropriately

```swift
do {
    let result = try await resilientOperation()
} catch let error as ResilienceError {
    switch error {
    case .retriesExhausted(let attempts, let lastError):
        logger.error("Operation failed after \(attempts) retries: \(lastError)")
        // Show user-friendly error message

    case .circuitBreakerOpen(let service):
        logger.warning("Service '\(service)' is unavailable")
        // Use cached data or show maintenance message

    case .allFallbacksFailed(let errors):
        logger.critical("All fallbacks failed: \(errors)")
        // Critical alert, manual intervention may be needed
    }
}
```

### 7. Test Failure Scenarios

```swift
// In tests, manually trip breakers to verify fallback behavior
await breaker.trip()
XCTAssertThrowsError(try await breaker.execute { "should fail" })

// Reset for normal operation
await breaker.reset()
```

### 8. Keep Operations Idempotent

When using retries, ensure your operations are idempotent:

```swift
// Bad: Non-idempotent operation
let policy = RetryPolicy.standard
try await policy.execute {
    try await account.debit(amount: 100)  // May charge multiple times!
}

// Good: Idempotent with deduplication key
try await policy.execute {
    try await account.debit(amount: 100, idempotencyKey: transactionId)
}
```

---

## Error Reference

### ResilienceError

| Error | Description |
|-------|-------------|
| `.retriesExhausted(attempts:lastError:)` | All retry attempts failed |
| `.circuitBreakerOpen(serviceName:)` | Circuit breaker is open, blocking requests |
| `.allFallbacksFailed(errors:)` | All fallback chain steps failed |

All `ResilienceError` cases conform to `LocalizedError` for user-friendly error messages and `Sendable` for safe concurrent use.

---

## Summary

The Swarm resilience module provides production-ready patterns for building robust agent systems:

| Component | Use Case |
|-----------|----------|
| `RetryPolicy` | Transient failures, network timeouts |
| `CircuitBreaker` | Cascading failure prevention |
| `FallbackChain` | Graceful degradation |
| `RateLimiter` | API quota management |

By combining these patterns, you can build agents that gracefully handle failures, protect downstream services, and provide reliable user experiences even when underlying services are degraded.
