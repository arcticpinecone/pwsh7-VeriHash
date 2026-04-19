# VeriHash — Copilot Instructions

VeriHash is a cross-platform PowerShell 7+ tool for computing and verifying file hashes (MD5, SHA256, SHA512). It supports sidecar files (`.sha256`, `.sha512`, `.md5`), clipboard detection, Authenticode signature checking, sha256sum-compatible manifests, and OS-level context menu / SendTo integration.

---

## Build, Test, and Lint

### Run all checks (tests + linter + profiler)
```powershell
.\Test-All.ps1
```

### Run only Pester tests
```powershell
.\Test-All.ps1 -SkipAnalyzer -SkipProfiler
# or directly:
Invoke-Pester -Path "Tests/" -Output Detailed
```

### Run a single test file
```powershell
Invoke-Pester -Path "Tests/VeriHash.Core.Tests.ps1" -Output Detailed
Invoke-Pester -Path "Tests/VeriHash.HotPath.Tests.ps1" -Output Detailed
Invoke-Pester -Path "Tests/VeriHash.Manifest.Tests.ps1" -Output Detailed
Invoke-Pester -Path "Tests/VeriHash.Timing.Tests.ps1" -Output Detailed
```

### Lint (PSScriptAnalyzer)
```powershell
Invoke-ScriptAnalyzer -Path VeriHash.ps1 -Settings PSScriptAnalyzerSettings.psd1
```
Custom settings suppress `PSAvoidUsingWriteHost` (intentional interactive output) and `PSAvoidUsingBrokenHashAlgorithms` (MD5 retained for legacy sidecar compatibility).

### Build / release
```powershell
.\Build.ps1                              # Run tests only
.\Build.ps1 -Version "2.0.0" -UpdateVersion  # Update version + run tests
```

### Required modules
```powershell
Install-Module Pester -Scope CurrentUser
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

---

## Architecture

### File layout
```
VeriHash.ps1              # Thin CLI dispatcher (≤200 lines)
VeriHash.Core/            # Core module: hashing, clipboard, sidecar, formatting, logging
VeriHash.HotPath/         # Hot-path module: PE detect, parallel hash+sig, batch loop
VeriHash.Manifest/        # Manifest module: create/verify sha256sum manifests
VeriHash.Integrations.ps1 # OS integration installers (lazy-loaded by CLI)
Tests/                    # Pester 5.x test suite
PSScriptAnalyzerSettings.psd1  # Linter customisation
Build.ps1                 # Build/release automation
Test-All.ps1              # Unified test runner
.planning/                # Planning artifacts (roadmap, phases, context)
```

### Module loading
All tests load modules via `Import-Module` in `BeforeAll`. The thin CLI uses conditional import (`if (-not (Get-Module ...))`) for testability — tests can pre-load modules with mocks before the CLI runs.

```powershell
# Test pattern:
Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force

# CLI pattern (VeriHash.ps1):
foreach ($mod in @('VeriHash.Core', 'VeriHash.HotPath', 'VeriHash.Manifest')) {
    if (-not (Get-Module -Name $mod)) {
        Import-Module (Join-Path $PSScriptRoot "$mod\$mod.psd1") -Force -ErrorAction Stop
    }
}
```

### Logging
See `VeriHash.Core/Public/Write-VeriHashLog.ps1` (plain-text, gated by `-Log` or `$env:VERIHASH_LOG=1`, locked timestamp format `yyyy-MM-ddTHH:mm:ssZ`). PSFramework is not used anywhere in the v2 codebase.

Tests redirect logging by setting `$env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')` in `BeforeAll`.

### Privacy / GDPR
Paths must be sanitized before logging:
```powershell
$filePath | ConvertTo-SanitizedPath   # replaces $env:USERPROFILE with %USERPROFILE%, $HOME with ~
```
Never log full hash values being compared — truncate to first 16 chars. Never log file contents.

---

## Key Conventions

### Function signature pattern
All non-trivial functions use `[CmdletBinding()]`, `[OutputType()]`, and comment-based help:
```powershell
function Get-Something {
    <#
    .SYNOPSIS ...
    .DESCRIPTION ...
    .PARAMETER Foo ...
    .OUTPUTS System.String
    .EXAMPLE ...
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Foo
    )
    ...
}
```

### Platform detection
```powershell
Import-Module .\VeriHash.Core\VeriHash.Core.psd1 -Force
if ((Get-VeriHashPlatform) -eq 'Windows') {
    # Windows-only branch
}
```
Platform detection lives once in `VeriHash.Core/Public/Get-VeriHashPlatform.ps1`.

### Desktop environment / context menu
Linux desktop environments are registered in `$script:DesktopEnvironments` (a hashtable). Each entry names a handler function (`Install-KDEContextMenu`, etc.). To add GNOME or XFCE support, add an entry to this hashtable and implement the named handler — no other dispatch code changes needed.

### TDD rule
**Never modify tests to make them pass. Modify the code.**

### Test environment isolation
All Pester `BeforeAll` blocks redirect logging by setting `$env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')` and clean it up in `AfterAll`.

---

## Current Development State

- **Phase 1 (Logging)**: ✅ Complete
- **Phase 2 (Configuration)**: ✅ Complete
- **Phase 3 (VirusTotal)**: ✅ Complete
- **Phase 4 (Manifest)**: ✅ Complete
- **Phase 5 (Thin CLI + Cleanup)**: ⏳ In progress
- **Active branch**: `dev`

Planning artifacts live in `.planning/`.
