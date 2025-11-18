# VeriHash Changelog

## Version History

- Current Feature/Release info is shown first.
- Version Release History contains older release notes.

---

### [v1.2.4] (Current)

 Version: 1.2.4 - 2025-11-17
 Enhanced Testing, Bug Fixes, UX Improvements & Performance Analysis Tools

 NEW FEATURES:

- ✨ **`-Force` parameter**: Auto-update sidecars without prompting when hash mismatches are detected
  - Skips interactive prompt when sidecar exists but has different hash
  - Usage: `.\VeriHash.ps1 file.exe -Force`
  - Ideal for automation scripts and batch processing
- ✨ **`-SkipSignatureCheck` parameter**: Skip digital signature verification for faster execution
  - Digital signature checks consume ~65% of execution time for small files (typically 110ms overhead)
  - Use this flag when speed is critical and signature verification is not needed
  - Usage: `.\VeriHash.ps1 file.exe -SkipSignatureCheck`
  - Ideal for: Batch processing, repeated hashing, automation scripts
  - Note: Always checks signatures regardless of file size unless this flag is used
- 🧠 **Smart signature detection**: Automatically skips signature checks on non-Authenticode files
  - Intelligently detects file types and only checks signatures on Authenticode-compatible files
  - Three categories of files:
    - ✅ **Authenticode-signable** (.exe, .dll, .ps1, .msi, etc.) - Signature is checked
    - ⚪ **Non-Authenticode signable** (.jar, .pdf, .apk, .dmg) - Shows "N/A (non-Authenticode signature format)"
    - ⚪ **Non-signable** (.txt, .jpg, .json, etc.) - Shows "N/A (file type cannot be signed)"
  - Saves ~110ms per file for non-Authenticode files (65% performance improvement)
  - Educational: Informs users when files use other signing methods vs. cannot be signed at all
  - Works automatically - no configuration needed
- 🔍 **Performance profiling tool**: `Profile-VeriHashTiming.ps1` analyzes execution overhead
  - Measures time spent in: Get-Item, file size formatting, datetime operations, signature checks, hashing, file I/O, console output
  - Shows percentage breakdown of where time is spent
  - Helps understand performance characteristics for different file sizes
  - Useful for identifying optimization opportunities
  - Returns structured data for programmatic access (Pester testing)
  - Example: `.\Profile-VeriHashTiming.ps1 -FilePath file.exe -Algorithm SHA256`
- ⏱️ **Millisecond precision in hash time calculations**: Now shows exact timing down to milliseconds
  - Example: `Hash time:    0.123 second(s)  (00 minutes, 00 seconds, 123 ms)` for very fast operations
  - Example: `Hash time:    83.789 second(s)  (01 minutes, 23 seconds, 789 ms)` for longer operations
- 🕐 **ISO8601 UTC timestamps**: Added precise start/end timestamps for timing comparisons
  - Start UTC displayed at beginning of operation
  - End UTC displayed at completion
  - Both use ISO8601 format with milliseconds (e.g., `2025-01-17T14:30:45.123Z`)

 BUG FIXES:

- 🐛 **Fixed confusing "Saved to:" text when sidecar already matched**
  - Now displays "Sidecar path:" when no update was needed
  - Displays "Saved to:" only when sidecar was actually created or updated
  - Makes output clearer about what action was taken
- 🐛 **Fixed cached SidecarMatch bug after user updates sidecar**
  - Previously: After choosing [U]pdate, the comparison would still show warnings
  - Now: `SidecarMatch` correctly returns `true` after successful update
  - Applies to: [U]pdate, [R]ename, and `-Force` auto-update scenarios
  - Result: No more confusing "file differs from sidecar" warnings after you just updated it
- 🐛 **Fixed cached SidecarHash displaying old hash after update**
  - `SidecarHash` property now contains the NEW hash value after update
  - Previously showed stale old hash even though file was updated on disk
  - Ensures comparison matrix displays accurate post-update state
- 🐛 **Removed 1GB signature check limit**
  - Previously: Digital signature checks were automatically skipped for files > 1GB
  - Problem: Large digitally signed files would not have their signatures verified
  - Now: Signature checks are ALWAYS performed regardless of file size (unless `-SkipSignatureCheck` is used)
  - Rationale: User should control when to skip signature checks, not the script
- 🐛 **Removed unused variables** flagged by PSScriptAnalyzer
  - Cleaned up `$currentLocal` and `$totalMs` variables
  - Results in cleaner, more maintainable code

 IMPROVEMENTS:

- ⏱️ **Improved timing accuracy**: Moved `$startTime` initialization to immediately after "Start UTC" display
  - "Total time" now accurately matches Start UTC → End UTC delta
  - Previously: Timing started after metadata display, causing ~125ms discrepancy
  - Now: Wall-clock time is accurately reflected in "Total time" output
  - Example: Start UTC → End UTC: 161ms now matches Total time: 157ms ✓
- 📊 **Enhanced timestamp display**: Dual format for clarity
  - ISO8601 UTC timestamps for precise timing comparisons
  - Human-readable "Completed" date for quick reference
- 📊 **Better performance visibility**: Users can now understand where execution time is spent
  - Digital signature check: ~65% of time for small files (110ms on average)
  - Get-Item (metadata): ~16% (27ms)
  - Hash computation: ~6% (10ms for SHA256 on 1KB file)
  - Everything else: ~13% (formatting, I/O, console output)
- 🔍 **Improved sidecar match messaging**: Now always shows computed hash and timing, even when sidecar matches
  - Clear display: "Computed hash: ABC123..." followed by "Sidecar hash: ABC123..."
  - Match status clearly indicated with visual markers (✅/🚫)
  - Hash time always displayed so user knows file was actually hashed
- ⚠️ **Better sidecar mismatch prompts**: More informative and context-aware
  - Clear explanation of why hashes might differ
  - Enhanced prompt options: `[U]pdate sidecar / [K]eep existing / [R]ename old & create new / [C]ancel`
  - Shows both computed and existing hash for comparison
- 📋 **Clipboard + Sidecar comparison matrix**: Crystal-clear comparison when both exist
  - File hash displayed as source of truth ("This is what the file is RIGHT NOW")
  - Separate comparison section showing clipboard vs. sidecar results
  - Each comparison source (clipboard/sidecar) shows clear match/no-match status
  - Summary statement explains overall verification results

 TESTING IMPROVEMENTS:

- 🧪 **Profile-VeriHashTiming.ps1 test suite**: 17 comprehensive Pester tests
  - Script validation and syntax checks
  - Execution tests for all algorithms (SHA256, MD5, SHA512)
  - Object return validation for programmatic access
  - Measurement accuracy verification
  - Total time calculation validation
  - Performance insights validation (signature check dominance for small files)
  - Sorted output verification
  - Error handling tests
  - Smart testing approach: Returns structured data for Pester while displaying Write-Host for humans
- 🧪 **SkipSignatureCheck parameter tests**: 5 new test cases
  - Verifies signature check is skipped when flag is provided
  - Verifies signature check runs normally when flag is NOT provided
  - Validates hashing accuracy is not affected by skipping signature check
  - Tests parameter combination with other flags
  - Cross-platform compatibility validation
- 🧪 **Smart signature detection tests**: 10 new comprehensive test cases
  - Tests for Authenticode-signable files (.exe, .ps1, .dll)
  - Tests for non-Authenticode signable files (.jar, .pdf, .apk)
  - Tests for non-signable files (.txt, .json, .jpg)
  - Validates correct message display for each category
  - Ensures hashing still works correctly for all file types
- 🧪 **Comprehensive test suite expansion**: Added 42 new test cases total
  - Sidecar update and match detection scenarios (8 tests)
  - Clipboard + Sidecar interaction testing (2 tests)
  - Force parameter behavior validation (2 tests)
  - Regression tests for cached SidecarMatch bug (2 tests)
  - Profile-VeriHashTiming.ps1 tests (17 tests)
  - SkipSignatureCheck tests (5 tests)
  - Smart signature detection tests (10 tests)
  - Help system validation for new parameters
- ✅ **Total test count: 91 tests** (was 59)
  - VeriHash.ps1: 52 tests (was 37)
  - QuickHash.ps1: 22 tests
  - Profile-VeriHashTiming.ps1: 17 tests (new)
  - ProfileAndSendTo.Tests.ps1: 22 tests
  - 100% pass rate across all test suites
- ✅ **PSScriptAnalyzer clean**: Zero warnings or errors
- 📊 **Test coverage now includes**:
  - Sidecar match detection when file hasn't changed
  - Auto-update behavior with `-Force` flag
  - User interaction scenarios (Update/Keep/Rename/Cancel)
  - Clipboard and sidecar comparison logic
  - Post-update state validation (no stale cached data)
  - Performance profiler measurement accuracy
  - Timing calculation validation
  - Smart signature detection for all three file categories
  - Correct message display for Authenticode vs non-Authenticode vs non-signable files

 PERFORMANCE INSIGHTS:

- 📈 **Small files (< 1KB)**: Digital signature check was the bottleneck
  - Signature check: 110ms (65%)
  - Hash computation: 10ms (6%)
  - **Smart detection now saves ~110ms for non-Authenticode files automatically**
  - For Authenticode files: Use `-SkipSignatureCheck` when speed is critical
- 📈 **Large files (> 1GB)**: Hash computation dominates
  - Signature check: ~110ms (negligible percentage of total time)
  - Hash computation time grows linearly with file size
  - Smart detection provides minimal benefit for large files (overhead already negligible)
- 📈 **Smart detection benefit**:
  - `.txt`, `.json`, `.jpg` files: ~65% faster (no signature check performed)
  - `.jar`, `.pdf`, `.apk` files: ~65% faster (non-Authenticode format detected)
  - `.exe`, `.dll`, `.ps1` files: No change (signature check still performed as intended)

 UX ENHANCEMENTS:

- 💬 File hash is always labeled as the immutable source of truth
- 💬 Comparisons are clearly separated from file hash computation
- 💬 Not overly verbose - compact but crystal clear
- 💬 Visual hierarchy helps users quickly understand verification results
- 💬 Clearer output text distinguishes between "no change needed" vs "file updated"

 CODE QUALITY:

- 🧹 **Code cleanup**: Removed all unused variables
- 📝 **Better state management**: Fixed cached comparison data after updates
- 🔧 **Consistent behavior**: Update/Rename/Force now all return correct match state
- 🔧 **Smart profiler design**: Returns objects for testing, displays Write-Host for users

 COMPATIBILITY:

- ✅ No breaking changes
- ✅ All existing functionality preserved
- ✅ `-Force` and `-SkipSignatureCheck` parameters are optional and backwards compatible
- ✅ Profiling tool is standalone and does not affect VeriHash.ps1
- ✅ Test suite ensures reliability across all scenarios

---

## Version Release History

### [v1.0.0]

 Version: 1.0.0 - 2024-12-06 🎆🫡
    Initial Release:
        - Core functionality to compute and verify SHA256 file hashes.
        - Supports interactive file selection for non-Windows platforms.
        - Handles file metadata display (size, creation, and modification times).
        - Includes digital signature validation for files.
        - Option to compare computed hash with input hash.
        - Automatic generation of .sha2_256 verification files.

---

### [v1.0.3]

 Version: 1.0.3 - 2024-12-07
    - Cleaned up the README.md
    - Skip digital signature check if file is over 1GB.
    - Now prints completion and timing.
    - Adding VeriHash to your PowerShell Profile (Super Handy!)
    - 1.0.1 + 1.02 got the 'a bunch of stuff is fixed' and shoved into 1.0.3 release.

---

### [v1.0.4]

 Version: 1.0.4 - 2024-12-08
    Enhancements:
        Skipping digital signature checks for large files.
        Better timing, completion messages, and metadata display.

    Notes
    - Conditional Check: if it's running on Windows.

- Error Handling: to handle any unexpected errors gracefully.
- User Feedback: If not on Windows, inform user signature verification is skipped on the current platform.

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

### [v1.0.6]

 Version: 1.0.6 - 2024-12-08
 Stable version

- Better file path validation
- PowerShell $PROFILE information added (example).

      function verihash {
          & "C:\Users\users\source\repos\VeriHash\VeriHash.ps1" @args
          }

---

### [v1.0.7]

 Version: 1.0.7 - 2024-12-09

- ADD - WEBP VeriHash logo to Readme
- CHANGE - Color of computed hash to Magenta, better stand out from all other text.
- BUG where computed time is missing on .sha2_256 hash verification
- Fix in progress 🚧👷🏼🏗️

---

### [v1.1.1]

 Version: 1.1.1 - 2024-04-04

- General improvements and bug fixes
- Enhanced sidecar file handling
- Cross-platform compatibility improvements

---

### [v1.2.0] 🎉

 Version: 1.2.0 - 2025-01-16
 Major Feature Release & Code Quality Improvements

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

### [v1.2.1]

 Version: 1.2.1 - 2025-01-16
 File Extension Standardization & UX Improvements

 BREAKING CHANGES:

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

### [v1.2.2]

 Version: 1.2.2 - 2025-01-16
 Testing & Quality Improvements

 NEW FEATURES:

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

 BUG FIXES:

- 🐛 **PowerShell 7 Compatibility**: Fixed deprecated `-Encoding Byte` parameter in QuickHash.ps1
  - Changed to `-AsByteStream -Raw` for PowerShell 7+ compatibility
  - QuickHash.ps1 line 19: File reading now uses modern cmdlet parameters
  - Resolves errors when running on PowerShell 7+

 CODE QUALITY:

- ✅ **PSScriptAnalyzer Validation**: QuickHash.ps1 passes all PSScriptAnalyzer rules
- ✅ **100% Test Pass Rate**: All 22 Pester tests passing
- 📊 **Test Coverage**: Comprehensive coverage of all QuickHash functionality
  - File hashing (5 tests)
  - String hashing (7 tests)
  - Algorithm validation (4 tests)
  - Error handling (1 test)
  - File vs string logic (2 tests)
  - Script validation (3 tests)

 COMPATIBILITY:

- ✅ Fully compatible with PowerShell 7.0+
- ✅ All existing functionality preserved
- ✅ No breaking changes

 LICENSE CHANGE:

- 📜 **License Update**: Changed from CC-BY-SA-4.0 to AGPL-3.0
  - Reason: AGPL is designed specifically for software and provides stronger copyleft protections
  - Network copyleft: Modified versions served over a network must provide source code
  - Previous versions (v1.2.1 and earlier) remain available under CC-BY-SA-4.0
  - This ensures the project remains free software with proper legal protections for code
  - Patent grant and software-specific terms now properly applied

---

### [v1.2.3]

 Version: 1.2.3 - 2025-11-17
 Documentation & Testing Improvements

 NEW FEATURES:

- 🧪 **Profile & SendTo Integration Tests**: Added comprehensive test suite for user-facing features
  - 22 Pester tests covering PowerShell Profile and Windows SendTo functionality
  - Profile creation, loading, and function availability validation
  - SendTo shortcut creation and properties verification
  - Execution policy and profile access scenario testing
  - Edge cases and troubleshooting validation
  - Test file: `Tests/ProfileAndSendTo.Tests.ps1`
  - 100% test pass rate (22/22 tests passing)

 DOCUMENTATION IMPROVEMENTS:

- 📚 **PowerShell Profile Integration Troubleshooting**: Added comprehensive troubleshooting section
  - Command not found after adding to profile - reload solutions
  - "Cannot find path" error when opening profile - alternative editors
  - "Running scripts is disabled" - execution policy fixes with detailed explanations
  - Profile exists but function doesn't work - step-by-step diagnostics
  - 55+ lines of troubleshooting guidance

- 📚 **Windows SendTo Menu Integration Documentation**: Complete new section (115+ lines)
  - Quick automated setup instructions
  - Detailed explanation of what gets created
  - SendTo vs Profile comparison table
  - Design decision documentation (-NoProfile intentional choice)
  - Comprehensive troubleshooting for 4 common scenarios:
    - Shortcut not appearing after creation
    - Wrong directory issues
    - Missing icon handling
    - Error scenarios with solutions
  - Recreating shortcut instructions

- 📚 **Enhanced Testing Documentation**: Updated Running Tests section
  - Added Test-All.ps1 as recommended quick method
  - Pester version verification instructions
  - Enhanced test coverage documentation
  - ProfileAndSendTo.Tests.ps1 added to test file list
  - Pester 5.x syntax troubleshooting note

 TESTING INFRASTRUCTURE:

- ⚙️ **Test-All.ps1 Coverage**: Automatically runs all tests including new ProfileAndSendTo tests
- 📊 **Test Documentation**: Clear separation of quick method vs individual test methods
- ✅ **Quality Assurance**: All edge cases documented with validation strategies

 COMPATIBILITY:

- ✅ No breaking changes
- ✅ All features backwards compatible
- ✅ Documentation follows project standards
- ✅ 220+ lines of new user-facing guidance

---
