# Phase 6: Sidecar Auto-Detect - Pattern Map

**Mapped:** 2026-04-19
**Files analyzed:** 5 (3 new, 2 modified)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `VeriHash.Core/Public/Invoke-VeriHashSidecarDetect.ps1` | service (routing/orchestration) | request-response | `VeriHash.Core/Public/Test-VeriHashSidecar.ps1` | exact — same module, same sidecar domain, reverse direction |
| `VeriHash.Core/VeriHash.Core.psd1` | config (module manifest) | — | Self (existing) | exact — add entry to `FunctionsToExport` |
| `VeriHash.ps1` (lines 152-196) | controller (CLI dispatcher) | request-response | Self (existing manifest-mode dispatch at lines 156-182) | exact — insert auto-detect branch before existing dispatch |
| `Tests/VeriHash.Core.Invoke-VeriHashSidecarDetect.Tests.ps1` | test (unit) | — | `Tests/VeriHash.Core.Test-VeriHashSidecar.Tests.ps1` | exact — same module, same sidecar domain |
| `Tests/VeriHash.Cli.SidecarAutoDetect.Tests.ps1` | test (integration/E2E) | — | `Tests/VeriHash.Cli.Tests.ps1` | exact — same CLI dispatch testing style |

## Pattern Assignments

### `VeriHash.Core/Public/Invoke-VeriHashSidecarDetect.ps1` (service, request-response) — NEW

**Analog:** `VeriHash.Core/Public/Test-VeriHashSidecar.ps1`

**Function declaration pattern** (lines 1-20):
```powershell
function Test-VeriHashSidecar {
    <#
    .SYNOPSIS
        Verifies a target file against its strongest adjacent sidecar.
    .DESCRIPTION
        Sidecar precedence: .sha512 > .sha256 > .md5. Only the chosen sidecar
        is read and verified (single hash compute). Supports v1 sidecar formats
        ('HASH  filename' two-space and 'HASH *filename' asterisk).
    .PARAMETER Path
        Path to the TARGET file (NOT the sidecar). Resolved with -LiteralPath.
    .OUTPUTS
        VeriHash.Result with an additional 'Sidecar' field describing which
        sidecar was used, or $null when no sidecar exists.
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.Result')]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
```
**Apply:** Copy this structure exactly — `[CmdletBinding()]`, `[OutputType()]`, `param()`, comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.OUTPUTS`. The new function should use `[OutputType('VeriHash.SidecarVerifyResult', 'VeriHash.ManifestVerifyResult')]`.

**Path resolution + sidecar read pattern** (lines 22-27):
```powershell
    $sidecar = Get-PreferredSidecar -TargetPath $Path
    if (-not $sidecar) { return $null }

    $sidecarLeaf = Split-Path -Leaf $sidecar.Path
    $line = Get-Content -LiteralPath $sidecar.Path -TotalCount 1
    $parsed = Read-SidecarLine -Line $line
```
**Apply:** The new function calls `Read-SidecarLine` with the same signature. It reads lines with `[System.IO.File]::ReadAllLines()` instead of `Get-Content -TotalCount 1` (since it needs to count ALL non-blank lines to distinguish 1-line sidecar from N-line manifest).

**Hash computation via Get-VeriHashResult** (line 29):
```powershell
    $actual = Get-VeriHashResult -Path $Path -Algorithm $sidecar.Algorithm
```
**Apply:** Same call pattern — pass companion path and algorithm derived from extension.

**Result comparison and status** (lines 43-53):
```powershell
    $status = if ($actual.Hash -eq $parsed.Hash) { 'matched' } else { 'mismatch' }

    return [pscustomobject]@{
        PSTypeName = 'VeriHash.Result'
        FilePath   = $actual.FilePath
        Size       = $actual.Size
        Algorithm  = $actual.Algorithm
        Hash       = $actual.Hash
        ElapsedMs  = $actual.ElapsedMs
        Sidecar    = "$status ($sidecarLeaf)"
    }
```
**Apply:** New function returns `VeriHash.SidecarVerifyResult` PSTypeName with fields: `SidecarPath`, `CompanionPath`, `Algorithm`, `ExpectedHash`, `ActualHash`, `Status` ('pass'|'mismatch'), `ElapsedMs`, `Warning`. Follow the `[pscustomobject]@{ PSTypeName = ... }` convention exactly.

---

**Secondary analog:** `VeriHash.Manifest/Public/Test-VeriHashManifest.ps1` (for path resolution + file reading + error handling patterns)

**File reading and blank-line filtering** (lines 31-34):
```powershell
    $resolvedManifest = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $manifestDir = Split-Path -Parent $resolvedManifest

    $rawLines = [System.IO.File]::ReadAllLines($resolvedManifest)
```
**Apply:** Same `Resolve-Path -LiteralPath` → `.ProviderPath` pattern, same `Split-Path -Parent` for directory, same `[System.IO.File]::ReadAllLines()` for reliable line reading. Filter blanks with `Where-Object { -not [string]::IsNullOrWhiteSpace($_) }`.

**Path traversal guard** (line 61, from `Test-PathTraversal.ps1`):
```powershell
        $isSafe = Test-PathTraversal -EntryPath $entryFilename -BaseDirectory $manifestDir
```
**Apply:** The new function MUST validate companion filenames extracted from GNU format lines against path traversal. `Test-PathTraversal` lives in VeriHash.Manifest (private). Either: (a) duplicate the guard logic inline, or (b) apply the same logic pattern:
```powershell
# From VeriHash.Manifest/Private/Test-PathTraversal.ps1 (lines 27-37):
    if ([System.IO.Path]::IsPathRooted($EntryPath)) { return $false }
    if ($EntryPath -match '^[A-Za-z]:') { return $false }
    $resolved = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine($BaseDirectory, $EntryPath)
    )
    $baseDirWithSep = $BaseDirectory.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    return $resolved.StartsWith($baseDirWithSep, [System.StringComparison]::OrdinalIgnoreCase)
```

**Companion path resolution** (lines 74-77 from Test-VeriHashManifest):
```powershell
        $resolvedPath = [System.IO.Path]::GetFullPath(
            [System.IO.Path]::Combine($manifestDir, $entryFilename)
        )
```
**Apply:** Same `[System.IO.Path]::GetFullPath(Combine(...))` pattern for resolving companion relative to sidecar dir, NOT CWD.

---

**Tertiary analog:** `VeriHash.Core/Private/Get-PreferredSidecar.ps1` (for extension→algorithm map)

**Extension-to-algorithm map** (lines 17-21):
```powershell
    $algoMap = [ordered]@{
        '.sha512' = 'SHA512'
        '.sha256' = 'SHA256'
        '.md5'    = 'MD5'
    }
```
**Apply:** Reuse this exact ordered map in the new function to determine algorithm from file extension.

---

**Tertiary analog:** `VeriHash.Core/Private/Read-SidecarLine.ps1` (for understanding return shape)

**Regex and return** (lines 18-21):
```powershell
    if ($Line -match '^([A-Fa-f0-9]+)\s+\*?(.+)$') {
        return @{ Hash = $matches[1].ToLowerInvariant(); Filename = $matches[2].Trim() }
    }
    return $null
```
**Apply:** When `Read-SidecarLine` returns `$null`, the line is a bare hash (no filename component). Bare hash fallback: strip hash extension from sidecar filename (`[System.IO.Path]::GetFileNameWithoutExtension($sidecarLeaf)`). When it returns a hashtable, use `$parsed.Hash` for expected hash and `$parsed.Filename` for companion name.

---

### `VeriHash.Core/VeriHash.Core.psd1` (config) — MODIFY

**Analog:** Self (existing file)

**FunctionsToExport pattern** (lines 72-73):
```powershell
FunctionsToExport = 'Get-VeriHashResult', 'Read-ClipboardHash', 'Test-VeriHashSidecar', 
               'Format-VeriHashReport', 'Write-VeriHashLog', 'Get-VeriHashPlatform'
```
**Apply:** Append `'Invoke-VeriHashSidecarDetect'` to this array. The `.psm1` auto-exports via `$publicFiles.BaseName` (line 12 of VeriHash.Core.psm1), but the manifest's `FunctionsToExport` is the authoritative export list and MUST be updated.

---

### `VeriHash.ps1` (controller, lines 152-196) — MODIFY

**Analog:** Self (existing dispatch structure)

**Current dispatch structure** (lines 152-196):
```powershell
# Main dispatch
$exitCode = 0

try {
    if ($Manifest) {
        # Manifest mode: extension auto-detect
        $manifestExts = @('.sha256', '.sha512', '.md5')
        $isVerify = $FilePath.Count -eq 1 -and
            [System.IO.Path]::GetExtension($FilePath[0]).ToLowerInvariant() -in $manifestExts

        if ($isVerify) {
            $result = Test-VeriHashManifest -Path $FilePath[0]
            # ... render manifest result ...
        } else {
            $result = New-VeriHashManifest -Path $FilePath
            # ...
        }
    } else {
        # Hash mode
        if ($FilePath.Count -eq 1) {
            Invoke-VeriHashHotPath -Path $FilePath[0] -Log:$Log
        } else {
            Invoke-VeriHashBatch -FilePath $FilePath -Log:$Log
        }
    }
} catch {
    Write-Error "$_"
    $exitCode = 1
}
```
**Apply:** Insert a new sidecar-auto-detect branch BEFORE the `if ($Manifest)` check (per SIDE-06: identical behavior with or without `-Manifest`). The auto-detect takes priority when: (1) `$FilePath.Count -eq 1` AND (2) extension is `.sha256`/`.sha512`/`.md5`. Pattern:
```powershell
$manifestExts = @('.sha256', '.sha512', '.md5')
$isSidecarCandidate = $FilePath.Count -eq 1 -and
    [System.IO.Path]::GetExtension($FilePath[0]).ToLowerInvariant() -in $manifestExts

try {
    if ($isSidecarCandidate) {
        # Sidecar auto-detect: unified for both -Manifest and hash mode (SIDE-06)
        $result = Invoke-VeriHashSidecarDetect -Path $FilePath[0]
        # ... render result based on PSTypeName ...
    } elseif ($Manifest) {
        # ... existing manifest create path ...
    } else {
        # ... existing hash mode path ...
    }
}
```

**Manifest verify render pattern** (lines 164-177 — reuse for N-line manifest result):
```powershell
            Write-Host "Manifest verify: $($result.ManifestPath)" -ForegroundColor Cyan
            foreach ($entry in $result.Entries) {
                $color = switch ($entry.Status) {
                    'pass'    { 'Green' }
                    'mismatch' { 'Red' }
                    'missing'  { 'Yellow' }
                    default    { 'Red' }
                }
                Write-Host "  $($entry.Path): $($entry.Status)" -ForegroundColor $color
            }
            $s = $result.Summary
            $tallyColor = if ($result.ExitCode -eq 0) { 'Green' } else { 'Red' }
            Write-Host "$($s.Passed)/$($s.Total) passed, $($s.Failed) mismatch, $($s.Missing) missing" -ForegroundColor $tallyColor
            $exitCode = $result.ExitCode
```
**Apply:** When `Invoke-VeriHashSidecarDetect` returns a `VeriHash.ManifestVerifyResult` (N-line path), render using this exact pattern. When it returns `VeriHash.SidecarVerifyResult` (1-line path), render a focused minimal output (D-01):
```powershell
# Focused sidecar verify output (D-01: no hot-path, no clipboard, no signatures)
$statusColor = if ($result.Status -eq 'pass') { 'Green' } else { 'Red' }
Write-Host "Sidecar verify: $($result.CompanionPath)" -ForegroundColor Cyan
Write-Host "  Algorithm: $($result.Algorithm)" -ForegroundColor Cyan
Write-Host "  Status:    $($result.Status.ToUpperInvariant())" -ForegroundColor $statusColor
```

---

### `Tests/VeriHash.Core.Invoke-VeriHashSidecarDetect.Tests.ps1` (test, unit) — NEW

**Analog:** `Tests/VeriHash.Core.Test-VeriHashSidecar.Tests.ps1`

**BeforeAll / AfterAll module import pattern** (lines 1-9):
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    $script:Fixture     = Join-Path $PSScriptRoot 'Fixtures/VeriHash_1024.ico'
    $script:TwoSpaceSrc = Join-Path $PSScriptRoot 'Fixtures/sidecar-twospace.sha256'
    $script:AsteriskSrc = Join-Path $PSScriptRoot 'Fixtures/sidecar-asterisk.sha256'
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}
```
**Apply:** Import `VeriHash.Core.psd1` with `-Force`. Clean up with `Remove-Module`. The new tests won't need Manifest module import since the N-line path can be tested by mocking `Test-VeriHashManifest`.

**Test fixture creation with $TestDrive** (lines 12-15):
```powershell
    BeforeEach {
        $script:IconCopy = Join-Path $TestDrive 'VeriHash_1024.ico'
        Copy-Item -LiteralPath $script:Fixture -Destination $script:IconCopy -Force
    }
```
**Apply:** Create sidecar fixture files in `$TestDrive` with `[System.IO.File]::WriteAllText()` (UTF8 no BOM, consistent with manifest test pattern). Create companion files alongside them.

**Sidecar file creation pattern** (lines 17-18, 36-38):
```powershell
        Copy-Item -LiteralPath $script:TwoSpaceSrc -Destination (Join-Path $TestDrive 'VeriHash_1024.ico.sha256') -Force
```
```powershell
        $enc = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText((Join-Path $TestDrive 'VeriHash_1024.ico.md5'),    "$md5  VeriHash_1024.ico`n",    $enc)
        [System.IO.File]::WriteAllText((Join-Path $TestDrive 'VeriHash_1024.ico.sha256'), "$sha256  VeriHash_1024.ico`n", $enc)
```
**Apply:** For the new unit tests, create sidecar files inline with `[System.IO.File]::WriteAllText()` (preferred over `Set-Content` for exact byte control). Create both GNU format (`$hash *filename`) and bare hash sidecars.

**Assertion patterns** (lines 19-21, 40, 46-47):
```powershell
        $r = Test-VeriHashSidecar -Path $script:IconCopy
        $r | Should -Not -BeNullOrEmpty
        $r.Sidecar | Should -Match 'matched'
```
```powershell
        $r.Algorithm | Should -Be 'SHA512'
```
```powershell
        Test-VeriHashSidecar -Path $bare | Should -BeNullOrEmpty
```
**Apply:** Assert on `$r.Status`, `$r.Algorithm`, `$r.CompanionPath`, `$r.ExpectedHash`, `$r.ActualHash`, `$r.Warning`, and PSTypeName.

---

**Secondary analog for unit tests:** `Tests/VeriHash.Manifest.Verify.Tests.ps1` (for richer fixture creation and CWD-independent testing)

**GUID-based test directory isolation** (lines 13-15):
```powershell
    BeforeEach {
        $script:testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
```
**Apply:** Use GUID-based subdirectories in `$TestDrive` for test isolation, especially for path-resolution tests.

**UTF8 no-BOM file creation** (lines 18-25):
```powershell
        $utf8 = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($script:f1, "content one`n", $utf8)
        [System.IO.File]::WriteAllText($script:f2, "content two`n", $utf8)
        $h1 = (Get-VeriHashResult -Path $script:f1 -Algorithm SHA256).Hash
        $h2 = (Get-VeriHashResult -Path $script:f2 -Algorithm SHA256).Hash
        $script:manifestPath = Join-Path $script:testDir 'test_manifest.sha256'
        $manifestContent = "$h1 *file1.txt`n$h2 *file2.txt`n"
        [System.IO.File]::WriteAllText($script:manifestPath, $manifestContent, $utf8)
```
**Apply:** Same pattern for creating companion files and sidecar files with known hashes.

**CWD-independent test pattern** (lines 115-121):
```powershell
            Push-Location $env:TEMP
            try {
                $r = Test-VeriHashManifest -Path $manifest
                $r.ExitCode | Should -Be 0
            } finally {
                Pop-Location
            }
```
**Apply:** Use this `Push-Location` / `try` / `finally` / `Pop-Location` pattern to test SIDE-03 (companion resolved relative to sidecar dir, not CWD).

---

### `Tests/VeriHash.Cli.SidecarAutoDetect.Tests.ps1` (test, integration) — NEW

**Analog:** `Tests/VeriHash.Cli.Tests.ps1`

**BeforeAll with all modules + CLI script ref** (lines 1-9):
```powershell
BeforeAll {
    # Pre-load modules so VeriHash.ps1's conditional import skips re-import
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')

    $script:cliScript = "$PSScriptRoot/../VeriHash.ps1"
}
```
**Apply:** Import ALL three modules before invoking VeriHash.ps1. Set `$env:VERIHASH_LOG_PATH` to `$TestDrive`.

**AfterAll cleanup** (lines 11-16):
```powershell
AfterAll {
    Remove-Module VeriHash.Manifest -ErrorAction SilentlyContinue
    Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}
```
**Apply:** Same cleanup sequence (Manifest → HotPath → Core).

**CLI E2E invocation pattern** (lines 133-139, 226-228):
```powershell
        $testFile = Join-Path $TestDrive 'hashme.txt'
        Set-Content $testFile 'single file hash test'
        $output = & $script:cliScript -FilePath $testFile -NoPause *>&1 | Out-String
        $output | Should -Match 'SHA256'
```
```powershell
        $output = & $script:cliScript -FilePath $manifestPath -Manifest -NoPause *>&1 | Out-String
        $output | Should -Match 'Manifest verify:'
        $output | Should -Match '1/1 passed'
```
**Apply:** Invoke VeriHash.ps1 with `& $script:cliScript -FilePath <path> -NoPause *>&1 | Out-String`. For SIDE-06 tests, run both `& ... -FilePath file.sha256 -NoPause` and `& ... -FilePath file.sha256 -Manifest -NoPause` and assert identical behavior.

**Exit code assertion** (line 235):
```powershell
        $LASTEXITCODE | Should -Be 1
```
**Apply:** Check `$LASTEXITCODE` for error-path tests (empty sidecar, missing companion).

---

## Shared Patterns

### PSTypeName Result Objects
**Source:** `VeriHash.Core/Public/Get-VeriHashResult.ps1` lines 30-39 and `VeriHash.Core/Public/Test-VeriHashSidecar.ps1` lines 45-53
**Apply to:** `Invoke-VeriHashSidecarDetect.ps1` return value
```powershell
# All result objects use [pscustomobject]@{ PSTypeName = 'VeriHash.XXX'; ... }
# Fields are PascalCase, hash values lowercase hex, timing in ElapsedMs as [int]
return [pscustomobject]@{
    PSTypeName = 'VeriHash.Result'
    FilePath   = $resolved
    Algorithm  = $Algorithm
    Hash       = $hash
    ElapsedMs  = [int]$sw.ElapsedMilliseconds
}
```

### Path Resolution
**Source:** `VeriHash.Manifest/Public/Test-VeriHashManifest.ps1` lines 31-32
**Apply to:** `Invoke-VeriHashSidecarDetect.ps1` for resolving sidecar path
```powershell
$resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
$parentDir = Split-Path -Parent $resolvedPath
```

### Extension-to-Algorithm Map
**Source:** `VeriHash.Core/Private/Get-PreferredSidecar.ps1` lines 17-21
**Apply to:** `Invoke-VeriHashSidecarDetect.ps1`, `VeriHash.ps1` dispatch
```powershell
$algoMap = [ordered]@{
    '.sha512' = 'SHA512'
    '.sha256' = 'SHA256'
    '.md5'    = 'MD5'
}
$ext = [System.IO.Path]::GetExtension($resolvedSidecar).ToLowerInvariant()
$algorithm = $algoMap[$ext]
```

### Module Auto-Load in .psm1
**Source:** `VeriHash.Core/VeriHash.Core.psm1` lines 1-12
**Apply to:** No changes needed — new `.ps1` file in `Public/` is auto-dot-sourced and auto-exported
```powershell
$ErrorActionPreference = 'Stop'
Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }
$publicFiles = @(Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -ErrorAction SilentlyContinue)
foreach ($f in $publicFiles) { . $f.FullName }
Export-ModuleMember -Function $publicFiles.BaseName
```

### Test Fixture File Creation (UTF8 no BOM)
**Source:** `Tests/VeriHash.Manifest.Verify.Tests.ps1` lines 18-25
**Apply to:** Both new test files
```powershell
$utf8 = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($filePath, $content, $utf8)
```

### Error Handling in CLI Dispatch
**Source:** `VeriHash.ps1` lines 191-194
**Apply to:** New sidecar auto-detect branch in VeriHash.ps1
```powershell
} catch {
    Write-Error "$_"
    $exitCode = 1
}
```

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| (none) | — | — | All 5 files have strong analogs in the existing codebase |

## Metadata

**Analog search scope:** `VeriHash.Core/Public/`, `VeriHash.Core/Private/`, `VeriHash.Manifest/Public/`, `VeriHash.Manifest/Private/`, `Tests/`, `VeriHash.ps1`
**Files scanned:** 12 analog candidates read
**Pattern extraction date:** 2026-04-19
