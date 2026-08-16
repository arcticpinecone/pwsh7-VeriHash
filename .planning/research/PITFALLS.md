# Domain Pitfalls

**Domain:** PowerShell 7+ CI/CD, linter expansion, and privacy-compliant logging retrofit
**Project:** VeriHash v1.3.0 → foundation hardening milestone
**Researched:** 2026-04-18

---

## Critical Pitfalls

Mistakes that cause CI failures, broken tests, or silent privacy regressions.

---

### Pitfall 1: Pester `Run.Exit = $false` Silently Swallows Test Failures in GitHub Actions

**What goes wrong:** The current `Test-All.ps1` sets `$pesterConfig.Run.Exit = $false` (line 87) and relies on manual `$testResults.FailedCount` checking plus `exit 1` under the `-CI` flag (line 213). If the GitHub Actions workflow calls `Test-All.ps1 -CI` and any code path before the `exit` throws an unhandled terminating error (e.g., `$ErrorActionPreference = 'Stop'` on line 46 catches a module install failure), the script exits with PowerShell's default exit code 0. The CI step passes despite test failures.

**Why it happens:** Pester 5.x `Run.Exit` controls whether `Invoke-Pester` itself calls `exit`. When `$false`, the caller must propagate the exit code. `Test-All.ps1` does this — but only at the very end. Any terminating error between `Invoke-Pester` and the final `exit 1` skips the exit code logic.

**Consequences:** Green CI badges on broken builds. Merged PRs with failing tests.

**Prevention:**
- Set `$pesterConfig.Run.Exit = $true` **or** use `$pesterConfig.Run.Throw = $true` with a try/catch. Pester docs recommend `Run.Throw` over `Run.Exit` for scripts that wrap Pester.
- Alternatively, in the GitHub Actions workflow step, add `shell: pwsh` plus the `$ErrorActionPreference = 'Stop'` header and check `$LASTEXITCODE` after the `Test-All.ps1 -CI` call:
  ```yaml
  - run: |
      ./Test-All.ps1 -CI
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    shell: pwsh
  ```
- Emit test result XML (NUnit/JUnit) via `$pesterConfig.TestResult.Enabled = $true` and upload as a GitHub Actions artifact or use `dorny/test-reporter` for PR annotations.

**Warning signs:** CI passes locally but `FailedCount -gt 0` shows in the Actions log without the step turning red.

**Detection:** Add a smoke-test PR that intentionally breaks a test; confirm CI goes red.

**Phase:** CI/CD setup (first phase — this must be validated before any other work trusts CI results).

**Confidence:** HIGH — verified against Pester 5.x docs (Context7: `Run.Exit` defaults to `$false`; `Run.Throw` is the preferred alternative).

---

### Pitfall 2: PSScriptAnalyzer Expansion Triggers `PSUseApprovedVerbs` on `Get-And-SaveHash`

**What goes wrong:** When expanding PSScriptAnalyzer from linting only `VeriHash.ps1` to also cover `VeriHash.Config.ps1` and `VeriHash.LogUtils.ps1`, the natural temptation is to also upgrade settings or fix the approach for `VeriHash.ps1`. But the _existing_ `VeriHash.ps1` already contains `Get-And-SaveHash` (line 805), a function with a hyphenated compound verb that violates `PSUseApprovedVerbs`. Today this doesn't fire because it's a script-internal function (not a module export), and the current `PSScriptAnalyzerSettings.psd1` only sets severity to `Error` + `Warning` (which excludes `PSUseApprovedVerbs` if it fires at `Information` level). But if anyone adds `Information` to the severity list or switches to a stricter rule profile during expansion, this function name immediately breaks the lint gate.

**Why it happens:** The settings file applies globally to all files analyzed. Expanding file coverage with the existing settings is safe, but tightening rules simultaneously with expanding file scope creates a combinatorial explosion of new violations.

**Consequences:** Lint gate fails on existing code that was previously passing. Pressure to rename `Get-And-SaveHash` — which is explicitly deferred to the monolith-split milestone (PROJECT.md Out of Scope). Renaming it now cascades into every test that references it.

**Prevention:**
- **Expand file scope first, don't change rules simultaneously.** The existing `PSScriptAnalyzerSettings.psd1` (Error + Warning severity, `PSAvoidUsingWriteHost` and `PSAvoidUsingBrokenHashAlgorithms` excluded) should be used unchanged when adding Config and LogUtils.
- Run PSScriptAnalyzer against Config and LogUtils _locally_ first to inventory all new findings before committing to the CI gate.
- If Config or LogUtils trigger new warnings (e.g., `PSAvoidGlobalVars` for `$script:` variables — they won't, `$script:` is not `$global:`, but verify), add targeted suppressions via `[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute()]` on the specific function, not by weakening global rules.
- The `Get-And-SaveHash` rename belongs in the monolith-split milestone. Do not touch it now.

**Warning signs:** PSScriptAnalyzer suddenly reports 5+ violations after what was supposed to be a simple file expansion.

**Detection:** Run `Invoke-ScriptAnalyzer -Path .\VeriHash.Config.ps1 -Settings .\PSScriptAnalyzerSettings.psd1` and `Invoke-ScriptAnalyzer -Path .\VeriHash.LogUtils.ps1 -Settings .\PSScriptAnalyzerSettings.psd1` locally before any CI changes.

**Phase:** PSScriptAnalyzer expansion phase — validate locally before wiring into CI.

**Confidence:** HIGH — verified the `PSScriptAnalyzerSettings.psd1` includes only `Error` + `Warning` severity, and `PSUseApprovedVerbs` is a `Warning`-level rule (Context7 PSScriptAnalyzer rules list). The risk is real if severity is inadvertently expanded.

---

### Pitfall 3: PSFramework Background Runspace Writes Log Files After Test Cleanup

**What goes wrong:** PSFramework's `Write-PSFMessage` is **asynchronous** — messages are queued and written to log files in a background runspace (confirmed in Context7 PSFramework docs). When tests dot-source `VeriHash.ps1` (which calls `Set-PSFLoggingProvider` with `-Enabled $true`), the logging provider starts a background worker. Test `AfterAll` blocks clean up `$env:VERIHASH_TEST_MODE` but do **not** flush or disable the logging provider. Result: log messages from the final test(s) may land in files _after_ `AfterAll` completes — or even after the next test file starts. On CI runners (which are faster and have different I/O timing), this race condition is more pronounced than on developer machines.

**Why it happens:** PSFramework logging is designed for long-running scripts, not test suites that rapidly dot-source and tear down. The background runspace persists across Pester containers.

**Consequences:**
- Log files from test runs bleed into production log directories (or test log directories from one test file appear during another).
- If future tests assert on log file contents (e.g., to verify privacy truncation worked), they may see stale or missing entries because the background writer hasn't flushed yet.
- Potential Pester error: `Cannot access file because it is being used by another process` when cleanup tries to delete log files the background writer is still holding.

**Prevention:**
- Call `Wait-PSFMessage` in `AfterAll` before any log file assertions or cleanup. This blocks until the PSFramework queue is flushed (documented in PSFramework: `Wait-PSFMessage` waits until the log queue has been flushed).
- Better: Call `Disable-PSFLoggingProvider -Name 'logfile' -InstanceName 'VeriHash'` in test teardown to fully shut down the logging instance for that test file.
- Keep `$env:VERIHASH_TEST_MODE = '1'` which already redirects log output to a `/test` subdirectory — but verify that this actually isolates from other test files' log paths.
- Do **not** add log-content assertions without `Wait-PSFMessage` guarding them first.

**Warning signs:** Intermittent CI failures like "file in use" errors on log cleanup, or test assertions on log content that pass locally but fail in CI.

**Detection:** Add `Wait-PSFMessage -Timeout 10s` in `AfterAll` of `VeriHash.Tests.ps1` and observe whether timing changes.

**Phase:** Logging fixes phase — address before adding any log-content verification tests.

**Confidence:** HIGH — PSFramework docs explicitly state logging is asynchronous via a background runspace.

---

### Pitfall 4: `ConvertTo-SanitizedPath` Not Available in `VeriHash.Config.ps1` Scope

**What goes wrong:** The 10+ unsanitized path violations in `VeriHash.Config.ps1` (lines 161, 162, 215, 228, 321, 322, 331, 348, 394, 404, 423 per CONCERNS.md) log `$configDir` and `$configFile` raw. The fix seems simple — call `ConvertTo-SanitizedPath`. But `ConvertTo-SanitizedPath` is defined in `VeriHash.ps1` (line 108), which dot-sources `VeriHash.Config.ps1` (line 101). The function doesn't exist yet when Config loads.

**Why it happens:** The load order is: `VeriHash.ps1` param block → dot-source `VeriHash.Config.ps1` → dot-source `VeriHash.LogUtils.ps1` → define `ConvertTo-SanitizedPath` (line 108). Config's code runs _before_ the sanitization function exists.

**Consequences:** If you add `ConvertTo-SanitizedPath` calls to `VeriHash.Config.ps1` without relocating the function, you get runtime errors: `The term 'ConvertTo-SanitizedPath' is not recognized`. Since these calls are inside `if ($script:PSFrameworkAvailable)` guards, the error only manifests when PSFramework is installed — silent on CI (where PSFramework is likely absent) but broken for users.

**Prevention:**
- Move `ConvertTo-SanitizedPath` to `VeriHash.LogUtils.ps1` (which is dot-sourced before Config is loaded — wait, no: LogUtils is loaded _after_ Config at line 102). Actually, looking at the load order again:
  ```
  VeriHash.ps1 line 101: . "$PSScriptRoot\VeriHash.Config.ps1"
  VeriHash.ps1 line 102: . "$PSScriptRoot\VeriHash.LogUtils.ps1"
  VeriHash.ps1 line 108: function ConvertTo-SanitizedPath { ... }
  ```
  Neither LogUtils nor Config is loaded after `ConvertTo-SanitizedPath` is defined. The correct fix is either:
  1. **Move `ConvertTo-SanitizedPath` into `VeriHash.LogUtils.ps1`** (it's a logging utility) and move the `VeriHash.LogUtils.ps1` dot-source _before_ `VeriHash.Config.ps1`, or
  2. **Duplicate a minimal inline sanitization** in `VeriHash.Config.ps1`, or
  3. **Don't call it at load time** — defer Config's log calls to use a lazy pattern where the path is sanitized only if the function exists.

  Option 1 is cleanest: `ConvertTo-SanitizedPath` logically belongs in LogUtils alongside `ConvertFrom-SanitizedPath` (its inverse, already in LogUtils at line 44). Reorder the dot-sources so LogUtils loads first.
- **After the move, verify tests still pass.** Config tests dot-source `VeriHash.Config.ps1` directly (line 4 of `VeriHash.Config.Tests.ps1`), so they _won't_ have `ConvertTo-SanitizedPath` available. Either:
  - Config tests also dot-source LogUtils first, or
  - The sanitization calls in Config are guarded: `if (Get-Command ConvertTo-SanitizedPath -ErrorAction SilentlyContinue) { ... } else { $configDir }`

**Warning signs:** Tests pass in CI (no PSFramework), but the tool errors on developer machines that have PSFramework installed.

**Detection:** Run the full test suite with PSFramework installed, not just in CI where it's absent.

**Phase:** Privacy/logging fix phase — must be resolved before any `Write-PSFMessage` changes in Config.

**Confidence:** HIGH — directly verified the load order in `VeriHash.ps1` lines 101-108 and confirmed `ConvertTo-SanitizedPath` is defined after both dot-sources.

---

### Pitfall 5: GitHub Actions Module Installation Timing — NuGet Provider Prompt

**What goes wrong:** The first `Install-Module` call on a fresh GitHub Actions runner may prompt for the NuGet provider installation ("NuGet provider is required to continue. Do you want to install it?"). In a non-interactive CI shell, this either hangs indefinitely or fails with "PowerShellGet requires NuGet provider" — crashing the workflow before tests even run.

**Why it happens:** GitHub-hosted runners (`windows-latest`, `ubuntu-latest`) ship with PowerShell 7 and PowerShellGet, but the NuGet package provider may not be pre-registered or may be at an older version. The prompt is triggered when `Install-Module` first needs to download from PSGallery.

**Consequences:** CI workflow hangs or errors with no test output at all. Looks like an infrastructure failure, not a code problem. Hard to debug because the error message is about NuGet, not Pester.

**Prevention:**
- Install the NuGet provider explicitly before any `Install-Module` call:
  ```yaml
  - name: Bootstrap NuGet + PSGallery
    shell: pwsh
    run: |
      Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
      Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  ```
- Use `-Force` on every `Install-Module` call to suppress all interactive prompts:
  ```yaml
  - name: Install Pester
    shell: pwsh
    run: Install-Module -Name Pester -Force -Scope CurrentUser -SkipPublisherCheck
  ```
- **Do not install PSFramework in CI unless tests require it.** VeriHash's design makes PSFramework optional. Installing it in CI adds ~20s to the workflow and risks the logging provider starting and causing file contention (see Pitfall 3). The `$script:PSFrameworkAvailable` guard means all logging code paths are skipped when it's absent — which is fine for CI.

**Warning signs:** CI workflow fails on the very first run with "unable to install" or "user interaction required" errors. Works on second run because the runner cached the provider from a partially completed first run.

**Detection:** Test the full workflow on a clean runner (not using `actions/cache`) to catch first-run issues.

**Phase:** CI/CD setup (first phase — this is a Day 1 blocker).

**Confidence:** HIGH — PowerShell docs confirm NuGet provider prompt behavior (Context7: "When using PowerShellGet for the first time, you may be prompted to install the NuGet provider").

---

### Pitfall 6: Hash Truncation Breaks Test Assertions That Capture `Write-Host` Output

**What goes wrong:** When fixing the privacy violation at `VeriHash.ps1:839` (truncating `$hashValue` to 16 chars in the `Write-PSFMessage` call), the developer also accidentally truncates the `$hashValue` in the nearby `Write-Host` output (the user-facing console line). Tests like `$output | Should -Match '^[A-F0-9]{64}$'` (VeriHash.Tests.ps1 line 439 pattern) fail because the console output now shows only 16 chars.

**Why it happens:** The fix is to the `-Message` and `-Data` parameters of `Write-PSFMessage`, but the variable `$hashValue` is used _both_ in the `Write-PSFMessage` call (should be truncated) and in subsequent `Write-Host` calls (should remain full). The temptation is to truncate `$hashValue` in-place rather than creating a separate `$truncatedHash` for logging only.

**Consequences:** Tests fail, and the TDD rule ("never modify a test to make it pass") creates pressure to roll back the fix. The truncation must be surgical: only the logging payload changes, never the user-facing output or the return value.

**Prevention:**
- Create a dedicated variable for logging:
  ```powershell
  $logHash = $hashValue.Substring(0, [Math]::Min(16, $hashValue.Length)) + '...'
  ```
  Use `$logHash` in `Write-PSFMessage` and `$hashValue` everywhere else. This is exactly the pattern at line 1063 (`$InputHash` truncation).
- **Never mutate `$hashValue` itself.** It's used in the return object (`Hash = $hashValue` in the `[pscustomobject]`), in sidecar file writes, and in `Write-Host` display.
- Search for _all_ `Write-PSFMessage` calls that include hash values in `-Message` or `-Data` and apply the same `$logHash` pattern. Don't fix only line 839 — grep for `Hash = $hashValue` or `$hashValue` inside `-Data @{` blocks.

**Warning signs:** After the logging fix, `VeriHash.Tests.ps1` tests that assert on output strings (via `*>&1 | Out-String`) start failing with "Expected '…64-char…' but got '…16-char…'".

**Detection:** Run full test suite after every `Write-PSFMessage` change. Never batch logging fixes without intermediate test runs.

**Phase:** Privacy/logging fix phase — each `Write-PSFMessage` change should be a separate commit with a test run.

**Confidence:** HIGH — directly inspected line 839 and confirmed `$hashValue` is shared between logging and return value.

---

## Moderate Pitfalls

---

### Pitfall 7: PSFramework `Set-PSFLoggingProvider` Log Rotation Parameters Use Different Names Than Expected

**What goes wrong:** The PROJECT.md active requirement says "Enable log-file rotation (`-MaxLogFileAge` / `-MaxTotalFolderSize` on the PSFramework provider)." These parameter names don't exist. The actual PSFramework logfile provider properties are `LogRotatePath`, `LogRetentionTime` (default: 30 days), `LogRotateFilter`, and `LogRotateRecurse`.

**Why it happens:** The PROJECT.md requirement was written with assumed parameter names. PSFramework's log rotation is triggered by setting `LogRotatePath` (a separate path to scan for old files), not by parameters on the main `Set-PSFLoggingProvider` call.

**Consequences:** Developer spends time looking for non-existent parameters, then discovers the rotation model is different: you specify a `LogRotatePath` directory and PSFramework deletes files older than `LogRetentionTime`. There is no `MaxTotalFolderSize` concept — rotation is time-based, not size-based.

**Prevention:**
- Use the correct PSFramework properties:
  ```powershell
  Set-PSFLoggingProvider -Name 'logfile' -InstanceName 'VeriHash' `
      -LogRotatePath (Join-Path $script:VeriHashLogPath ".") `
      -LogRetentionTime '30d' `
      -LogRotateFilter 'verihash-*.json' `
      # ... other existing params
  ```
- If size-based rotation is truly needed, implement a custom cleanup function in `VeriHash.LogUtils.ps1` that checks folder size on startup. But time-based rotation (30 days default) is likely sufficient for a developer tool.
- Update the PROJECT.md requirement to reflect the actual parameter names after implementation.

**Warning signs:** `Set-PSFLoggingProvider` silently ignores unknown parameters without error.

**Detection:** Read the PSFramework logfile provider docs before implementing — don't guess parameter names.

**Phase:** Log rotation task (small win phase).

**Confidence:** HIGH — verified against PSFramework logfile provider docs (Context7): the properties are `LogRotatePath`, `LogRetentionTime`, `LogRotateFilter`, `LogRotateRecurse`.

---

### Pitfall 8: GitHub Actions Pester Output Lacks CI Annotations Without `Output.CIFormat`

**What goes wrong:** Pester runs fine in CI, test results are visible in raw log output, but failed tests don't produce GitHub Actions annotations (the red error messages that appear inline on PR diffs and in the Actions summary). The developer assumes Pester auto-detects GitHub Actions — and it does (`Output.CIFormat` defaults to `'Auto'`), but only in Pester 5.3.0+. If the `Install-Module -Name Pester -Force` installs a version < 5.3.0 (unlikely on current PSGallery, but possible with pinned versions), CIFormat is unavailable.

**Why it happens:** Pester 5.3.0 introduced `Output.CIFormat` with `'Auto'` detection. When `GITHUB_ACTIONS` env var is `True` (set automatically by GitHub), Pester uses `GithubActions` format for error output. But if the workflow doesn't explicitly set `$pesterConfig.Output.CIFormat = 'GithubActions'`, and the Pester version is ambiguous, you might get no annotations.

**Consequences:** Test failures are buried in log output. Reviewers don't see inline annotations on the PR. Discovery of failures requires reading raw CI logs.

**Prevention:**
- Explicitly set CIFormat in the Pester configuration:
  ```powershell
  $pesterConfig.Output.CIFormat = 'GithubActions'
  ```
- Also enable test result XML export and use `dorny/test-reporter@v1` or `EnricoMi/publish-unit-test-result-action` for rich PR annotations:
  ```powershell
  $pesterConfig.TestResult.Enabled = $true
  $pesterConfig.TestResult.OutputFormat = 'NUnitXml'
  $pesterConfig.TestResult.OutputPath = 'TestResults.xml'
  ```
- Pin Pester to a known version: `Install-Module -Name Pester -RequiredVersion 5.6.1 -Force` (or latest stable).

**Warning signs:** CI fails but the GitHub Actions UI shows no annotations — just a red step with raw log text.

**Detection:** Intentionally fail a test in a PR and verify annotations appear.

**Phase:** CI/CD setup phase.

**Confidence:** HIGH — Pester docs confirm CIFormat auto-detection of GitHub Actions via `GITHUB_ACTIONS` env var (Context7).

---

### Pitfall 9: Cross-Platform CI Matrix Exposes Path Separator and Clipboard Mock Differences

**What goes wrong:** VeriHash is cross-platform (Windows + Linux). If the CI matrix includes both `windows-latest` and `ubuntu-latest`, tests that hard-code Windows paths (`Should -Match 'AppData.*VeriHash'`) fail on Linux, and clipboard-mocking tests fail because `Get-Clipboard` doesn't exist on Linux — the mock targets `wl-paste`/`xclip`/`xsel` instead, but these may not be installed on the `ubuntu-latest` runner.

**Why it happens:** The existing tests handle this with platform-conditional skipping (`Set-ItResult -Skipped -Because "Not running on Windows"`), which works correctly. The pitfall is: on `ubuntu-latest`, clipboard tools (`wl-paste`, `xclip`, `xsel`) are _not installed_ by default. The test code conditionally mocks only tools that `Get-Command` finds — so on a bare Ubuntu runner with no display server, **no clipboard mock is created**, and clipboard tests silently test nothing. They pass because no assertions fire, not because the code works.

**Consequences:** False sense of coverage. Clipboard-related tests effectively skip on Linux CI without being reported as skipped (because the `if (Get-Command wl-paste ...) { Mock ... }` pattern silently does nothing).

**Prevention:**
- For the initial CI setup, run CI **only on `windows-latest`**. VeriHash's primary user base is Windows. Linux CI is nice-to-have but adds complexity that isn't justified for this milestone.
- If adding Linux CI later, install clipboard tools: `sudo apt-get install -y xclip` and set `DISPLAY=:0` (or use `wl-copy` with a dummy compositor).
- Alternatively, restructure clipboard mocking to use a wrapper function that can be mocked platform-agnostically.

**Warning signs:** CI shows 7+ skipped tests on Linux — if the count changes from the known 7, investigate.

**Detection:** Compare the "skipped" count between Windows and Linux runners. If Linux has significantly more skips, some tests are silently not running.

**Phase:** CI/CD setup — decide single-platform vs. matrix upfront.

**Confidence:** MEDIUM — based on known `ubuntu-latest` runner capabilities (no display server, no clipboard tools). Verified clipboard mock pattern in `VeriHash.Tests.ps1` lines 110-122.

---

### Pitfall 10: `VeriHash.Config.ps1` Calls `Get-Module -ListAvailable` at Dot-Source Time

**What goes wrong:** When `VeriHash.Config.Tests.ps1` dot-sources `VeriHash.Config.ps1` (line 4 of tests), line 28 of Config executes `$script:PSFrameworkAvailable = $null -ne (Get-Module -ListAvailable -Name PSFramework)`. This is a 100-500ms operation that runs _every time the test file loads_. In CI, with no PSFramework installed, `Get-Module -ListAvailable` still scans all module paths before returning `$null`. With 5 test files all loading at different times, this adds 0.5-2.5 seconds of pure waste.

**Why it happens:** The `Get-Module -ListAvailable` check at Config.ps1 line 28 runs at dot-source time (not inside a function). It's the redundant detection identified in CONCERNS.md.

**Consequences:** Slower CI runs. Not a correctness issue, but an annoyance that compounds. The real risk is if PSFramework _is_ installed in CI (see Pitfall 5): the check returns `$true`, logging initializes, and the background runspace starts — causing the file contention issues from Pitfall 3.

**Prevention:**
- The planned fix (eliminate redundant `Get-Module -ListAvailable` call) should be done _before_ CI goes live, not after. This ensures CI runs are fast from day one.
- If deferred, at least don't install PSFramework in CI — the `$script:PSFrameworkAvailable = $false` fast-path avoids most of the cost.

**Warning signs:** CI takes 30+ seconds for simple test runs that finish in 5 seconds locally.

**Detection:** Add timing to the CI workflow: `Measure-Command { ./Test-All.ps1 -CI }`.

**Phase:** Small wins phase (bundle with PSFramework dedup fix).

**Confidence:** HIGH — directly verified line 28 of `VeriHash.Config.ps1` runs at dot-source time.

---

### Pitfall 11: `Test-All.ps1` Analyzer Section Only Accepts a Single Script Path

**What goes wrong:** The PSScriptAnalyzer section in `Test-All.ps1` (line 116) sets `$scriptPath = Join-Path $scriptRoot "VeriHash.ps1"` — a single file path. To expand to three files, you need to loop or pass an array. But `Invoke-ScriptAnalyzer -Path` accepts a path (file or directory), not an array. Passing an array silently uses only the first element, or errors depending on the version.

**Why it happens:** `Invoke-ScriptAnalyzer -Path` is documented to accept a single `[string]` path (not `[string[]]`). To analyze multiple specific files, you must call it multiple times or point it at a directory.

**Consequences:** Developer expands to `$scriptPath = @('VeriHash.ps1', 'VeriHash.Config.ps1', 'VeriHash.LogUtils.ps1')`, passes the array, and only the first file gets analyzed. The other two silently pass.

**Prevention:**
- Loop explicitly:
  ```powershell
  $scriptsToAnalyze = @(
      (Join-Path $scriptRoot 'VeriHash.ps1'),
      (Join-Path $scriptRoot 'VeriHash.Config.ps1'),
      (Join-Path $scriptRoot 'VeriHash.LogUtils.ps1')
  )
  $allResults = @()
  foreach ($script in $scriptsToAnalyze) {
      $allResults += Invoke-ScriptAnalyzer -Path $script -Settings $settingsPath
  }
  ```
- Alternatively, use `-Path $scriptRoot -Recurse` but then add `-ExcludePath` for scripts you don't want linted (e.g., `Test-All.ps1`, `Build.ps1`, `QuickHash.ps1`, `Profile-VeriHashTiming.ps1`). This is more fragile because new files are auto-included.
- The loop approach is safer: explicitly list what gets linted.

**Warning signs:** `Test-All.ps1` reports "0 issues" after adding two new files — suspiciously identical to before.

**Detection:** Temporarily add a known violation to `VeriHash.Config.ps1` (e.g., use an alias like `gci`) and verify the analyzer catches it.

**Phase:** PSScriptAnalyzer expansion phase.

**Confidence:** HIGH — verified `Invoke-ScriptAnalyzer -Path` accepts `[string]` not `[string[]]` via PSScriptAnalyzer docs (Context7).

---

## Minor Pitfalls

---

### Pitfall 12: Pester `$TestDrive` Path Differs Between Windows and Linux

**What goes wrong:** Tests that construct paths using `Join-Path $TestDrive "subdir"` work fine. But if any test string-concatenates paths (`"$TestDrive\subdir"`), the backslash fails on Linux CI.

**Why it happens:** PowerShell's `Join-Path` handles platform separators correctly, but string interpolation uses whatever literal separator is in the code.

**Consequences:** Tests fail on Linux CI with `FileNotFoundException` for paths like `/tmp/abc123\subdir`.

**Prevention:** Always use `Join-Path` for path construction in tests. Grep test files for `"$TestDrive\` and `"$PSScriptRoot\` and replace with `Join-Path`.

**Warning signs:** Tests pass on Windows CI but fail on Linux CI with path-related errors.

**Phase:** CI/CD setup — audit before enabling Linux CI.

**Confidence:** MEDIUM — the existing test files appear to use `Join-Path` consistently, but `"$PSScriptRoot\..\VeriHash.ps1"` on line 7 of `VeriHash.Tests.ps1` uses a backslash. PowerShell handles this on Linux, but it's still technically fragile.

---

### Pitfall 13: `virustotal.enabled = $true` Default Causes Unexpected Assertion Failures After Fix

**What goes wrong:** The fix to flip `virustotal.enabled` to `$false` in `Get-VeriHashDefaultConfig` (PROJECT.md active requirement) breaks the existing test at `VeriHash.Config.Tests.ps1` that asserts `$result.virustotal.enabled | Should -Be $true`. This violates the TDD rule — but the test is asserting the _old_ default, and the requirement is to _change_ the default.

**Why it happens:** The TDD rule says "never modify tests to make them pass." But changing a default value is a deliberate specification change, not a bug fix. The test must be updated to reflect the new spec.

**Consequences:** Confusion about whether updating the test violates the TDD rule. Analysis paralysis.

**Prevention:**
- The TDD rule applies to implementation bugs: "if a test fails, fix the implementation, not the test." A deliberate default change _is_ changing the implementation. The test should be updated to assert `$false` because that's the new correct behavior. This is not a TDD violation — it's a spec change.
- Document the change in the commit message: "Change VT default to disabled; update test to match new default."

**Warning signs:** Developer avoids changing the test, leaves the VT default at `$true`, and the requirement stays unmet.

**Detection:** Code review catches the discrepancy between the requirement and the implementation.

**Phase:** Small wins phase (VT default flip).

**Confidence:** HIGH — directly confirmed the existing test assertion in `VeriHash.Config.Tests.ps1` and the active requirement to change the default.

---

### Pitfall 14: GitHub Actions Runner Disk Space for Timing Tests

**What goes wrong:** `VeriHash.Timing.Tests.ps1` auto-generates a 500MB test file for performance benchmarking. On GitHub Actions runners (which have limited ephemeral disk), this is wasteful and slow. The test takes 30+ seconds just to create the file, adds no value in CI (performance numbers vary wildly between runner instances), and can fail if disk is constrained.

**Why it happens:** The test suite was designed for local development, not CI. The `-SkipProfiler` flag exists on `Test-All.ps1`, but timing _tests_ in `Tests/VeriHash.Timing.Tests.ps1` still run because they're in the `Tests/` directory that Pester scans.

**Consequences:** CI is 30-60 seconds slower. Intermittent failures on constrained runners. Performance numbers are meaningless in CI.

**Prevention:**
- Exclude timing tests from CI runs by using Pester's exclude path:
  ```powershell
  $pesterConfig.Run.Path = '.\Tests'
  $pesterConfig.Filter.ExcludeTag = @('Performance')
  ```
  Then tag the timing tests: add `-Tag 'Performance'` to the `Describe` block in `VeriHash.Timing.Tests.ps1`.
- Or use `$pesterConfig.Run.ExcludePath = @('.\Tests\VeriHash.Timing.Tests.ps1')` directly.
- Keep `-SkipProfiler` on the `Test-All.ps1 -CI` path (it already skips the profiler _run_, but doesn't skip the profiler _tests_).

**Warning signs:** CI takes 2+ minutes for a project with 133 simple tests.

**Detection:** Check CI timing breakdown — if `VeriHash.Timing.Tests.ps1` is >50% of total CI time, exclude it.

**Phase:** CI/CD setup phase.

**Confidence:** HIGH — verified `VeriHash.Timing.Tests.ps1` generates a 500MB file (line `$script:LargeFileSizeMB = 500` in TESTING.md).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Pitfall # | Mitigation |
|---|---|---|---|
| CI/CD setup | Exit code swallowed | 1 | Use `Run.Throw = $true` or verify exit code propagation |
| CI/CD setup | NuGet provider prompt hangs | 5 | Pre-install NuGet provider, set PSGallery trusted |
| CI/CD setup | No PR annotations | 8 | Set `Output.CIFormat = 'GithubActions'`, export NUnit XML |
| CI/CD setup | Timing tests waste CI time | 14 | Exclude via tag or path |
| CI/CD setup | Cross-platform matrix complexity | 9 | Start Windows-only |
| PSScriptAnalyzer expansion | New rules on old code | 2 | Expand scope first, don't change rules |
| PSScriptAnalyzer expansion | `Invoke-ScriptAnalyzer` path handling | 11 | Loop over files explicitly |
| Privacy/logging fixes | `ConvertTo-SanitizedPath` load order | 4 | Move function to LogUtils, reorder dot-sources |
| Privacy/logging fixes | Hash truncation hits console output | 6 | Separate `$logHash` variable |
| Privacy/logging fixes | PSFramework async writes | 3 | `Wait-PSFMessage` in test teardown |
| Small wins | Log rotation parameter names wrong | 7 | Use `LogRotatePath` + `LogRetentionTime` |
| Small wins | VT default test assertion | 13 | Update test — it's a spec change, not TDD violation |
| Small wins | Redundant `Get-Module` check slows CI | 10 | Fix dedup before CI goes live |

---

## Sources

- Pester 5.x configuration docs — Context7 `/pester/docs` (HIGH confidence)
  - `Run.Exit`, `Run.Throw`, `Output.CIFormat`, `TestResult.Enabled`
- PSFramework logging provider docs — Context7 `/websites/psframework` (HIGH confidence)
  - `LogRotatePath`, `LogRetentionTime`, `Wait-PSFMessage`, async background runspace behavior
- PSScriptAnalyzer rules and suppression — Context7 `/powershell/psscriptanalyzer` (HIGH confidence)
  - `SuppressMessageAttribute`, `-Path` parameter type, severity levels
- PowerShell module installation — Context7 `/microsoftdocs/powershell-docs` (HIGH confidence)
  - NuGet provider prompt, `Install-PackageProvider -Force`
- VeriHash codebase — direct inspection (HIGH confidence)
  - Load order (`VeriHash.ps1` lines 101-108), `Get-And-SaveHash` (line 805), `$hashValue` dual use (line 839-845), `VeriHash.Config.ps1` unsanitized paths (lines 161-423), `Test-All.ps1` single-path analyzer (line 116)

---

*Pitfalls audit: 2026-04-18*
