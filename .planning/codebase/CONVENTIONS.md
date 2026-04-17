# Coding Conventions

**Analysis Date:** 2026-04-17

## Naming Patterns

**Files:**
- Main scripts: `VeriHash.ps1`, `QuickHash.ps1`, `Profile-VeriHashTiming.ps1`
- Dot-sourced modules: `VeriHash.[Component].ps1` (e.g., `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`)
- Utility/runner scripts: `Test-All.ps1`, `Build.ps1`
- Config data: `PSScriptAnalyzerSettings.psd1`, `VeriHash.Config.ps1`

**Functions:**
- Follow PowerShell Verb-Noun convention: `Get-VeriHashConfig`, `Set-VeriHashConfig`, `ConvertTo-SanitizedPath`, `ConvertFrom-VeriHashLog`
- Approved verbs required: `Get-`, `Set-`, `Test-`, `Install-`, `Initialize-`, `ConvertTo-`, `ConvertFrom-`, `Select-`
- Internal/helper functions omit module prefix when script-local: `Select-File`, `Get-And-SaveHash`
- No cmdlet aliases in source code (PSScriptAnalyzer rule `PSAvoidUsingCmdletAliases`, empty allowlist)

**Variables:**
- Script-scoped shared state uses `$script:` prefix: `$script:RunningOnWindows`, `$script:PSFrameworkAvailable`, `$script:VeriHashConfig`
- Local variables use camelCase: `$configDir`, `$configFile`, `$hashValue`, `$sanitizedPath`
- Constants/lookups use PascalCase hashtables: `$script:DesktopEnvironments`, `$script:ValidLogLevels`, `$script:SignableExtensions`
- Environment variable names: SCREAMING_SNAKE_CASE with `VERIHASH_` prefix: `$env:VERIHASH_TEST_MODE`, `$env:VERIHASH_LOG_LEVEL`

**Types/Objects:**
- Return custom objects via `[pscustomobject]@{ ... }` with PascalCase property names
- Parameter type annotations use full type names: `[string]`, `[hashtable]`, `[switch]`, `[int]`, `[bool]`

## Comment-Based Help (Mandatory for Non-Trivial Functions)

**All public functions in `VeriHash.Config.ps1` and `VeriHash.LogUtils.ps1` include full comment-based help:**

```powershell
function Get-VeriHashConfig {
    <#
    .SYNOPSIS
        One-line summary.

    .DESCRIPTION
        Full description with priority rules, behavior details.

    .PARAMETER ParameterName
        What this parameter does.

    .OUTPUTS
        System.Collections.Hashtable - What is returned.

    .EXAMPLE
        $config = Get-VeriHashConfig
        Write-Host "Log level: $($config.logging.level)"
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigDirectory
    )
    ...
}
```

**Rules:**
- `.SYNOPSIS` — always present, single line
- `.DESCRIPTION` — always present for public functions, multi-line detail
- `.PARAMETER` — one entry per non-obvious parameter
- `.OUTPUTS` — always present with full .NET type name and description
- `.EXAMPLE` — at least one per function

## CmdletBinding and OutputType (Mandatory)

All non-trivial functions declare `[CmdletBinding()]` and `[OutputType()]`:

```powershell
[CmdletBinding()]
[OutputType([string])]
param(...)
```

- Functions that modify state add `SupportsShouldProcess`: `[CmdletBinding(SupportsShouldProcess = $true)]`
- Functions using `-WhatIf` gates writes with `$PSCmdlet.ShouldProcess()`
- Simple helper functions (e.g., `Test-InputHash`, `Get-And-SaveHash`) inside `VeriHash.ps1` use minimal `param()` blocks without full CmdletBinding — these are script-internal, not module functions

## Code Style

**Formatting:**
- No formatter config file detected (no `.prettierrc`, no `EditorConfig`); formatting is manual
- Consistent 4-space indentation throughout
- Opening braces on same line as control structure or function: `function Foo {`, `if (...) {`
- Closing braces on their own line
- Hashtable alignment: properties visually aligned with spaces for readability:
  ```powershell
  @{
      logging    = @{
          level   = 'INFO'
          file    = $true
          console = $true
      }
  }
  ```
- `[pscustomobject]@{}` property names PascalCase, aligned:
  ```powershell
  return [pscustomobject]@{
      Algorithm     = $Algorithm
      Hash          = $hashValue
      Sidecar       = $hashFilePath
      SidecarMatch  = $true
      Duration      = $hashDuration
  }
  ```

**Linting:**
- Tool: PSScriptAnalyzer with `PSScriptAnalyzerSettings.psd1`
- Severity: Error + Warning (Information excluded)
- Excluded rules (justified):
  - `PSAvoidUsingWriteHost` — intentional colored interactive output
  - `PSAvoidUsingBrokenHashAlgorithms` — MD5 retained for legacy sidecar compatibility
- Targeted PowerShell 7.0+ via `PSUseCompatibleSyntax`
- Run via `Test-All.ps1 -SkipTests` or `Test-All.ps1` (combined with Pester)

## Logical Region Grouping

Use `#region` / `#endregion` to structure large scripts:

```powershell
#region Platform Detection
$script:RunningOnWindows = ...
$script:RunningOnLinux   = ...
#endregion Platform Detection

#region PSFramework Logging Initialization
...
#endregion PSFramework Logging Initialization
```

Regions used in `VeriHash.Config.ps1`: `Platform Detection`, `Valid Values`
Regions used in `VeriHash.ps1`: `Module Imports`, `Path Sanitization (Data Minimization)`, `PSFramework Logging Initialization`

## Platform Detection

**Always use script-scoped platform booleans, never inline `$PSVersionTable` checks in logic:**

```powershell
# Defined at module/script scope
$script:RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform
$script:RunningOnLinux   = $PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Linux'
$script:RunningOnMacOS   = $PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Darwin'
```

- `VeriHash.Config.ps1` and `VeriHash.ps1` each define these at their own scope
- `VeriHash.LogUtils.ps1` uses local `$RunningOnWindows` (not script-scoped) — note the inconsistency

## PSFramework Logging Pattern

**All log calls are guarded by availability check. Never call `Write-PSFMessage` unconditionally:**

```powershell
if ($script:PSFrameworkAvailable) {
    Write-PSFMessage -Level Verbose -Message "Computing $Algorithm hash" -Tag 'Hash', 'Compute' -Data @{
        Path      = $sanitizedPath
        Algorithm = $Algorithm
    }
}
```

**Logging conventions:**
- `-Level`: `Debug` (trace detail), `Verbose` (operation progress), `Warning` (recoverable issues), `Error` (failures)
- `-Tag`: Comma-separated categorization — first tag is the domain (`Hash`, `Verify`, `Config`, `Clipboard`, `Install`), second is the lifecycle (`Entry`, `Compute`, `Result`, `Success`, `Error`, `Init`)
- `-Data`: Hashtable of structured context. **All path values must be sanitized first** (see Path Sanitization)
- `-Message`: Human-readable present-tense description of what is happening

## Path Sanitization (Data Minimization — GDPR)

**Never log raw file paths. Always sanitize before logging:**

```powershell
# CORRECT
$sanitizedPath = $PathToFile | ConvertTo-SanitizedPath
Write-PSFMessage -Level Verbose -Message "Computing hash" -Data @{ Path = $sanitizedPath }

# WRONG — never log $PathToFile directly
Write-PSFMessage -Level Verbose -Message "Computing hash" -Data @{ Path = $PathToFile }
```

`ConvertTo-SanitizedPath` replaces `$env:USERPROFILE` (Windows) or `$HOME` (Linux/macOS) with `%USERPROFILE%` / `~`.

Defined in `VeriHash.ps1` lines 108–133. The inverse (`ConvertFrom-SanitizedPath`) is in `VeriHash.LogUtils.ps1`.

## Error Handling

**Strategy:** Explicit try/catch; never silent swallowing without logging.

**Patterns:**

```powershell
# External calls that might fail — catch and warn, continue with defaults
try {
    $fileContent = Get-Content $configFile -Raw | ConvertFrom-Json
    # process content...
}
catch {
    if ($script:PSFrameworkAvailable) {
        Write-PSFMessage -Level Warning -Message "Failed to parse config file, using defaults" `
            -Tag 'Config', 'Error' -ErrorRecord $_
    }
    # falls through to defaults
}
```

```powershell
# Platform capability checks — try, fall back gracefully
try {
    $clipboard = Get-Clipboard -ErrorAction Stop
}
catch {
    Write-Host "Clipboard access not supported on this platform." -ForegroundColor Yellow
    return $null
}
```

```powershell
# System calls that must succeed — ErrorAction Stop + Write-Error
if (-not $pwshPath) {
    Write-Error "PowerShell 7 (pwsh) not found in PATH."
    return
}
```

**`-ErrorAction` usage:**
- `-ErrorAction SilentlyContinue` on `Get-Command` probes, optional lookups, cleanup operations
- `-ErrorAction Stop` when the failure must be caught in a try/catch
- Prefer explicit `-ErrorAction` over `$ErrorActionPreference` changes, except in `Test-All.ps1` which sets `$ErrorActionPreference = 'Stop'` globally

## Output / Console Pattern

**`Write-Host` is the correct output method** for this interactive console tool:
- Use `-ForegroundColor` for all user-facing messages to maintain visual hierarchy
- Color scheme:
  - `Green` — success, positive results
  - `Red` — failures, mismatches
  - `Yellow` — warnings, attention needed, user prompts
  - `Cyan` — informational, headings, progress
  - `Magenta` — highlighted values
  - `DarkGray` — secondary/decorative content
  - `White` — neutral labels

```powershell
Write-Host "Hash matches! ✅" -ForegroundColor Green
Write-Host "Hash does not match! 🚫" -ForegroundColor Red
Write-Warning "Sidecar hash differs from computed hash!"
```

Emoji used extensively for quick visual status: ✅ (match/OK), 🚫 (mismatch/fail), ⚠️ (warning/missing), 📝 (file operations)

## Module Import Pattern

Dot-source companion modules relative to `$PSScriptRoot`:

```powershell
#region Module Imports
. "$PSScriptRoot\VeriHash.Config.ps1"
. "$PSScriptRoot\VeriHash.LogUtils.ps1"
#endregion Module Imports
```

- Dot-sourcing is used (not `Import-Module`) since these are `.ps1` helper files, not modules
- The comment at end of `VeriHash.Config.ps1`: `# Functions are exported by dot-sourcing this file`

## Switch Statement Dispatch

Prefer `switch` over if/elseif chains for algorithm and platform routing:

```powershell
switch ($Algorithm) {
    'MD5'    { $ext = '.md5'     }
    'SHA256' { $ext = '.sha256'  }
    'SHA512' { $ext = '.sha512'  }
    default  { $ext = '.unknown' }
}
```

```powershell
switch ($LogLevel) {
    'Debug'   { Set-PSFConfig -FullName '...' -Value 9 }
    'Verbose' { Set-PSFConfig -FullName '...' -Value 6 }
    default   { Set-PSFConfig -FullName '...' -Value 3 }
}
```

## Configuration Priority Pattern

Configuration follows a strict three-tier priority, documented in comment-based help:

```
Environment variables  (highest)
  > Config file
    > Defaults          (lowest)
```

This pattern is implemented in `Get-VeriHashConfig` in `VeriHash.Config.ps1`.

## Comments

**When to Comment:**
- Above sections using `##` + descriptive label for major logical blocks (e.g., `## Context Menu Integration Functions`)
- Inline where non-obvious behavior occurs: regex formats, legacy compat decisions, GDPR rationale
- GDPR / security rationale documented inline with article references:
  ```powershell
  # Principle: GDPR Article 5(1)(c) - collect only what's necessary
  # Reference: GDPR Article 5(1)(c), OWASP Logging Cheat Sheet, CWE-532
  ```
- PSScriptAnalyzer exclusions in `PSScriptAnalyzerSettings.psd1` include explicit justification comments

**Block separators** use `###...###` (80 chars) for function group boundaries in `VeriHash.ps1`.

---

*Convention analysis: 2026-04-17*
