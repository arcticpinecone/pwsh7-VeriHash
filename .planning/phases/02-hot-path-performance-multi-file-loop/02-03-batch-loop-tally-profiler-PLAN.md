---
phase: 02-hot-path-performance-multi-file-loop
plan: 03
type: execute
wave: 3
depends_on:
  - "02-02"
files_modified:
  - VeriHash.HotPath/VeriHash.HotPath.psd1
  - VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1
  - Tests/VeriHash.HotPath.Batch.Tests.ps1
  - Profile-VeriHashTiming.ps1
autonomous: true
requirements:
  - MULTI-01
  - MULTI-02
  - MULTI-03
must_haves:
  truths:
    - "Invoke-VeriHashBatch accepts [string[]] $FilePath and runs Invoke-VeriHashHotPath sequentially for each entry."
    - "TallyLine is exactly the byte-locked format '<m>/<N> matched, <x> mismatch, <z> missing' with no spacing variations."
    - "Tally buckets exactly: matched + mismatch + missing = N (every input file falls in exactly one bucket; read errors / sig errors / exceptions all → missing)."
    - "One bad file (nonexistent path or unreadable file) does NOT abort the batch; the loop continues and the bad file lands in 'missing'."
    - "Per-file processing inside the batch still runs clipboard compare AND sidecar compare AND parallel PE signature (MULTI-03 — loop mode does not regress single-file behavior)."
    - "Profile-VeriHashTiming.ps1 with -Strict throws when wallClock > 1.2 * max(hashMs, sigMs) + 100; without -Strict, existing callers (Test-All.ps1) continue to work unchanged."
  artifacts:
    - path: "VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1"
      provides: "Multi-file sequential foreach + tally; returns VeriHash.BatchResult"
      min_lines: 50
    - path: "Tests/VeriHash.HotPath.Batch.Tests.ps1"
      provides: "MULTI-01/02/03 coverage including byte-locked tally string assertion"
    - path: "Profile-VeriHashTiming.ps1"
      provides: "-Strict switch added with D-A7-1 strict assertion"
  key_links:
    - from: "Invoke-VeriHashBatch.ps1"
      to: "Invoke-VeriHashHotPath (Plan 02)"
      via: "sequential foreach calls Invoke-VeriHashHotPath per file"
      pattern: "Invoke-VeriHashHotPath -Path"
    - from: "Profile-VeriHashTiming.ps1"
      to: "$measurements + $resultObject"
      via: "-Strict block reads existing variables and asserts D-A7-1 bound"
      pattern: "1.2 \\* \\[math\\]::Max"
---

<objective>
Add `Invoke-VeriHashBatch` (multi-file sequential loop with byte-locked tally + continue-and-tally) and extend `Profile-VeriHashTiming.ps1` with the D-A7-1 strict perf assertion gated behind a new `-Strict` switch.

Purpose: Closes MULTI-01 (`[string[]] $FilePath`), MULTI-02 (one block per file + `X/N matched, Y mismatch, Z missing` tally), MULTI-03 (loop mode preserves single-file features per file). Closes the Phase 2 deliverables and preserves Test-All.ps1 compatibility.

Output: `Invoke-VeriHashBatch` exported from VeriHash.HotPath; Tests/VeriHash.HotPath.Batch.Tests.ps1 green; Profile-VeriHashTiming.ps1 with `-Strict` throws on regressions, unchanged behavior otherwise.
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
@.planning/phases/02-hot-path-performance-multi-file-loop/02-02-SUMMARY.md
@.github/copilot-instructions.md

# Existing files this plan composes / extends:
@VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1
@VeriHash.HotPath/VeriHash.HotPath.psd1
@Profile-VeriHashTiming.ps1
@Test-All.ps1

# Test analogs:
@Tests/VeriHash.Core.Write-VeriHashLog.Tests.ps1

<interfaces>
<!-- Public function this plan adds -->
VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1:
```powershell
function Invoke-VeriHashBatch {
    [CmdletBinding()] [OutputType('VeriHash.BatchResult')]
    param(
        [Parameter(Mandatory)] [string[]] $FilePath,
        [ValidateSet('MD5','SHA256','SHA512')] [string] $Algorithm = 'SHA256',
        [switch] $Log
    )
    # returns:
    #   [pscustomobject]@{
    #     PSTypeName = 'VeriHash.BatchResult'
    #     Results    = <VeriHash.HotPathResult[]>
    #     Tally      = @{ Total=N; Matched=m; Mismatch=x; Missing=z }
    #     TallyLine  = '<m>/<N> matched, <x> mismatch, <z> missing'   # byte-locked
    #   }
}
```

<!-- Profile-VeriHashTiming.ps1 extension -->
Add: `[switch]$Strict` parameter; after measurements collected, if -Strict and wallClock > (1.2 * max(hashMs,sigMs)) + 100, throw.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1 (Wave 0 RED): Create Tests/VeriHash.HotPath.Batch.Tests.ps1 + stub Invoke-VeriHashBatch + add manifest export</name>
  <read_first>
    - Tests/VeriHash.Core.Write-VeriHashLog.Tests.ps1 (analog for byte-locked-line assertion style)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-PATTERNS.md (lines 181-244 batch pattern + tally; lines 426-439 batch test pattern)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-CONTEXT.md (D-A4-1/2/3 sequential + 3 buckets + continue-and-tally; <specifics> byte-locked tally format)
    - VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1 (Plan 02 — the function batch calls)
    - VeriHash.HotPath/VeriHash.HotPath.psd1 (must update FunctionsToExport)
  </read_first>
  <behavior>
    Tests must FAIL initially (Invoke-VeriHashBatch stub throws). Cover:
    - Module exports list now includes `Invoke-VeriHashBatch`.
    - MULTI-01: `Invoke-VeriHashBatch -FilePath @($a,$b,$c)` accepts string[] and returns Results.Count == 3.
    - MULTI-02 byte-lock: For three real PE/non-PE files with NO clipboard and NO sidecars (all "matched"), TallyLine === `3/3 matched, 0 mismatch, 0 missing` (exact string equality, not regex).
    - MULTI-02 with mismatch (mocked): For inputs whose Invoke-VeriHashHotPath returns MatchResult='mismatch' for one file, TallyLine === `2/3 matched, 1 mismatch, 0 missing`.
    - MULTI-02 with missing (real): For an input where one path does not exist on disk, batch does not throw; TallyLine === `2/3 matched, 0 mismatch, 1 missing`; Results.Count == 3 (the missing file gets a placeholder VeriHash.HotPathResult with MatchResult='missing'). Also asserts the Tally hashtable matches `Total=3; Matched=2; Mismatch=0; Missing=1`.
    - MULTI-02 single file: `Invoke-VeriHashBatch -FilePath @($a)` emits TallyLine `1/1 matched, 0 mismatch, 0 missing` (per RESEARCH.md Open Question 5 — always emit tally; CLI chooses entry point in Phase 5).
    - MULTI-03 preservation: For a single PE input under batch, Results[0].IsPE is set, Results[0].Signature is one of the 5 enum values, Results[0].HashElapsedMs and SigElapsedMs are present (proves the per-file orchestrator ran with parallel jobs).
    - Continue-and-tally: even if the FIRST file in the batch is missing, files 2 and 3 still process.
    - Profile-VeriHashTiming.ps1 backward compat: invoking the script without `-Strict` (as Test-All.ps1 step 3/3 does) still completes without throwing.
    - Profile-VeriHashTiming.ps1 -Strict assertion: when wallClock is artificially elevated (we'll mock by passing `-Strict` against a path that completes fast and inspect that no throw happens; the throw-path is exercised by injecting the bound check via test). Practical assertion: invoking `Profile-VeriHashTiming.ps1 -Strict -FilePath <small file> -Quiet` returns successfully (does not throw) — i.e., the strict gate is reachable without false positives in normal use.
  </behavior>
  <action>
**(a) Update `VeriHash.HotPath/VeriHash.HotPath.psd1` — extend FunctionsToExport:**
```powershell
FunctionsToExport = 'Get-VeriHashSignature', 'Invoke-VeriHashHotPath', 'Invoke-VeriHashBatch'
```

**(b) Create stub `VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1`:**
```powershell
function Invoke-VeriHashBatch {
    [CmdletBinding()] [OutputType('VeriHash.BatchResult')]
    param(
        [Parameter(Mandatory)] [string[]] $FilePath,
        [ValidateSet('MD5','SHA256','SHA512')] [string] $Algorithm = 'SHA256',
        [switch] $Log
    )
    throw 'NOT YET IMPLEMENTED'
}
```

**(c) Create `Tests/VeriHash.HotPath.Batch.Tests.ps1`** (mirror analog `Tests/VeriHash.Core.Write-VeriHashLog.Tests.ps1` for byte-locked-line assertion style; PATTERNS.md lines 426-439):

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    $script:PEFixture    = Join-Path $PSScriptRoot 'Fixtures/tiny-pe.bin'
    $script:NotPEFixture = Join-Path $PSScriptRoot 'Fixtures/tiny-not-pe.bin'
    # Three "real" inputs that should all bucket as 'matched' under no-clipboard/no-sidecar conditions.
    $script:F1 = $script:PEFixture
    $script:F2 = $script:NotPEFixture
    $script:F3 = Join-Path $TestDrive 'extra.bin'
    [IO.File]::WriteAllBytes($script:F3, [byte[]](1..16))
    # Test isolation — clear clipboard env / log env so MatchResult defaults to 'matched'
    Remove-Item Env:VERIHASH_LOG -ErrorAction SilentlyContinue
}
AfterAll { Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue }

Describe 'Invoke-VeriHashBatch surface (MULTI-01)' {
    It 'Module exports Invoke-VeriHashBatch' {
        (Get-Command -Module VeriHash.HotPath).Name | Should -Contain 'Invoke-VeriHashBatch'
    }
    It 'Accepts [string[]] $FilePath and returns Results.Count == input count' {
        $r = Invoke-VeriHashBatch -FilePath @($script:F1, $script:F2, $script:F3) -Algorithm SHA256
        $r.PSTypeNames | Should -Contain 'VeriHash.BatchResult'
        $r.Results.Count | Should -Be 3
    }
    It 'Single-file batch still emits a tally line (Open Question 5: always emit)' {
        $r = Invoke-VeriHashBatch -FilePath @($script:F1) -Algorithm SHA256
        $r.TallyLine | Should -Be '1/1 matched, 0 mismatch, 0 missing'
    }
}

Describe 'Invoke-VeriHashBatch tally byte-lock (MULTI-02)' {
    It 'TallyLine matches the locked regex shape' {
        $r = Invoke-VeriHashBatch -FilePath @($script:F1, $script:F2, $script:F3) -Algorithm SHA256
        $r.TallyLine | Should -Match '^\d+/\d+ matched, \d+ mismatch, \d+ missing$'
    }
    It 'TallyLine for {match, match, match} is exactly "3/3 matched, 0 mismatch, 0 missing"' {
        $r = Invoke-VeriHashBatch -FilePath @($script:F1, $script:F2, $script:F3) -Algorithm SHA256
        $r.TallyLine | Should -Be '3/3 matched, 0 mismatch, 0 missing'
        $r.Tally.Total    | Should -Be 3
        $r.Tally.Matched  | Should -Be 3
        $r.Tally.Mismatch | Should -Be 0
        $r.Tally.Missing  | Should -Be 0
    }
    It 'TallyLine for one mismatch is exactly "2/3 matched, 1 mismatch, 0 missing" (mocked Invoke-VeriHashHotPath)' {
        InModuleScope VeriHash.HotPath {
            $i = 0
            Mock Invoke-VeriHashHotPath {
                $script:i++
                $bucket = if ($script:i -eq 2) { 'mismatch' } else { 'matched' }
                [pscustomobject]@{
                    PSTypeName = 'VeriHash.HotPathResult'
                    FilePath = $Path; Hash='deadbeef'; HashAlgorithm=$Algorithm; HashElapsedMs=1
                    Signature='unsigned'; SignatureReason='not signed'; SigElapsedMs=1
                    WallClockMs=2; IsPE=$false; MatchResult=$bucket
                }
            }
            $r = Invoke-VeriHashBatch -FilePath @('a','b','c') -Algorithm SHA256
            $r.TallyLine | Should -Be '2/3 matched, 1 mismatch, 0 missing'
        }
    }
    It 'TallyLine for one missing (nonexistent path) is exactly "2/3 matched, 0 mismatch, 1 missing" — continue-and-tally (D-A4-3)' {
        $missing = Join-Path $TestDrive 'definitely-does-not-exist.bin'
        $r = Invoke-VeriHashBatch -FilePath @($script:F1, $missing, $script:F2) -Algorithm SHA256
        $r.Results.Count | Should -Be 3
        $r.TallyLine | Should -Be '2/3 matched, 0 mismatch, 1 missing'
        $r.Tally.Missing | Should -Be 1
    }
    It 'Continue-and-tally: bad file FIRST does not abort batch (D-A4-3)' {
        $missing = Join-Path $TestDrive 'first-bad.bin'
        $r = Invoke-VeriHashBatch -FilePath @($missing, $script:F1, $script:F2) -Algorithm SHA256
        $r.Results.Count | Should -Be 3
        $r.Tally.Missing | Should -Be 1
        $r.Tally.Matched | Should -Be 2
    }
}

Describe 'Invoke-VeriHashBatch preserves single-file features (MULTI-03)' {
    It 'Per-file Results entry has IsPE, Signature enum, HashElapsedMs, SigElapsedMs (parallel sig ran per file)' {
        $r = Invoke-VeriHashBatch -FilePath @($script:F1) -Algorithm SHA256
        $r.Results[0].IsPE | Should -BeOfType ([bool])
        $r.Results[0].Signature | Should -BeIn @('valid','invalid','unsigned','skipped','error')
        $r.Results[0].HashElapsedMs | Should -BeGreaterOrEqual 0
        $r.Results[0].SigElapsedMs  | Should -BeGreaterOrEqual 0
        $r.Results[0].WallClockMs   | Should -BeGreaterOrEqual 0
    }
}

Describe 'Profile-VeriHashTiming.ps1 -Strict gate (D-A7-1)' {
    It 'Without -Strict: existing callers (Test-All.ps1 step 3/3) keep working' {
        # Test-All.ps1 calls without -Strict — must complete without throwing
        $script = Join-Path $PSScriptRoot '..' 'Profile-VeriHashTiming.ps1'
        { & $script -FilePath $script:F1 -Algorithm SHA256 -Quiet } | Should -Not -Throw
    }
    It 'With -Strict: completes without throwing on a fast path (no false positives)' {
        $script = Join-Path $PSScriptRoot '..' 'Profile-VeriHashTiming.ps1'
        { & $script -FilePath $script:F1 -Algorithm SHA256 -Quiet -Strict } | Should -Not -Throw
    }
    It '-Strict parameter exists in the script' {
        $script = Join-Path $PSScriptRoot '..' 'Profile-VeriHashTiming.ps1'
        $cmd = Get-Command $script
        $cmd.Parameters.Keys | Should -Contain 'Strict'
    }
}
```

Run the test file and confirm RED — Invoke-VeriHashBatch throws on every It block; the Profile-VeriHashTiming -Strict tests fail because the parameter doesn't exist yet.
  </action>
  <verify>
    <automated>pwsh -NoProfile -Command "$r = Invoke-Pester -Path Tests/VeriHash.HotPath.Batch.Tests.ps1 -Output Detailed -PassThru; if ($r.FailedCount -lt 5) { throw 'Expected RED on multiple It blocks (got $($r.FailedCount))' }"</automated>
  </verify>
  <acceptance_criteria>
    - `VeriHash.HotPath/VeriHash.HotPath.psd1` `FunctionsToExport` line lists all three: `Get-VeriHashSignature`, `Invoke-VeriHashHotPath`, `Invoke-VeriHashBatch`.
    - `VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1` exists with the throw stub.
    - `Tests/VeriHash.HotPath.Batch.Tests.ps1` exists and contains the literal byte-locked strings `3/3 matched, 0 mismatch, 0 missing`, `2/3 matched, 1 mismatch, 0 missing`, `2/3 matched, 0 mismatch, 1 missing`, `1/1 matched, 0 mismatch, 0 missing` (verified via grep).
    - Running `Invoke-Pester -Path Tests/VeriHash.HotPath.Batch.Tests.ps1 -PassThru` reports `FailedCount >= 5`.
    - Plan 02 + Plan 01 tests still GREEN: `Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1,Tests/VeriHash.HotPath.PE.Tests.ps1,Tests/VeriHash.HotPath.Sig.Tests.ps1 -ExcludeTag Performance -PassThru` reports `FailedCount = 0`.
  </acceptance_criteria>
  <done>RED state ready for Task 2 implementation.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2 (GREEN): Implement Invoke-VeriHashBatch + extend Profile-VeriHashTiming.ps1 with -Strict switch</name>
  <read_first>
    - VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1 (current stub)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-PATTERNS.md (lines 181-244 batch pattern verbatim; lines 484-516 Profile-VeriHashTiming -Strict extension verbatim)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-RESEARCH.md (lines 452-493 Invoke-VeriHashBatch skeleton verbatim; lines 496-513 strict-assertion block verbatim)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-CONTEXT.md (D-A4-1/2/3 LOCKED — sequential, 3 buckets only, continue-and-tally; <specifics> byte-locked tally format string)
    - VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1 (the function called per file — confirm it can be called with the params we pass)
    - Profile-VeriHashTiming.ps1 (FULL FILE — must understand the current measurement structure to know where to insert the Strict block; per PATTERNS.md the param block is at lines 8-16 and `$measurements` accumulates throughout, with `$resultObject.Total` at the end. INSERT the strict block AFTER `$resultObject` is computed but BEFORE the script returns it)
    - Test-All.ps1 (step 3/3 invocation — confirm Profile-VeriHashTiming.ps1 is called WITHOUT -Strict so backward compat is preserved)
    - Tests/VeriHash.HotPath.Batch.Tests.ps1 (DO NOT MODIFY — turn it GREEN)
  </read_first>
  <action>
**(a) Replace stub `VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1` with the verbatim implementation per PATTERNS.md lines 205-244 + RESEARCH.md lines 452-493:**

```powershell
function Invoke-VeriHashBatch {
    <#
    .SYNOPSIS
        Multi-file hot-path loop: per-file Invoke-VeriHashHotPath, accumulate tally, emit byte-locked tally line.
    .DESCRIPTION
        Sequential foreach over $FilePath (D-A4-1: no per-file parallelism — preserves output ordering).
        Per-file failure (file not found, hash error, etc.) is caught and bucketed as 'missing'
        (D-A4-3 continue-and-tally — never fail-fast in batch mode). Tally has exactly 3 buckets:
        matched, mismatch, missing (D-A4-2). TallyLine string format is byte-locked
        (CONTEXT.md <specifics>): '<m>/<N> matched, <x> mismatch, <z> missing'.
    .PARAMETER FilePath
        One or more file paths to process.
    .PARAMETER Algorithm
        MD5 | SHA256 (default) | SHA512. Applied to all files.
    .PARAMETER Log
        Pass through to Invoke-VeriHashHotPath (one log line per file, per CONTEXT.md "Notes for the Planner").
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

    $results  = New-Object 'System.Collections.Generic.List[object]'
    $matched  = 0
    $mismatch = 0
    $missing  = 0

    foreach ($p in $FilePath) {
        try {
            $r = Invoke-VeriHashHotPath -Path $p -Algorithm $Algorithm -Log:$Log
            $results.Add($r)
            switch ($r.MatchResult) {
                'matched'  { $matched++ }
                'mismatch' { $mismatch++ }
                default    { $missing++ }    # 'missing' or anything unexpected → missing bucket (D-A4-2)
            }
        } catch {
            # D-A4-3: continue-and-tally; the exception message surfaces in the per-file result.
            $missing++
            $results.Add([pscustomobject]@{
                PSTypeName       = 'VeriHash.HotPathResult'
                FilePath         = $p
                Hash             = $null
                HashAlgorithm    = $Algorithm
                HashElapsedMs    = 0
                Signature        = 'error'
                SignatureReason  = "$($_.Exception.Message)"
                SigElapsedMs     = 0
                WallClockMs      = 0
                IsPE             = $false
                MatchResult      = 'missing'
            })
        }
    }

    # Byte-locked tally line — DO NOT REFORMAT (CONTEXT.md <specifics>; MULTI-02 success-criterion test pins this string).
    $tallyLine = '{0}/{1} matched, {2} mismatch, {3} missing' -f $matched, $FilePath.Count, $mismatch, $missing
    Write-Host $tallyLine -ForegroundColor Yellow

    return [pscustomobject]@{
        PSTypeName = 'VeriHash.BatchResult'
        Results    = $results.ToArray()
        Tally      = @{ Total = $FilePath.Count; Matched = $matched; Mismatch = $mismatch; Missing = $missing }
        TallyLine  = $tallyLine
    }
}
```

**(b) Extend `Profile-VeriHashTiming.ps1`:**

1. Add `[switch]$Strict` to the existing `param(...)` block (currently lines 8-16 per PATTERNS.md). Do NOT remove or reorder existing parameters.

2. After the existing measurement code computes `$resultObject` (search for `return $resultObject` near line 167 per PATTERNS.md line 503; if line numbers differ, locate by text), and BEFORE the final return, insert:

```powershell
if ($Strict) {
    $hashMs = $measurements['Hash Computation']
    $sigMs  = $measurements['Digital Signature Check']
    $wallMs = $resultObject.Total
    if ($null -ne $hashMs -and $null -ne $sigMs -and $null -ne $wallMs) {
        $bound = (1.2 * [math]::Max($hashMs, $sigMs)) + 100
        if ($wallMs -gt $bound) {
            throw "Strict perf assertion failed: wallClock=${wallMs}ms > 1.2*max(${hashMs},${sigMs})+100 = ${bound}ms"
        }
    }
}
```

If the existing variable names in `Profile-VeriHashTiming.ps1` differ (e.g., `$measurements` may not be the literal name; `$resultObject.Total` may be a different field), READ the file first and bind the strict block to the actual existing variables. Do not rename existing variables. The intent (LOCKED by D-A7-1): wallClock ≤ 1.2 × max(hashMs, sigMs) + 100ms; throw otherwise.

3. Verify Test-All.ps1 step 3/3 still calls Profile-VeriHashTiming.ps1 WITHOUT `-Strict` (it should — no change required). If Test-All.ps1 needs no edit, confirm via grep.

**(c) Run all HotPath tests excluding Performance, then ensure full suite green:**

```powershell
Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1,Tests/VeriHash.HotPath.PE.Tests.ps1,Tests/VeriHash.HotPath.Sig.Tests.ps1,Tests/VeriHash.HotPath.Batch.Tests.ps1 -ExcludeTag Performance -Output Detailed
.\Test-All.ps1 -CI    # full repo suite must remain green
```

If a Batch test fails because clipboard or sidecar state contaminates the "matched" expectation, ensure the test file properly isolates env (`Remove-Item Env:VERIHASH_LOG`, `Set-Clipboard $null` if available). DO NOT modify the tests' assertions — fix the test setup or the orchestrator.

**(d) Update `VeriHash.HotPath/VeriHash.HotPath.psm1`** if needed to ensure new functions auto-export (the loader pattern from Plan 01 dot-sources Public/*.ps1 then Export-ModuleMember -Function $publicFiles.BaseName, so no edit should be required — verify).
  </action>
  <verify>
    <automated>pwsh -NoProfile -Command "$r = Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1,Tests/VeriHash.HotPath.PE.Tests.ps1,Tests/VeriHash.HotPath.Sig.Tests.ps1,Tests/VeriHash.HotPath.Batch.Tests.ps1 -ExcludeTag Performance -Output Detailed -PassThru; if ($r.FailedCount -gt 0) { throw \"GREEN gate failed: $($r.FailedCount) tests failed\" }"; pwsh -NoProfile -File ./Test-All.ps1 -CI; Invoke-ScriptAnalyzer -Path VeriHash.HotPath -Recurse -Settings PSScriptAnalyzerSettings.psd1; Invoke-ScriptAnalyzer -Path Profile-VeriHashTiming.ps1 -Settings PSScriptAnalyzerSettings.psd1</automated>
  </verify>
  <acceptance_criteria>
    - All Tests/VeriHash.HotPath.Tests.ps1, .PE.Tests.ps1, .Sig.Tests.ps1, .Batch.Tests.ps1 tests pass (FailedCount=0) when run with `-ExcludeTag Performance`.
    - `git diff` between Task 1 and Task 2 commits shows ZERO modifications to `Tests/VeriHash.HotPath.Batch.Tests.ps1` (TDD rule).
    - `Get-Command -Module VeriHash.HotPath` lists exactly: `Get-VeriHashSignature`, `Invoke-VeriHashHotPath`, `Invoke-VeriHashBatch`.
    - `Select-String -Path VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1 -Pattern "'\{0\}/\{1\} matched, \{2\} mismatch, \{3\} missing'"` returns ≥1 match (the byte-locked tally format string is present verbatim).
    - `Select-String -Path VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1 -Pattern 'foreach\s*\(\s*\$\w+\s+in\s+\$FilePath\s*\)'` returns ≥1 match (sequential foreach per D-A4-1).
    - `Select-String -Path VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1 -Pattern '} catch \{'` returns ≥1 match (continue-and-tally try/catch per D-A4-3).
    - `Select-String -Path Profile-VeriHashTiming.ps1 -Pattern '\[switch\]\$Strict'` returns ≥1 match.
    - `Select-String -Path Profile-VeriHashTiming.ps1 -Pattern '1\.2 \* \[math\]::Max'` returns ≥1 match (D-A7-1 strict bound formula present).
    - `Select-String -Path Profile-VeriHashTiming.ps1 -Pattern 'Strict perf assertion failed'` returns ≥1 match (the throw message).
    - `.\Test-All.ps1 -CI` exits 0 and reports the full repo suite green (Profile-VeriHashTiming.ps1 step 3/3 still works without -Strict — backward compat preserved).
    - `Invoke-ScriptAnalyzer -Path VeriHash.HotPath -Recurse -Settings PSScriptAnalyzerSettings.psd1` returns 0 errors.
    - `Invoke-ScriptAnalyzer -Path Profile-VeriHashTiming.ps1 -Settings PSScriptAnalyzerSettings.psd1` returns 0 NEW errors (baseline preserved).
    - Tally arithmetic invariant holds across every test scenario: `Tally.Matched + Tally.Mismatch + Tally.Missing == Tally.Total == FilePath.Count`.
    - `Select-String -Path VeriHash.HotPath -Pattern 'WTD_DISABLE_MD2_MD4|PSFramework|Write-PSFMessage|\$IsWindows|\$RunningOnWindows' -Recurse` returns 0 matches (carried-forward bans still hold).
  </acceptance_criteria>
  <done>MULTI-01, MULTI-02, MULTI-03 closed. Profile-VeriHashTiming.ps1 -Strict gate ready for dev use; Test-All.ps1 unchanged. Phase 2 ready for /gsd-verify-work.</done>
</task>

</tasks>

<verification>
Plan-level + phase-final gate:

```powershell
# 1. Full HotPath test suite (excluding Performance — CI default)
Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1,Tests/VeriHash.HotPath.PE.Tests.ps1,Tests/VeriHash.HotPath.Sig.Tests.ps1,Tests/VeriHash.HotPath.Batch.Tests.ps1 -ExcludeTag Performance -Output Detailed

# 2. Performance tier (Windows local before /gsd-verify-work)
if ($IsWindows) { Invoke-Pester -Path Tests/VeriHash.HotPath.Perf.Tests.ps1 -Tag Performance -Output Detailed }

# 3. Full repo suite (proves no regression in Phase 1)
.\Test-All.ps1 -CI

# 4. Lint
Invoke-ScriptAnalyzer -Path VeriHash.HotPath -Recurse -Settings PSScriptAnalyzerSettings.psd1
Invoke-ScriptAnalyzer -Path Profile-VeriHashTiming.ps1 -Settings PSScriptAnalyzerSettings.psd1

# 5. Carried-forward bans
Select-String -Path VeriHash.HotPath -Pattern 'WTD_DISABLE_MD2_MD4|PSFramework|Write-PSFMessage|\$IsWindows|\$RunningOnWindows' -Recurse

# 6. Tally byte-lock spot check
Import-Module ./VeriHash.HotPath/VeriHash.HotPath.psd1 -Force
$probe = Invoke-VeriHashBatch -FilePath @('Tests/Fixtures/tiny-pe.bin','Tests/Fixtures/tiny-not-pe.bin')
$probe.TallyLine   # MUST equal: '2/2 matched, 0 mismatch, 0 missing'
```
</verification>

<success_criteria>
- Tests/VeriHash.HotPath.Batch.Tests.ps1 green (FailedCount=0).
- All four ROADMAP Phase 2 success criteria #4 + #5 (multi-file tally + per-file feature preservation) demonstrably pass.
- Profile-VeriHashTiming.ps1 -Strict throws on regression; without -Strict (Test-All.ps1 step 3/3) behavior unchanged.
- Full repo Test-All.ps1 -CI green — Phase 1 not regressed.
- Carried-forward bans still hold (no PSFramework, no forbidden flags, no redundant platform checks).
</success_criteria>

<output>
After completion, create `.planning/phases/02-hot-path-performance-multi-file-loop/02-03-SUMMARY.md` with:
- Files added/modified
- Test results (passed/failed/skipped) for all four HotPath test files
- Final tally-line examples observed
- Profile-VeriHashTiming.ps1 -Strict bound formula (`(1.2 * max(hashMs, sigMs)) + 100ms`)
- Confirmation that all 5 ROADMAP Phase 2 success criteria pass + all 8 requirement IDs (PERF-01..05, MULTI-01..03) satisfied
- Recommended next action: `/gsd-verify-work 2`
</output>
