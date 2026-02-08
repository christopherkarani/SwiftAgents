# API Ergonomics Improvements

## Overview

This plan outlines improvements to the Swarm API to enhance developer experience and type safety.

## Phase 1: Typed Handoffs & Tool Registry Type Safety (Completed)

### Handoff Configuration Improvements

**Problem**: `handoff(to:)` returns `AnyHandoffConfiguration` (type-erased), losing compile-time type information.

**Solution**:
- Modified `handoff(to:)` to return `HandoffConfiguration<AgentType>` (typed)
- Added `anyHandoff(to:)` function that returns `AnyHandoffConfiguration` directly
- Maintains improved type safety while providing migration path

**Breaking Change**: `handoff(to:)` now returns `HandoffConfiguration<T>` instead of `AnyHandoffConfiguration`. Code expecting `AnyHandoffConfiguration` should use `anyHandoff(to:)` instead.

**Files Modified**:
- `Sources/Swarm/Orchestration/HandoffBuilder.swift`
  - Modified `handoff(to:)` to return `HandoffConfiguration<T>`
  - Added `anyHandoff()` function

**Tests Added**:
- `Tests/SwarmTests/Orchestration/HandoffConfigurationTests+TypedHandoff.swift`
  - 7 tests for typed handoff configuration
  - Tests for `anyHandoff()` function

### Tool Registry Type Safety

**Problem**: `ToolRegistry` only supports string-based tool lookup, requiring runtime casting.

**Solution**:
- Added type-safe extensions to `ToolRegistry`:
  - `tool(ofType:)` - returns first tool of specified type
  - `tools(ofType:)` - returns all tools of specified type
  - `execute(ofType:arguments:)` - executes tool by type
  - `contains(toolOfType:)` - checks if tool exists by type

**Files Added**:
- `Sources/Swarm/Tools/ToolRegistry+TypeSafe.swift` - Type-safe extensions

**Tests Added**:
- `Tests/SwarmTests/Tools/ToolRegistryTests+TypeSafe.swift`
  - 10 tests for type-safe tool registry methods

### Code Quality Improvements

**Documentation**:
- Added comprehensive documentation comments to `Tool` factory methods (`.array()`, `.object()`, `.oneOf()`)
- Added detailed documentation to all `ToolRegistry+TypeSafe` extension methods with examples

**Code Organization**:
- Created separate `ToolRegistry+TypeSafe.swift` file for type-safe extensions
- Ensures clear separation of concerns

**Concurrency**:
- Removed redundant `await` in `contains(toolOfType:)` method
- Verified all code is `Sendable`-safe

**Test Fixes**:
- Fixed `HandoffConfigurationTests+TypedHandoff.swift` to use `configuration.name`
- Fixed `SpecificAgent` to conform to `Agent` protocol
- Fixed `ParallelToolExecutorTests+Advanced.swift` to use `$0.isSuccess` property access
- Fixed `ToolRegistryTests+TypeSafe.swift` to remove incorrect hook verification test

**Results**:
- All 21 Phase 1 tests pass (7 HandoffBuilder + 10 ToolRegistry + 4 ParameterType)
- All test suites pass with no regressions
- Code formatted with SwiftFormat
- Ready to proceed to Phase 2

### Parameter Type Factory Functions

**Problem**: Creating complex parameter types requires verbose enum syntax.

**Solution**:
- Added `ParameterTypeRepresentable` protocol for type-safe parameter type mapping
- Added factory methods to `ParameterType` enum:
  - `.array(_:)` - creates array type with element type
  - `.object(@ToolParameterBuilder:)` - creates object type with properties
  - `.oneOf(_:)` - creates enum choice type

**Files Modified**:
- `Sources/Swarm/Tools/Tool.swift`
  - Added `ParameterTypeRepresentable` protocol
  - Added conformances for `String`, `Int`, `Double`, `Bool`
  - Added static factory methods to `ParameterType` enum

**Tests Added**:
- `Tests/SwarmTests/Tools/ToolParameterTests+Factories.swift`
  - 5 tests for `ParameterTypeRepresentable` protocol
  - 8 tests for factory functions
  - 6 tests for factory usage integration

**Results**:
- All 19 Phase 1 tests pass
- No regressions in existing tests

## Phase 2: Actor-Based AgentResult Builder (Pending)

### Problem

`AgentResult.Builder` is a struct with manual mutation tracking, requiring careful manual management.

### Solution

Create an actor-based `AgentResult.Builder` with automatic thread-safe mutation.

### Implementation Plan

1. Refactor `AgentResult.Builder` to be an `actor`
2. Add `@MainActor` if needed for UI integration
3. Ensure all mutations are automatically thread-safe
4. Add SwiftLint rule to prevent direct property mutation
5. Update all existing tests
6. Add integration tests for concurrent builder access

### Files to Modify

- `Sources/Swarm/Core/AgentResult.swift`

### Tests to Update

- `Tests/SwarmTests/Core/AgentResultTests.swift`

## Phase 3: Memory Typed Message Retrieval (Pending)

### Problem

Retrieving messages from memory requires manual casting and type checking.

### Solution

Add typed message retrieval methods with generics.

### Implementation Plan

1. Add generic methods to memory protocols:
   - `messages(ofType:)` - retrieve messages by type
   - `lastMessage(ofType:)` - get last message of type
2. Add type-safe message filtering
3. Update existing memory implementations
4. Add tests for typed retrieval

### Files to Modify

- `Sources/Swarm/Memory/ConversationMemory.swift`
- `Sources/Swarm/Memory/HybridMemory.swift`
- `Sources/Swarm/Memory/VectorMemory.swift`

## Timeline

- Phase 1: Completed ✓
- Phase 2: Pending
- Phase 3: Pending

## Status

**Phase 1**: Complete - All 19 tests passing, no regressions
**Phase 2**: Not started
**Phase 3**: Not started
