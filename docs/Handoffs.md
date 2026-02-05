# Enhanced Agent Handoffs

Swarm provides a powerful handoff system for transferring control between agents with full observability and customization.

## Overview

Agent handoffs enable multi-agent workflows where one agent can delegate work to another. The enhanced handoff system adds:

- **Callbacks**: Execute code before handoffs occur
- **Input Filters**: Transform data being passed between agents
- **Dynamic Enablement**: Conditionally enable/disable handoffs at runtime
- **Observability Events**: Track handoff lifecycle for debugging and monitoring

## Quick Start

```swift
import Swarm

// Create a handoff configuration
let config = handoff(
    to: executorAgent,
    toolName: "execute_task",
    onHandoff: { context, data in
        print("Handing off to \(data.targetAgentName)")
    }
)

// Use in an agent
let agent = ReActAgent {
    Instructions("Coordinator agent")
    HandoffsComponent(config)
}
```

## HandoffConfiguration

The `HandoffConfiguration<Target>` struct defines how an agent hands off to a specific target:

```swift
public struct HandoffConfiguration<Target: Agent>: Sendable {
    /// The agent to hand off to
    public let targetAgent: Target

    /// Custom tool name for this handoff (optional)
    public let toolNameOverride: String?

    /// Description for the handoff tool (optional)
    public let toolDescription: String?

    /// Callback invoked before handoff execution
    public let onHandoff: OnHandoffCallback?

    /// Filter to transform input data
    public let inputFilter: InputFilterCallback?

    /// Callback to check if handoff is enabled
    public let isEnabled: IsEnabledCallback?

    /// Whether to nest handoff history
    public let nestHandoffHistory: Bool
}
```

## Creating Handoff Configurations

### Using the `handoff()` Function

The `handoff()` function provides a convenient way to create configurations:

```swift
let config = handoff(
    to: targetAgent,
    toolName: "transfer_to_specialist",
    toolDescription: "Hand off to the specialist for complex tasks",
    onHandoff: { context, data in
        // Pre-handoff logic
    },
    inputFilter: { data in
        // Transform the input
        return data
    },
    isEnabled: { context, agent in
        // Dynamic enablement check
        return true
    }
)
```

### Using HandoffBuilder

For more control, use the fluent builder:

```swift
let config = HandoffBuilder(to: targetAgent)
    .toolName("my_handoff")
    .toolDescription("Detailed description")
    .onHandoff { context, data in
        await context.set("handoff_count", value: .int(1))
    }
    .inputFilter { data in
        var modified = data
        modified.metadata["timestamp"] = .double(Date().timeIntervalSince1970)
        return modified
    }
    .isEnabled { context, agent in
        await context.get("ready")?.boolValue ?? false
    }
    .build()
```

## Callback Types

### OnHandoffCallback

Executed just before the handoff occurs. Use for logging, side effects, or context updates:

```swift
public typealias OnHandoffCallback = @Sendable (AgentContext, HandoffInputData) async throws -> Void
```

> **Note**: Errors thrown from this callback are logged but do **not** abort the handoff. For validation that should prevent handoffs, use `IsEnabledCallback` instead.

Example:
```swift
onHandoff: { context, data in
    // Log the handoff
    Log.agents.info("Handoff: \(data.sourceAgentName) -> \(data.targetAgentName)")

    // Update context before handoff
    await context.set("last_handoff_to", value: .string(data.targetAgentName))
    await context.set("handoff_timestamp", value: .double(Date().timeIntervalSince1970))
}
```

### InputFilterCallback

Transforms the handoff data before it reaches the target agent:

```swift
public typealias InputFilterCallback = @Sendable (HandoffInputData) -> HandoffInputData
```

Example:
```swift
inputFilter: { data in
    var modified = data

    // Add metadata
    modified.metadata["priority"] = .string("high")
    modified.metadata["source"] = .string(data.sourceAgentName)

    // Transform input
    modified.input = "Context: \(data.context)\n\nTask: \(data.input)"

    return modified
}
```

### IsEnabledCallback

Dynamically enables or disables the handoff based on runtime conditions:

```swift
public typealias IsEnabledCallback = @Sendable (AgentContext, any AgentRuntime) async -> Bool
```

Example:
```swift
isEnabled: { context, targetAgent in
    // Check feature flag
    guard await context.get("handoffs_enabled")?.boolValue == true else {
        return false
    }

    // Check target agent health
    // ... custom logic

    return true
}
```

## HandoffInputData

Data passed to handoff callbacks:

```swift
public struct HandoffInputData: Sendable, Equatable {
    /// Name of the source agent
    public let sourceAgentName: String

    /// Name of the target agent
    public let targetAgentName: String

    /// Input being passed to target
    public var input: String

    /// Context dictionary
    public let context: [String: SendableValue]

    /// Mutable metadata (can be modified in inputFilter)
    public var metadata: [String: SendableValue]
}
```

## Using Handoffs in Agents

### With AgentBuilder DSL

```swift
let agent = ReActAgent {
    Instructions("Coordinator that delegates tasks")

    Tools {
        AnalysisTool()
    }

    HandoffsComponent(
        handoff(to: researchAgent),
        handoff(to: writerAgent),
        handoff(to: reviewerAgent, isEnabled: { ctx, _ in
            await ctx.get("draft_ready")?.boolValue ?? false
        })
    )
}
```

### With Builder Pattern

```swift
let agent = ReActAgent.Builder()
    .instructions("Coordinator")
    .handoffs([
        AnyHandoffConfiguration(handoff(to: agent1)),
        AnyHandoffConfiguration(handoff(to: agent2))
    ])
    .build()
```

## Handoff Events

Track handoff lifecycle through `AgentEvent`:

```swift
for try await event in agent.stream(input) {
    switch event {
    case .handoffStarted(let from, let to, let input):
        print("Started: \(from) -> \(to)")

    case .handoffCompletedWithResult(let from, let to, let result):
        print("Completed with output: \(result.output)")

    case .handoffSkipped(let from, let to, let reason):
        print("Skipped: \(reason)")

    default:
        break
    }
}
```

## Orchestrator Integration

Orchestrators (SupervisorAgent, SequentialChain, AgentRouter) automatically apply handoff configurations:

```swift
let supervisor = SupervisorAgent(
    agents: [
        (name: "math", agent: mathAgent, description: mathDesc),
        (name: "writer", agent: writerAgent, description: writerDesc)
    ],
    routingStrategy: LLMRoutingStrategy(inferenceProvider: provider),
    handoffs: [
        AnyHandoffConfiguration(handoff(
            to: mathAgent,
            onHandoff: { ctx, data in
                Log.orchestration.info("Routing to math agent")
            }
        ))
    ]
)
```

## Type Erasure with AnyHandoffConfiguration

When storing heterogeneous handoff configurations, use `AnyHandoffConfiguration`:

```swift
let configs: [AnyHandoffConfiguration] = [
    AnyHandoffConfiguration(handoff(to: agentA)),
    AnyHandoffConfiguration(handoff(to: agentB)),
    AnyHandoffConfiguration(handoff(to: agentC))
]

// Access type-erased properties
for config in configs {
    print("Target: \(type(of: config.targetAgent))")
    print("Tool name: \(config.effectiveToolName)")
}
```

## Error Handling

When `isEnabled` returns `false`, handoffs throw `OrchestrationError.handoffSkipped`:

```swift
do {
    let result = try await coordinator.executeHandoff(request, context: context)
} catch OrchestrationError.handoffSkipped(let from, let to, let reason) {
    print("Handoff \(from) -> \(to) was skipped: \(reason)")
}
```

Errors thrown from `onHandoff` callbacks are logged but do not abort the handoff by default.

## Best Practices

1. **Keep callbacks lightweight**: Avoid heavy computation in handoff callbacks
2. **Use inputFilter for data transformation**: Don't modify context in inputFilter
3. **Use isEnabled for authorization**: Check permissions and feature flags
4. **Log handoffs for debugging**: Use onHandoff for observability
5. **Handle errors gracefully**: Wrap handoff calls in do-catch blocks

## Thread Safety

All handoff types are `Sendable` and safe to use across actor boundaries. The callback closures must also be `@Sendable`.
