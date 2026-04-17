# Codebase Concerns

**Analysis Date:** 2026-04-17

---

## Tech Debt

**Monolithic Main Script:**
- Issue: `VeriHash.ps1` is 1,373 lines of mixed concerns — param block, module imports, top-level initialization code, function definitions, and script execution all live in a single file. Functions cannot be unit tested without dot-sourcing the entire script and suppressing side effects.
- Files: `VeriHash.ps1`
- Impact: Every test in `Tests/VeriHash.Tests.ps1` uses the hack `. "$PSScriptRoot\..\VeriHash.ps1" -FilePath "dummy" -ErrorAction SilentlyContinue 2>$null` (line 7) to load functions. This is fragile — any unguarded runtime error during dot-source breaks the entire test suite silently.
- Fix approach: Extract all function definitions into a `VeriHash.Functions.ps1` module that can be dot-sourced cleanly, with `VeriHash.ps1` as a thin entry point that handles params and calls `Invoke-HashFile`.

**Unapproved Function Verb (`Get-And-SaveHash`):**
- Issue: `Get-And-SaveHash` (defined at `VeriHash.ps1` line 805) uses a hyphenated compound verb that violates PowerShell naming conventions. PSScriptAnalyzer would flag `PSUseApprovedVerbs` if this were a module export.
- Files: `VeriHash.ps1` line 805
- Impact: Low for a script tool; becomes blocking if the project is ever converted to a module.
- Fix approach: Rename to `Invoke-HashFile` or `Save-FileHash` when the monolith is split.

**Redundant `$script:PSFrameworkAvailable` Detection:**
- Issue: The availability check `$null -ne (Get-Module -ListAvailable -Name PSFramework)` is performed twice — once in `VeriHash.Config.ps1` line 28 (at dot-source time) and again in `VeriHash.ps1` line 155 (after `Get-VeriHashConfig` is called). The second assignment overwrites the first with identical logic.
- Files: `VeriHash.Config.ps1` line 28, `VeriHash.ps1` line 155
- Impact: `Get-Module -ListAvailable` is a slow operation (~100–500ms); running it twice wastes startup time.
- Fix approach: Remove the duplicate in `VeriHash.Config.ps1` and rely on the authoritative check in `VeriHash.ps1`. Alternatively, define one shared bootstrap function called once.

**`QuickHash.ps1` Is an Orphaned Diverged Tool:**
- Issue: `QuickHash.ps1` is a standalone interactive script that uses raw .NET crypto APIs (`[System.Security.Cryptography.MD5]::Create()`) rather than `Get-FileHash`. It only supports MD5 and SHA256, has no SHA512, no PSFramework logging, no sidecar support, no path sanitization, and no `-NoPause` equivalent. It also logs the full input value and hash to console without any privacy consideration.
- Files: `QuickHash.ps1`
- Impact: Creates user confusion about which tool to use; diverges from VeriHash conventions without a clear purpose; test coverage exists (`Tests/QuickHash.Tests.ps1`) but tests a diverged code path.
- Fix approach: Either deprecate and remove, or make it a thin wrapper that calls `VeriHash.ps1`.

**Build.ps1 Is a Partial Stub:**
- Issue: `Build.ps1` explicitly describes itself as a placeholder for future features (packaging, signing, documentation generation, changelog parsing). Currently it only runs tests and optionally updates a version string via regex.
- Files: `Build.ps1`
- Impact: No release automation; version bumping is a string regex replace with no validation or changelog synchronization.
- Fix approach: Implement changelog-to-release-notes extraction and version validation before v2.0.

---

## Known Bugs / Privacy Violations

**Full Hash Value Logged Untruncated in `Get-And-SaveHash`:**
- Issue: Line 839 of `VeriHash.ps1` logs the **complete** hash value in both the message string (`"Hash computed: $hashValue"`) and the `-Data` block (`Hash = $hashValue`). The project policy (documented in `.github/copilot-instructions.md` line 125) explicitly requires hash values to be truncated to 16 characters before logging. The correct pattern — `$InputHash.Substring(0, [Math]::Min(16, $InputHash.Length)) + '...'` — is used at line 1063 but is absent here.
- Files: `VeriHash.ps1` lines 839–845
- Impact: **Privacy violation** — full SHA256/SHA512 hashes (64/128 hex chars) are written to the JSON log files, which could be correlated with known-file databases to identify what files a user has on their system (a form of behavioral fingerprinting).
- Fix approach: Replace `$hashValue` in the message with `$hashValue.Substring(0, 16) + '...'` and apply the same truncation in the `-Data` block. Apply consistently in all `Write-PSFMessage` calls that include hash values.

**Config Paths Logged Without Sanitization in `VeriHash.Config.ps1`:**
- Issue: Multiple `Write-PSFMessage` calls in `VeriHash.Config.ps1` log `ConfigDirectory` and `ConfigFile` raw path strings (e.g., lines 161–162, 215, 228, 321–322, 331, 348, 394, 404, 423). These paths contain the OS username (`C:\Users\username\AppData\Roaming\VeriHash\config.json`). The `ConvertTo-SanitizedPath` helper that should sanitize these is defined in `VeriHash.ps1` (line 108), which is not available inside `VeriHash.Config.ps1` — it cannot be called there.
- Files: `VeriHash.Config.ps1` lines 161, 162, 215, 228, 321, 322, 331, 348, 394, 404, 423
- Impact: **Privacy violation** — usernames are written to log files, contradicting GDPR Article 5(1)(c) data minimization intent.
- Fix approach: Move `ConvertTo-SanitizedPath` (or a simplified inline version) to `VeriHash.Config.ps1` or `VeriHash.LogUtils.ps1` so it can be called by Config functions. Alternatively, pass pre-sanitized paths as parameters to the logging calls.

---

## Security Considerations

**VirusTotal API Key Stored in Plaintext:**
- Risk: `config.json` stores `virustotal.apiKey` in plaintext on disk. On Windows this is `%APPDATA%\VeriHash\config.json`; on Linux/macOS it is `~/.verihash/config.json`. Any process or user with filesystem access can read the key.
- Files: `VeriHash.Config.ps1` lines 195–198, 256–258; `Get-VeriHashDefaultConfig` (line 88)
- Current mitigation: The key is never logged (only `VTHasApiKey = ($config.virustotal.apiKey -ne '')` is logged, line 274 in `VeriHash.Config.ps1`). The key is only read from env var `VERIHASH_VT_APIKEY` or config file.
- Recommendations: Recommend using the `VERIHASH_VT_APIKEY` environment variable over the config file for the API key. Consider documenting that the config file should have restricted permissions (`chmod 600` on Linux). When the VT integration is implemented (Phase 3), add a warning in `Set-VeriHashConfig` if the API key is being written to disk.

**VirusTotal Config Section Enabled by Default Without Implementation:**
- Risk: `Get-VeriHashDefaultConfig` sets `virustotal.enabled = $true` (line 89 of `VeriHash.Config.ps1`). The VT integration is explicitly not started (Phase 3). If a user sets an API key in `VERIHASH_VT_APIKEY`, nothing consumes it yet, but the default `enabled: true` in generated config files may mislead users.
- Files: `VeriHash.Config.ps1` line 89
- Current mitigation: No VT code paths exist yet; the flag is unused.
- Recommendations: Change the default to `enabled = $false` until the feature is implemented. Add a comment in the config file noting the feature is planned.

**No Execution Policy Bypass on Linux KDE Context Menu:**
- Risk: The KDE `.desktop` file generated by `Install-KDEContextMenu` uses `-ExecutionPolicy Bypass` (line 524 of `VeriHash.ps1`). While appropriate for a user-installed tool, system-wide installation (`-SystemWide`) applies the same bypass to all users without the context of a per-user decision.
- Files: `VeriHash.ps1` lines 524–528
- Current mitigation: System-wide install requires root privilege check.
- Recommendations: Document the security implication in the README for system-wide installs.

---

## Performance Bottlenecks

**O(n²) Log Entry Accumulation in `ConvertFrom-VeriHashLog`:**
- Problem: `$logEntries += $flatEntry` (line 203 of `VeriHash.LogUtils.ps1`) uses PowerShell array concatenation inside a foreach loop. PowerShell arrays are fixed-size; `+=` creates a new array every iteration.
- Files: `VeriHash.LogUtils.ps1` line 203
- Cause: Naive `+=` pattern. For 200 entries this is negligible; for thousands of entries across multiple large daily log files it becomes quadratic in time and memory.
- Improvement path: Replace with `[System.Collections.Generic.List[PSCustomObject]]` initialized before the loop, and use `.Add($flatEntry)`. Cast to array before return: `return [PSCustomObject[]]$logEntries.ToArray()`.

**Double `Get-Module -ListAvailable` on Startup:**
- Problem: `Get-Module -ListAvailable -Name PSFramework` is called twice (Config.ps1 line 28 and VeriHash.ps1 line 155), adding 100–500ms to startup.
- Files: `VeriHash.Config.ps1` line 28, `VeriHash.ps1` line 155
- Cause: Redundant detection (see Tech Debt section).
- Improvement path: Single detection at the start of `VeriHash.ps1` before dot-sourcing.

---

## Fragile Areas

**Test Dot-Source Hack for Loading Functions:**
- Files: `Tests/VeriHash.Tests.ps1` line 7
- Why fragile: `. "$PSScriptRoot\..\VeriHash.ps1" -FilePath "dummy" -ErrorAction SilentlyContinue 2>$null` executes the entire script with a nonexistent file path, relying on the error being suppressed. If any top-level code path before function definitions throws a terminating error that escapes `-ErrorAction SilentlyContinue`, all tests in the suite will fail to load functions silently. Adding new top-level logic to `VeriHash.ps1` can break all tests without any obvious error message.
- Safe modification: Always test after adding any top-level code to `VeriHash.ps1`. Long-term fix: extract functions into a separate dot-sourceable file.
- Test coverage: Depends on this working; if it breaks, 0 tests run rather than failing visibly.

**`.sha2` and `.sha2_256` Legacy Extension Handling:**
- Files: `VeriHash.ps1` line 1103
- Why fragile: These legacy extensions are recognized as sidecar files and routed to `Test-HashSidecar`. However, `Get-And-SaveHash` never creates `.sha2` or `.sha2_256` files (only `.md5`, `.sha256`, `.sha512`). If a user has an old `.sha2_256` sidecar and the format inside differs from the expected `HASH  filename` pattern, parsing may fail silently (`Write-Warning` at line 1513 and continue). No tests exist for either extension.
- Test coverage: Zero test coverage for `.sha2` and `.sha2_256` paths.

**`Select-File` Dialog Depends on `System.Windows.Forms`:**
- Files: `VeriHash.ps1` line 647
- Why fragile: `Add-Type -AssemblyName System.Windows.Forms` can fail on some Windows configurations (headless, Server Core, or when running without a display). The failure is caught and falls back to `Read-Host`, which itself requires an interactive console. In automated or non-interactive contexts (e.g., batch processing, CI), this path is untested.
- Test coverage: No test covers the `Select-File` fallback path.

**Sidecar Conflict Interaction Flow Has No Timeout:**
- Files: `VeriHash.ps1` lines 964–1040 (the `Read-Host` prompt inside `Get-And-SaveHash`)
- Why fragile: When a sidecar mismatch is detected without `-Force`, the script blocks indefinitely on `Read-Host`. If called non-interactively (e.g., from another script or scheduler), the process hangs forever. The `-Force` flag prevents this, but there is no `-NoPause`-style timeout parameter for the sidecar conflict prompt specifically.
- Test coverage: Tests mock `Read-Host` correctly, but only the `'k'` (keep) branch is tested in the non-Force path (`Tests/VeriHash.Tests.ps1` line 517); the `'u'` (update) and `'r'` (rename) interactive branches are not covered by integration tests.

---

## Scaling Limits

**No Log Rotation or Cleanup:**
- Current capacity: PSFramework creates a new JSON file per day (`verihash-%date%.json`). Old files are never deleted.
- Limit: On an active machine, log files accumulate indefinitely. No `MaxDays`, `MaxSize`, or cleanup mechanism is configured in the `Set-PSFLoggingProvider` call (`VeriHash.ps1` line 183).
- Scaling path: Add `-KeepFilesFor` or `-MaxLogFiles` parameter to `Set-PSFLoggingProvider`, or add a cleanup function to `VeriHash.LogUtils.ps1` that prunes log files older than N days.

---

## Dependencies at Risk

**PSFramework Is Optional but Central to Diagnostics:**
- Risk: PSFramework is listed as optional (`Install-Module PSFramework -Scope CurrentUser`) but is the sole logging mechanism. If it is not installed, all structured logging is silently lost. Users debugging issues will have no log data.
- Impact: Reduces debuggability for users who haven't installed PSFramework.
- Migration plan: No alternative logging fallback currently exists. Consider adding a minimal `Write-Verbose`/`Write-Debug` fallback inside the `if (-not $script:PSFrameworkAvailable)` block for critical events.

---

## Missing Critical Features

**No CI/CD Pipeline:**
- Problem: The only file in `.github/` is `copilot-instructions.md`. There are no GitHub Actions workflows for automated test execution on push/PR.
- Blocks: Regressions can be introduced on any branch without automated detection. The `Test-All.ps1 -CI` flag exists but is never invoked automatically.

**VirusTotal Integration (Phase 3) Not Started:**
- Problem: Config schema, environment variable docs, and defaults for VirusTotal are fully in place, but no implementation exists. `virustotal.enabled = $true` in default config but does nothing.
- Files: `VeriHash.Config.ps1` lines 87–93, `VeriHash.ps1` (no VT code)
- Blocks: Users cannot use the feature; the config section creates a false impression of functionality.

**No Manifest/Multi-File Support:**
- Problem: Documented in `Verihash Multifile Concepting.md` (planning phase, scope locked for MVP). VeriHash processes exactly one file at a time. Multi-select via Send To is not yet supported.
- Blocks: Power users cannot hash multiple files in one operation.

**PSScriptAnalyzer Does Not Analyze `VeriHash.Config.ps1` or `VeriHash.LogUtils.ps1`:**
- Problem: `Test-All.ps1` runs `Invoke-ScriptAnalyzer` only against `VeriHash.ps1` (line 116). The two supporting modules are not linted.
- Files: `Test-All.ps1` line 116
- Blocks: Style violations, unapproved verbs, or missing `[CmdletBinding()]` in Config/LogUtils go undetected.
- Fix: Expand `$scriptPath` in `Test-All.ps1` to an array: `@('VeriHash.ps1', 'VeriHash.Config.ps1', 'VeriHash.LogUtils.ps1')` and loop.

---

## Test Coverage Gaps

**Legacy Sidecar Extensions (`.sha2`, `.sha2_256`):**
- What's not tested: Detection as a verification file, routing to `Test-HashSidecar`, and parsing of the content format.
- Files: `VeriHash.ps1` line 1103, `Tests/VeriHash.Tests.ps1`
- Risk: Silent regression if legacy format parsing breaks.
- Priority: Low (legacy users; new users get `.sha256`)

**`Select-File` Fallback Path:**
- What's not tested: The `Add-Type` failure → `Read-Host` fallback in `Select-File` (lines 647–672).
- Files: `VeriHash.ps1` lines 644–673, `Tests/VeriHash.Tests.ps1`
- Risk: Interactive file selection may silently fail on headless or Server environments.
- Priority: Medium

**Sidecar Conflict Interactive Branches (Update / Rename):**
- What's not tested: The `'u'` (update) and `'r'` (rename) user choices in the non-Force mismatch prompt (lines 971–1007 of `VeriHash.ps1`).
- Files: `VeriHash.ps1` lines 971–1007, `Tests/VeriHash.Tests.ps1`
- Risk: Silent regressions in the interactive update and rename paths.
- Priority: Medium

**`Install-KDEContextMenu` and `Install-WindowsSendTo` Functions:**
- What's not tested: No tests exist for any context menu installation path.
- Files: `VeriHash.ps1` lines 309–581, `Tests/`
- Risk: Platform-specific installation regressions go undetected.
- Priority: Low (not on hot path; hard to mock filesystem + COM objects)

**`Get-VeriHashLogSummary` Statistics:**
- What's not tested: The grouping and counting logic in `Get-VeriHashLogSummary` (`VeriHash.LogUtils.ps1` lines 253–277). Only `ConvertFrom-VeriHashLog` is directly tested.
- Files: `VeriHash.LogUtils.ps1` lines 221–278, `Tests/VeriHash.LogUtils.Tests.ps1`
- Risk: Incorrect summary statistics go unnoticed.
- Priority: Low

---

*Concerns audit: 2026-04-17*
