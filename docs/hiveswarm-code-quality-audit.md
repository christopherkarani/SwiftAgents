# HiveSwarm Code Quality Audit

**Date:** 2026-02-13  
**Scope:** `Sources/HiveSwarm/` — 6 files, ~1,611 lines  
**Files Analyzed:**
- `HiveAgents.swift` (773 lines)
- `HiveBackedAgent.swift` (481 lines)
- `SwarmToolRegistry.swift` (227 lines)
- `HiveCodableJSONCodec.swift` (25 lines)
- `RetryPolicyBridge.swift` (102 lines)
- `HiveCoreReexports.swift` (3 lines)

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 2 |
| High | 7 |
| Medium | 8 |
| Low | 4 |
| **Total** | **21** |

---

## Issue #1 — MessagesReducer filter silently drops messages

**File:** `HiveAgents.swift:351-354`  
**Severity:** Critical  
**Category:** Bug

```swift
return merged.filter { message in
    if case .none = message.op { return true }
    return false
}
```

The final filter keeps ONLY messages where `op == nil`. Any message that retains a non-nil `op` after processing is silently discarded. If `op` is a transient directive, it should be cleared during reduction — not used as a post-hoc discard gate.

**Risk:** Messages lost silently if any code path leaves a stale `.remove` or `.removeAll` op on a message that should be preserved.

**Fix:**
```swift
// Option A: Remove the filter (deletion is already handled above)
return merged

// Option B: Strip op from retained messages
return merged.map { var m = $0; m.op = nil; return m }
```

---

## Issue #2 — `secondsToNanoseconds` traps on negative TimeInterval

**File:** `RetryPolicyBridge.swift:98-100`  
**Severity:** Critical  
**Category:** Bug

```swift
private static func secondsToNanoseconds(_ seconds: TimeInterval) -> UInt64 {
    UInt64(seconds * 1_000_000_000)
}
```

Converting a negative `TimeInterval` (possible from a malformed policy) to `UInt64` traps at runtime. No guard exists.

**Fix:**
```swift
private static func secondsToNanoseconds(_ seconds: TimeInterval) -> UInt64 {
    guard seconds > 0 else { return 0 }
    return UInt64(clamping: Int64(seconds * 1_000_000_000))
}
```

---

## Issue #3 — `.rawValue == "string"` instead of enum cases

**File:** `HiveAgents.swift:734`, `HiveBackedAgent.swift:352,381`  
**Severity:** High  
**Category:** TypeSafety

```swift
// HiveAgents.swift:734
first.role.rawValue == "system"

// HiveBackedAgent.swift:352
message.role.rawValue == "tool"

// HiveBackedAgent.swift:381
$0.role.rawValue == "assistant"
```

3 occurrences of string-based role comparisons. Typo-prone, invisible to refactoring tools, no compiler help.

**Fix:**
```swift
// If role is an enum:
first.role == .system
message.role == .tool
$0.role == .assistant

// If role is a RawRepresentable struct, add typed constants:
extension HiveChatMessageRole {
    static let system = Self(rawValue: "system")
    static let tool = Self(rawValue: "tool")
    static let assistant = Self(rawValue: "assistant")
}
```

---

## Issue #4 — Duplicate JSON→SendableValue conversion

**File:** `HiveBackedAgent.swift:396-436` vs `SwarmToolRegistry.swift:71-86`  
**Severity:** High  
**Category:** Duplication

Two independent implementations of `[String: Any] → [String: SendableValue]`:

1. **HiveBackedAgent:** `parseToolArguments()` + `convertToSendableValue()` — 29 lines, manual `NSNumber`/`CFBoolean` dispatch
2. **SwarmToolRegistry:** `parseArgumentsJSON()` — delegates to `SendableValue.fromJSONValue()`

The implementations may diverge on edge cases (boolean detection, number precision).

**Fix:** Replace the `HiveBackedAgent` version with the existing `SendableValue.fromJSONValue`:
```swift
private func parseToolArguments(_ jsonString: String) -> [String: SendableValue] {
    guard let data = jsonString.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return ["raw": .string(jsonString)] }

    var result: [String: SendableValue] = [:]
    for (key, value) in json {
        result[key] = SendableValue.fromJSONValue(value)
    }
    return result
}
// Delete convertToSendableValue() entirely (~25 lines removed)
```

---

## Issue #5 — Repeated deterministic sort closures

**File:** `HiveAgents.swift:435,514,603,744-753`, `SwarmToolRegistry.swift:30,37,126,172`  
**Severity:** High  
**Category:** Duplication

The `utf8.lexicographicallyPrecedes` pattern appears **7 times** across 2 files.

**Fix:** Extract a shared utility:
```swift
enum HiveDeterministicSort {
    static func byName<T>(_ lhs: T, _ rhs: T) -> Bool where T: /* has .name */ {
        lhs.name.utf8.lexicographicallyPrecedes(rhs.name.utf8)
    }

    static func strings(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
}
```

---

## Issue #6 — Error silently swallowed in graph router

**File:** `HiveAgents.swift:44-51`  
**Severity:** High  
**Category:** Bug

```swift
let router: HiveRouter<Schema> = { store in
    do {
        let pending = try store.get(Schema.pendingToolCallsKey)
        return pending.isEmpty ? .end : .nodes([nodeIDs.tools])
    } catch {
        return .end  // ← Silently swallows error, terminates graph
    }
}
```

If `store.get()` throws (corrupted checkpoint, codec failure), the graph silently ends. No log, no error propagation. The caller sees a successful run with no output.

**Fix:**
```swift
} catch {
    Log.agents.error("Router failed to read pendingToolCallsKey: \(error)")
    return .end
}
```
Or propagate the error if the `HiveRouter` signature allows throwing.

---

## Issue #7 — `SwarmToolRegistry.init` silently deduplicates tools

**File:** `SwarmToolRegistry.swift:24-27`  
**Severity:** High  
**Category:** Bug

```swift
var byName: [String: any AnyJSONTool] = [:]
for tool in tools {
    byName[tool.name] = tool  // ← silent overwrite on duplicate name
}
```

If two tools share the same name, the second silently replaces the first. The caller is never told a tool was dropped.

**Fix:**
```swift
for tool in tools {
    guard byName[tool.name] == nil else {
        throw SwarmToolRegistryError.duplicateToolName(tool.name)
    }
    byName[tool.name] = tool
}
```
Requires adding `case duplicateToolName(String)` to `SwarmToolRegistryError`.

---

## Issue #8 — `rejectedOutput` / `cancelledOutput` near-duplicates

**File:** `HiveAgents.swift:547-598`  
**Severity:** High  
**Category:** Duplication

Both methods (~50 lines total) create a system message, clear pending tool calls, and route back to the model node. The only differences: message text and whether per-call tool messages are appended.

**Fix:**
```swift
private static func makeApprovalOutput(
    taskID: HiveTaskID,
    calls: [HiveToolCall],
    systemMessage: String,
    includeToolMessages: Bool
) -> HiveNodeOutput<Schema> {
    let sysMsg = HiveChatMessage(
        id: MessageID.system(taskID: taskID),
        role: .system, content: systemMessage,
        toolCalls: [], op: nil
    )
    var messages: [HiveChatMessage] = [sysMsg]
    if includeToolMessages {
        messages += calls.map { call in
            HiveChatMessage(
                id: "tool:" + call.id + ":cancelled",
                role: .tool,
                content: "Tool call cancelled by user.",
                toolCallID: call.id, toolCalls: [], op: nil
            )
        }
    }
    return HiveNodeOutput(
        writes: [
            AnyHiveWrite(Schema.pendingToolCallsKey, []),
            AnyHiveWrite(Schema.messagesKey, messages)
        ],
        next: .nodes([NodeID.model])
    )
}
```

---

## Issue #9 — `toJSONObject()` is `fileprivate`, duplicates inverse of `fromJSONValue`

**File:** `SwarmToolRegistry.swift:203-226`  
**Severity:** Medium  
**Category:** Duplication

`SendableValue.toJSONObject()` is `fileprivate` to `SwarmToolRegistry.swift`. `HiveBackedAgent.convertToSendableValue()` is essentially its inverse. Both should be shared `SendableValue` extensions visible to the module.

**Fix:** Promote `toJSONObject()` to `internal` or `public` on `SendableValue`. Delete `convertToSendableValue()` (Issue #4).

---

## Issue #10 — `[String: Any]` throughout JSON Schema building

**File:** `SwarmToolRegistry.swift:110-200`  
**Severity:** Medium  
**Category:** TypeSafety

The entire `makeParametersSchema` + `jsonSchema` section uses untyped `[String: Any]` dictionaries. Any key typo (e.g., `"properteis"`) compiles silently.

**Fix:** Define a `JSONSchemaNode` enum or struct:
```swift
enum JSONSchemaNode {
    case string
    case integer
    case number
    case boolean
    case array(items: JSONSchemaNode)
    case object(properties: [String: JSONSchemaProperty], required: [String])
    case oneOf([String])
    case anyOf([JSONSchemaNode])

    func toDict() -> [String: Any] { /* ... */ }
}
```

---

## Issue #11 — `makeToolUsingChatAgent` opaque parameter types

**File:** `HiveAgents.swift:28-62`  
**Severity:** Medium  
**Category:** API

```swift
public static func makeToolUsingChatAgent(
    preModel: HiveNode<Schema>? = nil,
    postModel: HiveNode<Schema>? = nil
) throws -> CompiledHiveGraph<Schema>
```

`HiveNode<Schema>` is a closure type with no compile-time hint about what inputs it receives or outputs it should produce. Callers must read the implementation to understand the contract.

**Fix:** Consider a builder pattern or typed configuration struct with documented expectations.

---

## Issue #12 — `toolExecuteNode` re-checks approval decisions

**File:** `HiveAgents.swift:605-617`  
**Severity:** Medium  
**Category:** Bug-risk

`toolExecuteNode` re-handles `.rejected` and `.cancelled` decisions that `toolsNode` should have already intercepted (returning early or interrupting). This creates confusing double-dispatch if graph edges change.

**Fix:** Remove the redundant check, or add a comment documenting it as intentional defense-in-depth.

---

## Issue #13 — Redundant compaction policy validation

**File:** `HiveAgents.swift:401-411` (duplicates `HiveAgents.swift:178-184`)  
**Severity:** Medium  
**Category:** Duplication

`builtInPreModel` re-validates compaction policy bounds and tokenizer presence. `preflight()` already performs identical checks before any run starts.

**Fix:** Remove redundant guards in `builtInPreModel`, or document as defense-in-depth.

---

## Issue #14 — `NSNumber` boolean detection is platform-fragile

**File:** `HiveBackedAgent.swift:416`  
**Severity:** Medium  
**Category:** Bug

```swift
if CFBooleanGetTypeID() == CFGetTypeID(number) {
```

`CFBoolean` bridging behavior differs on Linux where CoreFoundation support is incomplete. This may misclassify booleans as integers on non-Apple platforms.

**Fix:** Eliminate this code entirely by using `SendableValue.fromJSONValue()` (see Issue #4).

---

## Issue #15 — No input validation on `HiveCompactionPolicy.init`

**File:** `HiveAgents.swift:73-76`  
**Severity:** Medium  
**Category:** API

```swift
public init(maxTokens: Int, preserveLastMessages: Int) {
    self.maxTokens = maxTokens
    self.preserveLastMessages = preserveLastMessages
}
```

Invalid values (negative `maxTokens`, negative `preserveLastMessages`) are accepted at construction, only caught at runtime in `preflight()`.

**Fix:**
```swift
public init(maxTokens: Int, preserveLastMessages: Int) {
    precondition(maxTokens >= 1, "maxTokens must be >= 1")
    precondition(preserveLastMessages >= 0, "preserveLastMessages must be >= 0")
    self.maxTokens = maxTokens
    self.preserveLastMessages = preserveLastMessages
}
```

---

## Issue #16 — Tools executed sequentially, not concurrently

**File:** `HiveAgents.swift:630-655`  
**Severity:** Medium  
**Category:** Performance

```swift
for call in calls {
    let result = try await ... registry.invoke(call)
    ...
}
```

Independent tool calls are executed one at a time. For agents with multiple parallel tool calls (e.g., search + calculate), this adds unnecessary latency.

**Fix:** Use `withThrowingTaskGroup` for parallel execution, with an opt-in flag if deterministic ordering is required.

---

## Issue #17 — `HiveBackedAgent.stream()` double-finishes continuation

**File:** `HiveBackedAgent.swift:184-188, 218`  
**Severity:** Low  
**Category:** Bug-risk

```swift
// eventsTask defer:
defer {
    if !continuation.isFinished {
        continuation.finish()
    }
}
// ... outer code:
continuation.finish()  // line 218
```

Two code paths can call `continuation.finish()`. The `isFinished` guard prevents a crash but the ownership is ambiguous.

**Fix:** Let only one code path own the finish call. Remove the defer in `eventsTask` since the outer scope always finishes.

---

## Issue #18 — Unused variable read

**File:** `HiveAgents.swift:399`  
**Severity:** Low  
**Category:** Bug

```swift
_ = try input.store.get(Schema.llmInputMessagesKey)
```

Reads `llmInputMessagesKey` and discards the result. Either an intentional "assert channel exists" side-effect, or dead code.

**Fix:** Add a comment explaining intent, or remove the line.

---

## Issue #19 — `linear` backoff silently ignores step parameter

**File:** `RetryPolicyBridge.swift:69`  
**Severity:** Low  
**Category:** API

```swift
case .linear(let initial, _, let maxDelay):
    // Approximate linear growth with 1.5x factor.
```

The `step` parameter is discarded. The `1.5x` factor is arbitrary and may not match caller intent.

**Fix:** Compute a better approximation from `step` and `maxDelay`, or log a warning about the lossy mapping.

---

## Issue #20 — `custom` backoff fallback is arbitrary and silent

**File:** `RetryPolicyBridge.swift:86-94`  
**Severity:** Low  
**Category:** API

```swift
case .custom:
    return .exponentialBackoff(
        initialNanoseconds: 1_000_000_000,
        factor: 2.0,
        maxAttempts: policy.maxAttempts,
        maxNanoseconds: 60_000_000_000
    )
```

Custom policies map to hardcoded defaults with no warning.

**Fix:** Add `Log.agents.warning("Custom retry policy cannot be represented in Hive; using default exponential backoff.")`.

---

## Issue #21 — `String(reflecting:)` in codec ID is fragile

**File:** `HiveCodableJSONCodec.swift:11`  
**Severity:** Low  
**Category:** Fragile

```swift
self.id = id ?? "HiveSwarm.HiveCodableJSONCodec<\(String(reflecting: Value.self))>"
```

`String(reflecting:)` output is not guaranteed stable across Swift versions. If this ID is used for checkpoint matching, a Swift toolchain update could silently invalidate existing checkpoints.

**Fix:** Use `String(describing:)` or a manually-defined, version-stable identifier.

---

## Code Duplication Map

| Pattern | Locations | Total Lines |
|---------|-----------|-------------|
| JSON→SendableValue conversion | `HiveBackedAgent.swift:396-436`, `SwarmToolRegistry.swift:71-86` | ~45 |
| `utf8.lexicographicallyPrecedes` sort | `HiveAgents.swift:435,514,603,744-753`, `SwarmToolRegistry.swift:30,37,126,172` | 7 occurrences |
| `rejectedOutput` / `cancelledOutput` | `HiveAgents.swift:547-566`, `HiveAgents.swift:568-598` | ~50 |
| `.rawValue == "string"` role checks | `HiveAgents.swift:734`, `HiveBackedAgent.swift:352,381` | 3 occurrences |
| Compaction policy validation | `HiveAgents.swift:178-184`, `HiveAgents.swift:405-411` | ~12 |
| Required parameter sort | `SwarmToolRegistry.swift:126`, `SwarmToolRegistry.swift:172` | 2 occurrences |

---

## Refactoring Recommendations

### Low Effort (< 30 min each)

| # | Action | Files Touched | Lines Changed |
|---|--------|---------------|---------------|
| 1 | Replace `.rawValue == "string"` with enum cases | 2 | ~6 |
| 2 | Delete `convertToSendableValue`, use `SendableValue.fromJSONValue` | 1 | -25 |
| 3 | Clamp `secondsToNanoseconds` for negative inputs | 1 | ~3 |
| 4 | Add `precondition` to `HiveCompactionPolicy.init` | 1 | +2 |
| 5 | Detect duplicate tool names in `SwarmToolRegistry.init` | 1 | +4 |
| 6 | Log error in router catch block | 1 | +1 |
| 7 | Log warning for lossy `RetryPolicyBridge` conversions | 1 | +3 |

### Medium Effort (1-3 hours each)

| # | Action | Files Touched | Complexity |
|---|--------|---------------|------------|
| 8 | Extract `HiveDeterministicSort` utility | 3 (new + 2 existing) | 7 call sites |
| 9 | Merge `rejectedOutput`/`cancelledOutput` into shared helper | 1 | ~30 lines refactored |
| 10 | Remove redundant compaction validation in `builtInPreModel` | 1 | Requires verifying preflight always runs first |
| 11 | Type-safe `JSONSchemaNode` for schema building | 1 (new + 1 existing) | ~60 new lines, replaces ~90 |
| 12 | Promote `toJSONObject()` from `fileprivate` to module-level | 1 | Visibility change |

### High Effort (4+ hours each)

| # | Action | Files Touched | Risk |
|---|--------|---------------|------|
| 13 | Parallel tool execution with `TaskGroup` | 1 | Requires determinism analysis; opt-in flag needed |
| 14 | Redesign `makeToolUsingChatAgent` API with builder pattern | 1+ | Public API surface change; breaking for consumers |
