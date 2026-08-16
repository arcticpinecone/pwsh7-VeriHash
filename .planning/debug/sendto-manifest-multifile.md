---
status: resolved
trigger: "Right-click 10 ISO files in Explorer, Send to VeriHash - Manifest, console flashes and closes instantly"
created: 2026-04-19
updated: 2026-04-19
---

# Debug: sendto-manifest-multifile

## Symptoms

- **expected**: Right-click 10 ISOs → VeriHash - Manifest → manifest file created with hashes for all 10 files
- **actual**: Console window flashes open and closes instantly, no manifest file created
- **errors**: ParameterBindingException — "A positional parameter cannot be found that accepts argument" for 2nd+ file
- **timeline**: Discovered post-v2.0, never worked for multi-file SendTo manifest creation
- **reproduction**: Select multiple files in Windows Explorer → Send to → VeriHash - Manifest

## Current Focus

- hypothesis: CONFIRMED — $FilePath param lacks ValueFromRemainingArguments, only first file binds
- test: Pass 3 files via splatting to VeriHash.ps1 -Manifest
- expecting: ParameterBindingException on 2nd file — confirmed
- next_action: none — resolved
- next_action: Run experiment with pwsh -File to test positional array collection

## Evidence

- 2026-04-19: diagnostic wrapper captured args — all 9 ISOs arrive correctly from Explorer
- 2026-04-19: reproduced with test files — ParameterBindingException on 2nd positional arg
- 2026-04-19: root cause: [Parameter(Position=0)] without ValueFromRemainingArguments
- 2026-04-19: ParameterBindingException fires before try/catch, so pause-at-end never runs

## Resolution

- root_cause: $FilePath had [Parameter(Position=0)] without ValueFromRemainingArguments — only first file bound
- fix: Added ValueFromRemainingArguments to $FilePath parameter attribute in VeriHash.ps1
- verification: 3-file manifest creation succeeds; all 176 tests pass
- files_changed: VeriHash.ps1
