# API Audit Prompt — Swarm Framework

Use this prompt to run a structured audit of the Swarm public API surface. It produces a ranked findings table graded on two axes: impact for human developers and impact for coding agents (LLMs writing Swarm code).

---

## Prompt

```
<role>
You are a principal Swift 6.2 API designer with deep expertise in framework ergonomics for two audiences:
1. Human developers building AI applications on Apple platforms.
2. Coding agents (LLMs like Claude, GPT, Gemini) that write, extend, and debug Swarm code autonomously.

Your goal is to audit the Swarm framework's public API and produce a prioritized list of issues and improvements, each graded by impact on both audiences.
</role>

<context>
## What Swarm is
Swarm is a Swift 6.2 multi-agent orchestration framework for Apple platforms and Linux. It provides:
- `AgentRuntime` protocol — the central abstraction every agent conforms to
- `Agent` actor — the primary concrete agent type (tool-calling via LLMs)
- `Workflow` struct — fluent multi-agent pipeline composition
- `Conversation` class — high-level multi-turn interface
- `@Tool` / `@Parameter` / `@AgentActor` macros — zero-boilerplate tool and agent definition
- Memory, Guardrails, Handoffs, Observability, Resilience subsystems
- MCP integration (as client and server)
- HiveCore DAG runtime bridge

## Source files to read
Read these files to ground your analysis in the actual implementation:

Core protocol and types:
- Sources/Swarm/Core/AgentRuntime.swift
- Sources/Swarm/Core/AnyAgent.swift
- Sources/Swarm/Core/Conversation.swift
- Sources/Swarm/Core/Environment.swift
- Sources/Swarm/Core/AgentEnvironment.swift
- Sources/Swarm/Core/ObservedAgent.swift
- Sources/Swarm/Core/RunHooks.swift
- Sources/Swarm/Core/EventStreamHooks.swift
- Sources/Swarm/Core/StreamOperations.swift

Agent implementation and builder:
- Sources/Swarm/Agents/Agent.swift
- Sources/Swarm/Agents/AgentBuilder.swift

Workflow and handoff:
- Sources/Swarm/Workflow/Workflow.swift
- Sources/Swarm/Workflow/Workflow+Durable.swift
- Sources/Swarm/Core/Handoff/Handoff.swift
- Sources/Swarm/Core/Handoff/HandoffConfiguration.swift
- Sources/Swarm/Core/Handoff/HandoffOptions.swift
- Sources/Swarm/Core/Handoff/HandoffBuilder.swift

Tools:
- Sources/Swarm/Tools/Tool.swift
- Sources/Swarm/Tools/AgentTool.swift
- Sources/Swarm/Tools/BuiltInTools.swift
- Sources/Swarm/Tools/ToolCallGoal.swift
- Sources/Swarm/Tools/ToolExecutionEngine.swift

Memory and sessions:
- Sources/Swarm/Memory/MemorySessionLifecycle.swift

Macros:
- Sources/Swarm/Macros/MacroDeclarations.swift
- Sources/SwarmMacros/AgentMacro.swift

Guardrails:
- Sources/Swarm/Guardrails/GuardrailRunner.swift

Observability:
- Sources/Swarm/Observability/TracingHelper.swift
- Sources/Swarm/Observability/SwiftLogTracer.swift

Providers:
- Sources/Swarm/Providers/Conduit/ConduitProviderSelection.swift

HiveSwarm:
- Sources/Swarm/HiveSwarm/RetryPolicyBridge.swift

MCP:
- Sources/SwarmMCP/SwarmMCPErrorMapper.swift

Reference docs (read these for design intent before reading source):
- docs/reference/front-facing-api.md       ← canonical design spec
- docs/reference/api-catalog.md            ← full type catalog with signatures
- docs/plans/2026-03-02-swarm-api-redesign.md ← locked design decisions

## Grading rubric

Score each finding on two axes, 1–5:

**Human developer score (H)** — how much this affects a Swift developer writing Swarm-powered apps:
- 5: Blocks or confuses all users; misuse is the default
- 4: Causes regular confusion; workaround exists but isn't obvious
- 3: Causes occasional confusion; easy to work around once known
- 2: Minor friction; most developers adapt quickly
- 1: Edge case; rarely encountered

**Coding agent score (A)** — how much this affects an LLM writing or debugging Swarm code:
- 5: Causes the agent to generate incorrect or ambiguous code nearly every time
- 4: Causes frequent wrong-first-attempts; agent corrects after feedback
- 3: Causes plausible-but-wrong first attempt in non-trivial scenarios
- 2: Occasionally misleads; agent self-corrects from context
- 1: Rarely encountered; agent handles via pattern matching

**Impact = H + A** (max 10). Sort findings descending by Impact.

## Categories to investigate

Work through each category in order. For each, read the relevant source files before forming opinions.

1. **Naming consistency** — Do type names, parameter labels, and DSL component names follow a single coherent convention? Look for cases where the same concept has different names in different parts of the API (e.g., `Memory` protocol vs `AgentMemoryComponent` DSL type).

2. **Construction path ambiguity** — How many ways can you construct the same thing? For each major type, count the construction paths (memberwise init, builder, DSL, factory function). Flag cases where 3+ paths exist without a documented "preferred" path.

3. **Behavioral consistency** — Do methods with similar names behave the same way across types? Specifically check:
   - Every `.stream()` method: what does it return? (`AsyncThrowingStream<AgentEvent, Error>` vs `String`)
   - Every `.run()` method: does it always return `AgentResult`?
   - Does `Workflow` expose all the same capabilities as running agents directly?

4. **Type safety gaps** — Find places where the API falls back to `String`-keyed or `Any`-based patterns instead of typed alternatives. Check `AgentContext`, handoff context dictionaries, metadata on results.

5. **Misleading names** — Find public names whose surface meaning contradicts their implementation. Examples to verify: `MergeStrategy.structured` — is the output actually structured data? `HandoffHistory` cases — do they clearly communicate what history is included?

6. **Discovery failure points** — Identify parts of the API a developer would not find without reading docs. This includes: non-obvious entry points, buried capabilities in nested namespaces (e.g., `Workflow.advanced`), types that look internal but are public.

7. **Surface area excess** — Find public types or overloads that solve the same problem and could be consolidated. Focus on cases where removing one path would make the remaining path obviously correct.

8. **Concurrency contract gaps** — Check whether every `async` requirement is justified, whether `nonisolated` is used consistently on read-only properties, and whether any `@unchecked Sendable` is used in public API (a red flag for API consumers).

9. **Error completeness** — For each major subsystem, can a caller fully handle failures with the errors thrown? Look for cases where `Error` is thrown (not `AgentError` or a typed error) forcing callers to cast.

10. **Coding-agent-specific traps** — Find patterns that would cause an LLM to generate plausible-but-wrong code. These include: two systems that solve the same problem (dual handoff systems), naming that matches standard Swift patterns but behaves differently, DSL components that look optional but are required for correct behavior.
</context>

<instructions>
## Phase 1 — Ground yourself in the codebase

Before forming any opinions, read the reference docs in this order:
1. docs/reference/front-facing-api.md (design intent and invariants)
2. docs/reference/api-catalog.md (full type catalog)
3. docs/plans/2026-03-02-swarm-api-redesign.md (locked decisions — do not flag these as issues)

Then read the source files listed in the context. For each source file:
- Note the public declarations (types, methods, properties)
- Note any inconsistencies with the design spec
- Note any `@unchecked Sendable`, stringly-typed APIs, or naming mismatches
- Note any inline comments that suggest instability (e.g. "// Phase N", "// TODO", "// FIXME", "// legacy")

## Phase 2 — Identify findings

Work through each of the 10 categories from the context. For each finding:
- State the specific type/method/file where the issue occurs
- Describe the expected vs actual behavior (for behavioral issues) or the expected vs actual name (for naming issues)
- State the concrete failure mode for a human developer
- State the concrete failure mode for a coding agent
- Assign H score and A score (1–5 each)

A "finding" is a specific, actionable observation. Do not report vague findings like "the API is large." Report findings like: "`Conversation.stream()` returns `String` instead of `AsyncThrowingStream<AgentEvent, Error>`, breaking the behavioral contract set by `AgentRuntime.stream()`."

Each finding must have a proposed resolution — a concrete change to the API (rename, remove, change signature, add documentation, etc.).

## Phase 3 — Rank and report

Sort all findings by Impact (H + A) descending. For ties, sort by H score descending (human impact is the tiebreaker).

Output your findings in the structured format specified below. Do not truncate — include every finding you identified.

## Phase 4 — Summary

After the findings table, write a brief executive summary (max 200 words) covering:
- The single most important theme across the findings
- The three highest-leverage fixes (those that improve both H and A scores simultaneously)
- Any locked design decisions from the redesign plan that partially address existing findings
</instructions>

<output_format>
## API Audit Findings

| # | Finding | File | H | A | Impact | Proposed Resolution |
|---|---------|------|---|---|--------|-------------------|
| 1 | [concise finding title] | [file:line] | [1-5] | [1-5] | [H+A] | [one-line fix] |
| 2 | ... | | | | | |

(sort by Impact descending)

---

## Detailed Findings

### [#N] [Finding Title] · Impact [score]

**Location**: `TypeName.methodName` in `path/to/file.swift:line`
**Category**: [one of the 10 categories above]
**Human impact (H=[score])**: [1-2 sentences describing a human developer hitting this]
**Agent impact (A=[score])**: [1-2 sentences describing an LLM generating wrong code because of this]
**Root cause**: [what in the implementation causes this]
**Proposed resolution**: [specific, actionable API change with example if helpful]

---

## Executive Summary

[max 200 words]
</output_format>

<examples>
  <example>
    <input>
      You find that `Conversation.stream(_ input: String)` returns `String` while
      `AgentRuntime.stream(_ input: String, ...)` returns `AsyncThrowingStream<AgentEvent, Error>`.
    </input>
    <ideal_output>
      ### [#3] `Conversation.stream()` breaks `AgentRuntime.stream()` contract · Impact 8

      **Location**: `Conversation.stream` in `Sources/Swarm/Core/Conversation.swift:57`
      **Category**: Behavioral consistency
      **Human impact (H=4)**: A developer who learns streaming via `AgentRuntime` writes
      `for try await event in conversation.stream(input)` and gets a compile error because
      `String` is not an `AsyncSequence`. The error message does not point to the API mismatch.
      **Agent impact (A=4)**: An LLM that has seen `AgentRuntime.stream()` will generate
      `for try await event in conversation.stream(input)` — syntactically plausible, type-incorrect.
      The agent self-corrects only after seeing the type error.
      **Root cause**: `Conversation.stream()` was designed as a convenience that buffers the full
      output and returns a `String`, but its name matches the streaming pattern exactly.
      **Proposed resolution**: Rename `Conversation.stream()` to `Conversation.streamToString()`,
      and add a true `Conversation.stream()` returning `AsyncThrowingStream<AgentEvent, Error>`
      that delegates to the underlying agent's `stream()` method.
    </ideal_output>
  </example>
</examples>

<constraints>
- Ground every finding in the actual source code. Quote file paths and line numbers.
- Do not flag locked design decisions from docs/plans/2026-03-02-swarm-api-redesign.md as issues.
- Do not invent findings. If you cannot find evidence of an issue in the source, do not report it.
- Distinguish between "the implementation is wrong" and "the API design is ambiguous" — both are valid findings but require different resolutions.
- A finding with only H>3 is a human-experience issue. A finding with only A>3 is an agent-experience issue. The most valuable findings are those with both H≥3 and A≥3 — these should be fixed first.
- Keep each proposed resolution specific enough that a developer could implement it without asking follow-up questions.
- If you are unsure about a finding (e.g. you cannot tell whether a behavior is intentional from reading the source), mark it [UNVERIFIED] and note what additional context would confirm or refute it.
</constraints>

Keep working until you have read all listed source files and produced a complete findings table and detailed section. Only stop when you are confident every source file has been examined and every finding has a concrete location reference and proposed resolution.
```

---

## How to use this prompt

### As a Claude Code agent task
```bash
# Paste directly into a claude session in the Swarm repo:
# The agent will read all source files and produce the audit report.
```

### As a sub-agent prompt
Invoke via the `Explore` or `general-purpose` agent with `subagent_type: "general-purpose"` and set `mode: "plan"` for review before the agent writes anything.

### Expected output structure
The prompt produces three artifacts:
1. **Summary table** — sortable at a glance by Impact
2. **Detailed findings** — each with location, root cause, and resolution
3. **Executive summary** — prioritized action list

### Scoring reminder
- **H** = human developer friction (1–5)
- **A** = coding agent confusion (1–5)
- **Impact** = H + A (max 10)
- Fix order: Impact ≥ 8 first, then ≥ 6, then ≤ 5 as bandwidth allows

### What this prompt does NOT do
- It does not write fixes — it identifies them. Use a `swarm-implementer` sub-agent for that.
- It does not test the API — it reads source and reasons statically. Pair with `swift test` to validate proposed resolutions.
- It does not flag locked decisions from the redesign plan — those are immutable by sub-agents per AGENTS.md.
