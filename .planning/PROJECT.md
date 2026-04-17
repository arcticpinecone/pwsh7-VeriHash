# VeriHash

## What This Is

VeriHash is a cross-platform PowerShell 7+ tool that computes and verifies file hashes (MD5, SHA256, SHA512) with sidecar files, clipboard auto-detection, Authenticode signature checking, and OS-level context-menu / SendTo integration. It targets developers and power users who want a fast, scriptable, GUI-friendly way to confirm file integrity from Windows Explorer or the terminal.

## Core Value

Close the audit gaps so the privacy-first logging guide is the **honest contract**, and put a CI/CD safety net in place — before any new feature work lands on the foundation.

## Requirements

### Validated

<!-- Capabilities already shipped in v1.3.0 (inferred from codebase map). Locked. -->

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

### Active

<!-- This milestone: foundation hardening before Phase 3 (VirusTotal). -->

- [ ] Truncate hash values to 16 chars in all `Write-PSFMessage` calls (close `Get-And-SaveHash:839` privacy violation)
- [ ] Sanitize all path arguments in `VeriHash.Config.ps1` log payloads (close 10+ unsanitized-path violations)
- [ ] Run Pester + PSScriptAnalyzer automatically on every push and PR via GitHub Actions
- [ ] Lint `VeriHash.Config.ps1` and `VeriHash.LogUtils.ps1` with PSScriptAnalyzer (currently only `VeriHash.ps1` is linted)
- [ ] Enable log-file rotation (`-MaxLogFileAge` / `-MaxTotalFolderSize` on the PSFramework provider) so logs don't grow unbounded
- [ ] Default `virustotal.enabled` to `false` in `Get-VeriHashDefaultConfig` until Phase 3 ships (avoid misleading users)
- [ ] Eliminate the redundant `Get-Module -ListAvailable -Name PSFramework` call (single bootstrap detection)
- [ ] After fixes, the `Verihash Logging Concepting.md` guide describes actual behavior with no caveats

### Out of Scope

- **Monolith split of `VeriHash.ps1`** — High blast radius (every test depends on the dot-source hack). Deferred to its own milestone where it can get focused planning and a test migration.
- **VirusTotal integration (Phase 3)** — Already on the roadmap as the next feature milestone; do not start until the foundation is honest.
- **Multifile / batch hashing** — Tracked in `Verihash Multifile Concepting.md`; valuable but a feature, not a foundation fix.
- **`QuickHash.ps1` deprecation or rewrite** — Diverged tool with its own tests; decide its fate in a dedicated cleanup milestone, not while hardening.
- **Test coverage for legacy `.sha2` / `.sha2_256` extensions, `Select-File` fallback, sidecar `'u'`/`'r'` interactive branches** — Real gaps but secondary to privacy + CI; address opportunistically or in a later test-coverage milestone.
- **macOS context-menu integration** — Not implemented today and not driven by user demand.

## Context

**Brownfield, mid-life project.** VeriHash is at v1.3.0, has a working test suite (133 passing), supports Windows + Linux (KDE), and has well-established conventions documented in `.github/copilot-instructions.md`. The `.planning/codebase/` map (committed 2026-04-17) is the authoritative inventory of current behaviour.

**Two documents are in tension** and motivated this milestone:

- `Verihash Logging Concepting.md` (root) — User-facing guide describing a privacy-first logging design.
- `.planning/codebase/CONCERNS.md` — Audit revealing real gaps between that design and the code (full hashes logged in `Get-And-SaveHash:839`; ~10 unsanitized config-path log calls in `VeriHash.Config.ps1`).

The decision: the **guide is the contract**, and the code is brought into compliance.

**Key existing constraints to preserve:**

- PowerShell 7+ only (`#Requires`); no Windows PowerShell 5.x compatibility.
- PSFramework remains optional — every `Write-PSFMessage` call must stay guarded by `$script:PSFrameworkAvailable`.
- TDD rule (project policy): never modify a test to make it pass; modify the code.
- Test isolation: `$env:VERIHASH_TEST_MODE = '1'` in every Pester `BeforeAll`.

**Active branch:** `dev`. Last release: v1.3.0 (2025-12-27).

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
| Logging guide is the contract; fix code to match | Aspirational doc + audit reveals the gap; code drift is the bug | — Pending |
| Defer monolith split to its own milestone | Highest blast-radius change in CONCERNS; deserves dedicated planning and test migration | — Pending |
| Bundle small wins (log rotation, VT default flip, PSFramework dedup) into this milestone | Thematically aligned ("honest baseline"), small surface area, removes audit noise cheaply | — Pending |
| CI/CD before new features | Phase 3 (VirusTotal) is risky to ship without an automated regression net | — Pending |
| Expand PSScriptAnalyzer to all three `.ps1` modules | Currently only `VeriHash.ps1` is linted; Config and LogUtils have no automated style enforcement | — Pending |

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
*Last updated: 2026-04-17 after initialization*
