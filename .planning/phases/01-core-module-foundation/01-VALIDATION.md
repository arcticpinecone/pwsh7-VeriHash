---
phase: 1
slug: core-module-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

> **Source:** Pulled from `01-RESEARCH.md` § Validation Architecture. The planner is expected to refine this file when plans are written and lock `nyquist_compliant: true` once Wave 0 is in.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Pester 5.7.x (already installed; pinned in CI) |
| **Config file** | none yet — Wave 0 adds `Tests/PesterConfiguration.psd1` (or inline `New-PesterConfiguration` in `Test-All.ps1`) |
| **Quick run command** | `pwsh -NoProfile -Command "Invoke-Pester -Path Tests/VeriHash.Core.<Function>.Tests.ps1 -Output Detailed"` |
| **Full suite command** | `pwsh -NoProfile -File .\Test-All.ps1 -SkipAnalyzer -SkipProfiler` |
| **Estimated runtime** | ~10 seconds (per-function file) / ~30 seconds (full Pester suite) |

---

## Sampling Rate

- **After every task commit:** Run the per-function quick command for the file just touched
- **After every plan wave:** Run the full suite command
- **Before `/gsd-verify-work`:** Full Pester suite + `Invoke-ScriptAnalyzer` must both be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

> Plans MUST fill in concrete Task IDs. The rows below are the **per-requirement verification anchors** the planner has to assign to at least one task. Every CORE-NN ID in the right-hand column is a hard coverage gate.

| Anchor | Wave | Requirement | Test Type | Automated Command | Notes |
|--------|------|-------------|-----------|-------------------|-------|
| Module loads + exported surface | 1 | CORE-01 | integration | `Invoke-Pester Tests/VeriHash.Core.Manifest.Tests.ps1` | Asserts `Import-Module` + `Get-Command -Module VeriHash.Core` lists all 6 names |
| `Get-VeriHashResult` shape | 2 | CORE-02 | unit | `Invoke-Pester Tests/VeriHash.Core.GetVeriHashResult.Tests.ps1` | One `It` per algorithm (MD5/SHA256/SHA512); object has FilePath, Size, Algorithm, Hash, ElapsedMs |
| `Read-ClipboardHash` length inference | 2 | CORE-03 | unit | `Invoke-Pester Tests/VeriHash.Core.ReadClipboardHash.Tests.ps1` | Cases: 32-hex → MD5, 64 → SHA256, 128 → SHA512 |
| `Read-ClipboardHash` prefixed form | 2 | CORE-03 | unit | same file | `sha256:<hex>` form, including prefix-overrides-length case |
| Sidecar verify (`HASH  filename`) | 2 | CORE-04 | unit | `Invoke-Pester Tests/VeriHash.Core.TestVeriHashSidecar.Tests.ps1` | Round-trip a fixture file with two-space text format |
| Sidecar verify (`HASH *filename`) | 2 | CORE-04 | unit | same file | Binary-marker variant produced by `sha256sum -b` |
| Golden-text format | 2 | CORE-05 | golden | `Invoke-Pester Tests/VeriHash.Core.FormatVeriHashReport.Tests.ps1` | Diff against `Tests/Fixtures/format-report.golden.txt` |
| `Write-VeriHashLog` gating | 2 | CORE-06 | unit | `Invoke-Pester Tests/VeriHash.Core.WriteVeriHashLog.Tests.ps1` | Asserts no file when neither `-Log` nor `$env:VERIHASH_LOG` set; exactly one line when set |
| `Write-VeriHashLog` line shape | 2 | CORE-06 | unit | same file | UTF-8 no-BOM, single line, locked timestamp+algo+hash+path columns |
| Platform helper | 2 | CORE-07 | unit | `Invoke-Pester Tests/VeriHash.Core.GetVeriHashPlatform.Tests.ps1` | Returns `Windows`/`Linux`/`macOS` based on `$IsWindows`/`$IsLinux`/`$IsMacOS` |
| Zero duplicate platform defs | 2 | CORE-08 | static | `Invoke-Pester Tests/VeriHash.Core.NoDuplicates.Tests.ps1` | `Select-String -Pattern 'function Get-VeriHashPlatform'` over repo returns exactly 1 hit (in `VeriHash.Core/Public/`) |
| PSScriptAnalyzer clean | all | CORE-01..08 | static | `Invoke-ScriptAnalyzer -Path VeriHash.Core -Settings PSScriptAnalyzerSettings.psd1` | Zero `Error`/`Warning` outputs |

*Status legend: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky — planner will assign per-task IDs and tick boxes during execution.*

---

## Wave 0 Requirements

> Wave 0 = test scaffolding & fixtures that must land **before** Wave 1 (module skeleton) and Wave 2 (per-function ports). Without these the per-task automated commands above will reference files that don't exist.

- [ ] `Tests/Fixtures/` directory — central home for binary fixtures (move existing `VeriHash_1024.ico` here)
- [ ] `Tests/Fixtures/sidecar-text.sha256` — two-space `HASH  filename` fixture
- [ ] `Tests/Fixtures/sidecar-binary.sha256` — `HASH *filename` fixture
- [ ] `Tests/Fixtures/format-report.golden.txt` — golden text capture for `Format-VeriHashReport` (locks v2 lowercase contract — see RESEARCH.md Open Question #1)
- [ ] `Tests/VeriHash.Core.Manifest.Tests.ps1` — stub asserting `Import-Module` succeeds and exported function list (CORE-01)
- [ ] `Tests/VeriHash.Core.NoDuplicates.Tests.ps1` — stub asserting zero duplicate `Get-VeriHashPlatform` definitions (CORE-08)
- [ ] One `Tests/VeriHash.Core.<Function>.Tests.ps1` stub per exported function (5 stubs)
- [ ] `Test-All.ps1` updated to discover the new test files (or rely on `Invoke-Pester -Path Tests/`)

*If the planner determines existing infrastructure already covers an item, it must say so explicitly here and remove the row.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Read clipboard from a real desktop session | CORE-03 | `Get-Clipboard` returns `$null` in a non-interactive CI runner; cross-platform clipboard surfaces are intentionally non-deterministic | On a Windows or KDE desktop, copy a real SHA-256 hex string and run `Read-ClipboardHash` to confirm it returns `SHA256` |
| KDE/macOS clipboard fallbacks | CORE-03 | Requires `xclip`/`pbpaste` installed and a graphical session; not viable on CI | Run `Read-ClipboardHash` interactively on Linux+KDE and on macOS Terminal |

*All other phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (fixture files + stub test files)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
