# Phase 4: Integrations + Config Trim - Research

**Researched:** 2026-04-19
**Domain:** PowerShell script extraction, config trimming, dead-code removal
**Confidence:** HIGH

## Summary

Phase 4 has three independent work streams that share no code dependencies: (1) extract integration/install functions from `VeriHash.ps1` into a new lazy-loaded `VeriHash.Integrations.ps1`, adding manifest shortcut variants; (2) remove all VirusTotal config fields, defaults, env-var handling, and tests from `VeriHash.Config.ps1` and `Tests/VeriHash.Config.Tests.ps1`; (3) remove all PSFramework references from every production source file and test file.

The codebase analysis confirms 34 `$script:PSFrameworkAvailable` guard sites (14 in `VeriHash.Config.ps1`, 20 in `VeriHash.ps1`), with additional references in `VeriHash.LogUtils.ps1` comments and test files. VirusTotal references span 31 lines in `VeriHash.Config.Tests.ps1` and ~30 lines in `VeriHash.Config.ps1`. The integration extraction scope is well-bounded: lines 211–556 of `VeriHash.ps1` contain the `$script:DesktopEnvironments` table, `Get-DesktopEnvironment`, `Install-WindowsSendTo`, `Install-LinuxContextMenu`, and `Install-KDEContextMenu`.

**Primary recommendation:** Execute the three work streams in this order: (A) PSFramework removal + VirusTotal removal (independent, can be parallel), then (B) integration extraction (touches many of the same lines in VeriHash.ps1 that PSFramework removal touches, so PSFramework should land first to avoid merge conflicts).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Dot-sourced script (`VeriHash.Integrations.ps1` at repo root), not a full module. Run-once install code doesn't warrant module overhead. Can be promoted to a module later if integrations grow.
- **D-02:** Extract ALL install functions from VeriHash.ps1 — `Install-WindowsSendTo`, `Install-KDEContextMenu`, `Get-DesktopEnvironment`, the `$script:DesktopEnvironments` dispatch table, and helper detection code. VeriHash.ps1 keeps only the flag check + dot-source.
- **D-03:** Explicit Core check/resolve at top of file: `if (-not (Get-Module -Name 'VeriHash.Core')) { Import-Module "$PSScriptRoot/VeriHash.Core/VeriHash.Core.psd1" }`. Self-contained — works whether caller loaded Core or not. No `-Force` (unlike test files that always reload).
- **D-04:** Delete silently — remove all `if ($script:PSFrameworkAvailable) { ... }` blocks, `$script:PSFrameworkAvailable` variable initialization, and any `Import-Module PSFramework` or conditional PSFramework loading. No replacement with `Write-VeriHashLog` or `Write-Verbose`. Phase 5 rewrites VeriHash.ps1 into a thin CLI — most of this code gets deleted/rewritten then anyway.
- **D-05:** Remove guard tests from `VeriHash.HotPath.Tests.ps1` (lines 39-42) and `VeriHash.Manifest.Module.Tests.ps1` (lines 37-40). Update comments in `VeriHash.Tests.ps1` (lines 14, 22). These guard tests served their purpose during the Phase 1-3 transition; with PSFramework gone everywhere, they're redundant — and their removal satisfies the zero-match success criteria.
- **D-06:** Leave `ConvertTo-SanitizedPath` (defined in `VeriHash.LogUtils.ps1`) as dead code. All its call sites are inside PSFramework blocks being deleted. Phase 5 will decide whether to move it to Core or retire it. Do not delete or move it in Phase 4.
- **D-07:** Silent ignore + organic drop for VirusTotal config fields. The config loader only looks for properties it knows about (`logging`). Unknown sections (like `virustotal`) in existing `config.json` files are harmlessly ignored on read. On next save, `Set-VeriHashConfig` writes only known fields — the `virustotal` section silently disappears. No migration tool, no deprecation warning.
- **D-08:** VirusTotal env vars (`VERIHASH_VT_APIKEY`, `VERIHASH_VT_ENABLED`) simply stop being read. If a user has them set, they're harmlessly ignored. No error, no warning.
- **D-09:** Auto-detect create vs verify based on file extension. When a file is sent to the manifest shortcut: `.sha256`, `.sha512`, `.md5` → verify that manifest; anything else → create a manifest. Smart default, no user prompt needed.
- **D-10:** `-Manifest` flag on VeriHash.ps1 — consistent with the "one front door" pattern. The manifest .lnk passes `pwsh -File VeriHash.ps1 -Manifest` and Windows SendTo appends the dropped file. Phase 4 creates the shortcut; Phase 5 adds the `-Manifest` parameter handler to VeriHash.ps1.
- **D-11:** KDE service menu gets a manifest action alongside the existing hash action. Same auto-detect behavior as Windows SendTo.
- **D-12:** Phase 4 creates the shortcuts and KDE entries with the `-Manifest` flag. Phase 5 wires up the handler. Between phases, the manifest shortcut exists but won't function — acceptable since these are sequential development phases, not separate releases.

### Claude's Discretion
None specified — all key decisions were locked.

### Deferred Ideas (OUT OF SCOPE)
- **Full module promotion:** If integrations grow significantly (GNOME, XFCE, macOS Finder, PSGallery install), `VeriHash.Integrations.ps1` can be promoted to a full `VeriHash.Integrations/` module. Current scope doesn't warrant it.
- **ConvertTo-SanitizedPath in Core:** May be useful for `Write-VeriHashLog` path sanitization. Decision deferred to Phase 5 when the logging story is finalized.
- **VT config migration tool:** Not needed — silent ignore + organic drop handles the transition. If VeriHash ever re-adds VT support (future milestone), it would read the fields again anyway.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INTEG-01 | `VeriHash.Integrations.ps1` is dot-sourced lazily, only when an integration command is invoked. Hot path does not load it. | Extraction scope mapped: lines 211-556 of VeriHash.ps1. Lazy-load test pattern documented. |
| INTEG-02 | Windows `-InstallSendTo` installs both `VeriHash.lnk` and `VeriHash - Manifest.lnk` in user's SendTo folder; system-wide requires elevation. | Existing `Install-WindowsSendTo` (lines 283-336) analyzed. Manifest shortcut pattern (D-10) documented. |
| INTEG-03 | Linux KDE service-menu installation preserved from v1 (user-level + `--SystemWide` with root check). | Existing `Install-KDEContextMenu` (lines 386-556) analyzed. KDE `.desktop` format documented for manifest action addition. |
| CFG-01 | All `virustotal.*` fields, defaults, and `VERIHASH_VT_*` env-var handling removed from `VeriHash.Config.ps1`. | Complete line-by-line mapping of 30 VT lines in Config file provided. |
| CFG-02 | All VirusTotal references removed from `Tests/VeriHash.Config.Tests.ps1`. | 31 VT-referencing lines identified across 7 test contexts. |
| CFG-03 | PSFramework no longer referenced anywhere in production source or tests; ~33 guard sites eliminated. | Exact count verified: 34 guard sites (14 Config + 20 Main), plus 6 test file references. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Integration installer (SendTo/KDE) | Dot-sourced script | — | Run-once install code; D-01 locks this as non-module |
| Lazy-loading gate | CLI (VeriHash.ps1) | — | Flag check + dot-source stays in the main entry point |
| Config trimming (VT) | Config script | Config tests | VeriHash.Config.ps1 is the sole config surface |
| PSFramework removal | All legacy files | Tests | Spans VeriHash.ps1, VeriHash.Config.ps1, 4 test files |
| Platform detection | VeriHash.Core module | — | Phase 1 established `Get-VeriHashPlatform` as canonical source |

## Architecture Patterns

### System Architecture Diagram

```
User invokes VeriHash.ps1
     │
     ├── -SendTo / -InstallKDE flag?
     │     YES ──> dot-source VeriHash.Integrations.ps1
     │              │
     │              ├── Get-VeriHashPlatform (from Core)
     │              ├── Windows? ──> Install-WindowsSendTo
     │              │                  ├── Create VeriHash.lnk
     │              │                  └── Create VeriHash - Manifest.lnk
     │              └── Linux?   ──> Install-LinuxContextMenu
     │                                 └── Install-KDEContextMenu
     │                                      ├── ComputeHash action
     │                                      ├── VerifyHash action
     │                                      └── ManifestHash action (NEW)
     │
     └── Normal hash/verify invocation
           │
           ├── VeriHash.Core (always loaded)
           ├── VeriHash.HotPath (loaded for hash ops)
           ├── VeriHash.Manifest (loaded for manifest ops)
           └── VeriHash.Integrations.ps1 is NEVER loaded
```

### Recommended File Structure (after Phase 4)

```
VeriHash.ps1                    # Main script — flag check + dot-source for integrations
VeriHash.Integrations.ps1       # NEW: lazy-loaded install functions
VeriHash.Config.ps1             # Trimmed: no VT, no PSFramework guards
VeriHash.LogUtils.ps1           # Unchanged (ConvertTo-SanitizedPath stays as dead code per D-06)
VeriHash.Core/                  # Unchanged
VeriHash.HotPath/               # Unchanged
VeriHash.Manifest/              # Unchanged
Tests/
├── VeriHash.Integrations.Tests.ps1    # NEW: integration + lazy-load tests
├── VeriHash.Config.Tests.ps1          # Trimmed: no VT tests
├── VeriHash.HotPath.Tests.ps1         # Trimmed: PSFramework guard test removed
├── VeriHash.Manifest.Module.Tests.ps1 # Trimmed: PSFramework guard test removed
└── VeriHash.Tests.ps1                 # Comments updated
```

### Pattern: Lazy Dot-Source Loading

**What:** VeriHash.ps1 conditionally dot-sources `VeriHash.Integrations.ps1` only when an install flag is used.
**When to use:** When code is only needed for rare administrative operations (install/setup), not on every invocation.

```powershell
# In VeriHash.ps1 — replaces the current inline function definitions
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
[VERIFIED: codebase analysis of VeriHash.ps1 lines 597-616]

### Pattern: Self-Contained Core Import (D-03)

```powershell
# Top of VeriHash.Integrations.ps1
if (-not (Get-Module -Name 'VeriHash.Core')) {
    Import-Module "$PSScriptRoot/VeriHash.Core/VeriHash.Core.psd1"
}
```
[VERIFIED: D-03 from CONTEXT.md, consistent with VeriHash.Core.psd1 exports]

### Anti-Patterns to Avoid
- **Importing VeriHash.Integrations.ps1 unconditionally:** This violates INTEG-01 and adds load time to every hash operation. The dot-source MUST be inside the `if ($SendTo)` block.
- **Auto-elevation in installers:** D-02 from CONTEXT.md and INTEG-02 explicitly require no auto-elevation. System-wide install requires the user to manually run with `sudo`/elevated prompt.
- **Replacing PSFramework calls with Write-Verbose/Write-VeriHashLog:** D-04 explicitly says "delete silently — no replacement." Phase 5 handles the logging story.
- **Deleting ConvertTo-SanitizedPath:** D-06 says leave it as dead code. Phase 5 decides its fate.

## PSFramework Removal — Complete Inventory

### Guard Sites in VeriHash.Config.ps1 (14 sites)

| Line | Function | Block Purpose |
|------|----------|---------------|
| 157-162 | Get-VeriHashConfig | Log config loading start |
| 176-178 | Get-VeriHashConfig | Warn invalid log level from file |
| 211-215 | Get-VeriHashConfig | Log successful file load |
| 219-221 | Get-VeriHashConfig | Warn failed config parse |
| 224-228 | Get-VeriHashConfig | Log no config file found |
| 238-240 | Get-VeriHashConfig | Warn invalid env VERIHASH_LOG_LEVEL |
| 265-273 | Get-VeriHashConfig | Log final config loaded |
| 317-321 | Set-VeriHashConfig | Log saving config entry |
| 327-330 | Set-VeriHashConfig | Log created config directory |
| 344-347 | Set-VeriHashConfig | Log config saved |
| 390-394 | Initialize-VeriHashConfig | Log initializing config |
| 400-403 | Initialize-VeriHashConfig | Log created config directory |
| 409-411 | Initialize-VeriHashConfig | Log existing config found |
| 419-422 | Initialize-VeriHashConfig | Log default config created |

[VERIFIED: `Select-String -Pattern '\$script:PSFrameworkAvailable' VeriHash.Config.ps1` returned 14 matches]

### Guard Sites in VeriHash.ps1 (20 sites)

| Line | Function/Region | Block Purpose |
|------|----------------|---------------|
| 99 | Top-level | `$script:PSFrameworkAvailable` variable declaration |
| 107-187 | `#region PSFramework Logging Initialization` | Entire initialization block (Import-Module, Set-PSFLoggingProvider, level config, initial log message) |
| 125-186 | Same region | The `if/else` block spanning PSFramework init |
| 294-296 | Install-WindowsSendTo | Log install attempt |
| 328-333 | Install-WindowsSendTo | Log success |
| 353-357 | Install-LinuxContextMenu | Log install attempt |
| 401-405 | Install-KDEContextMenu | Log install attempt |
| 531-537 | Install-KDEContextMenu | Log success |
| 668-671 | Get-ClipboardHash | Log clipboard check entry |
| 744-745 | Get-ClipboardHash | Log MD5 detected |
| 752-753 | Get-ClipboardHash | Log SHA256 detected |
| 760-761 | Get-ClipboardHash | Log SHA512 detected |
| 768-769 | Get-ClipboardHash | Log no hash found |
| 788-797 | Get-And-SaveHash | Log hash computation start |
| 811-821 | Get-And-SaveHash | Log hash result |
| 1035-1044 | Invoke-HashFile | Log function entry |
| 1401-1405 | Test-HashSidecar | Log sidecar verify entry |
| 1408-1410 | Test-HashSidecar | Log sidecar not found |
| 1419-1421 | Test-HashSidecar | Log empty sidecar |
| 1432-1437 | Test-HashSidecar | Log processing entries |
| 1504-1514 | Test-HashSidecar | Log verify summary |

[VERIFIED: `Select-String -Pattern '\$script:PSFrameworkAvailable' VeriHash.ps1` returned 20 matches]

### Additional PSFramework References (non-guard sites)

| File | Line | Type |
|------|------|------|
| VeriHash.ps1 | 98-99 | Comment + variable declaration (`$script:PSFrameworkAvailable = ...`) |
| VeriHash.ps1 | 102-105 | `#region Module Imports` — dot-source of LogUtils (for `ConvertTo-SanitizedPath` used in PSF blocks) |
| VeriHash.ps1 | 107, 187 | `#region` / `#endregion PSFramework Logging Initialization` markers |
| VeriHash.LogUtils.ps1 | 14 | Comment: "PSFramework adds ComputerName/Username metadata" |
| VeriHash.LogUtils.ps1 | 218 | Comment: "Skip lines that are just commas (PSFramework JSON array format artifact)" |
| VeriHash.LogUtils.ps1 | 220 | Comment: "Strip trailing comma from JSON lines (PSFramework appends commas for array format)" |

**Note on VeriHash.LogUtils.ps1:** The PSFramework references at lines 14, 218, and 220 are only **comments**, not executable code. The success criteria use `Select-String -i 'PSFramework'`, which will match comments too. These three comment lines must be reworded or removed to achieve the zero-match target.

[VERIFIED: codebase inspection]

### PSFramework References in Test Files

| File | Line(s) | Type | Action Required |
|------|---------|------|-----------------|
| VeriHash.HotPath.Tests.ps1 | 39-42 | Guard test asserting no PSFramework in HotPath | Delete the `It` block (D-05) |
| VeriHash.Manifest.Module.Tests.ps1 | 37-40 | Guard test asserting no PSFramework in Manifest | Delete the `It` block (D-05) |
| VeriHash.Tests.ps1 | 14 | Comment mentioning "PSFramework Logging" | Reword comment (D-05) |
| VeriHash.Tests.ps1 | 22 | Comment: "PSFramework Logging -> retired in Phase 1" | Reword comment (D-05) |

[VERIFIED: `Select-String` output for Tests/*.ps1]

### ConvertTo-SanitizedPath Call Sites (become dead callers after PSFramework removal)

All 11 `ConvertTo-SanitizedPath` call sites in `VeriHash.Config.ps1` (lines 159, 160, 213, 226, 319, 320, 329, 346, 392, 402, 421) are **inside** PSFramework guard blocks being deleted. The call sites in `VeriHash.ps1` (lines 182, 330, 331, 533, 790, 815, 1037, 1400) are also inside PSFramework blocks — **except line 1400** which is a standalone assignment before the guard:

```powershell
# VeriHash.ps1 line 1399-1401
$sanitizedSidecarPath = $SidecarPath | ConvertTo-SanitizedPath  # line 1400 — OUTSIDE guard
if ($script:PSFrameworkAvailable) {                             # line 1401
```

**This standalone call at line 1400 needs deletion too** — the `$sanitizedSidecarPath` variable is only used inside subsequent PSFramework blocks (lines 1402-1403, 1409, 1421, 1434, 1507). After the guards are deleted, it becomes a dead variable. Per D-06, `ConvertTo-SanitizedPath` itself stays in `VeriHash.LogUtils.ps1` as dead code.

[VERIFIED: codebase analysis of VeriHash.ps1 lines 1399-1514]

## VirusTotal Removal — Complete Inventory

### VeriHash.Config.ps1 — Lines to Remove/Edit

| Lines | Location | Content |
|-------|----------|---------|
| 85-91 | `Get-VeriHashDefaultConfig` | `virustotal = @{ apiKey = ''; enabled = $false; ... }` section in defaults hashtable |
| 109-110 | `Get-VeriHashConfig` docstring | Doc lines about `VERIHASH_VT_APIKEY` and `VERIHASH_VT_ENABLED` env vars |
| 151-154 | `Get-VeriHashConfig` | `$source.'virustotal.*' = 'default'` initializers (4 lines) |
| 191-209 | `Get-VeriHashConfig` | `# Merge virustotal settings from file` block |
| 254-261 | `Get-VeriHashConfig` | `if ($env:VERIHASH_VT_APIKEY)` and `if ($env:VERIHASH_VT_ENABLED)` blocks |
| 271-272 | `Get-VeriHashConfig` | `VTEnabled` and `VTHasApiKey` in PSFramework log Data (inside a guard being deleted by PSF removal) |
| 337 | `Set-VeriHashConfig` | `virustotal = $Config.virustotal` in `$configToSave` hashtable |

**After removal:** `Get-VeriHashDefaultConfig` returns only `@{ logging = @{ ... } }`. `Set-VeriHashConfig`'s `$configToSave` contains only `logging`. The VT lines in the PSF guard blocks (271-272) are already covered by PSFramework removal.

[VERIFIED: `Select-String -Pattern 'virustotal|VERIHASH_VT_' VeriHash.Config.ps1`]

### Tests/VeriHash.Config.Tests.ps1 — Lines to Remove/Edit

| Lines | Context | Content |
|-------|---------|---------|
| 20-21 | `AfterAll` | `$env:VERIHASH_VT_APIKEY = $null; $env:VERIHASH_VT_ENABLED = $null` |
| 76-82 | `Get-VeriHashDefaultConfig` | `It 'Returns a hashtable with virustotal section'` — **entire test** |
| 94-103 | `Get-VeriHashDefaultConfig` | `It 'Has correct default virustotal values'` — **entire test** |
| 113-114 | `Get-VeriHashConfig` BeforeEach | `$env:VERIHASH_VT_APIKEY = $null; $env:VERIHASH_VT_ENABLED = $null` |
| 127 | `Get-VeriHashConfig` | `$result.virustotal.enabled | Should -Be $false` assertion — **remove line** |
| 143-148 | `Get-VeriHashConfig` | `virustotal = @{ ... }` in test config file data — **remove section** |
| 157-158 | `Get-VeriHashConfig` | `$result.virustotal.*` assertions — **remove lines** |
| 180 | `Get-VeriHashConfig` | `$result.virustotal.enabled | Should -Be $false` — **remove line** |
| 202-216 | `Get-VeriHashConfig` | `It 'Environment variable overrides config file for VirusTotal API key'` — **entire test** |
| 219-231 | `Get-VeriHashConfig` | The boolean env var test includes VT assertions — **edit to remove VT parts** |
| 244, 252 | `Get-VeriHashConfig` | VT source tracking assertions — **remove** |
| 264-265 | `Set-VeriHashConfig` BeforeEach | `$env:VERIHASH_VT_APIKEY/ENABLED = $null` — **remove** |
| 279-284 | `Set-VeriHashConfig` | `virustotal` section in test config — **remove** |
| 301 | `Set-VeriHashConfig` | `virustotal = @{ apiKey = 'test' }` — **remove** |
| 338-343 | `Set-VeriHashConfig` | `virustotal` section in round-trip test — **remove** |
| 353-354 | `Set-VeriHashConfig` | `$loaded.virustotal.*` round-trip assertions — **remove** |

[VERIFIED: `Select-String -Pattern 'virustotal|VERIHASH_VT_' Tests/VeriHash.Config.Tests.ps1`]

## Integration Extraction — Complete Inventory

### Code to Move from VeriHash.ps1 to VeriHash.Integrations.ps1

| Lines | Content | Notes |
|-------|---------|-------|
| 211-223 | `$script:DesktopEnvironments` hashtable | Dispatch table for DE detection |
| 227-281 | `function Get-DesktopEnvironment` | Three-tier DE detection |
| 283-336 | `function Install-WindowsSendTo` | Creates .lnk in SendTo folder |
| 338-384 | `function Install-LinuxContextMenu` | DE-dispatched Linux installer |
| 386-556 | `function Install-KDEContextMenu` | KDE .desktop file generator |

**Total: ~346 lines** moving from VeriHash.ps1 to VeriHash.Integrations.ps1.

### Code Staying in VeriHash.ps1

The handler block at lines 597-616 stays but is modified:
- Add `dot-source "$PSScriptRoot\VeriHash.Integrations.ps1"` inside the `if ($SendTo)` block
- The `Install-WindowsSendTo` / `Install-LinuxContextMenu` calls remain as-is — they'll resolve to functions in the dot-sourced file

### PSFramework Guards Within Extraction Scope

Several PSFramework guard blocks exist within the code being extracted (lines 294-296, 328-333, 353-357, 401-405, 531-537). Since PSFramework is being removed in the same phase, these guards should be deleted during extraction — the moved code should arrive in `VeriHash.Integrations.ps1` already clean.

[VERIFIED: codebase analysis of VeriHash.ps1 lines 211-556]

## KDE Service Menu Format — Manifest Action Addition

### Existing .desktop File Structure (VeriHash.ps1:505-521)

```ini
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
```

### Required Changes for Manifest Action (D-11)

Add a third action to the `Actions=` list and a new `[Desktop Action ...]` section:

```ini
Actions=ComputeHash;VerifyHash;ManifestHash;

[Desktop Action ManifestHash]
Name=Manifest (VeriHash)
Icon=$iconPath
Exec=$terminalCmd -e $pwshPath -NoProfile -ExecutionPolicy Bypass -File "$scriptFullPath" -Manifest "%f"
```

The `-Manifest` flag follows D-10 — Phase 5 will wire the handler. The auto-detect behavior (D-09) means the same action works for both create and verify based on file extension.

[VERIFIED: KDE .desktop service menu format from existing code in VeriHash.ps1:505-521]

### Windows Manifest Shortcut (D-10)

A second `.lnk` file named `VeriHash - Manifest.lnk` is created in SendTo:
- Same target as `VeriHash.lnk` but with `-Manifest` appended to arguments
- Arguments: `-NoProfile -ExecutionPolicy Bypass -File "<VeriHash.ps1>" -Manifest`
- Uses the same icon from `Icons\VeriHash_256.ico`

The existing `Install-WindowsSendTo` function (lines 283-336) creates one shortcut via COM `WScript.Shell`. The modified version creates two shortcuts using the same COM pattern.

[VERIFIED: analysis of Install-WindowsSendTo COM shortcut pattern]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Windows .lnk creation | Raw binary .lnk format | `New-Object -ComObject WScript.Shell` + `CreateShortcut()` | Binary format is complex; COM API is the standard PowerShell approach |
| KDE service menu | Custom file format | Standard `.desktop` file with `KonqPopupMenu/Plugin` type | KDE has specific format requirements including `X-KDE-ServiceTypes` |
| Platform detection | Custom env-var checks | `Get-VeriHashPlatform` from VeriHash.Core | Phase 1 D-03 established this as the single source of truth |
| Config file merge | Custom merge logic | Keep existing `Get-VeriHashConfig` pattern (just remove VT sections) | Existing priority chain (env > file > defaults) is well-tested |

## Common Pitfalls

### Pitfall 1: Forgetting PSFramework References in Comments
**What goes wrong:** The success criteria uses `Select-String -i 'PSFramework|Write-PSFMessage|PSFrameworkAvailable'` which matches comments, not just code.
**Why it happens:** Developers focus on removing executable code but forget comment text.
**How to avoid:** Run the exact success criteria regex after removal. The three comment lines in `VeriHash.LogUtils.ps1` (lines 14, 218, 220) and two in `VeriHash.Tests.ps1` (lines 14, 22) must be edited.
**Warning signs:** Any `Select-String` hit on the pattern, even in comments.

### Pitfall 2: Orphaned ConvertTo-SanitizedPath Calls
**What goes wrong:** After removing PSFramework guard blocks, standalone `ConvertTo-SanitizedPath` calls that were made before their guard block (like line 1400) create dead variables.
**Why it happens:** The pattern `$sanitizedPath = X | ConvertTo-SanitizedPath` followed by `if ($PSFrameworkAvailable) { ... use $sanitizedPath ... }` leaves the first line orphaned.
**How to avoid:** For each PSFramework block removal, check the 1-3 lines above for variable assignments that only feed into the block being removed. Delete them.
**Warning signs:** `$sanitizedSidecarPath` variable assigned but never used after guard removal.

### Pitfall 3: Breaking the Config Test Round-Trip
**What goes wrong:** After removing `virustotal` from `Set-VeriHashConfig`'s `$configToSave`, the round-trip test fails because it expects to write and read VT fields.
**Why it happens:** The round-trip test at lines 328-355 creates a config with VT fields, saves it, reads it back, and asserts VT values.
**How to avoid:** Remove VT data from the round-trip test's input config AND remove VT assertions from its verification. Keep the test — it still validates logging round-trip.
**Warning signs:** Pester failure in `Set-VeriHashConfig` round-trip test.

### Pitfall 4: SendTo Handler Must Dot-Source Before Calling Functions
**What goes wrong:** `Install-WindowsSendTo` is called before `VeriHash.Integrations.ps1` is dot-sourced, causing "command not found."
**Why it happens:** The dot-source must happen inside the `if ($SendTo)` block before the platform dispatch.
**How to avoid:** Place the `. "$PSScriptRoot\VeriHash.Integrations.ps1"` line as the first statement inside the `if ($SendTo) { }` block.
**Warning signs:** `CommandNotFoundException` when running `VeriHash.ps1 -SendTo`.

### Pitfall 5: VeriHash.LogUtils.ps1 Dot-Source Import in Config Tests
**What goes wrong:** After PSFramework removal, `Tests/VeriHash.Config.Tests.ps1` line 3-4 still dot-sources `VeriHash.LogUtils.ps1`. If Config no longer calls `ConvertTo-SanitizedPath` (all call sites were in PSFramework blocks), the import is unnecessary but harmless.
**Why it happens:** The `BeforeAll` in Config tests imports LogUtils because Config *used to* depend on it for `ConvertTo-SanitizedPath` in PSFramework blocks.
**How to avoid:** Leave the import for now — it's harmless and removing it risks Config tests if any future code re-adds the dependency. Phase 5 can clean it up.
**Warning signs:** None — leaving it is correct.

### Pitfall 6: VeriHash.ps1 Line 102-104 Module Imports Region
**What goes wrong:** After PSFramework removal, the `. "$PSScriptRoot\VeriHash.LogUtils.ps1"` import at line 103 exists only to provide `ConvertTo-SanitizedPath` for PSFramework blocks. With all those blocks gone, this dot-source is dead weight.
**Why it happens:** The import was needed because PSFramework blocks used `ConvertTo-SanitizedPath`.
**How to avoid:** The import of `VeriHash.LogUtils.ps1` at line 103 should be removed from VeriHash.ps1 as part of PSFramework cleanup. The `VeriHash.Config.ps1` import at line 104 stays (it provides config functions used by the LogLevel handler). Note: This does NOT mean deleting VeriHash.LogUtils.ps1 from the repo — just removing the dot-source from VeriHash.ps1.
**Warning signs:** PSScriptAnalyzer may not catch this; verify manually.

## Dependency Analysis Between Work Items

### Independence Assessment

```
PSFramework Removal ──┐
                      ├── Both touch VeriHash.ps1 lines 98-187 and VeriHash.Config.ps1
VirusTotal Removal ───┘   but affect DIFFERENT lines within those files.

Integration Extraction ── Touches VeriHash.ps1 lines 211-556 and 597-616.
                          OVERLAPS with PSFramework removal at lines 294-296, 328-333,
                          353-357, 401-405, 531-537 (PSF guards in install functions).
```

### Recommended Execution Order

1. **PSFramework removal** (spans all legacy files — broadest impact, cleanest when done first)
2. **VirusTotal removal** (Config-only — independent of PSFramework work, but cleaner after PSF is gone since some VT lines are inside PSF blocks)
3. **Integration extraction** (moves code that's already been cleaned of PSFramework guards)
4. **Test updates** (guard test removal, new integration tests, lazy-load verification test)

**Rationale:** PSFramework guards exist INSIDE the install functions being extracted. Removing PSFramework first means the extraction moves already-clean code. This avoids having to track "which PSFramework lines moved to the new file and still need deletion."

## Code Examples

### VeriHash.Integrations.ps1 — File Structure

```powershell
<#
    VeriHash.Integrations.ps1 - OS integration installers (SendTo, KDE context menu)

    Dot-sourced lazily by VeriHash.ps1 when -InstallSendTo or -InstallKDE is invoked.
    Not loaded during normal hash/verify operations.
#>

# Self-contained Core dependency (D-03)
if (-not (Get-Module -Name 'VeriHash.Core')) {
    Import-Module "$PSScriptRoot/VeriHash.Core/VeriHash.Core.psd1"
}

# Desktop environment dispatch table
$script:DesktopEnvironments = @{
    'KDE' = @{
        Name = 'KDE Plasma'
        # ... (moved from VeriHash.ps1)
    }
}

function Get-DesktopEnvironment { ... }        # Moved from VeriHash.ps1
function Install-WindowsSendTo { ... }         # Moved + modified (dual shortcut)
function Install-LinuxContextMenu { ... }      # Moved from VeriHash.ps1
function Install-KDEContextMenu { ... }        # Moved + modified (manifest action)
```
[VERIFIED: pattern consistent with D-01, D-02, D-03 from CONTEXT.md]

### Lazy-Load Test Pattern

```powershell
# In Tests/VeriHash.Integrations.Tests.ps1
It 'Hot-path invocation does not load VeriHash.Integrations.ps1' {
    # Run a normal hash operation
    $output = & "$PSScriptRoot/../VeriHash.ps1" -FilePath $testFile -NoPause -SkipSignatureCheck *>&1

    # Verify integrations file was never loaded
    # Check that VeriHash.Integrations.ps1 is not in the call stack or loaded scripts
    $loadedScripts = Get-ChildItem Function: | Where-Object {
        $_.ScriptBlock.File -like '*Integrations*'
    }
    $loadedScripts | Should -BeNullOrEmpty
}
```
[ASSUMED: test pattern — actual implementation may vary based on what Pester facilities are available for verifying loaded scripts]

### Config Trimming — Get-VeriHashDefaultConfig After

```powershell
function Get-VeriHashDefaultConfig {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    @{
        logging = @{
            level   = 'INFO'
            file    = $true
            console = $true
        }
    }
}
```
[VERIFIED: follows D-07 — only `logging` section remains]

### Set-VeriHashConfig $configToSave After

```powershell
$configToSave = @{
    logging = $Config.logging
}
```
[VERIFIED: follows D-07 — `virustotal = $Config.virustotal` line removed]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Pester 5.7.1 |
| Config file | None — inline `New-PesterConfiguration` in `Test-All.ps1` |
| Quick run command | `Invoke-Pester -Path Tests/ -Output Detailed` |
| Full suite command | `.\Test-All.ps1` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INTEG-01 | Hot path does not load Integrations file | integration | `Invoke-Pester Tests/VeriHash.Integrations.Tests.ps1 -Output Detailed` | ❌ Wave 0 |
| INTEG-02 | Windows SendTo installs both .lnk files | unit (mock COM) | Same as above | ❌ Wave 0 |
| INTEG-03 | KDE install preserves user/system behavior | unit | Same as above | ❌ Wave 0 |
| CFG-01 | No virustotal in Config source | grep | `Select-String -i 'virustotal\|VERIHASH_VT_' *.ps1,*.psm1,*.psd1 -Recurse` | ✅ manual verify |
| CFG-02 | No VT references in Config tests | grep | Same grep over Tests/ | ✅ manual verify |
| CFG-03 | No PSFramework anywhere | grep | `Select-String -i 'PSFramework\|Write-PSFMessage\|PSFrameworkAvailable' **/*.ps1` | ✅ manual verify |

### Sampling Rate
- **Per task commit:** `Invoke-Pester -Path Tests/ -Output Detailed`
- **Per wave merge:** `.\Test-All.ps1`
- **Phase gate:** Full suite green + all four success criteria greps return zero matches

### Wave 0 Gaps
- [ ] `Tests/VeriHash.Integrations.Tests.ps1` — covers INTEG-01, INTEG-02, INTEG-03
- [ ] Framework install: none needed — Pester 5.7.1 already installed and passing

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| PSFramework structured logging | Built-in `Write-VeriHashLog` (Phase 1 CORE-07) | Phase 1 (2026-04-18) | PSFramework is now dead code — safe to remove |
| VirusTotal config fields | Removed from scope entirely | v2.0 scope decision | Config surface area shrinks by ~50% |
| Install functions in main script | Lazy-loaded dot-sourced file | Phase 4 (this phase) | Hot path no longer carries install function definitions |

**Deprecated/outdated:**
- **PSFramework dependency**: Replaced by `Write-VeriHashLog` in VeriHash.Core. All 34 guard sites are dead code.
- **VirusTotal config surface**: Never implemented (all fields were scaffolding). Removed from scope.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The lazy-load test can verify non-loading by checking `Function:` drive for Integrations-sourced functions | Validation Architecture | LOW — alternative: check `$MyInvocation` or test that `Install-WindowsSendTo` is not available as a command after normal invocation |
| A2 | Removing the dot-source of VeriHash.LogUtils.ps1 from VeriHash.ps1 line 103 won't break anything | Pitfall 6 | LOW — all ConvertTo-SanitizedPath calls are in PSFramework blocks being deleted; but verify no other code in VeriHash.ps1 calls LogUtils functions |

## Open Questions

1. **LogUtils dot-source removal from VeriHash.ps1**
   - What we know: After PSFramework removal, all `ConvertTo-SanitizedPath` calls in VeriHash.ps1 are gone. The only remaining use of LogUtils functions would be `Get-VeriHashLogPath` (used in the PSFramework init block being deleted).
   - What's unclear: Whether any other code path in VeriHash.ps1 references any LogUtils function after the PSFramework init region is removed.
   - Recommendation: Verify with `Select-String` after PSFramework removal. If no hits, remove the dot-source. If uncertain, leave it — it's harmless dead weight and Phase 5 deletes most of VeriHash.ps1 anyway.

2. **VeriHash.Config.ps1 dot-sourcing LogUtils**
   - What we know: Config imports Core at the top (lines 23-26). Config test BeforeAll dot-sources LogUtils then Config.
   - What's unclear: After PSFramework guards are deleted from Config, does Config still need anything from LogUtils at all?
   - Recommendation: Config's only LogUtils dependency was `ConvertTo-SanitizedPath` in PSFramework blocks. After removal, the dependency is dead. But Config's own `Import-Module VeriHash.Core` at lines 23-26 is sufficient. No action needed in Phase 4 — the test file's LogUtils import is harmless.

## Environment Availability

Step 2.6: SKIPPED (Phase 4 is purely code/config changes — no external tools, services, or runtimes beyond existing PowerShell 7 and Pester infrastructure already verified as working).

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `VeriHash.ps1` (1527 lines), `VeriHash.Config.ps1` (428 lines), `VeriHash.LogUtils.ps1` (319 lines)
- Codebase analysis: All 22 test files in `Tests/`
- `.planning/codebase/INTEGRATIONS.md` — detailed SendTo/KDE/PSFramework integration documentation
- `.planning/codebase/TESTING.md` — test patterns and conventions
- `.planning/codebase/CONVENTIONS.md` — coding conventions
- `04-CONTEXT.md` — 12 locked decisions from user discuss phase

### Secondary (MEDIUM confidence)
- `.planning/REQUIREMENTS.md` — 6 phase requirements (INTEG-01 through CFG-03)
- `.planning/STATE.md` — project state and phase pipeline

### Tertiary (LOW confidence)
- None — all findings verified against codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools (PowerShell 7, Pester 5, PSScriptAnalyzer) already in use, verified working with 194/194 tests passing
- Architecture: HIGH — extraction scope precisely mapped with line numbers, patterns verified in existing code
- Pitfalls: HIGH — derived from direct code analysis, not assumed
- PSFramework inventory: HIGH — exact line-by-line count verified with `Select-String` (34 guard sites confirmed)
- VirusTotal inventory: HIGH — exact line-by-line mapping verified with `Select-String`

**Research date:** 2026-04-19
**Valid until:** 2026-05-19 (stable — no external dependency version risk)
