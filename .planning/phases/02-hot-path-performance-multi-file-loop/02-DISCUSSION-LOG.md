# Phase 2: Hot-Path Performance + Multi-File Loop — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `02-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 02-hot-path-performance-multi-file-loop
**Areas discussed:** 1 (CRL-disabling), 2 (Module location), 3 (ThreadJob orchestration), 4 (Multi-file ordering & isolation), 5 (Streaming mechanism), 6 (PE-detect implementation), 7 (Profiler tolerance)

Mode: Interactive. User selected "All seven (Recommended)" at gray-area selection.

---

## Area 2 — Where Phase 2 code lives

| Option | Description | Selected |
|--------|-------------|----------|
| (a) Extend `VeriHash.Core` | Add `Invoke-VeriHashHotPath` + `Invoke-VeriHashBatch` to the Phase 1 module | |
| (b) New `VeriHash.HotPath` module | Mirror the planned Phase 3 `VeriHash.Manifest` pattern; isolate orchestration | ✓ |
| (c) Inline in `VeriHash.ps1` | Leave orchestration in the monolith CLI; Phase 5 refactors | |

**User's choice:** (b) New `VeriHash.HotPath` module.
**Notes:** Recommended option chosen. Mirrors the upcoming Phase 3 pattern; keeps Core as pure primitives.

---

## Area 3 — ThreadJob orchestration shape (3 sub-questions, batched)

| Option | Description | Selected |
|--------|-------------|----------|
| 3a-1 / 3b-1 / 3c-1 | Two ThreadJobs (hash + sig); `-InitializationScript Import-Module`; `Wait-Job -Any` poll loop | ✓ |
| 3a-2 / 3b-1 / 3c-2 | Hash on main thread + sig in ThreadJob; `-InitializationScript`; `Receive-Job -Wait` sequential | |
| Mix | Free-form bundle | |

**User's choice:** Recommended bundle (two symmetric ThreadJobs + `-InitializationScript` + `Wait-Job -Any` poll).
**Notes:** Symmetric topology preserves PERF-03's "≈ max(hash, sig)" guarantee even when hash dominates on large files; `-InitializationScript` makes job runspace state explicit and testable; `Wait-Job -Any` is the natural fit for PERF-04 streaming.

---

## Area 1 — CRL-disabling mechanism (PERF-02)

| Option | Description | Selected |
|--------|-------------|----------|
| (a) WinVerifyTrust P/Invoke | `WTD_REVOCATION_NONE` + `WTD_CACHE_ONLY_URL_RETRIEVAL`; ~80 lines, Windows-only | ✓ |
| (b) ServicePointManager proxy hack | Inject dead proxy on calling thread before sig check | |
| (c) Trust OS chain-engine cache | Document warm-up cost; first call slow, rest fast | |
| (d) Get-AuthenticodeSignature + hard timeout | 2-second cap, return `signature: timeout` if exceeded | |

**User's choice:** (a) WinVerifyTrust P/Invoke.
**Notes:** Only option that actually controls chain-engine network behavior; required for the offline-network deterministic test in success criterion #1. P/Invoke shim wrapped in `if (-not ('VeriHash.WinTrust' -as [type]))` guard so re-`Import-Module` doesn't error.

---

## Area 4 — Multi-file ordering & failure isolation (3 sub-questions, batched)

| Option | Description | Selected |
|--------|-------------|----------|
| 4a-seq / 4b-3bucket / 4c-continue | Sequential foreach; strict 3 buckets per MULTI-02; continue-and-tally | ✓ |
| 4a-seq / 4b-4bucket / 4c-continue | Sequential; add 4th `error` bucket (changes MULTI-02 string); continue | |
| 4a-parallel / 4b-3bucket / 4c-continue | `ForEach-Object -Parallel` over files; strict 3 buckets; continue | |
| Mix | Free-form bundle | |

**User's choice:** Sequential foreach + strict 3 buckets (errors fold into `missing`) + continue-and-tally.
**Notes:** SendTo batches are 2–10 files; sequential keeps output deterministic and matches the v1 mental model. Strict 3 buckets keeps the locked MULTI-02 tally string. Continue-and-tally is the only sane SendTo behavior.

---

## Area 5 — Streaming mechanism (PERF-04)

| Option | Description | Selected |
|--------|-------------|----------|
| (a) `Write-Host` only | Matches v1 fixture; tests must use `*>&1` capture | |
| (b) `Write-Output` pipeline only | Capturable but breaks v1 colored fixture | |
| (c) Hybrid: PSCustomObject return + `Write-Host` via `Format-VeriHashReport` | Tests assert on object; humans see v1-compatible output | ✓ |

**User's choice:** (c) Hybrid.
**Notes:** First answer to this question was a clarification request — user asked what "v1 golden-text contract" means. After explanation, user confirmed (c). Pattern: orchestrator returns a structured `VeriHash.HotPathResult`; `Format-VeriHashReport` continues to `Write-Host` the colored line. Phase 5 thin-CLI tests will need this pattern anyway.

---

## Area 6 — PE-detect implementation (PERF-01)

| Option | Description | Selected |
|--------|-------------|----------|
| (a) `[System.IO.File]::OpenRead` + 2-byte read + dispose | Fast, deterministic, ~3 lines | ✓ |
| (b) `Get-Content -AsByteStream -TotalCount 2` | Idiomatic but cmdlet overhead | |
| (c) Reuse stream for hash | Saves one OS open call but couples PE-detect to hash path | |

**User's choice:** (a) `[System.IO.File]::OpenRead`.
**Notes:** User asked an EDR-cleanliness clarifying question after first prompt. Confirmed: (a) is `CreateFileW(GENERIC_READ, FILE_SHARE_READ, OPEN_EXISTING)` — most boring read handle Windows knows; identical syscall to `Get-Content -AsByteStream`. The actual EDR-bait in Phase 2 is the WinVerifyTrust P/Invoke (Area 1) — mitigations baked into D-A1-1.

---

## Area 7 — Profiler tolerance for PERF-03 / PERF-05

| Option | Description | Selected |
|--------|-------------|----------|
| (a) Strict: `wallClock <= 1.2 * max + 100ms` | Tight; fails on accidental serialization | |
| (b) Forgiving: `wallClock <= 1.5 * max + 200ms` | Survives noisy CI runners | |
| (c) Differential: `wallClock < 0.85 * (hash + sig)` | Proves parallelism; no upper bound | |
| (d) Bundle: strict (a) in `Profile-VeriHashTiming.ps1` + differential (c) in Pester | Belt and suspenders | ✓ |

**User's choice:** (d) Bundle.
**Notes:** Strict assertion in dev-only profiler script catches regressions during local iteration; looser differential check in Pester is the contract guarantee and survives GitHub Actions runner jitter. Pester perf test gets `-Tag 'Performance'` so it can be excluded on slow runners.

---

## Agent's Discretion

None — every gray area was explicitly resolved with the user.

## Deferred Ideas

- Per-file parallelism in `Invoke-VeriHashBatch` (`ForEach-Object -Parallel` over files) — rejected for Phase 2 to keep output ordering deterministic; could be a v2.x opt-in flag.
- `Format.ps1xml` for `VeriHash.HotPathResult` and `VeriHash.BatchResult` — `PSTypeName`s already in place to enable later.
- Signature timeout fallback — wrap WinVerifyTrust call with `Wait-Job -Timeout` if real-world telemetry shows hangs.
- macOS `codesign` integration — non-Windows path could shell out to `codesign --verify` later.

## Clarifications Captured

- **EDR cleanliness of `[System.IO.File]::OpenRead`** (Area 6): confirmed clean; same syscall as `Get-Content -AsByteStream`; no P/Invoke, no memory-mapping, on every WDAC/AppLocker default allow-list.
- **WinVerifyTrust EDR risk** (Area 1, raised during Area 6): mitigations enforced by D-A1-1 — only `WTD_REVOCATION_NONE | WTD_CACHE_ONLY_URL_RETRIEVAL` flags (no MD2/MD4 downgrades), single guarded `Add-Type` at module load, lives in `Private/`.
- **"v1 golden-text contract"** (Area 5): refers to Phase 1 SC #4 / CORE-06 — `Format-VeriHashReport` output must stay byte-identical to v1 monolith, enforced by a frozen text fixture; rendered via `Write-Host` for `-ForegroundColor` support, which informed the hybrid streaming pick.
