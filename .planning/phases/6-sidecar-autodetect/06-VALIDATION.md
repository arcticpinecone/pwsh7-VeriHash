---
phase: 6
slug: sidecar-autodetect
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-19
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Pester 5.7.1 |
| **Config file** | None — inline `New-PesterConfiguration` in Test-All.ps1 |
| **Quick run command** | `Invoke-Pester -Path "Tests/VeriHash.Core.Invoke-VeriHashSidecarDetect.Tests.ps1" -Output Detailed` |
| **Full suite command** | `.\Test-All.ps1 -SkipProfiler` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `Invoke-Pester -Path "Tests/VeriHash.Core.Invoke-VeriHashSidecarDetect.Tests.ps1" -Output Detailed`
- **After every plan wave:** Run `.\Test-All.ps1 -SkipProfiler`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 6-01-01 | 01 | 1 | SIDE-01 | — | 1-line sidecar → verify companion; N-line → manifest verify | unit | `Invoke-Pester -Path "Tests/VeriHash.Core.Invoke-VeriHashSidecarDetect.Tests.ps1" -Output Detailed` | ❌ W0 | ⬜ pending |
| 6-01-02 | 01 | 1 | SIDE-02 | — | GNU format → filename from line; bare hash → strip extension | unit | Same as above | ❌ W0 | ⬜ pending |
| 6-01-03 | 01 | 1 | SIDE-03 | — | Companion resolved relative to sidecar dir, not CWD | unit | Same as above (test with Push-Location) | ❌ W0 | ⬜ pending |
| 6-01-04 | 01 | 1 | SIDE-04 | T-6-01 | Error when companion doesn't exist | unit | Same as above | ❌ W0 | ⬜ pending |
| 6-01-05 | 01 | 1 | SIDE-05 | — | Error when sidecar file is empty | unit | Same as above | ❌ W0 | ⬜ pending |
| 6-02-01 | 02 | 1 | SIDE-06 | — | Identical behaviour with/without -Manifest | integration | `Invoke-Pester -Path "Tests/VeriHash.Cli.SidecarAutoDetect.Tests.ps1" -Output Detailed` | ❌ W0 | ⬜ pending |
| 6-01-06 | 01 | 1 | — | T-6-01 | Path traversal guard on companion filename | unit | Same as SIDE-01 command | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Tests/VeriHash.Core.Invoke-VeriHashSidecarDetect.Tests.ps1` — stubs for SIDE-01 through SIDE-05 (unit tests)
- [ ] `Tests/VeriHash.Cli.SidecarAutoDetect.Tests.ps1` — stubs for SIDE-06 (E2E integration via VeriHash.ps1)
- [ ] Test fixtures: single-line GNU format `.sha256`, single-line bare hash `.sha256`, multi-line `.sha256`, empty `.sha256`

*Existing test infrastructure (Pester 5.7.1, Test-All.ps1) covers framework needs — no new install required.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Right-click context menu triggers auto-detect | SIDE-01 | Requires OS context menu interaction | Right-click a `.sha256` file in Windows Explorer via SendTo → VeriHash; verify companion file is verified |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
