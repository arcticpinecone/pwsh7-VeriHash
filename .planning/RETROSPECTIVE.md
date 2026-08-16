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

## Milestone: v2.0 — Modular Rebuild

**Shipped:** 2026-04-19
**Phases:** 5 | **Plans:** 15 | **Requirements:** 38/38
**Duration:** 2 days (2026-04-18 → 2026-04-19)

### What Was Built
- Three-module architecture: `VeriHash.Core` (hash, clipboard, sidecar, format, log, platform), `VeriHash.HotPath` (parallel PE signature, batch, tally), `VeriHash.Manifest` (GNU sha256sum create/verify)
- 196-line thin CLI dispatcher replacing 1,527-line monolith
- P/Invoke WinVerifyTrust for PE-only Authenticode with ThreadJob parallelism
- Multi-file batch mode with byte-locked tally
- Manifest mode with atomic writes, path-traversal guard, machine-readable exit codes (0/1/2/3)
- Full cleanup: VirusTotal removed, PSFramework removed, QuickHash + LogUtils retired
- README and CHANGELOG rewritten for v2 architecture

### What Worked
- **Coarse phases** — Compressing 9 user-sketched phases into 5 dependency-ordered phases was the right call; each had clear boundaries and the dependency graph prevented integration conflicts
- **TDD caught real bugs** — "Never modify tests to pass" surfaced a real bug in `Format-VeriHashReport` (`.Status` vs `.Sidecar` property name) and clipboard contamination in batch tests
- **Module isolation** — Three separate modules with clean public APIs made testing straightforward; each testable in isolation via `Import-Module`
- **Audit-before-close** — Milestone audit caught 4 tech debt items that would have been embarrassing in the archive

### What Was Inefficient
- **Plan 05-02 checkbox drift** — ROADMAP showed `[ ] 05-02-PLAN.md` despite CLI tests being written and passing; fixed during tech debt pass but shouldn't have been necessary
- **Quick task state tracking** — The `260418-rename-log-jsonl` false positive from `audit-open` shows v1-era quick tasks don't cleanly survive milestone transitions

### Patterns Established
- `Import-Module` loading in all tests (no dot-source hack)
- Plain-text `Write-VeriHashLog` replacing PSFramework logging
- `Get-VeriHashPlatform` as single-source platform detection
- ThreadJob parallelism for hash + signature with explicit cleanup
- GNU sha256sum format validation via WSL round-trip
- `Format.ps1xml` with `FormatsToProcess` in module manifests

### Key Lessons
1. **P/Invoke for Windows APIs is viable** in PowerShell modules — WinVerifyTrust shim was cleaner and faster than `Get-AuthenticodeSignature`
2. **ThreadJob parallelism is easy to add** but clipboard/environment contamination between jobs needs explicit cleanup
3. **GNU sha256sum interop via WSL** is a strong validation for standards compliance
4. **Tick checkboxes as you go** — still not automated; same lesson from v1.0

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | 1 | 3 | Established GSD workflow, CI pipeline, privacy compliance |
| v2.0 | 1 | 5 | Full modular rebuild, three-module architecture, monolith eliminated |

### Cumulative Quality

| Milestone | Tests | Skipped | Prod LOC | Test LOC |
|-----------|-------|---------|----------|----------|
| v1.0 | 133 | 8 | ~2,000 (monolith) | ~1,200 |
| v2.0 | 176 | 5 | 2,039 (3 modules) | 1,817 |

### Top Lessons (Verified Across Milestones)

1. Treat documentation as spec — fix code to match, not the other way around
2. Ship CI early — automated validation saves manual re-checking on every subsequent change
3. Tick checkboxes as you go — waiting creates unnecessary remediation at audit time (repeated v1.0 → v2.0)
4. Module isolation pays off — clean APIs make testing straightforward and integration predictable
