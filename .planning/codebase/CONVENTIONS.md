# Coding Conventions

**Analysis Date:** 2026-04-18

VeriHash is a PowerShell 7+ cross-platform script (not a module). Conventions are enforced through PSScriptAnalyzer, Pester tests, and patterns documented in `.github\copilot-instructions.md`.

## Naming Patterns

**Files:**
- `PascalCase.ps1` for scripts: `VeriHash.ps1`, `QuickHash.ps1`, `Build.ps1`, `Test-All.ps1`
- `PascalCase.Namespace.ps1` for dot-sourced modules: `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`
- Test files mirror source: `VeriHash.Tests.ps1`, `VeriHash.Config.Tests.ps1`, `VeriHash.LogUtils.Tests.ps1`, `VeriHash.Timing.Tests.ps1` under `Tests\`
- Linter config is a data file: `PSScriptAnalyzerSettings.psd1`

**Functions:**
- Strict `Verb-Noun` pattern using approved PowerShell verbs:
  - `Get-VeriHashConfig`, `Get-VeriHashLogPath`, `Get-ClipboardHash`, `Get-DesktopEnvironment`
  - `Test-InputHash`, `Test-HashSidecar`
  - `Invoke-HashFile`
  - `Install-WindowsSendTo`, `Install-LinuxContextMenu`, `Install-KDEContextMenu`
  - `ConvertTo-SanitizedPath`, `ConvertFrom-VeriHashLog`
  - `Select-File`
- Noun prefix `VeriHash` is used for module-public helpers (`Get-VeriHashConfig`, `Get-VeriHashLogPath`).

**Variables:**
- `camelCase` for local variables: `$testsPassed`, `$scriptRoot`, `$analysisResults`, `$hashValue`
- `$script:PascalCase` for module/script-scope state shared across dot-sourced files:
  - `$script:PSFrameworkAvailable` (single authoritative PSFramework detection)
  - `$script:VeriHashConfig`
  - `$script:RunningOnWindows`, `$script:RunningOnLinux`, `$script:RunningOnMacOS`
  - `$script:DesktopEnvironments` (hashtable dispatch table)
- Ad-hoc script-root locals (not reused across modules) are plain `$PascalCase` or `$camelCase` at the top of `VeriHash.ps1` — e.g. `$RunningOnWindows` initialized on line 96.

**Parameters:**
- `[PascalCase]` per PowerShell idiom: `-FilePath`, `-Algorithm`, `-NoPause`, `-Force`, `-SkipSignatureCheck`, `-CI`, `-UpdateVersion`.
- Switches for boolean flags, never `[bool]` parameters.

**Environment variables:**
- `UPPER_SNAKE_CASE` with `VERIHASH_` prefix: `VERIHASH_LOG_LEVEL`, `VERIHASH_LOG_FILE`, `VERIHASH_LOG_CONSOLE`, `VERIHASH_VT_APIKEY`, `VERIHASH_VT_ENABLED`, `VERIHASH_TEST_MODE`, `VERIHASH_NO_CLEAR`.
- Documented in `.github\copilot-instructions.md` and `VeriHash.Config.ps1`.

**Config file keys:** lowercase (JSON): `logging.level`, `virustotal.apiKey`, etc.

**Types:** `[string]`, `[hashtable]`, `[PSCustomObject]`, `[switch]` — standard PowerShell types.

## Code Style

**Formatting:**
- 4-space indentation, no tabs.
- Opening brace on same line as keyword: `if (...) {`, `function Foo {`.
- `} else {` / `} catch {` on single line.
- Heavy use of ASCII/Unicode banner separators in scripts for section readability (see `Test-All.ps1` lines 50-56, 74-76).
- UTF-8 with optional BOM — several files carry a leading BOM (e.g., `Test-All.ps1`, `VeriHash.ps1`, `VeriHash.Timing.Tests.ps1`).
- `#region` / `#endregion` blocks used for logical sections in `VeriHash.ps1` (see `#region Module Imports` at line 102).

**Linting:**
- Tool: `PSScriptAnalyzer` with settings in `PSScriptAnalyzerSettings.psd1`.
- `Severity = @('Error', 'Warning')` — info-level rules ignored.
- `IncludeDefaultRules = $true`.
- `PSUseCompatibleSyntax` targeted at PowerShell 7.0.
- Suppressed rules (with rationale in the settings file):
  - `PSAvoidUsingWriteHost` — VeriHash is an interactive CLI; colored console output is a core UX feature.
  - `PSAvoidUsingBrokenHashAlgorithms` — MD5 is intentionally retained for legacy `.md5` sidecar compatibility (warned about in tests).
- Run locally: `Invoke-ScriptAnalyzer -Path VeriHash.ps1 -Settings PSScriptAnalyzerSettings.psd1`
- Run via `Test-All.ps1` (iterates `VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`).
- Enforced in CI: `.github\workflows\ci.yml` job `lint` fails on any issue.

**Script preamble:**
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
Every top-level script sets `$ErrorActionPreference = 'Stop'` (see `Test-All.ps1:46`, `Build.ps1:39`).

## Comment-Based Help (Mandatory)

All non-trivial functions carry full help blocks. Canonical signature (from `VeriHash.LogUtils.ps1`, `ConvertTo-SanitizedPath`):

```powershell
function ConvertTo-SanitizedPath {
    <#
    .SYNOPSIS
        Replaces user profile paths with platform-appropriate placeholders.
    .DESCRIPTION
        Implements data minimization by removing personally identifiable
        information from file paths before logging (GDPR Article 5(1)(c)).
    .PARAMETER Path
        The file path to sanitize.
    .OUTPUTS
        String - The sanitized path with user-specific segments replaced.
    .EXAMPLE
        'C:\Users\john\Downloads\file.exe' | ConvertTo-SanitizedPath
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(ValueFromPipeline)]
        [string]$Path
    )
    process { ... }
}
```

**Rules:**
- Every exported/reusable function has `[CmdletBinding()]` and `[OutputType([...])]` attributes.
- `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER <Name>` for each param, `.OUTPUTS`, and at least one `.EXAMPLE`.
- Parameters use `[Parameter(Mandatory = $true/$false)]`, `[ValidateSet(...)]`, and `[Alias(...)]` where appropriate. See `VeriHash.ps1` top-level `param()` block (`-Algorithm` uses `[ValidateSet('MD5','SHA256','SHA512','All')]`; `-Help` has `[Alias("h","?")]`).

## Import Organization

**Dot-sourcing (no module manifest):**
```powershell
#region Module Imports
# Import logging utilities first (Config depends on ConvertTo-SanitizedPath)
. "$PSScriptRoot\VeriHash.LogUtils.ps1"
. "$PSScriptRoot\VeriHash.Config.ps1"
#endregion Module Imports
```
- Order matters — `VeriHash.Config.ps1` depends on `ConvertTo-SanitizedPath` from `VeriHash.LogUtils.ps1`, so LogUtils is sourced first.
- Always use `$PSScriptRoot` for paths (never relative paths or `$PWD`).
- Tests mirror this: `Tests\VeriHash.Config.Tests.ps1` dot-sources LogUtils then Config in `BeforeAll`.

## Platform Detection Idioms

The canonical triple (from copilot instructions and mirrored in `VeriHash.ps1`):

```powershell
$script:RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform
$script:RunningOnLinux   = $PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Linux'
$script:RunningOnMacOS   = $PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Darwin'
```

Note the `-or $null -eq $PSVersionTable.Platform` clause — older Windows PowerShell leaves `Platform` unset. Always include it.

For Authenticode and Windows-only APIs, also guard with the built-in `$IsWindows` automatic variable (see `Profile-VeriHashTiming.ps1:58`).

**Path conventions:**
- Windows config/logs: `%APPDATA%\VeriHash\` (e.g., `Join-Path $env:APPDATA "VeriHash\logs"`).
- Unix config/logs: `~/.verihash/` (e.g., `Join-Path $HOME ".verihash/logs"`).
- Always use `Join-Path` — never string concatenation for paths.

## Script-Level Shared State

Cross-module flags use `$script:` scope so all dot-sourced files see them:
```powershell
# Single authoritative check — used by all modules
$script:PSFrameworkAvailable = $null -ne (Get-Module -ListAvailable -Name PSFramework)
```
Declared once near the top of `VeriHash.ps1` (line 100), consumed everywhere.

## Error Handling

**Canonical pattern (from copilot instructions):**
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

**Rules:**
- `try { ... } catch { Write-PSFMessage -Level Warning ...; throw }` — always log at Warning then re-throw to let the caller decide.
- `-ErrorRecord $_` is attached to the PSFramework call so the full exception is captured in the JSONL log.
- Top-level scripts set `$ErrorActionPreference = 'Stop'` so non-terminating errors become terminating.
- Silent ignore is explicit: `catch { $null = $_ }` (see `Profile-VeriHashTiming.ps1:108-111` for `Clear-Host` in non-interactive contexts).
- Use `-ErrorAction SilentlyContinue` for best-effort cleanup (e.g., `Remove-Item Env:\VERIHASH_TEST_MODE -ErrorAction SilentlyContinue`).
- `Write-Error` + `exit 1` is the pattern for build/test scripts (see `Build.ps1:51-53`).

## Logging (PSFramework, guarded)

**Every** call to `Write-PSFMessage` must be wrapped in the `$script:PSFrameworkAvailable` guard — PSFramework is an optional dependency.

```powershell
if ($script:PSFrameworkAvailable) {
    Write-PSFMessage -Level Verbose -Message "Hash computed" -Tag 'Hash', 'Result' -Data @{
        Path      = $filePath | ConvertTo-SanitizedPath
        Algorithm = $algorithm
        HashShort = $hash.Substring(0, 16)
    }
}
```

**Log levels used:** `Debug`, `Verbose`, `Warning`. Higher levels follow PSFramework conventions.

**Standard tags** (consume these — don't invent new ones; see `.github\copilot-instructions.md` table):

| Tag | Use For |
|-----|---------|
| `Hash` | Hash computation operations |
| `Verify` | Verification operations |
| `Compute` | Computing a hash |
| `Result` | Operation result |
| `Entry` | Function entry |
| `Success` | Successful operation |
| `Error` | Error condition |
| `Install` | Installation operations (context menu, SendTo) |
| `Windows` / `Linux` / `KDE` | Platform-specific operations |
| `Clipboard` | Clipboard operations |
| `Config` | Configuration loading |

**Log files:** JSONL format, daily rotation:
- Windows: `%APPDATA%\VeriHash\logs\verihash-YYYY-MM-DD.jsonl`
- Unix: `~/.verihash/logs/verihash-YYYY-MM-DD.jsonl`
- Test mode (`VERIHASH_TEST_MODE=1`): routed to `logs\test\` subfolder.

## Privacy / GDPR Conventions

`VeriHash.LogUtils.ps1` enforces GDPR Article 5(1)(c) data minimization:

- **Always sanitize paths before logging:**
  ```powershell
  $filePath | ConvertTo-SanitizedPath
  # Windows: C:\Users\john\Downloads\x.exe -> %USERPROFILE%\Downloads\x.exe
  # Unix:    /home/john/x.tar.gz           -> ~/x.tar.gz
  ```
- **Never log full hash values under comparison** — truncate to first 16 chars (`$hash.Substring(0, 16)`).
- **Never log file contents.**
- `ConvertFrom-SanitizedPath` expands paths back for local debugging.

## Console Output

- `Write-Host` is the approved output mechanism for user-facing messages (suppressed rule documented above).
- Use `-ForegroundColor` for semantic coloring: `Cyan` (headings), `Yellow` (in-progress / warnings), `Green` (success), `Red` (failure), `DarkGray` (separators/notes), `Gray` (neutral), `White` (steps).
- Banner boxes use box-drawing characters (`╔ ═ ╗ ║ ╚ ╝`) — see `Test-All.ps1:52-54`.
- Status symbols: `✅`, `❌`, `⚠️`.

## Function Design

**Size:** Functions should be single-purpose. `VeriHash.ps1` holds the larger orchestration functions (`Invoke-HashFile`, `Get-And-SaveHash`, `Test-HashSidecar`); helpers are extracted into `VeriHash.Config.ps1` and `VeriHash.LogUtils.ps1`.

**Parameters:**
- Prefer `[Parameter(Mandatory = $true)]` over positional-only parameters.
- Use `[ValidateSet(...)]` for closed value sets: algorithms, log levels.
- Use `[Alias(...)]` to preserve ergonomic CLI names (`-InputHash` → `-Hash`, `-h`/`-?` → `-Help`).
- Pipeline support where meaningful: `[Parameter(ValueFromPipeline)]` (e.g., `ConvertTo-SanitizedPath`), with a `process { }` block.

**Return values:**
- Functions with `[OutputType([string])]` return a single string (or pipe-sourced string).
- Structured returns use `[PSCustomObject]@{ ... }` (see `Profile-VeriHashTiming.ps1:119-125`).
- Avoid `Write-Output` in interactive functions — use `return`.

## Module Design

- No module manifest (`.psd1`) exists — scripts are dot-sourced and run directly.
- Public helpers in dot-sourced files are implicitly "exported" (all functions are in scope after `.` sourcing).
- Shared state goes through `$script:` scope, which is common across dot-sourced files at the same script root.
- `$script:DesktopEnvironments` is a dispatch hashtable; to add GNOME/XFCE support, add an entry and implement the named `Install-*ContextMenu` handler — no switch statement changes required.

## Dispatch Tables Over Switches

Platform/desktop routing uses hashtable lookup rather than large switch statements:
```powershell
$script:DesktopEnvironments = @{
    'KDE'   = 'Install-KDEContextMenu'
    # 'GNOME' = 'Install-GnomeContextMenu'  # add here, implement handler, done
}
```
This pattern is surfaced in `.github\copilot-instructions.md` and should be preferred for extensible routing.

---

*Convention analysis: 2026-04-18*
