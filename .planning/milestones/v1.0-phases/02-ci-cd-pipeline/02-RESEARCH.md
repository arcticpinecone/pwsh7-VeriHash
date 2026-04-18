# Phase 2: CI/CD Pipeline - Research

**Researched:** 2026-04-18
**Domain:** GitHub Actions CI/CD for PowerShell 7 projects (Pester + PSScriptAnalyzer)
**Confidence:** HIGH

## Summary

This phase creates a GitHub Actions CI workflow that runs Pester tests and PSScriptAnalyzer on every push and PR. The domain is well-understood — GitHub Actions has mature PowerShell 7 support, both runners (`ubuntu-latest`, `windows-latest`) ship with `pwsh` pre-installed, and the project's existing test infrastructure (`Test-All.ps1`, `PSScriptAnalyzerSettings.psd1`) provides proven patterns to replicate in CI.

The main work is: (1) create `.github/workflows/ci.yml` with parallel test + lint jobs, (2) update `Test-All.ps1` to lint all 3 `.ps1` files for local consistency. No novel challenges exist — this is standard infrastructure work with well-documented APIs.

**Primary recommendation:** Create a single `ci.yml` with two parallel jobs: `test` (OS matrix: ubuntu + windows, installs Pester 5.x, runs `Invoke-Pester`) and `lint` (single runner, installs PSScriptAnalyzer, runs `Invoke-ScriptAnalyzer` against all 3 files). Use `shell: pwsh` everywhere.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Single workflow file (`ci.yml`) — tests and lint in one file, simpler to maintain
- **D-02:** Triggers on push to `dev` and `main` branches, plus all PRs targeting those branches
- **D-03:** Path filters active — CI only runs when `.ps1` files or `Tests/` directory change (skips README, docs-only edits)
- **D-04:** Parallel jobs within the workflow: a test job (OS matrix) and a lint job (single runner) run concurrently
- **D-05:** OS matrix: `ubuntu-latest` + `windows-latest` only — macOS excluded per PROJECT.md out-of-scope
- **D-06:** PowerShell version: latest `pwsh` only — project requires 7+, no multi-version matrix
- **D-07:** All workflow steps use `shell: pwsh` — no Windows PowerShell 5.x
- **D-08:** CI runs PSScriptAnalyzer directly against all 3 files — not via Test-All.ps1
- **D-09:** CI fails on both Error and Warning severity findings — matches `PSScriptAnalyzerSettings.psd1` configuration
- **D-10:** `Test-All.ps1` is also updated to lint all 3 files locally — keeps local and CI behavior consistent
- **D-11:** Pester pinned to 5.x (`MaximumVersion 5.99`) — prevents Pester 6 auto-install breakage (CICD-04)
- **D-12:** PSScriptAnalyzer installed at latest (not pinned to exact version) — stable module, no breakage risk
- **D-13:** No module caching between runs — fresh install each time; module install is fast (~10-15s) and avoids cache invalidation complexity
- **D-14:** PSFramework is NOT installed in CI — it's optional, tests work without it, keeps CI fast

### Agent's Discretion
- Exact YAML structure and step naming within the workflow
- Whether to use `Install-Module -Force -Scope CurrentUser` or `Install-PSResource`
- Test results upload format (if any — e.g., Pester NUnit XML)
- Workflow concurrency settings (cancel in-progress runs on new push or not)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CICD-01 | GitHub Actions workflow runs Pester tests on every push and PR (`ubuntu-latest` + `windows-latest` matrix) | Covered by: GitHub Actions `matrix.os` strategy with `shell: pwsh`, Pester `New-PesterConfiguration` with `Run.Exit = $true` for proper exit codes |
| CICD-02 | GitHub Actions workflow runs PSScriptAnalyzer on every push and PR (fail on any finding) | Covered by: `Invoke-ScriptAnalyzer` with `-Settings` and `$LASTEXITCODE` / throw pattern for CI failure |
| CICD-03 | PSScriptAnalyzer lints all three `.ps1` files (`VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`) | Covered by: Array iteration or `-Path` called 3 times; existing `PSScriptAnalyzerSettings.psd1` applies to all |
| CICD-04 | Pester pinned to 5.x (`MaximumVersion 5.99`) in CI to prevent Pester 6 auto-install breakage | Covered by: `Install-Module Pester -MaximumVersion 5.99 -Force -Scope CurrentUser` |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| CI workflow definition | GitHub Actions (`.github/workflows/`) | — | Workflow YAML is the authoritative CI config; runs on GitHub's infrastructure |
| Test execution | GitHub Actions runner (pwsh) | — | Pester runs in-process on the runner; no external services |
| Static analysis | GitHub Actions runner (pwsh) | — | PSScriptAnalyzer runs in-process; settings file lives in repo root |
| Local test runner update | Local dev machine | — | `Test-All.ps1` is developer-facing; runs on their machine before push |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Pester | 5.7.1 (latest 5.x) | PowerShell testing framework | Only mature PS test framework; project already uses it [VERIFIED: PSGallery `Find-Module Pester` → 5.7.1, published 2025-01-08] |
| PSScriptAnalyzer | 1.25.0 | PowerShell static analysis / linter | Only PS linter; project already uses it [VERIFIED: PSGallery `Find-Module PSScriptAnalyzer` → 1.25.0, published 2026-03-20] |
| GitHub Actions | N/A | CI/CD platform | GitHub-native; free for public repos; repo is on GitHub [VERIFIED: git remote is `arcticpinecone/pwsh7-VeriHash`] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `actions/checkout@v4` | v4 | Check out repo in workflow | Always first step [ASSUMED] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Install-Module` | `Install-PSResource` (PSResourceGet) | PSResourceGet is newer/faster but not pre-installed on all runner images; `Install-Module` is universally available and well-tested in CI |
| Fresh install each run | Module caching (`actions/cache`) | Caching adds complexity for ~10s savings; user explicitly chose no caching (D-13) |
| Direct `Invoke-Pester` | `Test-All.ps1 -CI` | User chose direct invocation for tests (gives finer control over config), PSSA runs direct per D-08 |

**Installation (in CI):**
```powershell
Install-Module Pester -Force -Scope CurrentUser -MaximumVersion 5.99 -SkipPublisherCheck
Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
```

**Version verification:**
- Pester 5.7.1 — latest on PSGallery as of 2025-01-08 [VERIFIED: `Find-Module Pester`]
- PSScriptAnalyzer 1.25.0 — latest on PSGallery as of 2026-03-20 [VERIFIED: `Find-Module PSScriptAnalyzer`]

## Architecture Patterns

### System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│  GitHub Event: push to dev/main OR PR targeting dev/main     │
└──────────────┬───────────────────────────────────────────────┘
               │ (path filter: *.ps1, Tests/**)
               ▼
┌──────────────────────────────────────────────────────────────┐
│  ci.yml workflow                                             │
│                                                              │
│  ┌─────────────────────────┐  ┌──────────────────────────┐  │
│  │  Job: test              │  │  Job: lint               │  │
│  │  (runs in parallel)     │  │  (runs in parallel)      │  │
│  │                         │  │                          │  │
│  │  Matrix:                │  │  Runner: ubuntu-latest   │  │
│  │   - ubuntu-latest       │  │                          │  │
│  │   - windows-latest      │  │  Steps:                  │  │
│  │                         │  │  1. Checkout             │  │
│  │  Steps:                 │  │  2. Install PSSA         │  │
│  │  1. Checkout            │  │  3. Run PSSA on 3 files  │  │
│  │  2. Install Pester 5.x  │  │  4. Fail if findings     │  │
│  │  3. Run Invoke-Pester   │  │                          │  │
│  │  4. Exit code = result  │  └──────────────────────────┘  │
│  └─────────────────────────┘                                 │
└──────────────────────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│  PR Status Check: All jobs must pass → PR mergeable          │
└──────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure (new/modified files)
```
.github/
└── workflows/
    └── ci.yml              # NEW: CI workflow (single file per D-01)
Test-All.ps1                # MODIFIED: expand lint to all 3 files (D-10)
PSScriptAnalyzerSettings.psd1  # UNCHANGED: reused by both CI and local
```

### Pattern 1: Pester Invocation in CI with Exit Code
**What:** Use `New-PesterConfiguration` with `Run.Exit = $true` for CI-appropriate behavior
**When to use:** Always in CI — ensures non-zero exit code on test failures
**Example:**
```powershell
# Source: Pester 5.x configuration API (project's existing Test-All.ps1 pattern)
$config = New-PesterConfiguration
$config.Run.Path = './Tests'
$config.Run.Exit = $true                  # Exit with non-zero on failure
$config.Output.Verbosity = 'Detailed'     # Full output for CI logs
Invoke-Pester -Configuration $config
```
**Key detail:** `Run.Exit = $true` calls `exit $failedCount` — GitHub Actions interprets non-zero as step failure automatically. No wrapper script needed. [VERIFIED: existing `Test-All.ps1` uses `$pesterConfig.Run.Exit = $false` and handles exit manually; CI should use `$true` for simplicity]

### Pattern 2: PSScriptAnalyzer Multi-File Check with Failure
**What:** Run `Invoke-ScriptAnalyzer` against multiple files and fail CI if any findings exist
**When to use:** Lint job in CI
**Example:**
```powershell
# Source: PSScriptAnalyzer documentation + project's PSScriptAnalyzerSettings.psd1
$files = @(
    './VeriHash.ps1',
    './VeriHash.Config.ps1',
    './VeriHash.LogUtils.ps1'
)
$settings = './PSScriptAnalyzerSettings.psd1'

$allResults = @()
foreach ($file in $files) {
    $results = Invoke-ScriptAnalyzer -Path $file -Settings $settings
    if ($results) {
        $allResults += $results
        Write-Host "❌ Issues in ${file}:" -ForegroundColor Red
        $results | Format-Table RuleName, Severity, Line, Message -AutoSize
    } else {
        Write-Host "✅ ${file}: Clean" -ForegroundColor Green
    }
}

if ($allResults.Count -gt 0) {
    Write-Error "PSScriptAnalyzer found $($allResults.Count) issue(s) across $($files.Count) files"
    exit 1
}
```

### Pattern 3: GitHub Actions Path Filter Syntax
**What:** Only trigger CI when relevant files change
**When to use:** Workflow `on:` trigger (per D-03)
**Example:**
```yaml
# Source: GitHub Actions documentation (paths filter)
on:
  push:
    branches: [dev, main]
    paths:
      - '**.ps1'
      - 'Tests/**'
      - 'PSScriptAnalyzerSettings.psd1'
  pull_request:
    branches: [dev, main]
    paths:
      - '**.ps1'
      - 'Tests/**'
      - 'PSScriptAnalyzerSettings.psd1'
```
**Key detail:** `**.ps1` matches `.ps1` files at any depth. Including `PSScriptAnalyzerSettings.psd1` in path filters ensures lint rule changes also trigger CI. [ASSUMED: GitHub Actions glob syntax — well-documented but not verified in this session]

### Pattern 4: Module Installation in CI
**What:** Install modules reliably in non-interactive CI environment
**When to use:** Setup step before test/lint execution
**Example:**
```powershell
# Force + SkipPublisherCheck avoids all interactive prompts
# Scope CurrentUser avoids needing sudo on Linux
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module Pester -Force -Scope CurrentUser -MaximumVersion 5.99
Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
```
**Key detail:** `Set-PSRepository PSGallery -InstallationPolicy Trusted` eliminates the "untrusted repository" prompt that would hang CI. Alternative: use `-Force` which also suppresses this. Both work; combining them is belt-and-suspenders. [VERIFIED: local PSGallery shows `InstallationPolicy: Untrusted` by default]

### Anti-Patterns to Avoid
- **Using `shell: powershell` on Windows:** This invokes Windows PowerShell 5.1, not PowerShell 7. The project requires pwsh 7+. Always use `shell: pwsh`.
- **Installing PSFramework in CI:** Tests work without it (all PSFramework calls are guarded by `$script:PSFrameworkAvailable`). Installing it adds ~10s and complexity for zero benefit. User explicitly excluded this (D-14).
- **Using `Invoke-Pester` without configuration object:** The legacy parameter syntax (`-Script`, `-PassThru`) is Pester 4.x. Pester 5.x uses `New-PesterConfiguration`. The project already uses the 5.x pattern.
- **Not removing pre-installed Pester on Windows:** GitHub Windows runners may have Pester 5.x pre-installed via PackageManagement. `Install-Module -Force` handles this by overwriting. No explicit removal needed.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Test framework | Custom test runner | Pester 5.x | Mature, handles assertions, mocking, test discovery, exit codes |
| Static analysis | Custom lint rules | PSScriptAnalyzer + settings file | Standard PS linter with configurable rules, project already has settings |
| CI platform | Self-hosted runner | GitHub Actions | Free for public repos, pre-installed pwsh, zero maintenance |
| Version pinning | Manual version checks | `MaximumVersion` parameter | Built into `Install-Module`, guaranteed by PowerShellGet |
| Path filtering | Custom scripts to detect changes | GitHub Actions `paths:` filter | Native feature, zero code needed |

**Key insight:** Every component of this phase uses standard, battle-tested tools with no custom logic beyond glue scripts. The only "code" is YAML workflow definition and minor PowerShell module-install commands.

## Common Pitfalls

### Pitfall 1: PSGallery Untrusted Repository Prompt
**What goes wrong:** `Install-Module` hangs waiting for user confirmation because PSGallery is untrusted by default.
**Why it happens:** Fresh runner environments have PSGallery marked as `Untrusted` — any module install triggers an interactive "are you sure?" prompt.
**How to avoid:** Either `Set-PSRepository PSGallery -InstallationPolicy Trusted` before installing, or use `-Force` on every `Install-Module` call (which suppresses the prompt).
**Warning signs:** CI job hangs indefinitely at the install step with no output.

### Pitfall 2: Pester 3.x Pre-installed on Windows PowerShell
**What goes wrong:** Tests use Pester 4.x/5.x API (`New-PesterConfiguration`) but Pester 3.x is loaded.
**Why it happens:** Windows runners have Pester 3.4.0 installed system-wide for Windows PowerShell 5.1. If `shell: powershell` is used accidentally, Pester 3.x is found first.
**How to avoid:** Always use `shell: pwsh` (D-07). PowerShell 7 has a separate module path and `Install-Module -Force -Scope CurrentUser` puts 5.x in the user scope.
**Warning signs:** Error `New-PesterConfiguration: The term 'New-PesterConfiguration' is not recognized`.

### Pitfall 3: `Invoke-ScriptAnalyzer` Returns Nothing But Still Fails
**What goes wrong:** PSScriptAnalyzer returns `$null` (no issues) but the step is interpreted as failure.
**Why it happens:** Misusing `exit $results.Count` when `$results` is `$null` — PowerShell converts `$null.Count` to `0`, so this is actually fine. The real pitfall is the inverse: `$results` contains issues but the step doesn't fail because no `exit 1` is explicitly coded.
**How to avoid:** Explicitly check `if ($results) { exit 1 }` — when `$results` is a non-empty array, this is truthy. When empty/null, it's falsy.
**Warning signs:** CI shows "Issues found" in output but the job is marked green.

### Pitfall 4: Path Filters Blocking Initial Workflow Runs
**What goes wrong:** First commit with the workflow file never triggers CI because the workflow itself isn't in the `paths:` filter.
**Why it happens:** GitHub Actions evaluates `paths:` against the *changed files in the push*. If the first push only contains `.github/workflows/ci.yml` and no `.ps1` changes, the workflow won't trigger.
**How to avoid:** The first commit should include both the workflow file AND at least one `.ps1` or `Tests/` change. Or include `.github/workflows/**` in the paths filter (but this defeats the purpose for future docs-only changes). Simplest: accept that the first CI run may need a follow-up push to trigger.
**Warning signs:** Workflow tab shows "No workflow runs" after pushing ci.yml.

### Pitfall 5: Pester `Run.Exit = $true` Exits the Entire PowerShell Process
**What goes wrong:** When `Run.Exit = $true`, Pester calls `exit` at the process level. If there are steps after the Pester step in the same `run:` block, they won't execute.
**Why it happens:** `Run.Exit = $true` is designed for CI — it expects to be the last command.
**How to avoid:** Put `Invoke-Pester` in its own `run:` step (not combined with other commands in the same step). Each `run:` step is a separate process in GitHub Actions, so the exit only terminates that step.
**Warning signs:** Steps after Pester in the same `run:` block never execute.

### Pitfall 6: `Test-All.ps1` Lint Expansion Breaking Existing Behavior
**What goes wrong:** Expanding lint to 3 files reveals existing PSScriptAnalyzer findings in `VeriHash.Config.ps1` or `VeriHash.LogUtils.ps1` that make `Test-All.ps1` report failures locally.
**Why it happens:** These files were never linted before. Phase 1 may have introduced code that doesn't pass all rules.
**How to avoid:** Run PSScriptAnalyzer locally against all 3 files BEFORE creating the CI workflow. Fix any findings as part of this phase. The `VeriHash.LogUtils.Tests.ps1` already has an inline PSSA test for LogUtils — if that passes, LogUtils is likely clean.
**Warning signs:** First CI run fails on lint, not on new changes but on pre-existing code.

## Code Examples

### Complete CI Workflow (recommended structure)

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [dev, main]
    paths:
      - '**.ps1'
      - 'Tests/**'
      - 'PSScriptAnalyzerSettings.psd1'
  pull_request:
    branches: [dev, main]
    paths:
      - '**.ps1'
      - 'Tests/**'
      - 'PSScriptAnalyzerSettings.psd1'

jobs:
  test:
    name: Tests (${{ matrix.os }})
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest]

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Pester
        shell: pwsh
        run: |
          Set-PSRepository PSGallery -InstallationPolicy Trusted
          Install-Module Pester -Force -Scope CurrentUser -MaximumVersion 5.99

      - name: Run Pester Tests
        shell: pwsh
        run: |
          $config = New-PesterConfiguration
          $config.Run.Path = './Tests'
          $config.Run.Exit = $true
          $config.Output.Verbosity = 'Detailed'
          Invoke-Pester -Configuration $config

  lint:
    name: PSScriptAnalyzer
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install PSScriptAnalyzer
        shell: pwsh
        run: |
          Set-PSRepository PSGallery -InstallationPolicy Trusted
          Install-Module PSScriptAnalyzer -Force -Scope CurrentUser

      - name: Run PSScriptAnalyzer
        shell: pwsh
        run: |
          $files = @(
              './VeriHash.ps1',
              './VeriHash.Config.ps1',
              './VeriHash.LogUtils.ps1'
          )
          $settings = './PSScriptAnalyzerSettings.psd1'
          $totalIssues = 0

          foreach ($file in $files) {
              $results = Invoke-ScriptAnalyzer -Path $file -Settings $settings
              if ($results) {
                  $totalIssues += $results.Count
                  Write-Host "❌ $file - $($results.Count) issue(s):" -ForegroundColor Red
                  $results | Format-Table RuleName, Severity, Line, Message -AutoSize
              } else {
                  Write-Host "✅ $file - Clean" -ForegroundColor Green
              }
          }

          if ($totalIssues -gt 0) {
              Write-Error "PSScriptAnalyzer found $totalIssues total issue(s)"
              exit 1
          }

          Write-Host "`n✅ All files pass PSScriptAnalyzer" -ForegroundColor Green
```

### Test-All.ps1 Lint Expansion (D-10)

Current (line 116):
```powershell
$scriptPath = Join-Path $scriptRoot "VeriHash.ps1"
```

Updated:
```powershell
$scriptPaths = @(
    (Join-Path $scriptRoot "VeriHash.ps1"),
    (Join-Path $scriptRoot "VeriHash.Config.ps1"),
    (Join-Path $scriptRoot "VeriHash.LogUtils.ps1")
)
```

And the invocation changes from:
```powershell
$analysisResults = Invoke-ScriptAnalyzer -Path $scriptPath -Settings $settingsPath
```

To iterating over all files:
```powershell
$analysisResults = @()
foreach ($path in $scriptPaths) {
    $results = Invoke-ScriptAnalyzer -Path $path -Settings $settingsPath
    if ($results) { $analysisResults += $results }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Pester 4.x legacy syntax (`-Script`, `-PassThru`) | Pester 5.x `New-PesterConfiguration` API | Pester 5.0 (2020) | Must use configuration objects; legacy params deprecated |
| `Install-Module` (PowerShellGet v2) | `Install-PSResource` (PSResourceGet v1) | 2023+ | PSResourceGet is faster but `Install-Module` still works and is universally available on runners |
| `shell: powershell` (Win PS 5.1) | `shell: pwsh` (PS 7+) | GitHub Actions pwsh availability ~2020 | Cross-platform consistency; project requires PS 7+ |
| Manual exit code management | `Run.Exit = $true` in Pester config | Pester 5.0+ | Built-in CI support; no wrapper needed |

**Deprecated/outdated:**
- **Pester 4.x syntax:** `Invoke-Pester -Script $path -PassThru` is deprecated. Use `New-PesterConfiguration` + `Invoke-Pester -Configuration $config`.
- **`-SkipPublisherCheck` on Pester:** Was needed when Pester was catalog-signed (pre-5.4). Modern Pester versions don't require it, but including it is harmless.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `actions/checkout@v4` is the current version of the checkout action | Standard Stack | Low — v3 would also work; v4 is latest stable |
| A2 | GitHub Actions glob `**.ps1` matches .ps1 files at any directory depth in path filters | Architecture Patterns (Pattern 3) | Medium — if wrong, path filter might not catch nested .ps1 files (but project has no nested .ps1) |
| A3 | GitHub Actions runners (ubuntu-latest, windows-latest) have `pwsh` 7.x pre-installed | Common Pitfalls | Low — this has been true since 2020 and is well-documented by GitHub |
| A4 | `fail-fast: false` in matrix strategy means all OS jobs complete even if one fails | Code Examples | Low — standard documented behavior |

## Open Questions

1. **Should the workflow include `workflow_dispatch:` for manual triggers?**
   - What we know: Not mentioned in decisions; useful for debugging CI without pushing code changes
   - What's unclear: Whether user wants this convenience
   - Recommendation: Include it — zero cost, useful for debugging. Agent's discretion area.

2. **Should the workflow cancel in-progress runs when a new push arrives?**
   - What we know: Listed as agent's discretion in CONTEXT.md
   - What's unclear: User preference
   - Recommendation: Yes, add `concurrency` with `cancel-in-progress: true` for PRs — saves runner minutes, most recent push is the one that matters.

3. **Pre-existing PSScriptAnalyzer findings in Config/LogUtils files?**
   - What we know: `VeriHash.LogUtils.Tests.ps1` already has an inline PSSA test that passes (line 199-213). No such test exists for `VeriHash.Config.ps1`.
   - What's unclear: Whether `VeriHash.Config.ps1` passes PSSA cleanly
   - Recommendation: Run PSSA against all 3 files as the first implementation step. Fix any findings before creating the workflow.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| pwsh (CI runner) | All workflow steps | ✓ (pre-installed on GitHub Actions) | 7.x | — |
| PSGallery | Module installation | ✓ | — | — |
| Pester (PSGallery) | Test job | ✓ | 5.7.1 | — |
| PSScriptAnalyzer (PSGallery) | Lint job | ✓ | 1.25.0 | — |
| GitHub Actions | CI platform | ✓ | — | — |
| `.github/workflows/` directory | Workflow file | ✗ (doesn't exist yet) | — | Create it |

**Missing dependencies with no fallback:**
- None — all dependencies are available

**Missing dependencies with fallback:**
- `.github/workflows/` directory: Must be created (trivial)

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Pester 5.7.1 |
| Config file | None — configuration built inline (project convention) |
| Quick run command | `pwsh -Command "Invoke-Pester ./Tests -Output Detailed"` |
| Full suite command | `pwsh -File ./Test-All.ps1 -CI` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CICD-01 | Pester tests run on push/PR on ubuntu + windows | smoke (CI run) | Push a commit; check Actions tab | ❌ (validated by first CI run) |
| CICD-02 | PSSA runs on push/PR, fails on findings | smoke (CI run) | Push a commit with a known violation; verify red | ❌ (validated by first CI run) |
| CICD-03 | PSSA lints all 3 .ps1 files | unit | `pwsh -Command "Invoke-ScriptAnalyzer -Path ./VeriHash.Config.ps1 -Settings ./PSScriptAnalyzerSettings.psd1"` | ✅ (LogUtils inline test exists) |
| CICD-04 | Pester pinned to 5.x | inspection | Verify `MaximumVersion 5.99` in ci.yml | ❌ (verified by code review) |

### Sampling Rate
- **Per task commit:** `pwsh -File ./Test-All.ps1 -CI` (runs locally to ensure nothing breaks)
- **Per wave merge:** Push to `dev` branch → observe GitHub Actions run
- **Phase gate:** First successful CI run (green) on both ubuntu + windows after workflow is pushed

### Wave 0 Gaps
- [ ] `.github/workflows/` directory — must be created
- [ ] Verify `VeriHash.Config.ps1` passes PSSA before adding to CI lint (run locally first)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | No | — (no secrets in workflow; public repo) |
| V5 Input Validation | No | — |
| V6 Cryptography | No | — |

### Known Threat Patterns for GitHub Actions

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Workflow injection via PR title/body | Tampering | Don't use `${{ github.event.pull_request.title }}` in `run:` blocks — not applicable here (no such usage) |
| Secrets exposure in logs | Information Disclosure | No secrets used in this workflow (public repo, no API keys needed) |
| Dependency confusion (malicious module on PSGallery) | Tampering | Low risk — Pester and PSScriptAnalyzer are well-known Microsoft-maintained modules |

**Assessment:** This phase has minimal security surface. No secrets, no network calls, no user input processing. Standard `actions/checkout@v4` pin to major version is acceptable for a public repo.

## Sources

### Primary (HIGH confidence)
- Project codebase: `Test-All.ps1`, `PSScriptAnalyzerSettings.psd1`, `Tests/VeriHash.LogUtils.Tests.ps1` — existing patterns verified by reading files
- PSGallery registry: `Find-Module Pester` → 5.7.1, `Find-Module PSScriptAnalyzer` → 1.25.0 — versions verified via PowerShell commands
- `.planning/phases/02-ci-cd-pipeline/02-CONTEXT.md` — user decisions locked

### Secondary (MEDIUM confidence)
- GitHub Actions runner images: pwsh pre-installed on ubuntu-latest and windows-latest [ASSUMED — well-documented by GitHub, stable since 2020]
- GitHub Actions YAML syntax: `paths:`, `matrix:`, `shell:`, `concurrency:` — [ASSUMED — standard documented features]

### Tertiary (LOW confidence)
- None — all claims are either verified against codebase/registry or well-established platform features

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified against PSGallery registry, no ambiguity
- Architecture: HIGH — simple workflow with two jobs, all decisions locked by user
- Pitfalls: HIGH — drawn from established PowerShell CI patterns and verified local behavior (PSGallery untrusted policy)

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (stable domain — GitHub Actions and Pester 5.x are mature)
