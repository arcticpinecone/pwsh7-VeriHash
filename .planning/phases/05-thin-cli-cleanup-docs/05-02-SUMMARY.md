# Plan 05-02 Summary: CLI End-to-End Tests

**Status**: ✅ Complete
**Commits**: `31eef5f` (34 CLI tests + Format-VeriHashReport bug fix + ConfigTrim exclusion)

## What was done

### CLI end-to-end test suite
- Created `Tests/VeriHash.Cli.Tests.ps1` (235 lines, 11 Describe blocks, 34 tests)
- Covers all CLI-03 acceptance criteria:
  - CLI param surface: v2 params present, v1 params absent
  - Dispatch routing: correct functions called per code path
  - Centralized pause: Test-VeriHashInteractive exists, no -NoPause in modules
  - Help banner: -Help, --help, and no-args paths
  - E2E single-file hash, clipboard match (plain + prefixed), sidecar match/mismatch
  - E2E multi-file batch with tally format
  - Manifest create and verify (pass, fail, missing-file)
  - Dead code removal: deleted files absent, no PSFramework in source

### Bug fix discovered during testing
- `Format-VeriHashReport.ps1` line 55 used `$SidecarInfo.Status` (nonexistent property)
- Fixed to `$SidecarInfo.Sidecar` — sidecar status was silently blank in reports

### Supporting fixes
- Added `VeriHash.Cli.Tests.ps1` to ConfigTrim exclusion list (legitimate negative assertions)
- Added AfterAll clipboard cleanup to prevent contaminating subsequent batch tests

## Verification
- 34/34 CLI tests pass
- Full suite: 176 pass, 0 fail, 5 skipped (platform-specific)
- All 14 acceptance criteria from 05-02-PLAN.md met

## Deviations
- Format-VeriHashReport bug fix was not in the plan but was discovered during test creation and is directly related to CLI output correctness.
