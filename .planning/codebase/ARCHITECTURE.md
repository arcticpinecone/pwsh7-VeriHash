# Architecture

**Analysis Date:** 2026-04-17

## Pattern Overview

**Overall:** Single-script CLI tool with dot-sourced companion modules

**Key Characteristics:**
- `VeriHash.ps1` is the monolithic entry point (~1553 lines); all core logic lives here
- Companion modules (`VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`) are dot-sourced at startup, making their functions available in the main script's scope
- All execution happens in a single PowerShell session — no background jobs, runspaces, or modules with explicit `Export-ModuleMember`
- Platform detection runs at startup and gates Windows-specific paths (Authenticode signatures, file dialog, clipboard API, context menu installation) throughout the entire script
- Logging via PSFramework is fully optional; every logging call is guarded by `$script:PSFrameworkAvailable` so the tool degrades gracefully to console-only output if PSFramework is not installed

## Layers

**CLI / Entry Layer:**
- Purpose: Parse parameters, handle early-exit paths (help display, `-SendTo` installation)
- Location: `VeriHash.ps1` lines 56–642
- Contains: `param()` block, help handler, `-SendTo` dispatcher
- Depends on: Config module (loaded immediately after `param()`), LogUtils module
- Used by: End users directly (command line, Windows Explorer, context menu)

**Platform & Initialization Layer:**
- Purpose: Detect OS, load configuration, initialize PSFramework logging, define script-scope constants
- Location: `VeriHash.ps1` lines 96–226 (platform detection, module dot-sourcing, PSFramework init)
- Contains: `$RunningOnWindows`, `$RunningOnLinux`, `$script:VeriHashConfig`, `$script:SignableExtensions`, `$script:DesktopEnvironments`, PSFramework `Set-PSFLoggingProvider` setup
- Depends on: `VeriHash.Config.ps1` (Get-VeriHashConfig), `VeriHash.LogUtils.ps1` (Get-VeriHashLogPath)
- Used by: All downstream functions via `$script:` scope variables

**Context Menu Integration Layer:**
- Purpose: Install VeriHash as a Windows SendTo shortcut or Linux desktop service menu
- Location: `VeriHash.ps1` lines 251–582
- Contains: `Get-DesktopEnvironment`, `Install-WindowsSendTo`, `Install-LinuxContextMenu`, `Install-KDEContextMenu`
- Depends on: Platform variables (`$RunningOnWindows`, `$RunningOnLinux`), `$script:DesktopEnvironments` dispatch table
- Used by: `-SendTo` parameter path (early-exit, never reaches `Invoke-HashFile`)

**Core Orchestration Layer:**
- Purpose: Coordinate the full hash compute/verify workflow for a single file invocation
- Location: `VeriHash.ps1` lines 1048–1413 (`Invoke-HashFile`)
- Contains: `Invoke-HashFile` — clipboard auto-detection, file selection prompt, sidecar-vs-file routing, algorithm determination, result display, timing output
- Depends on: `Get-ClipboardHash`, `Select-File`, `Test-HashSidecar`, `Get-And-SaveHash`, `Test-InputHash`, `ConvertTo-SanitizedPath`, PSFramework
- Used by: Script tail (line 1552): `Invoke-HashFile -FilePath $FilePath ...`

**Hash Computation Layer:**
- Purpose: Compute file hash with a given algorithm, manage sidecar files, handle mismatch resolution
- Location: `VeriHash.ps1` lines 805–1043 (`Get-And-SaveHash`)
- Contains: `Get-And-SaveHash` — calls `Get-FileHash`, builds sidecar filename, creates/updates/prompts on sidecar mismatch, returns a `[pscustomobject]` result
- Depends on: PowerShell built-in `Get-FileHash`, `ConvertTo-SanitizedPath`, PSFramework
- Used by: `Invoke-HashFile` (both verify and compute paths)

**Sidecar Verification Layer:**
- Purpose: Parse and verify a multi-entry `.sha256` / `.sha512` / `.md5` sidecar file against its referenced files
- Location: `VeriHash.ps1` lines 1416–1541 (`Test-HashSidecar`)
- Contains: `Test-HashSidecar` — reads sidecar lines, detects algorithm by hash length (32/64/128 chars), computes hashes, reports pass/fail/missing per file
- Depends on: `Get-FileHash`, `ConvertTo-SanitizedPath`, PSFramework
- Used by: `Invoke-HashFile` when the input file extension is `.sha256`, `.sha512`, `.md5`, `.sha2`, or `.sha2_256`

**Configuration Module:**
- Purpose: Unified configuration management with priority merging
- Location: `VeriHash.Config.ps1`
- Contains: `Get-VeriHashConfigPath`, `Get-VeriHashDefaultConfig`, `Get-VeriHashConfig`, `Set-VeriHashConfig`, `Initialize-VeriHashConfig`
- Depends on: PSFramework (optional, guarded), `$PSVersionTable`, environment variables
- Used by: `VeriHash.ps1` initialization layer via dot-source

**Log Utilities Module:**
- Purpose: Programmatic access to VeriHash JSON log files for analysis and export
- Location: `VeriHash.LogUtils.ps1`
- Contains: `Get-VeriHashLogPath`, `ConvertFrom-SanitizedPath`, `ConvertFrom-VeriHashLog`, `Get-VeriHashLogSummary`
- Depends on: Nothing (standalone; no PSFramework dependency)
- Used by: `VeriHash.ps1` initialization (Get-VeriHashLogPath); also directly callable by users

**Standalone Lightweight Tool:**
- Purpose: Quick hash computation for files or strings without full VeriHash overhead
- Location: `QuickHash.ps1`
- Contains: `Get-Hash` function — uses .NET `System.Security.Cryptography` directly, supports MD5 and SHA256 for both file paths and raw strings
- Depends on: Nothing (no dot-sourcing, no PSFramework, no config)
- Used by: Independent invocation; not called by `VeriHash.ps1`

## Data Flow

**Compute Hash (Normal File):**

1. User invokes `VeriHash.ps1 "C:\path\to\file.exe"` (or with no args for interactive mode)
2. `param()` block captures `$FilePath`, `$Hash`, `$Algorithm`, switches
3. Config module dot-sourced → `Get-VeriHashConfig` loads env vars > `config.json` > defaults into `$script:VeriHashConfig`
4. PSFramework initialized (if available); log provider configured to `verihash-%date%.json`
5. `Invoke-HashFile` called at script tail (line 1552)
6. `Get-ClipboardHash` auto-detects MD5/SHA256/SHA512 hash from clipboard by length pattern (32/64/128 hex chars)
7. If no `$FilePath` → `Select-File` opens Windows file dialog (`System.Windows.Forms.OpenFileDialog`) or falls back to `Read-Host`
8. File extension checked: if sidecar extension → `Test-HashSidecar` (alternate path)
9. File metadata displayed: size, created/modified dates, Authenticode signature (Windows only, skippable)
10. Algorithm list determined: detected from clipboard/`-Hash` length, then additional `-Algorithm` params
11. `Get-And-SaveHash` called per algorithm → `Get-FileHash` → sidecar written as `HASHVALUE  filename.ext`
12. If sidecar already exists with different hash: prompt user (Update/Keep/Rename/Cancel) or auto-update with `-Force`
13. Results displayed: hash value, timing (ms), throughput (MB/s), comparison matrix (clipboard vs sidecar)

**Verify via Sidecar File:**

1. User passes a `.sha256` / `.sha512` / `.md5` file as `$FilePath`
2. `Invoke-HashFile` detects sidecar extension and calls `Test-HashSidecar $FilePath`
3. `Test-HashSidecar` reads each line, parses `HASH  filename` format, detects algorithm by hash length
4. `Get-FileHash` computed for each referenced file in the same directory
5. Pass/fail/missing reported per file; summary printed

**Config Loading Priority:**

1. `Get-VeriHashDefaultConfig` returns baseline hashtable
2. `config.json` values merged over defaults (if file exists and is valid JSON)
3. Environment variables (`VERIHASH_LOG_LEVEL`, `VERIHASH_LOG_FILE`, `VERIHASH_LOG_CONSOLE`, `VERIHASH_VT_APIKEY`, `VERIHASH_VT_ENABLED`) merged last at highest priority
4. CLI `-LogLevel` parameter overrides everything for the current session

**State Management:**
- No persistent in-memory state between invocations (script-scoped variables only, cleared on exit)
- `$script:VeriHashConfig` hashtable holds merged config for the session
- `$script:PSFrameworkAvailable` boolean gates all logging calls
- `$script:SignableExtensions` and `$script:NonAuthenticodeSignableExtensions` are static arrays defined at parse time

## Key Abstractions

**Sidecar File:**
- Purpose: Stores a hash alongside a file in a companion text file
- Format: `HASHVALUE  filename.ext` (standard Unix checksum format, two spaces)
- Extensions: `.sha256`, `.sha512`, `.md5` (new); `.sha2`, `.sha2_256` (legacy)
- Created by: `Get-And-SaveHash` in `VeriHash.ps1`
- Verified by: `Test-HashSidecar` (multi-file sidecar), `Get-And-SaveHash` (single-file comparison)

**Hash Result Object (`[pscustomobject]`):**
- Returned by `Get-And-SaveHash` with properties: `Algorithm`, `Hash`, `Sidecar`, `SidecarHash`, `SidecarMatch`, `Duration`, `SidecarExists`, and optional `ForceUpdated`/`UserUpdated`/`UserRenamed`/`UserKept`/`UserCancelled`
- Consumed by `Invoke-HashFile` for display formatting

**Clipboard Hash Object (`[pscustomobject]`):**
- Returned by `Get-ClipboardHash` with properties: `Algorithm`, `Hash`
- Algorithm detected by hex string length (32=MD5, 64=SHA256, 128=SHA512)
- `$null` returned when clipboard is empty or contains no valid hash

**Configuration Hashtable:**
- Nested hashtable structure: `$config.logging.level`, `$config.logging.file`, `$config.logging.console`, `$config.virustotal.apiKey`, `$config.virustotal.enabled`, `$config.virustotal.preferApi`, `$config.virustotal.autoOpen`
- Optional `_source` tracking: `$config._source.'logging.level'` = `'default'|'file'|'env'`
- Persisted as `config.json` (Windows: `%APPDATA%\VeriHash\config.json`; Linux/macOS: `~/.verihash/config.json`)

**Desktop Environment Dispatch Table (`$script:DesktopEnvironments`):**
- Hashtable keyed by DE name (e.g., `'KDE'`)
- Each entry has: `Name`, `FileType`, `UserPath`, `SystemPath`, `DetectionVars`, `DesktopValue`, `Handler` (function name string)
- Enables extensible context-menu installation for future DEs (GNOME, XFCE planned)

## Entry Points

**VeriHash.ps1:**
- Location: `VeriHash.ps1`
- Triggers: Direct invocation (`.\VeriHash.ps1`), Windows Explorer double-click, `VeriHash-OpenWith.bat`, PowerShell profile alias (`verihash`)
- Responsibilities: Full hash compute/verify workflow, context menu installation (`-SendTo`), help display

**VeriHash-OpenWith.bat:**
- Location: `VeriHash-OpenWith.bat`
- Triggers: Windows "Send To" context menu, Windows "Open With" association
- Responsibilities: Locates `pwsh.exe`, detects sidecar extensions to set `-OnlyVerify`, forwards file path to `VeriHash.ps1 -NoPause`

**QuickHash.ps1:**
- Location: `QuickHash.ps1`
- Triggers: Direct invocation
- Responsibilities: Quick hash of a file path or raw string via .NET crypto; no config, no logging, no sidecar files

**Build.ps1:**
- Location: `Build.ps1`
- Triggers: Manual invocation during release process
- Responsibilities: Runs `Test-All.ps1 -CI`, optionally updates version string in `VeriHash.ps1` header

**Test-All.ps1:**
- Location: `Test-All.ps1`
- Triggers: Manual invocation, called by `Build.ps1`
- Responsibilities: Runs Pester 5.x test suite, PSScriptAnalyzer against `VeriHash.ps1`, optional performance profiler

## Error Handling

**Strategy:** Try/catch at the `Invoke-HashFile` level; individual functions use `Write-Error` or `Write-Warning` for recoverable issues

**Patterns:**
- `Invoke-HashFile` wraps the core workflow in a `try/catch` (lines 1105–1409); errors surface via `Write-Error`
- Config file parsing uses `try/catch` — malformed `config.json` silently falls back to defaults with a warning
- Platform-specific operations (clipboard, file dialog, Authenticode) wrapped in `try/catch` with graceful fallback messages
- PSFramework availability always checked via `$script:PSFrameworkAvailable` before any `Write-PSFMessage` call
- Sidecar hash mismatch is not an error — it triggers an interactive resolution prompt (or `-Force` auto-resolution)

## Cross-Cutting Concerns

**Logging:** PSFramework (optional) writing JSON log lines to `verihash-%date%.json`. Log level controlled by CLI `-LogLevel` > env `VERIHASH_LOG_LEVEL` > `config.json` > default (`None`). All log `Data` payloads have file paths sanitized via `ConvertTo-SanitizedPath`.

**Privacy / Data Minimization:** GDPR Article 5(1)(c) compliance pattern — `ConvertTo-SanitizedPath` replaces `$env:USERPROFILE` (Windows) or `$HOME` (Linux/macOS) with `%USERPROFILE%`/`~` in all log output. `ConvertFrom-SanitizedPath` (in `VeriHash.LogUtils.ps1`) reverses this for local debugging.

**Platform Detection:** `$RunningOnWindows` and `$RunningOnLinux` booleans set at script scope in both `VeriHash.ps1` and `VeriHash.Config.ps1`. Platform gates: file dialog (Windows only), clipboard tool selection (wl-paste/xclip/xsel on Linux), Authenticode signature check (Windows only), context menu installation paths.

**Test Mode:** `$env:VERIHASH_TEST_MODE = '1'` redirects PSFramework log output to a `test/` subdirectory inside the normal log path, preventing test runs from polluting production logs.

---

*Architecture analysis: 2026-04-17*
