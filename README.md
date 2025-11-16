# VeriHash

![VeriHash Logo](https://github.com/arcticpinecone/pwsh7-VeriHash/blob/main/Icons/VeriHash_256.webp?raw=true)

## A modern, cross-platform PowerShell tool for computing and verifying file hashes

[![Version](https://img.shields.io/badge/version-1.2.2-blue.svg)](https://github.com/arcticpinecone/pwsh7-VeriHash/releases)
[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE.md)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)](https://github.com/arcticpinecone/pwsh7-VeriHash)

---

## 🚀 What's New in v1.2.2

**Testing improvements and PowerShell 7 compatibility!**

- ✅ **QuickHash Modernized**: Fixed deprecated `-Encoding Byte` parameter for full PowerShell 7 compatibility
- 🧪 **Comprehensive Testing**: Added 22 Pester tests for QuickHash.ps1 (100% passing)
- 📊 **Quality Assurance**: PSScriptAnalyzer validation ensures code quality
- 🔧 **Test Coverage**: File hashing, string hashing, algorithm validation, error handling, and more

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
# Install Pester (if not already installed)
Install-Module -Name Pester -Force -SkipPublisherCheck
```

**Run all tests**:

```powershell
# Run VeriHash tests
Invoke-Pester -Path "Tests\VeriHash.Tests.ps1" -Output Detailed

# Run QuickHash tests
Invoke-Pester -Path "Tests\QuickHash.Tests.ps1" -Output Detailed

# Run all tests in the Tests directory
Invoke-Pester -Path "Tests\" -Output Detailed
```

**Run PSScriptAnalyzer**:

```powershell
# Analyze VeriHash.ps1
Invoke-ScriptAnalyzer -Path ".\VeriHash.ps1" -Settings PSGallery

# Analyze QuickHash.ps1
Invoke-ScriptAnalyzer -Path ".\QuickHash.ps1" -Settings PSGallery
```

**Test Coverage**:

- **VeriHash.ps1**: Multiple test categories including hash verification, clipboard detection, sidecar files, and multi-file verification
- **QuickHash.ps1**: 22 tests covering file hashing, string hashing, algorithm validation, and error handling

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
