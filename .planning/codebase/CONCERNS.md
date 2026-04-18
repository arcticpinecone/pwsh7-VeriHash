# Codebase Concerns

**Analysis Date:** 2026-04-18

---

## Tech Debt

**Monolithic Main Script:**
- Issue: `VeriHash.ps1` is 1,527 lines of mixed concerns — param block, module imports, top-level initialization, function definitions, and script execution all live in a single file. Functions cannot be unit tested without dot-sourcing the entire script and suppressing side effects.
- Files: `VeriHash.ps1`
- Impact: Every test in `Tests/VeriHash.Tests.ps1` uses the hack `. "$PSScriptRoot\..\VeriHash.ps1" -FilePath "dummy" -ErrorAction SilentlyContinue 2>$null` (line 7) to load functions. Any unguarded runtime error during dot-source breaks the entire test suite silently.
- Fix approach: Extract all function definitions into a `VeriHash.Functions.ps1` module that can be dot-sourced cleanly, with `VeriHash.ps1` as a thin entry point that handles params and calls `Invoke-HashFile`.

**Unapproved Function Verb (`Get-And-SaveHash`):**
- Issue: `Get-And-SaveHash` (defined at `VeriHash.ps1` line 779) uses a hyphenated compound verb that violates PowerShell naming conventions. PSScriptAnalyzer would flag `PSUseApprovedVerbs` if this were a module export.
- Files: `VeriHash.ps1` line 779
- Impact: Low for a script tool; becomes blocking if the project is ever converted to a module.
- Fix approach: Rename to `Save-FileHash` or `New-FileHash` when the monolith is split. Note: `Invoke-HashFile` is already in use (line 1023).

**Triplicated Platform Detection Logic:**
- Issue: Platform detection (`$RunningOnWindows`, `$RunningOnLinux`, etc.) is defined independently in three files with **inconsistent** implementations:
  - `VeriHash.ps1` lines 96–97: `$RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT'` (no `$null` check)
  - `VeriHash.Config.ps1` lines 23–25: `$script:RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform` (includes `$null` check for PS 5.1 compatibility)
  - `VeriHash.LogUtils.ps1` lines 35, 74, 116: Re-detected as a local variable inside **each function body** — three separate times within the same file
- Files: `VeriHash.ps1` lines 96–97, `VeriHash.Config.ps1` lines 23–25, `VeriHash.LogUtils.ps1` lines 35, 74, 116
- Impact: The inconsistency could cause platform-detection mismatch if `$PSVersionTable.Platform` is `$null` (Windows PowerShell 5.1). While VeriHash requires PS7+, the Config module defensively includes the `$null` check but the main script does not. The LogUtils file re-detects locally in each function, which is wasteful and divergent.
- Fix approach: Define platform detection once in `VeriHash.ps1` before dot-sourcing modules. Use `$script:` scope so it propagates to dot-sourced modules. Remove all local re-declarations in LogUtils and Config.

**`QuickHash.ps1` Is an Orphaned Diverged Tool:**
- Issue: `QuickHash.ps1` (97 lines) is a standalone interactive script that uses raw .NET crypto APIs (`[System.Security.Cryptography.MD5]::Create()`) instead of `Get-FileHash`. It only supports MD5 and SHA256, has no SHA512, no PSFramework logging, no sidecar support, no path sanitization, and no `-NoPause` equivalent. It logs full input values and hashes to the console without any privacy consideration.
- Files: `QuickHash.ps1`, `Tests/QuickHash.Tests.ps1`
- Impact: Creates user confusion about which tool to use; diverges from VeriHash conventions without a clear purpose. `Tests/QuickHash.Tests.ps1` (282 lines) tests a completely independent code path.
- Fix approach: Either deprecate and remove, or make it a thin wrapper that calls `VeriHash.ps1`.

**`QuickHash.Tests.ps1` Contains Interactive Pester Install Prompt:**
- Issue: `Tests/QuickHash.Tests.ps1` lines 1–37 include an interactive `Read-Host` prompt to install Pester if missing. This code executes unconditionally before `BeforeAll` and will block CI runners that pipe to non-interactive shells.
- Files: `Tests/QuickHash.Tests.ps1` lines 1–37
- Impact: In CI, if Pester is somehow missing, the test runner hangs waiting for input instead of failing fast. The CI workflow (`.github/workflows/ci.yml`) installs Pester explicitly, so this prompt is redundant for CI but dangerous as a pattern.
- Fix approach: Remove the interactive prompt; rely on `Test-All.ps1` or CI to pre-install Pester. At most, use a `Write-Warning` and `exit 1` without `Read-Host`.

**Build.ps1 Is a Partial Stub:**
- Issue: `Build.ps1` explicitly describes itself as a placeholder for future features (packaging, signing, documentation generation, changelog parsing). Currently it only runs tests and optionally updates a version string via regex.
- Files: `Build.ps1`
- Impact: No release automation; version bumping is a string regex replace with no validation or changelog synchronization.
- Fix approach: Implement changelog-to-release-notes extraction and version validation before v2.0.

---

## Known Bugs

*No active bugs detected.* The following items from the 2026-04-17 audit have been resolved:

- ✅ **Full hash value logging in `Get-And-SaveHash`** — Fixed. Lines 813–817 of `VeriHash.ps1` now truncate to 16 characters before logging.
- ✅ **Config paths logged without sanitization** — Fixed. `ConvertTo-SanitizedPath` is now defined in `VeriHash.LogUtils.ps1` (line 44), which is dot-sourced before `VeriHash.Config.ps1`. All config logging calls now pipe paths through `ConvertTo-SanitizedPath`.
- ✅ **`virustotal.enabled` defaulting to `$true`** — Fixed. `VeriHash.Config.ps1` line 86 now sets `enabled = $false`.

---

## Security Considerations

**VirusTotal API Key Stored in Plaintext:**
- Risk: `config.json` stores `virustotal.apiKey` in plaintext on disk. On Windows this is `%APPDATA%\VeriHash\config.json`; on Linux/macOS it is `~/.verihash/config.json`. Any process or user with filesystem access can read the key.
- Files: `VeriHash.Config.ps1` lines 192–194, 253–255
- Current mitigation: The key is never logged (only `VTHasApiKey = ($config.virustotal.apiKey -ne '')` is logged, line 271 of `VeriHash.Config.ps1`). The key is only read from env var `VERIHASH_VT_APIKEY` or the config file.
- Recommendations: When VirusTotal integration is implemented (Phase 3), add a warning in `Set-VeriHashConfig` if the API key is being written to disk. Document that the `VERIHASH_VT_APIKEY` environment variable is the preferred method. Consider recommending `chmod 600` on Linux/macOS for the config file.

**Execution Policy Bypass in Context Menu Entries:**
- Risk: Both `Install-WindowsSendTo` (line 307 of `VeriHash.ps1`) and `Install-KDEContextMenu` (lines 498–502) use `-ExecutionPolicy Bypass`. For KDE system-wide installation (`-SystemWide`), this applies the bypass to all users on the system without per-user consent.
- Files: `VeriHash.ps1` lines 307, 498–502
- Current mitigation: System-wide install requires root privilege check (line 417–431).
- Recommendations: Document the security implication in the README for system-wide installs.

**No Config File Permission Enforcement:**
- Risk: When `Set-VeriHashConfig` creates `config.json` or the config directory (`VeriHash.Config.ps1` lines 324–341), no file permissions are set. On multi-user Linux/macOS systems, the default umask may leave the config file world-readable, exposing the VirusTotal API key.
- Files: `VeriHash.Config.ps1` lines 324–341
- Current mitigation: None.
- Recommendations: After creating the config file on Unix, apply `chmod 600` to the config file and `chmod 700` to the config directory. On Windows, the `%APPDATA%` directory is typically user-scoped, so this is lower risk.

---

## Performance Bottlenecks

**O(n²) Log Entry Accumulation in `ConvertFrom-VeriHashLog`:**
- Problem: `$logEntries += $flatEntry` (line 245 of `VeriHash.LogUtils.ps1`) uses PowerShell array concatenation inside a `foreach` loop. PowerShell arrays are fixed-size; `+=` creates a new array every iteration, copying all existing elements.
- Files: `VeriHash.LogUtils.ps1` line 245 (inside the loop starting at line 208)
- Cause: Naive `+=` pattern. For 200 entries this is negligible; for thousands of entries across multiple daily log files it becomes quadratic in time and memory.
- Improvement path: Replace with `[System.Collections.Generic.List[PSCustomObject]]` initialized before the loop, use `.Add($flatEntry)`, and cast to array before return: `return [PSCustomObject[]]$logEntries.ToArray()`.

**Repeated `ConvertTo-SanitizedPath` Calls in Config Logging:**
- Problem: `VeriHash.Config.ps1` pipes `$configDir` and `$configFile` through `ConvertTo-SanitizedPath` at every logging call site — 10+ times across `Get-VeriHashConfig`, `Set-VeriHashConfig`, and `Initialize-VeriHashConfig`. Each call runs a `[regex]::Escape()` and `-replace` operation.
- Files: `VeriHash.Config.ps1` lines 158, 159, 212, 225, 318, 319, 328, 345, 391, 401, 420
- Cause: Paths are sanitized on every log call rather than sanitized once at function entry.
- Improvement path: In each function, sanitize paths once at the top (e.g., `$sanitizedConfigDir = $configDir | ConvertTo-SanitizedPath`) and reuse the cached variable in all subsequent log calls.

---

## Fragile Areas

**Test Dot-Source Hack for Loading Functions:**
- Files: `Tests/VeriHash.Tests.ps1` line 7
- Why fragile: `. "$PSScriptRoot\..\VeriHash.ps1" -FilePath "dummy" -ErrorAction SilentlyContinue 2>$null` executes the entire script with a nonexistent file path, relying on the error being suppressed. If any top-level code path before function definitions throws a terminating error that escapes `-ErrorAction SilentlyContinue`, all tests in the suite fail to load functions silently. Adding new top-level logic to `VeriHash.ps1` can break all tests without any obvious error message.
- Safe modification: Always test after adding any top-level code to `VeriHash.ps1`. Long-term fix: extract functions into a separate dot-sourceable file.
- Test coverage: Depends on this working; if it breaks, 0 tests run rather than failing visibly.

**`.sha2` and `.sha2_256` Legacy Extension Handling:**
- Files: `VeriHash.ps1` line 1078
- Why fragile: These legacy extensions are recognized as sidecar files and routed to `Test-HashSidecar`. However, `Get-And-SaveHash` never creates `.sha2` or `.sha2_256` files (only `.md5`, `.sha256`, `.sha512`). If a user has an old `.sha2_256` sidecar whose internal format differs from the expected `HASH  filename` pattern, parsing may fall through to the `Write-Warning "Invalid format in line: $line"` at line 1488. No tests exist for either extension.
- Test coverage: Zero — no tests for `.sha2` or `.sha2_256` detection or parsing.

**`Select-File` Dialog Depends on `System.Windows.Forms`:**
- Files: `VeriHash.ps1` lines 618–647
- Why fragile: `Add-Type -AssemblyName System.Windows.Forms` (line 621) can fail on some Windows configurations (headless, Server Core, or when running without a display). The failure is caught and falls back to `Read-Host`, which itself requires an interactive console. In automated or non-interactive contexts (e.g., batch processing, CI), this path is untested.
- Test coverage: No test covers the `Select-File` fallback path.

**Sidecar Conflict Interaction Flow Has No Timeout:**
- Files: `VeriHash.ps1` lines 900–1016 (the `Read-Host` prompt inside `Get-And-SaveHash`)
- Why fragile: When a sidecar mismatch is detected without `-Force`, the script blocks indefinitely on `Read-Host` (line 940). If called non-interactively (e.g., from another script or scheduler), the process hangs forever. The `-Force` flag prevents this, but there is no timeout or non-interactive detection.
- Test coverage: Tests mock `Read-Host` correctly, but only the `'k'` (keep) branch is tested in the non-Force path (`Tests/VeriHash.Tests.ps1` line 517); the `'u'` (update) and `'r'` (rename) interactive branches are not covered by integration tests.

**Error Handling in Main `try/catch` Is Too Broad:**
- Files: `VeriHash.ps1` lines 1080–1384
- Why fragile: The main `try/catch` block in `Invoke-HashFile` (lines 1080–1384) catches all exceptions with a generic `Write-Error "An error occurred: $_"` (line 1383). No logging via PSFramework, no error classification, no re-throw — errors are silently consumed with a console message that provides no structured diagnostics.
- Safe modification: Add a `Write-PSFMessage -Level Warning -Message "..." -ErrorRecord $_` inside the catch block before the `Write-Error`, and consider narrowing the try scope.
- Test coverage: No test verifies error handling behavior for I/O errors, permission errors, or hash computation failures.

---

## Scaling Limits

**Single-File Processing Only:**
- Current capacity: VeriHash processes exactly one file per invocation. Multi-file hashing requires scripting multiple invocations.
- Limit: Power users cannot hash multiple files in one operation. Context menu "Send To" only processes the first file.
- Scaling path: Planned in `Verihash Multifile Concepting.md` but not implemented. The existing `Invoke-HashFile` would need to accept a `[string[]]$FilePath` array.

---

## Dependencies at Risk

**PSFramework Is Optional but Central to Diagnostics:**
- Risk: PSFramework is listed as optional (`Install-Module PSFramework -Scope CurrentUser`) but is the sole structured logging mechanism. If it is not installed, all structured logging is silently lost — the only warning is a `Write-Warning` when `$LogLevel -ne 'None'` (line 128–129 of `VeriHash.ps1`).
- Impact: Users debugging issues will have no log data without PSFramework. The 33+ `if ($script:PSFrameworkAvailable)` guard checks throughout the codebase contribute ~5% of the total code volume.
- Migration plan: No alternative logging fallback currently exists. Consider adding a minimal `Write-Verbose`/`Write-Debug` fallback inside the `if (-not $script:PSFrameworkAvailable)` block for critical events.

---

## Missing Critical Features

**VirusTotal Integration (Phase 3) Not Started:**
- Problem: Config schema, environment variable docs, and defaults for VirusTotal are fully in place (`VeriHash.Config.ps1` lines 84–89), but no implementation exists. The config section is inert.
- Files: `VeriHash.Config.ps1` lines 84–89, `VeriHash.ps1` (no VT code paths)
- Blocks: Users cannot use the feature. The config section exists but does nothing.

**No Manifest/Multi-File Support:**
- Problem: Documented in `Verihash Multifile Concepting.md` (planning phase, scope locked for MVP). VeriHash processes exactly one file at a time. Multi-select via Send To is not yet supported.
- Blocks: Power users cannot hash multiple files in one operation.

---

## Test Coverage Gaps

**Legacy Sidecar Extensions (`.sha2`, `.sha2_256`):**
- What's not tested: Detection as a verification file (line 1078), routing to `Test-HashSidecar`, and parsing of legacy content format.
- Files: `VeriHash.ps1` line 1078, `Tests/VeriHash.Tests.ps1`
- Risk: Silent regression if legacy format parsing breaks.
- Priority: Low (legacy users; new users get `.sha256`)

**`Select-File` Fallback Path:**
- What's not tested: The `Add-Type` failure → `Read-Host` fallback in `Select-File` (lines 618–647).
- Files: `VeriHash.ps1` lines 618–647, `Tests/VeriHash.Tests.ps1`
- Risk: Interactive file selection may silently fail on headless or Server environments.
- Priority: Medium

**Sidecar Conflict Interactive Branches (Update / Rename):**
- What's not tested: The `'u'` (update) and `'r'` (rename) user choices in the non-Force mismatch prompt (lines 947–982 of `VeriHash.ps1`).
- Files: `VeriHash.ps1` lines 947–982, `Tests/VeriHash.Tests.ps1`
- Risk: Silent regressions in the interactive update and rename paths.
- Priority: Medium

**`Install-KDEContextMenu` and `Install-WindowsSendTo` Functions:**
- What's not tested: No tests exist for any context menu installation path (283 lines of untested code from lines 283–556 of `VeriHash.ps1`).
- Files: `VeriHash.ps1` lines 283–556, `Tests/`
- Risk: Platform-specific installation regressions go undetected.
- Priority: Low (not on hot path; hard to mock filesystem + COM objects)

**Error Handling in `Invoke-HashFile`:**
- What's not tested: The `catch` block at line 1382–1384 of `VeriHash.ps1` — no test simulates file I/O errors, permission denied, or other failures during hash computation.
- Files: `VeriHash.ps1` lines 1382–1384, `Tests/VeriHash.Tests.ps1`
- Risk: Errors may be swallowed or produce unhelpful output without detection.
- Priority: Medium

**`Test-InputHash` Output Assertions Are Weak:**
- What's not tested: `Test-InputHash` tests (lines 39–77 of `Tests/VeriHash.Tests.ps1`) only assert `Should -Not -Throw` without verifying the correct Write-Host output (match vs. mismatch). A bug that swaps the match/mismatch messages would not be caught.
- Files: `Tests/VeriHash.Tests.ps1` lines 39–77, `VeriHash.ps1` lines 649–659
- Risk: Incorrect match/mismatch feedback to user goes undetected.
- Priority: Medium

---

## Resolved Since Last Audit (2026-04-17)

- ✅ **Redundant `$script:PSFrameworkAvailable` detection** — Fixed. Now a single check at `VeriHash.ps1` line 100, before dot-sourcing modules.
- ✅ **Full hash value logged untruncated** — Fixed. `Get-And-SaveHash` now truncates to 16 chars at lines 813–817 of `VeriHash.ps1`.
- ✅ **Config paths logged without sanitization** — Fixed. `ConvertTo-SanitizedPath` moved to `VeriHash.LogUtils.ps1` line 44, available to all modules.
- ✅ **`virustotal.enabled` defaulting to `$true`** — Fixed. Now `$false` at `VeriHash.Config.ps1` line 86.
- ✅ **No CI/CD pipeline** — Fixed. `.github/workflows/ci.yml` runs Pester tests on `ubuntu-latest` and `windows-latest`, plus PSScriptAnalyzer linting on all three script files.
- ✅ **PSScriptAnalyzer not analyzing all files** — Fixed. Both `Test-All.ps1` (lines 116–120) and `.github/workflows/ci.yml` (lines 71–75) now lint `VeriHash.ps1`, `VeriHash.Config.ps1`, and `VeriHash.LogUtils.ps1`.
- ✅ **No log rotation** — Fixed. `Set-PSFLoggingProvider` at `VeriHash.ps1` lines 160–161 configures `-LogRotatePath` and `-LogRetentionTime "30d"`.

---

*Concerns audit: 2026-04-18*
