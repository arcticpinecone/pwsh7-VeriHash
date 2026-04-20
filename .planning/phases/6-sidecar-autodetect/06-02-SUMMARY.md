# Plan 06-02 Summary — CLI Dispatch Integration + E2E Tests

**Phase:** 06 — Sidecar Auto-Detect
**Plan:** 02 of 02 (Wave 2)
**Status:** ✅ Complete
**Date:** 2026-04-20

## What Was Built

Wired `Invoke-VeriHashSidecarDetect` into `VeriHash.ps1`'s main dispatch so hash-extension files (`.sha256`, `.sha512`, `.md5`) auto-detect **before** the existing Manifest/Hash branches. This implements SIDE-06: identical behavior with and without `-Manifest`.

### New dispatch priority:
1. **Sidecar candidate** (single file with hash extension) → `Invoke-VeriHashSidecarDetect`
   - `SidecarVerifyResult` → renders "Sidecar verify:" + companion + algorithm + hashes + PASS/MISMATCH
   - `ManifestVerifyResult` → renders "Manifest verify:" with per-entry status + tally
2. **`-Manifest` with non-hash files** → `New-VeriHashManifest` (manifest create)
3. **Normal hash mode** → `Invoke-VeriHashHotPath` / `Invoke-VeriHashBatch`

### Bug fixes in dispatch:
- `Write-Error` in catch block now uses `-ErrorAction Continue` to prevent re-throw under `$ErrorActionPreference = 'Stop'`
- `exit $exitCode` always called (was conditional on error) so `$LASTEXITCODE` is reliable

## Files Modified

| File | Change |
|------|--------|
| `VeriHash.ps1` | New sidecar-first dispatch + SidecarVerifyResult/ManifestVerifyResult rendering |
| `Tests/VeriHash.Cli.Tests.ps1` | Updated 3 tests for SIDE-06 behavior (routing contract + E2E expectations) |

## Files Created

| File | Purpose |
|------|---------|
| `Tests/VeriHash.Cli.SidecarAutoDetect.Tests.ps1` | 10 E2E integration tests covering SIDE-06 |

## Test Results

- **198 passed**, 0 failed, 5 skipped (platform-specific)
- 10 new E2E tests: single-line sidecar with/without `-Manifest`, multi-line routing, regression guards, error/exit codes

## Commits

1. `27c5501` — `test(06-02): add failing CLI integration tests for sidecar auto-detect`
2. `698972c` — `feat(06-02): wire sidecar auto-detect into CLI dispatch (SIDE-06)`
