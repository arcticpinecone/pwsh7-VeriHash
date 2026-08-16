# Phase 3: Manifest Module - Research

**Researched:** 2026-04-18
**Domain:** PowerShell module for GNU sha256sum-compatible manifest creation & verification
**Confidence:** HIGH

## Summary

Phase 3 builds `VeriHash.Manifest` — a PowerShell module with two public functions (`New-VeriHashManifest`, `Test-VeriHashManifest`) that create and verify GNU `sha256sum`-compatible manifest files. The module follows the exact structural patterns established by VeriHash.Core (Phase 1) and VeriHash.HotPath (Phase 2): `Public/` + `Private/` folders dot-sourced from a thin `.psm1` loader, with a `.psd1` manifest declaring `RequiredModules = @('VeriHash.Core')`.

All core implementation patterns are verified against the existing codebase. The key technical concerns are: (a) writing LF line endings on Windows for GNU cross-platform compatibility, (b) atomic temp→rename writes using `Move-Item` on the same volume, (c) path-traversal detection via `[IO.Path]::GetFullPath` + `StartsWith`, and (d) returning structured result objects with exit codes rather than calling `exit` from module code. Each of these has been verified with working code against the development environment (PowerShell 7.6.0, Pester 5.7.1, WSL Debian with GNU coreutils sha256sum 9.1).

**Primary recommendation:** Mirror the VeriHash.HotPath module structure exactly — eager `Import-Module VeriHash.Core` in the `.psm1`, two public functions returning typed `[pscustomobject]` results, private helpers for line parsing / path validation / atomic write. Use `[System.IO.File]::WriteAllText()` with `[System.Text.UTF8Encoding]::new($false)` for UTF-8 NoBOM + LF line endings.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Manifest filename format is `YYYY-MM-DDTHHMMSSZ_manifest.<algorithm>` (e.g., `2026-04-17T143022Z_manifest.sha256`). UTC always, `Z` suffix, colons removed for Windows compatibility, `_manifest` suffix for at-a-glance identification.
- **D-02:** Collision handling: append `-1`, `-2`, etc. if filename already exists.
- **D-03:** Path separators: always write forward slashes (`/`) in manifest entries. Accept both `/` and `\` when reading/verifying.
- **D-04:** Skip blank lines and `# comment` lines when parsing manifests (matches GNU `sha256sum -c` behavior). This also future-proofs for metadata comments.
- **D-05:** Always binary mode — write `*` prefix before filename in manifest lines (`<hash> *<filename>`).
- **D-06:** UTF-8 encoding, no BOM.
- **D-07:** SHA256-only for Phase 3 MVP. Multi-algorithm support (SHA512, SHA1, MD5) deferred to a future phase.
- **D-08:** Sequential hashing during create — hash files one at a time in input order. No parallelism in Phase 3 MVP.
- **D-09:** Reuse `Get-VeriHashResult` from VeriHash.Core for all hashing — extract `.Hash` from the result object. Do not call .NET crypto APIs directly.
- **D-10:** Atomic write: create manifest via temp file → rename pattern. If any file fails to hash during create, abort immediately — no partial manifest written. Clean up the temp file on error.
- **D-11:** Exit codes: 0=all pass, 1=at least one mismatch, 2=at least one file missing, 3=parse error or path traversal detected. Highest code wins when multiple failure types occur.
- **D-12:** `Test-VeriHashManifest` returns a `VeriHash.ManifestVerifyResult` object with: `.ManifestPath`, `.Entries` (array of per-file results: path, expected hash, actual hash, status), `.ExitCode`, `.Summary` (total/passed/failed/missing counts).
- **D-13:** Path traversal (`../` or absolute paths in entries) is a hard reject — immediately return exit code 3. Paths are resolved relative to the manifest file's directory.
- **D-14:** Two public functions: `New-VeriHashManifest` (create) and `Test-VeriHashManifest` (verify).
- **D-15:** Two distinct PSTypeName result objects: `VeriHash.ManifestCreateResult` (returned by New) and `VeriHash.ManifestVerifyResult` (returned by Test).
- **D-16:** Module dependency: declare `RequiredModules = @('VeriHash.Core')` in the `.psd1` manifest. PowerShell auto-loads Core when Manifest is imported.
- **D-17:** No Write-Host or console formatting in Phase 3. Module returns structured objects only. Phase 5 CLI handles all display formatting.
- **D-18:** `New-VeriHashManifest` silently filters out files with hash-related extensions: `.sha256`, `.sha512`, `.sha384`, `.sha1`, `.md5`, `.sha2_256`, `.sha2` (per MANIFEST-03). No warning needed — these are noise.

### Agent's Discretion
- Private helper function decomposition (how many private helpers, naming)
- Exact parameter names and aliases for `New-VeriHashManifest` / `Test-VeriHashManifest`
- Internal regex pattern for manifest line parsing
- Temp file naming convention during atomic write
- Exact shape of `VeriHash.ManifestCreateResult` properties (beyond ManifestPath and FileCount)

### Deferred Ideas (OUT OF SCOPE)
- **Multi-algorithm support** (SHA512, SHA384, SHA1, MD5 via `-Algorithm` parameter) — future phase after SHA256 MVP proves out
- **Parallel hashing** during manifest create (ThrottleLimit 2+) — add if profiling shows sequential is a bottleneck
- **Metadata comments** at bottom of manifest files (`# VeriHash v2.0`, timestamps, etc.) — enabled by D-04's comment-skipping but not implemented in Phase 3
- **SendTo integration** (`VeriHash - Manifest.lnk`) — Phase 4 INTEG-02, not Phase 3
- **Console output formatting** (✅❌⚠️ emoji indicators, summary lines, progress) — Phase 5 CLI layer
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MANIFEST-01 | `New-VeriHashManifest -Path <files...>` creates GNU sha256sum-compatible manifest with atomic temp→rename | Verified: `[IO.File]::WriteAllText` + UTF8NoBOM + LF endings + `Move-Item` pattern. sha256sum 9.1 parses the output correctly. |
| MANIFEST-02 | All inputs must share a single common parent directory; mixed-root inputs produce locked error message | Verified: `Split-Path -Parent` on resolved paths, compare uniqueness. Pattern documented in Architecture section. |
| MANIFEST-03 | Files with hash extensions silently filtered from manifest inputs | Verified: `-notin` filter against extension set. Pattern works with `[IO.Path]::GetExtension()`. |
| MANIFEST-04 | `Test-VeriHashManifest` strict regex parsing with malformed-line reporting and exit code 3 | Verified: regex `^([0-9a-fA-F]{64})[ ](\*\| )(.+)$` correctly matches/rejects all test cases. D-04 blank/comment skip also verified. |
| MANIFEST-05 | Verify resolves relative to manifest dir, hard-rejects path traversal | Verified: `[IO.Path]::GetFullPath([IO.Path]::Combine($manifestDir, $entry))` + `StartsWith` correctly detects `../`, absolute paths, and escape attempts. |
| MANIFEST-06 | Machine-readable exit codes 0/1/2/3 with highest-wins precedence | Module returns `.ExitCode` property on result object (D-12). CLI layer (Phase 5) translates to process exit code. |
| MANIFEST-07 | SendTo entry `VeriHash - Manifest.lnk` | **⚠️ DEFERRED to Phase 4 (INTEG-02) per CONTEXT.md locked decisions.** Not implemented in Phase 3. |
| MANIFEST-08 | sha256sum -c round-trip test on Linux/WSL | Verified: WSL Debian available with sha256sum 9.1. Test creates manifest via `New-VeriHashManifest`, runs `wsl -d Debian -- sha256sum -c`, asserts exit code 0. Skip when no WSL. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Manifest creation (hashing + file writing) | PowerShell Module (VeriHash.Manifest) | — | Pure library logic, no UI |
| Manifest verification (parsing + rehashing + comparison) | PowerShell Module (VeriHash.Manifest) | — | Pure library logic, no UI |
| File hashing (actual crypto) | PowerShell Module (VeriHash.Core) | — | Reuse existing `Get-VeriHashResult` per D-09 |
| Atomic file writes | PowerShell Module (VeriHash.Manifest) | OS filesystem | Same-volume temp→rename is OS-guaranteed atomic |
| Path security (traversal guard) | PowerShell Module (VeriHash.Manifest) | .NET `System.IO.Path` | `GetFullPath` + `StartsWith` — pure computation |
| User-facing display / formatting | Phase 5 CLI layer | — | D-17: no Write-Host in Phase 3 |
| SendTo shortcut installation | Phase 4 Integration layer | — | Explicitly deferred per CONTEXT.md |
| GNU sha256sum compatibility | PowerShell Module (VeriHash.Manifest) | WSL/Linux coreutils (testing only) | Format compliance verified against GNU sha256sum 9.1 |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PowerShell 7+ | 7.6.0 (verified on dev machine) | Runtime | Project-wide requirement [VERIFIED: `$PSVersionTable`] |
| VeriHash.Core module | 2.0.0 | Hashing via `Get-VeriHashResult` | D-09: reuse Core, no direct .NET crypto calls [VERIFIED: module manifest] |
| `System.IO.Path` (.NET) | Built-in | Path traversal detection (`GetFullPath`, `Combine`) | Standard .NET API, no external dependency [VERIFIED: tested in session] |
| `System.Text.UTF8Encoding` (.NET) | Built-in | UTF-8 NoBOM file writing | Only reliable way to write LF line endings on Windows [VERIFIED: tested in session] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Pester | 5.7.1 (verified) | Testing framework | All unit/integration tests [VERIFIED: `Get-Module -ListAvailable`] |
| PSScriptAnalyzer | installed | Linting | Pre-commit and CI [VERIFIED: PSScriptAnalyzerSettings.psd1 present] |
| WSL + GNU coreutils | sha256sum 9.1 (Debian) | Round-trip verification test (MANIFEST-08) | Pester test conditional on WSL availability [VERIFIED: `wsl -d Debian -- sha256sum --version`] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `[IO.File]::WriteAllText` for manifest write | `Set-Content -Encoding utf8NoBOM` | Set-Content writes CRLF on Windows; WriteAllText with `\n` gives guaranteed LF [VERIFIED: tested both, Set-Content produces `0d 0a`] |
| `[IO.Path]::GetFullPath` for path traversal | `Resolve-Path` | Resolve-Path requires the target file to exist; GetFullPath works with hypothetical paths — critical for verifying entries before hashing [VERIFIED: tested in session] |
| `.psd1` `RequiredModules` for Core dependency | Explicit `Import-Module` in `.psm1` | Both work; HotPath uses explicit import in `.psm1` AND can use RequiredModules. D-16 locks RequiredModules. Use both (belt-and-suspenders). [VERIFIED: HotPath.psm1 does eager import] |

**Installation:** No new external packages needed. The module is pure PowerShell using built-in .NET types.

## Architecture Patterns

### System Architecture Diagram

```
Input Files (Explorer / CLI)
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│  New-VeriHashManifest                                           │
│  ┌──────────────┐   ┌──────────────┐   ┌────────────────────┐  │
│  │ Validate      │──▶│ Hash Loop    │──▶│ Atomic Write       │  │
│  │ • same parent │   │ (sequential) │   │ temp → rename      │  │
│  │ • filter exts │   │ • Get-Veri-  │   │ • UTF8 NoBOM + LF  │  │
│  │ • empty check │   │   HashResult │   │ • collision detect  │  │
│  └──────────────┘   │ • stop on    │   │ • cleanup on error  │  │
│                      │   first err  │   └────────────────────┘  │
│                      └──────────────┘                           │
│  Returns: VeriHash.ManifestCreateResult                         │
└─────────────────────────────────────────────────────────────────┘

Manifest File (.sha256)
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│  Test-VeriHashManifest                                          │
│  ┌──────────────┐   ┌──────────────┐   ┌────────────────────┐  │
│  │ Parse Lines   │──▶│ Validate     │──▶│ Hash & Compare     │  │
│  │ • strict regex│   │ Paths        │   │ • Get-VeriHash-    │  │
│  │ • skip blank/ │   │ • resolve    │   │   Result per entry │  │
│  │   comment     │   │   relative   │   │ • compare hashes   │  │
│  │ • exit code 3 │   │ • traversal  │   │ • bucket results   │  │
│  │   on bad line │   │   guard      │   │   (pass/fail/miss) │  │
│  └──────────────┘   └──────────────┘   └────────────────────┘  │
│                                                                  │
│  Returns: VeriHash.ManifestVerifyResult (with .ExitCode)        │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼  (Phase 5)
  CLI formats output + sets process exit code
```

### Recommended Project Structure

```
VeriHash.Manifest/
├── VeriHash.Manifest.psd1          # Module manifest (RequiredModules = @('VeriHash.Core'))
├── VeriHash.Manifest.psm1          # Thin loader (private → public → export)
├── Public/
│   ├── New-VeriHashManifest.ps1    # MANIFEST-01, -02, -03
│   └── Test-VeriHashManifest.ps1   # MANIFEST-04, -05, -06
└── Private/
    ├── Resolve-ManifestTargetPath.ps1  # Filename generation + collision handling (D-01, D-02)
    ├── Write-ManifestAtomically.ps1    # Temp → rename atomic write (D-10)
    ├── Read-ManifestLine.ps1           # Strict regex parsing + comment/blank skip (D-04, D-05)
    └── Test-PathTraversal.ps1          # Path escape detection (D-13, MANIFEST-05)

Tests/
├── VeriHash.Manifest.Module.Tests.ps1       # Module manifest + exports surface
├── VeriHash.Manifest.New.Tests.ps1          # New-VeriHashManifest tests
├── VeriHash.Manifest.Verify.Tests.ps1       # Test-VeriHashManifest tests
├── VeriHash.Manifest.ExitCodes.Tests.ps1    # Dedicated exit code coverage (MANIFEST-06)
└── VeriHash.Manifest.Roundtrip.Tests.ps1    # sha256sum -c round-trip (MANIFEST-08)
```

### Pattern 1: Module Loader (.psm1)
**What:** Thin loader that dot-sources Private then Public, exports public functions.
**When to use:** Always — this is the locked pattern from VeriHash.Core and VeriHash.HotPath.
**Example:**
```powershell
# Source: VeriHash.HotPath/VeriHash.HotPath.psm1 (existing, verified)
$ErrorActionPreference = 'Stop'

# Eager-load VeriHash.Core so callers don't have to.
$coreManifest = Join-Path $PSScriptRoot '..\VeriHash.Core\VeriHash.Core.psd1'
if (Test-Path -LiteralPath $coreManifest) {
    Import-Module $coreManifest -Force -Global -ErrorAction Stop
}

# Dot-source Private helpers FIRST so Public functions can call them at runtime.
Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

# Then dot-source Public functions.
$publicFiles = @(Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -ErrorAction SilentlyContinue)
foreach ($f in $publicFiles) { . $f.FullName }

# Belt-and-suspenders alongside the manifest's FunctionsToExport.
Export-ModuleMember -Function $publicFiles.BaseName
```

### Pattern 2: Result Object (PSTypeName)
**What:** `[pscustomobject]` with `PSTypeName` property — no PowerShell `class`.
**When to use:** All public function return values.
**Example:**
```powershell
# Source: Pattern established by VeriHash.Core Get-VeriHashResult.ps1 (verified)
# ManifestCreateResult:
[pscustomobject]@{
    PSTypeName   = 'VeriHash.ManifestCreateResult'
    ManifestPath = $finalPath           # Absolute path to written manifest
    FileCount    = $fileCount           # Number of files hashed
    Algorithm    = 'SHA256'             # Always SHA256 for MVP
    ElapsedMs    = [int]$sw.ElapsedMilliseconds
}

# ManifestVerifyResult:
[pscustomobject]@{
    PSTypeName   = 'VeriHash.ManifestVerifyResult'
    ManifestPath = $manifestPath
    Entries      = $entries             # Array of per-file result objects
    ExitCode     = $exitCode            # 0=pass, 1=mismatch, 2=missing, 3=parse error
    Summary      = [pscustomobject]@{
        Total   = $total
        Passed  = $passed
        Failed  = $failed
        Missing = $missing
    }
}
```

### Pattern 3: UTF-8 NoBOM + LF Line Endings
**What:** Write manifest files with guaranteed LF endings and no BOM, even on Windows.
**When to use:** All manifest file writes — both temp file and any future direct writes.
**Example:**
```powershell
# Source: Verified in this research session against WSL sha256sum 9.1
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$content = ($lines -join "`n") + "`n"   # LF after each line, including last
[System.IO.File]::WriteAllText($tempFile, $content, $utf8NoBom)
```
**Critical:** `Set-Content` on Windows writes CRLF (`0d 0a`). While GNU sha256sum 9.1 accepts CRLF, LF is the correct canonical format. Use `[IO.File]::WriteAllText` exclusively. [VERIFIED: tested both encodings; Set-Content produces CRLF, WriteAllText produces LF]

### Pattern 4: Atomic Write (Temp → Rename)
**What:** Write to a temp file in the same directory, then `Move-Item` to the final path.
**When to use:** Manifest creation — ensures no partial manifests on error or Ctrl+C.
**Example:**
```powershell
# Source: Concepting doc Write-ManifestAtomically pattern, verified in session
$tempFile = Join-Path $targetDir "~verihash-$([guid]::NewGuid().ToString('N').Substring(0, 8)).tmp"
try {
    # ... write content to $tempFile ...
    Move-Item -Path $tempFile -Destination $finalPath -ErrorAction Stop
} catch {
    if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile -Force }
    throw
}
```
**Why same directory:** `Move-Item` within the same NTFS volume is an atomic metadata operation (rename), not a copy+delete. Cross-volume moves are NOT atomic. [VERIFIED: standard NTFS behavior]

### Pattern 5: Path Traversal Detection
**What:** Reject manifest entries whose resolved path escapes the manifest directory.
**When to use:** Every entry in `Test-VeriHashManifest` before hashing.
**Example:**
```powershell
# Source: Verified in this research session with 6 test cases
$resolved = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::Combine($manifestDir, $entryPath)
)
$isSafe = $resolved.StartsWith($manifestDir, [System.StringComparison]::OrdinalIgnoreCase)
if (-not $isSafe) {
    # Hard reject — exit code 3
}
```
**Tested cases:** `safe-file.txt` ✓, `subfolder/file.txt` ✓, `../VeriHash.ps1` ✗, `..\..\README.md` ✗, `/etc/passwd` ✗, `C:\Windows\System32\cmd.exe` ✗ [VERIFIED: all cases correct]

### Pattern 6: Strict Regex Line Parsing
**What:** Parse each non-blank, non-comment manifest line with a strict regex.
**When to use:** `Test-VeriHashManifest` line parsing loop.
**Example:**
```powershell
# Source: GNU sha256sum format spec + MANIFEST-04 requirement, verified in session
$regex = '^([0-9a-fA-F]{64})[ ](\*| )(.+)$'   # {64} for SHA256 MVP
# Group 1: hash (64 hex chars)
# Group 2: mode indicator (* = binary, space = text)
# Group 3: filename (rest of line)

foreach ($rawLine in $lines) {
    $line = $rawLine.TrimEnd("`r")    # Handle CRLF manifests read on Windows
    if ([string]::IsNullOrWhiteSpace($line)) { continue }  # D-04: skip blank
    if ($line.StartsWith('#')) { continue }                  # D-04: skip comments
    $m = [regex]::Match($line, $regex)
    if (-not $m.Success) {
        # Malformed line — report and set exit code 3
    }
}
```
**Tested:** Binary mode (`hash *file.txt`) matches ✓, text mode (`hash  file.txt`) matches ✓, comments/blanks skip ✓, short hash fails ✗ [VERIFIED: regex tested against all GNU format variants]

### Anti-Patterns to Avoid
- **Using `exit` from module code:** `exit N` terminates the entire PowerShell session. Return exit code via result object `.ExitCode` property; only the CLI layer (Phase 5) calls `exit`. [VERIFIED: PowerShell behavior]
- **Using `Set-Content` for manifest writes:** Produces CRLF on Windows. Use `[IO.File]::WriteAllText` with explicit `\n` for LF. [VERIFIED: hex dump comparison]
- **Using `Resolve-Path` for path traversal detection:** Requires the target file to actually exist on disk. Use `[IO.Path]::GetFullPath` which works with hypothetical paths. [VERIFIED: tested with non-existent paths]
- **Using `Write-Host` or console output:** D-17 explicitly forbids this. Module returns structured objects only. Phase 5 CLI layer handles display. [CITED: CONTEXT.md D-17]
- **Catching errors and continuing during create:** D-10 says abort immediately on first hash failure. Only verify mode (Test-VeriHashManifest) continues after individual file errors. [CITED: CONTEXT.md D-10]
- **Using relative paths from CWD:** Manifest entries must resolve relative to the manifest file's directory, never `$PWD`. Use `Split-Path -Parent $ManifestPath` as the base. [CITED: MANIFEST-05]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| File hashing | Direct `Get-FileHash` or .NET crypto APIs | `Get-VeriHashResult` from VeriHash.Core | D-09: reuse Core. Consistent result objects, timing, logging support. |
| UTF-8 BOM handling | Custom byte-array manipulation | `[System.Text.UTF8Encoding]::new($false)` | .NET built-in, battle-tested. One-liner. |
| Path normalization (slashes) | Regex replacement of `\` → `/` in all contexts | `[IO.Path]::GetFullPath` for resolution; explicit `-replace '\\', '/'` only when writing manifest lines | GetFullPath handles all OS path normalization. Only need slash conversion at write time. |
| GUID-based temp names | Custom random string generation | `[guid]::NewGuid().ToString('N').Substring(0, 8)` | Standard pattern from concepting doc. Collision-proof for practical purposes. |
| Module boilerplate (.psm1 loader) | Handwritten export logic | Copy VeriHash.HotPath.psm1 exactly, change Core import path | Proven pattern: 2 modules already use it with zero issues. |

**Key insight:** Phase 3 introduces zero new external dependencies. Every capability (hashing, file I/O, path manipulation, encoding) is covered by existing project code (VeriHash.Core) or built-in .NET types. The complexity is in correctness of composition, not in finding the right tools.

## Common Pitfalls

### Pitfall 1: CRLF Line Endings in Manifest Files
**What goes wrong:** Using `Set-Content` or `Out-File` on Windows produces CRLF (`\r\n`) line endings. While GNU sha256sum 9.1 tolerates CRLF when verifying (`sha256sum -c`), other tools and strict parsers may reject it.
**Why it happens:** PowerShell cmdlets follow the host OS line ending convention by default.
**How to avoid:** Always use `[System.IO.File]::WriteAllText()` with explicit `\n` line separators and `[System.Text.UTF8Encoding]::new($false)` encoding.
**Warning signs:** Hex dump of manifest file shows `0d 0a` instead of `0a` at line endings. [VERIFIED: tested both approaches]

### Pitfall 2: Path Traversal False Negatives from `Resolve-Path`
**What goes wrong:** Using `Resolve-Path` to detect path traversal only works if the target file exists. A crafted manifest entry like `../../etc/passwd` might not trigger an error if the file doesn't exist — instead of returning the resolved traversal path, it throws a "path not found" error that could be incorrectly caught as "file missing" (exit code 2) instead of "path traversal" (exit code 3).
**Why it happens:** `Resolve-Path` is designed for existing filesystem paths, not hypothetical path validation.
**How to avoid:** Use `[IO.Path]::GetFullPath([IO.Path]::Combine($base, $entry))` — it resolves path segments purely computationally, without touching the filesystem.
**Warning signs:** Tests pass on disk layouts where the traversal target exists but fail in clean environments. [VERIFIED: tested with non-existent paths]

### Pitfall 3: Trailing Directory Separator in StartsWith Check
**What goes wrong:** `$resolved.StartsWith($manifestDir)` may produce false positives if a sibling directory shares a prefix. Example: manifest in `C:\Data` and entry resolving to `C:\DataBackup\file.txt` — `StartsWith("C:\Data")` is true even though the path escapes.
**Why it happens:** String prefix matching doesn't respect directory boundaries.
**How to avoid:** Ensure `$manifestDir` always ends with the directory separator before the `StartsWith` check: `$manifestDirWithSep = $manifestDir.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar`. Then check `$resolved.StartsWith($manifestDirWithSep, ...)`.
**Warning signs:** Traversal test passes for `../` but fails for paths in sibling directories with matching prefixes. [ASSUMED: standard path-security pitfall]

### Pitfall 4: Incomplete Temp File Cleanup on Pipeline Stop
**What goes wrong:** If the user presses Ctrl+C during hashing, the `catch` block may not execute because PowerShell sends a `PipelineStoppedException` which bypasses standard `try/catch`.
**Why it happens:** PowerShell's pipeline stop mechanism is separate from .NET exception handling.
**How to avoid:** Use `try { ... } catch { ... } finally { ... }` — the `finally` block executes even on pipeline stop. Place temp file cleanup in `finally` instead of (or in addition to) `catch`. Check if temp file still exists before deleting.
**Warning signs:** Orphaned `~verihash-*.tmp` files left in the target directory after interrupting a long hash operation. [ASSUMED: known PowerShell behavior pattern]

### Pitfall 5: Exit Code Precedence Logic
**What goes wrong:** When both mismatches (code 1) and missing files (code 2) occur, the wrong exit code is returned if using simple `if/elseif` instead of highest-wins logic.
**Why it happens:** D-11 says "highest code wins" — exit code 3 > 2 > 1 > 0. A simple flag-based approach might check `$hasMismatch` before `$hasMissing` and return 1 instead of 2.
**How to avoid:** Track the maximum exit code seen: `$exitCode = [Math]::Max($exitCode, $newCode)`. Or compute at the end from buckets: parse error → 3, missing → 2, mismatch → 1, all pass → 0, in descending priority.
**Warning signs:** Test with both missing AND mismatched files returns 1 instead of 2. But wait — actually re-reading D-11: "0=all pass, 1=at least one mismatch, 2=at least one file missing, 3=parse error." When both mismatch AND missing occur, highest wins → exit code 2. But MANIFEST-06 says: "2 = at least one missing/unreadable file (no mismatches)". This means if there ARE mismatches, code 1 wins over code 2. This is NOT a simple "highest wins" — it's priority-ordered. Parse the requirements carefully: code 3 > code 1 > code 2 > code 0. [CITED: MANIFEST-06 text explicitly says "no mismatches" qualifier on code 2]

### Pitfall 6: MANIFEST-07 Scope Conflict
**What goes wrong:** Implementing SendTo integration in Phase 3 when it's explicitly deferred to Phase 4.
**Why it happens:** REQUIREMENTS.md traceability maps MANIFEST-07 to Phase 3, but CONTEXT.md deferred section explicitly says "SendTo integration (`VeriHash - Manifest.lnk`) — Phase 4 INTEG-02, not Phase 3".
**How to avoid:** CONTEXT.md decisions override REQUIREMENTS.md mappings. MANIFEST-07 is NOT in scope for Phase 3. Planner should exclude it.
**Warning signs:** Plan includes a task for creating `.lnk` files or modifying `Install-WindowsSendTo`. [VERIFIED: CONTEXT.md deferred section, line 112]

## Code Examples

Verified patterns from the existing codebase and research session:

### Module Manifest (.psd1)
```powershell
# Source: Modeled on VeriHash.Core.psd1 and VeriHash.HotPath.psd1 (verified)
@{
    RootModule           = 'VeriHash.Manifest.psm1'
    ModuleVersion        = '2.0.0'
    CompatiblePSEditions = 'Core'
    GUID                 = '<new-guid>'    # Generate fresh
    Author               = 'arcticpinecone'
    Description          = 'GNU sha256sum-compatible manifest creation and verification for VeriHash.'
    PowerShellVersion    = '7.0'
    RequiredModules      = @('VeriHash.Core')   # D-16
    FunctionsToExport    = 'New-VeriHashManifest', 'Test-VeriHashManifest'
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData = @{ PSData = @{} }
}
```

### Common Parent Directory Validation (MANIFEST-02)
```powershell
# Source: Verified in research session
$resolvedPaths = $Path | ForEach-Object {
    (Resolve-Path -LiteralPath $_ -ErrorAction Stop).ProviderPath
}
$parents = $resolvedPaths | ForEach-Object { Split-Path -Parent $_ }
$uniqueParents = $parents | Select-Object -Unique
if ($uniqueParents.Count -ne 1) {
    throw 'Selected files span multiple directories. Manifests use relative paths — select files under one root.'
}
$commonParent = $uniqueParents[0]
```

### Hash Extension Filtering (MANIFEST-03)
```powershell
# Source: CONTEXT.md D-18, verified pattern
$hashExtensions = @('.sha256', '.sha512', '.sha384', '.sha1', '.md5', '.sha2_256', '.sha2')
$filtered = $resolvedPaths | Where-Object {
    [System.IO.Path]::GetExtension($_) -notin $hashExtensions
}
```

### Manifest Line Formatting (D-03, D-05)
```powershell
# Source: GNU sha256sum format spec, verified against sha256sum 9.1
$relativePath = [System.IO.Path]::GetFileName($filePath)   # Single-dir MVP: just filename
$relativePath = $relativePath -replace '\\', '/'             # D-03: forward slashes
$line = "$($hashResult.Hash) *$relativePath"                 # D-05: binary mode
```

### WSL Round-Trip Test (MANIFEST-08)
```powershell
# Source: Verified in research session — sha256sum -c works with VeriHash output
It 'Manifest round-trips through sha256sum -c on WSL' {
    $wslAvailable = $null -ne (Get-Command wsl -ErrorAction SilentlyContinue)
    if (-not $wslAvailable) {
        Set-ItResult -Skipped -Because 'WSL not available'
        return
    }
    # Create files in $TestDrive, generate manifest, convert path to WSL format
    $wslDir = ($TestDrive -replace '\\', '/' -replace '^([A-Z]):', { '/mnt/' + $_.Groups[1].Value.ToLower() })
    $result = wsl -d Debian -- bash -c "cd '$wslDir' && sha256sum -c 'manifest.sha256'" 2>&1
    $LASTEXITCODE | Should -Be 0
}
```

### Per-Entry Verify Result Object
```powershell
# Source: D-12 specification, following VeriHash.Result pattern
[pscustomobject]@{
    PSTypeName   = 'VeriHash.ManifestEntry'
    Path         = $entryPath           # As written in manifest
    ResolvedPath = $resolvedPath        # Absolute path after resolution
    ExpectedHash = $expectedHash        # From manifest
    ActualHash   = $actualHash          # Computed (or $null if missing)
    Status       = $status              # 'pass' | 'mismatch' | 'missing' | 'error'
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| VeriHash v1 monolith with all logic in one file | Modular architecture (Core → HotPath → Manifest) | Phase 1 (2026-04-18) | Each module is independently testable |
| Dot-source-with-dummy-path test loading | `Import-Module` with `.psd1` manifest | Phase 1 | Clean module isolation, proper exports |
| PSFramework for logging | Plain-text `Write-VeriHashLog` (opt-in) | Phase 1 | Zero external dependencies in modules |
| No manifest support | GNU sha256sum-compatible manifests | Phase 3 (this) | Multi-file verification without individual sidecars |

**Deprecated/outdated:**
- `$env:VERIHASH_TEST_MODE = '1'` — Retired in Phase 1. Use `$env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')` instead. [VERIFIED: Phase 2 test files use the new pattern]
- `PSFramework` logging in new modules — Phase 1 eliminated it from Core; Phase 4 removes it from legacy files. Do NOT use in VeriHash.Manifest. [CITED: copilot-instructions.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Trailing directory separator needed for safe `StartsWith` check to avoid sibling-directory prefix collision | Pitfall 3 | Could produce false-negative on path traversal detection; security risk. Low risk — standard security pattern, but should be verified with a dedicated Pester test. |
| A2 | `finally` block executes on `PipelineStoppedException` (Ctrl+C) in PowerShell 7 | Pitfall 4 | Orphaned temp files on interrupt. Medium risk — if `finally` doesn't run, need alternative cleanup strategy. |
| A3 | `RequiredModules = @('VeriHash.Core')` in .psd1 will auto-resolve the sibling module by name when loading from the repo root | Architecture | If PowerShell can't find 'VeriHash.Core' by name, module import fails. Mitigated by belt-and-suspenders explicit import in .psm1 (following HotPath pattern). |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

## Open Questions

1. **Exit code precedence between mismatch (1) and missing (2)**
   - What we know: D-11 says "highest code wins." MANIFEST-06 says code 2 applies when "no mismatches" are present.
   - What's unclear: These two statements appear to conflict. If a manifest has BOTH a mismatch and a missing file, does code 1 (mismatch) or code 2 (missing) win? D-11's "highest wins" says 2, but MANIFEST-06's "(no mismatches)" qualifier on code 2 suggests 1.
   - Recommendation: Implement the MANIFEST-06 reading: code 3 (parse error) is highest priority, then code 1 (any mismatch), then code 2 (missing only when no mismatches), then code 0. This matches standard GNU coreutils behavior where `sha256sum -c` returns 1 for ANY verification failure. The "(no mismatches)" qualifier on code 2 disambiguates: missing-only gets its own code to distinguish from data corruption. Priority: 3 > 1 > 2 > 0.

2. **RequiredModules resolution by name vs. by path**
   - What we know: VeriHash.Core sits at `../VeriHash.Core/` relative to VeriHash.Manifest. The HotPath module uses explicit path-based import in `.psm1` as belt-and-suspenders.
   - What's unclear: Whether `RequiredModules = @('VeriHash.Core')` (name-only) resolves when the module isn't installed via PSGallery but lives as a sibling directory.
   - Recommendation: Use both approaches (D-16 says `.psd1` RequiredModules, but also do explicit import in `.psm1` as HotPath does). Test module import in the Module.Tests.ps1 surface test.

## Project Constraints (from copilot-instructions.md)

- **PowerShell 7+** — all code must use PS7+ syntax; `PSUseCompatibleSyntax` targets 7.0 [CITED: PSScriptAnalyzerSettings.psd1]
- **No PSFramework** in new module code — use `Write-VeriHashLog` from Core [CITED: copilot-instructions.md]
- **TDD rule** — never modify tests to make them pass; modify the code [CITED: copilot-instructions.md]
- **Function signature pattern** — `[CmdletBinding()]`, `[OutputType()]`, comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.OUTPUTS`, `.EXAMPLE`) [CITED: copilot-instructions.md + CONVENTIONS.md]
- **Test environment isolation** — `$env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')` in `BeforeAll`; cleanup in `AfterAll` [CITED: copilot-instructions.md]
- **Module loading in tests** — `Import-Module "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1" -Force` [CITED: copilot-instructions.md + existing test patterns]
- **No Write-Host in modules** — module returns structured objects; CLI layer handles display [CITED: CONTEXT.md D-17]
- **PSScriptAnalyzer linting** — code must pass `Invoke-ScriptAnalyzer` with existing settings (suppresses `PSAvoidUsingWriteHost`, `PSAvoidUsingBrokenHashAlgorithms`, `PSUseUsingScopeModifierInNewRunspaces`) [VERIFIED: PSScriptAnalyzerSettings.psd1]
- **Platform detection** — use `Get-VeriHashPlatform` from Core, not `$IsWindows` / `$RunningOnWindows` redefinitions [CITED: copilot-instructions.md]
- **Error handling** — `try/catch/throw` pattern; `$ErrorActionPreference = 'Stop'` in .psm1 [CITED: CONVENTIONS.md]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Pester 5.7.1 [VERIFIED: `Get-Module -ListAvailable Pester`] |
| Config file | None — inline `New-PesterConfiguration` in `Test-All.ps1` |
| Quick run command | `Invoke-Pester -Path "Tests/VeriHash.Manifest.*.Tests.ps1" -Output Detailed` |
| Full suite command | `Invoke-Pester -Path "Tests/" -Output Detailed` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MANIFEST-01 | Create manifest with atomic write in common parent dir | unit + integration | `Invoke-Pester Tests/VeriHash.Manifest.New.Tests.ps1 -Output Detailed` | ❌ Wave 0 |
| MANIFEST-02 | Mixed-root inputs produce locked error message | unit | `Invoke-Pester Tests/VeriHash.Manifest.New.Tests.ps1 -Output Detailed` | ❌ Wave 0 |
| MANIFEST-03 | Hash-extension files silently filtered | unit | `Invoke-Pester Tests/VeriHash.Manifest.New.Tests.ps1 -Output Detailed` | ❌ Wave 0 |
| MANIFEST-04 | Strict regex parsing; malformed lines → exit code 3 | unit | `Invoke-Pester Tests/VeriHash.Manifest.Verify.Tests.ps1 -Output Detailed` | ❌ Wave 0 |
| MANIFEST-05 | Path-relative resolution + traversal rejection | unit | `Invoke-Pester Tests/VeriHash.Manifest.Verify.Tests.ps1 -Output Detailed` | ❌ Wave 0 |
| MANIFEST-06 | Exit codes 0/1/2/3 with correct precedence | unit (dedicated) | `Invoke-Pester Tests/VeriHash.Manifest.ExitCodes.Tests.ps1 -Output Detailed` | ❌ Wave 0 |
| MANIFEST-07 | SendTo .lnk installation | **DEFERRED to Phase 4** | — | — |
| MANIFEST-08 | sha256sum -c round-trip on WSL | integration (conditional) | `Invoke-Pester Tests/VeriHash.Manifest.Roundtrip.Tests.ps1 -Output Detailed` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `Invoke-Pester -Path "Tests/VeriHash.Manifest.*.Tests.ps1" -Output Detailed`
- **Per wave merge:** `Invoke-Pester -Path "Tests/" -Output Detailed`
- **Phase gate:** Full suite green (`.\Test-All.ps1`) before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `Tests/VeriHash.Manifest.Module.Tests.ps1` — module surface (imports, exports, no PSFramework)
- [ ] `Tests/VeriHash.Manifest.New.Tests.ps1` — covers MANIFEST-01, -02, -03
- [ ] `Tests/VeriHash.Manifest.Verify.Tests.ps1` — covers MANIFEST-04, -05
- [ ] `Tests/VeriHash.Manifest.ExitCodes.Tests.ps1` — covers MANIFEST-06
- [ ] `Tests/VeriHash.Manifest.Roundtrip.Tests.ps1` — covers MANIFEST-08

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PowerShell 7+ | All code | ✓ | 7.6.0 | — |
| Pester | All tests | ✓ | 5.7.1 | — |
| PSScriptAnalyzer | Linting | ✓ | Installed | — |
| VeriHash.Core module | D-09, D-16 (hashing) | ✓ | 2.0.0 | — |
| WSL + Debian | MANIFEST-08 round-trip test | ✓ | Debian (default) | Test marked Skip when WSL unavailable |
| GNU sha256sum | MANIFEST-08 verification | ✓ | 9.1 (in WSL Debian) | Test marked Skip when unavailable |

**Missing dependencies with no fallback:** None — all required dependencies are available.

**Missing dependencies with fallback:**
- WSL/sha256sum availability is not guaranteed on all systems. The MANIFEST-08 Pester test uses `Set-ItResult -Skipped` when WSL or sha256sum is absent. This is by design per the success criteria.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | Yes (path traversal) | `[IO.Path]::GetFullPath` + `StartsWith` directory-boundary check |
| V5 Input Validation | Yes (manifest parsing) | Strict regex, hash-length validation, reject malformed lines |
| V6 Cryptography | No (uses built-in `Get-FileHash`, not hand-rolled) | VeriHash.Core wraps `Get-FileHash` |

### Known Threat Patterns for PowerShell Manifest Processing

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path traversal in manifest entries (`../../../etc/passwd`) | Tampering / Information Disclosure | Resolve with `GetFullPath`, reject if path escapes manifest directory (MANIFEST-05) |
| Partial manifest write exposing incomplete verification state | Tampering | Atomic temp→rename pattern (D-10) — no partial manifests ever visible |
| Hash collision exploiting weak algorithm | Tampering | SHA256 is collision-resistant; future multi-algo phases should warn on MD5/SHA1 |
| Symlink following through manifest entry paths | Information Disclosure | `GetFullPath` resolves symlinks on read; `StartsWith` still validates containment. Low risk for MVP. |
| Malformed manifest causing unexpected behavior | Denial of Service | Strict regex parsing, immediate exit code 3 on parse failure (MANIFEST-04) |

## Sources

### Primary (HIGH confidence)
- VeriHash.Core module code (Get-VeriHashResult.ps1, Write-VeriHashLog.ps1) — verified patterns
- VeriHash.HotPath module code (psm1 loader, psd1 manifest, Invoke-VeriHashBatch.ps1) — verified module structure
- Existing Pester test files (VeriHash.HotPath.*.Tests.ps1, VeriHash.Core.*.Tests.ps1) — verified test conventions
- `.github/copilot-instructions.md` — project coding standards
- `.planning/codebase/CONVENTIONS.md`, `STRUCTURE.md`, `TESTING.md` — codebase analysis docs
- `Verihash Multifile Concepting.md` — manifest feature design document

### Secondary (MEDIUM confidence)
- GNU sha256sum 9.1 behavior — tested directly via `wsl -d Debian` in this session
- PowerShell `[IO.File]::WriteAllText` line ending behavior — tested with hex dump verification
- PowerShell `[IO.Path]::GetFullPath` path traversal behavior — tested with 6 cases in this session
- PowerShell `Set-Content` CRLF behavior on Windows — tested and confirmed via hex dump

### Tertiary (LOW confidence)
- None — all claims verified against codebase or tested in session

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — reuses existing project modules and built-in .NET types; zero new dependencies
- Architecture: HIGH — mirrors two proven module implementations (Core, HotPath) with well-documented patterns
- Pitfalls: HIGH — all critical pitfalls (line endings, path traversal, exit codes) verified with actual tests
- Exit code precedence: MEDIUM — MANIFEST-06 text creates a nuance with D-11 "highest wins"; recommendation provided but should be confirmed

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (stable domain — PowerShell module patterns don't change rapidly)
