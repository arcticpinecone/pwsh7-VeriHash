# Roadmap: VeriHash — Privacy + Foundation

## Overview

Close the audit gaps between the privacy-first logging guide and actual code, then lock in compliance with a CI/CD safety net. Three phases: fix what's broken, automate the guard rails, bundle the remaining small wins.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Privacy & Logging Compliance** - Fix all privacy violations so log output matches the logging guide's contract
- [ ] **Phase 2: CI/CD Pipeline** - Automate test and lint on every push/PR so compliance can't regress
- [ ] **Phase 3: Small Wins & Baseline Lock** - Close remaining audit items (log rotation, VT default) under CI protection

## Phase Details

### Phase 1: Privacy & Logging Compliance
**Goal**: All log output complies with the privacy-first logging guide — no full hashes, no raw paths, single bootstrap
**Depends on**: Nothing (first phase)
**Requirements**: PRIV-01, PRIV-02, PRIV-03, PRIV-04, LOGC-02
**Success Criteria** (what must be TRUE):
  1. Running VeriHash with PSFramework produces log entries where hash values are truncated to 16 chars + `...` — full hashes never appear in any log output
  2. Config operations with PSFramework produce log entries where all file paths pass through `ConvertTo-SanitizedPath` — no raw user paths in logs
  3. `ConvertTo-SanitizedPath` is defined in `VeriHash.LogUtils.ps1` and callable from Config, main script, and any future module (dot-source order: LogUtils → Config → VeriHash)
  4. PSFramework bootstrap detection (`$script:PSFrameworkAvailable`) is set exactly once across all modules — no redundant `Get-Module -ListAvailable` calls
  5. `Verihash Logging Concepting.md` accurately describes the code's actual behavior with zero "not yet implemented" caveats
**Plans:** 3 plans

Plans:
- [x] 01-01-PLAN.md — Relocate ConvertTo-SanitizedPath to LogUtils, reorder dot-sources, deduplicate PSFramework bootstrap
- [x] 01-02-PLAN.md — Fix hash truncation (PRIV-01) and config path sanitization (PRIV-02)
- [x] 01-03-PLAN.md — Update logging guide to match actual code behavior (PRIV-04)

### Phase 2: CI/CD Pipeline
**Goal**: Every push and PR is automatically validated — tests pass cross-platform, lint is clean across all modules
**Depends on**: Phase 1
**Requirements**: CICD-01, CICD-02, CICD-03, CICD-04
**Success Criteria** (what must be TRUE):
  1. Pushing a commit or opening a PR triggers a GitHub Actions workflow that runs all Pester tests on both `ubuntu-latest` and `windows-latest`
  2. The same workflow runs PSScriptAnalyzer against all three `.ps1` files (`VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`) and fails on any finding
  3. A PR that introduces a PSScriptAnalyzer violation or a Pester failure cannot pass CI
  4. Pester is pinned to 5.x (`MaximumVersion 5.99`) in CI — a future Pester 6 release does not silently break the pipeline
**Plans:** 2 plans

Plans:
- [x] 02-01-PLAN.md — Create CI workflow + expand local lint to all 3 files
- [x] 02-02-PLAN.md — Verify CI triggers and passes on GitHub Actions

### Phase 3: Small Wins & Baseline Lock
**Goal**: Remaining audit items from CONCERNS.md closed — the foundation is clean and self-maintaining before feature work begins
**Depends on**: Phase 2
**Requirements**: LOGC-01, LOGC-03
**Success Criteria** (what must be TRUE):
  1. PSFramework log provider is configured with `LogRotatePath` and `LogRetentionTime` so log files rotate automatically with 30-day retention
  2. `Get-VeriHashDefaultConfig` returns `virustotal.enabled = $false` — users are not misled about unshipped VirusTotal integration
**Plans**: 2 plans

Plans:
- [ ] 02-01-PLAN.md — Create CI workflow + expand local lint to all 3 files
- [ ] 02-02-PLAN.md — Verify CI triggers and passes on GitHub Actions

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Privacy & Logging Compliance | 3/3 | Complete | - |
| 2. CI/CD Pipeline | 2/2 | Complete | 2026-04-18 |
| 3. Small Wins & Baseline Lock | 0/? | Not started | - |
