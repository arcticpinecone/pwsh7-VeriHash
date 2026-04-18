---
phase: 02-hot-path-performance-multi-file-loop
plan: 02
type: execute
wave: 2
depends_on:
  - "02-01"
files_modified:
  - VeriHash.HotPath/VeriHash.HotPath.psd1
  - VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1
  - Tests/VeriHash.HotPath.Tests.ps1
  - Tests/VeriHash.HotPath.Perf.Tests.ps1
autonomous: true
requirements:
  - PERF-03
  - PERF-04
  - PERF-05
must_haves:
  truths:
    - "Invoke-VeriHashHotPath spins exactly two ThreadJobs (named 'hash' and 'sig') for a PE input, each started with -InitializationScript Import-Module."
    - "For a non-PE input, no sig ThreadJob is started; the signature line in the result reads Status='skipped', Reason='not a PE file' and the host output line is exactly 'Signature: skipped (not a PE file)'."
    - "Hash console line is printed before signature console line whenever the hash job finishes first; orchestrator handles the reverse ordering cleanly without throwing."
    - "Returned VeriHash.HotPathResult contains WallClockMs computed by a Stopwatch wrapping the entire orchestration; the value is within ±50ms of an external Measure-Command of the same call."
    - "On a 150 MB random fixture, WallClockMs < 0.85 * (HashElapsedMs + SigElapsedMs) — proves parallelism (PERF-03 differential)."
  artifacts:
    - path: "VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1"
      provides: "Single-file orchestrator: PE-detect → 2 ThreadJobs → poll → stream → return VeriHash.HotPathResult"
      min_lines: 80
    - path: "Tests/VeriHash.HotPath.Perf.Tests.ps1"
      provides: "PERF-03 differential test (-Tag Performance), 150MB fixture generated in BeforeAll"
  key_links:
    - from: "Invoke-VeriHashHotPath.ps1"
      to: "Get-VeriHashResult (VeriHash.Core)"
      via: "hash ThreadJob -ScriptBlock invokes Get-VeriHashResult after -InitializationScript Import-Module Core"
      pattern: "Get-VeriHashResult"
    - from: "Invoke-VeriHashHotPath.ps1"
      to: "Get-VeriHashSignature (VeriHash.HotPath, Plan 01)"
      via: "sig ThreadJob -ScriptBlock invokes Get-VeriHashSignature after -InitializationScript Import-Module HotPath"
      pattern: "Get-VeriHashSignature"
    - from: "Invoke-VeriHashHotPath.ps1"
      to: "Format-VeriHashReport (VeriHash.Core)"
      via: "called once per completed job (hash line, then sig line) for v1-compatible host output"
      pattern: "Format-VeriHashReport"
---

<objective>
Build `Invoke-VeriHashHotPath` — the per-file hot-path orchestrator that PE-detects, spins two ThreadJobs (hash + signature), polls with `Wait-Job -Any`, streams output progressively, and returns a `VeriHash.HotPathResult` with wall-clock timing.

Purpose: Closes PERF-03 (parallel hash+sig), PERF-04 (progressive streaming, hash line first when faster), PERF-05 (wall-clock = whole-call duration). Provides the per-file unit that Plan 03's batch loop calls.

Output: `Invoke-VeriHashHotPath` exported from VeriHash.HotPath; PERF-03 differential test green on a 150 MB fixture.
</objective>

<execution_context>
@~/.copilot/get-shit-done/workflows/execute-plan.md
@~/.copilot/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/02-hot-path-performance-multi-file-loop/02-CONTEXT.md
@.planning/phases/02-hot-path-performance-multi-file-loop/02-RESEARCH.md
@.planning/phases/02-hot-path-performance-multi-file-loop/02-PATTERNS.md
@.planning/phases/02-hot-path-performance-multi-file-loop/02-VALIDATION.md
@.planning/phases/02-hot-path-performance-multi-file-loop/02-01-SUMMARY.md
@.github/copilot-instructions.md

# Phase 1 + Plan 01 surface composed here:
@VeriHash.Core/Public/Get-VeriHashResult.ps1
@VeriHash.Core/Public/Format-VeriHashReport.ps1
@VeriHash.Core/Public/Read-ClipboardHash.ps1
@VeriHash.Core/Public/Test-VeriHashSidecar.ps1
@VeriHash.Core/Public/Write-VeriHashLog.ps1
@VeriHash.HotPath/Public/Get-VeriHashSignature.ps1
@VeriHash.HotPath/Private/Test-IsPEFile.ps1

# Test analogs:
@Tests/VeriHash.Timing.Tests.ps1
@Tests/VeriHash.Core.Get-VeriHashResult.Tests.ps1

<interfaces>
<!-- Public function this plan adds -->
VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1:
```powershell
function Invoke-VeriHashHotPath {
    [CmdletBinding()] [OutputType('VeriHash.HotPathResult')]
    param(
        [Parameter(Mandatory)] [string]   $Path,
        [ValidateSet('MD5','SHA256','SHA512')] [string] $Algorithm = 'SHA256',
        [switch] $Log
    )
    # returns VeriHash.HotPathResult — fields per CONTEXT.md D-A5-1
}
```

<!-- The result-object contract (locked by CONTEXT.md D-A5-1; do NOT alter) -->
[pscustomobject]@{
    PSTypeName       = 'VeriHash.HotPathResult'
    FilePath         = <string>      # resolved absolute path
    Hash             = <string>      # lowercase hex
    HashAlgorithm    = <string>      # 'MD5'|'SHA256'|'SHA512'
    HashElapsedMs    = <int>         # measured by Get-VeriHashResult
    Signature        = <string>      # 'valid'|'invalid'|'unsigned'|'skipped'|'error'
    SignatureReason  = <string>      # short string, may be ''
    SigElapsedMs     = <int>         # 0 if skipped
    WallClockMs      = <int>         # Stopwatch around entire orchestration
    IsPE             = <bool>
    MatchResult      = <string>      # 'matched'|'mismatch'|'missing'
}
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1 (Wave 0 RED): Add orchestrator behavior tests + perf test scaffold; stub Invoke-VeriHashHotPath</name>
  <read_first>
    - Tests/VeriHash.HotPath.Tests.ps1 (extend with new Describe blocks; Plan 01 created the file)
    - Tests/VeriHash.Timing.Tests.ps1 (analog for perf assertion style)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-PATTERNS.md (lines 89-178 orchestrator pattern; lines 443-464 Perf test pattern)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-RESEARCH.md (lines 227-257 ThreadJob pattern; lines 398-414 Pitfall 6 + Pitfall 8; lines 422-426 Pitfall 10)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-CONTEXT.md (D-A5-1 result-object shape)
    - VeriHash.HotPath/VeriHash.HotPath.psd1 (must update FunctionsToExport)
  </read_first>
  <behavior>
    Tests must FAIL initially (orchestrator stub throws). Cover:
    - Module exports list now includes `Invoke-VeriHashHotPath` (manifest update test).
    - For tiny-pe.bin: returned object has PSTypeName 'VeriHash.HotPathResult'; IsPE=$true; Hash is 64 lowercase hex chars (SHA256 default); HashAlgorithm='SHA256'; HashElapsedMs is non-negative int; SigElapsedMs is non-negative int; WallClockMs is non-negative int; Signature is one of the 5 enum values.
    - For tiny-not-pe.bin: IsPE=$false; Signature='skipped'; SignatureReason='not a PE file'; SigElapsedMs=0; host output captured via `*>&1 | Out-String` contains the literal substring `Signature: skipped (not a PE file)`.
    - WallClockMs vs Measure-Command: |result.WallClockMs - measured.TotalMilliseconds| <= 50 (PERF-05).
    - Streaming order (PERF-04 happy path): for a 1 MB file (hash slow-ish, sig fast — actually hash will be sub-ms; we use a synthetic test): host output has the hash line BEFORE the signature line in the captured stream. Use `6>&1` or `*>&1` capture. (Pitfall 6: do NOT hard-code "hash always first"; this test asserts ordering only when hash finishes first, which it will on a non-trivial fixture).
    - PERF-03 differential (`-Tag Performance`): on a 150 MB on-the-fly random fixture, `WallClockMs < 0.85 * (HashElapsedMs + SigElapsedMs)`.
    - Cross-platform: on non-Windows, calling Invoke-VeriHashHotPath on tiny-pe.bin returns Signature='skipped', Reason='not supported on this platform'; module still works end-to-end.
  </behavior>
  <action>
**(a) Update `VeriHash.HotPath/VeriHash.HotPath.psd1`:**
Change the FunctionsToExport line from:
```powershell
FunctionsToExport = 'Get-VeriHashSignature'
```
to:
```powershell
FunctionsToExport = 'Get-VeriHashSignature', 'Invoke-VeriHashHotPath'
```
(Plan 03 will add `Invoke-VeriHashBatch` later — leave that for Plan 03.)

**(b) Create stub `VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1`:**
```powershell
function Invoke-VeriHashHotPath {
    [CmdletBinding()] [OutputType('VeriHash.HotPathResult')]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [ValidateSet('MD5','SHA256','SHA512')] [string] $Algorithm = 'SHA256',
        [switch] $Log
    )
    throw 'NOT YET IMPLEMENTED'
}
```

**(c) APPEND new Describe blocks to `Tests/VeriHash.HotPath.Tests.ps1`** (do NOT delete existing Plan 01 blocks):

```powershell
Describe 'Invoke-VeriHashHotPath: surface (PERF-03/04/05 contract)' {
    It 'Module exports Invoke-VeriHashHotPath after Plan 02 manifest update' {
        (Get-Command -Module VeriHash.HotPath).Name | Should -Contain 'Invoke-VeriHashHotPath'
    }
}

Describe 'Invoke-VeriHashHotPath: result-object shape (D-A5-1)' {
    BeforeAll {
        $script:PEFixture = Join-Path $PSScriptRoot 'Fixtures/tiny-pe.bin'
        $script:NotPEFixture = Join-Path $PSScriptRoot 'Fixtures/tiny-not-pe.bin'
    }
    It 'PE input: returns VeriHash.HotPathResult with all D-A5-1 fields' {
        $r = Invoke-VeriHashHotPath -Path $script:PEFixture -Algorithm SHA256
        $r.PSTypeNames | Should -Contain 'VeriHash.HotPathResult'
        $r.IsPE | Should -BeTrue
        $r.HashAlgorithm | Should -Be 'SHA256'
        $r.Hash | Should -Match '^[0-9a-f]{64}$'
        $r.HashElapsedMs | Should -BeGreaterOrEqual 0
        $r.SigElapsedMs  | Should -BeGreaterOrEqual 0
        $r.WallClockMs   | Should -BeGreaterOrEqual 0
        $r.Signature     | Should -BeIn @('valid','invalid','unsigned','skipped','error')
    }
    It 'Non-PE input: IsPE=$false; Signature=skipped; Reason="not a PE file"; SigElapsedMs=0' {
        $r = Invoke-VeriHashHotPath -Path $script:NotPEFixture -Algorithm SHA256
        $r.IsPE | Should -BeFalse
        $r.Signature | Should -Be 'skipped'
        $r.SignatureReason | Should -Be 'not a PE file'
        $r.SigElapsedMs | Should -Be 0
    }
    It 'Non-PE input: host output contains literal "Signature: skipped (not a PE file)"' {
        $captured = Invoke-VeriHashHotPath -Path $script:NotPEFixture -Algorithm SHA256 6>&1 | Out-String
        $captured | Should -Match 'Signature:\s*skipped\s*\(not a PE file\)'
    }
}

Describe 'Invoke-VeriHashHotPath: PERF-05 wall-clock honesty' {
    It 'Returned WallClockMs within 50ms of Measure-Command' {
        $fixture = Join-Path $PSScriptRoot 'Fixtures/tiny-pe.bin'
        $result = $null
        $measured = Measure-Command { $script:result = Invoke-VeriHashHotPath -Path $fixture -Algorithm SHA256 }
        [math]::Abs($script:result.WallClockMs - [int]$measured.TotalMilliseconds) | Should -BeLessOrEqual 50
    }
}

Describe 'Invoke-VeriHashHotPath: cross-platform' -Skip:($IsWindows) {
    It 'On non-Windows returns Signature=skipped, Reason=not supported on this platform' {
        $fixture = Join-Path $PSScriptRoot 'Fixtures/tiny-pe.bin'
        $r = Invoke-VeriHashHotPath -Path $fixture -Algorithm SHA256
        $r.Signature | Should -Be 'skipped'
        $r.SignatureReason | Should -Be 'not supported on this platform'
    }
}
```

**(d) Create `Tests/VeriHash.HotPath.Perf.Tests.ps1`** (PERF-03 differential, `-Tag Performance`):

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force

    # Generate a 150 MB random fixture so min(hashMs, sigMs) > ~200ms (Pitfall 10 mitigation)
    # NOT committed — lives in $TestDrive
    $script:PerfFixture = Join-Path $TestDrive 'perf-fixture.bin'
    $bytes = [byte[]]::new(150 * 1MB)
    (New-Object System.Random 42).NextBytes($bytes)
    [System.IO.File]::WriteAllBytes($script:PerfFixture, $bytes)
}
AfterAll { Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue }

Describe 'Invoke-VeriHashHotPath parallelism (PERF-03)' -Tag 'Performance' {
    It 'WallClockMs < 0.85 * (HashElapsedMs + SigElapsedMs) on 150MB fixture' -Skip:(-not $IsWindows) {
        $r = Invoke-VeriHashHotPath -Path $script:PerfFixture -Algorithm SHA256
        # Pitfall 10: min subtask > 200ms is needed for the parallel margin to dominate ThreadJob startup.
        # 150MB random data SHA256 = ~300-500ms; sig on unsigned PE-magic-only file = ~50-150ms.
        # If min < 200ms locally, this test may flap — that's expected per the -Tag Performance gate.
        $sumMs = $r.HashElapsedMs + $r.SigElapsedMs
        $bound = [int](0.85 * $sumMs)
        $r.WallClockMs | Should -BeLessThan $bound -Because "wallClock=$($r.WallClockMs) hashMs=$($r.HashElapsedMs) sigMs=$($r.SigElapsedMs)"
    }
}
```

Run all HotPath tests excluding the Performance tag and confirm RED on the new Describe blocks (orchestrator throws), while Plan 01 tests stay GREEN.
  </action>
  <verify>
    <automated>pwsh -NoProfile -Command "$r = Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1 -ExcludeTag Performance -Output Detailed -PassThru; if ($r.FailedCount -lt 4) { throw 'Expected RED on at least 4 new orchestrator It blocks (got $($r.FailedCount))' }"</automated>
  </verify>
  <acceptance_criteria>
    - `VeriHash.HotPath/VeriHash.HotPath.psd1` `FunctionsToExport` line contains both `Get-VeriHashSignature` AND `Invoke-VeriHashHotPath` (grep for both).
    - `VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1` exists; body throws `'NOT YET IMPLEMENTED'`.
    - `Tests/VeriHash.HotPath.Tests.ps1` contains the 4 new Describe blocks listed above (verified by `Select-String 'Invoke-VeriHashHotPath: surface|Invoke-VeriHashHotPath: result-object shape|Invoke-VeriHashHotPath: PERF-05 wall-clock honesty|Invoke-VeriHashHotPath: cross-platform'` returning ≥4 matches).
    - `Tests/VeriHash.HotPath.Perf.Tests.ps1` exists with `-Tag 'Performance'` and `[byte[]]::new(150 * 1MB)`.
    - Running `Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1 -ExcludeTag Performance` produces FailedCount ≥ 4 (the new orchestrator behavior tests are RED).
    - Plan 01 tests (Tests/VeriHash.HotPath.PE.Tests.ps1, .Sig.Tests.ps1) remain GREEN: `Invoke-Pester -Path Tests/VeriHash.HotPath.PE.Tests.ps1,Tests/VeriHash.HotPath.Sig.Tests.ps1 -PassThru` reports `FailedCount = 0`.
  </acceptance_criteria>
  <done>RED state established for orchestrator + perf test scaffold ready; Plan 01 tests still GREEN.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2 (GREEN): Implement Invoke-VeriHashHotPath orchestrator</name>
  <read_first>
    - VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1 (current stub)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-PATTERNS.md (lines 89-178 — full orchestrator pattern with verbatim ThreadJob excerpts; lines 158-164 Stopwatch idiom; lines 167-177 per-file Phase 1 composition)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-RESEARCH.md (lines 227-257 Pattern 1 verbatim; lines 392-396 Pitfall 5 -InitializationScript module path; lines 398-402 Pitfall 6; lines 565-573 Open Question 4 absolute psd1 path)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-CONTEXT.md (D-A3-1/2/3 ThreadJob orchestration; D-A5-1 hybrid streaming + result shape; D-A6-1 PE-detect)
    - VeriHash.Core/Public/Get-VeriHashResult.ps1 (the function the hash ThreadJob invokes; understand its return shape — used to fill HashElapsedMs)
    - VeriHash.Core/Public/Format-VeriHashReport.ps1 (printer for hash line)
    - VeriHash.Core/Public/Write-VeriHashLog.ps1 (per-file log line — read parameter contract before calling)
    - VeriHash.HotPath/Public/Get-VeriHashSignature.ps1 (Plan 01 — the function the sig ThreadJob invokes)
    - Tests/VeriHash.HotPath.Tests.ps1 (the RED tests this task must turn GREEN — DO NOT MODIFY)
  </read_first>
  <action>
Implement `VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1` per the pattern below. Replace the `throw 'NOT YET IMPLEMENTED'` stub.

**Required structure:**

```powershell
function Invoke-VeriHashHotPath {
    <#
    .SYNOPSIS
        Single-file hot-path orchestrator: PE-detect, parallel hash+sig via ThreadJob, stream output, return result.
    .DESCRIPTION
        Runs Get-VeriHashResult and Get-VeriHashSignature in two parallel ThreadJobs (D-A3-1).
        Hash ThreadJob imports VeriHash.Core via -InitializationScript; Sig ThreadJob imports VeriHash.HotPath
        via -InitializationScript (D-A3-2). Polls jobs with Wait-Job -Any (D-A3-3) and renders each
        completed job's line via Format-VeriHashReport (hybrid streaming D-A5-1). Wraps the entire
        orchestration in a Stopwatch for WallClockMs (PERF-05). Returns VeriHash.HotPathResult.
    .PARAMETER Path
        File to hash + verify. Resolved with Resolve-Path.
    .PARAMETER Algorithm
        MD5 | SHA256 (default) | SHA512.
    .PARAMETER Log
        Write one plain-text line to ~/.verihash/verihash.log (or VERIHASH_LOG_PATH).
    .OUTPUTS
        VeriHash.HotPathResult
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.HotPathResult')]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [ValidateSet('MD5','SHA256','SHA512')] [string] $Algorithm = 'SHA256',
        [switch] $Log
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # 1. Resolve path; PE-detect ONCE on main thread (D-A6-1)
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $isPE     = Test-IsPEFile -Path $resolved

    # 2. Snapshot psd1 paths BEFORE Start-ThreadJob ($using: needs locals — Open Question 4)
    $coreModule    = Get-Module VeriHash.Core
    $hotPathModule = Get-Module VeriHash.HotPath
    $corePsd1     = if ($coreModule)    { $coreModule.Path }    else { Join-Path $PSScriptRoot '..\..\VeriHash.Core\VeriHash.Core.psd1' }
    $hotPathPsd1  = if ($hotPathModule) { $hotPathModule.Path } else { Join-Path $PSScriptRoot '..\..\VeriHash.HotPath\VeriHash.HotPath.psd1' }

    # 3. Spawn hash ThreadJob (always)
    $hashJob = Start-ThreadJob -Name 'hash' -InitializationScript {
        Import-Module $using:corePsd1 -Force
    } -ScriptBlock {
        param($p, $algo) Get-VeriHashResult -Path $p -Algorithm $algo
    } -ArgumentList $resolved, $Algorithm

    # 4. Spawn sig ThreadJob (always — Get-VeriHashSignature handles -IsPE:$false / non-Windows internally)
    $sigJob = Start-ThreadJob -Name 'sig' -InitializationScript {
        Import-Module $using:hotPathPsd1 -Force
    } -ScriptBlock {
        param($p, $isPE) Get-VeriHashSignature -Path $p -IsPE:$isPE
    } -ArgumentList $resolved, $isPE

    # 5. Poll: stream whichever finishes first (D-A3-3, Pitfall 6 — handle either order)
    $hashResult = $null
    $sigResult  = $null
    $sigSw      = [System.Diagnostics.Stopwatch]::StartNew()
    $sigDoneMs  = 0
    $pending = [System.Collections.Generic.List[object]]::new()
    $pending.Add($hashJob); $pending.Add($sigJob)

    while ($pending.Count -gt 0) {
        $done = Wait-Job -Job $pending -Any -Timeout 1
        if ($null -eq $done) { continue }
        $payload = Receive-Job -Job $done -Wait -AutoRemoveJob
        switch ($done.Name) {
            'hash' {
                $hashResult = $payload
                # Hash line via Format-VeriHashReport (Phase 1 printer; v1-compatible)
                Format-VeriHashReport -Result $payload | Out-Null   # printer uses Write-Host
            }
            'sig'  {
                $sigResult = $payload
                $sigDoneMs = [int]$sigSw.ElapsedMilliseconds
                # Sig line — direct Write-Host so Format-VeriHashReport stays unchanged from Phase 1
                $line = "Signature: $($payload.Status)" + $(if ($payload.Reason) { " ($($payload.Reason))" } else { '' })
                $color = switch ($payload.Status) {
                    'valid'    { 'Green' }
                    'invalid'  { 'Red' }
                    'unsigned' { 'Yellow' }
                    'skipped'  { 'DarkGray' }
                    default    { 'Magenta' }
                }
                Write-Host $line -ForegroundColor $color
            }
        }
        $pending.Remove($done) | Out-Null
    }

    $sw.Stop()
    $wallMs = [int]$sw.ElapsedMilliseconds

    # 6. Optional clipboard / sidecar comparison (MULTI-03 — preserves single-file features per file)
    $clip       = Read-ClipboardHash -ErrorAction SilentlyContinue
    $sidecar    = Test-VeriHashSidecar -Path $resolved -ErrorAction SilentlyContinue
    $matchResult = 'matched'   # default; downgrade below
    if ($null -ne $clip -and $clip.Hash -and ($hashResult.Hash -ne $clip.Hash)) { $matchResult = 'mismatch' }
    if ($null -ne $sidecar -and $sidecar.Hash -and ($hashResult.Hash -ne $sidecar.Hash)) { $matchResult = 'mismatch' }
    if ($null -eq $clip -and $null -eq $sidecar) {
        # No comparator → call it 'matched' (file integrity reported, nothing to compare against).
        # (Plan 03's batch loop tally treats 'matched' as the success bucket.)
        $matchResult = 'matched'
    }

    # 7. Per-file log line (per CONTEXT.md "Notes for the Planner" — one line per file)
    if ($Log -or $env:VERIHASH_LOG -eq '1') {
        $size = if ($hashResult.Size) { [int64]$hashResult.Size } else { 0 }
        Write-VeriHashLog -Op verify -Algorithm $Algorithm -Hash $hashResult.Hash `
                          -Bytes $size -ElapsedMs $wallMs -Result $matchResult -Path $resolved -Log:$Log
    }

    return [pscustomobject]@{
        PSTypeName       = 'VeriHash.HotPathResult'
        FilePath         = $resolved
        Hash             = $hashResult.Hash
        HashAlgorithm    = $Algorithm
        HashElapsedMs    = [int]($hashResult.ElapsedMs)
        Signature        = $sigResult.Status
        SignatureReason  = [string]$sigResult.Reason
        SigElapsedMs     = $sigDoneMs
        WallClockMs      = $wallMs
        IsPE             = [bool]$isPE
        MatchResult      = $matchResult
    }
}
```

**Required deviations / clarifications:**
- `Format-VeriHashReport` from Phase 1 has its own parameter contract — read its file and adapt the call site. If the Phase 1 signature is `Format-VeriHashReport -Result $r -CompareTo $clip -SidecarInfo $sidecar`, defer the call to AFTER clipboard/sidecar lookup so the printer can render the comparison. In that case, restructure: spawn jobs → wait for hash → do clip/sidecar lookup → call `Format-VeriHashReport -Result $hashResult -CompareTo $clip -SidecarInfo $sidecar` → wait for sig → render sig line. Verify against the actual `Format-VeriHashReport.ps1` signature before finalizing the printer call. The streaming contract (PERF-04: "hash line printed before sig line in common case") is preserved either way as long as the hash line emits before we await sig completion.
- `Write-VeriHashLog` — call exactly per its existing parameter list (read the file). If a parameter doesn't exist, drop it; do not invent.
- `Read-ClipboardHash` — Phase 1 returns `$null` or an object with `.Hash`; verify with the actual implementation.
- `Test-VeriHashSidecar` — same; verify shape.

**Re-verify the PERF-02 contract still holds end-to-end:** add no flag passing inside the ThreadJob; `Get-VeriHashSignature` (Plan 01) is the only path to `Invoke-WinVerifyTrust`, and Plan 01's Mock-based tests already lock the flags.

**Run all HotPath tests (excluding Performance tag) and confirm GREEN. Then run the Performance test on Windows:**
```powershell
Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1,Tests/VeriHash.HotPath.PE.Tests.ps1,Tests/VeriHash.HotPath.Sig.Tests.ps1 -ExcludeTag Performance -Output Detailed
Invoke-Pester -Path Tests/VeriHash.HotPath.Perf.Tests.ps1 -Tag Performance -Output Detailed   # Windows only
```

If a perf test fails because `min(hashMs, sigMs) < 200ms` on the runner, do NOT relax the 0.85 ratio — increase fixture size to 200 MB or 300 MB until the threshold is met (Pitfall 10).
  </action>
  <verify>
    <automated>pwsh -NoProfile -Command "$r = Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1,Tests/VeriHash.HotPath.PE.Tests.ps1,Tests/VeriHash.HotPath.Sig.Tests.ps1 -ExcludeTag Performance -Output Detailed -PassThru; if ($r.FailedCount -gt 0) { throw \"GREEN gate failed: $($r.FailedCount) tests failed (excluding Performance)\" }"; if ($IsWindows) { pwsh -NoProfile -Command "$p = Invoke-Pester -Path Tests/VeriHash.HotPath.Perf.Tests.ps1 -Tag Performance -Output Detailed -PassThru; if ($p.FailedCount -gt 0) { throw 'PERF-03 differential test failed' }" }; Invoke-ScriptAnalyzer -Path VeriHash.HotPath -Recurse -Settings PSScriptAnalyzerSettings.psd1</automated>
  </verify>
  <acceptance_criteria>
    - All Tests/VeriHash.HotPath.Tests.ps1, .PE.Tests.ps1, .Sig.Tests.ps1 tests pass (FailedCount=0) when run with `-ExcludeTag Performance`.
    - On Windows, Tests/VeriHash.HotPath.Perf.Tests.ps1 with `-Tag Performance` passes (FailedCount=0). PERF-03 differential satisfied.
    - `git diff` between Task 1 and Task 2 commits shows ZERO modifications to any `Tests/VeriHash.HotPath.*Tests.ps1` file (TDD rule honored).
    - `Select-String -Path VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1 -Pattern 'Start-ThreadJob.*-InitializationScript'` returns ≥2 matches (one per ThreadJob, per D-A3-2).
    - `Select-String -Path VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1 -Pattern 'Wait-Job.*-Any'` returns ≥1 match (D-A3-3).
    - `Select-String -Path VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1 -Pattern '\[System\.Diagnostics\.Stopwatch\]::StartNew'` returns ≥1 match (PERF-05 Stopwatch).
    - `Select-String -Path VeriHash.HotPath -Pattern 'WTD_DISABLE_MD2_MD4|PSFramework|Write-PSFMessage|\$IsWindows|\$RunningOnWindows' -Recurse` returns 0 matches.
    - `Get-Command -Module VeriHash.HotPath` lists exactly `Get-VeriHashSignature` AND `Invoke-VeriHashHotPath` (no other public exports).
    - PSScriptAnalyzer returns 0 errors on `VeriHash.HotPath/`.
    - The non-PE host-output test asserts host stream contains the literal substring `Signature: skipped (not a PE file)` and passes.
  </acceptance_criteria>
  <done>PERF-03 (parallel), PERF-04 (streaming), PERF-05 (wall-clock) success criteria met. Invoke-VeriHashHotPath ready for Plan 03 to wrap in a batch loop.</done>
</task>

</tasks>

<verification>
Plan-level gate:

```powershell
# Excluding Performance (CI default)
Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1,Tests/VeriHash.HotPath.PE.Tests.ps1,Tests/VeriHash.HotPath.Sig.Tests.ps1 -ExcludeTag Performance -Output Detailed

# Performance tier (Windows local)
if ($IsWindows) { Invoke-Pester -Path Tests/VeriHash.HotPath.Perf.Tests.ps1 -Tag Performance -Output Detailed }

# Lint
Invoke-ScriptAnalyzer -Path VeriHash.HotPath -Recurse -Settings PSScriptAnalyzerSettings.psd1

# Carried-forward bans
Select-String -Path VeriHash.HotPath -Pattern 'WTD_DISABLE_MD2_MD4|PSFramework|Write-PSFMessage|\$IsWindows|\$RunningOnWindows' -Recurse
```
</verification>

<success_criteria>
- All Plan 01 + Plan 02 Pester tests green (excluding Performance for CI).
- PERF-03 differential test green on Windows local with a 150–300 MB on-the-fly fixture.
- Two ThreadJobs verifiably spun per call (grep on the source); `Wait-Job -Any` polling present.
- Stopwatch wraps the entire orchestration (PERF-05).
- Non-PE files render the locked `Signature: skipped (not a PE file)` host string (PERF-01 reaffirmed end-to-end).
</success_criteria>

<output>
After completion, create `.planning/phases/02-hot-path-performance-multi-file-loop/02-02-SUMMARY.md` with:
- Files added/modified
- Test results (passed/failed/skipped, ExcludeTag Performance and -Tag Performance separately)
- Final value chosen for `Wait-Job -Any -Timeout` (1s recommended; document if changed)
- Final perf-fixture size (default 150 MB; 200/300 MB if larger needed for stability)
- Format-VeriHashReport call shape adopted (signature dictated final orchestrator structure)
- Confirmation that PERF-03/04/05 success criteria pass
- Notes for Plan 03 (`Invoke-VeriHashBatch` calls this function inside a sequential foreach)
</output>
