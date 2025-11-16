# VeriHash

![VeriHash Logo](https://github.com/arcticpinecone/pwsh7-VeriHash/blob/main/Icons/VeriHash_256.webp?raw=true)

## A modern, cross-platform PowerShell tool for computing and verifying file hashes

[![Version](https://img.shields.io/badge/version-1.2.1-blue.svg)](https://github.com/arcticpinecone/pwsh7-VeriHash/releases)
[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/license-CC--BY--SA--4.0-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)](https://github.com/arcticpinecone/pwsh7-VeriHash)

---

## 🚀 What's New in v1.2.1

**File extension standardization and UX improvements!**

- 📦 **Standard Extensions**: Now uses `.sha256` and `.sha512` (GNU coreutils compatible)
- ✨ **Multi-File Verification**: Verify checksum files with multiple entries (like `sha256sum -c`)
- 🐛 **Better UX**: Fixed VSCode compatibility, clearer error messages, improved cancellation handling
- ✅ **Backward Compatible**: Still reads old `.sha2_256` and `.sha2` files

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
- [Contributing](#-contributing)
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

---

## 📄 License

### Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)

You are free to:

- **Share**: Copy and redistribute the material
- **Adapt**: Remix, transform, and build upon the material

Under the following terms:

- **Attribution**: Give appropriate credit
- **ShareAlike**: Distribute under the same license

[Full License Text](https://creativecommons.org/licenses/by-sa/4.0/)

---

## 🙏 Acknowledgments

- Built with [PowerShell 7](https://github.com/PowerShell/PowerShell)
- Inspired by the need for cross-platform hash verification tools
- Community feedback and contributions

---

**Made with ❤️ by [arcticpinecone](https://github.com/arcticpinecone)**

[⭐ Star this repo](https://github.com/arcticpinecone/pwsh7-VeriHash) • [🐛 Report Bug](https://github.com/arcticpinecone/pwsh7-VeriHash/issues) • [💡 Request Feature](https://github.com/arcticpinecone/pwsh7-VeriHash/issues)
