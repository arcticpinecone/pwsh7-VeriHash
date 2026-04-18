# Phase 3: Small Wins & Baseline Lock - Research

**Researched:** 2026-04-18
**Domain:** PSFramework logging provider configuration, PowerShell configuration management
**Confidence:** HIGH

## Summary

Phase 3 closes two remaining audit items: enabling PSFramework log rotation (LOGC-01) and flipping the VirusTotal enabled default to `$false` (LOGC-03). Both are surgical, well-scoped edits to existing code — one parameter addition and one boolean flip — plus associated test updates.

**Critical finding:** The CONTEXT.md decision D-01 mentions adding `-LogRetentionTime 30`, but the PSFramework docs and source code confirm that `LogRotatePath` is the **trigger** that activates rotation. Without `-LogRotatePath`, the `LogRetentionTime` parameter has no effect. The requirement LOGC-01 correctly calls for BOTH parameters. The plan must add both `-LogRotatePath` and `-LogRetentionTime` to the `Set-PSFLoggingProvider` call.

**Primary recommendation:** Add `-LogRotatePath $script:VeriHashLogPath -LogRetentionTime "30d"` to the existing `Set-PSFLoggingProvider` call, flip `enabled = $true` to `enabled = $false` in `Get-VeriHashDefaultConfig`, and update the 3 test assertions that check the VT default.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Add `-LogRetentionTime 30` to the existing `Set-PSFLoggingProvider` call in `VeriHash.ps1` (line 152) — uses native PSFramework rotation, no custom cleanup needed
- **D-02:** 30-day retention only — no secondary file-count cap (`-MaxLogFiles`). One parameter, matches the requirement exactly
- **D-03:** No separate cleanup function in `VeriHash.LogUtils.ps1` — PSFramework handles pruning natively when the provider initializes
- **D-04:** Change `enabled = $true` to `enabled = $false` in `Get-VeriHashDefaultConfig` (`VeriHash.Config.ps1` line 85) — stops misleading users about unshipped VirusTotal integration

### Agent's Discretion
- How to update existing tests that assert `virustotal.enabled | Should -Be $true` for the default config (behavioral change, not a TDD violation — the intended behavior is changing)
- Whether to add an inline comment in `Get-VeriHashDefaultConfig` noting VT is planned for a future phase
- Test structure for validating log rotation parameter is present in the provider call

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LOGC-01 | PSFramework log rotation enabled via `LogRotatePath` + `LogRetentionTime` parameters (30-day retention) | PSFramework provider source confirms `LogRotatePath` enables rotation; `LogRetentionTime` accepts `"30d"` PSFTimeSpan format; both are instance properties passable to `Set-PSFLoggingProvider` |
| LOGC-03 | `virustotal.enabled` defaults to `$false` in `Get-VeriHashDefaultConfig` until VirusTotal integration ships | Current code at line 86 has `enabled = $true`; 3 test assertions at lines 100, 127, 180 assert the old value and must be updated |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Log rotation configuration | Script initialization (VeriHash.ps1) | — | PSFramework provider config happens at script startup; the framework handles actual file deletion |
| Default config values | Configuration module (VeriHash.Config.ps1) | — | `Get-VeriHashDefaultConfig` is the single source of truth for defaults |
| Test assertions | Test suite (Tests/) | — | Tests validate behavior of both capabilities |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PSFramework | 1.13.426 | Structured logging with log rotation | Already installed and configured; provides native `LogRotatePath`/`LogRetentionTime` support [VERIFIED: local module inspection] |
| Pester | 5.x (≤5.99) | Testing framework | Already in CI, pinned to 5.x per CICD-04 [VERIFIED: ci.yml] |
| PSScriptAnalyzer | latest | Linting | Already in CI [VERIFIED: ci.yml] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| PSFramework native rotation | Custom `Remove-Item` cleanup function | Unnecessary complexity; D-03 explicitly forbids this |
| `LogRetentionTime` only | `LogRotatePath` + `LogRetentionTime` | `LogRotatePath` is REQUIRED to activate rotation; `LogRetentionTime` alone does nothing |

## Architecture Patterns

### System Architecture Diagram

```
VeriHash.ps1 startup
    │
    ├─► dot-source VeriHash.LogUtils.ps1  (Get-VeriHashLogPath)
    ├─► dot-source VeriHash.Config.ps1    (Get-VeriHashDefaultConfig)
    │
    ├─► Check $script:PSFrameworkAvailable
    │       │
    │       └─► Set-PSFLoggingProvider -Name 'logfile' -InstanceName 'VeriHash'
    │               │
    │               ├─ -FilePath  (daily JSON log)
    │               ├─ -LogRotatePath     ← NEW: enables rotation
    │               └─ -LogRetentionTime  ← NEW: 30-day threshold
    │
    └─► PSFramework background thread
            │
            └─► Invoke-LogRotate (every 5 min max)
                    ├─ Check LogRotatePath is set → if empty, return
                    ├─ Parse LogRetentionTime as TimeSpan
                    └─ Delete files older than retention in LogRotatePath
```

### Recommended Change Map
```
VeriHash.ps1 (line 152)          # Add -LogRotatePath and -LogRetentionTime
VeriHash.Config.ps1 (line 86)    # Flip enabled = $true → $false
Tests/VeriHash.Config.Tests.ps1  # Update 3 assertions (lines 100, 127, 180)
```

### Pattern 1: PSFramework Logging Provider Instance Properties
**What:** Properties like `LogRotatePath` and `LogRetentionTime` are passed directly as parameters to `Set-PSFLoggingProvider` alongside core parameters like `-Name`, `-FilePath`, `-Enabled`.
**When to use:** Configuring any logfile provider behavior.
**Example:**
```powershell
# Source: PSFramework 1.13.426 logfile.provider.ps1 (verified locally)
Set-PSFLoggingProvider -Name 'logfile' -InstanceName 'VeriHash' `
    -FilePath (Join-Path $script:VeriHashLogPath "verihash-%date%.json") `
    -FileType Json `
    -JsonCompress $true `
    -UTC $true `
    -LogRotatePath $script:VeriHashLogPath `
    -LogRetentionTime "30d" `
    -Headers 'FunctionName', 'Level', 'Line', 'Message', 'ModuleName', 'Runspace', 'Tags', 'TargetObject', 'Timestamp', 'Type', 'Data' `
    -Enabled $true
```

### Anti-Patterns to Avoid
- **Setting `LogRetentionTime` without `LogRotatePath`:** Rotation is only activated when `LogRotatePath` is set. Without it, `LogRetentionTime` is ignored. [VERIFIED: PSFramework source `if (-not $basePath) { return }`]
- **Using numeric value for `LogRetentionTime`:** The parameter expects a PSFTimeSpan-compatible string like `"30d"`, not a bare integer `30`. [VERIFIED: config validation is `timespan`, default value is `"30d"`]
- **Creating a custom rotation function:** D-03 forbids this. PSFramework handles it natively.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Log file cleanup | Custom scheduled task or `Remove-Item` loop | PSFramework `-LogRotatePath` | Native, battle-tested, runs in background thread with 5-min throttle [VERIFIED: source] |
| TimeSpan parsing | Custom day-to-timespan conversion | PSFTimeSpan string `"30d"` | PSFramework parses this natively via `[PSFTimeSpan]` type accelerator [VERIFIED: source] |

**Key insight:** PSFramework's log rotation is a zero-code-maintenance solution — it activates with two parameters and runs automatically in the provider's background thread. No cron, no scheduled tasks, no cleanup functions.

## Common Pitfalls

### Pitfall 1: LogRotatePath Must Be Set to Enable Rotation
**What goes wrong:** Developer adds `-LogRetentionTime "30d"` but omits `-LogRotatePath`. Log rotation never activates.
**Why it happens:** The docs for `LogRetentionTime` describe what it does, but don't emphasize that `LogRotatePath` is the activation trigger.
**How to avoid:** Always set both parameters together. `LogRotatePath` activates rotation; `LogRetentionTime` controls the threshold.
**Warning signs:** Log files accumulate past 30 days with no deletion.

### Pitfall 2: LogRetentionTime Format
**What goes wrong:** Passing an integer (e.g., `-LogRetentionTime 30`) instead of a TimeSpan string.
**Why it happens:** The CONTEXT.md D-01 says "add `-LogRetentionTime 30`" which could be interpreted as a bare integer.
**How to avoid:** Use PSFTimeSpan format: `"30d"` for 30 days. The config system validates as `timespan` type. [VERIFIED: `Set-PSFConfig ... -Validation timespan`]
**Warning signs:** Error at runtime about invalid timespan, or silent fallback to default.

### Pitfall 3: Test Update is a Behavioral Change, Not a TDD Violation
**What goes wrong:** Developer hesitates to change tests because of project's "never modify tests to make them pass" rule.
**Why it happens:** The TDD rule applies to making broken code appear correct. Here, the INTENDED BEHAVIOR is changing.
**How to avoid:** CONTEXT.md explicitly grants discretion to update these tests. The old assertions tested the old intended behavior; new assertions test the new intended behavior.
**Warning signs:** N/A — this is a process concern, not a runtime one.

### Pitfall 4: LogRotatePath Deletes ANY Matching File
**What goes wrong:** Setting `LogRotatePath` to a broad directory could delete non-VeriHash files.
**Why it happens:** PSFramework rotation uses `Get-ChildItem -Path $basePath -Filter $filter` and deletes anything matching the filter that's old enough.
**How to avoid:** Set `LogRotatePath` to `$script:VeriHashLogPath` (the dedicated VeriHash logs directory) with the default filter `*`. Since VeriHash owns this directory exclusively, this is safe.
**Warning signs:** Other files disappearing from the log directory.

## Code Examples

### Current Set-PSFLoggingProvider Call (line 152 of VeriHash.ps1)
```powershell
# Source: VeriHash.ps1 lines 152-158 [VERIFIED: local file]
Set-PSFLoggingProvider -Name 'logfile' -InstanceName 'VeriHash' `
    -FilePath (Join-Path $script:VeriHashLogPath "verihash-%date%.json") `
    -FileType Json `
    -JsonCompress $true `
    -UTC $true `
    -Headers 'FunctionName', 'Level', 'Line', 'Message', 'ModuleName', 'Runspace', 'Tags', 'TargetObject', 'Timestamp', 'Type', 'Data' `
    -Enabled $true
```

### After Adding Log Rotation Parameters
```powershell
# Source: Pattern derived from PSFramework docs + existing code [VERIFIED]
Set-PSFLoggingProvider -Name 'logfile' -InstanceName 'VeriHash' `
    -FilePath (Join-Path $script:VeriHashLogPath "verihash-%date%.json") `
    -FileType Json `
    -JsonCompress $true `
    -UTC $true `
    -LogRotatePath $script:VeriHashLogPath `
    -LogRetentionTime "30d" `
    -Headers 'FunctionName', 'Level', 'Line', 'Message', 'ModuleName', 'Runspace', 'Tags', 'TargetObject', 'Timestamp', 'Type', 'Data' `
    -Enabled $true
```

### Current VT Default (VeriHash.Config.ps1 line 84-89)
```powershell
# Source: VeriHash.Config.ps1 [VERIFIED: local file]
virustotal = @{
    apiKey    = ''
    enabled   = $true    # ← Change to $false
    preferApi = $true
    autoOpen  = $false
}
```

### Test Assertion Updates Needed
```powershell
# Tests/VeriHash.Config.Tests.ps1 - 3 lines to change:

# Line 100 (in "Has correct default virustotal values"):
$result.virustotal.enabled | Should -Be $false  # was $true

# Line 127 (in "When no config file exists - Returns default configuration"):
$result.virustotal.enabled | Should -Be $false  # was $true

# Line 180 (in "Merges partial config with defaults"):
$result.virustotal.enabled | Should -Be $false  # Default  # was $true
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No log cleanup | PSFramework native `LogRotatePath` | Always available in PSFramework 1.x | Zero-maintenance rotation |
| VT enabled by default | VT disabled until implementation | This phase | Honest defaults |

**Deprecated/outdated:**
- None relevant — PSFramework 1.13.426 is current and the logfile provider API is stable.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | PSFTimeSpan `"30d"` is the correct format for 30 days | Code Examples | Low — verified against PSFramework source default value; if wrong, runtime error easily caught in testing |

**Note:** Almost all claims in this research were verified directly against the installed PSFramework 1.13.426 source code and Context7 documentation. Only A1 is listed because while the default value `"30d"` was verified, the full range of accepted formats wasn't exhaustively tested.

## Open Questions

1. **LogRetentionTime format validation**
   - What we know: Default is `"30d"`, validation type is `timespan`, PSFTimeSpan parses it as 30 days
   - What's unclear: Whether bare `"30"` (without `d` suffix) would be interpreted as 30 days or 30 ticks
   - Recommendation: Use `"30d"` explicitly — matches the documented default format. Risk is negligible.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Pester 5.7.1 |
| Config file | Inline `New-PesterConfiguration` in CI; direct invocation locally |
| Quick run command | `Invoke-Pester -Path "Tests/VeriHash.Config.Tests.ps1" -Output Detailed` |
| Full suite command | `Invoke-Pester -Path "Tests/" -Output Detailed` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LOGC-01 | Log rotation parameters present in provider call | integration (smoke) | `Invoke-Pester -Path "Tests/VeriHash.Tests.ps1" -Output Detailed` | ✅ (PSFramework Logging Integration context exists; rotation-specific assertion is Wave 0 gap) |
| LOGC-03 | `virustotal.enabled` defaults to `$false` | unit | `Invoke-Pester -Path "Tests/VeriHash.Config.Tests.ps1" -Output Detailed` | ✅ (assertions exist, need value flip) |

### Sampling Rate
- **Per task commit:** `Invoke-Pester -Path "Tests/VeriHash.Config.Tests.ps1" -Output Detailed`
- **Per wave merge:** `Invoke-Pester -Path "Tests/" -Output Detailed`
- **Phase gate:** Full suite green + PSScriptAnalyzer clean before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] Add test assertion verifying `LogRotatePath` and `LogRetentionTime` are configured when PSFramework is available — could be a new `It` block in `Tests/VeriHash.Tests.ps1` under "PSFramework Logging Integration" context
- No other gaps — existing test infrastructure covers LOGC-03 (just needs value updates)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | No user input processed in this phase |
| V6 Cryptography | no | — |
| V7 Error Handling & Logging | yes | PSFramework log rotation prevents unbounded disk usage (availability) |

### Known Threat Patterns for this phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unbounded log growth (DoS via disk exhaustion) | Denial of Service | Log rotation with retention time (LOGC-01) |
| Misleading config defaults (users think VT is active) | Information Disclosure (minor) | Disable VT default (LOGC-03) |

## Sources

### Primary (HIGH confidence)
- PSFramework 1.13.426 — local module source at `C:\Users\bean\Documents\PowerShell\Modules\PSFramework\1.13.426\internal\loggingProviders\logfile.provider.ps1` [VERIFIED: direct file inspection]
- Context7 `/websites/psframework` — "Set-PSFLoggingProvider" command docs and "Logfile Logging Provider Configuration" properties table [VERIFIED: Context7 query]
- Local codebase files — VeriHash.ps1 line 152, VeriHash.Config.ps1 line 86, Tests/VeriHash.Config.Tests.ps1 lines 100/127/180 [VERIFIED: direct file inspection]
- PSFramework config system — `Get-PSFConfig -Module PSFramework -Name 'logging.logfile.*'` output showing default values and types [VERIFIED: live PowerShell command]

### Secondary (MEDIUM confidence)
- Context7 `/powershellframeworkcollective/psframework` (GitHub source docs) — messaging configuration [VERIFIED: consistent with local source]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified against installed module and live config system
- Architecture: HIGH — PSFramework provider source code inspected directly
- Pitfalls: HIGH — derived from source code analysis of `Invoke-LogRotate` function

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (30 days — PSFramework logging API is stable)
