---
phase: 2
slug: hot-path-performance-multi-file-loop
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> See `02-RESEARCH.md` § "Validation Architecture" for the authoritative behavior → test map (full table); this file is the operational contract the executor checks against.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Pester 5.x (≤ 5.99) |
| **Config file** | None — inline `New-PesterConfiguration` in `Test-All.ps1` and `.github/workflows/ci.yml` |
| **Quick run command** | `Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1 -Output Detailed` |
| **Full suite command** | `.\Test-All.ps1 -CI` |
| **Performance subset** | `Invoke-Pester -Path Tests/ -Tag 'Performance' -Output Detailed` |
| **Skip performance on slow runner** | `Invoke-Pester -Path Tests/ -ExcludeTag 'Performance'` |
| **Estimated runtime (no perf tag)** | ~30s |
| **Estimated runtime (full + perf)** | ~90s on a 150 MB on-the-fly fixture |

---

## Sampling Rate

- **After every task commit:** `Invoke-Pester -Path Tests/VeriHash.HotPath.<Subset>.Tests.ps1 -ExcludeTag 'Performance' -Output Detailed`
- **After every plan wave:** `Invoke-Pester -Path Tests/ -ExcludeTag 'Performance' -Output Detailed`
- **Before `/gsd-verify-work`:** `.\Test-All.ps1 -CI` + `Invoke-Pester -Tag 'Performance'` both green
- **Max feedback latency:** ~30s (per-task) / ~60s (per-wave) / ~90s (phase gate)

---

## Per-Task Verification Map

> Plans MUST populate `<automated>` blocks that map each task to one of these tests. The full Behavior → Test map (16 rows) lives in `02-RESEARCH.md` § "Phase Requirements → Test Map". The orchestrator audits coverage at phase gate.

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| TBD by planner | 01–03 | 1–3 | PERF-01..05, MULTI-01..03 | unit / perf / integration | see RESEARCH.md table | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

> All test files below are MISSING in the current repo and MUST be created by Wave 0 of their respective plan, BEFORE any production code in that wave is written (TDD rule per `.github/copilot-instructions.md`).

- [ ] `Tests/VeriHash.HotPath.Tests.ps1` — module sanity, re-import safety, cross-platform skip
- [ ] `Tests/VeriHash.HotPath.PE.Tests.ps1` — `Test-IsPEFile` covering MZ / non-MZ / <2 bytes / I/O error / directory / symlink (PERF-01a/b/c)
- [ ] `Tests/VeriHash.HotPath.Sig.Tests.ps1` — `Get-VeriHashSignature` + Mock-based PERF-02 flag assertion + HRESULT → Status table
- [ ] `Tests/VeriHash.HotPath.Batch.Tests.ps1` — MULTI-01/02/03 + byte-locked tally string + continue-and-tally
- [ ] `Tests/VeriHash.HotPath.Perf.Tests.ps1` (`-Tag Performance`) — PERF-03 differential + 150 MB fixture generated in `BeforeAll`
- [ ] `Tests/Fixtures/tiny-pe.bin` (~64 bytes, valid MZ header, unsigned)
- [ ] `Tests/Fixtures/tiny-not-pe.bin` (~64 bytes, no MZ header)
- [ ] (Optional) `Tests/VeriHash.HotPath.Offline.Tests.ps1` (`-Tag Offline`) — manual network-disconnect integration; Skip-by-default
- [ ] Extension to `Profile-VeriHashTiming.ps1` adding `-Strict` switch with the D-A7-1 strict assertion

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real WinVerifyTrust call against an unsigned PE on a network-disconnected host completes in < 100 ms | PERF-02 (offline integration) | Cannot reliably disconnect a CI runner's network without breaking the runner; opt-in `-Tag 'Offline'` test left for local QA | 1) Disable network on host. 2) `Invoke-Pester -Path Tests/VeriHash.HotPath.Offline.Tests.ps1 -Tag Offline`. 3) Confirm wall-clock < 100 ms via `Measure-Command`. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING test files listed above
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s (phase gate)
- [ ] `nyquist_compliant: true` set in frontmatter once all plans pass `gsd-plan-checker`

**Approval:** pending
