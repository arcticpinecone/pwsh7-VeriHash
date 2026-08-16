---
title: Sidecar auto-detect exploration — right-click .sha256 verification
date: 2026-04-19
context: Post-v2.0 ideation — user expected right-clicking .sha256 to verify the companion file
---

# Sidecar Auto-Detect Exploration

## Problem

Right-clicking a `.sha256` sidecar file (without `-Manifest` flag) hashes the sidecar *itself* — returning the SHA256 of a tiny text file. The user's intent is always to verify the companion file using the hash stored in the sidecar.

## Design Decision: Auto-detect hash-extension files

When a single `.sha256`/`.sha512`/`.md5` file is passed (with or without `-Manifest`), VeriHash auto-detects what it is:

1. **Read the file** (non-blank lines only)
2. **1 line → sidecar**: verify companion file against stored hash
3. **Multiple lines → manifest**: verify all entries (existing `Test-VeriHashManifest` path)

### Sidecar companion resolution

When it's a sidecar (1 line), find the companion:
- If the line is GNU format (`hash *filename`) → companion is the filename from the line
- If the line is bare hash → strip the hash extension from sidecar filename (`file.iso.sha256` → `file.iso`)
- Resolve companion relative to the sidecar's directory
- If companion doesn't exist → clear error: "Companion file not found: file.iso"

### Flow in VeriHash.ps1

Current (broken):
```
.sha256 file → no -Manifest → Hash mode → hashes the text file (useless)
```

Proposed:
```
.sha256 file → auto-detect → read file → 1 line → sidecar verify
                                        → N lines → manifest verify
```

This means the check happens in Hash mode (lines 183-189 of VeriHash.ps1), BEFORE `Invoke-VeriHashHotPath`. Insert auto-detect logic there.

### Edge cases

- Empty .sha256 file → error: "Sidecar file is empty"
- Companion doesn't exist → error with clear message
- .sha256 file with 1 GNU-format line → sidecar (not manifest, even though format matches)
- .sha256 file passed WITH -Manifest → still auto-detect (unified behaviour)
