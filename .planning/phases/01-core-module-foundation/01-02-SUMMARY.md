# Plan 01-02 — SUMMARY

**Status:** ✅ Complete
**Branch:** `dev`
**Commits:** `ae661b4` → `87fc78e` → `92844ce`

## Outcomes

All 6 public functions and all 5 private helpers in `VeriHash.Core/` are now fully implemented (no remaining `throw 'NotImplemented'`).

| Contract ID | Function | Status |
|---|---|---|
| CORE-02 | `Get-VeriHashResult` | ✅ implemented |
| CORE-03 | `Read-ClipboardHash` (length-inferred) | ✅ implemented |
| CORE-04 | `Read-ClipboardHash` (prefix form) | ✅ implemented |
| CORE-05 | `Test-VeriHashSidecar` | ✅ implemented |
| CORE-06 | `Format-VeriHashReport` | ✅ implemented |
| CORE-07 | `Write-VeriHashLog` | ✅ implemented |
| CORE-08 | `Get-VeriHashPlatform` | ✅ implemented (single canonical definition; legacy duplicates deleted in Plan 03) |

## Verification

- **Pester:** 32/33 GREEN across 7 test files. The single remaining RED is the `Has zero duplicate platform-detection definitions outside Core` gate, which is intentionally deferred to Plan 01-03 (it deletes the legacy `$script:RunningOn*` lines in `VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`).
- **PSScriptAnalyzer:** 0 issues on `VeriHash.Core/` with project settings.
- **No PSFramework leakage:** `Select-String 'PSFramework|Write-PSFMessage'` over `VeriHash.Core/` returns empty.
- **Lowercase contract:** no `.ToUpper()` calls on hash values.
- **`-LiteralPath` discipline:** every filesystem cmdlet that takes a user path uses `-LiteralPath`.

## Notable decisions

- `Test-VeriHashSidecar` delegates to `Get-VeriHashResult` for the actual hash compute — single hashing code path, single `Get-FileHash` call per verification.
- `Format-VeriHashReport` is a pure renderer: no `Get-Item`, no `Get-FileHash`, no `Get-AuthenticodeSignature`, no `Resolve-Path`. The literal `<CREATED>` / `<MODIFIED>` placeholders are intentionally part of the Phase 1 contract (a pure formatter cannot stat the file).
- `Format-VeriHashLogLine` uses the explicit `"yyyy-MM-ddTHH:mm:ssZ"` format string — NOT `Get-Date -Format 'o'` — to avoid sub-second precision and `+00:00` offset noise.
- Test setup fix in `Tests/VeriHash.Core.Write-VeriHashLog.Tests.ps1`: the `BeforeEach` now removes the log file (Pester 5 `$TestDrive` is per-`Describe`, so files would otherwise accumulate across `It` blocks). No assertion was modified.
- Golden text fixtures (`format-report-golden-*.txt`) gained a trailing newline so they match `Out-String` output (13 `Write-Host` lines → 13 newlines).

## Files touched

**Implemented (replaced stub bodies):**
- `VeriHash.Core/Public/Get-VeriHashPlatform.ps1`
- `VeriHash.Core/Public/Get-VeriHashResult.ps1`
- `VeriHash.Core/Public/Read-ClipboardHash.ps1`
- `VeriHash.Core/Public/Test-VeriHashSidecar.ps1`
- `VeriHash.Core/Public/Format-VeriHashReport.ps1`
- `VeriHash.Core/Public/Write-VeriHashLog.ps1`
- `VeriHash.Core/Private/ConvertTo-VeriHashAlgorithm.ps1`
- `VeriHash.Core/Private/Read-SidecarLine.ps1`
- `VeriHash.Core/Private/Get-PreferredSidecar.ps1`
- `VeriHash.Core/Private/Resolve-VeriHashLogPath.ps1`
- `VeriHash.Core/Private/Format-VeriHashLogLine.ps1`

**Test/data adjustments (no assertion changes):**
- `Tests/Fixtures/format-report-golden-{md5,sha256,sha512}.txt` — appended trailing newline.
- `Tests/VeriHash.Core.Write-VeriHashLog.Tests.ps1` — `BeforeEach` cleanup of log file.

## Hand-off to Plan 01-03

Plan 03 still needs to:
1. Delete `$script:RunningOnWindows/Linux/macOS` lines in `VeriHash.ps1` (lines 96-97), `VeriHash.Config.ps1` (lines 23-25), `VeriHash.LogUtils.ps1` (lines 35, 74, 116) and route callers to `Get-VeriHashPlatform`.
2. Migrate `Tests/VeriHash.Tests.ps1` from the dot-source hack to `Import-Module`.
3. Run the full `Test-All.ps1 -CI` and confirm everything green (including the now-satisfied platform-dedup gate).
