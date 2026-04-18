# VeriHash

## What This Is

VeriHash is a cross-platform PowerShell 7+ tool that computes and verifies file hashes (MD5, SHA256, SHA512) with sidecar files, clipboard auto-detection, Authenticode signature checking, and OS-level context-menu / SendTo integration. It targets developers and power users who want a fast, scriptable, GUI-friendly way to confirm file integrity from Windows Explorer or the terminal.

## Core Value

Trustworthy file integrity verification — fast, scriptable, privacy-respecting.

## Requirements

### Validated

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
- ✓ Hash values truncated to 16 chars in all log output (PRIV-01, PRIV-02) — v1.0 milestone
- ✓ Config path sanitization via `ConvertTo-SanitizedPath` in all modules — v1.0 milestone
- ✓ `ConvertTo-SanitizedPath` relocated to `VeriHash.LogUtils.ps1` for cross-module use — v1.0 milestone
- ✓ Single PSFramework bootstrap detection (LOGC-02) — v1.0 milestone
- ✓ Logging guide updated to match actual behavior (PRIV-04) — v1.0 milestone
- ✓ GitHub Actions CI: Pester + PSScriptAnalyzer on every push/PR (CICD-01–04) — v1.0 milestone
- ✓ PSScriptAnalyzer lints all 3 `.ps1` files (CICD-03) — v1.0 milestone
- ✓ PSFramework log rotation with 30-day retention (LOGC-01) — v1.0 milestone
- ✓ VirusTotal defaults to disabled until integration ships (LOGC-03) — v1.0 milestone

### Active

See `.planning/REQUIREMENTS.md` for v2.0 requirements (32 items across CORE, PERF, MULTI, MANIFEST, INTEG, CFG, CLI, CLEAN categories).

### Out of Scope

- **VirusTotal integration** — **Cut from project scope per v2.0 decision.** Config scaffolding (`virustotal.*` fields, `VERIHASH_VT_*` env vars) is removed in v2.0. Keeps VeriHash focused on hashes + signatures. May be revisited as a separate tool, but not under VeriHash.
- **macOS context-menu integration** — Not implemented today and not driven by user demand.
- **Test coverage for legacy `.sha2`/`.sha2_256` extensions, Select-File fallback, and sidecar interactive Update/Rename branches** — Real gaps from v1.0 audit; addressed opportunistically in v2.0 test rewrites where the same code is touched, but not a v2.0 milestone goal in itself.
- **Module signing / PSGallery publish** — Out of scope for v2.0; revisit if VeriHash is ever distributed outside this repo.
- **Recursive folder hashing for manifest mode** — Manifest MVP is flat-files-in-one-directory only. Recursion deferred per the manifest concept doc.

## Current Milestone: v2.0 Modular Rebuild

**Goal:** Replace the 1,527-line `VeriHash.ps1` monolith with a tested, modular architecture (real `.psm1` modules) that keeps the hot path fast — hash + clipboard/sidecar compare + parallel signature for PE files — and ships multi-file loop mode plus GNU-compatible manifest mode in a single push.

**Target features:**
- Real PowerShell module structure (`VeriHash.Core`, `VeriHash.Manifest`) with manifests; tests use `Import-Module` (no more dot-source hack)
- Hot-path performance: parallel signing for PE files only, no CRL network checks, streaming output (hash first, signature appended)
- Multi-file loop mode via single SendTo entry (right-click N files → per-file results + tally)
- Manifest mode (`-Manifest`) — GNU `sha256sum`-compatible create/verify with second SendTo entry, atomic write, path-traversal guard, machine-readable exit codes
- Built-in plain-text logger (opt-in via `-Log` / `$env:VERIHASH_LOG`); PSFramework dependency removed
- VirusTotal scaffolding cut entirely
- `QuickHash.ps1` and `VeriHash.LogUtils.ps1` retired
- Clipboard detection learns the `<algo>:<hex>` prefix form (e.g., `sha256:abc...`)
- Thin `VeriHash.ps1` dispatcher (param parse → import module → render → pause)

**Key context:** v2 is a clean break — no CLI backwards-compat commitment, breaking changes documented in README/CHANGELOG. Sidecar file format compatibility preserved (existing v1.x `.sha256/.sha512/.md5` files still verify). Single user (project author) on `dev`. Skipping the formal research phase: this is internal restructuring, not a new domain.

## Context

**Shipped v1.0 milestone** (2026-04-18). VeriHash is at v1.3.0 codebase with v1.0 foundation hardening complete. Privacy-first logging is the honest contract — code matches the guide. CI/CD runs on every push (Pester cross-platform + PSScriptAnalyzer on all 3 files). Log rotation enabled, VT default flipped.

**Test suite:** 133 passing, 8 skipped (4 PSFramework-gated, 2 platform-gated, 2 user-file dependent).
**Tech stack:** PowerShell 7+, PSFramework (optional), Pester 5.x, PSScriptAnalyzer, GitHub Actions.
**Active branch:** `dev`. Last release tag: v1.3.0 (2025-12-27). Milestone tag: v1.0.

**Known tech debt:**
- PSFramework tests skip silently when module absent (Backlog 999.1)
- Monolith `VeriHash.ps1` (~66KB) — deferred to dedicated milestone

## Constraints

- **Tech stack**: PowerShell 7+ only — Project promise; cross-platform support depends on `pwsh`-only features (`-AsUTC`, `$PSVersionTable.Platform`).
- **Backward compatibility**: Sidecar file format (`HASH  filename`, GNU coreutils style) and existing extensions (`.md5`, `.sha256`, `.sha512`, `.sha2`, `.sha2_256`) — Existing user files must continue to verify.
- **Optional dependencies**: PSFramework, Pester, PSScriptAnalyzer must remain optional installs — Cannot be made hard requirements without breaking existing users.
- **Privacy / GDPR**: No usernames, no full hash values, no full file paths in any log output — Documented contract in the logging guide; the milestone exists to enforce it.
- **No interactive prompts in CI**: All Pester invocations and any new automation must work non-interactively (`-NoPause -Force` pattern) — CI cannot block on user input.
- **Lint settings**: `PSAvoidUsingWriteHost` and `PSAvoidUsingBrokenHashAlgorithms` stay suppressed — Intentional (interactive UX, MD5 sidecar legacy).

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Logging guide is the contract; fix code to match | Aspirational doc + audit reveals the gap; code drift is the bug | ✅ Good — all privacy gaps closed |
| Defer monolith split to its own milestone | Highest blast-radius change in CONCERNS; deserves dedicated planning and test migration | ✅ Good — kept v1.0 scope focused |
| Bundle small wins (log rotation, VT default flip, PSFramework dedup) into this milestone | Thematically aligned ("honest baseline"), small surface area, removes audit noise cheaply | ✅ Good — closed under CI protection |
| CI/CD before new features | Phase 3 (VirusTotal) is risky to ship without an automated regression net | ✅ Good — every push auto-validated |
| Expand PSScriptAnalyzer to all three `.ps1` modules | Currently only `VeriHash.ps1` is linted; Config and LogUtils have no automated style enforcement | ✅ Good — full lint coverage |
| Single workflow file with parallel test+lint jobs | Simplest structure for 2 concerns; no need for separate workflow files | ✅ Good |
| LOGC-02 grouped with Phase 1 | Shares dot-source order changes with PRIV-03 | ✅ Good — avoided rework |
| fail-fast: false on CI test matrix | Both OS jobs complete even if one fails — better diagnostics | ✅ Good |
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
*Last updated: 2026-04-18 — v2.0 Modular Rebuild milestone started*
