# Plan 06-01 Summary — Core Invoke-VeriHashSidecarDetect Function

**Phase:** 06 — Sidecar Auto-Detect
**Plan:** 01 of 02 (Wave 1)
**Status:** ✅ Complete
**Date:** 2026-04-20

## What Was Built

Created `Invoke-VeriHashSidecarDetect` — the routing brain for Phase 6's sidecar auto-detect feature. When a user right-clicks a `.sha256`/`.sha512`/`.md5` file, this function determines intent by line count:

- **1 non-blank line:** Sidecar verify — parses GNU format or bare hash, resolves companion relative to sidecar directory, hashes companion, and compares. Returns `VeriHash.SidecarVerifyResult`.
- **N non-blank lines:** Delegates to `Test-VeriHashManifest`. Returns `VeriHash.ManifestVerifyResult`.
- **0 non-blank lines:** Writes terminating error "Sidecar file is empty".

Focused verify only (D-01, D-03): no Authenticode, no clipboard, no hot-path output.

## Files Changed

| File | Action | Purpose |
|------|--------|---------|
| `VeriHash.Core/Public/Invoke-VeriHashSidecarDetect.ps1` | Created | Core routing function |
| `VeriHash.Core/VeriHash.Core.psd1` | Modified | Added to FunctionsToExport (7th function) |
| `Tests/VeriHash.Core.Invoke-VeriHashSidecarDetect.Tests.ps1` | Created | 12 unit tests covering SIDE-01–05, T-6-01, D-04 |
| `Tests/VeriHash.Core.Module.Tests.ps1` | Modified | Updated export contract from 6 → 7 functions |

## Requirements Covered

- **SIDE-01:** Single-line GNU format → sidecar verify; multi-line → manifest verify
- **SIDE-02:** Bare hash fallback — strips extension from sidecar filename to find companion
- **SIDE-03:** Companion resolved relative to sidecar's directory, not CWD
- **SIDE-04:** Missing companion → clear "Companion file not found" error
- **SIDE-05:** Empty sidecar → clear "Sidecar file is empty" error

## Security Mitigations

- **T-6-01:** Path traversal guard — rejects `../` escapes and absolute paths in companion filename

## Test Results

- **Unit tests:** 12/12 passed
- **Full suite:** 188/188 passed, 0 failed, 5 skipped (platform-specific)

## Commits

1. `2e37f98` — `test(06-01): add failing tests for Invoke-VeriHashSidecarDetect`
2. `5c1c44e` — `feat(06-01): implement Invoke-VeriHashSidecarDetect`
