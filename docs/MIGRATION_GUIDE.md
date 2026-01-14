# Migration Guide: SwiftAgents 1.0 to 1.1

This guide helps you migrate your SwiftAgents code from version 1.0 to 1.1, which introduces API ergonomics improvements and enhanced error handling.

## Overview of Changes

SwiftAgents 1.1 focuses on improving developer experience with:
- Type-safe tool registry operations
- Fluent handoff configuration APIs
- Enhanced error messages with recovery suggestions
- Parameter type factory methods

## Breaking Changes

### 1. Handoff Function Return Type

**What Changed:**
- `handoff(to:)` now returns `HandoffConfiguration<T>` instead of `AnyHandoffConfiguration`

**Why:**
- Provides compile-time type safety for handoff configurations
- Enables better IDE support and error detection

**Migration Required:**
```swift
// Before (1.0)
let configs: [AnyHandoffConfiguration] = [
    handoff(to: plannerAgent),
    handoff(to: executorAgent)
]

// After (1.1) - Option 1: Use anyHandoff
let configs: [AnyHandoffConfiguration] = [
    anyHandoff(to: plannerAgent),
    anyHandoff(to: executorAgent)
]

// After (1.1) - Option 2: Use typed configurations
let plannerConfig: HandoffConfiguration<PlannerAgent> = handoff(to: plannerAgent)
let executorConfig: HandoffConfiguration<ExecutorAgent> = handoff(to: executorAgent)
```

**Recommendation:** Use `anyHandoff(to:)` if you need collections of heterogeneous handoff configurations. Use `handoff(to:)` for type safety when working with specific agent types.

## New Features

### 1. Type-Safe Tool Registry

**New Methods:**
```swift
extension ToolRegistry {
    // Get tool by type (compile-time safe)
    func tool<T>(ofType type: T.Type) async -> T? where T: Tool

    // Get all tools of a type
    func tools<T>(ofType type: T.Type) async -> [T] where T: Tool

    // Execute tool by type
    func execute<T>(
        ofType type: T.Type,
        arguments: [String: SendableValue],
        agent: (any Agent)? = nil,
        context: AgentContext? = nil,
        hooks: (any RunHooks)? = nil
    ) async throws -> SendableValue where T: Tool

    // Check if tool type is registered
    func contains<T>(toolOfType type: T.Type) async -> Bool where T: Tool
}
```

**Migration Example:**
```swift
// Before (1.0) - Runtime string lookup
if let calculator = await registry.tool(named: "calculator") as? CalculatorTool {
    let result = try await calculator.execute(arguments: ["expression": .string("2+2")])
}

// After (1.1) - Compile-time type safe
if let calculator = await registry.tool(ofType: CalculatorTool.self) {
    let result = try await calculator.execute(arguments: ["expression": .string("2+2")])
}

// Or execute directly by type
let result = try await registry.execute(
    ofType: CalculatorTool.self,
    arguments: ["expression": .string("2+2")]
)
```

### 2. Fluent Handoff Builder

**New API:**
```swift
// Before (1.0) - Manual configuration
let config = HandoffConfiguration(
    targetAgent: executorAgent,
    toolNameOverride: "execute_task",
    toolDescription: "Execute the planned task",
    nestHandoffHistory: true
)

// After (1.1) - Fluent builder
let config = HandoffBuilder(to: executorAgent)
    .toolName("execute_task")
    .toolDescription("Execute the planned task")
    .nestHistory(true)
    .build()
```

**Benefits:**
- More readable configuration
- Method chaining
- Immutable builder pattern
- Better discoverability

### 3. Parameter Type Factory Methods

**New Factory Methods:**
```swift
extension ParameterType {
    // Type-safe array creation
    static func array<T>(_ elementType: T.Type) -> ParameterType where T: ParameterTypeRepresentable

    // Result builder for objects
    static func object(@ToolParameterBuilder _ properties: () -> [ToolParameter]) -> ParameterType

    // Variadic enum creation
    static func oneOf(_ choices: String...) -> ParameterType
}
```

**Migration Example:**
```swift
// Before (1.0) - Verbose enum construction
let param = ToolParameter(
    name: "data",
    description: "Complex data",
    type: .object(properties: [
        ToolParameter(name: "name", description: "Name", type: .string),
        ToolParameter(name: "tags", description: "Tags", type: .array(elementType: .string))
    ])
)

// After (1.1) - Clean factory methods
let param = ToolParameter(
    name: "data",
    description: "Complex data",
    type: .object {
        ToolParameter(name: "name", description: "Name", type: .string)
        ToolParameter(name: "tags", description: "Tags", type: .array(String.self))
    }
)
```

### 4. Enhanced Error Handling

**New Features:**
- Recovery suggestions for all errors
- More descriptive error messages
- Help anchors for documentation links

**Migration Example:**
```swift
// Before (1.0) - Basic error message
catch let error as AgentError {
    print("Error: \(error.localizedDescription)")
}

// After (1.1) - Enhanced error handling
catch let error as AgentError {
    print("Error: \(error.localizedDescription)")
    if let suggestion = error.recoverySuggestion {
        print("Suggestion: \(suggestion)")
    }
    if let anchor = error.helpAnchor {
        print("Help: https://swiftagents.dev/docs/\(anchor)")
    }
}
```

## Step-by-Step Migration

### Step 1: Update Dependencies
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/your-org/SwiftAgents", from: "1.1.0")
]
```

### Step 2: Fix Breaking Changes
1. Replace `handoff(to:)` with `anyHandoff(to:)` in collections
2. Update any code expecting `AnyHandoffConfiguration` from `handoff(to:)`

### Step 3: Adopt New Features
1. Replace string-based tool lookups with type-safe methods
2. Use `HandoffBuilder` for complex handoff configurations
3. Use parameter type factories for cleaner tool definitions
4. Add recovery suggestion handling to error cases

### Step 4: Test and Verify
1. Run your test suite
2. Verify all handoff configurations work
3. Check that tool executions still work
4. Test error handling improvements

## Compatibility Matrix

| Feature | SwiftAgents 1.0 | SwiftAgents 1.1 |
|---------|-----------------|-----------------|
| String-based tool lookup | ✅ | ✅ |
| Type-safe tool lookup | ❌ | ✅ |
| Manual handoff config | ✅ | ✅ |
| Fluent handoff builder | ❌ | ✅ |
| Basic error messages | ✅ | ✅ |
| Recovery suggestions | ❌ | ✅ |
| Parameter factories | ❌ | ✅ |

## Common Migration Issues

### Issue 1: Collection of Handoff Configurations
```swift
// Problem code (won't compile in 1.1)
let configs: [AnyHandoffConfiguration] = [
    handoff(to: agent1),  // Returns HandoffConfiguration<Agent1>
    handoff(to: agent2)   // Returns HandoffConfiguration<Agent2>
]

// Solution
let configs: [AnyHandoffConfiguration] = [
    anyHandoff(to: agent1),  // Use anyHandoff
    anyHandoff(to: agent2)
]
```

### Issue 2: Tool Type Casting
```swift
// Problem code (still works but not optimal)
if let tool = await registry.tool(named: "calculator") as? CalculatorTool {
    // Use tool
}

// Better solution
if let tool = await registry.tool(ofType: CalculatorTool.self) {
    // Use tool (no casting needed)
}
```

### Issue 3: Complex Parameter Types
```swift
// Problem code (verbose)
type: .object(properties: [
    ToolParameter(name: "name", type: .string),
    ToolParameter(name: "value", type: .int)
])

// Better solution
type: .object {
    ToolParameter(name: "name", type: .string)
    ToolParameter(name: "value", type: .int)
}
```

## Testing Your Migration

### Automated Tests
```swift
// Add to your test suite
func testMigrationCompatibility() async throws {
    let registry = ToolRegistry(tools: [CalculatorTool()])

    // Test old API still works
    let toolByName = await registry.tool(named: "calculator")
    #expect(toolByName != nil)

    // Test new API works
    let toolByType = await registry.tool(ofType: CalculatorTool.self)
    #expect(toolByType != nil)

    // Test they return the same tool
    #expect(toolByName as? CalculatorTool === toolByType)
}

func testHandoffMigration() async throws {
    let agent = MockAgent()

    // Test anyHandoff works
    let anyConfig = anyHandoff(to: agent)
    #expect(anyConfig.targetAgent === agent)

    // Test typed handoff works
    let typedConfig: HandoffConfiguration<MockAgent> = handoff(to: agent)
    #expect(typedConfig.targetAgent === agent)
}
```

### Manual Testing Checklist
- [ ] All agents initialize correctly
- [ ] Tool execution works
- [ ] Handoffs execute properly
- [ ] Error messages are helpful
- [ ] No performance regressions
- [ ] IDE autocomplete works for new APIs

## Getting Help

If you encounter issues during migration:

1. Check the [API Reference](API_REFERENCE.md) for updated method signatures
2. Review the [Best Practices Guide](BEST_PRACTICES.md) for recommended patterns
3. Search existing issues on GitHub
4. Create a new issue with your migration problem

## Release Notes

For a complete list of changes, see the [1.1 Release Notes](RELEASE_NOTES.md).

---

*This migration guide will be updated as new issues are discovered during the adoption period.*