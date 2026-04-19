---
phase: 4
slug: integrations-config-trim
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-19
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
| 04-01-01 | 01 | 1 | CFG-01 | grep | `Select-String -i 'virustotal\|VERIHASH_VT_' *.ps1,*.psm1,*.psd1 -Recurse` | ✅ manual verify | ⬜ pending |
| 04-01-02 | 01 | 1 | CFG-02 | grep | `Select-String -i 'virustotal\|VERIHASH_VT_' Tests/ -Recurse` | ✅ manual verify | ⬜ pending |
| 04-02-01 | 02 | 1 | CFG-03 | grep | `Select-String -i 'PSFramework\|Write-PSFMessage\|PSFrameworkAvailable' **/*.ps1,**/*.psm1,**/*.psd1 -Recurse` | ✅ manual verify | ⬜ pending |
| 04-03-01 | 03 | 2 | INTEG-01 | integration | `Invoke-Pester Tests/VeriHash.Integrations.Tests.ps1 -Output Detailed` | ❌ W0 | ⬜ pending |
| 04-03-02 | 03 | 2 | INTEG-02 | unit (mock) | `Invoke-Pester Tests/VeriHash.Integrations.Tests.ps1 -Output Detailed` | ❌ W0 | ⬜ pending |
| 04-03-03 | 03 | 2 | INTEG-03 | unit | `Invoke-Pester Tests/VeriHash.Integrations.Tests.ps1 -Output Detailed` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Tests/VeriHash.Integrations.Tests.ps1` — stubs for INTEG-01, INTEG-02, INTEG-03
- [ ] No new framework install needed — Pester 5.7.1 already installed and passing

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| KDE service menu installs correctly on real KDE Plasma 6 | INTEG-03 | Requires live KDE desktop session | Run `-InstallKDE` on Linux KDE, verify .desktop file in correct path, test from Dolphin context menu |
| Windows SendTo shortcuts appear and function in Explorer | INTEG-02 | Requires live Windows Explorer session | Run `-InstallSendTo`, verify both .lnk files in SendTo folder, right-click test file |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
