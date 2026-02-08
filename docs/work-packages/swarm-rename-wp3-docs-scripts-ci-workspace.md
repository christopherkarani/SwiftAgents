Prompt:
Update documentation, scripts, CI, and workspace/playground references from SwiftAgents → Swarm per the approved plan.

Goal:
All non-source artifacts reflect Swarm naming and new GitHub repo URL.

Task Breakdown:
1. Rename workspace and playground:
   - `SwiftAgents.xcworkspace` → `Swarm.xcworkspace`
   - `Sources/SwiftAgentsDemo/SwiftAgentsPlayground.playground` → `Sources/SwarmDemo/SwarmPlayground.playground`
   - Update `Swarm.xcworkspace/contents.xcworkspacedata` to new playground path.
2. Update docs and guides:
   - Replace `SwiftAgents` with `Swarm` in `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/**`, `HIVE_V1_PLAN.md`, and plan/work-package docs.
   - Update all repo URLs to `https://github.com/christopherkarani/Swarm` (and `.git` variants).
   - Update env var names to `SWARM_*`.
3. Update scripts:
   - `scripts/generate-coverage-report.sh` strings and test binary names to `Swarm*`.
   - `scripts/README.md` title and references.
4. Update CI and templates:
   - `.github/workflows/swift.yml` header/name references to Swarm.
   - `.github/pull_request_template.md` references/paths to Swarm.

Expected Output:
- Docs, scripts, CI, and workspace artifacts contain only Swarm naming and new repo URL.

Constraints:
- No code behavior changes.
- Keep instructions accurate to new paths/targets.
