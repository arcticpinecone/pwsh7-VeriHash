# Testing Patterns

**Analysis Date:** 2026-04-18

## Test Framework

**Runner:**
- **Pester 5.x** (capped at `<= 5.99` in CI: `.github\workflows\ci.yml:42`)
- Install: `Install-Module Pester -Scope CurrentUser`
- No separate config file — configuration is built inline via `New-PesterConfiguration` in `Test-All.ps1` and `.github\workflows\ci.yml`.

**Assertion Library:**
- Built-in Pester `Should` operator: `Should -Be`, `Should -BeOfType`, `Should -Match`, `Should -Not -Throw`, `Should -Not -BeNullOrEmpty`, `Should -HaveCount`, etc.

**Mocking:** Built-in Pester `Mock` command (see `Tests\VeriHash.Tests.ps1:85-97` for `Get-Clipboard` and Linux clipboard tool mocking).

**Run Commands:**
```powershell
# Run everything (tests + lint + profiler)
.\Test-All.ps1

# CI mode (sets exit code)
.\Test-All.ps1 -CI

# Tests only
.\Test-All.ps1 -SkipAnalyzer -SkipProfiler

# Direct Pester invocation
Invoke-Pester -Path "Tests/" -Output Detailed

# Single test file
Invoke-Pester -Path "Tests\VeriHash.Tests.ps1" -Output Detailed
Invoke-Pester -Path "Tests\VeriHash.Config.Tests.ps1" -Output Detailed
Invoke-Pester -Path "Tests\VeriHash.LogUtils.Tests.ps1" -Output Detailed
Invoke-Pester -Path "Tests\VeriHash.Timing.Tests.ps1" -Output Detailed

# Full release build (runs Test-All.ps1 -CI first, fails on non-zero exit)
.\Build.ps1
.\Build.ps1 -Version "1.4.0" -UpdateVersion
```

Standard Pester configuration used by `Test-All.ps1`:
```powershell
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path       = $testsPath       # ./Tests
$pesterConfig.Output.Verbosity = 'Detailed'
$pesterConfig.Run.Exit       = $false           # $true in CI
$testResults = Invoke-Pester -Configuration $pesterConfig
```

## Test File Organization

**Location:** All tests live in the `Tests\` directory at the repo root. One test file per source file:

```
Tests\
├── VeriHash.Tests.ps1           # tests for VeriHash.ps1 (main script)
├── VeriHash.Config.Tests.ps1    # tests for VeriHash.Config.ps1
├── VeriHash.LogUtils.Tests.ps1  # tests for VeriHash.LogUtils.ps1
├── VeriHash.Timing.Tests.ps1    # tests for Profile-VeriHashTiming.ps1
├── QuickHash.Tests.ps1          # tests for QuickHash.ps1
└── VeriHash_1024.ico            # shared test fixture (real file for hashing)
```

**Naming:** `<SourceName>.Tests.ps1` — mirrors the `.ps1` file it exercises.

**Discovery:** `Test-All.ps1` and CI point Pester at the entire `Tests\` directory; no explicit inclusion list.

## Test Structure

**Canonical skeleton** (every test file follows this):
```powershell
BeforeAll {
    # 1. Enable test mode FIRST (prevents polluting production logs)
    $env:VERIHASH_TEST_MODE = '1'

    # 2. Dot-source dependencies in correct order
    . "$PSScriptRoot\..\VeriHash.LogUtils.ps1"
    . "$PSScriptRoot\..\VeriHash.Config.ps1"

    # 3. Set up fixtures using $TestDrive (auto-cleaned by Pester)
    $script:TestOutputDir = Join-Path $TestDrive "MyTests"
    New-Item -ItemType Directory -Path $script:TestOutputDir -Force | Out-Null
}

AfterAll {
    # Clean up every env var the test touched
    Remove-Item Env:\VERIHASH_TEST_MODE -ErrorAction SilentlyContinue
    $env:VERIHASH_LOG_LEVEL = $null
    $env:VERIHASH_VT_APIKEY = $null
    # ...
}

Describe 'Function-Under-Test' {
    Context 'When <condition>' {
        It '<expected behavior>' {
            # Arrange
            $input = '...'

            # Act
            $result = Function-Under-Test -Param $input

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [string]
        }
    }
}
```

**Nesting conventions:**
- `Describe 'FunctionName'` — one block per public function.
- `Context 'When <condition>'` / `'Returns <thing>'` — groups related scenarios.
- `It '<observable behavior>'` — one assertion scope per behavior.
- Bodies use `# Arrange`, `# Act`, `# Assert` comments consistently (see `Tests\VeriHash.Tests.ps1:42-48`).

## Test Environment Isolation

**Non-negotiable:** every `BeforeAll` sets `$env:VERIHASH_TEST_MODE = '1'` and every `AfterAll` cleans it up. This redirects PSFramework logs to `logs\test\` so production JSONL logs are not polluted.

```powershell
BeforeAll { $env:VERIHASH_TEST_MODE = '1' }
AfterAll  { Remove-Item Env:\VERIHASH_TEST_MODE -ErrorAction SilentlyContinue }
```

Config tests also null out every `VERIHASH_*` env var they might set (`Tests\VeriHash.Config.Tests.ps1:15-22`):
```powershell
AfterAll {
    $env:VERIHASH_LOG_LEVEL   = $null
    $env:VERIHASH_LOG_FILE    = $null
    $env:VERIHASH_LOG_CONSOLE = $null
    $env:VERIHASH_VT_APIKEY   = $null
    $env:VERIHASH_VT_ENABLED  = $null
}
```

## Invoking VeriHash.ps1 Inside Tests

Always call the main script with `-NoPause -Force` (and typically `-SkipSignatureCheck`) to suppress interactive prompts and branches:

```powershell
$output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile -SkipSignatureCheck -NoPause -Force *>&1
```

- `-NoPause` disables the interactive "Press any key to continue" at the end.
- `-Force` skips overwrite confirmations for sidecar files.
- `-SkipSignatureCheck` bypasses Authenticode calls (Windows-only API).
- `*>&1` merges all streams so the test can inspect combined output.

For dot-sourcing the main script to import its functions (as `Tests\VeriHash.Tests.ps1:7` does):
```powershell
. "$PSScriptRoot\..\VeriHash.ps1" -FilePath "dummy" -ErrorAction SilentlyContinue 2>$null
```
A dummy file path is passed because the script currently runs at import; errors are suppressed.

## Mocking

**Framework:** Pester's built-in `Mock`.

**Cross-platform clipboard pattern** (from `Tests\VeriHash.Tests.ps1:82-97`):
```powershell
if ($IsWindows) {
    Mock Get-Clipboard { return '5d41402abc4b2a76b9719d911017c592' }
} else {
    if (Get-Command wl-paste -ErrorAction SilentlyContinue) {
        Mock wl-paste { return '5d41402abc4b2a76b9719d911017c592' }
    }
    if (Get-Command xclip -ErrorAction SilentlyContinue) {
        Mock xclip { return '5d41402abc4b2a76b9719d911017c592' }
    }
    if (Get-Command xsel -ErrorAction SilentlyContinue) {
        Mock xsel { return '5d41402abc4b2a76b9719d911017c592' }
    }
}
```

**What to Mock:**
- External commands (`Get-Clipboard`, `wl-paste`, `xclip`, `xsel`).
- Platform-specific OS integration points.

**What NOT to Mock:**
- `Get-FileHash` — real hashing is exercised against the committed fixture `Tests\VeriHash_1024.ico`.
- File I/O — use `$TestDrive` instead; it's auto-cleaned by Pester between runs.
- Platform detection — use `Set-ItResult -Skipped -Because` to skip tests on the wrong OS.

## Fixtures and Factories

**Shared fixture:** `Tests\VeriHash_1024.ico` — a real small binary used for hashing/profiler tests.

**Per-test fixtures:** created under `$TestDrive`, Pester's auto-cleaned temp directory:
```powershell
$script:TestOutputDir = Join-Path $TestDrive "VeriHashTests"
New-Item -ItemType Directory -Path $script:TestOutputDir -Force | Out-Null
```

**Timing test fixtures:** `Tests\VeriHash.Timing.Tests.ps1` supports both auto-generated large files (`$script:LargeFileSizeMB = 500`) and user-provided real files (`$script:UserProvidedTestFiles = @()`), with extension-aware Authenticode signability filtering (`$script:SignableExtensions` at line 40).

**Sample log fixtures** are written inline in `BeforeAll` for `ConvertFrom-VeriHashLog` tests (see `Tests\VeriHash.LogUtils.Tests.ps1:57-68`):
```powershell
$sampleEntries = @(
    '{"Timestamp":"2026-01-17T10:00:00.000Z","Level":"Verbose","Message":"Computing hash","FunctionName":"...","Tags":["Hash","Compute"],"Data":{"Path":"C:\\test.txt"}}'
    ...
)
$sampleEntries | Set-Content $script:SampleLogFile
```

## Platform-Conditional Tests

Use `Set-ItResult -Skipped -Because` inside an `It` block to skip on the wrong OS (never an `if` that silently passes):
```powershell
It 'Returns Windows path on Windows' {
    if (-not ($PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform)) {
        Set-ItResult -Skipped -Because "Not running on Windows"
        return
    }
    $result = Get-VeriHashConfigPath
    $result | Should -Match 'AppData.*VeriHash'
}
```

## Coverage

**Requirements:** None enforced. No coverage gate in CI or `Test-All.ps1`.

**Verbosity:** `Detailed` — all `Describe`/`Context`/`It` names printed for both local and CI runs.

## Test Types

**Unit tests:** dominant style. Dot-source the source module, call functions directly, assert return values.

**Integration-style tests:** a handful invoke `VeriHash.ps1` end-to-end with `& ... -NoPause -Force *>&1` and grep the merged output stream.

**Performance/timing tests:** `Tests\VeriHash.Timing.Tests.ps1` calls `Profile-VeriHashTiming.ps1` and asserts on the returned `[PSCustomObject]` containing `Measurements`, `Total`, and `SortedMeasurements`.

**E2E tests:** not used.

## Common Patterns

**Assert-without-capture (output goes to Write-Host):**
```powershell
{ Test-InputHash -ComputedHash $a -InputHash $b } | Should -Not -Throw
```
Used when the function's "return" is user-facing console output that can't be easily captured.

**Output capture when Write-Host is involved:**
```powershell
$output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile -NoPause -Force *>&1
$output | Should -Match 'SHA256'
```

**Error testing:**
```powershell
{ Get-VeriHashConfig -Path '/nonexistent' } | Should -Throw
```

## Performance Profiler

`Profile-VeriHashTiming.ps1` is a first-class part of the test pipeline:

- Run standalone: `.\Profile-VeriHashTiming.ps1 -FilePath <file> -Algorithm SHA256`
- Run as part of `Test-All.ps1` step `[3/3]` — uses `Tests\VeriHash_1024.ico` by default.
- Sets `$env:VERIHASH_NO_CLEAR = '1'` and `$env:VERIHASH_TEST_MODE = '1'` before invocation so `Clear-Host` is skipped and logs go to test dir.
- Returns a `[PSCustomObject]` with `.Measurements` (hashtable), `.Total` (ms), `.SortedMeasurements` (sorted enumerable) — Pester tests assert against these.
- Measures: `Get-Item`, size formatting, date formatting, `Get-AuthenticodeSignature` (Windows-only, guarded by `$IsWindows`), `Get-FileHash`, sidecar write, console-output overhead.
- `-Quiet` switch suppresses console output and swaps `Write-Host` for `Out-String | Out-Null` so the profiler itself doesn't skew measurements during automated runs.

## TDD Rule (Hard Constraint)

**Never modify tests to make them pass. Modify the code.**

This rule is documented in:
- `AGENTS.md` / `.agents/context/testing.md`
- `.github\copilot-instructions.md` under "TDD rule"

Tests define correct behavior. If a test fails, the fix belongs in the source under test, not in the assertion. A test may only be changed when the intended behavior itself changes (and that change is explicit and documented).

## CI Pipeline

File: `.github\workflows\ci.yml`

**Triggers:** push / PR to `dev` or `main`, when any `**.ps1`, `Tests/**`, or `PSScriptAnalyzerSettings.psd1` changes. Also `workflow_dispatch`.

**Jobs:**
1. `test` — matrix on `ubuntu-latest` and `windows-latest`; installs Pester (`<= 5.99`) and runs the full Pester config with `$config.Run.Exit = $true` so failures fail the job.
2. `lint` — ubuntu-only; runs `Invoke-ScriptAnalyzer` against `VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1` using `PSScriptAnalyzerSettings.psd1`; any issue fails the job.

Concurrency group `ci-${{ github.ref }}` with `cancel-in-progress: true` ensures superseded runs are cancelled.

## Pre-Commit Checklist

Per `.github\copilot-instructions.md`, before committing:
1. `.\Test-All.ps1` — must be green.
2. `.\Build.ps1` — runs `Test-All.ps1 -CI` and fails build on non-zero exit.
3. Update `CHANGELOG.md`.
4. Tag and push.

---

*Testing analysis: 2026-04-18*
