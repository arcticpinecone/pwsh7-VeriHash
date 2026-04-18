# Phase 2: Hot-Path Performance + Multi-File Loop — Research

**Researched:** 2026-04-18
**Domain:** PowerShell 7+ parallel orchestration (`Start-ThreadJob`) + Win32 P/Invoke (`WinVerifyTrust`) + multi-file CLI loop with strict tally
**Confidence:** HIGH (stack/patterns), MEDIUM (P/Invoke struct shape — needs Microsoft Docs cross-check before committing the type-def string), HIGH (project conventions)

---

## Summary

Phase 2 introduces a new `VeriHash.HotPath` module that orchestrates parallel hash + Authenticode signature checking via `Start-ThreadJob`, with PE-file detection (`MZ` magic-byte read), network CRL lookups disabled (`WinVerifyTrust` P/Invoke), progressive console streaming, and a multi-file batch loop with a strict tally line. CONTEXT.md has already locked the major architectural choices (D-A1..D-A7); the planner's remaining work is mechanical: pin the exact P/Invoke struct definition, choose a poll cadence for `Wait-Job -Any`, decide the perf-fixture strategy, and write the offline-network test in a way that doesn't depend on actually disabling networking.

The single biggest risk to sequence correctly is **the P/Invoke struct layout**: `WINTRUST_DATA` has version-sensitive fields (`pSignatureSettings` was added in Windows 8) and a discriminated union (`dwUnionChoice` / `pFile|pCatalog|pBlob|pSgnr|pCert`). Get the struct from a canonical source (Microsoft Docs `wintrust.h` or pinvoke.net) and pin it once — do not invent fields.

**Primary recommendation:** Build the module in three vertical slices (Wave 1 = WinVerifyTrust shim + signature wrapper; Wave 2 = `Invoke-VeriHashHotPath` with ThreadJob streaming; Wave 3 = `Invoke-VeriHashBatch` + tally + perf tests + `Profile-VeriHashTiming.ps1` extension). Use `Wait-Job -Any` with a 50–100ms polling timeout and `Receive-Job -Keep` to drain output. Generate the perf-fixture file on-the-fly in Pester `BeforeAll` (do not commit a 100MB file). Implement the "offline-network" test by **observing** that no `WTD_REVOCATION_CHECK_*` flag besides `_NONE` is passed, plus a Pester `Mock` that asserts the WinVerifyTrust shim is invoked with the locked flags — actually disabling networking on a CI host is fragile and out of scope.

---

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Area 1 — CRL-disabling mechanism (D-A1-1):** WinVerifyTrust P/Invoke in `VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1`. Flags: `WTD_REVOCATION_NONE | WTD_CACHE_ONLY_URL_RETRIEVAL` ONLY. **Forbidden:** `WTD_DISABLE_MD2_MD4` and any other downgrade flags. `Add-Type` is wrapped in `if (-not ('VeriHash.WinTrust' -as [type])) { Add-Type ... }`. Public wrapper `Get-VeriHashSignature` returns an object with `Status` ∈ `{valid, invalid, unsigned, skipped, error}` and `Reason` (short string). Non-Windows → `Status='skipped', Reason='not supported on this platform'`, never P/Invokes.

**Area 2 — Module location (D-A2-1):** New `VeriHash.HotPath` module at repo root, mirroring Phase 1 layout (`.psd1`, `.psm1`, `Public/`, `Private/`). Public surface:
- `Invoke-VeriHashHotPath` — single-file orchestrator (PE-detect, hash-job, sig-job, stream, return).
- `Invoke-VeriHashBatch` — multi-file loop, tally.

**Area 3 — ThreadJob orchestration (D-A3-1/2/3):** Two ThreadJobs (symmetric topology). Each started with `-InitializationScript { Import-Module <repo>/VeriHash.Core/VeriHash.Core.psd1 }`. Main thread loops `Wait-Job -Any -Timeout <small>` and prints whichever job finishes first via `Format-VeriHashReport`.

**Area 4 — Multi-file loop (D-A4-1/2/3):** Sequential `foreach` over files (no per-file parallelism). Tally is exactly 3 buckets: `<m>/<N> matched, <x> mismatch, <z> missing`. Read errors / sig errors / exceptions all fold into `missing`. Continue-and-tally on per-file failure (never fail-fast in batch mode).

**Area 5 — Streaming (D-A5-1):** Hybrid. `Invoke-VeriHashHotPath` calls `Format-VeriHashReport` for each printable line (Write-Host, golden-text-fixture-compatible) AND returns a `[pscustomobject] -PSTypeName 'VeriHash.HotPathResult'` with `FilePath`, `Hash`, `HashAlgorithm`, `HashElapsedMs`, `Signature`, `SignatureReason`, `SigElapsedMs`, `WallClockMs`, `IsPE`, `MatchResult`. `Invoke-VeriHashBatch` returns `'VeriHash.BatchResult'` with `Results[]`, `Tally{}`, `TallyLine`. Tests assert structured objects; humans see host output.

**Area 6 — PE-detect (D-A6-1):** `[System.IO.File]::OpenRead` + 2-byte read + immediate `Dispose()` in `VeriHash.HotPath/Private/Test-IsPEFile.ps1`. `$true` iff bytes are `0x4D 0x5A`. <2 bytes → `$false`. Read errors → `$false` (treat as not-PE; the file's actual error surfaces via the hash job).

**Area 7 — Profiler tolerance (D-A7-1):** Two-tier perf testing.
- **Strict (`Profile-VeriHashTiming.ps1`, dev-only):** `wallClock <= 1.2 * max(hashMs, sigMs) + 100ms`.
- **Differential (Pester `-Tag 'Performance'`):** `wallClock < 0.85 * (hashMs + sigMs)` on a fixture sized so `min(hash, sig) > ~200ms`. Excludable on slow runners with `-ExcludeTag Performance`.

### the agent's Discretion

These are the planner's calls (per CONTEXT.md `<open_questions_for_planner>`):
- Exact `WINTRUST_DATA` / `WINTRUST_FILE_INFO` field list and `TRUST_E_*` HRESULT → `Status` mapping (canonical struct from Microsoft Docs, do not invent).
- `Wait-Job -Any` poll cadence (50ms is a reasonable starting point) vs. `Receive-Job -Wait` on the first-finishing job.
- Pester perf-fixture: stored under `Tests/Fixtures/` (bloats repo) vs. generated on-the-fly in `BeforeAll` (preferred, lean repo).
- `Invoke-VeriHashBatch` log-line strategy: one log line per file (preferred per CONTEXT.md) vs. one summary line per batch.
- Plan count (CONTEXT.md hints 3 plans; final breakdown is the planner's call).

### Deferred Ideas (OUT OF SCOPE)

- Per-file parallelism in `Invoke-VeriHashBatch` (`ForEach-Object -Parallel` over files) — output-order risk.
- `Format.ps1xml` for `VeriHash.HotPathResult` / `VeriHash.BatchResult` — `PSTypeName` enables this later.
- Signature timeout fallback (`Wait-Job -Timeout` on the sig job) — only if real hangs are observed.
- macOS `codesign` integration — non-Windows is just `skipped`.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PERF-01 | Skip signature for non-PE; show `Signature: skipped (not a PE file)` | `Test-IsPEFile` (D-A6-1); signature-line rendering branch in `Format-VeriHashReport` extension |
| PERF-02 | Disable network CRL lookups | WinVerifyTrust P/Invoke with `WTD_REVOCATION_CHECK_NONE | WTD_CACHE_ONLY_URL_RETRIEVAL` (D-A1-1) |
| PERF-03 | Hash + sig run in parallel via `Start-ThreadJob`; wall ≈ max | Two ThreadJobs, `-InitializationScript` (D-A3-1/2); perf-test fixture sized so `min(hash,sig) > 200ms` (D-A7-1) |
| PERF-04 | Progressive streaming; hash line printed first | `Wait-Job -Any` poll loop (D-A3-3); hybrid Write-Host + return (D-A5-1) |
| PERF-05 | Displayed elapsed = wall-clock of whole call | `WallClockMs` field on `VeriHash.HotPathResult` (D-A5-1) |
| MULTI-01 | `[string[]] $FilePath` parameter; SendTo passes multiple files in one invocation | `Invoke-VeriHashBatch` accepts `[string[]]` (D-A2-1) |
| MULTI-02 | One block per file + tally `X/N matched, Y mismatch, Z missing` | Sequential foreach + locked tally string (D-A4-1/2) |
| MULTI-03 | Loop mode preserves single-file features (clipboard, sidecar, parallel sig) | Batch loops over `Invoke-VeriHashHotPath`, which IS the single-file path (D-A2-1) |

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| File hashing | `VeriHash.Core` (`Get-VeriHashResult`) | — | Phase 1 owns hashing primitives; Phase 2 only schedules them |
| Authenticode signature check (Windows) | `VeriHash.HotPath/Private/Invoke-WinVerifyTrust` | `wintrust.dll` (OS) | Phase 2 owns the P/Invoke + flag selection; OS does the cert-chain math |
| PE-file detection | `VeriHash.HotPath/Private/Test-IsPEFile` | — | New, hot-path-local, no caller outside HotPath |
| Parallel orchestration (per file) | `VeriHash.HotPath/Public/Invoke-VeriHashHotPath` | `ThreadJob` module (PS7 built-in) | The whole point of Phase 2 |
| Multi-file loop + tally | `VeriHash.HotPath/Public/Invoke-VeriHashBatch` | — | Sequential, no per-file parallelism |
| Output rendering | `VeriHash.Core/Public/Format-VeriHashReport` (Phase 1) | — | Phase 2 calls it twice per file (hash, sig); does NOT add a new printer |
| Comparison (clipboard / sidecar) | `VeriHash.Core` (`Read-ClipboardHash`, `Test-VeriHashSidecar`) | — | Phase 1 functions called per-file by `Invoke-VeriHashHotPath` |
| Logging | `VeriHash.Core/Public/Write-VeriHashLog` (Phase 1) | — | One plain-text line per file (recommended), not per-batch |
| Platform check | `VeriHash.Core/Public/Get-VeriHashPlatform` (Phase 1) | — | The ONLY platform check; no new `$IsWindows` definitions in HotPath |
| CLI dispatch | (Phase 5 thin CLI) | — | Phase 2 ships modules; CLI work is Phase 5 |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Microsoft.PowerShell.ThreadJob` | 2.2.0 | `Start-ThreadJob`, `Wait-Job`, `Receive-Job`, `Remove-Job` | Ships with PowerShell 7+; same-process runspaces (low overhead vs. `Start-Job` background processes) — `[VERIFIED: Get-Module -ListAvailable returned ThreadJob 2.2.0 at C:\program files\powershell\7\Modules\]` |
| `wintrust.dll` (Windows OS) | OS | `WinVerifyTrust` API for Authenticode | Only API path that exposes `WTD_*` revocation/cache flags; `Get-AuthenticodeSignature` does NOT expose these flags — `[CITED: learn.microsoft.com/en-us/windows/win32/api/wintrust/nf-wintrust-winverifytrust]` |
| `Pester` | 5.x (≤ 5.99) | Unit + integration + perf tests | Already pinned by repo CI (`<= 5.99`) — `[VERIFIED: .github/workflows/ci.yml line 42 per codebase/TESTING.md]` |
| `PSScriptAnalyzer` | current | Lint | Already pinned by repo CI — `[VERIFIED: PSScriptAnalyzerSettings.psd1 in repo root]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `[System.IO.File]` (BCL) | .NET 8 (PS7.4+) | `OpenRead` for 2-byte PE magic check | PE-detect — short-lived stream, immediate `Dispose()` |
| `[System.Diagnostics.Stopwatch]` (BCL) | .NET 8 | Wall-clock measurement | `WallClockMs` field on result object; perf assertions — `[VERIFIED: already used in Profile-VeriHashTiming.ps1 lines 27, 33, 49, 71, 80, 88]` |
| `[System.Runtime.InteropServices]` (BCL) | .NET 8 | `Marshal.AllocHGlobal`, `StructureToPtr`, `FreeHGlobal` for `WINTRUST_DATA` lifetime | WinVerifyTrust shim — `[CITED: standard P/Invoke pattern; learn.microsoft.com/en-us/dotnet/standard/native-interop/]` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Start-ThreadJob` (two jobs) | `ForEach-Object -Parallel` (PS7 native) | Lower-level control over individual job lifecycles is needed (PERF-04 streaming "first finished prints first" — `-Parallel` collects results, doesn't expose per-iteration completion order cleanly). **Decision locked: ThreadJob (D-A3-1).** |
| `Start-ThreadJob` | Runspace pool API directly | More code, no measurable benefit for 2 jobs. ThreadJob IS a thin runspace-pool wrapper. |
| `WinVerifyTrust` P/Invoke | `Get-AuthenticodeSignature -ErrorAction SilentlyContinue` | Cmdlet does not expose `WTD_REVOCATION_CHECK_NONE` / `WTD_CACHE_ONLY_URL_RETRIEVAL` flags — fails PERF-02. **Decision locked: P/Invoke (D-A1-1).** — `[CITED: learn.microsoft.com Get-AuthenticodeSignature has no flag-control parameter]` |
| `[System.IO.File]::OpenRead` for PE-detect | `Get-Content -AsByteStream -TotalCount 2` | Pipeline overhead (~5-15ms) on the hot path; `OpenRead` is ~0.1ms. **Decision locked: OpenRead (D-A6-1).** |

**Installation:** No new module installs. Everything ships with PowerShell 7.

**Version verification:**
- `Microsoft.PowerShell.ThreadJob` 2.2.0 — `[VERIFIED: Get-Module -ListAvailable on dev machine 2026-04-18; PowerShell 7.6.0]`
- Pester ≤5.99 — `[VERIFIED: codebase/TESTING.md line 9 cites .github/workflows/ci.yml:42]`

---

## Architecture Patterns

### System Architecture Diagram

```
                       Invoke-VeriHashBatch (Public)
                              [string[]] $FilePath
                                      │
                                      ▼
                       sequential foreach $file in $FilePath
                                      │
                       ┌──────────────┴──────────────┐
                       │   try { Invoke-VeriHashHotPath }    │
                       │   catch { record 'missing' bucket } │
                       └──────────────┬──────────────┘
                                      │
                                      ▼
                       Invoke-VeriHashHotPath (Public)
                                      │
                       ┌──────────────┴────────────────────────────┐
                       ▼                                            ▼
              Test-IsPEFile (Private)               clipboardHash = Read-ClipboardHash (Core)
            (OpenRead 2 bytes, dispose)
                       │
              ┌────────┴─────────┐
              │  Stopwatch start │   ◄── WallClockMs root
              └────────┬─────────┘
                       │
        ┌──────────────┴──────────────────┐
        │                                  │
        ▼                                  ▼
  Start-ThreadJob (Hash)           Start-ThreadJob (Sig)
  -InitializationScript            -InitializationScript
  Import-Module Core               Import-Module HotPath
  Get-VeriHashResult $p            if (IsPE) Get-VeriHashSignature $p
                                   else      [pscustomobject]@{Status='skipped';...}
        │                                  │
        └────────────────┬─────────────────┘
                         ▼
        while ($jobs) { Wait-Job -Any -Timeout 0.05 }
            ├─► first done → Receive-Job → Format-VeriHashReport (hash line)
            ├─► second done → Receive-Job → Format-VeriHashReport (sig line)
            └─► Remove-Job both
                         │
                         ▼
                  Stopwatch stop ─► WallClockMs
                         │
                         ▼
              Test-VeriHashSidecar (Core)  ◄── if a .shaXXX sidecar exists
                         │
                         ▼
              return [pscustomobject -PSTypeName 'VeriHash.HotPathResult']
                         │
                         ▼            (back in batch loop)
                accumulate Tally {Matched|Mismatch|Missing}
                         │
                         ▼ (after loop)
              Format-VeriHashReport TallyLine  &  return 'VeriHash.BatchResult'

  WINDOWS-ONLY (inside Sig ThreadJob):
  Get-VeriHashSignature → Invoke-WinVerifyTrust (Private)
       │
       ├─ if (-not ('VeriHash.WinTrust' -as [type])) { Add-Type ... }   ◄── one-time per runspace
       ├─ Marshal.AllocHGlobal(WINTRUST_FILE_INFO + WINTRUST_DATA)
       ├─ pinvoke WinVerifyTrust(NULL, WINTRUST_ACTION_GENERIC_VERIFY_V2, &wtd)
       │     dwUIChoice              = WTD_UI_NONE (2)
       │     fdwRevocationChecks     = WTD_REVOKE_NONE (0)
       │     dwUnionChoice           = WTD_CHOICE_FILE (1)
       │     dwStateAction           = WTD_STATEACTION_VERIFY (1) ; close with WTD_STATEACTION_CLOSE (2)
       │     dwProvFlags             = WTD_REVOCATION_CHECK_NONE (0x00000010)
       │                             | WTD_CACHE_ONLY_URL_RETRIEVAL (0x00001000)
       ├─ map HRESULT → Status enum (table below)
       └─ free unmanaged memory in finally{}
```

Reading the diagram: SendTo (or terminal) hands an array of paths to `Invoke-VeriHashBatch`; the loop runs sequentially; each iteration spins **two** ThreadJobs and prints whichever finishes first; PE-detect happens ONCE on the main thread before the sig job is shaped (sig job runs `Get-VeriHashSignature` which takes the IsPE flag); after both jobs return, sidecar verification runs synchronously (cheap), the result is bucketed, and the loop continues.

### Recommended Project Structure
```
VeriHash.HotPath/
├── VeriHash.HotPath.psd1
├── VeriHash.HotPath.psm1               # ~20-line loader; mirrors VeriHash.Core.psm1
├── Public/
│   ├── Invoke-VeriHashHotPath.ps1      # single-file orchestrator
│   ├── Invoke-VeriHashBatch.ps1        # multi-file loop + tally
│   └── Get-VeriHashSignature.ps1       # public wrapper around private P/Invoke
└── Private/
    ├── Invoke-WinVerifyTrust.ps1       # Add-Type + P/Invoke shim (Windows-only)
    ├── Test-IsPEFile.ps1               # 2-byte MZ check
    └── Format-VeriHashTallyLine.ps1    # locked tally-string formatter

Tests/
├── VeriHash.HotPath.Tests.ps1          # main behavior suite
├── VeriHash.HotPath.PE.Tests.ps1       # PE-detect edge cases
├── VeriHash.HotPath.Sig.Tests.ps1      # signature-wrapper + flag-assertion (Mock)
├── VeriHash.HotPath.Batch.Tests.ps1    # multi-file + tally string
├── VeriHash.HotPath.Perf.Tests.ps1     # -Tag 'Performance' (D-A7-1 differential)
└── Fixtures/
    ├── tiny-pe.bin                     # 64-byte committed file with MZ header (no signature)
    └── tiny-not-pe.bin                 # 64-byte committed file without MZ
    # (large perf fixture is generated in BeforeAll via [byte[]]::new(150MB) | random; NOT committed)
```

### Pattern 1: Two-ThreadJob orchestration with `Wait-Job -Any` polling
**What:** Start hash and sig in their own ThreadJobs; main thread polls `Wait-Job -Any -Timeout` and renders whichever completes first.
**When to use:** Whenever exactly two parallel sub-tasks need their results *streamed in completion order* (not just collected).
**Example:**
```powershell
# Source: pattern derived from learn.microsoft.com/en-us/powershell/module/threadjob/start-threadjob
# (CITED) and CONTEXT.md D-A3-3 (LOCKED)
$hashJob = Start-ThreadJob -Name 'hash' -InitializationScript {
    Import-Module $using:CorePsd1Path -Force
} -ScriptBlock {
    param($p, $algo) Get-VeriHashResult -Path $p -Algorithm $algo
} -ArgumentList $Path, $Algorithm

$sigJob = Start-ThreadJob -Name 'sig' -InitializationScript {
    Import-Module $using:HotPathPsd1Path -Force   # Note: HotPath, not Core (carries Get-VeriHashSignature)
} -ScriptBlock {
    param($p, $isPE) Get-VeriHashSignature -Path $p -IsPE:$isPE
} -ArgumentList $Path, $isPE

$pending = @($hashJob, $sigJob)
$hashResult = $null; $sigResult = $null
while ($pending.Count -gt 0) {
    $done = Wait-Job -Job $pending -Any -Timeout 1   # 1s ceiling; tight inner poll not needed
    if ($null -eq $done) { continue }                # spurious wake / timeout
    $payload = Receive-Job -Job $done -Wait -AutoRemoveJob
    if ($done.Name -eq 'hash') { $hashResult = $payload; Format-VeriHashReport -Result $payload }
    else                       { $sigResult  = $payload; <render sig line> }
    $pending = @($pending | Where-Object Id -ne $done.Id)
}
```
**Why `-Timeout 1` not `-Timeout 0.05`:** `Wait-Job -Any` blocks until a job completes OR the timeout fires. A 1-second ceiling has identical streaming feel (jobs typically complete in ms-to-seconds) and dramatically lower CPU spin than 50ms polling. The 50ms figure in CONTEXT.md is a starting point; recommend revising to **1000ms** unless a specific reason emerges. `-AutoRemoveJob` makes `Remove-Job` cleanup unnecessary. — `[CITED: learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/wait-job parameter docs]`

### Pattern 2: P/Invoke shim with re-import guard
**What:** `Add-Type -TypeDefinition` declares the WinVerifyTrust C# bridge once per runspace; guard prevents "type already defined" errors on `Import-Module -Force`.
**Example:**
```powershell
# Source: standard pattern; CONTEXT.md D-A1-1 LOCKED
if (-not ('VeriHash.WinTrust' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace VeriHash {
    [StructLayout(LayoutKind.Sequential)]
    public struct WINTRUST_FILE_INFO {
        public uint   cbStruct;
        [MarshalAs(UnmanagedType.LPWStr)] public string pcwszFilePath;
        public IntPtr hFile;
        public IntPtr pgKnownSubject;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct WINTRUST_DATA {
        public uint   cbStruct;
        public IntPtr pPolicyCallbackData;
        public IntPtr pSIPClientData;
        public uint   dwUIChoice;
        public uint   fdwRevocationChecks;
        public uint   dwUnionChoice;
        public IntPtr pFile;                    // union slot (we always use FILE)
        public uint   dwStateAction;
        public IntPtr hWVTStateData;
        [MarshalAs(UnmanagedType.LPWStr)] public string pwszURLReference;
        public uint   dwProvFlags;
        public uint   dwUIContext;
        public IntPtr pSignatureSettings;       // Win8+; pass IntPtr.Zero to ignore — CONFIRM via docs
    }
    public static class WinTrust {
        [DllImport("wintrust.dll", CharSet=CharSet.Unicode, SetLastError=false)]
        public static extern int WinVerifyTrust(IntPtr hwnd, [In] ref Guid pgActionID, [In] ref WINTRUST_DATA pWVTData);
    }
}
'@
}
```
**[ASSUMED]:** the `pSignatureSettings` field placement and the absence of any later-added fields. The planner MUST cross-check `wintrust.h` (Windows SDK) or pinvoke.net/wintrust before merging — invented field layout will silently corrupt memory and either return junk HRESULTs or crash the runspace.

### Pattern 3: Locked tally-line formatter
```powershell
# Source: CONTEXT.md <specifics> — byte-locked
function Format-VeriHashTallyLine {
    param([int]$Matched, [int]$Total, [int]$Mismatch, [int]$Missing)
    return ('{0}/{1} matched, {2} mismatch, {3} missing' -f $Matched, $Total, $Mismatch, $Missing)
}
```
The MULTI-02 success-criterion test pins this exact string. Do not parameterize spacing.

### Anti-Patterns to Avoid

- **Using `Start-Job` instead of `Start-ThreadJob`:** `Start-Job` spawns a child `pwsh` process per job (~hundreds of ms of overhead). ThreadJob uses in-process runspaces. The whole point of Phase 2 (PERF-03) collapses if `Start-Job` is used.
- **Calling `Get-AuthenticodeSignature` "with a flag":** the cmdlet has no flag-control parameter. PERF-02 requires P/Invoke.
- **Polling `Wait-Job -State Completed` in a tight `while` loop without `Wait-Job -Any -Timeout`:** burns CPU, no streaming benefit. `Wait-Job -Any` blocks the caller cleanly.
- **Forgetting to `Remove-Job` (or `-AutoRemoveJob`):** completed jobs leak in the session's `Get-Job` list. Use `Receive-Job -Wait -AutoRemoveJob` per Pattern 1.
- **Sharing module-scope state between the two ThreadJobs:** runspaces are isolated. If you need data in a job, pass via `-ArgumentList` or `$using:`. CONTEXT.md mandates `-InitializationScript Import-Module` for this reason (D-A3-2).
- **Adding a new `$IsWindows` / `$RunningOnWindows` definition in HotPath:** CONTEXT.md "carried forward" — `Get-VeriHashPlatform` is the only platform check.
- **Using `Write-PSFMessage` in HotPath:** CONTEXT.md "carried forward" — only `Write-VeriHashLog` (Phase 1) is permitted in new modules. PSFramework leaves entirely in Phase 4.
- **Defining the WinVerifyTrust struct without `[StructLayout(LayoutKind.Sequential)]`:** default `LayoutKind.Auto` reorders fields → silent ABI break.
- **Failing-fast in `Invoke-VeriHashBatch`:** D-A4-3 mandates continue-and-tally. One bad path must not kill a SendTo run.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Background job runspaces | A custom runspace pool wrapper | `Start-ThreadJob` (PS7 built-in) | Same code in 5 lines; mature; tested; matches the locked decision |
| File hashing | Re-implement SHA256 | `Get-VeriHashResult` (Phase 1) → `Get-FileHash` (BCL) | Phase 1 owns it |
| Authenticode chain validation | Hand-roll cert parsing | `WinVerifyTrust` (OS) | OS does PKI correctly; you cannot |
| Output rendering | New printer function | `Format-VeriHashReport` (Phase 1) | Golden-text fixture compatibility (carried-forward) |
| Sidecar verification | Re-implement parser | `Test-VeriHashSidecar` (Phase 1) | Phase 1 owns it; covers v1-compat |
| Clipboard hash parsing | Reinvent | `Read-ClipboardHash` (Phase 1) | Phase 1 owns it |
| Plain-text logging | Roll a logger | `Write-VeriHashLog` (Phase 1) | Phase 1 owns it; PSFramework forbidden |
| Platform detection | New `$IsWindows` block | `Get-VeriHashPlatform` (Phase 1) | CORE-08 / carried-forward |
| Tally arithmetic / formatting | Inline `[string]::Format` per call | `Format-VeriHashTallyLine` (Private) | Centralizes the byte-locked format string; one place to test (MULTI-02) |
| PE-detect via "list of extensions" (`.exe`, `.dll`, ...) | The v1 `$script:SignableExtensions` list approach | `Test-IsPEFile` (2-byte read) | The whole *point* of PERF-01 is content-based detection, not extension-based |

**Key insight:** Phase 2 is almost pure orchestration on top of Phase 1 + the OS. The only genuinely new code is the WinVerifyTrust shim (~80 lines C# + ~40 lines PowerShell wrapper) and ~150 lines of ThreadJob plumbing. Everything else composes.

---

## Runtime State Inventory

> **N/A — Phase 2 is greenfield code addition (new module), not a rename/refactor/migration.**
> No existing data is renamed. No existing service config references the new module names. The only "state" produced is the same `~/.verihash/verihash.log` file Phase 1 already writes to. No category applies; this section is intentionally empty.

---

## Common Pitfalls

### Pitfall 1: Reusing `Get-AuthenticodeSignature` "to save time"
**What goes wrong:** Cmdlet does network CRL lookups by default (PERF-02 fails). It also returns a rich `[Signature]` object that's slow to marshal across the ThreadJob boundary.
**Why it happens:** It's the obvious PowerShell-native option and "good enough" for v1.
**How to avoid:** Per D-A1-1, the *only* permitted code path is the WinVerifyTrust P/Invoke shim. Lint-grep CI for `Get-AuthenticodeSignature` in the new module.
**Warning signs:** Slow signature checks on machines with restrictive proxies; CRL-lookup network traffic visible in Process Monitor.

### Pitfall 2: `WINTRUST_DATA` struct field drift
**What goes wrong:** Forget `pSignatureSettings` (Win8+), or miss a field, or get field order wrong → unmanaged memory corruption, junk HRESULT, sometimes a `STATUS_ACCESS_VIOLATION` that takes down the runspace.
**Why it happens:** the agents copy from old (XP/Vista-era) snippets that pre-date `pSignatureSettings`.
**How to avoid:** Take the struct from a current source: Microsoft `wintrust.h` (Windows SDK), `pinvoke.net/default.aspx/wintrust/WinVerifyTrust.html`, or PowerShellGet's `Microsoft.PowerShell.Security` source. Add a Pester test that calls `Invoke-WinVerifyTrust` against a known-signed file (`pwsh.exe` itself) and asserts a sane HRESULT.
**Warning signs:** HRESULT values not in the documented `TRUST_E_*` / `CERT_E_*` range; intermittent crashes when `Import-Module` is run with `-Force`.

### Pitfall 3: HRESULT → Status mapping gaps
**What goes wrong:** Map only `0` (success) and `TRUST_E_NOSIGNATURE` (unsigned) → every other failure mode (expired cert, untrusted root, malformed file, signature mismatch) collapses to `error` with no useful `Reason`.
**Why it happens:** The HRESULT space is large and most snippets only handle the happy path.
**How to avoid:** Map at minimum:
| HRESULT | Hex | Status | Reason example |
|---------|-----|--------|----------------|
| `S_OK` | `0x00000000` | `valid` | (empty) |
| `TRUST_E_NOSIGNATURE` | `0x800B0100` | `unsigned` | `not signed` |
| `TRUST_E_BAD_DIGEST` | `0x80096010` | `invalid` | `bad digest` |
| `TRUST_E_EXPLICIT_DISTRUST` | `0x800B0111` | `invalid` | `explicit distrust` |
| `CERT_E_EXPIRED` | `0x800B0101` | `invalid` | `cert expired` |
| `CERT_E_REVOKED` | `0x80092010` | `invalid` | `cert revoked` |
| `CERT_E_UNTRUSTEDROOT` | `0x800B0109` | `invalid` | `untrusted root` |
| `CERT_E_CHAINING` | `0x800B010A` | `invalid` | `chain build failed` |
| any other | — | `error` | `0x{hresult:X8}` |

`[CITED: learn.microsoft.com/en-us/windows/win32/seccrypto/common-hresult-values; pinvoke.net wintrust constants]`

**Warning signs:** Real-world signed-but-expired binaries flagged `error` instead of `invalid`.

### Pitfall 4: `WTD_STATEACTION_VERIFY` without matching `WTD_STATEACTION_CLOSE`
**What goes wrong:** Each `WinVerifyTrust` call with `WTD_STATEACTION_VERIFY` (1) allocates a state handle in `WINTRUST_DATA.hWVTStateData`. If you don't call again with `WTD_STATEACTION_CLOSE` (2), Windows leaks the handle for the lifetime of the process. Per file. Across thousands of files (batch mode), this matters.
**Why it happens:** Tutorials show only the verify call, not the close call.
**How to avoid:** Wrap the VERIFY call in `try { ... } finally { <call again with WTD_STATEACTION_CLOSE> ; FreeHGlobal }`.
**Warning signs:** `Process` working set grows steadily across a large batch.

### Pitfall 5: `Start-ThreadJob` runspace doesn't see imported modules
**What goes wrong:** ThreadJob runspaces inherit module *paths* but not all *imports*; `Get-VeriHashResult` is "not recognized" inside the job.
**Why it happens:** PS7's ThreadJob uses a fresh runspace; `InitialSessionState` only carries some inheritance.
**How to avoid:** D-A3-2 mandates `-InitializationScript { Import-Module <abs-path>/VeriHash.Core.psd1 }`. Use `$using:CorePsd1Path` to flow the absolute path in.
**Warning signs:** Job state = `Failed`; `Receive-Job` raises `CommandNotFoundException`.

### Pitfall 6: "Hash always prints first" assumption is wrong on small files
**What goes wrong:** PERF-04 success criterion says "hash line prints before signature line." For a small file with valid signature, the signature job CAN finish first.
**Why it happens:** A 1KB file hashes in <1ms; signature verification has fixed overhead (cert chain walk).
**How to avoid:** D-A3-3 is symmetric: "whichever job completes first prints first." The success criterion uses "common case" wording — read it as "in the common case (large file), hash prints first; orchestration handles either order cleanly." Test BOTH orderings.
**Warning signs:** PERF-04 test that hard-codes "hash before sig" fails on the small fixture.

### Pitfall 7: PE detect on a directory or symlink
**What goes wrong:** `[System.IO.File]::OpenRead` on a directory throws `UnauthorizedAccessException`; on a broken symlink throws `FileNotFoundException`.
**Why it happens:** SendTo doesn't filter; users right-click folders.
**How to avoid:** D-A6-1 says "Read errors return `$false` (not-PE)." Catch the exception, return `$false`, let the hash job surface the real error in its result.
**Warning signs:** Stack traces from `Test-IsPEFile` instead of clean "missing" bucketing.

### Pitfall 8: Pester `Mock` of `Invoke-WinVerifyTrust` from inside a ThreadJob doesn't apply
**What goes wrong:** Pester `Mock` operates on the test's runspace; the ThreadJob runs in a fresh runspace where the mock doesn't exist → real `WinVerifyTrust` runs.
**Why it happens:** Mocks are session-state scoped.
**How to avoid:** For the offline-network test (SC #1), test `Get-VeriHashSignature` (the public wrapper) **synchronously** without going through `Invoke-VeriHashHotPath`. Mock `Invoke-WinVerifyTrust` and assert it was called with the locked flag values. Test ThreadJob orchestration separately with a mock signature wrapper that just returns a fixed object.
**Warning signs:** `Should -Invoke` returns `Times = 0` even though the orchestrator clearly ran.

### Pitfall 9: `Add-Type` race on parallel module imports
**What goes wrong:** Two ThreadJobs both `Import-Module HotPath`; both hit `Add-Type` simultaneously → "type already defined" error in one of them.
**Why it happens:** PS type system is process-wide; `-as [type]` check is not atomic with `Add-Type`.
**How to avoid:** Only the **sig** ThreadJob needs HotPath imported (it calls `Get-VeriHashSignature`). The hash ThreadJob only needs Core. Initialize each job's runspace with the module it needs, not both. The guard (`if (-not ('VeriHash.WinTrust' -as [type]))`) handles the re-import case within a single runspace.
**Warning signs:** Sporadic "type with name 'VeriHash.WinTrust' already exists" failures; only on test-suite re-runs.

### Pitfall 10: Performance test flaps on CI
**What goes wrong:** `wallClock < 0.85 * (hashMs + sigMs)` passes locally (`hashMs` and `sigMs` both ~500ms) but fails on a slow CI runner (`hashMs=200ms`, `sigMs=200ms`, `wallClock=380ms` — passes ratio 0.95 instead of 0.85).
**Why it happens:** ThreadJob startup overhead (~50-150ms in cold runspaces) eats the parallel margin when subtasks are short.
**How to avoid:** Ensure `min(hashMs, sigMs) > ~200ms` per D-A7-1. Generate a 100-200MB random file in `BeforeAll` (not committed; `[byte[]]::new(150*1MB)` then `Set-Content -AsByteStream`). Tag the test `Performance` so it can be excluded on the slowest runners.
**Warning signs:** Test passes locally, fails in CI; ratio computation ranges 0.85–0.95.

---

## Code Examples

### `Test-IsPEFile` (Private)
```powershell
# Source: D-A6-1 (LOCKED) + standard PE-magic-byte check
function Test-IsPEFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$Path)
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $buf = [byte[]]::new(2)
            $read = $stream.Read($buf, 0, 2)
            return ($read -eq 2 -and $buf[0] -eq 0x4D -and $buf[1] -eq 0x5A)
        } finally { $stream.Dispose() }
    } catch {
        return $false   # any I/O error = treat as not-PE; let the hash job surface the real error
    }
}
```

### `Invoke-VeriHashBatch` skeleton (Public)
```powershell
# Source: D-A4-1/2/3 (LOCKED)
function Invoke-VeriHashBatch {
    [CmdletBinding()]
    [OutputType('VeriHash.BatchResult')]
    param(
        [Parameter(Mandatory)] [string[]] $FilePath,
        [ValidateSet('MD5','SHA256','SHA512')] [string] $Algorithm = 'SHA256',
        [switch] $Log
    )
    $results  = New-Object System.Collections.Generic.List[object]
    $matched  = 0; $mismatch = 0; $missing = 0
    foreach ($p in $FilePath) {
        try {
            $r = Invoke-VeriHashHotPath -Path $p -Algorithm $Algorithm -Log:$Log
            $results.Add($r)
            switch ($r.MatchResult) {
                'matched'  { $matched++ }
                'mismatch' { $mismatch++ }
                default    { $missing++ }
            }
        } catch {
            $missing++
            $results.Add([pscustomobject]@{
                PSTypeName = 'VeriHash.HotPathResult'
                FilePath   = $p
                MatchResult = 'missing'
                SignatureReason = "$($_.Exception.Message)"
            })
        }
    }
    $tallyLine = '{0}/{1} matched, {2} mismatch, {3} missing' -f $matched, $FilePath.Count, $mismatch, $missing
    Write-Host $tallyLine -ForegroundColor Yellow
    return [pscustomobject]@{
        PSTypeName = 'VeriHash.BatchResult'
        Results    = $results.ToArray()
        Tally      = @{ Total=$FilePath.Count; Matched=$matched; Mismatch=$mismatch; Missing=$missing }
        TallyLine  = $tallyLine
    }
}
```

### `Profile-VeriHashTiming.ps1` strict-assertion extension
```powershell
# Source: D-A7-1 (LOCKED). Add to existing script — do NOT create a new file.
# Extension is GATED on a new -Strict switch so existing callers (Test-All.ps1 step 3/3) keep passing.
param(
    # ... existing params ...
    [switch]$Strict
)
# ... existing measurement code ...
if ($Strict) {
    $hashMs = $measurements['Hash Computation']
    $sigMs  = $measurements['Digital Signature Check']
    $wallMs = $resultObject.Total   # or stopwatch around the hot-path call
    $bound  = (1.2 * [math]::Max($hashMs, $sigMs)) + 100
    if ($wallMs -gt $bound) {
        throw "Strict perf assertion failed: wallClock=${wallMs}ms > 1.2*max(${hashMs},${sigMs})+100 = ${bound}ms"
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Start-Job` (child process) | `Start-ThreadJob` (in-process runspace) | PowerShell 6+; ThreadJob shipped in-box with PS7 | ~10–100x lower job-startup overhead; required for sub-second hot path |
| Extension-based PE detection (`.exe`, `.dll`, ...) | Magic-byte detection (`MZ` 0x4D 0x5A) | (project-internal change for v2) | Correctness on renamed files; PERF-01 |
| `Get-AuthenticodeSignature` (network CRLs by default) | `WinVerifyTrust` P/Invoke with `WTD_REVOCATION_CHECK_NONE | WTD_CACHE_ONLY_URL_RETRIEVAL` | (always — but cmdlet hides this knob) | PERF-02; offline correctness |
| PSFramework structured logging | `Write-VeriHashLog` plain-text | Phase 1 (CORE-07) | Zero external deps; simpler |
| Single-file per CLI invocation | `[string[]] $FilePath` batch | This phase (MULTI-01) | SendTo of N files → one invocation |

**Deprecated/outdated:**
- `Start-Job` for short-lived parallel work — superseded by `Start-ThreadJob`.
- Extension-list PE detection (`$script:SignableExtensions` in v1 monolith) — superseded by content-based `Test-IsPEFile`.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `WINTRUST_DATA` field order and presence (esp. `pSignatureSettings` placement) match the layout shown in Pattern 2 | Architecture Patterns / Pattern 2 | **HIGH** — wrong layout causes silent memory corruption / wrong HRESULTs / runspace crashes. Planner MUST pin to a current canonical source (Microsoft `wintrust.h` SDK header or `pinvoke.net/default.aspx/wintrust/WinVerifyTrust.html`) before the executor codes the shim. |
| A2 | The flag named "WTD_REVOCATION_NONE" in CONTEXT.md is actually `WTD_REVOCATION_CHECK_NONE` (`0x00000010`) — a `dwProvFlags` value (NOT to be confused with `WTD_REVOKE_NONE = 0`, an `fdwRevocationChecks` value) | User Constraints / Common Pitfalls | MEDIUM — both flags must be set correctly: `fdwRevocationChecks = WTD_REVOKE_NONE (0)` AND `dwProvFlags |= WTD_REVOCATION_CHECK_NONE (0x10)`. CONTEXT.md author may have conflated the names. Confirm with user/docs before coding. |
| A3 | `Wait-Job -Any -Timeout 1` (1 second) is preferable to `-Timeout 0.05` (50ms) suggested in CONTEXT.md | Pattern 1 | LOW — both work; 1s is a CPU-friendliness optimization with no streaming-feel cost. CONTEXT.md explicitly invites the planner to revisit (`<open_questions_for_planner>`). |
| A4 | The HRESULT → Status mapping table in Pitfall 3 is sufficient for real-world signed binaries | Common Pitfalls / Pitfall 3 | LOW — additional `TRUST_E_*` / `CERT_E_*` values may surface in production; mapping any unknown HRESULT to `error` with `Reason='0x{X8}'` is the safety net. |
| A5 | Generating a 100–200 MB random fixture in Pester `BeforeAll` (vs. committing it) is the right tradeoff | Recommended Project Structure | LOW — ~2 seconds extra setup time vs. ~150 MB repo bloat. Aligns with CONTEXT.md `<open_questions_for_planner>` recommendation ("preferred"). |
| A6 | Pester `Mock` of `Invoke-WinVerifyTrust` will work for PERF-02 verification when called through the public wrapper synchronously, even though it won't work across ThreadJob boundaries | Pitfall 8 + Validation Architecture | LOW — split test strategy is standard Pester practice for parallel code. |
| A7 | `Get-VeriHashSignature` should accept an `-IsPE` switch from the caller (so PE-detect runs once on the main thread, not duplicated inside the sig job) | Architecture Diagram | LOW — alternative is to re-detect inside the job; one extra 0.1ms file open. Either works; main-thread-detect avoids duplication. |
| A8 | `WTD_STATEACTION_VERIFY` (1) and `WTD_STATEACTION_CLOSE` (2) numeric constants are correct | Code Examples / Pitfall 4 | LOW — well-documented constants but planner should confirm against `wintrust.h`. |

---

## Open Questions (RESOLVED)

> All five open questions resolved during planning. Each `RESOLVED:` marker cites the plan/task that implements the decision so the executor can trace it back.

1. **Exact `WINTRUST_DATA` struct field list (and whether to include `pSignatureSettings`)**
   - What we know: structure exists; layout is `LayoutKind.Sequential`; `pSignatureSettings` was added in Win8.
   - What's unclear: any post-Win8 additions; whether passing `IntPtr.Zero` for `pSignatureSettings` is legal on Win10/11 (almost certainly yes; standard practice).
   - Recommendation: planner pins the struct from Microsoft `wintrust.h` (Windows 11 SDK) before Wave 1 executes; embeds the SDK URL/version as a comment in `Invoke-WinVerifyTrust.ps1`.
   - **RESOLVED:** Plan `02-01` Task 0 (PINVOKE-PIN gate) produces `02-01-PINVOKE-PIN.md` with the verbatim struct field list and SDK citation BEFORE Task 2 writes the P/Invoke shim.

2. **`Wait-Job -Any` timeout: 50ms (CONTEXT) vs. 1s (recommended) vs. `Receive-Job -Wait`?**
   - What we know: All three work for PERF-04. Streaming feel is identical for any timeout under ~1s because real jobs take 10ms–10s.
   - What's unclear: whether `Receive-Job -Wait -AutoRemoveJob` on the first-finishing job (no poll loop at all, just block twice) is cleaner than the loop.
   - Recommendation: prototype both during Wave 2; pick whichever is shorter and survives a kill-the-job test (Ctrl+C cleanup). 1-second `-Any` poll is the safe default.
   - **RESOLVED:** Plan `02-02` Task 2 uses `Wait-Job -Any -Timeout 1` (the safe default).

3. **Offline-network test for SC #1 — how to falsify the absence of network CRLs?**
   - What we know: CONTEXT.md SC #1 says "verified by an offline-network test."
   - What's unclear: whether to actually disable networking on the CI host (fragile, may not even work on GitHub Actions runners with deep net stack) or to test it through observation (Mock asserts the right flags were passed; integration test with `netsh wlan disconnect` only on developer Windows machine, marked Skip in CI).
   - Recommendation: **two layers** — (a) Pester `Mock Invoke-WinVerifyTrust` and assert `dwProvFlags -band 0x1010 -eq 0x1010` (= both required flags set) — runs everywhere; (b) optional manual integration test under `-Tag 'Offline'` that disconnects the runner network adapter — Skip-by-default. The first layer is the actual contract.
   - **RESOLVED:** `02-VALIDATION.md` adopts the two-layer strategy (Mock-based assertion as the contract; `-Tag 'Offline'` manual integration test as opt-in QA). Implemented by Plan `02-01` Task 1 (RED tests) and Task 2 (GREEN flag-locked shim).

4. **Where does `Invoke-VeriHashHotPath` get the absolute path to `VeriHash.Core.psd1` for the `-InitializationScript` Import-Module?**
   - What we know: ThreadJob `-InitializationScript` runs in a fresh runspace; relative paths from the orchestrator's `$PSScriptRoot` work as long as the path is captured *before* the ThreadJob starts and passed via `$using:`.
   - What's unclear: whether to compute it from `$PSScriptRoot` of `Invoke-VeriHashHotPath.ps1` (climbs `..\..\VeriHash.Core\VeriHash.Core.psd1`) or from `(Get-Module VeriHash.Core).Path`.
   - Recommendation: use `(Get-Module VeriHash.Core).Path` if Core is already imported in the caller; fall back to `$PSScriptRoot\..\..\VeriHash.Core\VeriHash.Core.psd1`. Either way, snapshot to a local before `Start-ThreadJob` and pass via `$using:`.
   - **RESOLVED:** Plan `02-02` Task 2 uses `(Get-Module VeriHash.Core).Path` with `$PSScriptRoot\..\..\VeriHash.Core\VeriHash.Core.psd1` fallback; snapshots to a local before `Start-ThreadJob` and passes via `$using:`.

5. **Should `Invoke-VeriHashBatch` accept a single file? (i.e., is "1 file" a degenerate batch?)**
   - What we know: MULTI-01 says "thin CLI accepts `[string[]] $FilePath`"; doesn't say `[string[]]` requires N>1.
   - What's unclear: whether single-file invocation should print a tally line (`1/1 matched, 0 mismatch, 0 missing`) or skip it.
   - Recommendation: ALWAYS print the tally for `Invoke-VeriHashBatch` (it's the loop function); the Phase 5 thin CLI is responsible for choosing `Invoke-VeriHashHotPath` (no tally) vs. `Invoke-VeriHashBatch` (tally) based on `$FilePath.Count`.
   - **RESOLVED:** Plan `02-03` Task 1 asserts the literal `'1/1 matched, 0 mismatch, 0 missing'` tally for the single-file batch case; Task 2 always emits the tally line. CLI dispatch is deferred to Phase 5.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PowerShell | All | ✓ | 7.6.0 | — |
| `Microsoft.PowerShell.ThreadJob` | PERF-03/04 | ✓ | 2.2.0 | — (ships in-box with PS7) |
| `wintrust.dll` | PERF-02 (Windows path) | ✓ on Windows | OS | non-Windows: signature wrapper returns `Status='skipped', Reason='not supported on this platform'` (D-A1-1) — no fallback needed |
| `Add-Type` (CSharp compiler) | WinVerifyTrust shim | ✓ | bundled with PS7 | — |
| Pester | All tests | Assumed installed (CI installs `<= 5.99`) | 5.x | — |
| PSScriptAnalyzer | Lint | Assumed installed | current | — |
| Disk space for perf fixture | PERF-03 differential test | Assumed (~200MB free in `$TestDrive`) | — | Skip `-Tag 'Performance'` if `[System.IO.DriveInfo]::GetDrives()` shows < 500MB free |

**Missing dependencies with no fallback:** None — PowerShell 7 + Windows OS provide everything needed.

**Missing dependencies with fallback:** None — non-Windows path is explicit (skipped status), not a fallback.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Pester 5.x (≤ 5.99) |
| Config file | None — inline `New-PesterConfiguration` in `Test-All.ps1` and `.github/workflows/ci.yml` |
| Quick run command | `Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1 -Output Detailed` |
| Full suite command | `.\Test-All.ps1 -CI` |
| Performance subset | `Invoke-Pester -Path Tests/ -Tag 'Performance' -Output Detailed` |
| Skip performance on slow runner | `Invoke-Pester -Path Tests/ -ExcludeTag 'Performance'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PERF-01a | Non-PE file → signature line `Signature: skipped (not a PE file)`; sig job NOT spawned | unit | `Invoke-Pester Tests/VeriHash.HotPath.PE.Tests.ps1 -Output Detailed` | ❌ Wave 0 |
| PERF-01b | PE file (MZ header) → `Test-IsPEFile` returns `$true` | unit | same | ❌ Wave 0 |
| PERF-01c | <2 byte file / read error → `Test-IsPEFile` returns `$false` (no throw) | unit | same | ❌ Wave 0 |
| PERF-02 | `Invoke-WinVerifyTrust` invoked with `dwProvFlags` containing both `WTD_REVOCATION_CHECK_NONE (0x10)` and `WTD_CACHE_ONLY_URL_RETRIEVAL (0x1000)`, AND `fdwRevocationChecks = WTD_REVOKE_NONE (0)` | unit (Mock) | `Invoke-Pester Tests/VeriHash.HotPath.Sig.Tests.ps1 -Output Detailed` — `Mock Invoke-WinVerifyTrust { ... }` + `Should -Invoke -ParameterFilter { $WtdData.dwProvFlags -band 0x1010 -eq 0x1010 -and $WtdData.fdwRevocationChecks -eq 0 }` | ❌ Wave 0 |
| PERF-02 (offline integration, opt-in) | Real WinVerifyTrust call against an unsigned PE on a network-disconnected host completes in < 100ms | integration `-Tag 'Offline'` | manual; Skip-by-default | ❌ Wave 0 |
| PERF-03 | `Invoke-VeriHashHotPath` on a 150MB fixture: `wallClockMs < 0.85 * (hashMs + sigMs)` | perf `-Tag 'Performance'` | `Invoke-Pester Tests/VeriHash.HotPath.Perf.Tests.ps1 -Tag Performance -Output Detailed` | ❌ Wave 0 |
| PERF-04 | Both completion orderings (hash-first, sig-first) handled — orchestrator drains via `Wait-Job -Any` and renders the first-finished job's line first | unit (synthetic jobs) | `Invoke-Pester Tests/VeriHash.HotPath.Tests.ps1 -Output Detailed` — inject mock `Invoke-VeriHashHotPath` jobs that sleep deterministic amounts | ❌ Wave 0 |
| PERF-05 | Returned `WallClockMs` is within ±50ms of `Measure-Command { Invoke-VeriHashHotPath ... }` | unit | same file | ❌ Wave 0 |
| MULTI-01 | `Invoke-VeriHashBatch -FilePath @('a','b','c')` accepts string[] and runs all three | unit | `Invoke-Pester Tests/VeriHash.HotPath.Batch.Tests.ps1 -Output Detailed` | ❌ Wave 0 |
| MULTI-02a | TallyLine equals exactly `2/3 matched, 1 mismatch, 0 missing` for {match, match, mismatch} | unit (string-equality) | same | ❌ Wave 0 |
| MULTI-02b | Read error / sig error / exception bucketed as `missing` (not `mismatch`, not thrown) | unit | same | ❌ Wave 0 |
| MULTI-02c | `Invoke-VeriHashBatch` does NOT fail-fast (one bad path, two good → 2/3 matched) | unit | same | ❌ Wave 0 |
| MULTI-03 | Per-file result in batch mode shows clipboard compare AND sidecar compare AND parallel sig (asserted via inspection of `Results[0].Hash`, `Results[0].Signature`, host output captured via `*>&1`) | integration | same | ❌ Wave 0 |
| Module sanity | `Import-Module VeriHash.HotPath/VeriHash.HotPath.psd1 -Force` succeeds; `Get-Command -Module VeriHash.HotPath` lists `Invoke-VeriHashHotPath`, `Invoke-VeriHashBatch`, `Get-VeriHashSignature` | unit | `Invoke-Pester Tests/VeriHash.HotPath.Tests.ps1 -Output Detailed` | ❌ Wave 0 |
| Re-import safety | `Import-Module ... -Force` twice does not throw (Add-Type guard works) | unit | same | ❌ Wave 0 |
| Cross-platform | Module imports cleanly on Linux; `Get-VeriHashSignature` returns `Status='skipped'` without P/Invoke attempt | unit (skip-on-Windows variant) | same | ❌ Wave 0 |
| Golden-text fixture (carried-forward) | `Format-VeriHashReport` output for a single-file `Invoke-VeriHashHotPath` still matches the Phase 1 golden fixture (with one new `Signature:` line appended) | golden-text | `Invoke-Pester Tests/VeriHash.HotPath.Tests.ps1 -Output Detailed` | ❌ Wave 0 (new fixture variant) |

### Sampling Rate
- **Per task commit:** `Invoke-Pester -Path Tests/VeriHash.HotPath.<Subset>.Tests.ps1 -ExcludeTag 'Performance' -Output Detailed`
- **Per wave merge:** `Invoke-Pester -Path Tests/ -ExcludeTag 'Performance' -Output Detailed`
- **Phase gate:** `.\Test-All.ps1 -CI` (full suite) + `Invoke-Pester -Tag 'Performance'` (locally) green before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `Tests/VeriHash.HotPath.Tests.ps1` — module sanity, re-import safety, cross-platform skip
- [ ] `Tests/VeriHash.HotPath.PE.Tests.ps1` — `Test-IsPEFile` covering MZ / non-MZ / <2 bytes / I/O error / directory / symlink
- [ ] `Tests/VeriHash.HotPath.Sig.Tests.ps1` — `Get-VeriHashSignature` + Mock-based PERF-02 flag assertion + HRESULT → Status table coverage
- [ ] `Tests/VeriHash.HotPath.Batch.Tests.ps1` — MULTI-01/02/03 + tally byte-locked string + continue-and-tally
- [ ] `Tests/VeriHash.HotPath.Perf.Tests.ps1` (`-Tag Performance`) — PERF-03 differential + 150MB fixture generated in `BeforeAll`
- [ ] `Tests/Fixtures/tiny-pe.bin` (committed, ~64 bytes, valid MZ header, unsigned)
- [ ] `Tests/Fixtures/tiny-not-pe.bin` (committed, ~64 bytes, no MZ header)
- [ ] (Optional) `Tests/VeriHash.HotPath.Offline.Tests.ps1` (`-Tag Offline`) — manual network-disconnect integration; Skip-by-default
- [ ] Extension to `Profile-VeriHashTiming.ps1` adding `-Strict` switch with the D-A7-1 strict assertion

---

## Project Constraints (from .github/copilot-instructions.md and PROJECT.md)

- **No PSFramework in `VeriHash.HotPath/`.** Use `Write-VeriHashLog` only (carried-forward + copilot-instructions line 142).
- **PowerShell 7+ cross-platform.** Module must `Import-Module` cleanly on Windows/Linux/macOS. Sig path is Windows-only and gated by `Get-VeriHashPlatform` (carried-forward).
- **TDD rule.** Tests are never modified to pass — modify the code (copilot-instructions line 156).
- **Visual output stays v1-compatible.** `Format-VeriHashReport` (Phase 1) is the only printer; golden-text fixture must still pass with the appended `Signature:` line (carried-forward).
- **No new platform-detection code.** `Get-VeriHashPlatform` is the single canonical check (Phase 1 CORE-08).
- **Test isolation env-var.** `$env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')` in `BeforeAll`; clear in `AfterAll` (copilot-instructions line 88; carried-forward).
- **`Import-Module` not dot-sourcing.** Tests load HotPath via `Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force` (copilot-instructions lines 65, 162).
- **Lint suppressions stay (`PSAvoidUsingWriteHost`, `PSAvoidUsingBrokenHashAlgorithms`).** Don't disable additional rules; new code must pass existing lint config.
- **Function signature pattern.** Every non-trivial function has `[CmdletBinding()]`, `[OutputType()]`, comment-based help with `.SYNOPSIS`/`.DESCRIPTION`/`.PARAMETER`/`.OUTPUTS`/`.EXAMPLE` (copilot-instructions lines 102–120).
- **PE detection IS content-based.** Do NOT use `$script:SignableExtensions`-style extension lists; PERF-01 mandates magic-byte detection.
- **Forbidden flags: `WTD_DISABLE_MD2_MD4` and any other downgrade flags** (CONTEXT.md D-A1-1). EDR will flag them.

---

## Sources

### Primary (HIGH confidence)
- `.planning/phases/02-hot-path-performance-multi-file-loop/02-CONTEXT.md` — locked decisions D-A1..D-A7
- `.planning/REQUIREMENTS.md` — PERF-01..05, MULTI-01..03 verbatim
- `.planning/ROADMAP.md` — Phase 2 success criteria 1–5
- `.planning/PROJECT.md` — vision, constraints, tech stack
- `.planning/codebase/STRUCTURE.md`, `CONVENTIONS.md`, `TESTING.md` — repo intel (Pester pattern, `$TestDrive`, env-var isolation, function signature pattern)
- `.github/copilot-instructions.md` — TDD rule, PSFramework prohibition, test isolation env var, Import-Module pattern
- `VeriHash.Core/VeriHash.Core.psm1`, `.psd1`, and Public/* files — `[VERIFIED: read 2026-04-18]` Phase 1 surface that HotPath consumes
- `Profile-VeriHashTiming.ps1` — `[VERIFIED: read 2026-04-18]` existing perf script extended in this phase
- `VeriHash.ps1` lines 1115–1160 — `[VERIFIED: read 2026-04-18]` v1 Authenticode call shape (the v1-compatible visual output reference)
- ThreadJob 2.2.0 in PowerShell 7.6.0 — `[VERIFIED: Get-Module -ListAvailable on dev machine 2026-04-18]`

### Secondary (MEDIUM confidence — citing canonical docs from training)
- `[CITED: learn.microsoft.com/en-us/windows/win32/api/wintrust/nf-wintrust-winverifytrust]` — `WinVerifyTrust` API signature
- `[CITED: learn.microsoft.com/en-us/windows/win32/api/wintrust/ns-wintrust-wintrust_data]` — `WINTRUST_DATA` struct (planner MUST re-confirm field list before coding)
- `[CITED: learn.microsoft.com/en-us/windows/win32/api/wintrust/ns-wintrust-wintrust_file_info]` — `WINTRUST_FILE_INFO` struct
- `[CITED: learn.microsoft.com/en-us/windows/win32/seccrypto/common-hresult-values]` — `TRUST_E_*` / `CERT_E_*` HRESULT values
- `[CITED: learn.microsoft.com/en-us/powershell/module/threadjob/start-threadjob]` — `Start-ThreadJob`, `-InitializationScript`, `-ArgumentList`
- `[CITED: learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/wait-job]` — `-Any`, `-Timeout`
- `[CITED: learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/receive-job]` — `-Wait`, `-AutoRemoveJob`
- `[CITED: pinvoke.net/default.aspx/wintrust/WinVerifyTrust.html]` — community-maintained WinVerifyTrust P/Invoke reference

### Tertiary (LOW confidence — flagged in Assumptions Log)
- A1: exact `WINTRUST_DATA` field order — `[ASSUMED]` from training; planner pins from current SDK
- A2: `WTD_REVOCATION_CHECK_NONE` vs `WTD_REVOCATION_NONE` naming — `[ASSUMED]` clarification

---

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — ThreadJob 2.2.0 verified on dev machine; Pester pinning verified in CI config.
- Architecture: **HIGH** — most decisions are locked in CONTEXT.md; recommendations build on Phase 1 verified module surface.
- WinVerifyTrust struct shape: **MEDIUM** — pattern is canonical but planner MUST verify field list against current Microsoft SDK before Wave 1 codes the shim.
- HRESULT mapping table: **MEDIUM** — values are well-documented but real-world coverage may need expansion.
- Pitfalls: **HIGH** — most are general PS7/ThreadJob/P-Invoke patterns plus project-specific carried-forward constraints.
- Validation architecture: **HIGH** — test strategy follows established Pester patterns documented in `codebase/TESTING.md`.

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (30 days; PowerShell 7.6 / ThreadJob 2.2 are stable)

---

## RESEARCH COMPLETE

**Phase:** 2 — Hot-Path Performance + Multi-File Loop
**Confidence:** HIGH overall (one MEDIUM area: WinVerifyTrust struct layout — flagged in Assumptions Log A1, A2 for planner verification before Wave 1)

### Key Findings
- `Microsoft.PowerShell.ThreadJob` 2.2.0 verified available in PowerShell 7.6.0 on the dev machine — no install step needed for PERF-03.
- The whole module is ~3 vertical slices on top of Phase 1: WinVerifyTrust shim + signature wrapper (Wave 1), `Invoke-VeriHashHotPath` orchestrator (Wave 2), `Invoke-VeriHashBatch` + tally + perf tests + Profile-VeriHashTiming.ps1 extension (Wave 3) — matches CONTEXT.md hint.
- The CONTEXT.md flag name `WTD_REVOCATION_NONE` is almost certainly `WTD_REVOCATION_CHECK_NONE` (`0x00000010`, a `dwProvFlags` value), distinct from `WTD_REVOKE_NONE = 0` (an `fdwRevocationChecks` value). Both flags must be set correctly for PERF-02. Planner should clarify with user.
- Recommend `Wait-Job -Any -Timeout 1` (1 second) over CONTEXT.md's suggested 50ms — same streaming feel, dramatically lower CPU spin. CONTEXT.md explicitly invites the planner to revisit.
- Offline-network test for SC #1 should be implemented as a Pester `Mock` of `Invoke-WinVerifyTrust` asserting the locked flag values — actually disconnecting the runner network is fragile and out of scope. Optional `-Tag 'Offline'` integration test for manual dev-machine validation.
- 100–200 MB perf fixture should be generated on-the-fly in Pester `BeforeAll`, not committed (lean repo).
- Pitfall 8 (Pester Mock doesn't reach inside ThreadJob runspaces) is the single biggest test-architecture gotcha — split tests: synchronous public-wrapper tests for flag assertions, separate orchestration tests using mock signature wrappers.

### File Created
`.planning/phases/02-hot-path-performance-multi-file-loop/02-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | ThreadJob 2.2.0 verified on dev machine; Pester ≤5.99 verified in CI config |
| Architecture (orchestration) | HIGH | All major decisions locked in CONTEXT.md; pattern composes cleanly on Phase 1 |
| WinVerifyTrust struct shape | MEDIUM | Canonical pattern from training/docs; planner MUST cross-check current SDK before coding (flagged Assumption A1) |
| HRESULT → Status mapping | MEDIUM | Coverage of common cases; real-world binaries may surface additional values (safety net = `error` + `Reason='0x{X8}'`) |
| Pitfalls | HIGH | Mix of well-known PS7/ThreadJob/P-Invoke gotchas + project-specific carried-forward constraints |
| Validation architecture | HIGH | Pester patterns documented in codebase/TESTING.md; test split addresses Mock-across-runspace pitfall |

### Open Questions (deferred to planning / discussion)
1. Confirm `WTD_REVOCATION_CHECK_NONE` vs `WTD_REVOCATION_NONE` naming with user (Assumption A2).
2. Pin exact `WINTRUST_DATA` field list from current Windows SDK header before Wave 1 (Assumption A1).
3. `Wait-Job -Any` timeout value: 50ms (CONTEXT) vs 1s (recommended) vs `Receive-Job -Wait` no-poll variant — prototype in Wave 2.
4. Single-file invocation of `Invoke-VeriHashBatch`: emit `1/1 matched, ...` tally, or skip tally? Recommendation: always emit; CLI chooses single vs. batch entry point.
5. Whether to ship the optional `-Tag 'Offline'` manual integration test in Phase 2 or defer to a v2.x QA pass.

### Ready for Planning
Research complete. Planner can decompose into 3 plans (per CONTEXT.md hint) or finer-grained breakdown. Critical pre-Wave-1 gate: planner must resolve Assumptions A1 and A2 (struct layout + flag naming) — either by user confirmation or by explicit verification against Microsoft SDK / docs — before the executor codes `Invoke-WinVerifyTrust.ps1`.
