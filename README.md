# VeriHash

![VeriHash Logo](https://github.com/arcticpinecone/pwsh7-VeriHash/blob/main/Icons/VeriHash_256.webp?raw=true)

## A modern, cross-platform PowerShell tool for computing and verifying file hashes

[![Version](https://img.shields.io/badge/version-1.3.0-blue.svg)](https://github.com/arcticpinecone/pwsh7-VeriHash/releases)
[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE.md)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)](https://github.com/arcticpinecone/pwsh7-VeriHash)

---

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

[See full changelog](CHANGELOG.md)

---

## 📋 Table of Contents

- [Features](#-features)
- [Why PowerShell 7?](#-why-powershell-7)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Usage Examples](#-usage-examples)
- [Advanced Usage](#-advanced-usage)
- [Speed Benchmarks](#-speed-benchmarks)
- [PowerShell Profile Integration](#-powershell-profile-integration)
- [Use Cases](#-use-cases)
- [QuickHash](#-quickhash---lightweight-string--file-hasher)
- [Contributing](#-contributing)
- [Running Tests](#-running-tests)
- [License](#-license)

---

## ✨ Features

- 🔐 **Multiple Hash Algorithms**: MD5, SHA256, SHA512
- ⚡ **Blazing Fast**: Optimized for modern SSDs (190+ MB/s)
- 🎯 **Smart Verification**: Auto-detects hash type from clipboard or file
- 📁 **Standard Sidecar Files**: GNU-compatible `.sha256`, `.sha512`, and `.md5` files
- 🔄 **Multi-File Verification**: Verify checksum files with multiple entries
- 🖥️ **Cross-Platform**: Windows, macOS, Linux
- 🎨 **Interactive GUI** (Windows): File picker dialog when no path provided
- ✅ **Digital Signatures**: Validates Authenticode signatures (Windows)
- 🔧 **Flexible Workflows**: Verify-only mode or compute multiple hashes at once

---

## 🌟 Why PowerShell 7?

PowerShell 7 is a modern, open-source, cross-platform shell that brings powerful scripting capabilities to all major operating systems.

**Key Benefits:**

- 🔁 **Cross-Platform**: Runs on Windows, macOS, and Linux
- 🧑‍💻 **Actively Maintained**: Regular updates and new features
- 🛟 **Safe Installation**: Installs alongside Windows PowerShell (no conflicts)
- 🚀 **Better Performance**: Optimized for modern systems

**New to PowerShell 7?**

- **Windows**: Install from [Microsoft Store](https://aka.ms/PSWindows) or [GitHub Releases](https://github.com/PowerShell/PowerShell/releases)
- **macOS/Linux**: Follow the [official installation guide](https://docs.microsoft.com/powershell/)

---

## 📦 Requirements

- **PowerShell 7.0+** (required)
- **Operating System**: Windows 10/11, macOS 12+, or Linux (Debian, Ubuntu, etc.)
- **Disk Space**: < 1 MB

---

## 💾 Installation

### Option 1: GitHub CLI (Recommended)

```bash
gh auth login
gh repo clone arcticpinecone/pwsh7-VeriHash VeriHash
cd VeriHash
```

### Option 2: Git Clone

```bash
git clone https://github.com/arcticpinecone/pwsh7-VeriHash VeriHash
cd VeriHash
```

### Optional: Execution Policy (Windows)

On Windows, you may need to allow script execution:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 🏃 Quick Start

### Compute a SHA256 hash

```powershell
.\VeriHash.ps1 "C:\path\to\file.exe"
```

### Verify with a hash

```powershell
.\VeriHash.ps1 "C:\path\to\file.exe" -Hash "ABC123..."
```

### Verify using sidecar file

```powershell
.\VeriHash.ps1 "C:\path\to\file.exe.sha256"
```

### Interactive mode

```powershell
.\VeriHash.ps1
```

---

## 📚 Usage Examples

### 1. **Compute SHA256 (Default)**

```powershell
.\VeriHash.ps1 "C:\Downloads\app.exe"
```

**Output**: Creates `app.exe.sha256` sidecar file

---

### 2. **Compute Multiple Algorithms**

```powershell
# Compute MD5 and SHA512
.\VeriHash.ps1 "file.zip" -Algorithm MD5,SHA512

# Compute all supported algorithms
.\VeriHash.ps1 "file.zip" -Algorithm All
```

**Output**: Creates `file.zip.md5`, `file.zip.sha256`, and `file.zip.sha512`

---

### 3. **Verify Hash (with automatic SHA256)**

```powershell
.\VeriHash.ps1 "installer.exe" -Hash "A1B2C3D4..."
```

**Behavior**:

1. Detects hash type (MD5/SHA256/SHA512) by length
2. Verifies the provided hash
3. Also computes SHA256 (unless the input was already SHA256)

---

### 4. **Verify Hash ONLY (No Extra Hashing)**

```powershell
.\VeriHash.ps1 "installer.exe" -Hash "A1B2C3D4..." -OnlyVerify
```

**Behavior**: Only verifies the hash, skips additional computations

---

### 5. **Clipboard Detection**

Copy a hash to your clipboard, then:

```powershell
.\VeriHash.ps1 "file.exe"
```

**Behavior**: Automatically detects and verifies the hash from clipboard

**Cross-Platform Support**:

- **Windows**: Built-in clipboard support
- **Linux**: Requires clipboard tool
  - Wayland: `sudo pacman -S wl-clipboard` (or `sudo apt install wl-clipboard`)
  - X11: `sudo pacman -S xclip` (or `sudo apt install xclip`)
- **macOS**: Built-in clipboard support

---

### 6. **Sidecar File Verification**

```powershell
# Verifies the referenced file against stored hash
.\VeriHash.ps1 "document.pdf.sha256"
```

---

### 7. **Multi-File Checksum Verification**

Verify multiple files from a single checksum file (GNU `sha256sum` compatible):

```powershell
# Verify all files listed in checksums.sha256
.\VeriHash.ps1 "checksums.sha256"
```

**Example `checksums.sha256` file**:

```text
E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855  file1.exe
D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2  file2.dll
A1B1C1D1E1F1A1B1C1D1E1F1A1B1C1D1E1F1A1B1C1D1E1F1A1B1C1D1E1F1A1B1  file3.txt
```

**Output**:

```text
Checksum file:      checksums.sha256
Total entries:      3
---
file1.exe - OK ✅
file2.dll - FAILED 🚫
  Expected: D2D2D2D2...
  Got:      C3C3C3C3...
file3.txt - MISSING ⚠️
---
Summary:
  Passed:  1
  Failed:  1
  Missing: 1
```

---

## 🔧 Advanced Usage

### All Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `FilePath` | String | Path to file (or sidecar file) |
| `-Hash` / `-InputHash` | String | Hash to verify against |
| `-Algorithm` | String[] | Algorithms to compute: `MD5`, `SHA256`, `SHA512`, `All` |
| `-OnlyVerify` | Switch | Only verify provided hash (no extra computations) |
| `-Force` | Switch | Auto-update sidecars without prompting when mismatches detected |
| `-SkipSignatureCheck` | Switch | Skip digital signature verification (faster for small files) |
| `-SendTo` | Switch | Install Windows "Send To" menu shortcut |
| `-Help` | Switch | Display detailed help message |

### Examples with Multiple Parameters

```powershell
# Verify MD5 and also compute SHA512
.\VeriHash.ps1 "file.bin" -Hash "D41D8CD98F00B204..." -Algorithm SHA512

# Compute all algorithms for a file
.\VeriHash.ps1 "backup.tar.gz" -Algorithm All

# Verify without extra hashing
.\VeriHash.ps1 "firmware.bin" -Hash "E3B0C44..." -OnlyVerify

# Fast hashing for small files (skip signature check)
.\VeriHash.ps1 "config.json" -SkipSignatureCheck

# Batch processing with Force and SkipSignatureCheck for maximum speed
.\VeriHash.ps1 "data.csv" -Force -SkipSignatureCheck
```

---

## ⚡ Speed Benchmarks

Hash computation speed varies by hardware and file size.

### Tested Performance (SHA256)

| Storage Type | Speed | 1 GB | 8 GB | 10 GB |
|-------------|-------|------|------|-------|
| **SSD** | ~190 MB/s | 5s | 40s | 53s |
| **HDD** | ~93 MB/s | 11s | 88s | 110s |

**Notes:**

- Small files (< 500 MB) hash almost instantly ⚡
- Large files (> 10 GB): Time for a coffee break ☕
- Actual speeds depend on CPU, storage, and system load

---

## 🔗 PowerShell Profile Integration

Add VeriHash to your PowerShell profile for quick access from anywhere.

### Windows Setup

1. **Open your profile**:

   ```powershell
   if (-not (Test-Path $PROFILE)) {
       New-Item -ItemType File -Path $PROFILE -Force
   }
   notepad $PROFILE
   ```

2. **Add the function** (update the path):

   ```powershell
   function verihash {
       & "C:\Users\YourUsername\VeriHash\VeriHash.ps1" @args
   }
   ```

3. **Reload profile**:

   ```powershell
   . $PROFILE
   ```

4. **Use it anywhere**:

   ```powershell
   verihash "C:\file.exe"
   verihash "C:\file.exe" -Hash "ABC123" -OnlyVerify
   verihash -Help
   ```

### macOS/Linux Setup

1. **Check profile path**:

   ```powershell
   $PROFILE
   # Usually: ~/.config/powershell/Microsoft.PowerShell_profile.ps1
   ```

2. **Create directory if needed**:

   ```bash
   mkdir -p $(Split-Path -Parent $PROFILE)
   ```

3. **Edit profile**:

   ```powershell
   if (-not (Test-Path $PROFILE)) {
       New-Item -ItemType File -Path $PROFILE -Force
   }
   nano $PROFILE
   ```

4. **Add function** (update path):

   ```powershell
   function verihash {
       & "/home/username/VeriHash/VeriHash.ps1" @args
   }
   ```

5. **Reload**:

   ```powershell
   . $PROFILE
   ```

### ⚠️ Troubleshooting Profile Integration

#### Problem: `verihash` command not found after adding to profile

**Solution**: PowerShell only loads your profile when it starts. Make sure to reload it:

```powershell
. $PROFILE
```

Or restart your PowerShell terminal completely.

#### Problem: "Cannot find path" error when trying to open profile with notepad

**Solution**: Use a different editor or let PowerShell create and open it:

```powershell
# Windows - Use VSCode instead of Notepad (if installed)
code $PROFILE

# Or use PowerShell ISE
powershell_ise $PROFILE

# Or use Out-File to edit programmatically
Add-Content -Path $PROFILE -Value @'
function verihash {
    & "C:\Path\To\VeriHash\VeriHash.ps1" @args
}
'@
```

#### Problem: "Running scripts is disabled on this system"

**Solution**: Your execution policy is too restrictive. Run this ONCE to allow profile scripts:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Explanation:**

- `RemoteSigned` allows local scripts to run and downloaded scripts to run if they're signed
- `-Scope CurrentUser` applies only to your user account, not system-wide
- This is the recommended setting for PowerShell 7

If you get an error about needing admin rights, try:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

#### Problem: Profile exists but `verihash` still doesn't work

**Diagnostic steps:**

1. Check if profile exists: `Test-Path $PROFILE`
2. Verify profile contains the function: `Get-Content $PROFILE`
3. Manually load profile: `. $PROFILE`
4. Check if function was loaded: `Get-Command verihash`
5. Verify the path in the function points to your VeriHash.ps1 location

---

## 🪟 Windows SendTo Menu Integration

Add VeriHash directly to Windows Explorer's context menu for quick access.

### Quick Setup (Automated)

```powershell
# Navigate to VeriHash directory, then run:
.\VeriHash.ps1 -SendTo
```

That's it! Right-click any file → **Send To** → **VeriHash**

### What Gets Created

The `-SendTo` flag creates a shortcut at:

```text
C:\Users\YourUsername\AppData\Roaming\Microsoft\Windows\SendTo\VeriHash.lnk
```

This shortcut:

- Points to PowerShell 7 (`pwsh.exe`)
- Launches VeriHash with the selected file
- Includes the icon from your VeriHash directory (if available)
- Uses `-ExecutionPolicy Bypass` for reliability

### ⚠️ Important: SendTo vs Profile Differences

| Feature | Profile (`verihash` function) | SendTo Menu |
|---------|-------------------------------|------------|
| **How to use** | Type `verihash filename.exe` in PowerShell | Right-click file → Send To |
| **Requires profile?** | ✅ Yes, must be loaded | ❌ No |
| **Profile aliases available?** | ✅ Yes | ❌ No (`-NoProfile` mode) |
| **Execution policy check** | Uses current policy | Includes `Bypass` flag |
| **Good for** | Terminal users, scripting | File Explorer users |

**Key Point**: SendTo uses `-NoProfile` intentionally. This means:

- SendTo works even if your profile has errors
- SendTo works even if execution policy is restrictive
- BUT you cannot use custom profile functions or aliases through SendTo
- This is a reliability design choice, not a limitation

### Troubleshooting SendTo

#### Problem: SendTo shortcut not appearing after running `-SendTo`

**Solution:**

1. Close and reopen Windows Explorer
2. Navigate to any file
3. Right-click → **Send To** → Look for **VeriHash**

If still not visible:

```powershell
# Verify the shortcut was created
Test-Path "$env:AppData\Microsoft\Windows\SendTo\VeriHash.lnk"

# If it exists, try re-creating it
.\VeriHash.ps1 -SendTo
```

#### Problem: SendTo works but opens in the wrong directory

**Solution**: VeriHash uses the location of selected file automatically. The shortcut's working directory is set to the VeriHash script directory for reference.

#### Problem: SendTo shortcut is missing the VeriHash icon

**Solution**: This happens if the `Icons` folder is missing or moved. The script shows a warning but creates the shortcut anyway with the default icon.

To fix:

1. Ensure `Icons\VeriHash_256.ico` exists in your VeriHash directory
2. Recreate the shortcut: `.\VeriHash.ps1 -SendTo`

#### Problem: SendTo shortcut throws an error when clicked

**Common causes:**

1. VeriHash script path changed → Update the shortcut path
2. PowerShell 7 not installed → Install from Microsoft Store or [GitHub](https://github.com/PowerShell/PowerShell)
3. File is on network drive → Some network shares have permission issues

**Solution:**

```powershell
# Recreate the shortcut (it will use current PowerShell 7 path)
.\VeriHash.ps1 -SendTo

# Verify the shortcut points to correct location
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut("$env:AppData\Microsoft\Windows\SendTo\VeriHash.lnk")
Write-Host "TargetPath: $($shortcut.TargetPath)"
Write-Host "Arguments: $($shortcut.Arguments)"
```

### Recreating the SendTo Shortcut

If you move your VeriHash directory or update PowerShell, recreate the shortcut:

```powershell
cd path\to\VeriHash
.\VeriHash.ps1 -SendTo
```

This will overwrite the old shortcut with updated paths.

---

## 🐧 Linux Context Menu Integration (KDE/Dolphin)

Add VeriHash directly to your Linux file manager's context menu for quick access.

### Quick Setup (Linux Automated)

```bash
# User-level installation (recommended)
pwsh -File VeriHash.ps1 -SendTo

# System-wide installation (requires sudo)
sudo pwsh -File VeriHash.ps1 -SendTo -SystemWide
```

That's it! Right-click any file in Dolphin → **Actions** → **Compute Hash (VeriHash)** or **Verify Hash (VeriHash)**

### Supported Desktop Environments

- ✅ **KDE Plasma (Dolphin)** - Fully supported
- 🚧 **GNOME (Nautilus)** - Planned for future release
- 🚧 **XFCE (Thunar)** - Planned for future release

### What Gets Created (User-Level)

The `-SendTo` flag creates these files:

```text
~/.local/share/kio/servicemenus/verihash.desktop
~/.local/share/icons/hicolor/1024x1024/apps/verihash.png
```

**System-Wide Installation** (with `-SystemWide` flag):

```text
/usr/share/kio/servicemenus/verihash.desktop
/usr/share/icons/hicolor/1024x1024/apps/verihash.png
```

### Using in Dolphin

1. Right-click any file in Dolphin file manager
2. Select **Actions** submenu
3. Choose one of:
   - **Compute Hash (VeriHash)** - Calculate and save hashes
   - **Verify Hash (VeriHash)** - Verify against existing sidecar (auto-enables `-OnlyVerify`)

### Uninstalling

**User-Level:**

```bash
rm ~/.local/share/kio/servicemenus/verihash.desktop
rm ~/.local/share/icons/hicolor/1024x1024/apps/verihash.png
```

**System-Wide:**

```bash
sudo rm /usr/share/kio/servicemenus/verihash.desktop
sudo rm /usr/share/icons/hicolor/1024x1024/apps/verihash.png
```

### Troubleshooting Linux Context Menu

#### Problem: Context menu integration not installing

**Solution:**

1. Verify PowerShell 7 is installed:

   ```bash
   pwsh --version
   ```

2. Install if needed:

   ```bash
   # Arch/Garuda/Manjaro
   sudo pacman -S powershell

   # Ubuntu/Debian
   sudo apt install powershell

   # Fedora
   sudo dnf install powershell
   ```

3. Verify desktop environment is KDE:

   ```bash
   echo $XDG_CURRENT_DESKTOP  # Should show "KDE"
   ```

#### Problem: Context menu entries don't appear in Dolphin

**Solution:**

1. Restart Dolphin:

   ```bash
   killall dolphin
   dolphin &
   ```

2. Verify the `.desktop` file was created:

   ```bash
   cat ~/.local/share/kio/servicemenus/verihash.desktop
   ```

3. Check KDE service menu directory permissions:

   ```bash
   ls -la ~/.local/share/kio/servicemenus/
   ```

#### Problem: "Could not detect desktop environment" error

**Cause**: You're running a desktop environment other than KDE, or environment variables aren't set.

**Solution**:

Check your desktop environment:

```bash
echo "XDG_CURRENT_DESKTOP: $XDG_CURRENT_DESKTOP"
echo "DESKTOP_SESSION: $DESKTOP_SESSION"
```

Current supported environments:

- KDE Plasma (detected via `XDG_CURRENT_DESKTOP=KDE` or `plasma`)

For other desktop environments, please open an issue on GitHub with your `$XDG_CURRENT_DESKTOP` value.

#### Problem: Icons not showing in context menu

**Solution:**

1. Verify icon was copied:

   ```bash
   ls -la ~/.local/share/icons/hicolor/1024x1024/apps/verihash.png
   ```

2. If missing, reinstall:

   ```bash
   pwsh -File VeriHash.ps1 -SendTo
   ```

3. Update icon cache (may help):

   ```bash
   gtk-update-icon-cache ~/.local/share/icons/hicolor/ -f
   ```

### Recreating the Context Menu

If you move your VeriHash directory or update PowerShell, recreate the integration:

```bash
cd /path/to/VeriHash
pwsh -File VeriHash.ps1 -SendTo
```

This will overwrite the old `.desktop` file with updated paths.

#### When to Reinstall

- ✅ **After updating PowerShell** (e.g., switching from pacman to manual install)
- ✅ **After moving VeriHash directory**
- ✅ **If context menu shows errors** about missing pwsh

The installer automatically detects the current `pwsh` location and updates all paths.

---

## 💼 Use Cases

### 🔬 **Software Integrity Verification**

Download software from the internet and verify it matches the vendor's published hash:

```powershell
verihash ".\downloaded-app.exe" -Hash "VENDOR_PROVIDED_HASH"
```

### 🔐 **CI/CD Pipeline Integration**

Ensure build artifacts haven't been tampered with:

```powershell
verihash ".\build\release.zip" -Algorithm All
# Store hashes in version control
```

### 💾 **Backup Integrity Checks**

Generate hashes for backups and verify periodically:

```powershell
# Initial backup
verihash "backup-2025-01.tar.gz"

# Verify later (checks against sidecar file)
verihash "backup-2025-01.tar.gz.sha256"
```

### 📦 **File Distribution**

Distribute files with multiple hash algorithms for maximum compatibility:

```powershell
verihash "software-v1.2.0.zip" -Algorithm All
# Creates .md5, .sha256, and .sha512 files
```

---

## ⚡ QuickHash - Lightweight String & File Hasher

VeriHash also includes **QuickHash.ps1**, a simplified interactive tool for quick hash calculations.

### 🎯 Purpose

QuickHash is designed for fast, interactive hash computation of **both text strings and files** without the complexity of full verification features.

### ✨ Key Features

- **String Hashing**: Hash passwords, API keys, or any text directly
- **File Hashing**: Compute file hashes with minimal setup
- **Interactive Prompts**: User-friendly prompt-based interface
- **Dual Algorithm Support**: MD5 and SHA256
- **Lightweight**: No dependencies, minimal code
- **PowerShell 7 Compatible**: Fully updated for modern PowerShell
- **Tested & Validated**: 22 comprehensive Pester tests ensure reliability

### 💼 QuickHash Use Cases

#### 1. Password/API Key Hashing

```powershell
.\QuickHash.ps1
# Enter: "MySecretPassword123"
# Choose: SHA256
# Result: Instant hash of your string
```

#### 2. Quick File Verification

```powershell
.\QuickHash.ps1
# Enter: "C:\Downloads\file.zip"
# Choose: MD5
# Result: File hash without creating sidecar files
```

#### 3. Development & Testing

```powershell
.\QuickHash.ps1
# Test hash values for unit tests
# Verify string transformations
# Quick file integrity checks
```

### 📝 Example Usage

```powershell
# Run QuickHash
.\QuickHash.ps1

# Prompt 1: "Please enter a string or a file path"
> Hello World

# Prompt 2: "Please choose an algorithm (MD5 or SHA256)"
> SHA256

# Output:
# Starting hash calculation for input: Hello World using algorithm: SHA256
# Input is a string. Computing hash of the string...
# Hash of the string ('Hello World'): B94D27B9934D3E08A52E52D7DA7DABFAC484EFE37A5380EE9088F7ACE2EFCDE9
# Process completed.
```

### 🔄 When to Use Each Tool

**Use QuickHash when:**

- You need a quick hash of a text string
- You want a simple, no-frills file hash
- You prefer interactive prompts over command-line arguments
- You don't need sidecar files or verification features

**Use VeriHash when:**

- You need comprehensive file verification
- You want to create and verify sidecar files
- You need SHA512 support
- You want clipboard detection and automation
- You need digital signature checking
- You require multiple hash algorithms at once

---

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Report Bugs**: [Open an issue](https://github.com/arcticpinecone/pwsh7-VeriHash/issues)
2. **Suggest Features**: [Start a discussion](https://github.com/arcticpinecone/pwsh7-VeriHash/discussions)
3. **Submit PRs**: Fork the repo and submit pull requests

**Development Setup**:

```bash
git clone https://github.com/arcticpinecone/pwsh7-VeriHash
cd VeriHash
# Make changes and test
.\VeriHash.ps1 -Help
```

### 🧪 Running Tests

VeriHash includes comprehensive Pester tests to ensure code quality and reliability.

**Prerequisites**:

```powershell
# Install or update Pester to latest version
Install-Module Pester -Force -SkipPublisherCheck

# Import and verify version
Import-Module Pester -PassThru
# Should show version 5.x or higher
```

**Run all tests**:

**Quick method** (recommended):

```powershell
# Run all tests and code quality checks in one command
.\Test-All.ps1
```

**Individual test methods**:

```powershell
# Import the latest Pester version
Import-Module Pester -Force

# Run VeriHash core functionality tests
Invoke-Pester -Path "Tests\VeriHash.Tests.ps1"

# Run QuickHash tests
Invoke-Pester -Path "Tests\QuickHash.Tests.ps1"

# Run Profile & SendTo integration tests (Windows only)
Invoke-Pester -Path "Tests\ProfileAndSendTo.Tests.ps1"

# Run all tests in the Tests directory
Invoke-Pester -Path "Tests\"
```

**Run PSScriptAnalyzer**:

```powershell
# Analyze VeriHash.ps1
Invoke-ScriptAnalyzer -Path ".\VeriHash.ps1" -Settings PSGallery

# Analyze QuickHash.ps1
Invoke-ScriptAnalyzer -Path ".\QuickHash.ps1" -Settings PSGallery
```

**Test Coverage**:

- **VeriHash.ps1**: 52 tests covering core functionality including:
  - Hash verification and clipboard detection
  - Sidecar file creation and verification
  - Multi-file checksum verification
  - Sidecar update and match detection (8 tests)
  - Clipboard + Sidecar interaction (2 tests)
  - Force parameter behavior (2 tests)
  - SkipSignatureCheck parameter behavior (5 tests)
  - Smart signature detection (10 tests)
  - Regression tests for cached comparison data (2 tests)
  - Help system validation
- **QuickHash.ps1**: 22 tests covering file hashing, string hashing, algorithm validation, and error handling
- **Profile-VeriHashTiming.ps1**: 17 tests covering performance profiling, measurement accuracy, and timing analysis
- **ProfileAndSendTo.Tests.ps1**: 22 tests covering PowerShell Profile and Windows SendTo functionality
- **Total: 91 comprehensive tests** ensuring reliability and performance

**Note on Pester Version**: VeriHash uses Pester 5.x syntax. If you see errors about `BeforeAll` location, update Pester with `Install-Module Pester -Force`.

---

## 📄 License

### GNU Affero General Public License v3.0 (AGPL-3.0)

VeriHash is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

**Key Permissions:**

- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Patent use
- ✅ Private use

**Conditions:**

- 📝 License and copyright notice
- 📝 State changes
- 📝 Disclose source
- 📝 Network use is distribution (AGPL-specific)
- 📝 Same license

**Limitations:**

- ⚠️ Liability
- ⚠️ Warranty

**Important:** If you run a modified version of VeriHash on a network server, you must make the source code available to users of that server.

[Full License Text](LICENSE.md) | [GNU AGPL-3.0 Official](https://www.gnu.org/licenses/agpl-3.0.html)

Author is utilizing the Official unmodified Markdown Version
[GNU AGPL-3.0 Official Markdown](https://www.gnu.org/licenses/agpl-3.0.md)
Retrieved: 2025-11-16

---

## 🙏 Acknowledgments

- Built with [PowerShell 7](https://github.com/PowerShell/PowerShell)
- Inspired by the need for cross-platform hash verification tools
- Community feedback and contributions

---

**Made with ❤️ by [arcticpinecone](https://github.com/arcticpinecone)**

[⭐ Star this repo](https://github.com/arcticpinecone/pwsh7-VeriHash) • [🐛 Report Bug](https://github.com/arcticpinecone/pwsh7-VeriHash/issues) • [💡 Request Feature](https://github.com/arcticpinecone/pwsh7-VeriHash/issues)
