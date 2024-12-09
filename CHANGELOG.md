# VeriHash Changelog

## Version History
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
		```$PROFILE
		function verihash {
		    & "C:\Users\users\source\repos\VeriHash\VeriHash.ps1" @args
		    }
		```
---
### [v1.0.7]

	Version: 1.0.7 - 2024-12-09
		- ADD - WEBP VeriHash logo to Readme
		- CHANGE - Color of computed hash to Magenta, better stand out from all other text.
		- BUG where computed time is missing on .sha2_256 hash verification
			- Fix in progress 🚧👷🏼🏗️
