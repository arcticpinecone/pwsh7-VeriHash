# Phase 3: Small Wins & Baseline Lock - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Close remaining audit items from CONCERNS.md — enable log rotation and flip the VirusTotal default — so the foundation is clean and self-maintaining before feature work begins. Covers LOGC-01 (log rotation) and LOGC-03 (VT default flip).

</domain>

<decisions>
## Implementation Decisions

### Log rotation (LOGC-01)
- **D-01:** Add `-LogRetentionTime 30` to the existing `Set-PSFLoggingProvider` call in `VeriHash.ps1` (line 152) — uses native PSFramework rotation, no custom cleanup needed
- **D-02:** 30-day retention only — no secondary file-count cap (`-MaxLogFiles`). One parameter, matches the requirement exactly
- **D-03:** No separate cleanup function in `VeriHash.LogUtils.ps1` — PSFramework handles pruning natively when the provider initializes

### VT default flip (LOGC-03)
- **D-04:** Change `enabled = $true` to `enabled = $false` in `Get-VeriHashDefaultConfig` (`VeriHash.Config.ps1` line 85) — stops misleading users about unshipped VirusTotal integration

### Agent's Discretion
- How to update existing tests that assert `virustotal.enabled | Should -Be $true` for the default config (behavioral change, not a TDD violation — the intended behavior is changing)
- Whether to add an inline comment in `Get-VeriHashDefaultConfig` noting VT is planned for a future phase
- Test structure for validating log rotation parameter is present in the provider call

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & success criteria
- `.planning/REQUIREMENTS.md` — LOGC-01 and LOGC-03 define the exact requirements for this phase
- `.planning/ROADMAP.md` §Phase 3 — Success criteria with 2 verifiable conditions

### Audit findings driving this phase
- `.planning/codebase/CONCERNS.md` §Scaling Limits — "No Log Rotation or Cleanup" documents the log accumulation problem (line 122)
- `.planning/codebase/CONCERNS.md` §Security & Privacy — "VirusTotal Config Section Enabled by Default Without Implementation" (line 65)

### Code targets
- `VeriHash.ps1` line 152 — `Set-PSFLoggingProvider` call where `-LogRetentionTime 30` must be added
- `VeriHash.Config.ps1` line 85 — `enabled = $true` in `Get-VeriHashDefaultConfig` virustotal section to flip to `$false`
- `Tests/VeriHash.Config.Tests.ps1` — Multiple assertions checking `virustotal.enabled` default value that will need updating

### Logging design contract
- `Verihash Logging Concepting.md` — Privacy-first logging guide; the code must match this contract

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Set-PSFLoggingProvider` call already configured with JSON format, UTC timestamps, and privacy-safe headers — just needs the rotation parameter added
- `Get-VeriHashDefaultConfig` has a clean hashtable structure — single-line change for VT default

### Established Patterns
- PSFramework guarded by `$script:PSFrameworkAvailable` — log rotation only activates when PSFramework is installed
- Config priority chain (env > file > defaults) — changing the default doesn't affect users who have explicit env var or config file overrides
- CI pipeline (Phase 2) validates all changes automatically on push

### Integration Points
- `VeriHash.ps1` line 152 — Provider configuration, add parameter inline
- `VeriHash.Config.ps1` line 85 — Default config hashtable
- `Tests/VeriHash.Config.Tests.ps1` lines 100, 127, 180 — Test assertions for VT enabled default

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. Both changes are surgical, well-scoped fixes to known audit items.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-small-wins-baseline-lock*
*Context gathered: 2026-04-18*
