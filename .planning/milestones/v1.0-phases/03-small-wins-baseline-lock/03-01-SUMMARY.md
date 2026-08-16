# Summary: Plan 03-01 — Enable log rotation & flip VT default

## What was built

Two surgical changes closing the final CONCERNS.md audit items:

1. **PSFramework log rotation (LOGC-01):** Added `-LogRotatePath $script:VeriHashLogPath` and `-LogRetentionTime "30d"` to the `Set-PSFLoggingProvider` call in `VeriHash.ps1`. Log files now auto-rotate with 30-day retention via PSFramework's native pruning — no custom cleanup code needed.

2. **VirusTotal default flip (LOGC-03):** Changed `virustotal.enabled` from `$true` to `$false` in `Get-VeriHashDefaultConfig` (`VeriHash.Config.ps1`). Users are no longer misled about unshipped VT integration.

## Files modified

| File | Change |
|------|--------|
| `VeriHash.ps1` | Added `-LogRotatePath` and `-LogRetentionTime "30d"` parameters |
| `VeriHash.Config.ps1` | Flipped `enabled = $true` → `$false` in virustotal defaults |
| `Tests/VeriHash.Tests.ps1` | Added log rotation parameter verification test |
| `Tests/VeriHash.Config.Tests.ps1` | Updated 3 assertions from `$true` → `$false` |

## Commits

1. `feat(LOGC-01): enable PSFramework log rotation with 30-day retention`
2. `fix(LOGC-03): flip VirusTotal enabled default to false`

## Verification

- **Full test suite:** 133 passed, 0 failed, 8 skipped (PSFramework/platform gating)
- **PSScriptAnalyzer:** 0 findings across all 3 production files
- **Pre-commit hooks:** Passed on both commits

## Requirements closed

- **LOGC-01:** PSFramework log rotation configured with 30-day retention
- **LOGC-03:** VirusTotal enabled default set to `$false`
