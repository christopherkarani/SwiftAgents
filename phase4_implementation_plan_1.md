# Phase 4 Implementation Plan: Enhanced Handoffs & MultiProvider

## Overview

This phase implements enhanced agent handoff capabilities and multi-provider model routing to achieve parity with OpenAI's Swarm SDK. The implementation adds sophisticated handoff callbacks, input filtering, dynamic enablement checks, and a flexible provider routing system.

## Goals

1. **Enhanced Handoffs**: Implement comprehensive handoff configuration with callbacks, filters, and conditional execution
2. **MultiProvider**: Create a provider routing system that dispatches to different inference providers based on model name prefixes
3. **OpenAI Parity**: Match the Swarm SDK's handoff and provider capabilities

## Prerequisites

- Phase 1 (Guardrails) completed and tested
- Phase 2 (Streaming Events & RunHooks) completed and tested
- Phase 3 (Session & TraceContext) completed and tested
- Existing SwiftAgents codebase is stable

## Implementation Steps

### Step 1: Update Handoff Foundation (Estimated: 2-3 hours)

#### Files to Create
1. **`Sources/SwiftAgents/Orchestration/HandoffConfiguration.swift`**
   - Define `HandoffConfiguration` struct with all properties
   - Define `HandoffInputData` struct
   - Define `HandoffEvent` struct
   - Add convenience initializer

2. **`Sources/SwiftAgents/Orchestration/HandoffBuilder.swift`**
   - Implement fluent builder API for creating handoff configurations
   - Add validation logic
   - Create convenience `handoff()` function

#### Files to Modify
3. **`Sources/SwiftAgents/Orchestration/Handoff.swift`** (if exists)
   - Update to use new `HandoffConfiguration`
   - Ensure backward compatibility
   - Add migration guide in comments

#### Validation Criteria
- [ ] `HandoffConfiguration` compiles without errors
- [ ] Builder pattern works with fluent API
- [ ] Convenience function creates valid configurations
- [ ] All properties are properly `Sendable`

---

### Step 2: Implement Handoff Callbacks (Estimated: 2-3 hours)

#### Implementation Details

Create the callback system that allows users to hook into the handoff process:

1. **OnHandoff Callback**
   ```swift
   public typealias OnHandoffCallback = @Sendable (AgentContext, HandoffInputData) async throws -> Void
   ```

2. **Input Filter**
   ```swift
   public typealias InputFilterCallback = @Sendable (HandoffInputData) -> HandoffInputData
   ```

3. **Dynamic Enablement**
   ```swift
   public typealias IsEnabledCallback = @Sendable (AgentContext, any Agent) async -> Bool
   ```

#### Files to Modify
- **`Sources/SwiftAgents/Orchestration/HandoffConfiguration.swift`**
  - Integrate callback properties
  - Add execution logic placeholders

#### Validation Criteria
- [ ] Callbacks are properly typed and `Sendable`
- [ ] Async/await works correctly
- [ ] Error propagation is handled
- [ ] Thread safety is maintained

---

### Step 3: Integrate Handoffs with Orchestrator (Estimated: 3-4 hours)

#### Files to Modify
1. **`Sources/SwiftAgents/Orchestration/SwarmOrchestrator.swift`** (or relevant orchestrator)
   - Update `executeHandoff()` method to use new configuration
   - Invoke `onHandoff` callbacks
   - Apply `inputFilter` transformations
   - Check `isEnabled` before executing
   - Implement history nesting when `nestHandoffHistory` is true

2. **`Sources/SwiftAgents/Core/Agent.swift`**
   - Add `handoffs` property to Agent protocol
   - Provide default implementation

#### Implementation Tasks
- [ ] Execute `onHandoff` callback before handoff
- [ ] Apply `inputFilter` to transform data
- [ ] Check `isEnabled` to determine if handoff should execute
- [ ] Nest history when configured
- [ ] Emit handoff events
- [ ] Trigger RunHooks callbacks
- [ ] Handle errors gracefully

#### Validation Criteria
- [ ] Handoff callbacks execute in correct order
- [ ] Input filtering works correctly
- [ ] Dynamic enablement prevents execution when false
- [ ] History nesting preserves context properly
- [ ] Events are emitted
- [ ] Errors are properly propagated

---

### Step 4: Implement MultiProvider (Estimated: 3-4 hours)

#### Files to Create
1. **`Sources/SwiftAgents/Providers/MultiProvider.swift`**
   - Create `MultiProvider` actor
   - Implement provider registration
   - Add model name parsing logic
   - Implement provider resolution
   - Support all InferenceProvider methods

#### Key Implementation Details

**Provider Registration:**
```swift
// Example usage:
let multiProvider = MultiProvider(defaultProvider: openRouterProvider)
await multiProvider.register(prefix: "anthropic", provider: anthropicProvider)
await multiProvider.register(prefix: "openai", provider: openAIProvider)
await multiProvider.register(prefix: "google", provider: googleProvider)
```

**Model Name Resolution:**
```swift
// Model names with prefixes route to specific providers:
// "anthropic/claude-3-5-sonnet-20241022" -> AnthropicProvider
// "openai/gpt-4" -> OpenAIProvider
// "google/gemini-pro" -> GoogleProvider
// "claude-3-opus" -> Default provider
```

**Methods to Implement:**
- [ ] `init(defaultProvider:)`
- [ ] `register(prefix:provider:)`
- [ ] `unregister(prefix:)`
- [ ] `registeredPrefixes` property
- [ ] `generate()` with routing
- [ ] `generateWithToolCalls()` with routing
- [ ] `stream()` with routing
- [ ] `parseModelName()` helper
- [ ] `resolveProvider()` helper

#### Validation Criteria
- [ ] Provider registration works
- [ ] Model name parsing handles prefixes correctly
- [ ] Routing dispatches to correct provider
- [ ] Default provider is used when no prefix matches
- [ ] All InferenceProvider methods are supported
- [ ] Thread safety is maintained with actor

---

### Step 5: Add Provider Convenience Methods (Estimated: 1-2 hours)

#### Files to Modify
1. **`Sources/SwiftAgents/Providers/MultiProvider.swift`**
   - Add static factory methods for common configurations

#### Implementation Examples
```swift
public extension MultiProvider {
    /// Create with OpenRouter as default + Anthropic for specific models
    static func standardConfiguration(
        openRouterKey: String,
        anthropicKey: String
    ) -> MultiProvider {
        let multiProvider = MultiProvider.withOpenRouter(apiKey: openRouterKey)
        let anthropic = AnthropicProvider(apiKey: anthropicKey)
        await multiProvider.register(prefix: "anthropic", provider: anthropic)
        return multiProvider
    }
    
    /// Create with multiple providers pre-configured
    static func multiCloud(
        openRouterKey: String,
        anthropicKey: String,
        openAIKey: String
    ) -> MultiProvider {
        // Implementation
    }
}
```

#### Validation Criteria
- [ ] Factory methods create valid configurations
- [ ] Common use cases are covered
- [ ] Documentation is clear

---

### Step 6: Update Agent Configurations (Estimated: 1-2 hours)

#### Files to Modify
1. **`Sources/SwiftAgents/Core/Agent.swift`**
   - Add `handoffs` property with default empty array
   - Update documentation

2. **`Sources/SwiftAgents/Agents/AgentBuilder.swift`**
   - Add `handoffs()` builder method
   - Support adding individual handoffs
   - Support adding array of handoffs

#### Implementation Example
```swift
let agent = AgentBuilder()
    .name("SupportAgent")
    .handoffs([
        handoff(
            to: billingAgent,
            onHandoff: { context, data in
                print("Handing off to billing with: \(data.input)")
            },
            toolNameOverride: "transfer_to_billing",
            isEnabled: { context, agent in
                // Only enable during business hours
                return isBusinessHours()
            }
        )
    ])
    .build()
```

#### Validation Criteria
- [ ] Builder method works with fluent API
- [ ] Handoffs are properly stored
- [ ] Agent can access configured handoffs
- [ ] Documentation is comprehensive

---

### Step 7: Integration Testing (Estimated: 2-3 hours)

#### Test Files to Create
1. **`Tests/SwiftAgentsTests/Orchestration/HandoffConfigurationTests.swift`**
2. **`Tests/SwiftAgentsTests/Orchestration/HandoffIntegrationTests.swift`**
3. **`Tests/SwiftAgentsTests/Providers/MultiProviderTests.swift`**

#### Test Coverage Requirements

**HandoffConfiguration Tests:**
- [ ] Basic configuration creation
- [ ] Builder pattern construction
- [ ] Callback execution
- [ ] Input filtering
- [ ] Dynamic enablement
- [ ] History nesting

**Handoff Integration Tests:**
- [ ] Simple handoff execution
- [ ] Handoff with callbacks
- [ ] Handoff with input filter
- [ ] Conditional handoff (enabled/disabled)
- [ ] Nested history preservation
- [ ] Error handling during handoff
- [ ] Event emission verification

**MultiProvider Tests:**
- [ ] Provider registration
- [ ] Model name parsing
- [ ] Provider resolution with prefixes
- [ ] Default provider fallback
- [ ] Multiple provider routing
- [ ] All InferenceProvider methods
- [ ] Thread safety with concurrent calls

#### Example Test Structure
```swift
final class HandoffIntegrationTests: XCTestCase {
    func testHandoffWithCallback() async throws {
        var callbackExecuted = false
        
        let targetAgent = MockAgent(name: "Target")
        let sourceAgent = MockAgent(
            name: "Source",
            handoffs: [
                handoff(
                    to: targetAgent,
                    onHandoff: { context, data in
                        callbackExecuted = true
                        XCTAssertEqual(data.sourceAgentName, "Source")
                    }
                )
            ]
        )
        
        let orchestrator = SwarmOrchestrator(initialAgent: sourceAgent)
        _ = try await orchestrator.run("test input")
        
        XCTAssertTrue(callbackExecuted)
    }
}
```

---

### Step 8: Documentation (Estimated: 2-3 hours)

#### Documentation to Create/Update

1. **`Docs/Handoffs.md`**
   - Comprehensive handoff guide
   - Callback examples
   - Input filtering use cases
   - Dynamic enablement patterns
   - Best practices

2. **`Docs/MultiProvider.md`**
   - Provider routing guide
   - Model name conventions
   - Registration examples
   - Common configurations
   - Migration from single provider

3. **README.md Updates**
   - Add Phase 4 to completed features
   - Include quick examples
   - Link to detailed docs

4. **Code Documentation**
   - Add comprehensive DocC comments to all public APIs
   - Include usage examples in documentation
   - Document thread safety guarantees

#### Example Documentation Snippets

**Handoff with Callback:**
```swift
/// Hand off to billing agent with logging
let billingHandoff = handoff(
    to: billingAgent,
    onHandoff: { context, data in
        // Log the handoff for analytics
        await analytics.track("agent_handoff", [
            "from": data.sourceAgentName,
            "to": "Billing",
            "reason": data.metadata["reason"]
        ])
    },
    toolDescription: "Transfer customer to billing specialist"
)
```

**MultiProvider Setup:**
```swift
/// Configure multi-provider routing
let provider = MultiProvider(defaultProvider: openRouter)
await provider.register(prefix: "anthropic", provider: anthropicProvider)
await provider.register(prefix: "openai", provider: openAIProvider)

// Use in agent:
let agent = AgentBuilder()
    .provider(provider)
    .model("anthropic/claude-3-5-sonnet-20241022") // Routes to Anthropic
    .build()
```

---

### Step 9: Example Applications (Estimated: 2-3 hours)

#### Examples to Create

1. **`Examples/HandoffExample/`**
   - Multi-agent customer service example
   - Demonstrates callbacks, filters, and conditional handoffs
   - Shows history nesting

2. **`Examples/MultiProviderExample/`**
   - Agent that uses multiple providers
   - Cost optimization example (route to cheaper models)
   - Capability-based routing (use Claude for analysis, GPT-4 for creative)

#### Example Code Structure

```swift
// Examples/HandoffExample/CustomerServiceExample.swift

import SwiftAgents

@main
struct CustomerServiceExample {
    static func main() async throws {
        // Define specialized agents
        let billingAgent = AgentBuilder()
            .name("BillingAgent")
            .instructions("Help with billing questions")
            .build()
        
        let technicalAgent = AgentBuilder()
            .name("TechnicalAgent")
            .instructions("Provide technical support")
            .build()
        
        // Main agent with handoffs
        let frontlineAgent = AgentBuilder()
            .name("FrontlineAgent")
            .instructions("Route customers to the right specialist")
            .handoffs([
                handoff(
                    to: billingAgent,
                    onHandoff: { context, data in
                        print("📊 Routing to billing...")
                        // Could add metadata, log to analytics, etc.
                    },
                    inputFilter: { data in
                        var modified = data
                        modified.metadata["priority"] = .string("high")
                        return modified
                    },
                    isEnabled: { context, agent in
                        // Only during business hours
                        return isBusinessHours()
                    }
                ),
                handoff(to: technicalAgent)
            ])
            .build()
        
        // Execute
        let orchestrator = SwarmOrchestrator(initialAgent: frontlineAgent)
        let result = try await orchestrator.run("I have a billing question")
        print("Result: \(result.output)")
    }
}
```

---

## Testing Checklist

### Unit Tests
- [ ] HandoffConfiguration creation
- [ ] HandoffBuilder fluent API
- [ ] Callback type definitions
- [ ] MultiProvider registration
- [ ] Model name parsing
- [ ] Provider resolution

### Integration Tests
- [ ] End-to-end handoff execution
- [ ] Callback execution during handoff
- [ ] Input filter transformation
- [ ] Dynamic enablement checks
- [ ] History nesting
- [ ] MultiProvider routing in agent
- [ ] Error propagation

### Performance Tests
- [ ] Handoff overhead measurement
- [ ] MultiProvider routing latency
- [ ] Concurrent provider access
- [ ] Memory usage with multiple providers

---

## Migration Guide

### For Existing SwiftAgents Users

**Before (Simple Handoff):**
```swift
let agent = AgentBuilder()
    .name("Agent")
    .handoffTo(otherAgent)
    .build()
```

**After (Enhanced Handoff):**
```swift
let agent = AgentBuilder()
    .name("Agent")
    .handoffs([
        handoff(
            to: otherAgent,
            onHandoff: { context, data in
                // Custom logic
            }
        )
    ])
    .build()
```

**Provider Setup Before:**
```swift
let agent = AgentBuilder()
    .provider(anthropicProvider)
    .build()
```

**Provider Setup After (MultiProvider):**
```swift
let multiProvider = MultiProvider(defaultProvider: openRouter)
await multiProvider.register(prefix: "anthropic", provider: anthropicProvider)

let agent = AgentBuilder()
    .provider(multiProvider)
    .model("anthropic/claude-3-5-sonnet-20241022")
    .build()
```

---

## Rollout Plan

### Phase 4.1: Core Implementation (Week 1)
- Day 1-2: HandoffConfiguration and Builder
- Day 3-4: MultiProvider implementation
- Day 5: Integration and initial testing

### Phase 4.2: Integration & Polish (Week 2)
- Day 1-2: Orchestrator integration
- Day 3: Comprehensive testing
- Day 4-5: Documentation and examples

### Phase 4.3: Validation (Week 3)
- Day 1-2: Community testing
- Day 3-4: Bug fixes and refinements
- Day 5: Final review and release prep

---

## Success Criteria

### Functionality
- [ ] All handoff features work as specified
- [ ] MultiProvider routes correctly
- [ ] Callbacks execute reliably
- [ ] Input filtering transforms data
- [ ] Dynamic enablement controls execution
- [ ] History nesting preserves context

### Quality
- [ ] Test coverage > 85%
- [ ] No memory leaks
- [ ] Thread-safe under concurrent access
- [ ] Performance overhead < 5ms per handoff
- [ ] Zero compiler warnings

### Documentation
- [ ] All public APIs documented
- [ ] Usage examples provided
- [ ] Migration guide complete
- [ ] Best practices documented

### Compatibility
- [ ] Backward compatible with existing code
- [ ] Works with all provider types
- [ ] Integrates with existing orchestrators
- [ ] Compatible with iOS 17+, macOS 14+

---

## Risk Assessment

### High Risk
- **Actor isolation complexity**: MultiProvider uses actors, ensure thread safety
  - *Mitigation*: Comprehensive concurrent access tests
  
- **Callback error handling**: Errors in callbacks could break handoffs
  - *Mitigation*: Robust error boundaries and logging

### Medium Risk
- **Performance overhead**: Additional abstraction layers
  - *Mitigation*: Performance benchmarks and optimization
  
- **API complexity**: Many configuration options
  - *Mitigation*: Good defaults and clear documentation

### Low Risk
- **Breaking changes**: New features shouldn't break existing code
  - *Mitigation*: Maintain backward compatibility

---

## Dependencies

### Internal
- Phase 1: Guardrails (for integration)
- Phase 2: RunHooks (for callbacks)
- Phase 3: TraceContext (for tracing)
- Existing Agent and Orchestrator infrastructure

### External
- Swift 6.0+
- Foundation framework
- Actor isolation support

---

## Deliverables

1. ✅ HandoffConfiguration with full feature set
2. ✅ HandoffBuilder with fluent API
3. ✅ MultiProvider with routing
4. ✅ Orchestrator integration
5. ✅ Comprehensive test suite (>85% coverage)
6. ✅ Complete documentation
7. ✅ Example applications
8. ✅ Migration guide

---

## Post-Implementation

### Monitoring
- Track handoff execution metrics
- Monitor provider routing patterns
- Measure performance impact
- Collect user feedback

### Future Enhancements
- Visual handoff flow builder
- Advanced routing strategies (cost-based, capability-based)
- Handoff analytics dashboard
- Provider health monitoring
- Automatic failover between providers

---

## Timeline Summary

- **Total Estimated Time**: 18-24 hours
- **Recommended Sprint**: 2-3 weeks
- **Team Size**: 1-2 engineers
- **Review Points**: After Steps 4, 7, and 8

---

## Notes

- Maintain backward compatibility throughout
- Use existing SwiftAgents patterns and conventions
- Prioritize thread safety and actor isolation
- Keep public APIs simple and intuitive
- Document all public interfaces thoroughly
- Test edge cases extensively
