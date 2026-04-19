# VeriHash Manifest Feature — Concept & Design

**Date**: 2026-01-22 (Created) | 2026-04-17 (Revised)
**Status**: Planning Phase — Scope Locked for MVP
**Goal**: Multi-select files in Explorer → Send To → get a single manifest. Send To the manifest later → verify them all.

---

## Philosophy

VeriHash exists to make hash verification **fast, visual, and accessible**.
People skip hash checks because they're cumbersome; this tool removes that barrier.

The manifest feature extends this to **groups of files** — same philosophy, same right-click simplicity.

---

## Core Use Case

### The Problem

VeriHash handles one file at a time. When you download or transfer several files, you either:

- Create individual `.sha256` sidecars for each (tedious)
- Skip verification entirely (risky)

### The Solution

A **manifest file** — one GNU-standard index file covering multiple files:

```text
e3b0c44298fc1c14...b855 *report.pdf
5d41402abc4b2a76...c592 *setup.exe
a1b2c3d4e5f67890...1234 *readme.txt
```

Right-click → Send To → done. Right-click the manifest later → verified.

---

## Two Send To Entries

| Shortcut | Behavior |
| - | - |
| **VeriHash** (existing) | Single-file sidecar create/verify. Unchanged. |
| **VeriHash - Manifest** (new) | Multi-file manifest create or verify. |

The existing `VeriHash` shortcut is **not modified**. A second `.lnk` is added via `-SendTo`, passing a `-Manifest` flag.

---

## Input Routing (Manifest Mode)

When invoked with `-Manifest`:

### Multiple file paths (Create mode)

Explorer passes each selected file as a separate argument.

- All inputs must be **files** (not folders). If a folder is passed, error: *"Folder input not supported yet. Select files directly."*
- All files must share a **single common parent directory**. If they don't, error: *"Selected files span multiple directories. Manifests use relative paths — select files under one root."*
- Files with hash extensions (`.sha256`, `.sha512`, `.sha384`, `.sha1`, `.md5`, `.sha2_256`, `.sha2`) are silently filtered out — you can't hash metadata as content.

### Single `.sha256` / `.sha512` / `.md5` / `.sha1` / `.sha384` file (Verify mode)

- Parse the manifest and verify each entry against the files on disk.

### Single non-hash file

- Error: *"Manifest mode requires multiple files (to create) or a manifest file (to verify)."*

### No arguments

- Error with usage hint.

---

## Manifest File Format

### Format: GNU `sha256sum` standard

```text
<hash> *<filename>
```

- **Always binary mode** (`*` prefix) — VeriHash deals in bytes, not text.
- **Relative paths** from the manifest file's directory (since MVP = single directory, paths are just filenames).
- **Forward slashes** (`/`) in paths when writing, accept `\` when reading. This ensures `sha256sum -c` works cross-platform.
- **UTF-8, no BOM**. GNU tools, Linux, macOS, and modern Windows all handle this correctly.

### Algorithm Support

- **Default**: SHA256
- **Supported**: SHA256, SHA512, SHA384, SHA1, MD5
- **Extension reflects algorithm**: `.sha256`, `.sha512`, `.sha1`, `.md5`, etc.
- **CLI flag**: `-Algorithm <name>` (same as existing single-file behavior)

### Naming Convention

- **Pattern**: `YYYY-MM-DDTHHMMSSZ.<algorithm>`
- **Example**: `2026-04-17T143022Z.sha256`
- The `Z` suffix marks UTC explicitly (ISO-8601 compliant). Colons are illegal in Windows filenames, so compact form is used.
- **Collision handling**: If the name exists, append `-1`, `-2`, etc. Never overwrite unless `-Force`.

### Compatibility Target

The output must pass `sha256sum -c <manifest>` on Linux/WSL. This is the acceptance test for format correctness.

---

## Create Flow

1. **Validate inputs**: All files exist, all in same directory, none are hash files.
2. **Hash each file**: Sequential by default, or `ForEach-Object -Parallel -ThrottleLimit 2` to keep CPU polite.
3. **Write to temp file**: `~verihash-<8-char-guid>.tmp` in the common directory.
4. **On success**: Atomic rename (`Move-Item`) to `YYYY-MM-DDTHHMMSSZ.<alg>`.
5. **On Ctrl+C / error**: Delete temp file. No partial manifests left behind.
6. **Display summary**: File count, manifest path, any errors.

### Safe Write Implementation

```powershell
function Write-ManifestAtomically {
    param(
        [string]$FinalPath,
        [string[]]$Content
    )

    # Temp file in SAME directory = same NTFS volume = atomic rename
    $tempFile = Join-Path (Split-Path $FinalPath) "~verihash-$([guid]::NewGuid().ToString('N').Substring(0,8)).tmp"

    try {
        $Content | Set-Content -Path $tempFile -Encoding UTF8NoBOM -ErrorAction Stop

        # Collision handling
        $targetPath = $FinalPath
        $counter = 0
        while (Test-Path $targetPath) {
            $counter++
            $targetPath = $FinalPath -replace '(\.\w+)$', "-$counter`$1"
        }

        Move-Item -Path $tempFile -Destination $targetPath -ErrorAction Stop
        return $targetPath
    }
    catch {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        throw
    }
}
```

---

## Verify Flow

1. **Parse manifest**: Strict regex per line: `^([0-9a-fA-F]{32,128}) (\*| )(.+)$`
   - Reject lines that don't match.
   - Validate hash length for the algorithm (inferred from file extension: `.sha256` = 64 hex chars, etc.).
2. **Resolve paths** relative to the **manifest file's directory** — never CWD.
3. **Path traversal guard**: Reject any entry whose resolved path escapes the manifest's root. If `Resolve-Path` of `(manifest_dir)/(entry_path)` doesn't start with `(manifest_dir)`, reject it with `❌ <path> (path traversal rejected)`. This is a hard security rule.
4. **Hash each file and compare**:
   - `✅ filename.ext` — match
   - `❌ filename.ext (hash mismatch)` — computed hash differs
   - `⚠️ filename.ext (file not found)` — missing from disk
   - `⚠️ filename.ext (unreadable)` — permission denied or I/O error
5. **Summary at end**:

   ```text
   Verification Complete
   ━━━━━━━━━━━━━━━━━━━━━
   ✅ 8 files verified
   ❌ 1 file failed
   ⚠️  1 file missing
   ```

6. **Exit codes** (machine-readable without parsing stdout):
   - `0` — all good
   - `1` — one or more hash mismatches
   - `2` — one or more missing/unreadable files (but no mismatches)
   - `3` — manifest parse error

### Error Handling During Hash

- If a file can't be read (permissions, locked, etc.), record it as `⚠️ unreadable` and **continue**. Don't abort the whole run.
- No separate pre-check pass. Catching errors inline is simpler and covers the same cases without doubling I/O.

---

## CLI Interface

The manifest feature adds a `-Manifest` switch to the existing `VeriHash.ps1` parameter block. No new parameter sets needed for MVP — `-Manifest` acts as a mode flag alongside the existing parameters.

```powershell
# Create manifest from multiple files
.\VeriHash.ps1 -Manifest "C:\Downloads\file1.exe" "C:\Downloads\file2.zip" "C:\Downloads\file3.iso"

# Verify a manifest
.\VeriHash.ps1 -Manifest "C:\Downloads\2026-04-17T143022Z.sha256"

# Create with specific algorithm
.\VeriHash.ps1 -Manifest "C:\Downloads\file1.exe" "C:\Downloads\file2.zip" -Algorithm SHA512

# Create without pause (scripting)
.\VeriHash.ps1 -Manifest "C:\Downloads\file1.exe" "C:\Downloads\file2.zip" -NoPause

# Create with explicit output location
.\VeriHash.ps1 -Manifest "C:\Downloads\file1.exe" "C:\Downloads\file2.zip" -OutputPath "C:\Manifests\" -NoPause
```

### Output Location Rules

- **Default**: Manifest is written to the common parent directory of the input files.
- **`-OutputPath`**: Override the output directory.
- **`-NoPause` without `-OutputPath`**: Uses default location (predictable for scripts).

---

## SendTo Installation

`-SendTo` installs **both** shortcuts:

```powershell
function Install-WindowsSendTo {
    param([switch]$ManifestMode)
    $name = if ($ManifestMode) { 'VeriHash - Manifest.lnk' } else { 'VeriHash.lnk' }
    $extraArg = if ($ManifestMode) { ' -Manifest' } else { '' }
    # ... existing shortcut creation logic, append $extraArg to $arguments
}
```

When the user runs `.\VeriHash.ps1 -SendTo`, both `VeriHash.lnk` and `VeriHash - Manifest.lnk` appear in the Send To menu.

### Windows Command Line Limit

Explorer passes each selected file as a separate argument. PowerShell + `.lnk` handles this fine, but long paths multiplied by many files can exceed ~8 KB. This is not an MVP blocker. If it becomes an issue, the fallback is a temp file listing paths. Don't pre-build for this.

---

## Skip Rules (Create Mode)

When building a manifest, filter out:

- Hash/sidecar files: `.sha256`, `.sha512`, `.sha384`, `.sha1`, `.md5`, `.sha2_256`, `.sha2`
- The manifest's own temp file (`~verihash-*.tmp`)

These are metadata, not content. Silently skip them — don't error.

---

## Security

- **Path traversal on verify**: Hard reject. Any manifest entry resolving outside the manifest's directory is flagged and skipped. Not a warning — a block.
- **No auto-elevation**: If files are unreadable, inform the user. Don't offer to re-run as admin.
- **No symlink following**: If a selected file is a symlink, hash the symlink target. But since MVP is flat files (no recursion), symlink loops aren't a concern yet.

---

## What's NOT in MVP

These are valid ideas for later. They're documented here so they're not lost, but they are **explicitly out of scope** for the first version.

| Feature | Why Deferred |
| - | - |
| **Recursive folder hashing** | Higher complexity (symlinks, permission trees, enumeration errors). Less frequent use case than multi-file select. |
| **Folder input (Smart Entry)** | Needs recursive hashing, ambiguity resolution UX. Depends on the above. |
| **Parent-directory index discovery** | Neat but adds surprise behavior. Users can send-to the manifest directly. |
| **`-Update` (modify existing manifest)** | Users can just create a new manifest. Atomic-rewrite semantics add complexity. |
| **`-Compare` (diff two manifests)** | Power-user feature. Can be a separate script or phase 3+. |
| **Sidecar import / cleanup** | Side-quest. Existing sidecar flow works fine independently. |
| **GUI options dialog** | Right-click → go. No dialog needed. |
| **Save location dialog** | Predictable default (same directory) is better for MVP. |
| **Tiered output (>50 issues → report file)** | Just stream results and print a summary. Add `-Report` flag later if needed. |
| **Permission pre-check pass** | Inline error handling covers this without doubling I/O. |
| **Signature column in manifest** | Breaks `sha256sum -c` compatibility. If wanted, separate report. |
| **Parallel auto-tuning** | Fixed `-ThrottleLimit 2` is fine. Tune later with real benchmarks. |
| **Linux context menu** | Windows-first. Equalize later. |

---

## Behavior Contracts

### The Manifest Mental Model

> **A manifest is a snapshot of content at a point in time.**

- **Create** = fresh hashes of the files you selected. Period.
- **Verify** = check files against ONE manifest. Period.
- Manifests don't know about each other. They don't know about sidecars. They're independent snapshots.

### Index Parsing Rules

- Trim whitespace per line
- Lines must match: `<hex_hash><space><mode_char><path>`
- Accept `*` (binary) and ` ` (text) mode indicators
- Reject lines with invalid hash length for the algorithm
- Normalize path separators to `/` when writing; accept both `/` and `\` when reading
- Skip blank lines and lines starting with `#` (comments, for forward-compatibility)

### Existing Single-File Flow

**Completely unchanged.** The `-Manifest` flag gates all new behavior. Without it, VeriHash works exactly as it does today.

---

## Implementation Phases

### Phase 1: MVP — Manifest Create + Verify (current target)

- `-Manifest` switch + input routing (create vs verify)
- Common-parent validation (single directory)
- GNU-format writer with atomic temp→rename
- GNU-format parser with strict regex + path-traversal guard
- Hashing with `-ThrottleLimit 2` (or sequential)
- Streaming output + end summary + exit codes
- Second SendTo shortcut via `-SendTo`
- Pester tests for roundtrip, tampered file, missing file, format compatibility, traversal rejection

### Phase 2: Progress + Polish

- Live progress counter: `Hashing... 3/10 (30%)`
- Large file warning (>10 GB)
- `-Report` flag for writing verification results to a file

### Phase 3: Folder Input + Recursion

- Accept folder as input (enumerate files recursively)
- Skip rules: hash files, hidden/system files, symlinks
- Confirmation prompt for large counts (>1000 files)

### Phase 4: Update + Discovery

- `-Update` to refresh an existing manifest (atomic rewrite)
- Parent-directory manifest search for single-file verify
- `-Compare` for diffing two manifests

### Phase 5: GUI + Advanced

- Save location dialog
- Import sidecars workflow
- Cross-platform context menu parity

---

## Resolved Questions

| Question | Answer |
| - | - |
| Naming collision? | Append `-1`, `-2`, etc. Never overwrite unless `-Force`. |
| Path separator in manifest? | Always `/` when writing. Accept `\` when reading. |
| Timestamp timezone? | UTC, marked with `Z` suffix. |
| Signature info in manifest? | No. Breaks GNU compatibility. Separate report if ever needed. |
| Folder input for MVP? | No. Select files directly. |
| Permission failures mid-run? | Catch inline, record as `⚠️ unreadable`, continue. |

---

## GNU `sha256sum` Format Reference

```text
<hash><space><mode><filename>
```

- Mode `*` = binary (byte-for-byte). Mode ` ` = text. VeriHash always writes `*`.
- Verify with: `sha256sum -c manifest.sha256`
- VeriHash already uses this format for individual sidecars.

---

## User Experience Examples

### Example 1: Create Manifest (Right-Click)

1. Select `report.pdf`, `data.csv`, `image.png` in Explorer
2. Right-click → Send To → **VeriHash - Manifest**
3. Console opens, hashes each file, writes manifest:

   ```text
   Hashing 3 files...
     ✅ report.pdf
     ✅ data.csv
     ✅ image.png

   Manifest created: 2026-04-17T143022Z.sha256 (3 files)
   ```

### Example 2: Verify Manifest (Right-Click)

1. Right-click `2026-04-17T143022Z.sha256` → Send To → **VeriHash - Manifest**
2. Console opens, verifies each entry:

   ```text
   Verifying manifest: 2026-04-17T143022Z.sha256
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     ✅ report.pdf
     ✅ data.csv
     ❌ image.png (hash mismatch)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Summary: 2/3 OK, 1 Failed, 0 Missing
   ```

### Example 3: CLI Create + Verify

```powershell
# Create
.\VeriHash.ps1 -Manifest "C:\Downloads\file1.exe" "C:\Downloads\file2.zip" -NoPause

# Verify
.\VeriHash.ps1 -Manifest "C:\Downloads\2026-04-17T143022Z.sha256" -NoPause
```

---

## Testing Strategy

### Pester Tests (`Tests/VeriHash.Manifest.Tests.ps1`)

- [ ] Create manifest from 3 files → verify roundtrip passes
- [ ] Tamper with one file → verify detects mismatch (exit code 1)
- [ ] Delete one file → verify reports missing (exit code 2)
- [ ] Manifest with path traversal entry (`../../etc/passwd`) → rejected
- [ ] Files spanning multiple directories → error message
- [ ] Folder input → error message
- [ ] Hash files in input → silently filtered
- [ ] Collision handling (timestamp already exists)
- [ ] UTF-8 no-BOM encoding validated
- [ ] `sha256sum -c` compatibility (if WSL available, else skip)
- [ ] `-Algorithm SHA512` creates `.sha512` extension
- [ ] Single file (non-hash) in manifest mode → error message

### Documentation Updates

- [ ] README: Add manifest section with examples
- [ ] CHANGELOG: Document new feature
- [ ] Help text: Add `-Manifest`, `-OutputPath` flags

---

## Success Criteria

- Multi-select files → Send To → manifest created in same directory
- Send To the manifest → all files verified with clear pass/fail
- Output is `sha256sum -c` compatible
- No partial manifests on cancel/error
- No breaking changes to existing single-file workflow
- Exit codes are machine-readable

---

*This is a living document. Update as implementation reveals new constraints or decisions.*
