# Phase 1: Privacy & Logging Compliance - Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 5 (modified)
**Analogs found:** 5 / 5

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `VeriHash.LogUtils.ps1` | utility | transform | `VeriHash.LogUtils.ps1` (self — `ConvertFrom-SanitizedPath` at lines 44–82) | exact |
| `VeriHash.Config.ps1` | config | CRUD | `VeriHash.ps1` lines 1059–1069 (correct sanitized logging pattern) | role-match |
| `VeriHash.ps1` | controller | request-response | `VeriHash.ps1` lines 1059–1069 (correct truncation) + lines 99–103 (dot-source block) | exact (self) |
| `Verihash Logging Concepting.md` | documentation | N/A | `Verihash Logging Concepting.md` (self — update in-place) | exact (self) |
| `Tests/VeriHash.Config.Tests.ps1` | test | request-response | `Tests/VeriHash.LogUtils.Tests.ps1` lines 1–13 (BeforeAll dot-source pattern) | exact |

## Pattern Assignments

### `VeriHash.LogUtils.ps1` — Receive `ConvertTo-SanitizedPath` (utility, transform)

**Analog:** `VeriHash.LogUtils.ps1` itself — `ConvertFrom-SanitizedPath` at lines 44–82

The relocated `ConvertTo-SanitizedPath` must mirror the structure and conventions of its inverse function `ConvertFrom-SanitizedPath`, which already lives in this file.

**Function signature pattern** (lines 44–70 — `ConvertFrom-SanitizedPath`):
```powershell
function ConvertFrom-SanitizedPath {
    <#
    .SYNOPSIS
        Expands sanitized paths back to full paths for local debugging.
    .DESCRIPTION
        VeriHash logs sanitize paths for privacy (GDPR Article 5(1)(c)).
        This function expands %USERPROFILE% or ~ back to the current user's
        home directory for local debugging purposes.

        Note: This only works on the same machine where logs were created.
    .PARAMETER Path
        The sanitized path to expand.
    .OUTPUTS
        String - The expanded path.
    .EXAMPLE
        ConvertFrom-SanitizedPath -Path '%USERPROFILE%\Downloads\file.exe'
        # Returns: C:\Users\YourName\Downloads\file.exe
    .EXAMPLE
        '~/Downloads/file.tar.gz' | ConvertFrom-SanitizedPath
        # Returns: /home/yourname/Downloads/file.tar.gz
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(ValueFromPipeline)]
        [string]$Path
    )
```

**Core pattern — local platform detection** (lines 71–82):
```powershell
    process {
        if ([string]::IsNullOrEmpty($Path)) { return $Path }

        $RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT'

        if ($RunningOnWindows) {
            $Path -replace '%USERPROFILE%', $env:USERPROFILE
        } else {
            $Path -replace '^~', $HOME
        }
    }
```

**CRITICAL:** The existing `ConvertFrom-SanitizedPath` uses a **local** `$RunningOnWindows` variable (line 74), NOT `$script:RunningOnWindows`. The relocated `ConvertTo-SanitizedPath` must follow this same convention. However, per RESEARCH.md Open Question #1, the local detection must include the `$null -eq $PSVersionTable.Platform` check (for Windows PowerShell compat), making it:
```powershell
$RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform
```
This matches `VeriHash.Config.ps1` line 23 and `copilot-instructions.md` line 177.

**Placement:** After `Get-VeriHashLogPath` (ends line 42), before `ConvertFrom-SanitizedPath` (starts line 44). This groups the sanitization pair together with `ConvertTo-` before `ConvertFrom-`.

**Source of function to move** — current `ConvertTo-SanitizedPath` in `VeriHash.ps1` (lines 108–133):
```powershell
function ConvertTo-SanitizedPath {
    <#
    .SYNOPSIS
        Replaces user profile paths with platform-appropriate placeholders.
    .DESCRIPTION
        Implements data minimization by removing personally identifiable
        information from file paths before logging.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(ValueFromPipeline)]
        [string]$Path
    )
    process {
        if ([string]::IsNullOrEmpty($Path)) { return $Path }

        if ($RunningOnWindows) {
            # Replace C:\Users\username with %USERPROFILE%
            $Path -replace [regex]::Escape($env:USERPROFILE), '%USERPROFILE%'
        } else {
            # Replace /home/username or /Users/username with ~
            $Path -replace [regex]::Escape($HOME), '~'
        }
    }
}
```
**Note:** The current version references bare `$RunningOnWindows` (line 125 — no `$script:` prefix, no local assignment). After relocation, it MUST use a local variable like `ConvertFrom-SanitizedPath` does.

---

### `VeriHash.Config.ps1` — Pipe 11 path values through `ConvertTo-SanitizedPath` (config, CRUD)

**Analog:** `VeriHash.ps1` line 840 — existing correct path sanitization in a `Write-PSFMessage -Data` block

**Correct path sanitization in -Data block** (`VeriHash.ps1` lines 837–846):
```powershell
    if ($script:PSFrameworkAvailable) {
        $throughputMBs = if ($hashDuration.TotalSeconds -gt 0) { [Math]::Round($fileSize / 1MB / $hashDuration.TotalSeconds, 2) } else { 0 }
        Write-PSFMessage -Level Verbose -Message "Hash computed: $hashValue" -Tag 'Hash', 'Result' -Data @{
            Path = $PathToFile | ConvertTo-SanitizedPath
            Algorithm = $Algorithm
            Hash = $hashValue
            DurationMs = [Math]::Round($hashDuration.TotalMilliseconds, 2)
            ThroughputMBs = $throughputMBs
        }
    }
```
Key line: `Path = $PathToFile | ConvertTo-SanitizedPath` — this is the pipe-to-sanitize pattern.

**Before/After pattern for each of the 11 sites** — example from `VeriHash.Config.ps1` lines 159–164:

BEFORE:
```powershell
    if ($script:PSFrameworkAvailable) {
        Write-PSFMessage -Level Debug -Message "Loading VeriHash configuration" -Tag 'Config', 'Entry' -Data @{
            ConfigDirectory = $configDir
            ConfigFile = $configFile
        }
    }
```

AFTER:
```powershell
    if ($script:PSFrameworkAvailable) {
        Write-PSFMessage -Level Debug -Message "Loading VeriHash configuration" -Tag 'Config', 'Entry' -Data @{
            ConfigDirectory = $configDir | ConvertTo-SanitizedPath
            ConfigFile = $configFile | ConvertTo-SanitizedPath
        }
    }
```

**All 11 violation sites** (from RESEARCH.md inventory):

| Line | Field(s) | Function |
|------|----------|----------|
| 161 | `ConfigDirectory` | `Get-VeriHashConfig` |
| 162 | `ConfigFile` | `Get-VeriHashConfig` |
| 215 | `ConfigFile` | `Get-VeriHashConfig` |
| 228 | `ConfigFile` | `Get-VeriHashConfig` |
| 321 | `ConfigDirectory` | `Set-VeriHashConfig` |
| 322 | `ConfigFile` | `Set-VeriHashConfig` |
| 331 | `ConfigDirectory` | `Set-VeriHashConfig` |
| 348 | `ConfigFile` | `Set-VeriHashConfig` |
| 394 | `ConfigDirectory` | `Initialize-VeriHashConfig` |
| 404 | `ConfigDirectory` | `Initialize-VeriHashConfig` |
| 423 | `ConfigFile` | `Initialize-VeriHashConfig` |

**PSFramework bootstrap removal** — remove line 28 from `VeriHash.Config.ps1`:
```powershell
# REMOVE this line (line 28):
$script:PSFrameworkAvailable = $null -ne (Get-Module -ListAvailable -Name PSFramework)
```
This is the duplicate; the authoritative check moves to VeriHash.ps1 before dot-sources.

---

### `VeriHash.ps1` — Hash truncation fix, dot-source reorder, bootstrap move, function removal (controller, request-response)

**Analog for hash truncation:** `VeriHash.ps1` lines 1060–1069 — existing correct truncation pattern

**Correct hash truncation pattern** (lines 1060–1063):
```powershell
    if ($script:PSFrameworkAvailable) {
        Write-PSFMessage -Level Debug -Message "Invoke-HashFile called" -Tag 'HashFile', 'Entry' -Data @{
            FilePath = $FilePath | ConvertTo-SanitizedPath
            InputHash = if ($InputHash) { $InputHash.Substring(0, [Math]::Min(16, $InputHash.Length)) + '...' } else { $null }
```
Key line: `$InputHash.Substring(0, [Math]::Min(16, $InputHash.Length)) + '...'`

**Fix at line 839** — BEFORE:
```powershell
        Write-PSFMessage -Level Verbose -Message "Hash computed: $hashValue" -Tag 'Hash', 'Result' -Data @{
            Path = $PathToFile | ConvertTo-SanitizedPath
            Algorithm = $Algorithm
            Hash = $hashValue
```

AFTER (apply truncation to BOTH the message string AND the -Data Hash field):
```powershell
        $truncatedHash = $hashValue.Substring(0, [Math]::Min(16, $hashValue.Length)) + '...'
        Write-PSFMessage -Level Verbose -Message "Hash computed: $truncatedHash" -Tag 'Hash', 'Result' -Data @{
            Path = $PathToFile | ConvertTo-SanitizedPath
            Algorithm = $Algorithm
            Hash = $truncatedHash
```

**Analog for dot-source block:** `VeriHash.ps1` lines 99–103 (current)

Current dot-source order (lines 99–103):
```powershell
#region Module Imports
# Import configuration and logging utility modules
. "$PSScriptRoot\VeriHash.Config.ps1"
. "$PSScriptRoot\VeriHash.LogUtils.ps1"
#endregion Module Imports
```

New order:
```powershell
#region Module Imports
# Import configuration and logging utility modules
. "$PSScriptRoot\VeriHash.LogUtils.ps1"
. "$PSScriptRoot\VeriHash.Config.ps1"
#endregion Module Imports
```

**PSFramework bootstrap relocation** — move from line 155 to BEFORE dot-sources

Current location (line 155):
```powershell
# Check if PSFramework is available
$script:PSFrameworkAvailable = $null -ne (Get-Module -ListAvailable -Name PSFramework)
```

New location: after platform detection (line 96–97), before the `#region Module Imports` block. This ensures `$script:PSFrameworkAvailable` is set before `VeriHash.Config.ps1` is loaded so all its `if ($script:PSFrameworkAvailable)` guards work.

**Platform detection block** (lines 95–97 — insert bootstrap after this):
```powershell
# Initialize variables early
$RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT'
$RunningOnLinux = $PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Linux'
```

**Function removal:** Remove `ConvertTo-SanitizedPath` from lines 105–134 (`#region Path Sanitization (Data Minimization)` through `#endregion Path Sanitization (Data Minimization)`). This function is being relocated to `VeriHash.LogUtils.ps1`.

---

### `Verihash Logging Concepting.md` — Documentation update (documentation, N/A)

**Analog:** Self — update existing content to match actual code behavior

**Fix 1: Example log entry hash** (lines 98–115)

Current example shows truncated hash placeholder `"ABC123..."` (6 chars) which implies incorrect truncation length. The actual code truncates to 16 chars.

Current (line 102):
```json
  "Message": "Hash computed: ABC123...",
```

Replace with realistic 16-char example:
```json
  "Message": "Hash computed: D7A8FBB307D78094...",
```

**Fix 2: Missing `Hash` field in Data block** (lines 108–113)

Current Data example omits the `Hash` field entirely:
```json
  "Data": {
    "Path": "%USERPROFILE%\\Downloads\\file.exe",
    "Algorithm": "SHA256",
    "DurationMs": 42.5,
    "ThroughputMBs": 190.2
  }
```

After fix, it should include the truncated hash to match `Get-And-SaveHash` output:
```json
  "Data": {
    "Path": "%USERPROFILE%\\Downloads\\file.exe",
    "Algorithm": "SHA256",
    "Hash": "D7A8FBB307D78094...",
    "DurationMs": 42.5,
    "ThroughputMBs": 190.2
  }
```

**Fix 3: Mention config path sanitization**

The guide currently describes path sanitization only for hash operations. After PRIV-02, config operations also sanitize paths. Add a note to the "Privacy-First Design" section (around lines 5–9) or the example section.

**Fix 4: FunctionName in example** (line 103)

Current:
```json
  "FunctionName": "Invoke-ComputeHash",
```

The actual function name in code is `Get-And-SaveHash` (line 839 context). Update to match:
```json
  "FunctionName": "Get-And-SaveHash",
```

---

### `Tests/VeriHash.Config.Tests.ps1` — Add LogUtils dot-source (test, request-response)

**Analog:** `Tests/VeriHash.LogUtils.Tests.ps1` lines 1–13

**LogUtils test BeforeAll pattern** (LogUtils.Tests.ps1 lines 1–9):
```powershell
BeforeAll {
    # Import the LogUtils functions
    $script:LogUtilsPath = "$PSScriptRoot\..\VeriHash.LogUtils.ps1"
    . $script:LogUtilsPath

    # Create a temp directory for test outputs
    $script:TestOutputDir = Join-Path $TestDrive "LogUtilsTests"
    New-Item -ItemType Directory -Path $script:TestOutputDir -Force | Out-Null
```

**Current Config test BeforeAll** (Config.Tests.ps1 lines 1–9):
```powershell
BeforeAll {
    # Import the Config functions
    $script:ConfigPath = "$PSScriptRoot\..\VeriHash.Config.ps1"
    . $script:ConfigPath

    # Create a temp directory for test config files
    $script:TestConfigDir = Join-Path $TestDrive "ConfigTests"
    New-Item -ItemType Directory -Path $script:TestConfigDir -Force | Out-Null
}
```

**Required change:** Add LogUtils dot-source BEFORE Config dot-source (mirrors production load order):
```powershell
BeforeAll {
    # Import LogUtils first (Config depends on ConvertTo-SanitizedPath)
    $script:LogUtilsPath = "$PSScriptRoot\..\VeriHash.LogUtils.ps1"
    . $script:LogUtilsPath

    # Import the Config functions
    $script:ConfigPath = "$PSScriptRoot\..\VeriHash.Config.ps1"
    . $script:ConfigPath

    # Create a temp directory for test config files
    $script:TestConfigDir = Join-Path $TestDrive "ConfigTests"
    New-Item -ItemType Directory -Path $script:TestConfigDir -Force | Out-Null
}
```

**Also from VeriHash.Tests.ps1 BeforeAll** (lines 1–7) — the main test `$env:VERIHASH_TEST_MODE = '1'` pattern:
```powershell
BeforeAll {
    # Enable test mode to redirect logs to separate test directory
    $env:VERIHASH_TEST_MODE = '1'

    # Import the function we want to test from VeriHash.ps1
    # We use dot-sourcing to load the script
    . "$PSScriptRoot\..\VeriHash.ps1" -FilePath "dummy" -ErrorAction SilentlyContinue 2>$null
```

**Note:** The Config tests currently do NOT set `$env:VERIHASH_TEST_MODE = '1'`. Per `copilot-instructions.md` line 195: *"All Pester BeforeAll blocks set `$env:VERIHASH_TEST_MODE = '1'`."* This is a pre-existing gap but NOT in scope for Phase 1 (Phase 1 only adds LogUtils dot-source). Mentioning for planner awareness.

---

## Shared Patterns

### PSFramework Guard Pattern
**Source:** Used throughout `VeriHash.ps1` and `VeriHash.Config.ps1`
**Apply to:** All files containing `Write-PSFMessage` calls

```powershell
if ($script:PSFrameworkAvailable) {
    Write-PSFMessage -Level <Level> -Message "<message>" -Tag '<Tag1>', '<Tag2>' -Data @{
        <Key> = <value>
    }
}
```

Every `Write-PSFMessage` MUST be wrapped in this guard. PSFramework is optional (copilot-instructions.md lines 91–96).

### Path Sanitization in -Data Blocks
**Source:** `VeriHash.ps1` line 840
**Apply to:** All `Write-PSFMessage -Data` blocks that include file paths

```powershell
-Data @{
    Path = $somePathVar | ConvertTo-SanitizedPath
    ConfigDirectory = $configDir | ConvertTo-SanitizedPath
    ConfigFile = $configFile | ConvertTo-SanitizedPath
}
```

Pipe pattern: `$variable | ConvertTo-SanitizedPath` (copilot-instructions.md lines 121–124).

### Hash Truncation Before Logging
**Source:** `VeriHash.ps1` line 1063
**Apply to:** Any `Write-PSFMessage` that includes hash values

```powershell
# Inline truncation in -Data block:
InputHash = if ($InputHash) { $InputHash.Substring(0, [Math]::Min(16, $InputHash.Length)) + '...' } else { $null }

# Or pre-compute for use in both message and data:
$truncatedHash = $hashValue.Substring(0, [Math]::Min(16, $hashValue.Length)) + '...'
Write-PSFMessage -Level Verbose -Message "Hash computed: $truncatedHash" -Tag 'Hash', 'Result' -Data @{
    Hash = $truncatedHash
}
```

Always 16 chars + `...`. Use `[Math]::Min(16, $str.Length)` to handle short strings safely (copilot-instructions.md line 125).

### Function Signature Convention
**Source:** `VeriHash.LogUtils.ps1` lines 44–70 (`ConvertFrom-SanitizedPath`)
**Apply to:** The relocated `ConvertTo-SanitizedPath`

```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        One-line description.
    .DESCRIPTION
        Multi-line description with context (GDPR reference, etc.).
    .PARAMETER ParamName
        Parameter description.
    .OUTPUTS
        TypeName - Description.
    .EXAMPLE
        Usage example
        # Returns: expected result
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

Must include `[CmdletBinding()]`, `[OutputType()]`, and full comment-based help (copilot-instructions.md lines 132–149).

### Local Platform Detection in LogUtils
**Source:** `VeriHash.LogUtils.ps1` lines 35, 74
**Apply to:** The relocated `ConvertTo-SanitizedPath` in LogUtils

```powershell
# From Get-VeriHashLogPath (line 35):
$RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT'

# From ConvertFrom-SanitizedPath (line 74):
$RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT'
```

LogUtils functions use local variables, NOT `$script:RunningOnWindows`. But the relocated function needs the `$null -eq $PSVersionTable.Platform` fallback (from Config.ps1 line 23):
```powershell
$RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform
```

### Test BeforeAll Dot-Source Pattern
**Source:** `Tests/VeriHash.LogUtils.Tests.ps1` lines 1–4
**Apply to:** `Tests/VeriHash.Config.Tests.ps1`

```powershell
BeforeAll {
    # Import the <Module> functions
    $script:<Module>Path = "$PSScriptRoot\..\VeriHash.<Module>.ps1"
    . $script:<Module>Path
```

Each test file stores the source path in a `$script:` variable and dot-sources it. When a module depends on another, dot-source the dependency first (mirrors production load order).

---

## No Analog Found

No files in this phase lack analogs. All 5 files are modifications to existing code with established patterns already present in the codebase.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| (none) | — | — | All files have exact or role-match analogs |

## Metadata

**Analog search scope:** Repository root (`VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`, `Tests/`, `.github/copilot-instructions.md`)
**Files scanned:** 8 (3 source files, 4 test files, 1 copilot-instructions, 1 logging guide)
**Pattern extraction date:** 2026-04-18
