# Plan: Syntactic Sugar Improvements for Coding Agents

## Goals
- Fix `@AgentActor` macro to correctly conform to `AgentRuntime`, including `AnyJSONTool` and `run/stream(session:hooks:)` requirements.
- Improve builder ergonomics with typed tool bridging and sane defaults that reduce boilerplate while preserving type safety.
- Update docs and tests to reflect new macro and builder behaviors.

## Non-Goals
- Redesign of `AgentRuntime` protocol surface beyond requirements for conformance.
- Behavioral changes to tool execution semantics or streaming model.
- Broad API renames unrelated to macro/builder ergonomics.

## Constraints
- Swift 6.2, strict concurrency; public types must be `Sendable`.
- Preserve existing public APIs where possible; changes must be source-compatible unless explicitly documented.
- Use Swift Testing (`import Testing`) for all new tests.

## API Decisions
- `@AgentActor`-generated type must:
  - Conform to `AgentRuntime`.
  - Expose `AnyJSONTool` collection consistent with the runtime.
  - Implement `run(session:hooks:)` and `stream(session:hooks:)` with correct signatures.
- Builder ergonomics:
  - Provide typed tool bridging API that converts typed tools to `AnyJSONTool` without `Any` or unsafe casting.
  - Defaults: sensible session and hook defaults, so builders can be used with minimal configuration.
  - Prefer explicit overloads for clarity over ad-hoc inference magic.

## Migration Notes
- If `@AgentActor` previously compiled without `AgentRuntime` conformance, adopting the new macro may expose missing method implementations; migration will be by macro generation (no user code changes expected unless overrides conflict).
- Builder API additions should be additive; deprecate any legacy untyped tool registration only if needed for correctness.

## Work Packages (Immutable)

### WP-1: Macro Conformance Audit
**Goal:** Identify current macro-generated conformance gaps.

**Tasks:**
- Inspect `@AgentActor` expansion and generated members.
- Locate `AgentRuntime` protocol requirements and `AnyJSONTool` expectations.
- Enumerate missing or mismatched signatures.

**Expected Output:**
`docs/work-packages/WP-1-macro-audit.md` with findings and target signatures.

---

### WP-2: Tests for `@AgentActor` Conformance
**Goal:** Failing tests that define expected macro output behavior.

**Tasks:**
- Add Swift Testing suite verifying `@AgentActor` types conform to `AgentRuntime`.
- Assert presence of `run(session:hooks:)` and `stream(session:hooks:)`.
- Verify tools surface as `AnyJSONTool`.

**Expected Output:**
`Tests/SwiftAgentsMacrosTests/AgentActorConformanceTests.swift`.

---

### WP-3: Macro Fix Implementation
**Goal:** Implement macro updates to satisfy `AgentRuntime`.

**Tasks:**
- Update macro generation to emit required methods and tool property.
- Ensure generated methods delegate to actor implementation safely.
- Add doc comments for public API if generated.

**Expected Output:**
Edits under `Sources/SwiftAgentsMacros/`.

---

### WP-4: Builder Ergonomics Tests
**Goal:** Failing tests that define typed tool bridging and defaults.

**Tasks:**
- Add tests for typed tool → `AnyJSONTool` bridging.
- Add tests for default session/hooks behavior in builder.
- Ensure tests are deterministic and isolated.

**Expected Output:**
`Tests/SwiftAgentsTests/BuilderErgonomicsTests.swift`.

---

### WP-5: Builder Ergonomics Implementation
**Goal:** Implement typed tool bridging and defaults.

**Tasks:**
- Add typed tool bridging APIs (struct/protocol extensions).
- Implement default session/hooks in builder entry points.
- Ensure no type erasure or unsafe casting.

**Expected Output:**
Edits under `Sources/SwiftAgents/`.

---

### WP-6: Documentation Updates
**Goal:** Update docs to reflect new ergonomics and macro behavior.

**Tasks:**
- Update usage guide(s) with examples for `@AgentActor` and builder defaults.
- Add migration notes and compatibility guidance.
- Ensure examples compile with Swift 6.2.

**Expected Output:**
Edits under `docs/`.

---

### WP-7: Review & Gap Fix
**Goal:** Validate plan compliance and correct gaps.

**Tasks:**
- Run macro-focused review for conformance and API misuse risk.
- Run builder-focused review for type-safety and defaults.
- Fix any discovered gaps and update tests/docs if needed.

**Expected Output:**
Review notes + incremental fixes.

---

## Task → Agent Mapping
- Context/Research Agent: WP-1
- Planning Agent: not needed (this doc is authoritative)
- Test Agent: WP-2, WP-4
- Implementation Agent: WP-3, WP-5
- Docs Agent: WP-6
- Review Agent(s): WP-7

---

## Milestones
1. Tests failing for macro conformance and builder ergonomics.
2. Macro and builder implementations updated to pass tests.
3. Docs updated with new usage and migration notes.

---

- Plan is immutable; work proceeds via the listed work packages only.

