# Plan 02-01 Summary — VeriHash.HotPath module skeleton + PE-detect + signature wrapper

**Phase:** 02 — Hot-Path Performance + Multi-File Loop
**Plan:** 01 of 03
**Status:** ✅ Complete
**Date:** 2026-04-18
**Commits:** `1b9af56` (Tasks 0-1, RED), `<HEAD>` (Task 2, GREEN)
**Requirements closed:** PERF-01, PERF-02

---

## Files added / modified

### Module — `VeriHash.HotPath/`

| Path | Purpose |
|------|---------|
| `VeriHash.HotPath/VeriHash.HotPath.psd1` | Module manifest. `ModuleVersion=2.0.0`, `PowerShellVersion=7.0`, `CompatiblePSEditions=Core`, `FunctionsToExport='Get-VeriHashSignature'`. |
| `VeriHash.HotPath/VeriHash.HotPath.psm1` | Loader — dot-sources `Private/*.ps1` then `Public/*.ps1` (verbatim copy of the Phase 1 Core loader). |
| `VeriHash.HotPath/Public/Get-VeriHashSignature.ps1` | Public wrapper. Returns `{Status, Reason}`. Platform-gated; non-Windows returns `Status='skipped'` without P/Invoking. Non-PE returns `Status='skipped', Reason='not a PE file'`. |
| `VeriHash.HotPath/Private/Test-IsPEFile.ps1` | Content-based PE detection — opens the file, reads 2 bytes, disposes, checks for `MZ` (`0x4D 0x5A`). Any I/O error returns `$false`. |
| `VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1` | P/Invoke shim. `Add-Type` with re-import guard, `WINTRUST_DATA` + `WINTRUST_FILE_INFO` exactly per `02-01-PINVOKE-PIN.md`. **`dwProvFlags = WTD_REVOCATION_CHECK_NONE \| WTD_CACHE_ONLY_URL_RETRIEVAL = 0x00001010`** — no network CRL (PERF-02). Pairs every VERIFY with STATEACTION_CLOSE in `finally`. |
| `VeriHash.HotPath/Private/ConvertFrom-WinTrustHResult.ps1` | HRESULT → `{Status, Reason}` mapping (8 known + default `error`). |

### Tests

| Path | Purpose | Counts |
|------|---------|--------|
| `Tests/VeriHash.HotPath.Tests.ps1` | Module sanity + manifest pin + forbidden-flag/PSFramework/$IsWindows audit. | 8 tests |
| `Tests/VeriHash.HotPath.PE.Tests.ps1` | `Test-IsPEFile` happy/sad paths (PE, not-PE, missing, dir, 1-byte). | 5 tests |
| `Tests/VeriHash.HotPath.Sig.Tests.ps1` | Platform gate (skipped on Windows runner), non-PE skip, full HRESULT→Status table (8 mappings + unknown→error). | 11 tests (1 platform-skipped on Windows) |
| `Tests/Fixtures/tiny-pe.bin` | 64-byte PE skeleton starting with `MZ`. |  |
| `Tests/Fixtures/tiny-not-pe.bin` | 64-byte ASCII filler not starting with `MZ`. |  |

### Reference / pin doc

| Path | Purpose |
|------|---------|
| `.planning/phases/02-hot-path-performance-multi-file-loop/02-01-PINVOKE-PIN.md` | Locked struct layout, flag values, action GUID, HRESULT table. Source of truth for any future P/Invoke revisitation. |

---

## Test counts

| Run | Passed | Failed | Skipped | Total |
|-----|--------|--------|---------|-------|
| Plan 02-01 tests (3 files) | 23 | 0 | 1 (non-Windows platform-gate test on Windows runner) | 24 |
| Full repo Pester suite | 135 | 0 | 5 | 140 |

PSScriptAnalyzer: **0 issues** under `VeriHash.HotPath/` with `PSScriptAnalyzerSettings.psd1`.

Real-binary smoke check on a Windows host:

| File | Result |
|------|--------|
| `pwsh.exe` (Microsoft-signed) | `Status=valid` |
| `notepad.exe` | `Status=unsigned` (no embedded signature; signed via OS catalog — catalog verification is intentionally out of scope for Plan 02-01, see "Open follow-ups") |
| `README.md` (no `-IsPE`) | `Status=skipped, Reason='not a PE file'` |

---

## HRESULT → Status mapping (consumed by downstream plans)

| HRESULT name | Hex (uint32) | Signed int32 | Status | Reason |
|--------------|-------------|--------------|--------|--------|
| `S_OK` | `0x00000000` | `0` | `valid` | `''` |
| `TRUST_E_NOSIGNATURE` | `0x800B0100` | `-2146762496` | `unsigned` | `not signed` |
| `TRUST_E_BAD_DIGEST` | `0x80096010` | `-2146869232` | `invalid` | `bad digest` |
| `TRUST_E_EXPLICIT_DISTRUST` | `0x800B0111` | `-2146762479` | `invalid` | `explicit distrust` |
| `CERT_E_EXPIRED` | `0x800B0101` | `-2146762495` | `invalid` | `cert expired` |
| `CERT_E_REVOKED` | `0x80092010` | `-2146885616` | `invalid` | `cert revoked` |
| `CERT_E_UNTRUSTEDROOT` | `0x800B0109` | `-2146762487` | `invalid` | `untrusted root` |
| `CERT_E_CHAINING` | `0x800B010A` | `-2146762486` | `invalid` | `chain build failed` |
| *anything else* | varies | varies | `error` | `'0x{0:X8}' -f ([uint32]$HResult)` |

---

## Requirements closed

- **PERF-01 — Skip signature for non-PE files.** Closed by `Test-IsPEFile` + the `-IsPE` switch on `Get-VeriHashSignature`. When `-IsPE` is `$false`, the function returns `Status='skipped', Reason='not a PE file'` without P/Invoking. Verified by `Tests/VeriHash.HotPath.Sig.Tests.ps1` "Returns Status=skipped, Reason='not a PE file' when -IsPE is `$false`".
- **PERF-02 — Disable network CRL lookups on signature checks.** Closed by setting `WINTRUST_DATA.fdwRevocationChecks = WTD_REVOKE_NONE (0)` AND `WINTRUST_DATA.dwProvFlags = WTD_REVOCATION_CHECK_NONE (0x10) | WTD_CACHE_ONLY_URL_RETRIEVAL (0x1000)`. Forbidden flags (`WTD_DISABLE_MD2_MD4` and others) are absent — enforced by `Tests/VeriHash.HotPath.Tests.ps1` "No forbidden WTD_DISABLE_MD2_MD4 flag in VeriHash.HotPath/" and the regex audit in the verification block.

---

## Open follow-ups for Plan 02-02

- **`Get-VeriHashSignature` is the consumable surface for the sig ThreadJob.** Plan 02-02's `Invoke-VeriHashHotPath` should:
  - Run `Test-IsPEFile -Path $path` ONCE on the main thread and pass the result via `-IsPE` to the sig job (avoid re-opening the file inside the ThreadJob).
  - Spawn the sig job with `-InitializationScript { Import-Module <repo>/VeriHash.Core/VeriHash.Core.psd1; Import-Module <repo>/VeriHash.HotPath/VeriHash.HotPath.psd1 }` so the runspace can resolve both `Get-VeriHashPlatform` (Core) and `Get-VeriHashSignature` (HotPath).
  - Treat `Status='error'` from the sig wrapper as the "missing"/error bucket per PERF-04 streaming rules — do NOT fail the file's hash output if the sig job returns `error`.
- **Catalog signatures intentionally out of scope.** `notepad.exe` returns `unsigned` because it is signed via the OS catalog file, not embedded. If catalog verification is later needed, the path is a separate `WTHelperProvDataFromChainContext` / `CryptCATAdminCalcHashFromFileHandle` call; Plan 02-01's PINVOKE-PIN.md has the slot for it but the plan does not ship it.
- **`pSignatureSettings` is `IntPtr.Zero`.** Sufficient for SHA-1 / SHA-256 trust on Win10/11. If the project later targets stricter Authenticode policies (e.g., minimum SHA-256 only), `WINTRUST_SIGNATURE_SETTINGS` becomes a follow-up.

---

## Verification commands (all passing)

```powershell
Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1,Tests/VeriHash.HotPath.PE.Tests.ps1,Tests/VeriHash.HotPath.Sig.Tests.ps1 -Output Detailed
Invoke-ScriptAnalyzer -Path VeriHash.HotPath -Recurse -Settings PSScriptAnalyzerSettings.psd1
Get-ChildItem VeriHash.HotPath -Recurse -File | Select-String -Pattern 'WTD_DISABLE_MD2_MD4|PSFramework|Write-PSFMessage|\$IsWindows|\$RunningOnWindows'
# zero matches expected
```
