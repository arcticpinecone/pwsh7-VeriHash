# Architecture Patterns: Path Sanitization Sharing

**Domain:** PowerShell dot-sourced module dependency ordering for privacy-compliant logging
**Researched:** 2025-07-18
**Confidence:** HIGH — all findings derived from direct codebase analysis

## Problem Statement

`ConvertTo-SanitizedPath` (defined at `VeriHash.ps1:108`) replaces `$env:USERPROFILE` / `$HOME` with `%USERPROFILE%` / `~` before log payloads are written. It is unavailable inside `VeriHash.Config.ps1` because Config is dot-sourced **before** the function is defined.

**Loading order in VeriHash.ps1:**
```
Line 101: . "$PSScriptRoot\VeriHash.Config.ps1"   ← dot-sourced first
Line 102: . "$PSScriptRoot\VeriHash.LogUtils.ps1"  ← dot-sourced second
Line 108: function ConvertTo-SanitizedPath { ... } ← defined third
Line 138: $script:VeriHashConfig = Get-VeriHashConfig  ← Config functions first CALLED here
```

**Result:** 11 `Write-PSFMessage` calls in `VeriHash.Config.ps1` log `ConfigDirectory` and `ConfigFile` as raw paths containing OS usernames — a GDPR Article 5(1)(c) violation.

### Subtlety: Define-Time vs. Call-Time

PowerShell dot-sourcing makes functions available in the caller's scope. Functions resolve references **at call-time**, not define-time. This means Config functions *could* call `ConvertTo-SanitizedPath` at runtime when invoked from VeriHash.ps1 (line 138), because by then the function exists in scope.

**However, this fails when:**
- Config.ps1 is dot-sourced standalone (as in `Tests/VeriHash.Config.Tests.ps1:4`)
- Any future consumer dot-sources Config.ps1 independently

The function must be **structurally available** to Config.ps1 — relying on implicit scope from a parent script is fragile and untestable.

---

## Approaches Evaluated

### Approach 1: Move `ConvertTo-SanitizedPath` to `VeriHash.LogUtils.ps1` ⭐ RECOMMENDED

**What:** Relocate `ConvertTo-SanitizedPath` from `VeriHash.ps1:108-133` into `VeriHash.LogUtils.ps1`, alongside its inverse `ConvertFrom-SanitizedPath` (already there). Reorder dot-sources so LogUtils loads first. Add `ConvertTo-SanitizedPath` calls in Config's `Write-PSFMessage` data blocks.

**Changes required:**

| File | Change | Lines Affected |
|------|--------|----------------|
| `VeriHash.LogUtils.ps1` | Add `ConvertTo-SanitizedPath` function with local `$RunningOnWindows` detection (matching existing `ConvertFrom-SanitizedPath` pattern) | +25 lines |
| `VeriHash.ps1` | Remove `ConvertTo-SanitizedPath` definition (lines 108-133); swap dot-source order (lines 101-102) | -26 lines, 2 lines swapped |
| `VeriHash.Config.ps1` | Add `| ConvertTo-SanitizedPath` to 11 path values in `-Data` blocks | 11 line edits |
| `Tests/VeriHash.Config.Tests.ps1` | Add `. "$PSScriptRoot\..\VeriHash.LogUtils.ps1"` before Config dot-source | +1 line |

**Implementation detail — platform detection:**
`ConvertTo-SanitizedPath` currently references bare `$RunningOnWindows` from VeriHash.ps1's scope. In LogUtils, it must use a function-local variable (matching the existing `ConvertFrom-SanitizedPath` pattern):

```powershell
function ConvertTo-SanitizedPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(ValueFromPipeline)]
        [string]$Path
    )
    process {
        if ([string]::IsNullOrEmpty($Path)) { return $Path }
        $RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT'
        if ($RunningOnWindows) {
            $Path -replace [regex]::Escape($env:USERPROFILE), '%USERPROFILE%'
        } else {
            $Path -replace [regex]::Escape($HOME), '~'
        }
    }
}
```

**Pros:**
- **Natural pairing:** `ConvertTo-` and `ConvertFrom-SanitizedPath` belong together — they're inverse operations. LogUtils already owns the `ConvertFrom-` side.
- **Zero code duplication:** Single definition, single source of truth.
- **LogUtils stays standalone:** It has no dependencies today; `ConvertTo-SanitizedPath` adds none (only uses `$PSVersionTable`, `$env:USERPROFILE`, `$HOME`).
- **Minimal blast radius:** 8 callers in VeriHash.ps1 continue to work unchanged — the function is still in scope via dot-source. Config gains access via the reordered dot-source.
- **Testable independently:** LogUtils tests can cover both sanitization directions in isolation. Config tests add one dot-source line.
- **Aligns with future monolith split:** When VeriHash.ps1 is eventually split, LogUtils is already the sanitization home — no second migration needed.

**Cons:**
- **Dot-source reorder changes initialization sequence:** LogUtils before Config instead of Config before LogUtils. Must verify no Config top-level code depends on LogUtils, and vice versa. *(Verified: no cross-dependency exists in top-level code.)*
- **Config tests gain a dependency:** `VeriHash.Config.Tests.ps1` must now dot-source LogUtils first. This is a conceptually appropriate dependency (Config logs → needs sanitization helpers) but does increase test setup.
- **Existing `ConvertTo-SanitizedPath` callers use pipeline syntax** (`$Path | ConvertTo-SanitizedPath`): Must verify the function-local `$RunningOnWindows` works correctly in the `process {}` block. *(Verified: same pattern `ConvertFrom-SanitizedPath` uses successfully.)*

**Test impact:** LOW
- No existing tests reference `ConvertTo-SanitizedPath` (zero coverage today — verified via `Select-String` across all test files)
- No existing tests reference `ConvertFrom-SanitizedPath` either
- VeriHash.Tests.ps1 dot-sources the full VeriHash.ps1 which will still load LogUtils → function is in scope
- Config tests need 1 additional dot-source line
- **Should add:** New test block in `VeriHash.LogUtils.Tests.ps1` covering both `ConvertTo-` and `ConvertFrom-SanitizedPath`

---

### Approach 2: Inline a Private Sanitization Helper in Config.ps1

**What:** Define a script-scoped helper function directly inside `VeriHash.Config.ps1` that duplicates the sanitization logic. Config uses this private function; VeriHash.ps1 keeps its own `ConvertTo-SanitizedPath`.

```powershell
# At top of VeriHash.Config.ps1, after platform detection
function script:SanitizeConfigPath {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return $Path }
    if ($script:RunningOnWindows) {
        $Path -replace [regex]::Escape($env:USERPROFILE), '%USERPROFILE%'
    } else {
        $Path -replace [regex]::Escape($HOME), '~'
    }
}
```

**Changes required:**

| File | Change | Lines Affected |
|------|--------|----------------|
| `VeriHash.Config.ps1` | Add `SanitizeConfigPath` function (~10 lines); replace 11 raw paths with `SanitizeConfigPath $configDir` | +10 lines, 11 line edits |

**Pros:**
- **Self-contained:** Config.ps1 gains zero external dependencies. Tests unchanged.
- **Smallest blast radius:** No file reordering, no cross-module changes, no test modifications.
- **Fast to implement:** One file, one function, done.

**Cons:**
- **DRY violation:** Same sanitization logic in two places. When the logic evolves (e.g., adding macOS `$HOME` patterns, or handling UNC paths), both must be updated.
- **Naming divergence:** `SanitizeConfigPath` (Config) vs. `ConvertTo-SanitizedPath` (VeriHash.ps1) — two names for the same operation creates cognitive overhead.
- **Defers the real fix:** The monolith split milestone will need to consolidate these anyway. This approach creates tech debt instead of reducing it.
- **`script:` scope function in a dot-sourced file leaks into the parent's scope** — `SanitizeConfigPath` becomes callable from VeriHash.ps1, which is unexpected and could mask bugs.

**Test impact:** NONE (no test changes required — but also no new test coverage for the duplicate function)

---

### Approach 3: Create `VeriHash.PathUtils.ps1` Shared Utility File

**What:** Extract `ConvertTo-SanitizedPath` into a new file `VeriHash.PathUtils.ps1`. Dot-source it first in VeriHash.ps1 (before Config and LogUtils). Config tests and LogUtils tests also dot-source it.

**Changes required:**

| File | Change | Lines Affected |
|------|--------|----------------|
| `VeriHash.PathUtils.ps1` | **New file** containing `ConvertTo-SanitizedPath` | +25 lines (new file) |
| `VeriHash.ps1` | Remove function definition; add dot-source of PathUtils before Config/LogUtils | -26 lines, +1 line |
| `VeriHash.Config.ps1` | Add `| ConvertTo-SanitizedPath` to 11 path data values | 11 line edits |
| `Tests/VeriHash.Config.Tests.ps1` | Add `. "$PSScriptRoot\..\VeriHash.PathUtils.ps1"` | +1 line |
| `Test-All.ps1` | Add PathUtils to PSScriptAnalyzer targets | +1 line |

**Pros:**
- **Explicit dependency:** The file name signals "shared utility."
- **No reordering of existing files:** Just prepend a new dot-source.

**Cons:**
- **Over-engineered for one function:** A whole file for a 15-line function is excessive.
- **Splits the sanitization pair:** `ConvertTo-SanitizedPath` in PathUtils, `ConvertFrom-SanitizedPath` stays in LogUtils. The inverse functions belong together.
- **Maintenance overhead:** New file to lint, test, document, and maintain.
- **Proliferates dot-source chain:** VeriHash.ps1 goes from 2 dot-sources to 3, increasing complexity for an already-acknowledged monolith problem.
- **Will need consolidation during monolith split anyway:** The new file becomes another thing to merge/reorganize later.

**Test impact:** LOW (one additional dot-source per affected test file)

---

### Approach 4: Guard Pattern with Graceful Degradation

**What:** Config functions check if `ConvertTo-SanitizedPath` exists before calling it. If unavailable, log the raw path (accepting the privacy gap in standalone contexts).

```powershell
# In each Write-PSFMessage -Data block:
ConfigDirectory = if (Get-Command ConvertTo-SanitizedPath -ErrorAction SilentlyContinue) {
    $configDir | ConvertTo-SanitizedPath
} else { $configDir }
```

**Pros:**
- **Zero structural changes:** No file moves, no reordering, no new files.
- **Backward compatible:** Works in every context — when called from VeriHash.ps1 (sanitized) and standalone (raw).

**Cons:**
- **Does not fix the privacy violation** when Config is used standalone or in tests. This is a workaround, not a fix.
- **`Get-Command` check on every log call:** Performance cost (~1ms per call × 11 calls × every invocation). Adds up.
- **Verbose boilerplate:** Every data block gets a 3-line conditional instead of a clean pipe. Config becomes harder to read.
- **Masks the architectural problem:** The dependency is real — hiding it behind a guard doesn't resolve it.

**Test impact:** NONE — but the privacy gap in tests remains.

---

## Recommendation

**Use Approach 1: Move `ConvertTo-SanitizedPath` to `VeriHash.LogUtils.ps1`.**

### Rationale

| Criterion | Approach 1 (LogUtils) | Approach 2 (Inline) | Approach 3 (PathUtils) | Approach 4 (Guard) |
|-----------|----------------------|--------------------|-----------------------|-------------------|
| Fixes privacy violation | ✅ Fully | ✅ Fully | ✅ Fully | ⚠️ Partial |
| DRY compliance | ✅ Single source | ❌ Duplicate logic | ✅ Single source | ✅ Single source |
| Blast radius | Low (swap + move) | Lowest (1 file) | Low (new file) | Lowest (edits only) |
| Test changes | +1 line in Config tests | None | +1 line in Config tests | None |
| Future-proof (monolith split) | ✅ Already in final home | ❌ Creates more debt | ⚠️ Needs consolidation | ❌ Defers problem |
| Pairs `ConvertTo-`/`ConvertFrom-` | ✅ Same file | ❌ Different files | ❌ Different files | ❌ Different files |
| New files | 0 | 0 | 1 | 0 |

Approach 1 wins on every criterion except "smallest blast radius" (where Approach 2 wins trivially). But Approach 2's blast-radius advantage is illusory — it creates a DRY violation that must be cleaned up later, making the *total* blast radius across milestones larger.

Approach 1 is the **only approach where the function ends up in its permanent home**, meaning zero rework during the future monolith split milestone.

### Implementation Order

1. **Add `ConvertTo-SanitizedPath` to `VeriHash.LogUtils.ps1`** — with function-local `$RunningOnWindows` detection
2. **Remove function definition from `VeriHash.ps1:108-133`** — the region comment can stay as a pointer
3. **Swap dot-source order in `VeriHash.ps1`** — LogUtils before Config (lines 101-102)
4. **Add sanitization calls to `VeriHash.Config.ps1`** — pipe path values through `ConvertTo-SanitizedPath` in all 11 `-Data` blocks
5. **Update `Tests/VeriHash.Config.Tests.ps1`** — add LogUtils dot-source before Config dot-source
6. **Add tests for `ConvertTo-SanitizedPath` and `ConvertFrom-SanitizedPath`** in `VeriHash.LogUtils.Tests.ps1`
7. **Verify all 133 existing tests pass** — regression check

### Dependency Safety Verification

Before committing to the reorder, verify these invariants hold (all verified in this research):

| Invariant | Status |
|-----------|--------|
| LogUtils top-level code has no dependency on Config | ✅ Verified — LogUtils defines functions only, no `$script:` vars from Config |
| Config top-level code has no dependency on LogUtils | ✅ Verified — Config's top-level does platform detection + PSFramework check, neither uses LogUtils |
| Config functions don't call LogUtils functions at define-time | ✅ Verified — Config functions are called at line 138+, well after all dot-sources |
| VeriHash.ps1 callers of `ConvertTo-SanitizedPath` (8 call sites) remain unaffected | ✅ Verified — function is in scope via dot-source regardless of which file defines it |
| `ConvertTo-SanitizedPath` has zero existing test coverage | ✅ Verified — no `Select-String` hits across all test files |

---

## Component Boundaries (Post-Fix)

```
VeriHash.LogUtils.ps1 (standalone, no deps)
├── Get-VeriHashLogPath
├── ConvertTo-SanitizedPath    ← moved here
├── ConvertFrom-SanitizedPath  ← already here
├── ConvertFrom-VeriHashLog
└── Get-VeriHashLogSummary

VeriHash.Config.ps1 (depends on: LogUtils for sanitization)
├── Get-VeriHashConfigPath
├── Get-VeriHashDefaultConfig
├── Get-VeriHashConfig          ← now sanitizes paths in log data
├── Set-VeriHashConfig          ← now sanitizes paths in log data
└── Initialize-VeriHashConfig   ← now sanitizes paths in log data

VeriHash.ps1 (depends on: LogUtils, Config)
├── dot-sources LogUtils first  ← reordered
├── dot-sources Config second   ← reordered
├── [ConvertTo-SanitizedPath removed — now in LogUtils]
├── 8 existing call sites unchanged
└── all other functions unchanged
```

## Data Flow: Path Sanitization After Fix

```
User invokes VeriHash.ps1
  │
  ├─ dot-source LogUtils.ps1 → ConvertTo-SanitizedPath now available
  ├─ dot-source Config.ps1   → function definitions loaded (not yet called)
  │
  ├─ ConvertTo-SanitizedPath defined ← [REMOVED, now in LogUtils]
  │
  ├─ Get-VeriHashConfig called (line 138)
  │    └─ Write-PSFMessage -Data @{ ConfigFile = $configFile | ConvertTo-SanitizedPath }
  │         └─ Logs: %USERPROFILE%\AppData\Roaming\VeriHash\config.json ✅
  │
  └─ Invoke-HashFile called (line 1552)
       └─ 8 existing ConvertTo-SanitizedPath calls unchanged ✅
```

## Anti-Patterns to Avoid

### Anti-Pattern: Relying on Implicit Parent Scope
**What:** Calling `ConvertTo-SanitizedPath` from Config functions without ensuring it's structurally available — relying on VeriHash.ps1 having defined it "by the time Config functions run."
**Why bad:** Works in production but breaks in tests, breaks if Config is ever used independently, makes dependency invisible.
**Instead:** Make the dependency explicit via dot-source ordering.

### Anti-Pattern: Duplicating Sanitization Logic
**What:** Copying the regex replace logic into Config.ps1 as a private helper.
**Why bad:** Two implementations of the same security-sensitive logic. If one is updated (e.g., to handle UNC paths or `$env:HOME` vs `$HOME` edge cases), the other silently diverges.
**Instead:** Single function in LogUtils, shared via dot-source chain.

### Anti-Pattern: Creating Single-Function Utility Files
**What:** `VeriHash.PathUtils.ps1` for one 15-line function.
**Why bad:** File proliferation in a project that already has a monolith problem acknowledged as deferred. Each new dot-source file increases the surface area of the eventually-needed split.
**Instead:** Use the existing file that already owns the inverse operation.

---

## Sources

- Direct codebase analysis: `VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1` — line-level review
- `.planning/codebase/ARCHITECTURE.md` — module loading order and layer descriptions
- `.planning/codebase/CONCERNS.md` — privacy violation documentation (lines 49-53)
- `.planning/PROJECT.md` — monolith split explicitly out of scope for this milestone
- `Tests/VeriHash.Config.Tests.ps1` — Config tests dot-source Config standalone (line 4)
- `Tests/VeriHash.LogUtils.Tests.ps1` — LogUtils tests dot-source LogUtils standalone (line 4)
- `Tests/VeriHash.Tests.ps1` — Main tests dot-source full VeriHash.ps1 with hack (line 7)
- `Select-String` verification: zero test coverage for either sanitization function across all test files

*Architecture research: 2025-07-18*
