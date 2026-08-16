# VeriHash

![VeriHash Logo](https://github.com/arcticpinecone/pwsh7-VeriHash/blob/main/Icons/VeriHash_256.webp?raw=true)

## Modular file integrity verification for PowerShell 7+

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/arcticpinecone/pwsh7-VeriHash/releases)
[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.md)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)](https://github.com/arcticpinecone/pwsh7-VeriHash)

> **v2.0 — Modular Rewrite** · [See what changed](CHANGELOG.md)

---

## 📋 Table of Contents

- [VeriHash](#verihash)
  - [Modular file integrity verification for PowerShell 7+](#modular-file-integrity-verification-for-powershell-7)
  - [📋 Table of Contents](#-table-of-contents)
  - [✨ Features](#-features)
  - [📋 Requirements](#-requirements)
  - [🚀 Installation](#-installation)
  - [💻 Usage](#-usage)
    - [Hash a single file](#hash-a-single-file)
    - [Hash multiple files](#hash-multiple-files)
    - [Create a manifest](#create-a-manifest)
    - [Verify a manifest](#verify-a-manifest)
    - [Clipboard matching](#clipboard-matching)
    - [Logging](#logging)
    - [All switches](#all-switches)
  - [🖥️ OS Integration](#️-os-integration)
    - [Windows (SendTo)](#windows-sendto)
    - [Linux (KDE Dolphin)](#linux-kde-dolphin)
  - [🏗️ Module Architecture](#️-module-architecture)
  - [⚡ Speed Benchmarks](#-speed-benchmarks)
  - [❓ Why PowerShell 7?](#-why-powershell-7)
  - [⚙️ PowerShell Profile Integration](#️-powershell-profile-integration)
  - [🔒 Privacy](#-privacy)
  - [⚠️ Upgrading from v1](#️-upgrading-from-v1)
  - [🤝 Contributing](#-contributing)
  - [🧪 Running Tests](#-running-tests)
  - [📄 License](#-license)

---

## ✨ Features

- 🔐 **Multiple Hash Algorithms**: SHA256 (default), MD5, SHA1, SHA512
- ⚡ **Parallel Processing**: Hash + Authenticode signature run concurrently for PE files
- 🎯 **Smart Verification**: The clipboard picks the algorithm — paste a vendor's MD5 and VeriHash answers in MD5, plus SHA256 in the same run
- 📁 **Sidecar Files**: GNU-compatible `.sha256` and `.sha512` written; `.sha256`, `.sha512`, `.md5` read
- 📦 **Manifest Mode**: Create and verify `sha256sum`-compatible manifests with atomic writes
- 🔄 **Multi-File Batch**: Process multiple files in one invocation with match/mismatch/missing tally
- 🖥️ **Cross-Platform**: Windows, macOS, Linux
- ✅ **Digital Signatures**: PE-only Authenticode verification (skips non-PE files)
- 📋 **Clipboard Matching**: Automatic hash comparison from clipboard on all platforms
- 🐧 **Linux Integration**: KDE Dolphin context menu support
- 📝 **Plain-Text Logging**: One line per file to `~/.verihash/verihash.log` (opt-in)

---

## 📋 Requirements

- **PowerShell 7.0+** (not Windows PowerShell 5.1)
  - Windows: `winget install Microsoft.PowerShell`
  - Linux: [Install instructions](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux)
  - macOS: `brew install powershell`

No external dependencies. PSFramework is **not** required (removed in v2).

---

## 🚀 Installation

```powershell
# Clone the repository
git clone https://github.com/arcticpinecone/pwsh7-VeriHash.git
cd pwsh7-VeriHash

# Verify it works
.\VeriHash.ps1 -Help
```

No module installation or `Install-Module` needed — run directly from the cloned directory.

---

## 💻 Usage

### Hash a single file

```powershell
.\VeriHash.ps1 file.exe
```

Computes SHA256, checks clipboard for a matching hash, checks for a sibling `.sha256` sidecar file, and displays Authenticode signature status for PE files.

### Hash multiple files

```powershell
.\VeriHash.ps1 file1.exe, file2.dll, file3.zip
```

Processes each file with full hash/sidecar/clipboard/signature checks, then prints a tally: `2/3 matched, 1 mismatch, 0 missing`.

### Create a manifest

```powershell
.\VeriHash.ps1 file1.txt, file2.txt -Manifest
```

Creates a `sha256sum`-compatible manifest in the files' parent directory. Atomic write (no partial manifests on Ctrl+C).

### Verify a manifest

```powershell
.\VeriHash.ps1 manifest.sha256 -Manifest
```

Extension auto-detect: `.sha256`, `.sha512`, `.md5` files are verified. Returns exit code 0 (all pass), 1 (mismatch), 2 (missing), 3 (parse error).

### Clipboard matching

Copy a hash to your clipboard before running VeriHash. Supported formats:

- Plain hex: `71792c028e07b0fdd30f...` (length auto-detects MD5/SHA1/SHA256/SHA512)
- Prefixed: `sha256:71792c028e07b0fdd30f...` (prefix overrides length detection)
- Labelled: `SHA-256: 71792c02 8e07b0fd ...` (vendor pages, spaces and hyphens tolerated)
- Grouped: `71792c02 8e07b0fd d30f4e2a ...` (VeriHash's own output, or `certutil`'s pairs)
- `sha256sum` line: `71792c028e07b0fd... *installer.exe` (the filename is ignored)

**The clipboard chooses the algorithm.** If a vendor published only an MD5, paste it and
VeriHash hashes with MD5 to answer that question — then computes SHA256 as well, so you
still get the digest worth keeping. Only the SHA256 is written to a sidecar; VeriHash never
writes a `.md5` or `.sha1`.

An explicit `-Algorithm` always outranks the clipboard.

### Logging

```powershell
.\VeriHash.ps1 file.exe -Log
# or set environment variable:
$env:VERIHASH_LOG = '1'
```

Appends one line per file to `~/.verihash/verihash.log`.

### All switches

| Switch | Description |
| -------- | ------------- |
| `-Algorithm` | `MD5` \| `SHA1` \| `SHA256` \| `SHA512`. Omit to let the clipboard decide, else SHA256 |
| `-Manifest` | Create or verify a sha256sum manifest |
| `-InstallSendTo` | Install Windows SendTo / Linux context menu |
| `-InstallKDE` | Install KDE Dolphin context menu |
| `-NoPause` | Never pause at exit |
| `-SystemWide` | System-wide install (Linux, requires sudo) |
| `-Log` | Log each file to `~/.verihash/verihash.log` |
| `-Help` | Show help |

---

## 🖥️ OS Integration

### Windows (SendTo)

```powershell
.\VeriHash.ps1 -InstallSendTo
```

Installs two shortcuts in your SendTo folder:

- **VeriHash** — right-click → Send to → VeriHash to hash files
- **VeriHash - Manifest** — right-click → Send to → create/verify manifest

### Linux (KDE Dolphin)

```powershell
# User-level
./VeriHash.ps1 -InstallSendTo

# System-wide (requires sudo)
sudo pwsh -File VeriHash.ps1 -InstallSendTo -SystemWide

# KDE-specific
./VeriHash.ps1 -InstallKDE
```

Creates `.desktop` service menu entries with Compute Hash, Verify Hash, and Manifest Hash actions.

---

## 🏗️ Module Architecture

VeriHash v2 is a modular rewrite. The ~900-line v1 monolith has been replaced with focused modules and a thin CLI dispatcher.

```pwsh
VeriHash.ps1                  ← Thin CLI dispatcher (≤200 lines)
│
├── VeriHash.Core/            ← Core module
│   ├── Get-VeriHashResult      Hash computation (MD5, SHA256, SHA512)
│   ├── Read-ClipboardHash      Clipboard auto-detect (plain hex + algo:hex)
│   ├── Test-VeriHashSidecar    Sidecar file verification
│   ├── Format-VeriHashReport   Formatted console output
│   ├── Write-VeriHashLog       Plain-text logging
│   └── Get-VeriHashPlatform    Cross-platform detection
│
├── VeriHash.HotPath/         ← Performance module
│   ├── Invoke-VeriHashHotPath  Single-file: parallel hash + Authenticode sig
│   ├── Invoke-VeriHashBatch    Multi-file loop with tally
│   └── Get-VeriHashSignature   PE-only Authenticode wrapper
│
├── VeriHash.Manifest/        ← Manifest module
│   ├── New-VeriHashManifest    Create sha256sum-compatible manifests
│   └── Test-VeriHashManifest   Verify manifests (exit codes 0/1/2/3)
│
└── VeriHash.Integrations.ps1 ← OS integration (lazy-loaded)
    ├── Install-WindowsSendTo   Windows SendTo shortcuts
    └── Install-LinuxContextMenu  KDE Dolphin .desktop entries
```

**Design principles:**

- **Modules own logic** — no business logic in the CLI script
- **CLI owns UX** — pause-at-end, help banner, manifest output rendering
- **Lazy loading** — Integrations.ps1 only loaded when `-InstallSendTo` or `-InstallKDE` is used
- **Testable** — modules loaded via `Import-Module`, conditional import in CLI enables mocking

---

## ⚡ Speed Benchmarks

VeriHash uses .NET's optimized hash streams and parallel ThreadJob execution:

| File Size | SHA256 Time | Throughput | Signature |
| ----------- | ------------- | ------------ | ----------- |
| 10 MB | ~50 ms | ~200 MB/s | Parallel |
| 1 GB | ~5 s | ~200 MB/s | Parallel |
| 4 GB | ~20 s | ~200 MB/s | Parallel |

*Throughput depends on disk speed. SSD recommended. Signature check runs concurrently — does not add to wall-clock time for PE files.*

Non-PE files skip signature checking entirely (`Signature: skipped (not a PE file)`).

---

## ❓ Why PowerShell 7?

PowerShell 7 (pwsh) is a modern, cross-platform shell built on .NET. It is **not** the same as Windows PowerShell 5.1 that comes with Windows.

- ✅ Cross-platform (Windows, Linux, macOS)
- ✅ `Start-ThreadJob` for parallel execution
- ✅ Modern .NET hashing APIs
- ✅ Runs alongside Windows PowerShell — no conflicts

Install: `winget install Microsoft.PowerShell` (Windows) or [see instructions](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell).

---

## ⚙️ PowerShell Profile Integration

Add to your `$PROFILE` for quick access:

```powershell
function verihash {
    & "C:\path\to\VeriHash.ps1" @args
}
```

Then use from anywhere:

```powershell
verihash file.exe
verihash *.dll -Manifest
```

See `Microsoft.PowerShell_profile_example.ps1` in the repo for a full example.

---

## 🔒 Privacy

- **No network calls** — hashing is entirely local
- **No telemetry** — nothing is sent anywhere
- **No VirusTotal** — removed in v2 (was never shipped in v1 releases)
- **Optional logging** — only with explicit `-Log` flag or `$env:VERIHASH_LOG=1`
- **Log privacy** — file paths logged without user-home prefix; hash values never logged in full

---

## ⚠️ Upgrading from v1

v2.0 is a clean break. Key changes:

| v1 | v2 |
| ---- | ----- |
| `.\VeriHash.ps1 file.exe -Hash "abc..."` | Copy hash to clipboard, then `.\VeriHash.ps1 file.exe` |
| `-Algorithm MD5,SHA512` | `-Algorithm MD5\|SHA1\|SHA256\|SHA512`, or let the clipboard choose |
| `-OnlyVerify` | Removed — verification is automatic |
| `-SkipSignatureCheck` | Removed — non-PE files auto-skip |
| `-Force` | Removed — sidecar conflicts resolved interactively |
| `-SendTo` | `-InstallSendTo` |
| PSFramework optional | Not used — plain-text logging built in |
| `QuickHash.ps1` | Removed — v2 hot-path replaces its purpose |

See [CHANGELOG.md](CHANGELOG.md) for the complete list.

---

## 🤝 Contributing

1. Fork and clone
2. Create a branch
3. Make changes
4. Run tests: `.\Test-All.ps1`
5. Submit a pull request

Please follow existing code conventions: `[CmdletBinding()]`, `[OutputType()]`, 4-space indentation, `Verb-Noun` function names.

---

## 🧪 Running Tests

```powershell
# Full suite (tests + linter + profiler)
.\Test-All.ps1

# Tests only
.\Test-All.ps1 -SkipAnalyzer -SkipProfiler

# Single test file
Invoke-Pester -Path Tests/VeriHash.Core.Module.Tests.ps1 -Output Detailed
Invoke-Pester -Path Tests/VeriHash.Cli.Tests.ps1 -Output Detailed

# CI mode (exit code on failure)
.\Test-All.ps1 -CI
```

Required: `Install-Module Pester -Scope CurrentUser` and `Install-Module PSScriptAnalyzer -Scope CurrentUser`.

---

## 📄 License

[MIT](LICENSE.md) — © 2024-2026 arcticpinecone
