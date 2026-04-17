# Codebase Structure

**Analysis Date:** 2026-04-17

## Directory Layout

```
VeriHash/                           # Repository root
├── VeriHash.ps1                    # Main script (~1553 lines) — full hash tool
├── VeriHash.Config.ps1             # Configuration module (dot-sourced by VeriHash.ps1)
├── VeriHash.LogUtils.ps1           # Log utility functions (dot-sourced by VeriHash.ps1)
├── QuickHash.ps1                   # Standalone lightweight hash tool (independent)
├── VeriHash-OpenWith.bat           # Windows context-menu / SendTo launcher
├── Build.ps1                       # Build & release script (runs tests + version bump)
├── Test-All.ps1                    # Test runner (Pester + PSScriptAnalyzer + profiler)
├── Profile-VeriHashTiming.ps1      # Performance profiler (measures per-operation overhead)
├── PSScriptAnalyzerSettings.psd1   # PSScriptAnalyzer rule configuration
├── Microsoft.PowerShell_profile_example.ps1  # Example $PROFILE alias snippet
├── CHANGELOG.md                    # Version history
├── README.md                       # User-facing documentation
├── LICENSE.md                      # AGPL-3.0 license
├── Icons/                          # Icon assets for context menu integration
│   ├── VeriHash_256.ico            # Windows .ico (256px) — used in SendTo shortcut
│   ├── VeriHash_512.icns           # macOS .icns (512px)
│   ├── VeriHash_1024.png           # PNG (1024px) — used in Linux KDE context menu
│   ├── VeriHash_1024.webp          # WebP variant
│   ├── VeriHash_256.webp           # WebP variant
│   └── SourceIcons.7z              # Source icon archive
├── Tests/                          # Pester 5.x test suite
│   ├── VeriHash.Tests.ps1          # Tests for VeriHash.ps1 functions
│   ├── VeriHash.Config.Tests.ps1   # Tests for VeriHash.Config.ps1
│   ├── VeriHash.LogUtils.Tests.ps1 # Tests for VeriHash.LogUtils.ps1
│   ├── QuickHash.Tests.ps1         # Tests for QuickHash.ps1
│   ├── VeriHash.Timing.Tests.ps1   # Performance / timing tests
│   └── VeriHash_1024.ico           # Test fixture file (used as a known hashing target)
├── .planning/                      # GSD planning documents
│   └── codebase/                   # Codebase analysis docs (ARCHITECTURE.md, STRUCTURE.md, etc.)
├── .github/                        # GitHub configuration
├── .vscode/                        # VS Code workspace settings
├── tmp/                            # Temporary files (local, not committed)
└── VeriHash.code-workspace         # VS Code multi-root workspace file
```

## Directory Purposes

**Root (`/`):**
- Purpose: All primary scripts live directly at the root — no `src/` subdirectory
- Contains: Main tool scripts, companion modules, build/test runners, config, documentation
- Key files: `VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`, `QuickHash.ps1`

**`Icons/`:**
- Purpose: Icon assets distributed with the tool for OS context-menu integration
- Contains: `.ico` (Windows), `.icns` (macOS), `.png`/`.webp` (Linux/web), source archive
- Key files: `VeriHash_256.ico` (Windows shortcut), `VeriHash_1024.png` (Linux KDE install)
- Generated: No (hand-crafted assets, source in `SourceIcons.7z`)
- Committed: Yes

**`Tests/`:**
- Purpose: Pester 5.x test suite covering all major scripts
- Contains: One `.Tests.ps1` per source file, plus a timing test file and a test fixture (`.ico`)
- Key files: `VeriHash.Tests.ps1` (main coverage), `VeriHash_1024.ico` (fixture for hash tests)
- Test isolation: Each test file dot-sources its subject script in `BeforeAll`; config tests use `$TestDrive` for isolation

**`.planning/codebase/`:**
- Purpose: GSD codebase analysis documents consumed by planning and execution agents
- Contains: `ARCHITECTURE.md`, `STRUCTURE.md` (and other analysis docs as created)
- Generated: Yes (by GSD map-codebase commands)
- Committed: Yes

**`tmp/`:**
- Purpose: Local temporary workspace
- Generated: Yes
- Committed: No (in `.gitignore`)

## Key File Locations

**Entry Points:**
- `VeriHash.ps1`: Primary tool — full hash compute, verify, and context-menu install
- `QuickHash.ps1`: Secondary tool — lightweight hash of file or string, no config/logging
- `VeriHash-OpenWith.bat`: Windows shell launcher for "Send To" / "Open With" integration
- `Build.ps1`: Release pipeline — runs tests then optionally updates version header
- `Test-All.ps1`: Development quality gate — Pester + PSScriptAnalyzer + performance profiler

**Configuration:**
- `VeriHash.Config.ps1`: Configuration module (dot-sourced; provides `Get-VeriHashConfig`, `Set-VeriHashConfig`, etc.)
- `PSScriptAnalyzerSettings.psd1`: Static analysis rules (excludes `PSAvoidUsingWriteHost`, `PSAvoidUsingBrokenHashAlgorithms`)
- Runtime config file (Windows): `%APPDATA%\VeriHash\config.json` (created on first run)
- Runtime config file (Linux/macOS): `~/.verihash/config.json` (created on first run)

**Core Logic:**
- `VeriHash.ps1` `Invoke-HashFile` function (line ~1048): Main orchestration
- `VeriHash.ps1` `Get-And-SaveHash` function (line ~805): Hash computation + sidecar management
- `VeriHash.ps1` `Test-HashSidecar` function (line ~1416): Multi-entry sidecar verification
- `VeriHash.ps1` `Get-ClipboardHash` function (line ~690): Clipboard hash auto-detection

**Logging Utilities:**
- `VeriHash.LogUtils.ps1`: Provides `ConvertFrom-VeriHashLog`, `Get-VeriHashLogSummary`, `Get-VeriHashLogPath`
- Runtime log files (Windows): `%APPDATA%\VeriHash\logs\verihash-YYYY-MM-DD.json`
- Runtime log files (Linux/macOS): `~/.verihash/logs/verihash-YYYY-MM-DD.json`
- Test log files: `…/logs/test/verihash-YYYY-MM-DD.json` (when `$env:VERIHASH_TEST_MODE = '1'`)

**Testing:**
- `Tests/VeriHash.Tests.ps1`: Tests for `VeriHash.ps1` (Test-InputHash, Get-ClipboardHash, Get-And-SaveHash, Test-HashSidecar, Invoke-HashFile)
- `Tests/VeriHash.Config.Tests.ps1`: Tests for all `VeriHash.Config.ps1` functions
- `Tests/VeriHash.LogUtils.Tests.ps1`: Tests for all `VeriHash.LogUtils.ps1` functions
- `Tests/QuickHash.Tests.ps1`: Tests for `QuickHash.ps1`
- `Tests/VeriHash.Timing.Tests.ps1`: Performance regression tests
- `Tests/VeriHash_1024.ico`: Shared test fixture — a known file used for hash computation tests

**Documentation:**
- `README.md`: User documentation (installation, usage, profile alias)
- `CHANGELOG.md`: Version history
- `Microsoft.PowerShell_profile_example.ps1`: Example `$PROFILE` snippet showing how to add `verihash` alias
- `Verihash Logging Concepting.md`: Design notes for logging system (planning artifact)
- `Verihash Multifile Concepting.md` / `Verihash Multifile Concepting Review.md`: Design notes for multi-file sidecar support (planning artifacts)

## Naming Conventions

**Script Files:**
- Pattern: `PascalCase` with dot-separated namespacing: `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`
- Test files mirror their subject: `VeriHash.Config.ps1` → `Tests/VeriHash.Config.Tests.ps1`
- Standalone scripts use simple PascalCase: `Build.ps1`, `QuickHash.ps1`, `Test-All.ps1`

**Functions:**
- Pattern: `Verb-Noun` following PowerShell approved verbs
- Examples: `Get-VeriHashConfig`, `Set-VeriHashConfig`, `Invoke-HashFile`, `Test-HashSidecar`, `Get-And-SaveHash`, `ConvertTo-SanitizedPath`
- Prefix `VeriHash` used for all public/reusable functions in companion modules: `Get-VeriHashConfig`, `Get-VeriHashLogPath`, `ConvertFrom-VeriHashLog`

**Variables:**
- Script-scope state: `$script:VeriHashConfig`, `$script:PSFrameworkAvailable`, `$script:SignableExtensions`
- Local variables: camelCase — `$fileInfo`, `$hashValue`, `$sanitizedPath`, `$configDir`
- Boolean platform flags: `$RunningOnWindows`, `$RunningOnLinux`, `$RunningOnMacOS`

**Parameters:**
- PascalCase: `$FilePath`, `$Algorithm`, `$InputHash`, `$OnlyVerify`, `$NoPause`

**Sidecar File Extensions:**
- Pattern: `originalfilename.ext.hashext` (e.g., `setup.exe.sha256`, `archive.tar.gz.md5`)
- Hash extensions: `.sha256`, `.sha512`, `.md5`
- Legacy extensions: `.sha2`, `.sha2_256` (detected for compatibility but not created)

**Icon Files:**
- Pattern: `VeriHash_{size}.{format}` (e.g., `VeriHash_256.ico`, `VeriHash_1024.png`)

## Where to Add New Code

**New Hash Algorithm Support:**
- Add algorithm to `ValidateSet` in `param()` block of `VeriHash.ps1` (line ~65)
- Add extension mapping in `Get-And-SaveHash` switch block (line ~849)
- Add length pattern to `Get-ClipboardHash` (line ~764)
- Add length case to `Test-HashSidecar` switch (line ~1476)
- Add test cases to `Tests/VeriHash.Tests.ps1`

**New Configuration Setting:**
- Add default value in `Get-VeriHashDefaultConfig` in `VeriHash.Config.ps1`
- Add file merge logic in `Get-VeriHashConfig`
- Add env var override in `Get-VeriHashConfig`
- Add source tracking entry
- Add tests in `Tests/VeriHash.Config.Tests.ps1`

**New Context Menu Platform (e.g., GNOME):**
- Add entry to `$script:DesktopEnvironments` table in `VeriHash.ps1` (line ~238) with `Handler` pointing to a new function name
- Implement `Install-GNOMEContextMenu` function following the `Install-KDEContextMenu` pattern (lines 412–582)
- Place the new function before the `-SendTo` handler block (~line 623)

**New Log Utility Function:**
- Add function to `VeriHash.LogUtils.ps1` following the `[CmdletBinding()]` + `[OutputType()]` + comment-based help pattern
- Add tests to `Tests/VeriHash.LogUtils.Tests.ps1`

**New Test:**
- Place in `Tests/` directory as `SubjectName.Tests.ps1` or inside the matching existing test file
- Use `$TestDrive` for any file output; use `$env:VERIHASH_TEST_MODE = '1'` in `BeforeAll` if PSFramework logging will be triggered
- Use the existing `Tests/VeriHash_1024.ico` as a hash computation fixture rather than creating new binary fixtures

**New Standalone Utility Script:**
- Place at repository root following PascalCase naming (`MyTool.ps1`)
- Add corresponding test file `Tests/MyTool.Tests.ps1`
- Reference in `Test-All.ps1` if it should be covered by `PSScriptAnalyzer`

## Special Directories

**`tmp/`:**
- Purpose: Local scratch space during development
- Generated: Yes (ad-hoc)
- Committed: No

**`.planning/`:**
- Purpose: GSD agent planning and analysis documents
- Generated: Yes (by GSD commands)
- Committed: Yes

**`.github/`:**
- Purpose: GitHub Actions workflows and repository configuration
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-04-17*
