# Plan 01-03 — SUMMARY

**Plan**: Migrate tests to `Import-Module`, eliminate duplicate platform-detection (CORE-08), refresh `.github/copilot-instructions.md`.
**Wave**: 3 (final wave of Phase 1)
**Status**: ✅ COMPLETE

---

## Commits

| Commit    | Subject                                                                                  |
|-----------|------------------------------------------------------------------------------------------|
| `532499f` | refactor(01-03): consume Get-VeriHashPlatform; delete legacy `$RunningOn*` (CORE-08)     |
| `9257a02` | test(01-03): migrate legacy Pester suite to VeriHash.Core (Import-Module)                |
| `ccd2fff` | docs(01-03): refresh copilot-instructions.md to v2 conventions                           |

---

## Task 1 — eliminate duplicate platform-detection definitions (CORE-08)

**Files touched**: `VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`.

- **`VeriHash.Config.ps1`**: deleted `#region Platform Detection` block (3 `$script:RunningOn*` definitions). Added `Import-Module` shim that loads `VeriHash.Core` only if its manifest is present (defensive — Core may be absent during partial-clone tooling). One consumer at the env-var resolver routed through `(Get-VeriHashPlatform) -eq 'Windows'`.
- **`VeriHash.LogUtils.ps1`**: same `Import-Module` shim added near the top of the dot-source body. Three inline `$RunningOnWindows = ...` redefinitions deleted (originally lines 35 / 74 / 116 inside `Get-VeriHashLogPath`, `ConvertTo-SanitizedPath`, `ConvertFrom-SanitizedPath`). Three consumers rewired to `(Get-VeriHashPlatform)`.
- **`VeriHash.ps1`**: deleted the bare `$RunningOnWindows`/`$RunningOnLinux` definitions at the top of the script and added `Import-Module "$PSScriptRoot\VeriHash.Core\VeriHash.Core.psd1" -Force -Global`. Seven remaining consumer references (Authenticode dispatch, KDE/SendTo installers, log-path helpers, `New-Item` defaults) replaced with `(Get-VeriHashPlatform) -eq '<X>'`.

**Verification**:
```powershell
Select-String -Path VeriHash.ps1,VeriHash.Config.ps1,VeriHash.LogUtils.ps1 `
  -Pattern '\$(?:script:)?RunningOn(?:Windows|Linux|MacOS)\s*='
# → no matches
```
The CORE-08 dedup gate (`Tests/VeriHash.Core.Get-VeriHashPlatform.Tests.ps1` `It "Has zero duplicate $RunningOn* definitions in production .ps1 files"`) flipped from RED to GREEN.

---

## Task 2 — migrate legacy Pester suite + Test-All

### `Tests/VeriHash.Tests.ps1` — rewrite (-1087 lines)

The legacy file dot-sourced `VeriHash.ps1 -FilePath dummy` and exercised the v1 monolith via 60+ `It` blocks across 12 `Describe` blocks. All Phase-1-relevant behaviors are now covered by per-function tests in `Tests/VeriHash.Core.*.Tests.ps1`.

**Triage map** (per plan 01-03 lines 181-261):

| Legacy `Describe`                    | Decision | Reason                                                                |
|--------------------------------------|----------|-----------------------------------------------------------------------|
| `Test-InputHash` (4 It)              | DELETE   | Covered by `Get-VeriHashResult.Tests.ps1` (case-insensitive compare). |
| `Get-ClipboardHash` (5 It)           | DELETE   | Covered by `Read-ClipboardHash.Tests.ps1` (32/64/128 + invalid).      |
| `Get-And-SaveHash` (7 It)            | DELETE   | Write-side; deferred to Phase 2 `Save-VeriHashSidecar`.               |
| `Test-HashSidecar` (3 It)            | DELETE   | Covered by `Test-VeriHashSidecar.Tests.ps1` (two-space + asterisk).   |
| `Multiple Algorithm Testing` (1 It)  | DELETE   | Write-side; deferred to Phase 2.                                      |
| `Sidecar Update and Match` (5 It)    | DELETE   | Write-side; deferred to Phase 2.                                      |
| `Clipboard and Sidecar Interaction`  | DELETE   | CLI orchestration; deferred to Phase 6 (CLI rewrite around Core).     |
| `Force Parameter Behavior` (2 It)    | DELETE   | CLI orchestration; deferred to Phase 6.                               |
| `Sidecar Match Property` (2 It)      | DELETE   | Write-side; deferred to Phase 2.                                      |
| `Help System` (7 It)                 | DELETE   | CLI surface; deferred to Phase 6.                                     |
| `SkipSignatureCheck` (4 It)          | DELETE   | Phase 3 signature module.                                             |
| `Smart Signature Detection` (12 It)  | DELETE   | Phase 3 signature module.                                             |
| `PSFramework Logging Integration`    | DELETE   | Phase 1 retired PSFramework from Core; `Write-VeriHashLog` covers it. |

**Replaced with 3 smoke tests**:

1. Module imports and exports the 6 expected public functions (sorted compare).
2. `Get-VeriHashResult` against `Tests/Fixtures/VeriHash_1024.ico` matches the locked SHA256 `3eb53e02…c775` (lowercase contract).
3. `[Parser]::ParseFile` on `VeriHash.ps1` returns zero errors — sentinel so Phase 5 has a clean retirement target.

The file-level comment block documents the triage map so Phase 5 can resurrect any retired `It` block that turns out to need a modern Core equivalent.

### `Tests/VeriHash.Timing.Tests.ps1`

One-line fix: icon fixture path updated to `Fixtures/VeriHash_1024.ico` (Plan 01-01 moved the asset; Timing tests still pointed at the old root location, which caused all 19 `Profile-VeriHashTiming` asserts to fail — surfaced by Test-All `Container failed: 1`).

### `Test-All.ps1`

PSScriptAnalyzer `$scriptPaths` extended to recursively include every `.ps1` under `VeriHash.Core/` (Public + Private). Existing legacy paths preserved.

### Verification

```powershell
pwsh -NoProfile -File .\Test-All.ps1 -CI -SkipProfiler
# → Tests Passed: 112, Failed: 0, Skipped: 4, Inconclusive: 0, NotRun: 0
# → PSScriptAnalyzer: No issues found (incl. VeriHash.Core/**/*.ps1)
# → All checks passed!
```

(4 skips are platform-conditional: 2× `Returns Unix path on Linux/macOS` + 2× PSFramework-dependent legacy assertions skipped on hosts without the optional module.)

---

## Task 3 — refresh `.github/copilot-instructions.md`

Six narrow edits, all bounded by plan 01-03 lines 273-294 — full README/CHANGELOG rewrite explicitly deferred to Phase 5.

1. **Module loading section**: dot-source-with-dummy-path guidance replaced with `Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force`. Noted that legacy files now import Core themselves.
2. **Logging section**: PSFramework deep-dive (~30 lines incl. tag table) compressed to one paragraph pointing at `Write-VeriHashLog`. Marker phrase `"PSFramework was removed in Phase 1"` present so the plan's automated grep gate passes.
3. **Function entry/exit logging pattern**: relabelled `(legacy files only)`; explicit warning `new code in VeriHash.Core/ must NOT use PSFramework`.
4. **Platform detection code block**: inline `$RunningOnWindows` recipe replaced with `Import-Module` + `(Get-VeriHashPlatform) -eq 'Windows'`. Cited CORE-08.
5. **Non-interactive test invocations**: dot-source hack replaced with the `Import-Module` pattern Phase 1 tests use.
6. **Test environment isolation**: `VERIHASH_TEST_MODE=1` swapped for `$env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')`. Marker phrase `"retired in Phase 1"` present so the grep gate passes.

Plus a new **"Out of Scope for Phase 1"** section documenting that Phase 5 (CLEAN-XX) owns the broader README/CHANGELOG rewrite.

**Untouched**: Build/Test/Lint commands, project description, file-layout block, configuration-system table, Privacy/GDPR rule, function-signature pattern, desktop-environment registration, TDD rule, "Current Development State" section.

**Plan verifier**: all 6 grep gates pass (`OK: copilot-instructions.md updated to v2 conventions`).

---

## Phase 1 ROADMAP success criteria — checklist

> *(from `.planning/ROADMAP.md` lines 26-30)*

1. ✅ **`Import-Module .\VeriHash.Core\VeriHash.Core.psd1` succeeds** and `Get-Command -Module VeriHash.Core` lists `Get-VeriHashResult`, `Read-ClipboardHash`, `Test-VeriHashSidecar`, `Format-VeriHashReport`, `Write-VeriHashLog`, and `Get-VeriHashPlatform`.
   - Verified by smoke test #1 in `Tests/VeriHash.Tests.ps1`.
2. ✅ **`Get-VeriHashResult -Path <file>`** returns object with `FilePath` / `Size` / `Algorithm` / `Hash` / `ElapsedMs` for MD5, SHA256, SHA512.
   - `Tests/VeriHash.Core.Get-VeriHashResult.Tests.ps1` (3 algorithms × shape tests).
3. ✅ **`Read-ClipboardHash`** detects plain-hex 32 / 64 / 128 AND `<algo>:<hex>` prefix override.
   - `Tests/VeriHash.Core.Read-ClipboardHash.Tests.ps1`.
4. ✅ **Legacy v1 sidecars verify** (`HASH  filename` two-space + `HASH *filename` asterisk); `Format-VeriHashReport` matches v1 golden text.
   - `Tests/VeriHash.Core.Test-VeriHashSidecar.Tests.ps1` + `Tests/VeriHash.Core.Format-VeriHashReport.Tests.ps1` × 3 algorithms.
5. ✅ **`Write-VeriHashLog`** appends one line only when `-Log` or `$env:VERIHASH_LOG=1`; **platform detection has zero duplicate definitions**.
   - `Tests/VeriHash.Core.Write-VeriHashLog.Tests.ps1` (gating + format) + `Tests/VeriHash.Core.Get-VeriHashPlatform.Tests.ps1` (CORE-08 dedup grep gate, GREEN).

---

## Files added / modified across Phase 1 (cumulative)

- **Added**: `VeriHash.Core/` (manifest + `.psm1` loader + 6 Public + 5 Private function files), `Tests/VeriHash.Core.*.Tests.ps1` (7 files), `Tests/Fixtures/` (icon + 2 sidecars + 3 golden text fixtures).
- **Modified (Plan 01-03)**: `VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1` (Import-Module shim + `(Get-VeriHashPlatform)` consumers), `Tests/VeriHash.Tests.ps1` (rewrite), `Tests/VeriHash.Timing.Tests.ps1` (one-line fixture path), `Test-All.ps1` (lint scope), `.github/copilot-instructions.md` (v2 conventions).

---

## Hand-off

Phase 1 close-out: ROADMAP entry can be ticked. Phase 2 (Hot-Path Performance + Multi-File Loop) is now unblocked.
