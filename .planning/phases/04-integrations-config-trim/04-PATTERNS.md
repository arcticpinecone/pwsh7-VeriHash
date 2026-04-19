# Phase 4: Integrations + Config Trim - Pattern Map

**Mapped:** 2025-07-23
**Files analyzed:** 9 (2 new, 7 modified)
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `VeriHash.Integrations.ps1` (NEW) | utility script | request-response (install ops) | `VeriHash.LogUtils.ps1` | exact (dot-sourced utility script with Core import) |
| `Tests/VeriHash.Integrations.Tests.ps1` (NEW) | test | request-response | `Tests/VeriHash.HotPath.Tests.ps1` | exact (module-surface + guard tests) |
| `VeriHash.Config.ps1` (MODIFY) | config service | CRUD (config load/save) | Self (remove VT + PSFramework blocks) | self-edit |
| `Tests/VeriHash.Config.Tests.ps1` (MODIFY) | test | CRUD | Self (remove VT test cases) | self-edit |
| `VeriHash.ps1` (MODIFY) | CLI entry point | request-response | Self (remove functions, add lazy dot-source) | self-edit |
| `VeriHash.LogUtils.ps1` (MODIFY) | utility script | transform | Self (comment edits only) | self-edit |
| `Tests/VeriHash.Tests.ps1` (MODIFY) | test | smoke test | Self (comment edits only) | self-edit |
| `Tests/VeriHash.HotPath.Tests.ps1` (MODIFY) | test | module surface | Self (remove `It` block) | self-edit |
| `Tests/VeriHash.Manifest.Module.Tests.ps1` (MODIFY) | test | module surface | Self (remove `It` block) | self-edit |

## Pattern Assignments

---

### `VeriHash.Integrations.ps1` (NEW — utility script, request-response)

**Analog:** `VeriHash.LogUtils.ps1` (dot-sourced script with Core import at top)

**File header / copyright pattern** (`VeriHash.LogUtils.ps1` lines 1-16):
```powershell
<#
    VeriHash.LogUtils.ps1 - Utilities for working with VeriHash log files

    Copyright (C) 2024-2025 arcticpinecone <arcticpinecone@arcticpinecone.eu>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    DATA MINIMIZATION NOTICE:
    VeriHash logs are designed with privacy in mind (GDPR Article 5(1)(c)).
    - Paths are sanitized: %USERPROFILE% (Windows) or ~ (Linux/macOS)
    - PSFramework adds ComputerName/Username metadata (cannot be disabled)
    - Use ConvertFrom-SanitizedPath to expand paths for local debugging
#>
```
**Note:** Adapt header to describe integrations purpose. Replace NOTICE section with lazy-load notice. Remove PSFramework comment line (line 14).

**Core import pattern** (`VeriHash.LogUtils.ps1` lines 18-21):
```powershell
$verihashCoreManifest = Join-Path (Split-Path -Parent $PSCommandPath) 'VeriHash.Core/VeriHash.Core.psd1'
if (Test-Path -LiteralPath $verihashCoreManifest) {
    Import-Module $verihashCoreManifest -Force -Global
}
```
**Note:** Per D-03, use the explicit check pattern instead:
```powershell
if (-not (Get-Module -Name 'VeriHash.Core')) {
    Import-Module "$PSScriptRoot/VeriHash.Core/VeriHash.Core.psd1"
}
```
No `-Force` — unlike LogUtils/Config which always reload, Integrations is self-contained and doesn't need to override an already-loaded Core.

**Dispatch table pattern** (source: `VeriHash.ps1` lines 211-223):
```powershell
# Desktop environment configuration for Linux context menu integration
$script:DesktopEnvironments = @{
    'KDE' = @{
        Name = 'KDE Plasma'
        FileType = '.desktop'
        UserPath = '~/.local/share/kio/servicemenus/'
        SystemPath = '/usr/share/kio/servicemenus/'
        DetectionVars = @('KDE_FULL_SESSION', 'KDE_SESSION_VERSION')
        DesktopValue = @('KDE', 'plasma')
        Handler = 'Install-KDEContextMenu'
    }
    # Future: GNOME, XFCE, etc. can be added here
}
```
Move as-is.

**Function structure with CmdletBinding** (canonical from `VeriHash.LogUtils.ps1` lines 47-85):
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
Every function in VeriHash.Integrations.ps1 MUST have: `<# .SYNOPSIS .DESCRIPTION .PARAMETER .OUTPUTS .EXAMPLE #>`, `[CmdletBinding()]`, `[OutputType([...])]`.

**Install-WindowsSendTo COM shortcut pattern** (source: `VeriHash.ps1` lines 283-336):
```powershell
function Install-WindowsSendTo {
    <#
    .SYNOPSIS
        Creates a Windows SendTo shortcut for VeriHash.
    .DESCRIPTION
        Installs a shortcut in the Windows SendTo folder, enabling right-click "Send To" functionality.
    #>
    [CmdletBinding()]
    param()

    $sendToPath    = Join-Path $env:AppData "Microsoft\Windows\SendTo"
    $shortcutPath  = Join-Path $sendToPath "VeriHash.lnk"
    $pwshCommand   = "pwsh"
    $scriptFullPath = $PSCommandPath
    $scriptDir     = Split-Path $scriptFullPath -Parent

    # Check execution policy
    $currentExecutionPolicy = Get-ExecutionPolicy
    if ($currentExecutionPolicy -ne 'Unrestricted' -and $currentExecutionPolicy -ne 'Bypass') {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`""
    } else {
        $arguments = "-NoProfile -File `"$scriptFullPath`""
    }

    $iconPath = Join-Path $scriptDir "Icons\VeriHash_256.ico"
    $shell    = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath      = $pwshCommand
    $shortcut.Arguments       = $arguments
    $shortcut.WorkingDirectory = $scriptDir

    if (Test-Path $iconPath) {
        $shortcut.IconLocation = $iconPath
    } else {
        Write-Warning "Icon file not found: $iconPath. Shortcut will use default icon."
    }

    $shortcut.Save()
    Write-Host "Shortcut created at: $shortcutPath" -ForegroundColor Green
}
```
**Key modification:** After extracting, add a SECOND shortcut (`VeriHash - Manifest.lnk`) with `-Manifest` appended to arguments per D-10. Remove all `if ($script:PSFrameworkAvailable) { ... }` blocks (lines 294-296 and 328-333 in original).

**Install-KDEContextMenu .desktop file pattern** (source: `VeriHash.ps1` lines 505-521):
```powershell
$desktopContent = @"
[Desktop Entry]
Type=Service
X-KDE-ServiceTypes=KonqPopupMenu/Plugin
MimeType=application/octet-stream;
Actions=ComputeHash;VerifyHash;

[Desktop Action ComputeHash]
Name=Compute Hash (VeriHash)
Icon=$iconPath
Exec=$execComputeHash

[Desktop Action VerifyHash]
Name=Verify Hash (VeriHash)
Icon=$iconPath
Exec=$execVerifyHash
"@
```
**Key modification:** Add `ManifestHash` to `Actions=` and a new `[Desktop Action ManifestHash]` section per D-11.

**Console output color pattern** (used throughout `VeriHash.ps1` lines 539-555):
```powershell
Write-Host ""
Write-Host "KDE context menu integration installed successfully!" -ForegroundColor Green
Write-Host "Location: $desktopFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "To use:" -ForegroundColor Yellow
Write-Host "  1. Right-click any file in Dolphin" -ForegroundColor Yellow
```
Preserve same color conventions: Green=success, Cyan=paths/headings, Yellow=instructions, Magenta=scope info, DarkGray=notes.

---

### `Tests/VeriHash.Integrations.Tests.ps1` (NEW — test, request-response)

**Analog:** `Tests/VeriHash.HotPath.Tests.ps1` (module surface + guard tests)

**BeforeAll/AfterAll pattern** (`VeriHash.HotPath.Tests.ps1` lines 1-8):
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
}
AfterAll {
    Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}
```
**Adapt:** Since `VeriHash.Integrations.ps1` is dot-sourced (not a module), the BeforeAll should dot-source it:
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    . "$PSScriptRoot/../VeriHash.Integrations.ps1"
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}
```

**Guard test pattern — "No X references in Y"** (`VeriHash.HotPath.Tests.ps1` lines 39-43):
```powershell
It 'No PSFramework references in VeriHash.HotPath/' {
    $hits = Get-ChildItem "$PSScriptRoot/../VeriHash.HotPath" -Recurse -File |
        Select-String -Pattern 'PSFramework|Write-PSFMessage' -ErrorAction SilentlyContinue
    $hits | Should -BeNullOrEmpty
}
```
**Adapt:** For Integrations, verify no PSFramework in the file:
```powershell
It 'No PSFramework references in VeriHash.Integrations.ps1' {
    $hits = Select-String -Path "$PSScriptRoot/../VeriHash.Integrations.ps1" `
        -Pattern 'PSFramework|Write-PSFMessage|PSFrameworkAvailable'
    $hits | Should -BeNullOrEmpty
}
```

**Module surface test pattern** (`VeriHash.HotPath.Tests.ps1` lines 10-31):
```powershell
Describe 'VeriHash.HotPath module manifest + exports (Plan 01 surface)' {
    It 'Imports cleanly' {
        { Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force } | Should -Not -Throw
    }
    It 'Exports exactly the locked Plan 02 public surface' {
        $expected = @('Get-VeriHashSignature', 'Invoke-VeriHashHotPath', 'Invoke-VeriHashBatch') | Sort-Object
        $actual   = (Get-Command -Module VeriHash.HotPath).Name | Sort-Object
        Compare-Object $actual $expected | Should -BeNullOrEmpty
    }
}
```
**Adapt:** For Integrations (dot-sourced), verify functions are available after dot-sourcing:
```powershell
It 'Dot-sourcing makes all integration functions available' {
    Get-Command Install-WindowsSendTo -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    Get-Command Install-LinuxContextMenu -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    Get-Command Install-KDEContextMenu -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    Get-Command Get-DesktopEnvironment -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
}
```

**Lazy-load verification pattern** (from RESEARCH.md, adapted from test conventions in TESTING.md):
```powershell
# Verify hot-path invocation does NOT load integrations code
$output = & "$PSScriptRoot/../VeriHash.ps1" -FilePath $testFile -NoPause -SkipSignatureCheck *>&1
```
This pattern uses the `& <script> *>&1` invocation from TESTING.md.

**Platform-skip pattern** (`Tests/VeriHash.Config.Tests.ps1` lines 36-40):
```powershell
It 'Returns Windows path on Windows' {
    if (-not ($PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform)) {
        Set-ItResult -Skipped -Because "Not running on Windows"
        return
    }
    # ... test body
}
```
Use this for Windows-only SendTo tests and Linux-only KDE tests.

---

### `VeriHash.Config.ps1` (MODIFY — config service, CRUD)

**Self-referencing (lines being removed/changed are documented in the file itself)**

**VirusTotal defaults to remove** (`VeriHash.Config.ps1` lines 85-91):
```powershell
        virustotal = @{
            apiKey    = ''
            enabled   = $false   # VirusTotal integration not yet shipped; enable when implemented
            preferApi = $true
            autoOpen  = $false
        }
```
Delete entire section. Result: `Get-VeriHashDefaultConfig` returns only `@{ logging = @{ ... } }`.

**VT source tracking to remove** (`VeriHash.Config.ps1` lines 151-154):
```powershell
    $source.'virustotal.apiKey' = 'default'
    $source.'virustotal.enabled' = 'default'
    $source.'virustotal.preferApi' = 'default'
    $source.'virustotal.autoOpen' = 'default'
```

**VT file merge to remove** (`VeriHash.Config.ps1` lines 191-209):
```powershell
            # Merge virustotal settings from file
            if ($fileContent.virustotal) {
                if ($null -ne $fileContent.virustotal.apiKey) {
                    $config.virustotal.apiKey = $fileContent.virustotal.apiKey
                    $source.'virustotal.apiKey' = 'file'
                }
                ... (through line 209)
            }
```

**VT env var handling to remove** (`VeriHash.Config.ps1` lines 254-262):
```powershell
    if ($env:VERIHASH_VT_APIKEY) {
        $config.virustotal.apiKey = $env:VERIHASH_VT_APIKEY
        $source.'virustotal.apiKey' = 'env'
    }

    if ($env:VERIHASH_VT_ENABLED) {
        $config.virustotal.enabled = $env:VERIHASH_VT_ENABLED -eq 'true'
        $source.'virustotal.enabled' = 'env'
    }
```

**VT docstring lines to remove** (`VeriHash.Config.ps1` lines 109-110):
```powershell
        - VERIHASH_VT_APIKEY: VirusTotal API key
        - VERIHASH_VT_ENABLED: Enable VirusTotal integration (true/false)
```

**Set-VeriHashConfig VT to remove** (`VeriHash.Config.ps1` line 337):
```powershell
        virustotal = $Config.virustotal
```
After removal, `$configToSave` becomes:
```powershell
    $configToSave = @{
        logging = $Config.logging
    }
```

**PSFramework guard block pattern to remove** (14 sites, example from `VeriHash.Config.ps1` lines 157-162):
```powershell
    if ($script:PSFrameworkAvailable) {
        Write-PSFMessage -Level Debug -Message "Loading VeriHash configuration" -Tag 'Config', 'Entry' -Data @{
            ConfigDirectory = $configDir | ConvertTo-SanitizedPath
            ConfigFile = $configFile | ConvertTo-SanitizedPath
        }
    }
```
Delete entire `if` block. Do NOT replace with anything (D-04).

---

### `Tests/VeriHash.Config.Tests.ps1` (MODIFY — test, CRUD)

**VT env var cleanup to remove** (lines 20-21):
```powershell
    $env:VERIHASH_VT_APIKEY = $null
    $env:VERIHASH_VT_ENABLED = $null
```

**Entire VT test blocks to remove** (example, lines 76-82):
```powershell
        It 'Returns a hashtable with virustotal section' {
            # Act
            $result = Get-VeriHashDefaultConfig

            # Assert
            $result.virustotal | Should -Not -BeNullOrEmpty
        }
```

**VT assertions embedded in non-VT tests to remove** (example, line 127):
```powershell
            $result.virustotal.enabled | Should -Be $false
```

**VT data in test config files to remove** (example, lines 143-148):
```powershell
                virustotal = @{
                    apiKey = 'test-api-key'
                    enabled = $false
                    preferApi = $false
                    autoOpen = $true
                }
```

**BeforeEach env var cleanup to remove** (example, lines 113-114):
```powershell
        $env:VERIHASH_VT_APIKEY = $null
        $env:VERIHASH_VT_ENABLED = $null
```

**Round-trip test VT data to remove** (lines 338-343 and 353-354):
```powershell
                virustotal = @{
                    apiKey = 'roundtrip-key'
                    enabled = $false
                    preferApi = $false
                    autoOpen = $true
                }
```
```powershell
            $loaded.virustotal.apiKey | Should -Be 'roundtrip-key'
            $loaded.virustotal.autoOpen | Should -Be $true
```

---

### `VeriHash.ps1` (MODIFY — CLI entry point, request-response)

**PSFramework variable + region to remove** (`VeriHash.ps1` lines 98-99):
```powershell
# Check if PSFramework is available (single authoritative check — used by all modules)
$script:PSFrameworkAvailable = $null -ne (Get-Module -ListAvailable -Name PSFramework)
```

**LogUtils dot-source to remove** (`VeriHash.ps1` lines 101-105):
```powershell
#region Module Imports
# Import logging utilities first (Config depends on ConvertTo-SanitizedPath)
. "$PSScriptRoot\VeriHash.LogUtils.ps1"
. "$PSScriptRoot\VeriHash.Config.ps1"
#endregion Module Imports
```
After edit: keep `VeriHash.Config.ps1` dot-source, remove `VeriHash.LogUtils.ps1` (per Pitfall 6 — all its consumers were inside PSFramework blocks).

**PSFramework init region to remove** (`VeriHash.ps1` lines 107-187):
```powershell
#region PSFramework Logging Initialization
...
#endregion PSFramework Logging Initialization
```
Delete entire region. Keep the non-PSFramework parts that should survive: `$script:VeriHashConfig = Get-VeriHashConfig` and the LogLevel priority logic lines 108-123 (these read config, not PSFramework-specific). **Wait — D-04 says "delete silently" for PSFramework. The config loading (line 109) and LogLevel logic (112-123) feed INTO PSFramework init. These become dead code when the PSF `if/else` block (125-186) is deleted. Phase 5 rewrites the CLI, so delete the entire region.**

**Install functions to EXTRACT** (`VeriHash.ps1` lines 211-556):
- `$script:DesktopEnvironments` (211-223)
- `Get-DesktopEnvironment` (227-281)
- `Install-WindowsSendTo` (283-336)
- `Install-LinuxContextMenu` (338-384)
- `Install-KDEContextMenu` (386-556)

All move to `VeriHash.Integrations.ps1`.

**SendTo handler to modify** (`VeriHash.ps1` lines 597-616):
```powershell
## Handle context menu integration installation
if ($SendTo) {
    try {
        if ((Get-VeriHashPlatform) -eq 'Windows') {
            Install-WindowsSendTo
        }
        elseif ((Get-VeriHashPlatform) -eq 'Linux') {
            Install-LinuxContextMenu -SystemWide:$SystemWide
        }
        else {
            Write-Warning "Context menu integration is only supported on Windows and Linux."
            Write-Host "Current Platform: $($PSVersionTable.Platform)"
        }
        return
    }
    catch {
        Write-Error "Error installing context menu integration: $_"
        return
    }
}
```
Add `dot-source "$PSScriptRoot\VeriHash.Integrations.ps1"` as the first line inside the `if ($SendTo)` block (Pitfall 4).

---

### `VeriHash.LogUtils.ps1` (MODIFY — utility script, comment edits only)

**PSFramework comment to edit** (`VeriHash.LogUtils.ps1` line 14):
```powershell
    - PSFramework adds ComputerName/Username metadata (cannot be disabled)
```
Reword to remove PSFramework mention.

**PSFramework comments in ConvertFrom-VeriHashLog** (`VeriHash.LogUtils.ps1` lines 218, 220):
```powershell
            # Skip lines that are just commas (PSFramework JSON array format artifact)
```
```powershell
            # Strip trailing comma from JSON lines (PSFramework appends commas for array format)
```
Reword to remove PSFramework mentions (e.g., "legacy JSON format artifact").

---

### `Tests/VeriHash.Tests.ps1` (MODIFY — test, comment edits only)

**PSFramework comment at line 14**:
```powershell
#   Help System, SkipSignatureCheck, Smart Signature Detection, PSFramework Logging)
```
Reword to remove "PSFramework Logging".

**PSFramework comment at line 22**:
```powershell
#     - PSFramework Logging    -> retired in Phase 1; replaced by Write-VeriHashLog
```
Reword to remove the entire line or change to "Logging -> Write-VeriHashLog (Phase 1)".

---

### `Tests/VeriHash.HotPath.Tests.ps1` (MODIFY — test, remove guard test)

**Guard test block to remove** (lines 39-43):
```powershell
    It 'No PSFramework references in VeriHash.HotPath/' {
        $hits = Get-ChildItem "$PSScriptRoot/../VeriHash.HotPath" -Recurse -File |
            Select-String -Pattern 'PSFramework|Write-PSFMessage' -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }
```
Delete entire `It` block. These tests served Phase 1-3 transition and are now redundant (D-05).

---

### `Tests/VeriHash.Manifest.Module.Tests.ps1` (MODIFY — test, remove guard test)

**Guard test block to remove** (lines 37-41):
```powershell
    It 'No PSFramework references in VeriHash.Manifest/' {
        $hits = Get-ChildItem "$PSScriptRoot/../VeriHash.Manifest" -Recurse -File |
            Select-String -Pattern 'PSFramework|Write-PSFMessage' -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }
```
Delete entire `It` block. Same rationale as HotPath (D-05).

---

## Shared Patterns

### Copyright Header
**Source:** `VeriHash.LogUtils.ps1` lines 1-16 / `VeriHash.Config.ps1` lines 1-20
**Apply to:** `VeriHash.Integrations.ps1` (new file)
```powershell
<#
    VeriHash.Integrations.ps1 - OS integration installers (SendTo, KDE context menu)

    Copyright (C) 2024-2025 arcticpinecone <arcticpinecone@arcticpinecone.eu>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Dot-sourced lazily by VeriHash.ps1 when -SendTo is invoked.
    Not loaded during normal hash/verify operations (INTEG-01).
#>
```

### Core Import (for dot-sourced scripts)
**Source:** `VeriHash.LogUtils.ps1` lines 18-21 (existing pattern), D-03 (new pattern)
**Apply to:** `VeriHash.Integrations.ps1` (top of file, after header)

Existing pattern (LogUtils/Config):
```powershell
$verihashCoreManifest = Join-Path (Split-Path -Parent $PSCommandPath) 'VeriHash.Core/VeriHash.Core.psd1'
if (Test-Path -LiteralPath $verihashCoreManifest) {
    Import-Module $verihashCoreManifest -Force -Global
}
```

D-03 pattern (for Integrations — self-contained, no `-Force`):
```powershell
if (-not (Get-Module -Name 'VeriHash.Core')) {
    Import-Module "$PSScriptRoot/VeriHash.Core/VeriHash.Core.psd1"
}
```

### PSFramework Guard Deletion
**Source:** All 34 guard sites across `VeriHash.Config.ps1` (14) and `VeriHash.ps1` (20)
**Apply to:** Both files, plus lines inside functions being extracted to `VeriHash.Integrations.ps1`
**Pattern to delete:**
```powershell
    if ($script:PSFrameworkAvailable) {
        Write-PSFMessage -Level <Level> -Message "<msg>" -Tag '<tags>' -Data @{
            <key> = <value> | ConvertTo-SanitizedPath
        }
    }
```
Delete the entire `if` block including content. Do NOT replace with `Write-Verbose`, `Write-VeriHashLog`, or anything else (D-04). Also delete standalone `ConvertTo-SanitizedPath` assignments that only feed deleted PSFramework blocks (e.g., `VeriHash.ps1` line 1400).

### Pester Test BeforeAll/AfterAll
**Source:** `Tests/VeriHash.Config.Tests.ps1` lines 1-22, `Tests/VeriHash.HotPath.Tests.ps1` lines 1-8
**Apply to:** `Tests/VeriHash.Integrations.Tests.ps1`
**Convention rules:**
- Import dependencies in `BeforeAll` (dot-source for scripts, `Import-Module -Force` for modules)
- Use `$TestDrive` for temp directories (auto-cleaned by Pester)
- Clean ALL env vars set during tests in `AfterAll`
- Use `$script:` prefix for shared test fixtures

### Console Output Colors
**Source:** `VeriHash.ps1` lines 539-555, CONVENTIONS.md
**Apply to:** `VeriHash.Integrations.ps1` (all install functions)
| Color | Semantic Meaning |
|-------|-----------------|
| Green | Success messages |
| Cyan | Paths, headings, informational |
| Yellow | Instructions, in-progress, warnings |
| Magenta | Scope information |
| DarkGray | Notes, secondary info |
| Red | Failures (via Write-Error or Write-Host) |

### Platform Skip in Tests
**Source:** `Tests/VeriHash.Config.Tests.ps1` lines 36-40
**Apply to:** `Tests/VeriHash.Integrations.Tests.ps1` (Windows-only SendTo tests, Linux-only KDE tests)
```powershell
if (-not ($PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform)) {
    Set-ItResult -Skipped -Because "Not running on Windows"
    return
}
```

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| *(none)* | — | — | All files have strong analogs in the existing codebase |

All 9 files either have exact analogs (for new files) or are self-referencing modifications (for existing files). The codebase conventions are well-established and consistent.

## Metadata

**Analog search scope:** Repo root (`*.ps1`), `Tests/` (`*.Tests.ps1`), `VeriHash.Core/`, `VeriHash.HotPath/`, `VeriHash.Manifest/`
**Files scanned:** 28 (all `.ps1` files in repo root + Tests/ + module directories)
**Pattern extraction date:** 2025-07-23
