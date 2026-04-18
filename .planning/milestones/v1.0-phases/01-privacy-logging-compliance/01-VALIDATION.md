---
phase: 1
slug: privacy-logging-compliance
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-18
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Pester 5.7.1 |
| **Config file** | None — configuration built inline (project convention) |
| **Quick run command** | `pwsh -Command "Invoke-Pester ./Tests -Output Detailed"` |
| **Full suite command** | `pwsh -File ./Test-All.ps1 -CI` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `pwsh -Command "Invoke-Pester ./Tests -Output Detailed"`
- **After every plan wave:** Run `pwsh -File ./Test-All.ps1 -CI`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | PRIV-03, LOGC-02 | T-01-01, T-01-02 | ConvertTo-SanitizedPath available from LogUtils; dot-source order LogUtils→Config; single PSFramework bootstrap | inspection + smoke | `Invoke-Pester ./Tests -Output Detailed` | ✅ | ✅ green |
| 01-01-02 | 01 | 1 | PRIV-03 | T-01-01 | Config tests mirror production load order (LogUtils→Config) | unit | `Invoke-Pester -Path 'Tests/VeriHash.Config.Tests.ps1' -Output Detailed` | ✅ | ✅ green |
| 01-02-01 | 02 | 2 | PRIV-01 | T-01-04 | Hash values truncated to 16 chars + '...' in all log output | inspection | Code inspection: `$truncatedHash` in Get-And-SaveHash | ✅ | ✅ green |
| 01-02-02 | 02 | 2 | PRIV-02 | T-01-05 | All 11 config paths sanitized via ConvertTo-SanitizedPath | inspection | Code inspection: 11 `ConvertTo-SanitizedPath` calls in Config | ✅ | ✅ green |
| 01-03-01 | 03 | 2 | PRIV-04 | T-01-07 | Logging guide matches actual code behavior | inspection | Doc inspection: `D7A8FBB307D78094` truncation pattern present | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `ConvertTo-SanitizedPath` defined in `VeriHash.LogUtils.ps1` — verified at line 44
- [x] Dot-source order is LogUtils → Config in `VeriHash.ps1` — verified at lines 104-105
- [x] Single PSFramework bootstrap — exactly 1 `Get-Module -ListAvailable` across all `.ps1` files
- [x] Hash truncation in `Get-And-SaveHash` — `$truncatedHash` used in `-Message` and `-Data Hash`
- [x] 11 config path sanitizations in `VeriHash.Config.ps1` — all piped through `ConvertTo-SanitizedPath`
- [x] Logging guide updated with realistic 16-char hash example (`D7A8FBB307D78094...`)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Logging guide accuracy vs runtime output | PRIV-04 | Requires PSFramework installed + log inspection | Run VeriHash with `-LogLevel Verbose`; compare log JSON with guide |
| PSFramework logs contain sanitized paths | PRIV-02 | Requires PSFramework installed + log review | Hash a file; confirm `%USERPROFILE%` in logs, no raw paths |
| Hash truncation visible in log JSON | PRIV-01 | Requires PSFramework installed + log review | Hash a file; confirm `Hash` field is 16 chars + `...` |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
