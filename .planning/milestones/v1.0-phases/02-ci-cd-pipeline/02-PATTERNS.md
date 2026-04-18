# Phase 2: CI/CD Pipeline - Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 2 (1 new, 1 modified)
**Analogs found:** 2 / 2

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.github/workflows/ci.yml` | config | event-driven | `Test-All.ps1` (functional analog) | partial — no workflows exist; Test-All.ps1 provides the Pester + PSSA invocation patterns CI must replicate |
| `Test-All.ps1` | utility | batch | Self (lines 111-145) | exact — modifying existing file's PSScriptAnalyzer section |

## Pattern Assignments

### `.github/workflows/ci.yml` (config, event-driven) — NEW FILE

**Analog:** `Test-All.ps1` — the CI workflow replicates what this script does locally (Pester tests + PSScriptAnalyzer lint), but as parallel GitHub Actions jobs.

**No direct YAML analog exists** — this is the first workflow in the repo. The patterns below are extracted from the existing PowerShell scripts that CI must replicate, plus the RESEARCH.md recommended YAML structure.

---

**Pester invocation pattern — from `Test-All.ps1` lines 84-89:**

The project uses Pester 5.x `New-PesterConfiguration` API (not legacy Pester 4.x parameters). CI should replicate this with `Run.Exit = $true` instead of `$false`:

```powershell
# LOCAL pattern (Test-All.ps1 lines 84-89):
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = $testsPath
$pesterConfig.Output.Verbosity = 'Detailed'
$pesterConfig.Run.Exit = $false    # <-- local handles exit manually

$testResults = Invoke-Pester -Configuration $pesterConfig
```

**CI adaptation** — change `Run.Exit` to `$true` so Pester exits the process with non-zero on failure (each `run:` step is a separate process in GitHub Actions, so this is safe):

```powershell
# CI pattern (for test job step):
$config = New-PesterConfiguration
$config.Run.Path = './Tests'
$config.Run.Exit = $true           # <-- CI: exit non-zero on failure
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
```

**Key difference:** Local `Test-All.ps1` uses `Run.Exit = $false` and manages exit codes itself (lines 208-214). CI uses `Run.Exit = $true` because each `run:` block is isolated — see RESEARCH.md Pitfall 5.

---

**PSScriptAnalyzer invocation pattern — from `Test-All.ps1` lines 115-139:**

The current local pattern lints a single file with the project settings file:

```powershell
# LOCAL pattern (Test-All.ps1 lines 115-122):
$settingsPath = Join-Path $scriptRoot "PSScriptAnalyzerSettings.psd1"
$scriptPath = Join-Path $scriptRoot "VeriHash.ps1"

if (Test-Path $settingsPath) {
    $analysisResults = Invoke-ScriptAnalyzer -Path $scriptPath -Settings $settingsPath
} else {
    $analysisResults = Invoke-ScriptAnalyzer -Path $scriptPath
}
```

**CI adaptation** — iterate over all 3 files, use `exit 1` on findings:

```powershell
# CI pattern (for lint job step):
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
```

---

**Result reporting pattern — from `Test-All.ps1` lines 92-97 and 124-138:**

The project uses emoji + colored `Write-Host` for pass/fail reporting:

```powershell
# Pass/fail reporting (Test-All.ps1 lines 92-97):
if ($testResults.FailedCount -gt 0) {
    $testsPassed = $false
    Write-Host "  ❌ Tests FAILED: $($testResults.FailedCount) failed, $($testResults.PassedCount) passed" -ForegroundColor Red
} else {
    Write-Host "  ✅ All $($testResults.PassedCount) tests PASSED" -ForegroundColor Green
}
```

```powershell
# PSSA result reporting (Test-All.ps1 lines 124-138):
if ($analysisResults) {
    $errorCount = ($analysisResults | Where-Object Severity -eq 'Error').Count
    $warningCount = ($analysisResults | Where-Object Severity -eq 'Warning').Count

    Write-Host "Found $($analysisResults.Count) issue(s):" -ForegroundColor Yellow
    $analysisResults | Format-Table -AutoSize

    if ($errorCount -gt 0) {
        $testsPassed = $false
        Write-Host "  ❌ PSScriptAnalyzer found $errorCount error(s)" -ForegroundColor Red
    } elseif ($warningCount -gt 0) {
        Write-Host "  ⚠️  PSScriptAnalyzer found $warningCount warning(s)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✅ No issues found" -ForegroundColor Green
}
```

---

**Module availability check pattern — from `Test-All.ps1` lines 60-72:**

The project checks for module availability before use. In CI, modules are explicitly installed so this isn't needed, but the install pattern should mirror the local expectation:

```powershell
# LOCAL check (Test-All.ps1 lines 60-65):
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Warning "Pester is not installed. Skipping tests."
    $SkipTests = $true
}
```

**CI module install** (no check needed — install unconditionally):

```powershell
# CI install pattern (from RESEARCH.md, verified):
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module Pester -Force -Scope CurrentUser -MaximumVersion 5.99
```

```powershell
# CI install pattern for PSSA:
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
```

---

**CI exit code pattern — from `Test-All.ps1` lines 208-214:**

```powershell
# Test-All.ps1 lines 208-214:
if ($CI) {
    if ($testsPassed) {
        exit 0
    } else {
        exit 1
    }
}
```

In the CI workflow, this is handled automatically: `Run.Exit = $true` for Pester, explicit `exit 1` for PSSA.

---

**PSScriptAnalyzer settings reuse — from `PSScriptAnalyzerSettings.psd1` (full file, 41 lines):**

Both CI and local must use the same settings file. Key configuration:

```powershell
# PSScriptAnalyzerSettings.psd1 lines 1-40:
@{
    IncludeDefaultRules = $true
    Severity = @('Error', 'Warning')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',          # Intentional: interactive console tool
        'PSAvoidUsingBrokenHashAlgorithms' # Intentional: MD5 for legacy sidecar compatibility
    )
    Rules = @{
        PSAvoidUsingCmdletAliases = @{
            allowlist = @()
        }
        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @('7.0')
        }
    }
}
```

**CI must pass `-Settings ./PSScriptAnalyzerSettings.psd1`** to `Invoke-ScriptAnalyzer`. D-09 confirms CI fails on both Error and Warning severity — this is already configured in the settings file's `Severity` key.

---

**Inline PSSA test pattern — from `Tests/VeriHash.LogUtils.Tests.ps1` lines 199-213:**

This is the established project pattern for running PSSA inside Pester. It shows how the project expects PSSA to be invoked:

```powershell
# Tests/VeriHash.LogUtils.Tests.ps1 lines 199-213:
Describe 'Code Quality - PSScriptAnalyzer' {
    It 'VeriHash.LogUtils.ps1 passes PSScriptAnalyzer with no warnings or errors' {
        if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
            Set-ItResult -Skipped -Because "PSScriptAnalyzer module is not installed"
            return
        }

        $results = Invoke-ScriptAnalyzer -Path $script:LogUtilsPath -Severity Warning, Error
        $results | Should -BeNullOrEmpty -Because "PSScriptAnalyzer found issues: $($results | ForEach-Object { "`n  [$($_.Severity)] $($_.RuleName) at line $($_.Line): $($_.Message)" })"
    }
}
```

Note: This inline test uses `-Severity Warning, Error` directly rather than `-Settings`. CI should use the `-Settings` approach for consistency with `Test-All.ps1`.

---

### `Test-All.ps1` (utility, batch) — MODIFY

**Analog:** Self — the PSScriptAnalyzer section (lines 111-145) is the modification target.

**Current single-file lint pattern (lines 115-122):**

```powershell
    $settingsPath = Join-Path $scriptRoot "PSScriptAnalyzerSettings.psd1"
    $scriptPath = Join-Path $scriptRoot "VeriHash.ps1"

    if (Test-Path $settingsPath) {
        $analysisResults = Invoke-ScriptAnalyzer -Path $scriptPath -Settings $settingsPath
    } else {
        $analysisResults = Invoke-ScriptAnalyzer -Path $scriptPath
    }
```

**Target: expand to multi-file pattern (D-10):**

Line 116 changes from single `$scriptPath` to array `$scriptPaths`, and lines 118-122 change from single invocation to a foreach loop that aggregates results. The rest of the section (lines 124-145: result reporting, error/warning counting, display) works unchanged because `$analysisResults` remains an array of findings.

**Variable naming pattern** — from `Test-All.ps1` existing variables:

```powershell
# Existing naming convention (lines 47, 81, 115-116):
$scriptRoot = $PSScriptRoot
$testsPath = Join-Path $scriptRoot "Tests"
$settingsPath = Join-Path $scriptRoot "PSScriptAnalyzerSettings.psd1"
$scriptPath = Join-Path $scriptRoot "VeriHash.ps1"          # <-- becomes $scriptPaths (plural)
```

The new array variable should follow the same `Join-Path $scriptRoot` pattern:

```powershell
$scriptPaths = @(
    (Join-Path $scriptRoot "VeriHash.ps1"),
    (Join-Path $scriptRoot "VeriHash.Config.ps1"),
    (Join-Path $scriptRoot "VeriHash.LogUtils.ps1")
)
```

**Iteration + aggregation pattern** — consistent with the project's existing style (used in profiler section, lines 169-178):

```powershell
$analysisResults = @()
foreach ($path in $scriptPaths) {
    if (Test-Path $settingsPath) {
        $results = Invoke-ScriptAnalyzer -Path $path -Settings $settingsPath
    } else {
        $results = Invoke-ScriptAnalyzer -Path $path
    }
    if ($results) { $analysisResults += $results }
}
```

The existing result display code (lines 124-139) already handles `$analysisResults` as an array — no changes needed there.

---

## Shared Patterns

### Shell: Always `pwsh`
**Source:** `.github/copilot-instructions.md` + CONTEXT.md D-07
**Apply to:** Every `run:` step in `.github/workflows/ci.yml`

All workflow steps must use `shell: pwsh`. The project requires PowerShell 7+ and never uses Windows PowerShell 5.1. Can be set at job level as a default.

### Module Install: Non-Interactive
**Source:** `Test-All.ps1` lines 60-72 (check pattern) + RESEARCH.md Pattern 4
**Apply to:** CI workflow install steps

```powershell
# Set trusted to avoid interactive prompt (RESEARCH.md Pitfall 1):
Set-PSRepository PSGallery -InstallationPolicy Trusted
# Pester pinned to 5.x (D-11, CICD-04):
Install-Module Pester -Force -Scope CurrentUser -MaximumVersion 5.99
# PSSA at latest (D-12):
Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
```

### Pester Configuration API (5.x)
**Source:** `Test-All.ps1` lines 84-89
**Apply to:** CI test job

Always use `New-PesterConfiguration` + `Invoke-Pester -Configuration $config`. Never use Pester 4.x legacy parameters (`-Script`, `-PassThru`).

### PSScriptAnalyzer Settings Reuse
**Source:** `PSScriptAnalyzerSettings.psd1` (full file)
**Apply to:** CI lint job + `Test-All.ps1` lint section

Always pass `-Settings ./PSScriptAnalyzerSettings.psd1` (or `$settingsPath` locally). Never hard-code excluded rules inline — the settings file is the single source of truth.

### Error Reporting Style
**Source:** `Test-All.ps1` lines 92-97, 128-138
**Apply to:** CI workflow `Write-Host` output

Use emoji prefixes (`✅`, `❌`, `⚠️`) with `-ForegroundColor` for pass/fail output. CI can use the same style since GitHub Actions renders ANSI colors.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `.github/workflows/ci.yml` | config | event-driven | No GitHub Actions workflows exist in the repo. YAML structure comes from RESEARCH.md code examples (lines 279-367). Functional logic (Pester + PSSA invocation) is drawn from `Test-All.ps1` patterns above. |

**Guidance for planner:** The CI workflow YAML structure should follow the complete example in RESEARCH.md lines 279-367. The PowerShell logic within `run:` blocks should copy patterns from `Test-All.ps1` as documented in the Pattern Assignments section above.

---

## Metadata

**Analog search scope:** Repository root (all `.ps1` files, `Tests/` directory, `.github/`, `.planning/codebase/`)
**Files scanned:** 12 (all `.ps1` scripts, settings file, test files, planning docs)
**Pattern extraction date:** 2026-04-18
