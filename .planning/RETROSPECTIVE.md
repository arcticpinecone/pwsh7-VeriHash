# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — Privacy + Foundation

**Shipped:** 2026-04-18
**Phases:** 3 | **Plans:** 6

### What Was Built
- Privacy-compliant logging: hash truncation + path sanitization across all modules
- GitHub Actions CI pipeline: Pester cross-platform + PSScriptAnalyzer on all 3 files
- PSFramework log rotation with 30-day retention
- VirusTotal default flipped to disabled; logging guide updated to match reality

### What Worked
- **Guide-as-contract approach** — treating the logging concepting doc as the spec and fixing code to match gave clear, auditable acceptance criteria
- **CI before features** — shipping the pipeline in Phase 2 meant Phase 3 changes were auto-validated
- **Grouping LOGC-02 with Phase 1** — shared dot-source reordering avoided a second round of module restructuring
- **Milestone audit before completion** — caught checkbox drift and missing validation artifacts proactively

### What Was Inefficient
- **Checkbox drift** — requirements and roadmap checkboxes weren't ticked as phases completed, requiring a bulk fix at audit time
- **No VERIFICATION.md during execution** — all 3 had to be generated retroactively; should be part of phase completion
- **PSFramework silent skip** — discovered during UAT that tests silently skip when PSFramework absent; this should have been caught earlier in the process

### Patterns Established
- Dot-source order convention: `LogUtils → Config → VeriHash.ps1` (utility-first)
- `ConvertTo-SanitizedPath` as the single sanitization entry point for all log payloads
- `$script:PSFrameworkAvailable` as the canonical guard variable (set once, checked everywhere)
- PSScriptAnalyzer settings: `PSAvoidUsingWriteHost` + `PSAvoidUsingBrokenHashAlgorithms` suppressed project-wide
- CI matrix: `fail-fast: false` + Pester `MaximumVersion 5.99` pinning

### Key Lessons
1. **Tick checkboxes as you go** — waiting until audit creates unnecessary remediation work
2. **Generate VERIFICATION.md during plan execution**, not as a retroactive gap-fill
3. **Optional dependencies need visibility** — PSFramework's graceful degradation is good, but users should know what they're missing (logged as Backlog 999.1)
4. **Single-day milestones are viable** when scope is tight and well-defined — 3 phases, 6 plans, 44 commits in one session

### Cost Observations
- Sessions: 1 (single continuous session)
- Notable: Entire milestone from planning through archival in one session; retroactive audit/validation added ~30% overhead that could be eliminated with inline completion checks

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | 1 | 3 | Established GSD workflow, CI pipeline, privacy compliance |

### Cumulative Quality

| Milestone | Tests | Skipped | Lint Files |
|-----------|-------|---------|------------|
| v1.0 | 133 | 8 | 3/3 |

### Top Lessons (Verified Across Milestones)

1. Treat documentation as spec — fix code to match, not the other way around
2. Ship CI early — automated validation saves manual re-checking on every subsequent change
