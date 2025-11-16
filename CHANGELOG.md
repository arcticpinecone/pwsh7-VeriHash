# VeriHash Changelog

## Version History

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
