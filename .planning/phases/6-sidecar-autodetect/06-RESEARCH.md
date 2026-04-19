# Phase 6: Sidecar Auto-Detect - Research

**Researched:** 2026-04-19
**Domain:** PowerShell routing logic, GNU sidecar format parsing, file extension-based dispatch
**Confidence:** HIGH

## Summary

Phase 6 adds intelligent routing so that right-clicking a `.sha256`/`.sha512`/`.md5` file verifies the companion file rather than uselessly hashing the sidecar text. The implementation must (1) detect hash-extension files at the CLI dispatch layer, (2) count non-blank lines to distinguish single-line sidecar from multi-line manifest, (3) resolve the companion file relative to the sidecar's directory, and (4) produce a focused verify result (hash + pass/fail comparison only, per D-01).

The codebase already has all the building blocks: `Read-SidecarLine` parses GNU format lines, `Get-PreferredSidecar` holds the extension-to-algorithm map, `Get-VeriHashResult` computes hashes, and `Test-VeriHashManifest` handles multi-line verification. The new work is a routing function that ties these together and integrates into `VeriHash.ps1`'s dispatch logic at the correct insertion point.

**Primary recommendation:** Create a new public function `Invoke-VeriHashSidecarDetect` in VeriHash.Core that encapsulates the auto-detect routing (read file → count lines → dispatch to sidecar verify or manifest verify), then modify VeriHash.ps1's dispatch to call it before falling through to the hot-path.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Focused verify — when a sidecar triggers auto-detect, hash the companion file and compare against the stored hash. Show pass/fail result only. Do NOT run the full hot-path (no Authenticode signature check, no clipboard detection, no formatted report sections). The sidecar verify is purpose-built: "does this file match the hash in the sidecar?"
- **D-02:** Three canonical extensions only: `.sha256`, `.sha512`, `.md5`. These match the existing codebase (`VeriHash.ps1` manifest mode, `Get-PreferredSidecar`). Legacy v1 extensions (`.sha2`, `.sha2_256`) are not supported for auto-detect.
- **D-03:** Skip clipboard during sidecar verify. The sidecar file IS the authoritative expected hash — clipboard adds noise and could produce confusing dual-comparison results (sidecar says match, clipboard from a different source says mismatch).
- **D-04:** Best-effort on hash length mismatch. If a `.sha256` sidecar contains a hash that isn't 64 hex chars, warn the user about the unexpected length but still compute SHA256 of the companion and compare. The computed hash is shown so the user can work with it even though comparison will fail.

### Agent's Discretion
- Module placement of the auto-detect function (VeriHash.Core vs CLI dispatcher)
- Internal routing logic structure (new function vs inline code)
- Whether `Read-SidecarLine` needs to be promoted from private to public or can stay private with a new wrapper
- Exact error message wording (must be clear and actionable per SIDE-04, SIDE-05)
- Test structure and mock strategy

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SIDE-01 | When a single `.sha256`/`.sha512`/`.md5` file is passed, auto-detect: 1 non-blank line → sidecar verify, multiple lines → manifest verify | Routing function reads file, filters blank lines, dispatches based on count. Extension detection reuses `Get-PreferredSidecar`'s `$algoMap`. |
| SIDE-02 | Sidecar companion resolution: GNU format (`hash *filename`) → filename from line; bare hash → strip hash extension from sidecar filename | `Read-SidecarLine` already parses GNU format. Bare hash fallback = regex didn't match filename → strip extension from sidecar path. |
| SIDE-03 | Companion file resolved relative to sidecar's directory, not CWD | Use `Split-Path -Parent` on the resolved sidecar path, then `Join-Path` or `[System.IO.Path]::GetFullPath(Combine(...))` — same pattern as `Test-VeriHashManifest`. |
| SIDE-04 | Clear error when companion file doesn't exist: "Companion file not found: {name}" | Write-Error with descriptive message after companion resolution fails `Test-Path`. |
| SIDE-05 | Clear error when sidecar file is empty | Check `$lines.Count -eq 0` after filtering blank lines → Write-Error "Sidecar file is empty: {path}". |
| SIDE-06 | `.sha256`/`.sha512`/`.md5` files passed with `-Manifest` flag also auto-detect (unified behaviour) | Both manifest-mode and hash-mode dispatch converge to the same auto-detect function. VeriHash.ps1 calls auto-detect in BOTH branches when extension matches. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Extension detection | CLI dispatcher (VeriHash.ps1) | — | Entry point must intercept before routing to hot-path or manifest |
| Line counting & dispatch | VeriHash.Core (public function) | — | Reusable logic that can be tested in isolation |
| GNU format parsing | VeriHash.Core (private Read-SidecarLine) | — | Already exists, called by new routing function |
| Companion path resolution | VeriHash.Core (new routing function) | — | Must resolve relative to sidecar dir per SIDE-03 |
| Hash computation | VeriHash.Core (Get-VeriHashResult) | — | Existing function, no changes needed |
| Multi-line manifest verify | VeriHash.Manifest (Test-VeriHashManifest) | — | Existing function, N-line path routes here |
| Result output | CLI dispatcher (VeriHash.ps1) | — | Pass/fail display (D-01: focused, minimal) |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PowerShell 7.0+ | 7.x | Runtime | Project requirement in all .psd1 manifests [VERIFIED: VeriHash.Core.psd1 line 36] |
| Pester | 5.7.1 | Test framework | Already installed, used by all existing tests [VERIFIED: Get-Module Pester -ListAvailable] |
| VeriHash.Core module | 2.0.0 | Hash compute, sidecar parsing | Existing module where new auto-detect function belongs [VERIFIED: VeriHash.Core.psd1] |
| VeriHash.Manifest module | 2.0.0 | Multi-line manifest verify | N-line path routes to existing Test-VeriHashManifest [VERIFIED: VeriHash.Manifest.psd1] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| PSScriptAnalyzer | installed | Lint/code quality | Run via Test-All.ps1 before committing [VERIFIED: Test-All.ps1] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| New public function in VeriHash.Core | Inline code in VeriHash.ps1 | Inline is simpler but untestable in isolation; function is testable and reusable by Phase 8 |
| Promoting Read-SidecarLine to public | Calling it internally from new public wrapper | Keep private — new public function wraps the call; maintains encapsulation |

## Architecture Patterns

### System Architecture Diagram

```
User right-clicks .sha256 file
        │
        ▼
┌─────────────────────────────────────────────────────┐
│  VeriHash.ps1 (CLI Dispatcher)                      │
│                                                     │
│  1. Is FilePath a hash-extension file?              │
│     (.sha256 / .sha512 / .md5)                      │
│     ├── YES ──────────────────────────────────┐     │
│     │   Call Invoke-VeriHashSidecarDetect      │     │
│     │                                         │     │
│     └── NO ─── existing hot-path / batch ─────┘     │
│                                                     │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  Invoke-VeriHashSidecarDetect (VeriHash.Core)       │
│                                                     │
│  1. Resolve sidecar path                            │
│  2. Read non-blank lines                            │
│  3. Count lines:                                    │
│     ├── 0 lines → Write-Error "empty"              │
│     ├── 1 line  → Sidecar Verify path              │
│     └── N lines → Route to Test-VeriHashManifest   │
│                                                     │
│  Sidecar Verify (1 line):                           │
│  ├── Parse with Read-SidecarLine                    │
│  ├── GNU format? → companion = parsed filename      │
│  ├── Bare hash?  → companion = strip extension      │
│  ├── Resolve companion relative to sidecar dir      │
│  ├── Companion missing? → Write-Error + return      │
│  ├── Validate hash length (D-04: warn, don't fail)  │
│  ├── Get-VeriHashResult -Path companion -Algorithm  │
│  └── Return VeriHash.SidecarVerifyResult            │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Recommended Project Structure (changes only)

```
VeriHash.Core/
├── Public/
│   ├── Invoke-VeriHashSidecarDetect.ps1  # NEW — auto-detect routing + sidecar verify
│   └── ... (existing)
├── Private/
│   ├── Read-SidecarLine.ps1              # EXISTING — stays private
│   ├── Get-PreferredSidecar.ps1          # EXISTING — reuse algoMap
│   └── ...
VeriHash.ps1                              # MODIFIED — dispatch calls new function
Tests/
├── VeriHash.Core.Invoke-VeriHashSidecarDetect.Tests.ps1  # NEW — unit tests
└── VeriHash.Cli.SidecarAutoDetect.Tests.ps1              # NEW — E2E integration tests
```

### Pattern 1: Extension-Based Algorithm Detection
**What:** Map file extension to hash algorithm using the same ordered map as `Get-PreferredSidecar`
**When to use:** Every time a hash-extension file is identified
**Example:**
```powershell
# Source: VeriHash.Core/Private/Get-PreferredSidecar.ps1 (existing pattern)
$algoMap = [ordered]@{
    '.sha512' = 'SHA512'
    '.sha256' = 'SHA256'
    '.md5'    = 'MD5'
}
$ext = [System.IO.Path]::GetExtension($SidecarPath).ToLowerInvariant()
$algorithm = $algoMap[$ext]
```

### Pattern 2: Companion Resolution (GNU format + bare hash fallback)
**What:** Determine the companion file from the sidecar content
**When to use:** After reading a single-line sidecar
**Example:**
```powershell
# Source: Design from sidecar-autodetect-exploration.md + Read-SidecarLine pattern
$parsed = Read-SidecarLine -Line $line
if ($null -ne $parsed -and $parsed.Filename) {
    # GNU format: hash *filename or hash  filename
    $companionName = $parsed.Filename
} else {
    # Bare hash: strip extension from sidecar filename
    # e.g., file.iso.sha256 → file.iso
    $companionName = [System.IO.Path]::GetFileNameWithoutExtension($sidecarLeaf)
}
# Resolve relative to sidecar directory (SIDE-03)
$companionPath = Join-Path $sidecarDir $companionName
```

### Pattern 3: Unified Dispatch (SIDE-06)
**What:** Both `-Manifest` and non-Manifest paths converge for hash-extension files
**When to use:** VeriHash.ps1 dispatch modification
**Example:**
```powershell
# In VeriHash.ps1 — unified auto-detect regardless of -Manifest flag
$manifestExts = @('.sha256', '.sha512', '.md5')
$isSidecarCandidate = $FilePath.Count -eq 1 -and
    [System.IO.Path]::GetExtension($FilePath[0]).ToLowerInvariant() -in $manifestExts

if ($isSidecarCandidate) {
    # Auto-detect: same function handles both modes (SIDE-06)
    $result = Invoke-VeriHashSidecarDetect -Path $FilePath[0]
    # ... render result ...
} elseif ($Manifest) {
    # Non-hash-extension files in manifest mode → create manifest
    $result = New-VeriHashManifest -Path $FilePath
    # ...
} else {
    # Normal hash mode
    # ...
}
```

### Anti-Patterns to Avoid
- **Duplicating the algorithm map:** Don't define a second copy of the extension→algorithm mapping. Extract it into a shared helper or reference the existing `Get-PreferredSidecar` pattern.
- **Resolving companion relative to CWD:** Always use `Split-Path -Parent` on the resolved sidecar path. The existing `Test-VeriHashManifest` already demonstrates this pattern correctly.
- **Running full hot-path for sidecar verify:** D-01 explicitly forbids Authenticode, clipboard, and formatted report. The new function returns a focused result only.
- **Hard-failing on hash length mismatch:** D-04 says warn but still compare. Don't `throw` — emit a warning and proceed.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GNU format line parsing | Custom regex | `Read-SidecarLine` (existing private function) | Already handles both `hash *file` and `hash  file` formats [VERIFIED: Read-SidecarLine.ps1] |
| Hash computation | Manual stream hashing | `Get-VeriHashResult` (existing public function) | Handles timing, path resolution, returns typed result [VERIFIED: Get-VeriHashResult.ps1] |
| Multi-line manifest verify | Custom multi-entry loop | `Test-VeriHashManifest` (existing public function) | Already handles parse errors, path traversal, missing files, exit codes [VERIFIED: Test-VeriHashManifest.ps1] |
| Algorithm-from-hash-length | Manual switch | `ConvertTo-VeriHashAlgorithm` (existing private function) | Already handles md5/sha256/sha512 by length and prefix [VERIFIED: ConvertTo-VeriHashAlgorithm.ps1] |
| Extension→algorithm mapping | Hardcoded inline | Reuse pattern from `Get-PreferredSidecar` | Single source of truth for the 3 canonical extensions [VERIFIED: Get-PreferredSidecar.ps1] |

**Key insight:** This phase is primarily a routing/orchestration problem, not a computation problem. All the heavy-lifting primitives exist. The new code is glue logic with clear error handling.

## Common Pitfalls

### Pitfall 1: Read-SidecarLine returns $null for bare hashes
**What goes wrong:** `Read-SidecarLine` regex is `^([A-Fa-f0-9]+)\s+\*?(.+)$` — it requires whitespace + filename AFTER the hash. A bare hash line (just `abc123def...`) returns `$null`.
**Why it happens:** The regex expects GNU format. Bare-hash sidecars (no filename) are a valid real-world format.
**How to avoid:** When `Read-SidecarLine` returns `$null` but the line IS valid hex, treat as bare hash → strip extension from sidecar filename.
**Warning signs:** Test with a sidecar containing only `3eb53e022fc03d61dffe2aff3244103daef28166b9c538cabbf04462fa59c775` (no filename).

### Pitfall 2: Read-ManifestLine only accepts 64-char SHA256 hashes
**What goes wrong:** The N-line path routes to `Test-VeriHashManifest` which uses `Read-ManifestLine`. That function's regex is strict: `^([0-9a-fA-F]{64})[ ](\*| )(.+)$` — it ONLY matches 64-char hashes.
**Why it happens:** `Test-VeriHashManifest` was built for SHA256-only manifests (v2.0 scope).
**How to avoid:** For Phase 6, the N-line path routes to `Test-VeriHashManifest` as-is. This means multi-line `.sha512` or `.md5` files will produce parse errors. This is acceptable for Phase 6 scope — multi-algorithm manifest support is NOT in requirements. Document this limitation.
**Warning signs:** A multi-line `.sha512` file routed to manifest verify will fail with parse errors due to 128-char hash not matching the 64-char regex.

### Pitfall 3: VeriHash.ps1 dispatch order breaks SIDE-06
**What goes wrong:** If auto-detect only appears in the hash-mode branch (`else` block), passing `-Manifest` with a single-line `.sha256` still goes through `Test-VeriHashManifest` directly (manifest mode branch), bypassing the auto-detect.
**Why it happens:** Current VeriHash.ps1 has separate `if ($Manifest)` and `else` branches.
**How to avoid:** Auto-detect check must come FIRST in the dispatch, BEFORE the `if ($Manifest)` branch. If the file matches a hash extension and is a single file, auto-detect takes priority regardless of `-Manifest`.
**Warning signs:** Test both `VeriHash.ps1 file.sha256` and `VeriHash.ps1 file.sha256 -Manifest` — behavior must be identical.

### Pitfall 4: Blank lines vs whitespace-only lines in sidecar
**What goes wrong:** `[string]::IsNullOrWhiteSpace()` treats `"   "` as blank but `$line -ne ''` does not.
**Why it happens:** Inconsistent blank-line filtering.
**How to avoid:** Use `[string]::IsNullOrWhiteSpace()` consistently (matches `Read-ManifestLine`'s pattern).
**Warning signs:** A sidecar file with trailing whitespace-only lines being counted as content lines.

### Pitfall 5: FunctionsToExport not updated in .psd1
**What goes wrong:** New public function exists in `Public/` folder but module doesn't export it.
**Why it happens:** `VeriHash.Core.psd1` has an explicit `FunctionsToExport` list (not wildcard).
**How to avoid:** Add `'Invoke-VeriHashSidecarDetect'` to the `FunctionsToExport` array in `VeriHash.Core.psd1`.
**Warning signs:** Function not found when calling from VeriHash.ps1 despite being in the Public folder.

## Code Examples

Verified patterns from the existing codebase:

### Reading and filtering sidecar file lines
```powershell
# Pattern from Test-VeriHashManifest.ps1 (uses [System.IO.File]::ReadAllLines for reliability)
$resolvedSidecar = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
$sidecarDir = Split-Path -Parent $resolvedSidecar
$rawLines = [System.IO.File]::ReadAllLines($resolvedSidecar)
$lines = $rawLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
```

### Extension-to-algorithm mapping (reuse pattern)
```powershell
# Source: VeriHash.Core/Private/Get-PreferredSidecar.ps1
$algoMap = [ordered]@{
    '.sha512' = 'SHA512'
    '.sha256' = 'SHA256'
    '.md5'    = 'MD5'
}
$ext = [System.IO.Path]::GetExtension($resolvedSidecar).ToLowerInvariant()
$algorithm = $algoMap[$ext]
# If $algorithm is $null, the file isn't a recognized sidecar (shouldn't happen if pre-filtered)
```

### Focused sidecar verify result object (new, follows existing PSTypeName pattern)
```powershell
# Follows VeriHash.Result pattern from Get-VeriHashResult.ps1
[pscustomobject]@{
    PSTypeName    = 'VeriHash.SidecarVerifyResult'
    SidecarPath   = $resolvedSidecar
    CompanionPath = $companionPath
    Algorithm     = $algorithm
    ExpectedHash  = $expectedHash
    ActualHash    = $actualHash
    Status        = $status   # 'pass' | 'mismatch'
    ElapsedMs     = [int]$sw.ElapsedMilliseconds
    Warning       = $warning  # hash length mismatch message or $null
}
```

### Hash length validation with warning (D-04)
```powershell
# Expected lengths per algorithm
$expectedLengths = @{ 'MD5' = 32; 'SHA256' = 64; 'SHA512' = 128 }
$expectedLen = $expectedLengths[$algorithm]
$warning = $null
if ($expectedHash.Length -ne $expectedLen) {
    $warning = "Unexpected hash length: expected $expectedLen chars for $algorithm, got $($expectedHash.Length)"
    Write-Warning $warning
}
```

### Complete new function skeleton
```powershell
function Invoke-VeriHashSidecarDetect {
    <#
    .SYNOPSIS
        Auto-detects sidecar vs manifest intent for a hash-extension file.
    .DESCRIPTION
        Reads a .sha256/.sha512/.md5 file:
        - 0 non-blank lines → error (SIDE-05)
        - 1 non-blank line → sidecar verify (SIDE-01, SIDE-02, SIDE-03, SIDE-04)
        - N non-blank lines → delegates to Test-VeriHashManifest (SIDE-01)
        Companion resolution: GNU format → filename from line; bare hash →
        strip extension from sidecar filename (SIDE-02).
    .PARAMETER Path
        Path to the hash-extension sidecar/manifest file.
    .OUTPUTS
        VeriHash.SidecarVerifyResult (1-line) or VeriHash.ManifestVerifyResult (N-line)
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.SidecarVerifyResult', 'VeriHash.ManifestVerifyResult')]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    # ... implementation
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hash-extension file → hash the text file | Auto-detect → verify companion | Phase 6 (this phase) | Core UX fix — the entire point of this phase |
| Separate manifest-mode and hash-mode paths for .sha256 | Unified: auto-detect regardless of -Manifest | Phase 6 (SIDE-06) | Eliminates user confusion about when to use -Manifest |
| `Test-VeriHashSidecar` direction: target → sidecar | New direction: sidecar → target (reverse) | Phase 6 | Existing function finds sidecars adjacent to target; new function starts FROM the sidecar |

**Key architectural note:** `Test-VeriHashSidecar` (existing) works in the OPPOSITE direction — you pass it a target file and it discovers adjacent sidecars. Phase 6 works from sidecar → companion. These are complementary, not competing. The existing function continues to serve the hot-path; the new function serves the auto-detect use case.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Multi-line `.sha512` files will produce parse errors when routed to `Test-VeriHashManifest` (because `Read-ManifestLine` only accepts 64-char hashes) | Common Pitfalls §2 | LOW — edge case for Phase 6; multi-algorithm manifest support is out of scope |
| A2 | The function name `Invoke-VeriHashSidecarDetect` follows PowerShell verb-noun convention and fits the module's naming pattern | Architecture Patterns | LOW — name is agent's discretion; can be adjusted |
| A3 | `VeriHash.SidecarVerifyResult` is the appropriate PSTypeName for the new result object | Code Examples | LOW — naming is agent's discretion |

**All other claims are verified from codebase inspection.**

## Open Questions (RESOLVED)

1. **Should Invoke-VeriHashSidecarDetect return the manifest result directly or a wrapped result?**
   - What we know: For N-line path, it delegates to `Test-VeriHashManifest` which returns `VeriHash.ManifestVerifyResult`. For 1-line path, it returns a new `VeriHash.SidecarVerifyResult`.
   - What's unclear: Should the function return two different types (output type union) or wrap both in a common envelope?
   - RESOLVED: Return different types — PowerShell handles polymorphic returns naturally, and the CLI can inspect `PSTypeName` to render appropriately. This matches existing patterns (e.g., `Get-PreferredSidecar` returns `$null` or object).

2. **Should the VeriHash.ps1 output for sidecar verify be minimal text or reuse Format-VeriHashReport?**
   - What we know: D-01 says "focused verify — show pass/fail result only". Format-VeriHashReport generates a full sectioned report.
   - What's unclear: Exact output format (single line? few lines?).
   - RESOLVED: Minimal output — companion path, algorithm, status (PASS/FAIL), and computed hash. Don't use Format-VeriHashReport. Phase 7 (Output Formatting) can enhance this later.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Pester 5.7.1 |
| Config file | None — inline `New-PesterConfiguration` in Test-All.ps1 |
| Quick run command | `Invoke-Pester -Path "Tests/VeriHash.Core.Invoke-VeriHashSidecarDetect.Tests.ps1" -Output Detailed` |
| Full suite command | `.\Test-All.ps1 -SkipProfiler` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SIDE-01 | 1-line sidecar → verify companion; N-line → manifest verify | unit | `Invoke-Pester -Path "Tests/VeriHash.Core.Invoke-VeriHashSidecarDetect.Tests.ps1" -Output Detailed` | ❌ Wave 0 |
| SIDE-02 | GNU format → filename from line; bare hash → strip extension | unit | Same as above | ❌ Wave 0 |
| SIDE-03 | Companion resolved relative to sidecar dir, not CWD | unit | Same as above (test with Push-Location to different dir) | ❌ Wave 0 |
| SIDE-04 | Error when companion doesn't exist | unit | Same as above | ❌ Wave 0 |
| SIDE-05 | Error when sidecar file is empty | unit | Same as above | ❌ Wave 0 |
| SIDE-06 | Identical behaviour with/without -Manifest | integration | `Invoke-Pester -Path "Tests/VeriHash.Cli.SidecarAutoDetect.Tests.ps1" -Output Detailed` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `Invoke-Pester -Path "Tests/VeriHash.Core.Invoke-VeriHashSidecarDetect.Tests.ps1" -Output Detailed`
- **Per wave merge:** `.\Test-All.ps1 -SkipProfiler -CI`
- **Phase gate:** Full suite green before verify

### Wave 0 Gaps
- [ ] `Tests/VeriHash.Core.Invoke-VeriHashSidecarDetect.Tests.ps1` — covers SIDE-01 through SIDE-05 (unit tests)
- [ ] `Tests/VeriHash.Cli.SidecarAutoDetect.Tests.ps1` — covers SIDE-06 (E2E integration via VeriHash.ps1)
- [ ] Test fixtures: single-line GNU format `.sha256`, single-line bare hash `.sha256`, multi-line `.sha256`, empty `.sha256`

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | Validate hex chars in hash string; validate extension before processing |
| V6 Cryptography | no | Uses system Get-FileHash (not hand-rolled) |

### Known Threat Patterns for this phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path traversal in GNU format filename | Tampering | Companion resolved relative to sidecar dir; do NOT allow `../` in companion name (follow Test-VeriHashManifest's `Test-PathTraversal` pattern) |
| Sidecar file with malicious content read as path | Information Disclosure | Only extract filename from parsed GNU format; bare hash fallback uses sidecar's own filename (no user-controlled path injection) |

**Note:** The path traversal concern is critical. When `Read-SidecarLine` extracts a filename from a GNU format line like `hash *../../etc/shadow`, the companion path must be validated. Recommendation: reuse `Test-PathTraversal` from VeriHash.Manifest or apply the same guard pattern (reject `../` and absolute paths in the companion name).

## Sources

### Primary (HIGH confidence)
- `VeriHash.Core/Private/Read-SidecarLine.ps1` — GNU format regex, return structure
- `VeriHash.Core/Private/Get-PreferredSidecar.ps1` — Extension→algorithm ordered map
- `VeriHash.Core/Public/Get-VeriHashResult.ps1` — Hash computation API
- `VeriHash.Core/Public/Test-VeriHashSidecar.ps1` — Existing reverse-direction sidecar verify
- `VeriHash.Manifest/Public/Test-VeriHashManifest.ps1` — Manifest verify (N-line target)
- `VeriHash.Manifest/Private/Read-ManifestLine.ps1` — Strict 64-char regex limitation
- `VeriHash.ps1` lines 152-196 — Current dispatch structure
- `.planning/notes/sidecar-autodetect-exploration.md` — Design spec
- `.planning/phases/6-sidecar-autodetect/06-CONTEXT.md` — User decisions
- `Tests/VeriHash.Core.Test-VeriHashSidecar.Tests.ps1` — Existing test patterns
- `Tests/VeriHash.Cli.Tests.ps1` — CLI E2E test patterns

### Secondary (MEDIUM confidence)
- `.planning/codebase/TESTING.md` — Test conventions (slightly stale references to v1 files but patterns are current)

### Tertiary (LOW confidence)
- None — all claims verified from codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries/modules verified in codebase, versions confirmed
- Architecture: HIGH — existing patterns clearly documented in code, integration points identified with line numbers
- Pitfalls: HIGH — each pitfall verified against actual regex patterns and function signatures in the codebase

**Research date:** 2026-04-19
**Valid until:** 2026-05-19 (stable — internal project, no external dependency changes expected)
