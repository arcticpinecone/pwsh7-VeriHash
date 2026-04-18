# Phase 2: Hot-Path Performance + Multi-File Loop — Context

**Gathered:** 2026-04-18
**Status:** Ready for planning
**Milestone:** v2.0 Modular Rebuild
**Depends on:** Phase 1 (Core Module Foundation) — COMPLETE

<domain>
## Phase Boundary

A single VeriHash invocation processes one or many files with hash and Authenticode signature running **in parallel for PE files only**, streaming output progressively, and reporting a tally for batches.

Specifically:
- Files whose first two bytes are not `MZ` skip signature checking entirely.
- For PE files, hash and signature run as concurrent `Start-ThreadJob` jobs; wall-clock ≈ max(hash, sig).
- Output streams: hash line prints first, signature line is appended once its job completes.
- The CLI accepts `[string[]] $FilePath`; multi-file invocations render one block per file plus a final tally row of the form `X/N matched, Y mismatch, Z missing`.
- Loop mode preserves single-file features per file (clipboard compare, sidecar compare, parallel signature).

This phase introduces a new module — **`VeriHash.HotPath`** — that owns the orchestration. Hash, sidecar, format, log, and platform helpers continue to live in `VeriHash.Core` (Phase 1).

</domain>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before acting.**

### Roadmap & requirements
- `.planning/ROADMAP.md` — Phase 2 entry, 5 success criteria, dependency graph
- `.planning/REQUIREMENTS.md` — PERF-01..05, MULTI-01..03 (the 8 locked requirements for this phase)
- `.planning/PROJECT.md` — Vision, principles, non-negotiables (no PSFramework, PowerShell 7+ cross-platform)
- `.planning/STATE.md` — Current milestone position

### Prior phase context (locked decisions that constrain this phase)
- `.planning/phases/01-core-module-foundation/01-CONTEXT.md` — module layout, result-object shape, plain-text log format, golden-text fixture rule
- `VeriHash.Core/VeriHash.Core.psd1` — the Phase 1 module this phase depends on; in particular `Get-VeriHashResult`, `Format-VeriHashReport`, `Read-ClipboardHash`, `Test-VeriHashSidecar`, `Get-VeriHashPlatform`, `Write-VeriHashLog`

### Repo intel
- `.planning/codebase/STRUCTURE.md` — Existing repo layout
- `.planning/codebase/CONVENTIONS.md` — Function signature, PSScriptAnalyzer settings
- `.planning/codebase/TESTING.md` — Pester conventions; `VERIHASH_LOG_PATH` test-isolation env-var pattern
- `Profile-VeriHashTiming.ps1` — existing dev-only profiler script; Phase 2 extends it with the strict perf assertion (D-A7)
- `VeriHash.ps1` — v1 monolith; source of the v1-compatible visual output and current Authenticode call shape

### External
- Microsoft Docs — `Start-ThreadJob` (ThreadJob module ships with PowerShell 7)
- Microsoft Docs — `WinVerifyTrust` API and the `WINTRUST_DATA` / `WTD_REVOCATION_NONE` flags (`wintrust.dll`)

</canonical_refs>

<decisions>
## Locked Decisions

### Area 2 — Module location

- **D-A2-1: Phase 2 ships a new `VeriHash.HotPath` module** at the repo root, mirroring the Phase 1 layout (`VeriHash.HotPath/VeriHash.HotPath.psd1`, `.psm1`, `Public/`, `Private/`).
- Provisional public surface:
  - `Invoke-VeriHashHotPath` — single-file orchestrator: PE-detect, hash-job, sig-job, stream output, return result object.
  - `Invoke-VeriHashBatch` — multi-file loop: foreach file → `Invoke-VeriHashHotPath`, accumulate tally, emit tally line.
- Phase 5's thin CLI imports both `VeriHash.Core` and `VeriHash.HotPath`; no orchestration code lives in `VeriHash.ps1`.

### Area 3 — ThreadJob orchestration

- **D-A3-1: Two ThreadJobs.** Hash and signature each run as their own `Start-ThreadJob`. Main thread orchestrates and streams. Symmetric topology so PERF-03's "≈ max(hash, sig)" holds whether hash or sig is the slow side.
- **D-A3-2: Module access via `-InitializationScript`.** Each ThreadJob is started with `-InitializationScript { Import-Module <repo>/VeriHash.Core/VeriHash.Core.psd1 }` so the job's runspace state is explicit, testable, and not coupled to PS7 runspace-pool inheritance.
- **D-A3-3: `Wait-Job -Any` poll loop.** Main thread loops `Wait-Job -Any -Timeout <small>` and prints whichever job completes first via `Format-VeriHashReport`. Satisfies PERF-04 (hash prints before sig in the common case where hash is faster, but also handles the reverse cleanly).

### Area 1 — CRL-disabling mechanism

- **D-A1-1: WinVerifyTrust P/Invoke** in `VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1`.
- Flags: `WTD_REVOCATION_NONE | WTD_CACHE_ONLY_URL_RETRIEVAL` only. **Forbidden:** `WTD_DISABLE_MD2_MD4` and any other downgrade flags (EDR will flag them).
- The `Add-Type` for the P/Invoke shim is wrapped in `if (-not ('VeriHash.WinTrust' -as [type])) { Add-Type ... }` so re-`Import-Module` doesn't error.
- Public wrapper `Get-VeriHashSignature` returns a small object with `Status` (`valid | invalid | unsigned | skipped | error`) and `Reason` (short string).
- On non-Windows platforms, `Get-VeriHashSignature` returns `Status='skipped'`, `Reason='not supported on this platform'` — never P/Invokes.

### Area 4 — Multi-file loop ordering & failure isolation

- **D-A4-1: Sequential foreach** over input files. No `ForEach-Object -Parallel` at the file level — per-file parallelism would scramble output ordering and contend with the inner hash/sig ThreadJobs. SendTo batches are typically 2–10 files; sequential is fast enough.
- **D-A4-2: Strict 3 buckets per MULTI-02.** Tally line is exactly: `<m>/<N> matched, <x> mismatch, <z> missing`. Read errors, sig errors, and exceptions fold into `missing`; the per-file output line still carries the actual error message so users see what went wrong.
- **D-A4-3: Continue-and-tally on per-file failure.** Never fail-fast in batch mode — one bad file must not kill the SendTo run.

### Area 5 — Streaming mechanism

- **D-A5-1: Hybrid streaming.**
  - `Invoke-VeriHashHotPath` calls `Format-VeriHashReport` for each printable line (`Write-Host`, v1-compatible colors, golden-text fixture still passes) **AND** returns:
    ```powershell
    [pscustomobject]@{
        PSTypeName     = 'VeriHash.HotPathResult'
        FilePath       = $path
        Hash           = $hash         # lowercase hex
        HashAlgorithm  = $algo         # 'MD5' | 'SHA256' | 'SHA512'
        HashElapsedMs  = $hashMs       # int
        Signature      = $sigStatus    # 'valid' | 'invalid' | 'unsigned' | 'skipped' | 'error'
        SignatureReason= $sigReason    # short string, may be empty
        SigElapsedMs   = $sigMs        # int (0 if skipped)
        WallClockMs    = $wallMs       # int — used by PERF-05 test
        IsPE           = $true/$false
        MatchResult    = 'matched' | 'mismatch' | 'missing'
    }
    ```
  - `Invoke-VeriHashBatch` returns:
    ```powershell
    [pscustomobject]@{
        PSTypeName = 'VeriHash.BatchResult'
        Results    = @(<HotPathResult>...)
        Tally      = @{ Total=N; Matched=m; Mismatch=x; Missing=z }
        TallyLine  = '<m>/<N> matched, <x> mismatch, <z> missing'
    }
    ```
- Tests assert on the structured objects; humans see the v1-compatible host output.

### Area 6 — PE-detect implementation

- **D-A6-1:** PE detection via `[System.IO.File]::OpenRead` + 2-byte read + immediate `Dispose()`.
- Lives in `VeriHash.HotPath/Private/Test-IsPEFile.ps1`. Returns `$true` iff bytes are `0x4D 0x5A` (`MZ`). Files smaller than 2 bytes return `$false`. Read errors return `$false` (treated as not-a-PE rather than throwing — the file's actual error surfaces in the hash job).
- Stream is short-lived and disposed before hash/sig ThreadJobs spin up — no handle contention.

### Area 7 — Profiler tolerance

- **D-A7-1: Two-tier perf testing.**
  - **Strict (`Profile-VeriHashTiming.ps1`, dev-only):** asserts `wallClock <= 1.2 * max(hashMs, sigMs) + 100ms`. Fails fast on regressions during local development; never runs in CI.
  - **Differential (Pester, `-Tag 'Performance'`):** asserts `wallClock < 0.85 * (hashMs + sigMs)` on a fixture file sized so `min(hash, sig) > ~200ms`. Survives GitHub Actions runner jitter; can be excluded on the slowest runners with `-ExcludeTag Performance`.
- The Pester suite is the contract; the profiler script is the canary.

</decisions>

<carried_forward>
## Carried Forward From Phase 1 / PROJECT.md

These remain locked for Phase 2 — do not re-litigate:

- **No PSFramework dependency.** `VeriHash.HotPath` uses only `Write-VeriHashLog` (Phase 1) for any logging. PSFramework is removed entirely in Phase 4.
- **PowerShell 7+ cross-platform.** Module imports cleanly on Windows/Linux/macOS. Signature checking is Windows-only; non-Windows platforms get a clean `skipped (not supported on this platform)` per D-A1-1.
- **TDD rule.** Tests are never modified to make them pass. Modify the code.
- **Visual output stays v1-compatible.** `Format-VeriHashReport` (Phase 1) is the only printer; the golden-text fixture from Phase 1 still passes.
- **Module folder location at repo root.** `./VeriHash.HotPath/` lives next to `./VeriHash.Core/`.
- **`Get-VeriHashPlatform` is the only platform check.** No new `$IsWindows`/`$RunningOnWindows` redefinitions in `VeriHash.HotPath`.
- **Test-isolation env-var pattern.** Pester `BeforeAll` sets `$env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')` and `AfterAll` clears it. New Phase 2 tests follow the same pattern.

</carried_forward>

<requirements_coverage>
## Requirements Coverage

All 8 Phase 2 requirements map to locked decisions:

| REQ-ID | Success criterion | Decision(s) |
|--------|-------------------|-------------|
| PERF-01 (skip sig for non-PE; show `Signature: skipped (not a PE file)`) | SC #1 | D-A6-1 (PE-detect), D-A1-1 (signature wrapper status mapping) |
| PERF-02 (disable network CRL lookups) | SC #1 | D-A1-1 (WinVerifyTrust + `WTD_REVOCATION_NONE`) |
| PERF-03 (parallel hash + sig via Start-ThreadJob; wall ≈ max) | SC #2 | D-A3-1/2/3 (two ThreadJobs, init script, poll loop), D-A7-1 (perf assertion) |
| PERF-04 (progressive streaming; hash prints first) | SC #3 | D-A3-3 (`Wait-Job -Any` poll), D-A5-1 (hybrid Write-Host + return) |
| PERF-05 (displayed elapsed = wall-clock of whole call) | SC #3 | D-A5-1 (`WallClockMs` field), D-A7-1 |
| MULTI-01 (`[string[]] $FilePath`, multi-file SendTo) | SC #4 | D-A2-1 (`Invoke-VeriHashBatch`) |
| MULTI-02 (one block per file + tally `X/N matched, Y mismatch, Z missing`) | SC #4 | D-A4-1/2 (sequential foreach + strict 3 buckets + locked tally string) |
| MULTI-03 (loop mode preserves single-file features) | SC #5 | D-A2-1 (batch loops over `Invoke-VeriHashHotPath`, which IS the single-file path) |

</requirements_coverage>

<code_context>
## Existing Code Insights

### Reusable assets (from Phase 1)
- `Get-VeriHashResult` — used by the hash ThreadJob via `-InitializationScript Import-Module`.
- `Format-VeriHashReport` — used twice per file (once for hash line, once for sig line) per D-A5-1.
- `Read-ClipboardHash`, `Test-VeriHashSidecar` — called per-file in `Invoke-VeriHashHotPath` to satisfy MULTI-03.
- `Get-VeriHashPlatform` — guards the WinVerifyTrust P/Invoke (Windows-only path).
- `Write-VeriHashLog` — one log line per file (op=`hash` or `verify`, includes wall-clock and result bucket).

### Established patterns
- Module layout: `Public/` + `Private/` dot-sourced from a thin `.psm1` (Phase 1 D-1).
- Result objects use `[pscustomobject]` with `PSTypeName = 'VeriHash.<Type>'` (Phase 1 D-2). `VeriHash.HotPath` mirrors with `VeriHash.HotPathResult` and `VeriHash.BatchResult`.
- Tests use `Import-Module "$PSScriptRoot/../VeriHash.<X>/VeriHash.<X>.psd1" -Force` (Phase 1 D-1). Phase 2 tests do the same for `VeriHash.HotPath`.

### Integration points
- `VeriHash.ps1` (legacy CLI) currently calls `Get-AuthenticodeSignature` inline. Phase 2 leaves the legacy CLI alone but adds the new modules; Phase 5 deletes the inline calls when the thin CLI is built.
- `Profile-VeriHashTiming.ps1` exists at the repo root (cited in PROJECT.md as the existing perf script). Phase 2 extends it with the strict perf assertion from D-A7-1; does not create a new script.

### Constraints surfaced during discussion
- WinVerifyTrust P/Invoke can attract EDR attention. Mitigations baked into D-A1-1: only `WTD_REVOCATION_NONE | WTD_CACHE_ONLY_URL_RETRIEVAL` flags (no MD2/MD4 downgrades), single `Add-Type` at module load guarded against re-import, lives in `Private/`.
- `[System.IO.File]::OpenRead` is EDR-clean (BCL pipe through `CreateFileW` with `GENERIC_READ + FILE_SHARE_READ`); same syscall as `Get-Content -AsByteStream`, no pipeline overhead.

</code_context>

<specifics>
## Specific Ideas

- **Tally line format is byte-locked:** `'{0}/{1} matched, {2} mismatch, {3} missing' -f $matched, $total, $mismatch, $missing`. No spacing variations. MULTI-02 success-criterion test pins this string.
- **`Get-VeriHashSignature.Status` enum (string-typed):** `'valid' | 'invalid' | 'unsigned' | 'skipped' | 'error'`. Locked.
- **WinVerifyTrust flags:** `WTD_REVOCATION_NONE (0x00000010)` + `WTD_CACHE_ONLY_URL_RETRIEVAL (0x00001000)`. No others.

</specifics>

<deferred>
## Deferred Ideas

Captured here so they aren't lost; not in scope for Phase 2.

- **Per-file parallelism in `Invoke-VeriHashBatch`** (`ForEach-Object -Parallel` over files): rejected for Phase 2 to keep output ordering deterministic. Could be a v2.x opt-in flag (e.g., `-Parallel`) once the single-file hot path proves stable.
- **`Format.ps1xml` for `VeriHash.HotPathResult` and `VeriHash.BatchResult`** — would give pretty `Format-Table` defaults. The `PSTypeName`s set in D-A5-1 enable this later. Not needed for Phase 2.
- **Signature timeout fallback** — if WinVerifyTrust hangs (e.g., a slow chain rebuild), wrap with a `Wait-Job -Timeout` cap on the sig job and fall back to `Status='error', Reason='timeout'`. Worth adding if real-world telemetry shows hangs; not built in Phase 2.
- **macOS `codesign` integration** — the `Get-VeriHashSignature` `Status='skipped'` non-Windows behavior leaves room for a future macOS-only path that shells out to `codesign --verify`. Out of scope.

</deferred>

<open_questions_for_planner>
## Notes for the Planner

Things the planner/researcher should explicitly decide during Phase 2 planning (not over-specified here):

- **WinVerifyTrust P/Invoke shape** — `WINTRUST_DATA` struct definition, `WINTRUST_FILE_INFO` setup, return-value mapping (`TRUST_E_*` HRESULTs → our `Status` enum). Get the canonical struct layout from Microsoft docs; do not invent fields.
- **Wait-Job poll cadence** — `Wait-Job -Any -Timeout 0.05` (50ms) is a reasonable starting point but the planner should pick a value that minimizes CPU spin while keeping streaming feel snappy. Consider whether `Receive-Job -Wait -AutoRemoveJob` on the *first-finishing* job + `Receive-Job` on the second is cleaner than a poll loop.
- **Pester perf-fixture file** — the differential test (D-A7-1) needs a fixture file large enough that `min(hash, sig) > 200ms`. Planner picks size (probably 50–200 MB; stored under `Tests/Fixtures/` or generated on-the-fly in `BeforeAll` to keep the repo lean).
- **`Invoke-VeriHashBatch` log-line strategy** — one log line per file (preferred, matches Phase 1's "one line per invocation" intent applied per-file) vs one summary line per batch. Recommend per-file.
- **Plan count** — likely 3 plans (Wave 1: module skeleton + WinVerifyTrust P/Invoke + signature wrapper; Wave 2: `Invoke-VeriHashHotPath` orchestrator + ThreadJob streaming; Wave 3: `Invoke-VeriHashBatch` + tally + perf tests + Profile-VeriHashTiming.ps1 extension), but final breakdown is the planner's call.

</open_questions_for_planner>

---

*Phase: 02-hot-path-performance-multi-file-loop*
*Context gathered: 2026-04-18*
