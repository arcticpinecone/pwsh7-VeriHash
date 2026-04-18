# VeriHash — Copilot Instructions

VeriHash is a cross-platform PowerShell 7+ tool for computing and verifying file hashes (MD5, SHA256, SHA512). It supports sidecar files (`.sha256`, `.sha512`, `.md5`), clipboard detection, Authenticode signature checking, and OS-level context menu / SendTo integration.

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
Invoke-Pester -Path "Tests/VeriHash.Tests.ps1" -Output Detailed
Invoke-Pester -Path "Tests/VeriHash.Config.Tests.ps1" -Output Detailed
Invoke-Pester -Path "Tests/VeriHash.LogUtils.Tests.ps1" -Output Detailed
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
.\Build.ps1 -Version "1.4.0" -UpdateVersion  # Update version + run tests
```

### Required modules
```powershell
Install-Module Pester -Scope CurrentUser
Install-Module PSScriptAnalyzer -Scope CurrentUser
Install-Module PSFramework -Scope CurrentUser   # Optional: enables structured logging
```

---

## Architecture

### File layout
```
VeriHash.ps1          # Main script — all core logic (large, ~66KB)
VeriHash.Config.ps1   # Configuration module (dot-sourced by VeriHash.ps1)
VeriHash.LogUtils.ps1 # Log analysis utilities (dot-sourced by VeriHash.ps1)
QuickHash.ps1         # Standalone lightweight hash tool (unrelated to main)
Tests/                # Pester 5.x test suite
PSScriptAnalyzerSettings.psd1  # Linter customisation
Build.ps1             # Build/release automation
Test-All.ps1          # Unified test runner
.agents/              # AI agent planning artifacts (plan.md, implementation.md, context/)
```

### Module loading
**All Phase 1+ tests load Core via** `Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force` **in `BeforeAll`.** The v1 dot-source-with-dummy-path hack (`. "$PSScriptRoot\..\VeriHash.ps1" "dummy"`) is retired. Legacy files (`VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`) still exist in Phase 1 — they now `Import-Module VeriHash.Core` themselves so the canonical helpers (`Get-VeriHashPlatform`, etc.) are available everywhere — but Phase 5 (CLEAN-XX) will thin them further.

### Configuration system (`VeriHash.Config.ps1`)
Priority: **env vars > config file > defaults**

| Source | Location |
|--------|----------|
| Config file | Windows: `%APPDATA%\VeriHash\config.json` / Unix: `~/.verihash/config.json` |
| Env vars | `VERIHASH_LOG_LEVEL`, `VERIHASH_LOG_FILE`, `VERIHASH_LOG_CONSOLE`, `VERIHASH_VT_APIKEY`, `VERIHASH_VT_ENABLED` |

Schema:
```json
{
  "logging": { "level": "INFO", "file": true, "console": true },
  "virustotal": { "apiKey": "", "enabled": true, "preferApi": true, "autoOpen": false }
}
```
Log path is **not** stored in config — it is always derived from platform at runtime.

### Logging
See `VeriHash.Core/Public/Write-VeriHashLog.ps1` (plain-text, gated by `-Log` or `$env:VERIHASH_LOG=1`, locked timestamp format `yyyy-MM-ddTHH:mm:ssZ`). **PSFramework was removed in Phase 1** (from `VeriHash.Core/`); legacy files (`VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`) continue to use `Write-PSFMessage` with the `if ($script:PSFrameworkAvailable) { ... }` guard until Phase 4 retires those call-sites.

Tests redirect logging by setting `$env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')` in `BeforeAll`. The legacy `VERIHASH_TEST_MODE=1` switch was retired in Phase 1.

### Privacy / GDPR
Paths logged in legacy files must be sanitized first:
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

### Function entry/exit logging pattern (legacy files only)
Legacy files (`VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`) still use PSFramework with the availability guard:
```powershell
function Invoke-SomeOperation {
    param($FilePath)
    if ($script:PSFrameworkAvailable) {
        Write-PSFMessage -Level Debug -Message "Invoke-SomeOperation called" -Tag 'Entry' -Data @{
            FilePath = $FilePath | ConvertTo-SanitizedPath
        }
    }
    try {
        # ... logic ...
    } catch {
        if ($script:PSFrameworkAvailable) {
            Write-PSFMessage -Level Warning -Message "Operation failed" -Tag 'Error' -ErrorRecord $_
        }
        throw
    }
}
```
**New code in `VeriHash.Core/` must NOT use PSFramework.** Use `Write-VeriHashLog` (plain-text, gated) instead. PSFramework will be removed from the legacy files in Phase 4.

### Platform detection
```powershell
Import-Module .\VeriHash.Core\VeriHash.Core.psd1 -Force
if ((Get-VeriHashPlatform) -eq 'Windows') {
    # Windows-only branch
}
```
Platform detection lives once in `VeriHash.Core/Public/Get-VeriHashPlatform.ps1` (CORE-08). Inline `$RunningOn*` redefinitions were eliminated in Phase 1.

### Desktop environment / context menu
Linux desktop environments are registered in `$script:DesktopEnvironments` (a hashtable). Each entry names a handler function (`Install-KDEContextMenu`, etc.). To add GNOME or XFCE support, add an entry to this hashtable and implement the named handler — no other dispatch code changes needed.

### TDD rule
**Never modify tests to make them pass. Modify the code.** This is a hard rule documented in `AGENTS.md` and `.agents/context/testing.md`.

### Non-interactive test invocations
Phase 1+ tests load Core via `Import-Module`, not by executing the v1 monolith:
```powershell
Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
```
The legacy dot-source-with-dummy-path hack (`. "$PSScriptRoot\..\VeriHash.ps1" -FilePath "dummy" -NoPause -Force`) is retired.

### Test environment isolation
All Pester `BeforeAll` blocks redirect logging by setting `$env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')` and clean it up in `AfterAll`. The legacy `VERIHASH_TEST_MODE=1` switch was retired in Phase 1.

---

## Out of Scope for Phase 1

Full README and CHANGELOG rewrite for v2 conventions is deferred to **Phase 5 (CLEAN-XX)**. This file (`.github/copilot-instructions.md`) is the minimum surface needed for AI-assisted contributions to use v2 idioms; the user-facing docs catch up in Phase 5.

---

## Current Development State

- **Phase 1 (Logging)**: ✅ Complete
- **Phase 2 (Configuration)**: ✅ Complete
- **Phase 3 (VirusTotal integration)**: ⏳ Not started — this is the active next phase
- **Active branch**: `dev`

Phase plan is in `.agents/implementation.md`. Context files for logging, config, testing, and MkDocs docs live in `.agents/context/`.
