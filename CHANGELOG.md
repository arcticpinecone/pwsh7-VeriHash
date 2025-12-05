# VeriHash Changelog

## Version History

- Current Feature/Release info is shown first: [v1.3.0]
- Version Release History contains older release notes.

---

### [v1.3.0] (Current)

**Version: 1.3.0 - 2025-11-29**
**Linux Desktop Integration & Cross-Platform Enhancements**

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

**Version: 1.2.6 - 2025-12-05**
**Critical Bug Fix - Duration Display Rounding Error**

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

**Version: 1.2.5 - 2025-11-18**
**Critical Bug Fixes & Enhanced Batch Wrapper**

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

**Version: 1.2.3 - 2025-11-17**
**Documentation & Testing Improvements**

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

**Version: 1.2.2 - 2025-01-16**
**Testing & Quality Improvements**

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

**Version: 1.2.1 - 2025-01-16**
**File Extension Standardization & UX Improvements**

**BREAKING CHANGES:**

- 📦 **New file extensions**: Changed from HashTab-style to GNU coreutils standard
  - `.sha2_256` → `.sha256` (SHA256 hashes)
  - `.sha2` → `.sha512` (SHA512 hashes)
  - `.md5` remains unchanged
- ⚠️ **Backward compatibility**: VeriHash still recognizes and verifies old `.sha2_256` and `.sha2` files

**NEW FEATURES:**

- ✨ **Multi-file checksum verification**: Can now verify checksum files containing multiple entries
  - Example: `checksums.sha256` with multiple `hash  filename` lines
  - Compatible with GNU `sha256sum`, `sha512sum`, and `md5sum` output format
  - Shows summary with passed/failed/missing file counts
- ✨ **Enhanced file dialog fallback**: Better handling when GUI dialogs fail (e.g., in VSCode)
  - Auto-falls back to manual path entry if Windows Forms dialog doesn't appear
  - Clear prompts with cancellation option

**BUG FIXES:**

- 🐛 Fixed confusing error message when cancelling file selection dialog
  - Now shows: "Operation cancelled. No file was selected." instead of file path error
- 🐛 Fixed "stuck in loop" behavior when running without parameters
  - Removed duplicate "Press Enter" prompts
- 🐛 Improved VSCode integrated terminal compatibility
  - File dialog failures now gracefully fall back to manual entry

**UX IMPROVEMENTS:**

- 💬 Clearer cancellation messages throughout the tool
- 💬 Better error messages that show the actual invalid path
- 💬 Friendlier prompts with explicit cancellation instructions
- 🎨 Multi-file verification output shows per-file status (OK ✅ / FAILED 🚫 / MISSING ⚠️)

**COMPATIBILITY:**

- ✅ Fully compatible with GNU coreutils checksum file format
- ✅ Can verify files created by `sha256sum`, `sha512sum`, and `md5sum`
- ✅ Supports both text mode (`hash  filename`) and binary mode (`hash *filename`) formats

---

### [v1.2.0] 🎉

**Version: 1.2.0 - 2025-01-16**
**Major Feature Release & Code Quality Improvements**

**NEW FEATURES:**

- ✨ `-Algorithm` parameter: Choose which hash(es) to compute (MD5, SHA256, SHA512, or All)
   Example: `.\VeriHash.ps1 file.exe -Algorithm MD5,SHA512`
- ✨ `-OnlyVerify` parameter: Verify hash without computing additional algorithms
   Example: `.\VeriHash.ps1 file.exe -Hash ABC123 -OnlyVerify`
- ✨ Smart sidecar file handling: Automatically detects and verifies sidecar files
   Now intelligently handles `.sha2_256`, `.sha2`, and `.md5` files
- ✨ Flexible hashing workflow: Users have full control over which algorithms run

**BUG FIXES:**

- 🐛 Fixed double-hashing bug (SHA256 was computed twice in some scenarios)
- 🐛 Removed duplicate -SendTo logic (was defined twice)
- 🐛 Clipboard check now skipped when -Hash is explicitly provided (performance)
- 🐛 Fixed inconsistent signature labels across platforms
- 🐛 Removed unused variables: $computedMatch, $backupPath, $IsInteractive

**CODE QUALITY:**

- 📝 All functions renamed to use PowerShell approved verbs:
   • Verify-InputHash → Test-InputHash
   • Compute-And-SaveHash → Get-And-SaveHash
   • Run-HashFile → Invoke-HashFile
   • Verify-HashSidecar → Test-HashSidecar
- 📝 Comprehensive help text with detailed examples
- 📝 Cleaner, more maintainable code structure

**BREAKING CHANGES:**

- None (internal function names changed, but user-facing behavior is backwards compatible)

**UPGRADE NOTES:**

- Default behavior unchanged: Running without parameters still computes SHA256
- New parameters are optional and enhance existing functionality
- All previous command-line usage patterns still work

---

### [v1.1.1]

**Version: 1.1.1 - 2024-04-04**

- General improvements and bug fixes
- Enhanced sidecar file handling
- Cross-platform compatibility improvements

---

### [v1.0.7]

**Version: 1.0.7 - 2024-12-09**

- ADD - WEBP VeriHash logo to Readme
- CHANGE - Color of computed hash to Magenta, better stand out from all other text.
- BUG where computed time is missing on .sha2_256 hash verification
- Fix in progress 🚧👷🏼🏗️

---

### [v1.0.6]

**Version: 1.0.6 - 2024-12-08**
**Stable version**

- Better file path validation
- PowerShell $PROFILE information added (example).
      function verihash {
          & "C:\Users\users\source\repos\VeriHash\VeriHash.ps1" @args
          }

---

### [v1.0.5]

**Version: 1.0.5 - 2024-12-08**
**SendTo functionality and icon support**

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

**Version: 1.0.4 - 2024-12-08**
**Enhancements:**
- Skipping digital signature checks for large files.
- Better timing, completion messages, and metadata display.

**Notes:**
- Conditional Check: if it's running on Windows.
- Error Handling: to handle any unexpected errors gracefully.
- User Feedback: If not on Windows, inform user signature verification is skipped on the current platform.

---

### [v1.0.3]

**Version: 1.0.3 - 2024-12-07**

- Cleaned up the README.md
- Skip digital signature check if file is over 1GB.
- Now prints completion and timing.
- Adding VeriHash to your PowerShell Profile (Super Handy!)
- 1.0.1 + 1.02 got the 'a bunch of stuff is fixed' and shoved into 1.0.3 release.

---

### [v1.0.0]

**Version: 1.0.0 - 2024-12-06 🎆🫡**
**Initial Release:**

- Core functionality to compute and verify SHA256 file hashes.
- Supports interactive file selection for non-Windows platforms.
- Handles file metadata display (size, creation, and modification times).
- Includes digital signature validation for files.
- Option to compare computed hash with input hash.
- Automatic generation of .sha2_256 verification files.
