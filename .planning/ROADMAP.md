# Roadmap — Milestone v2.0 Modular Rebuild

**Milestone:** v2.0 Modular Rebuild
**Granularity:** coarse
**Phases:** 5
**Coverage:** 38/38 requirements mapped ✓
**Created:** 2026-04-18

> Phase numbering resets at 1 per `--reset-phase-numbers`. v1.0 archived in `.planning/milestones/`.

## Phases

- [x] **Phase 1: Core Module Foundation** — Real `VeriHash.Core` module replaces monolith helpers; golden tests pin v1-compatible behavior.
- [x] **Phase 2: Hot-Path Performance + Multi-File Loop** — PE-only signature, parallel hash/sig via `Start-ThreadJob`, streaming output, multi-file SendTo. (UAT 10/10 pass — commit 0ed3609; 1 cosmetic gap → backlog 999.2.)
- [ ] **Phase 3: Manifest Module** — `VeriHash.Manifest` with GNU `sha256sum`-compatible create/verify, atomic writes, traversal guard, machine-readable exit codes.
- [ ] **Phase 4: Integrations + Config Trim** — Lazy-loaded SendTo/KDE installers (incl. manifest entry); VirusTotal and PSFramework excised from source + tests.
- [ ] **Phase 5: Thin CLI + Cleanup & Docs** — ≤200-line dispatcher, end-to-end CLI tests, retired files deleted, README/CHANGELOG/concepting docs reorganized for ship.

## Phase Details

### Phase 1: Core Module Foundation
**Goal**: A real importable `VeriHash.Core` PowerShell module owns hashing, clipboard parsing, sidecar verify, output formatting, plain-text logging, and platform detection — with tests loading it via `Import-Module` (no dot-source hack).
**Depends on**: Nothing (first phase of v2.0; blocks every other implementation phase)
**Requirements**: CORE-01, CORE-02, CORE-03, CORE-04, CORE-05, CORE-06, CORE-07, CORE-08
**Success Criteria** (what must be TRUE):
  1. `Import-Module .\VeriHash.Core\VeriHash.Core.psd1` succeeds and `Get-Command -Module VeriHash.Core` lists `Get-VeriHashResult`, `Read-ClipboardHash`, `Test-VeriHashSidecar`, `Format-VeriHashReport`, `Write-VeriHashLog`, and the platform helper.
  2. `Get-VeriHashResult -Path <file>` returns an object with `FilePath`, `Size`, `Algorithm`, `Hash`, and `ElapsedMs` for MD5, SHA256, and SHA512 inputs.
  3. `Read-ClipboardHash` returns the correct algorithm for plain-hex inputs (32/64/128 chars) AND for the `<algo>:<hex>` prefix form, with the explicit prefix overriding length-based inference.
  4. Existing v1.x sidecars (both `HASH  filename` and `HASH *filename`) verify against the new Core module without modification; `Format-VeriHashReport` output passes a golden-text test pinned to v1 visual layout.
  5. `Write-VeriHashLog` appends exactly one line to `~/.verihash/verihash.log` only when `-Log` or `$env:VERIHASH_LOG=1` is set; platform detection (`Windows`/`Linux`/`macOS`) is exported by Core and has zero duplicate definitions in any other file.
**Plans**: 3 plans
- [x] 01-01-PLAN.md — Module skeleton + manifest + .psm1 loader + 11 stub function files + Tests/Fixtures (icon move + 2 sidecars + 3 golden text fixtures) + 7 Pester test files (RED for per-function, GREEN for module sanity) [Wave 1]
- [x] 01-02-PLAN.md — Implement 6 public functions + 5 private helpers (CORE-02..CORE-07); turns 6 of 7 test files GREEN; lowercase contract + -LiteralPath discipline + no PSFramework [Wave 2]
- [x] 01-03-PLAN.md — Migrate Tests/VeriHash.Tests.ps1 to Import-Module; delete duplicate platform-detection from VeriHash.ps1, VeriHash.Config.ps1, VeriHash.LogUtils.ps1 (CORE-08); update Test-All.ps1; close Phase 1 with full Test-All -CI green [Wave 3]

### Phase 2: Hot-Path Performance + Multi-File Loop
**Goal**: A single VeriHash invocation processes one or many files with hash and Authenticode signature running in parallel for PE files only, streaming output progressively, and reporting a tally for batches.
**Depends on**: Phase 1 (uses `Get-VeriHashResult`, `Format-VeriHashReport`, `Read-ClipboardHash`, sidecar verify)
**Requirements**: PERF-01, PERF-02, PERF-03, PERF-04, PERF-05, MULTI-01, MULTI-02, MULTI-03
**Success Criteria** (what must be TRUE):
  1. Files whose first two bytes are not `MZ` render `Signature: skipped (not a PE file)` and never invoke Authenticode; PE-file signature checks run with network CRL lookups disabled (verified by an offline-network test).
  2. For a PE file, hash and signature run concurrently via `Start-ThreadJob`; the profiler confirms total wall-clock ≈ max(hash, sig), not their sum.
  3. The hash line prints to the console before the signature line on the same invocation; the signature line is appended once its job completes; displayed elapsed time matches wall-clock duration of the whole call.
  4. Invoking the CLI with N file paths in a single call renders one full result block per file followed by a final tally row of the form `X/N matched, Y mismatch, Z missing`.
  5. Each per-file result in loop mode still performs clipboard compare, sidecar compare, and parallel PE signature — i.e., loop mode does not regress single-file behavior.
**Plans**: 3 plans
- [x] 02-01-module-skeleton-pe-detect-signature-PLAN.md — VeriHash.HotPath module skeleton + Test-IsPEFile + Get-VeriHashSignature wrapper + WinVerifyTrust P/Invoke shim with locked flags (PERF-01, PERF-02) [Wave 1]
- [x] 02-02-hotpath-orchestrator-PLAN.md — Invoke-VeriHashHotPath: two ThreadJobs (hash + sig), Wait-Job -Any polling, Stopwatch wall-clock, hybrid streaming (PERF-03, PERF-04, PERF-05) [Wave 2]
- [x] 02-03-batch-loop-tally-profiler-PLAN.md — Invoke-VeriHashBatch sequential loop + byte-locked tally + continue-and-tally; Profile-VeriHashTiming.ps1 -Strict gate (MULTI-01, MULTI-02, MULTI-03) [Wave 3]

### Phase 3: Manifest Module
**Goal**: A `VeriHash.Manifest` module creates and verifies GNU `sha256sum`-compatible manifests with atomic writes, path-traversal-safe verification, and machine-readable exit codes — usable from CLI today and a second SendTo entry tomorrow.
**Depends on**: Phase 1 (uses Core hashing primitives and platform detection)
**Requirements**: MANIFEST-01, MANIFEST-02, MANIFEST-03, MANIFEST-04, MANIFEST-05, MANIFEST-06, MANIFEST-07, MANIFEST-08
**Success Criteria** (what must be TRUE):
  1. `New-VeriHashManifest -Path <files...>` writes a `sha256sum`-compatible manifest in the common parent directory using a temp-file → rename atomic pattern; mixed-root inputs error with the locked message; files with hash extensions (`.sha256`, `.sha512`, `.sha384`, `.sha1`, `.md5`, `.sha2`, `.sha2_256`) are silently filtered out.
  2. `Test-VeriHashManifest -Path <manifest>` parses each entry with strict regex `^([0-9a-fA-F]{hashlen})[ ](\*| )(.+)$`; malformed lines are reported and the run exits with code `3`.
  3. Verify resolves every entry relative to the manifest file's directory (not CWD) and hard-rejects (does not warn) any entry whose resolved path escapes that directory.
  4. Manifest verify exit codes are exactly `0` (all pass), `1` (≥1 hash mismatch), `2` (≥1 missing/unreadable, no mismatches), `3` (parse error) — covered by a dedicated Pester test per code.
  5. A manifest produced by `New-VeriHashManifest` round-trips successfully through `sha256sum -c <manifest>` on Linux/WSL (Pester test marked `Skip` when WSL/`sha256sum` is unavailable).
**Plans**: 4 plans
Plans:
- [x] 03-01-PLAN.md — Module skeleton + private helpers (Resolve-ManifestTargetPath, Write-ManifestAtomically, Read-ManifestLine, Test-PathTraversal) + module surface test GREEN [Wave 1]
- [x] 03-02-PLAN.md — New-VeriHashManifest implementation + create tests (MANIFEST-01, -02, -03) [Wave 2]
- [x] 03-03-PLAN.md — Test-VeriHashManifest implementation + verify/exit code tests (MANIFEST-04, -05, -06) [Wave 2, parallel with 03-02]
- [x] 03-04-PLAN.md — WSL sha256sum round-trip test (MANIFEST-08) + Test-All.ps1 linter update + full suite gate [Wave 3]

### Phase 4: Integrations + Config Trim
**Goal**: SendTo/KDE installers live in a lazily-loaded helper that installs both the regular and manifest entries; VirusTotal scaffolding and the PSFramework optional dependency are removed from production source and tests.
**Depends on**: Phase 1 (Core platform detection), Phase 3 (manifest SendTo entry must exist before installer references it)
**Requirements**: INTEG-01, INTEG-02, INTEG-03, CFG-01, CFG-02, CFG-03
**Success Criteria** (what must be TRUE):
  1. A hot-path invocation (single-file or multi-file hash/verify) does not load `VeriHash.Integrations.ps1` — verified by a test that asserts the file is not in `Get-Module`/loaded script paths after a normal run; only `-InstallSendTo` and `-InstallKDE` trigger its dot-source.
  2. Windows `-InstallSendTo` installs both `VeriHash.lnk` and `VeriHash - Manifest.lnk` in the user's SendTo folder; system-wide install requires manual elevation (no auto-elevation prompt). Linux KDE install preserves v1 user-level and `--SystemWide` (root-checked) behavior.
  3. `Select-String -i 'virustotal|VERIHASH_VT_'` over `*.ps1`, `*.psm1`, `*.psd1`, and `Tests/` returns zero matches; `VeriHash.Config.ps1` no longer exposes any `virustotal.*` defaults or env-var handling.
  4. `Select-String -i 'PSFramework|Write-PSFMessage|PSFrameworkAvailable'` over the entire source + tests tree returns zero matches; the ~33 `if ($script:PSFrameworkAvailable)` guard sites are gone and the test suite passes without PSFramework installed.
**Plans**: 2 plans
Plans:
- [ ] 04-01-PLAN.md — VirusTotal config trim + PSFramework removal from all source/tests (CFG-01, CFG-02, CFG-03) [Wave 1]
- [ ] 04-02-PLAN.md — Integration extraction to VeriHash.Integrations.ps1 + manifest shortcuts + tests (INTEG-01, INTEG-02, INTEG-03) [Wave 2]

### Phase 5: Thin CLI + Cleanup & Docs
**Goal**: A ≤200-line `VeriHash.ps1` dispatcher replaces the 1,527-line monolith, end-to-end Pester tests pin the locked v2 contract, retired files are deleted, and README/CHANGELOG/concepting docs are reorganized for ship.
**Depends on**: Phase 1, Phase 2, Phase 3, Phase 4 (CLI dispatches to all of them)
**Requirements**: CLI-01, CLI-02, CLI-03, CLEAN-01, CLEAN-02, CLEAN-03, CLEAN-04, CLEAN-05
**Success Criteria** (what must be TRUE):
  1. The new `VeriHash.ps1` is ≤ ~200 non-blank, non-comment lines and contains only: `param()` parsing, module imports, entry-function dispatch (Core hash, multi-file loop, or Manifest create/verify), output via `Format-VeriHashReport`, and a centralized pause-at-end block; no module file references `-NoPause`.
  2. `Tests/VeriHash.Cli.Tests.ps1` exercises end-to-end: single-file hash, clipboard match in plain hex form, clipboard match in `<algo>:<hex>` prefix form, sidecar match, sidecar mismatch resolution, multi-file loop with mixed outcomes, manifest create, and manifest verify (pass / fail / missing) — and all cases pass.
  3. `QuickHash.ps1`, `Tests/QuickHash.Tests.ps1`, `VeriHash.LogUtils.ps1`, and `Tests/VeriHash.LogUtils.Tests.ps1` are deleted from the repo (`git ls-files` returns none of them); the test suite still passes.
  4. README documents the v2 module architecture (`VeriHash.Core` + `VeriHash.Manifest` + thin CLI), the new CLI surface with breaking changes called out, and the simplified install path (no PSFramework). CHANGELOG has a `v2.0` entry listing removals (VirusTotal, PSFramework, QuickHash, LogUtils), additions (manifest mode, multi-file loop, prefixed clipboard parsing), and breaking CLI changes.
  5. `Verihash Multifile Concepting.md`, `Verihash Multifile Concepting Review.md`, and `Verihash Logging Concepting.md` are no longer at the repo root; they live in `.planning/archive/`.
**Plans**: TBD

## Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Module Foundation | 3/3 | ✅ Complete | 2026-04-18 |
| 2. Hot-Path Performance + Multi-File Loop | 3/3 | ✅ Complete + UAT-verified | 2026-04-18 |
| 3. Manifest Module | 4/4 | ✅ Complete | 2026-04-19 |
| 4. Integrations + Config Trim | 0/2 | ◆ Planned | - |
| 5. Thin CLI + Cleanup & Docs | 0/0 | Blocked on P2–P4 | - |

## Coverage Verification

**38 requirements mapped to 5 phases, each requirement in exactly one phase:**

| Phase | Categories | REQ-IDs | Count |
|-------|-----------|---------|-------|
| 1 | CORE | CORE-01..08 | 8 |
| 2 | PERF + MULTI | PERF-01..05, MULTI-01..03 | 8 |
| 3 | MANIFEST | MANIFEST-01..08 | 8 |
| 4 | INTEG + CFG | INTEG-01..03, CFG-01..03 | 6 |
| 5 | CLI + CLEAN | CLI-01..03, CLEAN-01..05 | 8 |
| **Total** | | | **38** |

✓ Every v2.0 requirement maps to exactly one phase
✓ No orphans, no duplicates

> **Note:** REQUIREMENTS.md header states "Total: 32" but the file actually defines 38 requirements across the 8 categories. The roadmap maps all 38; the header is corrected to 38 as part of this roadmap commit.

## Phase Dependency Graph

```
        Phase 1 (Core)
       /     |       \
      v      v        v
  Phase 2  Phase 3    |
  (Perf+   (Manifest) |
   Multi)     |       |
      \      v       /
       \  Phase 4   /
        \ (Integ+  /
         \ Cfg)   /
          \  |   /
           v v  v
          Phase 5
        (CLI+Clean)
```

- Phase 1 unblocks everything.
- Phases 2 and 3 are independent of each other; either can proceed first once Phase 1 is done. (Coarse granularity allows parallel execution.)
- Phase 4 depends on Phase 3 (manifest SendTo entry) and Phase 1 (platform detection); independent of Phase 2.
- Phase 5 requires all prior phases to be complete (CLI dispatches to all of them; cleanup deletes files no longer referenced).
