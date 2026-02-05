# Conduit Fix Plan (Swarm)

Status: In progress
Owner: Orchestrator
Date: 2026-02-01

## Goal

Fix correctness + usability gaps in the Conduit bridge:

1. Tool-call streaming should work when users configure providers via `ConduitProviderSelection` (not only via `LLM`).
2. `InferenceOptions.topK` must be forwarded into Conduit `GenerateConfig.topK` for Conduit-backed providers.
3. (Hardening) Only apply `toolChoice` when tools are non-empty, to avoid invalid provider configs when `generateWithToolCalls` is called directly.

## Context (Current Behavior)

- `ToolCallingAgent` uses live tool-call streaming only when the configured provider downcasts to `ToolCallStreamingInferenceProvider`.
  - `Sources/Swarm/Agents/ToolCallingAgent.swift:353`
- `LLM` forwards tool-call streaming.
  - `Sources/Swarm/Providers/Conduit/LLM.swift:111`
- `ConduitProviderSelection` currently does not forward tool-call streaming, so streaming is silently disabled if users pass `.openAI/.anthropic/.openRouter/...` via `ConduitProviderSelection`.
  - `Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift:11`
- `InferenceOptions.topK` exists but is not applied in the Conduit bridge.
  - `Sources/Swarm/Core/Agent.swift:309`
  - `Sources/Swarm/Providers/Conduit/ConduitInferenceProvider.swift:132`

## Test-Driven Deliverables

Add Swift Testing coverage for:

1. Agent behavior: wrapping a streaming-capable provider in `ConduitProviderSelection` still enables tool-call streaming in `ToolCallingAgent.stream(...)`.
2. Conduit config mapping: `InferenceOptions.topK` is applied to Conduit `GenerateConfig` for generation.
3. (Hardening) `toolChoice` is not applied when tools are empty.

## Implementation Deliverables

1. `ConduitProviderSelection` conforms to `ToolCallStreamingInferenceProvider` and forwards `streamWithToolCalls(...)` to the underlying provider when supported (mirrors `LLM` behavior).
2. `ConduitInferenceProvider.apply(options:to:)` maps `InferenceOptions.topK` into Conduit config.
3. (Hardening) Gate `toolChoice` application on `!tools.isEmpty` in both `generateWithToolCalls` and `streamWithToolCalls`.

## Constraints

- This document is treated as immutable by sub-agents. Sub-agents must not edit it.
- Follow strict TDD: tests fail first, then minimal implementation, then refactor.

