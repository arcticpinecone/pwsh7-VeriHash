---
phase: 04-integrations-config-trim
reviewed: 2025-07-11T22:45:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - VeriHash.Config.ps1
  - VeriHash.ps1
  - VeriHash.LogUtils.ps1
  - VeriHash.Integrations.ps1
  - Tests/VeriHash.Config.Tests.ps1
  - Tests/VeriHash.Tests.ps1
  - Tests/VeriHash.HotPath.Tests.ps1
  - Tests/VeriHash.Manifest.Module.Tests.ps1
  - Tests/VeriHash.Integrations.Tests.ps1
  - Test-All.ps1
findings:
  critical: 1
  warning: 1
  info: 2
  total: 4
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2025-07-11T22:45:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 4 cleanly removes all VirusTotal config scaffolding and all PSFramework guard blocks (34 guards across multiple files). The extraction of 5 integration functions from VeriHash.ps1 into VeriHash.Integrations.ps1 is structurally sound, and the lazy dot-source pattern (`if ($SendTo) { . "...Integrations.ps1" }`) correctly isolates integration code from normal hash/verify operations.

**Wave 1 (VT/PSF removal):** Complete and clean. No orphaned `$script:PSFrameworkAvailable`, `VERIHASH_VT_*`, or `Write-PSFMessage` references remain in any source file. Config tests were correspondingly updated. LogUtils comment references updated from "PSFramework" to "legacy".

**Wave 2 (Integration extraction):** Contains one critical bug — `$PSCommandPath` in dot-sourced functions resolves to the integrations file rather than the VeriHash.ps1 entry point, producing broken shortcuts. Additionally, the manifest shortcuts reference a `-Manifest` parameter that doesn't exist yet in VeriHash.ps1.

## Critical Issues

### CR-01: `$PSCommandPath` resolves to VeriHash.Integrations.ps1, not VeriHash.ps1

**File:** `VeriHash.Integrations.ps1:101` and `VeriHash.Integrations.ps1:199`
**Issue:** Both `Install-WindowsSendTo` (line 101) and `Install-KDEContextMenu` (line 199) use `$PSCommandPath` to build the shortcut/desktop-file target path. When these functions are dot-sourced from VeriHash.ps1, PowerShell's `$PSCommandPath` automatic variable inside the function resolves to the **defining file** (`VeriHash.Integrations.ps1`), not the calling script (`VeriHash.ps1`).

This was empirically confirmed: a test dot-sourcing `child.ps1` from `parent.ps1` showed `$PSCommandPath` inside the child's function returns `child.ps1`.

**Impact:** All created shortcuts (Windows SendTo `.lnk` files) and KDE `.desktop` entries will launch `VeriHash.Integrations.ps1` directly — which has no `param()` block and no main logic. The shortcuts are completely non-functional.

**Fix:** Replace `$PSCommandPath` with an explicit path to the entry-point script:
```powershell
# In Install-WindowsSendTo (line 101) and Install-KDEContextMenu (line 199):
# Before:
$scriptFullPath = $PSCommandPath

# After:
$scriptFullPath = Join-Path $PSScriptRoot "VeriHash.ps1"
```

This works because `$PSScriptRoot` in the dot-sourced file resolves to `VeriHash.Integrations.ps1`'s directory, which is the same directory as `VeriHash.ps1`.

## Warnings

### WR-01: Manifest shortcuts reference non-existent `-Manifest` parameter

**File:** `VeriHash.Integrations.ps1:133` (Windows), `VeriHash.Integrations.ps1:292-296` (KDE)
**Issue:** The manifest shortcuts pass `-Manifest` as a command-line flag to the target script:
- Windows: `$manifestShortcut.Arguments = "$arguments -Manifest"` (line 133)
- KDE: `$execManifestHash` includes `-Manifest "%f"` (lines 292, 296)

However, `VeriHash.ps1` does not declare a `-Manifest` parameter in its `param()` block (lines 56-93). When the manifest shortcut is invoked, PowerShell will throw: *"A parameter cannot be found that matches parameter name 'Manifest'."*

Note: The `VeriHash.Manifest` module exists separately, but the CLI entry point doesn't wire it up yet.

**Fix:** Either:
1. **Add the parameter now** (if manifest support is ready):
```powershell
# In VeriHash.ps1 param() block:
[Parameter(Mandatory = $false)]
[switch]$Manifest,
```
Plus routing logic in the main script to invoke `New-VeriHashManifest` when `-Manifest` is set.

2. **Defer the shortcuts** until the `-Manifest` parameter is implemented, to avoid shipping broken integration points. Add a `# TODO: enable once -Manifest param lands` comment and skip manifest shortcut creation.

## Info

### IN-01: Stale comment in Config test — LogUtils dependency no longer exists

**File:** `Tests/VeriHash.Config.Tests.ps1:2`
**Issue:** Comment says `# Import LogUtils first (Config depends on ConvertTo-SanitizedPath)` but this dependency was removed when PSFramework guards were stripped. `ConvertTo-SanitizedPath` was only called inside `Write-PSFMessage -Data` blocks, which are now gone. The LogUtils dot-source in the test's `BeforeAll` is harmless but misleading.
**Fix:** Update the comment or remove the unnecessary dot-source:
```powershell
# Before:
# Import LogUtils first (Config depends on ConvertTo-SanitizedPath)
$script:LogUtilsPath = "$PSScriptRoot\..\VeriHash.LogUtils.ps1"
. $script:LogUtilsPath

# After (remove or update):
# LogUtils not required by Config; dot-source retained for convenience only
```

### IN-02: VeriHash.Config.ps1 dot-sourced but unused in VeriHash.ps1

**File:** `VeriHash.ps1:99`
**Issue:** Line 99 dot-sources `VeriHash.Config.ps1`, but no config functions (`Get-VeriHashConfig`, `Set-VeriHashConfig`, `Initialize-VeriHashConfig`) are called anywhere in VeriHash.ps1 after the PSFramework logging removal. The config-loading block (`$script:VeriHashConfig = Get-VeriHashConfig`) and its consumers were removed in this phase. The import is now dead code.
**Fix:** This may be intentional to keep config functions available for interactive/profile use. If so, add a comment. If not, remove the import:
```powershell
# Intentional: keeps config functions available for interactive use / profile sourcing
. "$PSScriptRoot\VeriHash.Config.ps1"
```

---

_Reviewed: 2025-07-11T22:45:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
