Prompt:
Rename SwiftPM package/products/targets/macros for SwiftAgents → Swarm per the approved plan. Update only `Package.swift` and related manifest-level names.

Goal:
SwiftPM manifest reflects Swarm naming across package name, products, targets, dependencies, and build settings, with no Swift source edits.

Task Breakdown:
1. Update `Package.swift`:
   - Package name: `SwiftAgents` → `Swarm`.
   - Products:
     - `SwiftAgents` → `Swarm`.
     - `HiveSwiftAgents` → `HiveSwarm`.
     - `SwiftAgentsDemo` → `SwarmDemo`.
   - Targets:
     - `SwiftAgentsMacros` → `SwarmMacros`.
     - `SwiftAgents` → `Swarm`.
     - `SwiftAgentsTests` → `SwarmTests`.
     - `SwiftAgentsMacrosTests` → `SwarmMacrosTests`.
     - `HiveSwiftAgents` → `HiveSwarm`.
     - `HiveSwiftAgentsTests` → `HiveSwarmTests`.
     - `SwiftAgentsDemo` → `SwarmDemo`.
   - Internal manifest variable names:
     - `swiftAgentsDependencies` → `swarmDependencies`.
     - `swiftAgentsSwiftSettings` → `swarmSwiftSettings`.
   - Env var and define names:
     - `SWIFTAGENTS_*` → `SWARM_*` (including `SWARM_HIVE_RUNTIME` define).
2. Ensure target dependency lists refer to renamed targets/products.

Expected Output:
- `Package.swift` contains only Swarm names for package/products/targets/macros and `SWARM_*` env vars/defines.

Constraints:
- Do not edit any non-manifest files.
- Keep Swift 6.2 settings and platform versions unchanged.
- No backward-compatibility shims.
