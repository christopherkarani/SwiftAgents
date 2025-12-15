# Pre-Existing Test Compilation Errors

This document catalogs test compilation errors that existed prior to the Linux build fix (December 2025). These errors are unrelated to the `ArithmeticParser` and `CalculatorTool` changes.

## Summary

| Category | File Count | Error Count |
|----------|------------|-------------|
| ResilienceError Enum Mismatches | 3 | 6 |
| Ambiguous Method Calls | 2 | 10+ |
| Builder Pattern Mismatches | 2 | 4+ |
| RetryPolicy API Changes | 1 | 4 |

---

## 1. ResilienceError Enum Case Mismatches

### File: `ResilienceTests+CircuitBreaker.swift`

**Location:** Line 110

```swift
// Current code (incorrect):
if case .circuitBreakerOpen(let serviceName) = error {
    #expect(serviceName == "payment-service")
}

// Error: pattern with associated values does not match enum case 'circuitBreakerOpen'
// Note: remove associated values to make the pattern match
```

**Root Cause:** The `ResilienceError.circuitBreakerOpen` case no longer has an associated value, but the test expects one.

---

### File: `ResilienceTests+Retry.swift`

**Location:** Lines 95, 118

```swift
// Error 1 (line 95):
if case .retriesExhausted(let attempts, let lastError) = error {
    #expect(attempts == 3)
}
// Error: type '_ErrorCodeProtocol' has no member 'retriesExhausted'

// Error 2 (line 118):
#expect(error == .retriesExhausted(attempts: 4, lastError: "timeout"))
// Error: type 'ResilienceError' has no member 'retriesExhausted'
```

**Root Cause:** The `retriesExhausted` case has been removed or renamed in `ResilienceError`.

---

### File: `ResilienceTests+Fallback.swift`

**Location:** Lines 111, 129

```swift
// Error (line 111):
if case .allFallbacksFailed(let errors) = error {
    #expect(errors.count == 2)
}
// Error: type '_ErrorCodeProtocol' has no member 'allFallbacksFailed'
```

**Root Cause:** The `allFallbacksFailed` case has been removed or renamed in `ResilienceError`.

---

## 2. Ambiguous Method Calls

### File: `FluentResilienceTests.swift`

**Location:** Lines 229, 247, 265

```swift
// Error (line 229):
let resilientAgent = baseAgent.withRetry(.exponentialBackoff(maxAttempts: 3))
// Error: ambiguous use of 'withRetry'

// Error (line 247):
let timedAgent = baseAgent.withTimeout(.seconds(10))
// Error: ambiguous use of 'withTimeout'
```

**Root Cause:** Two candidates exist:
1. `Agent` extension method (internal, in test file)
2. `ResilientAgent` extension method (public, in framework)

**Candidates:**
```swift
// In test file (FluentResilienceTests.swift:425):
extension Agent {
    func withRetry(_ policy: RetryPolicy) -> ResilientAgent { ... }
}

// In framework (ResilientAgent.swift:327):
public func withRetry(_ policy: RetryPolicy) -> ResilientAgent { ... }
```

---

## 3. Builder Pattern Mismatches

### File: `ToolParameterBuilderTests.swift`

**Location:** Line 228

```swift
@ToolParameterBuilder
func makeParams() -> [ToolParameter] {
    // Empty
}
// Error: ambiguous use of 'buildBlock'
```

**Root Cause:** Two `buildBlock` overloads exist:
```swift
// Candidate 1 (ToolParameterBuilder.swift:39):
public static func buildBlock(_ components: ToolParameter...) -> [ToolParameter]

// Candidate 2 (ToolParameterBuilder.swift:44):
public static func buildBlock(_ components: [ToolParameter]...) -> [ToolParameter]
```

Empty builder body creates ambiguity between these overloads.

---

### File: `MemoryBuilderTests.swift`

**Location:** Line 20

```swift
let memory = CompositeMemory {
    ConversationMemory(maxTokens: 1000)
}
// Error: cannot pass array of type '[MemoryComponent]' as variadic arguments of type 'MemoryComponent'
```

**Root Cause:** `CompositeMemory` initializer signature changed.

---

## 4. RetryPolicy API Changes

### File: `FluentResilienceTests.swift`

**Location:** Lines 449, 461

```swift
// Error (line 449):
RetryPolicy(maxAttempts: maxAttempts, strategy: .fixed(delay: delay))
// Error: extra argument 'strategy' in call
// Error: cannot infer contextual base in reference to member 'fixed'

// Error (line 461):
RetryPolicy(
    maxAttempts: maxAttempts,
    strategy: .exponential(base: baseDelay, max: maxDelay, multiplier: multiplier, jitter: jitter)
)
// Error: extra argument 'strategy' in call
```

**Root Cause:** `RetryPolicy` initializer no longer accepts a `strategy` parameter. The API has been redesigned.

---

## Recommended Fixes

### Priority 1: Update ResilienceError Tests
1. Check current `ResilienceError` enum definition
2. Update test pattern matching to use correct case names/associated values
3. Remove references to deleted cases (`retriesExhausted`, `allFallbacksFailed`)

### Priority 2: Resolve Ambiguous Methods
1. Remove duplicate `withRetry`/`withTimeout` extensions from test file
2. Use the public API from `ResilientAgent` directly

### Priority 3: Fix Builder Tests
1. Add `buildBlock() -> [T]` overload for empty builders, OR
2. Update tests to not use empty builder bodies

### Priority 4: Update RetryPolicy Tests
1. Check current `RetryPolicy` API
2. Update test helper extensions to use new initializer signature

---

## Files Affected

```
Tests/SwiftAgentsTests/
├── Resilience/
│   ├── ResilienceTests+CircuitBreaker.swift  ❌
│   ├── ResilienceTests+Retry.swift           ❌
│   └── ResilienceTests+Fallback.swift        ❌
├── DSL/
│   ├── ToolParameterBuilderTests.swift       ❌
│   ├── MemoryBuilderTests.swift              ❌
│   └── FluentResilienceTests.swift           ❌
└── Tools/
    ├── ArithmeticParserTests.swift           ✅ (new, compiles)
    └── CalculatorToolTests.swift             ✅ (new, compiles)
```

---

## Related Source Files

To fix these test errors, review the current implementations in:

- `Sources/SwiftAgents/Resilience/ResilienceError.swift`
- `Sources/SwiftAgents/Resilience/ResilientAgent.swift`
- `Sources/SwiftAgents/Resilience/RetryPolicy.swift`
- `Sources/SwiftAgents/Tools/ToolParameterBuilder.swift`
- `Sources/SwiftAgents/Memory/CompositeMemory.swift`
