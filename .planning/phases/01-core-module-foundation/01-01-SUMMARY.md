---
phase: 01-core-module-foundation
plan: 01
status: complete
requirements: [CORE-01]
commits:
  - 29caa18 feat(01-01): add VeriHash.Core module skeleton with stub functions
  - 9b5e54a feat(01-01): add Tests/Fixtures with icon, sidecar pairs, and v2-lowercase golden text
  - 62207e5 test(01-01): add 7 Pester test files (module sanity GREEN, per-function RED)
---

# Plan 01-01 Summary — Core Module Skeleton + Fixtures + Failing Tests

## Objective delivered
Established the `VeriHash.Core` PowerShell 7+ module with manifest, loader,
6 stub Public functions, 5 stub Private helpers, 6 fixture assets, and
7 Pester test files. Module sanity tests GREEN; per-function tests RED with
`NotImplemented:` exceptions — Plan 02 has a clean TDD target.

## Tasks completed

### Task 1 — Module skeleton (commit `29caa18`)
- `VeriHash.Core/VeriHash.Core.psd1` — manifest with literal
  `FunctionsToExport` array of 6 names, `PowerShellVersion 7.0`,
  `CompatiblePSEditions Core`, all four export keys as `@()` (no wildcards)
- `VeriHash.Core/VeriHash.Core.psm1` — thin loader: dot-source `Private/`
  first, then `Public/`, then `Export-ModuleMember -Function $publicFiles.BaseName`
- 6 Public stubs (`Get-VeriHashPlatform`, `Get-VeriHashResult`,
  `Read-ClipboardHash`, `Test-VeriHashSidecar`, `Format-VeriHashReport`,
  `Write-VeriHashLog`) — each with locked param block and
  `throw 'NotImplemented: <name> -- implemented in plan 01-02'` body
- 5 Private stubs (`ConvertTo-VeriHashAlgorithm`, `Read-SidecarLine`,
  `Get-PreferredSidecar`, `Format-VeriHashLogLine`, `Resolve-VeriHashLogPath`)

### Task 2 — Fixtures (commit `9b5e54a`)
- `Tests/Fixtures/VeriHash_1024.ico` — moved via `git mv` from `Tests/`
- `Tests/Fixtures/sidecar-twospace.sha256` — `<sha256>  VeriHash_1024.ico` (two-space format)
- `Tests/Fixtures/sidecar-asterisk.sha256` — `<sha256> *VeriHash_1024.ico` (asterisk format)
- `Tests/Fixtures/format-report-golden-{md5,sha256,sha512}.txt` — v2 lowercase
  contract with `<TIMESTAMP>`, `<CREATED>`, `<MODIFIED>`, `<ELAPSED_MS>`
  placeholders for non-deterministic fields
- `Test-All.ps1` — icon path updated to `Tests\Fixtures\VeriHash_1024.ico`
- `.gitignore` — `!Tests/Fixtures/` and `!Tests/Fixtures/**` rules to override
  the existing `Tests/*.sha256` ignore for committed fixture assets

Fixture hashes (canonical, computed from icon, used in sidecars + golden text):
- MD5:    `441b45a2052b1f74aa946ba587a8f4f7`
- SHA256: `3eb53e022fc03d61dffe2aff3244103daef28166b9c538cabbf04462fa59c775`
- SHA512: `06d679a0ea464b9226ec3f981acad6cc6cd0f42dbdec78e3a3e4e58c880749a77daf4317b037208c73657b2f120f9b192fdb93803606d39059c887c7087c59a2`
- Size: 1 709 869 bytes (1.63 MB)

### Task 3 — Pester tests (commit `62207e5`)
- `Tests/VeriHash.Core.Module.Tests.ps1` — CORE-01 — 3 It blocks, all GREEN
- `Tests/VeriHash.Core.Get-VeriHashPlatform.Tests.ps1` — CORE-08 — RED
  (includes the dedup grep that will stay RED until Plan 03)
- `Tests/VeriHash.Core.Get-VeriHashResult.Tests.ps1` — CORE-02 — RED
- `Tests/VeriHash.Core.Read-ClipboardHash.Tests.ps1` — CORE-03/04 — RED
  (includes prefix-overrides-length rejection: `md5:` + 64-hex → null)
- `Tests/VeriHash.Core.Test-VeriHashSidecar.Tests.ps1` — CORE-05 — RED
- `Tests/VeriHash.Core.Format-VeriHashReport.Tests.ps1` — CORE-06 — RED
- `Tests/VeriHash.Core.Write-VeriHashLog.Tests.ps1` — CORE-07 — RED

All test files use `Import-Module ... -Force` in `BeforeAll`. No
`$env:VERIHASH_TEST_MODE` references (dead in Phase 1).

## Verification

### Pester (`Invoke-Pester -Path 'Tests/VeriHash.Core.*.Tests.ps1' -PassThru`)
- Containers discovered: **7** ✓
- Total tests: **33**
- Passed: **4** (3 module sanity + 1 incidental)
- Failed: **29** — all with `RuntimeException: NotImplemented: <name> -- implemented in plan 01-02`,
  proving every per-function test reaches into the module rather than passing vacuously
- Module sanity tests (`Tests/VeriHash.Core.Module.Tests.ps1`): **3/3 GREEN** ✓

### PSScriptAnalyzer
```
Invoke-ScriptAnalyzer -Path .\VeriHash.Core -Recurse -Settings .\PSScriptAnalyzerSettings.psd1 -Severity Error,Warning
→ 0 issues
```

### Module import + exports
```powershell
Import-Module .\VeriHash.Core\VeriHash.Core.psd1 -Force
(Get-Command -Module VeriHash.Core).Name | Sort-Object
# → Format-VeriHashReport, Get-VeriHashPlatform, Get-VeriHashResult,
#    Read-ClipboardHash, Test-VeriHashSidecar, Write-VeriHashLog
```
Exact 6-name match against `FunctionsToExport`.

## Acceptance criteria

| Criterion | Status |
|-----------|--------|
| `Test-Path .\VeriHash.Core\VeriHash.Core.psd1` and `.psm1` | ✓ |
| 6 Public + 5 Private stub `.ps1` files exist | ✓ |
| `Import-Module` succeeds with no warnings | ✓ |
| `Get-Command -Module VeriHash.Core` returns exactly the 6 locked names | ✓ |
| Manifest pins `PowerShellVersion 7.0` and `CompatiblePSEditions Core` | ✓ |
| No wildcard exports in `.psd1` | ✓ |
| `Tests/Fixtures/` contains icon + 2 sidecars + 3 golden-text files | ✓ |
| Sidecar files match canonical SHA256 of icon, lowercase, UTF-8 no-BOM | ✓ |
| Golden text files contain `<TIMESTAMP>`/`<CREATED>`/`<MODIFIED>`/`<ELAPSED_MS>` placeholders | ✓ |
| Golden text files contain only lowercase hex (no uppercase 32+ char runs) | ✓ |
| `Test-All.ps1` references `Tests\Fixtures\VeriHash_1024.ico` | ✓ |
| 7 Pester test files exist using `Import-Module -Force` (no dot-source) | ✓ |
| Module sanity tests GREEN | ✓ |
| Per-function tests RED with `NotImplemented:` failures | ✓ |
| PSScriptAnalyzer on `VeriHash.Core/` reports 0 errors/warnings | ✓ |

## Handoff to Plan 02

Plan 02 should:
1. Replace each `throw 'NotImplemented: ...'` body in
   `VeriHash.Core/Public/*.ps1` and `VeriHash.Core/Private/*.ps1` with a real
   implementation conforming to the locked param signatures.
2. Drive implementation TDD-style — every per-function test that is currently
   RED must turn GREEN; the golden-text tests pin the exact `Format-VeriHashReport`
   output (lowercase hashes, v1 layout minus Authenticode).
3. Do NOT modify the test files or the golden-text fixtures (TDD rule from
   `AGENTS.md`); modify the function bodies until output matches.

The platform-dedup grep in `Get-VeriHashPlatform.Tests.ps1` will remain RED
until Plan 03 deletes the `$RunningOn*` definitions in `VeriHash.ps1`,
`VeriHash.Config.ps1`, and `VeriHash.LogUtils.ps1`.
