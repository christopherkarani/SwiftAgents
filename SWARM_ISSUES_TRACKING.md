# Swarm Issues Tracking

> Short-form tracking document for project management.  
> See `SWARM_ISSUES_AUDIT.md` for full details.

---

## Quick Stats

| Metric | Count |
|--------|-------|
| 🔴 Critical (blocking) | 2 |
| 🟠 Major | 5 |
| 🟡 Medium | 6 |
| 🟢 Low | 1 |
| **Total** | **14** |

---

## Blocking Issues (Fix First)

| ID | Issue | File | Effort | Owner |
|----|-------|------|--------|-------|
| CRIT-001 | Platform version mismatch | Package.swift | Small | - |
| CRIT-002 | Foundation Models tool calling missing | LanguageModelSession.swift | Medium | - |

---

## Issue Checklist

### Critical
- [x] CRIT-001: Align platform requirements with dependencies (macOS 14→26)
- [x] CRIT-002: Implement or remove Foundation Models tool calling

### Major
- [ ] MAJ-001: Complete OrchestrationBuilder.swift or remove deprecated DSL
- [x] MAJ-002: Fix race condition in Agent.cancel()
- [x] MAJ-003: Resolve session/memory duplication
- [x] MAJ-004: Add tool name collision detection
- [x] MAJ-005: Fix handoff configuration lookup (type→identity)

### Medium
- [ ] MED-001: Review and reduce type erasure usage
- [x] MED-002: Deprecate redundant runtime mode enum cases
- [ ] MED-003: Split AgentConfiguration into focused structs
- [ ] MED-004: Replace global environment with explicit injection
- [x] MED-005: Fix retry policy attempt counting
- [ ] MED-006: Clarify Hive module architecture

### Low
- [ ] LOW-001: Split large files (>500 lines) into extensions

---

## Sprint Recommendations

### Sprint 1: Unblock
- CRIT-001: Fix build
- MAJ-004: Tool name validation
- MAJ-005: Handoff fix

### Sprint 2: Stability
- CRIT-002: Foundation Models
- MAJ-002: Cancellation race
- MAJ-003: Memory deduplication

### Sprint 3: Cleanup
- MAJ-001: DSL cleanup
- MED-002: Runtime mode deprecation
- LOW-001: File organization

### Sprint 4: Architecture
- MED-003: Configuration refactor
- MED-004: Dependency injection
- MED-006: Hive architecture

---

## Dependencies

```
CRIT-001 (build) unblocks all others
  ↓
MAJ-004, MAJ-005 (small fixes)
  ↓
CRIT-002, MAJ-002, MAJ-003 (larger changes)
  ↓
MAJ-001, MED-003 (API changes)
  ↓
MED-006 (architectural)
```

---

## Notes

- Total source: ~114K lines
- Total tests: ~5.6K lines  
- Ratio: 20:1 (concerning — consider adding tests with each fix)

*Last updated: 2026-02-13*
