# Architecture

**Analysis Date:** 2026-04-18

## Pattern Overview

**Overall:** Monolithic PowerShell 7+ script with dot-sourced helper modules (procedural/functional, no classes, no PowerShell module manifest).

**Key Characteristics:**
- Single large entry script (`VeriHash.ps1`, ~66 KB, ~1528 lines) containing all core logic — CLI parsing, platform dispatch, hashing, sidecar verification, clipboard detection, signature checking, and OS integration installers.
- Two helper scripts (`VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`) are dot-sourced at startup to inject functions into the main script's scope. No `.psm1` / `.psd1` modules exist.
- Cross-platform by design: every platform-dependent code path branches on `$RunningOnWindows` / `$script:RunningOnLinux` / `$script:RunningOnMacOS` booleans populated from `$PSVersionTable.Platform` + `$PSVersionTable.OS`.
- Pluggable desktop environment dispatch for Linux context-menu integration via the `$script:DesktopEnvironments` hashtable (currently only KDE handler is implemented; GNOME/XFCE slots are reserved).
- Optional structured logging: functions emit `Write-PSFMessage` calls that are no-ops unless the PSFramework module is installed (`$script:PSFrameworkAvailable` gate).
- Privacy-aware: user-profile paths are sanitised (`ConvertTo-SanitizedPath`) before being written to JSONL log files (GDPR Article 5(1)(c) data minimisation).
- v2.0 "Modular Rebuild" milestone is in progress — the long-term direction is to split `VeriHash.ps1` into named modules, but the current shipping state is still monolithic.

## Layers

**CLI / Entry layer:**
- Purpose: Parse parameters, validate `-FilePath`, dispatch to the main orchestrator.
- Location: `VeriHash.ps1` (top-level `param(...)` block at lines 56–93; final dispatch `Invoke-HashFile ...` at line 1528).
- Contains: `param` block, platform detection, module dot-sourcing, PSFramework logging initialisation, `-SendTo` / `-Help` early-exit branches.
- Depends on: `VeriHash.LogUtils.ps1`, `VeriHash.Config.ps1`.

**Configuration layer:**
- Purpose: Load and persist user configuration with a defined priority order.
- Location: `VeriHash.Config.ps1`.
- Contains: `Get-VeriHashConfigPath`, `Get-VeriHashDefaultConfig`, `Get-VeriHashConfig`, `Set-VeriHashConfig`, `Initialize-VeriHashConfig`.
- Priority (highest → lowest): CLI parameter → environment variable (`VERIHASH_*`) → `config.json` on disk → hard-coded defaults returned by `Get-VeriHashDefaultConfig`.
- Config file location: `%APPDATA%\VeriHash\config.json` (Windows) or `~/.verihash/config.json` (Linux/macOS).
- Depends on: `ConvertTo-SanitizedPath` from the log-utils layer (so log-utils must dot-source first).

**Logging / Privacy layer:**
- Purpose: Compute log paths and sanitise personally identifiable path segments before emission.
- Location: `VeriHash.LogUtils.ps1`.
- Contains: `Get-VeriHashLogPath`, `ConvertTo-SanitizedPath`, `ConvertFrom-SanitizedPath` (round-trip helpers).
- Log output: JSONL files at `%APPDATA%\VeriHash\logs\verihash-%date%.jsonl` (Windows) or `~/.verihash/logs/verihash-*.jsonl`, with 30-day retention configured via `Set-PSFLoggingProvider`. Test runs redirect to a `test\` subdirectory when `$env:VERIHASH_TEST_MODE -eq '1'`.

**OS Integration layer:**
- Purpose: Install right-click / SendTo shortcuts so users can invoke VeriHash from the file manager.
- Location: `VeriHash.ps1` (lines ~212–617).
- Contains: `$script:DesktopEnvironments` registry hashtable, `Get-DesktopEnvironment`, `Install-WindowsSendTo`, `Install-LinuxContextMenu`, `Install-KDEContextMenu`.
- Dispatch pattern: `Install-LinuxContextMenu` looks up the detected DE key in `$script:DesktopEnvironments`, resolves `.Handler` via `Get-Command`, and invokes it with `& $config.Handler -SystemWide:$SystemWide`. New desktop environments are added by appending an entry to the hashtable and defining a handler function — no `switch` edits needed.

**Core Hashing layer:**
- Purpose: Compute hashes, emit sidecar files, run signature checks, and orchestrate per-file workflow.
- Location: `VeriHash.ps1` (lines ~780–1390).
- Contains: `Get-And-SaveHash` (single-algorithm compute + sidecar write), `Invoke-HashFile` (main orchestrator: signature check, clipboard detection, algorithm selection, timing, pretty-printed output).
- Constants: `$script:SignableExtensions` (Authenticode-capable file extensions) and `$script:NonAuthenticodeSignableExtensions` (extensions signable via other formats) drive the signature-check branch.

**Verification layer:**
- Purpose: Verify hashes supplied via clipboard, CLI `-Hash`, or sidecar files.
- Location: `VeriHash.ps1` (lines ~650–780 and ~1392–1517).
- Contains: `Get-ClipboardHash` (platform-aware clipboard access — `Get-Clipboard` on Windows/macOS; `wl-paste` → `xclip` → `xsel` fallback chain on Linux), `Test-InputHash` (string comparison with coloured output), `Test-HashSidecar` (parses a `.sha256` / `.sha512` / `.md5` sidecar and verifies every referenced file).
- Algorithm auto-detection: `Get-ClipboardHash` and `Test-HashSidecar` infer algorithm from hash-string length (32 → MD5, 64 → SHA256, 128 → SHA512).

**Interactive UI layer:**
- Purpose: Prompt the user for a file when none was supplied on the command line.
- Location: `VeriHash.ps1` (`Select-File`, lines ~619–648).
- Behaviour: On Windows, loads `System.Windows.Forms` and shows an `OpenFileDialog`; on other platforms falls back to `Read-Host` plain-text entry.

## Data Flow

**Primary hash/verify flow (single file):**

1. User invokes `VeriHash.ps1 [<path>] [-Hash <hex>] [-Algorithm ...] [-OnlyVerify] [-SendTo] [-LogLevel ...]`.
2. Platform booleans (`$RunningOnWindows`, `$RunningOnLinux`) are set from `$PSVersionTable`.
3. `VeriHash.LogUtils.ps1` is dot-sourced, then `VeriHash.Config.ps1`.
4. `Get-VeriHashConfig` merges defaults → `config.json` → env vars into `$script:VeriHashConfig`; final `LogLevel` is resolved with CLI > env > config precedence.
5. If PSFramework is available, `Set-PSFLoggingProvider -Name 'logfile' -InstanceName 'VeriHash'` is configured with JSONL output, UTC timestamps, 30-day rotation, and a fixed header allow-list that excludes `ComputerName` / `Username`.
6. If `-SendTo` is set, the script branches into the OS-integration layer and returns.
7. Otherwise `Invoke-HashFile` is called:
   a. If no `-Hash` was supplied, `Get-ClipboardHash` is probed for an auto-detected MD5/SHA256/SHA512 value.
   b. If `-FilePath` is missing/invalid, `Select-File` prompts interactively.
   c. The file's extension is tested against sidecar extensions (`.sha256`, `.sha512`, `.md5`, `.sha2_256`, `.sha2`).
   d. **Sidecar branch:** `Test-HashSidecar` parses each non-empty line, detects the algorithm by hex length, computes `Get-FileHash` for each referenced file, and prints a per-file OK/FAILED/MISSING report plus a summary.
   e. **Regular-file branch:** Print metadata → run Authenticode check (Windows only, gated by `$script:SignableExtensions`) → compute each requested algorithm via `Get-And-SaveHash` → compare against `$InputHash` with `Test-InputHash` → emit sidecar files next to the source file.
8. Structured events are written to `verihash-<date>.jsonl`; user-visible output goes to the console via `Write-Host`.

**State Management:**
- No persistent runtime state. Configuration is read once per invocation into `$script:VeriHashConfig`.
- `$script:`-scoped variables (`$script:PSFrameworkAvailable`, `$script:VeriHashLogPath`, `$script:VeriHashConfig`, `$script:DesktopEnvironments`, `$script:SignableExtensions`, `$script:RunningOnWindows/Linux/MacOS`, `$script:ValidLogLevels`) act as effectively-global constants shared across all dot-sourced functions.
- All persistence is file-based: `config.json` for settings, `*.jsonl` for logs, sidecar files (`<name>.sha256`, etc.) for hashes.

## Key Abstractions

**Desktop Environment registry (`$script:DesktopEnvironments`):**
- Purpose: Extensibility point for Linux context-menu integration. Each key is a DE identifier; each value carries `Name`, `FileType`, `UserPath`, `SystemPath`, `DetectionVars`, `DesktopValue`, and a `Handler` function name.
- Defined: `VeriHash.ps1` lines ~213–224.
- Used by: `Get-DesktopEnvironment` (detection) and `Install-LinuxContextMenu` (dispatch via `Get-Command $config.Handler`).

**Sidecar file:**
- Purpose: Portable, human-readable checksum record stored next to the hashed file.
- Format: One entry per line, matching `^([A-Fa-f0-9]+)\s+\*?(.+)$` (hash + filename, GNU coreutils `sha256sum` compatible; `*` binary-mode marker accepted).
- Extensions recognised for verification: `.sha256`, `.sha512`, `.md5`, `.sha2_256`, `.sha2`.
- Produced by: `Get-And-SaveHash`. Consumed by: `Test-HashSidecar`.

**Configuration hashtable:**
- Shape: `@{ logging = @{ level; file; console }; virustotal = @{ apiKey; enabled; preferApi; autoOpen } }`.
- Optional `_source` sub-hashtable recording the origin of each leaf setting (`default` / `file` / `env`) when `Get-VeriHashConfig -IncludeSource` is called.
- Defined: `Get-VeriHashDefaultConfig` in `VeriHash.Config.ps1`.

**PSFramework availability gate:**
- Pattern: Every logging call is wrapped in `if ($script:PSFrameworkAvailable) { Write-PSFMessage ... }`. The single authoritative probe happens once at `VeriHash.ps1` line 100.
- Rationale: PSFramework is an optional dependency; the core tool must function when it is missing.

**Sanitised path:**
- Purpose: Strip user-identifying prefixes before emitting paths to logs.
- Pipeline idiom: `$path | ConvertTo-SanitizedPath` — used on every `-Data` value that contains a filesystem path.
- Round-trip helper `ConvertFrom-SanitizedPath` re-expands placeholders for local debugging.

## Entry Points

**`VeriHash.ps1`:**
- Location: `VeriHash.ps1`.
- Triggers: Direct invocation (`.\VeriHash.ps1 <path>`), PowerShell profile alias `verihash`, Windows SendTo shortcut, KDE Dolphin service menu, or `VeriHash-OpenWith.bat` wrapper.
- Responsibilities: Full hash/verify workflow described under Data Flow.

**`QuickHash.ps1`:**
- Location: `QuickHash.ps1`.
- Triggers: Direct invocation — prompts via `Read-Host` for an input value (string or path) and an algorithm (MD5 or SHA256 only).
- Responsibilities: Standalone, dependency-free interactive one-off hash. Does **not** dot-source the config/log modules and is intentionally decoupled from the main VeriHash feature set.

**`Test-All.ps1`:**
- Location: `Test-All.ps1`.
- Triggers: Developer invocation, CI pipeline (`.github\workflows\ci.yml`).
- Responsibilities: Runs Pester 5.x tests (`Tests\*.Tests.ps1`), PSScriptAnalyzer lint using `PSScriptAnalyzerSettings.psd1`, and optional timing profile.

**`Build.ps1`:**
- Location: `Build.ps1`.
- Triggers: Developer invocation for release cuts.
- Responsibilities: Runs `Test-All.ps1 -CI`; when `-Version` / `-UpdateVersion` are supplied, rewrites the `Version:` line in `VeriHash.ps1`.

**`Profile-VeriHashTiming.ps1`:**
- Location: `Profile-VeriHashTiming.ps1`.
- Triggers: Manual invocation.
- Responsibilities: Performance profiling harness over representative file sizes.

**`VeriHash-OpenWith.bat`:**
- Location: `VeriHash-OpenWith.bat`.
- Triggers: Windows "Open With" shell verb.
- Responsibilities: Thin `cmd.exe` launcher that hands the selected path to `pwsh -File VeriHash.ps1`.

## Error Handling

**Strategy:** Graceful degradation. The tool prints a coloured warning/error with `Write-Warning` / `Write-Error` / `Write-Host ... -ForegroundColor Red` and `return`s from the current function rather than throwing up the stack. Fatal parameter errors (missing `-FilePath`) still use `Write-Error` + `return`, not `throw`.

**Patterns:**
- `try { ... } catch { Write-Error "..." ; return }` around I/O and COM operations (e.g. `Install-WindowsSendTo`, `Select-File`, `Get-ClipboardHash`).
- Optional-feature gating: `if ($script:PSFrameworkAvailable) { ... }` around every log call; `if (Get-Command wl-paste -ErrorAction SilentlyContinue) { ... }` for Linux clipboard tools.
- Malformed `config.json` → warning logged, defaults used (see `Get-VeriHashConfig` catch block).
- Sidecar format errors → per-line `Write-Warning "Invalid format in line: $line"`; the loop continues so one bad line does not abort verification of the rest.
- `$ErrorActionPreference = 'Stop'` is set at the top of `Test-All.ps1` and `Build.ps1` so CI failures bubble up, but the end-user scripts do **not** set it globally.

## Cross-Cutting Concerns

**Logging:**
- Structured JSONL via PSFramework (`Write-PSFMessage -Level Debug|Verbose|Warning -Tag ... -Data @{...}`).
- Header allow-list (`FunctionName`, `Level`, `Line`, `Message`, `ModuleName`, `Runspace`, `Tags`, `TargetObject`, `Timestamp`, `Type`, `Data`) intentionally excludes `ComputerName`, `Username`, `File`.
- All path values inside `-Data` pass through `ConvertTo-SanitizedPath`.
- User-facing output is separate: `Write-Host` with ANSI colours, not captured in log files.

**Validation:**
- CLI parameters use `[ValidateSet(...)]` (`-Algorithm`, `-LogLevel`).
- Hashes are validated by regex length (`^[A-Fa-f0-9]{32|64|128}$`).
- Config values are validated against `$script:ValidLogLevels` before use; invalid values fall back to defaults with a warning.

**Platform dispatch:**
- Every platform-specific branch tests the `$RunningOnWindows` / `$script:RunningOnLinux` / `$script:RunningOnMacOS` booleans rather than re-probing `$PSVersionTable`.
- For Linux sub-platforms (KDE vs GNOME vs others), dispatch goes through the `$script:DesktopEnvironments` hashtable rather than hard-coded `switch` statements.

**Authentication:** Not applicable — the tool is local-only. VirusTotal API key support exists in config (`virustotal.apiKey`) but `virustotal.enabled` is `$false` by default and the integration is not yet shipped.

**Privacy / data minimisation:** See `VeriHash.LogUtils.ps1` — GDPR Article 5(1)(c), OWASP Logging Cheat Sheet, and CWE-532 are cited inline as the governing standards for log-header choice and path sanitisation.

---

*Architecture analysis: 2026-04-18*
