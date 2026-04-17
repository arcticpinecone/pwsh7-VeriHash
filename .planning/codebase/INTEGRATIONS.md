# External Integrations

**Analysis Date:** 2026-04-17

## APIs & External Services

**VirusTotal:**
- Service: VirusTotal hash lookup / file reputation
- Status: **Configuration scaffolding only — NOT yet implemented in `VeriHash.ps1`**
  - Config fields defined in `VeriHash.Config.ps1` (`virustotal.apiKey`, `virustotal.enabled`, `virustotal.preferApi`, `virustotal.autoOpen`)
  - No `Invoke-WebRequest` or `Invoke-RestMethod` calls to VirusTotal exist anywhere in current code
  - API key is stored/loaded but never consumed in the main script
- Auth: API key via `VERIHASH_VT_APIKEY` env var or `config.json` → `virustotal.apiKey`
- Config flags:
  - `virustotal.enabled` (bool) — toggle integration on/off
  - `virustotal.preferApi` (bool) — prefer API vs browser URL
  - `virustotal.autoOpen` (bool) — auto-open browser on result
- SDK/Client: None yet (planned)

## Data Storage

**Databases:**
- None — no database dependency of any kind

**File Storage:**
- Local filesystem only
- Sidecar hash files: written alongside target files with extensions `.md5`, `.sha256`, `.sha512`, `.sha2_256`, `.sha2`
- Format: Unix checksum standard — `HASH  filename.ext` (two-space separator)
- Config file: `%APPDATA%\VeriHash\config.json` (Windows) or `~/.verihash/config.json` (Linux/macOS)
- Log files: `%APPDATA%\VeriHash\logs\verihash-%date%.json` (Windows) or `~/.verihash/logs/verihash-%date%.json` (Linux/macOS)

**Caching:**
- None

## Authentication & Identity

**Auth Provider:**
- None — no user authentication, no login, no sessions
- VirusTotal API key stored in config file or env var (not yet consumed by implementation)

## OS & Shell Integrations

**Windows Authenticode Signatures:**
- PowerShell built-in `Get-AuthenticodeSignature` cmdlet
- Windows-only feature; silently skipped on Linux/macOS
- Supported file extensions: `.exe`, `.dll`, `.sys`, `.ocx`, `.cpl`, `.scr`, `.msi`, `.msix`, `.appx`, `.cab`, `.ps1`, `.psm1`, `.psd1`, `.ps1xml`, `.vbs`, `.vbe`, `.js`, `.jse`, `.wsf`
- Non-Authenticode-signable types reported as N/A: `.jar`, `.apk`, `.aab`, `.app`, `.ipa`, `.pkg`, `.dmg`, `.pdf`
- Can be skipped with `-SkipSignatureCheck` parameter

**Windows Clipboard:**
- `Get-Clipboard` built-in PowerShell cmdlet
- Auto-detects MD5 (32 hex chars), SHA256 (64 hex chars), SHA512 (128 hex chars) in clipboard on startup
- Used in `VeriHash.ps1` → `Get-ClipboardHash` function

**Linux Clipboard (runtime detection, first available wins):**
1. `wl-paste` — Wayland (e.g., `wl-clipboard` package)
2. `xclip -selection clipboard -o` — X11
3. `xsel --clipboard --output` — X11 alternative
- Advisory install messages shown if none found: `sudo pacman -S wl-clipboard` or `sudo pacman -S xclip`

**macOS Clipboard:**
- `Get-Clipboard` (PowerShell built-in, same as Windows path)

**Windows SendTo / "Open With" Integration:**
- `Install-WindowsSendTo` function in `VeriHash.ps1`
- Uses COM object `WScript.Shell` to create `.lnk` shortcut in `%APPDATA%\Microsoft\Windows\SendTo\`
- Triggered via `VeriHash.ps1 -SendTo`
- Batch wrapper: `VeriHash-OpenWith.bat` — discovers `pwsh.exe` via `where` or known install paths, auto-detects sidecar extensions to pass `-OnlyVerify`

**Windows GUI File Picker:**
- `System.Windows.Forms.OpenFileDialog` (.NET assembly)
- Falls back to `Read-Host` prompt if dialog fails
- Triggered interactively when no `-FilePath` argument is provided on Windows

**Linux KDE Desktop Context Menu:**
- `Install-KDEContextMenu` function in `VeriHash.ps1`
- Creates `.desktop` service menu file for KDE Plasma / Dolphin file manager
- User install: `~/.local/share/kio/servicemenus/verihash.desktop`
- System-wide install: `/usr/share/kio/servicemenus/verihash.desktop` (requires root)
- Icon: `Icons/VeriHash_1024.png` copied to XDG icon path
- Terminal emulator auto-detection (in order): `konsole`, `xterm`, `gnome-terminal`, `xfce4-terminal`, `alacritty`, `kitty`
- Triggered via `VeriHash.ps1 -SendTo` (Linux path) or `VeriHash.ps1 -SendTo -SystemWide`

**GNOME / Other Linux DEs:**
- Planned but not yet implemented (stub in `$script:DesktopEnvironments` hashtable)

## Monitoring & Observability

**Error Tracking:**
- None (no external service like Sentry, Raygun, etc.)

**Logs:**
- Structured JSON logging via PSFramework `logfile` provider (optional module)
- Log path: `%APPDATA%\VeriHash\logs\verihash-%date%.json` (Windows), `~/.verihash/logs/` (Linux/macOS)
- Log format: JSON lines, UTC timestamps, PSFramework message structure with `FunctionName`, `Level`, `Message`, `Tags`, `Data` fields
- Privacy: Paths sanitized before logging — `%USERPROFILE%` (Windows) or `~` (Linux/macOS) replaces full home paths; GDPR Article 5(1)(c) cited in code comments
- Log analysis utilities in `VeriHash.LogUtils.ps1`: `ConvertFrom-VeriHashLog`, `Get-VeriHashLogSummary`, `ConvertFrom-SanitizedPath`
- Test mode logs isolated to `logs/test/` subdirectory via `VERIHASH_TEST_MODE=1`

## CI/CD & Deployment

**Hosting:**
- No hosting — distributed as raw `.ps1` script files
- GitHub repository: `arcticpinecone/pwsh7-VeriHash`

**CI Pipeline:**
- No automated CI/CD pipeline detected (no `.github/workflows/` directory)
- Manual quality gate: `Test-All.ps1 -CI` (exits non-zero on failure, intended for CI use)
- Build script: `Build.ps1` (runs tests, optionally bumps version string)

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None currently active
- VirusTotal URL/API call is planned but not implemented

## Environment Configuration

**Required env vars:**
- None are strictly required — all have defaults

**Optional env vars:**
- `VERIHASH_LOG_LEVEL` — override log verbosity
- `VERIHASH_LOG_FILE` — toggle file logging
- `VERIHASH_LOG_CONSOLE` — toggle console logging
- `VERIHASH_VT_APIKEY` — VirusTotal API key (not yet consumed)
- `VERIHASH_VT_ENABLED` — enable VirusTotal feature (not yet consumed)
- `VERIHASH_TEST_MODE=1` — redirect PSFramework logs to `logs/test/`
- `VERIHASH_NO_CLEAR=1` — suppress terminal clear in profiler

**Secrets location:**
- VirusTotal API key: stored in `config.json` (`virustotal.apiKey`) or `VERIHASH_VT_APIKEY` env var
- No other secrets in use

---

*Integration audit: 2026-04-17*
