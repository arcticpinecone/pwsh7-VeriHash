#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runs all tests and code quality checks for VeriHash

.DESCRIPTION
    This script runs:
    1. Pester unit tests
    2. PSScriptAnalyzer code quality checks
    3. (Optional) Quick performance profile

    Use this before committing changes to ensure code quality.

.PARAMETER SkipTests
    Skip running Pester tests

.PARAMETER SkipAnalyzer
    Skip running PSScriptAnalyzer

.PARAMETER SkipProfiler
    Skip running the performance profiler summary

.PARAMETER CI
    Run in CI mode (exit with error code if tests fail)

.EXAMPLE
    .\Test-All.ps1
    Runs all tests and checks

.EXAMPLE
    .\Test-All.ps1 -SkipAnalyzer
    Runs only Pester tests

.EXAMPLE
    .\Test-All.ps1 -CI
    Runs in CI mode with proper exit codes
#>

param(
    [switch]$SkipTests,
    [switch]$SkipAnalyzer,
    [switch]$SkipProfiler,
    [switch]$CI
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
$testsPassed = $true

# ════════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║     VeriHash - Test & Quality Check      ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ════════════════════════════════════════════════════════════════════════════════
# Check if required modules are installed
# ════════════════════════════════════════════════════════════════════════════════
if (-not $SkipTests) {
    if (-not (Get-Module -ListAvailable -Name Pester)) {
        Write-Warning "Pester is not installed. Skipping tests."
        $SkipTests = $true
    }
}

if (-not $SkipAnalyzer) {
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Write-Warning "PSScriptAnalyzer is not installed. Skipping code analysis."
        $SkipAnalyzer = $true
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# [1/3] Pester Tests
# ════════════════════════════════════════════════════════════════════════════════
if (-not $SkipTests) {
    Write-Host "[1/3] Running Pester Tests" -ForegroundColor Yellow
    Write-Host "─────────────────────────────────────────────" -ForegroundColor DarkGray

    $testsPath = Join-Path $scriptRoot "Tests"

    if (Test-Path $testsPath) {
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $testsPath
        $pesterConfig.Output.Verbosity = 'Detailed'
        $pesterConfig.Run.Exit = $false

        $testResults = Invoke-Pester -Configuration $pesterConfig

        Write-Host ""
        if ($testResults.FailedCount -gt 0) {
            $testsPassed = $false
            Write-Host "  ❌ Tests FAILED: $($testResults.FailedCount) failed, $($testResults.PassedCount) passed" -ForegroundColor Red
        } else {
            Write-Host "  ✅ All $($testResults.PassedCount) tests PASSED" -ForegroundColor Green
        }
    } else {
        Write-Warning "Tests directory not found: $testsPath"
    }

    Write-Host ""
} else {
    Write-Host "[1/3] Skipping Pester Tests" -ForegroundColor DarkGray
    Write-Host ""
}

# ════════════════════════════════════════════════════════════════════════════════
# [2/3] PSScriptAnalyzer
# ════════════════════════════════════════════════════════════════════════════════
if (-not $SkipAnalyzer) {
    Write-Host "[2/3] Running PSScriptAnalyzer" -ForegroundColor Yellow
    Write-Host "─────────────────────────────────────────────" -ForegroundColor DarkGray

    $settingsPath = Join-Path $scriptRoot "PSScriptAnalyzerSettings.psd1"
    $scriptPath = Join-Path $scriptRoot "VeriHash.ps1"

    if (Test-Path $settingsPath) {
        $analysisResults = Invoke-ScriptAnalyzer -Path $scriptPath -Settings $settingsPath
    } else {
        $analysisResults = Invoke-ScriptAnalyzer -Path $scriptPath
    }

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

    Write-Host ""
} else {
    Write-Host "[2/3] Skipping PSScriptAnalyzer" -ForegroundColor DarkGray
    Write-Host ""
}

# ════════════════════════════════════════════════════════════════════════════════
# [3/3] Performance Profiler (Quick Check)
# ════════════════════════════════════════════════════════════════════════════════
$profilerScript = Join-Path $scriptRoot "Profile-VeriHashTiming.ps1"
$testIconFile = Join-Path $scriptRoot "Tests\VeriHash_1024.ico"

if (-not $SkipProfiler -and (Test-Path $profilerScript) -and (Test-Path $testIconFile)) {
    Write-Host "[3/3] Performance Profiler (Quick Check)" -ForegroundColor Yellow
    Write-Host "─────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  File: VeriHash_1024.ico (small file, overhead-focused)" -ForegroundColor DarkGray
    Write-Host ""

    # Prevent profiler from clearing the terminal
    $env:VERIHASH_NO_CLEAR = '1'
    $env:VERIHASH_TEST_MODE = '1'

    $profilerResult = & $profilerScript -FilePath $testIconFile -Algorithm SHA256 -Quiet

    # Display a clean summary table
    Write-Host "  Operation                      Time (ms)    Share" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray

    foreach ($entry in $profilerResult.SortedMeasurements) {
        $name = $entry.Key
        $ms = $entry.Value
        $pct = ($ms / $profilerResult.Total) * 100

        # Color by percentage
        $color = if ($pct -gt 25) { 'Yellow' } elseif ($pct -gt 10) { 'White' } else { 'DarkGray' }

        Write-Host ("  {0,-30} {1,7:N2}    {2,5:N1}%" -f $name, $ms, $pct) -ForegroundColor $color
    }

    Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ("  {0,-30} {1,7:N2} ms" -f "TOTAL", $profilerResult.Total) -ForegroundColor Green
    Write-Host ""

    # Note about what this measures
    Write-Host "  Note: Small file test shows overhead distribution." -ForegroundColor DarkGray
    Write-Host "        For large files, Hash Computation dominates (see Pester timing tests)." -ForegroundColor DarkGray
    Write-Host ""

    $env:VERIHASH_NO_CLEAR = $null
    $env:VERIHASH_TEST_MODE = $null
} else {
    Write-Host "[3/3] Skipping Performance Profiler" -ForegroundColor DarkGray
    Write-Host ""
}

# ════════════════════════════════════════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════════════════════════════════════════
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
if ($testsPassed) {
    Write-Host "  ║         ✅ All checks passed!            ║" -ForegroundColor Green
} else {
    Write-Host "  ║         ❌ Some checks failed!           ║" -ForegroundColor Red
}
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($CI) {
    if ($testsPassed) {
        exit 0
    } else {
        exit 1
    }
}