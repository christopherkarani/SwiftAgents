# SwiftAgents Macro Implementation Plan

## Overview

This plan outlines the implementation of Swift macros to significantly reduce boilerplate and improve developer ergonomics in the SwiftAgents framework.

## Macro Summary

| Macro | Type | Purpose | Priority |
|-------|------|---------|----------|
| `@Tool` | Attached (Member) | Generate Tool protocol conformance | P0 |
| `@Parameter` | Attached (Peer) | Define tool parameters declaratively | P0 |
| `@Agent` | Attached (Member) | Generate Agent protocol boilerplate | P1 |
| `@Traceable` | Attached (Peer) | Add automatic tracing/observability | P2 |
| `#Prompt` | Freestanding (Expression) | Type-safe prompt building | P3 |

---

## Phase 1: Infrastructure Setup

### Package.swift Changes
- Add `swift-syntax` dependency (600.0.0+)
- Create `SwiftAgentsMacros` target (CompilerPlugin)
- Create `SwiftAgentsMacrosLib` for shared macro logic
- Update main target to depend on macros

### Directory Structure
```
Sources/
├── SwiftAgents/              # Main library
│   └── Macros/
│       └── MacroDeclarations.swift  # Public macro declarations
├── SwiftAgentsMacros/        # Compiler plugin (macro implementations)
│   ├── SwiftAgentsMacrosPlugin.swift
│   ├── ToolMacro.swift
│   ├── ParameterMacro.swift
│   ├── AgentMacro.swift
│   └── TraceableMacro.swift
Tests/
└── SwiftAgentsMacrosTests/   # Macro expansion tests
```

---

## Phase 2: @Tool Macro

### Before (Current API)
```swift
public struct WeatherTool: Tool, Sendable {
    public let name = "weather"
    public let description = "Gets the current weather"
    public let parameters: [ToolParameter] = [
        ToolParameter(name: "location", description: "City name", type: .string, isRequired: true),
        ToolParameter(name: "units", description: "Units", type: .string, isRequired: false)
    ]

    public init() {}

    public func execute(arguments: [String: SendableValue]) async throws -> SendableValue {
        guard let location = arguments["location"]?.stringValue else {
            throw AgentError.invalidToolArguments(toolName: name, reason: "Missing location")
        }
        let units = arguments["units"]?.stringValue ?? "celsius"
        // ... implementation
        return .string("72°F")
    }
}
```

### After (With Macros)
```swift
@Tool("Gets the current weather")
struct WeatherTool {
    @Parameter("City name")
    var location: String

    @Parameter("Temperature units", default: "celsius")
    var units: String = "celsius"

    func execute() async throws -> String {
        // location and units are automatically available
        return "72°F in \(location)"
    }
}
```

### Implementation Details

The `@Tool` macro will:
1. Add `Tool` and `Sendable` conformance
2. Generate `name` property from type name (lowercased)
3. Use macro argument as `description`
4. Collect `@Parameter` annotated properties for `parameters` array
5. Generate wrapper `execute(arguments:)` that:
   - Extracts typed values from arguments dictionary
   - Validates required parameters
   - Calls the user's `execute()` method
   - Converts return type to `SendableValue`

### Macro Signature
```swift
@attached(member, names: named(name), named(description), named(parameters), named(init), named(execute))
@attached(extension, conformances: Tool, Sendable)
public macro Tool(_ description: String) = #externalMacro(module: "SwiftAgentsMacros", type: "ToolMacro")
```

---

## Phase 3: @Parameter Macro

### Usage
```swift
@Parameter("Description of parameter")
var requiredParam: String

@Parameter("Optional with default", default: "value")
var optionalParam: String = "value"

@Parameter("Enum choices", oneOf: ["a", "b", "c"])
var enumParam: String
```

### Generated Code
For each `@Parameter`:
- Extract to local variable in execute wrapper
- Add to parameters array with correct type mapping
- Handle optionality and defaults

### Type Mapping
| Swift Type | ParameterType |
|------------|---------------|
| `String` | `.string` |
| `Int` | `.int` |
| `Double` | `.double` |
| `Bool` | `.bool` |
| `[T]` | `.array(elementType: ...)` |
| `Optional<T>` | Same as T, `isRequired: false` |

---

## Phase 4: @Agent Macro

### Before
```swift
public actor MyAgent: Agent {
    public let tools: [any Tool]
    public let instructions: String
    public let configuration: AgentConfiguration
    public nonisolated let memory: (any AgentMemory)?
    public nonisolated let inferenceProvider: (any InferenceProvider)?

    private var isCancelled = false

    public init(...) { ... }
    public func run(_ input: String) async throws -> AgentResult { ... }
    public nonisolated func stream(_ input: String) -> AsyncThrowingStream<AgentEvent, Error> { ... }
    public func cancel() async { ... }
}
```

### After
```swift
@Agent("You are a helpful assistant")
actor MyAgent {
    @Tools var tools = [CalculatorTool(), DateTimeTool()]

    func process(_ input: String) async throws -> String {
        // Custom processing logic
        return "Response"
    }
}
```

### Generated Members
- All Agent protocol properties with defaults
- Standard initializer
- `run()` implementation calling user's `process()` method
- `stream()` wrapper
- `cancel()` implementation

---

## Phase 5: @Traceable Macro

### Usage
```swift
@Traceable
struct WeatherTool: Tool {
    // ... existing implementation
}
```

### Generated Code
Wraps `execute()` to:
- Emit `TraceEvent.toolCall` at start
- Record duration
- Emit `TraceEvent.toolResult` on completion
- Emit `TraceEvent.error` on failure

---

## Phase 6: #Prompt Macro

### Usage
```swift
let prompt = #Prompt {
    system: "You are \(role)"
    user: "Query: \(input)"
    tools: tools
}
```

### Features
- Compile-time validation of interpolations
- Safe escaping of user input
- Structured prompt building

---

## Testing Strategy

### Macro Expansion Tests
Use `assertMacroExpansion` from swift-syntax-testing:

```swift
func testToolMacroExpansion() throws {
    assertMacroExpansion(
        """
        @Tool("Calculator")
        struct CalcTool {
            @Parameter("Expression")
            var expr: String

            func execute() -> Double { 0 }
        }
        """,
        expandedSource: """
        struct CalcTool {
            var expr: String

            func execute() -> Double { 0 }

            // Generated members...
        }
        """,
        macros: testMacros
    )
}
```

### Integration Tests
- Create tools using macros
- Execute with real arguments
- Verify correct behavior

---

## Migration Guide

### Tools
1. Remove explicit `Tool` conformance
2. Add `@Tool("description")`
3. Convert parameters array to `@Parameter` properties
4. Simplify `execute()` to use typed properties

### Agents
1. Remove explicit `Agent` conformance
2. Add `@Agent("instructions")`
3. Remove boilerplate properties
4. Rename main method to `process()`

---

## Timeline

- Phase 1 (Infrastructure): Foundation
- Phase 2 (@Tool): Core feature
- Phase 3 (@Parameter): Core feature
- Phase 4 (@Agent): Enhancement
- Phase 5 (@Traceable): Enhancement
- Phase 6 (#Prompt): Nice-to-have

---

## Dependencies

```swift
.package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0")
```

## Notes

- Macros require Swift 5.9+
- Package already uses Swift 6.2, so compatible
- swift-syntax version should match Swift toolchain
