#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runs all tests and code quality checks for VeriHash

.DESCRIPTION
    This script runs:
    1. Pester unit tests
    2. PSScriptAnalyzer code quality checks

    Use this before committing changes to ensure code quality.

.PARAMETER SkipTests
    Skip running Pester tests

.PARAMETER SkipAnalyzer
    Skip running PSScriptAnalyzer

.PARAMETER CI
    Run in CI mode (exit with error code if tests fail)

.EXAMPLE
    .\Test-All.ps1
    Runs all tests and checks

.EXAMPLE
    .\Test-All.ps1 -SkipAnalyzer
    Runs only Pester tests
#>

param(
    [switch]$SkipTests,
    [switch]$SkipAnalyzer,
    [switch]$CI
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
$testsPassed = $true

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  VeriHash - Test & Quality Check" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if required modules are installed
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

# Run Pester Tests
if (-not $SkipTests) {
    Write-Host "[1/2] Running Pester Tests..." -ForegroundColor Yellow
    Write-Host "---`n" -ForegroundColor DarkGray

    $testsPath = Join-Path $scriptRoot "Tests"

    if (Test-Path $testsPath) {
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $testsPath
        $pesterConfig.Output.Verbosity = 'Detailed'
        $pesterConfig.Run.Exit = $false

        $testResults = Invoke-Pester -Configuration $pesterConfig

        if ($testResults.FailedCount -gt 0) {
            $testsPassed = $false
            Write-Host "`n❌ Tests FAILED: $($testResults.FailedCount) failed, $($testResults.PassedCount) passed" -ForegroundColor Red
        } else {
            Write-Host "`n✅ All tests PASSED: $($testResults.PassedCount) tests" -ForegroundColor Green
        }
    } else {
        Write-Warning "Tests directory not found: $testsPath"
    }

    Write-Host ""
} else {
    Write-Host "[1/2] Skipping Pester Tests" -ForegroundColor DarkGray
    Write-Host ""
}

# Run PSScriptAnalyzer
if (-not $SkipAnalyzer) {
    Write-Host "[2/2] Running PSScriptAnalyzer..." -ForegroundColor Yellow
    Write-Host "---`n" -ForegroundColor DarkGray

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
            Write-Host "❌ PSScriptAnalyzer found $errorCount error(s)" -ForegroundColor Red
        } elseif ($warningCount -gt 0) {
            Write-Host "⚠️  PSScriptAnalyzer found $warningCount warning(s)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✅ No issues found by PSScriptAnalyzer" -ForegroundColor Green
    }

    Write-Host ""
} else {
    Write-Host "[2/2] Skipping PSScriptAnalyzer" -ForegroundColor DarkGray
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
if ($testsPassed) {
    Write-Host "  ✅ All checks passed!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Cyan

    if ($CI) {
        exit 0
    }
} else {
    Write-Host "  ❌ Some checks failed!" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Cyan

    if ($CI) {
        exit 1
    }
}
