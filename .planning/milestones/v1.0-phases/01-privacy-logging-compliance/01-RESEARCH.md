# Phase 1: Privacy & Logging Compliance — Research

**Researched:** 2026-04-18
**Domain:** PowerShell privacy-first logging, path sanitization, PSFramework structured logging
**Confidence:** HIGH

## Summary

Phase 1 closes the gap between the privacy-first logging guide (`Verihash Logging Concepting.md`) and actual code behavior. The codebase audit (`.planning/codebase/CONCERNS.md`) identified two privacy violations and one performance issue that this phase must fix: (1) full hash values logged untruncated at `Get-And-SaveHash` line 839, (2) 11 `Write-PSFMessage` calls in `VeriHash.Config.ps1` that log raw config paths without sanitization, and (3) a redundant `Get-Module -ListAvailable -Name PSFramework` call adding 100–500ms startup overhead. A prerequisite fix is relocating `ConvertTo-SanitizedPath` from `VeriHash.ps1` to `VeriHash.LogUtils.ps1` so it is available to all modules in the dot-source chain.

All five requirements (PRIV-01 through PRIV-04, LOGC-02) are well-scoped, low-risk changes to existing code paths. The primary complexity is the dot-source ordering change (PRIV-03) which must be sequenced first since PRIV-02 depends on `ConvertTo-SanitizedPath` being available inside `VeriHash.Config.ps1`. The existing 133-test suite (all passing) provides a safety net. No new dependencies are required.

**Primary recommendation:** Sequence work as: (1) relocate `ConvertTo-SanitizedPath` → (2) fix hash truncation → (3) fix config path sanitization → (4) deduplicate PSFramework bootstrap → (5) update the logging guide to match reality.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PRIV-01 | Hash values truncated to 16 chars + `...` in all `Write-PSFMessage` data payloads (closes `Get-And-SaveHash:839`) | Verified: line 839 logs full `$hashValue` in both message string and `-Data` block. The correct truncation pattern already exists at line 1063. |
| PRIV-02 | All config-path log payloads in `VeriHash.Config.ps1` pass through `ConvertTo-SanitizedPath` (closes 11 unsanitized-path violations) | Verified: 11 `Write-PSFMessage` calls across lines 160–423 log `ConfigDirectory` and `ConfigFile` raw. `ConvertTo-SanitizedPath` is unreachable from Config because it's defined in VeriHash.ps1 (loaded after Config). |
| PRIV-03 | `ConvertTo-SanitizedPath` relocated to `VeriHash.LogUtils.ps1` so it is available to all dot-sourced modules (dot-source order: LogUtils → Config → VeriHash) | Verified: Current order is Config → LogUtils (lines 101–102 of VeriHash.ps1). Must swap to LogUtils → Config and move function. |
| PRIV-04 | After fixes, `Verihash Logging Concepting.md` describes actual code behavior with zero caveats | Verified: Guide shows truncated hash example (`"Hash computed: ABC123..."`) but code logs full hash. Guide does not mention Config path sanitization. |
| LOGC-02 | Single PSFramework bootstrap detection — eliminate redundant `Get-Module -ListAvailable` calls | Verified: Duplicate at `VeriHash.Config.ps1` line 28 and `VeriHash.ps1` line 155. Both assign `$script:PSFrameworkAvailable` identically. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Hash value truncation in logs | VeriHash.ps1 (Hash Computation Layer) | — | `Get-And-SaveHash` owns the hash result log call at line 839 |
| Path sanitization function | VeriHash.LogUtils.ps1 (Log Utilities Module) | — | Must be available to all modules; LogUtils is dot-sourced first |
| Config path sanitization | VeriHash.Config.ps1 (Configuration Module) | — | Config owns all 11 `Write-PSFMessage` calls that log paths |
| PSFramework bootstrap | VeriHash.ps1 (Initialization Layer) | — | Main script is authoritative for `$script:PSFrameworkAvailable` |
| Logging guide documentation | Verihash Logging Concepting.md (root) | — | User-facing contract; must match code behavior |

## Standard Stack

### Core

No new libraries needed. This phase modifies existing PowerShell code only.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PSFramework | Optional (already in use) | Structured JSON logging | Already the project's logging mechanism; stays optional [VERIFIED: codebase] |
| Pester | 5.x (already in use) | Test framework | 133 tests passing; validates changes don't regress [VERIFIED: test run] |
| PSScriptAnalyzer | Installed (already in use) | Static analysis | Used by Test-All.ps1 for linting [VERIFIED: codebase] |

### Alternatives Considered

None — this phase only modifies existing code; no new technology decisions.

## Architecture Patterns

### System Architecture Diagram

```
User invocation
    │
    ▼
VeriHash.ps1 (param block)
    │
    ├──[1] dot-source VeriHash.LogUtils.ps1    ◄── NEW ORDER (was step 2)
    │       └── ConvertTo-SanitizedPath        ◄── RELOCATED HERE (was in VeriHash.ps1)
    │       └── ConvertFrom-SanitizedPath      (already here)
    │       └── Get-VeriHashLogPath            (already here)
    │
    ├──[2] dot-source VeriHash.Config.ps1      ◄── NEW ORDER (was step 1)
    │       └── Get-VeriHashConfig
    │           └── Write-PSFMessage -Data @{
    │                 ConfigDirectory = $configDir | ConvertTo-SanitizedPath  ◄── FIX (was raw)
    │               }
    │       └── Set-VeriHashConfig (same pattern)
    │       └── Initialize-VeriHashConfig (same pattern)
    │       └── ❌ REMOVE: $script:PSFrameworkAvailable = ... (line 28)
    │
    ├──[3] PSFramework bootstrap (single check)
    │       └── $script:PSFrameworkAvailable = ...  (line 155, authoritative)
    │
    ├──[4] Get-VeriHashConfig → $script:VeriHashConfig
    │
    └──[5] Core functions
            └── Get-And-SaveHash
                └── Write-PSFMessage -Data @{
                      Hash = $hashValue.Substring(0,16) + '...'  ◄── FIX (was full hash)
                    }
```

### Pattern 1: Hash Truncation Before Logging

**What:** Truncate any hash value to 16 characters + `...` before it appears in any `Write-PSFMessage` call (message string or `-Data` block).

**When to use:** Every time a hash value is passed to structured logging.

**Example (already correct at line 1063):**
```powershell
# Source: VeriHash.ps1 line 1063 (existing correct pattern)
InputHash = if ($InputHash) { $InputHash.Substring(0, [Math]::Min(16, $InputHash.Length)) + '...' } else { $null }
```

**Pattern to apply at line 839:**
```powershell
# BEFORE (violation):
Write-PSFMessage -Level Verbose -Message "Hash computed: $hashValue" -Tag 'Hash', 'Result' -Data @{
    Hash = $hashValue
}

# AFTER (compliant):
$truncatedHash = $hashValue.Substring(0, [Math]::Min(16, $hashValue.Length)) + '...'
Write-PSFMessage -Level Verbose -Message "Hash computed: $truncatedHash" -Tag 'Hash', 'Result' -Data @{
    Hash = $truncatedHash
}
```

### Pattern 2: Path Sanitization in Config Module

**What:** All path values (`ConfigDirectory`, `ConfigFile`) passed to `Write-PSFMessage -Data` must be piped through `ConvertTo-SanitizedPath` first.

**When to use:** Every `Write-PSFMessage` call in `VeriHash.Config.ps1` that includes path data.

**Example:**
```powershell
# BEFORE (violation — 11 occurrences):
Write-PSFMessage -Level Debug -Message "Loading VeriHash configuration" -Tag 'Config', 'Entry' -Data @{
    ConfigDirectory = $configDir
    ConfigFile = $configFile
}

# AFTER (compliant):
Write-PSFMessage -Level Debug -Message "Loading VeriHash configuration" -Tag 'Config', 'Entry' -Data @{
    ConfigDirectory = $configDir | ConvertTo-SanitizedPath
    ConfigFile = $configFile | ConvertTo-SanitizedPath
}
```

### Pattern 3: Dot-Source Reordering

**What:** Change import order from `Config → LogUtils` to `LogUtils → Config` so `ConvertTo-SanitizedPath` is available when Config module loads.

**Current (VeriHash.ps1 lines 101–102):**
```powershell
. "$PSScriptRoot\VeriHash.Config.ps1"
. "$PSScriptRoot\VeriHash.LogUtils.ps1"
```

**After:**
```powershell
. "$PSScriptRoot\VeriHash.LogUtils.ps1"
. "$PSScriptRoot\VeriHash.Config.ps1"
```

### Anti-Patterns to Avoid

- **Inline sanitization logic in Config:** Don't duplicate `ConvertTo-SanitizedPath` logic inside `VeriHash.Config.ps1`. The function lives in LogUtils and is available after the dot-source reorder.
- **Conditional truncation:** Don't check hash length before truncating — always use `[Math]::Min(16, $hashValue.Length)` which handles any-length strings safely.
- **Moving PSFramework check to LogUtils:** Don't add a third location for the availability check. Remove it from Config (line 28) and keep only the one in VeriHash.ps1 (line 155).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Path sanitization | Inline regex in Config.ps1 | `ConvertTo-SanitizedPath` (relocated to LogUtils) | Function already handles Windows/Linux/macOS; don't duplicate |
| Hash truncation | Different truncation per algorithm | `$hash.Substring(0, [Math]::Min(16, $hash.Length)) + '...'` | Consistent 16-char pattern already established at line 1063 |

## Common Pitfalls

### Pitfall 1: Dot-Source Order Creates Circular Dependency

**What goes wrong:** Config module calls `ConvertTo-SanitizedPath` but that function isn't defined yet because Config is dot-sourced before LogUtils.
**Why it happens:** Current order is Config → LogUtils. Reversing to LogUtils → Config fixes this, but need to verify Config doesn't define anything LogUtils depends on.
**How to avoid:** Verify `VeriHash.LogUtils.ps1` has zero dependencies on `VeriHash.Config.ps1` functions. Confirmed: LogUtils is self-contained — no calls to `Get-VeriHashConfig`, `Get-VeriHashConfigPath`, or any Config function. [VERIFIED: codebase grep]
**Warning signs:** `CommandNotFoundException` for `ConvertTo-SanitizedPath` when VeriHash.Config.ps1 loads.

### Pitfall 2: PSFramework Detection Timing After Removal from Config

**What goes wrong:** Removing `$script:PSFrameworkAvailable` from Config line 28 means Config's `Write-PSFMessage` guards check an undefined variable (which is `$null`, effectively `$false`). This could silently suppress Config logging even when PSFramework is installed.
**Why it happens:** `$script:PSFrameworkAvailable` is only set at VeriHash.ps1 line 155, which runs AFTER Config is dot-sourced.
**How to avoid:** Two options: (a) Move the single detection to the very top of VeriHash.ps1 before any dot-source, or (b) Keep the check in Config but have VeriHash.ps1 not re-run it. Option (a) is cleaner — single location, runs first.
**Warning signs:** Config operations produce no log entries despite PSFramework being installed.

### Pitfall 3: Test Dot-Source Hack Sensitivity

**What goes wrong:** `Tests/VeriHash.Tests.ps1` line 7 dot-sources `VeriHash.ps1` with a dummy file path. Changing dot-source order or top-level initialization can break this fragile loading mechanism.
**Why it happens:** The test relies on `VeriHash.ps1` loading functions into scope despite the error from the nonexistent file path.
**How to avoid:** Run the full test suite after EVERY change to dot-source ordering or top-level initialization code.
**Warning signs:** All VeriHash.Tests.ps1 tests fail with "command not found" errors.

### Pitfall 4: Config Tests Don't Dot-Source LogUtils

**What goes wrong:** `Tests/VeriHash.Config.Tests.ps1` dot-sources only `VeriHash.Config.ps1`. After PRIV-02/PRIV-03, Config now calls `ConvertTo-SanitizedPath`, which won't exist in the test scope.
**Why it happens:** Config tests load Config in isolation; they don't follow the full VeriHash.ps1 initialization chain.
**How to avoid:** Add `. "$PSScriptRoot\..\VeriHash.LogUtils.ps1"` before `. "$PSScriptRoot\..\VeriHash.Config.ps1"` in Config test `BeforeAll`. This mirrors the new production dot-source order.
**Warning signs:** All Config tests fail with "ConvertTo-SanitizedPath: The term is not recognized".

### Pitfall 5: Logging Guide Example Hash Doesn't Match Pattern

**What goes wrong:** The logging guide shows `"Hash computed: ABC123..."` as an example, which implies 6-char truncation. The actual code truncates to 16 chars.
**Why it happens:** The guide was written aspirationally before implementation.
**How to avoid:** When updating the guide (PRIV-04), use a realistic 16-char example: `"Hash computed: D7A8FBB307D78094..."`.
**Warning signs:** Guide and code disagree on truncation length.

## Code Examples

### Complete Fix: Get-And-SaveHash Hash Truncation (PRIV-01)

```powershell
# Source: VeriHash.ps1 lines 836–846 — BEFORE
if ($script:PSFrameworkAvailable) {
    $throughputMBs = if ($hashDuration.TotalSeconds -gt 0) { [Math]::Round($fileSize / 1MB / $hashDuration.TotalSeconds, 2) } else { 0 }
    Write-PSFMessage -Level Verbose -Message "Hash computed: $hashValue" -Tag 'Hash', 'Result' -Data @{
        Path = $PathToFile | ConvertTo-SanitizedPath
        Algorithm = $Algorithm
        Hash = $hashValue
        DurationMs = [Math]::Round($hashDuration.TotalMilliseconds, 2)
        ThroughputMBs = $throughputMBs
    }
}

# Source: VeriHash.ps1 lines 836–846 — AFTER
if ($script:PSFrameworkAvailable) {
    $throughputMBs = if ($hashDuration.TotalSeconds -gt 0) { [Math]::Round($fileSize / 1MB / $hashDuration.TotalSeconds, 2) } else { 0 }
    $truncatedHash = $hashValue.Substring(0, [Math]::Min(16, $hashValue.Length)) + '...'
    Write-PSFMessage -Level Verbose -Message "Hash computed: $truncatedHash" -Tag 'Hash', 'Result' -Data @{
        Path = $PathToFile | ConvertTo-SanitizedPath
        Algorithm = $Algorithm
        Hash = $truncatedHash
        DurationMs = [Math]::Round($hashDuration.TotalMilliseconds, 2)
        ThroughputMBs = $throughputMBs
    }
}
```

### Complete Fix: Config Path Sanitization (PRIV-02 — one of 11 sites)

```powershell
# Source: VeriHash.Config.ps1 lines 159–164 — BEFORE
if ($script:PSFrameworkAvailable) {
    Write-PSFMessage -Level Debug -Message "Loading VeriHash configuration" -Tag 'Config', 'Entry' -Data @{
        ConfigDirectory = $configDir
        ConfigFile = $configFile
    }
}

# AFTER
if ($script:PSFrameworkAvailable) {
    Write-PSFMessage -Level Debug -Message "Loading VeriHash configuration" -Tag 'Config', 'Entry' -Data @{
        ConfigDirectory = $configDir | ConvertTo-SanitizedPath
        ConfigFile = $configFile | ConvertTo-SanitizedPath
    }
}
```

### Complete Fix: Dot-Source Reorder and Function Relocation (PRIV-03)

```powershell
# VeriHash.ps1 — BEFORE (lines 99–103)
#region Module Imports
. "$PSScriptRoot\VeriHash.Config.ps1"
. "$PSScriptRoot\VeriHash.LogUtils.ps1"
#endregion Module Imports

# VeriHash.ps1 — AFTER
#region Module Imports
. "$PSScriptRoot\VeriHash.LogUtils.ps1"
. "$PSScriptRoot\VeriHash.Config.ps1"
#endregion Module Imports
```

```powershell
# ConvertTo-SanitizedPath — REMOVE from VeriHash.ps1 lines 105–134
# ADD to VeriHash.LogUtils.ps1 (after Get-VeriHashLogPath, before ConvertFrom-SanitizedPath)
function ConvertTo-SanitizedPath {
    <#
    .SYNOPSIS
        Replaces user profile paths with platform-appropriate placeholders.
    .DESCRIPTION
        Implements data minimization by removing personally identifiable
        information from file paths before logging.
    .PARAMETER Path
        The file path to sanitize.
    .OUTPUTS
        System.String - The sanitized path.
    .EXAMPLE
        'C:\Users\john\Downloads\file.exe' | ConvertTo-SanitizedPath
        # Returns: %USERPROFILE%\Downloads\file.exe
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(ValueFromPipeline)]
        [string]$Path
    )
    process {
        if ([string]::IsNullOrEmpty($Path)) { return $Path }

        $RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform

        if ($RunningOnWindows) {
            $Path -replace [regex]::Escape($env:USERPROFILE), '%USERPROFILE%'
        } else {
            $Path -replace [regex]::Escape($HOME), '~'
        }
    }
}
```

Note: The relocated function uses a local `$RunningOnWindows` variable (matching the existing pattern in `ConvertFrom-SanitizedPath` at LogUtils line 74) rather than relying on `$script:RunningOnWindows` from VeriHash.ps1 scope.

### Complete Fix: PSFramework Bootstrap Deduplication (LOGC-02)

```powershell
# VeriHash.Config.ps1 — REMOVE line 28:
# $script:PSFrameworkAvailable = $null -ne (Get-Module -ListAvailable -Name PSFramework)

# VeriHash.ps1 — MOVE line 155 to BEFORE dot-source imports (after platform detection):
$script:PSFrameworkAvailable = $null -ne (Get-Module -ListAvailable -Name PSFramework)

# ... then dot-sources happen ...
. "$PSScriptRoot\VeriHash.LogUtils.ps1"
. "$PSScriptRoot\VeriHash.Config.ps1"  # ← Config now reads $script:PSFrameworkAvailable set above
```

## Detailed Violation Inventory

### PRIV-01: Hash Value Violations (1 site)

| File | Line | Current Code | Fix |
|------|------|-------------|-----|
| `VeriHash.ps1` | 839 | `Hash = $hashValue` and message `"Hash computed: $hashValue"` | Truncate both to 16 chars + `...` |

**No other hash-value-in-log violations found.** Line 1063 already truncates correctly. Clipboard detection (lines 771–791) logs algorithm only, not hash values. Sidecar verification (lines 1427–1538) logs metadata only, not hash values. [VERIFIED: grep of all Write-PSFMessage calls]

### PRIV-02: Unsanitized Path Violations (11 sites)

| File | Line | Field(s) | Context |
|------|------|----------|---------|
| `VeriHash.Config.ps1` | 161 | `ConfigDirectory` | `Get-VeriHashConfig` entry log |
| `VeriHash.Config.ps1` | 162 | `ConfigFile` | `Get-VeriHashConfig` entry log |
| `VeriHash.Config.ps1` | 215 | `ConfigFile` | Config file loaded successfully |
| `VeriHash.Config.ps1` | 228 | `ConfigFile` | No config file found, using defaults |
| `VeriHash.Config.ps1` | 321 | `ConfigDirectory` | `Set-VeriHashConfig` entry log |
| `VeriHash.Config.ps1` | 322 | `ConfigFile` | `Set-VeriHashConfig` entry log |
| `VeriHash.Config.ps1` | 331 | `ConfigDirectory` | Created config directory |
| `VeriHash.Config.ps1` | 348 | `ConfigFile` | Configuration saved |
| `VeriHash.Config.ps1` | 394 | `ConfigDirectory` | `Initialize-VeriHashConfig` entry log |
| `VeriHash.Config.ps1` | 404 | `ConfigDirectory` | Created config directory (init) |
| `VeriHash.Config.ps1` | 423 | `ConfigFile` | Created default configuration |

All 11 require adding `| ConvertTo-SanitizedPath` to the value expression.

### LOGC-02: Redundant PSFramework Detection (2 sites → 1)

| File | Line | Action |
|------|------|--------|
| `VeriHash.Config.ps1` | 28 | **Remove** — redundant |
| `VeriHash.ps1` | 155 | **Keep and move up** — before dot-sources, after platform detection |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ConvertTo-SanitizedPath` in main script only | Relocate to LogUtils for shared access | This phase | Config module can sanitize paths |
| Double `Get-Module -ListAvailable` | Single check before dot-sources | This phase | 100–500ms startup savings |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `VeriHash.LogUtils.ps1` has zero dependencies on `VeriHash.Config.ps1` | Pitfall 1 | Dot-source reorder breaks LogUtils loading |
| A2 | No Config tests will break from dot-source reorder alone (before adding sanitization calls) | Pitfall 4 | Tests fail unexpectedly |
| A3 | Moving `$script:PSFrameworkAvailable` before dot-sources doesn't cause timing issues | Pitfall 2 | Config logging silently disabled |

**Verification for A1:** Confirmed — grep of `VeriHash.LogUtils.ps1` shows no calls to any `VeriHash.Config.ps1` function (`Get-VeriHashConfig`, `Get-VeriHashConfigPath`, `Get-VeriHashDefaultConfig`, `Set-VeriHashConfig`, `Initialize-VeriHashConfig`). LogUtils is fully self-contained. [VERIFIED: codebase]

**Verification for A2:** `Tests/VeriHash.Config.Tests.ps1` BeforeAll only dot-sources `VeriHash.Config.ps1`. Config currently doesn't call `ConvertTo-SanitizedPath`. The reorder alone (PRIV-03) won't break Config tests — but adding sanitization calls (PRIV-02) will require Config tests to also dot-source LogUtils first. Sequence matters. [VERIFIED: codebase]

**Verification for A3:** The `$script:PSFrameworkAvailable` variable is used only in `if` guards. Setting it before dot-sources means it's available when Config loads. The `Get-Module -ListAvailable` call has no side effects; it just checks module availability. Moving it earlier is safe. [VERIFIED: codebase]

## Open Questions

1. **Should `ConvertTo-SanitizedPath` use `$script:RunningOnWindows` or local detection?**
   - What we know: The existing `ConvertFrom-SanitizedPath` in LogUtils uses a local `$RunningOnWindows` variable (line 74). The current `ConvertTo-SanitizedPath` in VeriHash.ps1 uses the script-scope `$RunningOnWindows` (line 125) that was set at VeriHash.ps1 line 96.
   - What's unclear: After relocation to LogUtils, `$RunningOnWindows` from VeriHash.ps1 scope won't be available during Config load.
   - Recommendation: Use local detection (matching `ConvertFrom-SanitizedPath` pattern) — `$RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform`. This is consistent with LogUtils convention and avoids scope dependency. The `$null -eq $PSVersionTable.Platform` check must be added (it's in Config line 23 but not in the current VeriHash.ps1 line 96 version).

2. **Should we add `ConvertTo-SanitizedPath` tests alongside the relocation?**
   - What we know: REQUIREMENTS.md TEST-01 (v2) explicitly calls out "Unit tests for `ConvertTo-SanitizedPath` and `ConvertFrom-SanitizedPath` (currently zero coverage)" as deferred.
   - What's unclear: Is it safe to relocate a function with zero test coverage?
   - Recommendation: The function is trivial (one regex replace per platform) and its behavior is transitively tested by any test that exercises logging with real paths. TEST-01 is v2 scope. Relocate without adding dedicated tests, but run full test suite to verify nothing regresses.

## Project Constraints (from copilot-instructions.md)

Extracted directives that the planner must enforce:

1. **PSFramework is optional** — every `Write-PSFMessage` call must be guarded by `if ($script:PSFrameworkAvailable)` [VERIFIED: copilot-instructions.md]
2. **Never log full hash values** — truncate to first 16 chars [VERIFIED: copilot-instructions.md line 125]
3. **Never log raw file paths** — always sanitize via `ConvertTo-SanitizedPath` [VERIFIED: copilot-instructions.md]
4. **TDD rule** — never modify tests to make them pass; modify the code [VERIFIED: copilot-instructions.md]
5. **Test isolation** — `$env:VERIHASH_TEST_MODE = '1'` in every Pester `BeforeAll` [VERIFIED: copilot-instructions.md]
6. **Non-interactive test invocations** — always pass `-NoPause -Force` when calling VeriHash.ps1 in tests [VERIFIED: copilot-instructions.md]
7. **PSScriptAnalyzer rules** — `PSAvoidUsingWriteHost` and `PSAvoidUsingBrokenHashAlgorithms` stay suppressed [VERIFIED: copilot-instructions.md]
8. **PowerShell 7+ only** — no Windows PowerShell 5.x compatibility [VERIFIED: copilot-instructions.md]
9. **Function signatures** — non-trivial functions use `[CmdletBinding()]`, `[OutputType()]`, and comment-based help [VERIFIED: CONVENTIONS.md]

## Sources

### Primary (HIGH confidence)
- `VeriHash.ps1` — direct code inspection of lines 96–213, 805–846, 1055–1069
- `VeriHash.Config.ps1` — direct code inspection of all 431 lines
- `VeriHash.LogUtils.ps1` — direct code inspection of all 279 lines
- `Verihash Logging Concepting.md` — direct inspection, 131 lines
- `.planning/codebase/CONCERNS.md` — audit findings
- `.planning/codebase/CONVENTIONS.md` — code conventions
- `.planning/codebase/ARCHITECTURE.md` — architecture patterns
- `.github/copilot-instructions.md` — project instructions
- Test run: 133 passed, 0 failed, 7 skipped (2026-04-18)

### Secondary (MEDIUM confidence)
- `.planning/REQUIREMENTS.md` — requirement definitions
- `.planning/ROADMAP.md` — phase scoping and success criteria

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; all changes to existing code with established patterns
- Architecture: HIGH — dot-source ordering verified with dependency analysis; no circular dependencies
- Pitfalls: HIGH — all pitfalls identified through direct code inspection; mitigations are concrete

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (stable codebase, no external dependency changes expected)
