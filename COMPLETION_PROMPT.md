# HiveSwarm Code Quality Fix — Completion Prompt

You are a senior Swift 6.2 engineer. Complete the remaining gaps from the code quality audit on branch `issue13`.

## Current State

Branch `issue13` has 4 commits fixing most issues, but gaps remain:
- No tests added for behavioral changes (Issues #1, #2, #7, #16)
- Issue #10 (JSONSchemaFragment) not implemented
- Build/tests never verified

## Remaining Work

### 1. Add Missing Tests

Add tests to `Tests/HiveSwarmTests/` for behavioral changes:

**Issue #1 - MessagesReducer test:**
- File: `HiveAgentsTests.swift`
- Add test: Messages with transient ops are preserved after reduction (not dropped)
- The fix changed from filtering out messages with non-nil `op` to stripping `op` from all messages

**Issue #2 - secondsToNanoseconds test:**
- File: `RetryPolicyBridgeTests.swift`  
- Add test: Policy with negative delay should not crash (return 0 nanoseconds)
- Test: `RetryPolicyBridge.toHive(RetryPolicy(backoff: .exponential(delay: -1.0, ...)))`

**Issue #7 - Duplicate tool detection test:**
- File: `HiveAgentsTests.swift` or new test file
- Add test: `SwarmToolRegistry.init` throws `duplicateToolName` when given tools with same name

**Issue #16 - Parallel tool execution test:**
- This is harder to test - verify tool messages are returned in deterministic order
- Check that concurrent execution produces same results as sequential

### 2. Issue #10 (Optional/Deferred)

If time permits, implement type-safe JSON schema building:
- Create `JSONSchemaFragment` enum in `SwarmToolRegistry.swift`
- Replace `[String: Any]` dictionaries with typed schema nodes
- This is medium-effort, ~60 new lines

### 3. Verify Build & Tests

Run these commands:
```bash
swift build --target HiveSwarm  # Should succeed
swift test --filter HiveSwarmTests  # Should pass
```

## Files to Modify

```
Tests/HiveSwarmTests/
├── HiveAgentsTests.swift          (add Issue #1, #7 tests)
└── RetryPolicyBridgeTests.swift   (add Issue #2 test)
```

## Constraints

- Do NOT modify HiveCore (external dependency)
- Do NOT change public API signatures
- Do NOT add force unwraps (`!`) or type suppressions
- Match existing test style (Swift Testing with `#expect`)
- Commit after completing tests with descriptive message

## Success Criteria

- [ ] Test for Issue #1 (MessagesReducer op stripping)
- [ ] Test for Issue #2 (negative delay handling)
- [ ] Test for Issue #7 (duplicate tool detection)
- [ ] Issue #10 implemented OR explicitly deferred with rationale
- [ ] `swift build --target HiveSwarm` succeeds
- [ ] `swift test --filter HiveSwarmTests` passes
