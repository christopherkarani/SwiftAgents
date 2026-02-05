Prompt:
You are a senior Swift 6.2 systems engineer. Produce an architecture mapping for Hive v1 that is grounded in the plan and makes dependencies, ownership boundaries, and data flows explicit. Keep it deterministic, type-safe, and concurrency-correct.

Goal:
Create a concise architecture map that shows how HiveCore, HiveCheckpointWax, HiveConduit, and HiveSwarm relate, with clear type/flow boundaries, key runtime invariants, and the minimal public APIs required for v1.

Task BreakDown:
- Inventory core types and modules from the plan, grouped by target (HiveCore, HiveCheckpointWax, HiveConduit, HiveSwarm), and list the public APIs that must exist for v1.
- Draw the execution flow for a single run (start -> step -> commit -> event emit -> checkpoint) and a resume flow (load checkpoint -> restore frontier -> continue), including where determinism is enforced.
- Map store layering (global vs task-local) and show how reducers and write application flow through a step; include where type-erasure is used and how type safety is preserved.
- Define event lifecycle ordering and where events are emitted (node start/finish, model token, tool invocation, checkpoint saved, interruption), including the stable sorting rules.
- Identify adapter boundaries and ownership: which types live in HiveCore vs adapter modules, and how the type-erased wrappers (AnyHiveModelClient, AnyHiveToolRegistry, AnyHiveCheckpointStore) are used.
- Capture concurrency boundaries (actor isolation, single-writer per threadID, bounded task execution) and list any potential race risks to watch for in implementation.
- Provide a dependency graph (textual is fine) and list any compile-time constraints (Sendable, Codable codecs, channel ID uniqueness) with where they are validated.
- Call out open questions/assumptions that must be resolved before implementation starts (e.g., Wax persistence layout, event payload redaction defaults).
