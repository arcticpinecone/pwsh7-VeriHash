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
`VeriHash.ps1` dot-sources its modules at startup:
```powershell
. "$PSScriptRoot\VeriHash.Config.ps1"
. "$PSScriptRoot\VeriHash.LogUtils.ps1"
```
There is no module manifest (`.psd1`) — scripts are run directly, not installed as a module.

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

### Logging (`PSFramework`)
Logging is optional; PSFramework may not be installed. Every call to `Write-PSFMessage` must be guarded:
```powershell
if ($script:PSFrameworkAvailable) {
    Write-PSFMessage -Level Verbose -Message "..." -Tag 'Hash', 'Result' -Data @{ ... }
}
```

Log files: JSONL (JSON Lines) format, daily rotation.
- Windows: `%APPDATA%\VeriHash\logs\verihash-YYYY-MM-DD.jsonl`
- Unix: `~/.verihash/logs/verihash-YYYY-MM-DD.jsonl`

When `VERIHASH_TEST_MODE=1`, logs go to `logs/test/` to avoid polluting production logs.

**Standard tags** (use these for consistency):

| Tag | Use For |
|-----|---------|
| `Hash` | Hash computation |
| `Verify` | Verification operations |
| `Compute` | Computing a hash |
| `Result` | Operation result |
| `Entry` | Function entry |
| `Success` | Successful operation |
| `Error` | Error condition |
| `Install` | Installation operations |
| `Windows` / `Linux` / `KDE` | Platform-specific |
| `Clipboard` | Clipboard operations |
| `Config` | Configuration loading |

### Privacy / GDPR
Paths logged via PSFramework must be sanitized first:
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

### Function entry/exit logging pattern
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
        if ($script:PSFrameworkAvailable) {
            Write-PSFMessage -Level Verbose -Message "Operation completed" -Tag 'Success'
        }
    } catch {
        if ($script:PSFrameworkAvailable) {
            Write-PSFMessage -Level Warning -Message "Operation failed" -Tag 'Error' -ErrorRecord $_
        }
        throw
    }
}
```

### Platform detection
```powershell
$script:RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform
$script:RunningOnLinux   = $PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Linux'
$script:RunningOnMacOS   = $PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Darwin'
```

### Desktop environment / context menu
Linux desktop environments are registered in `$script:DesktopEnvironments` (a hashtable). Each entry names a handler function (`Install-KDEContextMenu`, etc.). To add GNOME or XFCE support, add an entry to this hashtable and implement the named handler — no other dispatch code changes needed.

### TDD rule
**Never modify tests to make them pass. Modify the code.** This is a hard rule documented in `AGENTS.md` and `.agents/context/testing.md`.

### Non-interactive test invocations
When calling `VeriHash.ps1` inside Pester tests, always pass `-NoPause -Force` to suppress interactive prompts:
```powershell
. "$PSScriptRoot\..\VeriHash.ps1" -FilePath "dummy" -NoPause -Force -ErrorAction SilentlyContinue 2>$null
```

### Test environment isolation
All Pester `BeforeAll` blocks set `$env:VERIHASH_TEST_MODE = '1'` and clean it up in `AfterAll`. Do not skip this — it prevents test runs from polluting production logs.

---

## Current Development State

- **Phase 1 (Logging)**: ✅ Complete
- **Phase 2 (Configuration)**: ✅ Complete
- **Phase 3 (VirusTotal integration)**: ⏳ Not started — this is the active next phase
- **Active branch**: `dev`

Phase plan is in `.agents/implementation.md`. Context files for logging, config, testing, and MkDocs docs live in `.agents/context/`.
