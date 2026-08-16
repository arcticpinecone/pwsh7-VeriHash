---
phase: 04-integrations-config-trim
plan: 02
status: complete
wave: 2
---

# Plan 04-02 Summary — Integration Extraction + Tests

## Outcome
✅ **COMPLETE** — Integration install functions extracted into lazy-loaded VeriHash.Integrations.ps1 with manifest shortcuts/actions added. Full integration test suite passing (9 passed, 1 skipped). Full suite: 196 passed, 0 failed from our changes (2 pre-existing manifest module ordering failures unrelated to Phase 4).

## Tasks Completed

### Task 1: Create VeriHash.Integrations.ps1 + modify VeriHash.ps1 (INTEG-01, INTEG-02, INTEG-03)

| File | Changes |
|------|---------|
| `VeriHash.Integrations.ps1` | **NEW** — AGPL header, Core import guard (D-03), `$script:DesktopEnvironments`, `Get-DesktopEnvironment`, `Install-WindowsSendTo` (+ manifest shortcut D-10), `Install-LinuxContextMenu`, `Install-KDEContextMenu` (+ ManifestHash action D-11) |
| `VeriHash.ps1` | Deleted 5 functions + dispatch table (~310 lines). Added lazy dot-source inside `if ($SendTo)` block (INTEG-01) |

**INTEG-02 satisfied:** `Install-WindowsSendTo` creates both `VeriHash.lnk` and `VeriHash - Manifest.lnk`
**INTEG-03 satisfied:** KDE .desktop `Actions=ComputeHash;VerifyHash;ManifestHash;` with `[Desktop Action ManifestHash]` section

### Task 2: Integration tests + lint scope (INTEG-01 verification)

| File | Changes |
|------|---------|
| `Tests/VeriHash.Integrations.Tests.ps1` | **NEW** — 10 test cases across 4 Describe blocks (surface, SendTo, KDE, lazy-loading) |
| `Test-All.ps1` | Added `VeriHash.Integrations.ps1` to PSScriptAnalyzer lint scope |

## Verification
- Integration tests: 9 passed, 1 skipped (Linux-only Get-DesktopEnvironment)
- PSScriptAnalyzer: zero warnings on VeriHash.Integrations.ps1
- Full test suite: 196 passed, 7 skipped, 2 pre-existing ordering failures in VeriHash.Manifest.Module.Tests.ps1 (unrelated to Phase 4)
- VeriHash.ps1 no longer contains any install function definitions
- Lazy dot-source confirmed inside `if ($SendTo)` block

## Note
The `-Manifest` parameter is not yet handled by VeriHash.ps1's param block (per D-12: Phase 4 creates the shortcuts/actions, Phase 5 wires the parameter handler).
