# Milestones

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
