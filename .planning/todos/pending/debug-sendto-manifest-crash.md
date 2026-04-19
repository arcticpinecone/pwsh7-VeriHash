---
title: Debug SendTo manifest multi-file crash
date: 2026-04-19
priority: high
---

# Debug SendTo manifest multi-file crash

## Problem
Right-clicking 10 .ISO files in Windows Explorer → "VeriHash - Manifest" → console window flashes open and closes instantly. Error is invisible — the pause-at-end guard (`Test-VeriHashInteractive`) doesn't fire or fires too late.

## Reproduction steps
1. Install SendTo integration (`.\VeriHash.ps1 -InstallSendTo`)
2. Select multiple files (e.g., 10 .ISO files) in Explorer
3. Right-click → Send to → "VeriHash - Manifest"
4. Observe: single console window flashes and closes

## Investigation hints
- Only one window appears → Explorer passes all files to a single invocation
- The `.lnk` shortcut Arguments: `"$arguments -Manifest"` — file paths are appended by Explorer after these args
- Possible issues: path quoting with spaces, argument binding mismatch, error before try/catch block
- The pause-at-end runs *after* the catch block — if error is thrown during module import or param binding, pause never fires
- Check if `$FilePath` receives all 10 paths correctly or if they're mangled

## Acceptance criteria
- Multi-file SendTo manifest creation works for 10+ files
- Errors are visible (window stays open with pause)
- Manifest is created with all selected files
