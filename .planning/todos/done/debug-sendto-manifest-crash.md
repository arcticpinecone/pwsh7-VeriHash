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

## Resolution — 2026-08-16

**Fixed by `403350d` (2026-04-19), never closed.** The investigation hint about
argument binding was the right one: `$FilePath` had no
`ValueFromRemainingArguments`, so Explorer appending ten paths after
`... -Manifest` bound only the first and left the rest unbindable, throwing
during parameter binding — before the `try`/`catch` and before the pause-at-end
guard could fire, which is why the window vanished with no visible error.

`VeriHash.ps1` now declares:

```powershell
[Parameter(Position = 0, ValueFromRemainingArguments)]
[string[]]$FilePath,
```

Verified 2026-08-16 by reproducing the SendTo shortcut's exact shape — the
`-Manifest` switch first, ten paths appended after it, filenames containing
spaces:

```text
10 files, SHA256, 135 ms
EXIT CODE: 0
```

The manifest contained all 10 entries in GNU format with the spaced filenames
intact. All three acceptance criteria met.
