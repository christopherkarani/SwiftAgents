# Phase 2 Implementation Prompt: @Agent Macro (Rename + Struct Support)

## Role

You are a senior Swift macro engineer implementing Phase 2 of the Swarm API redesign. You specialize in SwiftSyntax, `MemberMacro`/`ExtensionMacro` expansion, and Swift 6.2 concurrency. You are working inside the Swarm repository at `/Users/chriskarani/CodingProjects/AIStack/Swarm/`.

Your goal: Make `@Agent` work on structs as the primary agent creation path. Deprecate `@AgentActor`. Follow strict TDD.

**Prerequisite**: Phase 1 must be complete. `Swarm.configure(provider:)` and `AgentError.toolCallingRequiresCloudProvider` must exist.

## Context

### What Changes

Today `@AgentActor` only works on actors. Phase 2 adds `@Agent` that works on **both structs and actors**:

```swift
// NEW — primary path (struct)
@Agent("You are a friendly assistant.")
struct Greeter {
    func process(_ input: String) async throws -> String {
        return "Hello! You said: \(input)"
    }
}
let result = try await Greeter().run("Hi there")

// STILL WORKS — actor path (deprecated name)
@AgentActor("You are helpful")
actor OldAgent {
    func process(_ input: String) async throws -> String { input }
}
```

### Key Design Decisions

| Decision | Choice |
|----------|--------|
| `@Agent` on structs | Primary creation path. Generates `AgentRuntime + Sendable` conformance |
| `@Agent` on actors | Also works (same as old `@AgentActor`). Generates `AgentRuntime` only |
| `@AgentActor` | Deprecated with `@available(*, deprecated, renamed: "Agent")` |
| Struct cancellation | No `isCancelled` state. `cancel()` is no-op. Rely on `Task.isCancelled` |
| Struct `run()` | Checks `Task.isCancelled` instead of local `isCancelled` flag |
| Builder generation | Actors get Builder (backward compat). Structs do NOT (already value types) |
| User tools property | If user declares `let tools = [...]`, macro skips generating `tools` |
| User handoffs | If user declares `let handoffs: [any AgentRuntime]`, macro generates bridging computed property for `AgentRuntime` protocol |
| Error message | `onlyApplicableToActor` → `onlyApplicableToActorOrStruct` (classes rejected) |

### Struct vs Actor Expansion Differences

| Generated Member | Struct | Actor |
|-----------------|--------|-------|
| `isCancelled` state | NOT generated | `private var isCancelled: Bool = false` |
| `cancel()` | `public func cancel() async {}` (no-op) | Sets `isCancelled = true` |
| `run()` cancellation check | `guard !Task.isCancelled else { throw AgentError.cancelled }` | `if isCancelled { throw AgentError.cancelled }` |
| Builder | NOT generated | Generated (backward compat) |
| Extension conformances | `AgentRuntime, Sendable` | `AgentRuntime` only |
| Handoff bridging | Detects `[any AgentRuntime]`, generates `[AnyHandoffConfiguration]` wrapper | Same |

## Current Source Files

### `Sources/SwarmMacros/AgentMacro.swift` (510 lines)

Key points about the current implementation:

```swift
public struct AgentMacro: MemberMacro, ExtensionMacro {
    // MemberMacro — line 44: guard rejects structs
    guard declaration.is(ActorDeclSyntax.self) else {
        throw AgentMacroError.onlyApplicableToActor
    }

    // ExtensionMacro — line 308: only adds extension for actors
    guard declaration.is(ActorDeclSyntax.self) else {
        return []
    }

    // Members generated (same for struct + actor EXCEPT isCancelled, cancel, Builder, run):
    // 1. tools, 2. instructions, 3. configuration
    // 4. memory (computed + backing), 5. inferenceProvider (computed + backing)
    // 6. tracer (computed + backing), 7. isCancelled, 8. init
    // 9. run(), 10. stream(), 11. cancel(), 12. Builder

    // Helper: getExistingMemberNames — checks for user-declared properties
    // Helper: hasInit — skips init generation if user provided one
    // Helper: hasProcessMethod — generates full run() or stub
}

enum AgentMacroError: Error, CustomStringConvertible {
    case onlyApplicableToActor      // ← must change
    case missingProcessMethod
}
```

### `Sources/SwarmMacros/Plugin.swift`

```swift
@main
struct SwarmMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ToolMacro.self,
        ParameterMacro.self,
        AgentMacro.self,       // ← used by both @Agent and @AgentActor
        TraceableMacro.self,
        PromptMacro.self,
        BuilderMacro.self
    ]
}
```

Plugin already registers `AgentMacro.self`. No change needed here since both `@Agent` and `@AgentActor` use `AgentMacro`. The **declaration** side (MacroDeclarations.swift) handles the routing.

### `Sources/Swarm/Macros/MacroDeclarations.swift`

Currently has TWO `@AgentActor` overloads:

```swift
// Overload 1: labeled (instructions:, generateBuilder:)
@attached(member, names: named(tools), named(instructions), ...)
@attached(extension, conformances: AgentRuntime)
public macro AgentActor(instructions: String, generateBuilder: Bool = true)
    = #externalMacro(module: "SwarmMacros", type: "AgentMacro")

// Overload 2: unlabeled string
@attached(member, names: named(tools), named(instructions), ...)
@attached(extension, conformances: AgentRuntime)
public macro AgentActor(_ instructions: String)
    = #externalMacro(module: "SwarmMacros", type: "AgentMacro")
```

### `Tests/SwarmMacrosTests/AgentMacroTests.swift`

Currently has:
- `testBasicAgentExpansion()` — `@AgentActor` on actor, full expansion match
- `testAgentWithExistingTools()` — actor with user-declared tools
- `testAgentOnlyAppliesToActor()` — struct gets diagnostic error
- `testAgentWithoutProcessMethod()` — actor without process, run() throws

Uses `agentMacros` dictionary:
```swift
let agentMacros: [String: Macro.Type] = [
    "AgentActor": AgentMacro.self
]
```

**CRITICAL**: These existing tests use XCTest (`final class AgentMacroTests: XCTestCase`). Keep them as XCTest — macro expansion tests require `assertMacroExpansion` from `SwiftSyntaxMacrosTestSupport` which uses XCTest. Add new tests in the same style.

## Instructions

Execute in this exact order.

### Step 1: Write Failing Tests (TDD Red Phase)

**Modify file**: `Tests/SwarmMacrosTests/AgentMacroTests.swift`

1. Update the `agentMacros` dictionary to include both names:

```swift
let agentMacros: [String: Macro.Type] = [
    "AgentActor": AgentMacro.self,
    "Agent": AgentMacro.self
]
```

2. Add new test methods to the `AgentMacroTests` class. For struct expansion tests, you need the **exact expected expansion**. The struct expansion differs from actor in these ways:
   - No `isCancelled` state
   - `cancel()` is `public func cancel() async {}` (empty body)
   - `run()` checks `guard !Task.isCancelled` instead of `if isCancelled`
   - No Builder generated
   - Extension adds `Sendable` conformance: `extension Greeter: AgentRuntime, Sendable {}`

Write these tests:

```swift
// --- @Agent on struct: basic ---
func testAgentOnStructBasic() throws {
    #if canImport(SwarmMacros)
    assertMacroExpansion(
        """
        @Agent("You are a friendly assistant.")
        struct Greeter {
            func process(_ input: String) async throws -> String {
                return "Hello!"
            }
        }
        """,
        expandedSource: /* struct expansion with:
            - nonisolated public let tools/instructions/configuration
            - memory/inferenceProvider/tracer computed properties
            - init with all params
            - run() using Task.isCancelled
            - stream()
            - cancel() as no-op
            - NO Builder
            - NO isCancelled state
        */,
        macros: agentMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
}

// --- @Agent on struct with user tools ---
func testAgentOnStructWithTools() throws {
    #if canImport(SwarmMacros)
    assertMacroExpansion(
        """
        @Agent("Math assistant")
        struct MathBot {
            let tools: [any AnyJSONTool] = []
            func process(_ input: String) async throws -> String { input }
        }
        """,
        expandedSource: /* tools NOT re-generated, rest generated */,
        macros: agentMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
}

// --- @Agent on actor (same as @AgentActor) ---
func testAgentOnActorStillWorks() throws {
    #if canImport(SwarmMacros)
    assertMacroExpansion(
        """
        @Agent("Actor agent")
        actor ActorStyleAgent {
            func process(_ input: String) async throws -> String { input }
        }
        """,
        expandedSource: /* same as @AgentActor expansion — has isCancelled, Builder, etc */,
        macros: agentMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
}

// --- @Agent rejects class ---
func testAgentRejectsClass() throws {
    #if canImport(SwarmMacros)
    assertMacroExpansion(
        """
        @Agent("Invalid")
        class InvalidAgent {
            func process(_ input: String) async throws -> String { "" }
        }
        """,
        expandedSource: """
        class InvalidAgent {
            func process(_ input: String) async throws -> String { "" }
        }
        """,
        diagnostics: [
            DiagnosticSpec(message: "@Agent can only be applied to actors or structs", line: 1, column: 1)
        ],
        macros: agentMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
}

// --- @AgentActor backward compat still works ---
func testAgentActorDeprecatedStillExpands() throws {
    #if canImport(SwarmMacros)
    // @AgentActor on actor should still produce the same expansion
    assertMacroExpansion(
        """
        @AgentActor("Backward compat")
        actor LegacyAgent {
            func process(_ input: String) async throws -> String { input }
        }
        """,
        expandedSource: /* same actor expansion as before */,
        macros: agentMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
}
```

3. Update the existing `testAgentOnlyAppliesToActor` test: this test currently expects a diagnostic when `@AgentActor` is on a struct. After Phase 2, `@AgentActor` on a struct should STILL fail (it's the deprecated path — actors only). But `@Agent` on a struct should succeed. Keep the existing test but update the diagnostic message to match the new error.

**Create file**: `Tests/SwarmTests/Integration/ScenarioTests.swift`

```swift
import Testing
@testable import Swarm

@Suite("API Scenarios — Compilation + Runtime")
struct ScenarioTests {

    @Test("Scenario 1: Agent struct runs with mock provider")
    func scenario1HelloWorld() async throws {
        let mock = MockInferenceProvider(responses: ["Hello! You said: Hi"])
        await Swarm.configure(provider: mock)
        let agent = try Agent(instructions: "You are a friendly assistant.")
        let result = try await agent.run("Hi there")
        #expect(result.output.contains("Hello"))
        await Swarm.reset()
    }

    @Test("Scenario 2: Agent with tools requires provider")
    func scenario2ToolAgent() async throws {
        let mock = MockInferenceProvider(responses: ["42"])
        await Swarm.configure(provider: mock)
        let tool = MockTool(name: "calculator")
        let agent = try Agent(tools: [tool], instructions: "Math assistant")
        let result = try await agent.run("What is 2+2?")
        #expect(result.output == "42")
        await Swarm.reset()
    }

    @Test("Scenario 10: Agent with input guardrail blocks bad input")
    func scenario10Guardrails() async throws {
        let mock = MockInferenceProvider(responses: ["ok"])
        let agent = try Agent(
            instructions: "Service agent",
            inferenceProvider: mock,
            inputGuardrails: [AlwaysTripGuardrail()]
        )
        await #expect(throws: Error.self) {
            try await agent.run("anything")
        }
    }
}
```

Note: You'll need to check if `AlwaysTripGuardrail` or similar test guardrail already exists in the mocks. If not, create a simple one.

### Step 2: Update AgentMacro.swift — Support Structs

**Modify file**: `Sources/SwarmMacros/AgentMacro.swift`

Make these changes:

**2a. Update the guard in `expansion(of:providingMembersOf:)`** (line 49):

```swift
// BEFORE:
guard declaration.is(ActorDeclSyntax.self) else {
    throw AgentMacroError.onlyApplicableToActor
}

// AFTER:
let isActor = declaration.is(ActorDeclSyntax.self)
let isStruct = declaration.is(StructDeclSyntax.self)
guard isActor || isStruct else {
    throw AgentMacroError.onlyApplicableToActorOrStruct
}
```

**2b. Conditionally generate `isCancelled`** — only for actors:

```swift
// Wrap the existing isCancelled generation:
if isActor {
    if !existingMembers.contains("isCancelled") {
        members.append("""
            private var isCancelled: Bool = false
            """)
    }
}
```

**2c. Generate different `run()` for structs vs actors**:

For structs, the `run()` method must:
- Use `guard !Task.isCancelled else { throw AgentError.cancelled }` instead of `if isCancelled { ... }`
- Remove `isCancelled = false` at the start

Create a helper method or use a conditional:

```swift
if hasProcess {
    if isStruct {
        members.append(generateStructRunMethod(instructions: instructions))
    } else {
        members.append(/* existing actor run method */)
    }
}
```

The struct `run()` is identical to the actor version EXCEPT:
- Remove: `isCancelled = false` line
- Replace: `if isCancelled { throw AgentError.cancelled }` with `guard !Task.isCancelled else { throw AgentError.cancelled }`

**2d. Generate different `cancel()` for structs**:

```swift
if isStruct {
    if !existingMembers.contains("cancel") {
        members.append("""
            public func cancel() async {
                // Struct agents rely on structured concurrency (Task.isCancelled)
            }
            """)
    }
} else {
    // existing actor cancel()
}
```

**2e. Skip Builder for structs**:

```swift
// Only generate Builder for actors
if isActor, shouldGenerateBuilder(from: node) {
    // existing Builder generation
}
```

**2f. Handle handoff bridging for structs**:

Check if user declared a property named `handoffs` or `handoffAgents`:

```swift
// If user has `let handoffs: [any AgentRuntime]`, generate bridging
if existingMembers.contains("handoffs") {
    // User declared handoffs — check if we need to generate
    // a protocol-conforming wrapper. For now, detect and skip
    // generating the default empty handoffs.
    // The handoff bridging requires generating a computed property
    // that maps [any AgentRuntime] to [AnyHandoffConfiguration].
    // This is a v1 limitation — document that users should use
    // `let handoffAgents: [any AgentRuntime]` naming pattern.
}
```

For v1, support `let handoffAgents: [any AgentRuntime]` pattern:
- If macro detects `handoffAgents` property, generate:
```swift
nonisolated public var handoffs: [AnyHandoffConfiguration] {
    handoffAgents.map { AnyHandoffConfiguration(targetAgent: $0, toolNameOverride: nil, toolDescription: nil) }
}
```

**2g. Update the ExtensionMacro** (line 300):

```swift
// BEFORE:
guard declaration.is(ActorDeclSyntax.self) else {
    return []
}
let agentExtension = try ExtensionDeclSyntax("extension \(type): AgentRuntime {}")

// AFTER:
let isActor = declaration.is(ActorDeclSyntax.self)
let isStruct = declaration.is(StructDeclSyntax.self)
guard isActor || isStruct else {
    return []
}

if isStruct {
    let ext = try ExtensionDeclSyntax("extension \(type): AgentRuntime, Sendable {}")
    return [ext]
} else {
    let ext = try ExtensionDeclSyntax("extension \(type): AgentRuntime {}")
    return [ext]
}
```

**2h. Update error enum**:

```swift
enum AgentMacroError: Error, CustomStringConvertible {
    case onlyApplicableToActorOrStruct  // renamed
    case missingProcessMethod

    var description: String {
        switch self {
        case .onlyApplicableToActorOrStruct:
            return "@Agent can only be applied to actors or structs"
        case .missingProcessMethod:
            return "@Agent requires a process(_ input: String) method"
        }
    }
}
```

### Step 3: Update MacroDeclarations.swift

**Modify file**: `Sources/Swarm/Macros/MacroDeclarations.swift`

Add the `@Agent` macro declarations (TWO overloads matching `@AgentActor`):

```swift
// MARK: - @Agent Macro

/// Generates AgentRuntime conformance for a struct or actor.
///
/// `@Agent` is the primary way to create agents in Swarm.
/// Apply it to a struct with a `process(_ input:)` method:
///
/// ```swift
/// @Agent("You are a helpful assistant.")
/// struct MyAgent {
///     func process(_ input: String) async throws -> String {
///         return "Response to: \(input)"
///     }
/// }
///
/// let result = try await MyAgent().run("Hello")
/// ```
@attached(
    member,
    names: named(tools), named(instructions), named(configuration),
    named(memory), named(inferenceProvider), named(tracer),
    named(_memory), named(_inferenceProvider), named(_tracer),
    named(isCancelled), named(init), named(run), named(stream),
    named(cancel), named(Builder), named(handoffs)
)
@attached(extension, conformances: AgentRuntime, Sendable)
public macro Agent(_ instructions: String) = #externalMacro(
    module: "SwarmMacros", type: "AgentMacro"
)

/// Labeled overload for @Agent with builder control.
@attached(
    member,
    names: named(tools), named(instructions), named(configuration),
    named(memory), named(inferenceProvider), named(tracer),
    named(_memory), named(_inferenceProvider), named(_tracer),
    named(isCancelled), named(init), named(run), named(stream),
    named(cancel), named(Builder), named(handoffs)
)
@attached(extension, conformances: AgentRuntime, Sendable)
public macro Agent(
    instructions: String,
    generateBuilder: Bool = true
) = #externalMacro(module: "SwarmMacros", type: "AgentMacro")
```

Then deprecate the existing `@AgentActor` overloads by adding `@available`:

```swift
// On BOTH @AgentActor overloads, add:
@available(*, deprecated, renamed: "Agent")
```

### Step 4: Update Existing Test for New Error Message

**Modify file**: `Tests/SwarmMacrosTests/AgentMacroTests.swift`

The existing `testAgentOnlyAppliesToActor` test expects:
```swift
DiagnosticSpec(message: "@AgentActor can only be applied to actors", ...)
```

Update to:
```swift
DiagnosticSpec(message: "@Agent can only be applied to actors or structs", ...)
```

### Step 5: Fill In Exact Expansion Strings

This is the hardest part. You MUST produce the exact expanded source for each test. The struct expansion is identical to the actor expansion with these differences:

1. No `private var isCancelled: Bool = false`
2. `cancel()` body is empty
3. `run()` uses `guard !Task.isCancelled` instead of `if isCancelled`
4. `run()` does NOT have `isCancelled = false`
5. No Builder struct
6. Extension is `AgentRuntime, Sendable` not just `AgentRuntime`

Copy the existing `testBasicAgentExpansion` expanded source as a template, apply the 6 differences above, and use that as the expected expansion for `testAgentOnStructBasic`.

### Step 6: Build and Run Tests

```bash
swift build 2>&1 | head -80
swift test --filter AgentMacroTests 2>&1
swift test --filter ScenarioTests 2>&1
swift test 2>&1 | tail -30
```

All existing tests must pass. All new tests must pass.

### Step 7: Format Code

```bash
swift package plugin --allow-writing-to-package-directory swiftformat
```

## Success Criteria

1. `swift build` succeeds with zero errors
2. `@Agent("...") struct MyAgent { ... }` compiles and generates `AgentRuntime + Sendable` conformance
3. `@Agent("...") actor MyAgent { ... }` compiles and generates `AgentRuntime` conformance (same as old `@AgentActor`)
4. `@AgentActor("...") actor MyAgent { ... }` still compiles (deprecated warning expected)
5. `@Agent("...") class Foo { ... }` produces a diagnostic error
6. Struct expansion has NO `isCancelled` state and NO `Builder`
7. Struct `cancel()` is a no-op empty body
8. Struct `run()` checks `Task.isCancelled`, not local state
9. All existing `AgentMacroTests` pass (with updated error message)
10. All new struct expansion tests pass
11. `ScenarioTests` pass (Scenarios 1, 2, 10)
12. `swift test` — ALL tests pass, zero regressions

## Files Changed Summary

| File | Action | What Changes |
|------|--------|-------------|
| `Sources/SwarmMacros/AgentMacro.swift` | MODIFY | Accept struct, conditional expansion, new error |
| `Sources/Swarm/Macros/MacroDeclarations.swift` | MODIFY | Add `@Agent`, deprecate `@AgentActor` |
| `Tests/SwarmMacrosTests/AgentMacroTests.swift` | MODIFY | Add struct tests, update error message, add `"Agent"` to macro dict |
| `Tests/SwarmTests/Integration/ScenarioTests.swift` | CREATE | Runtime integration tests for Scenarios 1, 2, 10 |

Note: `Plugin.swift` does NOT need changes — it already registers `AgentMacro.self` which handles both `@Agent` and `@AgentActor`.

## Edge Cases to Watch

1. **Macro expansion tests are EXACT string matches**: Whitespace, newlines, and indentation must match perfectly. Copy from existing passing tests and modify minimally.
2. **`nonisolated` on struct properties**: Structs don't have isolation domains, so `nonisolated` is technically redundant but keeps the expansion consistent with the protocol requirements. The compiler accepts it.
3. **`@AgentActor` on struct should still fail**: Even though `@Agent` now works on structs, `@AgentActor` is the deprecated name. The existing test `testAgentOnlyAppliesToActor` tests `@AgentActor` on a struct — decide: should this now succeed (since the macro implementation accepts structs) or fail? Since both `@Agent` and `@AgentActor` route to the same `AgentMacro`, it will now succeed. Update the test accordingly — the struct should expand correctly when using `@AgentActor` too, but the user gets a deprecation warning from the `@available` attribute (not from the macro).
4. **Builder name extraction**: The Builder code extracts the type name. For structs, `declaration.as(StructDeclSyntax.self)?.name.text` gives the name. But since we skip Builder for structs, this is informational only.
5. **Handoff bridging is deferred**: For v1, handoffs on `@Agent` structs use the protocol default (`[]`). The full `let handoffs: [any AgentRuntime]` → `[AnyHandoffConfiguration]` bridging is a follow-up. Document this limitation.
6. **Test guardrail mock**: `ScenarioTests` needs a test guardrail that always trips. Check if one exists in `Tests/SwarmTests/Mocks/`. If not, create a minimal `AlwaysTripGuardrail` struct.
7. **`inputGuardrails`/`outputGuardrails` on structs**: The macro does NOT generate these (they have protocol defaults of `[]`). Users who need guardrails use the `Agent` actor escape hatch (Scenario 10).
