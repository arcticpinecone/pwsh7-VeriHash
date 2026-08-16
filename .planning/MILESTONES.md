# Milestones

## ✅ v2.0 — Modular Rebuild

**Shipped:** 2026-04-19
**Phases:** 5 | **Plans:** 15 | **Requirements:** 38/38
**Test suite:** 176 pass · 0 fail · 5 skipped
**Production LOC:** 2,039 (32 files) | **Test LOC:** 1,817 (21 files)

### Key Accomplishments

1. **VeriHash.Core module** — 6 public functions (hash, clipboard, sidecar, format, log, platform) with Import-Module replacing dot-source hack
2. **Parallel hot-path** — PE-only Authenticode via P/Invoke with ThreadJob parallelism; streaming output (hash first, signature appended)
3. **Multi-file batch** — Single SendTo invocation processes N files with per-file results + byte-locked tally
4. **Manifest mode** — GNU sha256sum-compatible create/verify with atomic writes, path-traversal guard, machine-readable exit codes (0/1/2/3)
5. **Full cleanup** — VirusTotal and PSFramework removed; QuickHash and LogUtils retired; 196-line thin CLI dispatcher; README/CHANGELOG rewritten

### Stats

- Timeline: 2 days (2026-04-18 → 2026-04-19)
- Commits: 180
- Production: 2,039 LOC across 32 files (3 modules + CLI + integrations)
- Tests: 1,817 LOC across 21 test files

### Deferred

- `260418-rename-log-jsonl` quick task — stale v1 artifact (already complete, audit tool false positive)

### Archives

- [v2.0-ROADMAP.md](milestones/v2.0-ROADMAP.md)
- [v2.0-REQUIREMENTS.md](milestones/v2.0-REQUIREMENTS.md)
- [v2.0-MILESTONE-AUDIT.md](milestones/v2.0-MILESTONE-AUDIT.md)

---

## ✅ v1.0 — Privacy + Foundation

**Shipped:** 2026-04-18
**Phases:** 3 | **Plans:** 6 | **Requirements:** 11/11

### Key Accomplishments

1. **Privacy compliance locked** — All PSFramework log output sanitized: hash values truncated to 16 chars, all config paths pass through `ConvertTo-SanitizedPath`, logging guide updated to match reality
2. **CI/CD safety net shipped** — GitHub Actions runs Pester (ubuntu + windows) and PSScriptAnalyzer on every push/PR; regressions caught automatically
3. **Lint coverage expanded** — PSScriptAnalyzer now covers all 3 production files, not just `VeriHash.ps1`
4. **Log rotation enabled** — PSFramework provider configured with `LogRotatePath` + 30-day retention
5. **VirusTotal default flipped** — `virustotal.enabled` defaults to `$false` until integration ships
6. **Foundation honest** — The logging concepting guide now describes actual code behavior with zero caveats

### Stats

- Timeline: Single day (2026-04-18)
- Commits: 44
- Source files changed: 11
- Tests: 133 passed, 0 failed, 8 skipped

### Deferred

- PSFramework missing notification (Backlog 999.1) — users unaware when PSFramework absent

### Archives

- [v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)
- [v1.0-REQUIREMENTS.md](milestones/v1.0-REQUIREMENTS.md)
- [v1.0-MILESTONE-AUDIT.md](milestones/v1.0-MILESTONE-AUDIT.md)
