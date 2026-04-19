---
phase: 03-manifest-module
reviewed: 2025-07-17T19:45:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - VeriHash.Manifest/Public/New-VeriHashManifest.ps1
  - VeriHash.Manifest/Public/Test-VeriHashManifest.ps1
  - VeriHash.Manifest/Private/Read-ManifestLine.ps1
  - VeriHash.Manifest/Private/Resolve-ManifestTargetPath.ps1
  - VeriHash.Manifest/Private/Test-PathTraversal.ps1
  - VeriHash.Manifest/Private/Write-ManifestAtomically.ps1
  - VeriHash.Manifest/VeriHash.Manifest.psd1
  - VeriHash.Manifest/VeriHash.Manifest.psm1
  - Test-All.ps1
  - Tests/VeriHash.Manifest.ExitCodes.Tests.ps1
  - Tests/VeriHash.Manifest.Module.Tests.ps1
  - Tests/VeriHash.Manifest.New.Tests.ps1
  - Tests/VeriHash.Manifest.Roundtrip.Tests.ps1
  - Tests/VeriHash.Manifest.Verify.Tests.ps1
findings:
  critical: 0
  warning: 1
  info: 1
  total: 2
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2025-07-17T19:45:00Z
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

The VeriHash.Manifest module is well-structured and follows project conventions closely. Design decisions from 03-CONTEXT.md are faithfully implemented: atomic writes via temp-then-rename, strict SHA256 regex parsing, path traversal rejection, correct exit code precedence, and structured output objects. The module decomposition into focused private helpers (Read-ManifestLine, Test-PathTraversal, Resolve-ManifestTargetPath, Write-ManifestAtomically) is clean and testable.

Test coverage is thorough — exit code precedence, module export surface, roundtrip GNU compatibility, traversal rejection, and format compliance are all verified. The Test-All.ps1 change correctly extends PSScriptAnalyzer to the new module.

One cross-platform bug was found: a hardcoded forward-slash-to-backslash normalization in `Test-VeriHashManifest` breaks both subdirectory entry resolution and path traversal detection on Linux. One minor dead code instance was noted.

## Warnings

### WR-01: Cross-platform bug — hardcoded `'/' → '\'` normalization breaks Linux

**File:** `VeriHash.Manifest/Public/Test-VeriHashManifest.ps1:61`
**Issue:** Line 61 normalizes manifest entry paths by replacing all forward slashes with backslashes:
```powershell
$normalizedEntry = $entryFilename -replace '/', '\'
```
On Linux, `\` is a literal filename character, not a directory separator. This causes two distinct failures:

1. **Subdirectory entries resolve to wrong paths.** A manifest entry like `sub/deep.txt` becomes `sub\deep.txt`. On Linux, `[IO.Path]::Combine("/tmp/dir", "sub\deep.txt")` produces `/tmp/dir/sub\deep.txt` (with a literal backslash), not `/tmp/dir/sub/deep.txt`. The file won't be found, producing a false "missing" status (exit code 2) instead of "pass" (exit code 0).

2. **Path traversal detection is defeated.** An entry like `../../etc/passwd` becomes `..\..\etc\passwd`. On Linux, `GetFullPath` does not interpret `\` as a separator, so the `..` segments aren't resolved as parent-directory traversal. The result stays inside the base directory (with literal backslash characters), the traversal check passes, and the entry is reported as "missing" (exit code 2) instead of "traversal-rejected" (exit code 3). Similarly, Unix absolute paths like `/etc/passwd` become `\etc\passwd`, which is non-rooted on Linux and bypasses the absolute-path detection.

No actual file outside the manifest directory is ever read (the literal-backslash paths don't exist on disk), so there is no security data exposure. However, the exit codes are incorrect — exit code 3 (security concern) is demoted to exit code 2 (missing), hiding traversal attempts from the caller.

The test at `Tests/VeriHash.Manifest.Verify.Tests.ps1:106-122` covers `sub/deep.txt` resolution and would fail on Linux.

**Fix:** Remove the hardcoded normalization entirely. `[System.IO.Path]::Combine` and `[System.IO.Path]::GetFullPath` handle forward slashes natively on all platforms (Windows, Linux, macOS). Both the traversal check and the path resolution already use these APIs:

```powershell
# Line 61 — remove the hardcoded replace:
# BEFORE:
$normalizedEntry = $entryFilename -replace '/', '\'
$isSafe = Test-PathTraversal -EntryPath $normalizedEntry -BaseDirectory $manifestDir

# AFTER:
$isSafe = Test-PathTraversal -EntryPath $entryFilename -BaseDirectory $manifestDir
```

And update the path resolution at lines 76-78 to also use the original entry:

```powershell
# Lines 76-78 — use $entryFilename instead of $normalizedEntry:
$resolvedPath = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::Combine($manifestDir, $entryFilename)
)
```

This allows `[IO.Path]::GetFullPath` to resolve `../` traversals and `/`-rooted paths correctly on every platform, and `Test-PathTraversal` to properly reject them.

## Info

### IN-01: Redundant string replace on filename-only variable

**File:** `VeriHash.Manifest/Public/New-VeriHashManifest.ps1:58`
**Issue:** Line 58 replaces backslashes with forward slashes in `$fileName`:
```powershell
$fileName = $fileName -replace '\\', '/'   # D-03: forward slashes
```
However, `$fileName` is derived from `[System.IO.Path]::GetFileName($file)` on line 57, which returns only the filename component (no directory separators). Since lines 43-47 enforce that all input files share a single parent directory, there are never subdirectory components in the filename. The replace is dead code that never changes the value.

**Fix:** Remove the line or add a comment clarifying it's future-proofing. If kept for D-03 forward-slash compliance in a future multi-directory phase, consider a comment like:
```powershell
# D-03 future-proof: convert any backslashes to forward slashes (no-op for single-dir MVP)
$fileName = $fileName -replace '\\', '/'
```

---

_Reviewed: 2025-07-17T19:45:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
