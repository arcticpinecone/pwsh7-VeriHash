# Technology Stack: CI/CD for VeriHash

**Project:** VeriHash — Foundation Hardening Milestone (CI/CD + Logging Compliance)
**Researched:** 2026-04-17
**Scope:** GitHub Actions CI/CD stack for a PowerShell 7+ open-source CLI tool

## Recommended Stack

### CI Runtime: GitHub Actions with `ubuntu-latest`

| Technology | Version | Purpose | Why |
|---|---|---|---|
| GitHub Actions | v2 workflow syntax | CI/CD orchestration | Project is already on GitHub; zero-friction, free for public repos |
| `ubuntu-latest` runner | Ubuntu 24.04 (current) | Primary CI runner | **~2× faster cold-start than `windows-latest`**, lower queue times, PowerShell 7.4+ pre-installed via `pwsh`. VeriHash targets PS7+ cross-platform — running CI on Linux proves that claim. |
| `windows-latest` runner | Windows Server 2025 (current) | Secondary matrix runner | VeriHash has Windows-only features (Authenticode, SendTo, GUI file picker). A matrix build catches platform regressions. |
| `shell: pwsh` | (runner-provided) | Workflow step shell | `pwsh` is pre-installed on **all** GitHub-hosted runner OS images (ubuntu, windows, macos). Using `shell: pwsh` ensures identical PowerShell 7 behavior everywhere. It is the default shell on Windows runners already. |

**Confidence: HIGH** — Sourced from official GitHub Actions docs (Context7: `docs.github.com/en/actions/tutorials/build-and-test-code/powershell`). GitHub's own PSScriptAnalyzer example runs on `windows-latest`; their Pester example runs on `ubuntu-latest`. Both work.

**Why `ubuntu-latest` as primary, not `windows-latest`:**
1. **Faster**: Ubuntu runners provision ~30-60s faster and have shorter queue times.
2. **Proves cross-platform**: VeriHash claims PS7+ cross-platform support. If CI runs on Linux and passes, that claim is tested on every commit.
3. **Windows-only tests self-skip**: VeriHash tests already use platform-skip patterns (7 tests skip on non-Windows). This is already handled.
4. **Cost**: For public repos both are free, but Ubuntu minutes cost half of Windows minutes for private repos if VeriHash ever goes private.

### Core Actions

| Action | Version | Purpose | Why |
|---|---|---|---|
| `actions/checkout` | `v5` | Clone repo | Current stable. Uses node24 runtime (requires runner ≥ v2.327.1, which all `*-latest` runners satisfy). |
| `actions/upload-artifact` | `v4` | Upload test results XML | Current stable. Required for `if: always()` test result archival. |

**Confidence: HIGH** — GitHub's own PowerShell tutorial examples now use `actions/checkout@v5` (Context7 verified, `docs.github.com`). `actions/upload-artifact@v4` is used in all current GitHub tutorial examples.

### Testing: Pester 5.x (stay on v5, do not upgrade to v6)

| Technology | Version | Purpose | Why |
|---|---|---|---|
| Pester | `5.x` (latest 5.x, currently 5.7.x) | Test framework | **VeriHash already uses Pester 5.x patterns** (`New-PesterConfiguration`, `Should -Invoke`). Pester 6 drops support for PS 7.0/7.1, removes `Assert-MockCalled`/`Assert-VerifiableMock`, and provides no critical new features VeriHash needs. Upgrading to v6 is risk with zero value for this milestone. |
| `Install-Module -Name Pester -MaximumVersion 5.99 -Force` | — | CI install command | Pin to v5 range. Prevents accidental v6 install which could break existing tests. |

**Confidence: HIGH** — Pester v5→v6 migration guide verified via Context7 (`pester.dev/docs/v6/migrations/v5-to-v6`). Breaking changes are real and non-trivial. The project's 133 tests use v5 patterns correctly.

**How to invoke Pester in CI (configuration object, not command-line):**

```powershell
$config = New-PesterConfiguration
$config.Run.Path = './Tests'
$config.Run.Exit = $true                          # ← Exit with non-zero on failure (replaces -CI flag)
$config.Output.Verbosity = 'Detailed'
$config.Output.CIFormat = 'GithubActions'          # ← Native GH Actions error annotations
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'NUnitXml'       # ← Machine-readable for artifact upload
$config.TestResult.OutputPath = 'testResults.xml'
Invoke-Pester -Configuration $config
```

**Why configuration object, not `-OutputFile` / `-OutputFormat` params:**
- The parameter-based invocation (`Invoke-Pester -OutputFile ...`) uses the **legacy compatibility parameter set** inherited from Pester v4. It works but prints deprecation warnings and doesn't expose v5 features like `CIFormat`.
- `New-PesterConfiguration` is the canonical v5 approach, documented for CI in both Pester's own docs and GitHub's tutorials.
- `$config.Run.Exit = $true` makes Pester set `$LASTEXITCODE` non-zero on test failure — the workflow step automatically fails without needing `exit` logic.
- `$config.Output.CIFormat = 'GithubActions'` produces `::error` annotations that appear inline on PR diffs. `'Auto'` works too (auto-detects GH Actions from `$env:GITHUB_ACTIONS`), but explicit is clearer.

**Confidence: HIGH** — All config options verified via Context7 (`pester.dev/docs/v5/usage/configuration` and `pester.dev/docs/v6/commands/Invoke-Pester`).

### Linting: PSScriptAnalyzer (raw `pwsh` steps, no wrapper action)

| Technology | Version | Purpose | Why |
|---|---|---|---|
| PSScriptAnalyzer | `1.25.x` (latest, March 2026) | Static analysis / linting | v1.25 adds 6 new rules. Already configured in the project via `PSScriptAnalyzerSettings.psd1`. |
| Raw `pwsh` step | — | CI invocation | **Use raw `Invoke-ScriptAnalyzer` in a `pwsh` step, not a pre-built marketplace action.** See rationale below. |

**Why NOT use `devblackops/github-action-psscriptanalyzer` or similar marketplace actions:**
1. **Stale maintainership**: Third-party PSScriptAnalyzer GitHub Actions are thin wrappers around `Invoke-ScriptAnalyzer`. They add a dependency with no value over 3 lines of PowerShell.
2. **Settings file already exists**: VeriHash has `PSScriptAnalyzerSettings.psd1` with customized exclusions. Raw invocation respects this natively; wrapper actions may not pass all settings options.
3. **VeriHash needs multi-file linting**: The milestone requires linting `VeriHash.ps1`, `VeriHash.Config.ps1`, AND `VeriHash.LogUtils.ps1`. A raw step with `-Path` per file (or `-Recurse`) is trivial. Wrapper actions typically take a single path.
4. **Fail-on-warning control**: The existing `Test-All.ps1` treats errors as failures but warnings as non-fatal. In CI, you want to **fail the build on any finding** (Error or Warning). A raw step gives explicit control.

**How to invoke PSScriptAnalyzer in CI and fail the build:**

```powershell
$settings = './PSScriptAnalyzerSettings.psd1'
$scripts = @(
    './VeriHash.ps1'
    './VeriHash.Config.ps1'
    './VeriHash.LogUtils.ps1'
)
$allResults = @()
foreach ($script in $scripts) {
    $allResults += Invoke-ScriptAnalyzer -Path $script -Settings $settings
}
if ($allResults) {
    $allResults | Format-Table -AutoSize
    Write-Error "PSScriptAnalyzer found $($allResults.Count) issue(s)"
    exit 1
}
Write-Host "PSScriptAnalyzer: all scripts clean"
```

**Why fail on warnings too (not just errors):** The existing `PSScriptAnalyzerSettings.psd1` already filters to `Severity = @('Error', 'Warning')` and excludes intentional rules (`PSAvoidUsingWriteHost`, `PSAvoidUsingBrokenHashAlgorithms`). Anything that still triggers is a real issue. Fail the build.

**Confidence: HIGH** — PSScriptAnalyzer v1.25 confirmed via Context7 (`microsoftdocs/powershell-docs`, 2026-March updates). `Invoke-ScriptAnalyzer` API verified via Context7.

### Test Result Reporting

| Technology | Version | Purpose | Why |
|---|---|---|---|
| NUnit XML test results | Pester built-in | Machine-readable test output | Pester 5 natively outputs NUnitXml (the default). JUnit is also supported but NUnit is the Pester ecosystem standard. |
| `actions/upload-artifact@v4` | v4 | Archive test results | Simple, reliable. Upload the XML file as a workflow artifact for post-mortem debugging. |

**What about fancy PR annotations / test report rendering?**

For a project with 133 tests, the cost/benefit of a third-party test reporter action (like `dorny/test-reporter` or `ctrf-io/github-test-reporter`) is poor. Pester's native `CIFormat = 'GithubActions'` already produces inline `::error` annotations on failed tests. The NUnit XML artifact is there for debugging. Skip the extra dependency.

**Confidence: MEDIUM** — The recommendation to skip a test reporter is an opinion based on project size. For larger projects (1000+ tests), a dedicated reporter adds value.

### Module Installation Strategy in CI

**Do NOT rely on pre-installed module versions.** Install explicitly.

```powershell
# Install both modules in a single step to save time
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module -Name Pester -MaximumVersion 5.99 -Force -Scope CurrentUser
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
```

**Why explicit install even though modules may be pre-installed:**
1. **Runner image churn**: GitHub updates runner images weekly. Pre-installed versions change without notice. An explicit install pins your dependency contract.
2. **Version pinning**: `-MaximumVersion 5.99` prevents accidental Pester 6 breakage. Without it, a runner image update could install Pester 6 and break your 133 tests.
3. **Cross-platform consistency**: Ubuntu runners may not have the same pre-installed PS modules as Windows runners. Explicit install eliminates the difference.
4. **Speed**: `Install-Module` with `-Force` is fast (~5-8 seconds for Pester + PSScriptAnalyzer). Not worth optimizing.

**Confidence: HIGH** — This is the pattern used in GitHub's own PowerShell tutorial and Pester's own CI documentation.

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|---|---|---|---|
| Runner OS | `ubuntu-latest` primary + `windows-latest` matrix | `windows-latest` only | Slower, doesn't prove cross-platform claim, costs 2× minutes |
| Pester version | 5.x (pinned) | Pester 6 | Breaking changes, no value for this milestone, risk to 133 tests |
| PSScriptAnalyzer invocation | Raw `pwsh` step | `devblackops/github-action-psscriptanalyzer` | Stale wrapper, doesn't support multi-file + custom settings well |
| Test reporting | Pester `CIFormat` + artifact upload | `dorny/test-reporter@v1` | Extra dependency for 133 tests, Pester native annotations sufficient |
| Workflow approach | Single workflow, matrix OS | Separate workflows per OS | Unnecessary complexity; matrix handles it in one file |
| Test runner | Direct Pester config in workflow | Reuse `Test-All.ps1 -CI` | `Test-All.ps1` includes a profiler step inappropriate for CI; Pester config gives tighter control and native GH annotations |
| PSFramework in CI | Skip (not needed) | Install PSFramework | VeriHash degrades gracefully without it; logging is not being tested in CI initially |

## Recommended Workflow Structure

### Single file: `.github/workflows/ci.yml`

**Triggers:** `push` to `dev` and `main`, `pull_request` to `dev`

**Jobs:**
1. **`lint`** — Install PSScriptAnalyzer, run against all 3 scripts, fail on any finding
2. **`test`** — Matrix `[ubuntu-latest, windows-latest]`, install Pester 5.x, run tests with NUnit XML output, upload artifacts

**Why separate lint and test jobs:**
- Lint is fast (~10s) and OS-independent. Run once on `ubuntu-latest`.
- Tests need matrix for cross-platform. Run on both OSes.
- Separating them gives faster feedback: lint failures surface before waiting for test matrix.

**Why NOT reuse `Test-All.ps1`:**
- `Test-All.ps1` bundles Pester + PSScriptAnalyzer + Performance Profiler into one script.
- The profiler step requires a test icon file and measures execution overhead — irrelevant and noisy in CI.
- `Test-All.ps1` only lints `VeriHash.ps1` — the milestone requires linting all 3 scripts.
- `Test-All.ps1` doesn't produce NUnit XML output or use `CIFormat`.
- Better to invoke Pester and PSScriptAnalyzer directly with CI-appropriate configuration.

## Installation (CI context)

```yaml
# In a workflow step:
- name: Install PowerShell modules
  shell: pwsh
  run: |
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module -Name Pester -MaximumVersion 5.99 -Force -Scope CurrentUser
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
```

## Version Summary

| Component | Version | Pinning Strategy | Confidence |
|---|---|---|---|
| `actions/checkout` | `v5` | Major version tag (auto-patches) | HIGH |
| `actions/upload-artifact` | `v4` | Major version tag | HIGH |
| Pester | `5.x` (latest, ≤5.99) | `-MaximumVersion 5.99` | HIGH |
| PSScriptAnalyzer | `1.25.x` (latest) | No pin needed (stable API) | HIGH |
| PowerShell | `7.4+` (runner-provided) | Runner `*-latest` tracks current stable | HIGH |
| Runner: Ubuntu | `ubuntu-latest` (24.04) | `*-latest` label | HIGH |
| Runner: Windows | `windows-latest` (Server 2025) | `*-latest` label | HIGH |

## Sources

- GitHub Actions PowerShell tutorial: `docs.github.com/en/actions/tutorials/build-and-test-code/powershell` — Context7 verified, HIGH confidence
- GitHub Actions workflow syntax (shell: pwsh): `docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions` — Context7 verified, HIGH confidence
- GitHub Actions runner images: `docs.github.com/en/actions/how-tos/manage-runners/github-hosted-runners` — Context7 verified, HIGH confidence
- `actions/checkout` v5 changelog: `github.com/actions/checkout/blob/main/README.md` — Context7 verified, HIGH confidence
- Pester v5 Configuration: `pester.dev/docs/v5/usage/configuration` — Context7 verified, HIGH confidence
- Pester v6 CI integration: `pester.dev/docs/v6/usage/code-coverage` — Context7 verified, HIGH confidence
- Pester v5→v6 migration: `pester.dev/docs/v6/migrations/v5-to-v6` — Context7 verified, HIGH confidence
- Pester test results: `pester.dev/docs/v5/usage/test-results` — Context7 verified, HIGH confidence
- PSScriptAnalyzer v1.25: `microsoftdocs/powershell-docs` 2026-March updates — Context7 verified, HIGH confidence
- GitHub Actions matrix strategy: `docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations` — Context7 verified, HIGH confidence

---

*Stack research: 2026-04-17*
