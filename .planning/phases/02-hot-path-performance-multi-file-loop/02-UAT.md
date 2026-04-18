---
status: complete
phase: 02-hot-path-performance-multi-file-loop
source: 02-01-SUMMARY.md, 02-02-SUMMARY.md, 02-03-SUMMARY.md
started: 2026-04-18T22:10:00Z
updated: 2026-04-18T22:50:36Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

[testing complete]

## Tests

### 1. Module surface lock
expected: |
  Import-Module .\VeriHash.HotPath\VeriHash.HotPath.psd1 -Force succeeds with no errors. (Get-Module VeriHash.HotPath).ExportedFunctions.Keys | Sort-Object lists exactly: Get-VeriHashSignature, Invoke-VeriHashBatch, Invoke-VeriHashHotPath.
result: pass

### 2. Signature on a Microsoft-signed PE (Windows)
expected: |
  Get-VeriHashSignature -Path (Get-Process -Id $PID).Path -IsPE returns an object with Status='valid' and an empty/blank Reason. (The -IsPE switch is required — the wrapper assumes the caller has already run Test-IsPEFile.)
result: pass

### 3. Signature skipped on a non-PE file
expected: |
  Get-VeriHashSignature -Path .\README.md -IsPE:$false returns Status='skipped' with Reason='not a PE file'. No P/Invoke is attempted.
result: pass

### 4. Single-file orchestrator: streaming + result shape
expected: |
  Invoke-VeriHashHotPath -Path .\README.md -Algorithm SHA256 prints a hash report block (algorithm, hash hex, file size, etc.), followed by a separate line containing 'Signature:' (e.g., 'Signature: skipped (not a PE file)'). The returned object includes non-null HashElapsedMs, SigElapsedMs, WallClockMs, IsPE=$false, MatchResult, and Signature fields.
result: pass

### 5. Single-file orchestrator on a signed PE: parallel timing
expected: |
  Invoke-VeriHashHotPath -Path (Get-Process -Id $PID).Path -Algorithm SHA256 prints the hash stanza first, then 'Signature: valid'. The returned object has IsPE=$true, Signature='valid', and WallClockMs noticeably less than HashElapsedMs + SigElapsedMs (parallelism observable).
result: pass

### 6. Multi-file batch: tally line format
expected: |
  Invoke-VeriHashBatch -FilePath .\README.md,.\LICENSE.md,.\CHANGELOG.md -Algorithm SHA256 prints a hash report for each file, and ends with a single tally line in the EXACT format: '3/3 matched, 0 mismatch, 0 missing'.
result: pass

### 7. Multi-file batch: continue-and-tally on bad file
expected: |
  Invoke-VeriHashBatch -FilePath .\does-not-exist-xyz.bin,.\README.md,.\LICENSE.md -Algorithm SHA256 does NOT abort on the missing first file. It still produces output for README.md and LICENSE.md and ends with '2/3 matched, 0 mismatch, 1 missing'.
result: pass
note: |
  User flagged trailing object dump after tally line (default PS formatter rendering the returned VeriHash.BatchResult). Tested behavior (continue-and-tally + correct tally string) is correct — logged as cosmetic gap below for follow-up consideration (custom .format.ps1xml).

### 8. Single-file batch always emits tally
expected: |
  Invoke-VeriHashBatch -FilePath .\README.md -Algorithm SHA256 emits the hash report for README.md AND a tally line: '1/1 matched, 0 mismatch, 0 missing' (tally always emitted, even for one file).
result: pass

### 9. Profile-VeriHashTiming -Strict gate passes
expected: |
  .\Profile-VeriHashTiming.ps1 -FilePath <pwsh.exe> -Strict (against the default fixture or any modest file) completes without throwing. On failure it would throw a message starting with 'Strict perf assertion failed:'.
result: pass
note: |
  Confirmed clean exit — gate computed 1.2*max(2.01,90.41)+100 ≈ 208.5ms, observed total 102.23ms.

### 10. Cross-platform skip (skip if Windows-only host)
expected: |
  ONLY if you have access to a non-Windows pwsh 7 host: Get-VeriHashSignature -Path /any/file returns Status='skipped' with Reason indicating not supported on this platform; no P/Invoke attempted. If you only have Windows, mark this test as 'skip'.
result: pass
note: |
  Verified on WSL2 (Ubuntu) via pwsh -NoProfile invocation against VeriHash.HotPath. Returned Status='skipped' with platform reason as expected.

## Summary

total: 10
passed: 10
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "Invoke-VeriHashBatch interactive output is clean and ends at the tally line"
  status: cosmetic
  reason: "User reported: trailing 'Results -------' object dump appears after tally line when called bare at prompt. This is PowerShell's default formatter rendering the returned VeriHash.BatchResult; functionally correct but visually noisy."
  severity: cosmetic
  test: 7
  root_cause: "VeriHash.BatchResult has no custom .format.ps1xml — default formatter shows all properties including the Results array."
  artifacts:
    - path: "VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1"
      issue: "Returns object to pipeline; no Format.ps1xml provides a tidy default view."
  missing:
    - "Add VeriHash.HotPath/VeriHash.HotPath.format.ps1xml with a default view for VeriHash.BatchResult that hides Results / shows only TallyLine + Tally counts."
    - "Reference the format file from the .psd1 via FormatsToProcess."
  debug_session: ""
