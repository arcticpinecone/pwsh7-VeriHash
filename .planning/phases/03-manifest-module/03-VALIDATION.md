---
phase: 3
slug: manifest-module
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-18
finalized: 2025-07-18
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Pester 5.7.1 |
| **Config file** | None — inline `New-PesterConfiguration` in `Test-All.ps1` |
| **Quick run command** | `Invoke-Pester -Path "Tests/VeriHash.Manifest.*.Tests.ps1" -Output Detailed` |
| **Full suite command** | `Invoke-Pester -Path "Tests/" -Output Detailed` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `Invoke-Pester -Path "Tests/VeriHash.Manifest.*.Tests.ps1" -Output Detailed`
- **After every plan wave:** Run `Invoke-Pester -Path "Tests/" -Output Detailed`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | 01 | 1 | MANIFEST-01 | — | Atomic write via temp→rename | unit + integration | `Invoke-Pester Tests/VeriHash.Manifest.New.Tests.ps1 -Output Detailed` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | MANIFEST-02 | — | Mixed-root inputs rejected with locked error | unit | `Invoke-Pester Tests/VeriHash.Manifest.New.Tests.ps1 -Output Detailed` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | MANIFEST-03 | — | Hash-extension files silently filtered | unit | `Invoke-Pester Tests/VeriHash.Manifest.New.Tests.ps1 -Output Detailed` | ❌ W0 | ⬜ pending |
| TBD | 02 | 2 | MANIFEST-04 | — | Strict regex parse; malformed → exit 3 | unit | `Invoke-Pester Tests/VeriHash.Manifest.Verify.Tests.ps1 -Output Detailed` | ❌ W0 | ⬜ pending |
| TBD | 02 | 2 | MANIFEST-05 | T-3-01 | Path resolved relative to manifest dir; traversal hard-rejected | unit | `Invoke-Pester Tests/VeriHash.Manifest.Verify.Tests.ps1 -Output Detailed` | ❌ W0 | ⬜ pending |
| TBD | 02 | 2 | MANIFEST-06 | — | Exit codes 0/1/2/3 with correct precedence | unit (dedicated) | `Invoke-Pester Tests/VeriHash.Manifest.ExitCodes.Tests.ps1 -Output Detailed` | ❌ W0 | ⬜ pending |
| TBD | 03 | 3 | MANIFEST-08 | — | sha256sum -c round-trip on WSL | integration (conditional) | `Invoke-Pester Tests/VeriHash.Manifest.Roundtrip.Tests.ps1 -Output Detailed` | ❌ W0 | ⬜ pending |

*MANIFEST-07 (SendTo) deferred to Phase 4 (INTEG-02)*

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Tests/VeriHash.Manifest.Module.Tests.ps1` — module surface (imports, exports, no PSFramework)
- [ ] `Tests/VeriHash.Manifest.New.Tests.ps1` — covers MANIFEST-01, -02, -03
- [ ] `Tests/VeriHash.Manifest.Verify.Tests.ps1` — covers MANIFEST-04, -05
- [ ] `Tests/VeriHash.Manifest.ExitCodes.Tests.ps1` — covers MANIFEST-06
- [ ] `Tests/VeriHash.Manifest.Roundtrip.Tests.ps1` — covers MANIFEST-08

*Existing infrastructure covers framework requirements. Only phase-specific test files needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| *None* | — | — | — |

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
