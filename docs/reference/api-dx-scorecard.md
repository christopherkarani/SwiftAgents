# Swarm API — Phase 2 DX Scorecard
Generated: 2026-03-05 | Framework: Swarm | Branch: finalPhase

## Scoring Methodology

**Human DX (H: 1-5)**: Discoverability, naming clarity, progressive disclosure
**Agent DX (A: 1-5)**: Can a coding agent pick the right API on first try?
**Combined DX** = (H x 2 + A x 8) / 10 — weighted 80% toward agent ergonomics

---

## Master Scorecard

| # | Subsystem | Category | H | A | Combined | Status |
|---|-----------|----------|---|---|----------|--------|
| 1 | Core | Data Types (SendableValue, TokenUsage, ToolCall) | 5 | 5 | **5.0** | Exemplary |
| 2 | Core | Core Execution (AgentRuntime, AgentResult, AgentEvent) | 4 | 4 | **4.0** | Good |
| 3 | Core | Errors (AgentError, ModelSettingsValidationError) | 4 | 4 | **4.0** | Good |
| 4 | MCP | MCP Client/Server (MCPClient, MCPServer, HTTPMCPServer) | 4 | 5 | **4.8** | Good |
| 5 | Memory | Simple Memories (ConversationMemory, SlidingWindowMemory) | 5 | 4 | **4.4** | Good |
| 6 | Memory | Core Memory Protocol (Memory, AnyMemory) | 4 | 4 | **4.0** | Solid |
| 7 | Memory | Token Estimation (TokenEstimator, MemoryMessage) | 4 | 4 | **4.0** | Clear |
| 8 | Memory | Diagnostics (all *Diagnostics structs) | 4 | 4 | **4.0** | Well-designed |
| 9 | Tools | Tool Creation (@Tool macro, FunctionTool) | 4 | 4 | **4.0** | Good |
| 10 | Tools | Tool Registry & Execution (ToolRegistry, ParallelToolExecutor) | 4 | 4 | **4.0** | Good |
| 11 | Tools | AgentTool & Agent Composition (asTool) | 4 | 4 | **4.0** | Good |
| 12 | Workflow | Workflow (fluent API, MergeStrategy) | 4 | 4 | **4.0** | Good |
| 13 | Handoff | Simple Handoff MVP (HandoffRequest, HandoffResult) | 5 | 5 | **5.0** | Exemplary |
| 14 | Core | Observability Hooks (AgentObserver, CompositeObserver) | 4 | 3 | **3.6** | Adequate |
| 15 | Handoff | Error Handling (WorkflowError, WorkflowValidationError) | 4 | 3 | **3.4** | Adequate |
| 16 | Tools | Tool Macros (@Tool, @Parameter expansion) | 4 | 3 | **3.4** | Adequate |
| 17 | Tools | Tool Composition & Chaining (ToolChain, ToolChainBuilder) | 4 | 3 | **3.4** | Adequate |
| 18 | Handoff | Configuration & Callbacks (HandoffBuilder, onTransfer) | 4 | 3 | **3.4** | Adequate |
| 19 | Memory | Persistent Storage (PersistentMemory, SwiftDataMemory) | 4 | 3 | **3.4** | Adequate |
| 20 | Core | Inference (InferenceProvider, InferenceOptions) | 4 | 3 | **3.4** | Adequate |
| 21 | Core | Configuration (AgentConfiguration, ModelSettings) | 3 | 3 | **3.0** | Needs Work |
| 22 | Core | Agents (Agent actor, AnyAgent, Conversation) | 3 | 3 | **3.0** | Needs Work |
| 23 | Core | Context & Environment (AgentContext, AgentEnvironment) | 3 | 3 | **3.0** | Needs Work |
| 24 | Memory | Vector & Semantic Search (VectorMemory, EmbeddingProvider) | 3 | 3 | **3.0** | Needs Work |
| 25 | Memory | Sessions (Session, InMemorySession) | 3 | 3 | **3.0** | Needs Work |
| 26 | Tools | Tool Parameter Definition (ToolParameter, ToolParameterBuilder) | 3 | 3 | **3.0** | Needs Work |
| 27 | Tools | Built-In Tools (DateTimeTool, StringTool, BuiltInTools) | 3 | 3 | **3.0** | Needs Work |
| 28 | Resilience | Resilience (RetryPolicy, CircuitBreaker, RateLimiter) | 3 | 3 | **3.0** | Needs Work |
| 29 | Providers | Streaming (ToolCallStreamingInferenceProvider) | 3 | 3 | **3.0** | Needs Work |
| 30 | Providers | Provider Selection (LLM, ConduitProviderSelection, MultiProvider) | 2 | 3 | **2.6** | Poor |
| 31 | Tools | Guardrails Integration (ToolInputGuardrail in tools) | 3 | 2 | **2.4** | Poor |
| 32 | Tools | Core Tool Types (Tool vs AnyJSONTool hierarchy) | 3 | 2 | **2.4** | Poor |
| 33 | Handoff | Modern API (HandoffOptions, HandoffPolicy) | 3 | 2 | **2.2** | Poor |
| 34 | Observability | Tracers (7 concrete tracer actors) | 3 | 2 | **2.2** | Poor |
| 35 | Core | Builder DSL (AgentBuilder, component types) | 2 | 2 | **2.0** | Hostile |
| 36 | Core | Conversation Management | 2 | 2 | **2.0** | Hostile |
| 37 | Core | Session/Handoff Integration | 2 | 2 | **2.0** | Hostile |
| 38 | Memory | Summarization (SummaryMemory, HybridMemory overlap) | 2 | 2 | **2.0** | Hostile |
| 39 | Memory | Composition (CompositeMemory, MemoryBuilder false APIs) | 2 | 2 | **2.0** | Hostile |
| 40 | Tools | Typed Tool Bridging (AnyJSONToolAdapter leak) | 2 | 2 | **2.0** | Hostile |
| 41 | Tools | Tool Execution Flow & Error Handling | 2 | 2 | **2.0** | Hostile |
| 42 | Guardrails | Guardrails (3 parallel hierarchies) | 2 | 2 | **2.0** | Hostile |
| 43 | Handoff | Type Erasure (AnyHandoffConfiguration) | 2 | 2 | **2.0** | Hostile |
| 44 | Integration | Wax Integration (WaxIntegration facade, WaxMemory) | 2 | 2 | **2.0** | Hostile |
| 45 | Handoff | Type Proliferation (11 types for one concept) | 1 | 1 | **1.0** | Critical |
| 46 | Integration | Membrane (6 public types, all internal-only) | 1 | 1 | **1.0** | Critical |
| 47 | HiveSwarm | HiveSwarm Bridge (GraphAgent, internal leaks) | 1 | 1 | **1.0** | Critical |

---

## Aggregate Scores by Subsystem

| Subsystem | Avg H | Avg A | Avg Combined | # Categories | Critical Issues |
|-----------|-------|-------|-------------- |-------------- |-----------------|
| **MCP** | 4.0 | 5.0 | 4.8 | 1 | None |
| **Workflow** | 4.0 | 4.0 | 4.0 | 1 | None |
| **Core** | 3.1 | 3.0 | 3.2 | 10 | Builder DSL, Conversation, Session gaps |
| **Memory** | 3.4 | 3.2 | 3.1 | 8 | Summarization overlap, Composition false APIs |
| **Tools** | 3.2 | 2.9 | 3.0 | 10 | Tool/AnyJSONTool confusion, bridging leaks |
| **Resilience** | 3.0 | 3.0 | 3.0 | 1 | No composition guidance |
| **Handoff** | 3.2 | 2.7 | 2.8 | 5 | 11 types for 1 concept, 3 competing APIs |
| **Providers** | 2.5 | 3.0 | 2.8 | 2 | 3 overlapping provider selection APIs |
| **Observability** | 3.0 | 2.0 | 2.2 | 1 | 7 tracer actors, MetricsCollector confusion |
| **Guardrails** | 2.0 | 2.0 | 2.0 | 1 | 3 parallel type hierarchies |
| **Integration** | 1.5 | 1.5 | 1.5 | 2 | Membrane/HiveSwarm internal leaks |

**Framework-Wide Average: 3.0 / 5.0 (Adequate — needs significant polish)**

---

## Distribution

```
5.0  [==]          2 categories  (4%)   — Exemplary
4.0+ [==========]  10 categories (21%)  — Good
3.0+ [==========]  12 categories (26%)  — Needs Work
2.0+ [==============] 14 categories (30%)  — Poor/Hostile
1.0  [===]          3 categories  (6%)   — Critical
```

- **Top quartile** (>= 4.0): 12 of 47 categories (26%)
- **Below threshold** (< 3.5): 23 of 47 categories (49%)
- **Critical** (< 2.0): 3 categories (6%)

---

## Top 10 Highest-Impact Findings

### 1. CRITICAL: Handoff Type Proliferation (Combined: 1.0)
**11 types for one concept.** Three competing APIs (HandoffBuilder, HandoffOptions, AnyHandoffConfiguration) with duplicated semantics. No single happy path.
- Files: `Core/Handoff/*.swift` (6 files)
- Fix: Unify to one builder. One-liner `agent.handoff(to: target)`.

### 2. CRITICAL: Membrane Integration Leak (Combined: 1.0)
**6 internal-only types exposed as public.** `MembraneFeatureConfiguration`, `MembraneAgentAdapter`, etc. are HiveSwarm bridge internals, not user-facing.
- Files: `Integration/Membrane/MembraneAgentAdapter.swift`
- Fix: Mark all `internal`. Expose zero Membrane types.

### 3. CRITICAL: HiveSwarm Bridge Leak (Combined: 1.0)
**GraphAgent is public but internally-constructed.** Users never instantiate it directly.
- Files: `HiveSwarm/ChatGraph.swift`, `HiveSwarm/GraphAgent.swift`
- Fix: Mark `internal` or provide factory-only API.

### 4. HIGH: Tool/AnyJSONTool Protocol Confusion (Combined: 2.4)
**Two parallel tool protocols** with unclear relationship. `Tool` (typed) vs `AnyJSONTool` (dynamic). `AnyJSONToolAdapter` leaks type erasure into public API.
- Files: `Tools/Tool.swift`, `Tools/TypedToolProtocol.swift`, `Tools/ToolBridging.swift`
- Fix: Make `Tool` primary, hide `AnyJSONTool` as internal. Auto-bridge in registry.

### 5. HIGH: Guardrail Parallel Hierarchies (Combined: 2.0)
**3 separate type families** (Input/Output/Tool guardrails) with Closure and Builder variants each. 20 types total.
- Files: `Guardrails/*.swift` (7 files)
- Fix: Unify with `Guardrail<Phase>` generic. One builder pattern.

### 6. HIGH: Provider Selection Confusion (Combined: 2.6)
**3 overlapping APIs:** `LLM`, `ConduitProviderSelection`, `MultiProvider`. Agents don't know which to use.
- Files: `Providers/Conduit/LLM.swift`, `Providers/Conduit/ConduitProviderSelection.swift`, `Providers/MultiProvider.swift`
- Fix: `LLM` is THE path. Deprecate `ConduitProviderSelection`.

### 7. HIGH: Tracer Proliferation (Combined: 2.2)
**7 concrete tracer actors** for one concern. ConsoleTracer, PrettyConsoleTracer, SwiftLogTracer, BufferedTracer, CompositeTracer, NoOpTracer, AnyTracer.
- Files: `Observability/AgentTracer.swift`, `Observability/ConsoleTracer.swift`, `Observability/SwiftLogTracer.swift`
- Fix: Keep 3 public (ConsoleTracer, SwiftLogTracer, CompositeTracer). Internalize rest.

### 8. HIGH: Memory Summarization Overlap (Combined: 2.0)
**3 memory types** (SummaryMemory, HybridMemory, CompositeMemory) solving the same problem differently. No guidance on which to choose.
- Files: `Memory/SummaryMemory.swift`, `Memory/HybridMemory.swift`, `Memory/MemoryBuilder.swift`
- Fix: Document clear use cases or consolidate into one configurable type.

### 9. MEDIUM: Configuration Duplication (Combined: 3.0)
**AgentConfiguration, ModelSettings, InferenceOptions** all have `temperature`, `maxTokens`. Unclear which is canonical.
- Files: `Core/AgentConfiguration.swift`, `Core/ModelSettings.swift`, `Core/AgentRuntime.swift`
- Fix: Single source of truth. ModelSettings is the canonical location.

### 10. MEDIUM: Builder DSL Weakness (Combined: 2.0)
**AgentBuilder exists but is disconnected from Agent.** No `Agent.builder()` method. Components are trivial wrappers with no validation.
- Files: `Agents/AgentBuilder.swift`
- Fix: Agent should have a `.init { }` builder pattern or `.builder()` factory.

---

## Subsystem-Level Recommendations

### Quick Wins (access control, < 1 hour each)
- [ ] Mark all Membrane types `internal` (-6 public types)
- [ ] Mark `GraphAgent` `internal` (-1 public type)
- [ ] Mark `AnyJSONToolAdapter` `internal` (-1 public type)
- [ ] Mark `MCPRequest`, `MCPResponse`, `MCPErrorObject` `internal` (-3 public types)
- [ ] Internalize `NoOpTracer`, `AnyTracer`, `BufferedTracer`, `PrettyConsoleTracer` (-4 public types)
- [ ] Internalize `MemorySessionLifecycle`, `MemoryPromptDescriptor` if unused (-2 public types)
- **Total: -17 public types with zero breaking changes for users**

### Medium Lifts (1-4 hours each)
- [ ] Deprecate `ConduitProviderSelection` in favor of `LLM`
- [ ] Unify guardrails with `Guardrail<Phase>` generic
- [ ] Consolidate Handoff APIs (deprecate HandoffOptions, keep HandoffBuilder)
- [ ] Document memory type selection guide
- [ ] Add `Agent { }` builder init

### Strategic Changes (4+ hours)
- [ ] Unify Tool/AnyJSONTool protocol hierarchy
- [ ] Consolidate configuration types (AgentConfiguration + ModelSettings + InferenceOptions)
- [ ] Redesign memory composition (remove false APIs, implement missing features)
- [ ] Add progressive disclosure tiers to all major entry points
