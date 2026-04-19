# Phase 5: Thin CLI + Cleanup & Docs - Pattern Map

**Mapped:** 2025-07-24
**Files analyzed:** 5 new/modified files + 8 deletions + 3 moves
**Analogs found:** 4 / 5 (README rewrite has no structural analog)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `VeriHash.ps1` (rewrite) | CLI dispatcher | request-response | `VeriHash.ps1` (current lines 56–185) + `VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1` | role-match |
| `Tests/VeriHash.Cli.Tests.ps1` (new) | test | request-response | `Tests/VeriHash.Integrations.Tests.ps1` + `Tests/VeriHash.HotPath.Tests.ps1` | exact |
| `README.md` (rewrite) | docs | N/A | `README.md` (current structure/badges) | partial |
| `CHANGELOG.md` (update) | docs | N/A | `CHANGELOG.md` (current format) | exact |
| `.planning/archive/` (new dir + 3 moves) | config | file-I/O | N/A | N/A |

### Files to DELETE (no patterns needed — just removal)
| File | Reason |
|------|--------|
| `QuickHash.ps1` | CLEAN-01 — standalone v1 tool retired |
| `Tests/QuickHash.Tests.ps1` | CLEAN-01 — tests for deleted file |
| `VeriHash.LogUtils.ps1` | CLEAN-02 / D-06 — dead code, no v2 consumer |
| `Tests/VeriHash.LogUtils.Tests.ps1` | CLEAN-02 / D-06 — tests for deleted file |
| `VeriHash.Config.ps1` | D-05 — v2 has no config system |
| `Tests/VeriHash.Config.Tests.ps1` | D-08 — tests for deleted file |
| `Tests/VeriHash.Tests.ps1` | D-08 — v1 smoke tests, replaced by VeriHash.Cli.Tests.ps1 |
| `VeriHash-OpenWith.bat` | D-07 — replaced by .lnk shortcuts |

### Files to MOVE (no patterns needed — just rename)
| Source | Destination |
|--------|-------------|
| `Verihash Logging Concepting.md` | `.planning/archive/Verihash Logging Concepting.md` |
| `Verihash Multifile Concepting.md` | `.planning/archive/Verihash Multifile Concepting.md` |
| `Verihash Multifile Concepting Review.md` | `.planning/archive/Verihash Multifile Concepting Review.md` |

---

## Pattern Assignments

### `VeriHash.ps1` (CLI dispatcher, rewrite from ~890 → ≤200 lines)

**Role:** Thin CLI that parses params, imports v2 modules, dispatches to correct function, renders output, handles centralized pause.

#### Analog 1: Current `VeriHash.ps1` — Preamble + Param Block + Help + SendTo dispatch (lines 1–185)

**License header pattern** (lines 1–54):
```powershell
<#
    VeriHash.ps1 - A cross-platform PowerShell tool for computing and verifying file hashes

    Copyright (C) 2024-2025 arcticpinecone <arcticpinecone@arcticpinecone.eu>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    [... AGPL boilerplate ...]
#>
```

**Param block pattern** (lines 56–95) — v2 replaces entirely per D-01:
```powershell
# v1 param block (TO BE REPLACED — shown for structural reference only):
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$FilePath,

    [switch]$NoPause,

    [switch]$SystemWide,

    [Alias("h", "?")]
    [Parameter(Mandatory = $false)]
    [switch]$Help
)
```

**v2 param block contract** (from D-01):
- `[string[]]$FilePath` — universal file input (array, not single string)
- `-Manifest` [switch]
- `-InstallSendTo` [switch] (renamed from -SendTo)
- `-InstallKDE` [switch]
- `-NoPause` [switch]
- `-SystemWide` [switch]
- `-Log` [switch]
- `-Help` [switch] with `[Alias("h","?")]`

**Module import pattern** (line 98):
```powershell
Import-Module "$PSScriptRoot\VeriHash.Core\VeriHash.Core.psd1" -Force -Global
```

**Help dispatch pattern** (lines 126–163):
```powershell
# Handle common help flags (--help, -h, /?, etc.) that might have been passed as FilePath
$helpFlags = @('--help', '--Help', '-h', '-H', '/?', '/h', '/H', 'help', 'HELP')
if ($FilePath -in $helpFlags) {
    $Help = $true
    $FilePath = $null
}

if ($Help) {
    Write-Host "VeriHash.ps1 - A tool to compute and verify file hashes ..." -ForegroundColor Green
    Write-Host "Usage: ..." -ForegroundColor Cyan
    # ... parameter descriptions with -ForegroundColor Yellow ...
    # ... examples with -ForegroundColor Cyan ...
    return
}
```

**SendTo/integration dispatch pattern** (lines 166–185):
```powershell
if ($SendTo) {
    . "$PSScriptRoot\VeriHash.Integrations.ps1"
    try {
        if ((Get-VeriHashPlatform) -eq 'Windows') {
            Install-WindowsSendTo
        }
        elseif ((Get-VeriHashPlatform) -eq 'Linux') {
            Install-LinuxContextMenu -SystemWide:$SystemWide
        }
        else {
            Write-Warning "Context menu integration is only supported on Windows and Linux."
        }
        return
    }
    catch {
        Write-Error "Error installing context menu integration: $_"
        return
    }
}
```

**Pause-at-end pattern** (lines 899–901 — v2 needs auto-detection per D-04):
```powershell
if (-not $NoPause -and $Host.Name -eq 'ConsoleHost') {
    Read-Host -Prompt "Press Enter to continue..."
}
```

#### Analog 2: `VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1` — Multi-file loop + tally (for hash-mode dispatch shape)

**Multi-file loop with error bucketing** (lines 37–62):
```powershell
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
            # ... error fallback object ...
        })
    }
}
```

#### Analog 3: `VeriHash.Integrations.ps1` — Lazy dot-source pattern (for how CLI loads Integrations)

**Conditional import of VeriHash.Core** (lines 15–17):
```powershell
if (-not (Get-Module -Name 'VeriHash.Core')) {
    Import-Module "$PSScriptRoot/VeriHash.Core/VeriHash.Core.psd1"
}
```

#### Analog 4: `VeriHash.HotPath/VeriHash.HotPath.psm1` — Eager module import pattern (for CLI module loading)

**Module psm1 import pattern** (lines 1–9):
```powershell
$ErrorActionPreference = 'Stop'

# HotPath depends on Core; import eagerly
$coreManifest = Join-Path $PSScriptRoot '..\VeriHash.Core\VeriHash.Core.psd1'
if (Test-Path -LiteralPath $coreManifest) {
    Import-Module $coreManifest -Force -Global -ErrorAction Stop
}
```

#### Key v2 module surface the CLI dispatches to:

| Module | Functions | Usage in CLI |
|--------|-----------|-------------|
| `VeriHash.Core` | `Get-VeriHashResult`, `Format-VeriHashReport`, `Read-ClipboardHash`, `Test-VeriHashSidecar`, `Write-VeriHashLog`, `Get-VeriHashPlatform` | Platform detect, logging, single-file hash formatting |
| `VeriHash.HotPath` | `Invoke-VeriHashHotPath`, `Invoke-VeriHashBatch`, `Get-VeriHashSignature` | Hash mode: single-file hot-path, multi-file batch |
| `VeriHash.Manifest` | `New-VeriHashManifest`, `Test-VeriHashManifest` | Manifest mode: create or verify |
| `VeriHash.Integrations.ps1` (dot-sourced) | `Install-WindowsSendTo`, `Install-LinuxContextMenu`, `Install-KDEContextMenu`, `Get-DesktopEnvironment` | -InstallSendTo / -InstallKDE dispatch |

#### Manifest mode dispatch logic (from D-02):
```
# Extension auto-detect within -Manifest mode:
# .sha256/.sha512/.md5 → Test-VeriHashManifest (verify)
# anything else         → New-VeriHashManifest (create)
```

---

### `Tests/VeriHash.Cli.Tests.ps1` (new test, dispatch routing + error paths)

**Analog 1:** `Tests/VeriHash.Integrations.Tests.ps1` — Best match for "testing a dot-sourced script's dispatch behavior with mocking"

**BeforeAll/AfterAll import pattern** (lines 1–9):
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    . "$PSScriptRoot/../VeriHash.Integrations.ps1"
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}
```

**Function availability test pattern** (lines 11–17):
```powershell
Describe 'VeriHash.Integrations surface (INTEG-01)' {
    It 'Dot-sourcing makes all integration functions available' {
        Get-Command Install-WindowsSendTo | Should -Not -BeNullOrEmpty
        Get-Command Install-LinuxContextMenu | Should -Not -BeNullOrEmpty
        Get-Command Install-KDEContextMenu | Should -Not -BeNullOrEmpty
        Get-Command Get-DesktopEnvironment | Should -Not -BeNullOrEmpty
    }
}
```

**Negative content test pattern — checking source code for banned patterns** (lines 19–29):
```powershell
    It 'No PSFramework references in VeriHash.Integrations.ps1' {
        $hits = Select-String -Path "$PSScriptRoot/../VeriHash.Integrations.ps1" `
            -Pattern 'PSFramework|Write-PSFMessage|PSFrameworkAvailable' -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }
```

**Script content inspection pattern (lazy loading check)** (lines 67–79):
```powershell
Describe 'Lazy loading (INTEG-01 - integration isolation)' {
    It 'VeriHash.ps1 contains lazy dot-source inside SendTo block' {
        $mainScript = Get-Content "$PSScriptRoot/../VeriHash.ps1" -Raw
        $mainScript | Should -Match 'if \(\$SendTo\)[\s\S]*?VeriHash\.Integrations\.ps1'
    }

    It 'Install functions are NOT defined directly in VeriHash.ps1' {
        $mainScript = Get-Content "$PSScriptRoot/../VeriHash.ps1" -Raw
        $mainScript | Should -Not -Match 'function Install-WindowsSendTo'
    }
}
```

**Analog 2:** `Tests/VeriHash.HotPath.Tests.ps1` — Best match for "testing module exports and result-object shapes"

**Module export surface test** (lines 27–31):
```powershell
    It 'Exports exactly the locked Plan 02 public surface' {
        $expected = @('Get-VeriHashSignature', 'Invoke-VeriHashHotPath', 'Invoke-VeriHashBatch') | Sort-Object
        $actual   = (Get-Command -Module VeriHash.HotPath).Name | Sort-Object
        Compare-Object $actual $expected | Should -BeNullOrEmpty
    }
```

**Banned-pattern test** (lines 45–51):
```powershell
    It 'No redundant $IsWindows / $RunningOnWindows redefinitions in VeriHash.HotPath/' {
        $hits = Get-ChildItem "$PSScriptRoot/../VeriHash.HotPath" -Recurse -File |
            Select-String -Pattern '\$IsWindows|\$RunningOnWindows' -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }
```

**Analog 3:** `Tests/VeriHash.Manifest.Module.Tests.ps1` — Module manifest validation pattern

**Module manifest pin test** (lines 26–30):
```powershell
    It 'Manifest pins PowerShellVersion 7.0 and CompatiblePSEditions Core' {
        $m = Test-ModuleManifest "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1"
        $m.PowerShellVersion | Should -Be ([version]'7.0')
        $m.CompatiblePSEditions | Should -Contain 'Core'
    }
```

**No Write-Host in module test** (lines 37–41):
```powershell
    It 'No Write-Host calls in VeriHash.Manifest/ (D-17)'{
        $hits = Get-ChildItem "$PSScriptRoot/../VeriHash.Manifest" -Recurse -File |
            Select-String -Pattern 'Write-Host' -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }
```

#### CLI test strategy guidance (from D-13, D-14):
- Mock underlying module functions (Invoke-VeriHashHotPath, Invoke-VeriHashBatch, New-VeriHashManifest, Test-VeriHashManifest) — don't re-test internal logic
- Focus: correct param → function mapping, error handling for invalid input, help banner display
- `Test-VeriHashInteractive` (or similar) extracted as a testable function for pause detection (D-14)
- Test that `-Manifest` + `.sha256` file → calls `Test-VeriHashManifest`
- Test that `-Manifest` + regular file → calls `New-VeriHashManifest`
- Test that no-args interactive case shows help banner (D-03)

---

### `README.md` (complete rewrite for v2)

**Analog:** Current `README.md` — structural format only (lines 1–50)

**Badge pattern** (lines 7–10):
```markdown
[![Version](https://img.shields.io/badge/version-1.3.0-blue.svg)](https://github.com/arcticpinecone/pwsh7-VeriHash/releases)
[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE.md)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)](https://github.com/arcticpinecone/pwsh7-VeriHash)
```

**Logo pattern** (line 3):
```markdown
![VeriHash Logo](https://github.com/arcticpinecone/pwsh7-VeriHash/blob/main/Icons/VeriHash_256.webp?raw=true)
```

**Section headings pattern** — use emoji-prefixed headers:
```markdown
## 📋 Table of Contents
## 🚀 Features
## ⚡ Speed Benchmarks
```

**v2 README structure** (from D-09):
1. Features
2. Requirements
3. Installation
4. Usage (hash/verify/manifest)
5. OS Integration (SendTo/KDE)
6. Module Architecture (VeriHash.Core + HotPath + Manifest + thin CLI)
7. Speed Benchmarks
8. "Why PowerShell 7?"
9. PowerShell Profile Integration
10. Privacy
11. Contributing
12. Running Tests
13. License

**D-12:** Version badge shows `v2.0` with short tagline — link to CHANGELOG, no inline release notes in header.

---

### `CHANGELOG.md` (v2.0 entry)

**Analog:** Current `CHANGELOG.md` (lines 1–60)

**Header pattern** (lines 1–8):
```markdown
# VeriHash Changelog

## Version History

- Unreleased changes are shown first: [Unreleased]
- Current stable release: [v1.3.0]
- Version Release History contains older release notes.
```

**Entry format pattern** (lines 32–59):
```markdown
### [v1.3.0] (Current)

Version: 1.3.0 - 2025-12-27
> Linux Desktop Integration & Cross-Platform Enhancements

**NEW FEATURES:**

- 🐧 **Linux context menu integration**: Right-click files in Dolphin ...

**IMPROVEMENTS:**

- ⚡ **Hash processing speed display**: Now shows real-time throughput ...
```

**v2.0 CHANGELOG structure** (from D-10):
- `### [v2.0.0] (Current)` — frame as "Modular Rewrite"
- Key new capabilities section
- `⚠️ Breaking Changes` section (dropped params, removed features)
- All v1 entries under collapsed `<details><summary>Version 1.x History</summary>` section

---

## Shared Patterns

### Script Preamble
**Source:** `CONVENTIONS.md` + `VeriHash.ps1` lines 1–98 + `Build.ps1` lines 39–40
**Apply to:** `VeriHash.ps1` (rewrite)
```powershell
#!/usr/bin/env pwsh
<#
.SYNOPSIS ...
.DESCRIPTION ...
.PARAMETER ...
.EXAMPLE ...
#>
param(...)
$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
```

### Module Import Convention
**Source:** `VeriHash.ps1` line 98, `VeriHash.HotPath.psm1` lines 6–9, `VeriHash.Integrations.ps1` lines 15–17
**Apply to:** `VeriHash.ps1` (rewrite) — importing Core, HotPath, Manifest modules
```powershell
# Eager import of required modules
Import-Module "$PSScriptRoot\VeriHash.Core\VeriHash.Core.psd1" -Force
Import-Module "$PSScriptRoot\VeriHash.HotPath\VeriHash.HotPath.psd1" -Force
Import-Module "$PSScriptRoot\VeriHash.Manifest\VeriHash.Manifest.psd1" -Force

# Lazy import of Integrations (only when -InstallSendTo or -InstallKDE is used)
. "$PSScriptRoot\VeriHash.Integrations.ps1"
```

### Error Handling — Top-level CLI
**Source:** `VeriHash.ps1` lines 895–897 + `CONVENTIONS.md` error handling section
**Apply to:** `VeriHash.ps1` (rewrite)
```powershell
# Top-level try/catch wrapping main dispatch
try {
    # ... dispatch logic ...
} catch {
    Write-Error "An error occurred: $_"
}
```

### Pester Test Structure
**Source:** `Tests/VeriHash.Integrations.Tests.ps1` (full file), `Tests/VeriHash.HotPath.Tests.ps1` (full file)
**Apply to:** `Tests/VeriHash.Cli.Tests.ps1`
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    # additional module imports as needed
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'FeatureName (REQ-ID)' {
    It 'Test description' {
        # Arrange / Act / Assert
    }
}
```

### Console Output Color Conventions
**Source:** `CONVENTIONS.md` console output section + `VeriHash.ps1` lines 134–162
**Apply to:** `VeriHash.ps1` (help banner, error messages)

| Color | Usage |
|-------|-------|
| `Green` | Success, title line |
| `Cyan` | Headings, info, examples |
| `Yellow` | Warnings, parameter descriptions, in-progress |
| `Red` | Errors, failures |
| `White` | Section headers, steps |
| `DarkGray` | Separators, notes |

### Comment-Based Help
**Source:** `CONVENTIONS.md` lines 83–116 + `Invoke-VeriHashHotPath.ps1` lines 2–21
**Apply to:** `VeriHash.ps1` (script-level help block), `Test-VeriHashInteractive` function
```powershell
function Test-VeriHashInteractive {
    <#
    .SYNOPSIS
        Determines whether VeriHash should pause at exit.
    .DESCRIPTION
        Returns $true if the session is non-interactive (Explorer/SendTo launch)
        and the user hasn't specified -NoPause.
    .OUTPUTS
        Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    # ... detection heuristic (agent's discretion per D-04) ...
}
```

### Platform Detection
**Source:** `VeriHash.Core/Public/Get-VeriHashPlatform.ps1` (v2 canonical check)
**Apply to:** `VeriHash.ps1` (rewrite) — use `Get-VeriHashPlatform` from Core, NOT raw $PSVersionTable
```powershell
# v2 pattern: call Core's function, don't redefine platform booleans
if ((Get-VeriHashPlatform) -eq 'Windows') { ... }
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `README.md` (content) | docs | N/A | Structural format matches v1 README; however, the v2 content (module architecture docs, manifest usage examples) has no existing analog — content must be authored from scratch using D-09 section list |

---

## Metadata

**Analog search scope:** `VeriHash.ps1`, `VeriHash.Core/`, `VeriHash.HotPath/`, `VeriHash.Manifest/`, `VeriHash.Integrations.ps1`, `Tests/`, `Build.ps1`, `.planning/codebase/CONVENTIONS.md`, `.planning/codebase/ARCHITECTURE.md`
**Files scanned:** 28
**Pattern extraction date:** 2025-07-24
