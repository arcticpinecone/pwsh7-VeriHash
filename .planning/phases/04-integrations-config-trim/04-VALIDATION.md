---
phase: 4
slug: integrations-config-trim
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-19
updated: 2026-04-19
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Pester 5.7.1 |
| **Config file** | None — inline `New-PesterConfiguration` in `Test-All.ps1` |
| **Quick run command** | `Invoke-Pester -Path Tests/ -Output Detailed` |
| **Full suite command** | `.\Test-All.ps1` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `Invoke-Pester -Path Tests/ -Output Detailed`
- **After every plan wave:** Run `.\Test-All.ps1`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | CFG-01 | grep | `Invoke-Pester -Path Tests/VeriHash.ConfigTrim.Tests.ps1 -Output Detailed` | ✅ | ✅ green |
| 04-01-02 | 01 | 1 | CFG-02 | grep | `Invoke-Pester -Path Tests/VeriHash.ConfigTrim.Tests.ps1 -Output Detailed` | ✅ | ✅ green |
| 04-02-01 | 02 | 1 | CFG-03 | grep | `Invoke-Pester -Path Tests/VeriHash.ConfigTrim.Tests.ps1 -Output Detailed` | ✅ | ✅ green |
| 04-03-01 | 02 | 2 | INTEG-01 | integration | `Invoke-Pester Tests/VeriHash.Integrations.Tests.ps1 -Output Detailed` | ✅ | ✅ green |
| 04-03-02 | 02 | 2 | INTEG-02 | unit (mock) | `Invoke-Pester Tests/VeriHash.Integrations.Tests.ps1 -Output Detailed` | ✅ | ✅ green |
| 04-03-03 | 02 | 2 | INTEG-03 | unit | `Invoke-Pester Tests/VeriHash.Integrations.Tests.ps1 -Output Detailed` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `Tests/VeriHash.ConfigTrim.Tests.ps1` — tree-wide regression for CFG-01, CFG-02, CFG-03
- [x] `Tests/VeriHash.Integrations.Tests.ps1` — INTEG-01, INTEG-02, INTEG-03 (already existed)
- [x] No new framework install needed — Pester 5.7.1 already installed and passing

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| KDE service menu installs correctly on real KDE Plasma 6 | INTEG-03 | Requires live KDE desktop session | Run `-InstallKDE` on Linux KDE, verify .desktop file in correct path, test from Dolphin context menu |
| Windows SendTo shortcuts appear and function in Explorer | INTEG-02 | Requires live Windows Explorer session | Run `-InstallSendTo`, verify both .lnk files in SendTo folder, right-click test file |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-04-19

---

## Validation Audit 2026-04-19

| Metric | Count |
|--------|-------|
| Gaps found | 3 |
| Resolved | 3 |
| Escalated | 0 |

**Tests created:** `Tests/VeriHash.ConfigTrim.Tests.ps1` (3 tests: CFG-01, CFG-02, CFG-03 tree-wide regression)
**All 6 requirements now have automated verification.**
