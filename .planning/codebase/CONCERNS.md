# Codebase Concerns

**Analysis Date:** 2026-04-18

> **Milestone context:** `.planning\STATE.md` reports milestone **v2.0 (Modular Rebuild)** is in `roadmap_complete` status with 5 phases mapped (Core Module Foundation → Hot-Path Performance + Multi-File Loop → Manifest Module → Integrations + Config Trim → Thin CLI + Cleanup & Docs). Many items below are *already planned* for resolution in that milestone; this document records their current state so phase planners can cross-reference scope boundaries.

## Tech Debt

**Monolithic main script (`VeriHash.ps1`):**
- Issue: Single-file 66,719-byte / 1,351-line script hosting param parsing, PSFramework init, Authenticode extension tables, Linux desktop-environment hashtable, `Get-DesktopEnvironment`, `Install-WindowsSendTo`, `Install-KDEContextMenu`, `Get-ClipboardHash`, `Get-And-SaveHash`, `Invoke-HashFile`, `Test-HashSidecar`, and the top-level dispatcher. No module manifest (`.psd1`), no exported surface, no public/internal split.
- Files: `VeriHash.ps1` (entire file), supporting dot-sourced helpers `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`
- Impact: Hard to unit-test individual functions in isolation; every run reloads the full script including KDE install helpers that 99% of users never touch; change risk on hot paths (hashing) coupled with install paths.
- Fix approach: v2.0 Phase 1 (Core Module Foundation) + Phase 5 (Thin CLI). Target split per `.planning\ROADMAP.md`: `VeriHash.Core` module, `VeriHash.Manifest` module, lazy-loaded integrations helper, and a thin CLI wrapper. Phase 1 is ready to plan.

**Dot-source loading order dependency:**
- Issue: `VeriHash.ps1` lines 103-105 must dot-source `VeriHash.LogUtils.ps1` *before* `VeriHash.Config.ps1` because `Get-VeriHashConfig` calls `ConvertTo-SanitizedPath` during initialization. Comment on line 103 (`# Import logging utilities first (Config depends on ConvertTo-SanitizedPath)`) acknowledges the coupling but the dependency is implicit — no `#Requires`, no guard.
- Files: `VeriHash.ps1` lines 102-106, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`
- Impact: Silent breakage if someone reorders the includes or ports `VeriHash.Config.ps1` to a different entry point.
- Fix approach: v2.0 Phase 1 module manifests with explicit `RequiredModules` / `NestedModules` replace the implicit ordering.

**Ubiquitous `$script:PSFrameworkAvailable` guards:**
- Issue: Every log site is wrapped in `if ($script:PSFrameworkAvailable) { Write-PSFMessage ... }` — ~20+ call sites counted in `VeriHash.ps1` (lines 295, 329, 354, 402, 532, 669, 745, 753, 761, 769, 789, 812, 1037, 1400, etc.) and again in `VeriHash.Config.ps1` (lines 157, 211, 224, 265, 300, 317, 327, 344, 390, 400, 409). Duplicates the flag check at every call.
- Files: `VeriHash.ps1`, `VeriHash.Config.ps1`
- Impact: Visual noise, easy to forget a guard (a missed guard crashes the script on machines without PSFramework), defeats PSFramework's own null-provider behaviour.
- Fix approach: v2.0 Phase 4 excises PSFramework entirely per `.planning\REQUIREMENTS.md` (`virustotal.*` and PSFramework both removed). Until then, consider a single wrapper `Write-VHLog` to centralize the guard.

**Vestigial VirusTotal configuration:**
- Issue: `VeriHash.Config.ps1` lines 84-87 still define a `virustotal` config subtree (`apiKey`, `enabled`, `preferApi`, `autoOpen`), lines 150-153 register default source tracking, lines 190-204 parse it from the on-disk config file, and lines 108-109 document `VERIHASH_VT_APIKEY` / `VERIHASH_VT_ENABLED` env vars — for a feature that is never implemented (line 86 comment: `# VirusTotal integration not yet shipped; enable when implemented`).
- Files: `VeriHash.Config.ps1` lines 84-87, 108-109, 150-153, 190-204; `Tests\VeriHash.Config.Tests.ps1` (referenced by `.planning\REQUIREMENTS.md` CFG-02)
- Impact: Dead code surface; confusing to new contributors; tests assert on a feature that doesn't exist; risk that a partial VT implementation could accidentally leak hashes to a third party before review.
- Fix approach: v2.0 `.planning\REQUIREMENTS.md` CFG-01 and CFG-02 explicitly remove all `virustotal.*` fields, `VERIHASH_VT_*` env handling, and test references. `.planning\REQUIREMENTS.md` line 88 records the scope decision: "Cut entirely from project scope, not just deferred."

**Version string drift:**
- Issue: Header comment in `VeriHash.ps1` line 22-23 claims `Updated: December 27, 2025 / Version: 1.3.0`. There is no authoritative version constant elsewhere in code; CHANGELOG.md is the source of truth.
- Files: `VeriHash.ps1` lines 22-23, `CHANGELOG.md`
- Impact: Version shown in `-Help` output can skew from released tag.
- Fix approach: Introduce a single `$script:VeriHashVersion` constant in v2.0 Phase 1 core module, surface via a `Get-VeriHashVersion` function.

## Known Bugs

**No FIXME/HACK/BUG markers found.**
- `Select-String TODO|FIXME|HACK|XXX|BUG` over `*.ps1`/`*.psd1` returns only unrelated matches (`DEBUG`, "Note:" comments). No outstanding self-documented bugs in the code.
- Recently fixed items logged in `CHANGELOG.md` ([Unreleased]): `Get-VeriHashLogSummary` under-counting (UTF-8 BOM handling, trailing-comma stripping in JSONL) and test prompts blocking automation. These are closed, no action needed.

## Security Considerations

**MD5 retention for legacy sidecar compatibility:**
- Risk: MD5 is cryptographically broken (collision-prone) but `.md5` sidecars are still produced and verified. Relying on MD5 for integrity against an adversarial attacker is unsafe.
- Files: `VeriHash.ps1` `-Algorithm` param (line 65) accepts `'MD5'`; `Get-And-SaveHash` (lines 780-870) writes `.md5` sidecars; `Get-ClipboardHash` (line 746) detects 32-hex MD5 strings; `PSScriptAnalyzerSettings.psd1` lines 20-24 explicitly suppress `PSAvoidUsingBrokenHashAlgorithms`.
- Current mitigation: Suppression is documented inline; test suite includes warning that MD5 is collision-prone and recommends SHA256+. Default `-Algorithm All` computes SHA256 + SHA512 alongside MD5.
- Recommendations: Add a runtime warning banner when a user explicitly computes/verifies MD5 (not just inside tests). Consider gating `-Algorithm MD5` behind a `-AllowLegacyHash` switch in v2.0 Phase 5 (Thin CLI redesign).

**Path sanitization (`ConvertTo-SanitizedPath`):**
- Risk: Username/home-directory leakage in log files (GDPR Art. 5(1)(c) minimization).
- Files: `VeriHash.LogUtils.ps1` lines 44-84 (implementation); call sites throughout `VeriHash.ps1` (lines 183, 331, 332, 534, 791, 816, 1035+) and `VeriHash.Config.ps1`.
- Current mitigation: Regex replacement of `$env:USERPROFILE` → `%USERPROFILE%` on Windows, `$HOME` → `~` on Unix. Every `-Data` hashtable passed to `Write-PSFMessage` sanitizes paths before emission.
- Recommendations: Regex escape is applied (line 78/81) — safe. However, PSFramework itself stamps `ComputerName` / `Username` into every log entry (documented in `VeriHash.LogUtils.ps1` lines 13-14 as "cannot be disabled"). v2.0 removal of PSFramework (Phase 4) eliminates this passive leak; ensure the replacement logger does not reintroduce it. Also add coverage for edge cases: UNC paths (`\\server\share`), symlinks resolving outside `$HOME`, paths containing regex metacharacters (no current failure, but defense-in-depth). Consider hashing sensitive segments rather than replacing with a constant placeholder.

**Hash truncation in logs (16-char prefix + `...`):**
- Risk: Full hashes in logs create an audit trail that could identify files on a system (preimage via VirusTotal/Google search).
- Files: `VeriHash.ps1` line 814: `$truncatedHash = $hashValue.Substring(0, [Math]::Min(16, $hashValue.Length)) + '...'`
- Current mitigation: Only the first 16 hex chars (64 bits) are logged. For SHA256/SHA512 this is insufficient to recover the full hash; for MD5 (128 bits total) it's half.
- Recommendations: 16 chars is sensible. Document the policy explicitly in `VeriHash.LogUtils.ps1` header. Ensure the v2.0 replacement logger preserves this behaviour — it is currently enforced by the caller, not the logging layer, so a new caller could accidentally pass the full hash.

**Authenticode signature handling is Windows-only and best-effort:**
- Risk: `Get-AuthenticodeSignature` (line 1132) is wrapped in try/catch that only prints the error; an invalid or tampered signature is reported as "False 🚫" with no distinction between *unsigned* and *tampered/revoked*.
- Files: `VeriHash.ps1` lines 1125-1161
- Current mitigation: Extension allowlist (`$script:SignableExtensions` lines 191-201) and a separate `$script:NonAuthenticodeSignableExtensions` list (lines 204-210) prevent spurious "unsigned" labels on `.jar`/`.apk`/etc.
- Recommendations: Expose `$signature.Status` verbatim (`HashMismatch`, `NotSigned`, `NotTrusted`, `UnknownError`) in output, not just a Boolean. Trust-chain revocation is not checked separately. Non-Windows platforms silently skip — consider integrating `osslsigncode` on Linux/macOS for parity (v2.0 integrations phase candidate).

**`-ExecutionPolicy Bypass` baked into install shortcuts:**
- Risk: `Install-WindowsSendTo` (line 308) and `Install-KDEContextMenu` (lines 499, 502) hardcode `-ExecutionPolicy Bypass` into the generated shortcuts/`.desktop` files.
- Files: `VeriHash.ps1` lines 305-311, 499-504
- Current mitigation: The bypass applies only to the shortcut's pwsh invocation, not system-wide. User explicitly opted in by running `-SendTo`.
- Recommendations: Document the trade-off in README's install section. Consider signing `VeriHash.ps1` so the shortcut can use `-ExecutionPolicy AllSigned`.

**`.desktop` file `%f` substitution (Linux):**
- Risk: `%f` inserts a single user-selected file path into a shell command line; paths with spaces or shell metacharacters could theoretically break the invocation. KDE quotes `%f` but a malformed filename could still cause surprising behaviour.
- Files: `VeriHash.ps1` lines 499-500, 502-503
- Current mitigation: `"%f"` is wrapped in double quotes in the `Exec=` line. `pwsh -File` is used (not `-Command`) so the script sees the path as a single argument.
- Recommendations: Acceptable as-is. Add an integration test with a filename containing spaces and Unicode.

**`.env`-style secrets in config file:**
- Risk: Not detected — no `.env` files present; config lives at `$env:APPDATA\VeriHash\config.json` (Windows) / `~/.verihash/config.json`. VirusTotal `apiKey` field in `VeriHash.Config.ps1` line 84-87 would have stored an API key in plaintext JSON.
- Mitigation: V2.0 removes the `virustotal.*` config surface entirely (`.planning\REQUIREMENTS.md` CFG-01), eliminating this concern before it ships.

## Performance Bottlenecks

**`Get-FileHash` for large files is synchronous and non-streaming:**
- Problem: `Get-And-SaveHash` (line 804) calls `Get-FileHash -Path $PathToFile -Algorithm $Algorithm`. Get-FileHash reads the whole file sequentially in-process; for multi-GB files this blocks the console and cannot be cancelled gracefully (Ctrl-C leaves the cmdlet mid-read). CHANGELOG notes "175.25 MB/s for a 3.7 GB file hashed in 21 seconds" — disk-bound but not using any optimizations.
- Files: `VeriHash.ps1` line 804, also line 1473
- Cause: Single call to `Get-FileHash`. No buffer size tuning, no parallel algorithm computation (each call re-reads the file when `-Algorithm All` triggers three separate `Get-And-SaveHash` invocations).
- Improvement path: v2.0 Phase 2 (Hot-Path Performance + Multi-File Loop) explicitly targets this. Use a single FileStream read feeding multiple `HashAlgorithm` instances in a `TransformBlock` loop to compute MD5 + SHA256 + SHA512 in one pass. Expose a buffer-size setting in config. Consider emitting progress via `Write-Progress` for files > 100 MB.

**`-Algorithm All` re-reads the file per algorithm:**
- Problem: The dispatcher in `Invoke-HashFile` loops algorithms and calls `Get-And-SaveHash` per algorithm, each of which invokes `Get-FileHash`. For `-Algorithm All` on a 3.7 GB file, the disk is read three times (~63 s instead of ~21 s).
- Files: `VeriHash.ps1` `Invoke-HashFile` (around lines 1024-1350)
- Cause: Sequential algorithm loop, no shared stream.
- Improvement path: Multi-algorithm single-pass stream (v2.0 Phase 2 success criteria).

**JSONL log file growth:**
- Problem: `Set-PSFLoggingProvider` is configured with `-LogRetentionTime "30d"` (line 162) and `-LogRotateFilter "verihash-*.jsonl"` — retention is enforced, but each daily file can still grow unbounded within the day if the user hashes many files at `-LogLevel Debug`.
- Files: `VeriHash.ps1` lines 152-164
- Cause: Daily-rotation only; no per-file size cap.
- Improvement path: Add a size-based rotation trigger in the v2.0 logging replacement. Document in README that `VERIHASH_LOG_LEVEL=DEBUG` is diagnostic, not a default.

**`ConvertFrom-VeriHashLog` reads entire log files into memory:**
- Problem: `VeriHash.LogUtils.ps1` lines 210-216 load each log file with `Get-Content -Raw`, then split on `"`r?`n"` and iterate. For a single 100 MB JSONL file this materializes the whole content + split array.
- Files: `VeriHash.LogUtils.ps1` lines 207-252
- Cause: `-Raw` was chosen to handle UTF-8 BOM (fix documented in `CHANGELOG.md` [Unreleased]), but at a memory cost.
- Improvement path: Stream line-by-line with `[System.IO.File]::ReadLines()`, stripping BOM once on the first line. Low priority (logs are small in normal use).

**Desktop-environment detection runs three scans:**
- Problem: `Get-DesktopEnvironment` (lines 228-282) walks `$script:DesktopEnvironments` up to three times (XDG_CURRENT_DESKTOP, DESKTOP_SESSION, per-DE env vars). Currently only `KDE` is registered, so cost is trivial — but the N×M pattern will scale poorly once GNOME/XFCE/etc. are added.
- Files: `VeriHash.ps1` lines 228-282
- Cause: Nested `foreach` over DEs × values.
- Improvement path: Build a single reverse-lookup hashtable keyed by detection value. Low priority (runs once per `-SendTo` invocation).

## Fragile Areas

**PSFramework dependency pattern:**
- Files: `VeriHash.ps1` lines 99-188, and every `if ($script:PSFrameworkAvailable)` guard
- Why fragile: The "logging is optional" pretense is enforced only by repeated null-checks. `Set-PSFLoggingProvider` on line 152 uses many named parameters (`-JsonCompress`, `-JsonNoComma`, `-JsonNoEmptyFirstLine`, `-JsonString`, `-LogRotateFilter`, `-LogRetentionTime`) that are version-specific — a PSFramework version bump could silently drop one of these and degrade logging. `Import-Module PSFramework -ErrorAction SilentlyContinue` (line 133) swallows import errors.
- Safe modification: Do not add new `Write-PSFMessage` calls without the guard. Run `Tests\VeriHash.Tests.ps1` on a machine without PSFramework installed before releasing.
- Test coverage: Some coverage exists in `Tests\VeriHash.Config.Tests.ps1`; unclear whether "PSFramework absent" path is exercised in CI. Verify during v2.0 Phase 4 excision.

**Platform detection duplicated across modules:**
- Files: `VeriHash.ps1` lines 96-97, `VeriHash.Config.ps1` lines 22-26, `VeriHash.LogUtils.ps1` lines 35, 74, 116
- Why fragile: Each module re-derives `$RunningOnWindows` / `$RunningOnLinux` / `$RunningOnMacOS` from `$PSVersionTable`. `VeriHash.Config.ps1` line 23 includes a null-check fallback (`-or $null -eq $PSVersionTable.Platform`) that the others do not — inconsistent behaviour on Windows PowerShell 5.1 (though the script requires 7+).
- Safe modification: Treat these as read-only. Any change must be made in all three files simultaneously.
- Fix approach: v2.0 Phase 1 should expose a single `Get-VeriHashPlatform` or constants file.

**Cross-platform desktop-environment + terminal detection:**
- Files: `VeriHash.ps1` `Install-KDEContextMenu` lines 481-494 (terminal list), `Get-DesktopEnvironment` lines 228-282
- Why fragile: Terminal-emulator allowlist is `@('konsole', 'xterm', 'gnome-terminal', 'xfce4-terminal', 'alacritty', 'kitty')` — misses wezterm, foot, ghostty, tilix, terminator, and breaks on systems where only flatpak terminals are available. `Get-DesktopEnvironment` only registers `KDE`; GNOME is advertised in user output (lines 370-371) as "Coming soon" for 1+ year.
- Safe modification: Append to `$terminals` array; extend `$script:DesktopEnvironments` with parallel entries plus a matching `Install-*ContextMenu` handler.
- Test coverage: No Linux-specific integration tests detected in `Tests\` (primary test files are `VeriHash.Tests.ps1`, `VeriHash.Config.Tests.ps1`, `VeriHash.Timing.Tests.ps1`). Linux install paths are effectively untested in CI.

**Windows SendTo install uses COM (`WScript.Shell`):**
- Files: `VeriHash.ps1` lines 314-326
- Why fragile: `New-Object -ComObject WScript.Shell` works on Windows but will fail on PowerShell 7 running on Linux/macOS under WSL scenarios if someone passes `-SendTo` there. Currently gated by the outer dispatcher checking `$RunningOnWindows` before calling this function.
- Safe modification: Keep the Windows-only gate at the call site. If the gate is ever removed, the COM call throws.

**Sidecar parsing tolerates both legacy and standard formats:**
- Files: `VeriHash.ps1` lines 857-868 (`Get-And-SaveHash`), and `Test-HashSidecar` at line 1392
- Why fragile: Content is split on whitespace and the first part matching `^[A-Fa-f0-9]{32,128}$` wins. A filename containing a 32+ character hex substring (e.g., a download named after its hash) would confuse detection.
- Safe modification: Prefer the Unix-standard ordering (`HASH  filename`) and fall back to legacy only when the first token is non-hex.

**Test-mode log redirection relies on an env var:**
- Files: `VeriHash.ps1` lines 136-142, `Tests\VeriHash.Tests.ps1` (`BeforeAll`/`AfterAll` per CHANGELOG [Unreleased])
- Why fragile: If a test fails to restore `$env:VERIHASH_TEST_MODE`, subsequent production runs will write to the `logs\test\` subdirectory silently.
- Safe modification: Always wrap tests in a `try/finally` that clears the env var. Verify the existing AfterAll covers this path.

## GDPR / Privacy Considerations

**Data-minimization design is explicit and well-documented:**
- Files: `VeriHash.LogUtils.ps1` lines 11-15 (DATA MINIMIZATION NOTICE), `VeriHash.ps1` lines 150-151 (inline comment citing GDPR Art. 5(1)(c), OWASP Logging Cheat Sheet, CWE-532)
- Policy: Paths sanitized before emission, hashes truncated to 16 hex chars, file *contents* never logged (verified: no `Get-Content` calls feed into `Write-PSFMessage -Data`), log retention capped at 30 days.

**Passive PII leakage via PSFramework:**
- Risk: PSFramework's `logfile` provider stamps `ComputerName` and `Username` into every JSON record; `VeriHash.LogUtils.ps1` line 14 explicitly notes "cannot be disabled."
- Mitigation: v2.0 Phase 4 removes PSFramework. Until then, users on multi-tenant systems should set `VERIHASH_LOG_LEVEL=NONE` (the default).

**Log-file location is user-scoped:**
- Windows: `$env:APPDATA\VeriHash\logs` — ACL'd to the user.
- Linux/macOS: `$HOME/.verihash/logs` — mode depends on umask; VeriHash does not chmod after create.
- Risk: On shared Linux hosts with lax umask (022), logs could be world-readable.
- Recommendation: Explicitly `chmod 700` the log directory on first create. Low priority.

**No network I/O in current production paths:**
- Verified: `Select-String` for `Invoke-WebRequest|Invoke-RestMethod|System.Net.Http` in `VeriHash.ps1` returns no production-path matches. All hashing is local; no telemetry.

## Planned VirusTotal Integration Risks (Deferred / Out of Scope)

Per `.planning\REQUIREMENTS.md` line 88, VirusTotal integration is now **cut entirely from scope**, not merely deferred. The risks below are captured so that *if* a future milestone revisits this, the analysis is preserved:

- **Hash leakage to a third party**: submitting SHA256 to VirusTotal reveals that the user possesses a file with that hash. For unique files (e.g., documents not previously uploaded to VT), this can deanonymize the user.
- **API key storage**: current v1.3 scaffolding in `VeriHash.Config.ps1` line 84-87 stores the key in plaintext JSON. A future implementation must use DPAPI (Windows) / `libsecret` (Linux) / Keychain (macOS).
- **Rate-limiting**: VT's public API allows 4 req/min; a batch verification over many files trivially exceeds this. Would need opt-in batching + backoff.
- **Opt-in UX**: must be off by default, with a per-invocation confirmation, not a silent config flag.

**Current state:** v2.0 Phase 4 (`.planning\REQUIREMENTS.md` CFG-01, CFG-02) removes all VT scaffolding. Re-introducing VT would be a separate project entirely.

## Scaling Limits

**Single-file hashing:**
- Current capacity: `Get-FileHash` handles files up to `Int64.MaxValue` bytes in principle; practical wall-clock limit is disk-bound (~175 MB/s observed).
- Limit: User patience. No cancellation, no progress, no resume.
- Scaling path: v2.0 Phase 2 single-pass multi-algorithm + `Write-Progress`.

**Batch / multi-file hashing:**
- Current capacity: None. VeriHash v1.3 accepts a single `-FilePath`.
- Limit: Cannot hash a directory or glob.
- Scaling path: v2.0 Phase 2 ("Multi-File Loop") and Phase 3 (Manifest Module) address this explicitly.

**Log volume:**
- Current capacity: Unbounded within a day; 30-day retention window.
- Limit: Disk space on the user profile volume if `DEBUG` logging is left on.
- Scaling path: Size-based rotation, see Performance section.

## Dependencies at Risk

**PSFramework (optional):**
- Risk: External dependency on a third-party module; version-specific parameter surface on `Set-PSFLoggingProvider`; passive PII stamping; adds install friction.
- Impact: Logging features silently disabled if missing; can break on PSFramework major-version bumps.
- Migration plan: v2.0 Phase 4 removes it entirely (documented in `.planning\ROADMAP.md` Phase 4 goal).

**QuickHash.ps1:**
- Risk: Sibling script in repo root that appears to be a legacy/experimental companion. `.planning\ROADMAP.md` Phase 5 deliverables list "removals (VirusTotal, PSFramework, **QuickHash**, LogUtils)".
- Impact: Confuses new contributors; unclear which entry point is authoritative.
- Migration plan: Remove in v2.0 Phase 5.

**VeriHash.LogUtils.ps1:**
- Risk: Per roadmap, LogUtils is also scheduled for removal as part of v2.0 cleanup. Functions `ConvertFrom-VeriHashLog` and `Get-VeriHashLogSummary` are user-facing utilities — their removal is a breaking change for anyone scripting against them.
- Migration plan: Document in v2.0 CHANGELOG entry; provide a one-liner showing how to parse JSONL logs with `Get-Content | ConvertFrom-Json` as a replacement.

## Missing Critical Features

**Directory / glob / batch hashing:**
- Problem: Cannot hash multiple files in one invocation.
- Blocks: Verifying a release's full file set; generating a manifest for archives.
- Scheduled: v2.0 Phase 2 (Multi-File Loop), Phase 3 (Manifest Module).

**Manifest mode:**
- Problem: No built-in way to emit or verify a multi-file hash manifest (e.g., `SHA256SUMS` format).
- Blocks: Release verification workflows.
- Scheduled: v2.0 Phase 3.

**Module packaging:**
- Problem: No `.psd1` manifest; not installable via `Install-Module`.
- Blocks: PSGallery distribution, versioned dependency resolution.
- Scheduled: v2.0 Phase 1 (Core Module Foundation) + Phase 5 (Thin CLI).

**Cancellation / progress:**
- Problem: No `Write-Progress`; Ctrl-C during hashing leaves partial output.
- Blocks: Multi-GB file UX.
- Scheduled: Implicit in v2.0 Phase 2 performance work (not explicit in requirements — verify when planning).

## Test Coverage Gaps

**Linux context-menu installation paths:**
- What's not tested: `Install-LinuxContextMenu`, `Install-KDEContextMenu`, `Get-DesktopEnvironment`, terminal-emulator detection, `chmod +x` on generated `.desktop` files.
- Files: `VeriHash.ps1` lines 228-550
- Risk: Changes to KDE service-menu format, or a terminal emulator rename, could break all Linux users without CI catching it.
- Priority: Medium (feature is in v1.3 release; regressions likely).

**PSFramework-absent code paths:**
- What's not tested: Behaviour when `Get-Module -ListAvailable -Name PSFramework` returns `$null` (line 100). Every `if ($script:PSFrameworkAvailable)` block has an implicit else (do nothing).
- Files: `VeriHash.ps1` ~20 call sites
- Risk: A missing guard would `CommandNotFound` on `Write-PSFMessage`.
- Priority: Medium, but becomes moot after v2.0 Phase 4.

**Windows SendTo shortcut generation:**
- What's not tested: `Install-WindowsSendTo` (lines 284-337). COM object creation, execution-policy branch (lines 306-311), icon-missing fallback (line 322-324).
- Risk: A Windows-version change could break the SendTo folder path assumption.
- Priority: Low.

**Configuration precedence (env > file > default):**
- What's not tested: Cross-verify `Tests\VeriHash.Config.Tests.ps1` exercises all three layers and the source-tracking hashtable (`$source.*` in `VeriHash.Config.ps1` lines 150-153, 194, 198, 202, 206).
- Priority: Medium. Worth auditing before v2.0 Phase 4 (CFG-01, CFG-02) removes the `virustotal.*` branches — make sure the test removal matches the code removal.

**Large-file / streaming hashing:**
- What's not tested: Multi-GB files; `-Algorithm All` timing. `Tests\VeriHash.Timing.Tests.ps1` exists but file sizes covered are unknown without deeper read.
- Risk: v2.0 Phase 2 will rewrite the hot path — without a baseline benchmark harness, regressions are invisible.
- Priority: High before starting Phase 2 (baseline numbers needed for success criteria).

**Path-sanitization edge cases:**
- What's not tested: UNC paths (`\\server\share\...`), paths containing `%USERPROFILE%` literally, symlinks pointing outside `$HOME`, Unicode paths.
- Files: `VeriHash.LogUtils.ps1` lines 44-84
- Risk: A PII leak could occur for paths that don't match the simple prefix replacement.
- Priority: Medium.

---

*Concerns audit: 2026-04-18*
