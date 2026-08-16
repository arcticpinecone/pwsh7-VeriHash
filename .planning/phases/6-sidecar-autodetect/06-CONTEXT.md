# Phase 6: Sidecar Auto-Detect - Context

**Gathered:** 2026-04-19
**Status:** Ready for planning

<domain>
## Phase Boundary

When a single `.sha256`/`.sha512`/`.md5` file is passed (with or without `-Manifest`), VeriHash auto-detects intent: 1 non-blank line → sidecar verify (hash the companion, compare against stored hash); multiple lines → manifest verify (existing `Test-VeriHashManifest` path). Empty file → clear error. This phase adds the auto-detect routing and focused sidecar verify — it does NOT change output formatting (Phase 7) or manifest spot-check (Phase 8).

</domain>

<decisions>
## Implementation Decisions

### Verify behavior
- **D-01:** Focused verify — when a sidecar triggers auto-detect, hash the companion file and compare against the stored hash. Show pass/fail result only. Do NOT run the full hot-path (no Authenticode signature check, no clipboard detection, no formatted report sections). The sidecar verify is purpose-built: "does this file match the hash in the sidecar?"

### Supported extensions
- **D-02:** Three canonical extensions only: `.sha256`, `.sha512`, `.md5`. These match the existing codebase (`VeriHash.ps1` manifest mode, `Get-PreferredSidecar`). Legacy v1 extensions (`.sha2`, `.sha2_256`) are not supported for auto-detect.

### Clipboard interaction
- **D-03:** Skip clipboard during sidecar verify. The sidecar file IS the authoritative expected hash — clipboard adds noise and could produce confusing dual-comparison results (sidecar says match, clipboard from a different source says mismatch).

### Hash length validation
- **D-04:** Best-effort on hash length mismatch. If a `.sha256` sidecar contains a hash that isn't 64 hex chars, warn the user about the unexpected length but still compute SHA256 of the companion and compare. The computed hash is shown so the user can work with it even though comparison will fail.

### Agent's Discretion
- Module placement of the auto-detect function (VeriHash.Core vs CLI dispatcher)
- Internal routing logic structure (new function vs inline code)
- Whether `Read-SidecarLine` needs to be promoted from private to public or can stay private with a new wrapper
- Exact error message wording (must be clear and actionable per SIDE-04, SIDE-05)
- Test structure and mock strategy

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design spec
- `.planning/notes/sidecar-autodetect-exploration.md` — Full auto-detect design: routing logic, companion resolution (GNU format + extension strip), edge cases, VeriHash.ps1 integration point

### Requirements
- `.planning/REQUIREMENTS.md` §Sidecar Auto-Detect — SIDE-01 through SIDE-06

### Codebase integration
- `VeriHash.ps1:152-196` — Main dispatch: hash mode at lines 183-189 is the integration point
- `VeriHash.Core/Public/Test-VeriHashSidecar.ps1` — Existing sidecar verify (reverse direction: target → sidecar)
- `VeriHash.Core/Private/Get-PreferredSidecar.ps1` — Extension-to-algorithm map, sidecar discovery pattern
- `VeriHash.Core/Private/Read-SidecarLine.ps1` — GNU format line parser (private function)
- `VeriHash.Manifest/Public/Test-VeriHashManifest.ps1` — Multi-line manifest verify (the N-line path)

### Prior decisions
- `05-CONTEXT.md` D-02 — `[string[]]$FilePath` + `-Manifest` switch, extension auto-detect within manifest mode
- `05-CONTEXT.md` D-04 — Pause-at-end auto-detection heuristic

### Testing patterns
- `Tests/VeriHash.Core.Test-VeriHashSidecar.Tests.ps1` — Existing sidecar test patterns (sidecar file creation, hash comparison, mocking)
- `Tests/VeriHash.Cli.Tests.ps1` — CLI dispatch tests (mock strategy, hash-extension handling)
- `.planning/codebase/TESTING.md` — Test conventions and patterns

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Read-SidecarLine` (VeriHash.Core/Private): Parses GNU format `hash *filename` and bare hash lines — directly needed for companion resolution
- `Get-PreferredSidecar`: Extension-to-algorithm mapping (`@{ '.sha512' = 'SHA512'; '.sha256' = 'SHA256'; '.md5' = 'MD5' }`) — reuse this map
- `Get-VeriHashResult`: Core hash computation — use for hashing the companion file
- `Test-VeriHashManifest`: Multi-line manifest verify — the auto-detect N-line path routes here (already works)

### Established Patterns
- Extension-based algorithm detection is already the pattern in both `Get-PreferredSidecar` and `VeriHash.ps1` manifest mode (line 158-160)
- Conditional module import (`if (-not (Get-Module ...))`) for testability
- `VeriHash.Result` PSTypeName for hash result objects
- Private functions stay private unless a public consumer needs them — new code may need `Read-SidecarLine` access

### Integration Points
- `VeriHash.ps1` lines 183-189: Hash mode `if/else` — auto-detect logic inserts BEFORE `Invoke-VeriHashHotPath`
- `VeriHash.ps1` lines 156-160: Manifest mode extension check — Phase 6 unifies so hash-extension files auto-detect regardless of `-Manifest` (SIDE-06)
- Both hash mode and manifest mode must converge: a `.sha256` file should behave identically with or without `-Manifest`

</code_context>

<specifics>
## Specific Ideas

- The focused verify (D-01) was chosen because right-clicking a sidecar file is an "answer one question" action: does the companion match? Full hot-path output (signature, clipboard, metadata) is noise for this use case.
- Skipping clipboard (D-03) avoids the confusing dual-comparison scenario: sidecar says MATCH, clipboard (from a different source) says MISMATCH. The sidecar IS the authority.
- Best-effort on hash mismatch (D-04) ensures the user still gets the computed hash even when the sidecar is corrupted — they can compare manually or fix the sidecar. Failing hard would leave them with nothing.
- The companion resolution logic (GNU format → filename from line, bare hash → strip extension from sidecar filename) is already designed in the exploration notes and maps directly to SIDE-02.
- Resolving companion relative to sidecar's directory (SIDE-03) follows the same pattern already used in `Test-VeriHashManifest` (MANIFEST-07).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 06-sidecar-autodetect*
*Context gathered: 2026-04-19*
