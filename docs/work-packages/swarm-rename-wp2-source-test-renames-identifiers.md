Prompt:
Perform repo-wide SwiftAgents → Swarm renames for source/test/demo directories and code identifiers/imports. Follow the approved plan; no compatibility shims.

Goal:
All Swift sources, tests, and demo code compile against `Swarm`/`SwarmMacros`/`HiveSwarm` with updated identifiers and strings.

Task Breakdown:
1. Rename directories (git mv):
   - `Sources/SwiftAgents` → `Sources/Swarm`
   - `Sources/SwiftAgentsMacros` → `Sources/SwarmMacros`
   - `Sources/SwiftAgentsDemo` → `Sources/SwarmDemo`
   - `Sources/HiveSwiftAgents` → `Sources/HiveSwarm`
   - `Tests/SwiftAgentsTests` → `Tests/SwarmTests`
   - `Tests/SwiftAgentsMacrosTests` → `Tests/SwarmMacrosTests`
   - `Tests/HiveSwiftAgentsTests` → `Tests/HiveSwarmTests`
2. Rename key files to match modules/namespaces:
   - `Sources/Swarm/SwiftAgents.swift` → `Sources/Swarm/Swarm.swift`
   - `Sources/Swarm/Core/Logger+SwiftAgents.swift` → `Sources/Swarm/Core/Logger+Swarm.swift`
   - `Sources/HiveSwarm/SwiftAgentsToolRegistry.swift` → `Sources/HiveSwarm/SwarmToolRegistry.swift`
3. Update Swift code identifiers and imports:
   - `import SwiftAgents` → `import Swarm`
   - `@testable import SwiftAgents` → `@testable import Swarm`
   - `import SwiftAgentsMacros` → `import SwarmMacros`
   - `#if canImport(SwiftAgentsMacros)` → `#if canImport(SwarmMacros)`
   - `public enum SwiftAgents` → `public enum Swarm`
   - `SwiftAgentsToolRegistry` → `SwarmToolRegistry`
   - `SwiftAgentsToolRegistryError` → `SwarmToolRegistryError`
   - `SwiftAgentsMacrosPlugin` → `SwarmMacrosPlugin`
   - Update macro declarations to reference module `"SwarmMacros"`.
4. Update string literals and identifiers mentioning SwiftAgents:
   - Logger labels / subsystem strings (legacy `com.*` values) → `com.swarm.*`
   - MCP client info name `"SwiftAgents"` → `"Swarm"`
   - Provider appName `"SwiftAgents"` → `"Swarm"`
   - Any demo output strings mentioning SwiftAgents → Swarm
   - Any lowercase legacy product identifiers → `"swarm"` where they are product identifiers
5. Fix any path references in tests that include old folder names.

Expected Output:
- All Swift sources/tests import `Swarm`/`SwarmMacros` and reference `HiveSwarm` types.
- No Swift source contains legacy product names or legacy env var prefixes.

Constraints:
- No backward-compatibility typealiases or shims.
- Keep behavior unchanged aside from naming.
