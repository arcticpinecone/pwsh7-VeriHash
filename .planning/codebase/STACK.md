# Technology Stack

**Analysis Date:** 2026-04-18

## Languages

**Primary:**
- PowerShell 7+ (cross-platform, `pwsh`) — all production code lives in `.ps1` scripts
  - `VeriHash.ps1` (~66 KB, ~1,500+ lines) — main entry point and all core logic
  - `VeriHash.Config.ps1` — configuration module (dot-sourced)
  - `VeriHash.LogUtils.ps1` — logging/path sanitization utilities (dot-sourced)
  - `QuickHash.ps1` — standalone lightweight string/file hasher (independent)

**Secondary:**
- Windows Batch (`.bat`) — `VeriHash-OpenWith.bat` wrapper for Windows Explorer "Send To" / "Open With" integration (locates `pwsh.exe`, auto-detects sidecar extensions, forwards args)
- YAML — GitHub Actions CI pipeline at `.github\workflows\ci.yml`
- JSON / JSONL — config file format (`config.json`) and log file format (`verihash-YYYY-MM-DD.jsonl`)
- XDG `.desktop` file format — generated at runtime for KDE Plasma service menu integration

## Runtime

**Environment:**
- PowerShell 7.0 or later (required; Windows PowerShell 5.x is not supported)
- Declared indirectly via `# Requires PowerShell 7+` comment in `VeriHash.ps1` line 55 and via `PSUseCompatibleSyntax` target version `7.0` in `PSScriptAnalyzerSettings.psd1`
- Uses .NET APIs exposed by PowerShell 7 (e.g. `System.Security.Cryptography`, `System.Windows.Forms` on Windows, `System.IO.Path`)

**Package Manager:**
- PowerShell Gallery (`PSGallery`) — used via `Install-Module` for all dependencies
- No lockfile (PowerShell ecosystem has no equivalent of `package-lock.json`); versions are pinned loosely in CI (`Pester -MaximumVersion 5.99`)
- No `.psd1` module manifest — VeriHash is distributed as a script, not a module

## Frameworks

**Core:**
- None — VeriHash is a plain PowerShell script that uses built-in cmdlets (`Get-FileHash`, `Get-AuthenticodeSignature`, `Get-Clipboard`, `Set-PSFLoggingProvider`) and .NET types directly

**Testing:**
- Pester 5.x — unit + integration + timing tests under `Tests\`
  - Config path: `Test-All.ps1` (lines 84-89) builds `New-PesterConfiguration` inline; no dedicated config file
  - Test files: `Tests\VeriHash.Tests.ps1`, `Tests\VeriHash.Config.Tests.ps1`, `Tests\VeriHash.LogUtils.Tests.ps1`, `Tests\VeriHash.Timing.Tests.ps1`, `Tests\QuickHash.Tests.ps1`
- PSScriptAnalyzer — static lint checker, configured via `PSScriptAnalyzerSettings.psd1`

**Build/Dev:**
- `Build.ps1` — build script; runs `Test-All.ps1 -CI` then optionally rewrites `Version:` header in `VeriHash.ps1`
- `Test-All.ps1` — unified runner for Pester + PSScriptAnalyzer + optional profiler
- `Profile-VeriHashTiming.ps1` — performance profiler used by `Test-All.ps1` step 3/3

## Key Dependencies

**Critical (required):**
- Built-in PowerShell 7 cmdlets (no external modules required to run VeriHash at all):
  - `Microsoft.PowerShell.Utility\Get-FileHash` — MD5/SHA256/SHA512 computation
  - `Microsoft.PowerShell.Security\Get-AuthenticodeSignature` — Windows-only signature validation
  - `Microsoft.PowerShell.Management\Get-Clipboard` — clipboard read (Windows/macOS)

**Optional (graceful degradation via `$script:PSFrameworkAvailable` gate):**
- `PSFramework` (PSGallery) — structured JSON-lines logging backend
  - Checked once at startup: `$script:PSFrameworkAvailable = $null -ne (Get-Module -ListAvailable -Name PSFramework)` (`VeriHash.ps1:100`)
  - Imported with `-ErrorAction SilentlyContinue` (`VeriHash.ps1:133`)
  - Every `Write-PSFMessage` call is wrapped in `if ($script:PSFrameworkAvailable) { ... }`
  - Warning emitted if user passes `-LogLevel` but module is missing (`VeriHash.ps1:128-130`)

**Development-only (PSGallery):**
- `Pester` (< 6.0, pinned `-MaximumVersion 5.99` in CI) — test runner
- `PSScriptAnalyzer` — linter

**External CLI tools (Linux clipboard, probed at runtime via `Get-Command`):**
- `wl-paste` (Wayland), `xclip` (X11), `xsel` (X11 fallback) — clipboard read on Linux (`VeriHash.ps1:688-716`)
- `konsole`, `xterm`, `gnome-terminal`, `xfce4-terminal`, `alacritty`, `kitty` — terminal emulator discovery for KDE service menu (`VeriHash.ps1:482-489`)
- `chmod`, `id` — used during `-SendTo -SystemWide` install on Linux
- `pwsh` — looked up in `PATH` to build `Exec=` line of `.desktop` file

**Not yet integrated (declared in config defaults only):**
- VirusTotal API (v3) — config keys `virustotal.apiKey`, `virustotal.enabled`, `virustotal.preferApi`, `virustotal.autoOpen` exist in `VeriHash.Config.ps1:78-90` but no HTTP client / `Invoke-RestMethod` call is implemented yet. `enabled` defaults to `$false` with comment "VirusTotal integration not yet shipped; enable when implemented". See `.github\copilot-instructions.md` — Phase 3 is the active next milestone.

## Configuration

**Environment:**
- Config file (JSON): resolved by `Get-VeriHashConfigPath` in `VeriHash.Config.ps1:32-57`
  - Windows: `%APPDATA%\VeriHash\config.json`
  - Linux/macOS: `~/.verihash/config.json`
- Priority order (highest → lowest): environment variables → config file → built-in defaults (`Get-VeriHashDefaultConfig`)
- Recognised env vars (see `VeriHash.Config.ps1:231-261`):
  - `VERIHASH_LOG_LEVEL` — `DEBUG` | `VERBOSE` | `INFO` | `WARNING` | `ERROR` | `NONE`
  - `VERIHASH_LOG_FILE` — `true` / `false`
  - `VERIHASH_LOG_CONSOLE` — `true` / `false`
  - `VERIHASH_VT_APIKEY` — VirusTotal API key (forward-looking, unused today)
  - `VERIHASH_VT_ENABLED` — `true` / `false`
  - `VERIHASH_TEST_MODE` — `1` redirects log output under `logs\test\` to keep CI runs from polluting user logs
  - `VERIHASH_NO_CLEAR` — `1` prevents the profiler from clearing the terminal
- `.env` files are NOT used. Secrets (e.g. VT API key) flow via env vars or `config.json`.

**Build:**
- `PSScriptAnalyzerSettings.psd1` — linter rule set (excludes `PSAvoidUsingWriteHost`, `PSAvoidUsingBrokenHashAlgorithms`; enables `PSUseCompatibleSyntax` targeting `7.0`)
- `.github\workflows\ci.yml` — GitHub Actions pipeline (matrix: `ubuntu-latest`, `windows-latest`)
- No bundler, compiler, or transpiler — scripts are run directly by `pwsh`

## Platform Requirements

**Development:**
- PowerShell 7.0+ installed as `pwsh`
- Pester 5.x (`Install-Module Pester -Scope CurrentUser`)
- PSScriptAnalyzer (`Install-Module PSScriptAnalyzer -Scope CurrentUser`)
- PSFramework optional but recommended (`Install-Module PSFramework -Scope CurrentUser`)
- Git (GitHub CLI `gh` recommended per `README.md`)

**Production (end-user):**
- PowerShell 7.0+ on any of:
  - Windows 10 / 11 (primary; full feature set including `Get-AuthenticodeSignature`, WScript.Shell COM, `System.Windows.Forms` file picker)
  - Linux (Debian/Ubuntu/Arch/Garuda/Fedora; KDE Plasma context menu supported, GNOME/XFCE planned)
  - macOS 12+ (no Authenticode, no native context menu integration)
- Disk footprint: < 1 MB
- Optional runtime tools on Linux: `wl-clipboard` or `xclip`/`xsel` for clipboard hash detection; a supported terminal emulator for KDE service menu output

---

*Stack analysis: 2026-04-18*
