# Phase 4: Discussion Log

**Date:** 2025-07-23
**Mode:** Interactive (no flags)

## Areas Discussed

### 1. Integrations file shape
**Options presented:** Dot-sourced script, full module, inline in Phase 5 CLI, agent decides
**User questions:** Asked about future extensibility of full module approach
**Decision:** Dot-sourced script — run-once install code doesn't warrant module overhead
**Sub-decisions:**
- Extract ALL install functions (not just SendTo)
- Explicit Core check/resolve pattern (`if (-not (Get-Module ...))`)

### 2. PSFramework removal strategy
**Options presented:** Delete silently, redirect to Write-VeriHashLog, selective (delete debug, redirect warnings)
**Decision:** Delete silently — Phase 5 rewrites this code anyway
**Sub-decisions:**
- Remove guard tests from HotPath and Manifest test files
- Update retirement comments in VeriHash.Tests.ps1
- Leave ConvertTo-SanitizedPath as dead code for Phase 5

### 3. Config backward compatibility
**Options presented:** Silent ignore + organic drop, add courtesy deprecation notice
**Decision:** Silent ignore + organic drop — zero-friction upgrade path
**Sub-decisions:**
- VT env vars harmlessly ignored (no error if user has them set)

### 4. Manifest SendTo mechanics
**Options presented:** Auto-detect vs always-create vs always-verify; -Manifest flag vs separate script; KDE manifest action
**User questions:** Asked about weight of flag on VeriHash.ps1 vs separate script — explained "one front door" routing pattern
**Decisions:**
- Auto-detect create/verify by extension
- `-Manifest` flag on VeriHash.ps1 (one front door)
- KDE gets manifest action too
- Phase 4 creates plumbing, Phase 5 wires handler

## Areas Not Discussed (no gray areas identified)
None — all 4 identified areas were discussed.

## Deferred Items Captured
- Full module promotion if integrations grow
- ConvertTo-SanitizedPath placement decision → Phase 5
- VT config migration tool → not needed
