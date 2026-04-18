# Phase 2: Hot-Path Performance + Multi-File Loop — Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 14 new (7 production + 6 test + 1 fixture pair) + 1 modified (`Profile-VeriHashTiming.ps1`)
**Analogs found:** 13 / 14 (only `Invoke-WinVerifyTrust.ps1` has no in-repo analog — see "No Analog Found")

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `VeriHash.HotPath/VeriHash.HotPath.psd1` | module manifest | n/a | `VeriHash.Core/VeriHash.Core.psd1` | exact (mirror) |
| `VeriHash.HotPath/VeriHash.HotPath.psm1` | module loader | n/a | `VeriHash.Core/VeriHash.Core.psm1` | exact (verbatim shape) |
| `VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1` | public function (orchestrator) | event-driven (ThreadJob completion) + request-response | `VeriHash.Core/Public/Get-VeriHashResult.ps1` (signature shape only); `Format-VeriHashReport.ps1` (host I/O) | role-match — no orchestrator analog exists |
| `VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1` | public function (loop + tally) | batch / request-response | `VeriHash.Core/Public/Test-VeriHashSidecar.ps1` (composes other Public fns) | role-match |
| `VeriHash.HotPath/Public/Get-VeriHashSignature.ps1` | public wrapper (platform-gated) | request-response | `VeriHash.Core/Public/Read-ClipboardHash.ps1` (Windows-only with `Get-VeriHashPlatform` gate) | exact (gating shape) |
| `VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1` | P/Invoke shim | transform (managed → native → managed) | **none** in repo — see "No Analog Found" | n/a |
| `VeriHash.HotPath/Private/Test-IsPEFile.ps1` | private helper (predicate) | file I/O (read 2 bytes) | `VeriHash.Core/Private/Resolve-VeriHashLogPath.ps1` (private predicate/lookup) | role-match |
| `Tests/VeriHash.HotPath.Tests.ps1` | test (module sanity) | n/a | `Tests/VeriHash.Core.Module.Tests.ps1` | exact |
| `Tests/VeriHash.HotPath.PE.Tests.ps1` | test (private predicate) | n/a | `Tests/VeriHash.Core.Get-VeriHashResult.Tests.ps1` (fixture-file pattern) | role-match |
| `Tests/VeriHash.HotPath.Sig.Tests.ps1` | test (mock + assert flag values) | n/a | `Tests/VeriHash.Core.Read-ClipboardHash.Tests.ps1` (uses `Mock`) — see Pitfall 8 in RESEARCH.md | role-match |
| `Tests/VeriHash.HotPath.Batch.Tests.ps1` | test (string-locked tally) | n/a | `Tests/VeriHash.Core.Write-VeriHashLog.Tests.ps1` (`Should -Match` on locked line shape) | exact (assertion style) |
| `Tests/VeriHash.HotPath.Perf.Tests.ps1` | test (`-Tag Performance`) | n/a | `Tests/VeriHash.Timing.Tests.ps1` (perf assertions on profiler) | role-match |
| `Tests/VeriHash.HotPath.Offline.Tests.ps1` | test (`-Tag Offline`) | n/a | `Tests/VeriHash.HotPath.Sig.Tests.ps1` (sibling — Mock-based flag assertion) | role-match |
| `Tests/Fixtures/tiny-pe.bin` + `tiny-not-pe.bin` | test fixtures (binary) | n/a | `Tests/Fixtures/VeriHash_1024.ico` | exact (small committed binary) |
| `Profile-VeriHashTiming.ps1` (MODIFIED) | profiler script | batch | itself (extend in place) | self |

---

## Pattern Assignments

### `VeriHash.HotPath/VeriHash.HotPath.psd1` (module manifest)

**Analog:** `VeriHash.Core/VeriHash.Core.psd1` — copy verbatim, change four fields:
- `RootModule = 'VeriHash.HotPath.psm1'`
- `GUID = '<NEW GUID — generate via [guid]::NewGuid()>'`
- `Description = 'Hot-path orchestration: PE-detect, parallel hash+Authenticode, multi-file batch with tally.'`
- `FunctionsToExport = 'Invoke-VeriHashHotPath','Invoke-VeriHashBatch','Get-VeriHashSignature'`

**Verbatim header to copy** (analog lines 1–37):
```powershell
@{
RootModule = 'VeriHash.HotPath.psm1'
ModuleVersion = '2.0.0'
CompatiblePSEditions = 'Core'
GUID = '<new>'
Author = 'arcticpinecone'
CompanyName = 'Unknown'
Copyright = '(c) arcticpinecone. All rights reserved.'
Description = 'Hot-path orchestration: PE-detect, parallel hash+Authenticode, multi-file batch with tally.'
PowerShellVersion = '7.0'
```

**Export block pattern** (analog lines 71–82):
```powershell
FunctionsToExport = 'Invoke-VeriHashHotPath', 'Invoke-VeriHashBatch', 'Get-VeriHashSignature'
CmdletsToExport   = @()
VariablesToExport = @()
AliasesToExport   = @()
```

**Note for planner:** The Phase 1 `Module.Tests` (analog lines 26–30) asserts `PowerShellVersion 7.0` and `CompatiblePSEditions Core` via `Test-ModuleManifest`. Phase 2's `VeriHash.HotPath.Tests.ps1` must mirror that assertion → keep manifest fields identical.

---

### `VeriHash.HotPath/VeriHash.HotPath.psm1` (module loader)

**Analog:** `VeriHash.Core/VeriHash.Core.psm1` — copy verbatim. No edits required; the `$PSScriptRoot/Private` and `$PSScriptRoot/Public` dot-source pattern is path-relative and already correct.

**Verbatim copy** (analog lines 1–13):
```powershell
$ErrorActionPreference = 'Stop'

# Dot-source Private helpers FIRST so Public functions can call them at runtime.
Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

# Then dot-source Public functions.
$publicFiles = @(Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -ErrorAction SilentlyContinue)
foreach ($f in $publicFiles) { . $f.FullName }

# Belt-and-suspenders alongside the manifest's FunctionsToExport.
Export-ModuleMember -Function $publicFiles.BaseName
```

---

### `VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1` (public, orchestrator, event-driven)

**Analogs:**
- Function-signature shape & comment-based help: `VeriHash.Core/Public/Get-VeriHashResult.ps1` lines 1–24
- Result-object emission shape: `Get-VeriHashResult.ps1` lines 30–37
- Host rendering (called per printable line per D-A5-1): `Format-VeriHashReport.ps1` (just *call* it; never re-implement)
- Per-file composition pattern (clipboard + sidecar): `Test-VeriHashSidecar.ps1` lines 22–53
- ThreadJob orchestration shape: **no in-repo analog** — use RESEARCH.md "Pattern 1" (lines 227–257)

**Function signature pattern** (copy from `Get-VeriHashResult.ps1` lines 1–24):
```powershell
function Invoke-VeriHashHotPath {
    <#
    .SYNOPSIS
        Single-file hot-path orchestrator: PE-detect, parallel hash+sig, stream output, return result.
    .DESCRIPTION
        ... (mirror the .DESCRIPTION/.PARAMETER/.OUTPUTS structure of Get-VeriHashResult) ...
    .OUTPUTS
        VeriHash.HotPathResult
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.HotPathResult')]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [ValidateSet('MD5', 'SHA256', 'SHA512')] [string] $Algorithm = 'SHA256',
        [switch] $Log
    )
    ...
}
```

**Result-object shape** (CONTEXT.md D-A5-1 + analog `Get-VeriHashResult.ps1` lines 30–37 for the `[pscustomobject] @{ PSTypeName = 'VeriHash.<Type>' ...}` idiom):
```powershell
return [pscustomobject]@{
    PSTypeName      = 'VeriHash.HotPathResult'
    FilePath        = $resolved
    Hash            = $hash               # lowercase hex
    HashAlgorithm   = $Algorithm
    HashElapsedMs   = [int]$hashMs
    Signature       = $sigStatus          # valid|invalid|unsigned|skipped|error
    SignatureReason = $sigReason
    SigElapsedMs    = [int]$sigMs
    WallClockMs     = [int]$wallMs
    IsPE            = [bool]$isPE
    MatchResult     = $matchResult        # matched|mismatch|missing
}
```

**ThreadJob pattern to use** (RESEARCH.md Pattern 1, lines 234–255 — no in-repo analog; this is the canonical reference):
```powershell
$hashJob = Start-ThreadJob -Name 'hash' -InitializationScript {
    Import-Module $using:CorePsd1Path -Force
} -ScriptBlock { param($p,$algo) Get-VeriHashResult -Path $p -Algorithm $algo } -ArgumentList $Path, $Algorithm

$sigJob = Start-ThreadJob -Name 'sig' -InitializationScript {
    Import-Module $using:HotPathPsd1Path -Force
} -ScriptBlock { param($p,$isPE) Get-VeriHashSignature -Path $p -IsPE:$isPE } -ArgumentList $Path, $isPE

$pending = @($hashJob, $sigJob)
while ($pending.Count -gt 0) {
    $done = Wait-Job -Job $pending -Any -Timeout 1
    if ($null -eq $done) { continue }
    $payload = Receive-Job -Job $done -Wait -AutoRemoveJob
    if ($done.Name -eq 'hash') { Format-VeriHashReport -Result $payload }
    else                       { <render sig line via Format-VeriHashReport extension> }
    $pending = @($pending | Where-Object Id -ne $done.Id)
}
```

**Wall-clock measurement** (use BCL Stopwatch — the same idiom as `Get-VeriHashResult.ps1` line 27):
```powershell
$sw = [System.Diagnostics.Stopwatch]::StartNew()
# ... orchestration ...
$sw.Stop()
$wallMs = [int]$sw.ElapsedMilliseconds
```

**Per-file Phase 1 composition** (mirror `Test-VeriHashSidecar.ps1` lines 22–29 — call Phase 1 functions; never re-implement):
```powershell
$clip    = Read-ClipboardHash                            # may be $null
$sidecar = Test-VeriHashSidecar -Path $Path              # may be $null
Format-VeriHashReport -Result $hashPayload -CompareTo $clip -SidecarInfo $sidecar
```

**One log line per file** (CONTEXT.md "Notes for the Planner" recommends per-file). Use `Write-VeriHashLog.ps1` per its existing parameter contract (lines 17–39):
```powershell
Write-VeriHashLog -Op verify -Algorithm $Algorithm -Hash $hash -Bytes $size `
                  -ElapsedMs $wallMs -Result $matchResult -Path $Path -Log:$Log
```

---

### `VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1` (public, batch loop + tally)

**Analog:** `VeriHash.Core/Public/Test-VeriHashSidecar.ps1` (composes other public fns + emits typed result). Skeleton already drafted in RESEARCH.md lines 452–493 — use verbatim.

**Function signature pattern** (mirror `Test-VeriHashSidecar.ps1` lines 1–20 + RESEARCH.md skeleton):
```powershell
function Invoke-VeriHashBatch {
    <#
    .SYNOPSIS
        Multi-file hot-path loop: per-file Invoke-VeriHashHotPath, accumulate tally, emit tally line.
    .OUTPUTS
        VeriHash.BatchResult
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.BatchResult')]
    param(
        [Parameter(Mandatory)] [string[]] $FilePath,
        [ValidateSet('MD5','SHA256','SHA512')] [string] $Algorithm = 'SHA256',
        [switch] $Log
    )
    ...
}
```

**Continue-and-tally pattern** (RESEARCH.md lines 463–483, D-A4-3 LOCKED):
```powershell
$results  = New-Object System.Collections.Generic.List[object]
$matched = 0; $mismatch = 0; $missing = 0
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
            PSTypeName       = 'VeriHash.HotPathResult'
            FilePath         = $p
            MatchResult      = 'missing'
            SignatureReason  = "$($_.Exception.Message)"
        })
    }
}
```

**Byte-locked tally line** (CONTEXT.md `<specifics>` — DO NOT reformat):
```powershell
$tallyLine = '{0}/{1} matched, {2} mismatch, {3} missing' -f $matched, $FilePath.Count, $mismatch, $missing
Write-Host $tallyLine -ForegroundColor Yellow
```

**Result-object** (mirror `Get-VeriHashResult.ps1` lines 30–37 idiom; CONTEXT.md D-A5-1 shape):
```powershell
return [pscustomobject]@{
    PSTypeName = 'VeriHash.BatchResult'
    Results    = $results.ToArray()
    Tally      = @{ Total=$FilePath.Count; Matched=$matched; Mismatch=$mismatch; Missing=$missing }
    TallyLine  = $tallyLine
}
```

---

### `VeriHash.HotPath/Public/Get-VeriHashSignature.ps1` (public wrapper, platform-gated)

**Analog:** `VeriHash.Core/Public/Read-ClipboardHash.ps1` lines 14–21 — exact match for "Windows-only with `Get-VeriHashPlatform` gate" pattern. CONTEXT.md D-A1-1 mandates: non-Windows → `Status='skipped', Reason='not supported on this platform'`, never P/Invokes.

**Function signature + platform-gate pattern** (verbatim shape from `Read-ClipboardHash.ps1` lines 14–21):
```powershell
function Get-VeriHashSignature {
    <#
    .SYNOPSIS
        Returns Authenticode signature status for a file via WinVerifyTrust (Windows) or skipped elsewhere.
    .OUTPUTS
        [pscustomobject] @{ Status; Reason } -- Status in valid|invalid|unsigned|skipped|error
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [switch] $IsPE
    )

    if ((Get-VeriHashPlatform) -ne 'Windows') {
        return [pscustomobject]@{ Status = 'skipped'; Reason = 'not supported on this platform' }
    }
    if (-not $IsPE) {
        return [pscustomobject]@{ Status = 'skipped'; Reason = 'not a PE file' }
    }

    # Delegate to private P/Invoke shim:
    $hresult = Invoke-WinVerifyTrust -Path $Path
    return ConvertFrom-WinTrustHResult -HResult $hresult   # private mapper per RESEARCH.md Pitfall 3 table
}
```

**HRESULT → Status map** (RESEARCH.md Pitfall 3 table, lines 370–380 — copy verbatim into a private helper or inline switch).

---

### `VeriHash.HotPath/Private/Test-IsPEFile.ps1` (private predicate, file I/O)

**Analog:** `VeriHash.Core/Private/Resolve-VeriHashLogPath.ps1` for the *file shape* (private helper with `[CmdletBinding()]`, `[OutputType(...)]`, no exported wrapper). The body is given verbatim in RESEARCH.md lines 432–450 (D-A6-1 LOCKED).

**Verbatim implementation** (RESEARCH.md lines 433–450):
```powershell
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
        return $false   # any I/O error = treat as not-PE
    }
}
```

---

### `VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1` (private, P/Invoke shim)

**No in-repo analog.** Phase 1 has zero P/Invoke or `Add-Type -TypeDefinition` usage. **Planner MUST cross-check the struct layout from external authoritative sources before merging** — this is RESEARCH.md Assumption A1 (lines 290–300, plus Pitfall 2 lines 360–364).

**External references the planner must cite:**
- Microsoft `wintrust.h` (Windows SDK) — authoritative `WINTRUST_DATA` / `WINTRUST_FILE_INFO` field layout
- `pinvoke.net/default.aspx/wintrust/WinVerifyTrust.html` — community-maintained current signatures
- `learn.microsoft.com/en-us/windows/win32/api/wintrust/nf-wintrust-winverifytrust`
- `learn.microsoft.com/en-us/windows/win32/seccrypto/common-hresult-values` (HRESULT mapping table)

**Provisional skeleton from RESEARCH.md** (Pattern 2, lines 262–299 — `[ASSUMED]` flagged on `pSignatureSettings` — verify before merge):
```powershell
if (-not ('VeriHash.WinTrust' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace VeriHash {
    [StructLayout(LayoutKind.Sequential)]
    public struct WINTRUST_FILE_INFO { ... }
    [StructLayout(LayoutKind.Sequential)]
    public struct WINTRUST_DATA { ... }
    public static class WinTrust {
        [DllImport("wintrust.dll", CharSet=CharSet.Unicode, SetLastError=false)]
        public static extern int WinVerifyTrust(IntPtr hwnd, [In] ref Guid pgActionID, [In] ref WINTRUST_DATA pWVTData);
    }
}
'@
}
```

**Required mitigations** (CONTEXT.md D-A1-1 + RESEARCH.md Pitfalls 2, 4, 9):
1. **Re-import guard:** `if (-not ('VeriHash.WinTrust' -as [type]))` wrap (LOCKED).
2. **Locked flag set ONLY:** `WTD_REVOCATION_NONE (0x10) | WTD_CACHE_ONLY_URL_RETRIEVAL (0x1000)`. Forbidden: `WTD_DISABLE_MD2_MD4` and any other downgrade flag.
3. **Match `WTD_STATEACTION_VERIFY` with `WTD_STATEACTION_CLOSE` in `finally`** (Pitfall 4) to avoid handle leak per file across batch runs.
4. **`[StructLayout(LayoutKind.Sequential)]` on every struct** (Pitfall 2 — default `Auto` reorders fields → ABI break).

---

### `Tests/VeriHash.HotPath.Tests.ps1` (module sanity)

**Analog:** `Tests/VeriHash.Core.Module.Tests.ps1` — copy verbatim, swap module names.

**Verbatim BeforeAll/AfterAll pattern** (analog lines 1–6):
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
}
AfterAll {
    Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue
}
```

**Export-list assertion pattern** (analog lines 13–24 — adapt the `$expected` list):
```powershell
It 'Exports exactly the three locked public function names' {
    $expected = @('Invoke-VeriHashHotPath','Invoke-VeriHashBatch','Get-VeriHashSignature') | Sort-Object
    $actual = (Get-Command -Module VeriHash.HotPath).Name | Sort-Object
    Compare-Object $actual $expected | Should -BeNullOrEmpty
}
```

**Manifest assertion pattern** (analog lines 26–30 — copy verbatim):
```powershell
It 'Manifest pins PowerShellVersion 7.0 and CompatiblePSEditions Core' {
    $manifest = Test-ModuleManifest "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1"
    $manifest.PowerShellVersion | Should -Be ([version]'7.0')
    $manifest.CompatiblePSEditions | Should -Contain 'Core'
}
```

---

### `Tests/VeriHash.HotPath.PE.Tests.ps1` (PE-detect edge cases)

**Analog:** `Tests/VeriHash.Core.Get-VeriHashResult.Tests.ps1` for fixture-file pattern (lines 1–7).

**Pattern** (analog lines 1–7):
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    $script:PEFixture    = Join-Path $PSScriptRoot 'Fixtures/tiny-pe.bin'
    $script:NotPEFixture = Join-Path $PSScriptRoot 'Fixtures/tiny-not-pe.bin'
}
AfterAll { Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue }
```

**Note:** `Test-IsPEFile` is private; tests must invoke it via `InModuleScope VeriHash.HotPath { Test-IsPEFile -Path ... }`.

---

### `Tests/VeriHash.HotPath.Sig.Tests.ps1` (mock-based flag assertion)

**Analog:** `Tests/VeriHash.Core.Read-ClipboardHash.Tests.ps1` for `Mock` usage. **Critical reference: RESEARCH.md Pitfall 8 (lines 410–414)** — Mocks DO NOT cross ThreadJob runspaces, so test `Get-VeriHashSignature` *synchronously* (no orchestrator).

**Pattern:**
```powershell
BeforeAll { Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force }
AfterAll  { Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue }

Describe 'Get-VeriHashSignature flag-locking (PERF-02)' {
    It 'Calls Invoke-WinVerifyTrust with WTD_REVOCATION_NONE | WTD_CACHE_ONLY_URL_RETRIEVAL only' {
        InModuleScope VeriHash.HotPath {
            Mock Invoke-WinVerifyTrust { return 0 } -Verifiable
            Get-VeriHashSignature -Path $PSCommandPath -IsPE | Out-Null
            # Assert flags via the mock parameter filter — no other flag bits set
            Should -Invoke Invoke-WinVerifyTrust -Times 1 -ParameterFilter {
                # planner: assert WTD constants here when flag-passing arg is finalised
                $true
            }
        }
    }
}
```

---

### `Tests/VeriHash.HotPath.Batch.Tests.ps1` (string-locked tally)

**Analog:** `Tests/VeriHash.Core.Write-VeriHashLog.Tests.ps1` lines 36–40 — exact pattern for "assert byte-locked output line via `Should -Match` on a regex".

**Pattern** (analog line 39 — locked-shape assertion idiom):
```powershell
It 'Tally line is "<m>/<N> matched, <x> mismatch, <z> missing" — byte-locked' {
    $batch = Invoke-VeriHashBatch -FilePath @($f1,$f2,$f3) -Algorithm SHA256
    $batch.TallyLine | Should -Match '^\d+/\d+ matched, \d+ mismatch, \d+ missing$'
    $batch.TallyLine | Should -Be ('{0}/{1} matched, {2} mismatch, {3} missing' -f $batch.Tally.Matched, $batch.Tally.Total, $batch.Tally.Mismatch, $batch.Tally.Missing)
}
```

**Continue-and-tally test** (D-A4-3 — one bad path doesn't kill the run): include a nonexistent path in `$FilePath` and assert `$batch.Tally.Missing -ge 1` and `$batch.Results.Count -eq $FilePath.Count`.

---

### `Tests/VeriHash.HotPath.Perf.Tests.ps1` (`-Tag Performance`)

**Analog:** `Tests/VeriHash.Timing.Tests.ps1` (existing perf-assertion test file).

**Pattern** (D-A7-1 differential tier; RESEARCH.md Pitfall 10 mitigation, lines 422–426 — generate fixture in `BeforeAll`, do NOT commit):
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    # Generate a 150MB random fixture so min(hashMs, sigMs) > 200ms — NOT committed
    $script:PerfFixture = Join-Path $TestDrive 'perf-fixture.bin'
    [byte[]]$bytes = [byte[]]::new(150*1MB)
    (New-Object System.Random).NextBytes($bytes)
    [System.IO.File]::WriteAllBytes($script:PerfFixture, $bytes)
}

Describe 'Hot-path parallelism (PERF-03)' -Tag 'Performance' {
    It 'wallClock < 0.85 * (hashMs + sigMs)' {
        $r = Invoke-VeriHashHotPath -Path $script:PerfFixture -Algorithm SHA256
        $r.WallClockMs | Should -BeLessThan ([int](0.85 * ($r.HashElapsedMs + $r.SigElapsedMs)))
    }
}
```

---

### `Tests/VeriHash.HotPath.Offline.Tests.ps1` (`-Tag Offline`)

**Analog:** `Tests/VeriHash.HotPath.Sig.Tests.ps1` (sibling). Per RESEARCH.md (line 15), do NOT actually disable networking on the CI host — instead, **observe** that no `WTD_REVOCATION_CHECK_*` flag besides `_NONE` is passed to `Invoke-WinVerifyTrust`. This is satisfied by the same Mock-based assertion as `Sig.Tests.ps1`; the Offline tag exists for discoverability/exclusion only.

---

### `Tests/Fixtures/tiny-pe.bin` + `tiny-not-pe.bin` (committed binary fixtures)

**Analog:** `Tests/Fixtures/VeriHash_1024.ico` (~1KB committed binary — same convention).

**Content:**
- `tiny-pe.bin`: minimum 2 bytes starting with `0x4D 0x5A` (`MZ`). Recommend a small valid PE stub (~200 bytes) so it survives any future "is it a sane PE" checks; minimum 2-byte file also acceptable for D-A6-1 alone.
- `tiny-not-pe.bin`: any 2+ bytes NOT starting with `0x4D 0x5A` (e.g., a small text file: `not a pe file\n`).

---

### `Profile-VeriHashTiming.ps1` (MODIFIED — add `-Strict` switch)

**Analog:** itself (lines 8–16 for `param(...)`; lines 27–101 for stopwatch+`$measurements` accumulation).

**Existing param block** (lines 8–16 — extend, do NOT replace):
```powershell
param(
    [Parameter(Mandatory)]
    [string]$FilePath,

    [ValidateSet('SHA256', 'MD5', 'SHA512')]
    [string]$Algorithm = 'SHA256',

    [switch]$Quiet,

    [switch]$Strict          # NEW — D-A7-1 strict assertion
)
```

**Strict-assertion block** (RESEARCH.md lines 504–512; D-A7-1 LOCKED — append AFTER existing measurement code, BEFORE the `return $resultObject` at line 167):
```powershell
if ($Strict) {
    $hashMs = $measurements['Hash Computation']
    $sigMs  = $measurements['Digital Signature Check']
    $wallMs = $resultObject.Total   # or wrap whole script in stopwatch
    $bound  = (1.2 * [math]::Max($hashMs, $sigMs)) + 100
    if ($wallMs -gt $bound) {
        throw "Strict perf assertion failed: wallClock=${wallMs}ms > 1.2*max(${hashMs},${sigMs})+100 = ${bound}ms"
    }
}
```

**Compatibility note:** `Test-All.ps1` calls this script in step 3/3 without `-Strict`; the gate keeps existing CI green. Profile-VeriHashTiming runs in dev only when `-Strict` is passed.

---

## Shared Patterns

### Platform gating (Windows-only paths)

**Source:** `VeriHash.Core/Public/Read-ClipboardHash.ps1` lines 18–21
**Apply to:** `Get-VeriHashSignature.ps1`, `Invoke-WinVerifyTrust.ps1` (defensive guard at top)
```powershell
if ((Get-VeriHashPlatform) -ne 'Windows') {
    return [pscustomobject]@{ Status = 'skipped'; Reason = 'not supported on this platform' }
}
```
**Forbidden** (CONTEXT.md "carried forward"): `$IsWindows` / `$RunningOnWindows` redefinitions in HotPath.

### Result-object emission

**Source:** `VeriHash.Core/Public/Get-VeriHashResult.ps1` lines 30–37
**Apply to:** `Invoke-VeriHashHotPath`, `Invoke-VeriHashBatch`
```powershell
return [pscustomobject]@{
    PSTypeName = 'VeriHash.<TypeName>'
    Field1     = ...
    Field2     = ...
}
```

### Function preamble (every Public function)

**Source:** `VeriHash.Core/Public/Get-VeriHashResult.ps1` lines 1–24
**Apply to:** All three new Public functions
- Comment-based help: `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER ...`, `.OUTPUTS`
- `[CmdletBinding()]` attribute
- `[OutputType('VeriHash.<Type>')]` or `[OutputType([bool])]` etc.
- `param(...)` with `[Parameter(Mandatory)]` and `[ValidateSet(...)]` where applicable

### Logging (per-file, gated by `-Log` or env)

**Source:** `VeriHash.Core/Public/Write-VeriHashLog.ps1` lines 17–39 (param contract); `Resolve-VeriHashLogPath.ps1` lines 13–14 (`VERIHASH_LOG_PATH` env override)
**Apply to:** `Invoke-VeriHashHotPath` (one line per file with `Op='verify'`), `Invoke-VeriHashBatch` (passes `-Log:$Log` through to inner orchestrator)
```powershell
Write-VeriHashLog -Op verify -Algorithm $Algorithm -Hash $hash -Bytes $size `
                  -ElapsedMs $wallMs -Result $matchResult -Path $Path -Log:$Log
```

### Test isolation (env-var pattern)

**Source:** `Tests/VeriHash.Core.Write-VeriHashLog.Tests.ps1` lines 9–18 (`BeforeEach`/`AfterEach`)
**Apply to:** ALL Phase 2 test files that exercise `Write-VeriHashLog` (i.e., `Invoke-VeriHashHotPath` and `Invoke-VeriHashBatch` integration tests)
```powershell
BeforeEach {
    $script:LogPath = Join-Path $TestDrive 'verihash.log'
    $env:VERIHASH_LOG_PATH = $script:LogPath
    Remove-Item Env:VERIHASH_LOG -ErrorAction SilentlyContinue
}
AfterEach {
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG      -ErrorAction SilentlyContinue
}
```

### Test BeforeAll/AfterAll module load

**Source:** `Tests/VeriHash.Core.Module.Tests.ps1` lines 1–6
**Apply to:** Every Phase 2 test file
```powershell
BeforeAll { Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force }
AfterAll  { Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue }
```
**Note:** Tests that depend on Phase 1 also import `VeriHash.Core` — both modules can be `Import-Module`'d in the same `BeforeAll`.

### Stopwatch wall-clock measurement

**Source:** `VeriHash.Core/Public/Get-VeriHashResult.ps1` line 27 (`[System.Diagnostics.Stopwatch]::StartNew()`)
**Apply to:** `Invoke-VeriHashHotPath` (`WallClockMs`), `Profile-VeriHashTiming.ps1` (already used throughout)

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1` | P/Invoke shim | transform (managed → native) | Repo has zero `Add-Type -TypeDefinition` / DllImport usage. Planner MUST use external authoritative sources (Microsoft `wintrust.h`, pinvoke.net, `learn.microsoft.com/wintrust` docs) per RESEARCH.md Assumption A1 (lines 290–300) and Pitfall 2 (lines 360–364). The skeleton in RESEARCH.md Pattern 2 is `[ASSUMED]` — verify struct layout against Windows SDK header before merge. |

---

## Metadata

**Analog search scope:** `VeriHash.Core/Public`, `VeriHash.Core/Private`, `Tests/`, `Profile-VeriHashTiming.ps1`, `VeriHash.ps1` (lines 1115–1160 for Authenticode-call shape comparison only — superseded by D-A1-1 P/Invoke).
**Files scanned:** 17 (.ps1 + .psd1 + .psm1 + 2 markdown convention docs)
**Pattern extraction date:** 2026-04-18

## PATTERN MAPPING COMPLETE
