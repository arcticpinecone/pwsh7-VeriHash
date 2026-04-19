---
title: Manifest exploration findings
date: 2026-04-19
context: Post-v2.0 ideation session — right-click manifest workflows
---

# Manifest Exploration Findings

## What works

- **Full manifest verify** (`Test-VeriHashManifest`) is solid — parses sha256sum format, reports pass/fail/missing per entry, returns exit codes with correct precedence (parse-error > mismatch > missing > pass).
- **Manifest creation** (`New-VeriHashManifest`) works from CLI when paths are passed correctly — hashes sequentially, writes atomically, returns structured result.
- **Auto-detect** in the thin CLI correctly routes `.sha256` files to verify and everything else to create.

## What's broken

- **SendTo multi-file manifest creation**: right-clicking 10 .ISO files and choosing "VeriHash - Manifest" causes the console to flash and close instantly. Error is invisible — the pause-at-end guard doesn't fire (error likely occurs before the try/catch or during argument binding). Only one console window appears, so Explorer is passing all files in a single invocation.

## Feature gap: spot-check verification

User wants to right-click a **single file** when a manifest already exists in that directory, and have VeriHash:
1. Auto-detect the existing manifest
2. Look up the entry matching that filename
3. Hash just that one file and compare
4. Report pass/fail for that single entry

This avoids re-hashing all 10 files when you just want to confirm one ISO isn't corrupted.

### UX considerations
- How to distinguish "create new manifest for this one file" vs "spot-check this file against existing manifest"? Auto-detect (manifest present → spot-check) or explicit flag?
- What if multiple manifests exist in the directory? Pick the most recent? Ask?
- What if the file isn't in the manifest? Report "not found in manifest" clearly.
