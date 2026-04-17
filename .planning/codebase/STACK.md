# Technology Stack

**Analysis Date:** 2026-04-17

## Languages

**Primary:**
- PowerShell 7+ (`pwsh`) - All application logic, tooling, and tests
  - Explicit `#Requires PowerShell 7+` constraint in `VeriHash.ps1`
  - Uses PS7-specific syntax: `-AsUTC`, `Get-Date -AsUTC`, `$PSVersionTable.Platform`

**Secondary:**
- Batch Script (Windows CMD) - `VeriHash-OpenWith.bat`: Windows "Open With" / "Send To" launcher wrapper

## Runtime

**Environment:**
- PowerShell 7+ (`pwsh`) — NOT Windows PowerShell 5.x
- Cross-platform: Windows (Win32NT), Linux (Unix/Linux), macOS (Unix/Darwin)
- Platform detection at runtime via `$PSVersionTable.Platform` and `$PSVersionTable.OS`

**Package Manager:**
- PowerShellGet / PSGallery — modules installed via `Install-Module`
- No lockfile (module installation is manual/documented)

## Frameworks

**Core:**
- None (pure PowerShell script tool — no module packaging, no framework)
- Dot-sourced module pattern: `VeriHash.ps1` dot-sources `VeriHash.Config.ps1` and `VeriHash.LogUtils.ps1`

**Logging:**
- PSFramework (optional, from PSGallery) — structured JSON logging with tagged messages
  - Install: `Install-Module PSFramework -Scope CurrentUser`
  - Used via `Write-PSFMessage`, `Set-PSFLoggingProvider`, `Set-PSFConfig`
  - Gracefully degrades: all PSFramework calls guarded by `$script:PSFrameworkAvailable` check
  - Log format: JSON lines, UTC timestamps, compressed, stored as `verihash-%date%.json`

**Testing:**
- Pester 5.x (from PSGallery) — PowerShell BDD test framework
  - Install: `Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser`
  - Config API: `New-PesterConfiguration`, `Invoke-Pester -Configuration $pesterConfig`
  - Test files: `Tests/VeriHash.Tests.ps1`, `Tests/VeriHash.Config.Tests.ps1`, `Tests/VeriHash.LogUtils.Tests.ps1`, `Tests/QuickHash.Tests.ps1`, `Tests/VeriHash.Timing.Tests.ps1`

**Code Quality:**
- PSScriptAnalyzer (from PSGallery) — static analysis / linting
  - Install: `Install-Module PSScriptAnalyzer`
  - Settings: `PSScriptAnalyzerSettings.psd1`
  - Target: PowerShell 7.0 compatibility (`PSUseCompatibleSyntax` rule, `TargetVersions = @('7.0')`)
  - Excluded rules: `PSAvoidUsingWriteHost` (intentional for interactive UI), `PSAvoidUsingBrokenHashAlgorithms` (MD5 legacy compatibility)

**Build/Dev:**
- `Build.ps1` — build script (runs Test-All.ps1, supports `-Version` / `-UpdateVersion` params)
- `Test-All.ps1` — full QA runner: Pester → PSScriptAnalyzer → Performance profiler
- `Profile-VeriHashTiming.ps1` — micro-benchmark profiler using `[System.Diagnostics.Stopwatch]`

## Key Dependencies

**Critical:**
- `Get-FileHash` (built-in PowerShell cmdlet) — core hash computation (MD5, SHA256, SHA512)
- `Get-AuthenticodeSignature` (built-in, Windows only) — Authenticode digital signature checking
- `System.Windows.Forms` (.NET assembly) — Windows GUI file picker (`Add-Type -AssemblyName System.Windows.Forms`)
- `System.Security.Cryptography` (.NET namespace) — hash computation in `QuickHash.ps1` (`[System.Security.Cryptography.MD5]::Create()`, `[System.Security.Cryptography.SHA256]::Create()`)
- `WScript.Shell` (COM object, Windows only) — shortcut creation (`New-Object -ComObject WScript.Shell`)

**Optional/External Modules:**
- `PSFramework` — structured logging (degrades gracefully if absent)
- `Pester` — testing only (dev dependency)
- `PSScriptAnalyzer` — linting only (dev dependency)

**Linux Clipboard Tools (optional, runtime detection):**
- `wl-paste` — Wayland clipboard
- `xclip` — X11 clipboard
- `xsel` — X11 clipboard alternative

## Configuration

**Environment Variables:**
- `VERIHASH_LOG_LEVEL` — logging level: `DEBUG`, `VERBOSE`, `INFO`, `WARNING`, `ERROR`, `NONE`
- `VERIHASH_LOG_FILE` — enable file logging: `true`/`false`
- `VERIHASH_LOG_CONSOLE` — enable console logging: `true`/`false`
- `VERIHASH_VT_APIKEY` — VirusTotal API key
- `VERIHASH_VT_ENABLED` — enable VirusTotal integration: `true`/`false`
- `VERIHASH_TEST_MODE` — redirects logs to `logs/test/` subdirectory: `1`
- `VERIHASH_NO_CLEAR` — prevents terminal clear during profiling: `1`

**Config File:**
- Format: JSON
- Windows path: `%APPDATA%\VeriHash\config.json`
- Linux/macOS path: `~/.verihash/config.json`
- Priority: Environment variables > Config file > Defaults
- Managed by: `VeriHash.Config.ps1` (`Get-VeriHashConfig`, `Set-VeriHashConfig`, `Initialize-VeriHashConfig`)
- Schema: `{ logging: { level, file, console }, virustotal: { apiKey, enabled, preferApi, autoOpen } }`

**Log Files:**
- Windows path: `%APPDATA%\VeriHash\logs\verihash-%date%.json`
- Linux/macOS path: `~/.verihash/logs/verihash-%date%.json`
- Format: JSON lines (PSFramework `logfile` provider), UTC timestamps, compressed

**Build:**
- No build artifacts — pure script distribution
- `Build.ps1` performs version string replacement via regex in `VeriHash.ps1` header comment

## Platform Requirements

**Development:**
- PowerShell 7+ (`pwsh`)
- Optional: Pester 5.x, PSScriptAnalyzer, PSFramework (all from PSGallery)

**Production:**
- PowerShell 7+ (`pwsh`) — mandatory
- Windows: full feature support (file dialog, Authenticode signatures, SendTo integration)
- Linux: KDE Plasma supported for context menu; clipboard requires `wl-paste`, `xclip`, or `xsel`
- macOS: basic hash/verify supported; context menu integration not implemented

**Version:**
- VeriHash tool version: `1.3.0` (as of December 27, 2025 per `VeriHash.ps1` header)

---

*Stack analysis: 2026-04-17*
