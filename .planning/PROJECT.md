# VeriHash

## What This Is

VeriHash is a cross-platform PowerShell 7+ tool that computes and verifies file hashes (MD5, SHA256, SHA512). Built as three modular PowerShell modules (`VeriHash.Core`, `VeriHash.HotPath`, `VeriHash.Manifest`) behind a thin CLI dispatcher, it supports sidecar files, clipboard auto-detection (including `<algo>:<hex>` prefix form), parallel PE-only Authenticode signature checking, multi-file batch mode with tally, and GNU `sha256sum`-compatible manifest create/verify — all with OS-level context-menu / SendTo integration on Windows and Linux KDE.

## Core Value

Trustworthy file integrity verification — fast, scriptable, privacy-respecting.

## Requirements

### Validated

<details>
<summary>v1.0 — Privacy + Foundation (24 items)</summary>

- ✓ Compute MD5 / SHA256 / SHA512 hashes for any file via `Get-FileHash` — v1.3.0
- ✓ Auto-detect hash from clipboard (algorithm inferred from hex length) — v1.3.0
- ✓ Create and verify sidecar files (`.md5`, `.sha256`, `.sha512`) in standard `HASH  filename` format — v1.3.0
- ✓ Verify multi-file sidecar manifests via `Test-HashSidecar` — v1.3.0
- ✓ Detect mismatch between clipboard, sidecar, and computed hash with interactive resolution prompt — v1.3.0
- ✓ Authenticode digital-signature check on signable files (Windows; `.exe`, `.dll`, `.ps1`, …) — v1.3.0
- ✓ Windows SendTo / "Open With" integration via `-SendTo` and `VeriHash-OpenWith.bat` — v1.3.0
- ✓ Linux KDE service-menu installation via `-SendTo` — v1.3.0
- ✓ Layered configuration: env vars > `config.json` > defaults (`VeriHash.Config.ps1`) — v1.3.0
- ✓ Optional structured JSON logging via PSFramework with graceful degradation when module absent — v1.3.0
- ✓ Path sanitization helper (`ConvertTo-SanitizedPath`) used for log payloads in `VeriHash.ps1` — v1.3.0
- ✓ Test-mode log isolation via `VERIHASH_TEST_MODE=1` — v1.3.0
- ✓ Pester 5.x test suite (133 passing, 7 platform-skipped) and PSScriptAnalyzer linting on `VeriHash.ps1` — v1.3.0
- ✓ Performance profiler (`Profile-VeriHashTiming.ps1`) with throughput measurement — v1.3.0
- ✓ Standalone `QuickHash.ps1` for raw file/string hashing without VeriHash overhead — v1.3.0
- ✓ Hash values truncated to 16 chars in all log output (PRIV-01, PRIV-02) — v1.0
- ✓ Config path sanitization via `ConvertTo-SanitizedPath` in all modules — v1.0
- ✓ `ConvertTo-SanitizedPath` relocated to `VeriHash.LogUtils.ps1` for cross-module use — v1.0
- ✓ Single PSFramework bootstrap detection (LOGC-02) — v1.0
- ✓ Logging guide updated to match actual behavior (PRIV-04) — v1.0
- ✓ GitHub Actions CI: Pester + PSScriptAnalyzer on every push/PR (CICD-01–04) — v1.0
- ✓ PSScriptAnalyzer lints all 3 `.ps1` files (CICD-03) — v1.0
- ✓ PSFramework log rotation with 30-day retention (LOGC-01) — v1.0
- ✓ VirusTotal defaults to disabled until integration ships (LOGC-03) — v1.0

</details>

<details>
<summary>v2.0 — Modular Rebuild (38 items)</summary>

- ✓ VeriHash.Core module with manifest, .psm1 loader, Import-Module replacing dot-source (CORE-01) — v2.0
- ✓ Get-VeriHashResult: multi-algorithm hash with FilePath/Size/Algorithm/Hash/ElapsedMs output (CORE-02) — v2.0
- ✓ Read-ClipboardHash: plain-hex + `<algo>:<hex>` prefix detection with explicit prefix override (CORE-03) — v2.0
- ✓ Test-VeriHashSidecar: v1.x-compatible sidecar verify for both `HASH  filename` and `HASH *filename` (CORE-04) — v2.0
- ✓ Format-VeriHashReport: golden-text-pinned output formatting (CORE-05) — v2.0
- ✓ Write-VeriHashLog: opt-in plain-text logging, no PSFramework (CORE-06) — v2.0
- ✓ Get-VeriHashPlatform: single-source platform detection, zero duplicates (CORE-07, CORE-08) — v2.0
- ✓ PE-only Authenticode: MZ header gating, skip non-PE files (PERF-01) — v2.0
- ✓ Offline signature: CRL network lookups disabled (PERF-02) — v2.0
- ✓ Parallel hash+signature via ThreadJob, wall-clock ≈ max(hash,sig) (PERF-03) — v2.0
- ✓ Streaming output: hash first, signature appended (PERF-04) — v2.0
- ✓ Accurate wall-clock elapsed time display (PERF-05) — v2.0
- ✓ Multi-file batch: N files → per-file results + tally (MULTI-01) — v2.0
- ✓ Tally format: `X/N matched, Y mismatch, Z missing` (MULTI-02) — v2.0
- ✓ Loop mode preserves single-file behavior (clipboard/sidecar/signature) (MULTI-03) — v2.0
- ✓ GNU sha256sum-compatible manifest create with atomic writes (MANIFEST-01) — v2.0
- ✓ Hash-extension files silently filtered from manifest input (MANIFEST-02) — v2.0
- ✓ Mixed-root input rejected with locked error message (MANIFEST-03) — v2.0
- ✓ Strict manifest line parsing regex (MANIFEST-04) — v2.0
- ✓ Path-traversal guard: hard-reject escaping entries (MANIFEST-05) — v2.0
- ✓ Machine-readable exit codes: 0/1/2/3 (MANIFEST-06) — v2.0
- ✓ Manifest resolve relative to manifest directory, not CWD (MANIFEST-07) — v2.0
- ✓ WSL sha256sum round-trip compatibility (MANIFEST-08) — v2.0
- ✓ Lazy-loaded integrations: hot path never loads VeriHash.Integrations.ps1 (INTEG-01) — v2.0
- ✓ Dual SendTo shortcuts: VeriHash.lnk + VeriHash - Manifest.lnk (INTEG-02) — v2.0
- ✓ KDE service-menu with user-level and --SystemWide support (INTEG-03) — v2.0
- ✓ VirusTotal scaffolding fully removed (CFG-01) — v2.0
- ✓ PSFramework fully removed from all source + tests (CFG-02) — v2.0
- ✓ Config trim: no virustotal.* defaults or VERIHASH_VT_* env vars (CFG-03) — v2.0
- ✓ Thin CLI dispatcher ≤200 lines (CLI-01) — v2.0
- ✓ End-to-end CLI tests pin v2 contract (CLI-02) — v2.0
- ✓ No module file references -NoPause (CLI-03) — v2.0
- ✓ QuickHash.ps1 and Tests/QuickHash.Tests.ps1 deleted (CLEAN-01) — v2.0
- ✓ VeriHash.LogUtils.ps1 and Tests/VeriHash.LogUtils.Tests.ps1 deleted (CLEAN-02) — v2.0
- ✓ VeriHash.Config.ps1 and Tests/VeriHash.Config.Tests.ps1 deleted (CLEAN-03) — v2.0
- ✓ Concepting docs archived to .planning/archive/ (CLEAN-04) — v2.0
- ✓ README + CHANGELOG rewritten for v2 architecture (CLEAN-05) — v2.0
- ✓ Tests/VeriHash.Tests.ps1 deleted — legacy monolith tests replaced by module tests (CLEAN-03) — v2.0

</details>

### Active

#### v2.1 — UX Polish & Smart Routing

- [ ] Sidecar auto-detect: right-clicking `.sha256`/`.sha512`/`.md5` auto-routes to verification
- [ ] Output formatting: rich sectioned single-file report + compact batch table with 6-colour palette
- [ ] Manifest spot-check: single-file verify against existing manifest in same directory

### Out of Scope

- **VirusTotal integration** — **Cut from project scope per v2.0 decision.** Config scaffolding removed in v2.0. May be revisited as a separate tool.
- **macOS context-menu integration** — Not implemented today and not driven by user demand.
- **Module signing / PSGallery publish** — Out of scope; revisit if VeriHash is ever distributed outside this repo.
- **Recursive folder hashing for manifest mode** — Manifest MVP is flat-files-in-one-directory only. Recursion deferred per the manifest concept doc.

## Current Milestone: v2.1 UX Polish & Smart Routing

**Goal:** Make VeriHash smarter about user intent on right-click, and give output a polished presentation.

**Target features:**
- Sidecar auto-detect — `.sha256`/`.sha512`/`.md5` → verify companion (1 line) or manifest (N lines)
- Output formatting — rich sectioned single-file report + compact batch table, 6-colour palette
- Manifest spot-check — single file + existing manifest → verify that entry, not create new manifest

## Current State

**Shipped:** v2.0 Modular Rebuild (2026-04-19)

Three-module architecture: `VeriHash.Core` (hash, clipboard, sidecar, format, log, platform), `VeriHash.HotPath` (parallel PE signature, batch mode, tally), `VeriHash.Manifest` (GNU sha256sum-compatible create/verify) — all behind a 196-line thin `VeriHash.ps1` CLI dispatcher.

**Test suite:** 176 passing, 0 failed, 5 skipped (platform-specific)
**Tech stack:** PowerShell 7+, Pester 5.x, PSScriptAnalyzer. No PSFramework dependency.
**Active branch:** `dev`. Latest tag: v2.0.

## Constraints

- **Tech stack**: PowerShell 7+ only — cross-platform support depends on `pwsh`-only features.
- **Backward compatibility**: Sidecar file format (`HASH  filename`, GNU coreutils style) and existing extensions (`.md5`, `.sha256`, `.sha512`, `.sha2`, `.sha2_256`) — existing user files must continue to verify.
- **Privacy / GDPR**: No usernames, no full hash values, no full file paths in any log output.
- **No interactive prompts in CI**: All Pester invocations must work non-interactively.
- **Lint settings**: `PSAvoidUsingWriteHost` and `PSAvoidUsingBrokenHashAlgorithms` stay suppressed — intentional (interactive UX, MD5 sidecar legacy).

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Logging guide is the contract; fix code to match | Aspirational doc + audit reveals the gap; code drift is the bug | ✅ Good — all privacy gaps closed |
| CI/CD before new features | Risky to ship without automated regression net | ✅ Good — every push auto-validated |
| Three-module split (Core + HotPath + Manifest) | Each module has distinct responsibility; thin CLI dispatches | ✅ Good — clean separation, testable |
| P/Invoke WinVerifyTrust for PE signatures | Avoids `Get-AuthenticodeSignature` cmdlet overhead; locked flags disable CRL | ✅ Good — 2-3× faster |
| ThreadJob parallelism for hash+signature | Wall-clock ≈ max(hash, sig) instead of sum | ✅ Good — measurable speedup |
| GNU sha256sum format for manifests | Industry standard; `sha256sum -c` interop tested via WSL | ✅ Good — future-proof |
| VirusTotal cut from scope | Config scaffolding was dead weight; VeriHash focused on hashes + signatures | ✅ Good — simplified codebase |
| PSFramework fully removed | Plain-text logging sufficient; removes optional dependency complexity | ✅ Good — zero external deps |
| TDD rule: never modify tests to pass | Forces code correctness, not test retrofitting | ✅ Good — caught real bugs |
| Pester pinned to 5.x | Prevents silent Pester 6 breakage | ✅ Good — future-proofed |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-19 — v2.1 UX Polish & Smart Routing milestone started*
