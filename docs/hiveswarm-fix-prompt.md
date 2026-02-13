# HiveSwarm Code Quality Fix — Implementation Prompt

You are a senior Swift 6.2 engineer. Your task is to fix **all 21 issues** from the HiveSwarm code quality audit. Work on branch `issue13`.

## Audit Reference

The full audit is at `docs/hiveswarm-code-quality-audit.md`. Read it completely before starting.

## Repository Context

- **Swift 6.2** with strict concurrency enabled. All public types must be `Sendable`.
- **Build:** `swift build`
- **Test:** `swift test --filter HiveSwarmTests`
- **Format:** `swift package plugin --allow-writing-to-package-directory swiftformat`
- **Lint:** `swiftlint lint`
- HiveCore is an external dependency (do NOT modify it). HiveSwarm bridges HiveCore ↔ Swarm.
- `HiveChatMessage.role` is defined in HiveCore — inspect its type before changing `.rawValue` comparisons. If it's an enum, use cases directly. If it's a `RawRepresentable` struct, add typed static constants in an extension inside HiveSwarm.

## Target Files

```
Sources/HiveSwarm/
├── HiveAgents.swift          (773 lines)
├── HiveBackedAgent.swift     (481 lines)
├── SwarmToolRegistry.swift   (227 lines)
├── HiveCodableJSONCodec.swift (25 lines)
├── RetryPolicyBridge.swift   (102 lines)
└── HiveCoreReexports.swift   (3 lines — do not modify)
```

Existing tests:
```
Tests/HiveSwarmTests/
├── HiveAgentsTests.swift                (602 lines)
├── HiveBackedAgentStreamingTests.swift  (300 lines)
├── ModelRouterTests.swift               (302 lines)
└── RetryPolicyBridgeTests.swift         (241 lines)
```

## Execution Plan

Work in **4 phases**, committing after each. Run `swift build` after every file change. Run `swift test --filter HiveSwarmTests` after each phase.

---

### Phase 1: Critical Bugs (Issues #1, #2)

**Issue #1 — MessagesReducer filter drops messages silently**
- File: `HiveAgents.swift:351-354`
- The `.filter { if case .none = message.op ... }` at the end of `MessagesReducer.reduce` silently discards messages with non-nil `op`. The deletion logic above already removes messages marked `.remove`. Replace the filter with stripping `op` from all remaining messages:
```swift
return merged.map { message in
    var cleaned = message
    cleaned.op = nil
    return cleaned
}
```
- **Important:** First check if `HiveChatMessage.op` has a public setter. If it's `let`, you'll need to reconstruct the message. If `op` is not publicly settable, keep the existing filter but add a `Log.agents.warning` when a non-nil, non-.none op is encountered in the filter to make the silent drop visible.
- Add a test in `HiveAgentsTests.swift` that verifies messages with transient ops are preserved after reduction.

**Issue #2 — `secondsToNanoseconds` traps on negative input**
- File: `RetryPolicyBridge.swift:98-100`
- Replace with:
```swift
private static func secondsToNanoseconds(_ seconds: TimeInterval) -> UInt64 {
    guard seconds > 0 else { return 0 }
    return UInt64(clamping: Int64(seconds * 1_000_000_000))
}
```
- Add a test in `RetryPolicyBridgeTests.swift` that passes a policy with negative delay and verifies no crash (returns `.exponentialBackoff` with 0 nanoseconds).

**Commit message:** `Fix critical bugs: MessagesReducer silent drop and secondsToNanoseconds trap`

---

### Phase 2: Type Safety & Silent Failures (Issues #3, #6, #7, #14, #15)

**Issue #3 — `.rawValue == "string"` comparisons**
- Files: `HiveAgents.swift:734`, `HiveBackedAgent.swift:352,381`
- First, inspect the type of `HiveChatMessage.role` from HiveCore. Run: check the definition with LSP or grep HiveCore sources.
  - If it's an `enum` with `.system`, `.tool`, `.assistant` cases → replace all 3 `.rawValue ==` with direct case comparison.
  - If it's a `RawRepresentable` struct → add a private extension in a new section of `HiveAgents.swift`:
    ```swift
    extension HiveChatMessageRole {
        static let system = Self(rawValue: "system")
        static let tool = Self(rawValue: "tool")
        static let assistant = Self(rawValue: "assistant")
    }
    ```
    Then replace all 3 `.rawValue ==` usages.

**Issue #6 — Swallowed error in router**
- File: `HiveAgents.swift:44-51`
- Add logging before `return .end`:
```swift
} catch {
    Log.agents.error("Router failed to read pendingToolCallsKey, ending graph: \(error)")
    return .end
}
```

**Issue #7 — Silent tool deduplication**
- File: `SwarmToolRegistry.swift:24-27`
- Add `case duplicateToolName(String)` to `SwarmToolRegistryError` enum.
- Replace the loop with:
```swift
for tool in tools {
    guard byName[tool.name] == nil else {
        throw SwarmToolRegistryError.duplicateToolName(tool.name)
    }
    byName[tool.name] = tool
}
```

**Issue #14 — `NSNumber` boolean detection fragile on Linux**
- This is resolved by Issue #4 in Phase 3, but if Phase 3 is deferred, add a `#if canImport(CoreFoundation)` guard and a fallback path for Linux now.

**Issue #15 — No validation in `HiveCompactionPolicy.init`**
- File: `HiveAgents.swift:73-76`
- Add preconditions:
```swift
public init(maxTokens: Int, preserveLastMessages: Int) {
    precondition(maxTokens >= 1, "maxTokens must be >= 1")
    precondition(preserveLastMessages >= 0, "preserveLastMessages must be >= 0")
    self.maxTokens = maxTokens
    self.preserveLastMessages = preserveLastMessages
}
```

**Commit message:** `Improve type safety: enum roles, input validation, error logging, duplicate detection`

---

### Phase 3: Deduplication (Issues #4, #5, #8, #9, #12, #13)

**Issue #4 — Duplicate JSON→SendableValue conversion**
- File: `HiveBackedAgent.swift:396-436`
- Replace `parseToolArguments` with a version that uses `SendableValue.fromJSONValue()` (already used by `SwarmToolRegistry`). Delete `convertToSendableValue()` entirely (~25 lines removed).
- This also fixes Issue #14 (NSNumber/CFBoolean fragility) since `fromJSONValue` handles it correctly.

**Issue #5 — Repeated sort closures (7 occurrences)**
- Create a new internal utility enum. Do NOT create a new file — add it at the bottom of `HiveAgents.swift` (before the `UUID`/`UInt32` extensions):
```swift
enum HiveDeterministicSort {
    static func byUTF8Name<T: HiveNamed>(_ lhs: T, _ rhs: T) -> Bool {
        lhs.name.utf8.lexicographicallyPrecedes(rhs.name.utf8)
    }
    static func strings(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
}
```
- If `HiveToolDefinition`, `HiveToolCall` don't share a `HiveNamed` protocol, use two overloads or a generic with a `name` key path:
```swift
static func byName<T>(_ lhs: T, _ rhs: T, keyPath: KeyPath<T, String>) -> Bool {
    lhs[keyPath: keyPath].utf8.lexicographicallyPrecedes(rhs[keyPath: keyPath].utf8)
}
```
- Replace all 7 call sites across `HiveAgents.swift` and `SwarmToolRegistry.swift`.

**Issue #8 — `rejectedOutput`/`cancelledOutput` duplication**
- File: `HiveAgents.swift:547-598`
- Extract a shared helper:
```swift
private static func makeApprovalOutput(
    taskID: HiveTaskID,
    calls: [HiveToolCall],
    systemMessage: String,
    includeToolMessages: Bool
) -> HiveNodeOutput<Schema>
```
- Replace both `rejectedOutput` and `cancelledOutput` with calls to this helper.

**Issue #9 — `toJSONObject()` is fileprivate**
- File: `SwarmToolRegistry.swift:204`
- Change `fileprivate` to `internal` (or `package` if using Swift 5.9+ access level).

**Issue #12 — Redundant approval re-check in `toolExecuteNode`**
- File: `HiveAgents.swift:605-617`
- Add a doc comment explaining this is intentional defense-in-depth:
```swift
// Defense-in-depth: toolsNode handles approval flow, but if graph edges
// are reconfigured, this ensures rejected/cancelled decisions are honored.
```

**Issue #13 — Redundant compaction validation**
- File: `HiveAgents.swift:401-411`
- Add a doc comment:
```swift
// Defense-in-depth: preflight() validates these, but builtInPreModel
// guards independently in case it's used outside the standard run path.
```

**Commit message:** `Deduplicate JSON conversion, sort utilities, and approval output helpers`

---

### Phase 4: Logging, API, and Polish (Issues #10, #11, #16, #17, #18, #19, #20, #21)

**Issue #10 — `[String: Any]` in schema building**
- File: `SwarmToolRegistry.swift:110-200`
- This is a medium-effort refactor. Create a `JSONSchemaFragment` enum inside `SwarmToolRegistry.swift` (keep it private to the file):
```swift
private enum JSONSchemaFragment {
    case string
    case integer
    case number
    case boolean
    case array(items: JSONSchemaFragment)
    case object(properties: [(name: String, schema: JSONSchemaFragment, description: String, defaultValue: SendableValue?, isRequired: Bool)])
    case oneOf([String])
    case anyType

    func toDictionary() -> [String: Any] { /* ... */ }
}
```
- Rewrite `jsonSchema(for:)` to return `JSONSchemaFragment` instead of `[String: Any]`.
- Rewrite `makeParametersSchema` to build `JSONSchemaFragment.object(...)` then call `.toDictionary()` at the boundary.

**Issue #11 — Opaque `makeToolUsingChatAgent` API**
- File: `HiveAgents.swift:28-62`
- Add comprehensive doc comments to the method explaining what `preModel` and `postModel` receive and what they should produce. Do NOT change the method signature (that's a breaking API change reserved for a future version).

**Issue #16 — Sequential tool execution**
- File: `HiveAgents.swift:630-655`
- Replace the sequential `for call in calls` with `withThrowingTaskGroup`:
```swift
let toolMessages: [HiveChatMessage] = try await withThrowingTaskGroup(
    of: (Int, HiveChatMessage).self
) { group in
    for (index, call) in calls.enumerated() {
        group.addTask {
            let metadata = ["toolCallID": call.id]
            input.emitStream(.toolInvocationStarted(name: call.name), metadata)
            do {
                let result = try await withRetry(
                    policy: input.context.retryPolicy,
                    clock: input.environment.clock
                ) {
                    try await registry.invoke(call)
                }
                input.emitStream(.toolInvocationFinished(name: call.name, success: true), metadata)
                return (index, HiveChatMessage(
                    id: "tool:" + call.id,
                    role: .tool,
                    content: result.content,
                    toolCallID: call.id,
                    toolCalls: [],
                    op: nil
                ))
            } catch {
                input.emitStream(.toolInvocationFinished(name: call.name, success: false), metadata)
                throw error
            }
        }
    }
    var results: [(Int, HiveChatMessage)] = []
    for try await result in group {
        results.append(result)
    }
    return results.sorted { $0.0 < $1.0 }.map(\.1)
}
```
- **Important:** The results must be sorted by original index to maintain deterministic message ordering. The `(Int, HiveChatMessage)` tuple preserves insertion order.
- Verify `input.emitStream` is safe to call from concurrent contexts (it should be, given `HiveNodeInput` is Sendable).

**Issue #17 — Double-finish continuation**
- File: `HiveBackedAgent.swift:184-188`
- Remove the `defer` block from `eventsTask`. The outer scope at line 218 owns the continuation lifecycle.

**Issue #18 — Unused variable read**
- File: `HiveAgents.swift:399`
- Add a comment:
```swift
// Ensure llmInputMessages channel is initialized before reading messages.
_ = try input.store.get(Schema.llmInputMessagesKey)
```
- If after investigation the read has no side-effect, remove it.

**Issue #19 — Linear backoff ignores step**
- File: `RetryPolicyBridge.swift:69`
- Add a log warning:
```swift
case .linear(let initial, let step, let maxDelay):
    Log.agents.info("RetryPolicyBridge: linear backoff (step=\(step)) approximated as 1.5x exponential for Hive determinism.")
    return .exponentialBackoff(...)
```

**Issue #20 — Custom backoff silent fallback**
- File: `RetryPolicyBridge.swift:86-94`
- Add:
```swift
case .custom:
    Log.agents.warning("Custom retry policy cannot be represented in Hive's deterministic model; using default exponential backoff (1s base, 2x factor, 60s max).")
    return .exponentialBackoff(...)
```

**Issue #21 — `String(reflecting:)` fragility**
- File: `HiveCodableJSONCodec.swift:11`
- Replace `String(reflecting:)` with `String(describing:)`:
```swift
self.id = id ?? "HiveSwarm.HiveCodableJSONCodec<\(String(describing: Value.self))>"
```

**Commit message:** `Polish: type-safe schemas, parallel tools, logging, and API docs`

---

## Constraints

1. **Do NOT modify HiveCore.** It is an external dependency.
2. **Do NOT modify `HiveCoreReexports.swift`.**
3. **Do NOT break any existing tests.** Run `swift test --filter HiveSwarmTests` after each phase.
4. **Do NOT change public API signatures** unless the audit explicitly calls for it (only Issue #7 adds a new error case and Issue #15 adds preconditions — both are additive).
5. **Do NOT suppress type errors** with `as any`, `as! Any`, `@_silgen_name`, etc.
6. **Preserve deterministic behavior.** The Hive runtime requires deterministic execution. All sort orders, message IDs, and retry timing must remain reproducible.
7. **Match existing code style.** Use the patterns already in the codebase (e.g., `Log.agents.*` for logging, `HiveRuntimeError` for errors).
8. **Add tests for behavioral changes.** Issues #1, #2, #7, and #16 change behavior and must have corresponding test coverage.
9. **Run `swift build` after every file modification** to catch compilation errors immediately.
10. **Commit after each phase** with the specified commit message.

## Verification Checklist

After all 4 phases:

- [ ] `swift build` succeeds with zero warnings in HiveSwarm module
- [ ] `swift test --filter HiveSwarmTests` — all tests pass
- [ ] No force unwraps (`!`) introduced
- [ ] No `as any` / `@ts-ignore` equivalents introduced
- [ ] No `.rawValue == "string"` comparisons remain in HiveSwarm sources
- [ ] `convertToSendableValue()` method deleted from HiveBackedAgent
- [ ] `rejectedOutput()` and `cancelledOutput()` replaced with single `makeApprovalOutput()`
- [ ] All 7 sort closures use shared `HiveDeterministicSort`
- [ ] `SwarmToolRegistryError.duplicateToolName` case exists
- [ ] `HiveCompactionPolicy.init` has preconditions
- [ ] `RetryPolicyBridge.secondsToNanoseconds` handles negative input
- [ ] Tool execution in `toolExecuteNode` uses `TaskGroup` for parallelism
- [ ] `HiveCodableJSONCodec.id` uses `String(describing:)` not `String(reflecting:)`
- [ ] 4 commits on branch `issue13`, one per phase
