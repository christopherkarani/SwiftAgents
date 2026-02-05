Prompt:
Implement Phase 5 of `docs/plans/UNIFIED_AGENT_LONG_TERM_API_PLAN.md` (do not edit the plan doc): add a small parity/contract test kit that can run the same deterministic scenarios against legacy runtime agents and the unified runtime `Agent` configured to equivalent strategies. Focus on behavior, not implementation details.

Goal:
Prevent semantic drift during the multi-phase migration by locking in observable behavior parity across:
- legacy agents (`ReActAgent`, `ToolCallingAgent`, `ChatAgent`, `PlanAndExecuteAgent`)
- unified runtime `Agent` configured with `.react`, `.toolCalling`, `.chat`, `.planAndExecute`

Task Breakdown:
0) Likely files to touch (confirm with `rg` before editing):
   - New test harness:
     - `Tests/SwarmTests/TestKit/AgentParityHarness.swift`
   - New parity test suites:
     - `Tests/SwarmTests/Agents/UnifiedAgentParityTests.swift`
   - Existing mocks/helpers you should reuse:
     - `Tests/SwarmTests/Mocks/MockInferenceProvider.swift`
     - `Tests/SwarmTests/Mocks/MockTool.swift`
     - `Tests/SwarmTests/Mocks/MockAgentMemory.swift`
     - `Tests/SwarmTests/Agents/StreamingEventTests.swift` (as reference for event assertions)
1) Create a minimal parity harness (test-only):
   - Add a helper in tests (keep it internal to tests):
     - Suggested: `Tests/SwarmTests/TestKit/AgentParityHarness.swift`
   - The harness should:
     - accept a factory closure that returns `any AgentRuntime`,
     - run a scenario (input, optional session, hooks, tools, provider),
     - capture outputs and events (for streaming scenarios),
     - and return a lightweight snapshot struct for assertions.
2) Deterministic providers/tools for scenarios:
   - Reuse existing mocks:
     - `Tests/SwarmTests/Mocks/MockInferenceProvider.swift`
     - `Tests/SwarmTests/Mocks/MockTool.swift`
     - `Tests/SwarmTests/Mocks/MockAgentMemory.swift` (if needed)
   - Add new lightweight mocks only if required for streaming/cancellation determinism.
3) Scenarios to cover (minimum set from the plan):
   - Run output parity:
     - Same input -> same final output (or same normalized output) per equivalent strategy.
   - Iteration counts:
     - Ensure iterationCount matches (or matches within a defined, intentional strategy-specific tolerance).
   - Tool calls/results:
     - ToolCalling: tool calls happen via `generateWithToolCalls` and tool results are recorded.
     - ReAct: tool calls parsed/executed as before.
   - Guardrails:
     - Input and output tripwires are triggered consistently.
   - Sessions/memory:
     - Session history seeding and writeback behavior remains stable.
   - Streaming event shape:
     - Ensure key event types occur in the expected order (started/iterations/tool events/completed/error).
   - Cancellation:
     - Cancelling mid-stream/run results in consistent termination semantics.
4) Test suite organization:
   - Add a new suite, e.g.:
     - `Tests/SwarmTests/Agents/UnifiedAgentParityTests.swift`
   - Structure tests so they can run quickly and fail with clear diffs.
5) Execution:
   - Run `swift test` and ensure all tests are deterministic (no real network calls).

Expected Output:
- A reusable parity harness exists under `Tests/SwarmTests/TestKit/`.
- New parity tests cover the plan's required behaviors and run deterministically.
- The test suite prevents accidental behavioral drift between legacy agents and unified runtime `Agent`.

Constraints:
- Do NOT edit `docs/plans/UNIFIED_AGENT_LONG_TERM_API_PLAN.md`.
- Use Swift Testing (`import Testing`) only.
- Tests must be deterministic and avoid real inference providers/network calls.
- Prefer asserting on behavior (outputs/events) rather than internal implementation details.
