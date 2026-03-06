# API Reference

The complete API reference covers every public type, protocol, and API in the Swarm framework.

## Complete Reference

The **[Complete API Reference](/swarm-complete-reference)** is a single document covering all 15 subsystems:

1. **Overview & Architecture** — What Swarm is, layer diagram, platform requirements
2. **Quick Start** — Minimal working example
3. **Agents** — All agent types, `AgentRuntime` protocol, configuration
4. **Tools** — `@Tool` macro, `FunctionTool`, tool chaining, parallel execution
5. **DSL & Blueprints** — `AgentBlueprint`, `OrchestrationBuilder`, modifiers
6. **Orchestration** — All 11 step types, operators, context
7. **Handoffs & Routing** — `HandoffConfiguration`, `SupervisorAgent`, routing
8. **Memory** — All memory types, sessions, backends, embeddings
9. **Guardrails** — Input/output/tool guardrails, tripwire modes
10. **Resilience** — Retry, circuit breaker, fallback, timeout
11. **Observability** — Tracers, trace events, spans, metrics
12. **MCP Integration** — Client and server
13. **Providers** — LLM providers, MultiProvider, Foundation Models
14. **Macros** — `@Tool`, `@Parameter`, `@AgentActor`, `@Traceable`, `#Prompt`, `@Builder`
15. **Hive Runtime** — DAG compilation, checkpointing, resume

## By Topic

| Topic | Description |
|---|---|
| [Agents](/agents) | Agent types, configuration, `@AgentActor` macro |
| [Tools](/tools) | `@Tool` macro, `FunctionTool`, runtime toggling |
| [DSL & Blueprints](/dsl) | `AgentBlueprint`, `@OrchestrationBuilder`, modifiers |
| [Orchestration](/orchestration) | DAG, parallel, chains, human-in-the-loop |
| [Handoffs](/Handoffs) | Agent handoffs, routing, `SupervisorAgent` |
| [Memory](/memory) | Conversation, Vector, Summary, SwiftData backends |
| [Streaming](/streaming) | `AgentEvent` streaming, SwiftUI integration |
| [Guardrails](/guardrails) | Input/output validation, tripwires |
| [Resilience](/resilience) | Retry, circuit breakers, fallback, timeouts |
| [Observability](/observability) | Tracing, `OSLogTracer`, `SwiftLogTracer`, metrics |
| [MCP](/mcp) | Model Context Protocol client and server |
| [Providers](/providers) | Inference providers, `MultiProvider` routing |
| [Hive Swarm Hardening](/hive-swarm-nonfork-hardening) | Non-fork run control, checkpoint capability, deterministic transcript/state hashing |
