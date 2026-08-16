# Phase 1: Core Module Foundation — Context

**Gathered:** 2026-04-18
**Status:** Ready for planning
**Milestone:** v2.0 Modular Rebuild

<domain>
## Phase Boundary

Build a real importable `VeriHash.Core` PowerShell module that owns:

- File hashing (MD5 / SHA256 / SHA512)
- Clipboard hash parsing (length-inferred + `<algo>:<hex>` prefix form)
- Sidecar verification (v1-compatible `HASH  filename` and `HASH *filename`)
- Output formatting (visually compatible with v1)
- Plain-text logging (no PSFramework, no rotation, no parser)
- Platform detection (defined once, exported from Core)

Tests load the module via `Import-Module` — the v1 dot-source-with-dummy-path hack is gone. This phase blocks every other v2.0 implementation phase.

</domain>

<canonical_refs>
## Canonical References

Downstream agents (researcher, planner, executor) MUST read these before acting.

- `.planning/ROADMAP.md` — Phase 1 entry, success criteria, dependency graph
- `.planning/REQUIREMENTS.md` — CORE-01 through CORE-08 (the 8 locked requirements for this phase)
- `.planning/PROJECT.md` — Vision, principles, non-negotiables (no PSFramework, PowerShell 7+ cross-platform, privacy-respecting)
- `.planning/STATE.md` — Current milestone position
- `.planning/codebase/STRUCTURE.md` — Existing repo layout (informs migration from monolith)
- `.planning/codebase/CONVENTIONS.md` — Function signature, logging, and platform-detection patterns (some carry forward, some are being explicitly retired)
- `.planning/codebase/TESTING.md` — Pester conventions, `VERIHASH_TEST_MODE=1` env-isolation pattern (the new `VERIHASH_LOG_PATH` decision below follows the same precedent)
- `VeriHash.ps1` — v1 monolith being replaced; source for the golden-text fixture and the behavior to preserve

No external specs/ADRs apply to Phase 1.

</canonical_refs>

<decisions>
## Locked Decisions

### 1. Module internal layout — `Public/` + `Private/` folders dot-sourced from `.psm1`

`VeriHash.Core.psm1` is a thin (~20-line) loader that dot-sources every `.ps1` under `Public/` and `Private/`, then runs `Export-ModuleMember -Function (Get-ChildItem $PSScriptRoot/Public/*.ps1).BaseName`. One function per file.

Folder layout:
```
VeriHash.Core/
├── VeriHash.Core.psd1
├── VeriHash.Core.psm1
├── Public/
│   ├── Get-VeriHashResult.ps1
│   ├── Read-ClipboardHash.ps1
│   ├── Test-VeriHashSidecar.ps1
│   ├── Format-VeriHashReport.ps1
│   ├── Write-VeriHashLog.ps1
│   └── Get-VeriHashPlatform.ps1
└── Private/
    └── (internal helpers — to be identified during planning/research)
```

This is the de-facto PowerShell module convention; `VeriHash.Manifest` (Phase 3) will mirror it.

### 2. Result object type — `[pscustomobject]` with `PSTypeName = 'VeriHash.Result'`

`Get-VeriHashResult` returns:
```powershell
[pscustomobject]@{
    PSTypeName = 'VeriHash.Result'
    FilePath   = $path
    Size       = $size      # bytes (long)
    Algorithm  = $algo      # 'MD5' | 'SHA256' | 'SHA512'
    Hash       = $hash      # lowercase hex string
    ElapsedMs  = $ms        # int
}
```

No PowerShell `class`. Rationale: cold-start matters for Phase 2's hot path; `PSTypeName` keeps `Format.ps1xml` available as a future option without paying class-compilation cost on every import.

### 3. Platform helper — `Get-VeriHashPlatform` returns a string

Single exported function returning `'Windows' | 'Linux' | 'macOS'`. No predicates, no exported variable. Every other v2 module consumes platform context via `switch (Get-VeriHashPlatform)` or `if ((Get-VeriHashPlatform) -eq '...')`.

This satisfies CORE-08: detection is defined exactly once in Core; the duplicates in `VeriHash.Config.ps1` and `VeriHash.LogUtils.ps1` are eliminated as part of this phase.

### 4. Plain-text log line format

**Format (locked for the lifetime of v2 — no parser, no rotation):**
```
<ISO8601-UTC> <op> <algo> <hash> <bytes> <elapsed_ms> <result> <path>
```

- `<op>` ∈ `hash | verify`
- `<result>` ∈ `ok | mismatch | missing | error | n/a`
- `<path>` is **always last** so spaces in paths cannot break splitting on the first 7 columns
- Single space separator; UTC ISO 8601 timestamp (e.g., `2026-04-18T13:05:42Z`)

**Trigger (per CORE-07):** `-Log` flag OR `$env:VERIHASH_LOG=1`. One line per invocation. Append-only.

**Log file path:**
- Default: `~/.verihash/verihash.log`
- Overridable via `$env:VERIHASH_LOG_PATH` (env > default). Required for test isolation — same precedent as the existing `VERIHASH_TEST_MODE=1` pattern in `Tests/`.

### 5. Clipboard on Linux/macOS — graceful no-op

`Read-ClipboardHash` on non-Windows platforms:
```powershell
if ((Get-VeriHashPlatform) -ne 'Windows') {
    Write-Verbose 'Clipboard reading not supported on this platform yet.'
    return $null
}
```

`$null` is the existing "no clipboard hash to compare against" sentinel — every caller already handles it. No new dependencies, no new failure modes. v1 was Windows-only here too; this is not a regression.

Cross-platform clipboard support (xclip / wl-paste / pbpaste) is **deferred to the v2.x backlog** — see Deferred Ideas below.

### 6. Sidecar precedence — strongest wins

When multiple sidecar files exist for the same target (e.g., both `foo.iso.sha256` and `foo.iso.sha512`), `Test-VeriHashSidecar` picks in this fixed order:

1. `.sha512`
2. `.sha256`
3. `.md5`

Only the chosen sidecar is verified (single hash computation — keeps Phase 2's hot path fast). The output line names which sidecar was used, e.g.:

```
Sidecar: matched (foo.iso.sha512)
```

This eliminates user ambiguity about *what got verified* and avoids changing the output shape (multi-line per file would complicate Phase 2 streaming).

### 7. Module folder location — repo root

`./VeriHash.Core/` lives at the repository root, not under `src/` or `modules/`. Phase 3's `./VeriHash.Manifest/` mirrors this. The Phase 5 thin CLI (`VeriHash.ps1`) stays at the repo root next to its module dependencies.

This matches PowerShellGet/PSGallery layout conventions (one folder = one module, at root) and keeps `Import-Module` paths short in tests:
```powershell
Import-Module "$PSScriptRoot\..\VeriHash.Core\VeriHash.Core.psd1"
```

</decisions>

<carried_forward>
## Carried Forward From PROJECT.md / Prior Context

These are pre-decided constraints that apply to this phase — researcher and planner should treat them as locked, not as gray areas:

- **No PSFramework dependency in `VeriHash.Core`.** Phase 4 will excise PSFramework everywhere; do not introduce new uses in Phase 1. The plain-text logger (CORE-07, decision #4 above) is the only logging in Core.
- **PowerShell 7+ cross-platform.** Module must `Import-Module` cleanly and run on Windows, Linux, and macOS. Per-function platform behavior may differ (see decision #5: clipboard) but the module load itself never errors on any supported OS.
- **TDD rule:** Tests are never modified to make them pass. Modify the code. Documented in `AGENTS.md` and the Copilot custom instructions for this repo.
- **Visual output stays v1-compatible.** `Format-VeriHashReport` output passes a golden-text fixture pinned to v1 layout (per CORE-06 + Phase 1 success criterion #4). The fixture should be captured from a v1 run before refactor begins.
- **Test isolation env-var pattern.** Tests already use `VERIHASH_TEST_MODE=1` to redirect logs. The new `VERIHASH_LOG_PATH` env override (decision #4) follows the same precedent — Pester `BeforeAll`/`AfterAll` blocks set it, point it at a temp path, and clean up.

</carried_forward>

<requirements_coverage>
## Requirements Coverage

All 8 CORE requirements are addressed by the locked decisions above.

| REQ-ID | Decision(s) that satisfy it |
|--------|------------------------------|
| CORE-01 (importable module via `Import-Module`) | #1 (module layout), #7 (folder location) |
| CORE-02 (`Get-VeriHashResult` returns `FilePath/Size/Algorithm/Hash/ElapsedMs`) | #2 (result object type) |
| CORE-03 (`Read-ClipboardHash` length-based inference) | #5 (clipboard cross-platform behavior) — Windows path implements full logic |
| CORE-04 (`Read-ClipboardHash` `<algo>:<hex>` prefix form) | #5 (same — Windows path implements full logic) |
| CORE-05 (sidecar verify, v1-compatible formats) | #6 (sidecar precedence) |
| CORE-06 (`Format-VeriHashReport` v1-visually-compatible) | Carried-forward: golden-text fixture pinned to v1 |
| CORE-07 (`Write-VeriHashLog` plain-text, append-only) | #4 (log line format + `VERIHASH_LOG_PATH` override) |
| CORE-08 (platform detection defined exactly once) | #3 (`Get-VeriHashPlatform`) |

</requirements_coverage>

<deferred>
## Deferred Ideas

Captured here so they aren't lost; not in scope for Phase 1.

- **Cross-platform clipboard support for `Read-ClipboardHash`** — shell out to `wl-paste` (Wayland) → `xclip` → `xsel` on Linux, `pbpaste` on macOS. Add to v2.x backlog as its own phase. Surface area is large enough (Wayland vs X11, headless sessions, selection vs clipboard) to deserve dedicated planning.
- **`Format.ps1xml` for `VeriHash.Result`** — the `PSTypeName` chosen in decision #2 enables this later. Would give pretty `Format-Table` defaults. Not needed for Phase 1.
- **`-VerifyAll` CLI flag** — verify every present sidecar (not just the strongest) and report each independently. Belongs in Phase 5 (thin CLI) if there's user demand; do not build into Core.

</deferred>

<open_questions_for_planner>
## Notes for the Planner

Things the planner/researcher should explicitly decide during Phase 1 planning (intentionally not over-specified here):

- **Internal helper inventory** — which private helpers (under `Private/`) the public functions need. Likely candidates: hash-algorithm-from-extension lookup, sidecar-line parser, ISO 8601 timestamp formatter — but final list comes from research.
- **Golden-text fixture capture mechanism** — how to record v1 output once and pin it (test fixture file vs inline here-string). Either is fine; pick what's easiest to regenerate when the format intentionally changes.
- **Pester test file split** — one `*.Tests.ps1` per public function, or grouped by concern? Either works; should match whatever discoverability the existing `Tests/` directory already favors.
- **Module manifest (`.psd1`) metadata** — version pinning strategy, `RequiredModules`, `CompatiblePSEditions`, `FunctionsToExport` (must match `Public/*.ps1` basenames). Standard module-manifest hygiene; no decisions needed beyond "do it correctly."

</open_questions_for_planner>
