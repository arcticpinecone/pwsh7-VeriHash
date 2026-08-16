# External Integrations

**Analysis Date:** 2026-04-18

## APIs & External Services

**Planned / scaffolded only (not implemented in code):**
- **VirusTotal** — public file-reputation API
  - Intended purpose: look up computed file hashes against VirusTotal's detection database and optionally open the web report
  - Config surface present today (`VeriHash.Config.ps1:78-90`):
    ```
    virustotal = @{
        apiKey    = ''
        enabled   = $false   # "VirusTotal integration not yet shipped; enable when implemented"
        preferApi = $true
        autoOpen  = $false
    }
    ```
  - Env vars recognised: `VERIHASH_VT_APIKEY`, `VERIHASH_VT_ENABLED`
  - SDK/Client: none yet — no `Invoke-RestMethod` / `Invoke-WebRequest` calls exist in the codebase
  - Status: Phase 3 per `.github\copilot-instructions.md` ("⏳ Not started — this is the active next phase")

**Active integrations:** None. VeriHash does not currently make any outbound network calls.

## Data Storage

**Databases:** None. VeriHash is stateless aside from log files.

**File Storage:**
- Local filesystem only. Two persistent locations:
  - **Config directory** (`Get-VeriHashConfigPath` in `VeriHash.Config.ps1:32-57`):
    - Windows: `%APPDATA%\VeriHash\`
    - Linux/macOS: `~/.verihash/`
    - Contains `config.json` written by `Set-VeriHashConfig` (`VeriHash.Config.ps1:283-349`) with `ConvertTo-Json -Depth 3` and UTF-8 encoding
  - **Log directory** (`Get-VeriHashLogPath` in `VeriHash.LogUtils.ps1:18-42`):
    - Windows: `%APPDATA%\VeriHash\logs\`
    - Linux/macOS: `~/.verihash/logs/`
    - Test-mode subdirectory: `logs\test\` (when `$env:VERIHASH_TEST_MODE -eq '1'`)

**Caching:** None.

## Authentication & Identity

**Auth Provider:** Not applicable. VeriHash is a local CLI with no user accounts.

**Secret handling:**
- The only secret the product will consume is the VirusTotal API key (`VERIHASH_VT_APIKEY` env var or `virustotal.apiKey` in `config.json`).
- No secrets are currently stored in the repository. `.gitignore` excludes `*.log`, `*.txt`, `*.tmp`, `.claude/*`, `.serena/` and test-generated sidecar files.

## File System Integrations

**Sidecar checksum files:**
- Produced and consumed by `Get-And-SaveHash` (`VeriHash.ps1:780-`) and `Test-HashSidecar` (invoked at `VeriHash.ps1:1101`).
- Extensions recognised for auto-verification (`VeriHash.ps1:1079`):
  - `.sha256`
  - `.sha512`
  - `.md5`
  - `.sha2_256` (legacy VeriHash-specific)
  - `.sha2` (legacy VeriHash-specific)
- **On-disk format:** GNU/Unix `shasum`-compatible `HASHVALUE␠␠filename.ext`
  - Emitted at `VeriHash.ps1:840`: `$hashContent = "$hashValue  $($fileInfo.Name)"`
  - Parser accepts both two-space and space-asterisk separators (`VeriHash.ps1:1446` comment: "Support both two-space and space-asterisk formats")
- Naming pattern: sidecar is `<fullname.ext><algorithm-ext>` — e.g. `setup.exe` → `setup.exe.sha256`
- Extension dispatch in `Get-And-SaveHash` (`VeriHash.ps1:825-830`):
  ```powershell
  switch ($Algorithm) {
      'MD5'    { $ext = '.md5'    }
      'SHA256' { $ext = '.sha256' }
      'SHA512' { $ext = '.sha512' }
  }
  ```
- Multi-entry sidecar files are supported: `Test-HashSidecar` iterates every entry in the file and reports pass/fail counts (`VeriHash.ps1:1434-1507`).
- `.gitignore` excludes test-generated sidecars (`Tests/*.sha256`, `Tests/*.sha512`, `Tests/*.md5`).

**File dialog (Windows only):**
- When run without arguments, `Select-File` loads `System.Windows.Forms.OpenFileDialog` via `Add-Type -AssemblyName System.Windows.Forms` (`VeriHash.ps1:622-628`).
- Non-Windows platforms fall back to a prompt-based code path (no GUI).

## OS Context-Menu / SendTo Integration

All integrations are installed by running `VeriHash.ps1 -SendTo` (optionally with `-SystemWide` on Linux). Dispatch lives in the handler block around `VeriHash.ps1:599-616`.

**Windows — "Send To" shortcut (`Install-WindowsSendTo`, `VeriHash.ps1:284-337`):**
- Target folder: `$env:AppData\Microsoft\Windows\SendTo\VeriHash.lnk`
- Shortcut is created via COM: `New-Object -ComObject WScript.Shell` → `CreateShortcut(...)`
- Target: `pwsh` with arguments `-NoProfile -ExecutionPolicy Bypass -File "<VeriHash.ps1>"` (Bypass only if current execution policy is not already `Unrestricted`/`Bypass`)
- Icon: `Icons\VeriHash_256.ico` (falls back to default if file missing)
- Companion wrapper `VeriHash-OpenWith.bat` is provided for the Explorer "Open With..." workflow; it:
  - Locates `pwsh.exe` via `where pwsh.exe` → `%ProgramFiles%\PowerShell\7\` → `%ProgramFiles(x86)%\PowerShell\7\`
  - Auto-adds `-OnlyVerify` when the file extension is `.sha256`, `.sha2`, `.sha2_256`, `.md5`, or `.sha512`
  - Forwards `-NoPause` to VeriHash and pauses at the end only when no second argument is supplied (i.e. launched from Explorer)
- **No registry writes.** VeriHash does not touch `HKCR`, `HKCU\Software\Classes`, or `HKLM` — context-menu entries rely entirely on the SendTo folder.

**Linux — KDE Plasma / Dolphin service menu (`Install-KDEContextMenu`, `VeriHash.ps1:387-557`):**
- User-level install path: `~/.local/share/kio/servicemenus/verihash.desktop`
- System-wide install path: `/usr/share/kio/servicemenus/verihash.desktop` (requires root; enforced via `id -u` check at `VeriHash.ps1:417-432`)
- Icon copied to `~/.local/share/icons/hicolor/1024x1024/apps/verihash.png` (or `/usr/share/icons/...` system-wide), source `Icons\VeriHash_1024.png`; falls back to stock `utilities-file-archiver` if source missing
- Generated `.desktop` file (`VeriHash.ps1:506-522`) declares two actions:
  - `Desktop Action ComputeHash` → `Compute Hash (VeriHash)`
  - `Desktop Action VerifyHash` → `Verify Hash (VeriHash)` (passes `-OnlyVerify`)
- MIME scope: `MimeType=application/octet-stream;` — matches all files
- `Exec=` line wraps the `pwsh` call in the first terminal emulator found in PATH (priority: `konsole`, `xterm`, `gnome-terminal`, `xfce4-terminal`, `alacritty`, `kitty`) so users see output
- Both `VeriHash.ps1` and the `.desktop` file are `chmod +x`ed (KDE requires service menu files to be executable for trust reasons)

**Linux — desktop environment detection (`Get-DesktopEnvironment`, `VeriHash.ps1:228-282`):**
- Extensible hashtable `$script:DesktopEnvironments` (`VeriHash.ps1:213-224`) maps DE keys → `{ Name, FileType, UserPath, SystemPath, DetectionVars, DesktopValue, Handler }`
- Three-tier detection cascade:
  1. `$env:XDG_CURRENT_DESKTOP` regex match against `DesktopValue` list
  2. `$env:DESKTOP_SESSION` regex match
  3. Presence of any variable in `DetectionVars` (e.g. `KDE_FULL_SESSION`, `KDE_SESSION_VERSION`)
- Only KDE is currently wired up; comment at `VeriHash.ps1:223` notes GNOME/XFCE are planned extensions — add an entry and implement `Install-<DE>ContextMenu` with no dispatcher changes

**macOS:** No native context-menu installer. Standard CLI usage only.

## Clipboard Integration

Implemented in `Get-ClipboardHash` (`VeriHash.ps1:665-774`). Used when `-Hash` is not supplied, to auto-detect a hash the user copied.

**Read paths:**
- **Windows:** built-in `Get-Clipboard` cmdlet (line 679)
- **macOS / other Unix:** built-in `Get-Clipboard` (line 728)
- **Linux:** probes external CLIs in order until one returns data (lines 688-716):
  1. `wl-paste` (Wayland)
  2. `xclip -selection clipboard -o` (X11)
  3. `xsel --clipboard --output` (X11 fallback)
  - If none installed, prints remediation hint: `sudo pacman -S wl-clipboard` / `xclip`

**Detection logic (lines 740-773):** regex-matches the trimmed clipboard text against `^[A-Fa-f0-9]{32}$` (MD5), `^[A-Fa-f0-9]{64}$` (SHA256), `^[A-Fa-f0-9]{128}$` (SHA512) and returns `[pscustomobject]@{ Algorithm; Hash }` with hash uppercased. No write to clipboard is performed.

## Authenticode / Digital Signature Checking

Invoked from `Invoke-HashFile` (`VeriHash.ps1:1124-1161`). Windows-only — on Linux/macOS the code prints "Skipped (Authenticode signatures are not supported on this platform)".

**Mechanism:** `Get-AuthenticodeSignature -FilePath $FilePath` (line 1132); if `$signature.Status -eq 'Valid'` the UI prints ✅ with `$signature.SignerCertificate.Subject`, else 🚫.

**Extension allow-lists (defined at `VeriHash.ps1:191-210`):**
- `$script:SignableExtensions` — Authenticode-capable. Checked with `-in`:
  - PE binaries: `.exe`, `.dll`, `.sys`, `.ocx`, `.cpl`, `.scr`
  - Installers: `.msi`, `.msix`, `.appx`, `.cab`
  - PowerShell & script: `.ps1`, `.psm1`, `.psd1`, `.ps1xml`, `.vbs`, `.vbe`, `.js`, `.jse`, `.wsf`
- `$script:NonAuthenticodeSignableExtensions` — signable but not with Authenticode; reported as N/A:
  - `.jar`, `.apk`, `.aab`, `.app`, `.ipa`, `.pkg`, `.dmg`, `.pdf`
- Everything else prints `N/A (file type cannot be signed)`

**Bypass:** `-SkipSignatureCheck` parameter short-circuits the block entirely.

## PSFramework Logging Integration

PSFramework is the structured-logging backend. Every call site is gated behind `$script:PSFrameworkAvailable` (set once at `VeriHash.ps1:100`) so the module remains optional.

**Initialization (`VeriHash.ps1:108-188`):**
- `Import-Module PSFramework -ErrorAction SilentlyContinue`
- `Set-PSFLoggingProvider -Name 'logfile' -InstanceName 'VeriHash' ...` with:
  - `-FilePath (Join-Path $script:VeriHashLogPath "verihash-%date%.jsonl")`
  - `-FileType Json`, `-JsonCompress $true`, `-JsonNoComma $true`, `-JsonNoEmptyFirstLine $true`, `-JsonString $true`
  - `-UTC $true` — all timestamps normalised to UTC
  - `-LogRotatePath`, `-LogRotateFilter "verihash-*.jsonl"`, `-LogRetentionTime "30d"` — 30-day retention
  - `-Headers` customised to **exclude** `File`, `ComputerName`, `Username` (privacy / GDPR Art. 5(1)(c) — see `VeriHash.LogUtils.ps1:11-15` notice)
- Log-level priority: CLI `-LogLevel` > `$env:VERIHASH_LOG_LEVEL` > `config.logging.level` > default `INFO` (`VeriHash.ps1:113-124`)
- Level switches adjust `PSFramework.Message.Info.Maximum` / `.Verbose.Maximum` (values 3 / 6 / 9 for None / Verbose / Debug)

**Log format:** JSON Lines (`.jsonl`), one compact JSON object per event. Filename pattern `verihash-YYYY-MM-DD.jsonl`, rotated daily by PSFramework.

**Standard tags** (see `.github\copilot-instructions.md`): `Hash`, `Verify`, `Compute`, `Result`, `Entry`, `Success`, `Error`, `Install`, `Windows`, `Linux`, `KDE`, `Clipboard`, `Config`, `HashFile`, `Detected`, `NotFound`, `Init`.

**Privacy contract:**
- Paths must be piped through `ConvertTo-SanitizedPath` (`VeriHash.LogUtils.ps1:44-84`) before being logged — replaces `$env:USERPROFILE` with `%USERPROFILE%` on Windows and `$HOME` with `~` on Linux/macOS
- Inverse helper `ConvertFrom-SanitizedPath` (`VeriHash.LogUtils.ps1:86-124`) re-expands paths for local debugging
- Hashes are truncated to 16 chars + `...` before logging (e.g. `VeriHash.ps1:814, 1039`)
- File contents are never written to the log

**Log analysis utilities (`VeriHash.LogUtils.ps1`):**
- `ConvertFrom-VeriHashLog` — reads `.jsonl`, filters by `-Days` / `-Level` / `-Tag`, optional `-ExportCsv`
- `Get-VeriHashLogSummary` — aggregates counts by level/tag and returns top-N operation stats

## Monitoring & Observability

**Error Tracking:** None (no Sentry/Rollbar/etc.). Errors go to the local JSONL log when PSFramework is installed, plus console `Write-Warning` / `Write-Host`.

**Logs:** PSFramework JSONL files under the OS-specific log directory (see above).

**Metrics:** `Profile-VeriHashTiming.ps1` emits per-operation timing; consumed by `Test-All.ps1` step 3/3 for local profiling only.

## CI/CD & Deployment

**Hosting:** Not applicable — VeriHash is a script distributed via GitHub.

**CI Pipeline:** GitHub Actions — `.github\workflows\ci.yml`
- Triggers: push/PR on `dev` and `main` (path-filtered to `**.ps1`, `Tests/**`, `PSScriptAnalyzerSettings.psd1`), plus `workflow_dispatch`
- Concurrency group `ci-${{ github.ref }}` with `cancel-in-progress: true`
- Two jobs:
  1. **test** — matrix over `ubuntu-latest` + `windows-latest`; installs Pester `-MaximumVersion 5.99`; runs `Invoke-Pester` with `Run.Exit = $true` and `Output.Verbosity = 'Detailed'` against `./Tests`
  2. **lint** — ubuntu-only; installs PSScriptAnalyzer and runs it against `VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1` using `PSScriptAnalyzerSettings.psd1`; fails the build when any issue is found
- Default shell: `pwsh` for all steps

**Release automation:** `Build.ps1` — runs `Test-All.ps1 -CI`; with `-Version X.Y.Z -UpdateVersion` it rewrites the `Version:` header in `VeriHash.ps1`. Tag/push is manual (README steps).

## Environment Configuration

**Recognised env vars (all optional):**
- `VERIHASH_LOG_LEVEL`, `VERIHASH_LOG_FILE`, `VERIHASH_LOG_CONSOLE` — logging controls
- `VERIHASH_VT_APIKEY`, `VERIHASH_VT_ENABLED` — VirusTotal (forward-looking)
- `VERIHASH_TEST_MODE=1` — routes logs under `logs\test\`
- `VERIHASH_NO_CLEAR=1` — prevents profiler from clearing the terminal

**Secrets location:** User-owned env vars or `%APPDATA%\VeriHash\config.json` / `~/.verihash/config.json`. Nothing in-repo.

## Webhooks & Callbacks

**Incoming:** None. VeriHash does not run a server.
**Outgoing:** None today. VirusTotal's web-report auto-open is planned (`virustotal.autoOpen` config key exists but is not wired up).

---

*Integration audit: 2026-04-18*
