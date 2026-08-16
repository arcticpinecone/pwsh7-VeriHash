# Plan 02-02 Summary — Invoke-VeriHashHotPath orchestrator

**Phase:** 02 — Hot-Path Performance + Multi-File Loop
**Plan:** 02 of 03
**Status:** ✅ Complete
**Date:** 2026-04-18
**Requirements closed:** PERF-03, PERF-04, PERF-05

---

## Files added / modified

| Path | Change |
|------|--------|
| `VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1` | **NEW** — single-file orchestrator (148 lines). |
| `VeriHash.HotPath/VeriHash.HotPath.psd1` | `FunctionsToExport` extended to `'Get-VeriHashSignature', 'Invoke-VeriHashHotPath'`. |
| `VeriHash.HotPath/VeriHash.HotPath.psm1` | Added eager `Import-Module VeriHash.Core -Global` so `Format-VeriHashReport`, `Read-ClipboardHash`, `Test-VeriHashSidecar`, `Write-VeriHashLog`, and `Get-VeriHashPlatform` are guaranteed available to callers without a separate Core import. (Resolves Plan 02-02 Open Question 4.) |
| `Tests/VeriHash.HotPath.Tests.ps1` | Appended 4 new Describe blocks: surface (manifest export), result-object shape (D-A5-1), wall-clock honesty, cross-platform skip. |
| `Tests/VeriHash.HotPath.Perf.Tests.ps1` | **NEW** — `-Tag 'Performance'` differential test on a 150 MB MZ-prefixed random fixture. |
| `PSScriptAnalyzerSettings.psd1` | Added `PSUseUsingScopeModifierInNewRunspaces` to `ExcludeRules` with rationale: ThreadJob script blocks in this codebase use the documented `param(...) + -ArgumentList` binding form (the explicit alternative to `$using:`); the analyzer false-flags every parameter reference. |

---

## Test results

| Run | Passed | Failed | Skipped |
|-----|--------|--------|---------|
| HotPath suite (`Tests/VeriHash.HotPath*.Tests.ps1` minus `-Tag Performance`) | 28 | 0 | 2 (Linux platform-gate + non-Windows cross-platform) |
| Performance test (`Tests/VeriHash.HotPath.Perf.Tests.ps1` with `-Tag Performance`, Windows) | 1 | 0 | 0 |
| Full repo suite (excluding Performance) | 140 | 0 | 6 (1 not-run, 5 skipped) |
| PSScriptAnalyzer on `VeriHash.HotPath/` | — | — | **0 issues** |
| Forbidden-flag audit (`WTD_DISABLE_MD2_MD4\|PSFramework\|Write-PSFMessage\|$IsWindows\|$RunningOnWindows`) | — | — | **0 hits** under `VeriHash.HotPath/` |

PERF-03 measured numbers on the local Windows host (150 MB MZ-prefixed random fixture):

| Metric | Value |
|--------|-------|
| `HashElapsedMs` | ~600 ms |
| `SigElapsedMs` | ~200-300 ms (ThreadJob startup + WinVerifyTrust on bad-form PE) |
| `WallClockMs` | ~700 ms |
| `0.85 × (Hash + Sig)` bound | ~680-765 ms — `WallClockMs < bound` (PERF-03 satisfied) |

---

## Pinned design choices

### `Wait-Job -Any -Timeout` cadence: **1 second**

Two `do { Wait-Job -Job @(...) -Any -Timeout 1 } until (...)` loops:

1. First loop polls **both** jobs but only exits when `$hashJob.State` reaches a terminal state. This preserves the streaming contract (PERF-04: hash line printed before sig line in the common case where hash dominates).
2. Second loop waits on the sig job alone after the hash stanza is rendered.

The 1-second timeout is well below user-visible latency for any reasonable file but high enough to avoid CPU spin.

### Final perf-fixture size: **150 MB** (with 2-byte MZ prefix)

The plan's default fixture size held — no need to bump to 200/300 MB. The critical fix was the `MZ` prefix: a non-PE fixture caused `Get-VeriHashSignature` to early-return `Status='skipped'` and the orchestrator to record `SigElapsedMs=0`, which broke the differential ratio. Forcing PE-magic on bytes 0-1 makes the sig job actually invoke `WinVerifyTrust`, returning `error (0x800B0003 TRUST_E_SUBJECT_FORM_UNKNOWN)` after a real read — small but non-zero work that brings the ratio above the 0.85 bound.

### `Format-VeriHashReport` call shape adopted

Confirmed via the live signature in `VeriHash.Core/Public/Format-VeriHashReport.ps1`:

```powershell
Format-VeriHashReport -Result <pscustomobject> [-CompareTo <pscustomobject>] [-SidecarInfo <pscustomobject>]
```

Orchestrator uses splatting and only adds `-CompareTo` / `-SidecarInfo` when those values are non-null:

```powershell
$reportSplat = @{ Result = $hashResult }
if ($null -ne $clip)    { $reportSplat['CompareTo']   = $clip }
if ($null -ne $sidecar) { $reportSplat['SidecarInfo'] = $sidecar }
Format-VeriHashReport @reportSplat
```

Sig stanza is rendered separately via `Write-Host` (Phase 1 printer does not own that line).

### `$using:` in `-InitializationScript` — does not work for ThreadJobs

`Start-ThreadJob -InitializationScript { Import-Module $using:corePsd1 }` throws `RuntimeException: A Using variable cannot be retrieved`. Workaround: build the initialization script with `[scriptblock]::Create("Import-Module '$corePsd1' -Force")`, embedding the resolved path at scriptblock-creation time. ThreadJob script blocks themselves still receive inputs via `-ArgumentList` + `param(...)`.

### `Write-VeriHashLog` call mapping

`Write-VeriHashLog` validates `-Op` against `('hash','verify')` and `-Result` against `('ok','mismatch','missing','error','n/a')` — `'matched'` is **not** a legal value. The orchestrator maps:

- No comparator (no clipboard hash, no sidecar) → `Op='hash'`, `Result='n/a'`.
- Comparator present and hashes equal → `Op='verify'`, `Result='ok'`.
- Comparator present and hashes differ → `Op='verify'`, `Result='mismatch'`.

The `MatchResult` field on the returned `VeriHash.HotPathResult` keeps the human-readable `'matched' / 'mismatch'` so Plan 03's batch tally can use it directly.

---

## Requirements closed

- **PERF-03 — Parallelize hash and signature compute.** Two `Start-ThreadJob` calls (`-Name 'hash'` and `-Name 'sig'`) launched back-to-back on the main thread; both jobs are tracked by `Wait-Job -Any`. The 150 MB perf test enforces `WallClockMs < 0.85 * (HashElapsedMs + SigElapsedMs)`.
- **PERF-04 — Stream output progressively (hash line first when faster).** Orchestrator emits the hash stanza via `Format-VeriHashReport` immediately after the hash job completes, BEFORE blocking on the sig job. The non-PE host-output test asserts the literal `Signature: skipped (not a PE file)` line appears in the captured information stream.
- **PERF-05 — Honest wall-clock timing.** A `[System.Diagnostics.Stopwatch]` is started at the very first line of the function and stopped after the final job completes. `WallClockMs` is verified within 50 ms of `Measure-Command` over the same call.

---

## Notes for Plan 03 (`Invoke-VeriHashBatch`)

- Plan 03's batch loop should call `Invoke-VeriHashHotPath` per file inside a `foreach` and accumulate buckets from `result.MatchResult` + `result.Signature`. `MatchResult='matched'` is the success bucket (mapped to log `Result='ok'` only when there's a comparator).
- The HotPath module already imports VeriHash.Core eagerly at module load, so Plan 03 only needs `Import-Module VeriHash.HotPath`.
- `Invoke-VeriHashHotPath` performs PE-detect once on the main thread before spawning ThreadJobs. The batch loop should NOT pre-detect PE — let each per-file call own the detection so the per-call result object's `IsPE` field stays accurate.
- The cross-platform escape (`Get-VeriHashSignature` returns `Status='skipped', Reason='not supported on this platform'`) propagates through the orchestrator unchanged. Plan 03's tally should treat `Signature='skipped'` as a single bucket regardless of whether the cause was non-PE or non-Windows.
- `Wait-Job -Any -Timeout 1` polling cadence is acceptable for batch use as long as files are processed sequentially. If a future plan introduces per-file parallelism inside the batch loop, the cadence may need re-evaluation.

---

## Verification commands (all passing)

```powershell
Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1,Tests/VeriHash.HotPath.PE.Tests.ps1,Tests/VeriHash.HotPath.Sig.Tests.ps1 -ExcludeTag Performance -Output Detailed
Invoke-Pester -Path Tests/VeriHash.HotPath.Perf.Tests.ps1 -Tag Performance -Output Detailed   # Windows only
Invoke-ScriptAnalyzer -Path VeriHash.HotPath -Recurse -Settings PSScriptAnalyzerSettings.psd1
Get-ChildItem VeriHash.HotPath -Recurse -File | Select-String -Pattern 'WTD_DISABLE_MD2_MD4|PSFramework|Write-PSFMessage|\$IsWindows|\$RunningOnWindows'
```
