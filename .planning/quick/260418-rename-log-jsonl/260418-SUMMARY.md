---
status: complete
---

# Quick Task 260418: Rename log files from .json to .jsonl

## Changes

1. **VeriHash.ps1** — Changed log file extension from `.json` to `.jsonl` in `Set-PSFLoggingProvider` FilePath. Added `-LogRotateFilter "verihash-*.jsonl"` to scope rotation to VeriHash logs only. Updated comment to say "JSONL format".
2. **VeriHash.LogUtils.ps1** — Updated `ConvertFrom-VeriHashLog` file discovery filter from `verihash-*.json` to `verihash-*.jsonl`.
3. **Tests/VeriHash.LogUtils.Tests.ps1** — Updated sample log file name to `.jsonl`.
4. **.github/copilot-instructions.md** — Updated log path documentation to reflect `.jsonl` extension.

## Rationale

PSFramework's Json FileType with `JsonNoComma` and `JsonNoEmptyFirstLine` produces JSONL (one JSON object per line), not a valid JSON document. The `.json` extension was misleading — tools expecting a JSON array would fail. The `.jsonl` extension accurately describes the format.

## Test Results

- LogUtils tests: 13 passed, 0 failed
- Main VeriHash tests: 57 passed, 0 failed
