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

<!-- Next milestone requirements will be defined via /gsd-new-milestone -->

(None — define with `/gsd-new-milestone`)

### Out of Scope

- **Monolith split of `VeriHash.ps1`** — High blast radius (every test depends on the dot-source hack). Deferred to its own milestone where it can get focused planning and a test migration.
- **VirusTotal integration** — Next feature milestone after foundation is honest.
- **Multifile / batch hashing** — Tracked in `Verihash Multifile Concepting.md`; valuable but a feature, not a foundation fix.
- **`QuickHash.ps1` deprecation or rewrite** — Diverged tool with its own tests; decide its fate in a dedicated cleanup milestone.
- **macOS context-menu integration** — Not implemented today and not driven by user demand.
- **Test coverage for legacy extensions, Select-File fallback, sidecar interactive branches** — Real gaps; address in a test-coverage milestone.

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
*Last updated: 2026-04-18 after v1.0 milestone*
