# Foundation Models Interoperability Plan

## Goal
Establish full bidirectional interoperability between `Swarm` and Apple's `FoundationModels` framework, enabling:
1.  **Foundation -> Agent**: Wrapping `FoundationModels` tools for use in `Swarm`.
2.  **Agent -> Foundation**: Adapting `Swarm` tools for use in `FoundationModels` sessions.
3.  **Context Synergy**: Ensuring both tool types can access necessary context (agent state, other tools) regardless of the host environment.

## Technical Analysis

### The `Generable` Constraint
My research confirms that `FoundationModels` relies on the `@Generable` macro to generate tool schemas at **compile time**. 
*   **Implication**: We cannot dynamically generate strictly-typed `Generable` structs at runtime for arbitrary `Swarm` tools.
*   **Solution**: We must use a **Universal JSON Proxy** strategy for the Agent -> Foundation adapter.

### 1. Protocol Enhancement (Swarm)
Update `Swarm.Tool` to support the "Context" pattern used by Foundation Models.

```swift
func execute(
    arguments: [String: SendableValue],
    context: AgentContext?,
    registry: ToolRegistry?
) async throws -> SendableValue
```

### 2. Adapters

#### A. `FoundationToolAdapter` (Use FM Tool in Swarm)
Wraps a `FoundationModels.Tool` to work in `Swarm`.

*   **Capabilities**:
    *   **Schema Extraction**: Uses Swift `Mirror` to inspect the `Generable` argument struct and dynamically generate `[ToolParameter]` definitions.
    *   **Execution**: 
        1.  Receives `[String: SendableValue]` from Swarm.
        2.  Dynamically instantiates the `Generable` struct (via JSON decoding or memberwise init via reflection).
        3.  Calls the underlying `FoundationModels.Tool`.
    *   **Output**: Unwraps `ToolOutput` to `SendableValue`.

#### B. `SwiftAgentToolAdapter` (Use SA Tool in FoundationModels)
Wraps a `Swarm.Tool` to work in `FoundationModels`.

*   **Strategy**: "Universal JSON Proxy"
*   **Implementation**:
    1.  Define a static wrapper struct:
        ```swift
        @Generable
        struct DynamicToolArguments {
            @Guide("A JSON string containing all arguments for the tool, matching its schema.")
            var json: String
        }
        ```
    2.  The Adapter exposes this single `DynamicToolArguments` struct to the Foundation Model.
    3.  **Prompt Engineering**: The adapter modifies the tool description seen by the model: 
        `"Original Description... NOTE: Provide all arguments as a single JSON string."`
    4.  **Execution**: 
        *   Receives `DynamicToolArguments(json: "{...}")`.
        *   Parses JSON to `[String: SendableValue]`.
        *   Calls the underlying `Swarm` tool.

### 3. Context & Registry Bridge
*   **Foundation Session**: When running in `FoundationModels`, the `LanguageModelSession` manages context. We need to ensure `Swarm` tools access this via the `AgentContext` bridge.
*   **Swarm Session**: When running in `Swarm`, we pass the `AgentContext` directly.

## Execution Plan

1.  **Core Protocol Update**: Modify `Swarm.Tool` signature.
2.  **Adapter Implementation**:
    *   Create `FoundationToolAdapter`.
    *   Create `SwiftAgentToolAdapter` (with `DynamicToolArguments` strategy).
3.  **Integration**:
    *   Update `FoundationModelsProvider` to support passing SA tools to the underlying session.
4.  **Verification**:
    *   Test: Use a native FM tool (e.g., "Summarize") inside a `ReActAgent`.
    *   Test: Use a SA tool (e.g., "WebSearch") inside a `FoundationModels` session.

## Research Findings (Confirmed)
*   **Protocol Name**: `Tool` (FoundationModels).
*   **Argument Type**: `@Generable` struct (Strict typing).
*   **Discovery**: Autonomous by `LanguageModelSession`.
