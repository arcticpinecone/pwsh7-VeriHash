# Feature Landscape: PSFramework Log Rotation & Management

**Domain:** Log lifecycle management for a PowerShell 7+ CLI tool (VeriHash)
**Researched:** 2025-07-15
**Overall Confidence:** HIGH — Primary findings verified against PSFramework official documentation via Context7

## Context

VeriHash v1.3.0 uses `Set-PSFLoggingProvider -Name 'logfile'` with JSON output and `%date%` placeholder for daily log files. **No rotation is configured.** Log files accumulate indefinitely at `%APPDATA%\VeriHash\logs\` (Windows) or `~/.verihash/logs/` (Linux). The current call (VeriHash.ps1 lines 183–189) sets `FilePath`, `FileType`, `JsonCompress`, `UTC`, `Headers`, and `Enabled` — but omits all rotation parameters.

---

## Table Stakes

Features that are **required** for production logging hygiene. Missing = the tool leaks disk space silently.

| Feature | Why Expected | Complexity | Confidence | Notes |
|---------|--------------|------------|------------|-------|
| **Time-based log rotation** | Without it, logs grow unbounded forever. Users will eventually get "disk full" with no obvious cause. Any tool that writes persistent logs must clean up after itself. | **Low** | HIGH | PSFramework provides this natively via `LogRotatePath` + `LogRetentionTime`. Zero custom code needed. |
| **Scoped rotation filter** | PSFramework rotation deletes *any* file matching age+filter in the target path. A broad filter risks deleting non-VeriHash files if the log directory is shared. | **Low** | HIGH | Use `LogRotateFilter` set to `verihash-*.json` (not the default `*`). |
| **Test-mode isolation for rotation** | VeriHash uses `$env:VERIHASH_TEST_MODE=1` to redirect logs to a `logs/test/` subdirectory. Rotation must also apply to the test subdirectory during tests, and must NOT rotate production logs during test runs. | **Low** | HIGH | `LogRotatePath` must be dynamically set to `$script:VeriHashLogPath` (which already handles the test/prod split). |
| **Retention time default of 30 days** | PSFramework's default `LogRetentionTime` is already 30 days. For a CLI tool used periodically, 30 days is the sweet spot — enough history for "it worked last week" debugging, short enough to not hoard data. | **Low** | HIGH | Accept the PSFramework default. No custom value needed unless user demands override. |

### Implementation — Exact Parameters

The current `Set-PSFLoggingProvider` call needs exactly **two** new parameters added:

```powershell
# CURRENT (VeriHash.ps1 lines 183-189) — no rotation
Set-PSFLoggingProvider -Name 'logfile' -InstanceName 'VeriHash' `
    -FilePath (Join-Path $script:VeriHashLogPath "verihash-%date%.json") `
    -FileType Json `
    -JsonCompress $true `
    -UTC $true `
    -Headers 'FunctionName', 'Level', 'Line', 'Message', 'ModuleName', 'Runspace', 'Tags', 'TargetObject', 'Timestamp', 'Type', 'Data' `
    -Enabled $true

# REQUIRED ADDITION — add these two parameters:
#   -LogRotatePath   (Join-Path $script:VeriHashLogPath "verihash-*.json")
#   -LogRetentionTime (New-TimeSpan -Days 30)
#
# The LogRotateFilter default of '*' is fine because LogRotatePath already
# contains the specific glob pattern 'verihash-*.json'. However, for
# defense-in-depth, explicitly set:
#   -LogRotateFilter "verihash-*.json"
```

**Target call:**

```powershell
Set-PSFLoggingProvider -Name 'logfile' -InstanceName 'VeriHash' `
    -FilePath (Join-Path $script:VeriHashLogPath "verihash-%date%.json") `
    -FileType Json `
    -JsonCompress $true `
    -UTC $true `
    -Headers 'FunctionName', 'Level', 'Line', 'Message', 'ModuleName', 'Runspace', 'Tags', 'TargetObject', 'Timestamp', 'Type', 'Data' `
    -LogRotatePath (Join-Path $script:VeriHashLogPath "verihash-*.json") `
    -LogRetentionTime (New-TimeSpan -Days 30) `
    -Enabled $true
```

---

## Differentiators

Features that improve the logging experience but are NOT required for the milestone. Nice-to-have, can be deferred.

| Feature | Value Proposition | Complexity | Confidence | Notes |
|---------|-------------------|------------|------------|-------|
| **User-configurable retention period** | Power users may want 7 days (privacy maximizers) or 90 days (heavy debuggers). Expose as `logging.retentionDays` in `config.json`. | **Medium** | HIGH | Requires plumbing the config value into the `Set-PSFLoggingProvider` call. Not hard, but adds a config schema change + tests + docs. |
| **Log summary on rotation** | When VeriHash deletes old logs, emit a `Write-PSFMessage -Level Verbose` noting how many files were cleaned and the date range. Gives user confidence rotation is working. | **Medium** | MEDIUM | PSFramework handles deletion silently. To report, you'd need a pre/post file count comparison — custom code around the provider call. |
| **Manual log cleanup command** | A `Clear-VeriHashLogs -OlderThan 7` function in `VeriHash.LogUtils.ps1` for on-demand cleanup. | **Medium** | HIGH | Pure PowerShell; `Get-ChildItem | Where-Object LastWriteTime -lt $cutoff | Remove-Item`. Simple but needs tests and the `-WhatIf`/`-Confirm` pattern. |
| **Disk usage reporting in `Get-VeriHashLogSummary`** | Add total log folder size (bytes) and file count to the existing summary output. Helps users gauge log growth. | **Low** | HIGH | `(Get-ChildItem $logPath -File | Measure-Object Length -Sum).Sum` — trivial addition to existing function. |
| **`MoveOnFinal` / `CopyOnFinal` archive** | PSFramework supports moving/copying log files to an archive folder when the provider shuts down. Could be used to separate "completed session" logs from active ones. | **Low** (config) | HIGH | Native PSFramework feature. But adds conceptual complexity for a CLI tool — users would need to know about two directories. Not worth the confusion. |

---

## Anti-Features

Things to deliberately **NOT** build. Each is a trap that looks useful but isn't.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Size-based rotation (`MaxTotalFolderSize`)** | PSFramework does NOT support size-based rotation. There is no `MaxTotalFolderSize` or `MaxFileSize` parameter. Building custom size-based cleanup means fighting the framework — you'd need to enumerate files, sort by age, and delete until under budget, all outside PSFramework's rotation cycle. For a CLI tool writing ~1–10 KB/day in JSON logs, 30 days of logs is <1 MB. Size is not the real problem; age is. | Use time-based `LogRetentionTime` only. If a user generates abnormally large logs, the 30-day time window naturally caps exposure. |
| **Custom log rotation engine** | PSFramework already runs rotation checks every 5 minutes while the provider is active. Reimplementing this in `VeriHash.LogUtils.ps1` creates two competing deletion mechanisms, race conditions, and double-deletion errors. | Use PSFramework's native `LogRotatePath`/`LogRetentionTime`. One mechanism, one owner. |
| **Recursive rotation (`LogRotateRecurse`)** | VeriHash has a flat log directory. Enabling recursive rotation risks deleting files in unexpected subdirectories (e.g., the `test/` subdirectory might get rotated by the production provider instance). | Keep `LogRotateRecurse` at its default `$false`. Each provider instance (prod vs test) manages its own path. |
| **Log compression/archiving** | Tempting to gzip old logs. But VeriHash JSON logs are already compact (`-JsonCompress $true`), daily files are tiny, and PowerShell has no built-in streaming gzip for append. Compression adds complexity (users can't `Get-Content` compressed logs) for negligible space savings. | Leave logs as plain JSON. The `ConvertFrom-VeriHashLog` tooling already parses them. |
| **Log level filtering at the provider** | PSFramework supports `MinLevel`/`MaxLevel` on providers. Don't filter at the provider level — VeriHash already controls verbosity via the `$LogLevel` parameter and `Set-PSFConfig` for message thresholds. Adding provider-level filtering creates a confusing two-layer filter. | Keep the single-layer approach: `$LogLevel` parameter → `Set-PSFConfig` thresholds. All levels reach the file; the message threshold controls what gets generated. |
| **External log aggregation integration** | Syslog, Windows Event Log, or cloud logging providers exist in PSFramework (e.g., `eventlog`, `splunk`). Overkill for a CLI file-hashing tool. | Stay with the `logfile` provider. Users who need aggregation can point external tools at the JSON files. |

---

## Feature Dependencies

```
LogRotatePath setting ──→ LogRetentionTime (only meaningful when rotation is enabled)
                      ──→ LogRotateFilter (only applied when rotation is enabled)

Test-mode log path ($env:VERIHASH_TEST_MODE) ──→ LogRotatePath must use $script:VeriHashLogPath
                                                  (already dynamic; no additional dependency)

User-configurable retention [DEFERRED] ──→ config.json schema change
                                       ──→ Get-VeriHashDefaultConfig update
                                       ──→ Set-PSFLoggingProvider call reads config value
```

---

## PSFramework Logfile Provider — Complete Parameter Reference

**Confidence: HIGH** — Verified against psframework.org official docs via Context7 (source: https://psframework.org/docs/PSFramework/Logging/providers/logfile)

### All Rotation-Related Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `LogRotatePath` | String | `''` (empty = disabled) | Path pattern identifying files eligible for rotation. **Setting this activates rotation.** Uses filesystem glob (e.g., `C:\Logs\verihash-*.json`). |
| `LogRetentionTime` | TimeSpan | 30 days | Minimum age before a file is eligible for deletion. Only files matching `LogRotatePath` AND older than this value are deleted. |
| `LogRotateFilter` | String | `*` | Additional file filter applied within the `LogRotatePath`. Defense-in-depth filter. |
| `LogRotateRecurse` | Boolean | `$false` | Whether to search subdirectories recursively. |

### Rotation Behavior (from docs)

1. **Disabled by default** — rotation only activates when `LogRotatePath` is non-empty.
2. **Runs every 5 minutes** while the provider is active (i.e., while the PowerShell session is alive).
3. **No file ownership tracking** — PSFramework will delete ANY file matching the age + filter + path criteria. This is why a specific `LogRotatePath` glob pattern is critical.
4. **Age-based only** — there is NO size-based rotation. No `MaxTotalFolderSize`, `MaxFileSize`, or file-count-based rotation exists.

### Other Relevant Parameters (already configured in VeriHash)

| Parameter | Current Value | Notes |
|-----------|---------------|-------|
| `FilePath` | `verihash-%date%.json` | `%date%` creates daily files. Correct pattern. |
| `FileType` | `Json` | ✓ |
| `JsonCompress` | `$true` | Single-line JSON entries. ✓ |
| `UTC` | `$true` | GDPR-friendly, cross-timezone consistent. ✓ |
| `Headers` | Custom (no `ComputerName`, `File`, `Username`) | Privacy-preserving. ✓ |
| `MoveOnFinal` | Not set | Not needed for a CLI tool. |
| `CopyOnFinal` | Not set | Not needed for a CLI tool. |

---

## Correction: PROJECT.md Parameter Names

**Important finding:** The active requirement in PROJECT.md says:

> Enable log-file rotation (`-MaxLogFileAge` / `-MaxTotalFolderSize` on the PSFramework provider)

These parameter names are **incorrect**:

| PROJECT.md Says | Actual PSFramework Parameter | Exists? |
|----------------|------------------------------|---------|
| `-MaxLogFileAge` | `-LogRetentionTime` | ✅ Yes (TimeSpan, default 30d) |
| `-MaxTotalFolderSize` | — | ❌ **Does not exist.** No size-based rotation in PSFramework. |

The requirement should be updated to reference the actual parameter names. The intent (prevent unbounded log growth) is fully achievable with `LogRotatePath` + `LogRetentionTime` alone. Size-based rotation is unnecessary for a CLI tool generating <1 MB/month of logs.

---

## MVP Recommendation

### Must ship (this milestone):

1. **Add `LogRotatePath`** — `(Join-Path $script:VeriHashLogPath "verihash-*.json")` — enables rotation.
2. **Accept default `LogRetentionTime`** — 30 days. No custom value needed initially.
3. **Verify test isolation** — Confirm test-mode rotation targets `logs/test/verihash-*.json`, not production logs.
4. **Add Pester test** — Create a test that configures the provider with rotation and verifies old files are eligible. (Can mock by creating files with old `LastWriteTime` and checking PSFramework config state.)

### Defer:

- **User-configurable retention period** (`logging.retentionDays` in config.json) — Add when users request it. The 30-day default covers >95% of use cases.
- **Manual `Clear-VeriHashLogs` command** — Nice utility but not the same as automated rotation. Add in a future LogUtils enhancement pass.
- **Disk usage in `Get-VeriHashLogSummary`** — Low-effort but not blocking. Add opportunistically.

---

## Sources

| Source | Confidence | What it provided |
|--------|------------|------------------|
| PSFramework official docs — [Logfile Provider Properties](https://psframework.org/docs/PSFramework/Logging/providers/logfile) via Context7 (`/websites/psframework`) | **HIGH** | Complete parameter list, defaults, rotation behavior, all property types |
| PSFramework official docs — [Logging to Logfile](https://psframework.org/docs/PSFramework/Logging/loggingto/logfile) via Context7 | **HIGH** | Configuration examples with `LogRotatePath`, rotation frequency (5 min), ownership warning |
| PSFramework official docs — [Set-PSFLoggingProvider](https://psframework.org/docs/Commands/PSFramework/Set-PSFLoggingProvider) via Context7 | **HIGH** | Command-level parameter reference, filter parameters |
| PSFramework GitHub source (`/powershellframeworkcollective/psframework`) via Context7 | **HIGH** | README confirmation of auto-rotation capability |
| VeriHash codebase — `VeriHash.ps1` lines 183–189 | **HIGH** | Current provider configuration (no rotation params) |
| VeriHash codebase — `.planning/codebase/CONCERNS.md` lines 122–126 | **HIGH** | Documents the unbounded log growth issue |
