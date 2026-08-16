# Phase 3: Manifest Module - Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 12 new files (6 module source + 5 test files + 1 Build.ps1 update)
**Analogs found:** 12 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `VeriHash.Manifest/VeriHash.Manifest.psd1` | config | module-manifest | `VeriHash.HotPath/VeriHash.HotPath.psd1` | exact |
| `VeriHash.Manifest/VeriHash.Manifest.psm1` | config | module-loader | `VeriHash.HotPath/VeriHash.HotPath.psm1` | exact |
| `VeriHash.Manifest/Public/New-VeriHashManifest.ps1` | service | file-I/O + transform | `VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1` | role-match |
| `VeriHash.Manifest/Public/Test-VeriHashManifest.ps1` | service | file-I/O + request-response | `VeriHash.Core/Public/Test-VeriHashSidecar.ps1` | exact |
| `VeriHash.Manifest/Private/Resolve-ManifestTargetPath.ps1` | utility | transform | `VeriHash.Core/Private/Get-PreferredSidecar.ps1` | role-match |
| `VeriHash.Manifest/Private/Write-ManifestAtomically.ps1` | utility | file-I/O | `VeriHash.HotPath/Private/Test-IsPEFile.ps1` | partial (private helper pattern only) |
| `VeriHash.Manifest/Private/Read-ManifestLine.ps1` | utility | transform | `VeriHash.Core/Private/Read-SidecarLine.ps1` | exact |
| `VeriHash.Manifest/Private/Test-PathTraversal.ps1` | utility | transform | `VeriHash.HotPath/Private/Test-IsPEFile.ps1` | role-match |
| `Tests/VeriHash.Manifest.Module.Tests.ps1` | test | module-surface | `Tests/VeriHash.HotPath.Tests.ps1` | exact |
| `Tests/VeriHash.Manifest.New.Tests.ps1` | test | integration | `Tests/VeriHash.HotPath.Batch.Tests.ps1` | role-match |
| `Tests/VeriHash.Manifest.Verify.Tests.ps1` | test | integration | `Tests/VeriHash.Core.Test-VeriHashSidecar.Tests.ps1` | exact |
| `Tests/VeriHash.Manifest.ExitCodes.Tests.ps1` | test | unit | `Tests/VeriHash.HotPath.Batch.Tests.ps1` | role-match |
| `Tests/VeriHash.Manifest.Roundtrip.Tests.ps1` | test | integration | `Tests/VeriHash.HotPath.Batch.Tests.ps1` | partial (WSL-specific, no prior analog) |

---

## Pattern Assignments

### `VeriHash.Manifest/VeriHash.Manifest.psd1` (config, module-manifest)

**Analog:** `VeriHash.HotPath/VeriHash.HotPath.psd1` (entire file, 55 lines)

**Core pattern** — copy the HotPath manifest structure exactly, changing only module-specific fields:
```powershell
# Source: VeriHash.HotPath/VeriHash.HotPath.psd1 lines 1-55
@{
    RootModule           = 'VeriHash.HotPath.psm1'
    ModuleVersion        = '2.0.0'
    CompatiblePSEditions = 'Core'
    GUID                 = '23dd5e06-ffed-420a-92fb-488cb9087ccc'
    Author               = 'arcticpinecone'
    CompanyName          = 'Unknown'
    Copyright            = '(c) arcticpinecone. All rights reserved.'
    Description          = 'Hot-path orchestration: PE-detect, parallel hash+Authenticode, multi-file batch with tally.'
    PowerShellVersion    = '7.0'
    FunctionsToExport    = 'Get-VeriHashSignature', 'Invoke-VeriHashHotPath', 'Invoke-VeriHashBatch'
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData = @{
        PSData = @{
        }
    }
}
```

**Changes for VeriHash.Manifest:**
- `RootModule` → `'VeriHash.Manifest.psm1'`
- `GUID` → generate new GUID
- `Description` → `'GNU sha256sum-compatible manifest creation and verification for VeriHash.'`
- `FunctionsToExport` → `'New-VeriHashManifest', 'Test-VeriHashManifest'`
- **ADD** `RequiredModules = @('VeriHash.Core')` (D-16 — HotPath omits this, but CONTEXT.md locks it for Manifest)

---

### `VeriHash.Manifest/VeriHash.Manifest.psm1` (config, module-loader)

**Analog:** `VeriHash.HotPath/VeriHash.HotPath.psm1` (entire file, 21 lines) — copy verbatim

**Core pattern** (lines 1-21):
```powershell
# Source: VeriHash.HotPath/VeriHash.HotPath.psm1 lines 1-21
$ErrorActionPreference = 'Stop'

# HotPath orchestrator depends on Get-VeriHashResult / Format-VeriHashReport / Read-ClipboardHash
# / Test-VeriHashSidecar / Write-VeriHashLog from VeriHash.Core, plus Get-VeriHashPlatform.
# Import Core eagerly so callers don't have to (Plan 02-02 follow-up to Open Question 4).
$coreManifest = Join-Path $PSScriptRoot '..\VeriHash.Core\VeriHash.Core.psd1'
if (Test-Path -LiteralPath $coreManifest) {
    Import-Module $coreManifest -Force -Global -ErrorAction Stop
}

# Dot-source Private helpers FIRST so Public functions can call them at runtime.
Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

# Then dot-source Public functions.
$publicFiles = @(Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -ErrorAction SilentlyContinue)
foreach ($f in $publicFiles) { . $f.FullName }

# Belt-and-suspenders alongside the manifest's FunctionsToExport.
Export-ModuleMember -Function $publicFiles.BaseName
```

**Changes for VeriHash.Manifest:**
- Update the comment on line 3-5 to describe VeriHash.Manifest's dependency on Core (uses `Get-VeriHashResult`)
- Path to Core stays the same: `Join-Path $PSScriptRoot '..\VeriHash.Core\VeriHash.Core.psd1'`

---

### `VeriHash.Manifest/Public/New-VeriHashManifest.ps1` (service, file-I/O + transform)

**Analog:** `VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1` (file-loop + accumulate pattern)

**Function signature pattern** (from `Invoke-VeriHashBatch.ps1` lines 1-30):
```powershell
# Source: VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1 lines 1-30
function Invoke-VeriHashBatch {
    <#
    .SYNOPSIS
        Multi-file hot-path loop: per-file Invoke-VeriHashHotPath, accumulate tally, emit byte-locked tally line.
    .DESCRIPTION
        Sequential foreach over $FilePath (D-A4-1: no per-file parallelism -- preserves output ordering).
        ...
    .PARAMETER FilePath
        One or more file paths to process.
    .PARAMETER Algorithm
        MD5 | SHA256 (default) | SHA512. Applied to all files.
    .OUTPUTS
        VeriHash.BatchResult
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.BatchResult')]
    param(
        [Parameter(Mandatory)]
        [string[]]$FilePath,

        [ValidateSet('MD5', 'SHA256', 'SHA512')]
        [string]$Algorithm = 'SHA256',

        [switch]$Log
    )
```

**Sequential file-loop pattern** (from `Invoke-VeriHashBatch.ps1` lines 32-62):
```powershell
# Source: VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1 lines 32-62
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
                default    { $missing++ }
            }
        } catch {
            $missing++
            $results.Add([pscustomobject]@{
                PSTypeName       = 'VeriHash.HotPathResult'
                FilePath         = $p
                Hash             = $null
                # ... error result fields ...
                MatchResult      = 'missing'
            })
        }
    }
```

**Result object pattern** (from `Invoke-VeriHashBatch.ps1` lines 68-74):
```powershell
# Source: VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1 lines 68-74
    return [pscustomobject]@{
        PSTypeName = 'VeriHash.BatchResult'
        Results    = $results.ToArray()
        Tally      = @{ Total = $FilePath.Count; Matched = $matched; Mismatch = $mismatch; Missing = $missing }
        TallyLine  = $tallyLine
    }
```

**Key differences for New-VeriHashManifest:**
- D-10: **Stop on first error** (`throw` in catch, not continue-and-tally)
- Uses `Get-VeriHashResult` directly (not `Invoke-VeriHashHotPath`)
- Returns `VeriHash.ManifestCreateResult` (not `BatchResult`)
- Calls private helpers: `Resolve-ManifestTargetPath`, `Write-ManifestAtomically`
- No `Write-Host` (D-17)

**Also reference:** `Get-VeriHashResult` call pattern (from `Test-VeriHashSidecar.ps1` line 29):
```powershell
# Source: VeriHash.Core/Public/Test-VeriHashSidecar.ps1 line 29
    $actual = Get-VeriHashResult -Path $Path -Algorithm $sidecar.Algorithm
```

---

### `VeriHash.Manifest/Public/Test-VeriHashManifest.ps1` (service, file-I/O + request-response)

**Analog:** `VeriHash.Core/Public/Test-VeriHashSidecar.ps1` (verify file → compare hash → return result)

**Function signature pattern** (from `Test-VeriHashSidecar.ps1` lines 1-20):
```powershell
# Source: VeriHash.Core/Public/Test-VeriHashSidecar.ps1 lines 1-20
function Test-VeriHashSidecar {
    <#
    .SYNOPSIS
        Verifies a target file against its strongest adjacent sidecar.
    .DESCRIPTION
        Sidecar precedence: .sha512 > .sha256 > .md5. ...
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

**Hash compare pattern** (from `Test-VeriHashSidecar.ps1` lines 43-53):
```powershell
# Source: VeriHash.Core/Public/Test-VeriHashSidecar.ps1 lines 43-53
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

**Key differences for Test-VeriHashManifest:**
- Reads manifest file and parses lines (calls `Read-ManifestLine` per line)
- Calls `Test-PathTraversal` per entry
- Loops over all entries, accumulates per-entry results and exit code
- Returns `VeriHash.ManifestVerifyResult` with `.ExitCode`, `.Entries[]`, `.Summary`
- Uses `[Math]::Max($exitCode, $newCode)` for exit code precedence (priority: 3 > 1 > 2 > 0 per MANIFEST-06)

---

### `VeriHash.Manifest/Private/Read-ManifestLine.ps1` (utility, transform)

**Analog:** `VeriHash.Core/Private/Read-SidecarLine.ps1` (entire file, 22 lines) — nearly identical purpose

**Core pattern** (lines 1-22):
```powershell
# Source: VeriHash.Core/Private/Read-SidecarLine.ps1 lines 1-22
function Read-SidecarLine {
    <#
    .SYNOPSIS
        Parses a v1 sidecar line into hash + filename.
    .DESCRIPTION
        Accepts both v1 sidecar formats:
          'HASH  filename'  (two-space, GNU coreutils text mode)
          'HASH *filename'  (one-space + asterisk, GNU coreutils binary mode)
    .OUTPUTS
        System.Collections.Hashtable -- @{ Hash; Filename } or $null.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )
    if ($Line -match '^([A-Fa-f0-9]+)\s+\*?(.+)$') {
        return @{ Hash = $matches[1].ToLowerInvariant(); Filename = $matches[2].Trim() }
    }
    return $null
}
```

**Key differences for Read-ManifestLine:**
- **Stricter regex:** `'^([0-9a-fA-F]{64})[ ](\*| )(.+)$'` — requires exactly 64 hex chars (SHA256-specific), no loose `\s+`
- Must handle D-04 skip logic (blank lines, `#` comments) — either in this function or in the caller
- Returns `$null` for unparseable lines (same pattern) so caller can set exit code 3
- Should `TrimEnd("`r")` on input to handle CRLF manifests

---

### `VeriHash.Manifest/Private/Resolve-ManifestTargetPath.ps1` (utility, transform)

**Analog:** `VeriHash.Core/Private/Get-PreferredSidecar.ps1` (entire file, 29 lines) — private utility returning `[pscustomobject]` or `$null`

**Core pattern** (lines 1-29):
```powershell
# Source: VeriHash.Core/Private/Get-PreferredSidecar.ps1 lines 1-29
function Get-PreferredSidecar {
    <#
    .SYNOPSIS
        Picks the strongest adjacent sidecar for a target file.
    .DESCRIPTION
        Precedence: .sha512 > .sha256 > .md5. Returns the first existing
        sidecar adjacent to the target, or $null when none exists.
    .OUTPUTS
        System.Management.Automation.PSCustomObject -- @{ Path; Algorithm } or $null.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$TargetPath
    )
    $algoMap = [ordered]@{
        '.sha512' = 'SHA512'
        '.sha256' = 'SHA256'
        '.md5'    = 'MD5'
    }
    foreach ($ext in $algoMap.Keys) {
        $sidecarPath = "$TargetPath$ext"
        if (Test-Path -LiteralPath $sidecarPath) {
            return [pscustomobject]@{ Path = $sidecarPath; Algorithm = $algoMap[$ext] }
        }
    }
    return $null
}
```

**Key differences for Resolve-ManifestTargetPath:**
- Generates the manifest filename using D-01 format: `YYYY-MM-DDTHHMMSSZ_manifest.sha256`
- Handles D-02 collision: append `-1`, `-2`, etc. if file exists (loop with `Test-Path`)
- Returns the resolved final path as a string

---

### `VeriHash.Manifest/Private/Write-ManifestAtomically.ps1` (utility, file-I/O)

**Analog:** `VeriHash.HotPath/Private/Test-IsPEFile.ps1` (private helper structure only)

**Private helper structure** (from `Test-IsPEFile.ps1` lines 1-36):
```powershell
# Source: VeriHash.HotPath/Private/Test-IsPEFile.ps1 lines 1-36
function Test-IsPEFile {
    <#
    .SYNOPSIS
        Returns $true iff the file at $Path begins with the PE/MZ magic bytes (0x4D 0x5A).
    .DESCRIPTION
        Content-based PE detection. Opens the file with [System.IO.File]::OpenRead, ...
    .PARAMETER Path
        File path to inspect. May be missing or invalid; this function never throws.
    .OUTPUTS
        [bool]
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string] $Path
    )
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            # ... low-level I/O ...
        }
        finally {
            $stream.Dispose()
        }
    }
    catch {
        return $false
    }
}
```

**Core I/O pattern for atomic write** (from RESEARCH.md Pattern 3+4):
```powershell
# Source: RESEARCH.md Pattern 3 (UTF-8 NoBOM + LF) + Pattern 4 (Atomic Write)
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$content = ($lines -join "`n") + "`n"   # LF after each line, including last
$tempFile = Join-Path $targetDir "~verihash-$([guid]::NewGuid().ToString('N').Substring(0, 8)).tmp"
try {
    [System.IO.File]::WriteAllText($tempFile, $content, $utf8NoBom)
    Move-Item -Path $tempFile -Destination $finalPath -ErrorAction Stop
} catch {
    if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile -Force }
    throw
}
```

**Key note:** Use `try/catch/finally` (not just `try/catch`) — `finally` block executes even on `PipelineStoppedException` (Ctrl+C). Place temp cleanup in `finally` for robustness (RESEARCH.md Pitfall 4).

---

### `VeriHash.Manifest/Private/Test-PathTraversal.ps1` (utility, transform)

**Analog:** `VeriHash.HotPath/Private/Test-IsPEFile.ps1` (boolean-returning private helper)

**Structure pattern** (from `Test-IsPEFile.ps1` lines 1-21):
```powershell
# Source: VeriHash.HotPath/Private/Test-IsPEFile.ps1 lines 16-21
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string] $Path
    )
```

**Path traversal logic** (from RESEARCH.md Pattern 5):
```powershell
# Source: RESEARCH.md Pattern 5 (Path Traversal Detection)
$resolved = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::Combine($manifestDir, $entryPath)
)
# Pitfall 3: Ensure directory separator at end to prevent sibling-dir prefix collision
$manifestDirWithSep = $manifestDir.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$isSafe = $resolved.StartsWith($manifestDirWithSep, [System.StringComparison]::OrdinalIgnoreCase)
```

**Parameters:** Takes `$EntryPath` (from manifest) and `$BaseDirectory` (manifest's parent dir). Returns `[bool]` — `$true` if safe, `$false` if traversal detected.

---

### `Tests/VeriHash.Manifest.Module.Tests.ps1` (test, module-surface)

**Analog:** `Tests/VeriHash.HotPath.Tests.ps1` (lines 1-58) — exact same purpose

**BeforeAll/AfterAll pattern** (lines 1-8):
```powershell
# Source: Tests/VeriHash.HotPath.Tests.ps1 lines 1-8
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
}
AfterAll {
    Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}
```

**Module imports-cleanly test** (lines 10-17):
```powershell
# Source: Tests/VeriHash.HotPath.Tests.ps1 lines 10-17
Describe 'VeriHash.HotPath module manifest + exports (Plan 01 surface)' {
    It 'Imports cleanly' {
        { Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force } | Should -Not -Throw
    }

    It 'Re-imports with -Force without "type already defined"' {
        { 1..2 | ForEach-Object { Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force } } | Should -Not -Throw
    }
```

**Exports-exactly test** (lines 27-31):
```powershell
# Source: Tests/VeriHash.HotPath.Tests.ps1 lines 27-31
    It 'Exports exactly the locked Plan 02 public surface' {
        $expected = @('Get-VeriHashSignature', 'Invoke-VeriHashHotPath', 'Invoke-VeriHashBatch') | Sort-Object
        $actual   = (Get-Command -Module VeriHash.HotPath).Name | Sort-Object
        Compare-Object $actual $expected | Should -BeNullOrEmpty
    }
```

**Manifest pins test** (lines 33-37):
```powershell
# Source: Tests/VeriHash.HotPath.Tests.ps1 lines 33-37
    It 'Manifest pins PowerShellVersion 7.0 and CompatiblePSEditions Core' {
        $m = Test-ModuleManifest "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1"
        $m.PowerShellVersion | Should -Be ([version]'7.0')
        $m.CompatiblePSEditions | Should -Contain 'Core'
    }
```

**No-PSFramework test** (lines 39-43):
```powershell
# Source: Tests/VeriHash.HotPath.Tests.ps1 lines 39-43
    It 'No PSFramework references in VeriHash.HotPath/' {
        $hits = Get-ChildItem "$PSScriptRoot/../VeriHash.HotPath" -Recurse -File |
            Select-String -Pattern 'PSFramework|Write-PSFMessage' -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }
```

**Changes for VeriHash.Manifest.Module.Tests.ps1:**
- Module name → `VeriHash.Manifest`
- Expected exports → `'New-VeriHashManifest', 'Test-VeriHashManifest'`
- Add test verifying `RequiredModules` includes `VeriHash.Core`

---

### `Tests/VeriHash.Manifest.New.Tests.ps1` (test, integration)

**Analog:** `Tests/VeriHash.HotPath.Batch.Tests.ps1` (lines 1-92)

**Test setup with file fixtures in $TestDrive** (lines 1-18):
```powershell
# Source: Tests/VeriHash.HotPath.Batch.Tests.ps1 lines 1-18
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')

    $script:PEFixture    = Join-Path $PSScriptRoot 'Fixtures/tiny-pe.bin'
    $script:NotPEFixture = Join-Path $PSScriptRoot 'Fixtures/tiny-not-pe.bin'
    $script:F1 = $script:PEFixture
    $script:F2 = $script:NotPEFixture
    $script:F3 = Join-Path $TestDrive 'extra.bin'
    [IO.File]::WriteAllBytes($script:F3, [byte[]](1..16))

    Remove-Item Env:VERIHASH_LOG -ErrorAction SilentlyContinue
}
AfterAll {
    Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}
```

**Result-shape assertion pattern** (lines 25-29):
```powershell
# Source: Tests/VeriHash.HotPath.Batch.Tests.ps1 lines 25-29
    It 'Accepts [string[]] $FilePath and returns Results.Count == input count' {
        $r = Invoke-VeriHashBatch -FilePath @($script:F1, $script:F2, $script:F3) -Algorithm SHA256
        $r.PSTypeNames | Should -Contain 'VeriHash.BatchResult'
        $r.Results.Count | Should -Be 3
    }
```

**Changes for VeriHash.Manifest.New.Tests.ps1:**
- Import `VeriHash.Manifest` instead of `VeriHash.HotPath`
- Create test files in `$TestDrive` (simple text/bin files)
- Test: returns `VeriHash.ManifestCreateResult` with correct `.ManifestPath`, `.FileCount`
- Test: manifest file physically exists at `.ManifestPath`
- Test: manifest content is GNU-parseable (`<64hex> *<filename>` per line)
- Test: D-18 hash extension filtering (`.sha256` files excluded)
- Test: MANIFEST-02 multi-directory rejection
- Test: D-10 stop-on-first-error (error file aborts, no manifest written)
- Test: D-02 collision handling (pre-create a manifest, verify `-1` suffix)

---

### `Tests/VeriHash.Manifest.Verify.Tests.ps1` (test, integration)

**Analog:** `Tests/VeriHash.Core.Test-VeriHashSidecar.Tests.ps1` (lines 1-48)

**Test fixture setup + file manipulation** (lines 1-16):
```powershell
# Source: Tests/VeriHash.Core.Test-VeriHashSidecar.Tests.ps1 lines 1-9
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

**Write test sidecar files with UTF-8 NoBOM** (lines 35-38):
```powershell
# Source: Tests/VeriHash.Core.Test-VeriHashSidecar.Tests.ps1 lines 35-38
        $enc = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText((Join-Path $TestDrive 'VeriHash_1024.ico.md5'),    "$md5  VeriHash_1024.ico`n",    $enc)
        [System.IO.File]::WriteAllText((Join-Path $TestDrive 'VeriHash_1024.ico.sha256'), "$sha256  VeriHash_1024.ico`n", $enc)
        [System.IO.File]::WriteAllText((Join-Path $TestDrive 'VeriHash_1024.ico.sha512'), "$sha512  VeriHash_1024.ico`n", $enc)
```

**Changes for VeriHash.Manifest.Verify.Tests.ps1:**
- Import `VeriHash.Manifest`
- Create test files + write manifest by hand (or via `New-VeriHashManifest`)
- Test: returns `VeriHash.ManifestVerifyResult` with `.ExitCode 0`, `.Entries` all `pass`
- Test: mismatch detection (tamper a file, verify `.ExitCode 1`)
- Test: missing file detection (delete a file, verify `.ExitCode 2`)
- Test: D-04 comment/blank line skipping
- Test: MANIFEST-05 path traversal hard reject (`.ExitCode 3`)
- Test: MANIFEST-04 malformed line parse error (`.ExitCode 3`)

---

### `Tests/VeriHash.Manifest.ExitCodes.Tests.ps1` (test, unit)

**Analog:** `Tests/VeriHash.HotPath.Batch.Tests.ps1` (tally bucket verification pattern)

**Tally assertion pattern** (lines 37-51):
```powershell
# Source: Tests/VeriHash.HotPath.Batch.Tests.ps1 lines 43-50
    It 'TallyLine for {match, match, match} is exactly "3/3 matched, 0 mismatch, 0 missing"' {
        $r = Invoke-VeriHashBatch -FilePath @($script:F1, $script:F2, $script:F3) -Algorithm SHA256
        $r.TallyLine | Should -Be '3/3 matched, 0 mismatch, 0 missing'
        $r.Tally.Total    | Should -Be 3
        $r.Tally.Matched  | Should -Be 3
        $r.Tally.Mismatch | Should -Be 0
        $r.Tally.Missing  | Should -Be 0
    }
```

**Apply pattern to exit code scenarios:**
- All pass → `.ExitCode` 0
- One mismatch → `.ExitCode` 1
- One missing, no mismatch → `.ExitCode` 2
- Malformed line → `.ExitCode` 3
- Both mismatch + missing → `.ExitCode` per precedence (MANIFEST-06: 3 > 1 > 2 > 0)
- Each test creates a manifest file by hand and calls `Test-VeriHashManifest`

---

### `Tests/VeriHash.Manifest.Roundtrip.Tests.ps1` (test, integration)

**Analog:** No exact analog — WSL integration is new. Use BeforeAll/AfterAll from HotPath tests + RESEARCH.md WSL pattern.

**WSL skip pattern** (from RESEARCH.md Code Examples):
```powershell
# Source: RESEARCH.md WSL Round-Trip Test section
It 'Manifest round-trips through sha256sum -c on WSL' {
    $wslAvailable = $null -ne (Get-Command wsl -ErrorAction SilentlyContinue)
    if (-not $wslAvailable) {
        Set-ItResult -Skipped -Because 'WSL not available'
        return
    }
    # Create files in $TestDrive, generate manifest, convert path to WSL format
    $wslDir = ($TestDrive -replace '\\', '/' -replace '^([A-Z]):', { '/mnt/' + $_.Groups[1].Value.ToLower() })
    $result = wsl -d Debian -- bash -c "cd '$wslDir' && sha256sum -c 'manifest.sha256'" 2>&1
    $LASTEXITCODE | Should -Be 0
}
```

---

## Shared Patterns

### Result Object Convention
**Source:** `VeriHash.Core/Public/Get-VeriHashResult.ps1` lines 30-37
**Apply to:** `New-VeriHashManifest.ps1`, `Test-VeriHashManifest.ps1`
```powershell
# Every public function returns [pscustomobject] with PSTypeName — never a PowerShell class
return [pscustomobject]@{
    PSTypeName = 'VeriHash.Result'
    FilePath   = $resolved
    Size       = [long]$info.Length
    Algorithm  = $Algorithm
    Hash       = $hash
    ElapsedMs  = [int]$sw.ElapsedMilliseconds
}
```

### Function Signature Convention
**Source:** `VeriHash.Core/Public/Get-VeriHashResult.ps1` lines 1-24
**Apply to:** All 6 new `.ps1` function files
```powershell
function Verb-VeriHashNoun {
    <#
    .SYNOPSIS
        One-line description.
    .DESCRIPTION
        Detailed description with decision references (D-XX).
    .PARAMETER Name
        Parameter description.
    .OUTPUTS
        VeriHash.TypeName
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.TypeName')]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
```

### Module Loader Convention
**Source:** `VeriHash.HotPath/VeriHash.HotPath.psm1` lines 1-21
**Apply to:** `VeriHash.Manifest.psm1`
- `$ErrorActionPreference = 'Stop'` at top
- Eager `Import-Module` of Core via sibling path
- Dot-source Private then Public
- `Export-ModuleMember` belt-and-suspenders

### Test Isolation Convention
**Source:** `Tests/VeriHash.HotPath.Tests.ps1` lines 1-8
**Apply to:** All 5 new test files
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
}
AfterAll {
    Remove-Module VeriHash.Manifest -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}
```

### UTF-8 NoBOM + LF Write Convention
**Source:** `Tests/VeriHash.Core.Test-VeriHashSidecar.Tests.ps1` lines 35-38
**Apply to:** `Write-ManifestAtomically.ps1`, all test files that write manifest fixtures
```powershell
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
```

### Error Handling Convention
**Source:** `VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1` lines 38-62 (try/catch in loop)
**Apply to:** `New-VeriHashManifest.ps1` (but with abort-on-error, not continue)
```powershell
# For New-VeriHashManifest: stop-on-first-error (D-10)
try {
    # hash file, build manifest lines
} catch {
    # cleanup temp file, re-throw
    throw
}
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Tests/VeriHash.Manifest.Roundtrip.Tests.ps1` | test | integration (WSL) | No existing WSL integration tests in the codebase. Pattern sourced from RESEARCH.md code examples. |

---

## Metadata

**Analog search scope:** `VeriHash.Core/`, `VeriHash.HotPath/`, `Tests/`
**Files scanned:** 25 (all `.ps1`, `.psd1`, `.psm1` across module and test directories)
**Pattern extraction date:** 2026-04-18
