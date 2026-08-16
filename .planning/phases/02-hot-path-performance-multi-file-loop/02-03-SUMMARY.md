# Plan 02-03 SUMMARY — Multi-File Batch Loop + Profiler -Strict Gate

**Status:** ✅ Complete
**Commit (Task 1 RED + Task 2 GREEN):** to follow this file
**Closes:** MULTI-01, MULTI-02, MULTI-03, plus Profile-VeriHashTiming `-Strict` gate (D-A7-1)

---

## Files added

- `VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1` — sequential batch orchestrator with continue-and-tally.
- `Tests/VeriHash.HotPath.Batch.Tests.ps1` — 12 tests (surface, byte-locked tally, continue-and-tally, MULTI-03 feature preservation, Profile -Strict gate).

## Files modified

- `VeriHash.HotPath/VeriHash.HotPath.psd1` — `FunctionsToExport` extended to include `Invoke-VeriHashBatch`.
- `Profile-VeriHashTiming.ps1` — added `[switch]$Strict` parameter and post-measurement assertion `wallClock <= 1.2 * max(hashMs, sigMs) + 100ms` (throws on failure).
- `Tests/VeriHash.HotPath.Tests.ps1` — surface-lock test updated to expect the three-function surface (`Get-VeriHashSignature`, `Invoke-VeriHashHotPath`, `Invoke-VeriHashBatch`). This is a planned surface extension per Plan 02-03 acceptance criteria — not a test workaround.

---

## Test results (Test-All.ps1 -CI, full repo, ExcludeTag Performance)

| Metric | Count |
|---|---|
| Passed | 152 |
| Failed | 0 |
| Skipped | 6 (platform-gated) |
| NotRun | 1 (Performance tier) |
| Duration | ~29s |

`Tests/VeriHash.HotPath.Batch.Tests.ps1` alone: **12 passed, 0 failed, 0 skipped.**

PSScriptAnalyzer:
- `VeriHash.HotPath/`: 0 issues.
- `Profile-VeriHashTiming.ps1`: 1 pre-existing `PSUseBOMForUnicodeEncodedFile` warning (verified pre-existing via `git stash`), unchanged by this plan.

Carried-forward bans (`PSFramework`, `Write-PSFMessage`, `WTD_DISABLE_MD2_MD4`, `$IsWindows`, `$RunningOnWindows`) under `VeriHash.HotPath/`: **0 hits.**

---

## TallyLine examples observed

```
1/1 matched, 0 mismatch, 0 missing      (single-file batch — Open Question 5)
2/2 matched, 0 mismatch, 0 missing      (two clean files)
3/3 matched, 0 mismatch, 0 missing      (three clean files)
2/3 matched, 1 mismatch, 0 missing      (one mocked mismatch via InModuleScope)
2/3 matched, 0 mismatch, 1 missing      (one nonexistent path)
2/3 matched, 0 mismatch, 1 missing      (bad file FIRST — continue-and-tally proven)
```

Format string is byte-locked at `VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1` line 67:
`'{0}/{1} matched, {2} mismatch, {3} missing'`. Do not reformat.

---

## Profile-VeriHashTiming.ps1 -Strict gate

Bound formula (D-A7-1):
```
wallClock_ms <= 1.2 * max(hashMs, sigMs) + 100
```
Violation throws: `"Strict perf assertion failed: wallClock=<W>ms > 1.2*max(<H>,<S>)+100 = <B>ms"`.

- Without `-Strict`: existing `Test-All.ps1` step 3/3 invocation continues unchanged.
- With `-Strict`: enabled for dev / CI hot-path regression checks.

---

## Pinned implementation decisions

| Decision | Resolution |
|---|---|
| D-A4-1 (sequential per-file) | Plain `foreach ($p in $FilePath)` — preserves output ordering. No per-file parallelism. |
| D-A4-2 (3-bucket tally) | `switch ($r.MatchResult)` with `default → missing`. Read errors / sig errors / exceptions all roll up to `missing`. |
| D-A4-3 (continue-and-tally) | `try/catch` around `Invoke-VeriHashHotPath`; placeholder `VeriHash.HotPathResult` with `MatchResult='missing'`, `Signature='error'`, exception message in `SignatureReason`. Bad file FIRST does NOT abort batch (verified by test). |
| MULTI-03 feature preservation | Each batch entry calls `Invoke-VeriHashHotPath` end-to-end — sig job runs per file in parallel, IsPE/Signature/HashElapsedMs/SigElapsedMs all populated as in single-file mode. |
| Open Question 5 (always emit tally) | Single-file batch emits `1/1 matched, 0 mismatch, 0 missing`. Verified. |

---

## Phase 2 requirement closure

| Req ID | Status | Closed in |
|---|---|---|
| PERF-01 (PE-detect ≤ 1ms) | ✅ | Plan 02-01 |
| PERF-02 (WinVerifyTrust shim) | ✅ | Plan 02-01 |
| PERF-03 (parallel hash+sig, wall < 0.85*(H+S)) | ✅ | Plan 02-02 |
| PERF-04 (streaming output order) | ✅ | Plan 02-02 |
| PERF-05 (no PSFramework in HotPath) | ✅ | Plan 02-01/02 (verified again here) |
| MULTI-01 (`Invoke-VeriHashBatch` surface) | ✅ | Plan 02-03 (this) |
| MULTI-02 (byte-locked tally line) | ✅ | Plan 02-03 (this) |
| MULTI-03 (per-file feature preservation) | ✅ | Plan 02-03 (this) |

---

## Recommended next action

```
/gsd-verify-work 2
```

Phase 2 is complete and ready for verification + STATE.md/ROADMAP.md update.
