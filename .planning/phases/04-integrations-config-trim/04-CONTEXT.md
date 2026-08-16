# Phase 4: Integrations + Config Trim - Context

**Gathered:** 2025-07-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Lazy-loaded integrations file for Windows SendTo and Linux KDE context-menu installation, removal of all VirusTotal config fields and PSFramework references from legacy files. Hot-path invocation must never load integrations code. Console formatting and CLI parameter wiring are Phase 5 scope.

</domain>

<decisions>
## Implementation Decisions

### Integrations file shape
- **D-01:** Dot-sourced script (`VeriHash.Integrations.ps1` at repo root), not a full module. Run-once install code doesn't warrant module overhead. Can be promoted to a module later if integrations grow.
- **D-02:** Extract ALL install functions from VeriHash.ps1 — `Install-WindowsSendTo`, `Install-KDEContextMenu`, `Get-DesktopEnvironment`, the `$script:DesktopEnvironments` dispatch table, and helper detection code. VeriHash.ps1 keeps only the flag check + dot-source.
- **D-03:** Explicit Core check/resolve at top of file: `if (-not (Get-Module -Name 'VeriHash.Core')) { Import-Module "$PSScriptRoot/VeriHash.Core/VeriHash.Core.psd1" }`. Self-contained — works whether caller loaded Core or not. No `-Force` (unlike test files that always reload).

### PSFramework removal strategy
- **D-04:** Delete silently — remove all `if ($script:PSFrameworkAvailable) { ... }` blocks, `$script:PSFrameworkAvailable` variable initialization, and any `Import-Module PSFramework` or conditional PSFramework loading. No replacement with `Write-VeriHashLog` or `Write-Verbose`. Phase 5 rewrites VeriHash.ps1 into a thin CLI — most of this code gets deleted/rewritten then anyway.
- **D-05:** Remove guard tests from `VeriHash.HotPath.Tests.ps1` (lines 39-42) and `VeriHash.Manifest.Module.Tests.ps1` (lines 37-40). Update comments in `VeriHash.Tests.ps1` (lines 14, 22). These guard tests served their purpose during the Phase 1-3 transition; with PSFramework gone everywhere, they're redundant — and their removal satisfies the zero-match success criteria.
- **D-06:** Leave `ConvertTo-SanitizedPath` (defined in `VeriHash.LogUtils.ps1`) as dead code. All its call sites are inside PSFramework blocks being deleted. Phase 5 will decide whether to move it to Core or retire it. Do not delete or move it in Phase 4.

### Config backward compatibility
- **D-07:** Silent ignore + organic drop for VirusTotal config fields. The config loader only looks for properties it knows about (`logging`). Unknown sections (like `virustotal`) in existing `config.json` files are harmlessly ignored on read. On next save, `Set-VeriHashConfig` writes only known fields — the `virustotal` section silently disappears. No migration tool, no deprecation warning.
- **D-08:** VirusTotal env vars (`VERIHASH_VT_APIKEY`, `VERIHASH_VT_ENABLED`) simply stop being read. If a user has them set, they're harmlessly ignored. No error, no warning.

### Manifest SendTo mechanics
- **D-09:** Auto-detect create vs verify based on file extension. When a file is sent to the manifest shortcut: `.sha256`, `.sha512`, `.md5` → verify that manifest; anything else → create a manifest. Smart default, no user prompt needed.
- **D-10:** `-Manifest` flag on VeriHash.ps1 — consistent with the "one front door" pattern. The manifest .lnk passes `pwsh -File VeriHash.ps1 -Manifest` and Windows SendTo appends the dropped file. Phase 4 creates the shortcut; Phase 5 adds the `-Manifest` parameter handler to VeriHash.ps1.
- **D-11:** KDE service menu gets a manifest action alongside the existing hash action. Same auto-detect behavior as Windows SendTo.
- **D-12:** Phase 4 creates the shortcuts and KDE entries with the `-Manifest` flag. Phase 5 wires up the handler. Between phases, the manifest shortcut exists but won't function — acceptable since these are sequential development phases, not separate releases.

</decisions>

<specifics>
## Specific Ideas

- Dot-sourced script was chosen over full module because integrations code runs once per install — it doesn't justify module infrastructure (manifest, psm1 loader, folder structure). The v2 modules (Core, HotPath, Manifest) earn their structure because they're imported on every hash operation.
- The explicit `if (-not (Get-Module ...))` check was a user request for self-documenting code — PowerShell's `Import-Module` (without `-Force`) does the same check internally, but the explicit version makes the intent obvious to future readers.
- PSFramework deletion (not redirection) was chosen because Phase 5 rewrites VeriHash.ps1 into a ~200-line thin CLI. Most of the 82 PSFramework call sites live in functions already migrated to v2 modules — those legacy copies will be deleted in Phase 5 regardless.
- `ConvertTo-SanitizedPath` is deliberately left as dead code to avoid premature decisions. Phase 5 may want it for `Write-VeriHashLog` path sanitization, or may not. Git history preserves it regardless.
- Silent VirusTotal config handling was chosen for zero-friction upgrades. Users who had VT config won't see errors; the fields quietly fade on next config save.

</specifics>

<canonical_refs>
## Canonical References

| Ref | Location | Relevance |
|-----|----------|-----------|
| INTEG-01 | REQUIREMENTS.md | Lazy-loaded integrations — hot path must NOT load it |
| INTEG-02 | REQUIREMENTS.md | Windows SendTo installs both VeriHash.lnk and VeriHash - Manifest.lnk |
| INTEG-03 | REQUIREMENTS.md | Linux KDE service-menu preserved, user-level + --SystemWide |
| CFG-01 | REQUIREMENTS.md | Remove all virustotal fields/defaults/env-var handling |
| CFG-02 | REQUIREMENTS.md | Remove all VirusTotal references from config tests |
| CFG-03 | REQUIREMENTS.md | Remove PSFramework from ALL production source + tests |
| Install-WindowsSendTo | VeriHash.ps1:283-336 | Existing SendTo installer — moves to VeriHash.Integrations.ps1 |
| Install-LinuxContextMenu | VeriHash.ps1:338+ | Existing KDE installer — moves to VeriHash.Integrations.ps1 |
| Get-DesktopEnvironment | VeriHash.ps1:240-281 | DE detection — moves to VeriHash.Integrations.ps1 |
| $script:DesktopEnvironments | VeriHash.ps1 | Dispatch table — moves to VeriHash.Integrations.ps1 |
| Set-VeriHashConfig | VeriHash.Config.ps1:295-350 | Save function — drop `virustotal` from $configToSave |
| ConvertTo-SanitizedPath | VeriHash.LogUtils.ps1:47+ | Becomes dead code after PSFramework removal |
| Phase 3 D-17 | 03-CONTEXT.md | No Write-Host in manifest module; Phase 5 handles display |
| Phase 1 D-03 | 01-CONTEXT.md | Get-VeriHashPlatform is the only platform check |
| INTEGRATIONS.md | .planning/codebase/ | Detailed SendTo/KDE/PSFramework integration docs |

</canonical_refs>

<deferred>
## Deferred Ideas

- **Full module promotion:** If integrations grow significantly (GNOME, XFCE, macOS Finder, PSGallery install), `VeriHash.Integrations.ps1` can be promoted to a full `VeriHash.Integrations/` module. Current scope doesn't warrant it.
- **ConvertTo-SanitizedPath in Core:** May be useful for `Write-VeriHashLog` path sanitization. Decision deferred to Phase 5 when the logging story is finalized.
- **VT config migration tool:** Not needed — silent ignore + organic drop handles the transition. If VeriHash ever re-adds VT support (future milestone), it would read the fields again anyway.

</deferred>
