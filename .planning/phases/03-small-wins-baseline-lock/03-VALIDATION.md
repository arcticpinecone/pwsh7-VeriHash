---
phase: 3
slug: small-wins-baseline-lock
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-18
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Pester 5.7.1 |
| **Config file** | Inline `New-PesterConfiguration` in CI; direct invocation locally |
| **Quick run command** | `Invoke-Pester -Path "Tests/VeriHash.Config.Tests.ps1" -Output Detailed` |
| **Full suite command** | `Invoke-Pester -Path "Tests/" -Output Detailed` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `Invoke-Pester -Path "Tests/VeriHash.Config.Tests.ps1" -Output Detailed`
- **After every plan wave:** Run `Invoke-Pester -Path "Tests/" -Output Detailed`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | LOGC-01 | — | Log rotation prevents disk exhaustion | integration | `Invoke-Pester -Path "Tests/VeriHash.Tests.ps1" -Output Detailed` | ✅ | ✅ green |
| 03-01-02 | 01 | 1 | LOGC-03 | — | VT disabled by default prevents user confusion | unit | `Invoke-Pester -Path "Tests/VeriHash.Config.Tests.ps1" -Output Detailed` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Add test assertion in `Tests/VeriHash.Tests.ps1` verifying `LogRotatePath` and `LogRetentionTime` are configured when PSFramework is available

*Existing test infrastructure covers LOGC-03 — values updated from `$true` to `$false`.*

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
