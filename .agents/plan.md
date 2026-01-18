# VeriHash Development Plan

Current project state and roadmap for future development.

## What VeriHash Is

**Project Name:** VeriHash

**Problem:** Verifying file integrity through hash computation is cumbersome, platform-specific, and lacks user-friendly tooling for everyday users.

**Solution:** A cross-platform PowerShell tool that makes hash computation and verification fast, visual, and accessible with context menu integration, automatic hash detection, and GNU-compatible sidecar files.

**Users:**

- Security-conscious users verifying downloaded files
- IT professionals checking file integrity
- Developers validating build artifacts
- Anyone who needs to verify file authenticity

---

## Current State (v1.3.0)

**Completed Features:**

- Multi-algorithm hashing (MD5, SHA256, SHA512)
- Smart verification with auto-detection from clipboard
- GNU-compatible sidecar files (.md5, .sha256, .sha512)
- Multi-file checksum verification
- Cross-platform support (Windows, macOS, Linux)
- Interactive GUI file picker (Windows)
- Digital signature validation (Windows)
- Linux KDE/Dolphin context menu integration
- Real-time hash processing speed display (MB/s or GB/s)
- Clipboard detection on Linux (Wayland/X11)

**Test Coverage:** 91 tests across 3 test files, 100% pass rate

---

## MVP Features for Next Release (v1.4.0)

**Core Features (must-have for v1.4.0):**

1. **Logging Service** - Foundational observability infrastructure
   - Structured logging for all operations
   - Configurable log levels (DEBUG, INFO, WARNING, ERROR)
   - File and console output options
   - UTC timestamps in ISO 8601 format

2. **VirusTotal Integration** - Check file hashes against VirusTotal database
   - Post-hash prompt to check VirusTotal
   - API key management (env var + config file)
   - Rate limit tracking (4/min, 500/day)
   - Fallback to browser-based manual search

**Later Features (nice-to-have for v1.5.0+):**

- GNOME (Nautilus) context menu integration
- XFCE (Thunar) context menu integration
- Parallel hash computation for multiple algorithms
- Progress bar for large file hashing
- Recursive directory hashing with manifest
- Color-coded throughput display

---

## Tech Stack

**Language:** PowerShell 7+ (cross-platform)

**Cryptography:** System.Security.Cryptography (.NET)

**Testing:** Pester 5.x

**Code Quality:** PSScriptAnalyzer

**Platforms:** Windows 10/11, macOS 12+, Linux (Debian, Ubuntu, Fedora)

---

## Development Approach

**TDD (Test-Driven Development):**

- Write tests first that define expected behavior
- Implement code to pass tests
- Tests are NOT modified to pass - code is modified to pass tests
- Refactor against passing tests

**Log Everything:**

- Every significant operation logs entry/exit
- External calls (API, file system) log with timing
- Decision points log why a branch was taken
- Errors log with full context (inputs, state, exception)

This approach ensures:

- Agents and humans can troubleshoot effectively
- Operations are traceable and auditable
- Debugging is focused, not guesswork

---

## Next Steps

1. Complete Phase 1: Logging Service (foundation for all future work)
2. All subsequent phases use logging throughout
3. See `.agents/implementation.md` for detailed phase breakdown

---
**Next:** Implementation phases -> `.agents/implementation.md`
