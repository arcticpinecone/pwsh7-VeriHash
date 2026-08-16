# VeriHash Changelog

## Version History

- Current stable release: [v2.0.0]
- Version 1.x history is collapsed below.

---

### [Unreleased] — v3.0

> UX Polish & Smart Routing

Numbered 3.0 rather than 2.1: the default algorithm, the sidecar extension policy, and the
entire console surface changed behaviour. A script written against v2.0 can observe different
output for the same invocation, so the major version moves.

**BREAKING CHANGES:**

- 💥 **The clipboard can change which algorithm runs.** A run that previously always computed
  SHA256 now computes whatever algorithm a hash on the clipboard implies. Precedence is
  explicit `-Algorithm` > clipboard > SHA256. Pass `-Algorithm SHA256` to pin the old behaviour.
- 💥 **`.md5` and `.sha1` sidecars are never written.** Sidecars are always `.sha256`, or
  `.sha512` under an explicit `-Algorithm SHA512`. Tooling that expected a sidecar matching the
  requested algorithm will not find one for the weak algorithms.
- 💥 **Console output was redesigned.** Anything scraping stdout must be re-checked.
  `BatchResult.TallyLine` remains byte-locked as the machine-readable seam.
- 💥 **A new `UNVERIFIED` verdict exists.** When a pasted hash cannot be answered, the banner
  abstains instead of falling through to the sidecar's verdict. Consumers that assumed
  MATCH/MISMATCH/HASHED were exhaustive must handle a fourth state.
- 💥 **The CLI pins `[Console]::OutputEncoding` to UTF-8.** Anything capturing its output must
  decode UTF-8.

**LICENSE CHANGE:**

- 📜 **License Update**: Changed from AGPL-3.0 to MIT
  - Reason: VeriHash is a small local-first utility; the network-copyleft protections AGPL
    exists to provide do not apply to it, and the permissive terms remove friction for anyone
    vendoring the modules
  - Previous versions (v2.0.0 and earlier) remain available under AGPL-3.0, and v1.2.1 and
    earlier under CC-BY-SA-4.0
  - Sole copyright holder, so no contributor relicensing consent was required

**ADDED:**

- 🔍 **The clipboard drives the algorithm**: paste the hash a vendor published and VeriHash
  hashes with *that* algorithm instead of refusing to answer. Precedence is
  explicit `-Algorithm` > clipboard > SHA256.
- 🤝 **A weak hash gets a SHA256 companion**: an MD5 or SHA1 question is answered *and*
  SHA256 is computed in the same run, in a parallel thread. Vendors who publish only MD5
  no longer cost the user the digest worth keeping, and the sidecar is always the SHA256.
- 🆕 **SHA1 is supported**: hashable, comparable, and inferred from a 40-character paste.
  Weak, so it is answered but never recorded.
- 🎛️ **`-Algorithm` on the CLI**: `MD5 | SHA1 | SHA256 | SHA512`, forwarded only when bound
  so it can outrank the clipboard without a default silently doing the same.
- 🔬 **An unsupported hash is named, not ignored**: a 56- or 96-character paste is reported as
  a likely SHA-224 or SHA-384 that VeriHash does not implement, instead of being reported as
  an empty clipboard. Telling a user who deliberately copied a digest that they copied
  nothing invites them to read silence as approval. Other lengths report the count. The
  record carries no algorithm and no hash, so nothing can ever be compared against it.
- 🧾 **Manifest verify counts rejected entries**: `Summary` gains a `Rejected` bucket and the
  tally line gains a `N rejected` field, always rendered — including as a zero, so nothing
  has to parse two shapes of the same line.

**CHANGED:**

- 🔐 **Sidecars are always `.sha256`** (or `.sha512` under an explicit SHA512). `.md5` and
  `.sha1` are never written. `Get-PreferredSidecar` ranks `.sha512 > .sha256 > .md5`, so a
  `.md5` written once would become a weak file a later run could promote to the trusted
  comparator — never writing it closes that path.
- 🎨 **Console output redesigned**: verdict banner, stacked 8-char-group hash comparison with
  divergence highlighting, four-row checklist grid, and a compact batch summary.
  Truecolor ANSI with `NO_COLOR` and ASCII-glyph fallbacks.
  - The banner is reversed video (coloured background), so MATCH / MISMATCH / HASHED reads at a glance
  - A mismatch highlights the diverging hash groups on both lines and names the divergence character
  - `BatchResult.TallyLine` keeps its byte-locked `X/N matched, Y mismatch, Z missing` format for scripts;
    only the console display changed
  - The CLI now pins `[Console]::OutputEncoding` to UTF-8 so glyphs render instead of mojibake

**PERFORMANCE:**

- ⚡ **One hash pass per run**: a sidecar check no longer re-hashes a file the hot path
  has already hashed. The elapsed row now names both scopes — total and hashing.

**BUG FIXES:**

- 🔧 **A sidecar is no longer created when the file fails clipboard verification**:
  recording a hash for a file the user was just told not to trust would manufacture false assurance.
- 🔧 **A spaced or labelled hash on the clipboard is recognised**: VeriHash printed hashes in
  8-character groups but could only read a contiguous run, so copying its own output back in
  reported an empty clipboard. Vendor labels (`SHA-256: …`), `sha256sum` lines (`<hex> *name`),
  and `certutil`'s 2-character groups now parse too. Whitespace is never joined across what
  may be two separate digests — two 64-hex hashes would otherwise concatenate into a
  plausible "SHA512" and be compared against the file.
- 🔧 **The manifest summary adds up**: `Test-VeriHashManifest` produced five entry statuses
  and counted three. `parse-error` and `traversal-rejected` entries were included in `Total`
  but in no bucket, so a 10-entry manifest with two rejected paths reported
  `8/10 passed, 0 mismatch, 0 missing` — and the two unaccounted-for entries were precisely
  the ones a security guard had rejected. Counts are now taken by walking the entries once
  and incrementing exactly one bucket each, and a status that maps to no bucket throws
  instead of vanishing.
- 🔧 **The test harness can fail**: `Test-All.ps1` built its Pester configuration without
  `Run.PassThru`, so `Invoke-Pester` returned nothing. The harness read `FailedCount` off
  `$null`, compared `$null -gt 0`, got `$false`, and reported "All tests PASSED" on every
  run — exiting 0 even with failing tests. It now requests the result object, and treats a
  null result as inconclusive rather than as success. Verified by running the suite with a
  deliberately failing test: exit 1, where the same scenario previously exited 0.

---

### [v2.0.0] (Current)

Version: 2.0.0
> Modular Rewrite — focused modules replace the monolith

**ARCHITECTURE:**

- 🏗️ **Modular rewrite**: The ~900-line `VeriHash.ps1` monolith is replaced by a ≤200-line thin CLI dispatcher and three focused PowerShell modules:
  - **VeriHash.Core** — hashing, clipboard parsing, sidecar verify, formatting, logging, platform detection
  - **VeriHash.HotPath** — PE-only Authenticode, parallel hash + signature via ThreadJob, multi-file batch loop with tally
  - **VeriHash.Manifest** — GNU `sha256sum`-compatible manifest create and verify with atomic writes, path-traversal guard, machine-readable exit codes

**NEW FEATURES:**

- 📦 **Manifest mode**: Create and verify `sha256sum`-compatible manifests
  - `.\VeriHash.ps1 file1.txt, file2.txt -Manifest` — creates manifest
  - `.\VeriHash.ps1 manifest.sha256 -Manifest` — verifies manifest (extension auto-detect)
  - Exit codes: 0 (all pass), 1 (mismatch), 2 (missing), 3 (parse error)
  - Atomic writes via temp-file-then-rename (no partial manifests on Ctrl+C)
  - Path traversal guard rejects entries escaping manifest directory
- 🔄 **Multi-file batch mode**: Process multiple files in a single invocation
  - Full result per file (hash, sidecar, clipboard, signature)
  - Final tally: `X/N matched, Y mismatch, Z missing`
- 📋 **Prefixed clipboard parsing**: `sha256:71792c...` prefix form is recognized alongside plain hex
  - Explicit prefix overrides length-based algorithm inference
- ⚡ **PE-only signature checking**: Non-PE files skip Authenticode (no `MZ` header → instant skip)
- 🔀 **Parallel hash + signature**: ThreadJob concurrency for PE files (wall-clock ≈ max, not sum)
- 📝 **Built-in plain-text logging**: `-Log` flag or `$env:VERIHASH_LOG=1` writes to `~/.verihash/verihash.log`
- 🖥️ **Manifest SendTo shortcut**: `-InstallSendTo` now creates both `VeriHash.lnk` and `VeriHash - Manifest.lnk`
- 🐧 **KDE manifest action**: KDE context menu includes Compute Hash, Verify Hash, and Manifest Hash actions

**⚠️ BREAKING CHANGES:**

- **Dropped parameters:**
  - `-Hash` / `-InputHash` — copy hash to clipboard instead
  - `-Algorithm` — SHA256 is always computed; use module API for others
  - `-OnlyVerify` — verification is automatic when sidecar/clipboard match exists
  - `-SkipSignatureCheck` — non-PE files are auto-skipped; PE files always check
  - `-Force` — sidecar conflicts are handled interactively
  - `-LogLevel` — replaced by simple `-Log` on/off switch
- **Renamed parameters:**
  - `-SendTo` → `-InstallSendTo` (clearer intent)
- **Removed features:**
  - ❌ **VirusTotal integration** — removed entirely (scope creep; never shipped in releases)
  - ❌ **PSFramework dependency** — replaced by built-in plain-text logger
  - ❌ **QuickHash.ps1** — removed (v2 hot-path replaces its purpose)
  - ❌ **VeriHash.LogUtils.ps1** — removed (log analysis utilities, no v2 consumer)
  - ❌ **VeriHash.Config.ps1** — removed (v2 has no config file system)
  - ❌ **VeriHash-OpenWith.bat** — removed (replaced by proper .lnk shortcuts)
  - ❌ **Interactive file picker** — replaced by help banner with usage examples
- **Behavior changes:**
  - `[string[]]$FilePath` replaces `[string]$FilePath` (array input for multi-file)
  - Pause-at-end auto-detects GUI launch; terminal sessions skip pause automatically
  - No-args invocation shows help banner instead of file picker dialog

---

`<details>`
`<summary>📜 Version 1.x History</summary>`

### [Unreleased]

**BUG FIXES:**

- 🔧 **Fixed `Get-VeriHashLogSummary` not reading logs properly**: Was showing only 2 entries instead of 200+
  - `ConvertFrom-VeriHashLog` now handles UTF-8 BOM at file start
  - Strips trailing commas from JSON lines (PSFramework array format artifact)
  - Skips standalone comma lines in log files

**IMPROVEMENTS:**

- 🧪 **Test logs now separated from production logs**: Tests no longer pollute user's log history
  - New `VERIHASH_TEST_MODE=1` environment variable redirects logs to `logs/test/` subdirectory
  - `VeriHash.Tests.ps1` sets this automatically in `BeforeAll`/`AfterAll`

- 🤖 **Fixed interactive prompts blocking test runs**: All test invocations now include `-NoPause -Force`
  - Prevents "Press Enter to continue..." prompts during automated testing
  - Prevents sidecar conflict prompts during automated testing

---

### [v1.3.0] (Current)

Version: 1.3.0 - 2025-12-27
> Linux Desktop Integration & Cross-Platform Enhancements

**NEW FEATURES:**

- 🐧 **Linux context menu integration**: Right-click files in Dolphin to compute/verify hashes
  - ✅ **KDE Plasma/Dolphin support**: Native .desktop service menu integration
  - 📂 **User-level & system-wide installation**: `./VeriHash.ps1 -SendTo` or with `-SystemWide` flag
  - 🎨 **Icon integration**: VeriHash icon appears in context menu
  - 🔧 **Two actions**: "Compute Hash" and "Verify Hash" (with -OnlyVerify)
  - 🖥️ **Terminal window output**: Opens in Konsole/xterm for visual feedback
  - 🚀 **Extensible architecture**: Easy to add GNOME, XFCE support in future

- 📋 **Linux clipboard detection**: Auto-detects hashes in clipboard on Linux
  - Supports Wayland (`wl-paste`) and X11 (`xclip`, `xsel`)
  - Works the same way as Windows clipboard detection
  - Install: `sudo pacman -S wl-clipboard` (Wayland) or `sudo pacman -S xclip` (X11)

- ⚙️ **`-SystemWide` parameter**: Install context menu for all users (Linux only, requires sudo)
  - Usage: `sudo pwsh -File VeriHash.ps1 -SendTo -SystemWide`
  - Installs to `/usr/share/kio/servicemenus/` and `/usr/share/icons/`

**IMPROVEMENTS:**

- ⚡ **Hash processing speed display**: Now shows real-time throughput (MB/s or GB/s) after each hash computation
  - Example: `Hash speed:     175.25 MB/s` for a 3.7 GB file hashed in 21 seconds
  - Auto-scales to GB/s for very fast operations (≥ 1000 MB/s)
  - Helps users understand actual disk/hashing performance
  - Displayed alongside hash time for all algorithms (MD5, SHA256, SHA512)

- 🏗️ **Refactored -SendTo logic**: Platform-specific handlers for better maintainability
  - Windows: `Install-WindowsSendTo` function
  - Linux: `Install-LinuxContextMenu` → `Install-KDEContextMenu`
  - Extensible configuration system for adding new desktop environments
  - Automatically detects `pwsh` location (works with any PowerShell installation path)

- 🔍 **Smart desktop environment detection**: Auto-detects KDE via XDG_CURRENT_DESKTOP
  - Graceful fallback for unknown environments with helpful error messages
  - Shows detected environment variables for troubleshooting

- 🛡️ **Enhanced error handling**: Permission checks, dependency validation, helpful troubleshooting
  - Root privilege check for system-wide installation
  - PowerShell 7 detection with distribution-specific install instructions
  - Icon fallback to system icons if VeriHash icon missing
  - **Automatic execute permissions**: Installer now sets `chmod +x` on VeriHash.ps1 (required by KDE)

- 🐛 **Fixed Linux clipboard array handling**: PowerShell now correctly joins multi-line clipboard output
  - Resolves issue where `wl-paste` output was captured as array instead of string
  - Clipboard detection now works reliably on Wayland and X11

**TECHNICAL DETAILS:**

- New functions: `Get-DesktopEnvironment`, `Install-LinuxContextMenu`, `Install-KDEContextMenu`, `Install-WindowsSendTo`
- New configuration: `$script:DesktopEnvironments` hash table for extensibility
- New variable: `$RunningOnLinux` for Linux platform detection
- KDE integration: Creates `.desktop` file in `~/.local/share/kio/servicemenus/` or `/usr/share/kio/servicemenus/`
- Icon handling: Copies PNG icon to Linux icon directories with proper fallback

**TESTING (Linux Compatibility):**

- 🧪 **Fixed all 16 Linux test failures**: All 91 tests now pass on Linux
  - **Profile-VeriHashTiming.ps1**: Added platform-aware `Get-AuthenticodeSignature` handling
    - Windows: Uses Authenticode signature checks (significant overhead)
    - Linux/macOS: Skips unavailable cmdlet gracefully (instant check)
  - **Profile-VeriHashTiming.ps1**: New `-Quiet` parameter for cleaner test integration
    - Suppresses console output for programmatic use
    - Returns structured result object for Pester tests
    - Platform-aware Clear-Host handling
  - **VeriHash.Timing.Tests.ps1**: Optimized "hash once, test many" pattern
    - Replaces old Profile-VeriHashTiming.Tests.ps1 with performance-optimized version
    - Profiles large files only 3 times (once per algorithm) in BeforeAll
    - Reuses cached results across all test cases (3x faster execution)
    - Maintains full test coverage with zero redundant hashing
  - **Test-All.ps1**: Enhanced with integrated performance profiler summary
    - Shows quick overhead breakdown for small files
    - Provides throughput insights without verbose output
    - New `-SkipProfiler` parameter for flexibility
    - Improved visual formatting with Unicode box-drawing characters
  - **Clipboard test mocks**: Platform-specific mocking for Linux clipboard tools
    - Mocks `wl-paste`, `xclip`, `xsel` only if they exist on the system
    - Prevents "CommandNotFoundException" errors in Pester tests
  - **Sidecar format test**: Updated regex to expect Unix format (`HASH  filename`)
  - **Performance tests**: Platform-aware expectations for signature check overhead
- ✅ **100% test pass rate** on both Windows 11 and Linux (Garuda Linux verified)
- ✅ **Cross-platform test suite**: Tests adapt to platform capabilities automatically

**CODE QUALITY:**

- 🔧 **Profile-VeriHashTiming.ps1 cleanup**: Fixed PSScriptAnalyzer warnings
  - Removed 3 unused variable assignments (`$sizeFormatted`, `$utcString`, `$isSigned`)
  - Variables now use `$null =` pattern since we're measuring operations, not using results
  - Fixed empty catch block warning (added comment + `$null = $_` statement)
  - All 91 tests continue to pass after cleanup

**INSTALLATION:**

```bash
# Linux (user-level, recommended)
pwsh -File VeriHash.ps1 -SendTo

# Linux (system-wide, requires sudo)
sudo pwsh -File VeriHash.ps1 -SendTo -SystemWide

# Windows (unchanged)
.\VeriHash.ps1 -SendTo
```

---

### [v1.2.6] (Previous)

Version: 1.2.6 - 2025-12-05
> Critical Bug Fix - Duration Display Rounding Error

**CRITICAL BUG FIX:**

- 🐛 **Fixed duration rounding bug in time display**: Duration minutes were being rounded instead of truncated
  - **Problem:** PowerShell's `[int]` cast uses ROUNDING, not TRUNCATION
  - **Example bug:** 41.933 seconds displayed as "01 minutes, 41 seconds" instead of "00 minutes, 41 seconds"
  - **Root cause:** `[int]0.699` rounds UP to 1, but `.Seconds` property correctly shows 41
  - **When it appears:** Any duration with TotalMinutes in ranges like 0.5-0.999 (30-59.99s), 1.5-1.999 (90-119.99s), etc.
  - **Fix:** Replaced all `[int]$duration.TotalMinutes` with `[Math]::Floor($duration.TotalMinutes)`
  - **Fixed in:** VeriHash.ps1:654, 777, 815 (all three duration display locations)
  - **Impact:** All hash time and total time displays now show mathematically correct values

**COMPATIBILITY:**

- ✅ No breaking changes
- ✅ Pure display fix - no functional changes to hashing or verification logic
- ✅ All existing tests continue to pass

---

### [v1.2.5]

Version: 1.2.5 - 2025-11-18
> Critical Bug Fixes & Enhanced Batch Wrapper

 CRITICAL BUG FIX:

- 🐛 **Fixed sidecar file format bug**: Sidecar files now use the correct standard Unix format
  - **Before:** VeriHash created files in format `filename.ext  HASHVALUE` but expected to read `HASHVALUE  filename.ext`
  - **After:** VeriHash creates files in standard format `HASHVALUE  filename.ext` (Unix/GNU coreutils compatible)
  - **Impact:** This bug prevented proper verification when using right-click → Send To → VeriHash on `.sha256` files
  - **Error seen:** `WARNING: Invalid format in line: VeriHash_1024.ico  3EB53E0...` followed by 0 passed files
  - **Backward compatibility:** VeriHash can still read old-format sidecar files automatically
  - **Fixed in:** VeriHash.ps1:312 (write format) and VeriHash.ps1:336-341 (smart parsing for both formats)

 NEW FEATURES:

- ✨ **`-NoPause` parameter**: Skip the 'Press Enter to continue...' prompt at the end of execution
  - Ideal for batch file integration and automation scripts
  - Usage: `.\VeriHash.ps1 file.exe -NoPause`
  - Useful when called from batch wrappers or scheduled tasks
- 📂 **Enhanced batch wrapper v1.2.0** (`VeriHash-OpenWith.bat`):
  - **Auto-detect hash files:** Automatically recognizes `.sha256`, `.md5`, `.sha512`, `.sha2`, `.sha2_256` file extensions
  - **Auto-verify mode:** Automatically enables `-OnlyVerify` flag when a hash sidecar file is opened
  - **Performance optimization:** Checks PATH first for PowerShell 7 before checking Program Files locations
  - **Better integration:** Perfect for Windows file associations and Send To functionality
  - Now you can right-click a `.sha256` file and it will automatically verify the referenced file!

 IMPROVEMENTS:

- 🔍 **Smarter sidecar parsing**: Detects hash regardless of position (hash-first or filename-first) in sidecar files
  - Uses regex pattern `^[A-Fa-f0-9]{32,128}$` to identify which part is the hash
  - Supports both standard format (hash first) and legacy format (filename first)
  - More robust handling of different sidecar file formats
- 📝 **Updated help text**: Documented new `-NoPause` parameter in help output and examples
- 🔧 **Batch wrapper integration**: VeriHash.ps1 now properly integrates with the enhanced batch wrapper

 MERGE NOTES:

This release represents the successful merge of two development branches:

- Base: `claude/fix-verihash-timestamp-01BGad5gzg2VXAKJkF8ry4rN` (v1.2.4 with all advanced features)
- Enhancements: `claude/review-batch-wrapper-01EfrB1RBhfMhnfF286DoFwD` (batch wrapper improvements)

All features from v1.2.4 are preserved, including:

- `-Force` parameter for auto-updating sidecars
- `-SkipSignatureCheck` parameter for performance
- Smart signature detection
- Performance profiling tools
- Comprehensive test suite (91 tests)
- Millisecond-precision timing
- ISO8601 UTC timestamps

### [v1.2.4]

 Version: 1.2.4 - 2025-11-17
 Enhanced Testing, Bug Fixes, UX Improvements & Performance Analysis Tools

 NEW FEATURES:

- ✨ **`-Force` parameter**: Auto-update sidecars without prompting when hash mismatches detected
- ✨ **`-SkipSignatureCheck` parameter**: Skip digital signature verification (~65% faster for small files)
- 🧠 **Smart signature detection**: Automatically categorizes files (Authenticode-signable, non-Authenticode signable, non-signable)
- 🔍 **Performance profiling tool**: `Profile-VeriHashTiming.ps1` analyzes execution overhead breakdown
- ⏱️ **Millisecond precision**: Hash time calculations now show exact timing to milliseconds
- 🕐 **ISO8601 UTC timestamps**: Start/end timestamps with millisecond precision

 BUG FIXES:

- 🐛 Fixed "Saved to:" vs "Sidecar path:" labeling confusion
- 🐛 Fixed cached SidecarMatch bug after user updates sidecar
- 🐛 Fixed cached SidecarHash displaying old hash after update
- 🐛 Removed 1GB signature check limit (now user-controlled via `-SkipSignatureCheck`)
- 🐛 Removed unused variables flagged by PSScriptAnalyzer

 IMPROVEMENTS:

- ⏱️ Improved timing accuracy (moved `$startTime` initialization)
- 📋 Clipboard + Sidecar comparison matrix with clear visual indicators
- 🔍 Better sidecar match messaging and mismatch prompts

 TESTING:

- 🧪 Added 42 new test cases (91 tests total, was 59)
- ✅ Profile-VeriHashTiming.ps1 test suite (17 tests)
- ✅ Smart signature detection tests (10 tests)
- ✅ SkipSignatureCheck parameter tests (5 tests)
- ✅ 100% pass rate, PSScriptAnalyzer clean

---

### [v1.2.3]

Version: 1.2.3 - 2025-11-17
> Documentation & Testing Improvements

**NEW FEATURES:**

- 🧪 **Profile & SendTo Integration Tests**: 22 Pester tests for PowerShell Profile and Windows SendTo functionality
  - Profile creation, loading, and function availability validation
  - SendTo shortcut creation and properties verification
  - Test file: `Tests/ProfileAndSendTo.Tests.ps1`

**DOCUMENTATION IMPROVEMENTS:**

- 📚 **PowerShell Profile Integration Troubleshooting**: 55+ lines covering common issues (command not found, execution policy, etc.)
- 📚 **Windows SendTo Menu Integration**: 115+ lines with setup, troubleshooting, and design decisions
- 📚 **Enhanced Testing Documentation**: Test-All.ps1 usage, Pester version verification, coverage details

**COMPATIBILITY:**

- ✅ No breaking changes, 220+ lines of new user-facing guidance

---

### [v1.2.2]

Version: 1.2.2 - 2025-01-16
> Testing & Quality Improvements

**NEW FEATURES:**

- 🧪 **QuickHash Test Suite**: Added comprehensive Pester tests for QuickHash.ps1
  - 22 test cases covering all functionality
  - File hashing validation (MD5 & SHA256)
  - String hashing validation (MD5 & SHA256)
  - Known hash verification with test vectors
  - Algorithm parameter validation
  - Hash output format verification (32-char MD5, 64-char SHA256)
  - Special characters and Unicode handling
  - File vs string detection logic
  - Error handling and edge cases
  - Test file: `Tests/QuickHash.Tests.ps1`

**BUG FIXES:**

- 🐛 **PowerShell 7 Compatibility**: Fixed deprecated `-Encoding Byte` parameter in QuickHash.ps1
  - Changed to `-AsByteStream -Raw` for PowerShell 7+ compatibility
  - QuickHash.ps1 line 19: File reading now uses modern cmdlet parameters
  - Resolves errors when running on PowerShell 7+

**CODE QUALITY:**

- ✅ **PSScriptAnalyzer Validation**: QuickHash.ps1 passes all PSScriptAnalyzer rules
- ✅ **100% Test Pass Rate**: All 22 Pester tests passing
- 📊 **Test Coverage**: Comprehensive coverage of all QuickHash functionality
  - File hashing (5 tests)
  - String hashing (7 tests)
  - Algorithm validation (4 tests)
  - Error handling (1 test)
  - File vs string logic (2 tests)
  - Script validation (3 tests)

**COMPATIBILITY:**

- ✅ Fully compatible with PowerShell 7.0+
- ✅ All existing functionality preserved
- ✅ No breaking changes

**LICENSE CHANGE:**

- 📜 **License Update**: Changed from CC-BY-SA-4.0 to AGPL-3.0
  - Reason: AGPL is designed specifically for software and provides stronger copyleft protections
  - Network copyleft: Modified versions served over a network must provide source code
  - Previous versions (v1.2.1 and earlier) remain available under CC-BY-SA-4.0
  - This ensures the project remains free software with proper legal protections for code
  - Patent grant and software-specific terms now properly applied

---

### [v1.2.1]

Version: 1.2.1 - 2025-01-16
> File Extension Standardization & UX Improvements

**BREAKING CHANGES:**

- 📦 **New file extensions**: Changed from HashTab-style to GNU coreutils standard
  - `.sha2_256` → `.sha256` (SHA256 hashes)
  - `.sha2` → `.sha512` (SHA512 hashes)
  - `.md5` remains unchanged
- ⚠️ **Backward compatibility**: VeriHash still recognizes and verifies old `.sha2_256` and `.sha2` files

 NEW FEATURES:

- ✨ **Multi-file checksum verification**: Can now verify checksum files containing multiple entries
  - Example: `checksums.sha256` with multiple `hash  filename` lines
  - Compatible with GNU `sha256sum`, `sha512sum`, and `md5sum` output format
  - Shows summary with passed/failed/missing file counts
- ✨ **Enhanced file dialog fallback**: Better handling when GUI dialogs fail (e.g., in VSCode)
  - Auto-falls back to manual path entry if Windows Forms dialog doesn't appear
  - Clear prompts with cancellation option

 BUG FIXES:

- 🐛 Fixed confusing error message when cancelling file selection dialog
  - Now shows: "Operation cancelled. No file was selected." instead of file path error
- 🐛 Fixed "stuck in loop" behavior when running without parameters
  - Removed duplicate "Press Enter" prompts
- 🐛 Improved VSCode integrated terminal compatibility
  - File dialog failures now gracefully fall back to manual entry

 UX IMPROVEMENTS:

- 💬 Clearer cancellation messages throughout the tool
- 💬 Better error messages that show the actual invalid path
- 💬 Friendlier prompts with explicit cancellation instructions
- 🎨 Multi-file verification output shows per-file status (OK ✅ / FAILED 🚫 / MISSING ⚠️)

 COMPATIBILITY:

- ✅ Fully compatible with GNU coreutils checksum file format
- ✅ Can verify files created by `sha256sum`, `sha512sum`, and `md5sum`
- ✅ Supports both text mode (`hash  filename`) and binary mode (`hash *filename`) formats

---

### [v1.2.0] 🎉

 Version: 1.2.0 - 2025-01-16
 > Major Feature Release & Code Quality Improvements

 NEW FEATURES:

- ✨ `-Algorithm` parameter: Choose which hash(es) to compute (MD5, SHA256, SHA512, or All)
   Example: `.\VeriHash.ps1 file.exe -Algorithm MD5,SHA512`
- ✨ `-OnlyVerify` parameter: Verify hash without computing additional algorithms
   Example: `.\VeriHash.ps1 file.exe -Hash ABC123 -OnlyVerify`
- ✨ Smart sidecar file handling: Automatically detects and verifies sidecar files
   Now intelligently handles `.sha2_256`, `.sha2`, and `.md5` files
- ✨ Flexible hashing workflow: Users have full control over which algorithms run

 BUG FIXES:

- 🐛 Fixed double-hashing bug (SHA256 was computed twice in some scenarios)
- 🐛 Removed duplicate -SendTo logic (was defined twice)
- 🐛 Clipboard check now skipped when -Hash is explicitly provided (performance)
- 🐛 Fixed inconsistent signature labels across platforms
- 🐛 Removed unused variables: $computedMatch, $backupPath, $IsInteractive

 CODE QUALITY:

- 📝 All functions renamed to use PowerShell approved verbs:
   • Verify-InputHash → Test-InputHash
   • Compute-And-SaveHash → Get-And-SaveHash
   • Run-HashFile → Invoke-HashFile
   • Verify-HashSidecar → Test-HashSidecar
- 📝 Comprehensive help text with detailed examples
- 📝 Cleaner, more maintainable code structure

 BREAKING CHANGES:

- None (internal function names changed, but user-facing behavior is backwards compatible)

 UPGRADE NOTES:

- Default behavior unchanged: Running without parameters still computes SHA256
- New parameters are optional and enhance existing functionality
- All previous command-line usage patterns still work

---

### [v1.1.1]

 Version: 1.1.1 - 2024-04-04

- General improvements and bug fixes
- Enhanced sidecar file handling
- Cross-platform compatibility improvements

### [v1.0.7]

 Version: 1.0.7 - 2024-12-09

- ADD - WEBP VeriHash logo to Readme
- CHANGE - Color of computed hash to Magenta, better stand out from all other text.
- BUG where computed time is missing on .sha2_256 hash verification
- Fix in progress 🚧👷🏼🏗️

---

### [v1.0.6]

 Version: 1.0.6 - 2024-12-08
 Stable version

- Better file path validation
- PowerShell $PROFILE information added (example).
      function verihash {
          & "C:\Users\users\source\repos\VeriHash\VeriHash.ps1" @args
          }

---

### [v1.0.5]

 Version: 1.0.5 - 2024-12-08
 SendTo functionality and icon support

- Implemented functionality, to create shortcut in user right-click, Send To menu. (Windows)
- Added support for icons, using `Icons\VeriHash_256.ico`.
- Enhanced error handling and user feedback during shortcut creation.
- Updated script parameters and documentation for clarity.
- Added parameter explanations and usage details to the script header.
- README.md updated to include `-SendTo` usage and project setup instructions.
- Fix for potential issue with "File names like this.exe"
- Clipboard support for SHA256 hashes in testing.
- Check for VirtualTerminal

---

### [v1.0.4]

 Version: 1.0.4 - 2024-12-08
    Enhancements:
        Skipping digital signature checks for large files.
        Better timing, completion messages, and metadata display.
    Notes:
    - Conditional Check: if it's running on Windows.
    - Error Handling: to handle any unexpected errors gracefully.
    - User Feedback: If not on Windows, inform user signature verification is skipped on the current platform.

---

### [v1.0.3]

 Version: 1.0.3 - 2024-12-07
    - Cleaned up the README.md
    - Skip digital signature check if file is over 1GB.
    - Now prints completion and timing.
    - Adding VeriHash to your PowerShell Profile (Super Handy!)
    - 1.0.1 + 1.02 got the 'a bunch of stuff is fixed' and shoved into 1.0.3 release.

---

### [v1.0.0]

 Version: 1.0.0 - 2024-12-06 🎆🫡
    Initial Release:
        - Core functionality to compute and verify SHA256 file hashes.
        - Supports interactive file selection for non-Windows platforms.
        - Handles file metadata display (size, creation, and modification times).
        - Includes digital signature validation for files.
        - Option to compare computed hash with input hash.
        - Automatic generation of .sha2_256 verification files.

</details>
